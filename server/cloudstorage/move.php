<?php // move.php

require_once __DIR__ . '/security.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
$source_path = trim($input['source_path'] ?? '', '/');
$destination_path = trim($input['destination_path'] ?? '', '/');

if ($source_path === '' || $destination_path === '') {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'source_path and destination_path required']);
    exit;
}

$source = safe_path($source_path);
if ($source === false || !file_exists($source)) {
    http_response_code(404);
    echo json_encode(['success' => false, 'error' => 'Source not found']);
    exit;
}

if ($source === BASE_DIR) {
    http_response_code(403);
    echo json_encode(['success' => false, 'error' => 'Cannot move root folder']);
    exit;
}

$dest_dir = safe_path($destination_path);
if ($dest_dir === false || !is_dir($dest_dir)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Invalid destination path']);
    exit;
}

$item_name = basename($source);
$new_location = $dest_dir . '/' . $item_name;

if (file_exists($new_location)) {
    http_response_code(409);
    echo json_encode(['success' => false, 'error' => 'Item already exists at destination']);
    exit;
}

if (is_dir($source) && strpos($dest_dir, $source) === 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Cannot move folder into itself']);
    exit;
}

if (!rename($source, $new_location)) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Move failed']);
    exit;
}

echo json_encode(['success' => true]);
