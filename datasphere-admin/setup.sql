-- Run this once in phpMyAdmin to set up user management
-- =====================================================

-- 1. Add status column to users table (if not already there)
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'approved';

-- 2. Set all existing users as approved by default
UPDATE users SET status = 'approved' WHERE status IS NULL OR status = '';

-- 3. Create an IT Admin account (change password after first login!)
--    Password below is: Admin@1234
INSERT INTO users (name, email, password_hash, role, status, created_at)
VALUES (
    'IT Admin',
    'itadmin@ashesi.edu.gh',
    '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uJa/jPGHS', 
    'admin',
    'approved',
    NOW()
);

-- NOTE: The password hash above = "password" (Laravel default hash for testing)
-- To generate a real hash, run this PHP: echo password_hash('YourPassword', PASSWORD_DEFAULT);
-- Or use this SQL to set a custom password hash after creating the admin:
-- UPDATE users SET password_hash = password_hash('YourPassword') WHERE email = 'itadmin@ashesi.edu.gh';
