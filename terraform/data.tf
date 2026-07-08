# -----------------------------------------------------------------------------
# Data (Solution_Design.md - Resource Inventory: Cosmos DB)
# Cosmos DB for NoSQL: catalog + orders. Public network access is disabled;
# the account is reached over a private endpoint. The web app's managed identity
# is granted data-plane access via a built-in SQL role assignment.
# -----------------------------------------------------------------------------

resource "azurerm_cosmosdb_account" "main" {
  name                = "cosmos-${var.name_prefix}-${var.environment}-${var.region_token}-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.app.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  tags                = var.common_tags

  public_network_access_enabled = false
  automatic_failover_enabled    = false

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant    = false
  }
}

resource "azurerm_cosmosdb_sql_database" "main" {
  name                = "webshop"
  resource_group_name = azurerm_resource_group.app.name
  account_name        = azurerm_cosmosdb_account.main.name
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "orders" {
  name                  = "orders"
  resource_group_name   = azurerm_resource_group.app.name
  account_name          = azurerm_cosmosdb_account.main.name
  database_name         = azurerm_cosmosdb_sql_database.main.name
  partition_key_paths   = ["/customerId"]
  partition_key_version = 2
}

# Web app managed identity -> Cosmos DB data plane (Built-in Data Contributor).
resource "azurerm_cosmosdb_sql_role_assignment" "app_data" {
  resource_group_name = azurerm_resource_group.app.name
  account_name        = azurerm_cosmosdb_account.main.name
  role_definition_id  = "${azurerm_cosmosdb_account.main.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azurerm_linux_web_app.main.identity[0].principal_id
  scope               = azurerm_cosmosdb_account.main.id
}
