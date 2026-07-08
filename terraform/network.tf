# -----------------------------------------------------------------------------
# Networking (Solution_Design.md - Networking)
# VNet with an app-integration subnet (delegated to App Service) and a private
# endpoint subnet. Private DNS zones resolve Key Vault and Cosmos DB privately.
# -----------------------------------------------------------------------------

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.name_prefix}-${var.environment}-${var.region_token}-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.app.name
  address_space       = ["10.50.0.0/22"]
  tags                = var.common_tags
}

# Delegated subnet for App Service regional VNet integration (outbound to PEs).
resource "azurerm_subnet" "app_integration" {
  name                 = "snet-app-${var.name_prefix}-${var.environment}-${var.region_token}-01"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.50.0.0/24"]

  delegation {
    name = "webapp-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Subnet dedicated to private endpoints for Key Vault and Cosmos DB.
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-pe-${var.name_prefix}-${var.environment}-${var.region_token}-01"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.50.1.0/24"]
}

# --- Private DNS zones -------------------------------------------------------

resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.app.name
  tags                = var.common_tags
}

resource "azurerm_private_dns_zone" "cosmos" {
  name                = "privatelink.documents.azure.com"
  resource_group_name = azurerm_resource_group.app.name
  tags                = var.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "dnslink-kv-${var.name_prefix}-${var.environment}"
  resource_group_name   = azurerm_resource_group.app.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.main.id
  tags                  = var.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "cosmos" {
  name                  = "dnslink-cosmos-${var.name_prefix}-${var.environment}"
  resource_group_name   = azurerm_resource_group.app.name
  private_dns_zone_name = azurerm_private_dns_zone.cosmos.name
  virtual_network_id    = azurerm_virtual_network.main.id
  tags                  = var.common_tags
}

# --- Private endpoints -------------------------------------------------------

resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-kv-${var.name_prefix}-${var.environment}-${var.region_token}-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.app.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.common_tags

  private_service_connection {
    name                           = "psc-keyvault"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }
}

resource "azurerm_private_endpoint" "cosmos" {
  name                = "pe-cosmos-${var.name_prefix}-${var.environment}-${var.region_token}-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.app.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.common_tags

  private_service_connection {
    name                           = "psc-cosmos"
    private_connection_resource_id = azurerm_cosmosdb_account.main.id
    subresource_names              = ["Sql"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "cosmos-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.cosmos.id]
  }
}
