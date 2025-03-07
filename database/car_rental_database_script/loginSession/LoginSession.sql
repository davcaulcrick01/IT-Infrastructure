-- LoginSession Table
CREATE TABLE "LoginSession" (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL,
  token           VARCHAR NOT NULL UNIQUE,
  device_info     VARCHAR,
  ip_address      VARCHAR,
  last_active     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at      TIMESTAMP NOT NULL,
  is_valid        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES "User"(id)
);

-- Trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_login_session_updated_at
    BEFORE UPDATE ON "LoginSession"
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Sample query to view login sessions (commented out to prevent execution during table creation)
-- SELECT * FROM "LoginSession";