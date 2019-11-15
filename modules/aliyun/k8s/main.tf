resource "alicloud_cs_kubernetes" "k8s" {
  name_prefix               = "${var.cluster_name}"
  vswitch_ids               = ["${var.vswitch_ids}"]
  master_instance_types     = ["${var.master_instance_type}"]
  worker_instance_types     = ["${var.worker_instance_type}"]
  worker_numbers            = ["${var.worker_numbers}"]
  key_name                  = "${var.key_name}"
  master_disk_category      = "cloud_ssd"
  worker_disk_size          = "${var.worker_disk_size}"
  worker_data_disk_category = "cloud_ssd"
  worker_data_disk_size     = "${var.worker_data_disk_size}"
  pod_cidr                  = "${var.pod_cidr}"
  service_cidr              = "${var.service_cidr}"
  enable_ssh                = true
  slb_internet_enabled      = true
  node_cidr_mask            = 25
}
