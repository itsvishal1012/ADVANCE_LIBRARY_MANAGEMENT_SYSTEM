# 📚 Advanced Library Management System (LMS)

A **MySQL-based Library Management System** designed to handle student/faculty borrowing, reservations, fines, reminders, and reporting. This schema is production-ready with support for **policies, triggers, stored procedures, and views**.

---

## 🚀 Features

- **User & Role Management**
  - Supports Students, Faculty, Librarians, Admins
  - Role-based loan policies with overrides

- **Book Management**
  - Authors, Publishers, Books, Copies
  - Status tracking (Available, Borrowed, On Hold, Lost, Maintenance)

- **Borrowing & Reservations**
  - Queue system with position tracking
  - Reservation notifications
  - Issue, Return, Cancel, Reserve workflows

- **Policy & Fine Management**
  - Standard student/faculty loan durations
  - Fine calculation with per-user overrides
  - Fine payments logged with audit trail

- **Automation via Triggers**
  - Auto-update book availability when copies are added/updated
  - Queue handling for reservations
  - Auto-notifications when reserved copies become available

- **Reports via Views**
  - Popular books (last 6 months)
  - Active users (last 30 days)
  - Late returns summary
  - Fine balances and payments

- **Stored Procedures**
  - `sp_issue_book` → issue a book
  - `sp_return_book` → return & handle reservations/fines
  - `sp_reserve_book` / `sp_cancel_reservation`
  - `sp_pay_fine` → log payments
  - `sp_mark_copy_lost` / `sp_mark_copy_maintenance`
  - `sp_generate_due_reminders` → auto-create notifications
  - `sp_recommend_books` → genre-based book recommendations

---

## 🗄️ Database Schema Overview

### Core Entities
- `users` – Library users (students, faculty, staff)  
- `roles`, `user_roles` – Role-based access and policy application  
- `authors`, `publisher`, `books`, `book_copies` – Catalog of library items  

### Transactions & Policies
- `borrow_transactions` – Issues, returns, due dates, fines  
- `reservations` – Queue with `QUEUED`, `NOTIFIED`, `FULFILLED`, etc.  
- `policy`, `policy_overrides` – Default & custom loan rules  
- `payments` – Fine/fee payments with modes  

### Audit & Notifications
- `audit_log` – Who did what and when  
- `notifications` – Due reminders, hold-ready alerts, system messages  

---

## 🛠️ Setup Instructions

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/advanced-library-management.git
   cd advanced-library-management
   ```

2. Import schema into MySQL:
   ```bash
   mysql -u root -p < ADVANCE_LIBRARY_MANAGEMENT.sql
   ```

3. Verify tables:
   ```sql
   USE lms;
   SHOW TABLES;
   ```

4. Test sample data & procedures:
   ```sql
   CALL sp_reserve_book(4, 3, 2);
   CALL sp_issue_book(4, 3, 2);
   CALL sp_return_book(4, 1);
   CALL sp_generate_due_reminders();
   CALL sp_recommend_books(1, 5);
   ```

---

## 📊 Example Reports (Views)

- **Popular Books (6 months)**  
  ```sql
  SELECT * FROM v_popular_books_last_6m LIMIT 10;
  ```

- **Active Users (30 days)**  
  ```sql
  SELECT * FROM v_active_users_30d LIMIT 10;
  ```

- **Late Returns**  
  ```sql
  SELECT * FROM v_late_returns;
  ```

- **Fine Summary**  
  ```sql
  SELECT * FROM v_user_fines_summary;
  ```

---

## 📐 Schema Diagram

You can generate the schema diagram using [dbdiagram.io](https://dbdiagram.io).  
Paste the provided DBML schema file in the tool to view and export the ER diagram.

Example placeholder for GitHub (replace with exported diagram):
```markdown
![Schema Diagram](docs/schema-diagram.png)
```

---

## 📌 Notes

- Default policies: Students → 14 days / 3 books, Faculty → 28 days / 5 books  
- All operations logged in `audit_log`  
- Notifications support due-date reminders & hold-ready alerts  

---

## 📜 License

This project is licensed under the MIT License — feel free to use and modify.  
