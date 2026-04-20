locals {
  name_prefix = var.project_name

  default_tags = merge(
    {
      Project      = var.project_name
      ManagedBy    = "Terraform"
      Architecture = "Hub-Spoke-Inspection"
    },
    var.common_tags,
  )

  prod_name    = "${local.name_prefix}-prod"
  uat_name     = "${local.name_prefix}-uat"
  network_name = "${local.name_prefix}-network"
  tgw_name     = "${local.name_prefix}-tgw"

  az_suffixes = {
    ap-southeast-1a = "za"
    ap-southeast-1b = "zb"
    ap-southeast-1c = "zc"
  }

  tgw_subnet_to_gwlbe = merge(
    { for az in keys(var.network_subnet_cidrs.gwlbe) : az => az },
    var.tgw_subnet_to_gwlbe_az_map,
  )

  on_prem_routes = var.enable_on_prem_vpn ? {
    for cidr in var.on_prem_cidrs :
    replace(replace(cidr, ".", "-"), "/", "-") => cidr
  } : {}

  gwlbe_route_destinations = merge(
    {
      prod = var.prod_vpc_cidr
      uat  = var.uat_vpc_cidr
    },
    {
      for key, cidr in local.on_prem_routes :
      "onprem-${key}" => cidr
    },
  )

  prod_public_subnets = {
    for name, subnet in var.prod_subnets :
    name => subnet
    if subnet.route == "igw"
  }

  prod_private_subnets = {
    for name, subnet in var.prod_subnets :
    name => subnet
    if subnet.route == "tgw"
  }

  prod_tgw_attachment_subnets = {
    for name, subnet in var.prod_subnets :
    name => subnet
    if subnet.tgw_attachment
  }

  uat_public_subnets = {
    for name, subnet in var.uat_subnets :
    name => subnet
    if subnet.route == "igw"
  }

  uat_private_subnets = {
    for name, subnet in var.uat_subnets :
    name => subnet
    if subnet.route == "tgw"
  }

  uat_tgw_attachment_subnets = {
    for name, subnet in var.uat_subnets :
    name => subnet
    if subnet.tgw_attachment
  }
}
