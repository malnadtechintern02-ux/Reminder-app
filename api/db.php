<?php
// backend/api/db.php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

$host = 'localhost';
$dbname = 'focusday_db';
$user = 'root'; // default XAMPP user
$pass = ''; // default XAMPP password

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8", $user, $pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
} catch (PDOException $e) {
    die(json_encode(["error" => "Database connection failed: " . $e->getMessage()]));
}

function log_admin_action($pdo, $action, $affected_item = null, $admin_id = null) {
    try {
        $stmt = $pdo->prepare("INSERT INTO audit_logs (admin_id, action, affected_item) VALUES (?, ?, ?)");
        $stmt->execute([$admin_id, $action, $affected_item]);
    } catch (PDOException $e) {
        // Silently fail or log to file in production
    }
}
?>
