locals {
  max_subnet_length = "${max(length(var.private_subnet_suffix))}"
  nat_gateway_count = "${var.single_nat_gateway ? 1 : (var.one_nat_gateway_per_az ? length(var.azs) : length(var.azs))}"
  nat_gateway_ips   = split(",", (var.reuse_nat_ips ? join(",", var.external_nat_ip_ids) : join(",", aws_eip.nat[*].id)))
  # Use `local.vpc_id` to give a hint to Terraform that subnets should be deleted before secondary CIDR blocks can be free!
  vpc_id = "${element(concat(aws_vpc_ipv4_cidr_block_association.this.*.vpc_id, aws_vpc.this.*.id, list("")), 0)}"
}

######
# VPC
######
resource "aws_vpc" "this" {
  count = var.create_vpc ? 1 : 0

  cidr_block                       = var.cidr
  instance_tenancy                 = var.instance_tenancy
  enable_dns_hostnames             = var.enable_dns_hostnames
  enable_dns_support               = var.enable_dns_support
  assign_generated_ipv6_cidr_block = var.assign_generated_ipv6_cidr_block

  tags = merge(map("Name", format("%s", var.name)), var.tags, var.vpc_tags)

  lifecycle {
    ignore_changes = ["tags"]
  }
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  count = var.create_vpc && length(var.secondary_cidr_blocks) > 0 ? length(var.secondary_cidr_blocks) : 0

  vpc_id = aws_vpc.this.*.id

  cidr_block = element(var.secondary_cidr_blocks, count.index)
}

###################
# DHCP Options Set
###################
resource "aws_vpc_dhcp_options" "this" {
  count = var.create_vpc && var.enable_dhcp_options ? 1 : 0

  domain_name         = var.dhcp_options_domain_name
  domain_name_servers = [var.dhcp_options_domain_name_servers]
  #  ntp_servers          = [var.dhcp_options_ntp_servers]
  #  netbios_name_servers = [var.dhcp_options_netbios_name_servers]
  netbios_node_type = var.dhcp_options_netbios_node_type

  tags = merge(map("Name", format("%s", var.name)), var.tags, var.dhcp_options_tags)
}

###############################
# DHCP Options Set Association
###############################
resource "aws_vpc_dhcp_options_association" "this" {
  count = var.create_vpc && var.enable_dhcp_options ? 1 : 0

  vpc_id          = local.vpc_id
  dhcp_options_id = "${aws_vpc_dhcp_options.this[count.index].id}"
}

###################
# Internet Gateway
###################
resource "aws_internet_gateway" "this" {
  count = var.create_vpc && length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(map("Name", format("%s", var.name)), var.tags, var.igw_tags)
}

################
# Publiс routes
################
resource "aws_route_table" "public" {
  count = var.create_vpc && length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(map("Name", format("%s-${var.public_subnet_suffix}", var.name)), var.tags, var.public_route_table_tags)
}

resource "aws_route" "public_internet_gateway" {
  count = var.create_vpc && length(var.public_subnets) > 0 ? 1 : 0

  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[count.index].id

  timeouts {
    create = "5m"
  }
}

#################
# Private routes
# There are as many routing tables as the number of NAT gateways
#################
resource "aws_route_table" "private" {
  count = local.max_subnet_length * var.azs_count

  vpc_id = local.vpc_id

  tags = merge(map("Name", format("%s-%s-%s", var.name, element(var.private_subnet_suffix, count.index), var.azs[floor(count.index / var.azs_count)])))

  lifecycle {
    # When attaching VPN gateways it is common to define aws_vpn_gateway_route_propagation
    # resources that manipulate the attributes of the routing table (typically for the private subnets)
    ignore_changes = ["propagating_vgws"]
  }
}

################
# Public subnet
################
resource "aws_subnet" "public" {
  count = var.create_vpc && length(var.public_subnets) > 0 && (! var.one_nat_gateway_per_az || length(var.public_subnets) >= length(var.azs)) ? length(var.public_subnets) : 0

  vpc_id                  = local.vpc_id
  cidr_block              = element(concat(var.public_subnets, list("")), count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(map("Name", format("%s-${var.public_subnet_suffix}-%s", var.name, element(var.azs, count.index)), "suffix", var.public_subnet_suffix), var.tags, var.public_subnet_tags)

  lifecycle {
    ignore_changes = ["tags"]
  }
}

#################
# Private subnet
#################
resource "aws_subnet" "private" {
  count = var.create_vpc && length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

  vpc_id            = local.vpc_id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[floor(count.index % var.azs_count)]

  tags = merge(map("Name", format("%s-%s-%s", var.name, var.private_subnet_suffix[floor(count.index % var.private_subnet_suffix_count)], var.azs[floor(count.index % var.azs_count)]), "suffix", var.private_subnet_suffix[floor(count.index % var.private_subnet_suffix_count)]), var.tags, var.private_route_table_tags)

  lifecycle {
    ignore_changes = ["tags"]
  }
}

##############
# NAT Gateway
##############
# Workaround for interpolation not being able to "short-circuit" the evaluation of the conditional branch that doesn't end up being used
# Source: https://github.com/hashicorp/terraform/issues/11566#issuecomment-289417805
#
# The logical expression would be
#
#    nat_gateway_ips = var.reuse_nat_ips ? var.external_nat_ip_ids : aws_eip.nat.*.id
#
# but then when count of aws_eip.nat.*.id is zero, this would throw a resource not found error on aws_eip.nat.*.id.

resource "aws_eip" "nat" {
  count = var.create_vpc && (var.enable_nat_gateway && ! var.reuse_nat_ips) ? local.nat_gateway_count : 0

  vpc = true

  tags = merge(map("Name", format("%s-%s", var.name, element(var.azs, (var.single_nat_gateway ? 0 : count.index)))), var.tags, var.nat_eip_tags)
}

resource "aws_nat_gateway" "this" {
  count = var.create_vpc && var.enable_nat_gateway ? local.nat_gateway_count : 0

  allocation_id = element(local.nat_gateway_ips, (var.single_nat_gateway ? 0 : count.index))
  subnet_id     = element(aws_subnet.public.*.id, (var.single_nat_gateway ? 0 : count.index))

  tags = merge(map("Name", format("%s-%s", var.name, element(var.azs, (var.single_nat_gateway ? 0 : count.index)))), var.tags, var.nat_gateway_tags)

  depends_on = ["aws_internet_gateway.this"]
}

resource "aws_route" "private_nat_gateway" {
  count = local.max_subnet_length * var.azs_count

  route_table_id         = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.this.*.id, floor(count.index / var.azs_count))}"

  timeouts {
    create = "5m"
  }
}

#######################
# VPC Endpoint for EC2
#######################
data "aws_vpc_endpoint_service" "ec2" {
  count = var.create_vpc && var.enable_ec2_endpoint ? 1 : 0

  service = "ec2"
}

resource "aws_vpc_endpoint" "ec2" {
  count = var.create_vpc && var.enable_ec2_endpoint ? 1 : 0

  vpc_id            = local.vpc_id
  service_name      = data.aws_vpc_endpoint_service.ec2[0].service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [var.ec2_endpoint_security_group_ids]
  subnet_ids          = coalescelist(var.ec2_endpoint_subnet_ids, list(aws_subnet.private.*.id[0], aws_subnet.private.*.id[1], aws_subnet.private.*.id[2]))
  private_dns_enabled = "${var.ec2_endpoint_private_dns_enabled}"
}

###########################
# VPC Endpoint for ECR API
###########################
data "aws_vpc_endpoint_service" "ecr_api" {
  count = var.create_vpc && var.enable_ecr_api_endpoint ? 1 : 0

  service = "ecr.api"
}

resource "aws_vpc_endpoint" "ecr_api" {
  count = var.create_vpc && var.enable_ecr_api_endpoint ? 1 : 0

  vpc_id            = local.vpc_id
  service_name      = data.aws_vpc_endpoint_service.ecr_api[count.index]
  vpc_endpoint_type = "Interface"

  security_group_ids  = [var.ecr_api_endpoint_security_group_ids]
  subnet_ids          = [coalescelist(var.ecr_api_endpoint_subnet_ids, list(aws_subnet.private.*.id[0], aws_subnet.private.*.id[1]))]
  private_dns_enabled = var.ecr_api_endpoint_private_dns_enabled
}

###########################
# VPC Endpoint for ECR DKR
###########################
data "aws_vpc_endpoint_service" "ecr_dkr" {
  count = var.create_vpc && var.enable_ecr_dkr_endpoint ? 1 : 0

  service = "ecr.dkr"
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  count = var.create_vpc && var.enable_ecr_dkr_endpoint ? 1 : 0

  vpc_id            = local.vpc_id
  service_name      = data.aws_vpc_endpoint_service.ecr_dkr[0].service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [var.ecr_dkr_endpoint_security_group_ids]
  subnet_ids          = coalescelist(var.ecr_dkr_endpoint_subnet_ids, list(aws_subnet.private.*.id[0], aws_subnet.private.*.id[1], aws_subnet.private.*.id[2]))
  private_dns_enabled = var.ecr_dkr_endpoint_private_dns_enabled
}

##########################
# Route table association
##########################
resource "aws_route_table_association" "private" {
  count = var.create_vpc && length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, (var.single_nat_gateway ? 0 : count.index))
}

resource "aws_route_table_association" "public" {
  count = var.create_vpc && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public[0].id
}

###########
# internal network acl
###########
resource "aws_network_acl" "private" {
  vpc_id = local.vpc_id

  count      = length(var.private_subnet_suffix)
  subnet_ids = [element(aws_subnet.private.*.id, count.index * 2), element(aws_subnet.private.*.id, count.index * 2 + 1)]
  tags       = merge(map("Name", format("%s", element(var.private_subnet_suffix, count.index))))
}


resource "aws_network_acl_rule" "private" {
  count          = length(var.private_subnets) * var.private_subnet_suffix_count
  network_acl_id = element(aws_network_acl.private.*.id, floor(count.index / length(var.private_subnets)))
  protocol       = "-1"
  rule_action    = "allow"
  rule_number    = count.index % length(var.private_subnets) + 2
  cidr_block     = element(aws_subnet.private.*.cidr_block, count.index)
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "private-out" {
  count          = length(var.private_subnets) * var.private_subnet_suffix_count
  network_acl_id = element(aws_network_acl.private.*.id, floor(count.index / length(var.private_subnets)))
  protocol       = "-1"
  rule_action    = "allow"
  rule_number    = count.index % length(var.private_subnets) + 2
  cidr_block     = element(aws_subnet.private.*.cidr_block, count.index)
  from_port      = 0
  to_port        = 0
  egress         = true
}


###########
# EKS related ACL (EKS Control Plan, ECR, S3, EC2-Endpoint
# We use 350 -> 399 for ALLOW rules and reserve 300-349 for future DENY rules
# See database EKS section for more details of why 0.0.0.0/0 is used
###########
resource "aws_network_acl_rule" "private-eks-port" {
  count          = length(var.private_subnet_suffix)
  network_acl_id = element(aws_network_acl.private.*.id, count.index)
  protocol       = "tcp"
  rule_action    = "allow"
  rule_number    = 350
  cidr_block     = "0.0.0.0/0"
  from_port      = "1025"
  to_port        = "65535"
}

resource "aws_network_acl_rule" "private-eks-port-out" {
  count          = length(var.private_subnet_suffix)
  network_acl_id = element(aws_network_acl.private.*.id, count.index)
  protocol       = "tcp"
  rule_action    = "allow"
  rule_number    = 350
  cidr_block     = "0.0.0.0/0"
  from_port      = "1025"
  to_port        = "65535"
  egress         = true
}

resource "aws_network_acl_rule" "private-eks-ssl-port" {
  count          = length(var.private_subnet_suffix)
  network_acl_id = element(aws_network_acl.private.*.id, count.index)
  protocol       = "tcp"
  rule_action    = "allow"
  rule_number    = 351
  cidr_block     = "0.0.0.0/0"
  from_port      = "443"
  to_port        = "443"
}

resource "aws_network_acl_rule" "private-eks-ssl-port-out" {
  count          = length(var.private_subnet_suffix)
  network_acl_id = element(aws_network_acl.private.*.id, count.index)
  protocol       = "tcp"
  rule_action    = "allow"
  rule_number    = 351
  cidr_block     = "0.0.0.0/0"
  from_port      = "443"
  to_port        = "443"
  egress         = true
}

# UDP opens for helthcheck and http/3.
resource "aws_network_acl_rule" "private-eks-udp-port" {
  count          = length(var.private_subnet_suffix)
  network_acl_id = element(aws_network_acl.private.*.id, count.index)
  protocol       = "udp"
  rule_action    = "allow"
  rule_number    = 352
  cidr_block     = var.cidr
  to_port        = "65535"
}

resource "aws_network_acl_rule" "private-eks-udp-port-out" {
  count          = length(var.private_subnet_suffix)
  network_acl_id = element(aws_network_acl.private.*.id, count.index)
  protocol       = "udp"
  rule_action    = "allow"
  rule_number    = 352
  cidr_block     = var.cidr
  to_port        = "65535"
  egress         = true
}
