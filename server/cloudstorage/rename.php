<?php // rename.php

require_once __DIR__ . '/security.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
$old_path = trim($input['old_path'] ?? '', '/');
$new_name = $input['new_name'] ?? '';

if ($old_path === '' || $new_name === '') {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'old_path and new_name required']);
    exit;
}

$new_name = basename($new_name);
$new_name = preg_replace('/[^a-zA-Z0-9._\- ]/', '_', $new_name);

$resolved = safe_path($old_path);
if ($resolved === false || !file_exists($resolved)) {
    http_response_code(404);
    echo json_encode(['success' => false, 'error' => 'Path not found']);
    exit;
}

if ($resolved === BASE_DIR) {
    http_response_code(403);
    echo json_encode(['success' => false, 'error' => 'Cannot rename root folder']);
    exit;
}

$parent = dirname($resolved);
$new_path = $parent . '/' . $new_name;

if (file_exists($new_path)) {
    http_response_code(409);
    echo json_encode(['success' => false, 'error' => 'Name already exists']);
    exit;
}

if (!rename($resolved, $new_path)) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Rename failed']);
    exit;
}

echo json_encode(['success' => true]);
