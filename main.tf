terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 1.1.9"
}

provider "aws" {
  profile = "default"
  region  = var.region
}

# Creating VPC,name, CIDR and Tags
resource "aws_vpc" "vpc_tcc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"
  tags = {
    Name = "vpc_tcc"
  }
}

# Creating Public Subnets in VPC
resource "aws_subnet" "tcc-public-1" {
  vpc_id                  = aws_vpc.vpc_tcc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "us-west-2a"

  tags = {
    Name = "tcc-public-1"
  }
}

resource "aws_subnet" "tcc-public-2" {
  vpc_id                  = aws_vpc.vpc_tcc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "us-west-2b"

  tags = {
    Name = "tcc-public-2"
  }
}

# Creating Private Subnets in VPC
resource "aws_subnet" "tcc-private-1" {
  vpc_id                  = aws_vpc.vpc_tcc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = "false"
  availability_zone       = "us-west-2a"

  tags = {
    Name = "tcc-private-1"
  }
}

resource "aws_subnet" "tcc-private-2" {
  vpc_id                  = aws_vpc.vpc_tcc.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = "false"
  availability_zone       = "us-west-2b"

  tags = {
    Name = "tcc-private-2"
  }
}


# Creating Internet Gateway in AWS VPC
resource "aws_internet_gateway" "tcc-gw" {
  vpc_id = aws_vpc.vpc_tcc.id

  tags = {
    Name = "tcc-gw"
  }
}

# Creating Route Tables for Internet gateway
resource "aws_route_table" "tcc-public" {
  vpc_id = aws_vpc.vpc_tcc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tcc-gw.id
  }

  tags = {
    Name = "tcc-public-1"
  }
}

# Creating Route Associations public subnets
resource "aws_route_table_association" "tcc-public-1-a" {
  subnet_id      = aws_subnet.tcc-public-1.id
  route_table_id = aws_route_table.tcc-public.id
}

resource "aws_route_table_association" "tcc-public-2-a" {
  subnet_id      = aws_subnet.tcc-public-2.id
  route_table_id = aws_route_table.tcc-public.id
}



resource "aws_security_group" "allow_ssh" {
  name        = "name_security_group"
  description = "Allow ssh inbound traffic"
  vpc_id      = aws_vpc.vpc_tcc.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

    ingress {
    description      = "https"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "grafana"
    from_port        = 3000
    to_port          = 3000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_instance" "app_wordpress" {
 ami = var.ami_aws_instance
 instance_type = var.type_aws_instance
 vpc_security_group_ids = [aws_security_group.allow_ssh.id]
 key_name = var.keys_aws_instance
 user_data = <<-EOF
 #!/bin/bash
 sudo apt update && sudo apt install curl ansible unzip -y
 cd /tmp
 wget https://github.com/leg1on4rio/tcc/raw/master/ansible.zip
 unzip ansible.zip
 sudo ansible-playbook wordpress.yml
 EOF
 monitoring = true
 subnet_id = aws_subnet.tcc-public-1.id
 associate_public_ip_address = true
 tags = {
 Name = "app_wordpress"
 }
}

resource "aws_instance" "zabbix_server" {
 ami = var.ami_aws_instance
 instance_type = "t3.small"
 vpc_security_group_ids = [aws_security_group.allow_ssh.id]
 key_name = var.keys_aws_instance
 user_data = <<-EOF
 #!/bin/bash
 curl -fsSL https://get.docker.com -o get-docker.sh
 sudo sh get-docker.sh
 wget https://raw.githubusercontent.com/leg1on4rio/tcc/master/docker-compose.yml
 sudo apt install docker-compose -y
 sudo docker-compose up -d
 EOF
 monitoring = true
 subnet_id = aws_subnet.tcc-public-1.id
 associate_public_ip_address = true
 tags = {
 Name = "zabbix_server"
 }
}

