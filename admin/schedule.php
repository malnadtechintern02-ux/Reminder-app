<?php
session_start();
if (!isset($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
    header("Location: login.php");
    exit;
}

require_once '../api/db.php';

$filter = $_GET['filter'] ?? 'upcoming';

$query = "SELECT r.*, u.username FROM reminders r JOIN users u ON r.user_id = u.id";
if ($filter === 'today') {
    $query .= " WHERE DATE(r.scheduled_at) = CURDATE()";
} elseif ($filter === 'upcoming') {
    $query .= " WHERE r.scheduled_at > CURDATE()";
} elseif ($filter === 'completed') {
    $query .= " WHERE r.is_completed = 1";
} elseif ($filter === 'missed') {
    $query .= " WHERE r.scheduled_at < NOW() AND r.is_completed = 0";
}

$query .= " ORDER BY r.scheduled_at ASC";

$schedules = $pdo->query($query)->fetchAll();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Schedule Management - Admin Panel</title>
    <link rel="stylesheet" href="style.css">
    <style>
        .filter-nav { margin-bottom: 20px; display: flex; gap: 10px; }
        .filter-nav a {
            padding: 8px 16px; border-radius: 20px; text-decoration: none; 
            font-size: 14px; font-weight: 500; background: #F1F5F9; color: #475569;
        }
        .filter-nav a.active { background: var(--primary); color: #fff; }
    </style>
</head>
<body>
    <div class="sidebar">
        <div class="sidebar-header">FocusDay Admin</div>
        <div class="sidebar-nav">
            <a href="index.php">Dashboard</a>
            <a href="users.php">Users</a>
            <a href="reminders.php">Reminders</a>
            <a href="schedule.php" class="active">Schedule</a>
            <a href="categories.php">Categories</a>
            <a href="priorities.php">Priorities</a>
            <a href="pomodoro.php">Pomodoro</a>
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
            <h1>Schedule Management</h1>
        </div>

        <div class="filter-nav">
            <a href="?filter=today" class="<?= $filter === 'today' ? 'active' : '' ?>">Today</a>
            <a href="?filter=upcoming" class="<?= $filter === 'upcoming' ? 'active' : '' ?>">Upcoming</a>
            <a href="?filter=completed" class="<?= $filter === 'completed' ? 'active' : '' ?>">Completed</a>
            <a href="?filter=missed" class="<?= $filter === 'missed' ? 'active' : '' ?>">Missed</a>
        </div>

        <div class="card">
            <table class="table">
                <thead>
                    <tr>
                        <th>Date & Time</th>
                        <th>Title</th>
                        <th>User</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($schedules)): ?>
                        <tr><td colspan="4">No schedules found for this filter.</td></tr>
                    <?php else: ?>
                        <?php foreach ($schedules as $s): ?>
                        <tr>
                            <td><?= date('M j, Y H:i', strtotime($s['scheduled_at'])) ?></td>
                            <td>
                                <strong><?= htmlspecialchars($s['title']) ?></strong>
                                <div style="font-size:12px; color:var(--text-muted);"><?= htmlspecialchars($s['category_id']) ?> | <?= htmlspecialchars($s['priority']) ?></div>
                            </td>
                            <td><?= htmlspecialchars($s['username']) ?></td>
                            <td>
                                <?php if ($s['is_completed']): ?>
                                    <span class="badge active">Completed</span>
                                <?php elseif (strtotime($s['scheduled_at']) < time()): ?>
                                    <span class="badge inactive">Missed</span>
                                <?php else: ?>
                                    <span class="badge" style="background:#FEF3C7; color:#D97706;">Pending</span>
                                <?php endif; ?>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
