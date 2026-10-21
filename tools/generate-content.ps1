#requires -version 5.1
<#
  Single-source generator for the dragon-survival-dragonborn-tweaks pack.

  Everything under data/ and assets/ that derives from Dragon Survival or its
  addons is generated here, straight from the mod jars (source of truth), so a
  DS or addon update can be absorbed by re-running this script:

      powershell -ExecutionPolicy Bypass -File tools\generate-content.ps1

  What it emits
  -------------
  - Stage overlays: every ladder stage file from DS core + addons, verbatim
    from the jar, plus one dragonsurvival:mana add_value modifier (the mana
    curve). Covers: core dragons, mega_typhus, griffin, bee_queen,
    brain_stealer_dragon, claw_monster, realistic_spider (spiderling/adult).
  - Dragonborn parity ladder: dragonborn_newborn/young/adult/ancient rebuilt
    to the dragon ranges (10/25/40/60/300), with the health ladder shifted
    along, a 2-block scale, vanilla interaction range (add_value 0 on both
    player interaction attributes), and the mana curve.
  - Spider ancient stage (realistic_spider_ancient, 90-300): the adult file
    continued at the same modifier rates, plus the mana curve.
  - Species overrides: dragonborn_cave/forest/sea (4-stage progression) and
    realistic_spider (3-stage progression), each with a neoforge mod_loaded
    guard so they stay inert when the addon is absent.
  - stage_resources data map: full per-species blocks for the four species we
    extend (data maps merge per key with the default overwrite merger, so a
    partial block would drop the addon's own stage entries), adding
    newborn/ancient entries that reuse the previous stage's skins and icons.
    No new textures are ever authored.
  - Lang keys for the two new stages, and default_parts files (copied from the
    stage they reuse assets from, with the stage id rewritten).

  Mana curve
  ----------
  The mana attribute has base 1.0, so the modifier must contribute (pool - 1.0)
  at a stage's minimum growth. Per stage of a ladder, gains/point are
  interpolated between 0.08 (first stage) and 0.342 (final stage), so early
  stages are generous and the final stage carries the long end of the curve:
      4 stages: 0.08 / 0.1675 / 0.255 / 0.342
      3 stages: 0.08 / 0.211  / 0.342
  The pool chain starts at 10 mana at the first stage's min growth and grows by
  gain * stage span, reaching roughly 101 at growth 300 on a 4-stage ladder
  (the XP bonus from mana_handling rides on top; spider zeroes it out).
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
$ModsDir = 'C:\Users\kurok\curseforge\minecraft\Instances\Tensura RPG\mods'
$RepoRoot = Split-Path $PSScriptRoot -Parent

$Jars = @{
    core    = Join-Path $ModsDir 'DragonSurvival-1.21.1-v2.0.71-25.09.2026-all.jar'
    db      = (Get-ChildItem $ModsDir -Filter 'ds_dragonborn_cave_forest_sea-*.jar' | Select-Object -First 1).FullName
    spider  = (Get-ChildItem $ModsDir -Filter 'ds_realistic_spider-*.jar' | Select-Object -First 1).FullName
    mega    = (Get-ChildItem $ModsDir -Filter 'Megarria_Dragons_Addon*.jar' | Select-Object -First 1).FullName
    griffin = (Get-ChildItem $ModsDir -Filter 'griffin_ds-*.jar' | Select-Object -First 1).FullName
    bee     = (Get-ChildItem $ModsDir -Filter 'bee_queen_ds-*.jar' | Select-Object -First 1).FullName
    claw    = (Get-ChildItem $ModsDir -Filter 'desert_monster_ds-*.jar' | Select-Object -First 1).FullName
    brain   = (Get-ChildItem $ModsDir -Filter 'brain_stealer_dragon-*.jar' | Select-Object -First 1).FullName
    # slime_dragon_addon (SlimeThroneExtras) ships no stage files; it rides the
    # core ladder, so it needs no overlay.
}
foreach ($k in @($Jars.Keys)) {
    if (-not $Jars[$k] -or -not (Test-Path $Jars[$k])) { throw "Missing mod jar for '$k' under $ModsDir" }
}

$StagesPath = 'data/dragonsurvival/dragonsurvival/dragon_stage'
$SpeciesPath = 'data/dragonsurvival/dragonsurvival/dragon_species'
$DataMapPath = 'data/dragonsurvival/data_maps/dragonsurvival/dragon_species/stage_resources.json'
$LangPath = 'assets/dragonsurvival/lang/en_us.json'
$PartsPath = 'assets/dragonsurvival/skin/default_parts'

$ManaAttr = 'dragonsurvival:mana'
$ManaPoolStart = 10.0        # attribute pool at the first stage's min growth
$ManaAttrBase = 1.0          # DS registers the mana attribute with base 1.0
$ManaGainFirst = 0.08        # gain/point at ladder stage 1
$ManaGainLast = 0.342        # gain/point at the ladder's final stage

$Written = New-Object System.Collections.ArrayList

# ---------------------------------------------------------------------------
# JSON writer (PowerShell 5.1-safe: no ConvertTo-Json quirks, ASCII-escaped)
# ---------------------------------------------------------------------------
function Write-JsonString([System.Text.StringBuilder]$sb, [string]$s) {
    [void]$sb.Append('"')
    foreach ($ch in $s.ToCharArray()) {
        $c = [int]$ch
        switch ($c) {
            34 { [void]$sb.Append('\"'); break }
            92 { [void]$sb.Append('\\'); break }
            8  { [void]$sb.Append('\b'); break }
            9  { [void]$sb.Append('\t'); break }
            10 { [void]$sb.Append('\n'); break }
            12 { [void]$sb.Append('\f'); break }
            13 { [void]$sb.Append('\r'); break }
            default {
                if ($c -lt 32 -or $c -gt 126) { [void]$sb.Append(('\u{0:x4}' -f $c)) }
                else { [void]$sb.Append($ch) }
            }
        }
    }
    [void]$sb.Append('"')
}

function Format-JsonDouble([double]$d) {
    if ($d -eq [Math]::Truncate($d) -and [Math]::Abs($d) -lt 1E15) {
        return $d.ToString([System.Globalization.CultureInfo]::InvariantCulture) + '.0'
    }
    return $d.ToString('G15', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Write-JsonValue([System.Text.StringBuilder]$sb, [object]$v, [int]$depth) {
    if ($null -eq $v) { [void]$sb.Append('null'); return }
    if ($v -is [string]) { Write-JsonString $sb $v; return }
    if ($v -is [bool]) { [void]$sb.Append($(if ($v) { 'true' } else { 'false' })); return }
    if ($v -is [long] -or $v -is [int]) {
        [void]$sb.Append(([long]$v).ToString([System.Globalization.CultureInfo]::InvariantCulture)); return
    }
    if ($v -is [double] -or $v -is [decimal] -or $v -is [float]) {
        [void]$sb.Append((Format-JsonDouble ([double]$v))); return
    }
    $indent = '  ' * $depth
    $inner = '  ' * ($depth + 1)
    if ($v -is [System.Collections.IDictionary]) {
        $entries = @($v.GetEnumerator())
        if ($entries.Count -eq 0) { [void]$sb.Append('{}'); return }
        [void]$sb.Append('{')
        for ($i = 0; $i -lt $entries.Count; $i++) {
            [void]$sb.Append([char]10); [void]$sb.Append($inner)
            Write-JsonString $sb ([string]$entries[$i].Key)
            [void]$sb.Append(': ')
            Write-JsonValue $sb $entries[$i].Value ($depth + 1)
            if ($i -lt $entries.Count - 1) { [void]$sb.Append(',') }
        }
        [void]$sb.Append([char]10); [void]$sb.Append($indent); [void]$sb.Append('}')
        return
    }
    if ($v -is [System.Collections.IEnumerable]) {
        $items = @($v)
        if ($items.Count -eq 0) { [void]$sb.Append('[]'); return }
        [void]$sb.Append('[')
        for ($i = 0; $i -lt $items.Count; $i++) {
            [void]$sb.Append([char]10); [void]$sb.Append($inner)
            Write-JsonValue $sb $items[$i] ($depth + 1)
            if ($i -lt $items.Count - 1) { [void]$sb.Append(',') }
        }
        [void]$sb.Append([char]10); [void]$sb.Append($indent); [void]$sb.Append(']')
        return
    }
    $props = @($v.PSObject.Properties)
    if ($props.Count -eq 0) { [void]$sb.Append('{}'); return }
    [void]$sb.Append('{')
    for ($i = 0; $i -lt $props.Count; $i++) {
        [void]$sb.Append([char]10); [void]$sb.Append($inner)
        Write-JsonString $sb $props[$i].Name
        [void]$sb.Append(': ')
        Write-JsonValue $sb $props[$i].Value ($depth + 1)
        if ($i -lt $props.Count - 1) { [void]$sb.Append(',') }
    }
    [void]$sb.Append([char]10); [void]$sb.Append($indent); [void]$sb.Append('}')
}

function Write-JsonFile([string]$relPath, [object]$obj) {
    $sb = New-Object System.Text.StringBuilder
    [void](Write-JsonValue $sb $obj 0)
    [void]$sb.Append([char]10)
    $full = Join-Path $RepoRoot $relPath
    $dir = Split-Path $full -Parent
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    [System.IO.File]::WriteAllText($full, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    [void]$Written.Add($relPath)
}

# ---------------------------------------------------------------------------
# Jar access
# ---------------------------------------------------------------------------
function Get-JarJson([string]$jarKey, [string]$entryPath) {
    $jar = $Jars[$jarKey]
    $z = [System.IO.Compression.ZipFile]::OpenRead($jar)
    try {
        $e = $z.Entries | Where-Object { $_.FullName -eq $entryPath } | Select-Object -First 1
        if (-not $e) { throw "Entry '$entryPath' not found in $jar" }
        $ms = New-Object System.IO.MemoryStream
        $s = $e.Open()
        $s.CopyTo($ms)
        $s.Close()
        $text = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
    } finally {
        $z.Dispose()
    }
    return $text | ConvertFrom-Json
}

function Copy-Properties([object]$src, [string[]]$skip) {
    $out = [ordered]@{}
    foreach ($p in $src.PSObject.Properties) {
        if ($skip -contains $p.Name) { continue }
        $out[$p.Name] = $p.Value
    }
    return $out
}

# ---------------------------------------------------------------------------
# Mana curve helpers
# ---------------------------------------------------------------------------
function New-ManaModifier([double]$poolAtStageMin, [double]$minGrowth, [double]$gain) {
    # Attribute pool = base 1.0 + modifier, so the modifier contributes
    # (pool - 1.0); the linear amount evaluates base + gain * (growth - 1).
    $base = [Math]::Round(($poolAtStageMin - $ManaAttrBase) - $gain * ($minGrowth - 1.0), 6)
    return [ordered]@{
        amount    = [ordered]@{
            type                  = 'minecraft:linear'
            base                  = $base
            per_level_above_first = $gain
        }
        attribute = $ManaAttr
        operation = 'add_value'
    }
}

# Four-gain curve shared by every 4-stage ladder; 3-stage ladders use the
# first, middle and last values by interpolation.
$Gains4 = @(0.08, 0.1675, 0.255, 0.342)
$Gains3 = @(0.08, 0.211, 0.342)

# ---------------------------------------------------------------------------
# 1. Stage overlays: jar file verbatim + mana modifier
# ---------------------------------------------------------------------------
function Add-LadderOverlay([string]$jarKey, [string]$filePrefix, [string[]]$stageNames, [double[]]$gains, [double]$poolStart, [string]$nestedAncientEntry) {
    $pool = $poolStart
    for ($i = 0; $i -lt $stageNames.Count; $i++) {
        $name = $stageNames[$i]
        $id = "$filePrefix$name"
        if ($nestedAncientEntry -and $name -eq 'ancient') {
            $src = Get-JarJson $jarKey $nestedAncientEntry
        } else {
            $src = Get-JarJson $jarKey "data/dragonsurvival/dragonsurvival/dragon_stage/$id.json"
        }
        $min = [double]$src.growth_range.min
        $max = [double]$src.growth_range.max
        $gain = $gains[$i]
        $modifiers = @($src.modifiers) + @(,(New-ManaModifier $pool $min $gain))
        $out = Copy-Properties $src @('modifiers')
        $out['modifiers'] = $modifiers
        Write-JsonFile "$StagesPath/$id.json" $out
        $poolAtMax = $pool + $gain * ($max - $min)
        Write-Host ("  {0,-36} gain={1,-7} mana {2,7:N2} -> {3,7:N2}  growth {4}-{5}" -f $id, $gain, $pool, $poolAtMax, $min, $max)
        $pool = $poolAtMax
    }
    return $pool
}

$CoreAncientEntry = 'data/dragonsurvival/datapacks/ancient_stage/data/dragonsurvival/dragonsurvival/dragon_stage/ancient.json'

Write-Output '== Stage overlays (verbatim from jar + mana modifier) =='
Add-LadderOverlay 'core'    ''             @('newborn', 'young', 'adult', 'ancient')              $Gains4 $ManaPoolStart $CoreAncientEntry | Out-Null
Add-LadderOverlay 'mega'    'mega_typhus_' @('newborn', 'young', 'adult', 'ancient')              $Gains4 $ManaPoolStart $null | Out-Null
Add-LadderOverlay 'griffin' 'griffin_'     @('hatchling', 'fledgling', 'juvenile', 'adult')       $Gains4 $ManaPoolStart $null | Out-Null
Add-LadderOverlay 'bee'     'bee_queen_'   @('newborn', 'young', 'adult', 'ancient')              $Gains4 $ManaPoolStart $null | Out-Null
Add-LadderOverlay 'brain'   'brain_stealer_' @('newborn', 'young', 'adult', 'ancient')            $Gains4 $ManaPoolStart $null | Out-Null
Add-LadderOverlay 'claw'    'claw_monster_' @('newborn', 'young', 'adult', 'ancient')             $Gains4 $ManaPoolStart $null | Out-Null
# Spider is a 3-stage ladder: spiderling and adult come from the jar, the new
# ancient stage continues the adult file below. Capture the chain pool after
# adult so the ancient stage continues the same curve.
$spiderPoolAfterAdult = Add-LadderOverlay 'spider' 'realistic_spider_' @('spiderling', 'adult') $Gains3 $ManaPoolStart $null

# ---------------------------------------------------------------------------
# 2. Dragonborn parity ladder (Option A): ranges/health/ticks mirror the
#    dragon ladder; 2-block scale; vanilla interaction range; mana curve.
# ---------------------------------------------------------------------------
Write-Output '== Dragonborn parity ladder =='
$dbYoungSrc = Get-JarJson 'db' 'data/dragonsurvival/dragonsurvival/dragon_stage/dragonborn_young.json'
$dbGrowthItems = $dbYoungSrc.growth_items   # star_bone / star_heart

$dbStages = @(
    @{ id = 'dragonborn_newborn'; min = 10.0;  max = 25.0;  ticks = 216000;   hpBase = 0.0;  hpPer = 0.2 }
    @{ id = 'dragonborn_young';   min = 25.0;  max = 40.0;  ticks = 432000;   hpBase = 3.0;  hpPer = 0.2 }
    @{ id = 'dragonborn_adult';   min = 40.0;  max = 60.0;  ticks = 1728000;  hpBase = 6.0;  hpPer = 0.2 }
    @{ id = 'dragonborn_ancient'; min = 60.0;  max = 300.0; ticks = 69120000; hpBase = 20.5; hpPer = 0.5 }
)

$pool = $ManaPoolStart
for ($i = 0; $i -lt $dbStages.Count; $i++) {
    $s = $dbStages[$i]
    $gain = $Gains4[$i]
    $modifiers = @(
        [ordered]@{
            amount    = [ordered]@{ type = 'minecraft:linear'; base = $s.hpBase; per_level_above_first = $s.hpPer }
            attribute = 'minecraft:generic.max_health'
            operation = 'add_value'
        },
        [ordered]@{ amount = -0.3333; attribute = 'minecraft:generic.scale'; operation = 'add_value' },
        [ordered]@{ amount = 0; attribute = 'minecraft:player.entity_interaction_range'; operation = 'add_value' },
        [ordered]@{ amount = 0; attribute = 'minecraft:player.block_interaction_range'; operation = 'add_value' },
        (New-ManaModifier $pool $s.min $gain)
    )
    $out = [ordered]@{
        growth_range      = [ordered]@{ min = $s.min; max = $s.max }
        modifiers         = $modifiers
        ticks_until_grown = $s.ticks
        growth_items      = $dbGrowthItems
    }
    Write-JsonFile "$StagesPath/$($s.id).json" $out
    $poolAtMax = $pool + $gain * ($s.max - $s.min)
    Write-Output ("  {0,-36} gain={1,-7} mana {2,7:N2} -> {3,7:N2}  growth {4}-{5}" -f $s.id, $gain, $pool, $poolAtMax, $s.min, $s.max)
    $pool = $poolAtMax
}

# ---------------------------------------------------------------------------
# 3. Spider ancient stage: adult file continued at the same modifier rates
# ---------------------------------------------------------------------------
Write-Output '== Spider ancient stage =='
$spiderAdult = Get-JarJson 'spider' 'data/dragonsurvival/dragonsurvival/dragon_stage/realistic_spider_adult.json'
$spiderGainAncient = $Gains3[2]
$spiderMinAncient = 90.0
$spiderMaxAncient = 300.0
$spiderModifiers = @($spiderAdult.modifiers) + @(,(New-ManaModifier $spiderPoolAfterAdult $spiderMinAncient $spiderGainAncient))
$spiderAncient = Copy-Properties $spiderAdult @('growth_range', 'ticks_until_grown', 'modifiers')
$spiderAncient['growth_range'] = [ordered]@{ min = $spiderMinAncient; max = $spiderMaxAncient }
$spiderAncient['ticks_until_grown'] = 848000
$spiderAncient['modifiers'] = $spiderModifiers
Write-JsonFile "$StagesPath/realistic_spider_ancient.json" $spiderAncient
Write-Output ("  {0,-36} gain={1,-7} mana {2,7:N2} -> {3,7:N2}  growth {4}-{5}" -f 'realistic_spider_ancient', $spiderGainAncient, $spiderPoolAfterAdult, ($spiderPoolAfterAdult + $spiderGainAncient * ($spiderMaxAncient - $spiderMinAncient)), $spiderMinAncient, $spiderMaxAncient)

# ---------------------------------------------------------------------------
# 4. Species overrides (guarded, so they stay inert when the addon is absent)
# ---------------------------------------------------------------------------
Write-Output '== Species overrides =='
function Write-SpeciesOverride([string]$jarKey, [string]$entryName, [string]$modId, [string[]]$progression) {
    $src = Get-JarJson $jarKey "data/dragonsurvival/dragonsurvival/dragon_species/$entryName.json"
    $out = [ordered]@{
        'neoforge:conditions' = @( [ordered]@{ type = 'neoforge:mod_loaded'; modid = $modId } )
    }
    foreach ($p in $src.PSObject.Properties) {
        if ($p.Name -eq 'custom_stage_progression') { $out['custom_stage_progression'] = $progression }
        else { $out[$p.Name] = $p.Value }
    }
    Write-JsonFile "$SpeciesPath/$entryName.json" $out
    Write-Host ("  {0,-30} progression: {1}" -f $entryName, ($progression -join ', '))
}

$dbProgression = @('dragonsurvival:dragonborn_newborn', 'dragonsurvival:dragonborn_young', 'dragonsurvival:dragonborn_adult', 'dragonsurvival:dragonborn_ancient')
Write-SpeciesOverride 'db' 'dragonborn_cave' 'ds_dragonborn_cave_forest_sea' $dbProgression
Write-SpeciesOverride 'db' 'dragonborn_forest' 'ds_dragonborn_cave_forest_sea' $dbProgression
Write-SpeciesOverride 'db' 'dragonborn_sea' 'ds_dragonborn_cave_forest_sea' $dbProgression
Write-SpeciesOverride 'spider' 'realistic_spider' 'ds_realistic_spider' @('dragonsurvival:realistic_spider_spiderling', 'dragonsurvival:realistic_spider_adult', 'dragonsurvival:realistic_spider_ancient')

# ---------------------------------------------------------------------------
# 5. stage_resources data map: full blocks for the four extended species,
#    newborn/ancient entries reuse the previous stage's assets.
# ---------------------------------------------------------------------------
Write-Output '== stage_resources data map =='
$dbSR = Get-JarJson 'db' 'data/dragonsurvival/data_maps/dragonsurvival/dragon_species/stage_resources.json'
$spSR = Get-JarJson 'spider' 'data/dragonsurvival/data_maps/dragonsurvival/dragon_species/stage_resources.json'
$srValues = [ordered]@{}
foreach ($sp in @('cave', 'forest', 'sea')) {
    $key = "dragonsurvival:dragonborn_$sp"
    $block = $dbSR.values.PSObject.Properties[$key].Value
    $youngEntry = $block.'dragonsurvival:dragonborn_young'
    $block | Add-Member -NotePropertyName 'dragonsurvival:dragonborn_newborn' -NotePropertyValue $youngEntry
    $srValues[$key] = $block
}
$spBlock = $spSR.values.'dragonsurvival:realistic_spider'
$spBlock | Add-Member -NotePropertyName 'dragonsurvival:realistic_spider_ancient' -NotePropertyValue $spBlock.'dragonsurvival:realistic_spider_adult'
$srValues['dragonsurvival:realistic_spider'] = $spBlock
Write-JsonFile $DataMapPath ([ordered]@{ values = $srValues })
Write-Output '  dragonborn_cave/forest/sea + dragonborn_newborn, realistic_spider + ancient (adult assets)'

# ---------------------------------------------------------------------------
# 6. Lang keys for the two new stages
# ---------------------------------------------------------------------------
Write-Output '== Lang =='
Write-JsonFile $LangPath ([ordered]@{
    'dragon_stage.dragonsurvival.dragonborn_newborn'         = 'Newborn'
    'dragon_stage.dragonsurvival.realistic_spider_ancient'   = 'Ancient'
})

# ---------------------------------------------------------------------------
# 7. default_parts: copies of the reused stage, stage id rewritten
# ---------------------------------------------------------------------------
Write-Output '== default_parts =='
foreach ($sp in @('cave', 'forest', 'sea')) {
    $src = Get-JarJson 'db' "assets/dragonsurvival/skin/default_parts/dragonborn_$sp/dragonborn_${sp}_young.json"
    $src.stage = 'dragonsurvival:dragonborn_newborn'
    Write-JsonFile "$PartsPath/dragonborn_$sp/dragonborn_${sp}_newborn.json" $src
    Write-Output "  dragonborn_$sp newborn parts (reused from young)"
}
foreach ($body in @('realistic_spider', 'cute_spider')) {
    $src = Get-JarJson 'spider' "assets/dragonsurvival/skin/default_parts/realistic_spider/${body}_adult.json"
    $src.stage = 'dragonsurvival:realistic_spider_ancient'
    Write-JsonFile "$PartsPath/realistic_spider/${body}_ancient.json" $src
    Write-Output "  $body ancient parts (reused from adult)"
}

Write-Output ''
Write-Output ("Generated {0} files." -f $Written.Count)
