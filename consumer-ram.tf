#Accepting the RAM TGW resource share in consumer account
resource "aws_ram_resource_share_accepter" "tgw_accepter_consumer_account" {
  provider   = "aws.consumer-account"
  share_arn  = aws_ram_resource_share.central_tgw_share.arn
  depends_on = [
    aws_ram_principal_association.consumer_account_association
  ]
}