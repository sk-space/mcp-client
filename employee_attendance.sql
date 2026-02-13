-- MySQL 8 Employee Attendance Management System
-- Simple database for tracking employee attendance
--
-- Features:
--  - Employee management with department assignment
--  - Daily attendance tracking with check-in/check-out times
--  - Attendance status tracking (Present, Absent, Late, Half-day, Leave)
--  - Leave management system
--
-- Usage: Import this file into MySQL 8.x
--   mysql -u root -p < employee_attendance.sql

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- Create database
CREATE DATABASE IF NOT EXISTS employee_attendance_db
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE employee_attendance_db;

-- Disable foreign key checks for smooth reload
SET FOREIGN_KEY_CHECKS = 0;

-- Drop existing tables
DROP TABLE IF EXISTS attendance_records;
DROP TABLE IF EXISTS leave_requests;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS departments;

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

-- ========================================
-- DEPARTMENTS TABLE
-- ========================================
CREATE TABLE departments (
  department_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  department_name VARCHAR(100) NOT NULL,
  manager_id      INT UNSIGNED DEFAULT NULL COMMENT 'Employee ID of department manager',
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  PRIMARY KEY (department_id),
  UNIQUE KEY ux_department_name (department_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Department information';

-- ========================================
-- EMPLOYEES TABLE
-- ========================================
CREATE TABLE employees (
  employee_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  first_name     VARCHAR(50) NOT NULL,
  last_name      VARCHAR(50) NOT NULL,
  email          VARCHAR(100) NOT NULL,
  phone          VARCHAR(20),
  department_id  INT UNSIGNED NOT NULL,
  position       VARCHAR(100),
  hire_date      DATE NOT NULL,
  status         ENUM('Active', 'Inactive', 'On Leave', 'Terminated') DEFAULT 'Active',
  shift_start    TIME DEFAULT '09:00:00' COMMENT 'Expected shift start time',
  shift_end      TIME DEFAULT '17:00:00' COMMENT 'Expected shift end time',
  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  PRIMARY KEY (employee_id),
  UNIQUE KEY ux_employee_email (email),
  KEY idx_employee_department (department_id),
  KEY idx_employee_status (status),
  
  CONSTRAINT fk_employee_department 
    FOREIGN KEY (department_id) REFERENCES departments(department_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Employee information';

-- ========================================
-- ATTENDANCE RECORDS TABLE
-- ========================================
CREATE TABLE attendance_records (
  attendance_id  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  employee_id    INT UNSIGNED NOT NULL,
  attendance_date DATE NOT NULL,
  check_in_time  DATETIME DEFAULT NULL,
  check_out_time DATETIME DEFAULT NULL,
  status         ENUM('Present', 'Absent', 'Late', 'Half-day', 'On Leave', 'Holiday') NOT NULL DEFAULT 'Present',
  work_hours     DECIMAL(5,2) DEFAULT NULL COMMENT 'Calculated work hours',
  notes          TEXT COMMENT 'Additional notes or remarks',
  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  PRIMARY KEY (attendance_id),
  UNIQUE KEY ux_employee_date (employee_id, attendance_date),
  KEY idx_attendance_date (attendance_date),
  KEY idx_attendance_status (status),
  
  CONSTRAINT fk_attendance_employee 
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Daily attendance records';

-- ========================================
-- LEAVE REQUESTS TABLE
-- ========================================
CREATE TABLE leave_requests (
  leave_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  employee_id    INT UNSIGNED NOT NULL,
  leave_type     ENUM('Sick Leave', 'Vacation', 'Personal', 'Emergency', 'Unpaid') NOT NULL,
  start_date     DATE NOT NULL,
  end_date       DATE NOT NULL,
  days_count     INT UNSIGNED NOT NULL,
  reason         TEXT,
  status         ENUM('Pending', 'Approved', 'Rejected', 'Cancelled') DEFAULT 'Pending',
  approved_by    INT UNSIGNED DEFAULT NULL COMMENT 'Employee ID of approver',
  approved_at    DATETIME DEFAULT NULL,
  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  PRIMARY KEY (leave_id),
  KEY idx_leave_employee (employee_id),
  KEY idx_leave_dates (start_date, end_date),
  KEY idx_leave_status (status),
  
  CONSTRAINT fk_leave_employee 
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_leave_approver 
    FOREIGN KEY (approved_by) REFERENCES employees(employee_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Employee leave requests';

-- ========================================
-- SAMPLE DATA
-- ========================================

-- Insert Departments
INSERT INTO departments (department_name, manager_id) VALUES
('Human Resources', NULL),
('Engineering', NULL),
('Sales', NULL),
('Marketing', NULL),
('Finance', NULL);

-- Insert Employees
INSERT INTO employees (first_name, last_name, email, phone, department_id, position, hire_date, status, shift_start, shift_end) VALUES
('John', 'Doe', 'john.doe@company.com', '555-0101', 1, 'HR Manager', '2020-01-15', 'Active', '09:00:00', '17:00:00'),
('Jane', 'Smith', 'jane.smith@company.com', '555-0102', 2, 'Senior Developer', '2019-03-20', 'Active', '09:00:00', '17:00:00'),
('Mike', 'Johnson', 'mike.johnson@company.com', '555-0103', 2, 'Software Engineer', '2021-06-01', 'Active', '09:00:00', '17:00:00'),
('Sarah', 'Williams', 'sarah.williams@company.com', '555-0104', 3, 'Sales Manager', '2020-08-10', 'Active', '08:30:00', '16:30:00'),
('David', 'Brown', 'david.brown@company.com', '555-0105', 3, 'Sales Representative', '2022-01-15', 'Active', '08:30:00', '16:30:00'),
('Emily', 'Davis', 'emily.davis@company.com', '555-0106', 4, 'Marketing Specialist', '2021-04-01', 'Active', '09:00:00', '17:00:00'),
('Robert', 'Miller', 'robert.miller@company.com', '555-0107', 5, 'Accountant', '2020-11-01', 'Active', '09:00:00', '17:00:00'),
('Lisa', 'Wilson', 'lisa.wilson@company.com', '555-0108', 2, 'Junior Developer', '2023-02-01', 'Active', '09:00:00', '17:00:00'),
('James', 'Moore', 'james.moore@company.com', '555-0109', 1, 'HR Coordinator', '2022-05-15', 'Active', '09:00:00', '17:00:00'),
('Mary', 'Taylor', 'mary.taylor@company.com', '555-0110', 4, 'Content Writer', '2021-09-01', 'Active', '10:00:00', '18:00:00');

-- Update department managers
UPDATE departments SET manager_id = 1 WHERE department_id = 1;
UPDATE departments SET manager_id = 2 WHERE department_id = 2;
UPDATE departments SET manager_id = 4 WHERE department_id = 3;
UPDATE departments SET manager_id = 6 WHERE department_id = 4;
UPDATE departments SET manager_id = 7 WHERE department_id = 5;

-- Insert Attendance Records (Last 7 days for all employees)
INSERT INTO attendance_records (employee_id, attendance_date, check_in_time, check_out_time, status, work_hours) VALUES
-- Day 1 (7 days ago)
(1, CURDATE() - INTERVAL 7 DAY, CONCAT(CURDATE() - INTERVAL 7 DAY, ' 09:05:00'), CONCAT(CURDATE() - INTERVAL 7 DAY, ' 17:10:00'), 'Present', 8.08),
(2, CURDATE() - INTERVAL 7 DAY, CONCAT(CURDATE() - INTERVAL 7 DAY, ' 08:55:00'), CONCAT(CURDATE() - INTERVAL 7 DAY, ' 17:20:00'), 'Present', 8.42),
(3, CURDATE() - INTERVAL 7 DAY, CONCAT(CURDATE() - INTERVAL 7 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 7 DAY, ' 17:05:00'), 'Present', 8.08),
(4, CURDATE() - INTERVAL 7 DAY, CONCAT(CURDATE() - INTERVAL 7 DAY, ' 08:30:00'), CONCAT(CURDATE() - INTERVAL 7 DAY, ' 16:40:00'), 'Present', 8.17),
(5, CURDATE() - INTERVAL 7 DAY, CONCAT(CURDATE() - INTERVAL 7 DAY, ' 08:35:00'), CONCAT(CURDATE() - INTERVAL 7 DAY, ' 16:30:00'), 'Present', 7.92),
(6, CURDATE() - INTERVAL 7 DAY, CONCAT(CURDATE() - INTERVAL 7 DAY, ' 09:10:00'), CONCAT(CURDATE() - INTERVAL 7 DAY, ' 17:00:00'), 'Late', 7.83),
(7, CURDATE() - INTERVAL 7 DAY, CONCAT(CURDATE() - INTERVAL 7 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 7 DAY, ' 17:00:00'), 'Present', 8.00),
(8, CURDATE() - INTERVAL 7 DAY, CONCAT(CURDATE() - INTERVAL 7 DAY, ' 09:15:00'), CONCAT(CURDATE() - INTERVAL 7 DAY, ' 17:10:00'), 'Late', 7.92),
(9, CURDATE() - INTERVAL 7 DAY, CONCAT(CURDATE() - INTERVAL 7 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 7 DAY, ' 17:00:00'), 'Present', 8.00),
(10, CURDATE() - INTERVAL 7 DAY, CONCAT(CURDATE() - INTERVAL 7 DAY, ' 10:05:00'), CONCAT(CURDATE() - INTERVAL 7 DAY, ' 18:00:00'), 'Present', 7.92),

-- Day 2 (6 days ago)
(1, CURDATE() - INTERVAL 6 DAY, CONCAT(CURDATE() - INTERVAL 6 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 6 DAY, ' 17:00:00'), 'Present', 8.00),
(2, CURDATE() - INTERVAL 6 DAY, CONCAT(CURDATE() - INTERVAL 6 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 6 DAY, ' 17:30:00'), 'Present', 8.50),
(3, CURDATE() - INTERVAL 6 DAY, NULL, NULL, 'Absent', 0),
(4, CURDATE() - INTERVAL 6 DAY, CONCAT(CURDATE() - INTERVAL 6 DAY, ' 08:30:00'), CONCAT(CURDATE() - INTERVAL 6 DAY, ' 16:30:00'), 'Present', 8.00),
(5, CURDATE() - INTERVAL 6 DAY, CONCAT(CURDATE() - INTERVAL 6 DAY, ' 08:30:00'), CONCAT(CURDATE() - INTERVAL 6 DAY, ' 16:30:00'), 'Present', 8.00),
(6, CURDATE() - INTERVAL 6 DAY, CONCAT(CURDATE() - INTERVAL 6 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 6 DAY, ' 17:00:00'), 'Present', 8.00),
(7, CURDATE() - INTERVAL 6 DAY, CONCAT(CURDATE() - INTERVAL 6 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 6 DAY, ' 17:00:00'), 'Present', 8.00),
(8, CURDATE() - INTERVAL 6 DAY, CONCAT(CURDATE() - INTERVAL 6 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 6 DAY, ' 17:00:00'), 'Present', 8.00),
(9, CURDATE() - INTERVAL 6 DAY, CONCAT(CURDATE() - INTERVAL 6 DAY, ' 09:05:00'), CONCAT(CURDATE() - INTERVAL 6 DAY, ' 17:00:00'), 'Present', 7.92),
(10, CURDATE() - INTERVAL 6 DAY, CONCAT(CURDATE() - INTERVAL 6 DAY, ' 10:00:00'), CONCAT(CURDATE() - INTERVAL 6 DAY, ' 18:05:00'), 'Present', 8.08),

-- Day 3 (5 days ago)
(1, CURDATE() - INTERVAL 5 DAY, CONCAT(CURDATE() - INTERVAL 5 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 5 DAY, ' 17:00:00'), 'Present', 8.00),
(2, CURDATE() - INTERVAL 5 DAY, CONCAT(CURDATE() - INTERVAL 5 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 5 DAY, ' 17:00:00'), 'Present', 8.00),
(3, CURDATE() - INTERVAL 5 DAY, CONCAT(CURDATE() - INTERVAL 5 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 5 DAY, ' 13:00:00'), 'Half-day', 4.00),
(4, CURDATE() - INTERVAL 5 DAY, CONCAT(CURDATE() - INTERVAL 5 DAY, ' 08:30:00'), CONCAT(CURDATE() - INTERVAL 5 DAY, ' 16:30:00'), 'Present', 8.00),
(5, CURDATE() - INTERVAL 5 DAY, CONCAT(CURDATE() - INTERVAL 5 DAY, ' 08:30:00'), CONCAT(CURDATE() - INTERVAL 5 DAY, ' 16:30:00'), 'Present', 8.00),
(6, CURDATE() - INTERVAL 5 DAY, CONCAT(CURDATE() - INTERVAL 5 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 5 DAY, ' 17:00:00'), 'Present', 8.00),
(7, CURDATE() - INTERVAL 5 DAY, CONCAT(CURDATE() - INTERVAL 5 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 5 DAY, ' 17:00:00'), 'Present', 8.00),
(8, CURDATE() - INTERVAL 5 DAY, CONCAT(CURDATE() - INTERVAL 5 DAY, ' 09:20:00'), CONCAT(CURDATE() - INTERVAL 5 DAY, ' 17:00:00'), 'Late', 7.67),
(9, CURDATE() - INTERVAL 5 DAY, CONCAT(CURDATE() - INTERVAL 5 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 5 DAY, ' 17:00:00'), 'Present', 8.00),
(10, CURDATE() - INTERVAL 5 DAY, CONCAT(CURDATE() - INTERVAL 5 DAY, ' 10:00:00'), CONCAT(CURDATE() - INTERVAL 5 DAY, ' 18:00:00'), 'Present', 8.00),

-- Day 4 (4 days ago)
(1, CURDATE() - INTERVAL 4 DAY, CONCAT(CURDATE() - INTERVAL 4 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 4 DAY, ' 17:00:00'), 'Present', 8.00),
(2, CURDATE() - INTERVAL 4 DAY, CONCAT(CURDATE() - INTERVAL 4 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 4 DAY, ' 18:00:00'), 'Present', 9.00),
(3, CURDATE() - INTERVAL 4 DAY, CONCAT(CURDATE() - INTERVAL 4 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 4 DAY, ' 17:00:00'), 'Present', 8.00),
(4, CURDATE() - INTERVAL 4 DAY, CONCAT(CURDATE() - INTERVAL 4 DAY, ' 08:30:00'), CONCAT(CURDATE() - INTERVAL 4 DAY, ' 16:30:00'), 'Present', 8.00),
(5, CURDATE() - INTERVAL 4 DAY, CONCAT(CURDATE() - INTERVAL 4 DAY, ' 08:30:00'), CONCAT(CURDATE() - INTERVAL 4 DAY, ' 16:30:00'), 'Present', 8.00),
(6, CURDATE() - INTERVAL 4 DAY, NULL, NULL, 'On Leave', 0),
(7, CURDATE() - INTERVAL 4 DAY, CONCAT(CURDATE() - INTERVAL 4 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 4 DAY, ' 17:00:00'), 'Present', 8.00),
(8, CURDATE() - INTERVAL 4 DAY, CONCAT(CURDATE() - INTERVAL 4 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 4 DAY, ' 17:00:00'), 'Present', 8.00),
(9, CURDATE() - INTERVAL 4 DAY, CONCAT(CURDATE() - INTERVAL 4 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 4 DAY, ' 17:00:00'), 'Present', 8.00),
(10, CURDATE() - INTERVAL 4 DAY, CONCAT(CURDATE() - INTERVAL 4 DAY, ' 10:00:00'), CONCAT(CURDATE() - INTERVAL 4 DAY, ' 18:00:00'), 'Present', 8.00),

-- Day 5 (3 days ago)
(1, CURDATE() - INTERVAL 3 DAY, CONCAT(CURDATE() - INTERVAL 3 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 3 DAY, ' 17:00:00'), 'Present', 8.00),
(2, CURDATE() - INTERVAL 3 DAY, CONCAT(CURDATE() - INTERVAL 3 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 3 DAY, ' 17:00:00'), 'Present', 8.00),
(3, CURDATE() - INTERVAL 3 DAY, CONCAT(CURDATE() - INTERVAL 3 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 3 DAY, ' 17:00:00'), 'Present', 8.00),
(4, CURDATE() - INTERVAL 3 DAY, CONCAT(CURDATE() - INTERVAL 3 DAY, ' 08:30:00'), CONCAT(CURDATE() - INTERVAL 3 DAY, ' 16:30:00'), 'Present', 8.00),
(5, CURDATE() - INTERVAL 3 DAY, CONCAT(CURDATE() - INTERVAL 3 DAY, ' 08:45:00'), CONCAT(CURDATE() - INTERVAL 3 DAY, ' 16:30:00'), 'Late', 7.75),
(6, CURDATE() - INTERVAL 3 DAY, NULL, NULL, 'On Leave', 0),
(7, CURDATE() - INTERVAL 3 DAY, CONCAT(CURDATE() - INTERVAL 3 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 3 DAY, ' 17:00:00'), 'Present', 8.00),
(8, CURDATE() - INTERVAL 3 DAY, CONCAT(CURDATE() - INTERVAL 3 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 3 DAY, ' 17:00:00'), 'Present', 8.00),
(9, CURDATE() - INTERVAL 3 DAY, CONCAT(CURDATE() - INTERVAL 3 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 3 DAY, ' 17:00:00'), 'Present', 8.00),
(10, CURDATE() - INTERVAL 3 DAY, CONCAT(CURDATE() - INTERVAL 3 DAY, ' 10:00:00'), CONCAT(CURDATE() - INTERVAL 3 DAY, ' 18:00:00'), 'Present', 8.00),

-- Day 6 (2 days ago)
(1, CURDATE() - INTERVAL 2 DAY, CONCAT(CURDATE() - INTERVAL 2 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 2 DAY, ' 17:00:00'), 'Present', 8.00),
(2, CURDATE() - INTERVAL 2 DAY, CONCAT(CURDATE() - INTERVAL 2 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 2 DAY, ' 17:00:00'), 'Present', 8.00),
(3, CURDATE() - INTERVAL 2 DAY, CONCAT(CURDATE() - INTERVAL 2 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 2 DAY, ' 17:00:00'), 'Present', 8.00),
(4, CURDATE() - INTERVAL 2 DAY, CONCAT(CURDATE() - INTERVAL 2 DAY, ' 08:30:00'), CONCAT(CURDATE() - INTERVAL 2 DAY, ' 16:30:00'), 'Present', 8.00),
(5, CURDATE() - INTERVAL 2 DAY, CONCAT(CURDATE() - INTERVAL 2 DAY, ' 08:30:00'), CONCAT(CURDATE() - INTERVAL 2 DAY, ' 16:30:00'), 'Present', 8.00),
(6, CURDATE() - INTERVAL 2 DAY, CONCAT(CURDATE() - INTERVAL 2 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 2 DAY, ' 17:00:00'), 'Present', 8.00),
(7, CURDATE() - INTERVAL 2 DAY, CONCAT(CURDATE() - INTERVAL 2 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 2 DAY, ' 17:00:00'), 'Present', 8.00),
(8, CURDATE() - INTERVAL 2 DAY, CONCAT(CURDATE() - INTERVAL 2 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 2 DAY, ' 17:00:00'), 'Present', 8.00),
(9, CURDATE() - INTERVAL 2 DAY, CONCAT(CURDATE() - INTERVAL 2 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 2 DAY, ' 17:00:00'), 'Present', 8.00),
(10, CURDATE() - INTERVAL 2 DAY, CONCAT(CURDATE() - INTERVAL 2 DAY, ' 10:00:00'), CONCAT(CURDATE() - INTERVAL 2 DAY, ' 18:00:00'), 'Present', 8.00),

-- Day 7 (yesterday)
(1, CURDATE() - INTERVAL 1 DAY, CONCAT(CURDATE() - INTERVAL 1 DAY, ' 08:55:00'), CONCAT(CURDATE() - INTERVAL 1 DAY, ' 17:00:00'), 'Present', 8.08),
(2, CURDATE() - INTERVAL 1 DAY, CONCAT(CURDATE() - INTERVAL 1 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 1 DAY, ' 17:00:00'), 'Present', 8.00),
(3, CURDATE() - INTERVAL 1 DAY, CONCAT(CURDATE() - INTERVAL 1 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 1 DAY, ' 17:00:00'), 'Present', 8.00),
(4, CURDATE() - INTERVAL 1 DAY, CONCAT(CURDATE() - INTERVAL 1 DAY, ' 08:30:00'), CONCAT(CURDATE() - INTERVAL 1 DAY, ' 16:30:00'), 'Present', 8.00),
(5, CURDATE() - INTERVAL 1 DAY, CONCAT(CURDATE() - INTERVAL 1 DAY, ' 08:30:00'), CONCAT(CURDATE() - INTERVAL 1 DAY, ' 16:30:00'), 'Present', 8.00),
(6, CURDATE() - INTERVAL 1 DAY, CONCAT(CURDATE() - INTERVAL 1 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 1 DAY, ' 17:00:00'), 'Present', 8.00),
(7, CURDATE() - INTERVAL 1 DAY, CONCAT(CURDATE() - INTERVAL 1 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 1 DAY, ' 17:00:00'), 'Present', 8.00),
(8, CURDATE() - INTERVAL 1 DAY, CONCAT(CURDATE() - INTERVAL 1 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 1 DAY, ' 17:00:00'), 'Present', 8.00),
(9, CURDATE() - INTERVAL 1 DAY, CONCAT(CURDATE() - INTERVAL 1 DAY, ' 09:00:00'), CONCAT(CURDATE() - INTERVAL 1 DAY, ' 17:00:00'), 'Present', 8.00),
(10, CURDATE() - INTERVAL 1 DAY, CONCAT(CURDATE() - INTERVAL 1 DAY, ' 10:00:00'), CONCAT(CURDATE() - INTERVAL 1 DAY, ' 18:00:00'), 'Present', 8.00);

-- Insert Leave Requests
INSERT INTO leave_requests (employee_id, leave_type, start_date, end_date, days_count, reason, status, approved_by, approved_at) VALUES
(3, 'Sick Leave', CURDATE() - INTERVAL 6 DAY, CURDATE() - INTERVAL 6 DAY, 1, 'Medical appointment', 'Approved', 2, CONCAT(CURDATE() - INTERVAL 7 DAY, ' 15:30:00')),
(6, 'Vacation', CURDATE() - INTERVAL 4 DAY, CURDATE() - INTERVAL 3 DAY, 2, 'Family vacation', 'Approved', 6, CONCAT(CURDATE() - INTERVAL 10 DAY, ' 10:00:00')),
(5, 'Personal', CURDATE() + INTERVAL 5 DAY, CURDATE() + INTERVAL 7 DAY, 3, 'Personal matters', 'Pending', NULL, NULL),
(8, 'Vacation', CURDATE() + INTERVAL 15 DAY, CURDATE() + INTERVAL 19 DAY, 5, 'Planned vacation', 'Pending', NULL, NULL);

-- ========================================
-- USEFUL VIEWS
-- ========================================

-- View: Employee Attendance Summary
CREATE OR REPLACE VIEW v_employee_attendance_summary AS
SELECT 
  e.employee_id,
  CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
  e.email,
  d.department_name,
  e.position,
  COUNT(CASE WHEN ar.status = 'Present' THEN 1 END) AS days_present,
  COUNT(CASE WHEN ar.status = 'Late' THEN 1 END) AS days_late,
  COUNT(CASE WHEN ar.status = 'Absent' THEN 1 END) AS days_absent,
  COUNT(CASE WHEN ar.status = 'Half-day' THEN 1 END) AS days_half_day,
  COUNT(CASE WHEN ar.status = 'On Leave' THEN 1 END) AS days_on_leave,
  ROUND(AVG(ar.work_hours), 2) AS avg_work_hours,
  ROUND(SUM(ar.work_hours), 2) AS total_work_hours
FROM employees e
LEFT JOIN departments d ON e.department_id = d.department_id
LEFT JOIN attendance_records ar ON e.employee_id = ar.employee_id
  AND ar.attendance_date >= CURDATE() - INTERVAL 30 DAY
WHERE e.status = 'Active'
GROUP BY e.employee_id, employee_name, e.email, d.department_name, e.position;

-- View: Today's Attendance
CREATE OR REPLACE VIEW v_todays_attendance AS
SELECT 
  e.employee_id,
  CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
  d.department_name,
  e.position,
  ar.check_in_time,
  ar.check_out_time,
  ar.status,
  ar.work_hours,
  CASE 
    WHEN ar.check_in_time IS NULL THEN 'Not Checked In'
    WHEN ar.check_out_time IS NULL THEN 'Checked In'
    ELSE 'Checked Out'
  END AS current_status
FROM employees e
LEFT JOIN departments d ON e.department_id = d.department_id
LEFT JOIN attendance_records ar ON e.employee_id = ar.employee_id
  AND ar.attendance_date = CURDATE()
WHERE e.status = 'Active'
ORDER BY ar.check_in_time;

-- View: Department Attendance Stats
CREATE OR REPLACE VIEW v_department_attendance_stats AS
SELECT 
  d.department_id,
  d.department_name,
  COUNT(DISTINCT e.employee_id) AS total_employees,
  COUNT(CASE WHEN ar.status IN ('Present', 'Late') AND ar.attendance_date = CURDATE() THEN 1 END) AS present_today,
  COUNT(CASE WHEN ar.status = 'Absent' AND ar.attendance_date = CURDATE() THEN 1 END) AS absent_today,
  COUNT(CASE WHEN ar.status = 'On Leave' AND ar.attendance_date = CURDATE() THEN 1 END) AS on_leave_today,
  ROUND(
    (COUNT(CASE WHEN ar.status IN ('Present', 'Late') AND ar.attendance_date = CURDATE() THEN 1 END) * 100.0) / 
    NULLIF(COUNT(DISTINCT e.employee_id), 0), 
    2
  ) AS attendance_rate_percent
FROM departments d
LEFT JOIN employees e ON d.department_id = e.department_id AND e.status = 'Active'
LEFT JOIN attendance_records ar ON e.employee_id = ar.employee_id
GROUP BY d.department_id, d.department_name;

-- ========================================
-- USEFUL STORED PROCEDURES
-- ========================================

DELIMITER $$

-- Procedure: Check In Employee
CREATE PROCEDURE sp_check_in_employee(
  IN p_employee_id INT,
  IN p_check_in_time DATETIME
)
BEGIN
  DECLARE v_shift_start TIME;
  DECLARE v_attendance_status VARCHAR(20);
  
  -- Get employee shift start time
  SELECT shift_start INTO v_shift_start
  FROM employees
  WHERE employee_id = p_employee_id;
  
  -- Determine status (Late if more than 15 minutes after shift start)
  IF TIME(p_check_in_time) > ADDTIME(v_shift_start, '00:15:00') THEN
    SET v_attendance_status = 'Late';
  ELSE
    SET v_attendance_status = 'Present';
  END IF;
  
  -- Insert or update attendance record
  INSERT INTO attendance_records (employee_id, attendance_date, check_in_time, status)
  VALUES (p_employee_id, DATE(p_check_in_time), p_check_in_time, v_attendance_status)
  ON DUPLICATE KEY UPDATE 
    check_in_time = p_check_in_time,
    status = v_attendance_status;
    
  SELECT 'Check-in successful' AS message, v_attendance_status AS status;
END$$

-- Procedure: Check Out Employee
CREATE PROCEDURE sp_check_out_employee(
  IN p_employee_id INT,
  IN p_check_out_time DATETIME
)
BEGIN
  DECLARE v_check_in_time DATETIME;
  DECLARE v_work_hours DECIMAL(5,2);
  
  -- Get check-in time
  SELECT check_in_time INTO v_check_in_time
  FROM attendance_records
  WHERE employee_id = p_employee_id 
    AND attendance_date = DATE(p_check_out_time);
  
  -- Calculate work hours
  IF v_check_in_time IS NOT NULL THEN
    SET v_work_hours = TIMESTAMPDIFF(MINUTE, v_check_in_time, p_check_out_time) / 60.0;
    
    -- Update attendance record
    UPDATE attendance_records
    SET check_out_time = p_check_out_time,
        work_hours = v_work_hours
    WHERE employee_id = p_employee_id 
      AND attendance_date = DATE(p_check_out_time);
      
    SELECT 'Check-out successful' AS message, v_work_hours AS work_hours;
  ELSE
    SELECT 'Error: Employee has not checked in today' AS message;
  END IF;
END$$

-- Procedure: Get Employee Attendance Report
CREATE PROCEDURE sp_employee_attendance_report(
  IN p_employee_id INT,
  IN p_start_date DATE,
  IN p_end_date DATE
)
BEGIN
  SELECT 
    ar.attendance_date,
    ar.check_in_time,
    ar.check_out_time,
    ar.status,
    ar.work_hours,
    ar.notes
  FROM attendance_records ar
  WHERE ar.employee_id = p_employee_id
    AND ar.attendance_date BETWEEN p_start_date AND p_end_date
  ORDER BY ar.attendance_date DESC;
END$$

DELIMITER ;

-- ========================================
-- COMPLETION MESSAGE
-- ========================================

SELECT 'Employee Attendance Database created successfully!' AS Status;
SELECT 'Database: employee_attendance_db' AS Info;
SELECT COUNT(*) AS 'Total Employees' FROM employees;
SELECT COUNT(*) AS 'Total Departments' FROM departments;
SELECT COUNT(*) AS 'Total Attendance Records' FROM attendance_records;
SELECT COUNT(*) AS 'Total Leave Requests' FROM leave_requests;

-- Display sample queries
SELECT '
========================================
SAMPLE QUERIES TO GET STARTED:
========================================

1. View all employees:
   SELECT * FROM employees;

2. View today''s attendance:
   SELECT * FROM v_todays_attendance;

3. View employee attendance summary:
   SELECT * FROM v_employee_attendance_summary;

4. View department statistics:
   SELECT * FROM v_department_attendance_stats;

5. Check in an employee (using stored procedure):
   CALL sp_check_in_employee(1, NOW());

6. Check out an employee (using stored procedure):
   CALL sp_check_out_employee(1, NOW());

7. Get employee attendance report:
   CALL sp_employee_attendance_report(1, CURDATE() - INTERVAL 30 DAY, CURDATE());

8. View pending leave requests:
   SELECT * FROM leave_requests WHERE status = ''Pending'';

========================================
' AS 'Quick Reference Guide';
