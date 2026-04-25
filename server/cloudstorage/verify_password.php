<?php // verify_password.php

require_once __DIR__ . '/security.php';
require_once __DIR__ . '/db_config.php';

app_log('verify_password request received');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    app_log('verify_password rejected: invalid method ' . ($_SERVER['REQUEST_METHOD'] ?? 'unknown'));
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
$folder_path = trim($input['folder_path'] ?? '', '/');
$password = $input['password'] ?? '';

if ($folder_path === '' || $password === '') {
    app_log('verify_password rejected: missing folder_path/password');
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'folder_path and password required']);
    exit;
}

$stmt = $pdo->prepare('SELECT password_hash FROM folder_passwords WHERE folder_path = ?');
$stmt->execute([$folder_path]);
$row = $stmt->fetch();

if (!$row) {
    app_log('verify_password rejected: no password for ' . $folder_path);
    http_response_code(404);
    echo json_encode(['success' => false, 'error' => 'No password set for this folder']);
    exit;
}

if (!password_verify($password, $row['password_hash'])) {
    app_log('verify_password rejected: incorrect password for ' . $folder_path);
    http_response_code(403);
    echo json_encode(['success' => false, 'error' => 'Incorrect password']);
    exit;
}

$token = bin2hex(random_bytes(32));

app_log('verify_password success for ' . $folder_path);
echo json_encode(['success' => true, 'token' => $token]);
