# Exergy — App Store preparation

Repository preparation, not an uploaded release. Team **ZJLX84G8QV**, account **lp@thebonhomme.com** (same as NATURaL).

Two store records:

| Record | Bundle ID | Notes |
|---|---|---|
| iPhone + iPad + Watch | `com.lebonhommepharma.exergy` | Watch `…watchkitapp`, widget `…widget` |
| Mac | `com.lebonhommepharma.exergy.mac` | Menu bar (`LSUIElement`) |

iPad also has a dedicated target `com.lebonhommepharma.exergy.pad` for a native split canvas. First iOS record can cover iPhone+iPad if you ship one universal binary (`TARGETED_DEVICE_FAMILY: 1,2` on ExergyPhone). Decide in App Store Connect whether the phone binary is universal; keep the pad target for a later wide-canvas listing if needed.

## Identity

| Field | Value |
|---|---|
| Display name | Exergy |
| Subtitle | Remaining useful work |
| SKU (iOS) | `exergy-usage-1` |
| SKU (Mac) | `exergy-usage-mac-1` |
| Category | Developer Tools (secondary: Productivity) |
| Pricing | Free |
| Age | 4+ |
| Marketing | https://thebonhomme.com/Exergy/ |
| Support | https://thebonhomme.com/Exergy/support/ |
| Privacy | https://thebonhomme.com/Exergy/privacy/ |
| iCloud container | `iCloud.com.lebonhommepharma.exergy` |
| App Group | `group.com.lebonhommepharma.exergy` |
| URL scheme | `exergy://oauth` |

## App Privacy

Select **Data Not Collected**.

Exergy does not operate a server. Meters sync through the user’s **private** CloudKit database. OAuth tokens stay in the Keychain. Demo meters require no account.

Do not declare email, user ID, or product interaction as collected by Le Bonhomme Pharma. GitHub / Anthropic / Google / OpenAI / xAI see whatever the user authorizes **with those companies**; that is not our collection.

## Export compliance

`ITSAppUsesNonExemptEncryption` is `NO`. HTTPS to Apple and to user-chosen providers is exempt.

## Review notes (paste)

Exergy shows remaining AI coding quota. No Exergy login. First launch shows **Demo meters** (clearly labeled). To add a real account: Settings off Demo, Add account, paste an API key or complete OAuth (client IDs configured in the reviewed build).

iCloud sync uses the system Apple ID. Tokens are not in iCloud records.

Watch shows the same three focus rings.

Contact: lp@thebonhomme.com

## Remaining external gates

1. Register identifiers, App Group, iCloud container, Keychain group on team ZJLX84G8QV.
2. Create App Store Connect records; paste metadata from `metadata.md`.
3. Fill OAuth client IDs (see `../OAUTH.md`).
4. Archive + Validate + TestFlight on iPhone, iPad, Watch, Mac.
5. Screenshots at current accepted sizes.
6. Publish the GitHub Pages routes, then lock the URLs in Connect.

Local check:

```sh
python3 Exergy/scripts/validate-submission.py
python3 Exergy/scripts/test_contracts.py
```

Icons: geometric remaining-work gauges (chrome gold `#C4A359` on slate `#0F172A`). Regenerators and the Claude Design handoff live in [CLAUDE_DESIGN_ICON_WORKORDER.md](CLAUDE_DESIGN_ICON_WORKORDER.md). `make -C Exergy icons` rewrites the PNGs.
