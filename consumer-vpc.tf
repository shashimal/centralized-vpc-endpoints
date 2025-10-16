################################ Consumer AWS account######################################
###########################################################################################

locals {
  consumer_private_route_tables = module.consumer_account_vpc.private_route_table_ids
}

# Consumer account VPC
module "consumer_account_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~>6.4"

  providers = {
    aws = aws.consumer-account
  }

  name = "${local.counsumer_app_name}-vpc"
  cidr = local.counsumer_vpc_cidr

  azs             = ["${local.aws_region}a", "${local.aws_region}b"]
  public_subnets  = local.counsumer_vpc_public_subnets
  private_subnets = local.counsumer_vpc_private_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true


  tags = {
    Name = "${local.counsumer_app_name}-vpc"
  }

  private_subnet_tags = {
    Name = "private-subnet"
  }

  public_subnet_tags = {
    Name = "public-subnet"
  }
}

#TGW attachment for the consumer account VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "attachment_consumer_vpc" {
  provider = aws.consumer-account

  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpc_id             = module.consumer_account_vpc.vpc_id
  subnet_ids         = module.consumer_account_vpc.private_subnets

  depends_on = [
    aws_ram_principal_association.consumer_account_association
  ]

  tags = { Name = "consumer-vpc-attachment" }
}

#Route traffic to service provider account via TGW
resource "aws_route" "consumer_to_provider_vpc_route" {
  for_each = {
    for idx, rt_id in local.consumer_private_route_tables : idx => rt_id
  }

  provider               = aws.consumer-account
  route_table_id         = each.value
  destination_cidr_block = module.central_account_vpc.vpc_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.main_tgw.id

  depends_on = [
    module.consumer_account_vpc,
    aws_ec2_transit_gateway_vpc_attachment.attachment_consumer_vpc
  ]
}
