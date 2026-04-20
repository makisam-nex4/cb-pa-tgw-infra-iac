resource "aws_vpc" "network" {
  cidr_block           = var.network_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = local.network_name
    Role = "inspection-hub"
  }
}

resource "aws_vpc" "prod" {
  cidr_block           = var.prod_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = local.prod_name
    Role = "spoke-prod"
  }
}

resource "aws_vpc" "uat" {
  cidr_block           = var.uat_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = local.uat_name
    Role = "spoke-uat"
  }
}

resource "aws_subnet" "network_public" {
  for_each = var.network_subnet_cidrs.public

  vpc_id                  = aws_vpc.network.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name = "network-public-subnet-${local.az_suffixes[each.key]}"
    Tier = "public"
  }
}

resource "aws_subnet" "network_fw_data" {
  for_each = var.network_subnet_cidrs.fw_data

  vpc_id                  = aws_vpc.network.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name = "network-fw-data-private-subnet-${local.az_suffixes[each.key]}"
    Tier = "fw-data"
  }
}

resource "aws_subnet" "network_fw_mgmt" {
  for_each = var.network_subnet_cidrs.fw_mgmt

  vpc_id                  = aws_vpc.network.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name = "network-fw-mgmt-private-subnet-${local.az_suffixes[each.key]}"
    Tier = "fw-mgmt"
  }
}

resource "aws_subnet" "network_gwlb" {
  for_each = var.network_subnet_cidrs.gwlb

  vpc_id                  = aws_vpc.network.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name = "network-gwlb-private-subnet-${local.az_suffixes[each.key]}"
    Tier = "gwlb"
  }
}

resource "aws_subnet" "network_gwlbe" {
  for_each = var.network_subnet_cidrs.gwlbe

  vpc_id                  = aws_vpc.network.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name = "network-gwlbe-private-subnet-${local.az_suffixes[each.key]}"
    Tier = "gwlbe"
  }
}

resource "aws_subnet" "network_tgw" {
  for_each = var.network_subnet_cidrs.tgw

  vpc_id                  = aws_vpc.network.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name = "network-tgw-private-subnet-${local.az_suffixes[each.key]}"
    Tier = "tgw"
  }
}

resource "aws_subnet" "network_r53" {
  for_each = var.network_subnet_cidrs.r53

  vpc_id                  = aws_vpc.network.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name = "network-r53-private-subnet-${local.az_suffixes[each.key]}"
    Tier = "r53"
  }
}

resource "aws_subnet" "network_fw_gp" {
  for_each = var.network_subnet_cidrs.fw_gp

  vpc_id                  = aws_vpc.network.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name = "network-fw-gp-private-subnet-${local.az_suffixes[each.key]}"
    Tier = "fw-gp"
  }
}

resource "aws_subnet" "prod" {
  for_each = var.prod_subnets

  vpc_id                  = aws_vpc.prod.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.route == "igw"

  tags = {
    Name = each.key
    Tier = each.value.tier
  }
}

resource "aws_subnet" "uat" {
  for_each = var.uat_subnets

  vpc_id                  = aws_vpc.uat.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.route == "igw"

  tags = {
    Name = each.key
    Tier = each.value.tier
  }
}

resource "aws_internet_gateway" "network" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = "${local.network_name}-igw"
  }
}

resource "aws_internet_gateway" "prod" {
  vpc_id = aws_vpc.prod.id

  tags = {
    Name = "${local.prod_name}-igw"
  }
}

resource "aws_internet_gateway" "uat" {
  vpc_id = aws_vpc.uat.id

  tags = {
    Name = "${local.uat_name}-igw"
  }
}

resource "aws_lb" "inspection" {
  name               = "${local.name_prefix}-gwlb"
  load_balancer_type = "gateway"
  subnets            = values(aws_subnet.network_gwlb)[*].id

  tags = {
    Name = "${local.name_prefix}-gwlb"
  }
}

resource "aws_lb_target_group" "inspection" {
  name        = "${local.name_prefix}-gwlb-tg"
  port        = 6081
  protocol    = "GENEVE"
  target_type = "instance"
  vpc_id      = aws_vpc.network.id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = var.firewall_health_check_port
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }

  tags = {
    Name = "${local.name_prefix}-gwlb-tg"
  }
}

resource "aws_lb_listener" "inspection" {
  load_balancer_arn = aws_lb.inspection.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.inspection.arn
  }
}

resource "aws_vpc_endpoint_service" "inspection" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.inspection.arn]

  tags = {
    Name = "${local.name_prefix}-gwlb-service"
  }
}

resource "aws_vpc_endpoint" "gwlbe" {
  for_each = aws_subnet.network_gwlbe

  vpc_id            = aws_vpc.network.id
  service_name      = aws_vpc_endpoint_service.inspection.service_name
  vpc_endpoint_type = "GatewayLoadBalancer"
  subnet_ids        = [each.value.id]

  tags = {
    Name = "network-gwlbe-private-subnet-${local.az_suffixes[each.key]}"
  }
}
