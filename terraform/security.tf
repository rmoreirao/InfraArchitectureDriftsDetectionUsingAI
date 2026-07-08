# -----------------------------------------------------------------------------
# Security & IAM (Solution_Design.md - Security, Identity & Access)
# Key Vault holds application secrets (e.g. payment gateway API key). Public
# access is disabled; the vault is reached over a private endpoint. The web app
# reads secrets using its system-assigned managed identity (RBAC).
# -----------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                = "kv-${var.name_prefix}-${var.environment}-${var.region_token}-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.app.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  tags                = var.common_tags

  rbac_authorization_enabled    = true
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

# Sample secret used by the web app (payment gateway API key placeholder).
resource "azurerm_key_vault_secret" "payment_api_key" {
  name         = "PaymentGatewayApiKey"
  value        = "placeholder-rotate-me"
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.common_tags

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

# Deployer needs data-plane admin to write the sample secret (RBAC vault).
resource "azurerm_role_assignment" "deployer_kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Web app managed identity -> Key Vault (Key Vault Secrets User).
resource "azurerm_role_assignment" "app_kv_secrets" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}
