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

CREATE TABLE IF NOT EXISTS ringtones (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ringtone_id VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    type ENUM('built_in', 'uploaded') DEFAULT 'built_in',
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(255) NOT NULL,
    file_size INT DEFAULT 0,
    duration VARCHAR(20) DEFAULT '0:03',
    status TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
";

try {
    $pdo->exec($sql);
    
    // Check if status column exists in users table
    $stmt = $pdo->query("SHOW COLUMNS FROM users LIKE 'status'");
    if ($stmt->rowCount() == 0) {
        $pdo->exec("ALTER TABLE users ADD COLUMN status TINYINT(1) DEFAULT 1");
    }

    // Check if ringtone column exists in reminders table
    $stmt = $pdo->query("SHOW COLUMNS FROM reminders LIKE 'ringtone'");
    if ($stmt->rowCount() == 0) {
        $pdo->exec("ALTER TABLE reminders ADD COLUMN ringtone VARCHAR(100) DEFAULT 'morning_breeze'");
    }

    // Insert Default Pomodoro and Notification Settings
    $pdo->exec("INSERT IGNORE INTO app_settings (setting_key, setting_value) VALUES 
        ('pomodoro_focus', '25'),
        ('pomodoro_short_break', '5'),
        ('pomodoro_long_break', '15'),
        ('notification_global', '1'),
        ('notification_sound', '1'),
        ('notification_vibration', '1'),
        ('notification_warning', '1'),
        ('default_ringtone', 'morning_breeze')");

    // Insert default categories and priorities if empty
    $stmt = $pdo->query("SELECT COUNT(*) FROM categories");
    if ($stmt->fetchColumn() == 0) {
        $pdo->exec("INSERT INTO categories (name, icon) VALUES ('Work', 'work'), ('Personal', 'person'), ('Study', 'book'), ('Health', 'favorite')");
    }

    $stmt = $pdo->query("SELECT COUNT(*) FROM priorities");
    if ($stmt->fetchColumn() == 0) {
        $pdo->exec("INSERT INTO priorities (name, level) VALUES ('Low', 1), ('Medium', 2), ('High', 3), ('Urgent', 4)");
    }

    // Seed 12 modern built-in ringtones if empty
    $stmt = $pdo->query("SELECT COUNT(*) FROM ringtones WHERE type = 'built_in'");
    if ($stmt->fetchColumn() == 0) {
        $builtInRingtones = [
            ['morning_breeze', 'Morning Breeze', 'Smooth ambient marimba wake-up sound', 'morning_breeze.mp3', 'assets/sounds/morning_breeze.mp3', 282284, '0:03'],
            ['soft_sunrise', 'Soft Sunrise', 'Gentle acoustic chord swell', 'soft_sunrise.mp3', 'assets/sounds/soft_sunrise.mp3', 282284, '0:03'],
            ['bright_morning', 'Bright Morning', 'Uplifting pentatonic morning chime', 'bright_morning.mp3', 'assets/sounds/bright_morning.mp3', 282284, '0:03'],
            ['gentle_wake', 'Gentle Wake', 'Calming chime sequence', 'gentle_wake.mp3', 'assets/sounds/gentle_wake.mp3', 282284, '0:03'],
            ['happy_start', 'Happy Start', 'Upbeat major 7th chime', 'happy_start.mp3', 'assets/sounds/happy_start.mp3', 282284, '0:03'],
            ['fresh_day', 'Fresh Day', 'Modern synth pop chime', 'fresh_day.mp3', 'assets/sounds/fresh_day.mp3', 282284, '0:03'],
            ['digital_pulse', 'Digital Pulse', 'Crisp modern electronic pulse', 'digital_pulse.mp3', 'assets/sounds/digital_pulse.mp3', 282284, '0:03'],
            ['calm_bell', 'Calm Bell', 'Crystal clear glass bell toll', 'calm_bell.mp3', 'assets/sounds/calm_bell.mp3', 282284, '0:03'],
            ['energy_wake', 'Energy Wake', 'Dynamic rising energy motif', 'energy_wake.mp3', 'assets/sounds/energy_wake.mp3', 282284, '0:03'],
            ['daily_beat', 'Daily Beat', 'Rhythmic modern chime', 'daily_beat.mp3', 'assets/sounds/daily_beat.mp3', 282284, '0:03'],
            ['focus_start', 'Focus Start', 'Ambient warm synth chord', 'focus_start.mp3', 'assets/sounds/focus_start.mp3', 282284, '0:03'],
            ['classic_modern', 'Classic Modern', 'Refined modern telephone chime', 'classic_modern.mp3', 'assets/sounds/classic_modern.mp3', 282284, '0:03'],
        ];

        $insStmt = $pdo->prepare("INSERT INTO ringtones (ringtone_id, name, description, type, file_name, file_path, file_size, duration, status) VALUES (?, ?, ?, 'built_in', ?, ?, ?, ?, 1)");
        foreach ($builtInRingtones as $rt) {
            $insStmt->execute($rt);
        }
    }

    echo "Schema updated successfully with Ringtone management support.";
} catch (PDOException $e) {
    echo "Error: " . $e->getMessage();
}
