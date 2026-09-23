# One bundle identifier per app

**Decided by LP on 2026-09-21.** Applies to Exergy, ClusterFuck, and RIVE if it
becomes a native app. **Does not apply to NATURaL** — see "Grandfathered" below.

## The decision

Exergy ships under a single identifier, `com.lebonhommepharma.exergy`, on every
platform it supports. One App Store Connect record, one SKU, one listing.

| Platform | Identifier | Record |
|---|---|---|
| iOS / iPadOS | `com.lebonhommepharma.exergy` | the record |
| macOS | `com.lebonhommepharma.exergy` | same record, added as a platform |
| tvOS / visionOS, if ever built | `com.lebonhommepharma.exergy` | same record |
| watchOS | `com.lebonhommepharma.exergy.watchkitapp` | embedded — not a record |

The watch app, widget and complication keep sub-identifiers because Apple
requires it of embedded apps and extensions. A sub-identifier is not a second
listing; it is a component of the one above it.

## Why

- **Consolidated ratings and review counts.** Four records split the same
  audience four ways, and each starts from zero.
- **Cross-platform purchase.** A customer buys once and has it everywhere.
  Universal purchase activates once App Review approves a second platform.
- **One submission per update, not four.** Every separate record is its own
  screenshot set at every device size, description, keyword set, age rating,
  privacy nutrition label, support URL and privacy policy URL — and its own
  review cycle, with a round trip on every rejection.

Across the portfolio the choice was eleven listings against seven.

## What Apple actually requires

Verified against App Store Connect Help on 2026-09-21, not from memory:

> "If you want to offer an app with multiple platforms as a single purchase,
> create it as a single record in App Store Connect. All platforms will share
> the same bundle ID, but you'll add platform-specific information separately."

> "A macOS, tvOS, visionOS app, or any combination of creating these platforms,
> uses the same Apple ID (an app identifier), SKU, and bundle ID as the iOS app."

> "Watch-only apps are considered part of the iOS platform in App Store Connect."

Platforms can be added to an existing record later — "In the sidebar, click Add
Platform" — **provided the bundle identifiers already match**. That is the part
that is not reversible after shipping, and the reason this was decided before
first submission rather than after.

Sources: [Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app),
[Add platforms](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms/)

## Grandfathered: NATURaL

NATURaL registered distinct per-platform identifiers — `com.natural.BonhommeTV`,
`com.natural.BonhommeVision`, `com.natural.Bonhomme.mac` — and its records are
live with a permanent SKU. It keeps them. Changing them now would cost real work
and buy nothing, because the records already exist and cannot be merged.

Do not "fix" NATURaL to match this document. The inconsistency is deliberate.

## `com.lebonhommepharma.exergy.pad` is not sanctioned

`Apps/iPad/project.yml` declares `com.lebonhommepharma.exergy.pad`, a
per-device-class identifier — precisely the shape this decision rejects. The
iOS app already covers iPad: `TARGETED_DEVICE_FAMILY` is `"1,2"`.

The identifier stays registered because an unused registration costs nothing and
removing a portal registration is LP's action, not an agent's. **It must not be
shipped.** A registered identifier is not evidence that it was sanctioned.

`Apps/iPad/` is also not currently shippable on its own terms: it contains only
`project.yml` and `ExergyPadApp.swift`, with no icons, no asset catalog and no
privacy manifest.

## watchOS: embedded, and why

`ExergyWatch` is embedded in the phone target (`embed: true`) and always has
been, so it rides in one archive under one listing. No change was needed.

A standalone watch record was considered and rejected: watchOS is not a
selectable platform in App Store Connect, so a standalone watch app means a
watch-*only* app with no iOS version at all.

`WKRunsIndependentlyOfCompanionApp: true` is set and is **orthogonal to the
listing count** — it governs whether the watch app can run without the phone app
installed, not whether it gets its own record.

One honest caveat: no independent data path is implemented today. The watch
target carries CloudKit container, app-group and keychain entitlements, but
`ExergyAppModel` currently only calls `bootstrapDemoIfNeeded()` — there is no
CloudKit fetch in the watch sources. The entitlements express intent; the code
does not yet honour it. A watch app installed without its companion would show
demo data. That is a product question, not a topology one, and it is why the
flag was left as-is rather than flipped in either direction.

## Enforcement

`scripts/test_contracts.py` pins the exact identifier each spec declares, with
whole-line anchoring so a sibling cannot cover for a missing or mistyped id. Any
new identifier fails the contract until it is added deliberately — which is the
point.
