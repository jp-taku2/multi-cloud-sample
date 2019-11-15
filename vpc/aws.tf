provider "aws" {
  region                  = "ap-northeast-1"
  shared_credentials_file = "~/.aws/credentials"
  profile                 = "sandbox"
}


data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}

module "vpc" {
  source                      = "../modules/aws/vpc"
  create_vpc                  = true
  name                        = local.vpc-name
  public_subnets              = local.public_subnets_aws
  private_subnets             = local.private_subnets_aws
  public_subnet_suffix        = local.public_subnet_suffix
  private_subnet_suffix       = local.private_subnet_suffix
  private_subnet_suffix_count = length(local.private_subnet_suffix)
  cidr                        = local.vpc-cidr_aws
  azs                         = local.azs_aws
  azs_count                   = length(local.azs_aws)


  enable_dns_hostnames     = true
  enable_dns_support       = true
  enable_nat_gateway       = true
  enable_dhcp_options      = true
  dhcp_options_domain_name = "ap-northeast-1.compute.internal"
  # VPC Endpoint for EC2
  enable_ec2_endpoint              = false
  ec2_endpoint_private_dns_enabled = true
  ec2_endpoint_security_group_ids  = ["${data.aws_security_group.default.id}"]
  # VPC Endpoint for ECR API
  enable_ecr_api_endpoint              = false
  ecr_api_endpoint_private_dns_enabled = true
  ecr_api_endpoint_security_group_ids  = ["${data.aws_security_group.default.id}"]
  # VPC Endpoint for ECR DKR
  enable_ecr_dkr_endpoint              = false
  ecr_dkr_endpoint_private_dns_enabled = true
  ecr_dkr_endpoint_security_group_ids  = ["${data.aws_security_group.default.id}"]

  tags = {
    Environment = "prod"
  }
}
