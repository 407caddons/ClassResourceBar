local addonName, addon = ...

-- Only load for Shamans
local _, playerClass = UnitClass("player")
if playerClass ~= "SHAMAN" then return end

-- Resources
local maelstromBar, manaBar

-- Defaults
local MAELSTROM_COLOR = {r = 0, g = 0.5, b = 1}
local MANA_COLOR = {r = 0, g = 0, b = 1}

-- Spec IDs
local SPEC_ELEMENTAL = 262
local SPEC_ENHANCEMENT = 263
local SPEC_RESTORATION = 264

function addon.InitializeModule()
    local frame = addon.Frame
    
    -- Setup Mana Bar (Bottom 20%)
    manaBar = CreateFrame("StatusBar", nil, frame)
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    manaBar:SetStatusBarTexture(texture)
    
    local cMana = MonkStaggerBarDB.colors.shamanMana or MANA_COLOR
    manaBar:SetStatusBarColor(cMana.r, cMana.g, cMana.b)
    
    -- Background
    local manaBg = manaBar:CreateTexture(nil, "BACKGROUND")
    manaBg:SetAllPoints(true)
    manaBg:SetColorTexture(0, 0, 0, 0.5)
    
    -- Mana Text
    manaBar.text = manaBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    manaBar.text:SetPoint("CENTER")

    -- Setup Maelstrom Bar (Top 80%)
    maelstromBar = CreateFrame("StatusBar", nil, frame)
    maelstromBar:SetStatusBarTexture(texture)
    
    local cMaelstrom = MonkStaggerBarDB.colors.maelstrom or MAELSTROM_COLOR
    maelstromBar:SetStatusBarColor(cMaelstrom.r, cMaelstrom.g, cMaelstrom.b)
    
    local maelstromBg = maelstromBar:CreateTexture(nil, "BACKGROUND")
    maelstromBg:SetAllPoints(true)
    maelstromBg:SetColorTexture(0.1, 0, 0.2, 0.8)
    
    maelstromBar.text = maelstromBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    maelstromBar.text:SetPoint("CENTER")
    
    -- Register Events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")

    eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "UNIT_POWER_UPDATE" and arg1 == "player" then
            if arg2 == "MAELSTROM" or arg2 == "MANA" then
                addon.UpdateShamanResources()
            end
        elseif event == "UNIT_MAXPOWER" and arg1 == "player" then
            addon.UpdateShamanResources()
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LOGIN" then
            addon.OnLayoutUpdate()
            addon.UpdateShamanResources()
        end
    end)
    
    addon.OnLayoutUpdate()
    addon.UpdateShamanResources()
end

function addon.UpdateShamanResources()
    if not manaBar then return end
    
    -- Mana
    local mana = UnitPower("player", Enum.PowerType.Mana)
    local maxMana = UnitPowerMax("player", Enum.PowerType.Mana)
    manaBar:SetMinMaxValues(0, maxMana)
    manaBar:SetValue(mana)
    manaBar.text:SetText(mana)
    
    local cMana = MonkStaggerBarDB.colors.shamanMana or MANA_COLOR
    manaBar:SetStatusBarColor(cMana.r, cMana.g, cMana.b)
    
    -- Maelstrom
    if maelstromBar:IsVisible() then
        local maelstrom = UnitPower("player", Enum.PowerType.Maelstrom)
        local maxMaelstrom = UnitPowerMax("player", Enum.PowerType.Maelstrom)
        
        maelstromBar:SetMinMaxValues(0, maxMaelstrom)
        maelstromBar:SetValue(maelstrom)
        maelstromBar.text:SetText(maelstrom)
        
        local cMaelstrom = MonkStaggerBarDB.colors.maelstrom or MAELSTROM_COLOR
        maelstromBar:SetStatusBarColor(cMaelstrom.r, cMaelstrom.g, cMaelstrom.b)
    end
end

function addon.OnLayoutUpdate()
    if not manaBar then return end
    local frame = addon.Frame
    local w, h = MonkStaggerBarDB.width, MonkStaggerBarDB.height
    
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    
    local isElemental = (specID == SPEC_ELEMENTAL)
    local isEnhancement = (specID == SPEC_ENHANCEMENT)
    -- Enhancement technically uses Maelstrom too, but often tracks Maelstrom Weapon Stacks (Aura).
    -- Standard Resource Bar tracks Maelstrom (Power) for both.
    
    local showMaelstrom = (isElemental or isEnhancement)
    
    local gap = 2
    local availableHeight = h - gap
    local manaRatio = MonkStaggerBarDB.shamanManaRatio or 0.2
    
    if showMaelstrom then
        maelstromBar:Show()
        
        local maelstromHeight = availableHeight * (1 - manaRatio)
        local manaHeight = availableHeight * manaRatio
        
        maelstromBar:SetSize(w, maelstromHeight)
        maelstromBar:SetPoint("TOPLEFT", frame, "TOPLEFT")
        
        manaBar:SetSize(w, manaHeight)
        manaBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    else
        maelstromBar:Hide()
        
        -- Full Mana Bar (Resto)
        manaBar:SetSize(w, h)
        manaBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    end
end

function addon.OnTextureUpdate()
    if not manaBar then return end
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    manaBar:SetStatusBarTexture(texture)
    if maelstromBar then maelstromBar:SetStatusBarTexture(texture) end
end
