output "zone_id" {
  description = "The Route 53 hosted zone ID"
  value       = aws_route53_zone.reason_zone.id
}

output "root_a_record" {
  description = "The A record for the root domain"
  value       = aws_route53_record.root_a_record.fqdn
}

output "www_cname_record" {
  description = "The CNAME record for www subdomain"
  value       = aws_route53_record.www_cname_record.fqdn
}
