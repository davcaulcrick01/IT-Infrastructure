resource "aws_ecr_repository" "car_rental_app" {
  name                 = "car-rental-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "production"
    Application = "Car Rental App"
  }
}