<?php
session_start();
if (!isset($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
    header("Location: login.php");
    exit;
}

require_once '../api/db.php';

// Fetch stats
$usersCount = $pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
$activeUsers = $pdo->query("SELECT COUNT(*) FROM users WHERE status = 1")->fetchColumn();
$remindersCount = $pdo->query("SELECT COUNT(*) FROM reminders")->fetchColumn();
$completedCount = $pdo->query("SELECT COUNT(*) FROM reminders WHERE is_completed = 1")->fetchColumn();
$pendingCount = $pdo->query("SELECT COUNT(*) FROM reminders WHERE is_completed = 0 AND scheduled_at >= NOW()")->fetchColumn();
$missedCount = $pdo->query("SELECT COUNT(*) FROM reminders WHERE is_completed = 0 AND scheduled_at < NOW()")->fetchColumn();
$todayCount = $pdo->query("SELECT COUNT(*) FROM reminders WHERE DATE(scheduled_at) = CURDATE()")->fetchColumn();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard - Admin Panel</title>
    <link rel="stylesheet" href="style.css">
    <style>
        .stats-grid-large { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card-sm { background: var(--card-bg); padding: 20px; border-radius: 12px; border: 1px solid var(--border); }
        .stat-card-sm .val { font-size: 28px; font-weight: 700; color: var(--primary); margin-top: 5px; }
        .stat-card-sm .lbl { font-size: 14px; color: var(--text-muted); font-weight: 500; }
    </style>
</head>
<body>
    <div class="sidebar">
        <div class="sidebar-header">Time Bell Admin</div>
        <div class="sidebar-nav">
            <a href="index.php" class="active">Dashboard</a>
            <a href="users.php">Users</a>
            <a href="reminders.php">Reminders</a>
            <a href="schedule.php">Schedule</a>
            <a href="categories.php">Categories</a>
            <a href="priorities.php">Priorities</a>
            <a href="pomodoro.php">Pomodoro</a>
            <a href="notifications.php">Notifications</a>
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
            <h1>Dashboard Overview</h1>
        </div>

        <div class="stats-grid-large">
            <div class="stat-card-sm"><div class="lbl">Total Users</div><div class="val"><?= number_format($usersCount) ?></div></div>
            <div class="stat-card-sm"><div class="lbl">Active Users</div><div class="val"><?= number_format($activeUsers) ?></div></div>
            <div class="stat-card-sm"><div class="lbl">Total Reminders</div><div class="val"><?= number_format($remindersCount) ?></div></div>
            <div class="stat-card-sm"><div class="lbl">Completed Reminders</div><div class="val"><?= number_format($completedCount) ?></div></div>
            <div class="stat-card-sm"><div class="lbl">Pending Reminders</div><div class="val" style="color:#D97706;"><?= number_format($pendingCount) ?></div></div>
            <div class="stat-card-sm"><div class="lbl">Missed Reminders</div><div class="val" style="color:var(--danger);"><?= number_format($missedCount) ?></div></div>
            <div class="stat-card-sm"><div class="lbl">Today's Reminders</div><div class="val" style="color:#10B981;"><?= number_format($todayCount) ?></div></div>
        </div>

        <div class="card">
            <h2 style="margin-top:0;">Recent Activity (Audit)</h2>
            <table class="table">
                <thead>
                    <tr>
                        <th>Date & Time</th>
                        <th>Action</th>
                        <th>Item</th>
                    </tr>
                </thead>
                <tbody>
                    <?php
                    $recentActivity = $pdo->query("SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 5")->fetchAll();
                    if (empty($recentActivity)): ?>
                        <tr><td colspan="3">No recent activity.</td></tr>
                    <?php else: foreach ($recentActivity as $act): ?>
                        <tr>
                            <td><?= date('M j, Y H:i', strtotime($act['created_at'])) ?></td>
                            <td><?= htmlspecialchars($act['action']) ?></td>
                            <td><?= htmlspecialchars($act['affected_item'] ?? '-') ?></td>
                        </tr>
                    <?php endforeach; endif; ?>
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
