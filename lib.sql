
/*
========================================================
PROJECT NAME : LIBRARY MANAGEMENT SYSTEM
DATABASE     : MySQL 8.0
AUTHOR       : Vignesh
========================================================
*/


-- 1. CREATE DATABASE

CREATE DATABASE library_management;

USE library_management;


-- 2. CREATE BOOKS TABLE

CREATE TABLE books (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    book_name VARCHAR(100) NOT NULL,
    author VARCHAR(100) NOT NULL,
    total_copies INT NOT NULL,
    available_copies INT NOT NULL,

    -- Validate book quantities
    CONSTRAINT chk_total CHECK (total_copies >= 0),
    CONSTRAINT chk_available CHECK (
        available_copies >= 0
        AND available_copies <= total_copies
    )
);


-- 3. CREATE USERS TABLE

CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    user_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(15)
);


-- 4. CREATE TRANSACTIONS TABLE

CREATE TABLE transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    user_id INT NOT NULL,
    issue_date DATE NOT NULL,
    due_date DATE NOT NULL,
    return_date DATE,

    status ENUM('ISSUED', 'RETURNED')
        NOT NULL DEFAULT 'ISSUED',

    -- Book relationship
    FOREIGN KEY (book_id)
        REFERENCES books(book_id),

    -- User relationship
    FOREIGN KEY (user_id)
        REFERENCES users(user_id),

    -- Validate dates
    CHECK (due_date >= issue_date),
    CHECK (return_date IS NULL OR return_date >= issue_date),

    -- Return date must match transaction status
    CHECK (
        (status = 'ISSUED' AND return_date IS NULL)
        OR
        (status = 'RETURNED' AND return_date IS NOT NULL)
    )
);


-- 5. INSERT BOOK DETAILS

INSERT INTO books
(book_name, author, total_copies, available_copies)
VALUES
('Java', 'Vignesh', 5, 5),
('Oracle SQL', 'MSD', 4, 4),
('Python', 'Jay', 3, 3),
('C Programming', 'Anand', 6, 6),
('HTML', 'AK', 2, 2);


-- 6. INSERT USER DETAILS

INSERT INTO users
(user_name, email, phone)
VALUES
('Vignesh', 'vignesh@gmail.com', '9876543210'),
('Rahul', 'rahul@gmail.com', '9876543211'),
('Priya', 'priya@gmail.com', '9876543212');


-- 7. DISPLAY ALL BOOKS

SELECT * FROM books;


-- 8. DISPLAY ALL USERS

SELECT * FROM users;


-- 9. ADD NEW BOOK

INSERT INTO books
(book_name, author, total_copies, available_copies)
VALUES
('Spring Boot', 'Craig Walls', 3, 3);


-- 10. UPDATE BOOK DETAILS

UPDATE books
SET author = 'Updated Author'
WHERE book_id = 1;


-- 11. DELETE BOOK
-- Foreign key prevents deletion if transactions exist

DELETE FROM books
WHERE book_id = 5;


-- 12. ISSUE BOOK
-- Book ID = 1
-- User ID = 1
-- Borrowing period = 14 days

START TRANSACTION;

-- Lock the book row to prevent simultaneous stock changes

SELECT available_copies
FROM books
WHERE book_id = 1
FOR UPDATE;

-- Insert transaction only if book and user exist
-- and at least one copy is available

INSERT INTO transactions
(book_id, user_id, issue_date, due_date, status)

SELECT
    b.book_id,
    u.user_id,
    CURRENT_DATE,
    DATE_ADD(CURRENT_DATE, INTERVAL 14 DAY),
    'ISSUED'
FROM books b
JOIN users u
    ON u.user_id = 1
WHERE b.book_id = 1
AND b.available_copies > 0;

-- Reduce stock only if one transaction was inserted

UPDATE books
SET available_copies = available_copies - 1
WHERE book_id = 1
AND available_copies > 0
AND ROW_COUNT() = 1;

-- If any SQL error occurs, execute ROLLBACK.
-- If no transaction was inserted, no stock is reduced.

COMMIT;


-- 13. RETURN BOOK
-- Transaction ID = 1

START TRANSACTION;

-- Lock transaction record

SELECT book_id
FROM transactions
WHERE transaction_id = 1
FOR UPDATE;

-- Return only if currently issued

UPDATE transactions
SET return_date = CURRENT_DATE,
    status = 'RETURNED'
WHERE transaction_id = 1
AND status = 'ISSUED';

-- Increase stock only if return update succeeded
-- ROW_COUNT() refers to the previous UPDATE

UPDATE books
SET available_copies = available_copies + 1
WHERE book_id = (
    SELECT book_id
    FROM (
        SELECT book_id
        FROM transactions
        WHERE transaction_id = 1
    ) AS temp
)
AND ROW_COUNT() = 1;

-- If any SQL error occurs, execute ROLLBACK.

COMMIT;


-- 14. DISPLAY AVAILABLE BOOKS

SELECT
    book_id,
    book_name,
    author,
    total_copies,
    available_copies
FROM books
WHERE available_copies > 0;


-- 15. DISPLAY ISSUED BOOKS

SELECT
    t.transaction_id,
    u.user_name,
    b.book_name,
    t.issue_date,
    t.due_date,
    t.status
FROM transactions t
JOIN users u
    ON t.user_id = u.user_id
JOIN books b
    ON t.book_id = b.book_id
WHERE t.status = 'ISSUED';


-- 16. DISPLAY TRANSACTION HISTORY

SELECT
    t.transaction_id,
    u.user_name,
    b.book_name,
    t.issue_date,
    t.due_date,
    t.return_date,
    t.status
FROM transactions t
JOIN users u
    ON t.user_id = u.user_id
JOIN books b
    ON t.book_id = b.book_id
ORDER BY t.transaction_id DESC;

-- 17. FIND OVERDUE BOOKS

SELECT
    u.user_name,
    b.book_name,
    t.issue_date,
    t.due_date,
    DATEDIFF(CURRENT_DATE, t.due_date) AS overdue_days
FROM transactions t
JOIN users u
    ON t.user_id = u.user_id
JOIN books b
    ON t.book_id = b.book_id
WHERE t.status = 'ISSUED'
AND t.due_date < CURRENT_DATE;


-- 18. COUNT TOTAL BOOKS

SELECT
    COUNT(*) AS total_book_titles,
    SUM(total_copies) AS total_copies
FROM books;


-- 19. COUNT TOTAL USERS

SELECT COUNT(*) AS total_users
FROM users;


-- 20. COUNT BOOKS BORROWED BY EACH USER

SELECT
    u.user_name,
    COUNT(t.transaction_id) AS total_borrowed
FROM users u
LEFT JOIN transactions t
    ON u.user_id = t.user_id
GROUP BY u.user_id, u.user_name;

-- 21. FIND USERS WHO NEVER BORROWED BOOKS

SELECT *
FROM users u

WHERE NOT EXISTS (
    SELECT 1
    FROM transactions t
    WHERE t.user_id = u.user_id
);


-- 22. FIND MOST BORROWED BOOK

SELECT
    b.book_name,
    COUNT(t.transaction_id) AS total_issues
FROM books b
JOIN transactions t
    ON b.book_id = t.book_id
GROUP BY b.book_id, b.book_name
ORDER BY total_issues DESC
LIMIT 1;


-- 23. FINAL TABLE VERIFICATION

SELECT * FROM books;

SELECT * FROM users;

SELECT * FROM transactions;
