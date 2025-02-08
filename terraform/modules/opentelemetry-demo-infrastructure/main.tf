terraform {
  required_version = ">= 1.3.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.83"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" { state = "available" }
data "aws_default_tags" "these" {}

module "vpc" {
  source     = "git@github.com:terraform-aws-modules/terraform-aws-vpc.git?ref=v5.18.1"
  create_vpc = true

  name               = "${data.aws_default_tags.these.tags["Name"]}-vpc"
  cidr               = "10.0.0.0/20"
  enable_nat_gateway = true
  single_nat_gateway = true

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.0.0/22", "10.0.4.0/22"]
  public_subnets  = ["10.0.8.0/22", "10.0.12.0/22"]
}

module "eks" {
  source = "git@github.com:terraform-aws-modules/terraform-aws-eks.git?ref=v20.33.1"
  create = true

  cluster_name = "${data.aws_default_tags.these.tags["Name"]}-eks"

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  eks_managed_node_groups = {
    workers = {
      instance_types = ["m6i.large"]

      min_size     = 2
      max_size     = 5
      desired_size = 2
    }
  }
}
