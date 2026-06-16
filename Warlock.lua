local addonName, addon = ...

-- Only load for Warlocks
local _, playerClass = UnitClass("player")
if playerClass ~= "WARLOCK" then return end

local manaBar
local shardBlocks = {}
local SHARD_COLOR = {r = 0.58, g = 0.51, b = 0.79}
local MANA_COLOR = {r = 0, g = 0, b = 1}

local SPEC_AFFLICTION = 265
local SPEC_DEMONOLOGY = 266
local SPEC_DESTRUCTION = 267

function addon.InitializeModule()
    local frame = addon.Frame
    
    -- Setup Mana Bar (Bottom 20%)
    manaBar = CreateFrame("StatusBar", nil, frame)
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    manaBar:SetStatusBarTexture(texture)
    
    local cMana = MonkStaggerBarDB.colors.warlockMana or MANA_COLOR
    manaBar:SetStatusBarColor(cMana.r, cMana.g, cMana.b)
    
    -- Background
    local manaBg = manaBar:CreateTexture(nil, "BACKGROUND")
    manaBg:SetAllPoints(true)
    manaBg:SetColorTexture(0, 0, 0, 0.5)
    
    -- Mana Text
    manaBar.text = manaBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    manaBar.text:SetPoint("CENTER")

    -- Setup Soul Shard Blocks (Top 80%)
    for i = 1, 5 do
        local block = CreateFrame("StatusBar", nil, frame) -- Using StatusBar for Destruction bits
        block:SetStatusBarTexture(texture)
        
        block.bg = block:CreateTexture(nil, "BACKGROUND")
        block.bg:SetAllPoints(true)
        block.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        
        local cShard = MonkStaggerBarDB.colors.warlockShards or SHARD_COLOR
        block:SetStatusBarColor(cShard.r, cShard.g, cShard.b)
        block:SetMinMaxValues(0, 10) -- 10 bits per shard for Destruction
        
        shardBlocks[i] = block
    end
    
    -- Register Events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")

    eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "UNIT_POWER_UPDATE" and arg1 == "player" then
            if arg2 == "SOUL_SHARDS" or arg2 == "MANA" then
                addon.UpdateWarlockResources()
            end
        elseif event == "UNIT_MAXPOWER" and arg1 == "player" then
            addon.UpdateWarlockResources()
            addon.OnLayoutUpdate() -- Max shards can change
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LOGIN" then
            addon.UpdateWarlockResources()
            addon.OnLayoutUpdate()
        end
    end)
    
    addon.UpdateWarlockResources()
    addon.OnLayoutUpdate()
end

function addon.UpdateWarlockResources()
    if not manaBar then return end
    
    -- Mana
    local mana = UnitPower("player", Enum.PowerType.Mana)
    local maxMana = UnitPowerMax("player", Enum.PowerType.Mana)
    manaBar:SetMinMaxValues(0, maxMana)
    manaBar:SetValue(mana)
    manaBar.text:SetText(mana)
    
    local cMana = MonkStaggerBarDB.colors.warlockMana or MANA_COLOR
    manaBar:SetStatusBarColor(cMana.r, cMana.g, cMana.b)
    
    -- Soul Shards
    local spec = GetSpecialization()
    local isDestro = (spec == 3) -- Destruction spec index is 3
    
    local shards = UnitPower("player", Enum.PowerType.SoulShards)
    local maxShards = UnitPowerMax("player", Enum.PowerType.SoulShards)
    
    local cShard = MonkStaggerBarDB.colors.warlockShards or SHARD_COLOR
    
    if isDestro then
        local bits = UnitPower("player", Enum.PowerType.SoulShards, true)
        for i = 1, 5 do
            if i <= maxShards then
                shardBlocks[i]:Show()
                -- Destruction: shards are divided into 10 bits each.
                -- Total bits / 10 = whole shards.
                -- bits % 10 = progress of the current partial shard.
                local shardBits = 0
                if i <= shards then
                    shardBits = 10
                elseif i == shards + 1 then
                    shardBits = bits % 10
                end
                shardBlocks[i]:SetValue(shardBits)
                shardBlocks[i]:SetStatusBarColor(cShard.r, cShard.g, cShard.b)
            else
                shardBlocks[i]:Hide()
            end
        end
    else
        -- Affliction/Demo: Solid blocks
        for i = 1, 5 do
            if i <= maxShards then
                shardBlocks[i]:Show()
                if i <= shards then
                    shardBlocks[i]:SetValue(10)
                else
                    shardBlocks[i]:SetValue(0)
                end
                shardBlocks[i]:SetStatusBarColor(cShard.r, cShard.g, cShard.b)
            else
                shardBlocks[i]:Hide()
            end
        end
    end
end

function addon.OnLayoutUpdate()
    if not manaBar then return end
    local frame = addon.Frame
    local w, h = MonkStaggerBarDB.width, MonkStaggerBarDB.height
    
    local gap = 2
    local availableHeight = h - gap
    local manaRatio = MonkStaggerBarDB.warlockManaRatio or 0.2
    
    local shardHeight = availableHeight * (1 - manaRatio)
    local manaHeight = availableHeight * manaRatio
    
    -- Mana Bar
    manaBar:SetSize(w, manaHeight)
    manaBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    
    -- Shard Blocks
    local maxShards = UnitPowerMax("player", Enum.PowerType.SoulShards)
    if maxShards == 0 then maxShards = 5 end -- Fallback
    
    local totalGapWidth = (maxShards - 1) * gap
    local shardWidth = (w - totalGapWidth) / maxShards
    
    for i = 1, 5 do
        if i <= maxShards then
            shardBlocks[i]:SetSize(shardWidth, shardHeight)
            shardBlocks[i]:SetPoint("TOPLEFT", frame, "TOPLEFT", (i-1) * (shardWidth + gap), 0)
        else
            shardBlocks[i]:Hide()
        end
    end
end

function addon.OnTextureUpdate()
    if not manaBar then return end
    local texture = MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    manaBar:SetStatusBarTexture(texture)
    for i = 1, 5 do
        if shardBlocks[i] then
            shardBlocks[i]:SetStatusBarTexture(texture)
        end
    end
end
