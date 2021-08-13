terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"
  access_key = "<access_key>"
  secret_key = "<secret_key>"
}

# 1. Create a VPC
resource "aws_vpc" "CUSTOM_VPC" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "Custom VPC"
  }
}
# 2. Create an Internet Gateway
resource "aws_internet_gateway" "CUSTOM_IGW" {
  vpc_id = aws_vpc.CUSTOM_VPC.id

  tags = {
    Name = "Custom Internet Gateway"
  }
}

# 3. Create a Route Table
resource "aws_route_table" "CUSTOM_RT" {
  vpc_id = aws_vpc.CUSTOM_VPC.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.CUSTOM_IGW.id
    }

  route {
      ipv6_cidr_block        = "::/0"
      #PAZI OVDE MOZHE DA IMA ERROR (brisi egress_only_)
      gateway_id = aws_internet_gateway.CUSTOM_IGW.id 
    }

  tags = {
    Name = "Custom Route Table"
  }
}
# 4. Create a Subnet
resource "aws_subnet" "CUSTOM_SUBNET" {
  vpc_id     = aws_vpc.CUSTOM_VPC.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Custom Subnet"
  }
}
# 5. Associate the subnet with the route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.CUSTOM_SUBNET.id
  route_table_id = aws_route_table.CUSTOM_RT.id
}
# 6. Create a Security Group to allow port 22,80,443
resource "aws_security_group" "CUSTOM_SG" {
  name        = "Allow Web Trafic"
  description = "Allow Web inbound traffic on port 22, 80, 443"
  vpc_id      = aws_vpc.CUSTOM_VPC.id

  ingress {
      description      = "HTTPS"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  ingress  {
      description      = "HTTP"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  ingress {
      description      = "SSH"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
    }

  tags = {
    Name = "Allow Web traffic"
  }
}
# 7. Create a Network Interface with an IP in the subnet that was created in step 4
resource "aws_network_interface" "CUSTOM_NIC" {
  subnet_id       = aws_subnet.CUSTOM_SUBNET.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.CUSTOM_SG.id]
}
# 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "CUSTOM_EIP" {
  vpc                       = true
  network_interface         = aws_network_interface.CUSTOM_NIC.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.CUSTOM_IGW]
}
# 9. Create an Unbuntu server and install apache2
resource "aws_instance" "CUSTOM_WEBSERVER" {
    ami = "ami-00399ec92321828f5"
    instance_type = "t2.micro"
    availability_zone = "us-east-2c"
    key_name = "terraform_key"

    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.CUSTOM_NIC.id
    }

    user_data = <<-EOF
                  #!/bin/bash
                  sudo apt update -y
                  sudo apt install apache2 -y
                  sudo systemctl start apache2
                  sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                  EOF
    tags = {
      Name = "Web Server"
    }
}

output "server_private_ip" {
  value = aws_instance.CUSTOM_WEBSERVER.private_ip
}

output "server_id" {
  value = aws_instance.CUSTOM_WEBSERVER.id
}