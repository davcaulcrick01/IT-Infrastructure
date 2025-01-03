########################################
# NAT Gateway (for Private Subnet outbound access)
########################################

# Allocate an Elastic IP for the NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-NAT-EIP"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id  # NAT gateway lives in the public subnet

  tags = {
    Name = "${local.name_prefix}-nat-gateway"
  }
}
