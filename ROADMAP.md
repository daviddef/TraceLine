# TraceLine — Roadmap

Status: 20 July 2026. **Version 1.0 is live on the App Store** (`READY_FOR_SALE`). Twenty
levels across two worlds, endless mode, ~4,000 lines of Swift, 128 unit tests + 5 UI.

This is the **post-launch enrichment phase**. The brief from here: *richer, more fun,
better graphics, more worlds*. The plan below is organised around those four, in the order
that compounds — a new world is worth more once the rendering it ships on is better, and
better rendering is worth more once there is a settings screen to let a weaker device turn
it down.

---

## The bet, restated for a shipped game

v1 answered the three founding questions well enough to ship. The open ones now are
different, and they are about depth rather than existence.

### More worlds — the headline ask

Two worlds teach two ideas (dodge, then lose control). A third is designed, and its
mechanic's engine core is already built and tested — this is the cheapest large win on the
board. **Worlds are the spine of "richer": each one is a new verb, not a new coat of
paint.** The discipline that got us here holds — a world must introduce a genuinely new
hazard or a test fails.

### Better graphics — the most-visible ask

The rendering is honest but flat: a stand-in glow made of a scaled translucent copy (the
code itself says "in production, use SKEffectNode with CIFilter for proper glow"), no depth
behind the play area, hazards that are solid shapes. Real bloom, an ambient background, and
richer hazard art are the highest visible-polish-per-hour available, and they lift every
screen at once rather than one feature.

### More fun — the felt ask

Fun is the hardest to schedule because it is the hardest to measure, but two things move it
cheaply and are already scaffolded: **audio** (every cue is marked, no asset has ever
existed — a line that hums and cracks is most of a game's feel) and **juice** (screen
shake on a cut, particles on a clear, a satisfying wave transition).

### Still true, still unmeasured

The difficulty curve is a model, not a measurement — headroom assumes ~400 pt/s sustained
drawing and nobody has been timed. And *never lift + never cross* still excludes players
with tremor or low dexterity, which is both the right thing to fix and the biggest untapped
featuring angle. Neither blocks the enrichment work, but both stay on the board.

---

## Design principles

Unchanged, and worth re-reading before adding anything.

1. **Your finger is the game.** Not a character, not a cursor.
2. **The line is the hazard.** Good additions make your past self more dangerous.
3. **Fair, and visibly so.** The trap must be visible before it springs.
4. **Failure is instant and unambiguous** — *or* it is a race you were given a chance to
   win. Never a coin flip.

---

## The spine: what each world takes from you

Naming this made World 3 obvious.

| World | Takes | The lesson |
|---|---|---|
| 1 — The Grid | Your **round** | Hazards end you. Learn to dodge. |
| 2 — The Field | Your **control** | The magnet bends your input. The line stops going where you point. |
| **3 — The Burn** | Your **line, over time** | The first hazard you can *beat* rather than merely avoid. |

Principle 4's second clause — "a race you were given a chance to win" — is written into the
principles and used by nothing. World 3 is where it becomes the whole point.

---

## World 3 — The Burn — **SHIPPED**

> *The board stops trying to end you and starts trying to outlast you.*

Built: the **Fuse** is a real hazard type with a three-layer flame icon; on contact it
ignites the line and a particle flame eats toward the fingertip, coverage retracting live,
until you reach a shelter. **Wind** is the second mechanic — a constant drift on every
drawn point, shown as directional streaks in the world's own colour. Ten levels (Tinder →
Cinder), climbing 348 → 526 pt/s, fuse spotlit at 21 and wind arriving at 24. Tests guard
that every fuse level has a shelter to escape to and that wind stays inside World 3. The
Fuse also joins endless at wave 15. Flame speed (190 pt/s) is a first guess and wants
real-device tuning — below the design notes for why.

The design that follows is the record of how it was reasoned, kept because the *why* is
worth more than the diff.

### The Fuse

Volfied (1989) solved this exact problem: rather than killing on contact, an enemy touching
your wire sends a **flame down the line**, and you race it to safety. Instant death becomes
a timed escape with agency. It is 45 years load-bearing.

It was blocked on TraceLine having nowhere to run. **Safe zones removed that blocker** —
so the shelters already built stop being a nice-to-have and become the point. That is the
most satisfying thing about this design: it retroactively upgrades a mechanic already
shipped.

**How it behaves**

- A Fuse falls like any hazard. Touching it does **not** end the round.
- On contact it **ignites the line at the point of contact**.
- A flame travels from there *toward your fingertip*, consuming line behind it. Coverage
  retracts as it goes — the player watches progress burn away.
- Reach a **safe zone** with your tip and the flame dies. You keep what is left.
- Let it reach your finger and the round ends.

**Why it fits the engine as built**

Almost all of it already exists:

| Needed | Already there |
|---|---|
| Remove line from one end | `DrawingEngine.cut(where:)` |
| Coverage retracts when points go | Coverage is recomputed live every frame |
| Hazard tested against the whole line, not just the tip | The Cutter does this |
| A shelter that stops a hazard | `SafeZone.contains` / `shelters(from:to:)` |
| Warning drawn on a doomed stretch | `LineNode.markDoomed` |

Genuinely new: a **burning state** — an index advancing along the path each frame, plus an
escape check against the safe zones.

**Decisions to settle by playing it**

- **Flame speed** must be slower than a player can draw, or it is not a race, it is a
  delayed death. Start generous, tighten.
- **Telegraphing is free here** — a visible flame eating a visible line satisfies principle
  3 without extra UI.
- **A Fuse level must have a reachable shelter.** That is a level-design constraint and
  belongs in a test, not a habit: assert every Fuse level has at least one safe zone.
- **Two fuses at once is probably one too many.** Cap it like cutters.

### Wind — the secondary mechanic

The Fuse alone is thin over ten levels. **Wind** pairs with it thematically and is cheap: a
constant drift applied to every recorded point, so the whole board pulls one way.
Mechanically it is the magnet's `pulled()` with a uniform vector instead of a radial one —
the hook already exists.

Wind feeds fire, so there is an obvious escalation where wind accelerates the flame in its
direction. That may be one interaction too many; treat it as optional.

### Level names

| | | | | |
|---|---|---|---|---|
| 21 Tinder | 22 Smoulder | 23 Firebreak | 24 Updraft | 25 Backdraft |
| 26 Ash | 27 Wildfire | 28 Scorched | 29 Inferno | 30 Cinder |

### The gate

`testEachWorldIntroducesSomethingNew` fails if World 3 ships without a new hazard type, and
`testDemandNeverStallsOrGoesBackwards` fails if it opens softer than level 20 closed. Both
working as intended: World 3 cannot be "World 2 with bigger numbers" without a red test.

---

## Now — the enrichment sequence

Ordered so each step compounds the next.

**Shipped (1.1):**

- ✅ **World 3 — The Burn.** The Fuse is a real hazard; wind is its second mechanic; ten
  levels. Designed in full below.
- ✅ **World 4 — The Dark.** Takes *sight*: the board goes black but for a torch on the
  drawing tip. Reuses every hazard; the only new tech is a crop-masked veil. Ten levels.
- ✅ **Ambient background + hazard art.** Depth behind the play area, and the plainest
  hazards (blocker → mine, mover → chevrons, shrinker → contracting diamond) given character.
- ✅ **Audio.** All five cues synthesized in code (`Tools/generate_audio.py`), played through
  an `.ambient` session that mixes with music and obeys the silent switch.
- ✅ **Juice.** Camera shake on cuts/ignites, particle bursts on clears and wave advances.
- ✅ **Settings + accessibility.** Sound toggle and a Reduce Motion switch that also honours
  the system setting.
- ✅ **UX overhaul.** Game over is now a translucent overlay that auto-restarts — no "Try
  Again" tap; a real pause button with Resume / Restart / Level Select / Home; and **Free
  Play**, a home entry that opens every world, level and theme (free for now, gate later).

**Next:**

1. **Better graphics: real bloom.** Replace the fake glow with an `SKEffectNode` +
   `CIGaussianBlur` bloom pass, gated behind a graphics quality setting (the Settings screen
   now exists to hold that toggle). Theme-limited to the dark palettes, so it degrades to the
   current look on light themes rather than fighting them.
2. **World 5 — the next thing to take.** W1 took the round, W2 control, W3 the line over
   time, W4 sight. A world must still introduce a genuinely new mechanic, not bigger numbers
   — candidates: hazards that *hunt* the tip (takes the safety of dodging), or a board whose
   space contracts (the shrinker escalated to a world).

Also shipped earlier: **endless mode** (below), and a difficulty curve rebuilt to be
measurably monotonic — now climbing unbroken across all four worlds (45 → 646 pt/s).

### Endless, as built

The design problem was that filling the board is a *dead end*: coverage counts cells the
line crosses, so a full board has nowhere legal left to draw. Reaching the target had to
become a doorway rather than a win.

So endless is **waves**. Clear the target, the board wipes, difficulty steps up, and the
line **restarts from wherever the finger already is** — without lifting. That makes a run
one unbroken stroke drawn across many boards rather than a series of attempts, which is a
better hook than "survive a board": not *how long can you last*, but *how long can you
avoid letting go*.

- Boards are generated per wave and **deterministic** — everyone's wave 7 is the same wave
  7, which is the only thing that makes a leaderboard mean anything.
- Hazards arrive one at a time in the order the levels teach them, so a player arriving
  from World 2 meets them in an order they already know.
- Difficulty climbs to wave 25 and then plateaus; past that a run is endurance at full
  tilt rather than ever-rising demand.
- Its own Game Center board (`traceline.endless.alltime`), and runs also post to the
  all-time board.
- Clearing faster banks more: the wave bonus pays out the clock you did not use.

## Next

5. **World 3 — The Burn.** The Fuse, wind, ten levels. Designed above.
6. **Daily seeded challenge.** One deterministic board per day, shared globally. Best
   evidence-to-effort ratio in the research, and it gives the leaderboard a reason to exist.
7. **Settings screen.** The wireframe has one; the architecture spec's file list does not,
   so it was never built. Accessibility toggles need somewhere to live, which makes this a
   dependency of item 4 rather than a nicety.
8. **Per-level leaderboards and personal bests on the map.** The map shows stars but not
   your best score. Cheap, and it makes replay legible.

## Later

9. **Decay mode.** The Snake variant: the tail dissolves as you draw, coverage drains, and
   the line stops being a permanent wall. It inverts the core tension from *the board fills
   up and you run out of room* to *outrun your own decay*. Must be a **named mode the
   player chooses** — you have to know which rules you are playing under before you start
   drawing.
10. **Async ghost racing.** Replay a friend's line over your own. Uses the Game Center
    integration already shipping; no servers.
11. **Tip jar.** `Core/Store.swift` is wired and inert. Turning it on needs products in App
    Store Connect, a paid-apps agreement, an updated IAP declaration, and UI. Expect 1–3%
    conversion at best; treat revenue as goodwill, not a plan.
12. **Analytics provider.** `Core/Analytics.swift` has the call sites and no SDK. Attaching
    one means revisiting the "data not collected" privacy declaration and PRIVACY.md.
13. **iPad layout.** Out of scope for v1; the play area is already normalised, so it is
    mostly HUD work.

---

## Feature catalogue

Everything considered, scheduled or not. Conviction is my own read, not measured.

### Modes

| Feature | Conviction | Note |
|---|---|---|
| Endless / survival | **High** | The only structural answer to a finite game |
| Daily seeded challenge | **High** | Wordle-shaped; makes the leaderboard matter |
| Practice / zen (no timer, no hazards) | **High** | Doubles as the accessibility on-ramp |
| Decay mode (dissolving tail) | Medium | Genuinely different game; needs its own tuning |
| Time attack (fixed board, fastest clear) | Medium | Cheap once per-level leaderboards exist |
| Mirror mode (draw one line, get two) | Low | Novel, but fights "the line is the hazard" |

### Mechanics

| Feature | Conviction | Note |
|---|---|---|
| The Fuse | **High** | World 3's headline; 45 years of precedent |
| Wind / global drift | Medium | Cheap — `pulled()` with a uniform vector |
| Collectibles on the board | Medium | A second objective competing with coverage |
| Boss levels (one large patterned hazard) | Medium | Good world finales; a lot of bespoke work |
| Portals | Low | Breaks the "one continuous line" reading |
| Slippery input (lag / smoothing) | Low | Reads as broken input, not as a mechanic |
| Line width as a variable | Low | Sounds harder; mostly just fiddly |

### Progression and meta

| Feature | Conviction | Note |
|---|---|---|
| Per-level personal bests on the map | **High** | Cheap; makes replay legible |
| Star-gated bonus levels | Medium | Gives stars a purpose beyond themes |
| More achievements | Medium | Three is thin for twenty levels |
| Streaks | Medium | 48% industry adoption, no public efficacy data |
| Theme packs beyond the four | Low | Only worthwhile if a tip jar exists to attach them to |

### Social

| Feature | Conviction | Note |
|---|---|---|
| Async ghost racing | Medium-high | No servers; uses what already ships |
| Share a clear as video | Medium | ReplayKit; strong organic reach for a visual game |
| Per-level leaderboards | Medium | Needed before time attack means anything |

### Polish

| Feature | Conviction | Note |
|---|---|---|
| Audio | **High** | Hooks exist, assets never did. Best ratio on the list |
| Level intro cards | Medium | "12 — Bend" before the round; sells the naming work |
| Richer pause overlay | Medium | Currently only reachable before a round starts |
| Win/fail screen animation | Low | Already decent |

### Accessibility

| Feature | Conviction | Note |
|---|---|---|
| Forgiveness radius on self-crossing | **High** | The single biggest exclusion today |
| Practice mode | **High** | Also a mode; also a featuring angle |
| Reduce Motion support | **High** | Line effects and scanlines should honour it |
| High-contrast theme | Medium | The four themes are aesthetic, not accessible |
| VoiceOver on menus | Medium | Menus are `SKLabelNode`s with no accessibility tree |
| Larger touch targets | Low | Not currently a complaint |

---

## Shipped since v1

Recorded because several of these were fixes to things that had quietly never worked.

- **Obstacles from level 2** rather than level 6. Coverage counts cells the line crosses,
  so on an empty board the optimal strategy is a serpentine sweep — half of World 1 was a
  drill with a stopwatch.
- **The Cutter**, and then the **doomed-tail preview**. The first playtest verdict was that
  a cut "feels like the game stole something". The lane was telegraphed but the
  *consequence* was not, so the fix was information, not mercy: the stretch about to be
  taken is now drawn live, which turns a cut from theft into a choice.
- **Safe zones.** Shelters that hazards rebound off. Placed by level design, because
  territory cannot be *earned* here — closing a loop means touching your own line, which is
  a crossing, which is a fail.
- **World 2 — The Field**, and **magnetic pull made real**. Magnetic shipped in v1 as a
  hazard that pulsed and had no engine effect whatsoever.
- **Shrinker actually spawns.** It shipped in v1 fully built, themed and rotating, and
  never once appeared because no level listed it.
- **The difficulty curve rebuilt.** Measured with the real coverage algorithm: six of ten
  steps in World 1 asked for nothing more than the step before, and level 11 dropped back
  to level 2's demand. Now monotonic, 45 → 332 pt/s.
- **The level map** as a trail the player draws, with named levels.
- **Eight line effects**, per level, deterministic.
- **Theme unlocks that mean something.** The screen promised "unlock themes by completing
  worlds" while the code handed over all three the instant level 10 fell.

---

## Explicitly not doing

- **UGC / level editor.** Coverage boards are near-trivial to author, so the ceiling is
  low, and moderation cost exceeds the value.
- **Multiplayer.** Out of scope in the brief, and a different game.
- **iCloud sync.** UserDefaults is sufficient; sync is a support burden for a game with no
  account.
- **Ads.** There are none, the listing says so, and "remove ads" as a monetisation lever is
  therefore unavailable by choice.

---

## Risks

**The difficulty curve is modelled, not measured.** Headroom assumes ~400 pt/s sustained
drawing and nobody has been timed. If the back half is unclearable, time limits scale
independently of the curve's shape — but this is the assumption most likely to be wrong.

**App Store review is mid-flight.** Version 1.0 is rejected pending a screen recording and
resubmission. Everything shipped since — World 2, the difficulty rebuild, line effects,
theme unlocks — is in the attached build and unreviewed.

**Three subsystems are inert by design and easy to forget.** `Store` (IAP shell),
`Analytics` (no provider), `SoundHook` (no assets). Each is wired, tested, and does nothing.
Any could ship "working" without anyone noticing it never fired — which is exactly how
Magnetic shipped as a hazard with no effect, and how Shrinker shipped and never appeared.
Tests now guard those two specific cases. The general lesson is that **wired and working
are different claims**, and only one of them can be verified by looking.
