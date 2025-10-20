#Accepting the RAM TGW resource share in consumer account
resource "aws_ram_resource_share_accepter" "tgw_accepter_consumer_account" {
  provider  = "aws.consumer-account"
  share_arn = aws_ram_resource_share.central_tgw_share.arn
  depends_on = [
    aws_ram_principal_association.consumer_account_association
  ]
}


resource "aws_ram_resource_share_accepter" "resolver_rule_accepter_consumer_account" {
  provider  = "aws.consumer-account"
  share_arn = aws_ram_resource_share.resolver_rule_share.arn
  depends_on = [
    aws_ram_principal_association.resolver_rule_share_with_consumer_account
  ]
}

#######################################
# Associate Rule with the Consumer VPC
#######################################
resource "aws_route53_resolver_rule_association" "forward_to_outbound_inbound_vpc_assoc" {
  provider = "aws.consumer-account"

  resolver_rule_id = aws_route53_resolver_rule.forward_outbound_to_inbound.id
  vpc_id           = module.consumer_account_vpc.vpc_id
  name             = "forward-to-outbound-inbound-assoc"

  depends_on = [
    aws_ram_resource_share_accepter.resolver_rule_accepter_consumer_account
  ]
}