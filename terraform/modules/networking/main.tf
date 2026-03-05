# ─────────────────────────────────────────────
# VPC — le réseau privé principal
# ─────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # Requis pour EKS

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# ─────────────────────────────────────────────
# Internet Gateway — la porte vers Internet
# pour les ressources PUBLIQUES uniquement
# ─────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# ─────────────────────────────────────────────
# Subnets PUBLICS (1 par AZ)
# Contiennent : ALB, NAT Gateway
# ─────────────────────────────────────────────
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone = var.availability_zones[count.index]

  # Les ressources publiques reçoivent une IP publique automatiquement
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.name_prefix}-public-${count.index + 1}"
    "kubernetes.io/role/elb" = "1" # Requis pour l'ALB controller EKS
  }
}

# ─────────────────────────────────────────────
# Subnets PRIVÉS (1 par AZ)
# Contiennent : nœuds EKS, RDS
# Jamais d'IP publique
# ─────────────────────────────────────────────
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 11)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                              = "${var.name_prefix}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# ─────────────────────────────────────────────
# Elastic IPs pour les NAT Gateways
# Une IP fixe publique par NAT
# ─────────────────────────────────────────────
resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# ─────────────────────────────────────────────
# NAT Gateways — porte de sortie pour les
# ressources PRIVÉES (sans IP publique)
# Placés dans les subnets PUBLICS
# ─────────────────────────────────────────────
resource "aws_nat_gateway" "main" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.name_prefix}-nat-${count.index + 1}"
  }
}

# ─────────────────────────────────────────────
# Route Table PUBLIQUE
# Règle : tout ce qui n'est pas local → Internet Gateway
# ─────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ─────────────────────────────────────────────
# Route Tables PRIVÉES (une par AZ)
# Règle : tout ce qui n'est pas local → NAT Gateway
# ─────────────────────────────────────────────
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.name_prefix}-rt-private-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}