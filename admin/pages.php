<?php
session_start();
if (!isset($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
    header("Location: login.php");
    exit;
}

require_once '../api/db.php';

$message = '';
$edit_slug = $_GET['edit'] ?? null;
$preview = $_GET['preview'] ?? null;

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['save_page'])) {
    $slug = $_POST['slug'] ?? '';
    $title = $_POST['title'] ?? '';
    $content = $_POST['content'] ?? '';
    
    $stmt = $pdo->prepare("UPDATE pages SET title = ?, content = ? WHERE slug = ?");
    $stmt->execute([$title, $content, $slug]);
    $message = "Page '$title' updated successfully.";
    $edit_slug = $slug;
}

$pages = $pdo->query("SELECT * FROM pages")->fetchAll();

$current_page = null;
if ($edit_slug) {
    $stmt = $pdo->prepare("SELECT * FROM pages WHERE slug = ?");
    $stmt->execute([$edit_slug]);
    $current_page = $stmt->fetch();
}
if ($preview) {
    $stmt = $pdo->prepare("SELECT * FROM pages WHERE slug = ?");
    $stmt->execute([$preview]);
    $current_page = $stmt->fetch();
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pages - Admin Panel</title>
    <link rel="stylesheet" href="style.css">
    <style>
        .form-group { margin-bottom: 20px; }
        .form-group label { display: block; margin-bottom: 8px; font-weight: 500; }
        .form-group input, .form-group textarea {
            width: 100%; padding: 12px; border: 1px solid var(--border);
            border-radius: 8px; box-sizing: border-box; font-family: inherit;
        }
        .form-group textarea { resize: vertical; min-height: 200px; }
        .success-msg {
            background-color: rgba(16, 185, 129, 0.1); color: #10B981;
            padding: 12px; border-radius: 8px; margin-bottom: 20px;
        }
        .page-list { margin-bottom: 30px; }
        .preview-box {
            border: 1px solid var(--border); padding: 20px; border-radius: 8px;
            background: #fff; margin-top: 20px;
        }
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
            <a href="pages.php" class="active">Pages</a>
            <a href="faqs.php">FAQs</a>
            <a href="settings.php">Settings</a>
            <a href="audit.php">Audit Log</a>
            <a href="logout.php" style="color: var(--danger); margin-top: auto;">Logout</a>
        </div>
    </div>

    <div class="main-content">
        <div class="header">
            <h1>Content Management</h1>
        </div>

        <?php if ($message): ?>
            <div class="success-msg"><?= htmlspecialchars($message) ?></div>
        <?php endif; ?>

        <?php if ($preview && $current_page): ?>
            <div class="card">
                <h2>Preview: <?= htmlspecialchars($current_page['title']) ?></h2>
                <div class="preview-box">
                    <?= nl2br(htmlspecialchars($current_page['content'])) ?>
                </div>
                <div style="margin-top: 20px;">
                    <a href="pages.php?edit=<?= urlencode($current_page['slug']) ?>" class="btn btn-primary" style="text-decoration:none;">Back to Edit</a>
                    <a href="pages.php" class="btn" style="text-decoration:none; background:#E2E8F0; color:#0F172A;">Close</a>
                </div>
            </div>
        <?php elseif ($edit_slug && $current_page): ?>
            <div class="card">
                <h2>Edit Page: <?= htmlspecialchars($current_page['title']) ?></h2>
                <form method="POST">
                    <input type="hidden" name="save_page" value="1">
                    <input type="hidden" name="slug" value="<?= htmlspecialchars($current_page['slug']) ?>">
                    
                    <div class="form-group">
                        <label>Title</label>
                        <input type="text" name="title" value="<?= htmlspecialchars($current_page['title']) ?>" required>
                    </div>
                    
                    <div class="form-group">
                        <label>Content</label>
                        <textarea name="content" required><?= htmlspecialchars($current_page['content']) ?></textarea>
                    </div>
                    
                    <div>
                        <button type="submit" class="btn btn-primary">Save Changes</button>
                        <a href="pages.php?preview=<?= urlencode($current_page['slug']) ?>" class="btn" style="text-decoration:none; background:#E2E8F0; color:#0F172A; margin-left:10px;">Preview</a>
                        <a href="pages.php" class="btn" style="text-decoration:none; background:#E2E8F0; color:#0F172A; margin-left:10px;">Cancel</a>
                    </div>
                </form>
            </div>
        <?php else: ?>
            <div class="card page-list">
                <table class="table">
                    <thead>
                        <tr>
                            <th>Page Title</th>
                            <th>Slug</th>
                            <th>Last Updated</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($pages as $p): ?>
                        <tr>
                            <td><strong><?= htmlspecialchars($p['title']) ?></strong></td>
                            <td><code><?= htmlspecialchars($p['slug']) ?></code></td>
                            <td><?= date('M j, Y H:i', strtotime($p['updated_at'])) ?></td>
                            <td>
                                <a href="?edit=<?= urlencode($p['slug']) ?>" class="btn btn-primary" style="text-decoration:none; font-size:12px;">Edit</a>
                                <a href="?preview=<?= urlencode($p['slug']) ?>" class="btn" style="text-decoration:none; background:#E2E8F0; color:#0F172A; font-size:12px; margin-left:5px;">Preview</a>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        <?php endif; ?>
    </div>
</body>
</html>
