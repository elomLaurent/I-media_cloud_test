# Infrastructure avec Terraform (AWS)

## 1. Vue d’ensemble

Ce projet Terraform permet de **créer une infrastructure réseau de base sur AWS**.

L’objectif est de construire **une fondation réseau sécurisée et évolutive** qui pourra accueillir plus tard plusieurs services comme :

* Kubernetes (EKS)
* Bases de données (RDS)
* Services backend
* Load balancers

L’infrastructure suit les **bonnes pratiques du cloud** :

* VPC isolé
* Sous-réseaux publics et privés
* NAT Gateway pour l’accès internet sécurisé
* Déploiement sur plusieurs zones de disponibilité (High Availability)


# 2. Structure du projet

```
├── README.md
├── .gitignore
├── terraform/
│   ├── main.tf                   # Entrée, orchestration des modules
│   ├── variables.tf              # Variables globales typées et validées
│   ├── outputs.tf
│   └── modules/
│       ├── networking/          # VPC, subnets, NAT, ALB, Security Groups
```

### Pourquoi cette structure ?

La base du projet est divisé en **modules** pour evité la confusion dans un code très long ecrie dans un  seul fichier, 

Chaque module gère **une partie spécifique de l’infrastructure**.

Module actuel :

```
modules/networking
```

Dans le futur, on pourrait ajouter :

```
modules/compute
modules/database
modules/security
```

Cette approche améliore :

* la lisibilité du code
* la maintenance
* l’évolution de l’infrastructure


# 3. Configuration du provider AWS

Dans `versions.tf` :

```hcl
provider "aws" {
  region = var.aws_region
}
```

### Ce que ça fait

Terraform télécharge le **plugin officiel AWS** :

```
hashicorp/aws
```

Ce plugin permet à Terraform de communiquer avec **l’API AWS** pour créer des ressources comme :

* VPC
* Subnets
* Internet Gateway
* NAT Gateway

Sans ce provider, Terraform ne pourrait **pas créer de ressources sur AWS**.


# 4. Variables

Les variables sont définies dans `variables.tf`.

Exemple :

```hcl
variable "environment" {
  type    = string
  default = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging or prod."
  }
}
```

### Pourquoi utiliser des variables ?

Cela permet d’utiliser **le même code pour plusieurs environnements** :

* développement
* staging
* production

La validation empêche les erreurs de configuration.


# 5. Infrastructure réseau

Le module `networking` crée plusieurs composants :

* VPC
* Internet Gateway
* Subnets publics
* Subnets privés
* NAT Gateway
* Tables de routage


# 6. VPC (Virtual Private Cloud)

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```

Le **VPC est le réseau principal** où toutes les ressources seront déployées.

Il fournit :

* isolation réseau
* adresses IP privées
* contrôle du routage


# 7. Internet Gateway

```hcl
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}
```

L’Internet Gateway permet aux ressources du VPC **d’accéder à Internet**.

Sans ce composant :

❌ aucune communication avec Internet.


# 8. Subnets

Le projet crée **4 subnets** répartis sur **2 zones de disponibilité**.

### Subnets publics

```
AZ-A → 10.0.1.0/24
AZ-B → 10.0.2.0/24
```

Ils hébergent :

* Load balancers
* NAT Gateway

---

### Subnets privés

```
AZ-A → 10.0.11.0/24
AZ-B → 10.0.12.0/24
```

Ils hébergent :

* serveurs applicatifs
* bases de données

Ces ressources **ne sont pas accessibles directement depuis Internet**, ce qui améliore la sécurité.

---

# 9. Architecture multi-zone

Les subnets sont répartis sur **2 Availability Zones** :

```
eu-west-1a
eu-west-1b
```

Cela permet d’avoir :

✔ haute disponibilité
✔ tolérance aux pannes

Si une zone tombe, l’autre continue à fonctionner.


# 10. NAT Gateway

Les serveurs privés **ne peuvent pas accéder directement à Internet**.

On utilise donc un **NAT Gateway**.

Exemple :

```hcl
resource "aws_eip" "nat" {
  count = 2
}

resource "aws_nat_gateway" "main" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
}
```

### Fonctionnement

```
Serveur privé → NAT Gateway → Internet
Internet → NAT Gateway → Serveur privé
Internet → Serveur privé direct ❌
```

Cela permet aux serveurs privés de :

* télécharger des mises à jour
* récupérer des images Docker
* appeler des APIs externes

tout en restant **invisibles depuis Internet**.


# 11. Route Tables

Les **tables de routage** définissent comment le trafic circule.

### Route publique

```
0.0.0.0/0 → Internet Gateway
```

Tout le trafic Internet passe par l’Internet Gateway.


### Route privée

```
0.0.0.0/0 → NAT Gateway
```

Les serveurs privés passent par le NAT pour accéder à Internet.



# 12. Security Groups

Le module `networking` définit des **Security Groups** pour contrôler le trafic réseau :

### SG pour le Load Balancer

```hcl
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Allow HTTP/HTTPS traffic"
  vpc_id      = aws_vpc.main.id

  # Autoriser le trafic HTTP public
  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Autoriser le trafic HTTPS public
  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Trafic sortant autorisé vers Internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    { Name = "${var.name_prefix}-alb-sg" }
  )
}
```

**Explication** :

* Le SG **ALB** autorise le trafic HTTP/HTTPS depuis Internet.
* L’**egress** permet au Load Balancer de répondre aux clients.
* Tous les tags sont appliqués pour l’organisation et la traçabilité.


### SG pour les applications

```hcl
resource "aws_security_group" "app" {
  name   = "${var.name_prefix}-app-sg"
  vpc_id = aws_vpc.main.id

  # Autoriser uniquement le trafic depuis l'ALB
  ingress {
    description     = "Traffic from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Trafic sortant vers Internet pour les updates
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    { Name = "${var.name_prefix}-app-sg" }
  )
}
```

**Explication** :

* Le SG **App** ne permet que le trafic depuis l’ALB (pas depuis Internet directement).
* Le egress autorise les connexions sortantes (updates, API externes).

---

# 13. Load Balancer (ALB)

```hcl
resource "aws_lb" "app" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]

  tags = merge(
    var.common_tags,
    { Name = "${var.name_prefix}-alb" }
  )
}
```

**Explication** :

* ALB placé dans les **subnets publics**.
* Associé au **SG ALB** pour autoriser HTTP/HTTPS.
* Peut router le trafic vers les **instances backend** dans les subnets privés.


# 14. Outputs Terraform

Dans `modules/networking/outputs.tf` :

```hcl
output "vpc_id" {
  description = "ID du VPC principal"
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "Liste des subnets publics"
  value       = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "Liste des subnets privés"
  value       = aws_subnet.private[*].id
}

output "alb_sg_id" {
  description = "ID du Security Group du Load Balancer"
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "ID du Security Group des applications"
  value       = aws_security_group.app.id
}

output "alb_dns_name" {
  description = "DNS Name de l'ALB"
  value       = aws_lb.app.dns_name
}
```

**Explication** :

* Ces outputs permettent de **récupérer facilement les IDs et DNS** pour les modules compute, database ou pour des scripts CI/CD.
* Bien documentés pour la clarté.


# 15. Tags sur toutes les ressources

Toutes les ressources dans le module `networking` utilisent :

```hcl
tags = merge(var.common_tags, { Name = "<nom-ressource>" })
```

**Tags standards** :

* `Environment` : dev / staging / prod
* `Project` : userapi
* `ManagedBy` : terraform

Cela facilite la **gestion et l’audit des ressources**.


Si tu veux, je peux te créer maintenant **la version finale complète de ton module `networking`** avec :

* VPC
* Subnets publics et privés
* NAT Gateways
* Route Tables
* Security Groups (ALB & App)
* ALB
* Tags sur toutes les ressources
* Outputs documentés

Cette version serait **prête à être utilisée et déployée**.

Veux‑tu que je fasse ça ?


# 16. Workflow Terraform

Avant de déployer l’infrastructure, plusieurs commandes sont utilisées.


### Initialiser Terraform

```
terraform init
```

Télécharge les plugins nécessaires (AWS provider).


### Formater le code

```
terraform fmt
```

Formate automatiquement les fichiers Terraform.


### Vérifier la configuration

```
terraform validate
```

Exemple :

```
Success! The configuration is valid.
```


# 17. Terraform Plan

Avant de créer les ressources :

```
terraform plan
```

Terraform :

* compare l’infrastructure actuelle
* compare avec la configuration
* affiche les changements


# 18. Déploiement (Apply)

Après avoir vérifié le plan, on peut créer les ressources avec :

```bash
terraform apply
```

* Terraform affiche le **plan d’exécution** et demande confirmation (`yes` ou `no`).
* Une fois confirmé, Terraform **crée toutes les ressources** définies dans les fichiers `.tf`.
* Exemple de sortie :

```
aws_vpc.main: Creating...
aws_subnet.public[0]: Creating...
aws_subnet.public[1]: Creating...
...
Apply complete! Resources: 17 added, 0 changed, 0 destroyed.
```

**Remarques** :

* `apply` est la commande qui **déploie réellement** les ressources sur AWS.
* Toujours vérifier le plan (`terraform plan`) avant d’exécuter `apply`.
* On peut automatiser `apply` sans confirmation avec :

```bash
terraform apply -auto-approve
```


# 19. Suppression (Destroy)

Pour **supprimer toutes les ressources créées** :

```bash
terraform destroy
```

* Terraform va créer un plan de destruction pour **toutes les ressources du projet**.
* Il demande confirmation avant de supprimer.
* Exemple de sortie :

```
aws_lb.app: Destroying...
aws_security_group.app: Destroying...
aws_subnet.public[0]: Destroying...
...
Destroy complete! Resources: 17 destroyed.
```

**Remarques** :

* `destroy` est utile pour **réinitialiser l’infrastructure**, éviter les coûts inutiles sur AWS.
* Comme pour `apply`, on peut automatiser avec :

```bash
terraform destroy -auto-approve
```



# 20. Architecture

```
Internet
    │
    ▼
[Internet Gateway]
    │
    ▼
┌────────────── VPC 10.0.0.0/16 ────────────────┐
│                                               │
│  Public Subnet AZ-A      Public Subnet AZ-B   │
│  10.0.1.0/24             10.0.2.0/24          │
│  [NAT Gateway]           [NAT Gateway]        │
│        │                        │             │
│  Private Subnet AZ-A     Private Subnet AZ-B  │
│  10.0.11.0/24            10.0.12.0/24         │
│  [App / DB]              [App / DB]           │
│                                               │
└───────────────────────────────────────────────┘
```

## Déploiement

### Pré-requis

```bash
terraform >= 1.6.0
aws-cli >= 2.0
```
# 21. Améliorations 

L’infrastructure pourrait être améliorée avec :

* Cluster Kubernetes (EKS)
* Base de données RDS
* CI/CD

---