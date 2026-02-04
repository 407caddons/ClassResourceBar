local addonName, addon = ...
local _, playerClass = UnitClass("player")
if playerClass ~= "DRUID" then return end

-- Resources
local rageBar, energyBar, manaBar, astralBar

-- Spec IDs
local SPEC_BALANCE = 102
local SPEC_FERAL = 103
local SPEC_GUARDIAN = 104
local SPEC_RESTORATION = 105

-- Defaults
local RAGE_COLOR = {r = 1, g = 0, b = 0}
local ENERGY_COLOR = {r = 1, g = 1, b = 0}
local MANA_COLOR = {r = 0, g = 0, b = 1}
local ASTRAL_COLOR = {r = 0, g = 0.5, b = 1}

function addon.InitializeModule()
    local frame = addon.Frame
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    
    -- 1. Rage Bar
    rageBar = CreateFrame("StatusBar", nil, frame)
    rageBar:SetStatusBarTexture(texture)
    rageBar:SetMinMaxValues(0, 100)
    rageBar:SetValue(0)
    
    local rBg = rageBar:CreateTexture(nil, "BACKGROUND")
    rBg:SetAllPoints(true)
    rBg:SetColorTexture(0, 0, 0, 0.5)
    
    rageBar.text = rageBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rageBar.text:SetPoint("CENTER")
    
    -- 2. Energy Bar
    energyBar = CreateFrame("StatusBar", nil, frame)
    energyBar:SetStatusBarTexture(texture)
    energyBar:SetMinMaxValues(0, 100)
    energyBar:SetValue(0)
    
    local eBg = energyBar:CreateTexture(nil, "BACKGROUND")
    eBg:SetAllPoints(true)
    eBg:SetColorTexture(0, 0, 0, 0.5)
    
    energyBar.text = energyBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    energyBar.text:SetPoint("CENTER")
    
    -- 3. Mana Bar
    manaBar = CreateFrame("StatusBar", nil, frame)
    manaBar:SetStatusBarTexture(texture)
    manaBar:SetMinMaxValues(0, 100)
    manaBar:SetValue(0)
    
    local mBg = manaBar:CreateTexture(nil, "BACKGROUND")
    mBg:SetAllPoints(true)
    mBg:SetColorTexture(0, 0, 0, 0.5)
    
    manaBar.text = manaBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    manaBar.text:SetPoint("CENTER")
    
    -- 4. Astral Power Bar (Balance)
    astralBar = CreateFrame("StatusBar", nil, frame)
    astralBar:SetStatusBarTexture(texture)
    astralBar:SetMinMaxValues(0, 100)
    astralBar:SetValue(0)
    
    local aBg = astralBar:CreateTexture(nil, "BACKGROUND")
    aBg:SetAllPoints(true)
    aBg:SetColorTexture(0, 0, 0, 0.5)
    
    astralBar.text = astralBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    astralBar.text:SetPoint("CENTER")

    -- Events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    eventFrame:RegisterEvent("PLAYER_LOGIN") 
    
    eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "UNIT_POWER_UPDATE" and arg1 == "player" then
            addon.UpdateDruidResources()
        elseif event == "UNIT_MAXPOWER" and arg1 == "player" then
            addon.UpdateDruidResources()
        elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LOGIN" then
            addon.UpdateDruidLayout()
            addon.UpdateDruidResources()
        end
    end)
    
    addon.UpdateDruidLayout()
    addon.UpdateDruidResources()
end

function addon.UpdateDruidResources()
    if not rageBar or not energyBar then return end
    
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    
    -- Rage
    if rageBar:IsVisible() then
        local p = UnitPower("player", Enum.PowerType.Rage)
        local mp = UnitPowerMax("player", Enum.PowerType.Rage)
        rageBar:SetMinMaxValues(0, mp)
        rageBar:SetValue(p)
        rageBar.text:SetText(p)
        local c = MonkStaggerBarDB.colors.rage or RAGE_COLOR
        rageBar:SetStatusBarColor(c.r, c.g, c.b)
    end
    
    -- Energy
    if energyBar:IsVisible() then
        local p = UnitPower("player", Enum.PowerType.Energy)
        local mp = UnitPowerMax("player", Enum.PowerType.Energy)
        energyBar:SetMinMaxValues(0, mp)
        energyBar:SetValue(p)
        energyBar.text:SetText(p)
        local c = MonkStaggerBarDB.colors.druidEnergy or ENERGY_COLOR
        energyBar:SetStatusBarColor(c.r, c.g, c.b)
    end
    
    -- Mana
    if manaBar:IsVisible() then
        local p = UnitPower("player", Enum.PowerType.Mana)
        local mp = UnitPowerMax("player", Enum.PowerType.Mana)
        manaBar:SetMinMaxValues(0, mp)
        manaBar:SetValue(p)
        manaBar.text:SetText(p)
        local c = MonkStaggerBarDB.colors.mana or MANA_COLOR
        manaBar:SetStatusBarColor(c.r, c.g, c.b)
    end
    
    -- Astral Power
    if astralBar:IsVisible() then
        local p = UnitPower("player", Enum.PowerType.LunarPower)
        local mp = UnitPowerMax("player", Enum.PowerType.LunarPower)
        astralBar:SetMinMaxValues(0, mp)
        astralBar:SetValue(p)
        astralBar.text:SetText(p)
        local c = MonkStaggerBarDB.colors.astralPower or ASTRAL_COLOR
        astralBar:SetStatusBarColor(c.r, c.g, c.b)
    end
end

function addon.UpdateDruidLayout()
    if not rageBar then return end
    
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    
    -- Hide All Check
    rageBar:Hide()
    energyBar:Hide()
    manaBar:Hide()
    astralBar:Hide()
    
    local form = GetShapeshiftFormID()
    -- Common IDs: 1 (Cat?), 5 (Bear?), 31 (Moonkin)
    -- Using GetShapeshiftForm() index 1..N is safer usually, but let's stick to logic logic.
    -- Better: Enum.ShapeshiftForm.Bear etc? No.
    -- Let's use standard indices for Bear/Cat detection or FormID if we knew them for sure.
    -- Actually GetShapeshiftForm() returns index.
    -- 1 = Bear, 2 = Cat, 3 = Travel... varies by glyph/talent.
    -- Safest is Checking UnitPowerType? 
    -- Bear = Rage (1), Cat = Energy (3), Moonkin/Caster = Mana (0) or LunarPower (8)
    
    local pType, pToken = UnitPowerType("player")
    
    local frame = addon.Frame
    local w, h = MonkStaggerBarDB.width, MonkStaggerBarDB.height
    local gap = 2
    local availableHeight = h - gap
    local botRatio = MonkStaggerBarDB.druidBottomRatio or 0.2
    
    -- Setup sizing helper
    local function SetSplit(top, bottom)
        local botH = availableHeight * botRatio
        local topH = availableHeight * (1 - botRatio)
        
        top:Show()
        top:SetSize(w, topH)
        top:SetPoint("TOPLEFT", frame, "TOPLEFT")
        
        if bottom then
            bottom:Show()
            bottom:SetSize(w, botH)
            bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
        end
    end
    
    -- If Balance Spec, Prefer Astral Power as primary
    if specID == SPEC_BALANCE then
        -- If Form is Bear/Cat, show those instead? Usually resource mods follow form.
        if pType == Enum.PowerType.Rage then
             -- Bear Form as Balance
             SetSplit(rageBar, astralBar) -- show astral below?
        elseif pType == Enum.PowerType.Energy then
             -- Cat Form as Balance
             SetSplit(energyBar, astralBar)
        else
             -- Moonkin / Human Form -> Astral Power
             -- Replace Mana Bar request: "replace the mana bar with astral power"
             -- Assuming default layout was Top=Mana. Now Top=Astral.
             -- Do we see mana at all? Maybe bottom?
             -- User said "replace", could mean full swap.
             -- Let's show Astral Power as primary. Mana secondary?
             -- Balance druids have Mana, but it's secondary.
             SetSplit(astralBar, manaBar)
        end
        return
    end

    -- Other Specs (Feral, Guardian, Resto)
    if pType == Enum.PowerType.Rage then
        -- Bear Form
        SetSplit(rageBar, manaBar) -- Mana or Energy below? Usually Mana.
    elseif pType == Enum.PowerType.Energy then
        -- Cat Form
        SetSplit(energyBar, manaBar)
    else
        -- Caster Form (Resto / Normal)
        -- Full Mana Bar
        manaBar:Show()
        manaBar:SetSize(w, h)
        manaBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    end
end

function addon.OnTextureUpdate()
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    if rageBar then rageBar:SetStatusBarTexture(texture) end
    if energyBar then energyBar:SetStatusBarTexture(texture) end
    if manaBar then manaBar:SetStatusBarTexture(texture) end
    if astralBar then astralBar:SetStatusBarTexture(texture) end
end
