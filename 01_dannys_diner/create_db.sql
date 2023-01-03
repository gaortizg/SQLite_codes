-- REFERENCE:
-- https://8weeksqlchallenge.com/case-study-1/

-- After creating the tables, run the following command to create
-- *.db file
-- sqlite3 dannys_dinner.db < create_db.sql

-- ####################################################################
--                          CREATE TABLES
-- ####################################################################

-- Create table 'menu'
CREATE TABLE IF NOT EXISTS menu(
    'product_id' INTEGER PRIMARY KEY,
    'product_name' VARCHAR(10),
    'price' INT NOT NULL
);

-- Create table 'members'
CREATE TABLE IF NOT EXISTS members(
    'customer_id' VARCHAR(1) PRIMARY KEY,
    'join_date' DATE NOT NULL
);

-- Create table 'sales'
CREATE TABLE IF NOT EXISTS sales(
    'customer_id' VARCHAR(1),
    'order_date' DATE,
    'product_id' INTEGER,
    FOREIGN KEY(customer_id)
        REFERENCES members(customer_id)
        ON DELETE SET NULL
    FOREIGN KEY(product_id)
        REFERENCES menu(product_id)
        ON DELETE SET NULL
);


-- ####################################################################
--                        ADD DATA INTO TABLES
-- ####################################################################

-- Add data into 'menu' table
INSERT INTO menu
    ('product_id', 'product_name', 'price')
VALUES
    (1, 'sushi', 10),
    (2, 'curry', 15),
    (3, 'ramen', 12);

-- Add data into 'members' table
INSERT INTO members
    ('customer_id', 'join_date')
VALUES
    ('A', '2021-01-07'),
    ('B', '2021-01-09');

-- Add data into 'sales' table
INSERT INTO sales
    ('customer_id', 'order_date', 'product_id')
VALUES
    ('A', '2021-01-01', 1),
    ('A', '2021-01-01', 2),
    ('A', '2021-01-07', 2),
    ('A', '2021-01-10', 3),
    ('A', '2021-01-11', 3),
    ('A', '2021-01-11', 3),
    ('B', '2021-01-01', 2),
    ('B', '2021-01-02', 2),
    ('B', '2021-01-04', 1),
    ('B', '2021-01-11', 1),
    ('B', '2021-01-16', 3),
    ('B', '2021-02-01', 3),
    ('C', '2021-01-01', 3),
    ('C', '2021-01-01', 3),
    ('C', '2021-01-07', 3);