# -----------------------------------------------------------------------------
# Edge (Solution_Design.md - Networking: Front Door / WAF)
# Azure Front Door (Standard) is the single public entry point. A WAF policy is
# attached via a security policy. The web app is the only origin.
# -----------------------------------------------------------------------------

resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = "afd-${var.name_prefix}-${var.environment}-01"
  resource_group_name = azurerm_resource_group.app.name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = var.common_tags
}

resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = "fde-${var.name_prefix}-${var.environment}-01"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  tags                     = var.common_tags
}

resource "azurerm_cdn_frontdoor_origin_group" "main" {
  name                     = "og-webapp"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    interval_in_seconds = 30
    path                = "/"
    protocol            = "Https"
    request_type        = "HEAD"
  }
}

resource "azurerm_cdn_frontdoor_origin" "webapp" {
  name                          = "origin-webapp"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id

  enabled                        = true
  host_name                      = azurerm_linux_web_app.main.default_hostname
  origin_host_header             = azurerm_linux_web_app.main.default_hostname
  http_port                      = 80
  https_port                     = 443
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "main" {
  name                          = "route-webapp"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.webapp.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  link_to_default_domain = true
}

resource "azurerm_cdn_frontdoor_firewall_policy" "main" {
  name                = "waf${var.name_prefix}${var.environment}"
  resource_group_name = azurerm_resource_group.app.name
  sku_name            = azurerm_cdn_frontdoor_profile.main.sku_name
  enabled             = true
  mode                = "Prevention"
  tags                = var.common_tags

  custom_rule {
    name     = "RateLimitPerClient"
    enabled  = true
    priority = 100
    type     = "RateLimitRule"
    action   = "Block"

    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 300

    match_condition {
      match_variable     = "RemoteAddr"
      operator           = "IPMatch"
      negation_condition = true
      match_values       = ["0.0.0.0/0"]
    }
  }
}

resource "azurerm_cdn_frontdoor_security_policy" "main" {
  name                     = "secpol-${var.name_prefix}-${var.environment}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.main.id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.main.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}
