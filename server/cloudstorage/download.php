<?php // download.php

require_once __DIR__ . '/security.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$file_path = trim($_GET['file'] ?? '', '/');

if ($file_path === '') {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'File path required']);
    exit;
}

$resolved = safe_path($file_path);
if ($resolved === false || !is_file($resolved)) {
    http_response_code(404);
    echo json_encode(['success' => false, 'error' => 'File not found']);
    exit;
}

$finfo = new finfo(FILEINFO_MIME_TYPE);
$mime = $finfo->file($resolved);
$filename = basename($resolved);
$size = filesize($resolved);

header('Content-Type: ' . $mime);
header('Content-Disposition: attachment; filename="' . $filename . '"');
header('Content-Length: ' . $size);
header('Cache-Control: no-cache, must-revalidate');

readfile($resolved);
exit;
