resource "aws_vpc" "telemetry_vpc" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    "Name" = "telemetry_vpc-pr-${var.pr_number}"
  }
}

resource "aws_subnet" "telemetry_public_subnet_1a" {
  vpc_id                  = aws_vpc.telemetry_vpc.id
  cidr_block              = var.subnet_cidr_blocks[0]
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    "Name" = "public_subnet_1a-pr-${var.pr_number}"
  }
}

resource "aws_subnet" "telemetry_private_subnet_1a" {
  vpc_id                  = aws_vpc.telemetry_vpc.id
  cidr_block              = var.subnet_cidr_blocks[1]
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = false

  tags = {
    "Name" = "private_subnet_1a-pr-${var.pr_number}"
  }
}

resource "aws_subnet" "telemetry_private_subnet_1b" {
  vpc_id                  = aws_vpc.telemetry_vpc.id
  cidr_block              = var.subnet_cidr_blocks[2]
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = false

  tags = {
    "Name" = "private_subnet_1b-pr-${var.pr_number}"
  }
}

resource "aws_internet_gateway" "telemetry_ig" {
  vpc_id = aws_vpc.telemetry_vpc.id

  tags = {
    "Name" = "telemetry_ig-pr-${var.pr_number}"
  }
}

resource "aws_route_table" "telemetry_rt" {
  vpc_id = aws_vpc.telemetry_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.telemetry_ig.id
  }

  tags = {
    "Name" = "telemetry_rt-pr-${var.pr_number}"
  }
}

resource "aws_route_table_association" "telemetry_rta" {
  subnet_id      = aws_subnet.telemetry_public_subnet_1a.id
  route_table_id = aws_route_table.telemetry_rt.id
}

resource "aws_eip" "telemetry_eip" {
  domain = "vpc"

  tags = {
    Name = "telemetry_nat_eip-pr-${var.pr_number}"
  }
}

resource "aws_nat_gateway" "telemetry_nat" {
  allocation_id = aws_eip.telemetry_eip.id
  subnet_id     = aws_subnet.telemetry_public_subnet_1a.id

  tags = {
    Name = "telemetry_nat-pr-${var.pr_number}"
  }
}

resource "aws_route_table" "telemetry_private_rt" {
  vpc_id = aws_vpc.telemetry_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.telemetry_nat.id
  }

  tags = {
    Name = "telemetry_private_rt-pr-${var.pr_number}"
  }
}

resource "aws_route_table_association" "telemetry_private_rta" {
  subnet_id      = aws_subnet.telemetry_private_subnet_1a.id
  route_table_id = aws_route_table.telemetry_private_rt.id
}

resource "aws_route_table_association" "telemetry_private_rtb" {
  subnet_id      = aws_subnet.telemetry_private_subnet_1b.id
  route_table_id = aws_route_table.telemetry_private_rt.id
}

resource "aws_security_group" "iot_sg" {
  name        = "iot-sg-pr-${var.pr_number}"
  description = "Security group for IoT VPC Endpoint"
  vpc_id      = aws_vpc.telemetry_vpc.id

  egress {
    description = "Allow IoT to connect to MSK"
    from_port   = 9096
    to_port     = 9096
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  tags = {
    Name = "iot-sg-pr-${var.pr_number}"
    PR   = var.pr_number
  }
}

resource "aws_security_group" "consumer_sg" {
  name        = "test-msk-sg-pr-${var.pr_number}"
  description = "Security group for Lambda MSK consumer"
  vpc_id      = aws_vpc.telemetry_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr_block]
  }

  tags = {
    Name = "test-msk-sg-pr-${var.pr_number}"
    PR   = var.pr_number
  }
}

resource "aws_security_group" "kafka_sg" {
  name        = "msk-sg-pr-${var.pr_number}"
  description = "Security group for MSK cluster"
  vpc_id      = aws_vpc.telemetry_vpc.id

  ingress {
    from_port       = 9096
    to_port         = 9096
    protocol        = "tcp"
    security_groups = [aws_security_group.iot_sg.id]
  }

  ingress {
    from_port       = 9096
    to_port         = 9096
    protocol        = "tcp"
    security_groups = [aws_security_group.consumer_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr_block]
  }

  tags = {
    Name = "msk-sg-pr-${var.pr_number}"
    PR   = var.pr_number
  }
}
