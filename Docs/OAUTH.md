# OAuth and API keys

Redirect URI for every public client: `exergy://oauth`

PKCE: S256. State is random. Tokens: Keychain, never CloudKit.

Register these on team ZJLX84G8QV and paste the **client IDs** into the Xcode scheme (they are public for native PKCE clients; do not commit secrets).

| Provider | Console | Scopes | Notes |
|---|---|---|---|
| GitHub Copilot | GitHub OAuth App | `read:user` `read:org` | Usage JSON is fail-closed if the payload has no percent. |
| Google Gemini | Google Cloud OAuth | usage readonly | |
| Anthropic Claude | Anthropic console OAuth | `usage:read` | Also accepts Admin/API keys. |
| OpenAI Codex | API key only in 1.0 | — | Paste sk- key. |
| xAI Grok | API key | — | |
| OpenRouter | Management key | — | Not an inference key. |
| Cursor | Mac local JSON import | — | User-selected file; no unofficial scrape. |

Environment keys (optional):

```
EXERGY_GITHUB_CLIENT_ID
EXERGY_GOOGLE_CLIENT_ID
EXERGY_ANTHROPIC_CLIENT_ID
```

App Review can use Demo meters with OAuth unconfigured.
