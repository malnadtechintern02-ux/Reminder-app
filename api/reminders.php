<?php
// backend/api/reminders.php
require_once 'db.php';

$method = $_SERVER['REQUEST_METHOD'];

// Helper to get raw json body
$data = json_decode(file_get_contents("php://input"));

switch ($method) {
    case 'GET':
        // Fetch reminders for a user
        if (isset($_GET['user_id'])) {
            $stmt = $pdo->prepare("SELECT * FROM reminders WHERE user_id = ? ORDER BY scheduled_at ASC");
            $stmt->execute([$_GET['user_id']]);
            $reminders = $stmt->fetchAll();
            echo json_encode(["success" => true, "reminders" => $reminders]);
        } else {
            http_response_code(400);
            echo json_encode(["success" => false, "message" => "user_id required"]);
        }
        break;

    case 'POST':
        // Create a reminder
        if (isset($data->id) && isset($data->user_id) && isset($data->title) && isset($data->scheduled_at) && isset($data->category_id)) {
            $stmt = $pdo->prepare("INSERT INTO reminders (id, user_id, title, description, scheduled_at, end_time, category_id, priority, is_completed, is_repeating, repeat_type, has_alarm) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
            $stmt->execute([
                $data->id,
                $data->user_id,
                $data->title,
                $data->description ?? null,
                $data->scheduled_at,
                $data->end_time ?? null,
                $data->category_id,
                $data->priority ?? 'low',
                $data->is_completed ? 1 : 0,
                $data->is_repeating ? 1 : 0,
                $data->repeat_type ?? 'none',
                $data->has_alarm ? 1 : 0
            ]);
            echo json_encode(["success" => true, "message" => "Reminder created"]);
        } else {
            http_response_code(400);
            echo json_encode(["success" => false, "message" => "Incomplete data"]);
        }
        break;

    case 'PUT':
        // Update a reminder
        if (isset($data->id)) {
            $stmt = $pdo->prepare("UPDATE reminders SET title = ?, description = ?, scheduled_at = ?, end_time = ?, category_id = ?, priority = ?, is_completed = ?, is_repeating = ?, repeat_type = ?, has_alarm = ? WHERE id = ?");
            $stmt->execute([
                $data->title,
                $data->description ?? null,
                $data->scheduled_at,
                $data->end_time ?? null,
                $data->category_id,
                $data->priority ?? 'low',
                $data->is_completed ? 1 : 0,
                $data->is_repeating ? 1 : 0,
                $data->repeat_type ?? 'none',
                $data->has_alarm ? 1 : 0,
                $data->id
            ]);
            echo json_encode(["success" => true, "message" => "Reminder updated"]);
        } else {
            http_response_code(400);
            echo json_encode(["success" => false, "message" => "ID required"]);
        }
        break;

    case 'DELETE':
        // Delete a reminder
        $id = $_GET['id'] ?? null;
        if ($id) {
            $stmt = $pdo->prepare("DELETE FROM reminders WHERE id = ?");
            $stmt->execute([$id]);
            echo json_encode(["success" => true, "message" => "Reminder deleted"]);
        } else {
            http_response_code(400);
            echo json_encode(["success" => false, "message" => "ID required"]);
        }
        break;

    default:
        http_response_code(405);
        echo json_encode(["success" => false, "message" => "Method not allowed"]);
        break;
}
?>
