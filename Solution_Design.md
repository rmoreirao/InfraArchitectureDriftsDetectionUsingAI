# Brazil Market WebShop — Solution Design

> A cloud-native online grocery storefront for the Brazilian market, running on Azure.

---

## 1. Document Control

| | |
| --- | --- |
| **Solution** | Brazil Market WebShop (BMWS) |
| **Document type** | Solution Design |
| **Version** | 1.0 |
| **Status** | Draft for review |
| **Primary region** | Brazil South (`brazilsouth`) |
| **Environments** | Production, Non-production |
| **Application ID** | APP0000777 |
| **Owner** | bmws-platform@webshop.example |
| **Cost centre** | CC-4210 |

**Authors & reviewers**

| Name | Role | Responsibility |
| --- | --- | --- |
| J. Almeida | Solution Architect | Author |
| M. Costa | Platform Engineer | Author |
| R. Silva | Security Engineer | Reviewer |
| P. Oliveira | Product Owner | Approver |

**Change log**

| Version | Change | Status |
| --- | --- | --- |
| 1.0 | Initial solution design | Draft |

---

## 2. Introduction & Story

Brazil Market WebShop (BMWS) is a customer-facing online grocery store. Shoppers open the
storefront in their browser, search a product catalogue, add items to a cart, and place an order.
The business wants a small, secure, low-maintenance platform that can grow with demand, keeps
customer and order data private, and exposes a single hardened entry point to the internet.

The design is deliberately **simple**: one web application, one document database, one secret store,
and a global edge in front. There is no analytics pipeline, message bus, or background processing in
this iteration — those are explicitly deferred (see Section 12).

### 2.1 Goals

- Serve the storefront over HTTPS with a single global entry point and a web application firewall.
- Store catalogue, cart and order documents in a managed NoSQL database.
- Hold all application secrets in a managed vault — **no secrets or keys in application configuration**.
- Keep the database and secret store off the public internet (private endpoints only).
- Use platform-managed identity for all service-to-service authentication (no shared keys).
- Provide identical, isolated Production and Non-production environments.

### 2.2 In scope

Front Door edge + WAF, App Service web app, Cosmos DB (NoSQL), Key Vault, virtual network with
private endpoints and private DNS, and managed-identity based access control.

### 2.3 Out of scope

Payment provider integration internals, CDN caching strategy, CI/CD pipeline, data analytics,
messaging/eventing, and disaster-recovery to a second region (single region for this iteration).

---

## 3. Solution Overview

The storefront is a Linux **App Service** web application. All public traffic enters through **Azure
Front Door** (Standard) with a **WAF policy**; the web app only accepts traffic that comes from the
Front Door profile. Application data (catalogue, carts, orders) is stored in **Azure Cosmos DB for
NoSQL**. Application secrets (for example the payment-gateway API key) live in **Azure Key Vault**.

The web app authenticates to both Cosmos DB and Key Vault using its **system-assigned managed
identity** — there are no connection strings or account keys in the app configuration. Cosmos DB and
Key Vault have public network access disabled and are reached exclusively over **private endpoints**
inside the virtual network; the web app uses **regional VNet integration** to route to them, and
**private DNS zones** resolve the private endpoint IP addresses.

| Component | Azure service | Purpose |
| --- | --- | --- |
| Global edge | Azure Front Door (Standard) + WAF | Single public entry point, TLS, WAF protection |
| Storefront | App Service (Linux) | Hosts the web application |
| Database | Azure Cosmos DB for NoSQL | Catalogue, cart and order documents |
| Secret store | Azure Key Vault | Application secrets (e.g. payment API key) |
| Network | Virtual Network + subnets | Isolation, VNet integration, private endpoints |
| Private access | Private Endpoints + Private DNS | Private connectivity to Cosmos DB & Key Vault |
| Identity | System-assigned Managed Identity | Keyless service-to-service authentication |

---

## 4. Architecture

### 4.1 Logical diagram

![Brazil Market WebShop architecture](data:image/png;base64...)

### 4.2 Components

| # | Component | Azure resource type | Notes |
| --- | --- | --- | --- |
| C1 | Front Door profile | `azurerm_cdn_frontdoor_profile` | Standard SKU |
| C2 | Front Door endpoint + route | `azurerm_cdn_frontdoor_endpoint` / `_route` | `/*` → web app origin |
| C3 | WAF policy | `azurerm_cdn_frontdoor_firewall_policy` | Prevention mode, rate limiting |
| C4 | App Service plan + web app | `azurerm_service_plan` / `azurerm_linux_web_app` | Linux, P1v3, HTTPS only |
| C5 | Cosmos DB (account/db/container) | `azurerm_cosmosdb_account` (+ sql db/container) | NoSQL, private only |
| C6 | Key Vault | `azurerm_key_vault` | RBAC, private only |
| C7 | Virtual network + subnets | `azurerm_virtual_network` / `azurerm_subnet` | App integration + PE subnets |
| C8 | Private endpoints + DNS | `azurerm_private_endpoint` / `azurerm_private_dns_zone` | Cosmos DB & Key Vault |

### 4.3 Request & data flow

1. A shopper's browser resolves the Front Door endpoint and connects over HTTPS. Front Door
   terminates TLS and applies the WAF policy.
2. Front Door forwards the request to the App Service web app origin over HTTPS. The web app only
   accepts requests that carry the Front Door profile identifier (`X-Azure-FDID`) and originate from
   the `AzureFrontDoor.Backend` service tag; all other inbound traffic is denied.
3. The web app renders the storefront. To read/write catalogue, cart and order documents it calls
   Cosmos DB using its **managed identity** (Cosmos DB data-plane RBAC).
4. When the web app needs a secret (e.g. the payment-gateway API key) it retrieves it from Key Vault
   using the same managed identity (Key Vault Secrets User).
5. Traffic from the web app to Cosmos DB and Key Vault flows through the app-integration subnet to
   the **private endpoints**; private DNS zones resolve the services to their private IP addresses.
   Neither Cosmos DB nor Key Vault is reachable from the public internet.

---

## 5. Environments

Production and Non-production are deployed from the same templates into separate resource groups,
with identical topology. Names differ only by the environment token (`prod` / `nonprod`).

| Aspect | Production | Non-production |
| --- | --- | --- |
| Resource group | `rg-bmws-prod-brs-01` | `rg-bmws-nonprod-brs-01` |
| Region | Brazil South | Brazil South |
| App Service plan SKU | P1v3 | P1v3 |
| Cosmos DB throughput | 400 RU/s (provisioned) | 400 RU/s (provisioned) |
| Front Door SKU | Standard | Standard |
| Public network access (DB / KV) | Disabled | Disabled |

---

## 6. Resource Inventory

Naming convention: `<type>-bmws-<env>-<region>-<instance>` (region token `brs` = Brazil South).
Front Door resources are global and omit the region token.

### 6.1 Resource Group

| Env | Name | Region |
| --- | --- | --- |
| PROD | rg-bmws-prod-brs-01 | Brazil South |
| NONPROD | rg-bmws-nonprod-brs-01 | Brazil South |

### 6.2 App Service

| Env | App Service Plan | Web App | OS | SKU | HTTPS only |
| --- | --- | --- | --- | --- | --- |
| PROD | asp-bmws-prod-brs-01 | app-bmws-prod-brs-01 | Linux | P1v3 | Yes |
| NONPROD | asp-bmws-nonprod-brs-01 | app-bmws-nonprod-brs-01 | Linux | P1v3 | Yes |

The web app has a **system-assigned managed identity** and is integrated into the app subnet for
outbound access to the private endpoints. Inbound access is restricted to the Front Door profile.

### 6.3 Azure Cosmos DB (NoSQL)

| Env | Account | Database | Container | Partition key | Throughput | Public access |
| --- | --- | --- | --- | --- | --- | --- |
| PROD | cosmos-bmws-prod-brs-01 | webshop | orders | /customerId | 400 RU/s | Disabled |
| NONPROD | cosmos-bmws-nonprod-brs-01 | webshop | orders | /customerId | 400 RU/s | Disabled |

Consistency level: Session. Reached over a private endpoint (subresource `Sql`).

### 6.4 Azure Key Vault

| Env | Name | Authorization | Public access | Sample secret |
| --- | --- | --- | --- | --- |
| PROD | kv-bmws-prod-brs-01 | Azure RBAC | Disabled | PaymentGatewayApiKey |
| NONPROD | kv-bmws-nonprod-brs-01 | Azure RBAC | Disabled | PaymentGatewayApiKey |

### 6.5 Azure Front Door

| Env | Profile | Endpoint | SKU | WAF policy |
| --- | --- | --- | --- | --- |
| PROD | afd-bmws-prod-01 | fde-bmws-prod-01 | Standard | wafbmwsprod |
| NONPROD | afd-bmws-nonprod-01 | fde-bmws-nonprod-01 | Standard | wafbmwsnonprod |

Origin group `og-webapp` → origin `origin-webapp` (the web app). Route `route-webapp` matches `/*`,
forwards HTTPS only, and redirects HTTP → HTTPS.

---

## 7. Networking

### 7.1 Virtual Network & Subnets

| Env | VNet | Address space | Subnet | Prefix | Purpose |
| --- | --- | --- | --- | --- | --- |
| PROD | vnet-bmws-prod-brs-01 | 10.50.0.0/22 | snet-app-bmws-prod-brs-01 | 10.50.0.0/24 | App Service VNet integration (delegated to `Microsoft.Web/serverFarms`) |
| PROD | vnet-bmws-prod-brs-01 | 10.50.0.0/22 | snet-pe-bmws-prod-brs-01 | 10.50.1.0/24 | Private endpoints |
| NONPROD | vnet-bmws-nonprod-brs-01 | 10.60.0.0/22 | snet-app-bmws-nonprod-brs-01 | 10.60.0.0/24 | App Service VNet integration |
| NONPROD | vnet-bmws-nonprod-brs-01 | 10.60.0.0/22 | snet-pe-bmws-nonprod-brs-01 | 10.60.1.0/24 | Private endpoints |

### 7.2 Private Endpoints

| Env | Private endpoint | Target resource | Subresource |
| --- | --- | --- | --- |
| PROD | pe-kv-bmws-prod-brs-01 | kv-bmws-prod-brs-01 | vault |
| PROD | pe-cosmos-bmws-prod-brs-01 | cosmos-bmws-prod-brs-01 | Sql |
| NONPROD | pe-kv-bmws-nonprod-brs-01 | kv-bmws-nonprod-brs-01 | vault |
| NONPROD | pe-cosmos-bmws-nonprod-brs-01 | cosmos-bmws-nonprod-brs-01 | Sql |

### 7.3 Private DNS

Private DNS zones are linked to the virtual network so private endpoint FQDNs resolve to private IPs.

| Zone | Used by |
| --- | --- |
| privatelink.vaultcore.azure.net | Key Vault private endpoint |
| privatelink.documents.azure.com | Cosmos DB private endpoint |

### 7.4 Edge / Front Door

Front Door is the only public ingress. The App Service origin enforces `certificate_name_check`, and
the web app's inbound rules only allow the `AzureFrontDoor.Backend` service tag combined with the
Front Door profile identifier header — preventing direct access to the App Service default hostname.

---

## 8. Identity & Access Management

The web app authenticates to downstream services with its **system-assigned managed identity**; no
account keys or connection strings are stored in configuration.

| # | Identity | Role | Scope | Resource type | Purpose |
| --- | --- | --- | --- | --- | --- |
| 1 | app-bmws-\<env\>-brs-01 (MI) | Key Vault Secrets User | kv-bmws-\<env\>-brs-01 | Key Vault | Read application secrets |
| 2 | app-bmws-\<env\>-brs-01 (MI) | Cosmos DB Built-in Data Contributor | cosmos-bmws-\<env\>-brs-01 | Cosmos DB (data plane) | Read/write catalogue, cart & order documents |
| 3 | Deployment principal | Key Vault Administrator | kv-bmws-\<env\>-brs-01 | Key Vault | Seed the sample secret during deployment |

Assignment #2 is a Cosmos DB **data-plane** SQL role assignment (built-in Data Contributor,
`00000000-0000-0000-0000-000000000002`), not a control-plane RBAC role.

---

## 9. Security

| Area | Control |
| --- | --- |
| Ingress | Single public entry via Front Door; App Service locked to the Front Door profile only |
| WAF | Front Door WAF policy in Prevention mode with a per-client rate-limit rule |
| Transport | HTTPS only end-to-end; minimum TLS 1.2 on the web app; HTTP redirected to HTTPS at the edge |
| Secrets | Held in Key Vault (RBAC authorization); retrieved at runtime via managed identity |
| Data isolation | Cosmos DB and Key Vault have public network access disabled; reachable only via private endpoints |
| Identity | System-assigned managed identity for all service-to-service auth; no shared keys |
| Network | Dedicated app-integration and private-endpoint subnets; FTP/FTPS disabled on the web app |
| Encryption | Provider-managed encryption at rest on all PaaS services (default) |

---

## 10. Availability & Cost

### 10.1 Availability

The solution is built entirely from Azure PaaS services, so availability is governed by the
respective Microsoft SLAs. This iteration is single-region (Brazil South); cross-region disaster
recovery is out of scope (Section 12).

| Service | Indicative SLA |
| --- | --- |
| Azure Front Door (Standard) | 99.99% |
| App Service | 99.95% |
| Azure Cosmos DB (single region) | 99.99% |
| Key Vault | 99.99% |

### 10.2 Indicative monthly cost (Production)

Estimates from the Azure Pricing Calculator; indicative only, excluding data egress and request
volume beyond the stated baselines.

| Service | Configuration | Est. monthly (USD) |
| --- | --- | --- |
| App Service | P1v3, 1 instance, Linux | $115 |
| Azure Cosmos DB | 400 RU/s provisioned, 10 GB | $24 |
| Azure Front Door | Standard base + routing/WAF | $35 |
| Key Vault | Standard, low operation volume | $1 |
| Private Endpoints | 2 endpoints | $16 |
| **Total** | | **~$191** |

---

## 11. Assumptions & Decisions

| ID | Decision | Rationale |
| --- | --- | --- |
| AD-01 | Single region (Brazil South) for prod and non-prod | Keeps the first iteration simple; latency to Brazilian shoppers; DR deferred |
| AD-02 | Front Door is the only public entry; App Service locked to Front Door | Single hardened ingress with WAF; hides the App Service default hostname |
| AD-03 | Cosmos DB & Key Vault use private endpoints, public access disabled | Keeps data and secrets off the public internet |
| AD-04 | Managed identity for all service-to-service auth | Eliminates stored keys/connection strings |
| AD-05 | Front Door Standard with a custom rate-limit WAF rule | Managed rule sets require Premium; rate limiting covers the primary threat cheaply |
| AD-06 | Provisioned throughput (400 RU/s) on Cosmos DB | Predictable baseline cost for a small catalogue/order volume |

---

## 12. Open Items / Risks

| ID | Item | Type | Note |
| --- | --- | --- | --- |
| OI-01 | No second-region disaster recovery | Risk | Acceptable for the MVP; revisit if RTO/RPO tighten |
| OI-02 | WAF uses a custom rate-limit rule, not managed rule sets | Risk | Upgrade to Front Door Premium for OWASP managed rules if required |
| OI-03 | Payment provider integration not yet designed | Open | Only the secret placeholder exists today |
| OI-04 | Autoscale rules for App Service not defined | Open | Add scale-out rules before go-live based on load testing |
| OI-05 | Cosmos DB backup/restore policy not specified | Open | Confirm periodic vs continuous backup with the data owner |
