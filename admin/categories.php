<?php
session_start();
if (!isset($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
    header("Location: login.php");
    exit;
}

require_once '../api/db.php';

$message = '';
$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['action'])) {
        $action = $_POST['action'];

        if ($action === 'add') {
            $name = trim($_POST['name'] ?? '');
            $icon = trim($_POST['icon'] ?? '') ?: 'folder';
            $status = isset($_POST['status']) ? 1 : 0;

            if (empty($name)) {
                $error = "Category name is required.";
            } else {
                // Check duplicate name
                $stmt = $pdo->prepare("SELECT COUNT(*) FROM categories WHERE LOWER(name) = LOWER(?)");
                $stmt->execute([$name]);
                if ($stmt->fetchColumn() > 0) {
                    $error = "A category with this name already exists.";
                } else {
                    $stmt = $pdo->prepare("INSERT INTO categories (name, icon, status) VALUES (?, ?, ?)");
                    $stmt->execute([$name, $icon, $status]);
                    log_admin_action($pdo, "Created Category", $name);
                    $message = "Category added successfully.";
                }
            }
        } elseif ($action === 'edit') {
            $id = intval($_POST['id'] ?? 0);
            $name = trim($_POST['name'] ?? '');
            $icon = trim($_POST['icon'] ?? '') ?: 'folder';
            $status = isset($_POST['status']) ? 1 : 0;

            if ($id <= 0) {
                $error = "Invalid category ID specified.";
            } elseif (empty($name)) {
                $error = "Category name is required.";
            } else {
                // Check category exists
                $stmt = $pdo->prepare("SELECT * FROM categories WHERE id = ?");
                $stmt->execute([$id]);
                $existing = $stmt->fetch();

                if (!$existing) {
                    $error = "Category not found.";
                } else {
                    // Check duplicate name excluding current ID
                    $stmt = $pdo->prepare("SELECT COUNT(*) FROM categories WHERE LOWER(name) = LOWER(?) AND id != ?");
                    $stmt->execute([$name, $id]);
                    if ($stmt->fetchColumn() > 0) {
                        $error = "A category with this name already exists.";
                    } else {
                        $stmt = $pdo->prepare("UPDATE categories SET name = ?, icon = ?, status = ? WHERE id = ?");
                        $stmt->execute([$name, $icon, $status, $id]);
                        log_admin_action($pdo, "Updated Category", "'{$existing['name']}' -> '{$name}' (ID: {$id})");
                        $message = "Category updated successfully.";
                    }
                }
            }
        } elseif ($action === 'delete') {
            $id = intval($_POST['id'] ?? 0);
            if ($id <= 0) {
                $error = "Invalid category ID specified.";
            } else {
                $stmt = $pdo->prepare("SELECT name FROM categories WHERE id = ?");
                $stmt->execute([$id]);
                $cat = $stmt->fetch();

                if ($cat) {
                    $stmt = $pdo->prepare("DELETE FROM categories WHERE id = ?");
                    $stmt->execute([$id]);
                    log_admin_action($pdo, "Deleted Category", $cat['name'] ?? "ID: {$id}");
                    $message = "Category deleted successfully.";
                } else {
                    $error = "Category not found or already deleted.";
                }
            }
        }
    }
}

// Search & Filter Parameters
$search = trim($_GET['search'] ?? '');
$statusFilter = $_GET['status'] ?? 'all';
$sortBy = $_GET['sort'] ?? 'name_asc';

// Build Query
$query = "SELECT * FROM categories WHERE 1=1";
$params = [];

if ($search !== '') {
    $query .= " AND (name LIKE ? OR icon LIKE ?)";
    $params[] = "%{$search}%";
    $params[] = "%{$search}%";
}

if ($statusFilter === 'active') {
    $query .= " AND status = 1";
} elseif ($statusFilter === 'inactive') {
    $query .= " AND status = 0";
}

switch ($sortBy) {
    case 'name_desc':
        $query .= " ORDER BY name DESC";
        break;
    case 'id_desc':
        $query .= " ORDER BY id DESC";
        break;
    case 'id_asc':
        $query .= " ORDER BY id ASC";
        break;
    case 'name_asc':
    default:
        $query .= " ORDER BY name ASC";
        break;
}

$stmt = $pdo->prepare($query);
$stmt->execute($params);
$categories = $stmt->fetchAll();

// Statistics Counts
$totalCount = $pdo->query("SELECT COUNT(*) FROM categories")->fetchColumn();
$activeCount = $pdo->query("SELECT COUNT(*) FROM categories WHERE status = 1")->fetchColumn();
$disabledCount = $totalCount - $activeCount;
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Categories - Admin Panel</title>
    <link rel="stylesheet" href="style.css">
    <style>
        .stats-grid-sm {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }
        .stat-card-sm {
            background: var(--card-bg);
            padding: 18px;
            border-radius: 12px;
            border: 1px solid var(--border);
        }
        .stat-card-sm .val {
            font-size: 26px;
            font-weight: 700;
            color: var(--primary);
            margin-top: 4px;
        }
        .stat-card-sm .lbl {
            font-size: 13px;
            color: var(--text-muted);
            font-weight: 500;
        }

        .filter-bar {
            display: flex;
            gap: 12px;
            margin-bottom: 24px;
            flex-wrap: wrap;
            align-items: center;
        }
        .filter-bar input, .filter-bar select {
            padding: 10px 14px;
            border: 1px solid var(--border);
            border-radius: 10px;
            font-family: inherit;
            font-size: 14px;
            background: var(--card-bg);
            color: var(--text-main);
        }
        .filter-bar input[type="text"] {
            flex: 1;
            min-width: 200px;
        }

        .alert-success {
            background: rgba(16, 185, 129, 0.1);
            color: #10B981;
            padding: 14px 18px;
            border-radius: 12px;
            margin-bottom: 20px;
            font-weight: 500;
        }
        .alert-error {
            background: rgba(239, 68, 68, 0.1);
            color: #EF4444;
            padding: 14px 18px;
            border-radius: 12px;
            margin-bottom: 20px;
            font-weight: 500;
        }

        .modal-overlay {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(15, 23, 42, 0.6);
            backdrop-filter: blur(4px);
            z-index: 1000;
            align-items: center;
            justify-content: center;
        }
        .modal-overlay.active {
            display: flex;
        }
        .modal-content {
            background: var(--card-bg);
            width: 100%;
            max-width: 480px;
            padding: 28px;
            border-radius: 20px;
            border: 1px solid var(--border);
            box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
        }
        .modal-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
        }
        .modal-header h2 {
            margin: 0;
            font-size: 20px;
            font-weight: 600;
        }
        .modal-close {
            background: none;
            border: none;
            font-size: 24px;
            cursor: pointer;
            color: var(--text-muted);
        }
        
        .form-group-col {
            margin-bottom: 16px;
        }
        .form-group-col label {
            display: block;
            font-size: 14px;
            font-weight: 500;
            margin-bottom: 6px;
            color: var(--text-main);
        }
        .form-group-col input[type="text"] {
            width: 100%;
            padding: 10px 14px;
            border: 1px solid var(--border);
            border-radius: 10px;
            font-family: inherit;
            font-size: 14px;
            box-sizing: border-box;
        }

        .btn-secondary {
            background: #E2E8F0;
            color: var(--text-main);
        }
        .btn-secondary:hover {
            background: #CBD5E1;
        }

        .actions-cell {
            display: flex;
            gap: 8px;
            align-items: center;
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
            <a href="categories.php" class="active">Categories</a>
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
            <div>
                <h1>Manage Categories</h1>
                <p style="margin: 4px 0 0 0; color: var(--text-muted); font-size: 14px;">Organize and manage task categories for reminders</p>
            </div>
            <button class="btn btn-primary" onclick="openAddModal()" style="display:flex; align-items:center; gap:8px;">
                <span>+</span> Add Category
            </button>
        </div>

        <?php if ($message): ?>
            <div class="alert-success"><?= htmlspecialchars($message) ?></div>
        <?php endif; ?>

        <?php if ($error): ?>
            <div class="alert-error"><?= htmlspecialchars($error) ?></div>
        <?php endif; ?>

        <!-- Stats Overview -->
        <div class="stats-grid-sm">
            <div class="stat-card-sm">
                <div class="lbl">Total Categories</div>
                <div class="val"><?= $totalCount ?></div>
            </div>
            <div class="stat-card-sm">
                <div class="lbl">Active Categories</div>
                <div class="val" style="color:#10B981;"><?= $activeCount ?></div>
            </div>
            <div class="stat-card-sm">
                <div class="lbl">Disabled Categories</div>
                <div class="val" style="color:#EF4444;"><?= $disabledCount ?></div>
            </div>
        </div>

        <!-- Filter & Search Bar -->
        <form method="GET" class="filter-bar">
            <input type="text" name="search" placeholder="Search by name or icon..." value="<?= htmlspecialchars($search) ?>">
            
            <select name="status" onchange="this.form.submit()">
                <option value="all" <?= $statusFilter === 'all' ? 'selected' : '' ?>>All Statuses</option>
                <option value="active" <?= $statusFilter === 'active' ? 'selected' : '' ?>>Active Only</option>
                <option value="inactive" <?= $statusFilter === 'inactive' ? 'selected' : '' ?>>Disabled Only</option>
            </select>

            <select name="sort" onchange="this.form.submit()">
                <option value="name_asc" <?= $sortBy === 'name_asc' ? 'selected' : '' ?>>Name (A-Z)</option>
                <option value="name_desc" <?= $sortBy === 'name_desc' ? 'selected' : '' ?>>Name (Z-A)</option>
                <option value="id_desc" <?= $sortBy === 'id_desc' ? 'selected' : '' ?>>Newest First</option>
                <option value="id_asc" <?= $sortBy === 'id_asc' ? 'selected' : '' ?>>Oldest First</option>
            </select>

            <button type="submit" class="btn btn-secondary">Filter</button>
            <?php if ($search !== '' || $statusFilter !== 'all' || $sortBy !== 'name_asc'): ?>
                <a href="categories.php" class="btn btn-secondary" style="text-decoration:none;">Reset</a>
            <?php endif; ?>
        </form>

        <!-- Categories Table -->
        <div class="card">
            <table class="table">
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Category Name</th>
                        <th>Icon Identifier</th>
                        <th>Status</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($categories)): ?>
                    <tr>
                        <td colspan="5" style="text-align: center; color: var(--text-muted); padding: 24px;">
                            No categories found matching your criteria.
                        </td>
                    </tr>
                    <?php else: ?>
                        <?php foreach ($categories as $c): ?>
                        <tr>
                            <td><?= $c['id'] ?></td>
                            <td><strong><?= htmlspecialchars($c['name']) ?></strong></td>
                            <td><code><?= htmlspecialchars($c['icon']) ?></code></td>
                            <td>
                                <?= $c['status'] ? '<span class="badge active">Active</span>' : '<span class="badge inactive">Disabled</span>' ?>
                            </td>
                            <td>
                                <div class="actions-cell">
                                    <button type="button" class="btn btn-secondary" style="font-size:12px; padding:6px 12px; display:inline-flex; align-items:center; gap:4px;" onclick='openEditModal(<?= json_encode($c, JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP) ?>)'>
                                        ✏️ Edit
                                    </button>
                                    <form method="POST" onsubmit="return confirm('Are you sure you want to delete category \'<?= htmlspecialchars(addslashes($c['name'])) ?>\'?');" style="display:inline;">
                                        <input type="hidden" name="action" value="delete">
                                        <input type="hidden" name="id" value="<?= $c['id'] ?>">
                                        <button type="submit" class="btn btn-danger" style="font-size:12px; padding:6px 12px; display:inline-flex; align-items:center; gap:4px;">🗑️ Delete</button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>

    <!-- Add Category Modal -->
    <div id="addModal" class="modal-overlay">
        <div class="modal-content">
            <div class="modal-header">
                <h2>Add New Category</h2>
                <button type="button" class="modal-close" onclick="closeAddModal()">&times;</button>
            </div>
            <form method="POST">
                <input type="hidden" name="action" value="add">
                <div class="form-group-col">
                    <label>Category Name <span style="color:var(--danger)">*</span></label>
                    <input type="text" name="name" placeholder="e.g. Work, Personal, Fitness" required>
                </div>
                <div class="form-group-col">
                    <label>Icon Identifier</label>
                    <input type="text" name="icon" placeholder="e.g. work, home, folder" value="folder">
                </div>
                <div class="form-group-col">
                    <label style="display:flex; align-items:center; gap:10px; cursor:pointer;">
                        <input type="checkbox" name="status" checked style="width: 18px; height: 18px;">
                        <span>Active Status</span>
                    </label>
                </div>
                <div style="display:flex; gap:10px; justify-content:flex-end; margin-top:20px;">
                    <button type="button" class="btn btn-secondary" onclick="closeAddModal()">Cancel</button>
                    <button type="submit" class="btn btn-primary">Save Category</button>
                </div>
            </form>
        </div>
    </div>

    <!-- Edit Category Modal -->
    <div id="editModal" class="modal-overlay">
        <div class="modal-content">
            <div class="modal-header">
                <h2>Edit Category</h2>
                <button type="button" class="modal-close" onclick="closeEditModal()">&times;</button>
            </div>
            <form method="POST">
                <input type="hidden" name="action" value="edit">
                <input type="hidden" name="id" id="editId">
                <div class="form-group-col">
                    <label>Category Name <span style="color:var(--danger)">*</span></label>
                    <input type="text" name="name" id="editName" placeholder="Category Name" required>
                </div>
                <div class="form-group-col">
                    <label>Icon Identifier</label>
                    <input type="text" name="icon" id="editIcon" placeholder="e.g. work, home, folder">
                </div>
                <div class="form-group-col">
                    <label style="display:flex; align-items:center; gap:10px; cursor:pointer;">
                        <input type="checkbox" name="status" id="editStatus" style="width: 18px; height: 18px;">
                        <span>Active Status</span>
                    </label>
                </div>
                <div style="display:flex; gap:10px; justify-content:flex-end; margin-top:20px;">
                    <button type="button" class="btn btn-secondary" onclick="closeEditModal()">Cancel</button>
                    <button type="submit" class="btn btn-primary">Update Category</button>
                </div>
            </form>
        </div>
    </div>

    <script>
        function openAddModal() {
            document.getElementById('addModal').classList.add('active');
        }
        function closeAddModal() {
            document.getElementById('addModal').classList.remove('active');
        }

        function openEditModal(cat) {
            document.getElementById('editId').value = cat.id;
            document.getElementById('editName').value = cat.name;
            document.getElementById('editIcon').value = cat.icon || 'folder';
            document.getElementById('editStatus').checked = (cat.status == 1 || cat.status === '1');
            document.getElementById('editModal').classList.add('active');
        }
        function closeEditModal() {
            document.getElementById('editModal').classList.remove('active');
        }
    </script>
</body>
</html>
