-- Make sure this option is ON so when we delete a foreign key, the
-- attribute of the rows associated with the foreign key is replaced
-- by NULL, or the rows associated with the foreign key are deleted
-- (based on 'ON DELETE' setting)
PRAGMA foreign_keys = ON;

-- ####################################################################
--                          LOAD DATABASE
-- ####################################################################
.open employees.db


-- ####################################################################
--                           BASIC QUERIES
-- ####################################################################

-- Now that our database is loaded, let's carry out some basic queries.

-- 1. Find all employees
SELECT * FROM employee;

-- 2. Find all clients
SELECT * FROM client;

-- 3. Find all employees ordered by salary
SELECT * FROM employee ORDER BY salary;

-- 4. Find all employees ordered by sex, then name
SELECT * FROM employee
ORDER BY sex, first_name, last_name;

-- 5. Find the first 5 employees in the table
SELECT * FROM employee
LIMIT 5;

-- 6. Find the first and last names of all employees
SELECT first_name, last_name
FROM employee;

-- 7. Find the forename and surname names of all employees. The method shown
-- below renames the columns in the output only
SELECT first_name AS forename, last_name AS surname
FROM employee;

-- 8. Find out all the different genders
SELECT DISTINCT sex
FROM employee;


-- ####################################################################
--                          FUNCTIONS
-- ####################################################################

-- 1. Find the number of employees
SELECT COUNT(emp_id)
FROM employee;

-- 2. Find the number of female employees born after 1970
SELECT COUNT(emp_id)
FROM employee
WHERE sex = 'F' AND birth_day > '1971-01-01';

-- 3. Find the average of all employee's salaries
SELECT AVG(salary)
FROM employee;

-- 4. Find the sum of all employee's salaries
SELECT SUM(salary)
FROM employee;

-- 5. Find out how many males and females there are
SELECT COUNT(sex), sex
FROM employee
GROUP BY sex;

-- 6. Find the total sales of each salesman
SELECT emp_id, SUM(total_sales)
FROM works_with
GROUP BY emp_id;


-- ####################################################################
--                          WILDCARDS
-- ####################################################################
-- % = any # of characters
-- _ = one character

-- 1. Find any client's who are an LLC
SELECT * FROM client
WHERE client_name LIKE '%LLC';

-- 2. Find any branch suppliers who are in the label business
SELECT * FROM branch_supplier
WHERE supplier_name LIKE '% label%';

-- 3. Find any employee born in October
SELECT * FROM employee
WHERE birth_day LIKE '____-10-%';

-- 4. Find any clients who are schools
SELECT * FROM client
WHERE client_name LIKE '%school%';


-- ####################################################################
--                          UNION
-- ####################################################################
-- UNION operator combines the result sets of two or more queries into a single
-- result set

-- 1. Find a list of employee and branch names
SELECT first_name FROM employee
UNION
SELECT branch_name FROM branch;

-- 2. Find a list of all clients & branch suppliers' names
SELECT client_name, client.branch_id
FROM client
UNION
SELECT supplier_name, branch_supplier.branch_id
FROM branch_supplier;

-- 3. Find a list of all the money spent or earned by the company
SELECT (salary * (-1))
FROM employee
UNION
SELECT total_sales
FROM works_with;


-- ####################################################################
--                          JOINS
-- ####################################################################
-- It is used to combine rows from two or more tables based on a related
-- column between them

-- 1.a. Find all branches and the names of their managers (INNER JOIN)
SELECT employee.emp_id, employee.first_name, branch.branch_name
FROM employee
JOIN branch
ON employee.emp_id = branch.mgr_id;

-- 1.b. Find all branches and the names of their managers (LEFT JOIN)
SELECT employee.emp_id, employee.first_name, branch.branch_name
FROM employee
LEFT JOIN branch
ON employee.emp_id = branch.mgr_id;


-- ####################################################################
--                         NESTED QUERIES
-- ####################################################################

-- 1. Find names of all employees who have sold over $30,000 to a single client
SELECT employee.first_name, employee.last_name 
FROM employee 
WHERE employee.emp_id IN (
    SELECT works_with.emp_id
    FROM works_with
    WHERE works_with.total_sales > 30000
);

-- 2. Find all clients who are handled by the branch that Michael Scott manages
SELECT client.client_name
FROM client
WHERE client.branch_id IN (
    SELECT branch.branch_id
    FROM branch
    WHERE branch.mgr_id IN (
        SELECT employee.emp_id
        FROM employee
        WHERE employee.first_name = 'Michael' AND employee.last_name = 'Scott'
    )
);