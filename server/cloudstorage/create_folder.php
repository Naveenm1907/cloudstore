<?php // create_folder.php

require_once __DIR__ . '/security.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
$folder_name = $input['folder_name'] ?? '';
$parent_path = trim($input['parent_path'] ?? '', '/');

if ($folder_name === '') {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Folder name required']);
    exit;
}

$folder_name = preg_replace('/[^a-zA-Z0-9._\- ]/', '_', $folder_name);

if ($parent_path === '') {
    $parent_dir = BASE_DIR;
} else {
    $parent_dir = safe_path($parent_path);
    if ($parent_dir === false || !is_dir($parent_dir)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Invalid parent path']);
        exit;
    }
}

$new_folder = $parent_dir . '/' . $folder_name;

if (file_exists($new_folder)) {
    http_response_code(409);
    echo json_encode(['success' => false, 'error' => 'Folder already exists']);
    exit;
}

if (!mkdir($new_folder, 0755)) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Failed to create folder']);
    exit;
}

$relative = str_replace(BASE_DIR, '', $new_folder);
$relative = ltrim(str_replace('\\', '/', $relative), '/');

echo json_encode(['success' => true, 'path' => $relative]);
