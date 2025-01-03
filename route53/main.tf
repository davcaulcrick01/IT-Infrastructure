########################################
# Public Hosted Zone
########################################
resource "aws_route53_zone" "reason_zone" {
  name = var.domain_name

  tags = {
    Name = "Reason-Hosted-Zone"
  }
}

########################################
# A Record for the Root Domain
########################################
resource "aws_route53_record" "root_a_record" {
  zone_id = aws_route53_zone.reason_zone.id
  name    = var.domain_name
  type    = "A"
  ttl     = "300"

  # Replace this with the IP of your load balancer or server
  records = [var.a_record_ip]
}

########################################
# CNAME Record for Subdomain
########################################
resource "aws_route53_record" "www_cname_record" {
  zone_id = aws_route53_zone.reason_zone.id
  name    = "www.${var.domain_name}"
  type    = "CNAME"
  ttl     = "300"

  # Replace this with your desired target domain (e.g., an S3 website bucket)
  records = [var.cname_target]
}
