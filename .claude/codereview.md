# ClassResourceBar -- Comprehensive Code Review

**Date:** 2026-02-14
**Reviewer:** Claude (Automated Code Review)
**Scope:** All `.lua` files and `.toc` in the ClassResourceBar addon
**Files Reviewed:**
- `ClassResourceBar.toc`
- `Core.lua`
- `MonkStaggerBarConfig.lua`
- `Monk.lua`, `DeathKnight.lua`, `DemonHunter.lua`, `Druid.lua`, `Evoker.lua`, `Warrior.lua`
- `Paladin.lua`, `Hunter.lua`, `Warlock.lua`, `Mage.lua`, `Priest.lua`, `Rogue.lua`, `Shaman.lua`

---

## Table of Contents

1. [Performance Issues](#1-performance-issues)
2. [Memory Leaks and Memory Optimization](#2-memory-leaks-and-memory-optimization)
3. [Code Readability and Organization](#3-code-readability-and-organization)
4. [DRY Violations and Repeated Patterns](#4-dry-violations-and-repeated-patterns)
5. [Potential Bugs and Error Handling](#5-potential-bugs-and-error-handling)
6. [Suggested Improvements](#6-suggested-improvements)

---

## 1. Performance Issues

### 1.1. CRITICAL: Monk Stagger UpdateStagger() Called Every Frame (Monk.lua:90)

The Monk module registers a per-frame `ModuleOnUpdate` that calls `addon.UpdateStagger()` unconditionally on every single frame render:

```lua
-- Monk.lua, line ~90
addon.ModuleOnUpdate = function(elapsed)
    addon.UpdateStagger()
end
```

`UpdateStagger()` (Monk.lua:100-137) calls `UnitStagger("player")`, `UnitHealthMax("player")`, performs division, `string.format()`, and `SetStatusBarColor()` every frame. At 60+ FPS, this is 60+ calls per second doing formatting and color logic.

**Recommended fix:** Throttle the stagger update to ~10-20 times per second (every 0.05-0.1 seconds), similar to how `CheckFlyingState` is throttled in Core.lua:

```lua
local staggerThrottle = 0
addon.ModuleOnUpdate = function(elapsed)
    staggerThrottle = staggerThrottle + elapsed
    if staggerThrottle < 0.05 then return end
    staggerThrottle = 0
    addon.UpdateStagger()
end
```

### 1.2. CRITICAL: Death Knight Rune Update Every Frame (DeathKnight.lua:64)

The Death Knight module also uses a per-frame update for rune cooldown animation:

```lua
-- DeathKnight.lua, line ~64
addon.ModuleOnUpdate = function(elapsed)
    addon.UpdateRunes()
end
```

`UpdateRunes()` (DeathKnight.lua:82-98) loops through 6 runes calling `GetRuneCooldown(i)`, `GetTime()`, and `SetMinMaxValues`/`SetValue`/`SetStatusBarColor` for each rune every frame.

**Recommended fix:** While rune animation requires relatively frequent updates, this should still be throttled. Additionally, the function re-reads the color tables from SavedVariables on every call. Cache the colors outside the function:

```lua
local runeThrottle = 0
addon.ModuleOnUpdate = function(elapsed)
    runeThrottle = runeThrottle + elapsed
    if runeThrottle < 0.03 then return end -- ~30 FPS for smooth rune fill
    runeThrottle = 0
    addon.UpdateRunes()
end
```

### 1.3. MODERATE: Color Table Lookups in Every Update Call

Nearly every `Update*()` function re-reads color tables from `MonkStaggerBarDB.colors` on every invocation. These color tables change only when the user picks a new color in the config panel. Examples:

- `Monk.lua:UpdateStagger()` lines ~120-135: reads `colors.staggerLight`, `colors.staggerModerate`, `colors.staggerHeavy` each call
- `Monk.lua:UpdateEnergy()` line ~142: reads `MonkStaggerBarDB.colors.monkEnergy` each call
- `DeathKnight.lua:UpdateRunes()` lines ~83-84: reads `MonkStaggerBarDB.colors.runesReady` and `MonkStaggerBarDB.colors.runesRecharging` each call (this is per-frame!)
- `Druid.lua:UpdateDruidResources()` reads 4 different color tables per call
- Same pattern in Paladin.lua, Warlock.lua, Mage.lua, Priest.lua, Rogue.lua, Shaman.lua, Evoker.lua

**Recommended fix:** Cache color references in local variables and update them only when the config changes. For example, in DeathKnight.lua:

```lua
local cachedRuneReadyColor = nil
local cachedRuneRechargeColor = nil

local function RefreshColorCache()
    cachedRuneReadyColor = MonkStaggerBarDB.colors.runesReady or {r = 0.69, g = 0.38, b = 1}
    cachedRuneRechargeColor = MonkStaggerBarDB.colors.runesRecharging or {r = 0.4, g = 0.4, b = 0.4}
end
```

### 1.4. MODERATE: string.format() Called Per-Frame in Monk Stagger

`Monk.lua:UpdateStagger()` line ~112:
```lua
staggerBar.text:SetText(string.format("%d (%.1f%%)", stagger, percent))
```

Since `UpdateStagger()` is called every frame (see issue 1.1), this creates a new string every frame via `string.format()`. While WoW Lua has string interning, the formatting overhead is unnecessary at 60+ FPS.

**Recommended fix:** Throttle updates (see 1.1) or only update text when the value actually changes.

### 1.5. LOW: Redundant SetStatusBarColor Calls

Multiple update functions unconditionally call `SetStatusBarColor()` every time resources change, even though the color has not changed. For example:

- `Warrior.lua:UpdateRage()` line ~52: calls `SetStatusBarColor` on every `UNIT_POWER_UPDATE` event
- `DemonHunter.lua:UpdateFury()` line ~43: same pattern
- `Hunter.lua:UpdateFocus()` line ~38: same pattern

These are relatively cheap calls, but they are wasteful. Color should only be set during initialization and when changed via config.

### 1.6. LOW: Evoker Redundant Update Branch (Evoker.lua:56-62)

```lua
if arg2 == "ESSENCE" or arg2 == "MANA" then
     addon.UpdateEvokerResources()
else
     -- Update anyway just to be safe if token is weird
     addon.UpdateEvokerResources()
end
```

Both branches do the same thing, making the conditional completely meaningless. This should be simplified to a single unconditional call, or better yet, the else branch should be removed:

```lua
if arg2 == "ESSENCE" or arg2 == "MANA" then
    addon.UpdateEvokerResources()
end
```

### 1.7. LOW: Core.lua OnSizeChanged Handler Accesses Globals (Core.lua:99-111)

```lua
frame:SetScript("OnSizeChanged", function(self, w, h)
    ...
    if _G["MSBWidth"] then
        _G["MSBWidth"].isUpdating = true
        _G["MSBWidth"]:SetValue(w)
        _G["MSBWidth"].isUpdating = false
    end
    if _G["MSBHeight"] then
        _G["MSBHeight"].isUpdating = true
        _G["MSBHeight"]:SetValue(h)
        _G["MSBHeight"].isUpdating = false
    end
end)
```

The `OnSizeChanged` callback fires during resize dragging (every pixel moved). Each invocation performs 2 global table lookups (`_G["MSBWidth"]`, `_G["MSBHeight"]`). While not a major performance concern, caching these references would be cleaner. Additionally, this handler could fire very rapidly during smooth resizing.

---

## 2. Memory Leaks and Memory Optimization

### 2.1. MODERATE: New Color Tables Created on Fallback

Every time an update function is called and the saved color is nil, a new table is allocated as a fallback. In per-frame update functions, this becomes a real allocation concern:

```lua
-- DeathKnight.lua:UpdateRunes(), line ~83-84 (called every frame)
local cReady = MonkStaggerBarDB.colors.runesReady or {r = 0.69, g = 0.38, b = 1}
local cRecharge = MonkStaggerBarDB.colors.runesRecharging or {r = 0.4, g = 0.4, b = 0.4}
```

If `MonkStaggerBarDB.colors.runesReady` is nil (which should not happen after initialization, but could if colors were wiped), this allocates 2 new tables **every frame**.

This same pattern appears in nearly every update function across all class modules:
- `Monk.lua:UpdateStagger()` -- lines ~120, ~125, ~130 (3 potential allocations per frame)
- `Monk.lua:UpdateEnergy()` -- line ~142
- `Monk.lua:UpdateChi()` -- line ~155
- `Druid.lua:UpdateDruidResources()` -- lines ~97, ~106, ~115, ~124
- `Evoker.lua:UpdateEvokerResources()` -- lines ~72, ~80
- And so on in every other class file

**Recommended fix:** Use the file-level default constants that already exist:

```lua
-- These are already defined at file scope:
local RP_COLOR = {r = 0, g = 0.82, b = 1}

-- Use them directly:
local cReady = MonkStaggerBarDB.colors.runesReady or RP_COLOR
```

Most files already define these constants but inconsistently use them. For example, `DeathKnight.lua` defines `RP_COLOR` at line ~8 but then uses an inline table literal in `UpdateRunes()` at line ~84.

### 2.2. MODERATE: Closure Allocations in OnUpdate for Minimap Dragging (Core.lua:178)

```lua
button:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function(self)
        local mx, my = Minimap:GetCenter()
        ...
    end)
end)
```

Every drag start creates a new closure for the `OnUpdate` script. While minimap dragging is infrequent, this is an unnecessary pattern. The inner function should be pre-defined.

### 2.3. LOW: Config Pages Always All Created (MonkStaggerBarConfig.lua:~420-435)

When `OpenConfig()` is called, ALL 14 pages (General + 13 classes) are created immediately, regardless of which class the player is. Each page creates multiple frames (sliders, checkboxes, color pickers, dropdowns). For a Warrior player, the Monk, Evoker, Paladin, etc. pages are completely useless but still consume memory.

```lua
pages["General"] = CreateGeneralPage()
pages["Monk"] = CreateMonkPage()
pages["Death Knight"] = CreateDKPage()
pages["Demon Hunter"] = CreateDHPage()
pages["Druid"] = CreateDruidPage()
pages["Evoker"] = CreateEvokerPage()
pages["Warrior"] = CreateWarriorPage()
pages["Paladin"] = CreatePaladinPage()
pages["Hunter"] = CreateHunterPage()
pages["Warlock"] = CreateWarlockPage()
pages["Mage"] = CreateMagePage()
pages["Priest"] = CreatePriestPage()
pages["Rogue"] = CreateRoguePage()
pages["Shaman"] = CreateShamanPage()
```

**Recommended fix:** Lazy-load pages on first navigation. Only create a page when the user clicks its navigation button:

```lua
local function SwitchTo(name)
    for k, v in pairs(pages) do v:Hide() end
    if not pages[name] then
        pages[name] = pageCreators[name]() -- Create on first access
    end
    pages[name]:Show()
end
```

### 2.4. LOW: Excess Block Frames Created But Never Used

Several class modules create more blocks than will ever be needed:
- `Evoker.lua` line ~32: Creates 10 essence blocks, but max essence is typically 5-6
- `Mage.lua` line ~36: Creates 10 arcane charge blocks, but max is 4
- `Rogue.lua` line ~30: Creates 10 combo point blocks, typical max is 5-7

While these extra frames are hidden, they still consume memory for their frame objects, textures, and associated structures.

### 2.5. LOW: Event Frames Never Stored or Cleaned Up

Every class module creates an anonymous event frame in `InitializeModule()`:

```lua
local eventFrame = CreateFrame("Frame")
```

These are never assigned to a variable accessible outside the function scope (they are local to `InitializeModule`). While this is not a true memory leak (the event system holds a reference), it means:
- Event frames cannot be unregistered later if the module needs to be disabled
- There is no way to inspect or debug these frames
- If `InitializeModule` were somehow called twice, duplicate event frames would be created

---

## 3. Code Readability and Organization

### 3.1. Legacy Naming Throughout

The addon was originally "Monk Stagger Bar" and has been expanded to all classes, but many legacy names remain:
- SavedVariables: `MonkStaggerBarDB` (toc file and every lua file)
- Minimap button: `MonkStaggerBarMinimapButton` (Core.lua:163)
- Tooltip text: `"Monk Stagger Bar"` (Core.lua:199)
- Config title: `"Monk Stagger Bar Config"` (MonkStaggerBarConfig.lua:~148)
- Slash commands: `/monkstagger` (Core.lua:210)
- Config frame: `MSBConfigFrame` (MonkStaggerBarConfig.lua:~143)
- Default close button lookup: `configFrame:GetName() .. "CloseButton"` (MonkStaggerBarConfig.lua:~153)

While the SavedVariables name must remain for backwards compatibility, the user-facing strings should be updated to match the actual addon name "Class Resource Bar".

### 3.2. Inconsistent `addon.OnLayoutUpdate` Hook Pattern

The hook `addon.OnLayoutUpdate` is used differently across modules:
- `Monk.lua`: Defines `addon.UpdateMonkLayout()` and assigns it to `addon.OnLayoutUpdate` implicitly (Core.lua calls `addon.OnLayoutUpdate` which Monk overrides)
- Wait -- actually, Monk.lua defines `addon.UpdateMonkLayout()` as a separate function AND defines `addon.OnLayoutUpdate` (it does NOT -- there is no explicit `addon.OnLayoutUpdate` in Monk.lua). The Core `OnSizeChanged` handler calls `addon.OnLayoutUpdate()` which would be nil for Monk. Instead, Monk only responds to explicit `addon.UpdateMonkLayout()` calls.

This is inconsistent with every other class. Looking at the actual pattern:
- `DeathKnight.lua`: Defines `addon.OnLayoutUpdate()` -- CORRECT
- `DemonHunter.lua`: Defines `addon.OnLayoutUpdate()` as a no-op -- CORRECT
- `Druid.lua`: Defines `addon.UpdateDruidLayout()` but NOT `addon.OnLayoutUpdate()` -- BUG
- `Warrior.lua`: Defines `addon.OnLayoutUpdate()` as a no-op -- CORRECT
- `Hunter.lua`: Defines `addon.OnLayoutUpdate()` -- CORRECT
- All others: Define `addon.OnLayoutUpdate()` -- CORRECT

**Bug:** Monk and Druid do NOT define `addon.OnLayoutUpdate()`. This means when the frame is resized (via the resize grip), the Core's `OnSizeChanged` handler calls `addon.OnLayoutUpdate()` which was set by whichever module loaded last (or nil if Monk/Druid loaded last, since all other class modules would have returned early due to the class guard). However, since only one class module actually executes past the guard, if the player is a Monk or Druid, `addon.OnLayoutUpdate` would be nil and the resize would not update the bars.

Wait -- Core.lua line ~103:
```lua
if addon.OnLayoutUpdate then
    addon.OnLayoutUpdate()
end
```

So it's nil-safe. But the Monk and Druid bars will NOT respond to resize events, which is a functional bug.

### 3.3. Inconsistent Function Naming

Functions exposed on the `addon` table use inconsistent naming:
- Monk: `addon.UpdateMonkLayout()`, `addon.UpdateMonkResources()`, `addon.UpdateStagger()`, `addon.UpdateEnergy()`, `addon.UpdateMana()`, `addon.UpdateChi()`
- DeathKnight: `addon.UpdateRunicPower()`, `addon.UpdateRunes()`
- Druid: `addon.UpdateDruidLayout()`, `addon.UpdateDruidResources()`
- DemonHunter: `addon.UpdateFury()`
- Warrior: `addon.UpdateRage()`
- Paladin: `addon.UpdatePaladinResources()`, `addon.UpdatePaladinVisibility()`
- Hunter: `addon.UpdateFocus()`
- Warlock: `addon.UpdateWarlockResources()`
- Mage: `addon.UpdateMageResources()`
- Priest: `addon.UpdatePriestResources()`
- Rogue: `addon.UpdateRogueResources()`
- Shaman: `addon.UpdateShamanResources()`

Some classes prefix with the class name (`UpdateMonkResources`), others do not (`UpdateFury`, `UpdateRage`). Since only one class module is active at a time, namespace collision is not a runtime issue, but it makes the codebase harder to grep and understand.

### 3.4. Commented-Out Code and Verbose Internal Comments

Several files contain extensive inline reasoning comments that read more like developer notes or conversations than code documentation:

```lua
-- Monk.lua, line ~82
-- Update Loop (Stagger is time-sensitive, but purely check once per frame?
-- Actually standard OnUpdate isn't strictly needed if we trust events,
-- but Stagger % updates as HP changes or Stagger decays.
-- We'll keep the module update hook.
```

```lua
-- Druid.lua, lines ~105-115
-- Common IDs: 1 (Cat?), 5 (Bear?), 31 (Moonkin)
-- Using GetShapeshiftForm() index 1..N is safer usually, but let's stick to logic logic.
-- Better: Enum.ShapeshiftForm.Bear etc? No.
-- Let's use standard indices for Bear/Cat detection or FormID if we knew them for sure.
-- Actually GetShapeshiftForm() returns index.
-- 1 = Bear, 2 = Cat, 3 = Travel... varies by glyph/talent.
-- Safest is Checking UnitPowerType?
```

These should be condensed into concise documentation comments.

### 3.5. Inconsistent Indentation

`Monk.lua:UpdateStagger()` has inconsistent indentation around line ~130:

```lua
    if percent < 30 then
        local c = colors.staggerLight or COLOR_STAGGER_LIGHT
        r,g,b = c.r, c.g, c.b
    elseif percent < 60 then
        local c = colors.staggerModerate or COLOR_STAGGER_MODERATE
        r,g,b = c.r, c.g, c.b
    else
            local c = colors.staggerHeavy or COLOR_STAGGER_HEAVY  -- Extra indent
        r,g,b = c.r, c.g, c.b
    end
```

The `else` branch has an extra level of indentation on the first line.

---

## 4. DRY Violations and Repeated Patterns

### 4.1. HIGH: StatusBar + Background + Text Creation Pattern Repeated ~20 Times

Every class module independently creates StatusBar frames with the exact same pattern:

```lua
local bar = CreateFrame("StatusBar", nil, frame)
bar:SetStatusBarTexture(texture)
bar:SetMinMaxValues(0, 100)
bar:SetValue(0)

local bg = bar:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(true)
bg:SetColorTexture(0, 0, 0, 0.5)

bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
bar.text:SetPoint("CENTER")
```

This pattern appears in:
- `Monk.lua`: 3 times (stagger, energy, mana bars)
- `DeathKnight.lua`: 1 time (runic power bar) + partial for rune bars
- `DemonHunter.lua`: 1 time
- `Druid.lua`: 4 times (rage, energy, mana, astral)
- `Evoker.lua`: 1 time
- `Warrior.lua`: 1 time
- `Paladin.lua`: 1 time
- `Hunter.lua`: 1 time
- `Warlock.lua`: 1 time
- `Mage.lua`: 1 time
- `Priest.lua`: 2 times (mana, insanity)
- `Rogue.lua`: 1 time
- `Shaman.lua`: 2 times (mana, maelstrom)

**Recommended fix:** Add a helper function in `Core.lua`:

```lua
function addon.CreateStatusBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    bar:SetStatusBarTexture(texture)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0, 0, 0, 0.5)

    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bar.text:SetPoint("CENTER")

    return bar
end
```

### 4.2. HIGH: Block (Discrete Resource) Creation Pattern Repeated ~6 Times

Similar to StatusBars, discrete resource blocks follow an identical pattern:

```lua
for i = 1, N do
    local block = CreateFrame("Frame", nil, frame)
    block.bg = block:CreateTexture(nil, "BACKGROUND")
    block.bg:SetAllPoints(true)
    block.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    block.fill = block:CreateTexture(nil, "OVERLAY")
    block.fill:SetAllPoints(true)
    block.fill:SetColorTexture(color.r, color.g, color.b)
    block.fill:Hide()

    blocks[i] = block
end
```

Found in: Monk.lua (chi), Evoker.lua (essence), Paladin.lua (holy power), Mage.lua (arcane charges), Rogue.lua (combo points).

**Recommended fix:** Add a helper in Core.lua:

```lua
function addon.CreateResourceBlocks(parent, count, color)
    local blocks = {}
    for i = 1, count do
        local block = CreateFrame("Frame", nil, parent)
        block.bg = block:CreateTexture(nil, "BACKGROUND")
        block.bg:SetAllPoints(true)
        block.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        block.fill = block:CreateTexture(nil, "OVERLAY")
        block.fill:SetAllPoints(true)
        block.fill:SetColorTexture(color.r, color.g, color.b)
        block.fill:Hide()
        blocks[i] = block
        block:Hide()
    end
    return blocks
end
```

### 4.3. HIGH: Texture Fallback String Repeated ~40 Times

The string `"Interface\\TargetingFrame\\UI-StatusBar"` appears as a fallback in virtually every function across every file. Count: approximately 40 occurrences.

**Recommended fix:** Define once in Core.lua:

```lua
addon.DEFAULT_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
```

Then use `MonkStaggerBarDB.barTexture or addon.DEFAULT_TEXTURE` everywhere.

### 4.4. MODERATE: Event Frame Setup Pattern Repeated 14 Times

Every class module creates its own event frame with the same boilerplate:

```lua
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
eventFrame:RegisterEvent("UNIT_MAXPOWER")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "UNIT_POWER_UPDATE" and arg1 == "player" then
        ...
    end
end)
```

### 4.5. MODERATE: Mana Bar Update Pattern Repeated in ~8 Classes

The mana bar update logic is nearly identical in Evoker, Paladin, Warlock, Mage, Priest, Shaman, and Monk:

```lua
local mana = UnitPower("player", Enum.PowerType.Mana)
local maxMana = UnitPowerMax("player", Enum.PowerType.Mana)
manaBar:SetMinMaxValues(0, maxMana)
manaBar:SetValue(mana)
manaBar.text:SetText(mana)
local cMana = MonkStaggerBarDB.colors.CLASSNAME_Mana or MANA_COLOR
manaBar:SetStatusBarColor(cMana.r, cMana.g, cMana.b)
```

A shared `addon.UpdateManaBar(bar, colorKey)` helper would eliminate this repetition.

### 4.6. MODERATE: Block Update Logic Repeated

The pattern for updating discrete resource blocks is also repeated across Chi (Monk), Essence (Evoker), Holy Power (Paladin), Arcane Charges (Mage), and Combo Points (Rogue):

```lua
for i = 1, #blocks do
    if i <= maxResource then
        blocks[i]:Show()
        if i <= currentResource then
            blocks[i].fill:Show()
            blocks[i].fill:SetColorTexture(c.r, c.g, c.b)
        else
            blocks[i].fill:Hide()
        end
    else
        blocks[i]:Hide()
    end
end
```

---

## 5. Potential Bugs and Error Handling

### 5.1. BUG: Monk and Druid Do Not Define addon.OnLayoutUpdate

As discussed in section 3.2, `Monk.lua` does not define `addon.OnLayoutUpdate()`. It defines `addon.UpdateMonkLayout()` instead. When the user resizes the frame via the resize grip, `Core.lua` line ~103 checks:

```lua
if addon.OnLayoutUpdate then
    addon.OnLayoutUpdate()
end
```

For Monk players, `addon.OnLayoutUpdate` is nil, so the bars will not resize with the frame.

Similarly, `Druid.lua` defines `addon.UpdateDruidLayout()` but not `addon.OnLayoutUpdate()`.

**Fix for Monk.lua:** Add at the end:
```lua
addon.OnLayoutUpdate = addon.UpdateMonkLayout
```

**Fix for Druid.lua:** Add at the end:
```lua
addon.OnLayoutUpdate = addon.UpdateDruidLayout
```

### 5.2. BUG: Duplicate `energy` Key in Core.lua Defaults (Core.lua:35 and Core.lua:47)

```lua
-- Core.lua defaults.colors:
energy = { r = 1, g = 1, b = 0 },        -- Line ~35 (general Energy)
...
-- Rogue section:
energy = { r = 1, g = 1, b = 0 },        -- Line ~47 (duplicate key!)
comboPoints = { r = 1, g = 0.9, b = 0 },
```

In Lua, duplicate keys in a table constructor mean the second assignment silently overwrites the first. This is not currently causing visible issues because both values are identical, but it indicates a design problem. The Druid module references `MonkStaggerBarDB.colors.druidEnergy` (Druid.lua:~106) but no such default exists in Core.lua -- it falls back to `ENERGY_COLOR` local.

**Recommended fix:** Use class-prefixed color keys consistently (e.g., `rogueEnergy`, `druidEnergy`, `monkEnergy`) or a single shared `energy` key if the color should truly be shared.

### 5.3. BUG: Druid References Non-Existent Color Key (Druid.lua:106)

```lua
local c = MonkStaggerBarDB.colors.druidEnergy or ENERGY_COLOR
```

There is no `druidEnergy` key in the `defaults.colors` table in Core.lua. The config panel (`CreateDruidPage`) sets `MonkStaggerBarDB.colors.energy` (not `druidEnergy`). This means the Druid energy bar color will always use the local fallback `ENERGY_COLOR` and will never respond to color picker changes in the config.

### 5.4. BUG: Monk Config References Wrong Color Keys (MonkStaggerBarConfig.lua:~193-215)

The Monk config page reads/writes `MonkStaggerBarDB.colors.light`, `MonkStaggerBarDB.colors.moderate`, `MonkStaggerBarDB.colors.heavy`:

```lua
function()
    local c = MonkStaggerBarDB.colors.light or { r = 0, g = 1, b = 0 }
    return c.r, c.g, c.b
end,
```

But `Monk.lua:UpdateStagger()` reads `colors.staggerLight`, `colors.staggerModerate`, `colors.staggerHeavy`:

```lua
local c = colors.staggerLight or COLOR_STAGGER_LIGHT
```

And the defaults in Core.lua use `staggerLight`, `staggerModerate`, `staggerHeavy`. The config is writing to the wrong keys, so stagger color changes via the config panel will have no effect.

### 5.5. BUG: Warlock Destruction Spec Detection (Warlock.lua:~82)

```lua
local isDestro = (spec == 3) -- Destruction spec index is 3
```

This uses the raw spec index (1, 2, or 3) rather than the spec ID. The comment says "Destruction spec index is 3" but spec indices are not guaranteed to be stable across patches. The file already defines `SPEC_DESTRUCTION = 267` at line ~11 but never uses it. The correct check would be:

```lua
local specID = spec and GetSpecializationInfo(spec)
local isDestro = (specID == SPEC_DESTRUCTION)
```

### 5.6. POTENTIAL BUG: Anchor Point Accumulation

Several layout functions call `SetPoint()` without first calling `ClearAllPoints()`. For example, `Druid.lua:UpdateDruidLayout()` calls `SetSplit()` which does:

```lua
top:SetPoint("TOPLEFT", frame, "TOPLEFT")
bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
```

If this function is called multiple times (e.g., on spec change or shapeshift), anchor points accumulate rather than being replaced. WoW's SetPoint adds a new anchor point; it does not replace existing ones unless `ClearAllPoints()` is called first.

This affects: `Druid.lua`, `Monk.lua:UpdateMonkLayout()`, `Evoker.lua:OnLayoutUpdate()`, `Paladin.lua:OnLayoutUpdate()`, `Mage.lua:OnLayoutUpdate()`, `Priest.lua:OnLayoutUpdate()`, `Rogue.lua:OnLayoutUpdate()`, `Shaman.lua:OnLayoutUpdate()`, `Warlock.lua:OnLayoutUpdate()`.

**Recommended fix:** Add `ClearAllPoints()` before `SetPoint()` in all layout functions, or call it once at the start of each layout function for all bars.

### 5.7. LOW: No nil Guard on GetSpecialization() Results

Several modules call `GetSpecialization()` and immediately use the result:

```lua
-- Monk.lua:UpdateMonkResources()
local spec = GetSpecialization()
local specID = spec and GetSpecializationInfo(spec)
```

This is correctly nil-guarded. However, other places are not:

```lua
-- Warlock.lua:UpdateWarlockResources()
local spec = GetSpecialization()
local isDestro = (spec == 3)
```

If `GetSpecialization()` returns nil (e.g., during loading), `spec == 3` would be false, which is safe but not explicit.

### 5.8. LOW: Blizzard Resource Bar Hiding Cannot Be Undone Without Reload

`Core.lua:UpdateBlizzardResourceBar()` hooks `OnShow` to re-hide frames. But when the user unchecks the option:

```lua
-- MonkStaggerBarConfig.lua, CreateGeneralPage
function(checked)
    ...
    if not checked then
        print("|cff00ff00MSB:|r Blizzard resource bar will be restored after /reload")
        ReloadUI()
    end
end
```

The addon forces a `ReloadUI()` when the user unchecks the option. This is a disruptive user experience. A better approach would be to track and remove the hook.

---

## 6. Suggested Improvements

### 6.1. Centralized Bar/Block Factory in Core.lua

As detailed in sections 4.1 and 4.2, adding `addon.CreateStatusBar()` and `addon.CreateResourceBlocks()` to Core.lua would dramatically reduce code duplication and make maintenance easier.

### 6.2. Shared Layout Helper for Split-Frame Classes

Many classes use a "top resource blocks + bottom status bar" layout. A shared helper could handle this:

```lua
function addon.LayoutSplitFrame(topFrames, bottomBar, ratio, isBlocks, blockCount)
    local frame = addon.Frame
    local w, h = MonkStaggerBarDB.width, MonkStaggerBarDB.height
    local gap = 2
    local availableHeight = h - gap
    local bottomH = availableHeight * ratio
    local topH = availableHeight * (1 - ratio)

    bottomBar:ClearAllPoints()
    bottomBar:SetSize(w, bottomH)
    bottomBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")

    if isBlocks then
        local blockWidth = w / blockCount
        for i = 1, blockCount do
            topFrames[i]:ClearAllPoints()
            topFrames[i]:SetSize(blockWidth - 1, topH)
            topFrames[i]:SetPoint("TOPLEFT", frame, "TOPLEFT", (i-1) * blockWidth, 0)
            topFrames[i]:Show()
        end
    end
end
```

### 6.3. Replace OnUpdate with Event-Only Architecture Where Possible

Only Monk (stagger decay) and Death Knight (rune cooldown animation) truly need per-frame updates. All other classes are purely event-driven and do not set `addon.ModuleOnUpdate`. This is good. However, Core.lua still runs the OnUpdate handler every frame even when `addon.ModuleOnUpdate` is nil:

```lua
-- Core.lua
frame:SetScript("OnUpdate", function(self, elapsed)
    if addon.CheckFlyingState then
        addon.CheckFlyingState(elapsed)
    end
    if addon.ModuleOnUpdate then
        addon.ModuleOnUpdate(elapsed)
    end
end)
```

The `CheckFlyingState` call is already throttled internally, so the overhead is minimal, but if `hideWhileFlying` is false AND no module needs OnUpdate, the entire handler does nothing. Consider only setting the OnUpdate script when it is actually needed.

### 6.4. Config Panel: Only Show Relevant Class Page

Currently, all 13 class navigation buttons are shown. A more user-friendly approach would be to highlight or auto-navigate to the current player's class page, or hide pages for other classes (since color/ratio changes for other classes have no visual effect for the current player).

### 6.5. Consider Using SetPoint with ClearAllPoints Pattern

As noted in bug 5.6, add `ClearAllPoints()` before `SetPoint()` throughout all layout functions to prevent anchor accumulation.

### 6.6. TOC Metadata Update

The tooltip for the minimap button still says "Monk Stagger Bar" (Core.lua:199). The config window title says "Monk Stagger Bar Config" (MonkStaggerBarConfig.lua:~148). These should reference "Class Resource Bar" to match the actual addon name.

### 6.7. Consider Implementing addon:OnDisable / Cleanup

There is no mechanism to clean up if the addon needs to be disabled or if modules need to be torn down. Adding an `addon.Shutdown()` or per-module cleanup function would future-proof the architecture.

### 6.8. Deep-Merge Colors on Version Upgrade (Core.lua:~67-74)

The current default-merging logic in `addon.Initialize()` is shallow:

```lua
for k, v in pairs(defaults) do
    if MonkStaggerBarDB[k] == nil then
        MonkStaggerBarDB[k] = v
    end
end
```

This means if a new color is added to `defaults.colors` (e.g., a new class), it will NOT be merged because `MonkStaggerBarDB.colors` already exists (it is not nil). Only top-level keys that are entirely missing get merged.

**Recommended fix:** Add a deep-merge for the `colors` sub-table:

```lua
if MonkStaggerBarDB.colors then
    for k, v in pairs(defaults.colors) do
        if MonkStaggerBarDB.colors[k] == nil then
            MonkStaggerBarDB.colors[k] = v
        end
    end
end
```

---

## Summary of Priority

| Priority | Issue | File(s) |
|----------|-------|---------|
| CRITICAL | Stagger updated every frame unthrottled | Monk.lua |
| CRITICAL | Runes updated every frame unthrottled | DeathKnight.lua |
| HIGH | Monk/Druid missing addon.OnLayoutUpdate (resize broken) | Monk.lua, Druid.lua |
| HIGH | Config writes wrong stagger color keys | MonkStaggerBarConfig.lua |
| HIGH | Druid references non-existent color key | Druid.lua |
| HIGH | StatusBar creation pattern repeated ~20x | All class files |
| HIGH | Block creation pattern repeated ~6x | Monk, Evoker, Paladin, Mage, Rogue |
| HIGH | Deep-merge missing for colors sub-table | Core.lua |
| MODERATE | Color fallback tables allocated in hot paths | All class files |
| MODERATE | Anchor accumulation from missing ClearAllPoints | Most class files |
| MODERATE | Warlock uses spec index instead of spec ID | Warlock.lua |
| MODERATE | Duplicate `energy` key in defaults | Core.lua |
| MODERATE | Config creates all pages eagerly | MonkStaggerBarConfig.lua |
| LOW | Redundant SetStatusBarColor on every event | Multiple files |
| LOW | Legacy "Monk Stagger Bar" naming | Core.lua, Config |
| LOW | Verbose developer notes as comments | Multiple files |
| LOW | Excess block frames pre-allocated | Evoker, Mage, Rogue |
| LOW | Evoker redundant conditional branch | Evoker.lua |
