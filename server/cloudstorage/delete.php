<?php // delete.php

require_once __DIR__ . '/security.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
$path = trim($input['path'] ?? '', '/');

if ($path === '') {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Path required']);
    exit;
}

$resolved = safe_path($path);
if ($resolved === false || !file_exists($resolved)) {
    http_response_code(404);
    echo json_encode(['success' => false, 'error' => 'Path not found']);
    exit;
}

if ($resolved === BASE_DIR) {
    http_response_code(403);
    echo json_encode(['success' => false, 'error' => 'Cannot delete root folder']);
    exit;
}

if (is_dir($resolved)) {
    $entries = scandir($resolved);
    $contents = array_diff($entries, ['.', '..']);
    if (count($contents) > 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Folder is not empty']);
        exit;
    }
    if (!rmdir($resolved)) {
        http_response_code(500);
        echo json_encode(['success' => false, 'error' => 'Failed to delete folder']);
        exit;
    }
} else {
    if (!unlink($resolved)) {
        http_response_code(500);
        echo json_encode(['success' => false, 'error' => 'Failed to delete file']);
        exit;
    }
}

echo json_encode(['success' => true]);
