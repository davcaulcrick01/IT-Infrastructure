CREATE TABLE "_prisma_migrations" (
    id SERIAL PRIMARY KEY,
    checksum VARCHAR(64) NOT NULL,
    finished_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    migration_name VARCHAR(255) NOT NULL,
    logs TEXT,
    rolled_back_at TIMESTAMP,
    applied_steps_count INTEGER NOT NULL DEFAULT 0,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    database_version VARCHAR(255)
);
