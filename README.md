<p align="center">
<a href="https://www.insidesherpa.com/virtual-internships/prototype/oRMogWRHeewqHzA7u/College%20Students%3A%20Learn%20how%20to%20work%20at%20a%20YC%20startup">
<img src="https://s3-ap-southeast-2.amazonaws.com/insidesherpa-assets/yc/yc-blade.png"></a>
<br><br>
  <a href="https://www.insidesherpa.com/virtual-internships/prototype/oRMogWRHeewqHzA7u/College%20Students%3A%20Learn%20how%20to%20work%20at%20a%20YC%20startup">
  <img src="https://s3-ap-southeast-2.amazonaws.com/insidesherpa-assets/yc/workatastartup_logo_orange-c2a27f6374f9395166ee9906e2e0873af835b3c6132ae6aa0543582298567041.svg"></a>
</p>

<p align="center"> 
	<b><a href="#task">Task Overview</a></b>
	|
	<b><a href="#installation">Installation Instructions</a></b>
	| 
	<b><a href="https://www.insidesherpa.com/modules/oRMogWRHeewqHzA7u/nEg96uYWs9oh5Jrbc" target="_blank">Link to Module 3</a></b>		
	| 
	<b><a href="https://www.insidesherpa.com/virtual-internships/prototype/oRMogWRHeewqHzA7u/College%20Students%3A%20Learn%20how%20to%20work%20at%20a%20YC%20startup">Link to Y Combinator Program</a></b>
</p>

<h1> Introduction</h1> 
<b> College Students: Learn how to work at a Y Combinator startup </b>
<p>Train online for the skills Y Combinator startups are looking for. One of the official ways to get recruited into a Y Combinator startup.</p>

<h2 id="task"> Module 3 Task Overview </h2>
<p>Analytics - Analyse the latest feature releases</p>
<p> <b>Aim:</b>Create insights and ideas backed by data</p>

<p>Please clone this repository to start the task. Edit file <b>answer.sql</b> with your SQL query to produce meaningful data</p>

<p>On 2018-06-02, we released the Kanban Board on Shiptivity app. It has a major impact on our stats and we want to iterate on it</p>

<b>Purpose</b>
<p>We want to generate a few key ideas to move us on one of our core metrics: daily active users.</p>

<b>Acceptance Criteria</b>
<ol>
<li>This task is complete when we have a graph created that maps out the daily average users before and after the feature change</li>
<li>This task is complete when we have a graph of the number of status changes by card</li>
<li>This task is complete when you upload the SQL queries that can generate this information</li>
<li>This task is complete when we have three actionable ideas stated in the format below:
<ol>
	<li>Hypothesis </li>
	<li>Expected Impact </li>
	<li>What the feature is (a quick explanation of the feature)</li>
</ol>
</li>
<li>Sketches and flows of these features are optional but helpful (wireframe quality is enough)</li>
</ol>

<h2 id="installation" >Installation</h2>

<p>
You will need to have <b>sqlite3</b> installed

If you do not have sqlite3 installed, follow this <a href="https://www.tutorialspoint.com/sqlite/sqlite_installation.htm">guide</a> on how to install sqlite3.

On your terminal, try running <code>sqlite3 ./shiptivity.db</code>.

You can start running SQL command on the terminal.
</p>
<p>Tips: try <code>.schema</code> to see a list of CREATE TABLE commands for the db.</p>

<p> If you want to go back to tthe original state of db, there is a <code>dump</code> called shiptivity.dump that you can run to restore the data to its unchanged state.

## Submission (task 3)

- `answer.sql` holds the queries. Part 1 (1a to 1c): daily active users for every calendar day with a before/after flag and a 7-day average, the two period averages, and a month-by-month view with stickiness. Part 2 (2a to 2e): status changes per card per day, totals per card, the daily series since the release, the distribution of changes per card, and how long cards have sat in each status.
- `analytics-report.html` is a self-contained report with the two graphs, table views, the SQL, and three feature ideas with wireframes. Open it in any browser.
- Run the queries with `sqlite3 shiptivity.db < answer.sql` (SQLite 3.25 or newer, for the window functions). The database is not modified by any of them.
- `graphs/` holds each graph as a standalone image, in SVG (exact) and JPG (screenshot) form: daily active users, status changes per day, status changes per card, and cards by number of status changes.
- `feature-ideas.pdf` (and `feature-ideas.md`) is the three-ideas document on its own, with the wireframes, for the Forage upload. The sketches are also in `graphs/wireframe-1..3.svg`.
