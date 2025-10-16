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