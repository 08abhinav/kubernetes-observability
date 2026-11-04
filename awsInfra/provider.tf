terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.71.0"
    }
  }

  backend "s3"
    bucket  =  ""
    key     =  ""
    region  =  "us-east-1"
    encrypt =  true
}

provider "aws" {
  region = "us-east-1"
}
