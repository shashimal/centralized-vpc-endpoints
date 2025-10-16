################################ TGW setup for Network connectivity between AWS accounts ###############################
########################################################################################################################

#Central TGW for cross-account VPC connectivity
resource "aws_ec2_transit_gateway" "main_tgw" {
  description = "Central TGW for cross-account VPC connectivity"

  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = {
    Name = "main-cross-account-tgw"
  }
}

#TGW attachment with central (service provider) VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "attachment_central_vpc" {
  transit_gateway_id = aws_ec2_transit_gateway.main_tgw.id
  vpc_id             = module.central_account_vpc.vpc_id
  subnet_ids         = module.central_account_vpc.private_subnets

  tags = {
    Name = "central-vpc-attachment-request"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "consumer_vpc_accepter" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.attachment_consumer_vpc.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.attachment_consumer_vpc
  ]
}
