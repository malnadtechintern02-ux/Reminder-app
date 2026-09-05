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
            $stmt = $pdo->prepare("INSERT INTO categories (name, icon, status) VALUES (?, ?, ?)");
            $stmt->execute([
                $_POST['name'],
                $_POST['icon'] ?: 'folder',
                isset($_POST['status']) ? 1 : 0
            ]);
            log_admin_action($pdo, "Created Category", $_POST['name']);
            $message = "Category added successfully.";
        } elseif ($_POST['action'] === 'edit') {
            $stmt = $pdo->prepare("UPDATE categories SET name = ?, icon = ?, status = ? WHERE id = ?");
            $stmt->execute([
                $_POST['name'],
                $_POST['icon'] ?: 'folder',
                isset($_POST['status']) ? 1 : 0,
                $_POST['id']
            ]);
            log_admin_action($pdo, "Updated Category", $_POST['name']);
            $message = "Category updated successfully.";
        } elseif ($_POST['action'] === 'delete') {
            // Get name for logging
            $stmt = $pdo->prepare("SELECT name FROM categories WHERE id = ?");
            $stmt->execute([$_POST['id']]);
            $cat = $stmt->fetch();
            
            $stmt = $pdo->prepare("DELETE FROM categories WHERE id = ?");
            $stmt->execute([$_POST['id']]);
            log_admin_action($pdo, "Deleted Category", $cat['name'] ?? "ID: ".$_POST['id']);
            $message = "Category deleted successfully.";
        }
    }
}

$categories = $pdo->query("SELECT * FROM categories ORDER BY name ASC")->fetchAll();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Categories - Admin Panel</title>
    <link rel="stylesheet" href="style.css">
    <style>
        .form-group { margin-bottom: 20px; }
        .form-group label { display: block; margin-bottom: 8px; font-weight: 500; }
        .form-group input[type="text"] {
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
        <div class="sidebar-header">FocusDay Admin</div>
        <div class="sidebar-nav">
            <a href="index.php">Dashboard</a>
            <a href="users.php">Users</a>
            <a href="reminders.php">Reminders</a>
            <a href="schedule.php">Schedule</a>
            <a href="categories.php" class="active">Categories</a>
            <a href="priorities.php">Priorities</a>
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
            <h1>Manage Categories</h1>
            <button class="btn btn-primary" onclick="document.getElementById('add-form').style.display='block'">+ Add Category</button>
        </div>

        <?php if ($message): ?>
            <div class="success-msg"><?= htmlspecialchars($message) ?></div>
        <?php endif; ?>

        <!-- Add Form -->
        <div id="add-form" class="add-form">
            <h2>Add New Category</h2>
            <form method="POST">
                <input type="hidden" name="action" value="add">
                <div class="form-group">
                    <label>Category Name</label>
                    <input type="text" name="name" required>
                </div>
                <div class="form-group">
                    <label>Icon Identifier (e.g. 'work', 'home')</label>
                    <input type="text" name="icon" value="folder">
                </div>
                <div class="form-group">
                    <label>Active Status</label>
                    <input type="checkbox" name="status" checked style="width: 20px; height: 20px;">
                </div>
                <button type="submit" class="btn btn-primary">Save Category</button>
                <button type="button" class="btn" onclick="document.getElementById('add-form').style.display='none'">Cancel</button>
            </form>
        </div>

        <div class="card">
            <table class="table">
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Name</th>
                        <th>Icon</th>
                        <th>Status</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($categories as $c): ?>
                    <tr>
                        <td><?= $c['id'] ?></td>
                        <td><strong><?= htmlspecialchars($c['name']) ?></strong></td>
                        <td><?= htmlspecialchars($c['icon']) ?></td>
                        <td>
                            <?= $c['status'] ? '<span class="badge active">Active</span>' : '<span class="badge inactive">Disabled</span>' ?>
                        </td>
                        <td>
                            <form method="POST" onsubmit="return confirm('Delete this category?');" style="display:inline;">
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="id" value="<?= $c['id'] ?>">
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
