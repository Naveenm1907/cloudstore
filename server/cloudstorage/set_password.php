<?php // set_password.php

require_once __DIR__ . '/security.php';
require_once __DIR__ . '/db_config.php';

app_log('set_password request received');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    app_log('set_password rejected: invalid method ' . ($_SERVER['REQUEST_METHOD'] ?? 'unknown'));
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
$folder_path = trim($input['folder_path'] ?? '', '/');
$password = $input['password'] ?? '';

if ($folder_path === '' || $password === '') {
    app_log('set_password rejected: missing folder_path/password');
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'folder_path and password required']);
    exit;
}

$resolved = safe_path($folder_path);
if ($resolved === false || !is_dir($resolved)) {
    app_log('set_password rejected: folder not found for path=' . $folder_path);
    http_response_code(404);
    echo json_encode(['success' => false, 'error' => 'Folder not found']);
    exit;
}

$hash = password_hash($password, PASSWORD_BCRYPT);

$stmt = $pdo->prepare('SELECT id FROM folder_passwords WHERE folder_path = ?');
$stmt->execute([$folder_path]);

if ($stmt->fetch()) {
    app_log('set_password updating existing password for ' . $folder_path);
    $stmt = $pdo->prepare('UPDATE folder_passwords SET password_hash = ? WHERE folder_path = ?');
    $stmt->execute([$hash, $folder_path]);
} else {
    app_log('set_password inserting new password for ' . $folder_path);
    $stmt = $pdo->prepare('INSERT INTO folder_passwords (folder_path, password_hash) VALUES (?, ?)');
    $stmt->execute([$folder_path, $hash]);
}

app_log('set_password success for ' . $folder_path);
echo json_encode(['success' => true]);
