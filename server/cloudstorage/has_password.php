<?php // has_password.php

require_once __DIR__ . '/security.php';
require_once __DIR__ . '/db_config.php';

app_log('has_password request received');

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    app_log('has_password rejected: invalid method ' . ($_SERVER['REQUEST_METHOD'] ?? 'unknown'));
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$folder_path = trim($_GET['folder_path'] ?? '', '/');

if ($folder_path === '') {
    app_log('has_password rejected: missing folder_path');
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'folder_path required']);
    exit;
}

// Ensure requested folder exists under storage root.
$resolved = safe_path($folder_path);
if ($resolved === false || !is_dir($resolved)) {
    app_log('has_password rejected: folder not found for path=' . $folder_path);
    http_response_code(404);
    echo json_encode(['success' => false, 'error' => 'Folder not found']);
    exit;
}

$stmt = $pdo->prepare('SELECT 1 FROM folder_passwords WHERE folder_path = ? LIMIT 1');
$stmt->execute([$folder_path]);
$has = (bool) $stmt->fetchColumn();

app_log('has_password success for ' . $folder_path . ' => ' . ($has ? '1' : '0'));
echo json_encode(['success' => true, 'has_password' => $has]);

