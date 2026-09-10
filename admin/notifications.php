<?php
session_start();
if (!isset($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
    header("Location: login.php");
    exit;
}

require_once '../api/db.php';

$message = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $stmt = $pdo->prepare("INSERT INTO app_settings (setting_key, setting_value) VALUES (?, ?) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)");
    
    $settings = [
        'notification_global' => isset($_POST['notification_global']) ? '1' : '0',
        'notification_sound' => isset($_POST['notification_sound']) ? '1' : '0',
        'notification_vibration' => isset($_POST['notification_vibration']) ? '1' : '0',
        'notification_warning' => isset($_POST['notification_warning']) ? '1' : '0',
        'default_ringtone' => trim($_POST['default_ringtone'] ?? 'morning_breeze'),
    ];
    
    foreach ($settings as $key => $val) {
        $stmt->execute([$key, $val]);
    }
    
    log_admin_action($pdo, "Updated Notification Settings", "Defaults changed");
    $message = "Notification settings updated successfully.";
}

// Fetch current settings
$stmt = $pdo->query("SELECT setting_key, setting_value FROM app_settings WHERE setting_key LIKE 'notification_%' OR setting_key = 'default_ringtone'");
$current = [];
while ($row = $stmt->fetch()) {
    $current[$row['setting_key']] = $row['setting_value'];
}

// Fetch active ringtones for default selector
$activeRingtones = $pdo->query("SELECT ringtone_id, name, type FROM ringtones WHERE status = 1 ORDER BY type ASC, name ASC")->fetchAll();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Notification Settings - Admin Panel</title>
    <link rel="stylesheet" href="style.css">
    <style>
        .form-group { margin-bottom: 20px; display: flex; align-items: center; justify-content: space-between; }
        .form-group label { font-weight: 500; }
        .form-select { padding: 10px; border-radius: 8px; border: 1px solid var(--border); font-family: inherit; width: 60%; font-size: 14px; background: var(--card-bg); color: var(--text-main); }
        .success-msg {
            background-color: rgba(16, 185, 129, 0.1); color: #10B981;
            padding: 12px; border-radius: 8px; margin-bottom: 20px;
        }
        .help-text { font-size: 13px; color: var(--text-muted); margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="sidebar">
        <div class="sidebar-header">Time Bell Admin</div>
        <div class="sidebar-nav">
            <a href="index.php">Dashboard</a>
            <a href="users.php">Users</a>
            <a href="reminders.php">Reminders</a>
            <a href="schedule.php">Schedule</a>
            <a href="categories.php">Categories</a>
            <a href="priorities.php">Priorities</a>
            <a href="pomodoro.php">Pomodoro</a>
            <a href="notifications.php" class="active">Notifications</a>
            <a href="ringtones.php">Ringtones</a>
            <a href="analytics.php">Analytics</a>
            <a href="pages.php">Pages</a>
            <a href="faqs.php">FAQs</a>
            <a href="settings.php">Settings</a>
            <a href="audit.php">Audit Log</a>
            <a href="logout.php" style="color: var(--danger); margin-top: auto;">Logout</a>
        </div>
    </div>

    <div class="main-content">
        <div class="header">
            <h1>Global Notification & Alarm Settings</h1>
        </div>

        <div class="card" style="max-width: 600px;">
            <?php if ($message): ?>
                <div class="success-msg"><?= htmlspecialchars($message) ?></div>
            <?php endif; ?>
            <p class="help-text">Note: These act as global defaults/overrides. Individual users may still have device-level permissions they need to manage.</p>
            <form method="POST">
                <div class="form-group">
                    <label>Global Notifications</label>
                    <input type="checkbox" name="notification_global" <?= ($current['notification_global'] ?? '1') == '1' ? 'checked' : '' ?> style="width: 20px; height: 20px;">
                </div>
                <div class="form-group">
                    <label>Default Sound ON</label>
                    <input type="checkbox" name="notification_sound" <?= ($current['notification_sound'] ?? '1') == '1' ? 'checked' : '' ?> style="width: 20px; height: 20px;">
                </div>
                <div class="form-group">
                    <label>Default Alarm Ringtone</label>
                    <select name="default_ringtone" class="form-select">
                        <?php foreach ($activeRingtones as $rt): ?>
                            <option value="<?= htmlspecialchars($rt['ringtone_id']) ?>" <?= ($current['default_ringtone'] ?? 'morning_breeze') === $rt['ringtone_id'] ? 'selected' : '' ?>>
                                🎵 <?= htmlspecialchars($rt['name']) ?> (<?= ucfirst($rt['type']) ?>)
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="form-group">
                    <label>Default Vibration ON</label>
                    <input type="checkbox" name="notification_vibration" <?= ($current['notification_vibration'] ?? '1') == '1' ? 'checked' : '' ?> style="width: 20px; height: 20px;">
                </div>
                <div class="form-group">
                    <label>Default 5-Minute Warning</label>
                    <input type="checkbox" name="notification_warning" <?= ($current['notification_warning'] ?? '1') == '1' ? 'checked' : '' ?> style="width: 20px; height: 20px;">
                </div>
                <button type="submit" class="btn btn-primary" style="margin-top: 20px;">Save Settings</button>
            </form>
        </div>
    </div>
</body>
</html>
