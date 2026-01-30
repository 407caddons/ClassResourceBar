local addonName, addon = ...

-- Only load for Warriors
local _, playerClass = UnitClass("player")
if playerClass ~= "WARRIOR" then return end

local rageBar
local RAGE_COLOR = {r = 1, g = 0, b = 0}

function addon.InitializeModule()
    local frame = addon.Frame
    
    -- Setup Rage Bar
    rageBar = CreateFrame("StatusBar", nil, frame)
    rageBar:SetAllPoints(frame)
    rageBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    
    local c = MonkStaggerBarDB.colors.rage or RAGE_COLOR
    rageBar:SetStatusBarColor(c.r, c.g, c.b)
    
    rageBar:SetMinMaxValues(0, UnitPowerMax("player", Enum.PowerType.Rage))
    rageBar:SetValue(UnitPower("player", Enum.PowerType.Rage))
    
    -- Background
    local bg = rageBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0, 0, 0, 0.5)
    
    -- Rage Text
    rageBar.text = rageBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rageBar.text:SetPoint("CENTER")
    rageBar.text:SetText(UnitPower("player", Enum.PowerType.Rage))

    -- Update Loop
    frame:SetScript("OnUpdate", nil)
    
    -- Register Events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("PLAYER_LOGIN") 
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    
    eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "UNIT_POWER_UPDATE" and arg1 == "player" then
            if arg2 == "RAGE" then
                addon.UpdateRage()
            end
        elseif event == "UNIT_MAXPOWER" and arg1 == "player" then
            addon.UpdateRage()
        elseif event == "PLAYER_LOGIN" or event == "PLAYER_SPECIALIZATION_CHANGED" then
            addon.UpdateRage()
        end
    end)
    
    addon.UpdateRage()
end


function addon.UpdateRage()
    if not rageBar then return end
    
    rageBar:Show()
    
    local power = UnitPower("player", Enum.PowerType.Rage)
    local maxPower = UnitPowerMax("player", Enum.PowerType.Rage)
    
    rageBar:SetMinMaxValues(0, maxPower)
    rageBar:SetValue(power)
    rageBar.text:SetText(power)
    
    local c = MonkStaggerBarDB.colors.rage or RAGE_COLOR
    rageBar:SetStatusBarColor(c.r, c.g, c.b)
end

-- Layout Update
function addon.OnLayoutUpdate()
   -- Nothing special for now as it fills the frame.
end
