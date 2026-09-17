# Security

- Tokens and API keys: Keychain only (`SecureStore`). Default is device-bound (`synchronizable: false`).
- CloudKit private DB: meters and nicknames. `SecretPolicy` rejects token-like field names and values.
- No Exergy server. No analytics SDK.
- Report issues privately to lp@thebonhomme.com.

App Review: Demo meters require no secrets.
