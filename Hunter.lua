local addonName, addon = ...

-- Only load for Hunters
local _, playerClass = UnitClass("player")
if playerClass ~= "HUNTER" then return end

local focusBar
local FOCUS_COLOR = {r = 1, g = 0.5, b = 0.25}

function addon.InitializeModule()
    local frame = addon.Frame
    
    -- Setup Focus Bar
    focusBar = CreateFrame("StatusBar", nil, frame)
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    focusBar:SetStatusBarTexture(texture)
    
    local c = MonkStaggerBarDB.colors.hunterFocus or FOCUS_COLOR
    focusBar:SetStatusBarColor(c.r, c.g, c.b)
    
    -- Background
    local bg = focusBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0, 0, 0, 0.5)
    
    -- Focus Text
    focusBar.text = focusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    focusBar.text:SetPoint("CENTER")

    -- Register Events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("PLAYER_LOGIN")

    eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "UNIT_POWER_UPDATE" and arg1 == "player" then
            if arg2 == "FOCUS" then
                addon.UpdateFocus()
            end
        elseif event == "UNIT_MAXPOWER" and arg1 == "player" then
            addon.UpdateFocus()
        elseif event == "PLAYER_LOGIN" then
            addon.UpdateFocus()
        end
    end)
    
    addon.UpdateFocus()
    addon.OnLayoutUpdate()
end

function addon.UpdateFocus()
    if not focusBar then return end
    
    local focus = UnitPower("player", Enum.PowerType.Focus)
    local maxFocus = UnitPowerMax("player", Enum.PowerType.Focus)
    focusBar:SetMinMaxValues(0, maxFocus)
    focusBar:SetValue(focus)
    focusBar.text:SetText(focus)
    
    local c = MonkStaggerBarDB.colors.hunterFocus or FOCUS_COLOR
    focusBar:SetStatusBarColor(c.r, c.g, c.b)
end

function addon.OnLayoutUpdate()
    if not focusBar then return end
    local frame = addon.Frame
    local w, h = MonkStaggerBarDB.width, MonkStaggerBarDB.height
    
    focusBar:SetSize(w, h)
    focusBar:SetPoint("TOPLEFT", frame, "TOPLEFT")
end

function addon.OnTextureUpdate()
    if not focusBar then return end
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    focusBar:SetStatusBarTexture(texture)
end
