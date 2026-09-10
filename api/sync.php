<?php
// backend/api/sync.php
require_once 'db.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $userId = $_GET['user_id'] ?? '';
    if (!empty($userId)) {
        // Resolve user ID by username or id
        $stmt = $pdo->prepare("SELECT id FROM users WHERE username = ? OR id = ?");
        $stmt->execute([$userId, $userId]);
        $user = $stmt->fetch();
        
        if ($user) {
            $stmt = $pdo->prepare("SELECT * FROM reminders WHERE user_id = ? ORDER BY scheduled_at ASC");
            $stmt->execute([$user['id']]);
            $reminders = $stmt->fetchAll();
            echo json_encode(["success" => true, "reminders" => $reminders]);
            exit;
        }
    }
    echo json_encode(["success" => true, "reminders" => []]);
    exit;
}

$data = json_decode(file_get_contents("php://input"), true);

if (isset($data['user_id']) && isset($data['reminders'])) {
    $userId = $data['user_id'];
    
    // Check if user exists, if not create silently
    $stmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch();
    
    if (!$user) {
        $stmt = $pdo->prepare("INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)");
        $stmt->execute([$userId, $userId . '@device.local', password_hash('silent', PASSWORD_DEFAULT)]);
        $dbUserId = $pdo->lastInsertId();
    } else {
        $dbUserId = $user['id'];
    }

    $stmtCheck = $pdo->query("SHOW COLUMNS FROM reminders LIKE 'ringtone'");
    $hasRingtoneCol = ($stmtCheck && $stmtCheck->rowCount() > 0);

    // Clear old reminders for this user to do a fresh sync
    $pdo->prepare("DELETE FROM reminders WHERE user_id = ?")->execute([$dbUserId]);
    
    // Insert all current reminders
    if ($hasRingtoneCol) {
        $stmt = $pdo->prepare("INSERT INTO reminders (id, user_id, title, description, scheduled_at, end_time, category_id, priority, is_completed, is_repeating, repeat_type, has_alarm, ringtone) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    } else {
        $stmt = $pdo->prepare("INSERT INTO reminders (id, user_id, title, description, scheduled_at, end_time, category_id, priority, is_completed, is_repeating, repeat_type, has_alarm) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    }
    
    foreach ($data['reminders'] as $r) {
        $params = [
            $r['id'],
            $dbUserId,
            $r['title'],
            $r['description'] ?? null,
            date('Y-m-d H:i:s', strtotime($r['scheduled_at'])),
            isset($r['endTime']) && !empty($r['endTime']) ? date('Y-m-d H:i:s', strtotime($r['endTime'])) : null,
            $r['categoryId'],
            $r['priority'] ?? 'low',
            !empty($r['isCompleted']) ? 1 : 0,
            !empty($r['isRepeating']) ? 1 : 0,
            $r['repeatType'] ?? 'none',
            !empty($r['hasAlarm']) ? 1 : 0
        ];
        if ($hasRingtoneCol) {
            $params[] = $r['ringtone'] ?? 'morning_breeze';
        }
        $stmt->execute($params);
    }
    
    echo json_encode(["success" => true, "message" => "Sync complete", "synced_count" => count($data['reminders'])]);
} else {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Incomplete sync data"]);
}
?>
