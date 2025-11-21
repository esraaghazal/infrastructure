# Provider
provider "aws" {
  region = "us-east-1"
}

# VPC 
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Groups
resource "aws_security_group" "public_sg" {
  name        = "public-sg"
  description = "Allow SSH & web"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow DB traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instances (Frontend & Backend)

locals {
  ami = "ami-0fc5d935ebf8bc3bc" 
}

resource "aws_instance" "backend" {
  ami           = local.ami
  instance_type = "t2.micro"
  subnet_id     = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
  }

  tags = {
    Name = "backend-server"
  }
}

resource "aws_instance" "frontend" {
  ami           = local.ami
  instance_type = "t2.micro"
  subnet_id     = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
  }

  tags = {
    Name = "frontend-server"
  }
}

# RDS MySQL

resource "aws_db_instance" "mysql" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = "admin"
  password             = "admin12345"
  db_subnet_group_name = aws_db_subnet_group.rds_subnet.id
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot  = true
  publicly_accessible  = false
}

resource "aws_db_subnet_group" "rds_subnet" {
  name       = "rds-subnet"
  subnet_ids = data.aws_subnets.default.ids
}

# Outputs
output "frontend_ip" {
  value = aws_instance.frontend.public_ip
}

output "backend_ip" {
  value = aws_instance.backend.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.mysql.address
}
