CREATE DATABASE IF NOT EXISTS focusday_db;
USE focusday_db;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reminders (
    id VARCHAR(36) PRIMARY KEY,
    user_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    scheduled_at DATETIME NOT NULL,
    end_time DATETIME,
    category_id VARCHAR(50),
    priority VARCHAR(20) DEFAULT 'low',
    is_completed TINYINT(1) DEFAULT 0,
    is_repeating TINYINT(1) DEFAULT 0,
    repeat_type VARCHAR(20) DEFAULT 'none',
    has_alarm TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Insert a default admin user (password: admin123)
INSERT INTO users (username, email, password_hash) VALUES ('admin', 'admin@focusday.com', '$2y$10$C8.r/Y.o2tV10UjN6kY2/eK22.i9h2T0Q83g140Xh92i0oT1z0XpC') ON DUPLICATE KEY UPDATE id=id;

-- CMS Tables

CREATE TABLE IF NOT EXISTS app_settings (
    setting_key VARCHAR(100) PRIMARY KEY,
    setting_value TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS pages (
    slug VARCHAR(50) PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS faqs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    question VARCHAR(255) NOT NULL,
    answer TEXT NOT NULL,
    status TINYINT(1) DEFAULT 1,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT IGNORE INTO app_settings (setting_key, setting_value) VALUES 
('app_name', 'FocusDay Reminder'),
('contact_email', 'support@focusday.com'),
('contact_phone', '+1234567890');

INSERT IGNORE INTO pages (slug, title, content) VALUES 
('about', 'About Us', 'Welcome to FocusDay Reminder App.'),
('terms', 'Terms & Conditions', 'These are the terms and conditions.'),
('safety', 'Safety Guidelines', 'Please follow these safety guidelines.'),
('help', 'Help Center', 'How can we help you?'),
('disclaimer', 'Disclaimer', 'App disclaimer goes here.');

-- Extended CMS Tables
CREATE TABLE IF NOT EXISTS categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    icon VARCHAR(50) DEFAULT 'folder',
    status TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS priorities (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    level INT DEFAULT 0,
    status TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    admin_id INT NULL,
    action VARCHAR(255) NOT NULL,
    affected_item VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
