# Dragon Survival Dragonborn Tweaks

A **datapack + resource pack** for Dragon Survival that makes dragonborn a full
racing option in a normal base: a shorter dragonborn with the same four growth
stages as dragons, vanilla-sized interaction range, no claw slots - plus a
mana growth curve for every playable race, including addon races, and a new
ancient stage for spiders.

## What it changes

### 1. Dragonborn fit through doors

Dragonborn at every stage (newborn, young, adult, ancient) are shrunk to
**2 blocks tall**, so they fit a standard 1x2 doorway without crouching or
clipping.

### 2. Dragonborn stage parity with dragons

Dragonborn now grow through the same four stages as dragons, over the same
growth ranges and growth times:

| Stage | Growth range | Growth time |
|---|---|---|
| Newborn | 10 - 25 | 6 in-game days |
| Young | 25 - 40 | 12 in-game days |
| Adult | 40 - 60 | 48 in-game days |
| Ancient | 60 - 300 | 1920 in-game days |

Health growth at a given growth value is unchanged from before; the ladder
simply extends into the new ancient top (20.5 + 0.5 health per growth, same as
ancient dragons). Existing dragonborn characters need **one-time growth
adjustment** with the Dragon Survival growth editor after updating.

### 3. Vanilla interaction range

Dragonborn keep the normal player interaction range (3 blocks) at every stage.
Without this pack, dragonborn silently inherit an 8.5-block reach.

### 4. Mana growth for every race

Every playable race - core dragons, dragonborn, and the addon races (griffin,
bee queen, brain stealer, claw monster, mega typhus, realistic spider) -
now grows its mana pool with growth: small at first, accelerating toward the
end of the ladder, reaching about 100 mana at the growth cap. Spiders get the
same curve with no experience bonus on top.

### 5. Spider ancient stage

Spiders grow through **spiderling -> adult -> ancient**. The ancient stage
(90 - 300 growth) continues the adult stage's stats at the same rate. It uses
the adult stage's look and growth icon.

### 6. Claw slots disabled

Removes the claw equipment slots for all species. Entries for currently
disabled addon species (bee queen, brain stealer dragon, claw monster,
realistic spider, griffin, slime dragon, mega typhus) are included too, so
they're covered if those addons return.

## Getting it in-game

No configuration needed - it just applies once installed (see below).
Relevant addons unlock their content automatically: the dragonborn species
need the dragonborn addon, the spider ancient stage needs the spider addon.

## Dependencies

| | Requirement | Notes |
|---|---|---|
| **Required** | [Dragon Survival](https://www.curseforge.com/minecraft/mc-mods/dragon-survival) | All files target its namespace - meaningless without it |
| **Required** | [Paxi](https://www.curseforge.com/minecraft/mc-mods/paxi) | Auto-loads the pack from `config/paxi/datapacks/` and `config/paxi/resourcepacks/` |
| **Optional** | [DS Dragonborn - Cave, Forest & Sea](https://www.curseforge.com/minecraft/mc-mods/ds-dragonborn-cave-forest-sea) | Dragonborn species, stage parity and newborn stage |
| **Optional** | [Dragon Spider Queen](https://www.curseforge.com/minecraft/mc-mods/ds-realistic-spider) | Spider ancient stage |
| **Optional** | Other DS race addons (griffin, bee queen, claw monster, brain stealer, Megarria) | Mana growth curve for those races |

No other mods are required - content for absent addons is skipped.

Made for the **Tensura RPG** pack (Minecraft 1.21.1).

## Install

Copy this folder (or the unzipped pack) to **both** places:

```
<instance>/config/paxi/datapacks/dragon-survival-dragonborn-tweaks/
<instance>/config/paxi/resourcepacks/dragon-survival-dragonborn-tweaks/
```

The same folder serves as datapack and resource pack - Paxi loads it
automatically, just reload the world.

## Credits

- Built for [Dragon Survival](https://www.curseforge.com/minecraft/mc-mods/dragon-survival), loaded by [Paxi](https://www.curseforge.com/minecraft/mc-mods/paxi).

## License

GNU Lesser General Public License v2.1 - see [`LICENSE`](LICENSE).
Copyright (c) 2026 Bitwise Madness.
