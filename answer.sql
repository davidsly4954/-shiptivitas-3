-- TYPE YOUR SQL QUERY BELOW
--
-- Shiptivity analytics, task 3.
-- All timestamps in the database are Unix epoch seconds, so
-- date(<column>, 'unixepoch') turns them into calendar days.
-- The Kanban board was released on 2018-06-02: "before" is every day up to
-- 2018-06-01, "after" is 2018-06-02 onwards.
-- Each statement below runs on its own in sqlite3 (SQLite 3.25 or newer, for
-- the window functions in queries 1a, 2c, 3a, 3c and 3e; 3f also needs the
-- SQLite math functions, built into sqlite3 since 3.35).
-- Parts 1 and 2 answer the ticket. Part 3 holds the short supporting queries
-- behind the other figures quoted in the report.

-- PART 1: Create a SQL query that maps out the daily average users before and after the feature change

-- 1a. Daily active users for every calendar day in the data. Days without a
--     single login still appear with 0 (there are 9 of them, all before the
--     release), so the averages are per calendar day, not per "busy day".
--     The 7-day rolling average is the smoothed line on the graph.
WITH RECURSIVE calendar(day) AS (
  SELECT date(MIN(login_timestamp), 'unixepoch') FROM login_history
  UNION ALL
  SELECT date(day, '+1 day') FROM calendar
  WHERE day < (SELECT date(MAX(login_timestamp), 'unixepoch') FROM login_history)
),
daily AS (
  SELECT date(login_timestamp, 'unixepoch') AS day,
         COUNT(DISTINCT user_id)            AS daily_active_users,
         COUNT(*)                           AS logins
  FROM login_history
  GROUP BY day
)
SELECT c.day,
       CASE WHEN c.day < '2018-06-02' THEN 'before' ELSE 'after' END AS period,
       COALESCE(d.daily_active_users, 0) AS daily_active_users,
       COALESCE(d.logins, 0)             AS logins,
       ROUND(AVG(COALESCE(d.daily_active_users, 0)) OVER (
         ORDER BY c.day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS dau_7day_avg
FROM calendar c
LEFT JOIN daily d ON d.day = c.day
ORDER BY c.day;

-- 1b. The two headline numbers: average daily active users before and after
--     the release, with the number of days each average is based on.
WITH RECURSIVE calendar(day) AS (
  SELECT date(MIN(login_timestamp), 'unixepoch') FROM login_history
  UNION ALL
  SELECT date(day, '+1 day') FROM calendar
  WHERE day < (SELECT date(MAX(login_timestamp), 'unixepoch') FROM login_history)
),
daily AS (
  SELECT date(login_timestamp, 'unixepoch') AS day,
         COUNT(DISTINCT user_id)            AS daily_active_users
  FROM login_history
  GROUP BY day
),
per_day AS (
  SELECT c.day,
         CASE WHEN c.day < '2018-06-02' THEN 'before' ELSE 'after' END AS period,
         COALESCE(d.daily_active_users, 0) AS daily_active_users
  FROM calendar c
  LEFT JOIN daily d ON d.day = c.day
)
SELECT period,
       MIN(day)                          AS first_day,
       MAX(day)                          AS last_day,
       COUNT(*)                          AS days,
       ROUND(AVG(daily_active_users), 2) AS avg_daily_active_users,
       MIN(daily_active_users)           AS min_daily_active_users,
       MAX(daily_active_users)           AS max_daily_active_users
FROM per_day
GROUP BY period
ORDER BY first_day;

-- 1c. Month by month: monthly active users, average daily active users and
--     stickiness (average DAU divided by MAU). Shows that the release was a
--     step change in users, not a change in how often each user comes back.
--     The period is assigned per month, so June 2018 includes one pre-release
--     day (1 June). Stickiness is left NULL for partial months (the data
--     starts on 3 Feb 2018 and ends on 1 Feb 2019), where it is meaningless.
WITH RECURSIVE calendar(day) AS (
  SELECT date(MIN(login_timestamp), 'unixepoch') FROM login_history
  UNION ALL
  SELECT date(day, '+1 day') FROM calendar
  WHERE day < (SELECT date(MAX(login_timestamp), 'unixepoch') FROM login_history)
),
daily AS (
  SELECT date(login_timestamp, 'unixepoch') AS day,
         COUNT(DISTINCT user_id)            AS daily_active_users
  FROM login_history
  GROUP BY day
),
per_month AS (
  SELECT strftime('%Y-%m', c.day)                   AS month,
         COUNT(*)                                   AS days_in_data,
         AVG(COALESCE(d.daily_active_users, 0))     AS avg_daily_active_users
  FROM calendar c
  LEFT JOIN daily d ON d.day = c.day
  GROUP BY month
),
mau AS (
  SELECT strftime('%Y-%m', login_timestamp, 'unixepoch') AS month,
         COUNT(DISTINCT user_id)                           AS monthly_active_users,
         COUNT(*)                                          AS logins
  FROM login_history
  GROUP BY month
)
SELECT m.month,
       CASE WHEN m.month < '2018-06' THEN 'before' ELSE 'after' END AS period,
       m.days_in_data,
       u.monthly_active_users,
       u.logins,
       ROUND(m.avg_daily_active_users, 2)                        AS avg_daily_active_users,
       CASE WHEN m.days_in_data >= 28
            THEN ROUND(m.avg_daily_active_users / u.monthly_active_users, 2)
       END                                                       AS stickiness_dau_over_mau
FROM per_month m
JOIN mau u ON u.month = m.month
ORDER BY m.month;

-- PART 2: Create a SQL query that indicates the number of status changes by card

-- 2a. Status changes per card per day. The first history row of every card is
--     its creation (oldStatus IS NULL), which is not a status change, so those
--     rows are left out here and in the queries below.
SELECT date(h.timestamp, 'unixepoch') AS day,
       h.cardID                       AS card_id,
       c.name                         AS card_name,
       COUNT(*)                       AS status_changes,
       GROUP_CONCAT(h.oldStatus || ' -> ' || h.newStatus, ', ') AS changes
FROM (SELECT * FROM card_change_history ORDER BY timestamp, id) h  -- chronological, so the list reads in order
JOIN card c ON c.id = h.cardID
WHERE h.oldStatus IS NOT NULL
GROUP BY day, h.cardID
ORDER BY day, h.cardID;

-- 2b. Total status changes per card over the whole period, every card included
--     (38 cards have never left the backlog). Most changed cards first.
SELECT c.id     AS card_id,
       c.name   AS card_name,
       c.status AS current_status,
       COUNT(h.id) AS status_changes,
       SUM(CASE WHEN h.oldStatus = 'backlog'     AND h.newStatus = 'in-progress' THEN 1 ELSE 0 END) AS times_started,
       SUM(CASE WHEN h.oldStatus = 'in-progress' AND h.newStatus = 'complete'    THEN 1 ELSE 0 END) AS times_completed,
       SUM(CASE WHEN h.oldStatus = 'in-progress' AND h.newStatus = 'backlog'     THEN 1 ELSE 0 END) AS sent_back_to_backlog,
       SUM(CASE WHEN h.oldStatus = 'complete'    AND h.newStatus = 'in-progress' THEN 1 ELSE 0 END) AS reopened
FROM card c
LEFT JOIN card_change_history h ON h.cardID = c.id AND h.oldStatus IS NOT NULL
GROUP BY c.id
ORDER BY status_changes DESC, c.id;

-- 2c. Status changes per day across all cards, for every calendar day since
--     the release (days with no activity show 0). This is the daily graph.
WITH RECURSIVE calendar(day) AS (
  SELECT '2018-06-02'
  UNION ALL
  SELECT date(day, '+1 day') FROM calendar
  WHERE day < (SELECT date(MAX(timestamp), 'unixepoch') FROM card_change_history)
)
SELECT c.day,
       COUNT(h.id)              AS status_changes,
       COUNT(DISTINCT h.cardID) AS cards_changed,
       SUM(CASE WHEN h.newStatus = 'in-progress' THEN 1 ELSE 0 END) AS moved_to_in_progress,
       SUM(CASE WHEN h.newStatus = 'complete'    THEN 1 ELSE 0 END) AS moved_to_complete,
       SUM(CASE WHEN h.newStatus = 'backlog'     THEN 1 ELSE 0 END) AS moved_back_to_backlog,
       ROUND(AVG(COUNT(h.id)) OVER (
         ORDER BY c.day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS status_changes_7day_avg
FROM calendar c
LEFT JOIN card_change_history h
       ON date(h.timestamp, 'unixepoch') = c.day AND h.oldStatus IS NOT NULL
GROUP BY c.day
ORDER BY c.day;

-- 2d. Distribution: how many cards have had 0, 1, 2, ... status changes.
WITH per_card AS (
  SELECT c.id, COUNT(h.id) AS status_changes
  FROM card c
  LEFT JOIN card_change_history h ON h.cardID = c.id AND h.oldStatus IS NOT NULL
  GROUP BY c.id
)
SELECT status_changes, COUNT(*) AS cards
FROM per_card
GROUP BY status_changes
ORDER BY status_changes;

-- 2e. Where the cards stand today and how long they have been sitting there
--     (days since each card's last move, as of the last day in the data).
--     Context for the feature ideas: most "in progress" cards are stale.
WITH last_move AS (
  SELECT cardID, MAX(timestamp) AS last_timestamp
  FROM card_change_history
  GROUP BY cardID
),
as_of AS (
  -- midnight at the end of the last day in the data (2019-02-01), so that
  -- cards moved on that day get an age of 0, never a negative one
  SELECT CAST(strftime('%s', date(MAX(timestamp), 'unixepoch', '+1 day')) AS INTEGER) AS t
  FROM card_change_history
)
SELECT c.status,
       COUNT(*)                                                        AS cards,
       ROUND(AVG((as_of.t - l.last_timestamp) / 86400.0), 1)           AS avg_days_since_last_move,
       SUM(CASE WHEN as_of.t - l.last_timestamp > 14 * 86400 THEN 1 ELSE 0 END) AS untouched_over_14_days,
       SUM(CASE WHEN as_of.t - l.last_timestamp > 30 * 86400 THEN 1 ELSE 0 END) AS untouched_over_30_days
FROM card c
JOIN last_move l ON l.cardID = c.id
CROSS JOIN as_of
GROUP BY c.status
ORDER BY CASE c.status WHEN 'backlog' THEN 0 WHEN 'in-progress' THEN 1 ELSE 2 END;

-- PART 3: Supporting figures quoted in the report (beyond what the ticket asks for)

-- 3a. Gaps between a user's consecutive logins since the release: how often
--     people come back. Gaps over 14 days are the trigger for feature idea 1.
WITH logins AS (
  SELECT user_id, login_timestamp,
         LAG(login_timestamp) OVER (PARTITION BY user_id ORDER BY login_timestamp) AS previous_login
  FROM login_history
  WHERE date(login_timestamp, 'unixepoch') >= '2018-06-02'
),
gaps AS (
  SELECT (login_timestamp - previous_login) / 86400.0 AS gap_days
  FROM logins
  WHERE previous_login IS NOT NULL
)
SELECT COUNT(*)                                                   AS gaps,
       ROUND(AVG(gap_days), 2)                                    AS avg_gap_days,
       SUM(gap_days > 7)                                          AS gaps_over_7_days,
       SUM(gap_days > 14)                                         AS gaps_over_14_days,
       ROUND(AVG(CASE WHEN gap_days > 14 THEN gap_days END), 1)   AS avg_length_of_gaps_over_14_days,
       SUM(gap_days > 30)                                         AS gaps_over_30_days,
       ROUND(SUM(gap_days > 14) / 8.0, 1)                         AS gaps_over_14_days_per_month  -- eight months of data since the release
FROM gaps;

-- 3b. Where users stand on the last day of the data (1 Feb 2019): how many
--     have gone quiet, and how many were active in the final fortnight
--     (18 Jan to 1 Feb). "More than 14 days" means the last login was on
--     17 Jan or earlier.
WITH last_day AS (
  SELECT date(MAX(login_timestamp), 'unixepoch') AS d FROM login_history
),
last_login AS (
  SELECT user_id, date(MAX(login_timestamp), 'unixepoch') AS d
  FROM login_history
  WHERE date(login_timestamp, 'unixepoch') >= '2018-06-02'
  GROUP BY user_id
)
SELECT COUNT(*)                                     AS users_since_release,
       SUM(l.d < date(last_day.d, '-14 days'))      AS quiet_for_more_than_14_days,
       SUM(l.d < date(last_day.d, '-30 days'))      AS quiet_for_more_than_30_days,
       SUM(l.d >= date(last_day.d, '-14 days'))     AS active_in_final_fortnight
FROM last_login l
CROSS JOIN last_day;

-- 3c. When each user first logged in: did the user base keep growing after
--     the release month?
WITH first_login AS (
  SELECT user_id, date(MIN(login_timestamp), 'unixepoch') AS first_day
  FROM login_history
  GROUP BY user_id
)
SELECT strftime('%Y-%m', first_day)                              AS month,
       COUNT(*)                                                  AS new_users,
       SUM(COUNT(*)) OVER (ORDER BY strftime('%Y-%m', first_day)) AS users_so_far
FROM first_login
GROUP BY month
ORDER BY month;

-- 3d. Cycle time: days from a card's first move into "in progress" to its
--     first move into "complete", for cards that completed.
WITH spans AS (
  SELECT cardID,
         MIN(CASE WHEN newStatus = 'in-progress' THEN timestamp END) AS started,
         MIN(CASE WHEN newStatus = 'complete'    THEN timestamp END) AS completed
  FROM card_change_history
  GROUP BY cardID
),
durations AS (
  SELECT (completed - started) / 86400.0 AS days
  FROM spans
  WHERE started IS NOT NULL AND completed IS NOT NULL
)
SELECT COUNT(*)            AS completed_cards,
       ROUND(AVG(days), 1) AS avg_days_in_progress,
       SUM(days < 7)       AS under_a_week,
       SUM(days >= 60)     AS two_months_or_more
FROM durations;

-- 3e. How many status changes happened on a card that had sat untouched for
--     more than 14 days (the baseline for feature idea 2's metric).
WITH moves AS (
  SELECT id, cardID, oldStatus, timestamp,
         LAG(timestamp) OVER (PARTITION BY cardID ORDER BY timestamp, id) AS previous_touch
  FROM card_change_history
)
SELECT COUNT(*)                                                           AS status_changes,
       SUM(timestamp - previous_touch > 14 * 86400)                       AS after_more_than_14_days_untouched,
       ROUND(100.0 * SUM(timestamp - previous_touch > 14 * 86400) / COUNT(*), 0) AS share_percent
FROM moves
WHERE oldStatus IS NOT NULL;

-- 3f. Do busy login days coincide with busy board days? Pearson correlation
--     between daily logins and daily status changes since the release.
WITH RECURSIVE calendar(day) AS (
  SELECT '2018-06-02'
  UNION ALL
  SELECT date(day, '+1 day') FROM calendar
  WHERE day < (SELECT date(MAX(login_timestamp), 'unixepoch') FROM login_history)
),
daily AS (
  SELECT c.day,
         (SELECT COUNT(*) FROM login_history l
           WHERE date(l.login_timestamp, 'unixepoch') = c.day)                          AS logins,
         (SELECT COUNT(*) FROM card_change_history h
           WHERE date(h.timestamp, 'unixepoch') = c.day AND h.oldStatus IS NOT NULL)   AS changes
  FROM calendar c
)
SELECT COUNT(*) AS days,
       ROUND((COUNT(*) * SUM(logins * changes) - SUM(logins) * SUM(changes)) /
             (SQRT(COUNT(*) * SUM(logins * logins) - SUM(logins) * SUM(logins)) *
              SQRT(COUNT(*) * SUM(changes * changes) - SUM(changes) * SUM(changes))), 2)
         AS correlation_logins_vs_changes
FROM daily;
