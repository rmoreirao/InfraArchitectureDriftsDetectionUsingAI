# Comparison Rubric

Compare the INTENT model (design doc) against the REALITY model (Terraform) **decision by
decision**. Reason about architectural intent, not string equality.

## Verdicts

| Verdict | Meaning | When to use |
|---|---|---|
| ✅ Match | Terraform satisfies the documented decision | Values agree semantically |
| ⚠️ Documentation update needed | Terraform introduces or omits components the doc does not describe | New architectural component in code; documented component missing from code but not contradicting a hard rule |
| ❌ Drift | Terraform contradicts a documented decision | A hard requirement is violated |

## Severity guidance
- **❌ Drift** for violations of explicit constraints: wrong compute SKU/tier, public
  access where the doc requires private, missing HA where the doc requires it, wrong
  region for a location-constrained service, missing private endpoint that is a stated
  decision, secret management/identity rule broken.
- **⚠️ Documentation update** for additive changes: new service types not in the doc
  (e.g. Redis, Container Apps), extra components, or documented components that are absent
  from code but do not break a security/HA constraint.
- **✅ Match** when intent is met even if wording differs.

## Semantic examples (from the proposal)

Intent: "Production App Service must use PremiumV3." Terraform: `sku_name = "B2"`.
→ ❌ Drift. Doc requires PremiumV3; Terraform deploys Basic (B2).

Intent: "Database must not expose a public endpoint." Terraform:
`public_network_access_enabled = true`. → ❌ Drift.

Intent lists Web App + Azure SQL + Key Vault; Terraform adds Container Apps + Cosmos DB +
Redis. → ⚠️ New architectural components detected; update the documentation.

Intent: "Highly Available." Terraform: `zones = 3` / `replica_count = 3`.
→ ✅ Requirement satisfied.

Intent: "Sensitive services should not expose public endpoints." Terraform: Key Vault,
Storage, SQL with `public_network_access_enabled = true`. → ❌ Drift (even if wording
differs from the code).

## Reasoning checklist per decision
1. Which documented decision does this map to?
2. Does the Terraform value satisfy the *intent* (allowing for equivalent SKUs/wording)?
3. If not, is it a contradiction (❌) or merely undocumented/additive (⚠️)?
4. Cite both sides: the doc statement and the Terraform attribute/value.
