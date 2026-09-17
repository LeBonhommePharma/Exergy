# Exergy

**Remaining useful work — across every AI account, on every Apple you own.**

Exergy is Le Bonhomme Pharma’s usage tracker: Claude, Codex, Cursor, Grok, Copilot, Gemini, OpenRouter. Menu bar, iPhone, iPad, Apple Watch. OAuth. Private iCloud. No Exergy server.

The name is thermodynamic on purpose. **Exergy** is the remaining work a system can still do. [Shannon](https://github.com/LeBonhommePharma/Shannon) watches entropy collapse. Exergy watches how much quota you have left to spend. Same family as NATURaL / FlexAID∆S; different instrument.

> Headroom (open source and [headroom.zantos.co](https://headroom.zantos.co)) is the inspiration. Exergy is a native Swift, App Store-shaped product: lighter chrome, iCloud-native sync, OAuth instead of a Python host on `:8737`.

This tree lives in **ShannonUI** so it can reuse the multi-Apple layout, CloudKit fail-closed contracts, and UsageCore honesty rules. Bundle IDs are already `com.lebonhommepharma.exergy.*`. When GitHub allows a dedicated repo, extract `Exergy/` with `git filter-repo` — nothing here depends on Pill at compile time.

## Surfaces

| Surface | Job |
|---|---|
| **Mac** (`Apps/Mac`) | Menu-bar remaining marks + popover + optional floating HUD. Optional local JSON import (user-selected files, sandboxed). |
| **iPhone** (`Apps/iOS`) | Three tabs (Usage / Add / Settings), remaining rings, widgets. |
| **iPad** (`Apps/iPad`) | Split canvas, not a phone scale-up. |
| **Watch** | Remaining dial + complications. |

Compact surfaces show the first **three** enabled accounts. The pool is global: iPhone and Mac merge observations by max used-% inside the same reset window.

## Privacy (non-negotiable)

- **Tokens never enter CloudKit.** Keychain only. iCloud Keychain sync of sign-ins is **off** by default.
- CloudKit private database carries nicknames, provider kind, and meter snapshots (used %, reset time, optional spend).
- No analytics SDK. No Exergy backend. App Privacy: **Data Not Collected**.
- Demo meters ship for App Review and first launch so the UI is honest without secrets.

## Build

```bash
cd Exergy
make test          # ExergyCore + ExergyTheme (needs Swift)
make test-python   # contract tests (no Swift)
```

Xcode (macOS with XcodeGen):

```bash
cd Exergy/Apps/iOS && rm -rf Exergy.xcodeproj && xcodegen generate
cd ../Mac && rm -rf ExergyMac.xcodeproj && xcodegen generate
cd ../iPad && rm -rf ExergyPad.xcodeproj && xcodegen generate
```

Set `DEVELOPMENT_TEAM` to `ZJLX84G8QV` (same team as NATURaL). Unsigned Simulator builds leave it blank.

## App Store

Two records (Apple’s stores are separate):

1. **iOS / iPadOS + Watch companion** — `com.lebonhommepharma.exergy`
2. **Mac** — `com.lebonhommepharma.exergy.mac`

Checklist, metadata, privacy answers: [`Docs/AppStore/`](Docs/AppStore/README.md).

## OAuth

Client IDs are **not** in source. Paste them in Xcode Info / scheme env (`EXERGY_GITHUB_CLIENT_ID`, `EXERGY_GOOGLE_CLIENT_ID`, `EXERGY_ANTHROPIC_CLIENT_ID`). Redirect: `exergy://oauth` (PKCE S256). See [`Docs/OAUTH.md`](Docs/OAUTH.md).
