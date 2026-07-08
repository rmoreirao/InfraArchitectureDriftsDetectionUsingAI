# -----------------------------------------------------------------------------
# Data (Solution_Design.md - Azure Cosmos DB, Azure Storage account)
# -----------------------------------------------------------------------------

# Cosmos DB - provisioned throughput, single write region North Europe.
resource "azurerm_cosmosdb_account" "main" {
  name                = "cosno-${var.name_prefix}-${var.environment}-weeu-01"
  location            = var.cosmos_location
  resource_group_name = azurerm_resource_group.app.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  tags                = var.common_tags

  automatic_failover_enabled = false

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.cosmos_location
    failover_priority = 0
    zone_redundant    = true
  }
}

# Storage account - GPv2 Standard, Hot tier, LRS. Public access disabled,
# reachable via trusted Azure services + private endpoint (Design Decision 004/005).
resource "azurerm_storage_account" "main" {
  name                     = "st${var.name_prefix}${var.environment}weeu01"
  location                 = var.location
  resource_group_name      = azurerm_resource_group.app.name
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "LRS"
  access_tier              = "Hot"
  tags                     = var.common_tags

  public_network_access_enabled = false

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}
