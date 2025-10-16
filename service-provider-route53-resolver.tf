#######################################
# Route53 Resolver INBOUND Endpoint
#######################################
resource "aws_route53_resolver_endpoint" "inbound_interface_endpoint_resolver" {
  name               = "inbound-interface-endpoint-resolver"
  direction          = "INBOUND"
  security_group_ids = [module.resolver_sg.security_group_id]

  ip_address {
    subnet_id = module.central_account_vpc.private_subnets[0]
  }

  ip_address {
    subnet_id = module.central_account_vpc.private_subnets[1]
  }

  tags = {
    Name = "inbound-interface-endpoint-resolver"
  }

  depends_on = [
    module.central_account_vpc,
    module.central_account_vpc.private_subnets
  ]


}

#######################################
# Route53 Resolver OUTBOUND Endpoint
#######################################
resource "aws_route53_resolver_endpoint" "outbound_interface_endpoint_resolver" {
  name               = "outboud-interface-endpoint-resolver"
  direction          = "OUTBOUND"
  security_group_ids = [module.resolver_sg.security_group_id]

  ip_address {
    subnet_id = module.central_account_vpc.private_subnets[0]
  }

  ip_address {
    subnet_id = module.central_account_vpc.private_subnets[1]
  }

  tags = {
    Name = "outboud-interface-endpoint-resolver"
  }

  depends_on = [module.central_account_vpc,
    module.central_account_vpc.private_subnets
  ]
}

#######################################
# Route53 Resolver Rule to Forward to Inbound
#######################################
resource "aws_route53_resolver_rule" "forward_to_inbound" {
  name                 = "interface-endpoint-traffice-forward-to-inbound"
  domain_name          = local.app_domain # Private hosted zone DNS
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound_interface_endpoint_resolver.id

  # Forward outbound DNS queries to the inbound resolver’s IPs
  dynamic "target_ip" {
    for_each = toset([
      for ip in aws_route53_resolver_endpoint.inbound_interface_endpoint_resolver.ip_address : ip.ip
    ])
    content {
      ip = target_ip.value
    }
  }

  tags = {
    Name = "interface-endpoint-traffice-forward-to-inbound"
  }

  depends_on = [
    aws_route53_resolver_endpoint.inbound_interface_endpoint_resolver,
    aws_route53_resolver_endpoint.outbound_interface_endpoint_resolver
  ]

}

#######################################
# Security Group for Resolver Endpoints
######################################
module "resolver_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~>5.2"

  name        = "route53-resolver-sg"
  description = "Route53 resolver endpoint security group"
  vpc_id      = module.central_account_vpc.vpc_id
  ingress_cidr_blocks = [
    module.central_account_vpc.vpc_cidr_block,
  module.consumer_account_vpc.vpc_cidr_block]
  ingress_rules = ["dns-tcp", "dns-udp"] #TCP 53  #UDP 53
  egress_rules  = ["all-all"]
}