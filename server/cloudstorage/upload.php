<?php // upload.php

require_once __DIR__ . '/security.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

if (!isset($_FILES['file'])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'No file uploaded']);
    exit;
}

$folder_path = trim($_POST['folder_path'] ?? '', '/');
$file = $_FILES['file'];

if ($file['error'] !== UPLOAD_ERR_OK) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Upload error']);
    exit;
}

$allowed_mimes = [
    'image/jpeg',
    'image/png',
    'application/pdf',
    'video/mp4',
    'application/zip',
    'application/x-zip-compressed',
];

$finfo = new finfo(FILEINFO_MIME_TYPE);
$mime = $finfo->file($file['tmp_name']);

if (!in_array($mime, $allowed_mimes, true)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'File type not allowed']);
    exit;
}

if ($folder_path === '') {
    $target_dir = BASE_DIR;
} else {
    $target_dir = safe_path($folder_path);
    if ($target_dir === false || !is_dir($target_dir)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Invalid folder path']);
        exit;
    }
}

$original_name = basename($file['name']);
$original_name = preg_replace('/[^a-zA-Z0-9._-]/', '_', $original_name);
$filename = $original_name;
$counter = 1;

while (file_exists($target_dir . '/' . $filename)) {
    $ext = pathinfo($original_name, PATHINFO_EXTENSION);
    $name = pathinfo($original_name, PATHINFO_FILENAME);
    $filename = $name . '_' . $counter . '.' . $ext;
    $counter++;
}

$destination = $target_dir . '/' . $filename;

if (!move_uploaded_file($file['tmp_name'], $destination)) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Failed to save file']);
    exit;
}

$relative = str_replace(BASE_DIR, '', $destination);
$relative = ltrim(str_replace('\\', '/', $relative), '/');
$url = BASE_URL . '/' . rawurlencode_path($relative);

echo json_encode([
    'success'  => true,
    'url'      => $url,
    'filename' => $filename,
]);

function rawurlencode_path(string $path): string {
    return implode('/', array_map('rawurlencode', explode('/', $path)));
}
