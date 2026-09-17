# macOS — menu bar, popover, floating HUD

Overrides MASTER for the collector Mac app (`Apps/Mac`).

- **Pattern:** MenuBarExtra window + optional always-on-top remaining HUD. Not a marketing landing page.
- **Density:** compact (8–12pt). Popover ~380×560.
- **Hero:** remaining % for the first three accounts (`Metering.focus`). Capsules in the menu bar encode remaining height, not used.
- **HUD:** `MacGlanceHUD` — hidden-title-bar window, gold/slate tokens, values as text + rings.
- **Motion:** 180–220ms easeOut; `accessibilityReduceMotion` disables trim animation.
- **A11y:** menu bar label is the combined remaining chip; footer actions are labeled SF Symbols with 44pt hits.
- **Do not:** hover-only actions, emoji, invent 0% tracks, put tokens in the HUD.
