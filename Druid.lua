local addonName, addon = ...

-- Only load for Druids
local _, playerClass = UnitClass("player")
if playerClass ~= "DRUID" then return end

-- Resources
local rageBar, energyBar, manaBar
local topBar, bottomLeftBar, bottomRightBar

-- Colors (Defaults, will be overwritten by DB)
local COLOR_RAGE = {r=1, g=0, b=0}
local COLOR_ENERGY = {r=1, g=1, b=0}
local COLOR_MANA = {r=0, g=0, b=1}

-- Spec ID
local SPEC_GUARDIAN = 104

-- Forms
local FORM_BEAR = 1
local FORM_CAT = 2
-- Note: Form IDs can vary by race/glyphs/talents (e.g. Incarnation). 
-- Better to check GetShapeshiftFormID() or just GetShapeshiftForm() index.
-- Standard Indices: 1 Bear, 2 Cat, 3 Travel, 4 Moonkin/Tree (often). 
-- API: GetShapeshiftForm() returns index.

function addon.InitializeModule()
    local frame = addon.Frame
    
    -- Create Bars
    rageBar = CreateResourceBar("RageBar", frame)
    energyBar = CreateResourceBar("EnergyBar", frame)
    manaBar = CreateResourceBar("ManaBar", frame)
    
    -- Combo Points on Energy Bar
    energyBar.comboPoints = energyBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    energyBar.comboPoints:SetPoint("LEFT", energyBar, "LEFT", 10, 0)
    energyBar.comboPoints:SetText("")
    
    -- Event Handling
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("PLAYER_LOGIN") 
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

    
    eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "UNIT_POWER_UPDATE" and arg1 == "player" then
            if arg2 == "COMBO_POINTS" then
                addon.UpdateComboPoints()
            else
                addon.UpdateResources()
            end
        elseif event == "UNIT_MAXPOWER" and arg1 == "player" then
             addon.UpdateResources()
        elseif event == "UPDATE_SHAPESHIFT_FORM" then
             addon.UpdateDruidLayout()
             addon.UpdateResources()
             addon.UpdateComboPoints()
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LOGIN" then
             addon.UpdateDruidLayout() -- Checks spec inside
             addon.UpdateResources()
        end
    end)
    
    addon.UpdateDruidLayout()
end

function CreateResourceBar(name, parent)
    local bar = CreateFrame("StatusBar", name, parent)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 100)
    
    -- Background
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0, 0, 0, 0.5)
    
    -- Text
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bar.text:SetPoint("CENTER")
    
    return bar
end

function addon.UpdateDruidLayout()
    if not rageBar then return end
    
    -- Check Spec
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    
    if specID ~= SPEC_GUARDIAN then
        rageBar:Hide()
        energyBar:Hide()
        manaBar:Hide()
        -- Also hide generic frame background if set
        if addon.Frame then addon.Frame:SetBackdropBorderColor(0,0,0,0) end
        return
    end
    
    -- Ensure visible (if not mounted check handles it globally in Core)
    rageBar:Show()
    energyBar:Show()
    manaBar:Show()
    
    -- Determine Form
    local form = GetShapeshiftForm()
    -- 1: Bear, 2: Cat (Usually). Validate with GetShapeshiftFormInfo(foundIndex).
    -- But indices match fairly well.
    
    local top, botLeft, botRight
    
    if form == 1 then -- Bear
        top = rageBar
        botLeft = energyBar
        botRight = manaBar
    elseif form == 2 then -- Cat
        top = energyBar
        botLeft = rageBar
        botRight = manaBar
    else -- Caster / Other
        top = manaBar
        botLeft = rageBar
        botRight = energyBar
    end
    
    -- Set Text Visibility Flags
    top.showText = true
    botLeft.showText = false
    botRight.showText = false

    
    -- Apply Layout
    local width = MonkStaggerBarDB.width or 200
    local height = MonkStaggerBarDB.height or 20
    local bottomRatio = MonkStaggerBarDB.druidBottomRatio or 0.2
    
    local vGap = 2
    local hGap = 2
    local availableHeight = height - vGap
    local topHeight = availableHeight * (1 - bottomRatio)
    local bottomHeight = availableHeight * bottomRatio
    
    -- Top Bar
    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", addon.Frame, "TOPLEFT")
    top:SetPoint("TOPRIGHT", addon.Frame, "TOPRIGHT")
    top:SetHeight(topHeight)
    
    -- Bottom Left
    botLeft:ClearAllPoints()
    botLeft:SetPoint("BOTTOMLEFT", addon.Frame, "BOTTOMLEFT")
    botLeft:SetWidth((width - hGap) / 2)
    botLeft:SetHeight(bottomHeight)
    
    -- Bottom Right
    botRight:ClearAllPoints()
    botRight:SetPoint("BOTTOMRIGHT", addon.Frame, "BOTTOMRIGHT")
    botRight:SetWidth((width - hGap) / 2)
    botRight:SetHeight(bottomHeight)
    
    -- Update Colors
    local cRage = MonkStaggerBarDB.colors.rage or COLOR_RAGE
    rageBar:SetStatusBarColor(cRage.r, cRage.g, cRage.b)
    
    local cEnergy = MonkStaggerBarDB.colors.energy or COLOR_ENERGY
    energyBar:SetStatusBarColor(cEnergy.r, cEnergy.g, cEnergy.b)
    
    local cMana = MonkStaggerBarDB.colors.mana or COLOR_MANA
    manaBar:SetStatusBarColor(cMana.r, cMana.g, cMana.b)
    
    -- Combo Points Visibility
    if form == 2 then 
        energyBar.comboPoints:Show()
        addon.UpdateComboPoints()
    else
        energyBar.comboPoints:Hide()
    end
end

function addon.UpdateResources()
    if not rageBar then return end
    
    -- Rage
    local rage = UnitPower("player", Enum.PowerType.Rage)
    local maxRage = UnitPowerMax("player", Enum.PowerType.Rage)
    rageBar:SetMinMaxValues(0, maxRage)
    rageBar:SetValue(rage)
    if rageBar.showText then rageBar.text:SetText(rage) else rageBar.text:SetText("") end
    
    -- Energy
    local energy = UnitPower("player", Enum.PowerType.Energy)
    local maxEnergy = UnitPowerMax("player", Enum.PowerType.Energy)
    energyBar:SetMinMaxValues(0, maxEnergy)
    energyBar:SetValue(energy)
    if energyBar.showText then energyBar.text:SetText(energy) else energyBar.text:SetText("") end
    
    -- Mana
    local mana = UnitPower("player", Enum.PowerType.Mana)
    local maxMana = UnitPowerMax("player", Enum.PowerType.Mana)
    manaBar:SetMinMaxValues(0, maxMana)
    manaBar:SetValue(mana)
    if manaBar.showText then manaBar.text:SetText(mana) else manaBar.text:SetText("") end
end

function addon.UpdateComboPoints()
    if not energyBar then return end
    local cp = UnitPower("player", Enum.PowerType.ComboPoints)
    if cp and cp > 0 then
        energyBar.comboPoints:SetText(cp)
    else
        energyBar.comboPoints:SetText("")
    end
end

-- Hook Layout Update from Core to resizing
function addon.OnLayoutUpdate()
    addon.UpdateDruidLayout()
end
