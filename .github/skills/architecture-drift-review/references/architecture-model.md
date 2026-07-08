# Architecture Model

Both sides of the comparison are reduced to the same **simplified architecture model** so
the comparison is semantic, not syntactic. Only capture decisions an architect cares about.
Ignore incidental implementation detail (individual tags, DNS records, diagnostic settings,
locks, exact IP addresses) unless the design doc explicitly calls them out as a decision.

## Model shape

```yaml
architecture:
  resource_groups:
    - name: rg-...
  compute:
    - type: App Service            # logical type
      sku: B1                      # tier/size decision
      instance_count: 2
      public_access: true
      vnet_integration: true
  ai:
    - type: Azure OpenAI
      location: swedencentral
      public_access: false
    - type: Azure AI Search
      tier: standard
      replicas: 3                  # HA signal
      auth: rbac
      public_access: false
  database:
    - type: Cosmos DB
      capacity_mode: provisioned
      write_region: northeurope
      zone_redundant: true
  storage:
    - type: Storage Account
      account_kind: StorageV2
      replication: LRS
      access_tier: Hot
      public_access: false
  network:
    private_endpoints: [storage-blob, openai-account, search]
    public_access_defaults: deny
  identity:
    managed_identity: true         # system-assigned MIs used for service-to-service
  security:
    key_vault: true
    rbac_authorization: true

  ...
```

## Extracting the INTENT model (from the Markdown design doc)

- Read tables and design-decision callouts. Typical sections: Resource Groups, App Service
  Plan/Service, Azure OpenAI, Azure AI Search, Cosmos DB, Storage account, Private
  Endpoints, Key Vault, Security, Disaster Recovery.
- Translate prose decisions into model fields:
  - "PremiumV3" / "B1" → `compute.sku`.
  - "Public access disabled", "must not expose a public endpoint" → `public_access: false`.
  - "Sweden Central is used for AI Foundry" → `ai.location: swedencentral`.
  - "Three or more replicas are required for high availability" → `ai.replicas: 3` (HA).
  - "provisioned throughput", "Single Read/Write region North Europe" → database fields.
  - "A private endpoint for AI Foundry, Search Service and Storage Account" → `private_endpoints`.
  - "system assigned managed identity" → `identity.managed_identity: true`.
- Prefer the **PRD** environment values when a doc lists both PRD and NONPRD.

## Extracting the REALITY model (from Terraform)

Use `plan.json` (`terraform show -json` output, produced by `run-architecture-review.ps1`):
iterate `planned_values.root_module.resources` (and `child_modules`). The `plan.json` is a
required input — if it is missing, ask the user to run `run-architecture-review.ps1` first
rather than parsing raw HCL.

| Terraform resource type | Model mapping |
|---|---|
| `azurerm_resource_group` | `resource_groups[].name` |
| `azurerm_service_plan` | `compute[].sku` (`sku_name`), `instance_count` (`worker_count`) |
| `azurerm_linux_web_app` / `azurerm_windows_web_app` | `compute[]` type App Service; `public_access` (`public_network_access_enabled`), `vnet_integration` (`virtual_network_subnet_id` set) |
| `azurerm_cognitive_account` (kind `OpenAI`) | `ai[]` Azure OpenAI; `location`, `public_access` |
| `azurerm_search_service` | `ai[]` AI Search; `tier` (`sku`), `replicas` (`replica_count`), `auth` (`local_authentication_enabled=false` → rbac), `public_access` |
| `azurerm_cosmosdb_account` | `database[]` Cosmos DB; `write_region` (`geo_location`), `zone_redundant`, capacity mode |
| `azurerm_storage_account` | `storage[]`; `account_kind`, `replication` (`account_replication_type`), `access_tier`, `public_access` |
| `azurerm_private_endpoint` | `network.private_endpoints[]` (from `subresource_names`) |
| `azurerm_key_vault` | `security.key_vault: true`, `rbac_authorization` (`enable_rbac_authorization`) |
| `azurerm_role_assignment` | evidence of `identity.managed_identity` service-to-service wiring |
| `identity { type = "SystemAssigned" }` blocks | `identity.managed_identity: true` |

## Normalization rules
- Compare SKUs by tier intent, not exact string when the doc is descriptive
  ("PremiumV3" ≈ `P1v3`/`P2v3`; "Basic" ≈ `B1`/`B2`).
- `public_network_access_enabled = false` ⇔ "public access disabled" / "private only".
- Treat `replica_count >= 3` (or zone redundancy) as satisfying "highly available".
- Match resources by logical type first, then by name similarity — names may differ
  between doc and code.
