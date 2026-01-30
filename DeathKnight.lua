local addonName, addon = ...

-- Only load for Death Knights
local _, playerClass = UnitClass("player")
if playerClass ~= "DEATHKNIGHT" then return end

local runicPowerBar
local runeBars = {}
local RP_COLOR = {r = 0, g = 0.82, b = 1}

function addon.InitializeModule()
    local frame = addon.Frame
    
    -- Setup Runic Power Bar (Top 80%)
    runicPowerBar = CreateFrame("StatusBar", nil, frame)
    runicPowerBar:SetPoint("TOPLEFT", frame, "TOPLEFT")
    runicPowerBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    -- Height set in Layout Update
    runicPowerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    runicPowerBar:SetStatusBarColor(RP_COLOR.r, RP_COLOR.g, RP_COLOR.b)
    runicPowerBar:SetMinMaxValues(0, UnitPowerMax("player", Enum.PowerType.RunicPower))
    runicPowerBar:SetValue(UnitPower("player", Enum.PowerType.RunicPower))
    
    -- RP Background
    local bg = runicPowerBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0, 0, 0, 0.5)
    
    -- RP Text
    runicPowerBar.text = runicPowerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    runicPowerBar.text:SetPoint("CENTER")
    runicPowerBar.text:SetText(UnitPower("player", Enum.PowerType.RunicPower))

    -- Setup Rune Bars (Bottom 20%)
    for i = 1, 6 do
        local rBar = CreateFrame("StatusBar", nil, frame)
        -- Positioning set in Layout Update
        rBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        rBar:SetStatusBarColor(0.69, 0.38, 1) 
        
        -- Rune BG
        local rBg = rBar:CreateTexture(nil, "BACKGROUND")
        rBg:SetAllPoints(true)
        rBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        
        runeBars[i] = rBar
    end
    
    -- Initial Layout
    addon.OnLayoutUpdate()

    -- Start Update Loop
    frame:SetScript("OnUpdate", function()
         addon.UpdateRunes()
    end)
    
    -- Register Events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("RUNE_POWER_UPDATE")
    eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "UNIT_POWER_UPDATE" and arg1 == "player" and arg2 == "RUNIC_POWER" then
            addon.UpdateRunicPower()
        end
    end)
end

function addon.OnLayoutUpdate()
    if not MonkStaggerBarDB or not runicPowerBar then return end
    local frame = addon.Frame
    local w, h = MonkStaggerBarDB.width, MonkStaggerBarDB.height
    
    local h = MonkStaggerBarDB.height
    local ratio = MonkStaggerBarDB.runeHeightRatio or 0.2
    
    -- Safety Clamping
    if ratio < 0 then ratio = 0 end
    if ratio > 1 then ratio = 1 end
    
    local gap = 2
    local availableHeight = h - gap
    
    -- Update RP Bar
    if ratio == 1 then
        runicPowerBar:Hide()
    else
        runicPowerBar:Show()
        runicPowerBar:SetHeight(availableHeight * (1 - ratio))
    end
    
    local runeHeight = availableHeight * ratio
    local runeWidth = MonkStaggerBarDB.width / 6
    
    for i = 1, 6 do
        local rBar = runeBars[i]
        if rBar then
            if ratio == 0 then
                rBar:Hide()
            else
                rBar:Show()
                rBar:SetSize(runeWidth - 2, runeHeight)
                rBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (i-1) * runeWidth + 1, 0)
            end
        end
    end
end

function addon.UpdateRunicPower()
    if not runicPowerBar then return end -- Safety
    local power = UnitPower("player", Enum.PowerType.RunicPower)
    local maxPower = UnitPowerMax("player", Enum.PowerType.RunicPower)
    runicPowerBar:SetMinMaxValues(0, maxPower)
    runicPowerBar:SetValue(power)
    runicPowerBar.text:SetText(power)
    
    local c = MonkStaggerBarDB.colors.runicPower or {r = 0, g = 0.82, b = 1}
    runicPowerBar:SetStatusBarColor(c.r, c.g, c.b)
end

function addon.UpdateRunes()
    local cReady = MonkStaggerBarDB.colors.runesReady or {r = 0.69, g = 0.38, b = 1}
    local cRecharge = MonkStaggerBarDB.colors.runesRecharging or {r = 0.4, g = 0.4, b = 0.4}

    for i = 1, 6 do
        local start, duration, runeReady = GetRuneCooldown(i)
        local rBar = runeBars[i]
        if rBar then
            if runeReady then
                rBar:SetMinMaxValues(0, 1)
                rBar:SetValue(1)
                rBar:SetStatusBarColor(cReady.r, cReady.g, cReady.b) 
            else
                rBar:SetMinMaxValues(start, start + duration)
                rBar:SetValue(GetTime())
                rBar:SetStatusBarColor(cRecharge.r, cRecharge.g, cRecharge.b)
            end
        end
    end
end
