provider "aws" {
  region = "ap-southeast-1"
}

provider "aws" {
  alias  = "consumer-account"
  region = "ap-southeast-1"

  # I am using a cross account role to provision resource in both service provider and consumer accounts
  assume_role {
    role_arn     = "arn:aws:iam::207567773051:role/CrossAccountRole"
    session_name = "cross-account"
  }
}