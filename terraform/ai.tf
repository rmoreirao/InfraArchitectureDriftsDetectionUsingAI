# -----------------------------------------------------------------------------
# AI services (Solution_Design.md - Azure OpenAI / AI Foundry, Azure AI Search)
# -----------------------------------------------------------------------------

# Azure OpenAI / AI Foundry - Sweden Central (Design Decision 006),
# public access disabled (Azure PaaS Firewall table).
resource "azurerm_cognitive_account" "openai" {
  name                = "aoi-${var.name_prefix}-${var.environment}-swed-01"
  location            = var.openai_location
  resource_group_name = azurerm_resource_group.app.name
  kind                = "OpenAI"
  sku_name            = "S0"
  tags                = var.common_tags

  public_network_access_enabled = false

  identity {
    type = "SystemAssigned"
  }
}

# Azure AI Search - Standard tier, 3 replicas across AZs, RBAC auth.
resource "azurerm_search_service" "main" {
  name                = "srch-${var.name_prefix}-${var.environment}-weeu-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.app.name
  sku                 = "standard"
  replica_count       = 3
  partition_count     = 1
  tags                = var.common_tags

  local_authentication_enabled = false
  public_network_access_enabled = false

  identity {
    type = "SystemAssigned"
  }
}
