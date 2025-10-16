
################################ Provider Account App Setup ###############################
###########################################################################################
locals {
  instance_type = "t2.micro"

  user_data = <<-EOT
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y httpd.x86_64
    sudo systemctl start httpd.service
    sudo systemctl enable httpd.service
    echo "This is shared vpc endpoint service" | sudo tee /var/www/html/index.html
  EOT
}

# Private EC2 instance for running Nginx
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~>6.1"

  name                        = local.service_provider_app_name
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = local.instance_type
  vpc_security_group_ids      = [module.app_sg.security_group_id]
  subnet_id                   = module.central_account_vpc.private_subnets[0]
  user_data_base64            = base64encode(local.user_data)
  user_data_replace_on_change = true
  monitoring                  = false
}

# Internal network load balancer with an EC2 target
module "nlb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.13"

  name               = "${local.service_provider_app_name}-nlb"
  load_balancer_type = "network"
  vpc_id             = module.central_account_vpc.vpc_id
  subnets            = module.central_account_vpc.private_subnets
  internal           = true

  create_security_group = false
  security_groups       = [module.app_sg.security_group_id]
  enable_deletion_protection = false

  listeners = {
    http_80 = {
      port     = 80
      protocol = "TCP"
      forward = {
        target_group_key = "nginx"
      }
    }

    https_443 = {
      port            = 443
      protocol        = "TLS"
      certificate_arn = aws_acm_certificate.app_acm.arn
      ssl_policy      = "ELBSecurityPolicy-2016-08"
      forward = {
        target_group_key = "nginx"
      }
    }
  }

  target_groups = {
    nginx = {
      name_prefix = "sp-"
      protocol    = "TCP"
      port        = 80
      target_type = "instance"
      target_id   = module.ec2_instance.id
      health_check = {
        enabled             = true
        interval            = 6
        path                = "/"
        port                = "80"
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 6
      }
    }
  }
}

#Application security group which allows any traffic from both service provider and consumer accounts
module "app_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~>5.2"

  name                = local.service_provider_app_name
  description         = local.service_provider_app_name
  vpc_id              = module.central_account_vpc.vpc_id
  ingress_cidr_blocks = [module.central_account_vpc.vpc_cidr_block, module.consumer_account_vpc.vpc_cidr_block]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  egress_rules        = ["all-all"]
}


#Creating ACM for https listeners
#Note that I already have a public hosted zone created for my domain app.duleendra.com
resource "aws_acm_certificate" "app_acm" {
  domain_name               = local.app_domain
  validation_method         = "DNS"
  subject_alternative_names = ["*.${local.app_domain}"]
}

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app_acm.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.zone.zone_id

  depends_on = [aws_acm_certificate.app_acm]
}