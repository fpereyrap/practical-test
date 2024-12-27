locals {
  max_subnet_length = max(
    length(local.private_subnets)
  )
  transit_gateway = var.route_transit_gateway ? 1 : 0

  private_subnets = [cidrsubnet(var.cidr, 2, 0), cidrsubnet(var.cidr, 2, 1)]
  public_subnets  = [cidrsubnet(var.cidr, 2, 2), cidrsubnet(var.cidr, 2, 3)]

  nat_gateway_count = var.single_nat_gateway ? 1 : var.one_nat_gateway_per_az ? length(var.azs) : local.max_subnet_length

  nat_gateway_ips = split(
    ",",
    var.reuse_nat_ips ? join(",", var.external_nat_ip_ids) : join(",", aws_eip.nat.*.id)


  )

  # Use `local.vpc_id` to give a hint to Terraform that subnets should be deleted before secondary CIDR blocks can be free!
  vpc_id = element(
    concat(
      aws_vpc_ipv4_cidr_block_association.this.*.vpc_id,
      aws_vpc.this.*.id,
      [""],
    ),
    0,
  )

  mandatory_tags = {
    "Terraform"   = "true",
    "Environment" = var.environment
  }

  tags = merge(local.mandatory_tags, var.tags)
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

  tags = merge(
    {
      "Name" = format("%s", var.name)
    },
    local.tags,
    var.tags
  )
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  count = var.create_vpc && length(var.secondary_cidr_blocks) > 0 ? length(var.secondary_cidr_blocks) : 0

  vpc_id = aws_vpc.this[0].id

  cidr_block = element(var.secondary_cidr_blocks, count.index)
}

###################
# DHCP Options Set
###################
resource "aws_vpc_dhcp_options" "this" {
  count = var.create_vpc && var.enable_dhcp_options ? 1 : 0

  domain_name          = var.dhcp_options_domain_name
  domain_name_servers  = var.dhcp_options_domain_name_servers
  ntp_servers          = var.dhcp_options_ntp_servers
  netbios_name_servers = var.dhcp_options_netbios_name_servers
  netbios_node_type    = var.dhcp_options_netbios_node_type

  tags = merge(
    {
      "Name" = format("%s", var.name)
    },
    local.tags,
    var.tags,
    var.dhcp_options_tags
  )
}

###############################
# DHCP Options Set Association
###############################
resource "aws_vpc_dhcp_options_association" "this" {
  count = var.create_vpc && var.enable_dhcp_options ? 1 : 0

  vpc_id          = local.vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.this[0].id
}

###################
# Internet Gateway
###################
resource "aws_internet_gateway" "this" {
  count = var.create_vpc && length(local.public_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = format("%s", var.name)
    },
    local.tags,
    var.tags,
    var.igw_tags
  )
}

################
# Publiс routes
################
resource "aws_route_table" "public" {
  count = var.create_vpc && length(local.public_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = format("%s-${var.public_subnet_suffix}", var.name)
    },
    local.tags,
    var.tags,
    var.public_route_table_tags
  )
}

resource "aws_route" "public_internet_gateway" {
  count = var.create_vpc && length(local.public_subnets) > 0 ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id

  timeouts {
    create = "5m"
  }
}

#################
# Private routes
# There are so many routing tables as the largest amount of subnets of each type
#################
resource "aws_route_table" "private" {
  count = var.create_vpc && local.max_subnet_length > 0 ? local.nat_gateway_count : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = var.single_nat_gateway ? "${var.name}-${var.private_subnet_suffix}" : format(
        "%s-${var.private_subnet_suffix}-%s",
        var.name,
        element(var.azs, count.index),
      )
    },
    local.tags,
    var.tags,
    var.private_route_table_tags
  )

  lifecycle {
    # When attaching VPN gateways it is common to define aws_vpn_gateway_route_propagation
    # resources that manipulate the attributes of the routing table (typically for the private subnets)
    ignore_changes = [propagating_vgws]
  }
}

#################
# Intra routes
#################
resource "aws_route_table" "intra" {
  count = var.create_vpc && length(var.intra_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = "${var.name}-intra"
    },
    local.tags,
    var.tags,
    var.intra_route_table_tags
  )
}

################
# Public subnet
################
resource "aws_subnet" "public" {
  count = var.create_vpc && length(local.public_subnets) > 0 && false == var.one_nat_gateway_per_az || length(local.public_subnets) >= length(var.azs) ? length(local.public_subnets) : 0

  vpc_id                  = local.vpc_id
  cidr_block              = element(concat(local.public_subnets, [""]), count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(
    {
      "Name" = format(
        "%s-${var.public_subnet_suffix}-%s",
        var.name,
        element(var.azs, count.index),
      )
    },
    local.tags,
    var.tags,
    var.public_subnet_tags
  )
}

#################
# Private subnet
#################
resource "aws_subnet" "private" {
  count = var.create_vpc && length(local.private_subnets) > 0 ? length(local.private_subnets) : 0

  vpc_id            = local.vpc_id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = element(var.azs, count.index)

  tags = merge(
    {
      "Name" = format(
        "%s-${var.private_subnet_suffix}-%s",
        var.name,
        element(var.azs, count.index),
      )
    },
    local.tags,
    var.tags,
    var.private_subnet_tags
  )
}

#####################################################
# intra subnets - private subnet without NAT gateway
#####################################################
resource "aws_subnet" "intra" {
  count = var.create_vpc && length(var.intra_subnets) > 0 ? length(var.intra_subnets) : 0

  vpc_id            = local.vpc_id
  cidr_block        = var.intra_subnets[count.index]
  availability_zone = element(var.azs, count.index)

  tags = merge(
    {
      "Name" = format("%s-intra-%s", var.name, element(var.azs, count.index))
    },
    local.tags,
    var.tags,
    var.intra_subnet_tags
  )
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
  count = var.create_vpc && var.enable_nat_gateway && false == var.reuse_nat_ips ? local.nat_gateway_count : 0

  tags = merge(
    {
      "Name" = format(
        "%s-%s",
        var.name,
        element(var.azs, var.single_nat_gateway ? 0 : count.index),
      )
    },
    local.tags,
    var.tags,
    var.nat_eip_tags
  )
}

resource "aws_nat_gateway" "this" {
  count = var.create_vpc && var.enable_nat_gateway ? local.nat_gateway_count : 0

  # allocation_id = element(
  #   local.nat_gateway_ips,
  #   var.single_nat_gateway ? 0 : count.index,
  # )
  # subnet_id = element(
  #   aws_subnet.public.*.id,
  #   var.single_nat_gateway ? 0 : count.index,
  # )

  allocation_id = local.nat_gateway_ips[count.index]
  subnet_id     = element(aws_subnet.public.*.id, count.index)

  tags = merge(
    {
      "Name" = format(
        "%s-%s",
        var.name,
        element(var.azs, var.single_nat_gateway ? 0 : count.index),
      )
    },
    local.tags,
    var.tags,
    var.nat_gateway_tags
  )

  depends_on = [aws_internet_gateway.this, aws_eip.nat, aws_subnet.public]
}

resource "aws_route" "private_nat_gateway" {
  count = var.create_vpc && var.enable_nat_gateway && !var.route_transit_gateway ? local.nat_gateway_count : 0

  route_table_id         = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this.*.id, count.index)

  timeouts {
    create = "5m"
  }
}

######################
# Transit Gateway
######################
# No Transit Gateway is created here. Only the route table will be generated.
# The route table rule will be assigned to the private subnets.

resource "aws_route" "transit_gateway" {
  count = var.create_vpc && var.route_transit_gateway ? 1 : 0

  route_table_id         = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.transit_gateway_id

  timeouts {
    create = "5m"
  }
}

##################################
# VPC Endpoint for Secrets Manager
##################################
data "aws_vpc_endpoint_service" "secretsmanager" {
  count   = var.create_vpc && var.enable_secrets_manager_endpoint ? 1 : 0
  service = "secretsmanager"
}

resource "aws_vpc_endpoint" "secretsmanager" {
  count = var.create_vpc && var.enable_secrets_manager_endpoint ? 1 : 0

  vpc_id       = local.vpc_id
  service_name = data.aws_vpc_endpoint_service.secretsmanager[0].service_name

  vpc_endpoint_type = "Interface"

  security_group_ids = coalescelist(var.secrets_manager_endpoint_security_group_ids, aws_vpc.this.*.default_security_group_id)

  subnet_ids          = coalescelist(var.secrets_manager_endpoint_subnet_ids, aws_subnet.private.*.id)
  private_dns_enabled = var.secrets_manager_endpoint_private_dns_enabled

  tags = merge(local.tags, var.vpc_endpoint_secrets_manager_tags)
}


######################
# VPC Endpoint for S3
######################
data "aws_vpc_endpoint_service" "s3" {
  count = var.create_vpc && var.enable_s3_endpoint ? 1 : 0

  service = "s3"
}

resource "aws_vpc_endpoint" "s3" {
  count = var.create_vpc && var.enable_s3_endpoint ? 1 : 0

  vpc_id       = local.vpc_id
  service_name = data.aws_vpc_endpoint_service.s3[0].service_name

  tags = merge(local.tags, var.vpc_endpoint_s3_tags)
}


######################
# VPC Endpoint for apigateway
######################

resource "aws_vpc_endpoint" "api_gateway_endpoint" {
  count = var.enable_api_gateway_endpoint && length(local.private_subnets) > 0 ? 1 : 0

  vpc_id       = local.vpc_id
  service_name = data.aws_vpc_endpoint_service.api_gateway_service_name[0].service_name

  # private_dns_enabled = var.vpc_endpoint_private_dns

  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.private.*.id
  security_group_ids = aws_security_group.allow_api_gateway_enpoint.*.id

  depends_on = [aws_subnet.private]

  tags = merge(local.tags, var.tags, var.vpc_endpoint_api_gateway_tags)
}


resource "aws_security_group" "allow_api_gateway_enpoint" {
  count       = var.enable_api_gateway_endpoint && length(local.private_subnets) > 0 ? 1 : 0
  name        = "sg_execute_api"
  description = "It allows for HTTPS access to the endpoint for the entire VPC IP"
  vpc_id      = local.vpc_id

  ingress {
    description = "execute api from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = aws_subnet.private.*.cidr_block
  }

  tags = merge(local.tags, var.tags, var.vpc_endpoint_api_gateway_tags)
}

data "aws_vpc_endpoint_service" "api_gateway_service_name" {
  count = var.enable_api_gateway_endpoint && length(local.private_subnets) > 0 ? 1 : 0

  service = "execute-api"

  tags = local.tags
}


resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  count = var.create_vpc && var.enable_s3_endpoint ? local.nat_gateway_count : 0

  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
  route_table_id  = element(aws_route_table.private.*.id, count.index)
}

resource "aws_vpc_endpoint_route_table_association" "intra_s3" {
  count = var.create_vpc && var.enable_s3_endpoint && length(var.intra_subnets) > 0 ? 1 : 0

  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
  route_table_id  = element(aws_route_table.intra.*.id, 0)
}

resource "aws_vpc_endpoint_route_table_association" "public_s3" {
  count = var.create_vpc && var.enable_s3_endpoint && length(local.public_subnets) > 0 ? 1 : 0

  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
  route_table_id  = aws_route_table.public[0].id
}

############################
# VPC Endpoint for DynamoDB
############################
data "aws_vpc_endpoint_service" "dynamodb" {
  count = var.create_vpc && var.enable_dynamodb_endpoint ? 1 : 0

  service = "dynamodb"
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = var.create_vpc && var.enable_dynamodb_endpoint ? 1 : 0

  vpc_id       = local.vpc_id
  service_name = data.aws_vpc_endpoint_service.dynamodb[0].service_name

  tags = merge(local.tags, var.tags, var.vpc_endpoint_dynamodb_tags)

}

resource "aws_vpc_endpoint_route_table_association" "private_dynamodb" {
  count = var.create_vpc && var.enable_dynamodb_endpoint ? local.nat_gateway_count : 0

  vpc_endpoint_id = aws_vpc_endpoint.dynamodb[0].id
  route_table_id  = element(aws_route_table.private.*.id, count.index)
}

resource "aws_vpc_endpoint_route_table_association" "intra_dynamodb" {
  count = var.create_vpc && var.enable_dynamodb_endpoint && length(var.intra_subnets) > 0 ? 1 : 0

  vpc_endpoint_id = aws_vpc_endpoint.dynamodb[0].id
  route_table_id  = element(aws_route_table.intra.*.id, 0)
}

resource "aws_vpc_endpoint_route_table_association" "public_dynamodb" {
  count = var.create_vpc && var.enable_dynamodb_endpoint && length(local.public_subnets) > 0 ? 1 : 0

  vpc_endpoint_id = aws_vpc_endpoint.dynamodb[0].id
  route_table_id  = aws_route_table.public[0].id
}

######################
# VPC Endpoint for SSM
######################
data "aws_vpc_endpoint_service" "ssm" {
  count = var.create_vpc && var.enable_ssm_endpoint ? 1 : 0

  service = "ssm"
}

resource "aws_vpc_endpoint" "ssm" {
  count = var.create_vpc && var.enable_ssm_endpoint ? 1 : 0

  vpc_id            = local.vpc_id
  service_name      = data.aws_vpc_endpoint_service.ssm[0].service_name
  vpc_endpoint_type = "Interface"

  security_group_ids = var.ssm_endpoint_security_group_ids

  subnet_ids          = coalescelist(var.ssm_endpoint_subnet_ids, aws_subnet.private.*.id)
  private_dns_enabled = var.ssm_endpoint_private_dns_enabled

  tags = merge(local.tags, var.tags, var.vpc_endpoint_ssm_tags)

}

######################
# VPC Endpoint for EC2
######################
data "aws_vpc_endpoint_service" "ec2" {
  count = var.create_vpc && var.enable_ec2_endpoint ? 1 : 0

  service = "ec2"
}

resource "aws_vpc_endpoint" "ec2" {
  count = var.create_vpc && var.enable_ec2_endpoint ? 1 : 0

  vpc_id            = local.vpc_id
  service_name      = data.aws_vpc_endpoint_service.ec2[0].service_name
  vpc_endpoint_type = "Interface"

  security_group_ids = var.ec2_endpoint_security_group_ids

  subnet_ids          = coalescelist(var.ec2_endpoint_subnet_ids, aws_subnet.private.*.id)
  private_dns_enabled = var.ec2_endpoint_private_dns_enabled

  tags = merge(local.tags, var.tags, var.vpc_endpoint_ec2_tags)

}

##########################
# Route table association
##########################
resource "aws_route_table_association" "private" {
  count = var.create_vpc && length(local.private_subnets) > 0 ? length(local.private_subnets) : 0

  subnet_id = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(
    aws_route_table.private.*.id,
    var.single_nat_gateway ? 0 : count.index,
  )
}

resource "aws_route_table_association" "intra" {
  count = var.create_vpc && length(var.intra_subnets) > 0 ? length(var.intra_subnets) : 0

  subnet_id      = element(aws_subnet.intra.*.id, count.index)
  route_table_id = element(aws_route_table.intra.*.id, 0)
}

resource "aws_route_table_association" "public" {
  count = var.create_vpc && length(local.public_subnets) > 0 ? length(local.public_subnets) : 0

  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public[0].id
}

###########
# Defaults
###########
resource "aws_default_vpc" "this" {
  count = var.manage_default_vpc ? 1 : 0

  enable_dns_support   = var.default_vpc_enable_dns_support
  enable_dns_hostnames = var.default_vpc_enable_dns_hostnames

  tags = merge(
    {
      "Name" = format("%s", var.default_vpc_name)
    },
    local.tags,
    var.tags,
  )
}

resource "aws_default_security_group" "this" {
  count = var.manage_default_security_group ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, var.tags)

}
