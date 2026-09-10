<?php
require_once '../api/db.php';

$sql = "
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
('app_name', 'Time Bell Reminder'),
('contact_email', 'support@timebell.com'),
('contact_phone', '+1234567890');

INSERT IGNORE INTO pages (slug, title, content) VALUES 
('about', 'About Us', 'Welcome to Time Bell Reminder App.'),
('terms', 'Terms & Conditions', 'These are the terms and conditions.'),
('safety', 'Safety Guidelines', 'Please follow these safety guidelines.'),
('help', 'Help Center', 'How can we help you?'),
('disclaimer', 'Disclaimer', 'App disclaimer goes here.');
";

try {
    $pdo->exec($sql);
    echo "Tables created and seeded successfully.";
} catch (PDOException $e) {
    echo "Error: " . $e->getMessage();
}

file_put_contents('../database.sql', "\n-- CMS Tables\n" . $sql, FILE_APPEND);
