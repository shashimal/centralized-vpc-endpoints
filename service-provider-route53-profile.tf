# resource "aws_route53profiles_profile" "shared_endpoint_profile" {
#   name = "shared-endpoint-profile"
# }
#
# resource "aws_route53profiles_association" "service_provider_vpc_association" {
#   name        = "service-provider-vpc-association"
#   profile_id  = aws_route53profiles_profile.shared_endpoint_profile.id
#   resource_id = module.central_account_vpc.vpc_id
# }
#
# resource "aws_route53profiles_resource_association" "shared_app_phz_association" {
#   name         = "shared-app-phz-association"
#   profile_id   = aws_route53profiles_profile.shared_endpoint_profile.id
#   resource_arn = aws_route53_zone.phz.arn
# }
# #
# resource "aws_route53profiles_resource_association" "shared_app_resolver_rule_association" {
#   name         = "shared-app-resolver-rule-association"
#   profile_id   = aws_route53profiles_profile.shared_endpoint_profile.id
#   resource_arn = aws_route53_resolver_rule.forward_outbound_to_inbound.arn
# }