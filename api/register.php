<?php
// backend/api/register.php
require_once 'db.php';

$data = json_decode(file_get_contents("php://input"));

if (isset($data->username) && isset($data->email) && isset($data->password)) {
    try {
        $hash = password_hash($data->password, PASSWORD_DEFAULT);
        $stmt = $pdo->prepare("INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)");
        $stmt->execute([$data->username, $data->email, $hash]);
        $userId = $pdo->lastInsertId();

        echo json_encode([
            "success" => true,
            "message" => "Registration successful",
            "user" => [
                "id" => $userId,
                "username" => $data->username,
                "email" => $data->email
            ]
        ]);
    } catch (PDOException $e) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Email or username already exists"]);
    }
} else {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Incomplete data"]);
}
?>
