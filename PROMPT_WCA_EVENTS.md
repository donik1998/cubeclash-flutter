# Prompt — Support the full WCA event set (big cubes and beyond)

> Paste into a **fresh chat** opened on `cubeclash-flutter` so `CLAUDE.md` auto-loads.
> This is a **design + domain-model** task before it is a coding task. Expect to
> propose before you build.

---

## 0. Task

CubeClash currently assumes one shape of puzzle: an NxN cube, scrambled by
space-separated single-face moves, solved in a handful of seconds, averaged with
Ao5/Ao12. `PuzzleSpec` knows `3x3`, `2x2` and `4x4`; `CubeFaceIcon` knows
`nxn | pentagon | triangle`.

We are committing to **every official WCA event**. That assumption breaks in
four independent places, and the interesting work is in handling those honestly
rather than forcing 17 events through a 3×3-shaped UI.

**Start with a written proposal, not code.** Read the codebase, work out what
the event model has to become, and put the decisions in §4 to me before
implementing.

Read first: `CLAUDE.md`, `lib/features/timer/domain/`, `lib/core/widgets/cube_face_icon.dart`,
`lib/features/timer/domain/usecases/compute_averages.dart`, and commit `7ab933c`
for how Figma work is done here.

---

## 1. The event set

The 17 official WCA events, with their competition format:

| Event | Format | Notes |
|---|---|---|
| 2×2, 3×3, 4×4, 5×5 | Ao5 | the current assumption |
| 6×6, 7×7 | **Mo3** | mean of 3, no trimming |
| 3×3 One-Handed | Ao5 | same puzzle, different discipline |
| Clock | Ao5 | not a twisty puzzle at all |
| Megaminx | Ao5 | dodecahedron |
| Pyraminx | Ao5 | tetrahedron |
| Skewb | Ao5 | corner-turning cube |
| Square-1 | Ao5 | shape-shifting |
| 3×3 Blindfolded | **Bo3** | best of 3 |
| 4×4 / 5×5 Blindfolded | **Bo3** | |
| 3×3 Fewest Moves | **Mo3** | result is a **move count**, not a time |
| 3×3 Multi-Blind | **Bo1** | result is `solved/attempted in time` |

**Verify this table against the current WCA Regulations before relying on it.**
It is written from memory and formats do change; §9 of the Regulations is the
authority. Treat a mismatch as a bug in this document, not in the Regulations.

---

## 2. The four things that break

### A. A scramble is not a space-separated list of face turns

Current model: `String scramble`, rendered by splitting on spaces.

That is wrong for most of the set:

- **Megaminx** is written as ~7 lines of ~11 moves (`R++ D-- R++ D-- … U`), and
  **the line breaks are semantic** — cubers read and execute it line by line.
  Reflowing it as one paragraph makes it materially harder to follow.
- **Square-1** is slash-separated pairs: `(1,0)/(6,0)/(-3,0)/…`. Splitting on
  spaces is meaningless.
- **Clock** uses a different alphabet entirely (`UR1+ DR2- … y2 U'`) plus pin
  states.
- **Multi-Blind** is *N separate scrambles*, one per cube — a list, not a string.
- **Big cubes** are just long: ~60 moves for 5×5, ~80 for 6×6, ~100 for 7×7.

At the current `AppTypography.scramble` (19/28) in a ~350pt card, a 7×7 scramble
runs to roughly ten lines and swallows the screen. The scramble card cannot stay
a fixed block.

Work out what replaces `String scramble` — a structured type carrying lines
and/or tokens, most likely — and how the card adapts: type ramp by length, a
collapsed/expanded state, a scroll region, or something better. Whatever you
pick, **Megaminx line breaks must survive** and **Square-1 must not be split on
spaces**.

Note this crosses a layer boundary: `Solve.scramble`, `SolveDto`, the `/solves`
contract and the race protocol all carry the scramble as a string today. Decide
whether the wire format stays a string (with the client parsing per event) or
becomes structured — and say which, because the backend has to agree.

### B. A result is not always a time under a minute

- `TimeText.format` handles `m:ss.cc` but not hours. Multi-Blind attempts run up
  to **60 minutes**.
- `AppTypography.timerHero` is 78px. `0.00` is four glyphs; `5:23.45` is seven;
  a Multi-Blind `58:12.00` is eight. At 78px tabular Noto Serif that overflows
  the content width. The hero needs to scale to its content rather than clip or
  wrap.
- **Fewest Moves has no time at all** — the result is a move count (e.g. `28`).
  The entire timer interaction is wrong for it; it needs a number entry.
- **Multi-Blind** is a compound result: `11/13 in 54:22`.

So `Solve.timeMs` is not a sufficient result model either. Work out what it
becomes, and keep `effectiveTimeMs` meaning something sensible for penalties
(a +2 on an FMC result is nonsense; a DNF is not).

### C. Averaging is per-event

`ComputeAverages` already has `average(times, n)` (trimmed) and `mean(times, n)`
(untrimmed). What is missing is the notion that **the event chooses the format**:
Ao5 for most, Mo3 for 6×6/7×7/FMC, Bo3 for the blindfolded events.

The session stat cards on Timer Home currently read `best / ao5 / ao12`. Decide
what they read for a 6×6 — the competition format (`mo3`), the practice
statistics people actually track (`ao5`/`ao12`), or both. There is a real
argument either way; make it and write it down.

### D. Icons and the event picker

`PuzzleShape` covers `nxn | pentagon | triangle`. Missing: Skewb, Square-1,
Clock, and the *modifier* events (Blindfolded, One-Handed, Fewest Moves,
Multi-Blind) which are the **same puzzle with a different discipline**.

Seventeen bespoke icons is the wrong answer. A base shape plus a modifier badge
composes far better and matches how cubers name the events (`3BLD` is a 3×3, one
hand is a 3×3). Propose the composition model.

Then: a 17-item bottom sheet is not a picker. It needs grouping (NxN · other
puzzles · blindfolded · special) and probably search or recents. Pull the frame
if Figma has one; design it from the tokens if not, and say which you did.

---

## 3. Race implications

Racing is currently tuned for a ~10-second solve. A 7×7 race is a four-minute
commitment; a Multi-Blind race is an hour.

Think through, and propose:

- Which events are even raceable. Restricting quick-match to short events at
  first is a defensible answer — just make it a decision, not an accident.
- The disconnect **grace window** and opponent-progress cadence, both currently
  sized for short solves.
- What the matchmaking wait means when the pool for `6x6 quick match` is
  realistically empty.

`RaceBloc` should not need structural change for this — check whether that holds.

---

## 4. Decisions to bring me before implementing

1. The scramble model — structured type vs string, and what the **wire format**
   becomes (the backend has to match).
2. The result model — how FMC move counts and Multi-Blind compound results fit
   beside `timeMs`.
3. What the session stat cards show per event format.
4. The icon composition model (base shape + modifier badge, or your alternative).
5. Which events are raceable at launch.
6. Whether non-NxN **scramblers** are in this piece of work or a separate one —
   see §5.

---

## 5. Scope warning: scramblers are a separate mountain

`GenerateScramble` is a random-move scrambler with NxN redundancy rules. It
extends to 5×5/6×6/7×7 straightforwardly (more faces, more wide layers, more
moves).

It does **not** extend to Megaminx, Square-1, Clock, Skewb or Pyraminx — each has
its own notation, its own legality rules, and in several cases needs a solver to
produce competition-legal random-*state* scrambles. The vault already lists
"full random-state WCA-legal scrambles via two-phase solver" as roadmap.

**Recommendation:** this piece of work covers the **event model, result model,
UI and icons** for all 17 events, plus random-move scramblers for the NxN family.
For the rest, ship the event with an honest "scrambles coming" state — the same
pattern as the `WCA comps` scramble source on Timer Home, which says what it
can't do instead of quietly serving something else. Do not fake a Megaminx
scramble with 3×3 moves.

Push back if you disagree, but say so before building.

---

## 6. Constraints

- Domain stays pure Dart. No Flutter or IO in `features/*/domain/`.
- Tokens only — if a frame needs a value that isn't one, add it to the token file
  with a comment naming the source node.
- Server owns competitive truth: `is_pb`, Elo, rank. Adding events changes none
  of that.
- Every async surface keeps loading / empty / error.
- Icons come from Figma exports where frames exist — see `tool/figma_icons.md`.
  Never hand-author an icon file.
- The scrambler's invariants are tested heavily and are a portfolio talking
  point. Extending it must not weaken them; add cases, don't relax rules.

---

## 7. Definition of done

```bash
dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test
```

Expect substantial new domain tests: format-per-event selection, the scramble
model round-tripping Megaminx line breaks and Square-1 pairs, result formatting
across seconds/minutes/hours/move-counts, and NxN scrambler invariants at 5×5,
6×6 and 7×7.

Then update `CLAUDE.md` (event model, result model, what's supported vs
"scrambles coming"), update the README status table, and commit — separating the
domain/model change from the UI change if that keeps the diffs reviewable.

Report at the end: which events are fully supported, which are present but
awaiting scramblers, and anything the WCA Regulations say that contradicts this
document.
