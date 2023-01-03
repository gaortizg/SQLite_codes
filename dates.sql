-- Write an SQL to find buisness days between 'create_date' and
-- 'resolved_date' by excluding weekends and public holidays

-- 2022-08-01 -> Monday, 2022-08-03 -> Wednesday
-- 2022-08-01 -> Monday, 2022-08-12 -> Friday
-- 2022-08-01 -> Monday, 2022-08-16 -> Tuesday

-- Create 'tickets' table
DROP TABLE IF EXISTS tickets;
CREATE TABLE tickets (
    ticket_id INTEGER PRIMARY KEY,
    create_date DATE,
    resolved_date DATE
);

-- create 'holidays' table
DROP TABLE IF EXISTS holidays;
CREATE TABLE holidays (
    holiday_date DATE,
    reason VARCHAR(20)
);

-- Add data into 'tickets' table
INSERT INTO tickets
    (ticket_id, create_date, resolved_date)
VALUES
    (1, "2022-08-01", "2022-08-03"),
    (2, "2022-08-01", "2022-08-12"),
    (3, "2022-08-01", "2022-08-16");

-- Add data into 'holiday' table
INSERT INTO holidays
    (holiday_date, reason)
VALUES
    ("2022-08-11", "holiday1"),
    ("2022-08-15", "holiday2");

-- Check table 'tickets'
SELECT * FROM tickets;

-- Calculate actual day difference
SELECT CAST((JulianDay(tickets.resolved_date) - 
             JulianDay(tickets.create_date)) AS INTEGER) AS actual_day_diff
FROM tickets;

-- Compute number of weekends between dates
SELECT (CAST(strftime("%W", tickets.resolved_date) AS INTEGER) -
        CAST(strftime("%W", tickets.create_date) AS INTEGER)) AS num_weekends
FROM tickets;

-- Now we can subtract num_weekends from actual_day_diff
SELECT (CAST((JulianDay(tickets.resolved_date) - 
             JulianDay(tickets.create_date)) AS INTEGER)) - 
       2 * (CAST(strftime("%W", tickets.resolved_date) AS INTEGER) -
            CAST(strftime("%W", tickets.create_date) AS INTEGER)) AS business_days
FROM tickets;

-- Let's join 'tickets' and 'holidays' tables
SELECT *
FROM tickets
LEFT JOIN holidays
ON holidays.holiday_date BETWEEN tickets.create_date AND tickets.resolved_date;

-- Now let's select data we need from this new table
SELECT tickets.ticket_id,
       tickets.create_date,
       tickets.resolved_date,
       COUNT(holidays.holiday_date) AS num_holidays
FROM tickets
LEFT JOIN holidays
ON holidays.holiday_date BETWEEN tickets.create_date AND tickets.resolved_date
GROUP BY tickets.ticket_id;

-- Now we can compute actual business days (without weekends and holidays)
WITH tmp_table AS (
    SELECT tickets.ticket_id,
           tickets.create_date,
           tickets.resolved_date,
           COUNT(holidays.holiday_date) AS num_holidays
    FROM tickets
    LEFT JOIN holidays
    ON holidays.holiday_date BETWEEN tickets.create_date AND tickets.resolved_date
    GROUP BY tickets.ticket_id
)
SELECT *,
       (CAST((JulianDay(tmp_table.resolved_date) - 
             JulianDay(tmp_table.create_date)) AS INTEGER)) AS actual_days,
       (CAST((JulianDay(tmp_table.resolved_date) - 
             JulianDay(tmp_table.create_date)) AS INTEGER)) - 
       2 * (CAST(strftime("%W", tmp_table.resolved_date) AS INTEGER) -
            CAST(strftime("%W", tmp_table.create_date) AS INTEGER)) - 
       tmp_table.num_holidays AS working_days
FROM tmp_table;