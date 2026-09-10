<?php
session_start();
if (!isset($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
    header("Location: login.php");
    exit;
}

require_once '../api/db.php';

$message = '';
$error = '';

// Ensure uploads directory exists
$uploadDir = '../uploads/ringtones/';
if (!file_exists($uploadDir)) {
    @mkdir($uploadDir, 0777, true);
}

// Handle Form Submissions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';

    if ($action === 'add') {
        $name = trim($_POST['name'] ?? '');
        $description = trim($_POST['description'] ?? '');
        $status = isset($_POST['status']) && $_POST['status'] == '1' ? 1 : 0;

        if (empty($name)) {
            $error = "Ringtone name is required.";
        } elseif (!isset($_FILES['mp3_file']) || $_FILES['mp3_file']['error'] !== UPLOAD_ERR_OK) {
            $error = "Please select a valid MP3 file to upload.";
        } else {
            $file = $_FILES['mp3_file'];
            $fileExt = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));

            if ($fileExt !== 'mp3') {
                $error = "Invalid file type. Only .mp3 files are allowed.";
            } elseif ($file['size'] > 10 * 1024 * 1024) { // 10MB max
                $error = "File size exceeds limit of 10MB.";
            } else {
                $safeName = preg_replace('/[^a-zA-Z0-9_\-]/', '_', strtolower($name));
                $fileName = 'custom_' . time() . '_' . $safeName . '.mp3';
                $targetPath = $uploadDir . $fileName;
                $dbFilePath = 'uploads/ringtones/' . $fileName;

                if (move_uploaded_file($file['tmp_name'], $targetPath)) {
                    $ringtoneId = 'custom_' . time() . '_' . rand(1000, 9999);
                    $fileSize = $file['size'];

                    $stmt = $pdo->prepare("INSERT INTO ringtones (ringtone_id, name, description, type, file_name, file_path, file_size, duration, status) VALUES (?, ?, ?, 'uploaded', ?, ?, ?, '0:03', ?)");
                    $stmt->execute([$ringtoneId, $name, $description, $fileName, $dbFilePath, $fileSize, $status]);

                    log_admin_action($pdo, "Uploaded Custom Ringtone", $name);
                    $message = "Custom MP3 ringtone uploaded successfully!";
                } else {
                    $error = "Failed to save uploaded file on server.";
                }
            }
        }
    } elseif ($action === 'toggle_status' && isset($_POST['id'])) {
        $id = intval($_POST['id']);
        $stmt = $pdo->prepare("SELECT ringtone_id, name, status FROM ringtones WHERE id = ?");
        $stmt->execute([$id]);
        $rt = $stmt->fetch();

        if ($rt) {
            $newStatus = $rt['status'] == 1 ? 0 : 1;
            $stmt = $pdo->prepare("UPDATE ringtones SET status = ? WHERE id = ?");
            $stmt->execute([$newStatus, $id]);

            log_admin_action($pdo, "Toggled Ringtone Status (" . ($newStatus == 1 ? "Active" : "Inactive") . ")", $rt['name']);
            $message = "Ringtone status updated to " . ($newStatus == 1 ? "Active" : "Inactive") . ".";
        }
    } elseif ($action === 'edit' && isset($_POST['id'])) {
        $id = intval($_POST['id']);
        $name = trim($_POST['name'] ?? '');
        $description = trim($_POST['description'] ?? '');
        $status = isset($_POST['status']) && $_POST['status'] == '1' ? 1 : 0;

        if (empty($name)) {
            $error = "Ringtone name cannot be empty.";
        } else {
            $stmt = $pdo->prepare("UPDATE ringtones SET name = ?, description = ?, status = ? WHERE id = ?");
            $stmt->execute([$name, $description, $status, $id]);

            log_admin_action($pdo, "Updated Ringtone Details", $name);
            $message = "Ringtone updated successfully.";
        }
    } elseif ($action === 'delete' && isset($_POST['id'])) {
        $id = intval($_POST['id']);
        $stmt = $pdo->prepare("SELECT * FROM ringtones WHERE id = ?");
        $stmt->execute([$id]);
        $rt = $stmt->fetch();

        if ($rt) {
            if ($rt['type'] === 'built_in') {
                $error = "Built-in ringtones cannot be permanently deleted. You can set them to Inactive instead.";
            } else {
                // Reassign reminders using this ringtone to fallback default (morning_breeze)
                $pdo->prepare("UPDATE reminders SET ringtone = 'morning_breeze' WHERE ringtone = ?")->execute([$rt['ringtone_id']]);

                // Delete physical file
                $fullPath = '../' . $rt['file_path'];
                if (file_exists($fullPath)) {
                    @unlink($fullPath);
                }

                // Delete DB record
                $stmt = $pdo->prepare("DELETE FROM ringtones WHERE id = ?");
                $stmt->execute([$id]);

                log_admin_action($pdo, "Deleted Custom Ringtone", $rt['name']);
                $message = "Custom ringtone deleted safely.";
            }
        }
    }
}

// Fetch Stats
$totalCount = $pdo->query("SELECT COUNT(*) FROM ringtones")->fetchColumn();
$builtInCount = $pdo->query("SELECT COUNT(*) FROM ringtones WHERE type = 'built_in'")->fetchColumn();
$uploadedCount = $pdo->query("SELECT COUNT(*) FROM ringtones WHERE type = 'uploaded'")->fetchColumn();
$activeCount = $pdo->query("SELECT COUNT(*) FROM ringtones WHERE status = 1")->fetchColumn();

// Search & Filter Parameters
$search = trim($_GET['search'] ?? '');
$typeFilter = $_GET['type'] ?? 'all';
$statusFilter = $_GET['status'] ?? 'all';
$sortBy = $_GET['sort'] ?? 'name';

$query = "SELECT r.*, 
    (SELECT COUNT(*) FROM reminders rem WHERE rem.ringtone = r.ringtone_id) AS usage_count 
    FROM ringtones r WHERE 1=1";
$params = [];

if (!empty($search)) {
    $query .= " AND (r.name LIKE ? OR r.file_name LIKE ? OR r.description LIKE ?)";
    $params[] = "%$search%";
    $params[] = "%$search%";
    $params[] = "%$search%";
}

if ($typeFilter === 'built_in') {
    $query .= " AND r.type = 'built_in'";
} elseif ($typeFilter === 'uploaded') {
    $query .= " AND r.type = 'uploaded'";
}

if ($statusFilter === 'active') {
    $query .= " AND r.status = 1";
} elseif ($statusFilter === 'inactive') {
    $query .= " AND r.status = 0";
}

switch ($sortBy) {
    case 'newest':
        $query .= " ORDER BY r.created_at DESC";
        break;
    case 'oldest':
        $query .= " ORDER BY r.created_at ASC";
        break;
    case 'status':
        $query .= " ORDER BY r.status DESC, r.name ASC";
        break;
    case 'name':
    default:
        $query .= " ORDER BY r.name ASC";
        break;
}

$stmt = $pdo->prepare($query);
$stmt->execute($params);
$ringtones = $stmt->fetchAll();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ringtones - Admin Panel</title>
    <link rel="stylesheet" href="style.css">
    <style>
        .stats-grid-sm { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 16px; margin-bottom: 24px; }
        .stat-card-sm { background: var(--card-bg); padding: 18px; border-radius: 12px; border: 1px solid var(--border); }
        .stat-card-sm .val { font-size: 26px; font-weight: 700; color: var(--primary); margin-top: 4px; }
        .stat-card-sm .lbl { font-size: 13px; color: var(--text-muted); font-weight: 500; }
        
        .filter-bar { display: flex; gap: 12px; margin-bottom: 24px; flex-wrap: wrap; align-items: center; }
        .filter-bar input, .filter-bar select {
            padding: 10px 14px; border: 1px solid var(--border); border-radius: 10px; font-family: inherit; font-size: 14px; background: var(--card-bg); color: var(--text-main);
        }
        
        .alert-success { background: rgba(16, 185, 129, 0.1); color: #10B981; padding: 14px 18px; border-radius: 12px; margin-bottom: 20px; font-weight: 500; }
        .alert-error { background: rgba(239, 68, 68, 0.1); color: #EF4444; padding: 14px 18px; border-radius: 12px; margin-bottom: 20px; font-weight: 500; }

        .play-btn {
            background: var(--primary); color: white; border: none; padding: 6px 14px; border-radius: 20px; cursor: pointer; font-size: 13px; font-weight: 500; display: inline-flex; align-items: center; gap: 6px; transition: 0.2s;
        }
        .play-btn:hover { background: var(--primary-hover); }
        .play-btn.playing { background: var(--danger); }

        .modal-overlay {
            display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(15, 23, 42, 0.6); backdrop-filter: blur(4px); z-index: 1000; align-items: center; justify-content: center;
        }
        .modal-overlay.active { display: flex; }
        .modal-content { background: var(--card-bg); width: 100%; max-width: 500px; padding: 28px; border-radius: 20px; border: 1px solid var(--border); box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1); }
        .modal-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
        .modal-header h2 { margin: 0; font-size: 20px; font-weight: 600; }
        .modal-close { background: none; border: none; font-size: 24px; cursor: pointer; color: var(--text-muted); }
        
        .form-group-col { margin-bottom: 16px; }
        .form-group-col label { display: block; font-size: 14px; font-weight: 500; margin-bottom: 6px; color: var(--text-main); }
        .form-group-col input[type="text"], .form-group-col textarea { width: 100%; padding: 10px 14px; border: 1px solid var(--border); border-radius: 10px; font-family: inherit; font-size: 14px; box-sizing: border-box; }
        .form-group-col input[type="file"] { width: 100%; padding: 8px; border: 1px dashed var(--border); border-radius: 10px; background: var(--bg-color); }
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
            <a href="ringtones.php" class="active">Ringtones</a>
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
                <h1>Ringtone Management</h1>
                <p style="margin: 4px 0 0 0; color: var(--text-muted); font-size: 14px;">Manage built-in and uploaded MP3 alarm ringtones for the mobile app</p>
            </div>
            <button onclick="openAddModal()" class="btn btn-primary" style="display:flex; align-items:center; gap:8px;">
                <span>+</span> Add Ringtone
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
            <div class="stat-card-sm"><div class="lbl">Total Ringtones</div><div class="val"><?= number_format($totalCount) ?></div></div>
            <div class="stat-card-sm"><div class="lbl">Built-in Tones</div><div class="val"><?= number_format($builtInCount) ?></div></div>
            <div class="stat-card-sm"><div class="lbl">Uploaded / Custom</div><div class="val" style="color:#8B5CF6;"><?= number_format($uploadedCount) ?></div></div>
            <div class="stat-card-sm"><div class="lbl">Active Ringtones</div><div class="val" style="color:#10B981;"><?= number_format($activeCount) ?></div></div>
        </div>

        <!-- Filter & Search Bar -->
        <div class="filter-bar">
            <form method="GET" style="display:flex; gap:12px; width:100%; flex-wrap:wrap; align-items:center;">
                <input type="text" name="search" placeholder="Search ringtone name or file..." value="<?= htmlspecialchars($search) ?>" style="flex-grow:1; min-width:200px;">
                <select name="type" onchange="this.form.submit()">
                    <option value="all" <?= $typeFilter === 'all' ? 'selected' : '' ?>>All Types</option>
                    <option value="built_in" <?= $typeFilter === 'built_in' ? 'selected' : '' ?>>Built-in Only</option>
                    <option value="uploaded" <?= $typeFilter === 'uploaded' ? 'selected' : '' ?>>Uploaded Only</option>
                </select>
                <select name="status" onchange="this.form.submit()">
                    <option value="all" <?= $statusFilter === 'all' ? 'selected' : '' ?>>All Statuses</option>
                    <option value="active" <?= $statusFilter === 'active' ? 'selected' : '' ?>>Active Only</option>
                    <option value="inactive" <?= $statusFilter === 'inactive' ? 'selected' : '' ?>>Inactive Only</option>
                </select>
                <select name="sort" onchange="this.form.submit()">
                    <option value="name" <?= $sortBy === 'name' ? 'selected' : '' ?>>Sort: Name</option>
                    <option value="newest" <?= $sortBy === 'newest' ? 'selected' : '' ?>>Sort: Newest</option>
                    <option value="oldest" <?= $sortBy === 'oldest' ? 'selected' : '' ?>>Sort: Oldest</option>
                    <option value="status" <?= $sortBy === 'status' ? 'selected' : '' ?>>Sort: Status</option>
                </select>
                <button type="submit" class="btn btn-primary">Filter</button>
            </form>
        </div>

        <!-- Ringtones Table -->
        <div class="card" style="overflow-x: auto;">
            <table class="table">
                <thead>
                    <tr>
                        <th>Ringtone Name</th>
                        <th>Type</th>
                        <th>File Name & Size</th>
                        <th>Preview</th>
                        <th>Status</th>
                        <th>Reminders Used</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($ringtones)): ?>
                        <tr>
                            <td colspan="7" style="text-align:center; padding: 32px; color: var(--text-muted);">
                                No custom ringtones yet.<br>
                                Upload an MP3 ringtone to make it available in the mobile application.
                            </td>
                        </tr>
                    <?php else: ?>
                        <?php foreach ($ringtones as $rt): 
                            $filePath = ($rt['type'] === 'built_in') ? '../Mobileapp/' . $rt['file_path'] : '../' . $rt['file_path'];
                            $fileSizeFormatted = $rt['file_size'] > 0 ? round($rt['file_size'] / 1024, 1) . ' KB' : 'N/A';
                        ?>
                        <tr>
                            <td>
                                <strong>🎵 <?= htmlspecialchars($rt['name']) ?></strong>
                                <?php if (!empty($rt['description'])): ?>
                                    <div style="font-size:12px; color:var(--text-muted); margin-top:2px;"><?= htmlspecialchars($rt['description']) ?></div>
                                <?php endif; ?>
                            </td>
                            <td>
                                <?php if ($rt['type'] === 'built_in'): ?>
                                    <span class="badge" style="background: rgba(99, 102, 241, 0.1); color: var(--primary);">Built-in</span>
                                <?php else: ?>
                                    <span class="badge" style="background: rgba(139, 92, 246, 0.1); color: #8B5CF6;">Uploaded</span>
                                <?php endif; ?>
                            </td>
                            <td>
                                <code style="font-size:12px; background:var(--bg-color); padding:3px 8px; border-radius:6px;"><?= htmlspecialchars($rt['file_name']) ?></code>
                                <div style="font-size:11px; color:var(--text-muted); margin-top:2px;"><?= $fileSizeFormatted ?></div>
                            </td>
                            <td>
                                <button type="button" class="play-btn" id="btn-<?= $rt['id'] ?>" onclick="toggleAudio('<?= htmlspecialchars($filePath) ?>', 'btn-<?= $rt['id'] ?>')">
                                    <span>▶</span> Preview
                                </button>
                            </td>
                            <td>
                                <?php if ($rt['status'] == 1): ?>
                                    <span class="badge active">🟢 Active</span>
                                <?php else: ?>
                                    <span class="badge inactive">⚪ Inactive</span>
                                <?php endif; ?>
                            </td>
                            <td>
                                <span style="font-size:13px; font-weight:600;"><?= number_format($rt['usage_count']) ?></span>
                            </td>
                            <td>
                                <div style="display:flex; gap:8px; align-items:center;">
                                    <!-- Toggle Active/Inactive -->
                                    <form method="POST" style="display:inline;">
                                        <input type="hidden" name="action" value="toggle_status">
                                        <input type="hidden" name="id" value="<?= $rt['id'] ?>">
                                        <button type="submit" class="btn" style="background:var(--bg-color); border:1px solid var(--border); color:var(--text-main); font-size:12px; padding:5px 10px;" title="Toggle Status">
                                            <?= $rt['status'] == 1 ? 'Disable' : 'Enable' ?>
                                        </button>
                                    </form>

                                    <!-- Edit -->
                                    <button type="button" class="btn" style="background:var(--bg-color); border:1px solid var(--border); color:var(--text-main); font-size:12px; padding:5px 10px;" onclick="openEditModal(<?= htmlspecialchars(json_encode($rt)) ?>)">
                                        Edit
                                    </button>

                                    <!-- Delete (Uploaded only) -->
                                    <?php if ($rt['type'] === 'uploaded'): ?>
                                        <form method="POST" onsubmit="return confirm('Are you sure you want to delete \'<?= htmlspecialchars($rt['name'], ENT_QUOTES) ?>\'? <?= $rt['usage_count'] > 0 ? "This ringtone is currently used by " . $rt['usage_count'] . " reminder(s) and will be reset to Morning Breeze." : "" ?>');" style="display:inline;">
                                            <input type="hidden" name="action" value="delete">
                                            <input type="hidden" name="id" value="<?= $rt['id'] ?>">
                                            <button type="submit" class="btn btn-danger" style="font-size:12px; padding:5px 10px;">Delete</button>
                                        </form>
                                    <?php endif; ?>
                                </div>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>

    <!-- Modal: Add Ringtone -->
    <div id="addModal" class="modal-overlay">
        <div class="modal-content">
            <div class="modal-header">
                <h2>+ Add Custom Ringtone</h2>
                <button class="modal-close" onclick="closeAddModal()">&times;</button>
            </div>
            <form method="POST" enctype="multipart/form-data">
                <input type="hidden" name="action" value="add">
                <div class="form-group-col">
                    <label>Ringtone Name *</label>
                    <input type="text" name="name" required placeholder="e.g. Morning Focus">
                </div>
                <div class="form-group-col">
                    <label>MP3 File *</label>
                    <input type="file" name="mp3_file" accept=".mp3,audio/mpeg" required>
                    <div style="font-size:12px; color:var(--text-muted); margin-top:4px;">Supported format: .mp3 (Max: 10MB)</div>
                </div>
                <div class="form-group-col">
                    <label>Description (Optional)</label>
                    <textarea name="description" rows="2" placeholder="Brief description of this ringtone sound..."></textarea>
                </div>
                <div class="form-group-col" style="display:flex; align-items:center; gap:10px;">
                    <input type="checkbox" name="status" value="1" id="addStatus" checked style="width:18px; height:18px;">
                    <label for="addStatus" style="margin:0; cursor:pointer;">Active (Available in Mobile App)</label>
                </div>
                <div style="display:flex; justify-content:flex-end; gap:10px; margin-top:20px;">
                    <button type="button" class="btn" style="background:var(--bg-color); border:1px solid var(--border);" onclick="closeAddModal()">Cancel</button>
                    <button type="submit" class="btn btn-primary">Save Ringtone</button>
                </div>
            </form>
        </div>
    </div>

    <!-- Modal: Edit Ringtone -->
    <div id="editModal" class="modal-overlay">
        <div class="modal-content">
            <div class="modal-header">
                <h2>Edit Ringtone</h2>
                <button class="modal-close" onclick="closeEditModal()">&times;</button>
            </div>
            <form method="POST">
                <input type="hidden" name="action" value="edit">
                <input type="hidden" name="id" id="editId">
                <div class="form-group-col">
                    <label>Ringtone Name *</label>
                    <input type="text" name="name" id="editName" required>
                </div>
                <div class="form-group-col">
                    <label>Description</label>
                    <textarea name="description" id="editDescription" rows="2"></textarea>
                </div>
                <div class="form-group-col" style="display:flex; align-items:center; gap:10px;">
                    <input type="checkbox" name="status" value="1" id="editStatus" style="width:18px; height:18px;">
                    <label for="editStatus" style="margin:0; cursor:pointer;">Active (Available in Mobile App)</label>
                </div>
                <div style="display:flex; justify-content:flex-end; gap:10px; margin-top:20px;">
                    <button type="button" class="btn" style="background:var(--bg-color); border:1px solid var(--border);" onclick="closeEditModal()">Cancel</button>
                    <button type="submit" class="btn btn-primary">Update Ringtone</button>
                </div>
            </form>
        </div>
    </div>

    <!-- HTML5 Audio Engine Script -->
    <script>
        let currentAudio = null;
        let currentBtnId = null;

        function toggleAudio(src, btnId) {
            const btn = document.getElementById(btnId);

            if (currentBtnId === btnId && currentAudio && !currentAudio.paused) {
                currentAudio.pause();
                currentAudio.currentTime = 0;
                btn.classList.remove('playing');
                btn.innerHTML = '<span>▶</span> Preview';
                currentAudio = null;
                currentBtnId = null;
                return;
            }

            if (currentAudio) {
                currentAudio.pause();
                currentAudio.currentTime = 0;
                if (currentBtnId) {
                    const prevBtn = document.getElementById(currentBtnId);
                    if (prevBtn) {
                        prevBtn.classList.remove('playing');
                        prevBtn.innerHTML = '<span>▶</span> Preview';
                    }
                }
            }

            currentAudio = new Audio(src);
            currentBtnId = btnId;

            btn.classList.add('playing');
            btn.innerHTML = '<span>■</span> Stop';

            currentAudio.play().catch(err => {
                console.error("Audio playback error:", err);
                alert("Failed to play audio preview. File may be missing or corrupt.");
                btn.classList.remove('playing');
                btn.innerHTML = '<span>▶</span> Preview';
                currentAudio = null;
                currentBtnId = null;
            });

            currentAudio.onended = function() {
                btn.classList.remove('playing');
                btn.innerHTML = '<span>▶</span> Preview';
                currentAudio = null;
                currentBtnId = null;
            };
        }

        window.addEventListener('beforeunload', function() {
            if (currentAudio) {
                currentAudio.pause();
            }
        });

        function openAddModal() {
            document.getElementById('addModal').classList.add('active');
        }
        function closeAddModal() {
            document.getElementById('addModal').classList.remove('active');
        }

        function openEditModal(rt) {
            document.getElementById('editId').value = rt.id;
            document.getElementById('editName').value = rt.name;
            document.getElementById('editDescription').value = rt.description || '';
            document.getElementById('editStatus').checked = (rt.status == 1);
            document.getElementById('editModal').classList.add('active');
        }
        function closeEditModal() {
            document.getElementById('editModal').classList.remove('active');
        }
    </script>
</body>
</html>
