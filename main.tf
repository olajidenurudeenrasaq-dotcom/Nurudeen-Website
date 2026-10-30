data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "website" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Nurudeen Website VPC"
  }
}

resource "aws_internet_gateway" "website" {
  vpc_id = aws_vpc.website.id

  tags = {
    Name = "Nurudeen Website IGW"
  }
}

resource "aws_subnet" "client" {
  vpc_id                  = aws_vpc.website.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "Nurudeen Website Client Subnet"
    Tier = "client"
  }
}

resource "aws_subnet" "middle" {
  vpc_id                  = aws_vpc.website.id
  cidr_block              = "10.20.2.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "Nurudeen Website Middle Subnet"
    Tier = "middle"
  }
}

resource "aws_route_table" "client" {
  vpc_id = aws_vpc.website.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.website.id
  }

  tags = {
    Name = "Nurudeen Website Client Routes"
  }
}

resource "aws_route_table_association" "client" {
  subnet_id      = aws_subnet.client.id
  route_table_id = aws_route_table.client.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "Nurudeen Website NAT EIP"
  }
}

resource "aws_nat_gateway" "website" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.client.id

  depends_on = [aws_route_table_association.client]

  tags = {
    Name = "Nurudeen Website NAT"
  }
}

resource "aws_route_table" "middle" {
  vpc_id = aws_vpc.website.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.website.id
  }

  tags = {
    Name = "Nurudeen Website Middle Routes"
  }
}

resource "aws_route_table_association" "middle" {
  subnet_id      = aws_subnet.middle.id
  route_table_id = aws_route_table.middle.id
}

resource "aws_security_group" "client" {
  name        = "nurudeens-website-client"
  description = "Allow public HTTP to the website client tier"
  vpc_id      = aws_vpc.website.id

  ingress {
    description = "Public website HTTP"
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

  tags = {
    Name = "Nurudeen Website Client SG"
  }
}

resource "aws_security_group" "middle" {
  name        = "nurudeens-website-middle"
  description = "Allow HTTP only from the client tier"
  vpc_id      = aws_vpc.website.id

  ingress {
    description     = "Client tier to middle tier"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.client.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Nurudeen Website Middle SG"
  }
}

resource "aws_instance" "middle" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.middle.id
  vpc_security_group_ids      = [aws_security_group.middle.id]
  associate_public_ip_address = false
  user_data_replace_on_change = true

  user_data = <<-USERDATA
    #!/bin/bash
    set -euxo pipefail
    dnf install -y httpd
    sed -i 's/^Listen 80$/Listen 8080/' /etc/httpd/conf/httpd.conf
    printf '%s\n' '<!doctype html><html><head><title>Middle tier</title></head><body><h1>Nurudeen Website middle tier is running.</h1></body></html>' > /var/www/html/index.html
    systemctl enable --now httpd
  USERDATA

  depends_on = [aws_route_table_association.middle]

  tags = {
    Name = "Nurudeen Website Middle Tier"
    Tier = "middle"
  }
}

resource "aws_instance" "client" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.client.id
  vpc_security_group_ids      = [aws_security_group.client.id]
  associate_public_ip_address = true
  user_data_replace_on_change = true

  user_data = <<-USERDATA
    #!/bin/bash
    set -euxo pipefail
    dnf install -y httpd
    cat > /var/www/html/index.html <<'HTML'
    <!doctype html>
    <html lang="en">
      <head><meta charset="utf-8"><title>Nurudeen's Website</title></head>
      <body>
        <h1>Welcome to Nurudeen's website!</h1>
        <p>This site is served by the public client tier.</p>
        <p><a href="/middle">Check the private middle tier</a></p>
      </body>
    </html>
    HTML
    cat > /etc/httpd/conf.d/middle-proxy.conf <<'APACHE'
    ProxyRequests Off
    ProxyPass /middle http://${aws_instance.middle.private_ip}:8080/
    ProxyPassReverse /middle http://${aws_instance.middle.private_ip}:8080/
    APACHE
    systemctl enable --now httpd
  USERDATA

  depends_on = [aws_route_table_association.client]

  tags = {
    Name = "Nurudeen Website"
    Tier = "client"
  }
}

resource "aws_eip" "website" {
  domain   = "vpc"
  instance = aws_instance.client.id

  tags = {
    Name = "Nurudeen Website"
  }
}
