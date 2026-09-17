# Widgets, complications, ShannonUI glance HUD

Overrides MASTER for WidgetKit + Shannon pill glance.

- **Small widget:** one ring + remaining % + band text.
- **Medium:** three remaining columns.
- **Accessory:** circular dial / rectangular remaining chip.
- **Shannon Mac glance:** `ExergyPlanGlance` fills `exergyUsageLabel` only when session usage is missing. Chip is remaining (`39% left`), never tokens. Gauge SF Symbol beside the usage line.
- **Fail-closed:** malformed JSON or missing usedPercent → no chip.
