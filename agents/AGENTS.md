# Agent rules and conventions - Dragon Survival Dragonborn Tweaks

**Repo:** `HexaHexes/dragon-survival-dragonborn-tweaks` | **Branch:** `main`
**Type:** Paxi **pack** - one folder/zip that is both a datapack (`data/`) and a
resource pack (`assets/`). No Gradle, no jar, no Java.
**Formats:** data 48, resource 34, declared via `supported_formats` 34-48 in
`pack.mcmeta` so the same zip loads in both places (MC 1.21.1).

Dragonborn parity and mana-growth tweaks for Dragon Survival, shipped as a Paxi
pack that auto-loads from `config/paxi/datapacks/` **and**
`config/paxi/resourcepacks/` (the same file goes to both folders).

**Dependencies**
- Required: Dragon Survival (`dragonsurvival`) - all files target the
  `dragonsurvival` namespace. Paxi - auto-loads the pack.
- Optional DS addons (see the allowlist below): their content is overlaid
  conditionally; without the addon, their stage files sit dormant and their
  species entries are skipped by conditions or `required: false` tags.

**What it changes**
- **Dragonborn size -> 2.0 blocks** (`generic.scale` -0.3333 on all four
  dragonborn stages).
- **Vanilla interaction range** for dragonborn: `add_value` 0 on both
  `minecraft:player.entity_interaction_range` and
  `minecraft:player.block_interaction_range` in all four dragonborn stage
  files (the dragonborn addon declares no range ladder, so DS's code default
  of 8.5 blocks leaked through; the zero declarations must stay `add_value`
  to match the code default's operation).
- **Dragonborn stage parity (Option A, rename-shift):** the ladder mirrors the
  dragon ladder byte-for-byte on ranges and ticks - newborn 10-25/216000,
  young 25-40/432000, adult 40-60/1728000, ancient 60-300/69120000. Health
  ladders move with the ranges (0/3/6 base at +0.2/growth, so HP-at-growth is
  unchanged); the new dragonborn ancient top mirrors dragon ancient health
  (20.5 base, +0.5/growth). Existing saves need a one-time growth adjust via
  the DS growth editor.
- **Spider ancient stage** (`realistic_spider_ancient`, growth 90-300, ticks
  848000): the adult stage's modifier ladders continued at the same rates,
  `is_default: false`, no natural growth. Three stages after spiderling now.
- **Mana growth curve** overlaid on every ladder: core dragons, dragonborn,
  mega_typhus, griffin, bee_queen, brain_stealer_dragon, claw_monster,
  realistic_spider (see "Mana curve" below).
- **Claw slots disabled** via the
  `tags/dragonsurvival/dragon_species/no_claw_slots.json` tag for all active
  species (plus `required: false` entries for currently disabled addon
  species).

**Version:** lives in `pack.mcmeta` - the `pack.description` string carries a
`vX.Y.Z` suffix (e.g. `... - v1.0.0`). Bump it there, not in a
`gradle.properties`.

---

## Addon classification (three buckets)

Species/stage-owning addons - the ONLY targets of stage overlays and data-map
extensions:
- `ds_dragonborn_cave_forest_sea` (dragonborn_cave/forest/sea)
- `griffin_ds` (griffin: hatchling/fledgling/juvenile/adult)
- `bee_queen_ds` (bee_queen)
- `desert_monster_ds` (claw_monster)
- `brain_stealer_dragon` (brain_stealer_dragon)
- `ds_realistic_spider` (realistic_spider)
- `slime_dragon_addon` (slime_dragon - ships no stage files, rides the core
  ladder; no overlay exists or is needed)
- `megarria_dragons_addon` (mega_typhus)

Infrastructure/compat - part of the DS ecosystem but own no species or stages;
never overlay them:
- `dragonborn_lib`, `dragon_survival_iaf_integration`, `corpsedragonsurvival`

Not DS at all - do not touch, despite the names:
- Ice and Fire (`IceAndFireCE`), `mechadragon`, `IceandfireUltimateOptimization`,
  `seadwellers`

The overlay table in `tools/generate-content.ps1` is an explicit allowlist of
species and stage ids. Never scan jar filenames or `data/` trees to decide
what to overlay.

## Generator (single source of truth)

- `tools/generate-content.ps1` derives everything under `data/` and `assets/`
  that comes from DS or its addons, reading the mod jars directly (paths at
  the top of the script; the instance `mods/` folder is the source of truth).
- On a DS or addon update: update the jar path(s) in the script, re-run it,
  lint, and commit the regenerated files. Do not hand-edit generated files.
- Hand-maintained files: `pack.mcmeta`, `no_claw_slots.json`, `ci.yml`,
  `AGENTS.md`, `README.md`, `tools/`.

**Asset reuse rule:** a new stage (newborn or ancient) always reuses the
previous stage's skins, icons and default_parts. Never author new textures.
The generator copies them by construction - keep it that way.

**stage_resources merge rule:** NeoForge data maps merge per key across packs
with the default overwrite merger (topmost pack wins per key, whole value).
So our `stage_resources.json` ships FULL blocks for the four species we
extend (`dragonborn_cave/forest/sea`, `realistic_spider`) - a partial block
would drop the addon's own young/adult/ancient entries. Keys we do not touch
are left to their own files. If an addon updates its stage_resources entries,
re-run the generator.

**Species overrides are condition-guarded:** every species file we override
carries a `neoforge:mod_loaded` condition for its addon, so the file stays
inert when the addon is absent. Stage files are vanilla-reference-only and
stay unconditionally (dormant ids are harmless).

## Mana curve

- The `dragonsurvival:mana` attribute has base 1.0, so modifiers contribute
  (pool - 1.0) at a stage's minimum growth.
- Gain/point per ladder stage, interpolated between 0.08 (first stage) and
  0.342 (final stage): 4-stage ladders use 0.08 / 0.1675 / 0.255 / 0.342;
  3-stage ladders (spider) use 0.08 / 0.211 / 0.342.
- The pool chain starts at 10 at the first stage's min growth and grows by
  gain x span: a 4-stage dragon-style ladder ends near 101 at growth 300.
  The XP bonus from `mana_handling` (up to +9) rides on top; spider zeroes
  its `mana_handling`, so its curve is the whole pool.
- Ladders with odd ranges (griffin caps at 50, bee_queen young ends at 30)
  simply follow their own per-file growth ranges; gains are per stage
  ordinal, not per growth value.

## Gotchas

- **No Gradle and no jar** - the build gate is a JSON lint (`ci.yml`), not a
  compile. There is nothing to `gradlew build` or tag a jar for.
- This is a datapack, so "release" = tagging the repo; there is no
  `mod_version` file.
- Editing workflow: this repo is the source of truth; re-copy the folder over
  the deployed copies inside the instance's `config/paxi/datapacks/` AND
  `config/paxi/resourcepacks/` after editing here. One folder, both places.
- Scale tuning: change `-0.3333` in the generator's dragonborn stage table
  (`-0.3333` -> 2.0 blocks tall). Species: add/remove entries in
  `no_claw_slots.json`.
- Interaction-range zeroing must stay `add_value` - DS merges stage modifiers
  per attribute+operation against its code defaults.
- Any ancient stage we add reuses the previous stage's assets. Always.

---

## Branch sync (do this first)

Before starting any new development in this repo:

1. `git status` - confirm what uncommitted work exists. Never disturb or sweep it.
2. `git pull --ff-only` - sync with the remote. A fast-forward is the normal case,
   because we push straight to the shared branch.
3. If the pull would **not** fast-forward (the branch has diverged), or if it would
   collide with local uncommitted work, **stop and ask** rather than merging, rebasing
   or stashing on your own.

## Scope doctrine

- **One mod + bundled datapack.** No KubeJS scripts.
- **Data-driven over code** - prefer JSON/datapack content to Java when both work.
- **Public API only, no mixins** in the colony-gear-style addon mods. Sanctioned
  exception: `ds-tensura-fix` (tensura-dragon-skin-rebalance), a mixin fix mod by design.

## Verification

- This repo has no GameTests; the gate is the JSON lint (run the same loop as
  `ci.yml` locally, or `jq empty` per file) plus the user's in-game check.
- Client-render and stage-registry behavior cannot be proven headless. The
  honest scope is "lint green + the user's in-game check" - say so rather than
  overclaiming. Verify with an addon-absent clean `/reload` and an
  addon-present ladder check per species.

## Build environment

- PowerShell 5.1+ on Windows; the generator writes BOM-free UTF-8.
- JDK 21 (`JAVA_HOME` -> JDK 21) exists for other repos but is unused here.

## PowerShell quirks (this org is developed on Windows)

- A `git push` "error" in PowerShell is usually stderr passthrough - success is the
  `hash..hash  branch -> branch` line, not the absence of red text.
- `New-Object Type(args)` breaks on arithmetic - use `::new()` or a parenthesized
  argument.
- Never use `Set-Content -Encoding UTF8` (writes a BOM); use
  `[System.IO.File]::WriteAllText` with `UTF8Encoding($false)`.
- No PS5 ternary; keep generated JSON ASCII-escaped.

## Git & release

- Remote is SSH: `git@github.com:HexaHexes/<name>.git`.
- Push only after tests are green **and** the user has given the go.
- Never sweep the user's uncommitted work into a commit - commit only what is intended.
- Commit subjects: concise, imperative.

## House style

- **No icons** unless the user explicitly asks. Icons are being removed across all repos.
- **No emojis, ever.** Prohibited in all code, docs, configs, and commit messages.
- READMEs are **player-facing only**: pitch, mechanics in plain terms, in-game usage,
  required/optional dependencies, credits, license. No build internals, no class names.
- All repos are **LGPL v2.1**, copyright Bitwise Madness. `NOTICE` / attribution files
  are mandatory and must never be deleted.
- Deploy to the Tensura RPG instance **only** when the user asks.

## CI & release model

- `ci.yml` lints **all** JSON under `data/` and `assets/` plus `pack.mcmeta`, and
  enforces the **version-bump guard**: a beta or stable bump must change the
  version file and nothing else; an `-alpha` bump may bundle work; a PR labelled
  `breaking` forces the next clean bump to raise the major or minor version.
- **Build and GameTest jobs are deferred** (they belong to the mod repos). This
  datapack repo's "build" is a zip, so it has a working `release.yml` that tags
  and publishes on a version bump.
- `version-bump.yml` opens an isolated version-bump PR (only the version file changes).
- CurseForge publishing (`curseforge.yml`) is **deferred** until a mod has a CurseForge
  listing and the `CURSEFORGE_PROJECT_ID` / `CURSEFORGE_API_KEY` secrets. Do not add it
  speculatively.
- Where a release workflow exists, alpha/nightly publishing is opt-in via the
  `ALPHA_RELEASES` repo variable and is **off** by default.
