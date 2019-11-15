provider "alicloud" {
  region                  = "ap-northeast-1"
  shared_credentials_file = "~/.aliyun/config.json"
  profile                 = "default"
}

module "vpc-al" {
  source = "./modules/aliyun/vpc"

  create_vpc = true
  name       = local.vpc-name
  cidr       = local.vpc-cidr_al

  private_subnet_suffix = local.private_subnet_suffix
  azs                   = local.azs_al
  private_subnets       = local.private_subnets_al

  # NAT Gateway
  nat_name      = "dev-nat"
  specification = "Small"
  snat_count    = length(local.azs_al)
}

module "k8s" {
  source = "./modules/aliyun/k8s"
  cluster_name = "${local.cluster_name}"
  key_name = "k8s_sample"
  vswitch_ids = module.vpc-al.vswitch_id

  azs                   = local.azs_al
  master_instance_type  = "ecs.t5-lc1m2.small"
  worker_instance_type  = "ecs.t5-lc1m2.small"
  worker_numbers        = "3"
  pod_cidr              = "172.16.0.0/16"
  service_cidr          = "172.31.1.0/24"
  worker_data_disk_size = "50"
  worker_disk_size      = "50"
}
