# ClassResourceBar - Feature Suggestions

This document outlines potential future features for the ClassResourceBar addon, organized by category. Each feature includes a description, rationale, difficulty estimate, and technical considerations.

---

## Table of Contents

1. [Visibility and Display](#visibility-and-display)
2. [Text and Overlays](#text-and-overlays)
3. [Animations and Visual Effects](#animations-and-visual-effects)
4. [Configuration and Profiles](#configuration-and-profiles)
5. [Class-Specific Enhancements](#class-specific-enhancements)
6. [Quality of Life](#quality-of-life)
7. [Advanced Features](#advanced-features)
8. [Accessibility](#accessibility)

---

## Visibility and Display

### 1. Combat Visibility Toggle

**Description:** Add an option to show/hide the resource bar based on combat state. The bar would fade in when entering combat and fade out (or hide entirely) when leaving combat. An optional fade delay timer would prevent the bar from vanishing instantly after combat ends.

**Why it would be useful:** Many players prefer a clean UI outside of combat. Resource bars are most relevant during active gameplay, so hiding them out of combat reduces visual clutter without losing any practical benefit.

**Difficulty:** Easy

**Justification:** The WoW API provides `PLAYER_REGEN_DISABLED` (entering combat) and `PLAYER_REGEN_ENABLED` (leaving combat) events. Implementation requires registering these events in Core.lua, adding a SavedVariable toggle (`hideOutOfCombat`), and calling `frame:SetAlpha()` accordingly. The existing `hideWhileFlying` pattern in Core.lua is a near-identical template.

**Technical considerations:**
- Events: `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`
- A configurable fade-out delay (e.g., 3 seconds after combat ends) would prevent jarring disappearances. Use `C_Timer.After()` or an OnUpdate-based timer.
- Consider interaction with the existing `hideWhileFlying` option -- if both are enabled, flying should take priority.

---

### 2. Instance/Zone-Based Visibility

**Description:** Allow the bar to auto-show or auto-hide based on the player's current zone type: dungeon, raid, arena, battleground, open world, or specific zone names.

**Why it would be useful:** Some players only want resource tracking in competitive or group content. Others may want it everywhere except rest areas. Zone-based visibility gives fine-grained control.

**Difficulty:** Medium

**Justification:** Requires checking `IsInInstance()`, `GetInstanceInfo()`, or `GetZoneText()` on zone change events. The logic itself is simple, but the configuration UI needs a multi-select interface for zone types, which adds complexity.

**Technical considerations:**
- Events: `ZONE_CHANGED_NEW_AREA`, `PLAYER_ENTERING_WORLD`
- API: `IsInInstance()` returns instance type (party, raid, pvp, arena, none)
- Config UI would need checkboxes for each zone type

---

### 3. Conditional Visibility Based on Target

**Description:** Option to only show the bar when the player has an attackable target selected, or when the player has a target at all.

**Why it would be useful:** Provides an alternative to combat-based visibility that responds to player intent (targeting something) rather than combat state. Useful for preparation before pulls.

**Difficulty:** Easy

**Justification:** Listen to `PLAYER_TARGET_CHANGED` and check `UnitExists("target")` and/or `UnitCanAttack("player", "target")`. Similar pattern to the flying state check.

**Technical considerations:**
- Event: `PLAYER_TARGET_CHANGED`
- API: `UnitExists("target")`, `UnitCanAttack("player", "target")`
- Should work alongside other visibility options, not override them

---

### 4. Opacity / Alpha Slider

**Description:** Add a global alpha/opacity slider so users can make the bar semi-transparent at all times, independent of visibility toggles.

**Why it would be useful:** Some players want the bar visible but unobtrusive. A master opacity control lets users blend it into their UI without fully hiding it.

**Difficulty:** Easy

**Justification:** Single slider in General config that calls `frame:SetAlpha(value)`. Store the value in SavedVariables and apply it on load. Must coordinate with visibility toggles that also manipulate alpha.

**Technical considerations:**
- The flying-state check currently sets alpha to 0 or 1 directly. This would need to be refactored so that "shown" alpha uses the user-configured value rather than a hard-coded 1.
- Store as `MonkStaggerBarDB.globalAlpha` (default 1.0)

---

### 5. Bar Orientation Option (Vertical Bars)

**Description:** Allow the resource bar to be displayed vertically instead of horizontally.

**Why it would be useful:** Some UI layouts place resource tracking on the sides of the screen. Vertical orientation opens up new placement possibilities and matches addons like IceHUD.

**Difficulty:** Hard

**Justification:** WoW StatusBar frames support `SetOrientation("VERTICAL")`, but the entire layout system (block positioning, split ratios, text placement) assumes horizontal orientation. Every class module's `OnLayoutUpdate` would need conditional logic for vertical mode. Discrete blocks would need to stack vertically instead of horizontally.

**Technical considerations:**
- `StatusBar:SetOrientation("VERTICAL")` is supported natively
- All `SetPoint` and `SetSize` calls in every class module must account for orientation
- Text positioning needs to shift
- Resize grip behavior changes
- Consider implementing this as a Core.lua flag that modules read during layout

---

### 6. Per-Bar Background Color and Alpha

**Description:** Allow customization of the background color and alpha for each bar segment independently, rather than the current hardcoded black at 0.5 alpha.

**Why it would be useful:** Players who use specific UI color themes or transparent UIs would benefit from matching the bar backgrounds to their overall aesthetic.

**Difficulty:** Easy

**Justification:** Each bar already creates a background texture with `SetColorTexture(0, 0, 0, 0.5)`. Adding a color picker and alpha slider per bar, or a single global background setting, is straightforward.

**Technical considerations:**
- Could be implemented as a global setting first (simpler) and expanded to per-bar later
- Store as `MonkStaggerBarDB.bgColor = {r, g, b, a}`

---

## Text and Overlays

### 7. Text Display Options

**Description:** Add configuration for text visibility, format, font, size, and position on each bar. Options would include: show/hide text, display as raw value, percentage, both, or abbreviated (e.g., "145k"), and font selection from SharedMedia or built-in fonts.

**Why it would be useful:** The current text overlay is always-on and uses a fixed format. Players have different preferences: some want large percentage text, some want compact numbers, some want no text at all. Font customization helps the bar blend with other UI addons.

**Difficulty:** Medium

**Justification:** The text infrastructure already exists (each bar has a `.text` FontString). The main work is in the config UI: adding dropdowns for format and font, and propagating changes to all class modules. Font handling requires enumerating available fonts or integrating with LibSharedMedia.

**Technical considerations:**
- WoW API: `FontString:SetFont(path, size, flags)`, `AbbreviateNumbers()` (or manual formatting)
- Format options: raw number, percentage, "number / max", abbreviated, hidden
- Built-in fonts are at paths like `Fonts\\FRIZQT__.TTF`
- LibSharedMedia integration would require adding it as an optional dependency
- Store font settings in SavedVariables: `MonkStaggerBarDB.textFormat`, `MonkStaggerBarDB.fontSize`, `MonkStaggerBarDB.fontPath`

---

### 8. Mana as Percentage Display

**Description:** Option to display mana (and other continuous resources) as a percentage rather than a raw number.

**Why it would be useful:** Raw mana values (e.g., 250,000) are often less meaningful than "85%". Many players think in percentages for mana management. This is a specific, high-value subset of the broader text formatting feature above.

**Difficulty:** Easy

**Justification:** A simple toggle that changes `manaBar.text:SetText(mana)` to `manaBar.text:SetText(string.format("%.0f%%", (mana/maxMana)*100))`. Applies across all class modules that display mana.

**Technical considerations:**
- Guard against division by zero when `maxMana` is 0
- Could be a global toggle or per-class
- Already partially implemented for Monk stagger (which shows both value and percentage)

---

### 9. Tick Marks / Threshold Indicators

**Description:** Display configurable threshold markers on continuous bars (e.g., a line at 50 energy for Rogue abilities, or at specific rage thresholds for Warriors).

**Why it would be useful:** Many abilities have fixed resource costs. Visual threshold markers help players instantly see when they have enough resources for key abilities without reading the number.

**Difficulty:** Medium

**Justification:** Requires creating thin texture overlays positioned at percentage points along the bar. The positioning math is straightforward, but the config UI needs per-class threshold management (adding/removing/editing threshold values).

**Technical considerations:**
- Create line textures with `CreateTexture()` and position via `SetPoint("LEFT", bar, "LEFT", (threshold/max)*barWidth, 0)`
- Thresholds need to update when max power changes (e.g., max energy can vary with haste)
- Could offer preset thresholds for common ability costs
- Store as `MonkStaggerBarDB.thresholds = { className = { {value=50, color={r,g,b}}, ... } }`

---

## Animations and Visual Effects

### 10. Smooth Bar Fill Animation

**Description:** Animate bar value changes with smooth interpolation instead of instant snapping. When a resource value changes, the bar smoothly transitions to the new value over a configurable duration.

**Why it would be useful:** Smooth animations make the UI feel polished and make it easier to track the rate of resource gain/loss visually. Many popular UI addons use this technique.

**Difficulty:** Medium

**Justification:** WoW provides `StatusBar:SetAnimatedValues()` in some contexts, but a manual approach using the OnUpdate hook with linear or ease-out interpolation is more reliable. The addon already has an OnUpdate loop in Core.lua. The challenge is doing this efficiently for multiple bars without creating performance issues.

**Technical considerations:**
- Use `addon.ModuleOnUpdate` to interpolate bar values each frame
- Store target value and current display value separately: `bar.targetValue` vs `bar:GetValue()`
- Interpolation: `currentValue = currentValue + (targetValue - currentValue) * min(1, elapsed * speed)`
- Stagger bar already uses OnUpdate, so this is a natural extension
- Should be optional (toggle in config) since some players prefer instant feedback

---

### 11. Flash on Max Resource

**Description:** Add a brief flash or glow effect when a discrete resource (combo points, holy power, chi, etc.) reaches its maximum count, or when a continuous bar is full.

**Why it would be useful:** Provides an at-a-glance visual cue that resources are capped and should be spent, helping prevent resource waste. Especially valuable in fast-paced combat.

**Difficulty:** Medium

**Justification:** Requires adding an `AnimationGroup` with alpha fade on a glow texture overlay. The logic check (is resource at max?) is trivial. The animation system in WoW is well-documented. Needs to be applied to all class modules.

**Technical considerations:**
- WoW API: `AnimationGroup`, `Animation:SetFromAlpha()`, `Animation:SetToAlpha()`
- Create a semi-transparent overlay texture on each bar/block
- Trigger animation in the Update functions when `current == max`
- Could also support a "pulse" effect using scale animations
- Performance: animations are GPU-driven and lightweight

---

### 12. Color Gradient on Continuous Bars

**Description:** Instead of a solid color, allow bars to display a gradient that shifts color based on the fill percentage (e.g., red at low energy, yellow at mid, green at full).

**Why it would be useful:** Adds visual information density. Players can gauge resource level by color without reading numbers. Similar to how the Monk stagger bar already changes color at thresholds, but applied smoothly.

**Difficulty:** Medium

**Justification:** WoW StatusBar textures can have their color set, but true gradients require either a custom gradient texture or setting the bar color dynamically on each update based on percentage. The dynamic approach is simpler and works with any texture.

**Technical considerations:**
- Calculate color interpolation: `lerp(lowColor, highColor, percentage)`
- Could use two-stop or three-stop gradients (low/mid/high colors)
- Apply in each Update function: `bar:SetStatusBarColor(interpolatedR, interpolatedG, interpolatedB)`
- Config UI needs color pickers for gradient stops (min 2, ideally 3)
- The Monk stagger bar's existing threshold-based coloring is a simplified version of this

---

### 13. Border Customization

**Description:** Allow users to choose border styles, colors, thickness, or to disable borders entirely. Currently the frame uses `UI-Tooltip-Border` with alpha 0 (effectively hidden).

**Why it would be useful:** Border styling is a common request for UI consistency. Some players want visible borders to delineate the bar; others want completely borderless bars for a minimalist look.

**Difficulty:** Easy

**Justification:** The backdrop system is already in place via `BackdropTemplate`. Changing the `edgeFile`, `edgeSize`, and border color is a matter of config values and a call to `SetBackdrop()` / `SetBackdropBorderColor()`.

**Technical considerations:**
- Multiple border texture options built into WoW: `UI-Tooltip-Border`, `ChatBubble-Header`, etc.
- Store selection in SavedVariables
- Consider also adding per-block borders for discrete resources

---

## Configuration and Profiles

### 14. Per-Spec Color Profiles

**Description:** Allow different color schemes for different specializations of the same class. For example, a Druid could have different energy bar colors for Feral vs. Guardian, or a Priest could have different mana bar colors for Holy vs. Discipline.

**Why it would be useful:** Players who frequently switch specs may want visual differentiation. A Brewmaster Monk's energy bar could be a different color from a Windwalker's to provide instant spec recognition.

**Difficulty:** Medium

**Justification:** Currently, colors are stored per resource type globally (e.g., `colors.energy`). This would require restructuring color storage to be keyed by spec ID (e.g., `colors[specID].energy`). All color lookups in class modules would need to be updated. The config UI would need a spec selector.

**Technical considerations:**
- Data structure change: `MonkStaggerBarDB.specColors[specID] = { resource = {r,g,b}, ... }`
- Fallback to global colors if spec-specific not defined
- Migration logic for existing saved variables
- Config UI needs a spec dropdown or tabs within class pages

---

### 15. Full Profile System (Import/Export)

**Description:** Implement named profiles that save all settings (position, size, colors, ratios, toggles). Include the ability to export a profile as a text string and import from a string, enabling sharing between characters or players.

**Why it would be useful:** Players with multiple characters want consistent UI settings. Sharing configurations in guides or community forums is common practice. Eliminates the need to manually recreate settings on alts.

**Difficulty:** Hard

**Justification:** Requires serializing the entire `MonkStaggerBarDB` table to a compact string format (Base64-encoded, compressed). The import UI needs a large editbox for pasting. Multiple named profiles need a management UI (create, delete, switch, rename). WoW does not provide native compression, so a library like LibDeflate or AceSerializer would help, though a simpler approach using `string.format` and manual parsing is possible.

**Technical considerations:**
- Serialization: Convert table to string. Libraries like AceSerializer exist, or implement manual serialization.
- Compression: Optional but recommended for shorter strings. LibDeflate is lightweight.
- Encoding: Base64 for clipboard-safe strings
- UI: Large `EditBox` frame for copy/paste
- Profile management: array of named profiles in SavedVariables
- Per-character or account-wide profile selection
- Version checking on import to handle schema changes

---

### 16. Reset to Defaults Button

**Description:** Add a "Reset to Defaults" button in the config UI, both globally and per-class-page.

**Why it would be useful:** After extensive customization, players may want to start fresh without manually resetting every slider and color picker. This is a standard UX expectation for settings panels.

**Difficulty:** Easy

**Justification:** The `defaults` table already exists in Core.lua. A reset function would copy relevant defaults back into `MonkStaggerBarDB` and call `addon.UpdateLayout()` / `addon.UpdateTextures()`. Per-class reset would only restore that class's color entries.

**Technical considerations:**
- Global reset: `MonkStaggerBarDB = CopyTable(defaults)` then reload UI or call all update functions
- Per-class reset: iterate over class-specific keys in defaults and overwrite
- Add confirmation dialog to prevent accidental resets

---

### 17. Rename SavedVariables from Legacy Name

**Description:** Migrate the SavedVariables name from `MonkStaggerBarDB` to a more appropriate name like `ClassResourceBarDB`, reflecting the addon's current scope.

**Why it would be useful:** The legacy name is confusing for new users and developers. It implies the addon is Monk-only. A proper name improves code clarity and user understanding.

**Difficulty:** Medium

**Justification:** Changing the SavedVariables name in the TOC is trivial, but requires a migration path so existing users do not lose their settings. On first load with the new name, check if `MonkStaggerBarDB` exists and copy it to `ClassResourceBarDB`, then nil out the old one.

**Technical considerations:**
- TOC change: `## SavedVariables: ClassResourceBarDB`
- Migration in Core.lua PLAYER_LOGIN: if `ClassResourceBarDB` is nil and `MonkStaggerBarDB` is not nil, copy over
- All references to `MonkStaggerBarDB` throughout the entire codebase must be updated (every file references it)
- Consider keeping `MonkStaggerBarDB` as a secondary SavedVariables entry during a transition period
- This is a breaking change for users who downgrade

---

## Class-Specific Enhancements

### 18. Druid Combo Points Display (Feral)

**Description:** Add combo point blocks for Feral Druids, similar to the Rogue module. Currently the Druid module only shows Energy and Mana but does not display Combo Points, which are a core Feral resource.

**Why it would be useful:** Feral Druids rely on Combo Points as heavily as Rogues do. The current implementation shows only Energy, missing half of the Feral resource picture. This is arguably a feature gap rather than just an enhancement.

**Difficulty:** Medium

**Justification:** The Rogue module already implements Combo Points with blocks. The Druid module would need to add similar block creation and a three-way layout (Combo Points top, Energy middle, Mana bottom) or a two-way layout with a ratio slider. The shapeshift form detection already exists.

**Technical considerations:**
- Reuse the Rogue's combo block pattern
- Layout becomes more complex: three resources in one frame
- Need to handle form changes (combo points only relevant in Cat form or with talent)
- Events: `UNIT_POWER_UPDATE` with `COMBO_POINTS` token already works
- Add combo point color to defaults and Druid config page

---

### 19. Death Knight Rune Type Coloring

**Description:** Color individual runes based on their type or readiness state with more granularity. Optionally, allow coloring by rune index position to provide a fixed visual reference.

**Why it would be useful:** In the current implementation, runes are either "ready" or "recharging" with two colors. Some players may prefer per-rune-slot coloring or want to distinguish runes that are close to finishing their cooldown from those that just started.

**Difficulty:** Easy

**Justification:** The rune bars already exist and have individual status bar colors. Adding a gradient based on remaining cooldown time (`(GetTime() - start) / duration`) would be a simple enhancement to the existing `UpdateRunes()` function.

**Technical considerations:**
- `GetRuneCooldown(i)` returns start, duration, runeReady
- Cooldown progress: `progress = (GetTime() - start) / duration`
- Interpolate color from recharging to ready based on progress
- Config: optional toggle between binary coloring and gradient coloring

---

### 20. Monk Stagger Decay Timer

**Description:** Display the rate at which stagger is decaying, or a small timer/text showing how long until stagger reaches zero at the current decay rate.

**Why it would be useful:** Brewmaster Monks make decisions based on stagger management (when to Purify, when to use defensives). Knowing the decay rate or time-to-zero adds decision-making information that the raw stagger number alone does not convey.

**Difficulty:** Medium

**Justification:** Stagger decay rate can be estimated by tracking `UnitStagger("player")` over time and computing the delta. The stagger already has an OnUpdate loop. The challenge is handling combat-protected values (`issecretvalue()`) which can interrupt tracking.

**Technical considerations:**
- Track `addon.lastStagger` values over a rolling window (e.g., last 1 second)
- Compute decay rate as `(previousStagger - currentStagger) / elapsed`
- Display as additional text on the stagger bar (e.g., "-5000/s")
- Handle `issecretvalue()` returns gracefully
- Decay rate estimation may be noisy; consider smoothing

---

### 21. Warlock Destruction Shard Fragment Count

**Description:** Display a numeric overlay on each soul shard block showing the number of fragments (0-9) for Destruction spec, giving a precise readout alongside the visual fill.

**Why it would be useful:** The progressive fill on Destruction shard blocks conveys approximate fragment count visually, but an exact number removes ambiguity, especially when fragments are gained in small increments.

**Difficulty:** Easy

**Justification:** The shard blocks already exist as StatusBar frames. Adding a FontString to each block and setting the text to the fragment count is minimal work. The fragment data is already being calculated in `UpdateWarlockResources()`.

**Technical considerations:**
- Add `.text` FontString to each shard block during initialization
- Set text to `shardBits` value in the update function
- Only show text for Destruction spec; hide for Affliction/Demonology
- Font size needs to be small enough to fit within a block

---

### 22. Enhancement Shaman Maelstrom Weapon Stacks

**Description:** In addition to (or instead of) the Maelstrom power bar, display Maelstrom Weapon buff stacks as discrete blocks for Enhancement Shamans.

**Why it would be useful:** Enhancement Shamans track Maelstrom Weapon stacks (an aura) as a primary resource for instant-cast spells. This is distinct from the Maelstrom power type and is arguably more important for Enhancement gameplay.

**Difficulty:** Medium

**Justification:** Maelstrom Weapon is a buff, not a power type. It requires aura scanning via `AuraUtil.FindAuraByName()` or `C_UnitAuras.GetAuraDataBySpellName()`. The display would use discrete blocks similar to combo points. Needs spec detection to show only for Enhancement.

**Technical considerations:**
- Spell: "Maelstrom Weapon" (needs spell ID for reliability)
- API: `C_UnitAuras.GetAuraDataBySpellName("player", "Maelstrom Weapon")` returns applications (stacks)
- Max stacks is typically 10 (talent-dependent)
- Event: `UNIT_AURA` for aura changes
- Could coexist with or replace the Maelstrom power bar depending on user preference

---

### 23. Paladin Protection Shield of the Righteous Tracking

**Description:** For Protection Paladins, display the remaining duration of the Shield of the Righteous buff as a timer or cooldown overlay on the bar.

**Why it would be useful:** Shield of the Righteous uptime is a critical metric for Protection Paladin survivability. Tracking its duration alongside Holy Power (which fuels it) creates a complete resource management display.

**Difficulty:** Medium

**Justification:** Requires aura tracking (`UNIT_AURA` event, `C_UnitAuras` API) and either a timer text overlay or a secondary bar showing buff duration. The infrastructure for dual bars (blocks + status bar) already exists in the Paladin module.

**Technical considerations:**
- Track the "Shield of the Righteous" buff via `C_UnitAuras.GetAuraDataBySpellName()`
- Display as a small timer text, or repurpose the mana bar area for a duration bar during active buff
- Event: `UNIT_AURA`
- Spec-specific: only show for Protection (specID 66)

---

### 24. Demon Hunter Havoc Meta Timer

**Description:** Display a timer or duration bar for Metamorphosis when active for Havoc Demon Hunters.

**Why it would be useful:** Metamorphosis is a major cooldown for Havoc. Seeing its remaining duration alongside Fury helps players optimize ability usage during the buff window.

**Difficulty:** Medium

**Justification:** Similar to Protection Paladin SotR tracking. Requires aura monitoring and either a text overlay or a secondary bar. The current DH module only shows a single Fury bar, so there is room in the layout.

**Technical considerations:**
- Track "Metamorphosis" buff via aura API
- Could add a small timer bar below the Fury bar using a split ratio
- Only relevant during the buff; bar section could hide/show dynamically
- Event: `UNIT_AURA`

---

## Quality of Life

### 25. Minimap Button Toggle

**Description:** Add an option to show or hide the minimap button entirely, for players who use minimap button management addons or prefer a clean minimap.

**Why it would be useful:** Many players use addons like MBB (MinimapButtonBag) or simply dislike minimap clutter. Providing a toggle is standard practice for well-behaved addons.

**Difficulty:** Easy

**Justification:** Add a checkbox in config that calls `MonkStaggerBarMinimapButton:Hide()` or `:Show()`. Store the preference in SavedVariables. Apply on login.

**Technical considerations:**
- Store as `MonkStaggerBarDB.showMinimapButton` (default true)
- Apply in `addon.CreateMinimapButton()` after creation
- If hidden, players can still access config via `/msb` slash command
- Consider integration with LibDBIcon for proper minimap button management

---

### 26. Frame Strata and Level Controls

**Description:** Allow users to set the frame strata (BACKGROUND, LOW, MEDIUM, HIGH) and frame level of the resource bar, controlling how it layers with other UI elements.

**Why it would be useful:** In complex UIs with many addons, frame overlap is common. Controlling strata lets users ensure the resource bar is always visible (or intentionally behind other elements).

**Difficulty:** Easy

**Justification:** Single API call: `frame:SetFrameStrata("MEDIUM")`. Add a dropdown in the General config page. Store the selection in SavedVariables.

**Technical considerations:**
- API: `Frame:SetFrameStrata(strata)`, `Frame:SetFrameLevel(level)`
- Valid strata: "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP"
- Default should be "MEDIUM"
- Frame level is a numeric value within a strata for fine control

---

### 27. Bar Scale Option

**Description:** Add a scale slider that uniformly scales the entire resource bar frame, independent of width/height.

**Why it would be useful:** Scale provides a quick way to resize everything proportionally (including text, borders, and gaps) without adjusting individual width/height values. Useful for players on high-DPI displays.

**Difficulty:** Easy

**Justification:** Single API call: `frame:SetScale(value)`. One slider in config. Very straightforward.

**Technical considerations:**
- API: `Frame:SetScale(scale)`
- Scale affects mouse interaction regions, so dragging/resizing adjustments may need `GetEffectiveScale()` corrections
- Store as `MonkStaggerBarDB.scale` (default 1.0)
- Interacts with WoW's UI scale setting; `GetEffectiveScale()` accounts for this

---

### 28. Additional Slash Commands

**Description:** Expand the slash command system to support subcommands: `/msb toggle` (show/hide), `/msb lock`/`unlock`, `/msb reset` (reset position to center), `/msb profile <name>` (switch profiles, if implemented).

**Why it would be useful:** Power users and macro creators benefit from command-line control. Toggle commands can be bound to macros for situational visibility. Reset position is a recovery tool when the bar is dragged off-screen.

**Difficulty:** Easy

**Justification:** The slash command handler already exists. Adding `msg` parsing with `string.split` or pattern matching for subcommands is minimal work.

**Technical considerations:**
- Parse `msg` in `SlashCmdList["MONKSTAGGERBAR"]`
- Example: `if msg == "toggle" then frame:SetShown(not frame:IsShown())`
- `reset` subcommand: set x=0, y=-200, call `UpdateLayout()`
- Print help text for `/msb help`

---

### 29. Update Tooltip and Minimap Button Text

**Description:** Update the minimap button tooltip from "Monk Stagger Bar" to "Class Resource Bar" to match the addon's current identity. Similarly, update the config window title.

**Why it would be useful:** Reduces confusion for players who installed the addon expecting class-wide support. The current tooltip and config title still reference the Monk-specific origin.

**Difficulty:** Easy

**Justification:** Two string changes: one in `addon.CreateMinimapButton()` and one in `addon.OpenConfig()`. Purely cosmetic.

**Technical considerations:**
- Change `GameTooltip:SetText("Monk Stagger Bar")` to `GameTooltip:SetText("Class Resource Bar")`
- Change `configFrame.title:SetText("Monk Stagger Bar Config")` to `configFrame.title:SetText("Class Resource Bar Config")`
- Consider also renaming the slash commands to `/crb` while keeping the old ones as aliases

---

### 30. Config Page Auto-Detection

**Description:** When opening the config panel, automatically navigate to the class page that matches the player's current class, instead of always defaulting to "General".

**Why it would be useful:** Most users will want to adjust their own class's settings first. Auto-selecting the relevant page saves a click and makes the UI feel smarter.

**Difficulty:** Easy

**Justification:** At config open, check `select(2, UnitClass("player"))` and call `SwitchTo(className)`. The navigation system already supports switching by name.

**Technical considerations:**
- Class name mapping: `UnitClass("player")` returns localized name and uppercase English token
- The config pages use display names ("Death Knight", "Demon Hunter") while UnitClass returns tokens ("DEATHKNIGHT", "DEMONHUNTER")
- Build a lookup table mapping tokens to display names
- Could default to class page on first open, General on subsequent opens within the same session

---

## Advanced Features

### 31. LibSharedMedia Integration

**Description:** Integrate with the LibSharedMedia library to allow users to select from a wide variety of community-provided bar textures and fonts, instead of the hardcoded five texture options.

**Why it would be useful:** LibSharedMedia is the de facto standard for UI customization in WoW. Many players install texture/font packs and expect addons to support LSM. This dramatically expands the visual customization options.

**Difficulty:** Medium

**Justification:** Requires adding LibSharedMedia as an optional dependency (embedded or external). The texture dropdown would be populated from `LSM:List("statusbar")` instead of a hardcoded list. Font selection would use `LSM:List("font")`. The library handles path resolution.

**Technical considerations:**
- Add `## OptionalDeps: LibSharedMedia-3.0` to TOC
- Fallback to hardcoded list if LSM is not installed
- LSM registration: `LSM:Register("statusbar", "MyTexture", path)`
- Dropdown population: `for _, name in ipairs(LSM:List("statusbar")) do ... end`
- Path resolution: `LSM:Fetch("statusbar", name)`
- Consider also supporting LibSharedMedia-registered fonts for text overlays

---

### 32. DataBroker / LDB Support

**Description:** Implement a LibDataBroker data source so the addon's current resource values can be displayed in LDB display addons (Titan Panel, Bazooka, ChocolateBar, etc.).

**Why it would be useful:** Some players prefer consolidated data displays. LDB support allows resource values to appear in data bars or panels, providing an alternative to or complement of the visual bar.

**Difficulty:** Medium

**Justification:** LibDataBroker is a lightweight protocol. Creating an LDB object with `text` and `OnClick` fields is straightforward. Updating the text on resource change events is the main ongoing work.

**Technical considerations:**
- Create LDB data object: `LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(...)`
- Update `text` field in resource update functions
- `OnClick` launches config
- `OnTooltipShow` shows detailed resource info
- Optional dependency: `## OptionalDeps: LibDataBroker-1.1`

---

### 33. Multi-Frame Mode (Separate Bars)

**Description:** Instead of a single combined frame, allow users to split resources into separate, independently positioned frames. For example, a Rogue could have Combo Points in one location and Energy in another.

**Why it would be useful:** Some players position different resources in different screen areas for optimal visibility. A combined frame forces all resources to the same location, which may not suit every UI layout.

**Difficulty:** Hard

**Justification:** This is a fundamental architectural change. Currently, all bars are children of a single `addon.Frame`. Multi-frame mode would require creating multiple parent frames, each with independent position/size SavedVariables, and reworking every class module's layout logic. The config UI would need per-frame position/size controls.

**Technical considerations:**
- Each resource type gets its own parent frame
- Separate SavedVariables for each frame's position/size
- Class modules need to be refactored to work with multiple parent frames
- Dragging/resizing for each frame independently
- Consider implementing as an alternative "mode" rather than replacing the current single-frame approach
- This is the most complex feature on this list but also one of the most requested in resource bar addons

---

### 34. Power Cost Prediction

**Description:** Show a transparent overlay or marker on the bar indicating how much resource the next queued ability would cost. For example, if a Rogue has 80 Energy and the next ability costs 35, show a marker or shaded region indicating the post-cast energy level.

**Why it would be useful:** Helps players plan resource usage by visualizing the cost of their next action. Common in advanced UI frameworks like ElvUI.

**Difficulty:** Hard

**Justification:** Requires hooking into the spell casting system to detect the next queued spell, looking up its resource cost via `GetSpellPowerCost()`, and rendering a prediction overlay on the bar. The cost lookup and overlay rendering are moderately complex, and handling spell queue edge cases adds difficulty.

**Technical considerations:**
- API: `GetSpellPowerCost(spellID)` returns cost table
- Detect current/queued spell: `CastingInfo()`, spell queue monitoring
- Render: create a secondary texture overlay on the status bar with reduced alpha
- Must handle variable costs (e.g., Execute rage scaling)
- Event: `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_STOP`, `CURRENT_SPELL_CAST_CHANGED`

---

### 35. WeakAura-Style Conditional Display Rules

**Description:** Provide a simple rules engine for conditional visibility and coloring. For example: "If energy < 30, change bar color to red" or "If target is boss, show bar; otherwise hide." This would be a simplified version of WeakAuras triggers.

**Why it would be useful:** Bridges the gap between the addon's current static configuration and WeakAuras' dynamic behavior, without requiring WeakAuras itself. Allows power users to create situational visual cues.

**Difficulty:** Hard

**Justification:** Requires designing a rule definition system, a UI for creating/editing rules, and an evaluation engine that checks conditions on each update. This is essentially a mini scripting system. While powerful, it risks scope creep and complexity.

**Technical considerations:**
- Rule format: `{ condition = "resource < threshold", action = "setColor", params = {r,g,b} }`
- Evaluation: parse conditions, check against current state
- UI: dropdown-based rule builder (avoid freeform Lua for security)
- Performance: rules must be evaluated efficiently (throttled or event-driven)
- Could start with a limited set of conditions (resource thresholds) and actions (color change, visibility)

---

## Accessibility

### 36. Color Blind Mode / Preset Color Schemes

**Description:** Offer preset color schemes designed for common color vision deficiencies (protanopia, deuteranopia, tritanopia). Instead of manually configuring colors, users can select a preset that ensures all resource indicators are distinguishable.

**Why it would be useful:** Approximately 8% of males and 0.5% of females have some form of color vision deficiency. Color-dependent resource tracking (especially the Monk stagger green/yellow/red progression) can be problematic. Presets remove the burden of manual color selection.

**Difficulty:** Medium

**Justification:** Requires defining 3-4 preset color tables with colors chosen for accessibility (e.g., blue/orange instead of green/red). The config UI needs a "Color Scheme" dropdown that bulk-applies colors. The actual color application uses existing infrastructure.

**Technical considerations:**
- Research color-blind-safe palettes (e.g., Okabe-Ito, Wong palette)
- Preset tables that override `MonkStaggerBarDB.colors` entries
- "Custom" option preserves user-defined colors
- Could integrate with WoW's built-in color blind settings (`GetCVarBool("colorblindMode")`)
- Monk stagger thresholds (green/yellow/red) are the highest priority for accessible alternatives

---

### 37. Screen Reader / Accessibility Text Announcements

**Description:** Option to output resource values to chat or screen reader-compatible text when they reach certain thresholds (e.g., announce "5 combo points" or "Stagger is heavy").

**Why it would be useful:** Players who rely on screen readers or have difficulty seeing small UI elements benefit from text-based announcements of important resource states.

**Difficulty:** Easy

**Justification:** Check thresholds in update functions and call `print()` or `UIErrorsFrame:AddMessage()` when crossed. Throttle announcements to avoid spam. Simple conditionals added to existing update logic.

**Technical considerations:**
- Throttle announcements (e.g., once per threshold crossing, not every frame)
- Track previous state to detect crossings: `if prev < threshold and current >= threshold then announce`
- Output options: chat frame, UIErrorsFrame, or MSBT/Parrot integration
- Configurable thresholds and toggle per resource
- Keep announcements concise and non-spammy

---

### 38. Large Mode / Simplified Display

**Description:** A "large mode" that dramatically increases the size of discrete resource indicators (combo points, holy power, etc.) and uses high-contrast colors, optimized for visibility at a glance.

**Why it would be useful:** Players with visual impairments or those who play on large screens at a distance benefit from oversized, high-contrast resource indicators. Also useful for streaming where viewers need to see resources clearly.

**Difficulty:** Easy

**Justification:** This is essentially a preset that sets width to 400+, height to 40+, and applies high-contrast colors. Could be implemented as a one-click preset or a "Large Mode" toggle.

**Technical considerations:**
- Preset values for width, height, and colors
- Could also increase font size for text overlays
- Consider adding an outline to text (`OUTLINE` flag in `SetFont()`) for better readability
- One-button application similar to the "Reset to Defaults" concept

---

## Summary Table

| # | Feature | Category | Difficulty |
|---|---------|----------|------------|
| 1 | Combat Visibility Toggle | Visibility | Easy |
| 2 | Instance/Zone-Based Visibility | Visibility | Medium |
| 3 | Conditional Visibility (Target) | Visibility | Easy |
| 4 | Opacity / Alpha Slider | Visibility | Easy |
| 5 | Vertical Bar Orientation | Visibility | Hard |
| 6 | Per-Bar Background Color/Alpha | Visibility | Easy |
| 7 | Text Display Options | Text | Medium |
| 8 | Mana as Percentage | Text | Easy |
| 9 | Tick Marks / Threshold Indicators | Text | Medium |
| 10 | Smooth Bar Fill Animation | Animation | Medium |
| 11 | Flash on Max Resource | Animation | Medium |
| 12 | Color Gradient on Continuous Bars | Animation | Medium |
| 13 | Border Customization | Animation | Easy |
| 14 | Per-Spec Color Profiles | Config | Medium |
| 15 | Full Profile System (Import/Export) | Config | Hard |
| 16 | Reset to Defaults Button | Config | Easy |
| 17 | Rename SavedVariables | Config | Medium |
| 18 | Druid Combo Points (Feral) | Class | Medium |
| 19 | DK Rune Cooldown Gradient | Class | Easy |
| 20 | Monk Stagger Decay Timer | Class | Medium |
| 21 | Warlock Destruction Fragment Count | Class | Easy |
| 22 | Enhancement Maelstrom Weapon Stacks | Class | Medium |
| 23 | Paladin SotR Duration Tracking | Class | Medium |
| 24 | DH Havoc Meta Timer | Class | Medium |
| 25 | Minimap Button Toggle | QoL | Easy |
| 26 | Frame Strata / Level Controls | QoL | Easy |
| 27 | Bar Scale Option | QoL | Easy |
| 28 | Additional Slash Commands | QoL | Easy |
| 29 | Update Tooltip / Title Text | QoL | Easy |
| 30 | Config Auto-Detect Class | QoL | Easy |
| 31 | LibSharedMedia Integration | Advanced | Medium |
| 32 | DataBroker / LDB Support | Advanced | Medium |
| 33 | Multi-Frame Mode | Advanced | Hard |
| 34 | Power Cost Prediction | Advanced | Hard |
| 35 | Conditional Display Rules | Advanced | Hard |
| 36 | Color Blind Presets | Accessibility | Medium |
| 37 | Screen Reader Announcements | Accessibility | Easy |
| 38 | Large Mode / Simplified Display | Accessibility | Easy |
