variable "subscription_id" {
  type        = string
  description = "Azure subscription id (sub-gsotech-prd-gsointaudit-01) used for the deployment."
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "location" {
  type        = string
  description = "Primary Azure region for West Europe resources."
  default     = "westeurope"
}

variable "openai_location" {
  type        = string
  description = "Region for Azure OpenAI / AI Foundry. Sweden Central is required for the larger models (Design Decision 006)."
  default     = "swedencentral"
}

variable "cosmos_location" {
  type        = string
  description = "Read/Write region for Cosmos DB."
  default     = "northeurope"
}

variable "name_prefix" {
  type        = string
  description = "Short application/environment prefix used in resource names."
  default     = "iaai"
}

variable "environment" {
  type        = string
  description = "Functional environment name."
  default     = "prd"
}

variable "common_tags" {
  type        = map(string)
  description = "Tags applied to every resource (see Solution_Design.md - Tags)."
  default = {
    ApplicationID   = "APM0001409"
    ApplicationName = "GSO Internal Audit - AI Solution"
    ApplicationTeam = "Internal Audit"
    Brand           = "gso"
    BusinessUnit    = "gsointaudit"
    Environment     = "prd"
    PlatformTeam    = "GSO Cloud HIE"
    SCFClassification = "Standard"
  }
}
