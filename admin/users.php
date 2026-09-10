<?php
session_start();
if (!isset($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
    header("Location: login.php");
    exit;
}

require_once '../api/db.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['action'])) {
        if ($_POST['action'] === 'delete' && isset($_POST['id'])) {
            $stmt = $pdo->prepare("SELECT username FROM users WHERE id = ?");
            $stmt->execute([$_POST['id']]);
            $u = $stmt->fetch();
            
            $stmt = $pdo->prepare("DELETE FROM users WHERE id = ?");
            $stmt->execute([$_POST['id']]);
            log_admin_action($pdo, "Deleted User", $u['username'] ?? "ID: ".$_POST['id']);
            header("Location: users.php");
            exit;
        } elseif ($_POST['action'] === 'toggle_status' && isset($_POST['id'])) {
            $stmt = $pdo->prepare("UPDATE users SET status = IF(status=1, 0, 1) WHERE id = ?");
            $stmt->execute([$_POST['id']]);
            log_admin_action($pdo, "Toggled User Status", "ID: ".$_POST['id']);
            header("Location: users.php");
            exit;
        }
    }
}

// Fetch users with their reminder stats
$users = $pdo->query("
    SELECT u.*, 
           (SELECT COUNT(*) FROM reminders r WHERE r.user_id = u.id) as total_reminders,
           (SELECT COUNT(*) FROM reminders r WHERE r.user_id = u.id AND r.is_completed = 1) as completed_reminders,
           (SELECT COUNT(*) FROM reminders r WHERE r.user_id = u.id AND r.is_completed = 0 AND r.scheduled_at >= NOW()) as pending_reminders
    FROM users u 
    ORDER BY u.created_at DESC
")->fetchAll();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Users - Admin Panel</title>
    <link rel="stylesheet" href="style.css">
    <style>
        .stats-badge {
            display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 11px; margin-right: 4px;
        }
        .bg-gray { background: #F1F5F9; color: #475569; }
        .bg-green { background: #D1FAE5; color: #065F46; }
        .bg-yellow { background: #FEF3C7; color: #92400E; }
    </style>
</head>
<body>
    <div class="sidebar">
        <div class="sidebar-header">Time Bell Admin</div>
        <div class="sidebar-nav">
            <a href="index.php">Dashboard</a>
            <a href="users.php" class="active">Users</a>
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
            <h1>Manage Users</h1>
        </div>

        <div class="card" style="overflow-x: auto;">
            <table class="table">
                <thead>
                    <tr>
                        <th>User</th>
                        <th>Status</th>
                        <th>Stats (T/C/P)</th>
                        <th>Joined</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($users as $u): ?>
                    <tr>
                        <td>
                            <strong><?= htmlspecialchars($u['username']) ?></strong>
                            <div style="font-size:12px; color:var(--text-muted);"><?= htmlspecialchars($u['email']) ?></div>
                        </td>
                        <td>
                            <?php if ($u['username'] !== 'admin'): ?>
                                <?= ($u['status'] ?? 1) ? '<span class="badge active">Active</span>' : '<span class="badge inactive">Inactive</span>' ?>
                            <?php else: ?>
                                <span class="badge active">Admin</span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <span class="stats-badge bg-gray" title="Total"><?= $u['total_reminders'] ?></span>
                            <span class="stats-badge bg-green" title="Completed"><?= $u['completed_reminders'] ?></span>
                            <span class="stats-badge bg-yellow" title="Pending"><?= $u['pending_reminders'] ?></span>
                        </td>
                        <td><?= date('M j, Y', strtotime($u['created_at'])) ?></td>
                        <td>
                            <?php if ($u['username'] !== 'admin'): ?>
                                <form method="POST" style="display:inline;">
                                    <input type="hidden" name="action" value="toggle_status">
                                    <input type="hidden" name="id" value="<?= $u['id'] ?>">
                                    <button type="submit" class="btn" style="background: #E2E8F0; color:#0F172A; font-size:12px; padding:6px 12px;">Toggle</button>
                                </form>
                                <form method="POST" onsubmit="return confirm('Delete this user? All their reminders will be lost.');" style="display:inline;">
                                    <input type="hidden" name="action" value="delete">
                                    <input type="hidden" name="id" value="<?= $u['id'] ?>">
                                    <button type="submit" class="btn btn-danger" style="font-size:12px; padding:6px 12px;">Delete</button>
                                </form>
                            <?php else: ?>
                                <span style="font-size:12px; color:var(--text-muted);">No actions</span>
                            <?php endif; ?>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
