data "aws_vpc" "selected" {
  default = true
}

data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_subnets" "pb-subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  filter {
    name   = "tag:Name"
    values = ["default-publicsb-*"]
  }
}

resource "aws_launch_template" "asg-lt" {
  name                   = "phonebook-lt"
  image_id               = data.aws_ami.amazon-linux-2.id
  instance_type          = "t2.micro"
  key_name               = "firstkey"
  vpc_security_group_ids = [aws_security_group.server-sg.id]
  user_data              = filebase64("${abspath(path.module)}/userdata.sh")
  depends_on             = [github_repository_file.dbendpoint] # *******dont forget this ***

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "Webserver of Phonebook App"
    }
  }
}

resource "aws_lb_target_group" "app-lb-tg" {
  name        = "phonebook-lb-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.selected.id
  target_type = "instance"
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb" "app-lb" {
  name               = "phonebook-lb-tf"
  ip_address_type    = "ipv4"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets            = data.aws_subnets.pb-subnets.ids

}

resource "aws_lb_listener" "app-listener" {
  load_balancer_arn = aws_lb.app-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app-lb-tg.arn
  }
}

resource "aws_autoscaling_group" "app-asg" {
  name                      = "phonebook-asg"  
  desired_capacity          = 2
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  target_group_arns         = [aws_lb_target_group.app-lb-tg.arn]
  vpc_zone_identifier       = aws_lb.app-lb.subnets

  launch_template {
    id      = aws_launch_template.asg-lt.id
    version = "$Latest"
    # version = aws_launch_template.asg-lt.latest_version
  }
}

resource "aws_db_instance" "db-server" {
  allocated_storage           = 20
  db_name                     = "phonebook"
  engine                      = "mysql"
  engine_version              = "8.0.28"
  instance_class              = "db.t2.micro"
  username                    = "admin"
  password                    = "Bekir1234"
  skip_final_snapshot         = true
  identifier                  = "phonebook-app-db"
  multi_az                    = false
  port                        = 3306
  vpc_security_group_ids      = [aws_security_group.db-sg.id]
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  backup_retention_period     = 0
  monitoring_interval         = 0
  publicly_accessible         = false
}

resource "github_repository_file" "dbendpoint" {
  repository = "phonebook"
  branch     = "main"
  file       = "dbserver.endpoint"
  content    = aws_db_instance.db-server.address #endpoint secersek yanlis olur. cünkü ekstra hosno da veriyor

  overwrite_on_create = true
}