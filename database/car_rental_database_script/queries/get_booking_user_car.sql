-- Get all bookings with user, car, service and payment details
SELECT 
  b.id AS booking_id,
  u.email AS user_email,
  c.make AS car_make,
  c.model AS car_model,
  c.license_plate,
  c.price_per_day,
  b.start_date,
  b.end_date,
  b.total_price,
  s.name AS service_name,
  s.price AS service_price,
  p.payment_method,
  p.status AS payment_status,
  p.payment_date
FROM "Booking" b
JOIN "User" u ON b.user_id = u.id
JOIN "Car" c ON b.car_id = c.id
LEFT JOIN "ServiceBooking" sb ON b.id = sb.booking_id
LEFT JOIN "Service" s ON sb.service_id = s.id
LEFT JOIN "Payment" p ON b.id = p.booking_id;
