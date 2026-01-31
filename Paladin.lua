local addonName, addon = ...

-- Only load for Paladins
local _, playerClass = UnitClass("player")
if playerClass ~= "PALADIN" then return end

local manaBar
local hpBlocks = {}
local HOLY_POWER_COLOR = {r = 1, g = 0.9, b = 0}
local MANA_COLOR = {r = 0, g = 0, b = 1}

-- Protection Paladin Spec ID
local SPEC_PROTECTION = 66

function addon.InitializeModule()
    local frame = addon.Frame
    
    -- Setup Mana Bar (Bottom 20%)
    manaBar = CreateFrame("StatusBar", nil, frame)
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    manaBar:SetStatusBarTexture(texture)
    
    local cMana = MonkStaggerBarDB.colors.paladinMana or MANA_COLOR
    manaBar:SetStatusBarColor(cMana.r, cMana.g, cMana.b)
    
    -- Background
    local manaBg = manaBar:CreateTexture(nil, "BACKGROUND")
    manaBg:SetAllPoints(true)
    manaBg:SetColorTexture(0, 0, 0, 0.5)
    
    -- Mana Text
    manaBar.text = manaBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    manaBar.text:SetPoint("CENTER")

    -- Setup Holy Power Blocks (Top 80%)
    for i = 1, 5 do
        local block = CreateFrame("Frame", nil, frame)
        block.bg = block:CreateTexture(nil, "BACKGROUND")
        block.bg:SetAllPoints(true)
        block.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        
        block.fill = block:CreateTexture(nil, "OVERLAY")
        block.fill:SetAllPoints(true)
        local cHP = MonkStaggerBarDB.colors.holyPower or HOLY_POWER_COLOR
        block.fill:SetColorTexture(cHP.r, cHP.g, cHP.b)
        block.fill:Hide()
        
        hpBlocks[i] = block
    end
    
    -- Register Events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")

    eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "UNIT_POWER_UPDATE" and arg1 == "player" then
            if arg2 == "HOLY_POWER" or arg2 == "MANA" then
                addon.UpdatePaladinResources()
            end
        elseif event == "UNIT_MAXPOWER" and arg1 == "player" then
            addon.UpdatePaladinResources()
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LOGIN" then
            addon.UpdatePaladinVisibility()
            addon.UpdatePaladinResources()
        end
    end)
    
    addon.UpdatePaladinVisibility()
    addon.UpdatePaladinResources()
    addon.OnLayoutUpdate()
end

function addon.UpdatePaladinVisibility()
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    
    local isProt = (specID == SPEC_PROTECTION)
    
    if isProt then
        manaBar:Show()
        for i = 1, 5 do hpBlocks[i]:Show() end
    else
        manaBar:Hide()
        for i = 1, 5 do hpBlocks[i]:Hide() end
    end
end

function addon.UpdatePaladinResources()
    if not manaBar:IsVisible() then return end
    
    -- Mana
    local mana = UnitPower("player", Enum.PowerType.Mana)
    local maxMana = UnitPowerMax("player", Enum.PowerType.Mana)
    manaBar:SetMinMaxValues(0, maxMana)
    manaBar:SetValue(mana)
    manaBar.text:SetText(mana)
    
    local cMana = MonkStaggerBarDB.colors.paladinMana or MANA_COLOR
    manaBar:SetStatusBarColor(cMana.r, cMana.g, cMana.b)
    
    -- Holy Power
    local hp = UnitPower("player", Enum.PowerType.HolyPower)
    local maxHP = UnitPowerMax("player", Enum.PowerType.HolyPower)
    
    local cHP = MonkStaggerBarDB.colors.holyPower or HOLY_POWER_COLOR
    
    for i = 1, 5 do
        if i <= hp then
            hpBlocks[i].fill:Show()
            hpBlocks[i].fill:SetColorTexture(cHP.r, cHP.g, cHP.b)
        else
            hpBlocks[i].fill:Hide()
        end
        
        if i <= maxHP then
            hpBlocks[i]:Show()
        else
            hpBlocks[i]:Hide()
        end
    end
end

function addon.OnLayoutUpdate()
    if not manaBar then return end
    local frame = addon.Frame
    local w, h = MonkStaggerBarDB.width, MonkStaggerBarDB.height
    
    local gap = 2
    local availableHeight = h - gap
    local manaRatio = MonkStaggerBarDB.paladinManaRatio or 0.2
    
    local hpHeight = availableHeight * (1 - manaRatio)
    local manaHeight = availableHeight * manaRatio
    
    -- Mana Bar
    manaBar:SetSize(w, manaHeight)
    manaBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    
    -- Holy Power Blocks
    local blockWidth = w / 5
    for i = 1, 5 do
        hpBlocks[i]:SetSize(blockWidth - 2, hpHeight)
        hpBlocks[i]:SetPoint("TOPLEFT", frame, "TOPLEFT", (i-1) * blockWidth + 1, 0)
    end
end

function addon.OnTextureUpdate()
    if not manaBar then return end
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    manaBar:SetStatusBarTexture(texture)
    -- Holy Power blocks use solid colors, so no texture update needed unless they are converted to StatusBars
end
