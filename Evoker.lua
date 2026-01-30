local addonName, addon = ...

-- Only load for Evokers
local _, playerClass = UnitClass("player")
if playerClass ~= "EVOKER" then return end

local manaBar

local COLOR_MANA_DEFAULT = {r=0, g=0.5, b=1}

function addon.InitializeModule()
    local frame = addon.Frame
    
    -- Create Bar
    manaBar = CreateFrame("StatusBar", nil, frame)
    manaBar:SetAllPoints(frame)
    manaBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    manaBar:SetMinMaxValues(0, 100)
    
    -- Background
    local bg = manaBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0, 0, 0, 0.5)
    
    -- Text
    manaBar.text = manaBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    manaBar.text:SetPoint("CENTER")
    
    -- Event Handling
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("PLAYER_LOGIN") 
    
    eventFrame:SetScript("OnEvent", function(self, event, arg1)
        if (event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER") and arg1 == "player" then
            addon.UpdateResources()
        elseif event == "PLAYER_LOGIN" then
            addon.UpdateResources()
        end
    end)
    
    addon.UpdateResources()
end

function addon.UpdateResources()
    if not manaBar then return end
    
    local mana = UnitPower("player", Enum.PowerType.Mana)
    local maxMana = UnitPowerMax("player", Enum.PowerType.Mana)
    
    manaBar:SetMinMaxValues(0, maxMana)
    manaBar:SetValue(mana)
    manaBar.text:SetText(mana)
    
    -- Color
    local c = MonkStaggerBarDB.colors.evokerMana or COLOR_MANA_DEFAULT
    manaBar:SetStatusBarColor(c.r, c.g, c.b)
end

function addon.OnLayoutUpdate()
    -- Bar uses SetAllPoints, so it resizes automatically with the main frame
end
