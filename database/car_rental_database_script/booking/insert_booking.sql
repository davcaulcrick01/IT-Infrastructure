-- Insert sample bookings for different car types
-- Luxury Car Booking
INSERT INTO "Booking" (user_id, car_id, start_date, end_date, total_price) 
VALUES (
  (SELECT id FROM "User" WHERE email = 'test@example.com'),
  (SELECT id FROM "Car" WHERE model IN ('S-Class', 'A8', '7 Series') LIMIT 1),
  '2024-03-01', '2024-03-07', 2899.99
);

-- Exotic Car Booking
INSERT INTO "Booking" (user_id, car_id, start_date, end_date, total_price) 
VALUES (
  (SELECT id FROM "User" WHERE email = 'test@example.com'),
  (SELECT id FROM "Car" WHERE model IN ('Aventador', '488 GTB', 'GT3 RS') LIMIT 1),
  '2024-04-01', '2024-04-03', 3999.99
);

-- SUV Booking with Services
INSERT INTO "Booking" (user_id, car_id, start_date, end_date, total_price) 
VALUES (
  (SELECT id FROM "User" WHERE email = 'test@example.com'),
  (SELECT id FROM "Car" WHERE model IN ('G-Wagon', 'Cayenne', 'Urus') LIMIT 1),
  '2024-05-01', '2024-05-07', 2499.99
);

-- Add chauffeur service to the SUV booking
INSERT INTO "ServiceBooking" (booking_id, service_id)
VALUES (
  (SELECT id FROM "Booking" WHERE user_id = (SELECT id FROM "User" WHERE email = 'test@example.com') ORDER BY created_at DESC LIMIT 1),
  (SELECT id FROM "Service" WHERE name = 'Chauffeur Service')
);