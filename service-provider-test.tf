#Lambda function for testing the shared vpc interface endpoint in service provider account
module "test_function_in_provider_account" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.1"

  function_name = "test-function-in-provider-account"
  description   = "Test function in the provider account"
  handler       = "index.handler"
  runtime       = "nodejs22.x"
  source_path   = "${path.module}/lambda"

  vpc_subnet_ids         = module.central_account_vpc.private_subnets
  vpc_security_group_ids = [module.app_sg.security_group_id]

  create_role = false

  lambda_role = module.lambda_role.arn

  memory_size = 128
  timeout     = 40
}

module "lambda_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~>6.2.0"

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
