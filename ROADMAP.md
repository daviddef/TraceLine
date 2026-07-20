# TraceLine — Roadmap

Status: 17 July 2026. v1 is built, tested, and on TestFlight as build `202607170816`.
The App Store listing is complete and waiting on submission.

---

## Where we are

**Shipped (v1, World 1).** The two rules, four fail conditions, coverage-and-timer win
condition, 10 levels, 4 themes, Game Center leaderboard and achievements, and the full
release pipeline. 50 unit tests, 5 UI tests.

**Blocked on a human, not on code:**

| | |
|---|---|
| App Privacy questionnaire | Web UI only, no API. Answer: data not collected |
| Submit for review | Everything else is in place |
| **Level 1 difficulty** | **Never validated by a real player. See Risks** |

---

## What the research changed

Six findings that should steer everything below. Full sourcing in the session; evidence
strength is called out because most published retention advice is vendor marketing with
no methodology behind it.

### 1. We are building a modern Qix — and nobody noticed

The brief benchmarks against 1LINE, Linelight and Snake. Those are line games, but the
actual ancestor is **Qix (1981)** and **Volfied (1989)**: cover a board with a
**vulnerable trail** that hazards attack. That is TraceLine's exact shape, and it means
45 years of solved problems are sitting there. Chief among them:

**Volfied's flame.** When an enemy touches your unfinished wire, it doesn't kill you — a
flame runs down the line and you race it to safety. Instant death became a timed escape
*with agency*. This is the proven answer to precisely the frustration the Cutter is
trying to solve, and it is strong precedent rather than opinion.

### 2. Obstacles are not garnish — they are the entire game

TraceLine's coverage counts cells the line passes through. That makes the optimal
strategy a **serpentine sweep**: back and forth, spaced one cell apart, until the bar
fills. It is mechanical and it is boring — and it is exactly what levels 1–5 ask for,
because they have no obstacles at all.

Obstacles are the only thing that breaks the sweep and forces a decision. So the
instinct that we under-built "objects in the way" is right, and it is more serious than
a missing feature: **half of World 1 is a chore with a stopwatch.** The fix is not only
new hazard types, it is introducing them far earlier than level 6.

### 3. Ten levels is a D7 cliff, structurally

GameAnalytics' 2026 cross-title telemetry (the one genuinely empirical source found):
median mobile D1 ~22%, **median D7 ~4%**, top decile ~12%. Arcade titles lead on D1 and
decay hardest. TraceLine is arcade-shaped, has ten levels, and no endless mode — so
there is nothing to retain anyone past day one. No cosmetic layer fixes a content wall.

### 4. True severing is rare — take that as a warning and a gift

Searching hard for prior art on a hazard that *cuts* the trail turned up almost nothing:
Paper.io, splix, slither all kill on trail contact. The nearest precedent is a designer
blog. Rare means differentiated, and it also means unproven — so the Cutter should be
prototyped and felt before it is scheduled.

### 5. The level map is folklore

World-map node trails are the dominant casual convention, but there is **no public A/B
evidence** they lift engagement. The only concrete claim found is inside a King UI
patent — evidence of a believed problem, not a measured effect. At ten levels a map is
cosmetic theatre. Named levels are the part that carries the value.

### 6. The monetisation lever we assumed is unavailable

"Remove ads" converts ~11% of iOS first-spenders — and is meaningless here, because
there are no ads to remove. What is left is a multi-tier **consumable tip jar** (best
practical evidence, though n=1) and cosmetic theme packs. Payer rates cluster at 2–5% of
DAU and that number is weakly sourced. Treat revenue as goodwill, not a plan.

**Bonus, and possibly the most valuable line in the research:** a rule set built on
*never lift* and *never cross* punishes hand tremor and low dexterity brutally. A
forgiveness radius and an obstacle-free practice mode would open the game to players who
currently cannot play it at all — and accessibility is the single biggest untapped App
Store featuring angle.

---

## Design principles

1. **Your finger is the game.** Not a character, not a cursor.
2. **The line is the hazard.** Good additions make your past self more dangerous.
3. **Fair, and visibly so.** The trap must be visible before it springs.
4. **Failure is instant and unambiguous** — *or* it is a race you were given a chance to
   win. Never a coin flip.

---

## Now — the next build

### Hazards that cost instead of kill

Every obstacle today is a wall: touch it, round over. Two additions, both softenings:

**The Cutter** *(your idea, and it was in the original research as "Eraser — deletes a
section of your drawn line if touched", dropped when HANDOVER trimmed five obstacle types
to four).*

A Cutter travels a **visible lane** across the board — a track, a trail, a flight path.
Where it crosses your line, it severs it. The piece attached to your fingertip survives;
the rest is gone. You are not killed, you are set back. Draw across the tracks and the
train keeps taking it from you.

*Why it fits the engine:* coverage is recomputed every frame from the live point array,
so deleting points automatically retracts the coverage bar. The punishment is already
wired — the player watches progress physically retreat.

*And the trap:* if coverage ever became a cumulative "cells ever touched" set — an
obvious-looking optimisation — the Cutter would **invert into a reward**, because a
shorter line means fewer walls and more freedom at no cost. The mechanic depends on
coverage staying live. This needs a test pinning it.

*Open decisions:* severed line vanishes (rather than lingering as a dead wall —
otherwise it punishes twice); freed space is redrawable, so a cut costs *time*, not
permanent progress; a player boxed in by their own line could deliberately take a cut to
escape, which is either skill expression or an exploit — playtest before deciding.

**The Fuse** *(Volfied, 1989)* — the higher-conviction one. Instead of a blocker killing
on contact, it **ignites your line** and a flame runs down it toward your finger. Reach
safety and you live. Same hazard, but the player gets a chance and a story.

One type, four skins: Neon gets a light-cycle, Clay a beetle, Retro a train.

### Rebalance World 1

Obstacles from level 2, not level 6. Levels 1–5 are currently a serpentine drill.

### Named levels

Cheap, and the part of the "fun map" ask the evidence actually supports:

| | | | | |
|---|---|---|---|---|
| 1 Warm Up | 2 Room to Move | 3 Tight Quarters | 4 The Long Way | 5 Breathing Room |
| 6 Company | 7 Traffic | 8 Crossfire | 9 Rush Hour | 10 Gridlock |

The scattered node map is deferred, not rejected — see Later. At ten levels it is
theatre; at thirty it earns its keep.

---

## Exploring: safe zones

> "Safe zones, where objects rebound off and you can hide."

The most interesting idea on this list, for three reasons.

### 1. It fixes the deepest problem in the game

Finding 2 above: coverage counts cells the line passes through, so on an empty board the
optimal strategy is a serpentine sweep. Every hazard so far is a *thing to dodge* on that
empty board — none of them change its shape. Safe zones are the first proposal that makes
the board **terrain**. Obstacles rebounding off them turns an empty field into a place
with structure, and a sweep stops being either optimal or possible.

That is worth more than another hazard type.

### 2. It unlocks the Fuse

I said earlier that Volfied's flame doesn't port, because racing a burning line to safety
presupposes a **safe zone** and TraceLine has none. That objection dies the moment this
exists. Safe zones are the missing primitive the whole Qix lineage is built on, and they
make the 1989 solution available to us.

### 3. It is the mirror of the Cutter

The Cutter makes you **spend line**. A safe zone makes you **spend time** — shelter costs
seconds against a clock you cannot pause. Two costs, opposite currencies, same decision:
is this worth it? That symmetry is the sign of a mechanic that belongs.

### The constraint nobody can design around

**You can never enclose an area**, so territory cannot be *earned* the Qix way. Touching
your own line is a crossing, and a crossing ends the round — closing a loop is by
definition a fail. Qix claims territory by sealing a region against an edge; TraceLine
structurally cannot.

So zones are **placed by level design**, not won. That is a smaller idea than Qix's, and
it is the only one the rules permit.

### How it would work

- **Obstacles rebound.** A zone is solid to hazards; they bounce off it. This is what
  makes zones read as terrain rather than as a UI overlay.
- **Cutters cannot enter, so zones cast shadows.** A zone blocking a lane clips that
  cutter's remaining sweep — line beyond it is out of reach. The doomed-tail preview
  already computes from `remainingSweep`, so it would show these shelters **for free**,
  with no new code.
- **Your line is safe inside.** That is the hiding.

### The two ways it goes wrong

- **Camping.** If hiding is free, hide. It isn't free: the clock runs and the coverage
  target is most of the board, so shelter always costs progress. That tension is the
  mechanic — but it needs playtesting, not confidence.
- **Free coverage.** If cells inside a zone count toward the target, a big zone is a safe
  farm and the game is over. Zones must be **small refuges, not fields** — or coverage
  inside them shouldn't count at all. Sizing is the whole balance question.

### Open question

Static pockets are the cheap, rules-compatible version. The richer one is an
**edge-anchored** claim: a line run from one board edge to another divides the board, and
the smaller side becomes safe. That is Qix, it is legal under rule 2 (no loop is closed —
the edges do the sealing), and it would be a far bigger change to the win condition.
Worth prototyping the cheap one first and seeing whether the idea has legs.

## Next

- **Endless mode.** The highest-conviction bet in the research: the only structural
  answer to a ten-level D7 cliff. Board never ends, hazards escalate, one score.
- **Accessibility pass.** Forgiveness radius, practice mode, tremor tolerance.
- **World 2 (levels 11+)** — the brief's own next milestone. **Shrinker** is already
  built, themed and rotating, and has never appeared on screen because no level lists it.
  **Magnetic pull** likewise: the research specced it to *pull the line*, HANDOVER
  downgraded it to "visual only", so today it pulses and does nothing. The pull is the
  interesting half.
- **Audio.** `SoundHook` marks every cue; no assets exist. Best polish-per-hour on the
  list.

---

## The fading tail — a mode, not a flourish

Proposed alongside the cosmetic line effects: "some lines slowly start disappearing at the
tail end". The other suggestions (rainbow, sparks) are decoration. This one is not, and it
is worth keeping separate.

The same `points` array is three things at once: the wall you must not cross, the coverage
that scores you, and what gets drawn. So a vanishing tail can only mean one of:

1. **Fades visually, still blocks and still counts.** An invisible wall — it breaks design
   principle 3 outright. Not an option.
2. **Genuinely removed.** Coverage retracts as it goes, and your line stops being a
   permanent obstacle. That is a different game: the tension inverts from "the board fills
   up and you run out of room" to "outrun your own decay". It is Snake, and it is good —
   but it is not this game's rules.
3. **Removed as a wall, kept as coverage.** Needs a separate claimed-cells set, which is
   precisely the change flagged under the Cutter as inverting that mechanic into a reward.

Option 2 is the interesting one and deserves to exist as a **named mode** the player
chooses, not a surprise attached to random levels. A player must know which rules they are
playing under before they start drawing.

## World 3

Worlds are data now: `worlds.json` plus a `world` on each level, one trail per world.
A third world is content, not surgery — but a test fails if it introduces no hazard the
previous world did not have, because "the last world with bigger numbers" is precisely
what the research says will not hold anyone.

The obvious candidate is the **Fuse** (Volfied, 1989): a hazard that ignites your line and
burns it toward your finger while you race for a shelter. It was blocked on there being
anywhere to run — safe zones fixed that. It is the last big idea on the list with 45 years
of proof behind it.

## Later

- **Daily seeded challenge.** One deterministic board per day, shared globally —
  Wordle-shaped, cheap, and it gives the leaderboard a reason to exist.
- **Async ghost racing.** Replay a friend's line over your own. Uses the Game Center
  integration already shipping; no servers.
- **The level map**, once there are enough levels to justify it.
- **Tip jar** — multi-tier consumable. `Core/Store.swift` is already wired and inert;
  turning it on needs products, a paid-apps agreement, an updated IAP declaration and UI.
- **Settings screen.** The wireframe has one; the architecture spec's file list does not.
- **Pause overlay** currently works only before a round starts.

**Explicitly not doing:** UGC/level editor (coverage boards are trivial to author;
moderation cost exceeds the value), multiplayer, iCloud sync, iPad.

---

## The difficulty curve

Measured, not guessed. `DifficultyCurveTests` runs a serpentine through the real coverage
algorithm and reports what each level actually asks for. Two things fell out of that:

**Passes needed ≈ targetCoverage × gridSize.** Coverage counts cells the line crosses, so
a serpentine of R rows on an N×N grid covers about R/N. That makes `gridSize` exactly as
strong a difficulty lever as the target percentage, and it means **target coverage alone
is not a difficulty ranking** — 0.65 on a 20-grid and 0.65 on a 32-grid are different
games. Both are now set together to land a chosen number of passes.

**The old curve stalled and reset.** Measured: levels 2‑3‑4 all asked 7 passes, 5‑6 both
10, 9‑10 both 13, and level 11 dropped back to 7 — identical to level 2. Six of ten steps
in World 1 asked for nothing new, and World 2 spent until level 17 climbing back to where
World 1 ended.

The spine is now **required drawing speed**, which combines how much board you must fill
with how long you get. It climbs 45 → 332 pt/s across the twenty levels (previously
45 → 133), and time headroom tightens from about 9× down to 1.2×.

**Teaching a mechanic is not the same as lowering difficulty** — this was got wrong once
and enforced with a test. World 2 opens *harder* than World 1 closed; the magnet gets its
spotlight by being nearly the only hazard on the board at level 11, not by making the
board easy. A test now permits thinning the hazard mix only when a genuinely new hazard is
being introduced.

**Unvalidated:** the headroom figures assume a sustained drawing speed of about 400 pt/s.
That is a model, not a measurement — nobody has been timed. If the back half proves
impossible, the fix is to scale the time limits; the shape of the curve is independent of
that constant.

## Risks

**Level 1 has never been played by a human.** 50% coverage of a 15×15 grid in 60 seconds,
no lifting, no crossing — and, per finding 2, with no obstacles it is a pure serpentine
drill. The maths is right and the tests pass; "correct" and "fun" are different claims
and only one has been checked. A reviewer who cannot clear level 1 is a plausible 2.1
rejection. It is one line in `levels.json`.

**The whole difficulty curve is unvalidated.** It was written from a spec, never felt.

**The Cutter is unproven.** Nobody ships it. Prototype and play it before committing.
