# ─────────────────────────────────────────────
# Ressource : Application Load Balancer (ALB)
# ─────────────────────────────────────────────
# Crée un ALB dans les subnets publics pour gérer le trafic HTTP/HTTPS
# vers les applications déployées dans les subnets privés.

resource "aws_lb" "main" {
  # Nom du Load Balancer
  name = "${var.name_prefix}-alb"

  # Type de LB : "application" pour ALB (alternativement "network" pour NLB)
  load_balancer_type = "application"

  # Subnets où le LB sera déployé
  # Ici, tous les subnets publics
  subnets = aws_subnet.public[*].id

  # Security Group associé à l'ALB
  # Définit quelles connexions entrantes sont autorisées
  security_groups = [aws_security_group.alb.id]

  # Tags AWS
  # Utile pour identifier et gérer la ressource dans la console
  tags = {
    Name      = "${var.name_prefix}-alb"
    Environment = var.environment 
    Project     = var.name_prefix
    ManagedBy   = "terraform"
  }
}