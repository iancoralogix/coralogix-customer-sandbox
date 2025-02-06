terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      Environment = "development"
      Name        = "otel-coralogix-demo"
    }
  }
}

module "opentelemetry-demo-infrastructure" {
  source = "./modules/opentelemetry-demo-infrastructure"
}
