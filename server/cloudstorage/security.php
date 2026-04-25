<?php // security.php

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-API-Key');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

define('API_KEY', '281af63ca719ddcb1870c5bf8c79063c70fc3821e88d2bdb2ca0d76e8d346192');

$provided_key = $_SERVER['HTTP_X_API_KEY'] ?? '';

if ($provided_key !== API_KEY) {
    http_response_code(401);
    echo json_encode(['success' => false, 'error' => 'Unauthorized']);
    exit;
}

// Deployed at: public_html/cloudstorage/
// User files live under: public_html/cloudstorage/uploads/
define('BASE_DIR', realpath(__DIR__ . '/uploads'));
define('BASE_URL', 'https://doswing.in/cloudstorage/uploads');

if (BASE_DIR === false) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Server storage directory not found']);
    exit;
}

/**
 * Resolve a relative path under BASE_DIR.
 *
 * @return string|false
 */
function safe_path(string $relative_path) {
    $full = BASE_DIR . '/' . $relative_path;
    $resolved = realpath($full);
    if ($resolved === false) {
        return false;
    }
    if (strpos($resolved, BASE_DIR) !== 0) {
        return false;
    }
    return $resolved;
}

/**
 * Resolve a relative path allowing non-existent leaf name.
 *
 * @return string|false
 */
function safe_parent_path(string $relative_path) {
    $full = BASE_DIR . '/' . $relative_path;
    $parent = realpath(dirname($full));
    if ($parent === false) {
        return false;
    }
    if (strpos($parent, BASE_DIR) !== 0) {
        return false;
    }
    return $parent . '/' . basename($full);
}

/**
 * Minimal server logger for debugging in shared hosting.
 */
function app_log($message) {
    $logDir = __DIR__ . '/logs';
    if (!is_dir($logDir)) {
        @mkdir($logDir, 0755, true);
    }
    $line = '[' . date('Y-m-d H:i:s') . '] ' . $message . PHP_EOL;
    @file_put_contents($logDir . '/cloudstorage.log', $line, FILE_APPEND);
}
