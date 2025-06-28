output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.vpc.id
}

output "public_subnet_id" {
  description = "The ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "The ID of the first private subnet"
  value       = aws_subnet.private.id
}

output "private2_subnet_id" {
  description = "The ID of the second private subnet"
  value       = aws_subnet.private2.id
}

output "private_subnet_ids" {
  description = "List of all private subnet IDs"
  value       = [aws_subnet.private.id, aws_subnet.private2.id]
}
