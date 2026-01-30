local addonName, addon = ...
local _, playerClass = UnitClass("player")
if playerClass ~= "MONK" then return end

local STAGGER_LIGHT = 124275
local STAGGER_MODERATE = 124274
local STAGGER_HEAVY = 124273

local staggerBar, energyBar

local COLOR_ENERGY_DEFAULT = {r=1, g=1, b=0}

function addon.InitializeModule()
    local frame = addon.Frame
    
    -- Create Stagger Bar
    staggerBar = CreateFrame("StatusBar", nil, frame)
    staggerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    staggerBar:GetStatusBarTexture():SetHorizTile(false)
    staggerBar:SetMinMaxValues(0, 100)
    staggerBar:SetValue(0)
    
    local bg = staggerBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0, 0, 0, 0.5)
    
    staggerBar.text = staggerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    staggerBar.text:SetPoint("CENTER")
    staggerBar.text:SetText("0 (0.0%)")
    
    -- Create Energy Bar
    energyBar = CreateFrame("StatusBar", nil, frame)
    energyBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    energyBar:SetMinMaxValues(0, 100)
    energyBar:SetValue(0)
    
    local bg2 = energyBar:CreateTexture(nil, "BACKGROUND")
    bg2:SetAllPoints(true)
    bg2:SetColorTexture(0, 0, 0, 0.5)
    
    energyBar.text = energyBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    energyBar.text:SetPoint("CENTER")
    energyBar.text:SetText("")
    
    -- Event Handling
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("PLAYER_LOGIN")

    eventFrame:SetScript("OnEvent", function(self, event, arg1)
        if event == "UNIT_POWER_UPDATE" and arg1 == "player" then
             addon.UpdateEnergy()
        elseif event == "UNIT_MAXPOWER" and arg1 == "player" then
             addon.UpdateEnergy()
        elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
             addon.UpdateMonkLayout()
             addon.UpdateStagger()
             addon.UpdateEnergy()
        elseif event == "UNIT_HEALTH" then
             addon.UpdateStagger() -- Stagger contextually relates to health cap
        else
             addon.UpdateStagger()
        end
    end)
    
    -- Update Loop for Stagger (Smoother?)
    -- Or trigger via OnEvent. Original had OnUpdate. Keeping it.
    frame:SetScript("OnUpdate", function()
        addon.UpdateStagger()
    end)
    
    addon.UpdateMonkLayout()
    addon.UpdateStagger()
    addon.UpdateEnergy()
end

function addon.UpdateMonkLayout()
    if not staggerBar or not energyBar then return end
    
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    
    -- Only show for Brewmaster (268)
    if specID ~= 268 then
        staggerBar:Hide()
        energyBar:Hide()
        if addon.Frame then addon.Frame:SetBackdropBorderColor(0,0,0,0) end
        return 
    end
    
    -- Check Ratio
    local energyRatio = MonkStaggerBarDB.monkEnergyRatio or 0
    -- 0 means no energy bar (legacy behavior)
    -- 1 means only energy bar (weird but requested logic support)
    
    local width = MonkStaggerBarDB.width or 200
    local height = MonkStaggerBarDB.height or 20
    
    -- If ratio is 0, Stagger takes full height, Energy hidden
    if energyRatio <= 0.01 then
        staggerBar:Show()
        staggerBar:ClearAllPoints()
        staggerBar:SetAllPoints(addon.Frame)
        
        energyBar:Hide()
    elseif energyRatio >= 0.99 then
        staggerBar:Hide()
        
        energyBar:Show()
        energyBar:ClearAllPoints()
        energyBar:SetAllPoints(addon.Frame)
    else
        -- Split
        staggerBar:Show()
        energyBar:Show()
        
        local gap = 2
        local energyHeight = (height - gap) * energyRatio
        local staggerHeight = (height - gap) - energyHeight
        
        staggerBar:ClearAllPoints()
        staggerBar:SetPoint("TOPLEFT", addon.Frame, "TOPLEFT")
        staggerBar:SetPoint("TOPRIGHT", addon.Frame, "TOPRIGHT")
        staggerBar:SetHeight(staggerHeight)
        
        energyBar:ClearAllPoints()
        energyBar:SetPoint("BOTTOMLEFT", addon.Frame, "BOTTOMLEFT")
        energyBar:SetPoint("BOTTOMRIGHT", addon.Frame, "BOTTOMRIGHT")
        energyBar:SetHeight(energyHeight)
    end
    
    -- Update Energy Color
    local cEnergy = MonkStaggerBarDB.colors.monkEnergy or COLOR_ENERGY_DEFAULT
    energyBar:SetStatusBarColor(cEnergy.r, cEnergy.g, cEnergy.b)
end

function addon.UpdateEnergy()
    if not energyBar or not energyBar:IsShown() then return end
    
    local energy = UnitPower("player", Enum.PowerType.Energy)
    local maxEnergy = UnitPowerMax("player", Enum.PowerType.Energy)
    
    energyBar:SetMinMaxValues(0, maxEnergy)
    energyBar:SetValue(energy)
    energyBar.text:SetText(energy)
end

function addon.UpdateStagger()
    if not staggerBar or not staggerBar:IsShown() then return end
    
    local stagger = UnitStagger("player") or 0
    local maxHealth = UnitHealthMax("player")
    local percent = stagger / maxHealth

    staggerBar:SetMinMaxValues(0, maxHealth)
    staggerBar:SetValue(stagger)
    staggerBar.text:SetText(string.format("%d (%.1f%%)", stagger, percent * 100))
    
    -- Colors
    local r, g, b = MonkStaggerBarDB.colors.light.r, MonkStaggerBarDB.colors.light.g, MonkStaggerBarDB.colors.light.b
    
    local isLight = C_UnitAuras.GetPlayerAuraBySpellID(STAGGER_LIGHT)
    local isModerate = C_UnitAuras.GetPlayerAuraBySpellID(STAGGER_MODERATE)
    local isHeavy = C_UnitAuras.GetPlayerAuraBySpellID(STAGGER_HEAVY)

    if isHeavy then
        r, g, b = MonkStaggerBarDB.colors.heavy.r, MonkStaggerBarDB.colors.heavy.g, MonkStaggerBarDB.colors.heavy.b
    elseif isModerate then
        r, g, b = MonkStaggerBarDB.colors.moderate.r, MonkStaggerBarDB.colors.moderate.g, MonkStaggerBarDB.colors.moderate.b
    elseif isLight then
        r, g, b = MonkStaggerBarDB.colors.light.r, MonkStaggerBarDB.colors.light.g, MonkStaggerBarDB.colors.light.b
    end
    
    staggerBar:SetStatusBarColor(r, g, b)
end

function addon.OnLayoutUpdate()
    addon.UpdateMonkLayout()
end
