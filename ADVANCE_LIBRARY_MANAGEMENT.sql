DROP DATABASE IF EXISTS LMS;
CREATE DATABASE LMS CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE LMS;
SET sql_safe_updates = 0;
SET foreign_key_check = 1;

CREATE TABLE ROLES(
role_id TINYINT UNSIGNED PRIMARY KEY auto_increment,
role_code VARCHAR(50) NOT NULL UNIQUE,
role_description VARCHAR(300) NOT NULL
) ENGINE = innoDB;

CREATE TABLE USERS (
user_id BIGINT UNSIGNED PRIMARY KEY auto_increment,
full_name VARCHAR(50) NOT NULL,
email VARCHAR(100) UNIQUE NOT NULL,
phone_no VARCHAR(20) UNIQUE NOT NULL,
dept VARCHAR(30),
person_status BOOLEAN NOT NULL DEFAULT TRUE,
created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = innoDB;
 
 CREATE TABLE USER_ROLES(
 user_id BIGINT UNSIGNED NOT NULL,
 role_id TINYINT UNSIGNED NOT NULL,
 PRIMARY KEY (user_id, role_id),
 FOREIGN KEY (user_id) REFERENCES USERS (user_id) ON DELETE CASCADE,
 FOREIGN KEY (role_id) REFERENCES ROLES (role_id) ON DELETE RESTRICT
) ENGINE = innoDB;

CREATE TABLE AUTHORS (
author_id BIGINT UNSIGNED PRIMARY KEY NOT NULL auto_increment,
author_name VARCHAR(50) NOT NULL UNIQUE
) ENGINE = innoDB;

CREATE TABLE PUBLISHER (
publisher_id BIGINT UNSIGNED PRIMARY KEY NOT NULL auto_increment,
publisher_name VARCHAR(50) NOT NULL UNIQUE
) ENGINE = innoDB;

CREATE TABLE BOOKS(
book_id BIGINT UNSIGNED PRIMARY KEY NOT NULL auto_increment,
isbn13 CHAR(13)NOT NULL UNIQUE,
title VARCHAR(255) NOT NULL,
genre VARCHAR(80),
published_year YEAR,
author_id BIGINT UNSIGNED NOT NULL,
publisher_id BIGINT UNSIGNED NOT NULL,
total_copies INT UNSIGNED NOT NULL DEFAULT 0,
available_copies INT UNSIGNED NOT NULL DEFAULT 0,
created_at DATETIME NOT NULL DEFAULT current_timestamp,
CONSTRAINT FK_BOOKS_AUTHOR FOREIGN KEY (author_id) REFERENCES AUTHORS (author_id),
CONSTRAINT FK_BOOKS_PUBLISHER FOREIGN KEY (publisher_id) REFERENCES PUBLISHER (publisher_id)
) ENGINE = innoDB;

CREATE TABLE BOOK_COPIES(
copy_id BIGINT UNSIGNED PRIMARY KEY NOT NULL auto_increment,
book_id BIGINT UNSIGNED NOT NULL,
barcode VARCHAR(50) NOT NULL UNIQUE,
status ENUM('AVAILABLE', 'BORROWED', 'ON_HOLD', 'LOST', 'MAINTAINANCE') NOT NULL DEFAULT 'AVAILABLE',
LAST_STATUS_CHANGE DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
FOREIGN KEY (book_id) REFERENCES BOOKS(book_id) ON DELETE CASCADE,
INDEX (book_id, status)
) ENGINE = innoDB;

CREATE TABLE POLICY(
policy_id TINYINT UNSIGNED PRIMARY KEY NOT NULL CHECK (policy_id = 1),
std_loan_days_student INT UNSIGNED NOT NULL DEFAULT 14,
std_loan_days_faculty INT UNSIGNED NOT NULL DEFAULT 28,
fine_per_day INT UNSIGNED NOT NULL DEFAULT 10,
max_active_loans_student INT UNSIGNED NOT NULL DEFAULT 3,
max_active_loans_facluty INT UNSIGNED NOT NULL DEFAULT 5
) ENGINE = innoDB;

INSERT INTO POLICY(policy_id) VALUES(1)
ON DUPLICATE KEY UPDATE policy_id = policy_id;

CREATE TABLE POLICY_OVERRIDES(
user_id BIGINT UNSIGNED PRIMARY KEY NOT NULL,
loan_days INT UNSIGNED,
max_loan INT UNSIGNED,
fine_per_day INT UNSIGNED,
FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE = innoDB;

CREATE TABLE RESERVATION (
reservation_id BIGINT UNSIGNED PRIMARY KEY auto_increment,
user_id BIGINT UNSIGNED NOT NULL,
book_id BIGINT UNSIGNED NOT NULL,
reserved_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
status ENUM('QUEUED', 'NOTIFIED', 'FULFILED', 'CANCELLED', 'EXPIRED') NOT NULL DEFAULT 'QUEUED',
queue_position INT UNSIGNED NOT NULL,
UNIQUE(book_id,user_id,status),
FOREIGN KEY (book_id) REFERENCES BOOKS (book_id) ON DELETE CASCADE,
FOREIGN KEY (user_id) REFERENCES USERS (user_id) ON DELETE CASCADE,
INDEX(book_id,status,queue_position)
) ENGINE = innoDB;

CREATE TABLE BORROW_TRANSACTIONS(
    transaction_id BIGINT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    book_id BIGINT UNSIGNED NOT NULL,
    copy_id BIGINT UNSIGNED NOT NULL,
    issue_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    due_date DATETIME NOT NULL,
    return_date DATETIME NOT NULL,
    fine INT UNSIGNED NOT NULL DEFAULT 0,
    status ENUM('ACTIVE', 'RETURNED', 'CANCELLED', 'OVERDUE') NOT NULL DEFAULT 'ACTIVE',
    FOREIGN KEY (user_id) REFERENCES USERS (user_id),
    FOREIGN KEY (book_id) REFERENCES BOOKS (book_id),
    FOREIGN KEY (copy_id) REFERENCES BOOK_COPIES (copy_id),
    INDEX (issue_date)   -- instead of partitioning, just index it
) ENGINE=InnoDB;

CREATE TABLE payments (
  payment_id   BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id      BIGINT UNSIGNED NOT NULL,
  amount_paise INT UNSIGNED NOT NULL,
  mode         ENUM('CASH','UPI','CARD','ONLINE') NOT NULL,
  paid_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  note         VARCHAR(255),
  FOREIGN KEY (user_id) REFERENCES users(user_id),
  INDEX (user_id, paid_at)
) ENGINE=InnoDB;

CREATE TABLE audit_log (
  audit_id     BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  actor_user   BIGINT UNSIGNED NULL,
  action       VARCHAR(40) NOT NULL,
  entity_type  VARCHAR(40) NOT NULL,
  entity_id    BIGINT UNSIGNED NOT NULL,
  message      VARCHAR(500),
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX (action, created_at),
  INDEX (entity_type, entity_id)
) ENGINE=InnoDB;

CREATE TABLE notifications (
  notification_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id         BIGINT UNSIGNED NOT NULL,
  type            ENUM('DUE_REMINDER','HOLD_READY','SYSTEM') NOT NULL,
  message         VARCHAR(255) NOT NULL,
  sent_at         DATETIME DEFAULT NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES USERS (user_id)
) ENGINE=InnoDB;

SHOW TABLES;

DROP FUNCTION IF EXISTS fn_calculate_fine_paise;
DELIMITER $$
CREATE FUNCTION fn_calculate_fine_paise(p_due DATETIME, p_returned DATETIME, p_rate_per_day_paise INT)
RETURNS INT
DETERMINISTIC
BEGIN
  DECLARE late_days INT;
  IF p_returned IS NULL OR p_returned <= p_due THEN
    RETURN 0;
  END IF;
  SET late_days = TIMESTAMPDIFF(DAY, p_due, p_returned);
  IF late_days < 0 THEN SET late_days = 0; END IF;
  RETURN late_days * p_rate_per_day_paise;
END$$
DELIMITER ;

CREATE OR REPLACE VIEW v_popular_books_last_6m AS
SELECT b.book_id, b.title, COUNT(*) AS borrow_count
FROM borrow_transactions t
JOIN books b ON b.book_id = t.book_id
WHERE t.issue_date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY b.book_id, b.title
ORDER BY borrow_count DESC;

CREATE OR REPLACE VIEW v_active_users_30d AS
SELECT u.user_id, u.full_name, COUNT(*) AS borrows_30d
FROM users u
JOIN borrow_transactions t ON t.user_id = u.user_id
WHERE t.issue_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY u.user_id, u.full_name
ORDER BY borrows_30d DESC;

CREATE OR REPLACE VIEW v_late_returns AS
SELECT
  t.transaction_id, u.full_name, b.title, t.due_date, t.return_date,
  GREATEST(TIMESTAMPDIFF(DAY, t.due_date, COALESCE(t.return_date, NOW())), 0) AS days_late
FROM borrow_transactions t
JOIN users u ON u.user_id = t.user_id
JOIN books b ON b.book_id = t.book_id
WHERE (t.return_date IS NULL AND t.due_date < NOW())
   OR (t.return_date IS NOT NULL AND t.return_date > t.due_date);
   
CREATE OR REPLACE VIEW v_user_fines_summary AS
SELECT
  u.user_id, u.full_name,
  COALESCE(SUM(CASE WHEN t.status IN ('ACTIVE','RETURNED','OVERDUE') THEN t.fine END),0) AS total_fines_paise,
  COALESCE((SELECT SUM(p.amount_paise) FROM payments p WHERE p.user_id = u.user_id),0) AS total_paid_paise,
  COALESCE(SUM(CASE WHEN t.status IN ('ACTIVE','RETURNED','OVERDUE') THEN t.fine END),0)
    - COALESCE((SELECT SUM(p.amount_paise) FROM payments p WHERE p.user_id = u.user_id),0)
    AS balance_paise
FROM users u
LEFT JOIN borrow_transactions t ON t.user_id = u.user_id
GROUP BY u.user_id, u.full_name;

-- --- Triggers -----------------------------------------------------------
DROP TRIGGER IF EXISTS trg_book_copy_status_after_update;
DELIMITER $$

CREATE TRIGGER trg_book_copy_status_after_update
AFTER UPDATE ON book_copies
FOR EACH ROW
BEGIN
  -- Run the update only if book_id or status changed
  IF NEW.book_id <> OLD.book_id OR NEW.status <> OLD.status THEN
    UPDATE books b
    SET available_copies = (
      SELECT COUNT(*) FROM book_copies bc
      WHERE bc.book_id = b.book_id AND bc.status = 'AVAILABLE'
    ),
        total_copies = (
      SELECT COUNT(*) FROM book_copies bc
      WHERE bc.book_id = b.book_id
    )
    WHERE b.book_id IN (OLD.book_id, NEW.book_id);
  END IF;
END$$

DELIMITER ;


DROP TRIGGER IF EXISTS trg_book_copy_after_insert;
DELIMITER $$
CREATE TRIGGER trg_book_copy_after_insert
AFTER INSERT ON book_copies
FOR EACH ROW
BEGIN
  UPDATE books b
  SET available_copies = (
    SELECT COUNT(*) FROM book_copies bc
    WHERE bc.book_id = b.book_id AND bc.status = 'AVAILABLE'
  ),
      total_copies = (
    SELECT COUNT(*) FROM book_copies bc
    WHERE bc.book_id = b.book_id
  )
  WHERE b.book_id = NEW.book_id;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_reservation_before_insert;
DELIMITER $$

CREATE TRIGGER trg_reservation_before_insert
BEFORE INSERT ON reservation
FOR EACH ROW
BEGIN
  IF NEW.queue_position IS NULL OR NEW.queue_position = 0 THEN
    SET NEW.queue_position =
      COALESCE((
        SELECT MAX(queue_position)
        FROM reservation
        WHERE book_id = NEW.book_id
          AND status IN ('QUEUED','NOTIFIED')
      ), 0) + 1;
  END IF;
END$$

DELIMITER ;

DROP TRIGGER IF EXISTS trg_reservation_notified_after_update;
DELIMITER $$
CREATE TRIGGER trg_reservation_notified_after_update
AFTER UPDATE ON reservation
FOR EACH ROW
BEGIN
  IF NEW.status='NOTIFIED' AND OLD.status='QUEUED' THEN
    INSERT INTO notifications (user_id, type, message)
    VALUES (NEW.user_id, 'HOLD_READY', CONCAT('Book ready for pickup: Book#', NEW.book_id));
  END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_get_role_policy;
DELIMITER $$

CREATE PROCEDURE sp_get_role_policy(
  IN p_user_id BIGINT,
  OUT p_loan_days INT,
  OUT p_max_loans INT,
  OUT p_fine_rate INT
)
BEGIN
  DECLARE has_override INT DEFAULT 0;
  DECLARE is_faculty INT DEFAULT 0;

  -- Check for overrides
  SELECT COUNT(*) INTO has_override
  FROM policy_overrides
  WHERE user_id = p_user_id;

  IF has_override > 0 THEN
    SELECT
      COALESCE(loan_days, (SELECT std_loan_days_student FROM policy WHERE policy_id=1)),
      COALESCE(max_loans, (SELECT max_active_loans_student FROM policy WHERE policy_id=1)),
      COALESCE(fine_per_day_paise, (SELECT fine_per_day_paise FROM policy WHERE policy_id=1))
    INTO p_loan_days, p_max_loans, p_fine_rate
    FROM policy_overrides
    WHERE user_id = p_user_id;

  ELSE
    -- Check faculty role
    SELECT COUNT(*) INTO is_faculty
    FROM user_roles ur
    JOIN roles r ON r.role_id = ur.role_id
    WHERE ur.user_id = p_user_id AND r.role_code = 'FACULTY';

    IF is_faculty > 0 THEN
      SELECT std_loan_days_faculty, max_active_loans_faculty, fine_per_day_paise
      INTO p_loan_days, p_max_loans, p_fine_rate
      FROM policy
      WHERE policy_id = 1;
    ELSE
      SELECT std_loan_days_student, max_active_loans_student, fine_per_day_paise
      INTO p_loan_days, p_max_loans, p_fine_rate
      FROM policy
      WHERE policy_id = 1;
    END IF;
  END IF;
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS sp_issue_book;
DELIMITER $$
CREATE PROCEDURE sp_issue_book(IN p_actor_user BIGINT, IN p_borrower BIGINT, IN p_book_id BIGINT)
BEGIN
  DECLARE v_copy_id BIGINT;
  DECLARE v_loan_days INT;
  DECLARE v_max_loans INT;
  DECLARE v_queue_user BIGINT;
  DECLARE v_rate INT;

  START TRANSACTION;

  IF (SELECT is_active FROM users WHERE user_id = p_borrower) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Borrower is not active';
  END IF;

  SELECT user_id INTO v_queue_user
  FROM reservations
  WHERE book_id = p_book_id AND status IN ('QUEUED','NOTIFIED')
  ORDER BY queue_position ASC, reserved_at ASC
  LIMIT 1;

  IF v_queue_user IS NOT NULL AND v_queue_user <> p_borrower THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Book reserved for another user';
  END IF;

  CALL sp_get_role_policy(p_borrower, v_loan_days, v_max_loans, v_rate);

  IF (SELECT COUNT(*) FROM borrow_transactions
      WHERE user_id = p_borrower AND status = 'ACTIVE') >= v_max_loans THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Max active loans reached';
  END IF;

  SELECT copy_id INTO v_copy_id
  FROM book_copies
  WHERE book_id = p_book_id AND status = 'AVAILABLE'
  LIMIT 1;

  IF v_copy_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No available copy';
  END IF;

  INSERT INTO borrow_transactions (user_id, book_id, copy_id, issue_date, due_date, status)
  VALUES (p_borrower, p_book_id, v_copy_id, NOW(), DATE_ADD(NOW(), INTERVAL v_loan_days DAY), 'ACTIVE');

  UPDATE book_copies SET status='BORROWED', last_status_change=NOW()
  WHERE copy_id = v_copy_id;

  UPDATE reservations
  SET status = 'FULFILLED'
  WHERE book_id = p_book_id AND user_id = p_borrower AND status IN ('QUEUED','NOTIFIED')
  ORDER BY queue_position ASC LIMIT 1;

  INSERT INTO audit_log (actor_user, action, entity_type, entity_id, message)
  VALUES (p_actor_user, 'ISSUE', 'TRANSACTION', LAST_INSERT_ID(),
          CONCAT('Issued copy ', v_copy_id, ' of book ', p_book_id, ' to user ', p_borrower));

  COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_return_book;
DELIMITER $$
CREATE PROCEDURE sp_return_book(IN p_actor_user BIGINT, IN p_transaction_id BIGINT)
BEGIN
  DECLARE v_copy_id BIGINT;
  DECLARE v_book_id BIGINT;
  DECLARE v_user_id BIGINT;
  DECLARE v_due DATETIME;
  DECLARE v_rate INT;
  DECLARE v_fine INT DEFAULT 0;
  DECLARE v_next_user BIGINT;

  START TRANSACTION;

  SELECT copy_id, book_id, user_id, due_date INTO v_copy_id, v_book_id, v_user_id, v_due
  FROM borrow_transactions
  WHERE transaction_id = p_transaction_id AND status = 'ACTIVE'
  FOR UPDATE;

  IF v_copy_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transaction not active or not found';
  END IF;

  SELECT p.fine_per_day_paise INTO v_rate FROM policy p WHERE p.policy_id = 1;
  -- Override rate if user has override
  SELECT COALESCE(fine_per_day_paise, v_rate) INTO v_rate
  FROM policy_overrides WHERE user_id = v_user_id;

  SET v_fine = fn_calculate_fine_paise(v_due, NOW(), v_rate);

  UPDATE borrow_transactions
  SET return_date = NOW(),
      fine_paise = v_fine,
      status = 'RETURNED'
  WHERE transaction_id = p_transaction_id;

  SELECT user_id INTO v_next_user
  FROM reservations
  WHERE book_id = v_book_id AND status = 'QUEUED'
  ORDER BY queue_position ASC, reserved_at ASC
  LIMIT 1
  FOR UPDATE;

  IF v_next_user IS NULL THEN
    UPDATE book_copies SET status='AVAILABLE', last_status_change=NOW() WHERE copy_id = v_copy_id;
  ELSE
    UPDATE book_copies SET status='ON_HOLD', last_status_change=NOW() WHERE copy_id = v_copy_id;
    UPDATE reservations
      SET status='NOTIFIED'
    WHERE book_id = v_book_id AND user_id = v_next_user AND status='QUEUED'
    ORDER BY queue_position ASC LIMIT 1;

    INSERT INTO audit_log (actor_user, action, entity_type, entity_id, message)
    VALUES (p_actor_user, 'HOLD_PLACED', 'BOOK_COPY', v_copy_id,
            CONCAT('Copy on hold for user ', v_next_user));
  END IF;

  INSERT INTO audit_log (actor_user, action, entity_type, entity_id, message)
  VALUES (p_actor_user, 'RETURN', 'TRANSACTION', p_transaction_id,
          CONCAT('Returned copy ', v_copy_id, '; fine_paise=', v_fine));

  COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_reserve_book;
DELIMITER $$
CREATE PROCEDURE sp_reserve_book(IN p_actor_user BIGINT, IN p_user BIGINT, IN p_book_id BIGINT)
BEGIN
  START TRANSACTION;
  IF EXISTS (SELECT 1 FROM reservations WHERE book_id = p_book_id AND user_id = p_user AND status IN ('QUEUED','NOTIFIED')) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Already reserved';
  END IF;

  INSERT INTO reservations (book_id, user_id, status, queue_position)
  VALUES (p_book_id, p_user, 'QUEUED', NULL);

  INSERT INTO audit_log (actor_user, action, entity_type, entity_id, message)
  VALUES (p_actor_user, 'RESERVE', 'RESERVATION', LAST_INSERT_ID(),
          CONCAT('User ', p_user, ' reserved book ', p_book_id));
  COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_cancel_reservation;
DELIMITER $$
CREATE PROCEDURE sp_cancel_reservation(IN p_actor_user BIGINT, IN p_reservation_id BIGINT)
BEGIN
  START TRANSACTION;
  UPDATE reservations SET status='CANCELLED'
  WHERE reservation_id = p_reservation_id AND status IN ('QUEUED','NOTIFIED');

  INSERT INTO audit_log (actor_user, action, entity_type, entity_id, message)
  VALUES (p_actor_user, 'CANCEL_RESERVATION', 'RESERVATION', p_reservation_id, 'Reservation cancelled');
  COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_pay_fine;
DELIMITER $$
CREATE PROCEDURE sp_pay_fine(
  IN p_actor_user BIGINT,
  IN p_user BIGINT,
  IN p_amount_paise INT,
  IN p_mode VARCHAR(10),
  IN p_note VARCHAR(255)
)
BEGIN
  START TRANSACTION;
  INSERT INTO payments(user_id, amount_paise, mode, note)
  VALUES (p_user, p_amount_paise,
          CASE UPPER(p_mode)
            WHEN 'CASH' THEN 'CASH'
            WHEN 'UPI'  THEN 'UPI'
            WHEN 'CARD' THEN 'CARD'
            ELSE 'ONLINE'
          END,
          p_note);

  INSERT INTO audit_log (actor_user, action, entity_type, entity_id, message)
  VALUES (p_actor_user, 'PAYMENT', 'USER', p_user, CONCAT('Payment ', p_amount_paise, ' paise via ', p_mode));
  COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_mark_copy_lost;
DELIMITER $$

CREATE PROCEDURE sp_mark_copy_lost(
  IN p_actor_user BIGINT,
  IN p_copy_id BIGINT,
  IN p_replacement_cost_paise INT
)
BEGIN
  DECLARE v_book_id BIGINT;
  DECLARE v_last_user BIGINT;

  START TRANSACTION;

  -- Lock and fetch book_id for the copy
  SELECT book_id
    INTO v_book_id
  FROM book_copies
  WHERE copy_id = p_copy_id
  FOR UPDATE;

  -- Mark the copy as lost
  UPDATE book_copies
  SET status = 'LOST',
      last_status_change = NOW()
  WHERE copy_id = p_copy_id;

  -- (Optional) record replacement charge for the last borrower
  SELECT user_id
    INTO v_last_user
  FROM loans
  WHERE copy_id = p_copy_id
  ORDER BY loan_date DESC
  LIMIT 1;

  IF v_last_user IS NOT NULL THEN
    INSERT INTO fines(user_id, book_id, copy_id, fine_type, amount_paise, created_by)
    VALUES (v_last_user, v_book_id, p_copy_id, 'REPLACEMENT', p_replacement_cost_paise, p_actor_user);
  END IF;

  COMMIT;
END$$

DELIMITER ;


DROP PROCEDURE IF EXISTS sp_mark_copy_maintenance;
DELIMITER $$
CREATE PROCEDURE sp_mark_copy_maintenance(IN p_actor_user BIGINT, IN p_copy_id BIGINT)
BEGIN
  START TRANSACTION;
  UPDATE book_copies SET status='MAINTENANCE', last_status_change=NOW()
  WHERE copy_id=p_copy_id;

  INSERT INTO audit_log (actor_user, action, entity_type, entity_id, message)
  VALUES (p_actor_user, 'MARK_MAINTENANCE', 'BOOK_COPY', p_copy_id, 'Copy under maintenance');
  COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_generate_due_reminders;
DELIMITER $$
CREATE PROCEDURE sp_generate_due_reminders()
BEGIN
  INSERT INTO notifications (user_id, type, message)
  SELECT DISTINCT t.user_id, 'DUE_REMINDER',
         CONCAT('Reminder: "', b.title, '" is due on ', DATE(t.due_date))
  FROM borrow_transactions t
  JOIN books b ON b.book_id=t.book_id
  WHERE t.status='ACTIVE'
    AND t.due_date BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 2 DAY)
    AND NOT EXISTS (
      SELECT 1 FROM notifications n
      WHERE n.user_id=t.user_id
        AND n.type='DUE_REMINDER'
        AND n.message LIKE CONCAT('%', b.title, '%')
        AND n.created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY)
    );
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_recommend_books;
DELIMITER $$
CREATE PROCEDURE sp_recommend_books(IN p_user_id BIGINT, IN p_last_n INT)
BEGIN
  DECLARE v_genre VARCHAR(80);

  -- Find dominant genre across the user's last N borrows
  SELECT x.genre INTO v_genre
  FROM (
    SELECT b.genre, COUNT(*) AS cnt
    FROM (
      SELECT book_id
      FROM borrow_transactions
      WHERE user_id=p_user_id
      ORDER BY issue_date DESC
      LIMIT p_last_n
    ) t
    JOIN books b ON b.book_id=t.book_id
    GROUP BY b.genre
    ORDER BY cnt DESC, b.genre
    LIMIT 1
  ) x;
  
  IF v_genre IS NULL THEN
    SELECT NULL AS book_id, NULL AS title, NULL AS genre, NULL AS available_copies
    WHERE 1=0;
  ELSE
    SELECT DISTINCT b.book_id, b.title, b.genre, b.available_copies
    FROM books b
    WHERE b.genre = v_genre
      AND b.book_id NOT IN (SELECT bt.book_id FROM borrow_transactions bt WHERE bt.user_id = p_user_id)
    ORDER BY b.available_copies DESC, b.title
    LIMIT 5;
  END IF;
END$$
DELIMITER ;

INSERT INTO roles (role_code, role_description) VALUES
  ('STUDENT','Student borrower'),
  ('FACULTY','Faculty borrower'),
  ('LIBRARIAN','Library staff'),
  ('ADMIN','System admin') 
  AS new
ON DUPLICATE KEY UPDATE role_description=VALUES(role_description);

INSERT INTO users (full_name, email, phone_no, dept) VALUES
  ('Aarav Mehta', 'aarav@uni.edu', '9000000001', 'CSE'),
  ('Diya Sharma', 'diya@uni.edu', '9000000002', 'ECE'),
  ('Prof. Neha Rao', 'neha.rao@uni.edu', '9000000003', 'CSE'),
  ('Librarian Kumar', 'lib.kumar@uni.edu', '9000000004', 'LIB'),
  ('Rohan Gupta', 'rohan.g@uni.edu', '9000000005', 'CSE'),
  ('Ishita Verma', 'ishita.v@uni.edu', '9000000006', 'ECE'),
  ('Aditya Singh', 'aditya.s@uni.edu', '9000000007', 'ME'),
  ('Meera Iyer', 'meera.iyer@uni.edu', '9000000008', 'CE'),
  ('Prof. Arjun Menon', 'arjun.menon@uni.edu', '9000000009', 'ECE'),
  ('Prof. Kavita Nair', 'kavita.nair@uni.edu', '9000000010', 'ME'),
  -- students 11–90
  ('Student 11', 'student11@uni.edu', '9000000011', 'CSE'),
  ('Student 12', 'student12@uni.edu', '9000000012', 'ECE'),
  ('Student 13', 'student13@uni.edu', '9000000013', 'ME'),
  ('Student 14', 'student14@uni.edu', '9000000014', 'CE'),
  ('Student 15', 'student15@uni.edu', '9000000015', 'CSE'),
  ('Student 16', 'student16@uni.edu', '9000000016', 'ECE'),
  ('Student 17', 'student17@uni.edu', '9000000017', 'ME'),
  ('Student 18', 'student18@uni.edu', '9000000018', 'CE'),
  ('Student 90', 'student90@uni.edu', '9000000090', 'ECE'),
  -- librarians/admins 91–100
  ('Librarian Asha', 'lib.asha@uni.edu', '9000000091', 'LIB'),
  ('Librarian Vivek', 'lib.vivek@uni.edu', '9000000092', 'LIB'),
  ('Admin Suresh', 'admin.suresh@uni.edu', '9000000093', 'LIB'),
  ('Admin Priya', 'admin.priya@uni.edu', '9000000094', 'LIB'),
  ('Admin John', 'admin.john@uni.edu', '9000000095', 'LIB'),
  ('Staff Anita', 'staff.anita@uni.edu', '9000000096', 'LIB'),
  ('Staff Rajesh', 'staff.rajesh@uni.edu', '9000000097', 'LIB'),
  ('Staff Sneha', 'staff.sneha@uni.edu', '9000000098', 'LIB'),
  ('Staff Mohan', 'staff.mohan@uni.edu', '9000000099', 'LIB'),
  ('Staff Fatima', 'staff.fatima@uni.edu', '9000000100', 'LIB')
AS new
ON DUPLICATE KEY UPDATE full_name=new.full_name, dept=new.dept;

-- Students 1–80
INSERT INTO user_roles (user_id, role_id)
SELECT user_id, 1 FROM users WHERE user_id BETWEEN 1 AND 80;

-- Faculty 81–95
INSERT INTO user_roles (user_id, role_id)
SELECT user_id, 2 FROM users WHERE user_id BETWEEN 81 AND 95;

-- Librarians 96–98
INSERT INTO user_roles (user_id, role_id)
SELECT user_id, 3 FROM users WHERE user_id BETWEEN 96 AND 98;

-- Admins 99–100
INSERT INTO user_roles (user_id, role_id)
SELECT user_id, 4 FROM users WHERE user_id BETWEEN 99 AND 100;

INSERT INTO authors (author_name) VALUES
  ('J.K. Rowling'), 
  ('Andrew Tanenbaum'),
  ('Corey Schafer'), 
  ('Donald Knuth')
AS new 
ON DUPLICATE KEY UPDATE author_name = new.author_name;

INSERT INTO publisher (publisher_name) VALUES
  ('Penguin'), 
  ('O''Reilly'),
  ('Prentice Hall'), 
  ('Addison-Wesley')
AS new 
ON DUPLICATE KEY UPDATE publisher_name = new.publisher_name;

INSERT INTO books (isbn13, title, genre, published_year, author_id, publisher_id) VALUES
  ('9780439554930','Harry Potter and the Sorcerer''s Stone','Fantasy',1997,1,1),
  ('9780133591620','Computer Networks','Networking',2010,2,3),
  ('9781492051367','Effective Python for Data Analysis','Programming',2020,3,2),
  ('9780201896831','The Art of Computer Programming Vol.1','CS Theory',1997,4,4)
AS new
ON DUPLICATE KEY UPDATE title=new.title, genre=new.genre;

INSERT INTO book_copies (book_id, barcode) VALUES
  (1,'HP-001'),(1,'HP-002'),(1,'HP-003'),
  (2,'CN-001'),(2,'CN-002'),
  (3,'EP-001'),(3,'EP-002'),
  (4,'TAOCP1-001');
  
  UPDATE books b
SET available_copies = (SELECT COUNT(*) FROM book_copies bc WHERE bc.book_id=b.book_id AND bc.status='AVAILABLE'),
    total_copies     = (SELECT COUNT(*) FROM book_copies bc WHERE bc.book_id=b.book_id);

INSERT INTO policy_overrides (user_id, loan_days, max_loan, fine_per_day)
VALUES (3, 35, 7, 5)  -- Prof. Neha: 35 days, 7 loans, ₹5/day
ON DUPLICATE KEY UPDATE loan_days=VALUES(loan_days), max_loan=VALUES(max_loan), fine_per_day=VALUES(fine_per_day);

CALL sp_reserve_book(4, 3, 2);
CALL sp_issue_book(4, 3, 2);

UPDATE borrow_transactions
SET due_date = DATE_SUB(NOW(), INTERVAL 3 DAY)
WHERE user_id=1 AND book_id=2 AND status='ACTIVE'
ORDER BY transaction_id DESC LIMIT 1;

SELECT transaction_id INTO @t1
FROM borrow_transactions
WHERE user_id=1 AND book_id=2 AND status='ACTIVE'
ORDER BY transaction_id DESC LIMIT 1;

CALL sp_return_book(4, @t1);

CALL sp_generate_due_reminders();

CALL sp_pay_fine(4, 1, 2000, 'UPI', 'Partial fine');

CALL sp_mark_copy_lost(4, 1, 15000); -- copy_id=1 (example), ₹150 replacement

CALL sp_mark_copy_maintenance(4, 2);

CALL sp_recommend_books(1, 5);

SELECT * FROM v_popular_books_last_6m LIMIT 10;
SELECT * FROM v_active_users_30d LIMIT 10;
SELECT * FROM v_late_returns;
SELECT * FROM v_user_fines_summary;
SELECT * FROM notifications ORDER BY created_at DESC LIMIT 20;
SELECT * FROM audit_log ORDER BY created_at DESC LIMIT 20;

SELECT 
    t.table_name,
    c.column_name,
    c.ordinal_position,
    c.column_type,
    c.is_nullable,
    c.column_default,
    c.extra,
    c.column_key,
    c.character_maximum_length,
    c.numeric_precision,
    c.numeric_scale,
    k.constraint_name,
    k.referenced_table_name,
    k.referenced_column_name
FROM information_schema.tables t
JOIN information_schema.columns c 
    ON t.table_name = c.table_name 
   AND t.table_schema = c.table_schema
LEFT JOIN information_schema.key_column_usage k 
    ON c.table_schema = k.table_schema 
   AND c.table_name = k.table_name 
   AND c.column_name = k.column_name
WHERE t.table_schema = 'lms'
ORDER BY t.table_name, c.ordinal_position;

