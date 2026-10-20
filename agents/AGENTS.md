# Agent rules and conventions â€” Dragon Survival Dragonborn Tweaks

**Repo:** `HexaHexes/dragon-survival-dragonborn-tweaks` Â· **Branch:** `main`
**Type:** Paxi **datapack** (no Gradle, no jar, no Java) Â· **Pack format:** 48 (MC 1.21.1)

Two Dragon Survival gameplay tweaks for dragonborn, shipped as a Paxi datapack that
auto-loads from `config/paxi/datapacks/`.

**Dependencies**
- Required: Dragon Survival (`dragonsurvival`) â€” all files target the `dragonsurvival`
  namespace. Paxi â€” auto-loads the pack. No other mods required; tag entries for absent
  addons are `required: false` and are skipped.

**What it changes**
- **Dragonborn size â†’ 2.0 blocks** so they fit a 1Ã—1 doorway: a `generic.scale`
  modifier of `-0.3333` in the three `dragon_stage` files
  (`dragonborn_young`, `dragonborn_adult`, `dragonborn_ancient`).
- **Claw slots disabled** via the
  `tags/dragonsurvival/dragon_species/no_claw_slots.json` tag for all 6 active species
  (plus `required: false` entries for currently disabled addon species).

**Version:** lives in `pack.mcmeta` â€” the `pack.description` string carries a
`vX.Y.Z` suffix (e.g. `... â€” v1.0.0`). Bump it there, not in a `gradle.properties`.

**Gotchas**
- **No Gradle and no jar** â€” the build gate is a JSON lint (`ci.yml`), not a compile.
  There is nothing to `gradlew build` or tag a jar for.
- This is a datapack, so "release" = tagging the repo; there is no `mod_version` file.
- Editing workflow: this repo is the source of truth; re-copy the folder over the
  deployed copy inside the instance's `config/paxi/datapacks/` after editing here.
- Scale tuning: change `-0.3333` in the three `dragon_stage/*.json` files
  (`-0.3333` â‰ˆ 2.0 blocks tall). Species: add/remove entries in `no_claw_slots.json`.

---

## Branch sync (do this first)

Before starting any new development in this repo:

1. `git status` â€” confirm what uncommitted work exists. Never disturb or sweep it.
2. `git pull --ff-only` â€” sync with the remote. A fast-forward is the normal case,
   because we push straight to the shared branch.
3. If the pull would **not** fast-forward (the branch has diverged), or if it would
   collide with local uncommitted work, **stop and ask** rather than merging, rebasing
   or stashing on your own.

## Scope doctrine

- **One mod + bundled datapack.** No KubeJS scripts.
- **Data-driven over code** â€” prefer JSON/datapack content to Java when both work.
- **Public API only, no mixins** in the colony-gear-style addon mods. Sanctioned
  exception: `ds-tensura-fix` (tensura-dragon-skin-rebalance), a mixin fix mod by design.

## Verification

- The in-repo GameTest run is the **only** CI gate. Never verify against a live
  CurseForge instance.
- Keep `expectedTests` in `build.gradle` in sync with the `@GameTest` methods.
- **Client-render features cannot be proven headless.** The honest scope is
  "build green + the user's in-game check" â€” say so rather than overclaiming.

## Build environment

- JDK 21 (`JAVA_HOME` -> JDK 21); the toolchain targets Java 21.
- The Gradle wrapper is committed. `./gradlew build` compiles, `./gradlew runGametest`
  (or `runGameTestServer`) runs the GameTest server.
- `libs/` (compile-only) and `testmods/` (runtime closure) are **gitignored** staging
  folders. Never commit third-party jars.
- On `run/` file-lock errors, kill any stale `java` process and retry.

## PowerShell quirks (this org is developed on Windows)

- A `git push` "error" in PowerShell is usually stderr passthrough â€” success is the
  `hash..hash  branch -> branch` line, not the absence of red text.
- `New-Object Type(args)` breaks on arithmetic â€” use `::new()` or a parenthesized
  argument.

## Git & release

- Remote is SSH: `git@github.com:HexaHexes/<name>.git`.
- Push only after tests are green **and** the user has given the go.
- Never sweep the user's uncommitted work into a commit â€” commit only what is intended.
- Commit subjects: concise, imperative.

## House style

- **No icons** unless the user explicitly asks. Icons are being removed across all repos.
- READMEs are **player-facing only**: pitch, mechanics in plain terms, in-game usage,
  required/optional dependencies, credits, license. No build internals, no class names.
- All repos are **LGPL v2.1**, copyright Bitwise Madness. `NOTICE` / attribution files
  are mandatory and must never be deleted.
- Deploy to the Tensura RPG instance **only** when the user asks.

## CI & release model

- `ci.yml` runs on pull requests: a build job and a GameTest job. Both assert a
  non-zero result â€” a run that passes vacuously (0 tests) is a failure.
- `release.yml` runs on every push to the default branch, re-runs the tests, and â€” only
  when the version was bumped â€” tags and publishes a GitHub release with a cumulative
  changelog. Alpha/nightly publishing is opt-in via the `ALPHA_RELEASES` repo variable
  and is **off** by default.
- `version-bump.yml` opens an isolated version-bump PR (only the version file changes).
  Beta/stable bumps must not carry other changes; `-alpha` bumps may bundle work.
- CurseForge publishing (`curseforge.yml`) is **deferred** until a mod has a CurseForge
  listing and the `CURSEFORGE_PROJECT_ID` / `CURSEFORGE_API_KEY` secrets. Do not add it
  speculatively.

