local addonName, addon = ...
local _, playerClass = UnitClass("player")
if playerClass ~= "MONK" then return end

-- Specific spell/aura checks or power definitions
-- Stagger is handled via UnitStagger. PowerType 12 = Chi.

-- Frames
local staggerBar, energyBar, manaBar
local chiBlocks = {}

-- Spec IDs
local SPEC_BREWMASTER = 268
local SPEC_WINDWALKER = 269
local SPEC_MISTWEAVER = 270

-- Defaults for Colors
local COLOR_STAGGER_LIGHT = {r=0, g=1, b=0}
local COLOR_STAGGER_MODERATE = {r=1, g=1, b=0}
local COLOR_STAGGER_HEAVY = {r=1, g=0, b=0}
local COLOR_ENERGY = {r=1, g=1, b=0}
local COLOR_MANA = {r=0, g=0.5, b=1}
local COLOR_CHI = {r=0.71, g=1, b=0.92}

addon.lastStagger = 0
addon.lastMaxHealth = 1

function addon.InitializeModule()
    local frame = addon.Frame
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"

    -- 1. Stagger Bar (Brewmaster)
    staggerBar = CreateFrame("StatusBar", nil, frame)
    staggerBar:SetStatusBarTexture(texture)
    staggerBar:SetMinMaxValues(0, 100)
    staggerBar:SetValue(0)
    
    local sBg = staggerBar:CreateTexture(nil, "BACKGROUND")
    sBg:SetAllPoints(true)
    sBg:SetColorTexture(0, 0, 0, 0.5)
    
    staggerBar.text = staggerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    staggerBar.text:SetPoint("CENTER")
    staggerBar.text:SetText("0 (0.0%)")

    -- 2. Energy Bar (BM / WW)
    energyBar = CreateFrame("StatusBar", nil, frame)
    energyBar:SetStatusBarTexture(texture)
    energyBar:SetMinMaxValues(0, 100)
    energyBar:SetValue(0)
    
    local eBg = energyBar:CreateTexture(nil, "BACKGROUND")
    eBg:SetAllPoints(true)
    eBg:SetColorTexture(0, 0, 0, 0.5)
    
    energyBar.text = energyBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    energyBar.text:SetPoint("CENTER")
    
    -- 3. Mana Bar (Mistweaver)
    manaBar = CreateFrame("StatusBar", nil, frame)
    manaBar:SetStatusBarTexture(texture)
    manaBar:SetMinMaxValues(0, 100)
    manaBar:SetValue(0)
    
    local mBg = manaBar:CreateTexture(nil, "BACKGROUND")
    mBg:SetAllPoints(true)
    mBg:SetColorTexture(0, 0, 0, 0.5)
    
    manaBar.text = manaBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    manaBar.text:SetPoint("CENTER")
    
    -- 4. Chi Blocks (Windwalker)
    for i = 1, 6 do
        local block = CreateFrame("Frame", nil, frame)
        block.bg = block:CreateTexture(nil, "BACKGROUND")
        block.bg:SetAllPoints(true)
        block.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        
        block.fill = block:CreateTexture(nil, "OVERLAY")
        block.fill:SetAllPoints(true)
        local cChi = MonkStaggerBarDB.colors.chi or COLOR_CHI
        block.fill:SetColorTexture(cChi.r, cChi.g, cChi.b)
        block.fill:Hide()
        
        chiBlocks[i] = block
    end

    -- Event Handling
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")

    eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "UNIT_POWER_UPDATE" and arg1 == "player" then
            if arg2 == "CHI" or arg2 == "ENERGY" or arg2 == "MANA" then
                addon.UpdateMonkResources()
            end
        elseif event == "UNIT_MAXPOWER" and arg1 == "player" then
             addon.UpdateMonkResources()
             addon.UpdateMonkLayout() -- Max Chi might change
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LOGIN" then
             addon.UpdateMonkLayout()
             addon.UpdateMonkResources()
        elseif event == "UNIT_HEALTH" and arg1 == "player" then
             addon.UpdateStagger()
        end
    end)
    
    -- Update Loop (Stagger is time-sensitive, but purely check once per frame? 
    -- Actually standard OnUpdate isn't strictly needed if we trust events, 
    -- but Stagger % updates as HP changes or Stagger decays.
    -- We'll keep the module update hook.
    addon.ModuleOnUpdate = function(elapsed)
        addon.UpdateStagger()
    end
    
    addon.UpdateMonkLayout()
    addon.UpdateMonkResources()
end

function addon.UpdateMonkResources()
   local spec = GetSpecialization()
   local specID = spec and GetSpecializationInfo(spec)
   
   -- Brewmaster Handling
   if specID == SPEC_BREWMASTER then
       addon.UpdateStagger()
       addon.UpdateEnergy()
   
   -- Windwalker Handling
   elseif specID == SPEC_WINDWALKER then
       addon.UpdateEnergy()
       addon.UpdateChi()
       
   -- Mistweaver Handling
   elseif specID == SPEC_MISTWEAVER then
       addon.UpdateMana()
   end
end

function addon.UpdateStagger()
    if not staggerBar:IsVisible() then return end
    
    local stagger = UnitStagger("player") or 0
    local maxHealth = UnitHealthMax("player") or 1
    
    if stagger ~= addon.lastStagger or maxHealth ~= addon.lastMaxHealth then
        addon.lastStagger = stagger
        addon.lastMaxHealth = maxHealth
        
        local percent = (stagger / maxHealth) * 100
        staggerBar:SetMinMaxValues(0, maxHealth)
        staggerBar:SetValue(stagger)
        staggerBar.text:SetText(string.format("%d (%.1f%%)", stagger, percent))
        
        -- Stagger Colors
        local colors = MonkStaggerBarDB.colors
        local r, g, b = 0, 1, 0
        
        -- Thresholds: Light < 30%, Moderate < 60%, Heavy > 60% (Roughly)
        -- Actually game logic defines colors based on threshold relative to health?
        -- Standard icon colors: Green, Yellow, Red.
        
        -- Simplified Logic based on Percentage for now, or use API if available?
        -- No direct API for Stagger Level Color, usually inferred.
        if percent < 30 then
            local c = colors.staggerLight or COLOR_STAGGER_LIGHT
            r,g,b = c.r, c.g, c.b
        elseif percent < 60 then
            local c = colors.staggerModerate or COLOR_STAGGER_MODERATE
            r,g,b = c.r, c.g, c.b
        else
             local c = colors.staggerHeavy or COLOR_STAGGER_HEAVY
            r,g,b = c.r, c.g, c.b
        end
        staggerBar:SetStatusBarColor(r, g, b)
    end
end

function addon.UpdateEnergy()
    if not energyBar:IsVisible() then return end
    
    local energy = UnitPower("player", Enum.PowerType.Energy)
    local maxEnergy = UnitPowerMax("player", Enum.PowerType.Energy)
    
    energyBar:SetMinMaxValues(0, maxEnergy)
    energyBar:SetValue(energy)
    energyBar.text:SetText(energy)
    
    local c = MonkStaggerBarDB.colors.monkEnergy or COLOR_ENERGY
    energyBar:SetStatusBarColor(c.r, c.g, c.b)
end

function addon.UpdateMana()
    if not manaBar:IsVisible() then return end
    
    local mana = UnitPower("player", Enum.PowerType.Mana)
    local maxMana = UnitPowerMax("player", Enum.PowerType.Mana)
    
    manaBar:SetMinMaxValues(0, maxMana)
    manaBar:SetValue(mana)
    manaBar.text:SetText(mana)
    
    local c = MonkStaggerBarDB.colors.monkMana or COLOR_MANA
    manaBar:SetStatusBarColor(c.r, c.g, c.b)
end

function addon.UpdateChi()
    -- Windwalker Chi
    local chi = UnitPower("player", Enum.PowerType.Chi)
    local maxChi = UnitPowerMax("player", Enum.PowerType.Chi)
    
    local c = MonkStaggerBarDB.colors.chi or COLOR_CHI
    
    for i = 1, #chiBlocks do
        if i <= maxChi and chiBlocks[i]:IsVisible() then
            if i <= chi then
                chiBlocks[i].fill:Show()
                chiBlocks[i].fill:SetColorTexture(c.r, c.g, c.b)
            else
                chiBlocks[i].fill:Hide()
            end
        end
    end
end

function addon.UpdateMonkLayout()
    local frame = addon.Frame
    local w, h = MonkStaggerBarDB.width, MonkStaggerBarDB.height
    local gap = 2
    local availableHeight = h - gap
    
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    
    -- Hide All First
    staggerBar:Hide()
    energyBar:Hide()
    manaBar:Hide()
    for i=1, #chiBlocks do chiBlocks[i]:Hide() end
    
    if specID == SPEC_BREWMASTER then
        staggerBar:Show()
        energyBar:Show()
        
        -- Existing BM Logic: split based on maybe 30/70? Or use ratios?
        -- Code didn't have explicit ratio slider for BM before, assumed fixed?
        -- Let's check Core defaults or Config... it had "monkEnergyRatio"?
        -- Let's use a default if not set.
        local bmEnergyRatio = MonkStaggerBarDB.monkEnergyRatio or 0.3 -- Default
        
        local energyH = availableHeight * bmEnergyRatio
        local staggerH = availableHeight * (1 - bmEnergyRatio)
        
        staggerBar:SetSize(w, staggerH)
        staggerBar:SetPoint("TOPLEFT", frame, "TOPLEFT")
        
        energyBar:SetSize(w, energyH)
        energyBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
        
    elseif specID == SPEC_WINDWALKER then
        -- Chi (Top), Energy (Bottom)
        energyBar:Show()
        
        local wwRatio = MonkStaggerBarDB.windwalkerEnergyRatio or 0.2
        local energyH = availableHeight * wwRatio
        local chiH = availableHeight * (1 - wwRatio)
        
        energyBar:SetSize(w, energyH)
        energyBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
        
        local maxChi = UnitPowerMax("player", Enum.PowerType.Chi)
        if maxChi == 0 then maxChi = 5 end
        
        local blockWidth = w / maxChi
        for i = 1, maxChi do
            chiBlocks[i]:Show()
            chiBlocks[i]:SetSize(blockWidth - 1, chiH)
            chiBlocks[i]:SetPoint("TOPLEFT", frame, "TOPLEFT", (i-1)*blockWidth, 0)
        end
        
    elseif specID == SPEC_MISTWEAVER then
        -- Just Mana Bar
        manaBar:Show()
        
        -- Full height? Or allow ratio if we want to add Focus tea later?
        -- Request says "just a mana bar".
        local mwRatio = MonkStaggerBarDB.monkManaRatio or 1.0 -- Default full usage if set to 1.
        -- If user set ratio in config (e.g. 0.2), usually that implies bottom bar. 
        -- But for single bar, use full height.
        -- Config slider was "Mana Bar Height %". If it's meant to fill frame, we should ignore ratio 
        -- unless there's a secondary resource. Since there isn't one yet, force full.
        
        manaBar:SetSize(w, h)
        manaBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    end
end

function addon.OnTextureUpdate()
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    if staggerBar then staggerBar:SetStatusBarTexture(texture) end
    if energyBar then energyBar:SetStatusBarTexture(texture) end
    if manaBar then manaBar:SetStatusBarTexture(texture) end
end
