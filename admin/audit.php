<?php
session_start();
if (!isset($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
    header("Location: login.php");
    exit;
}

require_once '../api/db.php';

$logs = $pdo->query("SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 100")->fetchAll();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Audit Logs - Admin Panel</title>
    <link rel="stylesheet" href="style.css">
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
            <a href="pages.php">Pages</a>
            <a href="faqs.php">FAQs</a>
            <a href="settings.php">Settings</a>
            <a href="audit.php" class="active">Audit Log</a>
            <a href="logout.php" style="color: var(--danger); margin-top: auto;">Logout</a>
        </div>
    </div>

    <div class="main-content">
        <div class="header">
            <h1>Audit Logs</h1>
        </div>

        <div class="card">
            <table class="table">
                <thead>
                    <tr>
                        <th>Date & Time</th>
                        <th>Action</th>
                        <th>Affected Item</th>
                        <th>Admin ID</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($logs)): ?>
                        <tr><td colspan="4">No logs recorded yet.</td></tr>
                    <?php else: ?>
                        <?php foreach ($logs as $log): ?>
                        <tr>
                            <td><?= date('M j, Y H:i:s', strtotime($log['created_at'])) ?></td>
                            <td><strong><?= htmlspecialchars($log['action']) ?></strong></td>
                            <td><?= htmlspecialchars($log['affected_item'] ?? '-') ?></td>
                            <td><?= htmlspecialchars($log['admin_id'] ?? 'System') ?></td>
                        </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
