-- InsuranceClaim Table
CREATE TABLE "InsuranceClaim" (
  id                SERIAL PRIMARY KEY,
  damage_report_id  INT UNIQUE NOT NULL,
  claim_number      VARCHAR UNIQUE NOT NULL,
  status            VARCHAR NOT NULL,
  estimated_damage  FLOAT NOT NULL,
  deductible_amount FLOAT NOT NULL,
  insurance_provider VARCHAR NOT NULL,
  adjuster_name     VARCHAR,
  adjuster_contact  VARCHAR,
  FOREIGN KEY (damage_report_id) REFERENCES "DamageReport"(id)
);