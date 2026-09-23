# App Store Connect — privacy and listing answers

## Identity

One identifier across iOS, iPadOS and macOS — one App Store Connect record, one
listing. Decided by LP on 2026-09-21; rationale and Apple's requirements in
[bundle-id-topology.md](bundle-id-topology.md). NATURaL is deliberately exempt.


| Field | Value |
|---|---|
| Name | Exergy |
| Bundle ID (all platforms) | com.lebonhommepharma.exergy |
| SKU | exergy-usage-1 |
| Primary language | English (U.S.) |
| Category | Developer Tools |
| Secondary | Productivity |
| Pricing | Free |
| Copyright | 2026 Le Bonhomme Pharma |

URLs: marketing `https://thebonhomme.com/Exergy/`, support `https://thebonhomme.com/Exergy/support/`, privacy `https://thebonhomme.com/Exergy/privacy/`

## Export compliance

Answer that the app uses only exempt encryption (HTTPS to Apple and to providers the user signs into).

## App Privacy

**Data Not Collected.**

Evidence:

- No developer servers, accounts, or analytics SDKs
- CloudKit private database only; secrets are Keychain-only (`SecretPolicy` refuses token field names)
- Privacy manifests: `NSPrivacyTracking` false, empty collected types
- Demo path requires no third-party sign-in

Do not select tracking.

## Age rating

Unrestricted web browsing: No. User-generated content: No. Developer tools showing usage percentages.
