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
            $stmt = $pdo->prepare("INSERT INTO faqs (question, answer, status, display_order) VALUES (?, ?, ?, ?)");
            $stmt->execute([
                $_POST['question'],
                $_POST['answer'],
                isset($_POST['status']) ? 1 : 0,
                $_POST['display_order'] ?: 0
            ]);
            $message = "FAQ added successfully.";
        } elseif ($_POST['action'] === 'edit') {
            $stmt = $pdo->prepare("UPDATE faqs SET question = ?, answer = ?, status = ?, display_order = ? WHERE id = ?");
            $stmt->execute([
                $_POST['question'],
                $_POST['answer'],
                isset($_POST['status']) ? 1 : 0,
                $_POST['display_order'] ?: 0,
                $_POST['id']
            ]);
            $message = "FAQ updated successfully.";
        } elseif ($_POST['action'] === 'delete') {
            $stmt = $pdo->prepare("DELETE FROM faqs WHERE id = ?");
            $stmt->execute([$_POST['id']]);
            $message = "FAQ deleted successfully.";
        }
    }
}

$faqs = $pdo->query("SELECT * FROM faqs ORDER BY display_order ASC, id DESC")->fetchAll();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FAQs - Admin Panel</title>
    <link rel="stylesheet" href="style.css">
    <style>
        .form-group { margin-bottom: 20px; }
        .form-group label { display: block; margin-bottom: 8px; font-weight: 500; }
        .form-group input[type="text"], .form-group input[type="number"], .form-group textarea {
            width: 100%; padding: 12px; border: 1px solid var(--border);
            border-radius: 8px; box-sizing: border-box; font-family: inherit;
        }
        .form-group textarea { resize: vertical; min-height: 100px; }
        .success-msg {
            background-color: rgba(16, 185, 129, 0.1); color: #10B981;
            padding: 12px; border-radius: 8px; margin-bottom: 20px;
        }
        .faq-form { background: #fff; padding: 20px; border-radius: 8px; border: 1px solid var(--border); margin-bottom: 30px; display: none; }
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
            <a href="notifications.php">Notifications</a>
            <a href="ringtones.php">Ringtones</a>
            <a href="analytics.php">Analytics</a>
            <a href="pages.php">Pages</a>
            <a href="faqs.php" class="active">FAQs</a>
            <a href="settings.php">Settings</a>
            <a href="audit.php">Audit Log</a>
            <a href="logout.php" style="color: var(--danger); margin-top: auto;">Logout</a>
        </div>
    </div>

    <div class="main-content">
        <div class="header">
            <h1>Manage FAQs</h1>
            <button class="btn btn-primary" onclick="document.getElementById('add-form').style.display='block'">+ Add FAQ</button>
        </div>

        <?php if ($message): ?>
            <div class="success-msg"><?= htmlspecialchars($message) ?></div>
        <?php endif; ?>

        <!-- Add Form -->
        <div id="add-form" class="faq-form">
            <h2>Add New FAQ</h2>
            <form method="POST">
                <input type="hidden" name="action" value="add">
                <div class="form-group">
                    <label>Question</label>
                    <input type="text" name="question" required>
                </div>
                <div class="form-group">
                    <label>Answer</label>
                    <textarea name="answer" required></textarea>
                </div>
                <div class="form-group" style="display: flex; gap: 20px;">
                    <div>
                        <label>Display Order</label>
                        <input type="number" name="display_order" value="0" style="width: 100px;">
                    </div>
                    <div>
                        <label>Active Status</label>
                        <input type="checkbox" name="status" checked style="width: 20px; height: 20px; margin-top:10px;">
                    </div>
                </div>
                <button type="submit" class="btn btn-primary">Save FAQ</button>
                <button type="button" class="btn" onclick="document.getElementById('add-form').style.display='none'">Cancel</button>
            </form>
        </div>

        <div class="card">
            <table class="table">
                <thead>
                    <tr>
                        <th>Order</th>
                        <th>Question</th>
                        <th>Status</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($faqs as $f): ?>
                    <tr>
                        <td><?= $f['display_order'] ?></td>
                        <td>
                            <strong><?= htmlspecialchars($f['question']) ?></strong>
                            <div style="font-size:13px; color:var(--text-muted); margin-top:4px;">
                                <?= nl2br(htmlspecialchars($f['answer'])) ?>
                            </div>
                        </td>
                        <td>
                            <?= $f['status'] ? '<span class="badge active">Active</span>' : '<span class="badge inactive">Hidden</span>' ?>
                        </td>
                        <td>
                            <form method="POST" onsubmit="return confirm('Delete this FAQ?');" style="display:inline;">
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="id" value="<?= $f['id'] ?>">
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
