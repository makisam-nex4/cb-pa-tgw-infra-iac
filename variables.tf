variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_profile" {
  description = "AWS CLI profile used by the AWS provider."
  type        = string
  default     = "cb-pa"
}

variable "project_name" {
  description = "Prefix used for shared resource names."
  type        = string
  default     = "CB"
}

variable "common_tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "network_vpc_cidr" {
  description = "CIDR block for the shared inspection/network VPC."
  type        = string
  default     = "10.212.0.0/23"
}

variable "enable_on_prem_vpn" {
  description = "When false, skip the AWS Site-to-Site VPN resources and all on-prem route propagation."
  type        = bool
  default     = false
}

variable "prod_vpc_cidr" {
  description = "CIDR block for the Prod VPC."
  type        = string
  default     = "10.210.0.0/16"
}

variable "uat_vpc_cidr" {
  description = "CIDR block for the UAT VPC."
  type        = string
  default     = "10.211.0.0/16"
}

variable "network_subnet_cidrs" {
  description = "Subnet layout for the network VPC."
  type = object({
    public  = map(string)
    fw_data = map(string)
    fw_mgmt = map(string)
    gwlb    = map(string)
    gwlbe   = map(string)
    tgw     = map(string)
    r53     = map(string)
    fw_gp   = map(string)
  })

  default = {
    public = {
      ap-southeast-1a = "10.212.0.0/28"
      ap-southeast-1b = "10.212.0.16/28"
    }
    fw_data = {
      ap-southeast-1a = "10.212.0.32/28"
      ap-southeast-1b = "10.212.0.48/28"
    }
    fw_mgmt = {
      ap-southeast-1a = "10.212.0.64/28"
      ap-southeast-1b = "10.212.0.80/28"
    }
    gwlb = {
      ap-southeast-1a = "10.212.0.96/28"
      ap-southeast-1b = "10.212.0.112/28"
    }
    gwlbe = {
      ap-southeast-1a = "10.212.0.128/28"
      ap-southeast-1b = "10.212.0.144/28"
    }
    tgw = {
      ap-southeast-1a = "10.212.0.176/28"
      ap-southeast-1b = "10.212.0.192/28"
      ap-southeast-1c = "10.212.0.208/28"
    }
    r53 = {
      ap-southeast-1a = "10.212.0.224/28"
      ap-southeast-1b = "10.212.0.240/28"
    }
    fw_gp = {
      ap-southeast-1a = "10.212.1.0/28"
      ap-southeast-1b = "10.212.1.16/28"
    }
  }

  validation {
    condition = (
      length(var.network_subnet_cidrs.public) == 2 &&
      length(var.network_subnet_cidrs.fw_mgmt) == 2 &&
      length(var.network_subnet_cidrs.fw_data) == 2 &&
      length(var.network_subnet_cidrs.fw_gp) == 2 &&
      length(var.network_subnet_cidrs.gwlb) == 2 &&
      length(var.network_subnet_cidrs.gwlbe) == 2 &&
      length(var.network_subnet_cidrs.tgw) == 3 &&
      length(var.network_subnet_cidrs.r53) == 2
    )
    error_message = "The network VPC layout requires 2 public, fw_mgmt, fw_data, gwlb, gwlbe, r53, and fw_gp subnets plus 3 TGW subnets."
  }

  validation {
    condition = (
      length(setsubtract(keys(var.network_subnet_cidrs.public), keys(var.network_subnet_cidrs.fw_mgmt))) == 0 &&
      length(setsubtract(keys(var.network_subnet_cidrs.public), keys(var.network_subnet_cidrs.fw_data))) == 0 &&
      length(setsubtract(keys(var.network_subnet_cidrs.public), keys(var.network_subnet_cidrs.fw_gp))) == 0 &&
      length(setsubtract(keys(var.network_subnet_cidrs.fw_mgmt), keys(var.network_subnet_cidrs.public))) == 0 &&
      length(setsubtract(keys(var.network_subnet_cidrs.fw_data), keys(var.network_subnet_cidrs.public))) == 0 &&
      length(setsubtract(keys(var.network_subnet_cidrs.fw_gp), keys(var.network_subnet_cidrs.public))) == 0
    )
    error_message = "public, fw_mgmt, fw_data, and fw_gp must use the same two availability zones so both Palo Alto firewalls can be built consistently."
  }

  validation {
    condition = alltrue([
      for cidr in values(var.network_subnet_cidrs.fw_gp) :
      tonumber(split("/", cidr)[1]) <= 28
    ])
    error_message = "AWS IPv4 subnets must be /28 or larger. Update fw_gp subnet CIDRs to use /28 or a larger range."
  }
}

variable "prod_subnets" {
  description = "Exact subnet layout for the Prod VPC. Map keys become the Name tags."
  type = map(object({
    cidr           = string
    az             = string
    route          = string
    tier           = string
    tgw_attachment = bool
  }))

  default = {
    "prod-public-subnet-za" = {
      cidr           = "10.210.0.0/28"
      az             = "ap-southeast-1a"
      route          = "igw"
      tier           = "public"
      tgw_attachment = false
    }
    "prod-public-subnet-zb" = {
      cidr           = "10.210.0.16/28"
      az             = "ap-southeast-1b"
      route          = "igw"
      tier           = "public"
      tgw_attachment = false
    }
    "pa-prod-app-private-subnet-za" = {
      cidr           = "10.210.0.32/28"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = true
    }
    "pa-prod-app-private-subnet-zb" = {
      cidr           = "10.210.0.48/28"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = true
    }
    "pa-prod-app-private-subnet-zc" = {
      cidr           = "10.210.0.64/28"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = true
    }
    "pa-prod-db-private-subnet-za" = {
      cidr           = "10.210.0.80/28"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pa-prod-db-private-subnet-zb" = {
      cidr           = "10.210.0.96/28"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pa-prod-db-private-subnet-zc" = {
      cidr           = "10.210.0.112/28"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pa-prod-app-cluster-private-subnet-za" = {
      cidr           = "10.210.1.0/24"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pa-prod-app-cluster-private-subnet-zb" = {
      cidr           = "10.210.2.0/24"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pa-prod-app-cluster-private-subnet-zc" = {
      cidr           = "10.210.3.0/24"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pb-prod-app-private-subnet-za" = {
      cidr           = "10.210.4.0/28"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pb-prod-app-private-subnet-zb" = {
      cidr           = "10.210.4.16/28"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pb-prod-app-private-subnet-zc" = {
      cidr           = "10.210.4.32/28"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pb-prod-db-private-subnet-za" = {
      cidr           = "10.210.4.48/28"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pb-prod-db-private-subnet-zb" = {
      cidr           = "10.210.4.64/28"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pb-prod-db-private-subnet-zc" = {
      cidr           = "10.210.4.80/28"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pb-prod-app-cluster-private-subnet-za" = {
      cidr           = "10.210.5.0/24"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pb-prod-app-cluster-private-subnet-zb" = {
      cidr           = "10.210.6.0/24"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pb-prod-app-cluster-private-subnet-zc" = {
      cidr           = "10.210.7.0/24"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
  }

  validation {
    condition = alltrue([
      for subnet in values(var.prod_subnets) :
      contains(["igw", "tgw"], subnet.route)
    ])
    error_message = "Each prod subnet route must be either igw or tgw."
  }
}

variable "uat_subnets" {
  description = "Exact subnet layout for the shared UAT VPC. Map keys become the Name tags."
  type = map(object({
    cidr           = string
    az             = string
    route          = string
    tier           = string
    tgw_attachment = bool
  }))

  default = {
    "dev-public-subnet-za" = {
      cidr           = "10.211.0.0/28"
      az             = "ap-southeast-1a"
      route          = "igw"
      tier           = "public"
      tgw_attachment = false
    }
    "dev-public-subnet-zb" = {
      cidr           = "10.211.0.16/28"
      az             = "ap-southeast-1b"
      route          = "igw"
      tier           = "public"
      tgw_attachment = false
    }
    "pa-dev-app-private-subnet-za" = {
      cidr           = "10.211.0.32/28"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = true
    }
    "pa-dev-app-private-subnet-zb" = {
      cidr           = "10.211.0.48/28"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = true
    }
    "pa-dev-app-private-subnet-zc" = {
      cidr           = "10.211.0.64/28"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = true
    }
    "pa-dev-db-private-subnet-za" = {
      cidr           = "10.211.0.80/28"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pa-dev-db-private-subnet-zb" = {
      cidr           = "10.211.0.96/28"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pa-dev-db-private-subnet-zc" = {
      cidr           = "10.211.0.112/28"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pa-dev-app-cluster-private-subnet-za" = {
      cidr           = "10.211.1.0/24"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pa-dev-app-cluster-private-subnet-zb" = {
      cidr           = "10.211.2.0/24"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pa-dev-app-cluster-private-subnet-zc" = {
      cidr           = "10.211.3.0/24"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pb-dev-app-private-subnet-za" = {
      cidr           = "10.211.4.0/28"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pb-dev-app-private-subnet-zb" = {
      cidr           = "10.211.4.16/28"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pb-dev-app-private-subnet-zc" = {
      cidr           = "10.211.4.32/28"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pb-dev-db-private-subnet-za" = {
      cidr           = "10.211.4.48/28"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pb-dev-db-private-subnet-zb" = {
      cidr           = "10.211.4.64/28"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pb-dev-db-private-subnet-zc" = {
      cidr           = "10.211.4.80/28"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pb-dev-app-cluster-private-subnet-za" = {
      cidr           = "10.211.5.0/24"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pb-dev-app-cluster-private-subnet-zb" = {
      cidr           = "10.211.6.0/24"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pb-dev-app-cluster-private-subnet-zc" = {
      cidr           = "10.211.7.0/24"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "uat-public-subnet-za" = {
      cidr           = "10.211.16.0/28"
      az             = "ap-southeast-1a"
      route          = "igw"
      tier           = "public"
      tgw_attachment = false
    }
    "uat-public-subnet-zb" = {
      cidr           = "10.211.16.16/28"
      az             = "ap-southeast-1b"
      route          = "igw"
      tier           = "public"
      tgw_attachment = false
    }
    "pa-uat-app-private-subnet-za" = {
      cidr           = "10.211.16.32/28"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pa-uat-app-private-subnet-zb" = {
      cidr           = "10.211.16.48/28"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pa-uat-app-private-subnet-zc" = {
      cidr           = "10.211.16.64/28"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pa-uat-db-private-subnet-za" = {
      cidr           = "10.211.16.80/28"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pa-uat-db-private-subnet-zb" = {
      cidr           = "10.211.16.96/28"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pa-uat-db-private-subnet-zc" = {
      cidr           = "10.211.16.112/28"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pa-uat-app-cluster-private-subnet-za" = {
      cidr           = "10.211.17.0/24"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pa-uat-app-cluster-private-subnet-zb" = {
      cidr           = "10.211.18.0/24"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pa-uat-app-cluster-private-subnet-zc" = {
      cidr           = "10.211.19.0/24"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pb-uat-app-private-subnet-za" = {
      cidr           = "10.211.20.0/28"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pb-uat-app-private-subnet-zb" = {
      cidr           = "10.211.20.16/28"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pb-uat-app-private-subnet-zc" = {
      cidr           = "10.211.20.32/28"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pb-uat-db-private-subnet-za" = {
      cidr           = "10.211.20.48/28"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pb-uat-db-private-subnet-zb" = {
      cidr           = "10.211.20.64/28"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pb-uat-db-private-subnet-zc" = {
      cidr           = "10.211.20.80/28"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pb-uat-app-cluster-private-subnet-za" = {
      cidr           = "10.211.21.0/24"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pb-uat-app-cluster-private-subnet-zb" = {
      cidr           = "10.211.22.0/24"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pb-uat-app-cluster-private-subnet-zc" = {
      cidr           = "10.211.23.0/24"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "preprod-public-subnet-za" = {
      cidr           = "10.211.24.0/28"
      az             = "ap-southeast-1a"
      route          = "igw"
      tier           = "public"
      tgw_attachment = false
    }
    "preprod-public-subnet-zb" = {
      cidr           = "10.211.24.16/28"
      az             = "ap-southeast-1b"
      route          = "igw"
      tier           = "public"
      tgw_attachment = false
    }
    "pa-preprod-app-private-subnet-za" = {
      cidr           = "10.211.24.32/28"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pa-preprod-app-private-subnet-zb" = {
      cidr           = "10.211.24.48/28"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pa-preprod-app-private-subnet-zc" = {
      cidr           = "10.211.24.64/28"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pa-preprod-db-private-subnet-za" = {
      cidr           = "10.211.24.80/28"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pa-preprod-db-private-subnet-zb" = {
      cidr           = "10.211.24.96/28"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pa-preprod-db-private-subnet-zc" = {
      cidr           = "10.211.24.112/28"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pa-preprod-app-cluster-private-subnet-za" = {
      cidr           = "10.211.25.0/24"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pa-preprod-app-cluster-private-subnet-zb" = {
      cidr           = "10.211.26.0/24"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pa-preprod-app-cluster-private-subnet-zc" = {
      cidr           = "10.211.27.0/24"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pb-preprod-app-private-subnet-za" = {
      cidr           = "10.211.28.0/28"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pb-preprod-app-private-subnet-zb" = {
      cidr           = "10.211.28.16/28"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pb-preprod-app-private-subnet-zc" = {
      cidr           = "10.211.28.32/28"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "app-private"
      tgw_attachment = false
    }
    "pb-preprod-db-private-subnet-za" = {
      cidr           = "10.211.28.48/28"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pb-preprod-db-private-subnet-zb" = {
      cidr           = "10.211.28.64/28"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pb-preprod-db-private-subnet-zc" = {
      cidr           = "10.211.28.80/28"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "db-private"
      tgw_attachment = false
    }
    "pb-preprod-app-cluster-private-subnet-za" = {
      cidr           = "10.211.29.0/24"
      az             = "ap-southeast-1a"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pb-preprod-app-cluster-private-subnet-zb" = {
      cidr           = "10.211.30.0/24"
      az             = "ap-southeast-1b"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
    "pb-preprod-app-cluster-private-subnet-zc" = {
      cidr           = "10.211.31.0/24"
      az             = "ap-southeast-1c"
      route          = "tgw"
      tier           = "app-cluster-private"
      tgw_attachment = false
    }
  }

  validation {
    condition = alltrue([
      for subnet in values(var.uat_subnets) :
      contains(["igw", "tgw"], subnet.route)
    ])
    error_message = "Each UAT subnet route must be either igw or tgw."
  }
}

variable "tgw_subnet_to_gwlbe_az_map" {
  description = "Maps each TGW subnet AZ to the GWLB endpoint AZ used for the default route."
  type        = map(string)
  default = {
    ap-southeast-1c = "ap-southeast-1b"
  }

  validation {
    condition = alltrue([
      for az, gwlbe_az in var.tgw_subnet_to_gwlbe_az_map :
      contains(keys(var.network_subnet_cidrs.tgw), az) && contains(keys(var.network_subnet_cidrs.gwlbe), gwlbe_az)
    ])
    error_message = "Each tgw_subnet_to_gwlbe_az_map entry must map an existing TGW subnet AZ to an existing GWLBE subnet AZ."
  }
}

variable "on_prem_cidrs" {
  description = "On-premises CIDR blocks reachable through the Site-to-Site VPN."
  type        = list(string)
  default     = []
}

variable "vpn_customer_gateway_ip" {
  description = "Public IP address of the on-premises customer gateway."
  type        = string
  default     = null
  nullable    = true
}

variable "vpn_customer_gateway_bgp_asn" {
  description = "BGP ASN for the on-premises customer gateway."
  type        = number
  default     = 65000
}

variable "vpn_static_routes_only" {
  description = "Set to true when the on-premises VPN uses static routes instead of BGP."
  type        = bool
  default     = false
}

variable "transit_gateway_amazon_side_asn" {
  description = "AWS-side ASN for the Transit Gateway."
  type        = number
  default     = 64512
}

variable "firewall_ami_id" {
  description = "AMI ID for the Palo Alto VM-Series firewall instances."
  type        = string
  default     = "ami-0df99db587acd24dd"
}

variable "firewall_instance_type" {
  description = "Instance type for the Palo Alto firewall instances."
  type        = string
  default     = "m5.xlarge"
}

variable "firewall_key_name" {
  description = "Optional EC2 key pair name for the firewall instances."
  type        = string
  default     = null
  nullable    = true
}

variable "firewall_instance_profile_name" {
  description = "Optional IAM instance profile name for bootstrap or licensing."
  type        = string
  default     = null
  nullable    = true
}

variable "firewall_user_data" {
  description = "Optional user data for firewall bootstrap configuration."
  type        = string
  default     = null
  nullable    = true
}

variable "firewall_health_check_port" {
  description = "Health-check port used by the GWLB target group."
  type        = number
  default     = 80
}

variable "admin_ingress_cidrs" {
  description = "CIDR ranges allowed to manage the firewall management interfaces."
  type        = list(string)
  default     = []
}
