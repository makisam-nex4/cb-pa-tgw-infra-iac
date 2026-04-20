output "network_vpc_id" {
  description = "ID of the shared inspection/network VPC."
  value       = aws_vpc.network.id
}

output "network_subnet_ids" {
  description = "Network VPC subnet IDs keyed by the requested subnet names."
  value = merge(
    {
      for az, subnet in aws_subnet.network_public :
      "network-public-subnet-${local.az_suffixes[az]}" => subnet.id
    },
    {
      for az, subnet in aws_subnet.network_fw_data :
      "network-fw-data-private-subnet-${local.az_suffixes[az]}" => subnet.id
    },
    {
      for az, subnet in aws_subnet.network_fw_mgmt :
      "network-fw-mgmt-private-subnet-${local.az_suffixes[az]}" => subnet.id
    },
    {
      for az, subnet in aws_subnet.network_gwlb :
      "network-gwlb-private-subnet-${local.az_suffixes[az]}" => subnet.id
    },
    {
      for az, subnet in aws_subnet.network_gwlbe :
      "network-gwlbe-private-subnet-${local.az_suffixes[az]}" => subnet.id
    },
    {
      for az, subnet in aws_subnet.network_tgw :
      "network-tgw-private-subnet-${local.az_suffixes[az]}" => subnet.id
    },
    {
      for az, subnet in aws_subnet.network_r53 :
      "network-r53-private-subnet-${local.az_suffixes[az]}" => subnet.id
    },
    {
      for az, subnet in aws_subnet.network_fw_gp :
      "network-fw-gp-private-subnet-${local.az_suffixes[az]}" => subnet.id
    },
  )
}

output "prod_vpc_id" {
  description = "ID of the Prod VPC."
  value       = aws_vpc.prod.id
}

output "prod_subnet_ids" {
  description = "Prod VPC subnet IDs keyed by exact subnet names."
  value = {
    for name, subnet in aws_subnet.prod : name => subnet.id
  }
}

output "uat_vpc_id" {
  description = "ID of the UAT VPC."
  value       = aws_vpc.uat.id
}

output "uat_subnet_ids" {
  description = "UAT VPC subnet IDs keyed by exact subnet names."
  value = {
    for name, subnet in aws_subnet.uat : name => subnet.id
  }
}

output "transit_gateway_id" {
  description = "Transit Gateway ID."
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_route_table_ids" {
  description = "Transit Gateway route tables for spoke, inspection, and VPN traffic domains."
  value = {
    spoke      = aws_ec2_transit_gateway_route_table.spoke.id
    inspection = aws_ec2_transit_gateway_route_table.inspection.id
    vpn        = try(aws_ec2_transit_gateway_route_table.vpn[0].id, null)
  }
}

output "gwlb_service_name" {
  description = "PrivateLink service name used by the GWLB endpoints."
  value       = aws_vpc_endpoint_service.inspection.service_name
}

output "gwlbe_ids" {
  description = "Gateway Load Balancer endpoint IDs per AZ."
  value = {
    for az, endpoint in aws_vpc_endpoint.gwlbe : az => endpoint.id
  }
}

output "firewall_management_public_ips" {
  description = "Elastic IPs attached to the firewall management interfaces."
  value = {
    for az, eip in aws_eip.firewall_mgmt : az => eip.public_ip
  }
}

output "firewall_public_ips" {
  description = "Elastic IPs attached to the firewall public or untrust interfaces."
  value = {
    for az, eip in aws_eip.firewall_public : az => eip.public_ip
  }
}

output "vpn_tunnel_outside_ips" {
  description = "AWS public tunnel endpoints for the Site-to-Site VPN."
  value = {
    tunnel1 = try(aws_vpn_connection.s2s[0].tunnel1_address, null)
    tunnel2 = try(aws_vpn_connection.s2s[0].tunnel2_address, null)
  }
}
