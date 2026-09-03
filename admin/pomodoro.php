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
        'pomodoro_focus' => $_POST['pomodoro_focus'] ?? '25',
        'pomodoro_short_break' => $_POST['pomodoro_short_break'] ?? '5',
        'pomodoro_long_break' => $_POST['pomodoro_long_break'] ?? '15'
    ];
    
    foreach ($settings as $key => $val) {
        $stmt->execute([$val, $key]);
    }
    
    log_admin_action($pdo, "Updated Pomodoro Settings", "Defaults changed");
    $message = "Pomodoro default settings updated successfully.";
}

// Fetch current settings
$stmt = $pdo->query("SELECT setting_key, setting_value FROM app_settings WHERE setting_key LIKE 'pomodoro_%'");
$current = [];
while ($row = $stmt->fetch()) {
    $current[$row['setting_key']] = $row['setting_value'];
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pomodoro Settings - Admin Panel</title>
    <link rel="stylesheet" href="style.css">
    <style>
        .form-group { margin-bottom: 20px; }
        .form-group label { display: block; margin-bottom: 8px; font-weight: 500; }
        .form-group input {
            width: 100%; padding: 12px; border: 1px solid var(--border);
            border-radius: 8px; box-sizing: border-box; font-family: inherit;
        }
        .success-msg {
            background-color: rgba(16, 185, 129, 0.1); color: #10B981;
            padding: 12px; border-radius: 8px; margin-bottom: 20px;
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
            <a href="pomodoro.php" class="active">Pomodoro</a>
            <a href="notifications.php">Notifications</a>
            <a href="pages.php">Pages</a>
            <a href="faqs.php">FAQs</a>
            <a href="settings.php">Settings</a>
            <a href="audit.php">Audit Log</a>
            <a href="logout.php" style="color: var(--danger); margin-top: auto;">Logout</a>
        </div>
    </div>

    <div class="main-content">
        <div class="header">
            <h1>Pomodoro Defaults</h1>
        </div>

        <div class="card" style="max-width: 600px;">
            <?php if ($message): ?>
                <div class="success-msg"><?= htmlspecialchars($message) ?></div>
            <?php endif; ?>
            <form method="POST">
                <div class="form-group">
                    <label>Focus Duration (Minutes)</label>
                    <input type="number" name="pomodoro_focus" value="<?= htmlspecialchars($current['pomodoro_focus'] ?? '25') ?>" required>
                </div>
                <div class="form-group">
                    <label>Short Break Duration (Minutes)</label>
                    <input type="number" name="pomodoro_short_break" value="<?= htmlspecialchars($current['pomodoro_short_break'] ?? '5') ?>" required>
                </div>
                <div class="form-group">
                    <label>Long Break Duration (Minutes)</label>
                    <input type="number" name="pomodoro_long_break" value="<?= htmlspecialchars($current['pomodoro_long_break'] ?? '15') ?>" required>
                </div>
                <button type="submit" class="btn btn-primary">Save Settings</button>
            </form>
        </div>
    </div>
</body>
</html>
