data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  selected_azs = slice(
    data.aws_availability_zones.available.names,
    0,
    var.az_count
  )

  public_subnets = zipmap(
    local.selected_azs,
    var.public_subnet_cidrs
  )

  private_subnets = zipmap(
    local.selected_azs,
    var.private_subnet_cidrs
  )

  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Kubernetes-Observability"
  }
}


resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-vpc"
  })
}


resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-igw"
  })
}


resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-public-${each.key}"

    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                     = "1"
  })
}


resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-private-${each.key}"

    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  })
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-public-rt"
  })
}


resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-nat-eip"
  })
}

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id

  # Place NAT Gateway in the first public subnet
  subnet_id = aws_subnet.public[local.selected_azs[0]].id

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-nat"
  })

  depends_on = [
    aws_internet_gateway.main
  ]
}


resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-private-rt"
  })
}


resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}


resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}


output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = {
    for az, subnet in aws_subnet.public : az => subnet.id
  }
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = {
    for az, subnet in aws_subnet.private : az => subnet.id
  }
}

output "availability_zones" {
  description = "Selected Availability Zones"
  value       = local.selected_azs
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}
