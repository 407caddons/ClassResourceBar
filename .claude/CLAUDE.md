# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClassResourceBar is a World of Warcraft (Retail, Interface 120000 / WoW 12.0) addon that displays class-specific resource bars. It replaces WeakAuras-style resource tracking with a native addon. Distributed via CurseForge (Project ID: 1448507).

Slash commands: `/msb` or `/monkstagger` to open config.

## Build & Development

No build system, linter, or test framework. The addon is pure Lua loaded directly by the WoW client. To test changes, edit `.lua` files and `/reload` in-game. The TOC file (`ClassResourceBar.toc`) defines load order and must be updated when adding/removing files.

SavedVariables are stored under the legacy name `MonkStaggerBarDB` (originally a Monk-only addon).

## Architecture

### Core System (`Core.lua`)

- Creates the master frame `MSBFrame` attached to `UIParent`, exposed as `addon.Frame`
- Manages SavedVariables with automatic default-merging for version upgrades
- Provides module hooks that class files implement:
  - `addon.InitializeModule()` — called at `PLAYER_LOGIN`
  - `addon.ModuleOnUpdate(elapsed)` — per-frame update tick
  - `addon.OnLayoutUpdate()` — called on frame resize/reposition
  - `addon.OnTextureUpdate()` — called when bar texture changes
- Handles frame dragging, resizing, flying-state visibility, minimap button, and slash commands

### Class Modules (`<ClassName>.lua`)

Each class file follows the same pattern:
1. Early-exit guard: `if playerClass ~= "CLASSNAME" then return end` — only the player's class module executes
2. Creates StatusBars and/or block frames as children of `addon.Frame`
3. Implements `addon.InitializeModule()` to build UI elements
4. Implements `addon.OnLayoutUpdate()` and `addon.OnTextureUpdate()` for dynamic updates
5. Registers its own event frame for class-specific WoW events (`UNIT_POWER_UPDATE`, `UNIT_MAXPOWER`, `PLAYER_SPECIALIZATION_CHANGED`, etc.)

Resource display types:
- **Continuous bars** (`StatusBar` frames) — for power resources like Energy, Mana, Rage, Fury, Runic Power, etc.
- **Discrete blocks** (individual frames) — for stacking resources like Chi, Combo Points, Holy Power, Runes, Soul Shards, Arcane Charges, Essence

Classes with dual resources (e.g., Rogue: Combo Points + Energy) use a height ratio stored in SavedVariables (e.g., `rogueEnergyRatio`) to split the frame vertically, with a 2px gap between sections.

### Configuration (`MonkStaggerBarConfig.lua`)

Settings panel registered with WoW's `Settings.RegisterAddOnCategory`. Provides sliders (position, size, ratios), color pickers, texture dropdowns, and toggles. Config changes call `addon.UpdateLayout()` or `addon.UpdateTextures()` to propagate.

### TOC Load Order

```
Core.lua                  -- Foundation (must be first)
MonkStaggerBarConfig.lua  -- Settings UI
Monk.lua                  -- Then class modules
DeathKnight.lua
DemonHunter.lua
Druid.lua
Evoker.lua
Warrior.lua
Paladin.lua
Hunter.lua
Warlock.lua
Mage.lua
Priest.lua
Rogue.lua
Shaman.lua
```

## Key Conventions

- All bars use `"Interface\\TargetingFrame\\UI-StatusBar"` as the default texture, overridable via `MonkStaggerBarDB.barTexture`
- Background textures are solid black at 0.5 alpha
- Colors are stored as `{r, g, b}` tables in `MonkStaggerBarDB.colors`
- Monk Stagger uses `issecretvalue()` (WoW API function) to detect combat-protected values that cannot be used in calculations, falling back to `addon.lastStagger` when the value is protected
- Spec-aware classes (Monk, Druid, Priest) check `GetSpecializationInfo(GetSpecialization())` and rebuild UI on `PLAYER_SPECIALIZATION_CHANGED`
- Druid additionally tracks `UPDATE_SHAPESHIFT_FORM` for form-specific resources
- Warlock Destruction spec uses progressive shard fill (partial blocks) vs. solid blocks for other specs
