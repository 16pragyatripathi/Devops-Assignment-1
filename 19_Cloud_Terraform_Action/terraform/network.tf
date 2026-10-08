# ---------------------------------------------------------------- VPC + IGW
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.project}-igw" }
}

# ------------------------------------------------------------------ Subnets
# cidrsubnet(10.20.0.0/16, 8, n) -> 10.20.n.0/24
# public : 10.20.1.0/24 (AZ a), 10.20.2.0/24 (AZ b)
# private: 10.20.11.0/24 (AZ a), 10.20.12.0/24 (AZ b)
resource "aws_subnet" "public" {
  count = length(var.azs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-public-${substr(var.azs[count.index], -1, 1)}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  count = length(var.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 11)
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.project}-private-${substr(var.azs[count.index], -1, 1)}"
    Tier = "private"
  }
}

# ------------------------------------------------------------- Route tables
# What makes a subnet "public" is this route to the internet gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# The private route table only has the implicit "local" route, unless the
# optional NAT gateway is switched on.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.project}-private-rt" }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ------------------------------------------------- Optional NAT gateway
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = { Name = "${var.project}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id # a NAT gateway lives in a PUBLIC subnet

  tags       = { Name = "${var.project}-nat" }
  depends_on = [aws_internet_gateway.main]
}

resource "aws_route" "private_to_nat" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

# ---------------------------------------------------------- Security groups
resource "aws_security_group" "web" {
  name        = "${var.project}-web-sg"
  description = "HTTP/HTTPS from anywhere, SSH from one admin IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from admin IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-web-sg" }
}

resource "aws_security_group" "app" {
  name        = "${var.project}-app-sg"
  description = "App port reachable only from the web tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App traffic from web servers only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id] # a group, not an IP range
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-app-sg" }
}
