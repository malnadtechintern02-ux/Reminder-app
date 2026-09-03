<?php
session_start();
if (!isset($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
    header("Location: login.php");
    exit;
}

require_once '../api/db.php';

$message = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $stmt = $pdo->prepare("UPDATE app_settings SET setting_value = ? WHERE setting_key = ?");
    
    $settings = [
        'app_name' => $_POST['app_name'] ?? '',
        'contact_email' => $_POST['contact_email'] ?? '',
        'contact_phone' => $_POST['contact_phone'] ?? ''
    ];
    
    foreach ($settings as $key => $val) {
        $stmt->execute([$val, $key]);
    }
    
    $message = "Settings updated successfully.";
}

// Fetch current settings
$stmt = $pdo->query("SELECT setting_key, setting_value FROM app_settings");
$current_settings = [];
while ($row = $stmt->fetch()) {
    $current_settings[$row['setting_key']] = $row['setting_value'];
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Settings - Admin Panel</title>
    <link rel="stylesheet" href="style.css">
    <style>
        .form-group {
            margin-bottom: 20px;
        }
        .form-group label {
            display: block;
            margin-bottom: 8px;
            font-weight: 500;
        }
        .form-group input {
            width: 100%;
            padding: 12px;
            border: 1px solid var(--border);
            border-radius: 8px;
            box-sizing: border-box;
            font-family: inherit;
        }
        .form-group input:focus {
            outline: none;
            border-color: var(--primary);
        }
        .success-msg {
            background-color: rgba(16, 185, 129, 0.1);
            color: #10B981;
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="sidebar">
        <div class="sidebar-header">FocusDay Admin</div>
        <div class="sidebar-nav">
            <a href="index.php">Dashboard</a>
            <a href="users.php">Users</a>
            <a href="reminders.php">Reminders</a>
            <a href="schedule.php">Schedule</a>
            <a href="categories.php">Categories</a>
            <a href="priorities.php">Priorities</a>
            <a href="pomodoro.php">Pomodoro</a>
            <a href="notifications.php">Notifications</a>
            <a href="analytics.php">Analytics</a>
            <a href="pages.php">Pages</a>
            <a href="faqs.php">FAQs</a>
            <a href="settings.php" class="active">Settings</a>
            <a href="audit.php">Audit Log</a>
            <a href="logout.php" style="color: var(--danger); margin-top: auto;">Logout</a>
        </div>
    </div>

    <div class="main-content">
        <div class="header">
            <h1>Application Settings</h1>
        </div>

        <div class="card" style="max-width: 600px;">
            <?php if ($message): ?>
                <div class="success-msg"><?= htmlspecialchars($message) ?></div>
            <?php endif; ?>
            <form method="POST">
                <div class="form-group">
                    <label>Application Name</label>
                    <input type="text" name="app_name" value="<?= htmlspecialchars($current_settings['app_name'] ?? '') ?>" required>
                </div>
                <div class="form-group">
                    <label>Contact Email</label>
                    <input type="email" name="contact_email" value="<?= htmlspecialchars($current_settings['contact_email'] ?? '') ?>" required>
                </div>
                <div class="form-group">
                    <label>Contact Phone</label>
                    <input type="text" name="contact_phone" value="<?= htmlspecialchars($current_settings['contact_phone'] ?? '') ?>">
                </div>
                <button type="submit" class="btn btn-primary">Save Settings</button>
            </form>
        </div>
    </div>
</body>
</html>
