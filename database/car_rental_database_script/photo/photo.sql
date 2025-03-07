-- Photo Table
DROP TABLE IF EXISTS "Photo";

CREATE TABLE "Photo" (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  damage_report_id INT NOT NULL,
  url             VARCHAR NOT NULL,
  caption         VARCHAR,
  date_uploaded   TIMESTAMP DEFAULT now() NOT NULL,
  created_at      TIMESTAMP DEFAULT now() NOT NULL,
  updated_at      TIMESTAMP DEFAULT now() NOT NULL,
  FOREIGN KEY (damage_report_id) REFERENCES "DamageReport"(id) ON DELETE CASCADE
);