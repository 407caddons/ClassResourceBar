local addonName, addon = ...

-- Only load for Evokers
local _, playerClass = UnitClass("player")
if playerClass ~= "EVOKER" then return end

-- Resources
local manaBar
local essenceBlocks = {}

-- Defaults
local MANA_COLOR = {r = 0, g = 0.5, b = 1}
local ESSENCE_COLOR = {r = 0.4, g = 0.8, b = 0.9}

function addon.InitializeModule()
    local frame = addon.Frame
    
    -- Setup Mana Bar (Bottom 20%)
    manaBar = CreateFrame("StatusBar", nil, frame)
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    manaBar:SetStatusBarTexture(texture)
    
    local cMana = MonkStaggerBarDB.colors.evokerMana or MANA_COLOR
    manaBar:SetStatusBarColor(cMana.r, cMana.g, cMana.b)
    
    -- Background
    local manaBg = manaBar:CreateTexture(nil, "BACKGROUND")
    manaBg:SetAllPoints(true)
    manaBg:SetColorTexture(0, 0, 0, 0.5)
    
    -- Mana Text
    manaBar.text = manaBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    manaBar.text:SetPoint("CENTER")

    -- Setup Essence Blocks (Top 80%)
    -- Max Essence is usually 5 or 6. We generate enough blocks.
    for i = 1, 10 do
        local block = CreateFrame("Frame", nil, frame)
        block.bg = block:CreateTexture(nil, "BACKGROUND")
        block.bg:SetAllPoints(true)
        block.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        
        block.fill = block:CreateTexture(nil, "OVERLAY")
        block.fill:SetAllPoints(true)
        local cEssence = MonkStaggerBarDB.colors.essence or ESSENCE_COLOR
        block.fill:SetColorTexture(cEssence.r, cEssence.g, cEssence.b)
        block.fill:Hide()
        
        essenceBlocks[i] = block
        block:Hide()
    end
    
    -- Register Events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")

    eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "UNIT_POWER_UPDATE" and arg1 == "player" then
            -- Update on any power change for player to ensure we catch Essence
            if arg2 == "ESSENCE" or arg2 == "MANA" then
                 addon.UpdateEvokerResources()
            else
                 -- Update anyway just to be safe if token is weird
                 addon.UpdateEvokerResources()
            end
        elseif event == "UNIT_MAXPOWER" and arg1 == "player" then
            addon.UpdateEvokerResources()
            addon.OnLayoutUpdate()
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LOGIN" then
            addon.OnLayoutUpdate()
            addon.UpdateEvokerResources()
        end
    end)
    
    addon.OnLayoutUpdate()
    addon.UpdateEvokerResources()
end

function addon.UpdateEvokerResources()
    if not manaBar then return end
    
    -- Mana
    local mana = UnitPower("player", Enum.PowerType.Mana)
    local maxMana = UnitPowerMax("player", Enum.PowerType.Mana)
    manaBar:SetMinMaxValues(0, maxMana)
    manaBar:SetValue(mana)
    manaBar.text:SetText(mana)
    
    local cMana = MonkStaggerBarDB.colors.evokerMana or MANA_COLOR
    manaBar:SetStatusBarColor(cMana.r, cMana.g, cMana.b)
    
    -- Essence
    -- Power Type 19 is Essence (Hardcoded for safety + Enum fallback)
    local pType = Enum.PowerType.Essence or 19
    local essence = UnitPower("player", pType)
    local maxEssence = UnitPowerMax("player", pType)
    
    local cEssence = MonkStaggerBarDB.colors.essence or ESSENCE_COLOR
    
    for i = 1, #essenceBlocks do
        if i <= maxEssence then
            essenceBlocks[i]:Show()
            if i <= essence then
                essenceBlocks[i].fill:Show()
                essenceBlocks[i].fill:SetColorTexture(cEssence.r, cEssence.g, cEssence.b)
            else
                essenceBlocks[i].fill:Hide()
            end
        else
            essenceBlocks[i]:Hide()
        end
    end
end

function addon.OnLayoutUpdate()
    if not manaBar then return end
    local frame = addon.Frame
    local w, h = MonkStaggerBarDB.width, MonkStaggerBarDB.height
    
    local gap = 2
    local availableHeight = h - gap
    local manaRatio = MonkStaggerBarDB.evokerManaRatio or 0.2
    
    -- Layout: Top for Essence, Bottom for Mana (All specs use Essence)
    
    local essenceHeight = availableHeight * (1 - manaRatio)
    local manaHeight = availableHeight * manaRatio
    
    manaBar:SetSize(w, manaHeight)
    manaBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    
    local maxEssence = UnitPowerMax("player", Enum.PowerType.Essence)
    if not maxEssence or maxEssence == 0 then maxEssence = 5 end -- Value is typically 5 or 6
    
    local blockWidth = w / maxEssence
    for i = 1, maxEssence do
        essenceBlocks[i]:SetSize(blockWidth - 1, essenceHeight) -- -1 for gap
        essenceBlocks[i]:SetPoint("TOPLEFT", frame, "TOPLEFT", (i-1) * blockWidth, 0)
    end
    
     -- Hide unused blocks
    for i = maxEssence + 1, #essenceBlocks do
        essenceBlocks[i]:Hide()
    end
end

function addon.OnTextureUpdate()
    if not manaBar then return end
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    manaBar:SetStatusBarTexture(texture)
end
