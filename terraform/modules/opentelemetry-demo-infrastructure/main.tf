data "aws_region" "current" {}
data "aws_default_tags" "current" {}
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source     = "git@github.com:terraform-aws-modules/terraform-aws-vpc.git?ref=v5.18.1"
  create_vpc = true

  name               = "${data.aws_default_tags.current.tags["Name"]}-vpc"
  cidr               = "10.0.0.0/20"
  enable_nat_gateway = true
  single_nat_gateway = true

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.0.0/22", "10.0.4.0/22"]
  public_subnets  = ["10.0.8.0/22", "10.0.12.0/22"]
}

#module "eks" {
#  source = "git@github.com:terraform-aws-modules/terraform-aws-eks.git?ref=v20.33.1"
#  create = true
#
#  cluster_name                             = "${data.aws_default_tags.current.tags["Name"]}-eks"
#  cluster_endpoint_public_access           = true
#  enable_cluster_creator_admin_permissions = true
#
#  cluster_compute_config = {
#    enabled    = true
#    node_pools = ["general-purpose"]
#  }
#
#  vpc_id                   = module.vpc.vpc_id
#  control_plane_subnet_ids = module.vpc.private_subnets
#  subnet_ids               = module.vpc.private_subnets
#
#  eks_managed_node_groups = {
#    example = {
#      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
#      instance_types = ["m6i.large"]
#
#      min_size = 2
#      max_size = 5
#      # This value is ignored after the initial creation
#      # https://github.com/bryantbiggs/eks-desired-size-hack
#      desired_size = 2
#
#      # This is not required - demonstrates how to pass additional configuration to nodeadm
#      # Ref https://awslabs.github.io/amazon-eks-ami/nodeadm/doc/api/
#      cloudinit_pre_nodeadm = [
#        {
#          content_type = "application/node.eks.aws"
#          content      = <<-EOT
#            ---
#            apiVersion: node.eks.aws/v1alpha1
#            kind: NodeConfig
#            spec:
#              kubelet:
#                config:
#                  shutdownGracePeriod: 30s
#                  featureGates:
#                    DisableKubeletCloudCredentialProviders: true
#          EOT
#        }
#      ]
#    }
#  }
#}
