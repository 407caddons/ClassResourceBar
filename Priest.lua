local addonName, addon = ...

-- Only load for Priests
local _, playerClass = UnitClass("player")
if playerClass ~= "PRIEST" then return end

-- Resources
local insanityBar, manaBar

-- Defaults
local INSANITY_COLOR = {r = 0.4, g = 0, b = 0.8}
local MANA_COLOR = {r = 0, g = 0, b = 1}

-- Spec IDs
local SPEC_SHADOW = 258

function addon.InitializeModule()
    local frame = addon.Frame
    
    -- Setup Mana Bar
    manaBar = CreateFrame("StatusBar", nil, frame)
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    manaBar:SetStatusBarTexture(texture)
    
    local cMana = MonkStaggerBarDB.colors.priestMana or MANA_COLOR
    manaBar:SetStatusBarColor(cMana.r, cMana.g, cMana.b)
    
    -- Background
    local manaBg = manaBar:CreateTexture(nil, "BACKGROUND")
    manaBg:SetAllPoints(true)
    manaBg:SetColorTexture(0, 0, 0, 0.5)
    
    -- Mana Text
    manaBar.text = manaBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    manaBar.text:SetPoint("CENTER")

    -- Setup Insanity Bar (Shadow)
    insanityBar = CreateFrame("StatusBar", nil, frame)
    insanityBar:SetStatusBarTexture(texture)
    
    local cInsanity = MonkStaggerBarDB.colors.insanity or INSANITY_COLOR
    insanityBar:SetStatusBarColor(cInsanity.r, cInsanity.g, cInsanity.b)
    
    local insanityBg = insanityBar:CreateTexture(nil, "BACKGROUND")
    insanityBg:SetAllPoints(true)
    insanityBg:SetColorTexture(0.1, 0, 0.2, 0.8)
    
    insanityBar.text = insanityBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    insanityBar.text:SetPoint("CENTER")
    
    -- Register Events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")

    eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "UNIT_POWER_UPDATE" and arg1 == "player" then
            if arg2 == "INSANITY" or arg2 == "MANA" then
                addon.UpdatePriestResources()
            end
        elseif event == "UNIT_MAXPOWER" and arg1 == "player" then
            addon.UpdatePriestResources()
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LOGIN" then
            addon.OnLayoutUpdate()
            addon.UpdatePriestResources()
        end
    end)
    
    addon.OnLayoutUpdate()
    addon.UpdatePriestResources()
end

function addon.UpdatePriestResources()
    if not manaBar then return end
    
    -- Mana
    local mana = UnitPower("player", Enum.PowerType.Mana)
    local maxMana = UnitPowerMax("player", Enum.PowerType.Mana)
    manaBar:SetMinMaxValues(0, maxMana)
    manaBar:SetValue(mana)
    manaBar.text:SetText(mana)
    
    local cMana = MonkStaggerBarDB.colors.priestMana or MANA_COLOR
    manaBar:SetStatusBarColor(cMana.r, cMana.g, cMana.b)
    
    -- Insanity
    if insanityBar:IsVisible() then
        local insanity = UnitPower("player", Enum.PowerType.Insanity)
        local maxInsanity = UnitPowerMax("player", Enum.PowerType.Insanity)
        
        insanityBar:SetMinMaxValues(0, maxInsanity)
        insanityBar:SetValue(insanity)
        insanityBar.text:SetText(insanity)
        
        local cInsanity = MonkStaggerBarDB.colors.insanity or INSANITY_COLOR
        insanityBar:SetStatusBarColor(cInsanity.r, cInsanity.g, cInsanity.b)
    end
end

function addon.OnLayoutUpdate()
    if not manaBar then return end
    local frame = addon.Frame
    local w, h = MonkStaggerBarDB.width, MonkStaggerBarDB.height
    
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    
    local isShadow = (specID == SPEC_SHADOW)
    
    local gap = 2
    local availableHeight = h - gap
    local manaRatio = MonkStaggerBarDB.priestManaRatio or 0.2
    
    if isShadow then
        insanityBar:Show()
        
        local insanityHeight = availableHeight * (1 - manaRatio)
        local manaHeight = availableHeight * manaRatio
        
        insanityBar:SetSize(w, insanityHeight)
        insanityBar:SetPoint("TOPLEFT", frame, "TOPLEFT")
        
        manaBar:SetSize(w, manaHeight)
        manaBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    else
        insanityBar:Hide()
        
        -- Full Mana Bar
        manaBar:SetSize(w, h)
        manaBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    end
end

function addon.OnTextureUpdate()
    if not manaBar then return end
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    manaBar:SetStatusBarTexture(texture)
    if insanityBar then insanityBar:SetStatusBarTexture(texture) end
end
