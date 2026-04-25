<?php // list_files.php

require_once __DIR__ . '/security.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$path = trim($_GET['path'] ?? '', '/');

if ($path === '') {
    $target_dir = BASE_DIR;
} else {
    $target_dir = safe_path($path);
    if ($target_dir === false || !is_dir($target_dir)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Invalid path']);
        exit;
    }
}

$items = [];
$entries = scandir($target_dir);

foreach ($entries as $entry) {
    if ($entry === '.' || $entry === '..' || $entry === '.htaccess') {
        continue;
    }

    $full_path = $target_dir . '/' . $entry;
    $is_dir = is_dir($full_path);

    $relative = str_replace(BASE_DIR, '', $full_path);
    $relative = ltrim(str_replace('\\', '/', $relative), '/');

    $item = [
        'name'       => $entry,
        'type'       => $is_dir ? 'folder' : 'file',
        'size'       => $is_dir ? 0 : filesize($full_path),
        'created_at' => date('Y-m-d H:i:s', filectime($full_path)),
    ];

    if (!$is_dir) {
        $item['url'] = BASE_URL . '/' . implode('/', array_map('rawurlencode', explode('/', $relative)));
    } else {
        $item['url'] = null;
    }

    $items[] = $item;
}

echo json_encode(['success' => true, 'data' => $items]);
