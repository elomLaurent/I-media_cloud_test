# ─────────────────────────────────────────────
# Output : ID du VPC principal
# ─────────────────────────────────────────────
# Permet de récupérer l'identifiant unique du VPC créé.
# Utile pour référencer le VPC dans d'autres modules ou ressources.
output "vpc_id" {
  description = "ID du VPC principal"
  value       = aws_vpc.main.id
}

# ─────────────────────────────────────────────
# Output : Liste des subnets publics
# ─────────────────────────────────────────────
# Retourne un tableau contenant les IDs de tous les subnets publics.
# Ces subnets hébergent des ressources accessibles depuis Internet
# comme les Load Balancers ou NAT Gateways.
output "public_subnets" {
  description = "Liste des subnets publics"
  value       = aws_subnet.public[*].id
}

# ─────────────────────────────────────────────
# Output : Liste des subnets privés
# ─────────────────────────────────────────────
# Retourne un tableau contenant les IDs de tous les subnets privés.
# Ces subnets hébergent des ressources internes (applications, bases de données)
# non accessibles directement depuis Internet.
output "private_subnets" {
  description = "Liste des subnets privés"
  value       = aws_subnet.private[*].id
}

# ─────────────────────────────────────────────
# Output : Security Group du Load Balancer
# ─────────────────────────────────────────────
# Retourne l'ID du Security Group associé à l'ALB.
# Définit quelles connexions entrantes sont autorisées (HTTP/HTTPS).
# Peut être utilisé dans d'autres modules pour créer des règles de sécurité.
output "alb_sg_id" {
  description = "ID du Security Group du Load Balancer"
  value       = aws_security_group.alb.id
}

# ─────────────────────────────────────────────
# Output : Security Group des applications
# ─────────────────────────────────────────────
# Retourne l'ID du Security Group des serveurs applicatifs.
# Les règles de ce SG permettent uniquement le trafic provenant
# du Load Balancer pour sécuriser les applications.
output "app_sg_id" {
  description = "ID du Security Group des applications"
  value       = aws_security_group.app.id
}

# ─────────────────────────────────────────────
# Output : DNS Name de l'ALB
# ─────────────────────────────────────────────
# Fournit le nom DNS public de l'Application Load Balancer.
# Permet d'accéder aux applications depuis Internet
# ou de configurer des enregistrements DNS (Route53 par ex.).
output "alb_dns_name" {
  description = "DNS Name de l'ALB"
  value       = aws_lb.main.dns_name
}