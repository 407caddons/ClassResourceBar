local addonName, addon = ...

-- Only load for Mages
local _, playerClass = UnitClass("player")
if playerClass ~= "MAGE" then return end

-- Resources
local manaBar
local chargeBlocks = {}

-- Defaults
local CHARGE_COLOR = {r = 0.1, g = 0.5, b = 1}
local MANA_COLOR = {r = 0, g = 0, b = 1}

-- Spec IDs
local SPEC_ARCANE = 62
local SPEC_FIRE = 63
local SPEC_FROST = 64

function addon.InitializeModule()
    local frame = addon.Frame
    
    -- Setup Mana Bar (Bottom 20%)
    manaBar = CreateFrame("StatusBar", nil, frame)
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    manaBar:SetStatusBarTexture(texture)
    
    local cMana = MonkStaggerBarDB.colors.mageMana or MANA_COLOR
    manaBar:SetStatusBarColor(cMana.r, cMana.g, cMana.b)
    
    -- Background
    local manaBg = manaBar:CreateTexture(nil, "BACKGROUND")
    manaBg:SetAllPoints(true)
    manaBg:SetColorTexture(0, 0, 0, 0.5)
    
    -- Mana Text
    manaBar.text = manaBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    manaBar.text:SetPoint("CENTER")

    -- Setup Arcane Charge Blocks (Top 80%)
    -- Max Charges is usually 4, can be modified by talents? API returns max.
    -- We'll create a few and show/hide/resize as needed.
    for i = 1, 10 do -- Safely create enough
        local block = CreateFrame("Frame", nil, frame)
        block.bg = block:CreateTexture(nil, "BACKGROUND")
        block.bg:SetAllPoints(true)
        block.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        
        block.fill = block:CreateTexture(nil, "OVERLAY")
        block.fill:SetAllPoints(true)
        local cCharge = MonkStaggerBarDB.colors.arcaneCharges or CHARGE_COLOR
        block.fill:SetColorTexture(cCharge.r, cCharge.g, cCharge.b)
        block.fill:Hide()
        
        chargeBlocks[i] = block
        block:Hide() -- Hide initially
    end
    
    -- Register Events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")

    eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "UNIT_POWER_UPDATE" and arg1 == "player" then
            if arg2 == "ARCANE_CHARGES" or arg2 == "MANA" then
                addon.UpdateMageResources()
            end
        elseif event == "UNIT_MAXPOWER" and arg1 == "player" then
            addon.UpdateMageResources()
            addon.OnLayoutUpdate() -- Max charges might change?
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LOGIN" then
            addon.OnLayoutUpdate()
            addon.UpdateMageResources()
        end
    end)
    
    addon.OnLayoutUpdate()
    addon.UpdateMageResources()
end

function addon.UpdateMageResources()
    if not manaBar then return end
    
    -- Mana
    local mana = UnitPower("player", Enum.PowerType.Mana)
    local maxMana = UnitPowerMax("player", Enum.PowerType.Mana)
    manaBar:SetMinMaxValues(0, maxMana)
    manaBar:SetValue(mana)
    manaBar.text:SetText(mana)
    
    local cMana = MonkStaggerBarDB.colors.mageMana or MANA_COLOR
    manaBar:SetStatusBarColor(cMana.r, cMana.g, cMana.b)
    
    -- Arcane Charges
    local charges = UnitPower("player", Enum.PowerType.ArcaneCharges)
    local maxCharges = UnitPowerMax("player", Enum.PowerType.ArcaneCharges)
    
    local cCharge = MonkStaggerBarDB.colors.arcaneCharges or CHARGE_COLOR
    
    for i = 1, #chargeBlocks do
        if i <= maxCharges then
            chargeBlocks[i]:Show()
            if i <= charges then
                chargeBlocks[i].fill:Show()
                chargeBlocks[i].fill:SetColorTexture(cCharge.r, cCharge.g, cCharge.b)
            else
                chargeBlocks[i].fill:Hide()
            end
        else
            chargeBlocks[i]:Hide()
        end
    end
end

function addon.OnLayoutUpdate()
    if not manaBar then return end
    local frame = addon.Frame
    local w, h = MonkStaggerBarDB.width, MonkStaggerBarDB.height
    
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    
    local isArcane = (specID == SPEC_ARCANE)
    
    local gap = 2
    local availableHeight = h - gap
    local manaRatio = MonkStaggerBarDB.mageManaRatio or 0.2
    
    if isArcane then
        -- Secondary Layout
        local chargeHeight = availableHeight * (1 - manaRatio)
        local manaHeight = availableHeight * manaRatio
        
        manaBar:SetSize(w, manaHeight)
        manaBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
        
        local maxCharges = UnitPowerMax("player", Enum.PowerType.ArcaneCharges)
        if not maxCharges or maxCharges == 0 then maxCharges = 4 end -- Fallback
        
        local blockWidth = w / maxCharges
        for i = 1, #chargeBlocks do
            if i <= maxCharges then
                chargeBlocks[i]:SetSize(blockWidth - 1, chargeHeight) -- -1 for gap
                chargeBlocks[i]:SetPoint("TOPLEFT", frame, "TOPLEFT", (i-1) * blockWidth, 0)
                chargeBlocks[i]:Show()
            else
                chargeBlocks[i]:Hide()
            end
        end
    else
        -- Full Mana Bar if not Arcane
        manaBar:SetSize(w, h)
        manaBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
        
        -- Hide all charge blocks
        for i = 1, #chargeBlocks do
            chargeBlocks[i]:Hide()
        end
    end
end

function addon.OnTextureUpdate()
    if not manaBar then return end
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    manaBar:SetStatusBarTexture(texture)
end
