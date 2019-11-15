provider "alicloud" {
  region                  = "ap-northeast-1"
  shared_credentials_file = "~/.aliyun/config.json"
  profile                 = "default"
}

module "vpc-al" {
  source = "../modules/aliyun/vpc"

  create_vpc = true
  name       = local.vpc-name
  cidr       = local.vpc-cidr_al

  #  private_subnet_suffix_count = length(local.private_subnet_suffix)
  private_subnet_suffix = local.private_subnet_suffix
  azs                   = local.azs_al
  private_subnets       = local.private_subnets_al

  # NAT Gateway
  nat_name      = "dev-nat"
  specification = "Small"
  snat_count    = length(local.azs_al)
  #  snat_table_id      = ""
  #  snat_ips           = ""
  #  source_vswitch_ids = []
}