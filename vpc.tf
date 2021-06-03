terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_vpc" "production-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "vpc by terraform"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.production-vpc.id
  tags = {
    Name = "gateway by terraform"
  }

}

resource "aws_route_table" "production-route-table" {
  vpc_id = aws_vpc.production-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "route table by terraform"
  }
}

resource "aws_subnet" "terraform-subnet" {
  vpc_id            = aws_vpc.production-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "subnet by terraform"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.terraform-subnet.id
  route_table_id = aws_route_table.production-route-table.id
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web.traffic"
  description = "Allow TLS web traffic"
  vpc_id      = aws_vpc.production-vpc.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" //any protocol
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "webserver-nic" {
  subnet_id       = aws_subnet.terraform-subnet.id
  private_ips     = ["10.0.1.51"]
  security_groups = [aws_security_group.allow_web.id]

}

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.webserver-nic.id
  associate_with_private_ip = "10.0.1.51"
  depends_on                = [aws_internet_gateway.gw]
}

resource "aws_instance" "terraform-ec2" {
  ami               = "ami-02f26adf094f51167"
  instance_type     = "t2.micro"
  availability_zone = "ap-southeast-1a"
  key_name          = "jatin-marek-learning1-key-pair"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.webserver-nic.id
  }

  user_data = <<-EOF
		#! /bin/bash
                sudo yum update
		sudo yum install -y httpd
		sudo systemctl start httpd
		sudo systemctl enable httpd
		echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
	EOF
  tags = {
    Name = "Created by Terraform"
  }
}
