variable "cluster_name" {}

variable "master_instance_type" {}

variable "azs" {
  description = "A list of availability zones in the region"
  default     = []
}

variable "vswitch_ids" {
  default = []
}

variable "worker_instance_type" {
  default = ""
}

variable "worker_numbers" {
  default = ""
}

variable "key_name" {
  default = ""
}

variable "worker_disk_size" {
  default = ""
}

variable "worker_data_disk_size" {
  default = ""
}

variable "pod_cidr" {
  default = ""
}

variable "service_cidr" {
  default = ""
}
