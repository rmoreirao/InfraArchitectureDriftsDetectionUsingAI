variable "subscription_id" {
  type        = string
  description = "Azure subscription id used for the deployment."
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "location" {
  type        = string
  description = "Primary Azure region for all regional resources (Brazil South)."
  default     = "brazilsouth"
}

variable "name_prefix" {
  type        = string
  description = "Short application prefix used in resource names (Brazil Market WebShop)."
  default     = "bmws"
}

variable "environment" {
  type        = string
  description = "Functional environment name (prod | nonprod)."
  default     = "prod"
}

variable "region_token" {
  type        = string
  description = "Short region token used in resource names."
  default     = "brs"
}

variable "common_tags" {
  type        = map(string)
  description = "Tags applied to every resource (see Solution_Design.md - Document Control)."
  default = {
    ApplicationID   = "APP0000777"
    ApplicationName = "Brazil Market WebShop"
    ApplicationTeam = "WebShop Platform"
    Environment     = "prod"
    Owner           = "bmws-platform@webshop.example"
    CostCenter      = "CC-4210"
  }
}
