locals {
  prod_route_table_names = {
    for name, subnet in var.prod_subnets :
    name => (
      strcontains(name, "-app-cluster-private-subnet-")
      ? replace(name, "-app-cluster-private-subnet-${local.az_suffixes[subnet.az]}", "-app-private-rt")
      : replace(name, "-subnet-${local.az_suffixes[subnet.az]}", "-rt")
    )
  }

  uat_route_table_names = {
    for name, subnet in var.uat_subnets :
    name => (
      strcontains(name, "-app-cluster-private-subnet-")
      ? replace(name, "-app-cluster-private-subnet-${local.az_suffixes[subnet.az]}", "-app-private-rt")
      : replace(name, "-subnet-${local.az_suffixes[subnet.az]}", "-rt")
    )
  }

  prod_public_route_tables = toset([
    for name, subnet in var.prod_subnets :
    local.prod_route_table_names[name]
    if subnet.route == "igw"
  ])

  prod_app_private_route_tables = toset([
    for name, subnet in var.prod_subnets :
    local.prod_route_table_names[name]
    if subnet.route == "tgw" && strcontains(local.prod_route_table_names[name], "-app-private-rt")
  ])

  prod_db_private_route_tables = toset([
    for name, subnet in var.prod_subnets :
    local.prod_route_table_names[name]
    if subnet.route == "tgw" && strcontains(local.prod_route_table_names[name], "-db-private-rt")
  ])

  uat_public_route_tables = toset([
    for name, subnet in var.uat_subnets :
    local.uat_route_table_names[name]
    if subnet.route == "igw"
  ])

  uat_app_private_route_tables = toset([
    for name, subnet in var.uat_subnets :
    local.uat_route_table_names[name]
    if subnet.route == "tgw" && strcontains(local.uat_route_table_names[name], "-app-private-rt")
  ])

  uat_db_private_route_tables = toset([
    for name, subnet in var.uat_subnets :
    local.uat_route_table_names[name]
    if subnet.route == "tgw" && strcontains(local.uat_route_table_names[name], "-db-private-rt")
  ])

  network_tgw_route_tables = toset(distinct(values(local.tgw_subnet_to_gwlbe)))

  prod_app_private_on_prem_routes = {
    for route in flatten([
      for rt_name in local.prod_app_private_route_tables : [
        for key, cidr in local.on_prem_routes : {
          id   = "${rt_name}-${key}"
          name = rt_name
          cidr = cidr
        }
      ]
    ]) : route.id => route
  }

  prod_db_private_on_prem_routes = {
    for route in flatten([
      for rt_name in local.prod_db_private_route_tables : [
        for key, cidr in local.on_prem_routes : {
          id   = "${rt_name}-${key}"
          name = rt_name
          cidr = cidr
        }
      ]
    ]) : route.id => route
  }

  uat_app_private_on_prem_routes = {
    for route in flatten([
      for rt_name in local.uat_app_private_route_tables : [
        for key, cidr in local.on_prem_routes : {
          id   = "${rt_name}-${key}"
          name = rt_name
          cidr = cidr
        }
      ]
    ]) : route.id => route
  }

  uat_db_private_on_prem_routes = {
    for route in flatten([
      for rt_name in local.uat_db_private_route_tables : [
        for key, cidr in local.on_prem_routes : {
          id   = "${rt_name}-${key}"
          name = rt_name
          cidr = cidr
        }
      ]
    ]) : route.id => route
  }
}

resource "aws_route_table" "prod_public" {
  for_each = local.prod_public_route_tables

  vpc_id = aws_vpc.prod.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod.id
  }

  tags = {
    Name = each.value
  }
}

resource "aws_route_table" "prod_app_private" {
  for_each = local.prod_app_private_route_tables

  vpc_id = aws_vpc.prod.id

  tags = {
    Name = each.value
  }
}

resource "aws_route" "prod_app_private_to_uat" {
  for_each = aws_route_table.prod_app_private

  route_table_id         = each.value.id
  destination_cidr_block = var.uat_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}

resource "aws_route" "prod_app_private_default" {
  for_each = aws_route_table.prod_app_private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}

resource "aws_route" "prod_app_private_on_prem" {
  for_each = local.prod_app_private_on_prem_routes

  route_table_id         = aws_route_table.prod_app_private[each.value.name].id
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}

resource "aws_route_table" "prod_db_private" {
  for_each = local.prod_db_private_route_tables

  vpc_id = aws_vpc.prod.id

  tags = {
    Name = each.value
  }
}

resource "aws_route" "prod_db_private_on_prem" {
  for_each = local.prod_db_private_on_prem_routes

  route_table_id         = aws_route_table.prod_db_private[each.value.name].id
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}

resource "aws_route_table_association" "prod" {
  for_each = local.prod_route_table_names

  subnet_id = aws_subnet.prod[each.key].id
  route_table_id = (
    var.prod_subnets[each.key].route == "igw"
    ? aws_route_table.prod_public[each.value].id
    : (
      strcontains(each.value, "-app-private-rt")
      ? aws_route_table.prod_app_private[each.value].id
      : aws_route_table.prod_db_private[each.value].id
    )
  )
}

resource "aws_route_table" "uat_public" {
  for_each = local.uat_public_route_tables

  vpc_id = aws_vpc.uat.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.uat.id
  }

  tags = {
    Name = each.value
  }
}

resource "aws_route_table" "uat_app_private" {
  for_each = local.uat_app_private_route_tables

  vpc_id = aws_vpc.uat.id

  tags = {
    Name = each.value
  }
}

resource "aws_route" "uat_app_private_to_prod" {
  for_each = aws_route_table.uat_app_private

  route_table_id         = each.value.id
  destination_cidr_block = var.prod_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}

resource "aws_route" "uat_app_private_default" {
  for_each = aws_route_table.uat_app_private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}

resource "aws_route" "uat_app_private_on_prem" {
  for_each = local.uat_app_private_on_prem_routes

  route_table_id         = aws_route_table.uat_app_private[each.value.name].id
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}

resource "aws_route_table" "uat_db_private" {
  for_each = local.uat_db_private_route_tables

  vpc_id = aws_vpc.uat.id

  tags = {
    Name = each.value
  }
}

resource "aws_route" "uat_db_private_on_prem" {
  for_each = local.uat_db_private_on_prem_routes

  route_table_id         = aws_route_table.uat_db_private[each.value.name].id
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}

resource "aws_route_table_association" "uat" {
  for_each = local.uat_route_table_names

  subnet_id = aws_subnet.uat[each.key].id
  route_table_id = (
    var.uat_subnets[each.key].route == "igw"
    ? aws_route_table.uat_public[each.value].id
    : (
      strcontains(each.value, "-app-private-rt")
      ? aws_route_table.uat_app_private[each.value].id
      : aws_route_table.uat_db_private[each.value].id
    )
  )
}

resource "aws_route_table" "network_gwlb" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = "network-gwlb-rt"
  }
}

resource "aws_route_table_association" "network_gwlb" {
  for_each = aws_subnet.network_gwlb

  subnet_id      = each.value.id
  route_table_id = aws_route_table.network_gwlb.id
}

resource "aws_route_table" "network_gwlbe" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = "network-gwlbe-rt"
  }
}

resource "aws_route" "network_gwlbe_to_prod" {
  route_table_id         = aws_route_table.network_gwlbe.id
  destination_cidr_block = var.prod_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}

resource "aws_route" "network_gwlbe_to_uat" {
  route_table_id         = aws_route_table.network_gwlbe.id
  destination_cidr_block = var.uat_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}

resource "aws_route" "network_gwlbe_on_prem" {
  for_each = local.on_prem_routes

  route_table_id         = aws_route_table.network_gwlbe.id
  destination_cidr_block = each.value
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}

resource "aws_route_table_association" "network_gwlbe" {
  for_each = aws_subnet.network_gwlbe

  subnet_id      = each.value.id
  route_table_id = aws_route_table.network_gwlbe.id
}

resource "aws_route_table" "network_tgw" {
  for_each = local.network_tgw_route_tables

  vpc_id = aws_vpc.network.id

  tags = {
    Name = "network-tgw-rt-${local.az_suffixes[each.value]}"
  }
}

resource "aws_route" "network_tgw_default" {
  for_each = aws_route_table.network_tgw

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = aws_vpc_endpoint.gwlbe[each.key].id
}

resource "aws_route_table_association" "network_tgw" {
  for_each = aws_subnet.network_tgw

  subnet_id      = each.value.id
  route_table_id = aws_route_table.network_tgw[local.tgw_subnet_to_gwlbe[each.key]].id
}

resource "aws_route_table" "network_fw_data" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = "network-fw-data-rt"
  }
}

resource "aws_route_table_association" "network_fw_data" {
  for_each = aws_subnet.network_fw_data

  subnet_id      = each.value.id
  route_table_id = aws_route_table.network_fw_data.id
}

resource "aws_route_table" "network_fw_mgmt" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = "network-fw-mgmt-rt"
  }
}

resource "aws_route" "network_fw_mgmt_on_prem" {
  for_each = local.on_prem_routes

  route_table_id         = aws_route_table.network_fw_mgmt.id
  destination_cidr_block = each.value
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}

resource "aws_route_table_association" "network_fw_mgmt" {
  for_each = aws_subnet.network_fw_mgmt

  subnet_id      = each.value.id
  route_table_id = aws_route_table.network_fw_mgmt.id
}

resource "aws_route_table" "network_public" {
  vpc_id = aws_vpc.network.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.network.id
  }

  tags = {
    Name = "network-public-rt"
  }
}

resource "aws_route_table_association" "network_public" {
  for_each = aws_subnet.network_public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.network_public.id
}

resource "aws_route_table" "network_r53" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = "network-r53-rt"
  }
}

resource "aws_route" "network_r53_on_prem" {
  for_each = local.on_prem_routes

  route_table_id         = aws_route_table.network_r53.id
  destination_cidr_block = each.value
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}

resource "aws_route_table_association" "network_r53" {
  for_each = aws_subnet.network_r53

  subnet_id      = each.value.id
  route_table_id = aws_route_table.network_r53.id
}

resource "aws_route_table" "network_fw_gp" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = "network-fw-gp-rt"
  }
}

resource "aws_route" "network_fw_gp_to_prod" {
  route_table_id         = aws_route_table.network_fw_gp.id
  destination_cidr_block = var.prod_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}

resource "aws_route" "network_fw_gp_to_uat" {
  route_table_id         = aws_route_table.network_fw_gp.id
  destination_cidr_block = var.uat_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}

resource "aws_route_table_association" "network_fw_gp" {
  for_each = aws_subnet.network_fw_gp

  subnet_id      = each.value.id
  route_table_id = aws_route_table.network_fw_gp.id
}
