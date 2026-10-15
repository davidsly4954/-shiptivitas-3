-- TYPE YOUR SQL QUERY BELOW
--
-- Shiptivity analytics, task 3.
-- All timestamps in the database are Unix epoch seconds, so
-- date(<column>, 'unixepoch') turns them into calendar days.
-- The Kanban board was released on 2018-06-02: "before" is every day up to
-- 2018-06-01, "after" is 2018-06-02 onwards.
-- Each statement below runs on its own in sqlite3 (SQLite 3.25 or newer, for
-- the window function in query 1a).

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
       ROUND(m.avg_daily_active_users / u.monthly_active_users, 2) AS stickiness_dau_over_mau
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
FROM card_change_history h
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
  -- midnight at the start of the last day in the data (2019-02-01)
  SELECT strftime('%s', date(MAX(timestamp), 'unixepoch')) AS t FROM card_change_history
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
