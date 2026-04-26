<?php
require_once 'db_config.php';

$user_id = $_POST['user_id'] ?? '';
$building = $_POST['building'] ?? '';
$room = $_POST['room'] ?? '';
$category = $_POST['category'] ?? '';
$description = $_POST['description'] ?? '';
$latitude = $_POST['latitude'] ?? '';
$longitude = $_POST['longitude'] ?? '';
$photo = null;
$audio = null;

if (empty($user_id) || empty($building) || empty($category) || empty($description)) {
    echo json_encode(['success' => false, 'message' => 'All fields are required']);
    exit;
}

// Handle photo upload
if (isset($_FILES['photo']) && $_FILES['photo']['error'] === 0) {
    $uploadDir = 'uploads/';
    if (!file_exists($uploadDir)) {
        mkdir($uploadDir, 0777, true);
    }
    $fileExtension = pathinfo($_FILES['photo']['name'], PATHINFO_EXTENSION);
    $fileName = uniqid() . '.' . $fileExtension;
    $filePath = $uploadDir . $fileName;
    if (move_uploaded_file($_FILES['photo']['tmp_name'], $filePath)) {
        $photo = $fileName;
    }
}

// Handle audio upload
if (isset($_FILES['audio']) && $_FILES['audio']['error'] === 0) {
    $uploadDir = 'uploads/';
    if (!file_exists($uploadDir)) {
        mkdir($uploadDir, 0777, true);
    }
    $audioName = uniqid() . '.aac';
    $audioPath = $uploadDir . $audioName;
    if (move_uploaded_file($_FILES['audio']['tmp_name'], $audioPath)) {
        $audio = $audioName;
    }
}

$stmt = $pdo->prepare("INSERT INTO reports (user_id, building, room, category, description, photo, latitude, longitude, audio) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
if ($stmt->execute([$user_id, $building, $room, $category, $description, $photo, $latitude, $longitude, $audio])) {
    echo json_encode(['success' => true, 'message' => 'Report submitted successfully']);
} else {
    echo json_encode(['success' => false, 'message' => 'Failed to submit report']);
}
?>