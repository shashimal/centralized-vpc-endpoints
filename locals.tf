locals {
  aws_region = "ap-southeast-1"

  #This is the domain that we use to access service
  app_domain = "app.duleendra.com"

  #Central AWS account
  service_provider_app_name            = "service-provider-app"
  service_provider_vpc_cidr            = "10.0.0.0/16"
  service_provider_vpc_public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  service_provider_vpc_private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]


  #Consumer AWS account
  counsumer_account_id          = 207567773051
  counsumer_app_name            = "counsumer-app"
  counsumer_vpc_cidr            = "20.0.0.0/16"
  counsumer_vpc_public_subnets  = ["20.0.1.0/24", "20.0.2.0/24"]
  counsumer_vpc_private_subnets = ["20.0.11.0/24", "20.0.12.0/24"]
}