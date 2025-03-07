output "database_instance_id" {
  description = "ID of the database EC2 instance"
  value       = aws_instance.database_instance.id
}

output "database_private_ip" {
  description = "Private IP of the database instance"
  value       = aws_instance.database_instance.private_ip
}

output "database_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.database_sg.id
}

output "database_endpoint" {
  description = "Database connection endpoint"
  value       = "${aws_instance.database_instance.private_ip}:${local.db_port}"
}

output "database_connection_string" {
  description = "Database connection string"
  value       = "${local.db_engine}://${var.db_username}:${var.db_password}@${aws_instance.database_instance.private_ip}:${local.db_port}/${var.db_name}"
  sensitive   = true
}

output "instance_private_ip" {
  description = "Private IP of the database instance"
  value       = aws_instance.database_instance.private_ip
}

output "instance_public_ip" {
  description = "Public IP of the database instance"
  value       = aws_instance.database_instance.public_ip
} 