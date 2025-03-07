-- Payments Table
CREATE TABLE "Payment" (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id         UUID NOT NULL,
    amount             NUMERIC NOT NULL,
    payment_date       TIMESTAMP DEFAULT now() NOT NULL,
    payment_method     VARCHAR NOT NULL,
    status             VARCHAR DEFAULT 'SUCCESS' NOT NULL,
    created_at         TIMESTAMP DEFAULT now() NOT NULL,
    updated_at         TIMESTAMP DEFAULT now() NOT NULL,
    CONSTRAINT fk_booking FOREIGN KEY(booking_id) REFERENCES "Booking"(id) ON DELETE CASCADE
);