locals {
  ## common
  public_subnet_suffix = "dmz"
  private_subnet_suffix = [
    "private",
  ]
  vpc-name = "dev-vpc"


  ## for aliyun
  vpc-cidr_al = "192.168.0.0/20"
  private_subnets_al = [
    "192.168.0.0/25",
    "192.168.0.128/25",
    "192.168.3.0/25",
    "192.168.3.128/25",
  ]
  azs_al = [
    "ap-northeast-1a",
    "ap-northeast-1b",
  ]

  ## for aws
  vpc-cidr_aws = "192.168.16.0/20"
  azs_aws = [
    "ap-northeast-1a",
    "ap-northeast-1c",
  ]
  public_subnets_aws = [
    "192.168.16.0/25",
    "192.168.16.128/25",
  ]
  private_subnets_aws = [
    "192.168.20.0/25",
    "192.168.20.128/25",
  ]
}