CREATE TABLE "Service" (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name              VARCHAR NOT NULL,
    description       TEXT,
    price             DECIMAL NOT NULL,
    duration_minutes  INTEGER NOT NULL,
    availability     INTEGER DEFAULT 1 NOT NULL,
    service_type     VARCHAR(50) NOT NULL,
    status           VARCHAR(20) DEFAULT 'ACTIVE' NOT NULL,
    reason_inactive  TEXT,
    last_active_date TIMESTAMP,
    created_at       TIMESTAMP DEFAULT now() NOT NULL,
    updated_at       TIMESTAMP DEFAULT now() NOT NULL,
    CONSTRAINT check_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'DISCONTINUED', 'MAINTENANCE'))
);

CREATE INDEX idx_service_status ON "Service"(status);
CREATE INDEX idx_service_type ON "Service"(service_type);
