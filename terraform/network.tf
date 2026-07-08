# -----------------------------------------------------------------------------
# Networking (Solution_Design.md - Virtual Network, NSG, Private Endpoints)
# -----------------------------------------------------------------------------

resource "azurerm_virtual_network" "main" {
  name                = "vnet-gsoaudit01-${var.environment}-weeu-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.app.name
  address_space       = ["10.72.192.0/24"]
  tags                = var.common_tags
}

# Dedicated subnet delegated to App Service for VNet integration (Design Decision 002).
resource "azurerm_subnet" "app_integration" {
  name                 = "snet-${var.name_prefix}-${var.environment}-weeu-01"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.72.192.0/28"]

  service_endpoints = [
    "Microsoft.AzureActiveDirectory",
    "Microsoft.CognitiveServices",
    "Microsoft.AzureCosmosDB",
  ]

  delegation {
    name = "webapp-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Separate subnet for private endpoints (Physical view development).
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-${var.name_prefix}-pe-${var.environment}-weeu-01"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.72.192.16/28"]
}

# NSG for the App Service integration subnet: outbound to OpenAI, Cosmos, Entra only.
resource "azurerm_network_security_group" "app" {
  name                = "nsg-snet-${var.name_prefix}-${var.environment}-weeu-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.app.name
  tags                = var.common_tags

  security_rule {
    name                       = "Allow-OpenAI-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "CognitiveServicesFrontend"
  }

  security_rule {
    name                       = "Allow-CosmosDB-Outbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCosmosDB"
  }

  security_rule {
    name                       = "Allow-EntraID-Outbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureActiveDirectory"
  }

  security_rule {
    name                       = "Deny-Any-To-Any"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app_integration.id
  network_security_group_id = azurerm_network_security_group.app.id
}

# Private endpoints (Design Decision 005): Storage blob, Foundry/OpenAI account, Search.
resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-${azurerm_storage_account.main.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.app.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.common_tags

  private_service_connection {
    name                           = "psc-storage-blob"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_endpoint" "openai" {
  name                = "pe-oai-${var.name_prefix}-${var.environment}-swed-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.app.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.common_tags

  private_service_connection {
    name                           = "psc-openai-account"
    private_connection_resource_id = azurerm_cognitive_account.openai.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_endpoint" "search" {
  name                = "pe-srch-${var.name_prefix}-${var.environment}-weeu-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.app.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.common_tags

  private_service_connection {
    name                           = "psc-search-service"
    private_connection_resource_id = azurerm_search_service.main.id
    subresource_names              = ["searchService"]
    is_manual_connection           = false
  }
}
