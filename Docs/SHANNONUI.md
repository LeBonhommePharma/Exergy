# Exergy inside ShannonUI

Shannon's pill already shows **session** usage (Codex `rate_limits`, Claude JSONL) via `UsageCore`. Exergy shows **plan** remaining across logins and syncs that through the user's iCloud.

Integration, fail-closed:

- `UsageCore.ExergyPlanGlance` decodes `exergy-glance.json` from App Group `group.com.lebonhommepharma.exergy`.
- `MacFloatingGlance.present(..., exergyUsageLabel:)` uses that chip only when no session usage was sourced.
- Tokens are never in the JSON.

Exergy apps do not link Pill. Pill does not link ExergyCore. The JSON schema is the contract.
