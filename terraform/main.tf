terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_vpc" "chat_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "chat-vpc"
  }
}

resource "aws_subnet" "chat_subnet_public_a" {
  vpc_id                  = aws_vpc.chat_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "chat-subnet-public-a"
  }
}

resource "aws_subnet" "chat_subnet_public_b" {
  vpc_id                  = aws_vpc.chat_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "chat-subnet-public-b"
  }
}

resource "aws_subnet" "chat_subnet_private_a" {
  vpc_id            = aws_vpc.chat_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "chat-subnet-private-a"
  }
}

resource "aws_subnet" "chat_subnet_private_b" {
  vpc_id            = aws_vpc.chat_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "chat-subnet-private-b"
  }
}

resource "aws_internet_gateway" "chat_igw" {
  vpc_id = aws_vpc.chat_vpc.id

  tags = {
    Name = "chat-igw"
  }
}

resource "aws_eip" "chat_nat_eip" {
  domain = "vpc"

  tags = {
    Name = "chat-nat-eip"
  }
}

resource "aws_nat_gateway" "chat_nat_gw" {
  allocation_id = aws_eip.chat_nat_eip.id
  subnet_id     = aws_subnet.chat_subnet_public_a.id

  tags = {
    Name = "chat-nat-gw"
  }
}

resource "aws_route_table" "chat_rt_public" {
  vpc_id = aws_vpc.chat_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.chat_igw.id
  }

  tags = {
    Name = "chat-rt-public"
  }
}

resource "aws_route_table_association" "chat_rta_public_a" {
  subnet_id      = aws_subnet.chat_subnet_public_a.id
  route_table_id = aws_route_table.chat_rt_public.id
}

resource "aws_route_table_association" "chat_rta_public_b" {
  subnet_id      = aws_subnet.chat_subnet_public_b.id
  route_table_id = aws_route_table.chat_rt_public.id
}

resource "aws_route_table" "chat_rt_private" {
  vpc_id = aws_vpc.chat_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.chat_nat_gw.id
  }

  tags = {
    Name = "chat-rt-private"
  }
}

resource "aws_route_table_association" "chat_rta_private_a" {
  subnet_id      = aws_subnet.chat_subnet_private_a.id
  route_table_id = aws_route_table.chat_rt_private.id
}

resource "aws_route_table_association" "chat_rta_private_b" {
  subnet_id      = aws_subnet.chat_subnet_private_b.id
  route_table_id = aws_route_table.chat_rt_private.id
}

resource "aws_security_group" "chat_sg_alb" {
  name        = "chat-sg-alb"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.chat_vpc.id

  ingress {
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
    Name = "chat-sg-alb"
  }
}

resource "aws_security_group" "chat_sg_backend" {
  name        = "chat-sg-backend"
  description = "Security group for backend instances"
  vpc_id      = aws_vpc.chat_vpc.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.chat_sg_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "chat-sg-backend"
  }
}

resource "aws_security_group" "chat_sg_frontend" {
  name        = "chat-sg-frontend"
  description = "Security group for frontend instance"
  vpc_id      = aws_vpc.chat_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "chat-sg-frontend"
  }
}

resource "aws_security_group" "chat_sg_rds" {
  name        = "chat-sg-rds"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.chat_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.chat_sg_backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "chat-sg-rds"
  }
}

resource "aws_db_subnet_group" "chat_db_subnet_group" {
  name       = "chat-db-subnet-group"
  subnet_ids = [
    aws_subnet.chat_subnet_private_a.id,
    aws_subnet.chat_subnet_private_b.id
  ]

  tags = {
    Name = "chat-db-subnet-group"
  }
}

resource "aws_db_instance" "chat_db" {
  engine              = "postgres"
  engine_version      = "15"
  instance_class      = "db.t3.micro"
  db_name             = var.db_name
  username            = var.db_username
  password            = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.chat_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.chat_sg_rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = {
    Name = "chat-db"
  }
}

resource "aws_launch_template" "chat_lt" {
  name_prefix   = "chat-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.chat_sg_backend.id]

  user_data = base64encode(<<EOF
#!/bin/bash
apt-get update -y
apt-get install -y git nodejs npm
cd /home/ubuntu
git clone https://github.com/OussamaBouchnak/ProjetCloudIng2Info.git app
cd app/backend
npm install
export DB_HOST=${aws_db_instance.chat_db.endpoint}
export DB_USER=${var.db_username}
export DB_PASS=${var.db_password}
export DB_NAME=${var.db_name}
export PORT=3000
npm start &
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "chat-backend"
    }
  }
}

resource "aws_lb" "chat_alb" {
  name               = "chat-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.chat_sg_alb.id]
  subnets = [
    aws_subnet.chat_subnet_public_a.id,
    aws_subnet.chat_subnet_public_b.id
  ]

  tags = {
    Name = "chat-alb"
  }
}

resource "aws_lb_target_group" "chat_tg" {
  name        = "chat-tg"
  port        = 3000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.chat_vpc.id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    interval            = 30
  }

  tags = {
    Name = "chat-tg"
  }
}

resource "aws_lb_listener" "chat_listener" {
  load_balancer_arn = aws_lb.chat_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.chat_tg.arn
  }
}

resource "aws_autoscaling_group" "chat_asg" {
  name                = "chat-asg"
  vpc_zone_identifier = [
    aws_subnet.chat_subnet_private_a.id,
    aws_subnet.chat_subnet_private_b.id
  ]
  target_group_arns   = [aws_lb_target_group.chat_tg.arn]
  health_check_type   = "ELB"
  min_size            = 2
  desired_capacity    = 2
  max_size            = 4

  launch_template {
    id      = aws_launch_template.chat_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "chat-backend-asg"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "chat_cpu_policy" {
  name                   = "chat-cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.chat_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70
  }
}

resource "aws_instance" "chat_frontend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.chat_subnet_public_a.id
  vpc_security_group_ids = [aws_security_group.chat_sg_frontend.id]
  associate_public_ip_address = true

  user_data = base64encode(<<EOF
#!/bin/bash
apt-get update -y
apt-get install -y git nginx
git clone https://github.com/OussamaBouchnak/ProjetCloudIng2Info.git /home/ubuntu/repo
cp -r /home/ubuntu/repo/frontend/* /var/www/html/
systemctl enable nginx
systemctl start nginx
EOF
  )

  tags = {
    Name = "chat-frontend-ec2"
  }
}

output "alb_dns_name" {
  value = aws_lb.chat_alb.dns_name
}

output "frontend_public_ip" {
  value = aws_instance.chat_frontend.public_ip
}

output "rds_endpoint" {
  value = split(":", aws_db_instance.chat_db.endpoint)[0]
}
