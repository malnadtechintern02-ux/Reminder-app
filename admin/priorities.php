<?php
session_start();
if (!isset($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
    header("Location: login.php");
    exit;
}

require_once '../api/db.php';

$message = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['action'])) {
        if ($_POST['action'] === 'add') {
            $stmt = $pdo->prepare("INSERT INTO priorities (name, level, status) VALUES (?, ?, ?)");
            $stmt->execute([
                $_POST['name'],
                $_POST['level'] ?: 0,
                isset($_POST['status']) ? 1 : 0
            ]);
            log_admin_action($pdo, "Created Priority", $_POST['name']);
            $message = "Priority added successfully.";
        } elseif ($_POST['action'] === 'delete') {
            $stmt = $pdo->prepare("SELECT name FROM priorities WHERE id = ?");
            $stmt->execute([$_POST['id']]);
            $p = $stmt->fetch();
            
            $stmt = $pdo->prepare("DELETE FROM priorities WHERE id = ?");
            $stmt->execute([$_POST['id']]);
            log_admin_action($pdo, "Deleted Priority", $p['name'] ?? "ID: ".$_POST['id']);
            $message = "Priority deleted successfully.";
        }
    }
}

$priorities = $pdo->query("SELECT * FROM priorities ORDER BY level ASC")->fetchAll();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Priorities - Admin Panel</title>
    <link rel="stylesheet" href="style.css">
    <style>
        .form-group { margin-bottom: 20px; }
        .form-group label { display: block; margin-bottom: 8px; font-weight: 500; }
        .form-group input[type="text"], .form-group input[type="number"] {
            width: 100%; padding: 12px; border: 1px solid var(--border);
            border-radius: 8px; box-sizing: border-box; font-family: inherit;
        }
        .success-msg {
            background-color: rgba(16, 185, 129, 0.1); color: #10B981;
            padding: 12px; border-radius: 8px; margin-bottom: 20px;
        }
        .add-form { background: #fff; padding: 20px; border-radius: 8px; border: 1px solid var(--border); margin-bottom: 30px; display: none; }
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
            <a href="priorities.php" class="active">Priorities</a>
            <a href="pomodoro.php">Pomodoro</a>
            <a href="notifications.php">Notifications</a>
            <a href="ringtones.php">Ringtones</a>
            <a href="pages.php">Pages</a>
            <a href="faqs.php">FAQs</a>
            <a href="settings.php">Settings</a>
            <a href="audit.php">Audit Log</a>
            <a href="logout.php" style="color: var(--danger); margin-top: auto;">Logout</a>
        </div>
    </div>

    <div class="main-content">
        <div class="header">
            <h1>Manage Priorities</h1>
            <button class="btn btn-primary" onclick="document.getElementById('add-form').style.display='block'">+ Add Priority</button>
        </div>

        <?php if ($message): ?>
            <div class="success-msg"><?= htmlspecialchars($message) ?></div>
        <?php endif; ?>

        <!-- Add Form -->
        <div id="add-form" class="add-form">
            <h2>Add New Priority</h2>
            <form method="POST">
                <input type="hidden" name="action" value="add">
                <div class="form-group">
                    <label>Priority Name</label>
                    <input type="text" name="name" required>
                </div>
                <div class="form-group">
                    <label>Level (Higher = more urgent)</label>
                    <input type="number" name="level" value="1">
                </div>
                <div class="form-group">
                    <label>Active Status</label>
                    <input type="checkbox" name="status" checked style="width: 20px; height: 20px;">
                </div>
                <button type="submit" class="btn btn-primary">Save Priority</button>
                <button type="button" class="btn" onclick="document.getElementById('add-form').style.display='none'">Cancel</button>
            </form>
        </div>

        <div class="card">
            <table class="table">
                <thead>
                    <tr>
                        <th>Level</th>
                        <th>Name</th>
                        <th>Status</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($priorities as $p): ?>
                    <tr>
                        <td><?= $p['level'] ?></td>
                        <td><strong><?= htmlspecialchars($p['name']) ?></strong></td>
                        <td>
                            <?= $p['status'] ? '<span class="badge active">Active</span>' : '<span class="badge inactive">Disabled</span>' ?>
                        </td>
                        <td>
                            <form method="POST" onsubmit="return confirm('Delete this priority?');" style="display:inline;">
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="id" value="<?= $p['id'] ?>">
                                <button type="submit" class="btn btn-danger" style="font-size:12px; padding:6px 12px;">Delete</button>
                            </form>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
