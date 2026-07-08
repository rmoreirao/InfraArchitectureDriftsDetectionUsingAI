---
name: architecture-drift-review
description: 'Detect architecture drift/compliance between a high-level architecture design document (Markdown, e.g. a Solution Design or Confluence export) and Terraform infrastructure. Use when asked to "review architecture drift", "check terraform against the design", "architecture compliance", "does the terraform match the solution design", "compare intent vs reality", or to validate that infrastructure still implements documented architectural decisions (resource groups, SKUs, networking, private endpoints, high availability, security, database tier, managed identity). Consumes a pre-generated Terraform plan JSON, extracts a simplified architecture model from both sides, semantically compares them, and writes a Markdown review report.'
argument-hint: '<path-to-architecture.md> <path-to-plan.json>'
---

# Architecture Drift Review

Validate whether Terraform infrastructure still implements the architectural decisions
documented in a high-level design document. This is a **compliance review**, not a
documentation generator: it compares *intent* (the design doc) against *reality* (the
Terraform plan) and reports drift.

The deterministic Terraform work (running `init`/`validate`/`plan`/`show -json` against
the current Azure credentials) is handled *outside* this skill by
`run-architecture-review.ps1`, which produces the `plan.json` this skill consumes.

## When to Use
- Reviewing a Pull Request that changes Terraform, to confirm it still matches the design.
- Checking whether a Solution Design / architecture Markdown doc is still accurate.
- Answering "does the Terraform match the architecture?" or "where has it drifted?".

## What NOT to Do
- Do not compare every Terraform resource. Only the **architectural decisions that matter**
  (see [architecture-model.md](./references/architecture-model.md)).
- Do not rewrite the design doc or the Terraform. Produce a **report**; suggest changes.

## Inputs
1. **Architecture doc** — path to a Markdown file (default: `Solution_Design.md`).
2. **Terraform plan JSON** — path to a pre-generated `plan.json` (default:
   `terraform/plan.json`), produced by `run-architecture-review.ps1` using the current
   Azure credentials.

If either input is missing, ask the user for the path before proceeding. If `plan.json`
does not exist, do **not** attempt to generate it — instruct the user to run
`run-architecture-review.ps1` first.

## Procedure

### 1. Extract the intent model (from the design doc)
Read the architecture Markdown and extract a simplified model following
[architecture-model.md](./references/architecture-model.md). Capture only architectural
decisions (resource groups, compute SKU, database tier, networking/private endpoints,
public access, high availability, identity, security).

### 2. Extract the reality model (from Terraform)
From `plan.json` (`terraform show -json` output), extract the same simplified model. Map
Terraform resource types/attributes to the model per
[architecture-model.md](./references/architecture-model.md).

### 3. Compare semantically
For each architectural decision, classify the result using
[comparison-rubric.md](./references/comparison-rubric.md):
- ✅ **Match** — Terraform satisfies the documented intent (semantically, not just literally).
- ⚠️ **Documentation update needed** — Terraform adds/omits components the doc doesn't reflect.
- ❌ **Drift** — Terraform contradicts a documented decision.

Reason about intent: "Highly available" is satisfied by `replica_count = 3` across zones;
"no public endpoint" is violated by `public_network_access_enabled = true`.

### 4. Write the report
Write a Markdown report to `architecture-review.md` in the workspace root (or a path the
user specifies) using [report-template.md](./references/report-template.md). Include a
summary verdict, a per-decision table, and suggested documentation updates.

## Completion Checks
- Every architectural decision from the doc appears in the report with a verdict.
- Terraform-only components not in the doc are listed as ⚠️.
- Each ❌ drift cites the documented decision and the conflicting Terraform value.
