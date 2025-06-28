########################################
# Public Subnet
########################################
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.reason_public_cidr # Using local variable
  availability_zone       = local.public_az          # Using local variable
  map_public_ip_on_launch = true                     # public IP by default for instances

  tags = {
    Name = "${local.name_prefix}-public-subnet"
  }
}

########################################
# Private Subnet 1
########################################
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = local.reason_private_cidr
  availability_zone = local.private_az

  tags = {
    Name = "${local.name_prefix}-private-subnet-1"
  }
}

########################################
# Private Subnet 2
########################################
resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = local.reason_private2_cidr
  availability_zone = local.private2_az

  tags = {
    Name = "${local.name_prefix}-private-subnet-2"
  }
}