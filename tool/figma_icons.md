# Figma icon exports

Icons in `assets/icons/` are exported from the CubeClash Figma file and
committed. They are the designers' vectors — the design system specifies
stroke 2 with round caps and joins, which no stock icon font reproduces.

File key: `agaSWydXRtfQIiN112f6wG`

| Asset | Source node | Notes |
|---|---|---|
| `chevron-down.svg` | `21:58` (Timer Home → topbar → event) | event-picker affordance |
| `refresh.svg` | `26:41` (Timer Home → scramble → row → new) | "New" scramble pill |
| `nav-timer.svg` | `I21:87;18:40` | bottom nav |
| `nav-race.svg` | `I21:87;18:45` | bottom nav (flag) |
| `nav-stats.svg` | `I21:87;18:50` | bottom nav (bars) |
| `nav-you.svg` | `I21:87;18:62` | bottom nav (person) |

The **Race** frames (`33:106`, `33:188`, `33:246`, `34:106`, `34:140`,
`34:167`, `39:106`) add no icons. Their only vectors are plain filled circles —
the live dot and the avatar placeholders — which are drawn with a
`BoxDecoration`, since exporting a circle as an asset buys nothing. The `×`
close affordance is the literal glyph at 22pt, not an icon.

## Re-exporting

Figma's MCP asset URLs expire after ~7 days, so re-fetch rather than reusing
an old link:

1. `get_design_context` on the node that contains the icon.
2. `curl -sL -o assets/icons/<name>.svg "<asset url>"`.
3. Normalise for flutter_svg, which cannot parse CSS custom properties:
   - replace `var(--stroke-0, #RRGGBB)` with the bare hex,
   - replace `width="100%" height="100%"` with the intrinsic size.

`AppIcon` tints whatever colour the asset carries via a `srcIn` filter, so one
export serves every state.
