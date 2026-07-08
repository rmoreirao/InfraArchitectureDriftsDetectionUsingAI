# -----------------------------------------------------------------------------
# Compute (Solution_Design.md - Resource Inventory: App Service)
# Linux web app behind Front Door. Public access is restricted so only the
# Front Door profile (matched by service tag + FDID header) can reach the app.
# -----------------------------------------------------------------------------

resource "azurerm_service_plan" "main" {
  name                = "asp-${var.name_prefix}-${var.environment}-${var.region_token}-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.app.name
  os_type             = "Linux"
  sku_name            = "P1v3"
  tags                = var.common_tags
}

resource "azurerm_linux_web_app" "main" {
  name                = "app-${var.name_prefix}-${var.environment}-${var.region_token}-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.app.name
  service_plan_id     = azurerm_service_plan.main.id
  tags                = var.common_tags

  https_only = true

  # Regional VNet integration so the app reaches Key Vault and Cosmos DB over
  # their private endpoints.
  virtual_network_subnet_id = azurerm_subnet.app_integration.id

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    KEY_VAULT_URI    = azurerm_key_vault.main.vault_uri
    COSMOS_ENDPOINT  = azurerm_cosmosdb_account.main.endpoint
    COSMOS_DATABASE  = azurerm_cosmosdb_sql_database.main.name
    COSMOS_CONTAINER = azurerm_cosmosdb_sql_container.orders.name
  }

  site_config {
    minimum_tls_version = "1.2"
    ftps_state          = "Disabled"

    # Only allow inbound traffic that arrives via the Front Door profile.
    ip_restriction {
      name        = "Allow-FrontDoor"
      priority    = 100
      action      = "Allow"
      service_tag = "AzureFrontDoor.Backend"
      headers {
        x_azure_fdid = [azurerm_cdn_frontdoor_profile.main.resource_guid]
      }
    }

    ip_restriction {
      name       = "Deny-All"
      priority   = 500
      action     = "Deny"
      ip_address = "0.0.0.0/0"
    }
  }
}
