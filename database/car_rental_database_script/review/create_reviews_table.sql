-- Reviews Table
DO $$ 
BEGIN
    -- Create Review table if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'Review') THEN
        CREATE TABLE "Review" (
            id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            rating            INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
            comment           TEXT,
            user_id           UUID NOT NULL,
            car_id            UUID NOT NULL,
            created_at        TIMESTAMP DEFAULT now() NOT NULL,
            updated_at        TIMESTAMP DEFAULT now() NOT NULL,
            CONSTRAINT fk_user_review FOREIGN KEY(user_id) REFERENCES "User"(id),
            CONSTRAINT fk_car_review FOREIGN KEY(car_id) REFERENCES "Car"(id)
        );
    END IF;

    -- Add or update constraints regardless if table exists
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'fk_user_review'
    ) THEN
        ALTER TABLE "Review"
        ADD CONSTRAINT fk_user_review FOREIGN KEY(user_id) REFERENCES "User"(id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'fk_car_review'
    ) THEN
        ALTER TABLE "Review"
        ADD CONSTRAINT fk_car_review FOREIGN KEY(car_id) REFERENCES "Car"(id);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at timestamp
CREATE OR REPLACE FUNCTION update_review_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER update_review_updated_at
    BEFORE UPDATE ON "Review"
    FOR EACH ROW
    EXECUTE FUNCTION update_review_updated_at();