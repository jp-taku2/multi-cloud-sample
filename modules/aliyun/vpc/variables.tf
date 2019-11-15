variable "create_vpc" {
  description = "Controls if VPC should be created (it affects almost all resources)"
  default     = true
}

variable "name" {
  default = ""
}

variable "cidr" {
  default = "0.0.0.0/0"
}

variable "azs" {
  type    = "list"
  default = []
}

variable "snat_count" {
  default = 2
}

variable "private_subnets" {
  type    = "list"
  default = []
}

variable "private_subnet_suffix" {
  type    = "list"
  default = []
}

variable "azs_count" {
  default = 2
}

variable "nat_gateway_id" {
  default = ""
}

variable "nat_name" {
  default = ""
}

variable "specification" {
  default = "Small"
}

variable "description" {
  default = "terraform-nat-gw"
}