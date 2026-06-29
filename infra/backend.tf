terraform {
  backend "s3" {
    bucket = "obinna-infra-backends"
    key    = "muchen_autos/terraform.tfstate"
    region = "eu-west-2"
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-2"
}