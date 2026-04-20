# AWS Transit Gateway Inspection Hub

This Terraform project builds the AWS infrastructure shown in the diagram as a hub-and-spoke design in `ap-southeast-1`:

- `Prod VPC` (`10.210.0.0/16`)
- `UAT VPC` (`10.211.0.0/16`)
- `Network VPC` (`10.212.0.0/23`) for centralized inspection
- Transit Gateway with separated route tables for spoke, inspection, and VPN flows
- optional Site-to-Site VPN attachment to on-premises
- Gateway Load Balancer plus GWLB endpoints
- Two Palo Alto VM-Series instances with four interfaces each: `eth0` management, `eth1` GWLB data, `eth2` public or untrust, and `eth3` internal NAT or trust
- Firewall management interfaces get Elastic IPs and use a default route to the Internet Gateway for administration

## Important assumptions

The diagram implies a few AWS-specific components that are required for a real deployment but are not explicitly drawn:

- Dedicated `GWLB` subnets are added because the Gateway Load Balancer itself needs subnets.
- Dedicated `fw_mgmt`, `public`, and `fw_gp` subnets are added so the firewall can keep management, internet-facing, and internal trust/GP traffic separated.
- A third TGW subnet is kept in `ap-southeast-1c`, and it is routed to the `ap-southeast-1b` GWLB endpoint to match the diagram's ZA/ZB inspection pair.
- The Prod TGW attachment uses `pa-prod-app-private-subnet-za`, `pa-prod-app-private-subnet-zb`, and `pa-prod-app-private-subnet-zc`.
- The shared UAT VPC TGW attachment uses `pa-dev-app-private-subnet-za`, `pa-dev-app-private-subnet-zb`, and `pa-dev-app-private-subnet-zc`.

## Files

- `variables.tf`: all input variables
- `network.tf`: VPCs, subnets, internet gateways, GWLB, and GWLB endpoints
- `rtb.tf`: VPC route tables, routes, and subnet associations
- `transit-gateway.tf`: TGW, VPC attachments, VPN, and TGW route tables
- `firewall.tf`: security groups, ENIs, EIPs, firewall EC2 instances, and GWLB target registration
- `outputs.tf`: useful deployment outputs

## Before apply

Update `terraform.tfvars.example` into your own `terraform.tfvars` and set these values:

- `aws_profile`
- `enable_on_prem_vpn`
- `firewall_ami_id`
- `admin_ingress_cidrs`
- optional `network_subnet_cidrs` when you need a custom network layout; if set, `public`, `fw_mgmt`, `fw_data`, and `fw_gp` must use the same two AZ names.
- optional `prod_subnets` and `uat_subnets` when you need to override the exact spoke subnet inventory
- `vpn_customer_gateway_ip` and `on_prem_cidrs` only when `enable_on_prem_vpn = true`
- optional `firewall_instance_profile_name` and `firewall_user_data` for PAN-OS bootstrap

## Firewall user data

The firewall EC2 resources already pass `var.firewall_user_data` into the instances. Add it in `terraform.tfvars` with a heredoc, for example:

```hcl
firewall_user_data = <<-EOT
vmseries-bootstrap-aws-s3bucket=my-pa-bootstrap-bucket
vmseries-bootstrap-aws-region=ap-southeast-1
EOT
```

If you do not want bootstrap user data, leave `firewall_user_data = null`.

## Firewall count

This configuration is now validated to build exactly **2** Palo Alto firewalls. Terraform enforces that:

- `public` has exactly 2 subnets
- `fw_mgmt` has exactly 2 subnets
- `fw_data` has exactly 2 subnets
- `fw_gp` has exactly 2 subnets
- all four subnet groups use the same two availability zones

## Deploy

```bash
terraform init
terraform plan
terraform apply
```
