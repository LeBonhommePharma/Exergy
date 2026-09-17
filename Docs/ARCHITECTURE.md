# Architecture

```
Apps (SwiftUI, minimal chrome)
  Mac menu bar · iPhone · iPad split · Watch dial
        │
        ▼
ExergyTheme     remaining rings, gold/slate tokens, 4/8pt grid, HUDs
        │
        ▼
ExergyCore      models, PKCE, CloudKit codec, metering, Keychain policy
        │
        ├─ Keychain     tokens / API keys
        └─ CloudKit     private DB zone ExergyState
              records: ExergyAccount, ExergyUsage, ExergySettings
```

ShannonUI `UsageCore` already meters **session** tokens (Codex `rate_limits`, Claude JSONL). Exergy meters **plan** remaining across logins and syncs that through iCloud. The pill can show an Exergy glance chip when the App Group JSON exists; it never reads Exergy secrets.

## Honesty rules (from Shannon UsageCore)

- Never invent a used percent from raw token counts.
- Missing data draws an empty track, not 0%.
- Compact surfaces share `Metering.focus(limit: 3)`.

## Multi-device

A weekly Claude pool is one pool. `PoolMerge` takes the **max** used % among observations that share kind + reset timestamp. Device name is provenance.

## Extracting a dedicated repo

```
git filter-repo --path Exergy/ --path-rename Exergy/:
```

Bundle IDs, iCloud container, and App Group already use the `exergy` namespace.
