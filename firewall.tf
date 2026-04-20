resource "aws_security_group" "firewall_mgmt" {
  name        = "${local.name_prefix}-fw-mgmt-sg"
  description = "Open policy for testing on all firewall interfaces."
  vpc_id      = aws_vpc.network.id

  ingress {
    description = "Allow all inbound traffic for testing"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic for testing"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-fw-mgmt-sg"
  }
}

resource "aws_network_interface" "firewall_mgmt" {
  for_each = aws_subnet.network_fw_mgmt

  subnet_id       = each.value.id
  security_groups = [aws_security_group.firewall_mgmt.id]

  tags = {
    Name = "${local.name_prefix}-fw-mgmt-${each.key}"
  }
}

resource "aws_network_interface" "firewall_data" {
  for_each = aws_subnet.network_fw_data

  subnet_id         = each.value.id
  security_groups   = [aws_security_group.firewall_mgmt.id]
  source_dest_check = false

  tags = {
    Name = "${local.name_prefix}-fw-data-${each.key}"
  }
}

resource "aws_network_interface" "firewall_public" {
  for_each = aws_subnet.network_public

  subnet_id         = each.value.id
  security_groups   = [aws_security_group.firewall_mgmt.id]
  source_dest_check = false

  tags = {
    Name = "network-public-subnet-${local.az_suffixes[each.key]}-eni"
  }
}

resource "aws_network_interface" "firewall_gp" {
  for_each = aws_subnet.network_fw_gp

  subnet_id         = each.value.id
  security_groups   = [aws_security_group.firewall_mgmt.id]
  source_dest_check = false

  tags = {
    Name = "${local.name_prefix}-fw-gp-${each.key}"
  }
}

resource "aws_eip" "firewall_mgmt" {
  for_each = aws_network_interface.firewall_mgmt

  # Attach a public IP to each management interface.
  domain            = "vpc"
  network_interface = each.value.id

  tags = {
    Name = "${local.name_prefix}-fw-mgmt-eip-${each.key}"
  }
}

resource "aws_eip" "firewall_public" {
  for_each = aws_network_interface.firewall_public

  domain            = "vpc"
  network_interface = each.value.id

  tags = {
    Name = "${local.name_prefix}-fw-public-eip-${each.key}"
  }
}

resource "aws_instance" "firewall" {
  for_each = aws_network_interface.firewall_mgmt

  ami                  = var.firewall_ami_id
  instance_type        = var.firewall_instance_type
  key_name             = var.firewall_key_name
  iam_instance_profile = var.firewall_instance_profile_name
  user_data            = var.firewall_user_data
  monitoring           = true

  # PAN-OS interface order:
  # device_index 0 = management
  # device_index 1 = data interface connected to GWLB
  # device_index 2 = public or untrust interface
  # device_index 3 = internal GP or trust interface
  network_interface {
    device_index         = 0
    network_interface_id = each.value.id
  }

  network_interface {
    device_index         = 1
    network_interface_id = aws_network_interface.firewall_data[each.key].id
  }

  network_interface {
    device_index         = 2
    network_interface_id = aws_network_interface.firewall_public[each.key].id
  }

  network_interface {
    device_index         = 3
    network_interface_id = aws_network_interface.firewall_gp[each.key].id
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 60
  }

  tags = {
    Name = "${local.name_prefix}-fw-${each.key}"
    Role = "inspection-firewall"
  }
}

resource "aws_lb_target_group_attachment" "firewall" {
  for_each = aws_instance.firewall

  target_group_arn = aws_lb_target_group.inspection.arn
  target_id        = each.value.id
}
