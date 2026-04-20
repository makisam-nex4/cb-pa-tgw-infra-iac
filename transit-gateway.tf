resource "aws_ec2_transit_gateway" "this" {
  description                     = "Shared transit gateway for inspected north-south and hybrid connectivity."
  amazon_side_asn                 = var.transit_gateway_amazon_side_asn
  auto_accept_shared_attachments  = "disable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = {
    Name = local.tgw_name
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "network" {
  subnet_ids             = values(aws_subnet.network_tgw)[*].id
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  vpc_id                 = aws_vpc.network.id
  dns_support            = "enable"
  ipv6_support           = "disable"
  appliance_mode_support = "enable"

  tags = {
    Name = "${local.network_name}-tgw-attachment"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "prod" {
  subnet_ids = [
    for name in sort(keys(local.prod_tgw_attachment_subnets)) :
    aws_subnet.prod[name].id
  ]
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  vpc_id                 = aws_vpc.prod.id
  dns_support            = "enable"
  ipv6_support           = "disable"
  appliance_mode_support = "disable"

  tags = {
    Name = "${local.prod_name}-tgw-attachment"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "uat" {
  subnet_ids = [
    for name in sort(keys(local.uat_tgw_attachment_subnets)) :
    aws_subnet.uat[name].id
  ]
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  vpc_id                 = aws_vpc.uat.id
  dns_support            = "enable"
  ipv6_support           = "disable"
  appliance_mode_support = "disable"

  tags = {
    Name = "${local.uat_name}-tgw-attachment"
  }
}

#
# On-premises VPN resources are intentionally optional.
# Leave enable_on_prem_vpn = false to skip the Site-to-Site VPN build for now.
#
resource "aws_customer_gateway" "on_prem" {
  count = var.enable_on_prem_vpn ? 1 : 0

  bgp_asn    = var.vpn_customer_gateway_bgp_asn
  ip_address = var.vpn_customer_gateway_ip
  type       = "ipsec.1"

  tags = {
    Name = "${local.name_prefix}-customer-gateway"
  }
}

resource "aws_vpn_connection" "s2s" {
  count = var.enable_on_prem_vpn ? 1 : 0

  customer_gateway_id = aws_customer_gateway.on_prem[0].id
  transit_gateway_id  = aws_ec2_transit_gateway.this.id
  type                = "ipsec.1"
  static_routes_only  = var.vpn_static_routes_only

  tags = {
    Name = "${local.name_prefix}-s2s-vpn"
  }
}

resource "aws_vpn_connection_route" "static" {
  for_each = var.enable_on_prem_vpn && var.vpn_static_routes_only ? local.on_prem_routes : {}

  destination_cidr_block = each.value
  vpn_connection_id      = aws_vpn_connection.s2s[0].id
}

resource "aws_ec2_transit_gateway_route_table" "spoke" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = {
    Name = "${local.tgw_name}-spoke-rt"
  }
}

resource "aws_ec2_transit_gateway_route_table" "inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = {
    Name = "${local.tgw_name}-inspection-rt"
  }
}

resource "aws_ec2_transit_gateway_route_table" "vpn" {
  count = var.enable_on_prem_vpn ? 1 : 0

  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = {
    Name = "${local.tgw_name}-vpn-rt"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "network" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.network.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}

resource "aws_ec2_transit_gateway_route_table_association" "prod" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ec2_transit_gateway_route_table_association" "uat" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.uat.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ec2_transit_gateway_route_table_association" "vpn" {
  count = var.enable_on_prem_vpn ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.s2s[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpn[0].id
}

resource "aws_ec2_transit_gateway_route" "spoke_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.network.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ec2_transit_gateway_route" "inspection_prod" {
  destination_cidr_block         = var.prod_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}

resource "aws_ec2_transit_gateway_route" "inspection_uat" {
  destination_cidr_block         = var.uat_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.uat.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}

resource "aws_ec2_transit_gateway_route" "vpn_network" {
  count = var.enable_on_prem_vpn ? 1 : 0

  destination_cidr_block         = var.network_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.network.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpn[0].id
}

resource "aws_ec2_transit_gateway_route" "vpn_prod" {
  count = var.enable_on_prem_vpn ? 1 : 0

  destination_cidr_block         = var.prod_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.network.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpn[0].id
}

resource "aws_ec2_transit_gateway_route" "vpn_uat" {
  count = var.enable_on_prem_vpn ? 1 : 0

  destination_cidr_block         = var.uat_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.network.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpn[0].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "vpn_to_inspection" {
  count = var.enable_on_prem_vpn ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.s2s[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}
