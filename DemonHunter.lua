local addonName, addon = ...

-- Only load for Demon Hunters
local _, playerClass = UnitClass("player")
if playerClass ~= "DEMONHUNTER" then return end

local furyBar
local FURY_COLOR = {r = 0.64, g = 0.19, b = 0.79}

function addon.InitializeModule()
    local frame = addon.Frame
    
    -- Setup Fury Bar
    furyBar = CreateFrame("StatusBar", nil, frame)
    furyBar:SetAllPoints(frame)
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    furyBar:SetStatusBarTexture(texture)
    
    local c = MonkStaggerBarDB.colors.fury or FURY_COLOR
    furyBar:SetStatusBarColor(c.r, c.g, c.b)
    
    furyBar:SetMinMaxValues(0, UnitPowerMax("player", Enum.PowerType.Fury))
    furyBar:SetValue(UnitPower("player", Enum.PowerType.Fury))
    
    -- Background
    local bg = furyBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0, 0, 0, 0.5)
    
    -- Fury Text
    furyBar.text = furyBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    furyBar.text:SetPoint("CENTER")
    furyBar.text:SetText(UnitPower("player", Enum.PowerType.Fury))

    -- Update Loop
    -- No specific update loop needed for DH, handled by events
    
    -- Register Events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("PLAYER_LOGIN") 
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    
    eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "UNIT_POWER_UPDATE" and arg1 == "player" then
            if arg2 == "FURY" then
                addon.UpdateFury()
            end
        elseif event == "UNIT_MAXPOWER" then
            addon.UpdateFury()
        elseif event == "PLAYER_LOGIN" or event == "PLAYER_SPECIALIZATION_CHANGED" then
            addon.UpdateFury()
        end
    end)
    
    addon.UpdateFury()
end


function addon.UpdateFury()
    if not furyBar then return end
    
    -- Show for all specs (Havoc, Vengeance, Devourer)
    furyBar:Show()
    
    local power = UnitPower("player", Enum.PowerType.Fury)
    local maxPower = UnitPowerMax("player", Enum.PowerType.Fury)
    
    furyBar:SetMinMaxValues(0, maxPower)
    furyBar:SetValue(power)
    furyBar.text:SetText(power)
    
    local c = MonkStaggerBarDB.colors.fury or FURY_COLOR
    furyBar:SetStatusBarColor(c.r, c.g, c.b)
end

-- Layout Update
function addon.OnLayoutUpdate()
   -- Nothing special for now as it fills the frame.
end

function addon.OnTextureUpdate()
    if not furyBar then return end
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    furyBar:SetStatusBarTexture(texture)
end
