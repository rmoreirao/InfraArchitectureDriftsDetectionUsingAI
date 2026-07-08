# -----------------------------------------------------------------------------
# Resource Group (Solution_Design.md - Environments / Resource Inventory)
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "app" {
  name     = "rg-${var.name_prefix}-${var.environment}-${var.region_token}-01"
  location = var.location
  tags     = var.common_tags
}
