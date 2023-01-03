-- REFERENCE:
-- https://8weeksqlchallenge.com/case-study-2/

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
--                         CLEAN THE DATA
-- ##--##--##--##--##--##--##--##--##--##--##--##--##--##--##--##--##--

-- Before moving onto doing some queries, let's clean the data in tables
-- 'customer_orders' and 'runner_orders'
UPDATE customer_orders
    SET exclusions = NULL
    WHERE exclusions = 'null' OR
        exclusions = '';

UPDATE customer_orders
    SET extras = NULL
    WHERE extras = 'null' OR
          extras = '';

UPDATE runner_orders
    SET distance = RTRIM(distance, 'km');

UPDATE runner_orders
    SET duration = RTRIM(duration, 'minutes');

UPDATE runner_orders
    SET distance = NULL
    WHERE distance = 'null';

UPDATE runner_orders
    SET duration = NULL
    WHERE duration = 'null';

UPDATE runner_orders
    SET pickup_time = NULL
    WHERE pickup_time = 'null';

UPDATE runner_orders
    SET cancellation = NULL
    WHERE cancellation = 'null' OR
          cancellation = '';

-- Let's rename the columns we modified in 'runner_orders' so as to
-- include the units
ALTER TABLE runner_orders
    RENAME COLUMN distance TO distance_km;

ALTER TABLE runner_orders
    RENAME COLUMN duration TO duration_min;

-- Let's create a new table where we separate the list of toppings
-- from pizza-recipes, so that each topping is in a seperate row
DROP TABLE IF EXISTS pizza_recipes_clean;
CREATE TABLE pizza_recipes_clean (
    pizza_id INTEGER,
    toppings TEXT,
    FOREIGN KEY(pizza_id)
        REFERENCES pizza_names(pizza_id)
        ON DELETE SET NULL
);

WITH RECURSIVE split(pizza_id, toppings, str) AS (
    SELECT pizza_id, '', toppings||',' FROM pizza_recipes
    UNION ALL SELECT
    pizza_id,
    substr(str, 0, INSTR(str, ',')),
    substr(str, INSTR(str, ',')+1)
    FROM split
    WHERE str != ''
)
INSERT INTO pizza_recipes_clean
SELECT pizza_id,
       TRIM(toppings) AS toppings
FROM split
WHERE toppings != ''
ORDER BY pizza_id;

-- ##--##--##--##--##--##--##--##--##--##--##--##--##--##--##--##--##--
--                            QUERIES
-- ##--##--##--##--##--##--##--##--##--##--##--##--##--##--##--##--##--

-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- A. Pizza metrics
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-- 1. How many pizzas were ordered?
SELECT COUNT(customer_orders.order_id) AS total_pizzas
FROM customer_orders;

-- 2. How many unique customer orders were made?
SELECT COUNT(DISTINCT customer_orders.order_id) AS unique_orders 
FROM customer_orders;

-- 3. How many successful orders were delivered by each runner?
SELECT runner_id,
       COUNT(runner_orders.order_id) AS successful_deliveries
FROM runner_orders
WHERE distance_km NOT NULL
GROUP BY runner_id;

-- 4. How many of each type of pizza was delivered?
SELECT customer_orders.pizza_id,
       pizza_names.pizza_name,
       COUNT(customer_orders.pizza_id) AS pizzas_delivered
FROM customer_orders
JOIN pizza_names
ON customer_orders.pizza_id = pizza_names.pizza_id
JOIN runner_orders
ON customer_orders.order_id = runner_orders.order_id
WHERE runner_orders.pickup_time NOT NULL
GROUP BY customer_orders.pizza_id;

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?
SELECT customer_orders.customer_id,
       pizza_names.pizza_name,
       COUNT(customer_orders.pizza_id) AS pizzas_ordered
FROM customer_orders
JOIN pizza_names
ON customer_orders.pizza_id = pizza_names.pizza_id
GROUP BY customer_orders.customer_id,
         customer_orders.pizza_id;

-- 6. What was the maximum number of pizzas delivered in a single order?
WITH pizza_count AS (
    SELECT runner_orders.order_id,
           COUNT(customer_orders.pizza_id) AS pizzas_delivered
    FROM customer_orders
    JOIN runner_orders
    ON customer_orders.order_id = runner_orders.order_id
    WHERE runner_orders.pickup_time NOT NULL
    GROUP BY customer_orders.order_id
)
SELECT MAX(pizzas_delivered) AS max_pizza_delivery
FROM pizza_count;

-- 7. For each customer, how many delivered pizzas had at least 1 change
--    and how many had no changes?
SELECT customer_orders.customer_id AS customer_id,
       COUNT(customer_orders.customer_id) AS total_pizzas_delivered,
       SUM(
            CASE
            WHEN customer_orders.exclusions IS NOT NULL OR
                customer_orders.extras IS NOT NULL THEN
                    1
            ELSE
                    0
            END
        ) AS at_least_one_change,
       SUM(
            CASE
            WHEN customer_orders.exclusions IS NULL AND
                customer_orders.extras IS NULL THEN
                    1
            ELSE
                    0
            END
        ) AS no_change
FROM customer_orders
JOIN runner_orders
ON customer_orders.order_id = runner_orders.order_id
WHERE runner_orders.pickup_time IS NOT NULL
GROUP BY customer_id;

-- 8. How many pizzas were delivered that had both exclusions and extras?
SELECT SUM(
            CASE
            WHEN customer_orders.exclusions IS NOT NULL AND
                 customer_orders.extras IS NOT NULL THEN
                    1
            ELSE
                    0
            END
        ) AS pizzas_with_exclusions_and_extras
FROM customer_orders
JOIN runner_orders
ON customer_orders.order_id = runner_orders.order_id
WHERE runner_orders.pickup_time IS NOT NULL;


-- 9. What was the total volume of pizzas ordered for each hour of the day?
SELECT strftime('%H', customer_orders.order_time) AS hour_of_day,
       COUNT(customer_orders.order_id) AS num_pizzas_ordered       
FROM customer_orders
GROUP BY strftime('%H', customer_orders.order_time)
ORDER BY strftime('%H', customer_orders.order_time);

-- 10. What was the volume of orders for each day of the week?
SELECT (strftime('%w', customer_orders.order_time) + 1) AS day_of_week,
       COUNT(customer_orders.order_id) AS num_pizzas_ordered       
FROM customer_orders
GROUP BY strftime('%w', customer_orders.order_time)
ORDER BY strftime('%w', customer_orders.order_time);


-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- B. Runner and customer experience
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-- 1. How many runners signed up for each 1 week period? (i.e. week starts
--    2021-01-01)
SELECT (strftime('%W', runners.registration_date) + 1) AS week_of_year,
       COUNT(runners.registration_date) AS num_registrations
FROM runners
GROUP BY strftime('%W', runners.registration_date);

-- 2. What was the average time in minutes it took for each runner to arrive
--    at the Pizza Runner HQ to pickup the order?
WITH time_min AS (
    SELECT ((strftime('%s', runner_orders.pickup_time) -
           strftime('%s', customer_orders.order_time)) / 60) AS time_diff_min
    FROM customer_orders
    JOIN runner_orders
    ON customer_orders.order_id = runner_orders.order_id
    WHERE runner_orders.pickup_time IS NOT NULL
    GROUP BY customer_orders.order_id
)
SELECT ROUND(AVG(time_min.time_diff_min)) AS avg_time_min
FROM time_min;

-- 3. Is there any relationship between the number of pizzas and how long the
--    order takes to prepare?
WITH pizza_tmp AS (
    SELECT customer_orders.order_id,
           COUNT(customer_orders.order_id) AS num_pizzas,
           ((strftime('%s', runner_orders.pickup_time) -
             strftime('%s', customer_orders.order_time)) / 60) AS time_diff_min
    FROM customer_orders
    JOIN runner_orders
    ON customer_orders.order_id = runner_orders.order_id
    WHERE runner_orders.pickup_time IS NOT NULL
    GROUP BY customer_orders.order_id
)
SELECT pizza_tmp.num_pizzas,
       AVG(pizza_tmp.time_diff_min) AS avg_time_prep
FROM pizza_tmp
GROUP BY pizza_tmp.num_pizzas;


-- 4. What was the average distance travelled for each customer?
WITH dist_customer AS (
    SELECT customer_orders.customer_id AS customer_id,
           runner_orders.distance_km AS distance
    FROM customer_orders
    JOIN runner_orders
    ON customer_orders.order_id = runner_orders.order_id
    WHERE runner_orders.distance_km IS NOT NULL
    GROUP BY customer_orders.order_id
)
SELECT dist_customer.customer_id,
       AVG(dist_customer.distance)
FROM dist_customer
GROUP BY dist_customer.customer_id;


-- 5. What was the difference between the longest and shortest delivery times
--    for all orders?
SELECT (MAX(runner_orders.duration_min) -
        MIN(runner_orders.duration_min)) AS diff_delivery_times_min
FROM runner_orders
WHERE runner_orders.duration_min IS NOT NULL;

-- 6. What was the average speed for each runner for each delivery and do you
--    notice any trend for these values?
SELECT runner_orders.order_id,
       runner_orders.runner_id,
       COUNT(customer_orders.order_id) AS num_pizzas,
       runner_orders.distance_km,
       ROUND(runner_orders.duration_min / 60.0, 2) AS duration_hr,
       ROUND(60.0 * runner_orders.distance_km /
             runner_orders.duration_min, 1) AS avg_speed_km_h
FROM runner_orders
JOIN customer_orders
ON runner_orders.order_id = customer_orders.order_id
WHERE runner_orders.distance_km IS NOT NULL
GROUP BY runner_orders.order_id
ORDER BY runner_orders.order_id;

-- 7. What is the successful delivery percentage for each runner?
WITH eff_runner AS (
    SELECT runner_orders.runner_id AS runner_id,
        CASE
        WHEN runner_orders.pickup_time IS NOT NULL THEN
                1
        ELSE
                0
        END check_pickup
    FROM runner_orders
)
SELECT eff_runner.runner_id,
       ROUND(100 * SUM(eff_runner.check_pickup) /
             COUNT(eff_runner.runner_id), 1) AS delivery_perc
FROM eff_runner
GROUP BY eff_runner.runner_id;

-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- C. Ingredient optimization
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-- 1. What are the standard ingredients for each pizza?
WITH std_ing AS (
    WITH split_table AS (
        -- Split toppings list elements on separate rows using recursion
        WITH RECURSIVE split(pizza_id, toppings, str) AS (
            SELECT pizza_id, '', toppings||',' FROM pizza_recipes
            UNION ALL SELECT
            pizza_id,
            substr(str, 0, INSTR(str, ',')),
            substr(str, INSTR(str, ',')+1)
            FROM split
            WHERE str != ''
        )
        SELECT pizza_id,
            TRIM(toppings) AS split_toppings
        FROM split
        WHERE toppings != ''
        ORDER BY pizza_id
    )
    SELECT split_table.pizza_id AS pizza_id,
        GROUP_CONCAT(pizza_toppings.topping_name, ', ') AS std_ingredients
    FROM split_table
    JOIN pizza_toppings
    ON split_table.split_toppings = pizza_toppings.topping_id
    GROUP BY split_table.pizza_id
)
SELECT std_ing.pizza_id,
       pizza_names.pizza_name,
       std_ing.std_ingredients
FROM std_ing
JOIN pizza_names
ON std_ing.pizza_id = pizza_names.pizza_id
ORDER BY std_ing.pizza_id;

-- 2. What was the most commonly added extra?
WITH split_table AS (
    -- Split extras list elements on separate rows using recursion
    WITH RECURSIVE split(order_id, extras, str) AS (
        SELECT order_id, '', extras||',' FROM customer_orders
        UNION ALL SELECT
        order_id,
        substr(str, 0, INSTR(str, ',')),
        substr(str, INSTR(str, ',')+1)
        FROM split
        WHERE str != ''
    )
    SELECT order_id,
           TRIM(extras) AS split_extras
    FROM split
    WHERE extras != ''
    ORDER BY order_id
)
SELECT split_table.split_extras AS extras,
       pizza_toppings.topping_name,
       COUNT(split_table.split_extras) AS num_times_ordered
FROM split_table
JOIN pizza_toppings
ON split_table.split_extras = pizza_toppings.topping_id
GROUP BY split_table.split_extras;

-- 3. What was the most common exclusion?
WITH split_table AS (
    -- Split exclusions list elements on separate rows using recursion
    WITH RECURSIVE split(order_id, exclusions, str) AS (
        SELECT order_id, '', exclusions||',' FROM customer_orders
        UNION ALL SELECT
        order_id,
        substr(str, 0, INSTR(str, ',')),
        substr(str, INSTR(str, ',')+1)
        FROM split
        WHERE str != ''
    )
    SELECT order_id,
           TRIM(exclusions) AS split_exclusions
    FROM split
    WHERE exclusions != ''
    ORDER BY order_id
)
SELECT split_table.split_exclusions AS exclusions,
       pizza_toppings.topping_name,
       COUNT(split_table.split_exclusions) AS num_times_removed
FROM split_table
JOIN pizza_toppings
ON split_table.split_exclusions = pizza_toppings.topping_id
GROUP BY split_table.split_exclusions
ORDER BY num_times_removed DESC;

-- 4. Generate an order item for each record in the customers_orders table in
--    the format of one of the following:
--      * Meat Lovers
--      * Meat Lovers - Exclude Beef
--      * Meat Lovers - Extra Bacon
--      * Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers


-- 5. Generate an alphabetically ordered comma separated ingredient list for each
--    pizza order from the customer_orders table and add a 2x in front of any
--    relevant ingredients. For example:
--      * "Meat Lovers: 2xBacon, Beef, ... , Salami"


-- 6. What is the total quantity of each ingredient used in all delivered pizzas
--    sorted by most frequent first?

-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- D. Pricing and ratings
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no
--    charges for changes - how much money has Pizza Runner made so far if there are
--    no delivery fees?

-- Modify pizza_names table so we include the price of each pizza
ALTER TABLE pizza_names
ADD COLUMN price float;

UPDATE pizza_names
    SET price = 12.0
    WHERE pizza_name = 'Meatlovers';

UPDATE pizza_names
    SET price = 10.0
    WHERE pizza_name = 'Vegetarian';

-- Now let's compute the total amount $ made in sales
WITH total_money AS (
    SELECT customer_orders.pizza_id,
           (COUNT(customer_orders.pizza_id) *
            pizza_names.price) AS total
    FROM customer_orders
    JOIN pizza_names
    ON customer_orders.pizza_id = pizza_names.pizza_id
    GROUP BY customer_orders.pizza_id
)
SELECT SUM(total_money.total)
FROM total_money;


-- 2. What if there was an additional $1 charge for any pizza extras?
--      * Add cheese is $1 extra
WITH split_table AS (
    -- Split extras list elements on separate rows using recursion
    WITH RECURSIVE split(order_id, extras, str) AS (
        SELECT order_id, '', extras||',' FROM customer_orders
        UNION ALL SELECT
        order_id,
        substr(str, 0, INSTR(str, ',')),
        substr(str, INSTR(str, ',')+1)
        FROM split
        WHERE str != ''
    )
    SELECT order_id,
        COUNT(TRIM(extras)) AS total_extras
    FROM split
    WHERE extras != ''
    GROUP BY order_id
    ORDER BY order_id
)
SELECT customer_orders.order_id As order_id,
    customer_orders.pizza_id AS pizza_id,
    split_table.total_extras AS extras
FROM customer_orders
LEFT JOIN split_table
ON customer_orders.order_id = split_table.order_id
ORDER BY customer_orders.order_id;

-- 3. The Pizza Runner team now wants to add an additional ratings system that allows
--    customers to rate their runner, how would you design an additional table for this
--    new dataset - generate a schema for this new table and insert your own data for
--    ratings for each successful customer order between 1 to 5.
-- 4. Using your newly generated table - can you join all of the information together
--    to form a table which has the following information for successful deliveries?
--      * customer_id
--      * order_id
--      * runner_id
--      * rating
--      * order_time
--      *pickup_time
--      * Time between order and pickup
--      * Delivery duration
--      * Average speed
--      * Total number of pizzas
-- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost
--    for extras and each runner is paid $0.30 per kilometre traveled - how much money
--    does Pizza Runner have left over after these deliveries?