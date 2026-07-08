# -----------------------------------------------------------------------------
# Compute (Solution_Design.md - App Service Plan, Azure App Service)
# -----------------------------------------------------------------------------

resource "azurerm_service_plan" "main" {
  name                = "asp-${var.name_prefix}-${var.environment}-weeu-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.app.name
  os_type             = "Linux"
  sku_name            = "B1"
  worker_count        = 2
  tags                = var.common_tags
}

resource "azurerm_linux_web_app" "main" {
  name                = "app-${var.name_prefix}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.app.name
  service_plan_id     = azurerm_service_plan.main.id
  tags                = var.common_tags

  # Design Decision 003: public endpoint allowed for the MVP; Entra ID protects access.
  public_network_access_enabled = true

  # VNet integration for outbound traffic (Design Decision 002).
  virtual_network_subnet_id = azurerm_subnet.app_integration.id

  https_only = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    minimum_tls_version = "1.2"
  }
}
