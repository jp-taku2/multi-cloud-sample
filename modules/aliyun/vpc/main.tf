locals {
  vpc_id = "${element(concat(alicloud_vpc.this.*.id, list("")), 0)}"
}

######
# VPC
######
resource "alicloud_vpc" "this" {
  count = "${var.create_vpc ? 1 : 0}"

  name       = "${var.name}"
  cidr_block = "${var.cidr}"
}

resource "alicloud_eip" "snat" {
  count     = "${var.snat_count}"
  bandwidth = 100
}

##### SUBNET START #####

#################
# Private subnet
#################
resource "alicloud_vswitch" "private" {
  count             = "${var.create_vpc && length(var.private_subnets) > 0 && length(var.private_subnets) >= length(var.azs) ? length(var.private_subnets) : 0}"
  availability_zone = "${var.azs["${count.index % var.azs_count}"]}"
  cidr_block        = "${var.private_subnets[count.index]}"
  vpc_id            = "${local.vpc_id}"
  description       = "private"
  name              = "${var.name}-${element(var.private_subnet_suffix, floor(count.index / var.azs_count))}"
}

##################
##  subnet
##################
#resource "alicloud_vswitch" "database" {
#  count             = "${var.create_vpc && length(var.database_subnets) > 0 && length(var.database_subnets) >= length(var.azs) ? length(var.database_subnets) : 0}"
#  availability_zone = "${var.azs["${count.index % var.azs_count}"]}"
#  cidr_block        = "${var.database_subnets[count.index]}"
#  vpc_id            = "${local.vpc_id}"
#  description       = "database"
#  name              = "${var.name}-${element(var.database_subnet_suffix, count.index/var.azs_count)}"
#}

##### SUBNET END #####

################
# nat gateway
################
resource "alicloud_nat_gateway" "this_nat_gateway" {
  count         = "${var.nat_gateway_id == "" ? 1 : 0}"
  vpc_id        = "${local.vpc_id}"
  name          = "${var.nat_name}"
  specification = "${var.specification}"
  description   = "${var.description}"
}

resource "alicloud_eip_association" "this" {
  count         = "${var.snat_count}"
  allocation_id = "${element(alicloud_eip.snat.*.id, count.index)}"
  instance_id   = "${alicloud_nat_gateway.this_nat_gateway.0.id}"
}

#resource "alicloud_snat_entry" "this_snat_entry" {
#  count             = "${length(var.source_vswitch_ids)}"
#  snat_table_id     = "${alicloud_nat_gateway.this_nat_gateway.snat_table_ids}"
#  source_vswitch_id = "${element(var.source_vswitch_ids, count.index)}"
#  snat_ip           = "${alicloud_eip.snat.*.ip_address[count.index % length(var.azs)]}"
#}
