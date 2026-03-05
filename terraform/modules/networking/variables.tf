variable "name_prefix" {
  description = "Préfixe pour nommer les ressources"
  type        = string
}

variable "vpc_cidr" {
  description = "Bloc CIDR du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Liste des AZs à utiliser (minimum 2)"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "environment" {
  description = "Environnement de déploiement"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Doit être \"dev\", \"staging\" ou \"prod\"."
  }
}