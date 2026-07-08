# Architecture Compliance Review

- **Design document:** `Solution_Design.md` (Brazil Market WebShop — Solution Design, v1.0)
- **Terraform source:** `terraform/plan.json` (`terraform show -json`)
- **Reviewed:** 2026-07-08

## Verdict

❌ **Architecture drift detected**

The core topology matches the design, but two documented security/connectivity decisions are **not** implemented in Terraform: the web app has **no regional VNet integration** (so it cannot reach the private endpoints as designed), and **Key Vault RBAC authorization is not enabled** (it falls back to the access-policy model, contradicting the documented RBAC decision and undermining the Key Vault role assignments).

## Findings

| Architectural decision | Documented intent | Terraform reality | Verdict |
|---|---|---|---|
| App → private endpoints connectivity | Regional VNet integration into `snet-app` (delegated `Microsoft.Web/serverFarms`) | `azurerm_linux_web_app.virtual_network_subnet_id = null`; no swift/VNet-integration resource | ❌ Drift |
| Key Vault authorization model | Azure RBAC (Section 6.4, 9) | `azurerm_key_vault.enable_rbac_authorization = null` → defaults to `false` (access-policy model) | ❌ Drift |
| Ingress FDID binding | App accepts only the Front Door **profile** via `X-Azure-FDID` header + service tag (Sec 4.3, 7.4) | `ip_restriction` uses service tag `AzureFrontDoor.Backend` + `Deny-All`, but **no FDID header check** | ⚠️ Hardening gap |
| Non-production environment | Identical, isolated PROD + NONPROD (Section 5) | Only PROD resources present in this plan (single RG `rg-bmws-prod-brs-01`) | ⚠️ Coverage |
| Resource group / region | `rg-bmws-prod-brs-01`, Brazil South | `rg-bmws-prod-brs-01`, `brazilsouth` | ✅ Match |
| App Service plan SKU | P1v3, Linux | `sku_name = P1v3`, `os_type = Linux` | ✅ Match |
| HTTPS-only / TLS / FTPS | HTTPS only, min TLS 1.2, FTP(S) disabled | `https_only = true`, `minimum_tls_version = 1.2`, `ftps_state = Disabled` | ✅ Match |
| Ingress lock to Front Door | App Service locked to Front Door only (AD-02) | `ip_restriction`: Allow `AzureFrontDoor.Backend` (p100) + Deny `0.0.0.0/0` (p500) | ✅ Match |
| Managed identity | System-assigned MI for all service-to-service auth (AD-04) | `identity { type = "SystemAssigned" }` on web app | ✅ Match |
| Front Door SKU | Standard | `sku_name = Standard_AzureFrontDoor` | ✅ Match |
| WAF policy | Prevention mode + rate limiting (AD-05) | `mode = Prevention`, `enabled = true` | ✅ Match |
| Database engine | Cosmos DB for NoSQL | `kind = GlobalDocumentDB` (SQL API) | ✅ Match |
| Cosmos public access | Disabled (AD-03) | `public_network_access_enabled = false`, VNet filter | ✅ Match |
| Cosmos throughput | 400 RU/s provisioned (AD-06) | `offer_type = Standard`, database `throughput = 400`, no serverless capability | ✅ Match |
| Cosmos consistency / partition | Session; `/customerId` | `consistency_level = Session`; `partition_key_paths = ["/customerId"]` | ✅ Match |
| Cosmos data-plane role | Built-in Data Contributor (MI) | `azurerm_cosmosdb_sql_role_assignment` present | ✅ Match |
| Key Vault public access | Disabled (AD-03) | `public_network_access_enabled = false`; `network_acls.default_action = Deny` | ✅ Match |
| Private endpoints | KV (`vault`) + Cosmos (`Sql`) | `pe-kv…` → `vault`; `pe-cosmos…` → `Sql` | ✅ Match |
| Private DNS zones | `privatelink.vaultcore.azure.net`, `privatelink.documents.azure.com` | Both present and VNet-linked | ✅ Match |
| IAM role assignments | KV Secrets User (MI), KV Administrator (deploy) | Both `azurerm_role_assignment` present | ✅ Match |

## ❌ Drift detected

### Web app has no regional VNet integration
- **Documented:** "the web app uses **regional VNet integration** to route to them" (Section 3); the web app is "integrated into the app subnet for outbound access to the private endpoints" (Section 6.2); `snet-app` is "delegated to `Microsoft.Web/serverFarms`" (Section 7.1).
- **Terraform:** `azurerm_linux_web_app.app-bmws-prod-brs-01.virtual_network_subnet_id = null`. The delegated subnet `snet-app-bmws-prod-brs-01` exists (delegation `Microsoft.Web/serverFarms`), but the web app is **not** joined to it and there is no `azurerm_app_service_virtual_network_swift_connection` / integration resource in the plan.
- **Impact:** Without VNet integration, the web app's outbound traffic to Cosmos DB and Key Vault does not enter the VNet, so it cannot resolve/reach the **private endpoints**. Since both services have public access disabled, runtime calls to the database and secret store will fail. This breaks the data flow in Section 4.3 (step 5).
- **Suggested fix:** Set `virtual_network_subnet_id` on the web app to `snet-app-bmws-prod-brs-01` (or add the swift VNet integration resource) and enable `vnet_route_all_enabled = true`. Alternatively, if the design changed, update the doc.

### Key Vault RBAC authorization not enabled
- **Documented:** Key Vault "Authorization: Azure RBAC" (Section 6.4); "Secrets … held in Key Vault (RBAC authorization)" (Section 9).
- **Terraform:** `azurerm_key_vault.kv-bmws-prod-brs-01.enable_rbac_authorization = null` → the provider default is `false`, i.e. the **vault access-policy** authorization model, not Azure RBAC.
- **Impact:** Contradicts the documented decision. It is also internally inconsistent: the plan creates `Key Vault Secrets User` and `Key Vault Administrator` **role assignments**, which only grant data-plane access when RBAC authorization is enabled. With the access-policy model and no access policies defined, the managed identity would be unable to read `PaymentGatewayApiKey` at runtime.
- **Suggested fix:** Set `enable_rbac_authorization = true` on the Key Vault so the documented RBAC role assignments take effect.

## ⚠️ Documentation / hardening suggestions

- **Front Door profile identity (FDID) not enforced.** Sections 4.3 and 7.4 state the web app accepts only requests that carry the specific Front Door **profile identifier** (`X-Azure-FDID`). Terraform restricts by the shared `AzureFrontDoor.Backend` service tag plus a Deny-All rule, but performs **no FDID header check** — so any Azure Front Door tenant (not only `afd-bmws-prod-01`) could reach the origin. Add an FDID/`X-Azure-FDID` header condition (or reconcile the doc with the implemented control).
- **`ip_restriction_default_action = Allow`.** The lock relies entirely on the explicit `Deny-All` (priority 500) rule after the Front Door allow. It is functionally closed, but setting the default action to `Deny` would be more defensive and clearer.
- **Non-production environment absent from this plan.** Section 5 documents identical PROD + NONPROD environments, but this `plan.json` contains only PROD resources (single resource group `rg-bmws-prod-brs-01`). Confirm NONPROD is managed in a separate Terraform state; otherwise the documented environment is not deployed.

## ✅ Satisfied decisions

- Region **Brazil South** and resource group naming.
- App Service **P1v3 / Linux**, **HTTPS-only**, **TLS 1.2**, **FTPS disabled**.
- **System-assigned managed identity** on the web app (AD-04); Cosmos data-plane and Key Vault role assignments present.
- App Service **locked to Front Door** via service-tag allow + Deny-All ingress rules (AD-02).
- **Front Door Standard** with a **Prevention-mode WAF** policy (AD-05).
- **Cosmos DB for NoSQL**, public access **disabled**, **400 RU/s provisioned** throughput, **Session** consistency, `/customerId` partition key (AD-03, AD-06).
- **Key Vault** public access **disabled** with default-Deny network ACLs (AD-03).
- **Private endpoints** for Key Vault (`vault`) and Cosmos DB (`Sql`) with matching **private DNS zones** linked to the VNet (AD-03).

## Notes

- Reality model derived from `terraform/plan.json` (`terraform show -json`), generated `2026-07-08T13:06:26Z`. Plan contains 27 resources for the PROD environment.
- `subnet_id` on the private endpoints and `role_definition_id` on the Cosmos SQL role assignment are `null` in `planned_values` because they are computed/known-after-apply; this does not affect the findings above.
- Per the model rubric, PROD values were used where the design lists both PROD and NONPROD.
