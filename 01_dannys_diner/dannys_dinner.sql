-- REFERENCE:
-- https://8weeksqlchallenge.com/case-study-1/

-- Make sure this option is ON so when we delete a foreign key, the
-- attribute of the rows associated with the foreign key is replaced
-- by NULL, or the rows associated with the foreign key are deleted
-- (based on 'ON DELETE' setting)
PRAGMA foreign_keys = ON;

-- Activate headers so output shows column headers
-- (no semi-colon required)
.headers on

-- The next mode allows to print output more nicely
-- (no semi-colon required)
.mode column

-- ####################################################################
--                            QUERIES
-- ####################################################################

-- 1. What is the total amount each customer spent at the restaurant?
SELECT s.customer_id,
       SUM(m.price) AS total_spent
    FROM sales as s
        JOIN menu as m
        ON s.product_id = m.product_id
GROUP BY
s.customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT s.customer_id,
       COUNT(DISTINCT s.order_date) AS num_visits
    FROM sales AS s
GROUP BY 
s.customer_id;

-- 3. What was the first item from the menu purchased by each customer?
WITH ranked_orders AS (
    SELECT s.customer_id AS customer_id,
           m.product_name AS product_name,
           s.order_date AS order_date,
           DENSE_RANK() OVER (
                PARTITION BY s.customer_id
                ORDER BY s.order_date
            ) AS rank
        FROM sales AS s
            JOIN menu AS m
            ON s.product_id = m.product_id
    )
SELECT DISTINCT ranked_orders.customer_id,
                ranked_orders.product_name AS first_purchase
FROM ranked_orders
WHERE rank = 1;

-- 4. What is the most purchased item on the menu and how many times was it
-- purchased by all customers?
SELECT m.product_name,
       COUNT(s.product_id) AS times_purchased
    FROM sales AS s
        JOIN menu AS m
        ON s.product_id = m.product_id
GROUP BY s.product_id
ORDER BY times_purchased DESC
LIMIT 1;

-- 5. Which item was the most popular for each customer?
WITH most_popular AS (
    SELECT s.customer_id AS customer_id,
           m.product_name AS product_name,
           COUNT(s.product_id) AS times_purchased,
           DENSE_RANK() OVER (
                PARTITION BY s.customer_id
                ORDER BY COUNT(s.product_id) DESC
            ) rank
        FROM sales AS s
            JOIN menu AS m
            ON s.product_id = m.product_id
    GROUP BY s.product_id,
             s.customer_id
    )
SELECT most_popular.customer_id,
       most_popular.product_name,
       most_popular.times_purchased
    FROM most_popular
WHERE rank = 1;

-- 6. Which item was purchased first by the customer after they became
-- a member?
WITH first_purchase_as_member AS (
    SELECT s.customer_id AS customer_id,
           m.product_name AS product_name,
           s.order_date AS order_date,
           mem.join_date AS join_date,
           DENSE_RANK() OVER(
                PARTITION BY s.customer_id
                ORDER BY s.order_date
            ) rank
        FROM sales AS s
            JOIN menu AS m
            ON s.product_id = m.product_id
            JOIN members AS mem
            ON s.customer_id = mem.customer_id
        WHERE s.order_date >= mem.join_date
    )
SELECT first_purchase_as_member.customer_id,
       first_purchase_as_member.product_name,
       first_purchase_as_member.order_date
    FROM first_purchase_as_member
WHERE rank = 1;

-- 7. Which item was purchased just before the customer became a member?
WITH last_purchase_before_mem AS (
    SELECT s.customer_id AS customer_id,
           m.product_name AS product_name,
           s.order_date AS order_date,
           mem.join_date AS join_date,
           DENSE_RANK() OVER(
                PARTITION BY s.customer_id
                ORDER BY s.order_date DESC
            ) rank
        FROM sales AS s
            JOIN menu AS m
            ON s.product_id = m.product_id
            JOIN members AS mem
            ON s.customer_id = mem.customer_id
        WHERE s.order_date < mem.join_date
    )
SELECT last_purchase_before_mem.customer_id,
       last_purchase_before_mem.product_name,
       last_purchase_before_mem.order_date
    FROM last_purchase_before_mem
WHERE rank = 1;

-- 8. What is the total items and amount spent for each member before they
-- became a member?
SELECT s.customer_id,
       COUNT(s.product_id) AS total_items,
       SUM(m.price) AS total_spent
    FROM sales AS s
        JOIN menu AS m
        ON s.product_id = m.product_id
        JOIN members AS mem
        ON s.customer_id = mem.customer_id
WHERE s.order_date < mem.join_date
GROUP BY s.customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points
-- multiplier, how many points would each customer have?
WITH points_tab AS (
    SELECT s.customer_id AS customer_id,
            CASE
                WHEN m.product_name = 'sushi' THEN
                    m.price * 20
                ELSE
                    m.price * 10
                END AS points
        FROM sales AS s
            JOIN menu AS m
            ON s.product_id = m.product_id
)
SELECT points_tab.customer_id,
       SUM(points_tab.points)
FROM points_tab
GROUP BY points_tab.customer_id;

-- 10. In the first week after a customer joins the program (including
-- their join date) they earn 2x points on all items, not just sushi.
-- How many points do customer A and B have at the end of January?
WITH points_members AS (
    SELECT s.customer_id AS customer_id,
            s.order_date AS order_date,
            CASE
                WHEN s.order_date >= mem.join_date
                    AND s.order_date < DATE(mem.join_date, '+7 days') THEN
                        m.price * 20
                WHEN m.product_name = 'sushi' THEN
                    m.price * 20
                ELSE
                    m.price * 10
                END AS points
        FROM sales AS s
            JOIN menu AS m
            ON s.product_id = m.product_id
            JOIN members AS mem
            ON s.customer_id = mem.customer_id
)
SELECT points_members.customer_id,
       SUM(points_members.points) AS points_Jan
FROM points_members
WHERE points_members.order_date >= '2021-01-01'
        AND points_members.order_date < '2021-02-01'
GROUP BY points_members.customer_id;

-- Bonus question 1: Join All The Things
-- Recreate table using available data
SELECT s.customer_id,
       s.order_date,
       m.product_name,
       m.price,
       CASE
        WHEN s.order_date < mem.join_date THEN
            'N'
        WHEN s.order_date >= mem.join_date THEN
            'Y'
        ELSE
            'N'
        END AS member
    FROM sales AS s
        LEFT JOIN menu AS m
        ON s.product_id = m.product_id
        LEFT JOIN members AS mem
        ON s.customer_id = mem.customer_id;

-- Bonus question 2: Rank All The Things
-- Danny also requires further information about the ranking of customer
-- products, but he purposely does not need the ranking for non-member purchases
-- so he expects null ranking values for the records when customers are not yet
-- part of the loyalty program
WITH summary_tab AS (
    SELECT s.customer_id,
        s.order_date,
        m.product_name,
        m.price,
        CASE
            WHEN s.order_date < mem.join_date THEN
                'N'
            WHEN s.order_date >= mem.join_date THEN
                'Y'
            ELSE
                'N'
            END AS member
        FROM sales AS s
            LEFT JOIN menu AS m
            ON s.product_id = m.product_id
            LEFT JOIN members AS mem
            ON s.customer_id = mem.customer_id
)
SELECT *,
    CASE
        WHEN summary_tab.member = 'N' THEN
            NULL
        ELSE
            DENSE_RANK() OVER(
                        PARTITION BY summary_tab.customer_id, summary_tab.member
                        ORDER BY summary_tab.order_date
                    )
        END AS ranking
    FROM summary_tab;