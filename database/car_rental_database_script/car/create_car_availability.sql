-- Car Availability Table
CREATE TABLE IF NOT EXISTS "CarAvailability" (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    car_id             UUID NOT NULL,
    date               TIMESTAMP NOT NULL,
    is_available       BOOLEAN DEFAULT true NOT NULL,
    created_at         TIMESTAMP DEFAULT now() NOT NULL,
    updated_at         TIMESTAMP DEFAULT now() NOT NULL,
    CONSTRAINT fk_car_availability FOREIGN KEY(car_id) REFERENCES "Car"(id) ON DELETE CASCADE,
    UNIQUE(car_id, date)
);

-- Trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_car_availability_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE TRIGGER update_car_availability_updated_at
    BEFORE UPDATE ON "CarAvailability"
    FOR EACH ROW
    EXECUTE FUNCTION update_car_availability_updated_at();