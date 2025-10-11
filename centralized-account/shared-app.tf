locals {
  app_name = "shared-app"
  user_data = <<-EOT
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y httpd.x86_64
    sudo systemctl start httpd.service
    sudo systemctl enable httpd.service
    echo "Service is running in ap-southeast-1" | sudo tee /var/www/html/index.html
  EOT
}

module "app" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~>5.7"

  name                   = local.app_name
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  monitoring             = true
  vpc_security_group_ids = [module.app_sg.security_group_id]
  subnet_id              = module.vpc.private_subnets[0]
  user_data_base64       = base64encode(local.user_data)
  user_data_replace_on_change = true
}

module "app_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~>5.2"

  name                = local.app_name
  description         = local.app_name
  vpc_id              = module.vpc.vpc_id
  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]
  ingress_rules       = ["http-80-tcp"]
  egress_rules        = ["all-all"]
}