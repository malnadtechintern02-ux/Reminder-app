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
            $stmt = $pdo->prepare("SELECT title FROM reminders WHERE id = ?");
            $stmt->execute([$_POST['id']]);
            $r = $stmt->fetch();
            
            $stmt = $pdo->prepare("DELETE FROM reminders WHERE id = ?");
            $stmt->execute([$_POST['id']]);
            log_admin_action($pdo, "Deleted Reminder", $r['title'] ?? "ID: ".$_POST['id']);
            header("Location: reminders.php");
            exit;
        } elseif ($_POST['action'] === 'toggle_complete' && isset($_POST['id'])) {
            $stmt = $pdo->prepare("UPDATE reminders SET is_completed = IF(is_completed=1, 0, 1) WHERE id = ?");
            $stmt->execute([$_POST['id']]);
            log_admin_action($pdo, "Toggled Reminder Completion", "ID: ".$_POST['id']);
            header("Location: reminders.php");
            exit;
        }
    }
}

// Filtering
$search = $_GET['search'] ?? '';
$status = $_GET['status'] ?? 'all';

$query = "SELECT r.*, u.username FROM reminders r JOIN users u ON r.user_id = u.id WHERE 1=1";
$params = [];

if ($search) {
    $query .= " AND (r.title LIKE ? OR u.username LIKE ?)";
    $params[] = "%$search%";
    $params[] = "%$search%";
}

if ($status === 'completed') {
    $query .= " AND r.is_completed = 1";
} elseif ($status === 'pending') {
    $query .= " AND r.is_completed = 0 AND r.scheduled_at >= NOW()";
} elseif ($status === 'missed') {
    $query .= " AND r.is_completed = 0 AND r.scheduled_at < NOW()";
}

$query .= " ORDER BY r.created_at DESC";

$stmt = $pdo->prepare($query);
$stmt->execute($params);
$reminders = $stmt->fetchAll();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reminders - Admin Panel</title>
    <link rel="stylesheet" href="style.css">
    <style>
        .filter-bar { display: flex; gap: 15px; margin-bottom: 20px; flex-wrap: wrap; }
        .filter-bar input[type="text"], .filter-bar select {
            padding: 10px; border: 1px solid var(--border); border-radius: 8px; font-family: inherit;
        }
    </style>
</head>
<body>
    <div class="sidebar">
        <div class="sidebar-header">Time Bell Admin</div>
        <div class="sidebar-nav">
            <a href="index.php">Dashboard</a>
            <a href="users.php">Users</a>
            <a href="reminders.php" class="active">Reminders</a>
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
            <h1>Manage Reminders</h1>
        </div>

        <div class="filter-bar">
            <form method="GET" style="display:flex; gap:10px; width:100%;">
                <input type="text" name="search" placeholder="Search title or user..." value="<?= htmlspecialchars($search) ?>" style="flex-grow:1;">
                <select name="status">
                    <option value="all" <?= $status === 'all' ? 'selected' : '' ?>>All Statuses</option>
                    <option value="pending" <?= $status === 'pending' ? 'selected' : '' ?>>Pending</option>
                    <option value="completed" <?= $status === 'completed' ? 'selected' : '' ?>>Completed</option>
                    <option value="missed" <?= $status === 'missed' ? 'selected' : '' ?>>Missed</option>
                </select>
                <button type="submit" class="btn btn-primary">Filter</button>
            </form>
        </div>

        <div class="card" style="overflow-x: auto;">
            <table class="table">
                <thead>
                    <tr>
                        <th>Title / Category</th>
                        <th>User</th>
                        <th>Scheduled For</th>
                        <th>Status</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($reminders)): ?>
                        <tr><td colspan="5">No reminders found.</td></tr>
                    <?php else: ?>
                        <?php foreach ($reminders as $r): ?>
                        <tr>
                            <td>
                                <strong><?= htmlspecialchars($r['title']) ?></strong>
                                <div style="font-size:12px; color:var(--text-muted);">
                                    <?= htmlspecialchars($r['category_id']) ?> | <?= htmlspecialchars($r['priority']) ?>
                                    <?php if ($r['has_alarm']) echo ' 🔔'; ?>
                                    <?php if ($r['is_repeating']) echo ' 🔄'; ?>
                                    <?php if (!empty($r['ringtone'])): ?>
                                        | 🎵 <?= htmlspecialchars(ucwords(str_replace(['_', '-'], ' ', $r['ringtone']))) ?>
                                    <?php endif; ?>
                                </div>
                            </td>

                            <td><?= htmlspecialchars($r['username']) ?></td>
                            <td><?= date('M j, Y H:i', strtotime($r['scheduled_at'])) ?></td>
                            <td>
                                <?php if ($r['is_completed']): ?>
                                    <span class="badge active">Completed</span>
                                <?php elseif (strtotime($r['scheduled_at']) < time()): ?>
                                    <span class="badge inactive">Missed</span>
                                <?php else: ?>
                                    <span class="badge" style="background:#FEF3C7; color:#D97706;">Pending</span>
                                <?php endif; ?>
                            </td>
                            <td>
                                <form method="POST" style="display:inline;">
                                    <input type="hidden" name="action" value="toggle_complete">
                                    <input type="hidden" name="id" value="<?= $r['id'] ?>">
                                    <button type="submit" class="btn" style="background: #E2E8F0; color:#0F172A; font-size:12px; padding:6px 12px;">Toggle</button>
                                </form>
                                <form method="POST" onsubmit="return confirm('Delete this reminder?');" style="display:inline;">
                                    <input type="hidden" name="action" value="delete">
                                    <input type="hidden" name="id" value="<?= $r['id'] ?>">
                                    <button type="submit" class="btn btn-danger" style="font-size:12px; padding:6px 12px;">Delete</button>
                                </form>
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
