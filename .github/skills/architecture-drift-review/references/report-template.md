# Report Template

Write the review to `architecture-review.md` (workspace root unless the user specifies a
path). Use this structure. Keep it concise and evidence-based.

```markdown
# Architecture Compliance Review

- **Design document:** <path>
- **Terraform source:** <path to plan.json>
- **Reviewed:** <date>

## Verdict

<one of>
- ✅ Architecture matches documentation
- ⚠️ Documentation should be updated
- ❌ Architecture drift detected

<one-sentence summary of the most important finding>

## Findings

| Architectural decision | Documented intent | Terraform reality | Verdict |
|---|---|---|---|
| App Service SKU | PremiumV3 | B1 | ❌ Drift |
| OpenAI region | Sweden Central | swedencentral | ✅ Match |
| Storage public access | Disabled | false | ✅ Match |
| ... | ... | ... | ... |

## ❌ Drift detected
For each drift:
### <decision name>
- **Documented:** <quote/paraphrase from the design doc>
- **Terraform:** `<resource.attribute = value>`
- **Impact:** <why it matters>
- **Suggested fix:** <change Terraform to X, or confirm & update the doc>

## ⚠️ Documentation updates suggested
- <component in Terraform not described in the doc, or vice versa>

## ✅ Satisfied decisions
- <bullet list of decisions that matched>

## Notes
- <e.g. "plan.json generated against subscription <id> on <date>." or any caveats about the plan.>
```

Rules:
- Every row in the findings table must have a verdict.
- Order the report so ❌ appears before ⚠️ before ✅.
- Quote concrete Terraform attributes as evidence, not vague statements.
