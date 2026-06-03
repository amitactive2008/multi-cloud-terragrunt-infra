locals {
  common_tags = merge(
    { Name = var.name, ManagedBy = "terraform" },
    var.tags
  )
}

# ─── VPC ────────────────────────────────────────────────────────────────────
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = var.name })
}

# ─── Internet Gateway ───────────────────────────────────────────────────────
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.name}-igw" })
}

# ─── Public Subnets ─────────────────────────────────────────────────────────
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true
  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-public-${var.azs[count.index]}"
      Tier = "public"
    },
    var.eks_cluster_name != "" ? {
      "kubernetes.io/role/elb"                               = "1"
      "kubernetes.io/cluster/${var.eks_cluster_name}"        = "shared"
    } : {}
  )
}

# ─── Private Subnets ────────────────────────────────────────────────────────
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-private-${var.azs[count.index]}"
      Tier = "private"
    },
    var.eks_cluster_name != "" ? {
      "kubernetes.io/role/internal-elb"                      = "1"
      "kubernetes.io/cluster/${var.eks_cluster_name}"        = "shared"
    } : {}
  )
}

# ─── DB Subnets ─────────────────────────────────────────────────────────────
resource "aws_subnet" "db" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.db_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = merge(local.common_tags, {
    Name = "${var.name}-db-${var.azs[count.index]}"
    Tier = "db"
  })
}

# ─── ES Subnets ─────────────────────────────────────────────────────────────
resource "aws_subnet" "es" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.es_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = merge(local.common_tags, {
    Name = "${var.name}-es-${var.azs[count.index]}"
    Tier = "es"
  })
}

# ─── NAT Gateway (single, in first public subnet) ───────────────────────────
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "${var.name}-nat-eip" })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = merge(local.common_tags, { Name = "${var.name}-nat-gw" })
  depends_on    = [aws_internet_gateway.this]
}

# ─── Route Tables ───────────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Single private route table (shared by private, db, es subnets) via NAT GW
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.name}-private-rt" })
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db" {
  count          = 2
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "es" {
  count          = 2
  subnet_id      = aws_subnet.es[count.index].id
  route_table_id = aws_route_table.private.id
}

# ─── DB Subnet Group ────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id
  tags       = merge(local.common_tags, { Name = "${var.name}-db-subnet-group" })
}
