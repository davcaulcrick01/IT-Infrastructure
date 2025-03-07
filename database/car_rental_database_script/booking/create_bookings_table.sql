-- Create enum type for booking status if it doesn't exist
DO $$ BEGIN
  CREATE TYPE "BookingStatus" AS ENUM ('PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Bookings Table
CREATE TABLE IF NOT EXISTS "Booking" (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            UUID NOT NULL,
  car_id             UUID NOT NULL,
  start_date         TIMESTAMP NOT NULL,
  end_date           TIMESTAMP NOT NULL,
  total_price        FLOAT NOT NULL,
  status             "BookingStatus" NOT NULL DEFAULT 'PENDING',
  created_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_user FOREIGN KEY(user_id) REFERENCES "User"(id),
  CONSTRAINT fk_car FOREIGN KEY(car_id) REFERENCES "Car"(id)
);

-- Trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_booking_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE TRIGGER update_booking_updated_at
    BEFORE UPDATE ON "Booking"
    FOR EACH ROW
    EXECUTE FUNCTION update_booking_updated_at();
