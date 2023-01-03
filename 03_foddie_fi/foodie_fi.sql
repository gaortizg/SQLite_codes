-- REFERENCE:
-- https://8weeksqlchallenge.com/case-study-3/

-- Make sure this option is ON so when we delete a foreign key, the
-- attribute of the rows associated with the foreign key is replaced
-- by NULL, or the rows associated with the foreign key are deleted
-- (based on 'ON DELETE' setting)
PRAGMA foreign_keys = ON;

-- Activate headers so output shows column headers
-- (no semi-colon required)
.headers ON

-- The next mode allows to print output more nicely
-- (no semi-colon required)
.mode column

-- ##--##--##--##--##--##--##--##--##--##--##--##--##--##--##--##--##--
--                            QUERIES
-- ##--##--##--##--##--##--##--##--##--##--##--##--##--##--##--##--##--

-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- A. Customer Journey
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-- Based off the 8 sample customers provided in the sample below from the
-- 'subscriptions' table, write a brief description about each customer’s
-- onboarding journey. Try to keep it as short as possible

-- Sample 'subscriptions' table
SELECT subscriptions.customer_id,
       subscriptions.plan_id,
       plans.plan_name,
       subscriptions.start_date
FROM subscriptions
JOIN plans
ON subscriptions.plan_id = plans.plan_id
WHERE subscriptions.customer_id IN (1, 2, 11, 13, 15, 16, 18, 19);

-- From the sample it can be seen that all of the customers start with
-- the 'Trial' period. All the customers use up the trial period, and
-- after 7 days, most of them convert their initial plan into a monthly
-- one (either basic or pro), which highlights the fact that these people
-- enjoy the content.
-- It can be seen that 2 clients (25% of the sample) decided to cancel
-- their subscription, while the remaining 75% of the customers have either
-- upgraded to a monthly or annual plan. Most of the customers who upgraded
-- their plans started with a monthly subscription, and later on (2-3
-- months after initial upgrade), decided to upgrade again to a higher
-- subscription level


-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- B. Data analysis questions
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-- 1. How many customers has Foodie-Fi ever had?
CREATE TEMPORARY TABLE total_customers AS
    SELECT COUNT(DISTINCT subscriptions.customer_id)
    FROM subscriptions;

SELECT * FROM total_customers;

-- 2. What is the monthly distribution of trial plan start_date values for
--    our dataset - use the start of the month as the group by value
SELECT strftime("%m", subscriptions.start_date) AS month,
       COUNT(subscriptions.plan_id) AS monthly_trials
FROM subscriptions
WHERE subscriptions.plan_id = 0
GROUP BY strftime("%m", subscriptions.start_date);

-- 3.What plan start_date values occur after the year 2020 for our dataset?
--   Show the breakdown by count of events for each plan_name
SELECT subscriptions.plan_id,
       plans.plan_name,
       COUNT(subscriptions.plan_id) AS subs_after_2020
FROM subscriptions
JOIN plans
ON subscriptions.plan_id = plans.plan_id
WHERE subscriptions.start_date > '2020-12-31'
GROUP BY subscriptions.plan_id;

-- 4. What is the customer count and percentage of customers who have churned
--    rounded to 1 decimal place?
WITH num_churns AS (
    SELECT SUM(CASE subscriptions.plan_id
                    WHEN 4 THEN
                        1
                    ELSE
                        0
                    END) AS churns
    FROM subscriptions
)
SELECT num_churns.churns AS num_churns,
       ROUND(100.0 * num_churns.churns / (SELECT * FROM total_customers), 1) AS perc_churns
FROM num_churns;

-- 5. How many customers have churned straight after their initial free trial.
--    What percentage is this rounded to the nearest whole number?
WITH next_plan_cte AS (
    SELECT *,
           LEAD(subscriptions.plan_id, 1)
            OVER(PARTITION BY subscriptions.customer_id
                ORDER BY   subscriptions.start_date) AS next_plan
    FROM subscriptions
),
churners AS (
    SELECT *
    FROM next_plan_cte
    WHERE next_plan = 4 AND plan_id = 0
)
SELECT COUNT(churners.customer_id) AS num_churn_straight_after_trial,
       ROUND(100.0 * COUNT(churners.customer_id) / 
                    (SELECT COUNT(DISTINCT subscriptions.customer_id)
                     FROM subscriptions), 2) AS churn_pct
FROM churners;

-- 6. What is the number and percentage of customer plans after their initial
--    free trial?
SELECT plans.plan_name,
       count(subscriptions.customer_id) AS num_costumer,
       ROUND(100.0 * COUNT(DISTINCT subscriptions.customer_id) / 
                      (SELECT COUNT(DISTINCT subscriptions.customer_id)
                        FROM subscriptions), 2) AS customer_pct
FROM subscriptions
JOIN plans
ON subscriptions.plan_id = plans.plan_id
WHERE plans.plan_name != 'trial'
GROUP BY plans.plan_name
ORDER BY plans.plan_id;

-- 7. What is the customer count and percentage breakdown of all 5 plan_name
--    values at 2020-12-31?
WITH latest_plan_cte AS (
    SELECT *,
           ROW_NUMBER() OVER(PARTITION BY subscriptions.customer_id
                             ORDER BY subscriptions.start_date DESC) AS latest_plan
    FROM subscriptions
    JOIN plans
    ON subscriptions.plan_id = plans.plan_id
    WHERE subscriptions.start_date <= '2020-12-31'
)
SELECT latest_plan_cte.plan_id,
       latest_plan_cte.plan_name,
       COUNT(latest_plan_cte.customer_id) AS num_customers,
       ROUND(100.0 * COUNT(latest_plan_cte.customer_id) / 
                     (SELECT COUNT(DISTINCT subscriptions.customer_id) FROM subscriptions), 2) AS pct_breakdown
FROM latest_plan_cte
WHERE latest_plan_cte.latest_plan = 1
GROUP BY latest_plan_cte.plan_id
ORDER BY latest_plan_cte.plan_id;

-- 8. How many customers have upgraded to an annual plan in 2020?
SELECT subscriptions.plan_id,
       COUNT(DISTINCT subscriptions.customer_id) AS num_annual_plan
FROM subscriptions
WHERE (subscriptions.plan_id = 3) AND
      (CAST(strftime("%Y", subscriptions.start_date) AS INTEGER) = 2020);

-- 9. How many days on average does it take for a customer to an annual plan
--    from the day they join Foodie-Fi?
WITH trial_plan_cte AS (
    SELECT *
    FROM subscriptions
    JOIN plans
    ON subscriptions.plan_id = plans.plan_id
    WHERE subscriptions.plan_id = 0
),
annual_plan_cte AS (
    SELECT *
    FROM subscriptions
    JOIN plans
    ON subscriptions.plan_id = plans.plan_id
    WHERE subscriptions.plan_id = 3
)
SELECT ROUND(AVG(CAST((JulianDay(annual_plan_cte.start_date) - 
                       JulianDay(trial_plan_cte.start_date)) AS INTEGER)), 2) AS avg_conversion_days
FROM trial_plan_cte
INNER JOIN annual_plan_cte
ON trial_plan_cte.customer_id = annual_plan_cte.customer_id;

-- 10. Can you further breakdown this average value into 30 day periods
--     (i.e. 0-30 days, 31-60 days etc)
WITH next_plan_cte AS (
    SELECT *,
           LEAD(subscriptions.start_date, 1) OVER(PARTITION BY subscriptions.customer_id
                                                  ORDER BY subscriptions.start_date) AS next_plan_start_date,
           LEAD(subscriptions.plan_id, 1) OVER(PARTITION BY subscriptions.customer_id
                                               ORDER BY subscriptions.start_date) AS next_plan
    FROM subscriptions
),
window_details AS (
    SELECT *,
           CAST((JulianDay(next_plan_cte.next_plan_start_date) - 
                 JulianDay(next_plan_cte.start_date)) AS INTEGER) AS total_days,
           ROUND(CAST((JulianDay(next_plan_cte.next_plan_start_date) - 
                       JulianDay(next_plan_cte.start_date)) AS INTEGER) / 30, 2) AS window_30_days
    FROM next_plan_cte
    WHERE next_plan_cte.next_plan = 3
)
SELECT window_details.window_30_days,
       COUNT(window_details.customer_id) AS customer_count
FROM window_details
GROUP BY window_details.window_30_days
ORDER BY window_details.window_30_days;


-- 11. How many customers downgraded from a pro monthly to a basic monthly plan
--     in 2020?
WITH next_plan_cte AS (
    SELECT *,
           LEAD(subscriptions.plan_id, 1) OVER(PARTITION BY subscriptions.customer_id
                                               ORDER BY subscriptions.start_date) AS next_plan
    FROM subscriptions
)
SELECT COUNT(next_plan_cte.customer_id) AS downgrade_account
FROM next_plan_cte
WHERE next_plan_cte.plan_id = 2 AND
      next_plan_cte.next_plan = 1 AND
      next_plan_cte.start_date <= '2020-12-31';