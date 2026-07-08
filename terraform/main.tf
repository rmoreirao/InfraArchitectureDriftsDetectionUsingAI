# -----------------------------------------------------------------------------
# Resource Groups (Solution_Design.md - Resource Groups)
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "app" {
  name     = "rg-${var.name_prefix}-${var.environment}-weeu-01"
  location = var.location
  tags     = var.common_tags
}

resource "azurerm_resource_group" "shared" {
  name     = "rg-intaudit-shared-${var.environment}-weeu"
  location = var.location
  tags     = var.common_tags
}
