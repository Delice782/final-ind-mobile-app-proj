<?php
session_start();
if (!isset($_SESSION['admin_logged_in'])) {
    header('Location: login.php');
    exit;
}
require 'db_connect.php';

// Handle actions
$message = '';
$message_type = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';
    $user_id = intval($_POST['user_id'] ?? 0);

    if ($action === 'approve') {
        $stmt = $pdo->prepare("UPDATE users SET status = 'approved' WHERE id = ?");
        $stmt->execute([$user_id]);
        $message = 'User approved successfully.';
        $message_type = 'success';

    } elseif ($action === 'reject') {
        $stmt = $pdo->prepare("UPDATE users SET status = 'rejected' WHERE id = ?");
        $stmt->execute([$user_id]);
        $message = 'User rejected.';
        $message_type = 'warning';

    } elseif ($action === 'delete') {
        $stmt = $pdo->prepare("DELETE FROM users WHERE id = ? AND role != 'admin'");
        $stmt->execute([$user_id]);
        $message = 'User deleted.';
        $message_type = 'error';

    } elseif ($action === 'update_role') {
        $new_role = $_POST['new_role'];
        $allowed = ['student', 'staff', 'admin'];
        if (in_array($new_role, $allowed)) {
            $stmt = $pdo->prepare("UPDATE users SET role = ? WHERE id = ?");
            $stmt->execute([$new_role, $user_id]);
            $message = 'User role updated.';
            $message_type = 'success';
        }

    } elseif ($action === 'update_user') {
        $name = trim($_POST['name']);
        $email = trim($_POST['email']);
        $role = $_POST['role'];
        $status = $_POST['status'];
        $stmt = $pdo->prepare("UPDATE users SET name=?, email=?, role=?, status=? WHERE id=?");
        $stmt->execute([$name, $email, $role, $status, $user_id]);
        $message = 'User updated successfully.';
        $message_type = 'success';

    } elseif ($action === 'reset_password') {
        $new_password = $_POST['new_password'];
        if (strlen($new_password) >= 6) {
            $hashed = password_hash($new_password, PASSWORD_DEFAULT);
            $stmt = $pdo->prepare("UPDATE users SET password = ? WHERE id = ?");
            $stmt->execute([$hashed, $user_id]);
            $message = 'Password reset successfully.';
            $message_type = 'success';
        } else {
            $message = 'Password must be at least 6 characters.';
            $message_type = 'error';
        }
    }
}

// Ensure status column exists (add it if not present for older installs)
try {
    $pdo->query("SELECT status FROM users LIMIT 1");
} catch (Exception $e) {
    $pdo->query("ALTER TABLE users ADD COLUMN status VARCHAR(20) DEFAULT 'approved'");
}

// Fetch stats
$total = $pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
$pending = $pdo->query("SELECT COUNT(*) FROM users WHERE status = 'pending'")->fetchColumn();
$approved = $pdo->query("SELECT COUNT(*) FROM users WHERE status = 'approved'")->fetchColumn();
$admins = $pdo->query("SELECT COUNT(*) FROM users WHERE role = 'admin'")->fetchColumn();

// Filters
$filter_status = $_GET['status'] ?? 'all';
$filter_role = $_GET['role'] ?? 'all';
$search = $_GET['search'] ?? '';

$where = [];
$params = [];

if ($filter_status !== 'all') {
    $where[] = "status = ?";
    $params[] = $filter_status;
}
if ($filter_role !== 'all') {
    $where[] = "role = ?";
    $params[] = $filter_role;
}
if ($search) {
    $where[] = "(name LIKE ? OR email LIKE ?)";
    $params[] = "%$search%";
    $params[] = "%$search%";
}

$sql = "SELECT * FROM users";
if ($where) $sql .= " WHERE " . implode(" AND ", $where);
$sql .= " ORDER BY created_at DESC";

$stmt = $pdo->prepare($sql);
$stmt->execute($params);
$users = $stmt->fetchAll();

// User to edit (if editing)
$edit_user = null;
if (isset($_GET['edit'])) {
    $stmt = $pdo->prepare("SELECT * FROM users WHERE id = ?");
    $stmt->execute([intval($_GET['edit'])]);
    $edit_user = $stmt->fetch();
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DataSphere — User Management</title>
    <link href="https://fonts.googleapis.com/css2?family=DM+Serif+Display&family=DM+Sans:wght@300;400;500;600&display=swap" rel="stylesheet">
    <style>
        :root {
            --maroon: #8B1A1A;
            --maroon-dark: #6B1212;
            --gold: #C9A84C;
            --cream: #FDF8F0;
            --text: #1A1A1A;
            --muted: #6B6B6B;
            --border: #E8E0D0;
            --bg: #F5F0E8;
            --white: #FFFFFF;
            --success: #2E7D32;
            --success-bg: #E8F5E9;
            --warning-bg: #FFF8E1;
            --warning: #F57F17;
            --error: #C62828;
            --error-bg: #FFEBEE;
            --sidebar-w: 240px;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: 'DM Sans', sans-serif;
            background: var(--bg);
            color: var(--text);
            min-height: 100vh;
            display: flex;
        }

        /* SIDEBAR */
        .sidebar {
            width: var(--sidebar-w);
            background: var(--maroon);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            position: fixed;
            top: 0; left: 0;
            z-index: 100;
        }

        .sidebar-logo {
            padding: 28px 24px 20px;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }

        .sidebar-logo h2 {
            font-family: 'DM Serif Display', serif;
            color: white;
            font-size: 20px;
            letter-spacing: -0.3px;
        }

        .sidebar-logo p {
            color: rgba(255,255,255,0.55);
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-top: 2px;
        }

        .sidebar-nav {
            padding: 20px 12px;
            flex: 1;
        }

        .nav-label {
            font-size: 10px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1.2px;
            color: rgba(255,255,255,0.35);
            padding: 0 12px;
            margin-bottom: 8px;
            margin-top: 16px;
        }

        .nav-item {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 10px 12px;
            border-radius: 8px;
            color: rgba(255,255,255,0.75);
            font-size: 13.5px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.15s;
            text-decoration: none;
            margin-bottom: 2px;
        }

        .nav-item:hover, .nav-item.active {
            background: rgba(255,255,255,0.12);
            color: white;
        }

        .nav-item svg { opacity: 0.8; flex-shrink: 0; }

        .sidebar-footer {
            padding: 16px 12px;
            border-top: 1px solid rgba(255,255,255,0.1);
        }

        .admin-card {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 10px 12px;
            border-radius: 8px;
            background: rgba(255,255,255,0.08);
        }

        .admin-avatar {
            width: 32px; height: 32px;
            background: var(--gold);
            border-radius: 50%;
            display: flex; align-items: center; justify-content: center;
            font-size: 12px; font-weight: 700; color: var(--maroon);
            flex-shrink: 0;
        }

        .admin-info p { font-size: 12.5px; color: white; font-weight: 500; }
        .admin-info span { font-size: 11px; color: rgba(255,255,255,0.5); }

        .logout-btn {
            display: block;
            text-align: center;
            margin-top: 8px;
            padding: 8px;
            border-radius: 6px;
            color: rgba(255,255,255,0.5);
            font-size: 12px;
            text-decoration: none;
            transition: all 0.15s;
        }
        .logout-btn:hover { color: white; background: rgba(255,255,255,0.08); }

        /* MAIN */
        .main {
            margin-left: var(--sidebar-w);
            flex: 1;
            padding: 32px;
            min-height: 100vh;
        }

        .page-header {
            display: flex;
            align-items: flex-start;
            justify-content: space-between;
            margin-bottom: 28px;
        }

        .page-header h1 {
            font-family: 'DM Serif Display', serif;
            font-size: 28px;
            color: var(--text);
            letter-spacing: -0.5px;
        }

        .page-header p {
            color: var(--muted);
            font-size: 14px;
            margin-top: 4px;
        }

        /* STATS */
        .stats-row {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 16px;
            margin-bottom: 28px;
        }

        .stat-card {
            background: white;
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 20px;
            position: relative;
            overflow: hidden;
        }

        .stat-card::before {
            content: '';
            position: absolute;
            top: 0; left: 0; right: 0;
            height: 3px;
        }

        .stat-card.total::before { background: var(--maroon); }
        .stat-card.pending::before { background: var(--warning); }
        .stat-card.approved::before { background: var(--success); }
        .stat-card.admin::before { background: var(--gold); }

        .stat-label {
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            color: var(--muted);
            margin-bottom: 8px;
        }

        .stat-number {
            font-family: 'DM Serif Display', serif;
            font-size: 36px;
            line-height: 1;
            color: var(--text);
        }

        .stat-card.pending .stat-number { color: var(--warning); }
        .stat-card.approved .stat-number { color: var(--success); }

        /* MESSAGE */
        .alert {
            padding: 12px 18px;
            border-radius: 8px;
            margin-bottom: 20px;
            font-size: 14px;
            font-weight: 500;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .alert.success { background: var(--success-bg); color: var(--success); border: 1px solid #C8E6C9; }
        .alert.warning { background: var(--warning-bg); color: var(--warning); border: 1px solid #FFE082; }
        .alert.error { background: var(--error-bg); color: var(--error); border: 1px solid #FFCDD2; }

        /* FILTERS */
        .filters-bar {
            background: white;
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 16px 20px;
            margin-bottom: 20px;
            display: flex;
            gap: 12px;
            align-items: center;
            flex-wrap: wrap;
        }

        .search-box {
            flex: 1;
            min-width: 200px;
            position: relative;
        }

        .search-box input {
            width: 100%;
            padding: 9px 14px 9px 38px;
            border: 1.5px solid var(--border);
            border-radius: 8px;
            font-family: 'DM Sans', sans-serif;
            font-size: 13.5px;
            outline: none;
            transition: border-color 0.2s;
        }

        .search-box input:focus { border-color: var(--maroon); }

        .search-box svg {
            position: absolute;
            left: 12px; top: 50%;
            transform: translateY(-50%);
            color: var(--muted);
        }

        .filter-select {
            padding: 9px 14px;
            border: 1.5px solid var(--border);
            border-radius: 8px;
            font-family: 'DM Sans', sans-serif;
            font-size: 13.5px;
            color: var(--text);
            background: white;
            outline: none;
            cursor: pointer;
        }

        .filter-select:focus { border-color: var(--maroon); }

        .btn {
            padding: 9px 18px;
            border-radius: 8px;
            font-family: 'DM Sans', sans-serif;
            font-size: 13px;
            font-weight: 600;
            border: none;
            cursor: pointer;
            transition: all 0.15s;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }

        .btn-primary { background: var(--maroon); color: white; }
        .btn-primary:hover { background: var(--maroon-dark); }
        .btn-success { background: var(--success-bg); color: var(--success); }
        .btn-success:hover { background: #C8E6C9; }
        .btn-warning { background: var(--warning-bg); color: var(--warning); }
        .btn-warning:hover { background: #FFE082; }
        .btn-danger { background: var(--error-bg); color: var(--error); }
        .btn-danger:hover { background: #FFCDD2; }
        .btn-ghost { background: transparent; color: var(--muted); border: 1.5px solid var(--border); }
        .btn-ghost:hover { border-color: var(--maroon); color: var(--maroon); }
        .btn-sm { padding: 6px 12px; font-size: 12px; }

        /* TABLE */
        .table-card {
            background: white;
            border: 1px solid var(--border);
            border-radius: 10px;
            overflow: hidden;
        }

        .table-header {
            padding: 16px 20px;
            border-bottom: 1px solid var(--border);
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .table-header h3 {
            font-size: 15px;
            font-weight: 600;
            color: var(--text);
        }

        .table-header span {
            font-size: 12px;
            color: var(--muted);
        }

        table {
            width: 100%;
            border-collapse: collapse;
        }

        thead th {
            padding: 12px 16px;
            text-align: left;
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            color: var(--muted);
            background: #FAFAFA;
            border-bottom: 1px solid var(--border);
        }

        tbody tr {
            border-bottom: 1px solid var(--border);
            transition: background 0.1s;
        }

        tbody tr:last-child { border-bottom: none; }
        tbody tr:hover { background: #FAFAFA; }

        td {
            padding: 14px 16px;
            font-size: 13.5px;
            vertical-align: middle;
        }

        .user-cell {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .user-avatar {
            width: 36px; height: 36px;
            border-radius: 50%;
            background: var(--maroon);
            display: flex; align-items: center; justify-content: center;
            font-size: 13px; font-weight: 700; color: white;
            flex-shrink: 0;
        }

        .user-name { font-weight: 600; color: var(--text); font-size: 13.5px; }
        .user-email { font-size: 12px; color: var(--muted); }

        /* BADGES */
        .badge {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 20px;
            font-size: 11px;
            font-weight: 600;
            letter-spacing: 0.3px;
        }

        .badge-student { background: #E3F2FD; color: #1565C0; }
        .badge-staff { background: #F3E5F5; color: #6A1B9A; }
        .badge-facilities { background: #E8F5E9; color: #2E7D32; }
        .badge-admin { background: rgba(139,26,26,0.1); color: var(--maroon); }

        .status-dot {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            font-size: 12.5px;
            font-weight: 500;
        }

        .dot {
            width: 7px; height: 7px;
            border-radius: 50%;
            flex-shrink: 0;
        }

        .dot-approved { background: var(--success); }
        .dot-pending { background: var(--warning); }
        .dot-rejected { background: var(--error); }

        .actions-cell {
            display: flex;
            gap: 6px;
            flex-wrap: wrap;
        }

        /* MODAL */
        .modal-overlay {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(0,0,0,0.4);
            z-index: 200;
            align-items: center;
            justify-content: center;
        }

        .modal-overlay.open { display: flex; }

        .modal {
            background: white;
            border-radius: 12px;
            padding: 32px;
            width: 100%;
            max-width: 480px;
            position: relative;
            animation: modalIn 0.2s ease;
            max-height: 90vh;
            overflow-y: auto;
        }

        @keyframes modalIn {
            from { opacity: 0; transform: scale(0.96); }
            to { opacity: 1; transform: scale(1); }
        }

        .modal h3 {
            font-family: 'DM Serif Display', serif;
            font-size: 20px;
            margin-bottom: 20px;
            color: var(--text);
        }

        .modal-close {
            position: absolute;
            top: 16px; right: 16px;
            background: none; border: none;
            cursor: pointer; color: var(--muted);
            font-size: 20px; line-height: 1;
        }

        .modal-close:hover { color: var(--text); }

        .form-group {
            margin-bottom: 16px;
        }

        .form-group label {
            display: block;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            color: var(--muted);
            margin-bottom: 6px;
        }

        .form-group input,
        .form-group select {
            width: 100%;
            padding: 10px 12px;
            border: 1.5px solid var(--border);
            border-radius: 8px;
            font-family: 'DM Sans', sans-serif;
            font-size: 14px;
            color: var(--text);
            outline: none;
            transition: border-color 0.2s;
        }

        .form-group input:focus,
        .form-group select:focus { border-color: var(--maroon); }

        .modal-actions {
            display: flex;
            gap: 10px;
            margin-top: 24px;
            justify-content: flex-end;
        }

        .empty-state {
            text-align: center;
            padding: 60px 20px;
            color: var(--muted);
        }

        .empty-state svg { margin-bottom: 12px; opacity: 0.4; }
        .empty-state p { font-size: 15px; }

        .date-text { font-size: 12px; color: var(--muted); }

        .tab-pills {
            display: flex;
            gap: 4px;
            background: var(--bg);
            border-radius: 8px;
            padding: 4px;
            margin-bottom: 20px;
            width: fit-content;
        }

        .tab-pill {
            padding: 7px 16px;
            border-radius: 6px;
            font-size: 13px;
            font-weight: 500;
            text-decoration: none;
            color: var(--muted);
            transition: all 0.15s;
        }

        .tab-pill.active, .tab-pill:hover {
            background: white;
            color: var(--text);
            box-shadow: 0 1px 4px rgba(0,0,0,0.08);
        }

        .tab-pill.active { color: var(--maroon); font-weight: 600; }
    </style>
</head>
<body>

<!-- SIDEBAR -->
<aside class="sidebar">
    <div class="sidebar-logo">
        <h2>DataSphere</h2>
        <p>Admin Panel</p>
    </div>
    <nav class="sidebar-nav">
        <div class="nav-label">Management</div>
        <a href="dashboard.php" class="nav-item active">
            <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"/>
            </svg>
            User Management
        </a>
        <a href="dashboard.php?status=pending" class="nav-item">
            <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
            Pending Approvals
            <?php if ($pending > 0): ?>
                <span style="background:var(--warning);color:white;border-radius:20px;padding:1px 8px;font-size:11px;margin-left:auto;"><?= $pending ?></span>
            <?php endif; ?>
        </a>
    </nav>
    <div class="sidebar-footer">
        <div class="admin-card">
            <div class="admin-avatar"><?= strtoupper(substr($_SESSION['admin_name'], 0, 1)) ?></div>
            <div class="admin-info">
                <p><?= htmlspecialchars($_SESSION['admin_name']) ?></p>
                <span>Administrator</span>
            </div>
        </div>
        <a href="logout.php" class="logout-btn">← Sign Out</a>
    </div>
</aside>

<!-- MAIN -->
<main class="main">
    <div class="page-header">
        <div>
            <h1>User Management</h1>
            <p>Manage all registered DataSphere users — approve, edit, assign roles, and delete accounts.</p>
        </div>
    </div>

    <!-- STATS -->
    <div class="stats-row">
        <div class="stat-card total">
            <div class="stat-label">Total Users</div>
            <div class="stat-number"><?= $total ?></div>
        </div>
        <div class="stat-card pending">
            <div class="stat-label">Pending Approval</div>
            <div class="stat-number"><?= $pending ?></div>
        </div>
        <div class="stat-card approved">
            <div class="stat-label">Approved</div>
            <div class="stat-number"><?= $approved ?></div>
        </div>
        <div class="stat-card admin">
            <div class="stat-label">Admins</div>
            <div class="stat-number"><?= $admins ?></div>
        </div>
    </div>

    <?php if ($message): ?>
        <div class="alert <?= $message_type ?>"><?= htmlspecialchars($message) ?></div>
    <?php endif; ?>

    <!-- FILTER TABS -->
    <div class="tab-pills">
        <a href="dashboard.php" class="tab-pill <?= $filter_status === 'all' && !$search ? 'active' : '' ?>">All Users</a>
        <a href="dashboard.php?status=pending" class="tab-pill <?= $filter_status === 'pending' ? 'active' : '' ?>">Pending</a>
        <a href="dashboard.php?status=approved" class="tab-pill <?= $filter_status === 'approved' ? 'active' : '' ?>">Approved</a>
        <a href="dashboard.php?status=rejected" class="tab-pill <?= $filter_status === 'rejected' ? 'active' : '' ?>">Rejected</a>
    </div>

    <!-- SEARCH & FILTERS -->
    <form method="GET" class="filters-bar">
        <input type="hidden" name="status" value="<?= htmlspecialchars($filter_status) ?>">
        <div class="search-box">
            <svg width="15" height="15" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
            </svg>
            <input type="text" name="search" placeholder="Search by name or email…" value="<?= htmlspecialchars($search) ?>">
        </div>
        <select name="role" class="filter-select">
            <option value="all" <?= $filter_role === 'all' ? 'selected' : '' ?>>All Roles</option>
            <option value="student" <?= $filter_role === 'student' ? 'selected' : '' ?>>Student</option>
            <option value="staff" <?= $filter_role === 'staff' ? 'selected' : '' ?>>Staff</option>
            <option value="admin" <?= $filter_role === 'admin' ? 'selected' : '' ?>>Admin</option>
        </select>
        <button type="submit" class="btn btn-primary">Search</button>
        <?php if ($search || $filter_role !== 'all'): ?>
            <a href="dashboard.php" class="btn btn-ghost">Clear</a>
        <?php endif; ?>
    </form>

    <!-- USERS TABLE -->
    <div class="table-card">
        <div class="table-header">
            <h3>Users <span>(<?= count($users) ?> results)</span></h3>
        </div>
        <?php if (empty($users)): ?>
            <div class="empty-state">
                <svg width="48" height="48" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                <p>No users found.</p>
            </div>
        <?php else: ?>
        <table>
            <thead>
                <tr>
                    <th>User</th>
                    <th>Role</th>
                    <th>Status</th>
                    <th>Joined</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($users as $u): ?>
                <tr>
                    <td>
                        <div class="user-cell">
                            <div class="user-avatar"><?= strtoupper(substr($u['name'], 0, 1)) ?></div>
                            <div>
                                <div class="user-name"><?= htmlspecialchars($u['name']) ?></div>
                                <div class="user-email"><?= htmlspecialchars($u['email']) ?></div>
                            </div>
                        </div>
                    </td>
                    <td>
                        <span class="badge badge-<?= $u['role'] ?>"><?= ucfirst($u['role']) ?></span>
                    </td>
                    <td>
                        <?php $st = $u['status'] ?? 'approved'; ?>
                        <span class="status-dot">
                            <span class="dot dot-<?= $st ?>"></span>
                            <?= ucfirst($st) ?>
                        </span>
                    </td>
                    <td class="date-text"><?= date('M j, Y', strtotime($u['created_at'])) ?></td>
                    <td>
                        <div class="actions-cell">
                            <?php if (($u['status'] ?? 'approved') === 'pending'): ?>
                                <form method="POST" style="display:inline">
                                    <input type="hidden" name="action" value="approve">
                                    <input type="hidden" name="user_id" value="<?= $u['id'] ?>">
                                    <button type="submit" class="btn btn-sm btn-success">✓ Approve</button>
                                </form>
                                <form method="POST" style="display:inline">
                                    <input type="hidden" name="action" value="reject">
                                    <input type="hidden" name="user_id" value="<?= $u['id'] ?>">
                                    <button type="submit" class="btn btn-sm btn-warning">✕ Reject</button>
                                </form>
                            <?php endif; ?>
                            <a href="?edit=<?= $u['id'] ?>&status=<?= $filter_status ?>&role=<?= $filter_role ?>&search=<?= urlencode($search) ?>" class="btn btn-sm btn-ghost">Edit</a>
                            <?php if ($u['role'] !== 'admin'): ?>
                                <form method="POST" style="display:inline" onsubmit="return confirm('Delete <?= htmlspecialchars($u['name']) ?>? This cannot be undone.')">
                                    <input type="hidden" name="action" value="delete">
                                    <input type="hidden" name="user_id" value="<?= $u['id'] ?>">
                                    <button type="submit" class="btn btn-sm btn-danger">Delete</button>
                                </form>
                            <?php endif; ?>
                        </div>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
        <?php endif; ?>
    </div>
</main>

<!-- EDIT MODAL -->
<?php if ($edit_user): ?>
<div class="modal-overlay open" id="editModal">
    <div class="modal">
        <button class="modal-close" onclick="window.location='dashboard.php'">×</button>
        <h3>Edit User</h3>
        <form method="POST">
            <input type="hidden" name="action" value="update_user">
            <input type="hidden" name="user_id" value="<?= $edit_user['id'] ?>">
            <div class="form-group">
                <label>Full Name</label>
                <input type="text" name="name" value="<?= htmlspecialchars($edit_user['name']) ?>" required>
            </div>
            <div class="form-group">
                <label>Email Address</label>
                <input type="email" name="email" value="<?= htmlspecialchars($edit_user['email']) ?>" required>
            </div>
            <div class="form-group">
                <label>Role</label>
                <select name="role">
                    <option value="student" <?= $edit_user['role'] === 'student' ? 'selected' : '' ?>>Student</option>
                    <option value="staff" <?= $edit_user['role'] === 'staff' ? 'selected' : '' ?>>Staff</option>
                    <option value="admin" <?= $edit_user['role'] === 'admin' ? 'selected' : '' ?>>Admin</option>
                </select>
            </div>
            <div class="form-group">
                <label>Account Status</label>
                <select name="status">
                    <option value="approved" <?= ($edit_user['status'] ?? '') === 'approved' ? 'selected' : '' ?>>Approved</option>
                    <option value="pending" <?= ($edit_user['status'] ?? '') === 'pending' ? 'selected' : '' ?>>Pending</option>
                    <option value="rejected" <?= ($edit_user['status'] ?? '') === 'rejected' ? 'selected' : '' ?>>Rejected</option>
                </select>
            </div>
            <div class="modal-actions">
                <a href="dashboard.php" class="btn btn-ghost">Cancel</a>
                <button type="submit" class="btn btn-primary">Save Changes</button>
            </div>
        </form>

        <hr style="margin: 24px 0; border: none; border-top: 1px solid var(--border);">
        <h3 style="font-size:16px; margin-bottom:16px;">Reset Password</h3>
        <form method="POST">
            <input type="hidden" name="action" value="reset_password">
            <input type="hidden" name="user_id" value="<?= $edit_user['id'] ?>">
            <div class="form-group">
                <label>New Password</label>
                <input type="password" name="new_password" placeholder="Min. 6 characters" required minlength="6">
            </div>
            <div class="modal-actions">
                <button type="submit" class="btn btn-warning" onclick="return confirm('Reset this user\'s password?')">Reset Password</button>
            </div>
        </form>
    </div>
</div>
<?php endif; ?>

</body>
</html>
