

# Variables
variable "access_key" {
  description = "access_key security credential for AWS account"
  type = string
  sensitive = true 
}

variable "secret_key" {
  description = "secret_key security credential for AWS account"
  type = string
  sensitive = true 
}

variable "key_pair" {
  description = "key pair used to access your AWS EC2 instance"
  type = string
  sensitive = true
}

variable "region" {
  description                 = "AWS Region"
  type                        = string
  default                     = "us-west-2"
}

variable "availability_zone" {
  description                 = "AWS Availability Zone"
  type                        = string
  default                     = "us-west-2a"
}

# AWS Provider initalization
provider "aws" {
  region                      = var.region
  access_key                  = var.access_key
  secret_key                  = var.secret_key
}

# 1. Create VPC
resource "aws_vpc" "prod_vpc" {
  cidr_block                  = "10.0.0.0/16"

  tags = {
    Name = "production_vpc"
  }
}

# 2. Create internet gateway
resource "aws_internet_gateway" "prod_gateway" {
  vpc_id                      = aws_vpc.prod_vpc.id

  tags = {
    Name = "production_gateway"
  }
}

# 3. Create customer route table
resource "aws_route_table" "prod_route_table" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block                = "0.0.0.0/0"
    gateway_id                = aws_internet_gateway.prod_gateway.id
  }

  route {
    ipv6_cidr_block           = "::/0"
    gateway_id                = aws_internet_gateway.prod_gateway.id
  }

  tags = {
    Name = "production_route_table"
  }
}

# 4. Create a subnet
resource "aws_subnet" "prod_subnet" {
  vpc_id                      = aws_vpc.prod_vpc.id
  cidr_block                  = "10.0.1.0/24"
  availability_zone           = var.availability_zone

  tags = {
    Name = "production_subnet"
  }
}

# 5. Associate subnet with route table
resource "aws_route_table_association" "public_a" {
  subnet_id                 = aws_subnet.prod_subnet.id
  route_table_id            = aws_route_table.prod_route_table.id
}

# 6. Create security group to allow port 22, 80, and 443
resource "aws_security_group" "allow_web" {
  name                      = "allow_web_traffic"
  description               = "Allow web inbound traffic"
  vpc_id                    = aws_vpc.prod_vpc.id

  ingress {
    description             = "https traffic"
    from_port               = 443
    to_port                 = 443
    protocol                = "tcp"
    cidr_blocks             = ["0.0.0.0/0"]
  }

  ingress {
    description             = "http traffic"
    from_port               = 80
    to_port                 = 80
    protocol                = "tcp"
    cidr_blocks             = ["0.0.0.0/0"]
  }

  ingress {
    description             = "ssh traffic"
    from_port               = 22
    to_port                 = 22
    protocol                = "tcp"
    cidr_blocks             = ["104.175.192.7/32"]
  }

  egress {
    from_port               = 0
    to_port                 = 0
    protocol                = "-1"
    cidr_blocks             = ["0.0.0.0/0"]
    ipv6_cidr_blocks        = ["::/0"]
  }

  tags = {
    Name = "allow_web_traffic"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "prod_network_interface" {
  subnet_id                 = aws_subnet.prod_subnet.id
  private_ips               = ["10.0.1.50"]
  security_groups           = [aws_security_group.allow_web.id]
}

# 8. Assign elasticIP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.prod_network_interface.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.prod_gateway]
}

# prints out public dns at the end of terrraform apply or terraform refresh
output "server_public_dns" {
  value = aws_eip.one.public_dns
}

# 9. Create Ubuntu server with ngnix
# Ubuntu Server 20.04 LTS (HVM), SSD Volume Type
resource "aws_instance" "web_server" {
  ami                       = "ami-0ca5c3bd5a268e7db"
  instance_type             = "t2.micro"
  availability_zone         = var.availability_zone
  key_name                  = var.key_pair

  network_interface {
    device_index            = 0
    network_interface_id    = aws_network_interface.prod_network_interface.id
  }

  user_data = <<EOT
                #cloud-config
                # update apt on boot
                package_update: true
                # install nginx
                packages:
                - nginx
                write_files:
                - content: |
                    <!DOCTYPE html>
                    <html>
                    <head>
                      <title>StackPath - Amazon Web Services Instance</title>
                      <meta http-equiv="Content-Type" content="text/html;charset=UTF-8">
                      <style>
                        html, body {
                          background: #000;
                          height: 100%;
                          width: 100%;
                          padding: 0;
                          margin: 0;
                          display: flex;
                          justify-content: center;
                          align-items: center;
                          flex-flow: column;
                        }
                        img { width: 250px; }
                        svg { padding: 0 40px; }
                        p {
                          color: #fff;
                          font-family: 'Courier New', Courier, monospace;
                          text-align: center;
                          padding: 10px 30px;
                        }
                      </style>
                    </head>
                    <body>
                      <img src="https://www.stackpath.com/content/images/logo-and-branding/stackpath-logo-standard-screen.svg">
                      <p>This request was proxied from <strong>Amazon Web Services</strong></p>
                    </body>
                    </html>
                  path: /usr/share/app/index.html
                  permissions: '0644'
                runcmd:
                - cp /usr/share/app/index.html /usr/share/nginx/html/index.html
                EOT

  tags = {
    Name = "web_server"
  }
} 
