#Lambda function for testing the shared vpc interface endpoint in the consumer account
module "test_function_in_consumer_account" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.1"

  providers = {
    aws = aws.consumer-account
  }

  function_name = "test-function-in-consumer-account"
  description   = "Test function in the consumer account"
  handler       = "index.handler"
  runtime       = "nodejs22.x"
  source_path   = "${path.module}/lambda"

  vpc_subnet_ids         = module.consumer_account_vpc.private_subnets
  vpc_security_group_ids = [module.consumer_lambda_sg.security_group_id]

  create_role = false

  lambda_role = module.consumer_lambda_role.arn

  memory_size = 128
  timeout     = 40
}

module "consumer_lambda_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~>5.2"

  providers = {
    aws = aws.consumer-account
  }

  name                = local.counsumer_app_name
  description         = local.counsumer_app_name
  vpc_id              = module.consumer_account_vpc.vpc_id
  ingress_cidr_blocks = [module.consumer_account_vpc.vpc_cidr_block]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  egress_rules        = ["all-all"]
}

module "consumer_lambda_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role"

  providers = {
    aws = aws.consumer-account
  }

  name = "shared-vpc-endpoint-lambda-role"

  trust_policy_permissions = {
    TrustRoleAndServiceToAssume = {
      actions = [
        "sts:AssumeRole"
      ]
      principals = [{
        type = "Service"
        identifiers = [
          "lambda.amazonaws.com",
        ]
      }]
    }
  }

  policies = {
    AWSLambdaVPCAccessExecutionRole = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
    AWSLambdaExecute                = "arn:aws:iam::aws:policy/AWSLambdaExecute"
  }
}