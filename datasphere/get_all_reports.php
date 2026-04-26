<?php
require_once 'db_config.php';

$stmt = $pdo->prepare("
    SELECT r.*, u.name as user_name 
    FROM reports r 
    JOIN users u ON r.user_id = u.id 
    ORDER BY r.created_at DESC
");
$stmt->execute();
$reports = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo json_encode(['success' => true, 'reports' => $reports]);
?>