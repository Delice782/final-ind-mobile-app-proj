<?php
require_once 'db_config.php';

$data = json_decode(file_get_contents('php://input'), true);

$report_id = $data['report_id'] ?? '';
$status = $data['status'] ?? '';

if (empty($report_id) || empty($status)) {
    echo json_encode(['success' => false, 'message' => 'All fields required']);
    exit;
}

$stmt = $pdo->prepare("UPDATE reports SET status = ? WHERE id = ?");
if ($stmt->execute([$status, $report_id])) {
    echo json_encode(['success' => true, 'message' => 'Status updated']);
} else {
    echo json_encode(['success' => false, 'message' => 'Update failed']);
}
?>