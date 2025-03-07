-- Users Table
CREATE TABLE "User" (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email              VARCHAR UNIQUE NOT NULL,
  password           VARCHAR NOT NULL,
  name               VARCHAR,
  role               VARCHAR DEFAULT 'USER' NOT NULL,
  phone_number       VARCHAR,
  address            VARCHAR,
  profile_image      VARCHAR,
  email_verified     BOOLEAN DEFAULT false NOT NULL,
  is_active          BOOLEAN DEFAULT true NOT NULL,
  last_login         TIMESTAMP,
  google_id          VARCHAR UNIQUE,
  apple_id           VARCHAR UNIQUE,
  reset_password_token VARCHAR,
  token_expiry       TIMESTAMP,
  created_at         TIMESTAMP DEFAULT now() NOT NULL,
  updated_at         TIMESTAMP DEFAULT now() NOT NULL
);

-- Add foreign key constraints for relationships
-- These statements will verify the foreign key relationships are properly set up
SELECT tc.constraint_name, tc.table_name, kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name IN ('Booking', 'Review', 'ServiceBooking', 'AuditLog', 'LoginSession')
  AND kcu.column_name = 'user_id';