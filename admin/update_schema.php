<?php
require_once '../api/db.php';

$sql = "
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

-- Add status column to users if not exists (will throw error if exists, so we catch it gracefully or check first)
";

try {
    $pdo->exec($sql);
    
    // Check if status column exists in users table
    $stmt = $pdo->query("SHOW COLUMNS FROM users LIKE 'status'");
    if ($stmt->rowCount() == 0) {
        $pdo->exec("ALTER TABLE users ADD COLUMN status TINYINT(1) DEFAULT 1");
    }

    // Insert Default Pomodoro Settings
    $pdo->exec("INSERT IGNORE INTO app_settings (setting_key, setting_value) VALUES 
        ('pomodoro_focus', '25'),
        ('pomodoro_short_break', '5'),
        ('pomodoro_long_break', '15'),
        ('notification_global', '1'),
        ('notification_sound', '1'),
        ('notification_vibration', '1'),
        ('notification_warning', '1')");

    // Insert some default categories and priorities if empty
    $stmt = $pdo->query("SELECT COUNT(*) FROM categories");
    if ($stmt->fetchColumn() == 0) {
        $pdo->exec("INSERT INTO categories (name, icon) VALUES ('Work', 'work'), ('Personal', 'person'), ('Study', 'book'), ('Health', 'favorite')");
    }

    $stmt = $pdo->query("SELECT COUNT(*) FROM priorities");
    if ($stmt->fetchColumn() == 0) {
        $pdo->exec("INSERT INTO priorities (name, level) VALUES ('Low', 1), ('Medium', 2), ('High', 3), ('Urgent', 4)");
    }

    echo "Schema updated successfully.";
} catch (PDOException $e) {
    echo "Error: " . $e->getMessage();
}

// Append to database.sql
$schema = "
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
";
file_put_contents('../database.sql', $schema, FILE_APPEND);
