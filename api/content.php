<?php
// backend/api/content.php
require_once 'db.php';

$type = $_GET['type'] ?? '';

if ($type === 'settings') {
    $stmt = $pdo->query("SELECT setting_key, setting_value FROM app_settings");
    $settings = [];
    while ($row = $stmt->fetch()) {
        $settings[$row['setting_key']] = $row['setting_value'];
    }
    echo json_encode(['success' => true, 'data' => $settings]);
} elseif ($type === 'page') {
    $slug = $_GET['slug'] ?? '';
    if (!$slug) {
        echo json_encode(['success' => false, 'error' => 'Slug is required']);
        exit;
    }
    $stmt = $pdo->prepare("SELECT * FROM pages WHERE slug = ?");
    $stmt->execute([$slug]);
    $page = $stmt->fetch();
    
    if ($page) {
        echo json_encode(['success' => true, 'data' => $page]);
    } else {
        echo json_encode(['success' => false, 'error' => 'Page not found']);
    }
} elseif ($type === 'faqs') {
    $stmt = $pdo->query("SELECT * FROM faqs WHERE status = 1 ORDER BY display_order ASC, id ASC");
    $faqs = $stmt->fetchAll();
    echo json_encode(['success' => true, 'data' => $faqs]);
} elseif ($type === 'categories') {
    $stmt = $pdo->query("SELECT * FROM categories WHERE status = 1 ORDER BY name ASC");
    $categories = $stmt->fetchAll();
    echo json_encode(['success' => true, 'data' => $categories]);
} elseif ($type === 'priorities') {
    $stmt = $pdo->query("SELECT * FROM priorities WHERE status = 1 ORDER BY level ASC");
    $priorities = $stmt->fetchAll();
    echo json_encode(['success' => true, 'data' => $priorities]);
} else {
    echo json_encode(['success' => false, 'error' => 'Invalid type parameter']);
}
