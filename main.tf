provider "aws" {
  region                  = "us-east-1"
  profile                 = "Nikola"
}

resource "aws_vpc" "vpc1" {
  cidr_block       = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "vpc1"
  }
}

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "subnet-1"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc1.id
tags = {
    Name = "IGW for vpc1"
  }
}

resource "aws_route_table" "vpc1route" {
  vpc_id = aws_vpc.vpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "vpc1 route table"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.vpc1route.id
}

resource "aws_security_group" "allow_web_ssh" {
  name        = "vpc1-SG1"
  description = "vpc1 SG1"
  vpc_id      = aws_vpc.vpc1.id

  ingress {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    description = "ssh"
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
    Name = "vpc1 SG1"
  }
}

resource "aws_network_interface" "instance1nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web_ssh.id]

}

resource "aws_eip" "instance1eip" {
  vpc                       = true
  network_interface         = aws_network_interface.instance1nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_instance" "vpc1ubuntu" {
  ami           = "ami-06b263d6ceff0b3dd"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "nikola-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.instance1nic.id
  }

	user_data = <<-EOF
                #! /bin/bash     
                sudo apt-get update
                sudo apt-get install -y    apt-transport-https     ca-certificates     curl     gnupg-agent     software-properties-common
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
                sudo add-apt-repository \
                 "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
                  $(lsb_release -cs) \
                 stable"  
                sudo apt-get update
                sudo apt-get install -y docker-ce docker-ce-cli containerd.io
                sudo docker build -t hhh:1.0 https://hereismynginxfile.s3.amazonaws.com/Dockerfile
                sudo docker run -p 80:80 -d hhh:1.0
                sudo docker run -d --name mongo-cointainer -e MONGO_INITDB_ROOT_USERNAME=mongoadmin -e MONGO_INITDB_ROOT_PASSWORD=secret mongo
              EOF

  
  tags = {
    Name = "vpc1, 10.0.1.50"
  }
}

resource "aws_subnet" "subnet-2" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "subnet-2"
  }
}


resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet-2.id
  route_table_id = aws_route_table.vpc1route.id
}

resource "aws_security_group" "allow_web_ssh2" {
  name        = "vpc1-SG2"
  description = "vpc1 SG2"
  vpc_id      = aws_vpc.vpc1.id

  ingress {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    description = "ssh"
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
    Name = "vpc1 SG2"
  }
}

resource "aws_network_interface" "instance2nic" {
  subnet_id       = aws_subnet.subnet-2.id
  private_ips     = ["10.0.2.50"]
  security_groups = [aws_security_group.allow_web_ssh2.id]

}

resource "aws_eip" "instance2eip" {
  vpc                       = true
  network_interface         = aws_network_interface.instance2nic.id
  associate_with_private_ip = "10.0.2.50"
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_lb" "alb" {
  name               = "alb1"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web_ssh.id, aws_security_group.allow_web_ssh2.id]
  subnets            = [aws_subnet.subnet-1.id, aws_subnet.subnet-2.id]
}

resource "aws_lb_target_group" "lb_tg" {
    health_check {
      interval = 10
      path = "/"
      protocol = "HTTP"
      timeout = 5
    }
  name     = "lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc1.id
}

resource "aws_lb_listener" "listener_group" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "tga1" {
  target_group_arn = aws_lb_target_group.lb_tg.arn
  target_id        = aws_instance.vpc1ubuntu2.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "tga2" {
  target_group_arn = aws_lb_target_group.lb_tg.arn
  target_id        = aws_instance.vpc1ubuntu.id
  port             = 80
}

resource "aws_cloudwatch_metric_alarm" "cpuutilization" {
  alarm_name                = "terraform-cpuutilization"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_description         = "This metric monitors ec2 cpu utilization"
}

resource "aws_autoscaling_group" "asg" {
  name                      = "asg"
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 1
  launch_configuration      = aws_launch_configuration.lc.name
  vpc_zone_identifier       = [aws_subnet.subnet-1.id, aws_subnet.subnet-2.id]
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_launch_configuration" "lc" {
  name   = "lc"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "vpc1ubuntu2" {
  ami           = "ami-06b263d6ceff0b3dd"
  instance_type = "t2.micro"
  availability_zone = "us-east-1b"
  key_name = "nikola-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.instance2nic.id
  }

	user_data = <<-EOF
                #! /bin/bash     
                sudo apt-get update
                sudo apt-get install -y    apt-transport-https     ca-certificates     curl     gnupg-agent     software-properties-common
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
                sudo add-apt-repository \
                 "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
                  $(lsb_release -cs) \
                 stable"  
                sudo apt-get update
                sudo apt-get install -y docker-ce docker-ce-cli containerd.io
                sudo docker build -t hhh:1.0 https://hereismynginxfile.s3.amazonaws.com/Dockerfile
                sudo docker run -p 80:80 -d hhh:1.0
                sudo docker run -d --name mongo-cointainer -e MONGO_INITDB_ROOT_USERNAME=mongoadmin -e MONGO_INITDB_ROOT_PASSWORD=secret mongo
              EOF

  
  tags = {
    Name = "vpc1, 10.0.2.50"
  }
}