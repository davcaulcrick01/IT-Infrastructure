CREATE TABLE "ServiceBooking" (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id         UUID NOT NULL,
    service_id         UUID NOT NULL,
    status             VARCHAR DEFAULT 'PENDING' NOT NULL,
    scheduled_date     TIMESTAMP NOT NULL,
    completed_date     TIMESTAMP,
    notes              TEXT,
    created_at         TIMESTAMP DEFAULT now() NOT NULL,
    updated_at         TIMESTAMP DEFAULT now() NOT NULL,
    CONSTRAINT fk_booking_service FOREIGN KEY(booking_id) REFERENCES "Booking"(id) ON DELETE CASCADE,
    CONSTRAINT fk_service FOREIGN KEY(service_id) REFERENCES "Service"(id) ON DELETE CASCADE,
    CONSTRAINT check_status CHECK (status IN ('PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'))
);
