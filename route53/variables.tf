variable "domain_name" {
  type        = string
  description = "The domain name for the hosted zone."
}

variable "a_record_ip" {
  type        = string
  description = "The IP address for the root A record."
}

variable "cname_target" {
  type        = string
  description = "The target for the CNAME record."
}

variable "region" {
  type        = string
  description = "The target for the CNAME record."
}

