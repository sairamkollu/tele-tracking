######
# ELB
######
module "elb" {
  source = "../../../../../../modules/alb"

  name = "tele_alb"

  subnets         = data.aws_subnet_ids.all.ids
  security_groups = [data.aws_security_group.default.id]
  internal        = false

  listener = [
    {
      instance_port     = "80"
      instance_protocol = "http"
      lb_port           = "80"
      lb_protocol       = "http"
    },
  ]

  health_check = {
    target              = "HTTP:80/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  tags = {
    Owner       = "tele_project"
    Environment = "prod"
  }
}

######
# Launch configuration and autoscaling group
######
module "tele_asg" {
  source = "../../../../../../modules/autoscaling"

  name = "tele-alb"

  lc_name = "tele-lc"

  image_id        = data.aws_ami.amazon_linux.id
  instance_type   = "t3a.micro"
  security_groups = [data.aws_security_group.default.id]
  load_balancers  = [module.elb.tele_alb_id]

  # Auto scaling group
  asg_name                  = "tele-asg"
  vpc_zone_identifier       = data.aws_subnet_ids.all.ids
  health_check_type         = "EC2"
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  wait_for_capacity_timeout = 0

  tags = [
    {
      key                 = "Environment"
      value               = "prod"
      propagate_at_launch = true
    },
    {
      key                 = "Project"
      value               = "teletracking"
      propagate_at_launch = true
    },
  ]
}
