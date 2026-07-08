# -----------------------------------------------------------------------------
# Security & IAM (Solution_Design.md - Key Vault, RBAC Role Assignments)
# -----------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

# Shared Internal Audit Key Vault, network-restricted to the app subnet.
resource "azurerm_key_vault" "shared" {
  name                = "kvgsointaudit${var.environment}weeu"
  location            = var.location
  resource_group_name = azurerm_resource_group.shared.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  tags                = var.common_tags

  rbac_authorization_enabled    = true
  public_network_access_enabled = false

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [azurerm_subnet.app_integration.id]
  }
}

# --- RBAC subset (Solution_Design.md - RBAC Role Assignments) ---

# App Service MI -> Azure OpenAI (Azure AI User).
resource "azurerm_role_assignment" "app_to_openai" {
  scope                = azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

# App Service MI -> Key Vault (Key Vault Secrets User).
resource "azurerm_role_assignment" "app_to_kv" {
  scope                = azurerm_key_vault.shared.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

# Search MI -> Storage (Storage Blob Data Reader).
resource "azurerm_role_assignment" "search_to_storage" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_search_service.main.identity[0].principal_id
}
