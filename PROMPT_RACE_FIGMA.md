# Prompt — Rebuild the Race screens to match Figma

> Paste into a **fresh chat** opened on `cubeclash-flutter` so `CLAUDE.md` auto-loads.
> Scope: presentation layer only. One session, one commit.

---

## 0. Task

The Race feature is functionally complete and well tested, but its **screens were
built before the Figma MCP was reachable** — they were inferred from design tokens
and prose, and they do not match the frames. Rebuild the presentation layer of the
Race feature to match Figma.

**Do not touch** `RaceBloc`, `RaceState`, `RaceEvent`, `RaceDto`, `RaceRoom`,
`FakeRaceGateway` or `SocketRaceGateway` unless a frame demands state the bloc
does not expose — and if it does, say so before changing it.

Read first:

1. `CLAUDE.md` — architecture, conventions, don'ts.
2. `tool/figma_icons.md` — the icon export pipeline and its two gotchas.
3. `lib/features/race/` — what exists.
4. Commit `7ab933c` — the Timer Home + nav shell Figma pass. **Follow that
   pattern exactly**; it is the reference for how this work is done here.

---

## 1. Figma

File key `agaSWydXRtfQIiN112f6wG`. Frames (dark → light):

| Screen | Dark | Light |
|---|---|---|
| Race Lobby · Quick Match | `33:106` | `45:287` |
| Race Lobby · Private | `33:188` | `45:369` |
| Race Lobby · Tournaments | `33:246` | `45:427` |
| Race · Ready room | `34:106` | `45:496` |
| Race · Live | `34:140` | `45:530` |
| Race · Result (Win) | `34:167` | `45:557` |
| Race · Result (Lose) | `39:106` | `45:590` |

Workflow per screen — this is mandatory, not a suggestion:

1. `get_design_context` on the node (the `figma-design-to-code` skill loads first
   and must be named in `skillNames`). It returns exact padding, radii, sizes,
   weights and token names.
2. Adapt to Flutter. **Never paste the React/Tailwind verbatim.**
3. Reuse `core/widgets` and `core/theme`. If a frame needs a value that isn't a
   token, add it to the token file with a comment saying which node it came from
   — do not inline a literal.
4. Export any icon the frame uses (see §3).
5. Regenerate that screen's goldens and **look at them** against the Figma
   screenshot before moving on.

`get_metadata` on a whole page will exceed the token limit — it gets saved to a
file you can grep. Prefer `get_design_context` on one frame at a time.

---

## 2. Known divergences to fix

Confirmed by inspecting `34:140` (Live). Treat this as a starting list, not the
whole list — check every frame yourself.

**Race · Live is a different screen from what is built.** Figma shows:

- A `● LIVE RACE` header, red dot + danger-coloured overline, with an **×** close
  affordance top-right.
- **Two side-by-side player cards**, equal weight, with `VS` between them. Each
  card: avatar circle, display name, country name (the word, e.g. `Uzbekistan`,
  not just a flag), and that player's live time in large type.
- `SAME SCRAMBLE` overline with the scramble beneath it, centred.
- `Tap anywhere to stop` centred in the lower half.
- **No hero timer.** **No progress bars.**

What is currently built instead: a scramble card at the top, one giant
`TimeText`, and two `LinearProgressIndicator` comparison bars. All of that goes.

The current `OpponentProgressBar` in `race_widgets.dart` is probably dead after
this — delete it rather than leaving it unused, and drop its tests.

Note the design implication and keep it: showing both clocks at equal weight is
what makes it read as a race. Don't reintroduce a hero timer for "your" time.

---

## 3. Icons

The frames use exported vectors, not Material glyphs. This mattered enough on the
Timer pass to be worth restating: the design system specifies **stroke 2, round
caps and joins**, which no icon font reproduces, and substituting Material icons
is what made the first pass read as subtly wrong everywhere.

For each icon in a frame:

1. Take the asset URL from the `get_design_context` response.
2. `curl -sL -o assets/icons/<name>.svg "<url>"`.
3. Normalise for flutter_svg, which cannot parse CSS custom properties:
   - `var(--stroke-0, #RRGGBB)` → the bare hex,
   - `width="100%" height="100%"` → the intrinsic size.
4. Add a case to `AppIcons` and a row to `tool/figma_icons.md`.

Asset URLs expire in ~7 days, so re-fetch rather than reusing an old link.
`AppIcon` tints via a `srcIn` filter, so one export serves every state.

---

## 4. Constraints that still hold

- **The server owns the outcome.** The bloc already never compares two times or
  computes an Elo change. Keep it that way — the result screens render
  `race:result`, they don't derive anything.
- Live Race stays a **full-screen route outside the shell** with `PopScope`
  blocking back mid-solve. That part is right; don't undo it.
- Every async surface keeps loading / empty / error.
- `MediaQuery.disableAnimations` must still suppress motion.
- Touch targets ≥ 48dp. The **×** close affordance in the Live header is the one
  most likely to fail this — a 20pt glyph needs padding out.
- Tokens only. No hardcoded colours, spacing or type.

---

## 5. Tests

The Race bloc tests (31) and most widget tests should survive untouched — that is
the point of not touching the bloc. Expect to rewrite:

- `test/features/race/race_page_test.dart` — the assertions that name the old
  layout (`find.text('YOUR TIME')`, the progress-bar tests, `Tap anywhere to
  stop` placement).
- `test/features/race/race_page_golden_test.dart` — regenerate all seven, and
  **read each PNG** rather than trusting a green run.

Add coverage for anything new the frames introduce (the × close, the country
label, whatever the lobby frames turn out to contain).

Watch for: a golden that renders real random data is non-deterministic. If a Race
frame ends up showing a scramble from the live scrambler, seed it — see
`test/core/router/nav_bar_test.dart` for the pattern.

---

## 6. Definition of done

```bash
dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test
```

Then:

- Update the "Current state" block in `CLAUDE.md`.
- Update `tool/figma_icons.md` with any new icons.
- Commit once, with a message that says **what diverged and why the frame's
  choice is better** — not just "matched Figma". See `7ab933c` for the bar.

Report at the end: which frames you inspected, what differed, and anything in the
frames that contradicts the vault or the bloc so it can be decided rather than
silently resolved.
