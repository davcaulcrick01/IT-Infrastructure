-- Cars Table
CREATE TABLE "Car" (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  make               VARCHAR NOT NULL,
  model              VARCHAR NOT NULL,
  year               INT NOT NULL,
  color              VARCHAR NOT NULL,
  license_plate      VARCHAR UNIQUE NOT NULL,
  price              FLOAT NOT NULL,
  is_available       BOOLEAN DEFAULT true NOT NULL,
  images             TEXT[] NOT NULL DEFAULT '{}',
  category           "CarCategory" NOT NULL,
  features           TEXT[] NOT NULL DEFAULT '{}',
  created_at         TIMESTAMP DEFAULT now() NOT NULL,
  updated_at         TIMESTAMP DEFAULT now() NOT NULL
);

-- Create indexes for foreign key relationships
CREATE INDEX "Car_id_idx" ON "Car"(id);

-- Create trigger for updated_at timestamp
CREATE OR REPLACE FUNCTION update_car_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_car_updated_at
    BEFORE UPDATE ON "Car"
    FOR EACH ROW
    EXECUTE FUNCTION update_car_updated_at();