<?php
// backend/api/sync.php
require_once 'db.php';

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
    
    // Clear old reminders for this user to do a fresh sync
    $pdo->prepare("DELETE FROM reminders WHERE user_id = ?")->execute([$dbUserId]);
    
    // Insert all current reminders
    $stmt = $pdo->prepare("INSERT INTO reminders (id, user_id, title, description, scheduled_at, end_time, category_id, priority, is_completed, is_repeating, repeat_type, has_alarm) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    
    foreach ($data['reminders'] as $r) {
        $stmt->execute([
            $r['id'],
            $dbUserId,
            $r['title'],
            $r['description'] ?? null,
            date('Y-m-d H:i:s', strtotime($r['scheduled_at'])),
            isset($r['endTime']) ? date('Y-m-d H:i:s', strtotime($r['endTime'])) : null,
            $r['categoryId'],
            $r['priority'] ?? 'low',
            $r['isCompleted'] ? 1 : 0,
            $r['isRepeating'] ? 1 : 0,
            $r['repeatType'] ?? 'none',
            $r['hasAlarm'] ? 1 : 0
        ]);
    }
    
    echo json_encode(["success" => true, "message" => "Sync complete", "synced_count" => count($data['reminders'])]);
} else {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Incomplete sync data"]);
}
?>
