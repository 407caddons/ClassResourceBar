local addonName, addon = ...

-- Only load for Rogues
local _, playerClass = UnitClass("player")
if playerClass ~= "ROGUE" then return end

-- Resources
local energyBar
local comboBlocks = {}

-- Defaults
local COMBO_COLOR = {r = 1, g = 0.9, b = 0}
local ENERGY_COLOR = {r = 1, g = 1, b = 0}

function addon.InitializeModule()
    local frame = addon.Frame
    
    -- Setup Energy Bar (Bottom 20%)
    energyBar = CreateFrame("StatusBar", nil, frame)
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    energyBar:SetStatusBarTexture(texture)
    
    local cEnergy = MonkStaggerBarDB.colors.energy or ENERGY_COLOR
    energyBar:SetStatusBarColor(cEnergy.r, cEnergy.g, cEnergy.b)
    
    -- Background
    local energyBg = energyBar:CreateTexture(nil, "BACKGROUND")
    energyBg:SetAllPoints(true)
    energyBg:SetColorTexture(0, 0, 0, 0.5)
    
    -- Energy Text
    energyBar.text = energyBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    energyBar.text:SetPoint("CENTER")

    -- Setup Combo Point Blocks (Top 80%)
    -- Max CP can vary (5, 6, 7). We create enough blocks.
    for i = 1, 10 do
        local block = CreateFrame("Frame", nil, frame)
        block.bg = block:CreateTexture(nil, "BACKGROUND")
        block.bg:SetAllPoints(true)
        block.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        
        block.fill = block:CreateTexture(nil, "OVERLAY")
        block.fill:SetAllPoints(true)
        local cCombo = MonkStaggerBarDB.colors.comboPoints or COMBO_COLOR
        block.fill:SetColorTexture(cCombo.r, cCombo.g, cCombo.b)
        block.fill:Hide()
        
        comboBlocks[i] = block
    end
    
    -- Register Events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")

    eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "UNIT_POWER_UPDATE" and arg1 == "player" then
            if arg2 == "COMBO_POINTS" or arg2 == "ENERGY" then
                addon.UpdateRogueResources()
            end
        elseif event == "UNIT_MAXPOWER" and arg1 == "player" then
            addon.UpdateRogueResources()
            addon.OnLayoutUpdate() -- Max CP changed
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LOGIN" then
            addon.OnLayoutUpdate()
            addon.UpdateRogueResources()
        end
    end)
    
    addon.OnLayoutUpdate()
    addon.UpdateRogueResources()
end

function addon.UpdateRogueResources()
    if not energyBar then return end
    
    -- Energy
    local energy = UnitPower("player", Enum.PowerType.Energy)
    local maxEnergy = UnitPowerMax("player", Enum.PowerType.Energy)
    energyBar:SetMinMaxValues(0, maxEnergy)
    energyBar:SetValue(energy)
    energyBar.text:SetText(energy)
    
    local cEnergy = MonkStaggerBarDB.colors.energy or ENERGY_COLOR
    energyBar:SetStatusBarColor(cEnergy.r, cEnergy.g, cEnergy.b)
    
    -- Combo Points
    local cp = UnitPower("player", Enum.PowerType.ComboPoints)
    local maxCP = UnitPowerMax("player", Enum.PowerType.ComboPoints)
    
    local cCombo = MonkStaggerBarDB.colors.comboPoints or COMBO_COLOR
    
    for i = 1, 10 do
        if i <= maxCP then
            comboBlocks[i]:Show()
            if i <= cp then
                comboBlocks[i].fill:Show()
                comboBlocks[i].fill:SetColorTexture(cCombo.r, cCombo.g, cCombo.b)
            else
                comboBlocks[i].fill:Hide()
            end
        else
            comboBlocks[i]:Hide()
        end
    end
end

function addon.OnLayoutUpdate()
    if not energyBar then return end
    local frame = addon.Frame
    local w, h = MonkStaggerBarDB.width, MonkStaggerBarDB.height
    
    local gap = 2
    local availableHeight = h - gap
    local energyRatio = MonkStaggerBarDB.rogueEnergyRatio or 0.2
    
    local cpHeight = availableHeight * (1 - energyRatio)
    local energyHeight = availableHeight * energyRatio
    
    -- Energy Bar
    energyBar:SetSize(w, energyHeight)
    energyBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    
    -- Combo Points
    local maxCP = UnitPowerMax("player", Enum.PowerType.ComboPoints)
    if maxCP < 5 then maxCP = 5 end -- Safety default
    
    local blockWidth = w / maxCP
    for i = 1, maxCP do
        comboBlocks[i]:SetSize(blockWidth - 1, cpHeight)
        comboBlocks[i]:SetPoint("TOPLEFT", frame, "TOPLEFT", (i-1) * blockWidth, 0)
    end
end

function addon.OnTextureUpdate()
    if not energyBar then return end
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    energyBar:SetStatusBarTexture(texture)
end
