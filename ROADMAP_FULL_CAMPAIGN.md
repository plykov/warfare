# GARDEN RECLAIMED — Roadmap to a Full-Scale Single-Player Campaign

## What this document is

Phases 2–6 turned a 12-mission campaign slice into a 16-mission one with full art/audio, accessibility, and
viewmodel fidelity. This document is the next level up: not a milestone scope ready to hand to Codex, but a
map of what actually has to change — architecturally and in production process — to grow this from "a
polished slice" into "a full-scale single-player FPS campaign" (order-of-magnitude: 40–80+ missions, real
mid-campaign progression, enough enemy/encounter variety to sustain that length without repetition).

Every claim below is grounded in the current code, not assumed. Where something is a hard constraint from
`CLAUDE.md`'s invariants, it's called out explicitly — this roadmap does not propose violating any of them
without flagging it as a decision, not a default.

---

## The honest bottleneck list

Read directly from the code, ordered by how hard each one blocks "bigger campaign" specifically:

### 1. Arena variety caps out at 9 recipes, and challenge trials already share one
`world/chapter_arena.gd::recipe_for()` is a hand-authored `match` statement — 9 hard-coded chapters (8 core
+ the Covenant Gauntlet added in Phase 6). Every one of the 8 post-campaign challenge trials (missions 9-16)
already renders the *same* 9th arena. Appending mission 17, 18, ... 80 under the current design means either
authoring dozens more hand-built recipes (linear cost, doesn't scale) or accepting that most of the campaign
plays out in one repeated space. **This is the single biggest structural blocker to "bigger campaign."**

### 2. Rank progression caps at chapter 8 and never moves again
`RankSystem`: `rank_index = clampi(mission.chapter - 1, 0, RANKS.size() - 1)`, `RANKS.size() == 8`. Every
mission from chapter 9 onward manifests at the same maximum rank, "ONE OF THE SEVEN." A longer campaign
built on the current chapter-driven rank model has no mid-campaign power curve past mission 8 — the *entire*
back half of a 40+ mission campaign would play at max rank with nothing new to earn. New Game+
(`GameState.ng_plus_multiplier()`, capping at `1.6×` after enough cycles) is the only progression lever past
that point today, and it's a difficulty multiplier, not new capability.

### 3. Enemy roster is three archetypes plus one generic boss
`enemies/`: `DemonEnemy`, `FallenEnemy`, `SyntheticEnemy` (all `extends EnemyBase`), plus
`TerritorialPrince` (data-driven bosses via `configure(kind, title, power)`). Three enemy types is enough
variety for 16 missions layered with objective/pressure differences; it is not enough to carry 40-80 missions
of moment-to-moment combat without every encounter feeling like a reskin of the same three fights.

### 4. Mission content is 100% hand-authored data, one `.tres` file per mission
`GameState.MISSION_PATHS` is a literal `PackedStringArray` of file paths; each mission is a fully
hand-tuned `MissionResource` (corruption pattern/seed, full Intercessor voice timeline, objective
composition, balance numbers verified by hand against `balance_sim.gd`). This has been the actual authoring
cost of every content phase so far — Phase 5's 4 missions were a full milestone's worth of work. Scaling
this linearly to 40-80 missions means 40-80x that authoring cost with no leverage gained.

### 5. The 12-weapon roster is locked by design, not oversight
`CLAUDE.md` Invariant 3: "Weapons never reload and all twelve are carried at once." This isn't a gap to
close — it's a deliberate design commitment already reflected everywhere (`WeaponManager`'s fixed
`WEAPON_PATHS`, the no-reload cadence, Phase 4's per-weapon viewmodel work). A bigger campaign should
*not* assume more weapons are coming. Whatever makes a longer campaign feel fresh has to come from enemies,
arenas, objectives, and encounter pressure — not a growing arsenal.

### 6. No mid-campaign meta-progression exists
There's no unlock, upgrade, currency, or loadout-customization layer at all. The 12 weapons are always all
available (by design, see #5); the only knobs that change over a campaign are `mission.chapter`-driven rank
cosmetics/silhouette (caps at 8) and NG+'s difficulty multiplier (a post-completion loop, not a
mid-campaign one). A much longer campaign without *some* new thing to earn periodically risks feeling flat
by mission 20, regardless of content volume.

---

## What actually has to happen — grouped by leverage, not by calendar

### A. Make content authoring scale sub-linearly (the load-bearing piece)

The corruption system is already closer to procedural than it looks: `CorruptionDirector.initial_value_for_cell()`
takes a `pattern` (8 named archetypes today), a `seed`, and a `bias`, and deterministically produces a
distinct field for *any* seed — this is already proven to generate unique, distinct signatures per mission
(`_test_authored_corruption_layouts` asserts every mission's signature is unique across all 16 today, purely
from pattern+seed combinatorics). That means the corruption-field half of "new mission" is already
effectively free at scale. The genuinely expensive parts are: arena geometry (bottleneck #1), and
hand-tuned balance/narrative content (bottleneck #4).

**Recommended approach, in order:**
1. **Solve arena variety first** (see B below) — nothing else matters if every mission still funnels into
   one repeated space.
2. **Build a semi-procedural mission composer**: given a target difficulty band, generate `objective_ids`
   combinations (already a closed, safe set of 6 primitives — combinatorially there are already dozens of
   valid multi-objective combinations, most unused today), pick a corruption pattern+seed, and derive
   `enemy_budget`/`enemy_power`/`spawn_interval`/`target_purity` from `balance_sim.gd`'s existing formulas
   rather than hand-guessing them per mission — the simulator already *proves* fairness for a given set of
   inputs, so it can also be used as the generator's sanity gate, not just its checker.
3. **Keep hand-authored content for the things that need a human**: title, briefing, scripture reference,
   Intercessor voice lines — these are the actual creative content of a mission and shouldn't be
   templated/generated. This is the same split Phase 5/6 already implicitly used (data composed from locked
   primitives, prose hand-written) — formalize it into tooling instead of repeating it by hand every phase.

### B. Solve arena variety without hand-building 40+ recipes

Two real options, not mutually exclusive:
- **A larger authored library, built once**: instead of one arena per mission, build a modest library
  (say, 6-10 more distinct recipes beyond the current 9) and have missions *select* from the library by
  tag/theme rather than own a 1:1 bespoke arena. This directly fixes bottleneck #1's "8 challenge trials
  share one space" problem without infinite authoring cost.
- **Procedural arena composition from existing primitives**: `chapter_arena.gd::_box()` already proves an
  arena is just a list of positioned/sized boxes with a glow value. A constrained generator (place N
  structures respecting the existing central-clearance rule, vary heights/footprints within tested bounds)
  could produce arbitrarily many distinct, valid arenas from the same authored building blocks Phase 6 used
  by hand for the Covenant Gauntlet. This is a genuinely new system, not a content pass — scope it as its
  own milestone with real design work, not a quick add-on.

Either path needs the same underlying fix: `ChapterArena`'s `CHAPTER_LABELS`/`CHAPTER_TINTS`/`recipe_for()`
triad currently *is* the campaign structure (chapter index ties to rank, label, tint, and geometry all at
once). A bigger campaign needs these decoupled — arena selection, rank progression, and mission identity
should be three independent axes, not one shared index.

### C. Give the campaign a progression curve that doesn't cap at mission 8

This is the one that most needs a real product decision before scoping, not just an engineering pass:
- **Option 1 — extend the rank ladder.** Add ranks beyond "ONE OF THE SEVEN," each with new visual
  silhouette work (`RankManifestation`'s pattern already supports this structurally) and a new passive
  (`RankSystem.PASSIVES`). Keeps the existing chapter-driven model, just makes the ladder longer.
- **Option 2 — decouple progression from rank entirely.** Introduce a separate campaign-length progression
  axis (e.g., accumulating "authority" or similar) that unlocks new *enemy pressure profiles*, arena
  library entries, or Intercessor content over the course of a long campaign, independent of the fixed
  8-rank cosmetic ladder. More flexible, but a bigger design lift — this is closer to the "new gameplay
  system" option that got set aside back at the Phase 5 direction question.
- **Option 3 — accept a flat late-game and lean entirely on encounter/mission variety.** Valid if the bet
  is that arena/enemy/objective variety (A and B above) is enough to sustain interest without a growing
  power curve — cheapest option, but real risk that a 40+ mission campaign feels like NG+ grinding earlier
  than it should.

This needs a decision before any of it is scoped in detail — it's not something to default into.

### D. Enemy roster depth

Three archetypes is thin at scale. `EnemyBase`'s contract (`ai_state`, `spreads_corruption`,
`uses_projectiles`, integrity/attack tuning) already supports meaningfully different subclasses — this is a
tractable, well-scoped content-engineering milestone once arena/progression direction (B, C) is settled,
not a blocker to start on now. Recommend 3-5 new archetypes with genuinely different combat verbs (not just
reskinned stat variants of Demon/Fallen/Synthetic), each following the same `EnemyBase` extension pattern
the existing three already prove out.

### E. Production/process scaling this whole project has been dodging so far

Not code changes, but real costs that compound as content volume grows:
- **Balance verification at scale.** `balance_sim.gd`'s 3-profile matrix already runs per mission; at
  40-80 missions this is still cheap computationally, but *human* review of "does this feel right" (the
  subjective gates every phase has flagged and left open) does not scale the same way. A longer campaign
  needs a real playtesting cadence, not per-milestone spot checks by whoever's available.
- **CI runtime.** Headless test/smoke/campaign/balance runs will grow with content volume; worth watching
  before it becomes a bottleneck on iteration speed, not urgent yet at today's scale.
- **Asset budget.** The CC0-sourced art/audio pipeline scales fine for *reused* assets (shared textures,
  pooled cue players) but a genuinely bigger game likely wants more visual distinction than "everything is
  Kenney Castle Kit + KayKit" can provide indefinitely — worth a decision point once arena variety (B) is
  underway, not before.

---

## Suggested sequencing

This is a recommendation, not a commitment — the real first step is picking a direction for **C** (the
progression-curve decision), since it changes the shape of almost everything else:

1. **Decide C** (progression model) — blocks meaningful scoping of B and D.
2. **B — arena variety** (library or procedural, per C's outcome) — unblocks all future content growth,
   highest leverage single investment.
3. **D — enemy roster depth** — can start in parallel with B once a couple of new arenas exist to fight in.
4. **A — mission composer tooling** — built once B/D give it enough building blocks to compose from
   meaningfully; this is what actually makes 40-80 missions affordable instead of 40-80x the Phase 5 cost.
5. **E — process** — starts informally now (this is already partially happening via the subjective-gate
   tracking every phase doc records), formalizes once content volume makes ad hoc review insufficient.

None of this needs to happen before the next phase — Phase 7 can still be a normal-sized milestone (more
enemy archetypes, or a first arena-library pass) using the same process this project already runs. This
document exists so that milestone gets chosen with the actual bottleneck in view, not chosen blind.
