<?php
session_start();
if (isset($_SESSION['admin_logged_in'])) {
    header('Location: dashboard.php');
    exit;
}

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    require 'db_connect.php';
    $email = trim($_POST['email']);
    $password = $_POST['password'];

    $stmt = $pdo->prepare("SELECT * FROM users WHERE email = ? AND role = 'admin'");
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if ($user && password_verify($password, $user['password'])) {
        $_SESSION['admin_logged_in'] = true;
        $_SESSION['admin_id'] = $user['id'];
        $_SESSION['admin_name'] = $user['name'];
        header('Location: dashboard.php');
        exit;
    } else {
        $error = 'Invalid credentials or not an admin account.';
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DataSphere — Admin Login</title>
    <link href="https://fonts.googleapis.com/css2?family=DM+Serif+Display&family=DM+Sans:wght@300;400;500;600&display=swap" rel="stylesheet">
    <style>
        :root {
            --maroon: #8B1A1A;
            --maroon-dark: #6B1212;
            --maroon-light: #A52020;
            --gold: #C9A84C;
            --cream: #FDF8F0;
            --text: #1A1A1A;
            --muted: #6B6B6B;
            --border: #E0D5C5;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: 'DM Sans', sans-serif;
            background: var(--cream);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
            overflow: hidden;
        }

        body::before {
            content: '';
            position: fixed;
            top: -50%;
            left: -20%;
            width: 600px;
            height: 600px;
            background: radial-gradient(circle, rgba(139,26,26,0.08) 0%, transparent 70%);
            pointer-events: none;
        }

        body::after {
            content: '';
            position: fixed;
            bottom: -20%;
            right: -10%;
            width: 500px;
            height: 500px;
            background: radial-gradient(circle, rgba(201,168,76,0.07) 0%, transparent 70%);
            pointer-events: none;
        }

        .login-container {
            background: white;
            border: 1px solid var(--border);
            border-radius: 4px;
            padding: 56px 48px;
            width: 100%;
            max-width: 420px;
            position: relative;
            box-shadow: 0 4px 40px rgba(0,0,0,0.06);
            animation: slideUp 0.5s ease;
        }

        @keyframes slideUp {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
        }

        .login-container::before {
            content: '';
            position: absolute;
            top: 0; left: 0; right: 0;
            height: 4px;
            background: linear-gradient(90deg, var(--maroon), var(--gold));
            border-radius: 4px 4px 0 0;
        }

        .logo-area {
            text-align: center;
            margin-bottom: 40px;
        }

        .logo-icon {
            width: 52px;
            height: 52px;
            background: var(--maroon);
            border-radius: 12px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 16px;
        }

        .logo-icon svg { color: white; }

        .logo-area h1 {
            font-family: 'DM Serif Display', serif;
            font-size: 26px;
            color: var(--text);
            letter-spacing: -0.5px;
        }

        .logo-area p {
            font-size: 13px;
            color: var(--muted);
            margin-top: 4px;
            letter-spacing: 0.5px;
            text-transform: uppercase;
        }

        .error-box {
            background: #FFF0F0;
            border: 1px solid #FFCDD2;
            border-radius: 6px;
            padding: 12px 16px;
            margin-bottom: 24px;
            font-size: 13.5px;
            color: #C62828;
        }

        .field {
            margin-bottom: 20px;
        }

        .field label {
            display: block;
            font-size: 12px;
            font-weight: 600;
            color: var(--muted);
            text-transform: uppercase;
            letter-spacing: 0.8px;
            margin-bottom: 8px;
        }

        .field input {
            width: 100%;
            padding: 12px 14px;
            border: 1.5px solid var(--border);
            border-radius: 6px;
            font-family: 'DM Sans', sans-serif;
            font-size: 14px;
            color: var(--text);
            background: white;
            transition: border-color 0.2s;
            outline: none;
        }

        .field input:focus {
            border-color: var(--maroon);
        }

        .btn-login {
            width: 100%;
            padding: 14px;
            background: var(--maroon);
            color: white;
            border: none;
            border-radius: 6px;
            font-family: 'DM Sans', sans-serif;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            margin-top: 8px;
            transition: background 0.2s, transform 0.1s;
            letter-spacing: 0.3px;
        }

        .btn-login:hover { background: var(--maroon-dark); }
        .btn-login:active { transform: scale(0.99); }

        .footer-note {
            text-align: center;
            margin-top: 28px;
            font-size: 12px;
            color: var(--muted);
        }

        .badge {
            display: inline-block;
            background: rgba(139,26,26,0.08);
            color: var(--maroon);
            font-size: 11px;
            font-weight: 600;
            padding: 3px 10px;
            border-radius: 20px;
            letter-spacing: 0.5px;
            text-transform: uppercase;
            margin-bottom: 12px;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="logo-area">
            <div class="logo-icon">
                <svg width="26" height="26" fill="none" viewBox="0 0 24 24" stroke="white" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"/>
                </svg>
            </div>
            <span class="badge">IT Admin</span>
            <h1>DataSphere</h1>
            <p>User Management Portal</p>
        </div>

        <?php if ($error): ?>
            <div class="error-box"><?= htmlspecialchars($error) ?></div>
        <?php endif; ?>

        <form method="POST">
            <div class="field">
                <label>Email Address</label>
                <input type="email" name="email" placeholder="admin@ashesi.edu.gh" required>
            </div>
            <div class="field">
                <label>Password</label>
                <input type="password" name="password" placeholder="••••••••" required>
            </div>
            <button type="submit" class="btn-login">Sign In to Admin Panel</button>
        </form>

        <p class="footer-note">Ashesi University · Facilities &amp; IT Department</p>
    </div>
</body>
</html>
