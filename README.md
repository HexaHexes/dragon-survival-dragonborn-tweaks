# Dragon Survival Dragonborn Tweaks

A Paxi datapack for the **Tensura RPG** pack (MC 1.21.1) with two Dragon Survival gameplay tweaks for dragonborn.

## What it changes

### 1. Dragonborn size → 2.0 blocks
Dragonborn in young/adult/ancient stages are shrunk so they fit a standard **1×2 doorway**, via a `generic.scale` modifier of **`-0.3333`** applied in the three stage files:

- `data/dragonsurvival/dragonsurvival/dragon_stage/dragonborn_young.json`
- `data/dragonsurvival/dragonsurvival/dragon_stage/dragonborn_adult.json`
- `data/dragonsurvival/dragonsurvival/dragon_stage/dragonborn_ancient.json`

### 2. Claw slots disabled
`data/dragonsurvival/tags/dragonsurvival/dragon_species/no_claw_slots.json` removes claw slots for all 6 active species (plus `required: false` entries for currently disabled addon species — bee queen, brain stealer dragon, claw monster, realistic spider, griffin, slime dragon — so they're covered if re-enabled later).

## Dependencies

| Requirement | Notes |
|---|---|
| Dragon Survival (`dragonsurvival`) | All files target the `dragonsurvival` namespace — meaningless without it |
| Paxi | Auto-loads the pack from `config/paxi/datapacks/` |

No other mods are required; tag entries for absent addons are `required: false` and are simply skipped.

## Tuning

- Scale: change `-0.3333` in the three `dragon_stage/*.json` files (`-0.3333` ≈ 2.0 blocks tall).
- Species: add/remove entries in `no_claw_slots.json`.

## Install

Copy this folder (or the unzipped pack) to:

```
<instance>/config/paxi/datapacks/dragon-survival-dragonborn-tweaks/
```

Paxi loads it automatically; no restart beyond the usual world reload.

## Editing workflow

This repository is the source of truth. The copy inside the CurseForge instance's `config/paxi/datapacks/` is the deployed version — after editing here, re-copy the folder over the deployed one.
