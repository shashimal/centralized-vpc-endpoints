#Sharing the TGW with other AWS accounts using RAM
#Crate a resource  share for TGW
resource "aws_ram_resource_share" "central_tgw_share" {
  name                      = "central-tgw-share"
  allow_external_principals = true
  tags                      = { Name = "central-tgw-share" }
}

#Associate the TGW with RAM
resource "aws_ram_resource_association" "tgw_resource_association" {
  resource_share_arn = aws_ram_resource_share.central_tgw_share.arn
  resource_arn       = aws_ec2_transit_gateway.main_tgw.arn
}

#Shared with consumer account
resource "aws_ram_principal_association" "consumer_account_association" {
  resource_share_arn = aws_ram_resource_share.central_tgw_share.arn
  principal          = local.counsumer_account_id
}


#######################################
# AWS RAM Resource Share for Resolver Rule
#######################################
resource "aws_ram_resource_share" "resolver_rule_share" {
  name                      = "resolver-rule-share"
  allow_external_principals = true
  tags = {
    Name = "resolver-rule-share"
  }
}

#######################################
# Share Resolver Rule with Another AWS Account
#######################################
resource "aws_ram_principal_association" "share_with_account" {
  resource_share_arn = aws_ram_resource_share.resolver_rule_share.arn
  principal          = local.counsumer_account_id
}

#######################################
# Associate Resolver Rule as a Shared Resource
#######################################
resource "aws_ram_resource_association" "resolver_rule_association" {
  resource_share_arn = aws_ram_resource_share.resolver_rule_share.arn
  resource_arn       = aws_route53_resolver_rule.forward_to_inbound.arn
}