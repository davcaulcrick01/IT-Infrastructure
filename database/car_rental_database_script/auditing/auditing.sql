-- AuditLog Table
CREATE TABLE "AuditLog" (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL,
  action          VARCHAR NOT NULL,
  entity_type     VARCHAR NOT NULL,
  entity_id       VARCHAR NOT NULL,
  changes         JSON NOT NULL,
  timestamp       TIMESTAMP DEFAULT now() NOT NULL
);