########################################
# Public Subnet
########################################
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block             = "10.0.1.0/24"      # <-- Update as needed
  availability_zone       = "us-east-1a"      # <-- Update or parameterize
  map_public_ip_on_launch = true             # public IP by default for instances

  tags = {
    Name = "${local.name_prefix}-public-subnet"
  }
}

########################################
# Private Subnet
########################################
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"         
  availability_zone = "us-east-1a"      

  tags = {
    Name = "${local.name_prefix}-private-subnet"
  }
}