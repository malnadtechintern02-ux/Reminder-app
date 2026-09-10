<?php
session_start();
if (!isset($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
    header("Location: login.php");
    exit;
}

require_once '../api/db.php';

// Completion rate
$total = $pdo->query("SELECT COUNT(*) FROM reminders")->fetchColumn();
$completed = $pdo->query("SELECT COUNT(*) FROM reminders WHERE is_completed = 1")->fetchColumn();
$completion_rate = $total > 0 ? round(($completed / $total) * 100, 1) : 0;

// Category usage
$cat_usage = $pdo->query("SELECT category_id, COUNT(*) as count FROM reminders GROUP BY category_id ORDER BY count DESC LIMIT 5")->fetchAll();

// Daily activity (last 7 days of reminders scheduled)
$daily_activity = $pdo->query("
    SELECT DATE(scheduled_at) as date, COUNT(*) as count 
    FROM reminders 
    WHERE scheduled_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY) 
    GROUP BY DATE(scheduled_at) 
    ORDER BY date ASC
")->fetchAll();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Analytics - Admin Panel</title>
    <link rel="stylesheet" href="style.css">
    <style>
        .analytics-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-bottom: 30px; }
        @media(max-width: 768px) { .analytics-grid { grid-template-columns: 1fr; } }
        .bar-chart { margin-top: 20px; }
        .bar-row { display: flex; align-items: center; margin-bottom: 12px; }
        .bar-label { width: 100px; font-weight: 500; font-size: 14px; }
        .bar-wrapper { flex-grow: 1; background: #F1F5F9; height: 24px; border-radius: 4px; overflow: hidden; margin: 0 15px; }
        .bar-fill { background: var(--primary); height: 100%; }
        .bar-val { width: 40px; text-align: right; font-size: 14px; font-weight: 600; }
        .big-rate { font-size: 48px; font-weight: 700; color: var(--primary); text-align: center; margin: 20px 0; }
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
            <a href="analytics.php" class="active">Analytics</a>
            <a href="pages.php">Pages</a>
            <a href="faqs.php">FAQs</a>
            <a href="settings.php">Settings</a>
            <a href="audit.php">Audit Log</a>
            <a href="logout.php" style="color: var(--danger); margin-top: auto;">Logout</a>
        </div>
    </div>

    <div class="main-content">
        <div class="header">
            <h1>Analytics & Statistics</h1>
        </div>

        <div class="analytics-grid">
            <div class="card">
                <h2>Completion Rate</h2>
                <div class="big-rate"><?= $completion_rate ?>%</div>
                <p style="text-align:center; color:var(--text-muted);">Overall task completion rate</p>
            </div>
            
            <div class="card">
                <h2>Most Used Categories</h2>
                <div class="bar-chart">
                    <?php 
                    $max_cat = !empty($cat_usage) ? max(array_column($cat_usage, 'count')) : 1;
                    foreach ($cat_usage as $c): 
                        $pct = ($c['count'] / $max_cat) * 100;
                    ?>
                    <div class="bar-row">
                        <div class="bar-label"><?= htmlspecialchars($c['category_id'] ?: 'Uncategorized') ?></div>
                        <div class="bar-wrapper"><div class="bar-fill" style="width: <?= $pct ?>%;"></div></div>
                        <div class="bar-val"><?= $c['count'] ?></div>
                    </div>
                    <?php endforeach; ?>
                </div>
            </div>
        </div>

        <div class="card">
            <h2>Activity (Last 7 Days)</h2>
            <div class="bar-chart">
                <?php 
                $max_day = !empty($daily_activity) ? max(array_column($daily_activity, 'count')) : 1;
                foreach ($daily_activity as $d): 
                    $pct = ($d['count'] / $max_day) * 100;
                ?>
                <div class="bar-row">
                    <div class="bar-label"><?= date('M j', strtotime($d['date'])) ?></div>
                    <div class="bar-wrapper"><div class="bar-fill" style="background:#10B981; width: <?= $pct ?>%;"></div></div>
                    <div class="bar-val"><?= $d['count'] ?></div>
                </div>
                <?php endforeach; ?>
                <?php if (empty($daily_activity)) echo "<p>No activity in the last 7 days.</p>"; ?>
            </div>
        </div>
    </div>
</body>
</html>
