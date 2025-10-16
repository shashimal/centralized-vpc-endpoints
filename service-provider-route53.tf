#Create private hosted zone
resource "aws_route53_zone" "phz" {
  name = local.app_domain

  vpc {
    vpc_id = module.central_account_vpc.vpc_id
  }

  tags = {
    Name = local.app_domain
  }
}

#Create an alias record for VPC interface endpoint
resource "aws_route53_record" "shared_vpc_endpoint_record" {
  zone_id = aws_route53_zone.phz.zone_id
  name    = local.app_domain
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.shared_interface_endpoint.dns_entry[0].dns_name
    zone_id                = aws_vpc_endpoint.shared_interface_endpoint.dns_entry[0].hosted_zone_id
    evaluate_target_health = false
  }
}