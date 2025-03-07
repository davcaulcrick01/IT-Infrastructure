-- DamageReport Table
CREATE TABLE "DamageReport" (
  id                SERIAL PRIMARY KEY,
  car_id            INT NOT NULL,
  rental_id         INT NOT NULL,
  date_of_incident  TIMESTAMP NOT NULL,
  location_of_incident VARCHAR NOT NULL,
  driver_statement  VARCHAR NOT NULL,
  damage_description VARCHAR NOT NULL,
  weather_conditions VARCHAR NOT NULL,
  police_report_filed BOOLEAN NOT NULL,
  police_report_number VARCHAR
);