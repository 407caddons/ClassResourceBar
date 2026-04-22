local addonName, addon = ...

-- Core Frame Setup
local frame = CreateFrame("Frame", "MSBFrame", UIParent, "BackdropTemplate")
addon.Frame = frame -- Expose frame to modules

-- Default settings
local defaults = {
    x = 0,
    y = -200,
    width = 200,
    height = 20,
    minimapPos = 225,
    hideWhileFlying = false,
    colors = {
        staggerLight = { r = 0, g = 1, b = 0 },
        staggerModerate = { r = 1, g = 1, b = 0 },
        staggerHeavy = { r = 1, g = 0, b = 0 },
        monkEnergy = { r = 1, g = 1, b = 0 },
        monkMana = { r = 0, g = 0.5, b = 1 },
        chi = { r = 0.71, g = 1, b = 0.92 }, -- Light Jade/Teal
        runicPower = { r = 0, g = 0.82, b = 1 },
        runesReady = { r = 0.69, g = 0.38, b = 1 },
        runesRecharging = { r = 0.4, g = 0.4, b = 0.4 },
        fury = { r = 0.64, g = 0.19, b = 0.79 }, -- DH Purple
        rage = { r = 1, g = 0, b = 0 },
        energy = { r = 1, g = 1, b = 0 },
        mana = { r = 0, g = 0, b = 1 },
        astralPower = { r = 0, g = 0.5, b = 1 }, -- Blue-ish/Star color
        holyPower = { r = 1, g = 0.9, b = 0 },
        paladinMana = { r = 0, g = 0, b = 1 },
        hunterFocus = { r = 1, g = 0.5, b = 0.25 },       -- Orange
        warlockShards = { r = 0.58, g = 0.51, b = 0.79 }, -- Purple
        warlockMana = { r = 0, g = 0, b = 1 },            -- Blue

        -- Mage
        arcaneCharges = { r = 0.1, g = 0.5, b = 1 }, -- Cyan/Blue
        mageMana = { r = 0, g = 0, b = 1 },          -- Blue

        -- Priest
        insanity = { r = 0.4, g = 0, b = 0.8 }, -- Dark Purple
        priestMana = { r = 0, g = 0, b = 1 },   -- Blue

        -- Rogue
        energy = { r = 1, g = 1, b = 0 },        -- Yellow
        comboPoints = { r = 1, g = 0.9, b = 0 }, -- Yellow/Gold (Classic CP)

        -- Shaman
        maelstrom = { r = 0, g = 0.5, b = 1 }, -- Blue
        shamanMana = { r = 0, g = 0, b = 1 },  -- Blue

        -- Evoker
        essence = { r = 0.4, g = 0.8, b = 0.9 }, -- Cyan/Teal
        evokerMana = { r = 0, g = 0.5, b = 1 },

    },
    runeHeightRatio = 0.2,
    druidBottomRatio = 0.2,
    monkManaRatio = 0.2,
    windwalkerEnergyRatio = 0.2,
    evokerManaRatio = 0.2,
    paladinManaRatio = 0.2,
    warlockManaRatio = 0.2,
    mageManaRatio = 0.2,
    priestManaRatio = 0.2,
    rogueEnergyRatio = 0.2,
    shamanManaRatio = 0.2,
    barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
    hideBlizzardResourceBar = false,
}

-- Initialize Core
function addon.Initialize()
    -- Load saved variables or set defaults
    if not MonkStaggerBarDB then
        MonkStaggerBarDB = CopyTable(defaults)
    else
        -- Merge defaults in case of new versions
        for k, v in pairs(defaults) do
            if MonkStaggerBarDB[k] == nil then
                MonkStaggerBarDB[k] = v
            end
        end
    end

    -- Setup Frame
    frame:SetPoint("CENTER", UIParent, "CENTER", MonkStaggerBarDB.x, MonkStaggerBarDB.y)
    frame:SetSize(MonkStaggerBarDB.width, MonkStaggerBarDB.height)

    -- Common Background (Module can override or overlay)
    -- Actually, let's keep the backdrop generic or allow modules to skin it.
    -- For now, we replicate the original look.
    frame:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
    })
    frame:SetBackdropBorderColor(1, 1, 1, 0) -- Default to protected/hidden

    -- Enable Mouse for dragging (Config mode)
    frame:SetMovable(true)
    frame:SetResizable(true) -- Enable resizing
    frame:EnableMouse(false)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local _, _, _, x, y = self:GetPoint()
        MonkStaggerBarDB.x = x
        MonkStaggerBarDB.y = y
        addon.UpdateLayout() -- Notify modules if needed
    end)

    -- Resize Grip
    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetPoint("BOTTOMRIGHT")
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:EnableMouse(true)
    resizeGrip:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    resizeGrip:SetScript("OnMouseDown", function(self)
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnMouseUp", function(self)
        frame:StopMovingOrSizing()
    end)
    resizeGrip:Hide()
    frame.resizeGrip = resizeGrip

    -- Sync Size Changes
    frame:SetScript("OnSizeChanged", function(self, w, h)
        MonkStaggerBarDB.width = w
        MonkStaggerBarDB.height = h
        -- Don't call UpdateLayout here to avoid anchor errors during resize
        -- Just notify the module to update bar layouts
        if addon.OnLayoutUpdate then
            addon.OnLayoutUpdate()
        end
        -- Update config sliders if open (set flag to prevent callback loop)
        if _G["MSBWidth"] then
            _G["MSBWidth"].isUpdating = true
            _G["MSBWidth"]:SetValue(w)
            _G["MSBWidth"].isUpdating = false
        end
        if _G["MSBHeight"] then
            _G["MSBHeight"].isUpdating = true
            _G["MSBHeight"]:SetValue(h)
            _G["MSBHeight"].isUpdating = false
        end
    end)

    -- Initialize Minimap Button
    if MonkStaggerBarDB.minimapPos == nil then
        MonkStaggerBarDB.minimapPos = 225
    end
    addon.CreateMinimapButton()

    -- Setup flying state checker and centralized update loop
    frame:SetScript("OnUpdate", function(self, elapsed)
        -- Global checks
        if addon.CheckFlyingState then
            addon.CheckFlyingState(elapsed)
        end

        -- Module specific update hook
        if addon.ModuleOnUpdate then
            addon.ModuleOnUpdate(elapsed)
        end
    end)

    -- Initialize Active Module
    addon.ModuleOnUpdate = nil -- Reset before init
    if addon.InitializeModule then
        addon.InitializeModule()
    end

    -- Apply Blizzard resource bar visibility
    addon.UpdateBlizzardResourceBar()
end

-- Update Layout (Called by Config or Drag/Resize)
function addon.UpdateLayout()
    if not MonkStaggerBarDB then return end
    frame:SetPoint("CENTER", UIParent, "CENTER", MonkStaggerBarDB.x, MonkStaggerBarDB.y)
    frame:SetSize(MonkStaggerBarDB.width, MonkStaggerBarDB.height)

    -- Update Config Sliders if open
    if _G["MSBWidth"] then
        if not _G["MSBWidth"].isUpdating then
            _G["MSBWidth"]:SetValue(MonkStaggerBarDB.width)
        end
    end
    if _G["MSBHeight"] then
        if not _G["MSBHeight"].isUpdating then
            _G["MSBHeight"]:SetValue(MonkStaggerBarDB.height)
        end
    end

    -- Notify Module
    if addon.OnLayoutUpdate then
        addon.OnLayoutUpdate()
    end
end

-- Refresh Textures (Called when Texture changes)
function addon.UpdateTextures()
    if addon.OnTextureUpdate then
        addon.OnTextureUpdate()
    end
end

-- Flying State Check (Throttled)
local lastFlyingState = false
local flyingCheckThrottle = 0

function addon.CheckFlyingState(elapsed)
    if not MonkStaggerBarDB or not MonkStaggerBarDB.hideWhileFlying then
        if frame then frame:SetAlpha(1) end
        return
    end

    flyingCheckThrottle = flyingCheckThrottle + elapsed
    if flyingCheckThrottle < 0.1 then return end
    flyingCheckThrottle = 0

    local isFlying = IsFlying()
    if isFlying ~= lastFlyingState then
        lastFlyingState = isFlying
        if frame then
            frame:SetAlpha(isFlying and 0 or 1)
        end
    end
end

-- Hide/Show Blizzard Resource Bar
local blizzardResourceFrames = {
    "WarlockPowerFrame",
    "PaladinPowerBarFrame",
    "ComboPointPlayerFrame",
    "RuneFrame",
    "MageArcaneChargesFrame",
    "MonkHarmonyBarFrame",
    "TotemFrame",
    "EssencePlayerFrame",
    "PriestBarFrame",
}

local hookedFrames = {}

function addon.UpdateBlizzardResourceBar()
    if not MonkStaggerBarDB then return end
    local shouldHide = MonkStaggerBarDB.hideBlizzardResourceBar

    for _, frameName in ipairs(blizzardResourceFrames) do
        local f = _G[frameName]
        if f then
            if shouldHide then
                f:Hide()
                if not hookedFrames[frameName] then
                    f:HookScript("OnShow", function(self)
                        if MonkStaggerBarDB and MonkStaggerBarDB.hideBlizzardResourceBar then
                            self:Hide()
                        end
                    end)
                    hookedFrames[frameName] = true
                end
            end
        end
    end
end

-- Event Handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        addon.Initialize()
    end
end)

-- Minimap Button
function addon.CreateMinimapButton()
    local button = CreateFrame("Button", "MonkStaggerBarMinimapButton", Minimap)
    button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    button:SetSize(32, 32)
    -- Using the unified icon now
    button:SetNormalTexture("Interface\\AddOns\\ClassResourceBar\\MonkStaggerBarIcon.png")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")

    local function UpdatePosition()
        local angle = math.rad(MonkStaggerBarDB.minimapPos or 225)
        local x = math.cos(angle) * 80
        local y = math.sin(angle) * 80
        button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            MonkStaggerBarDB.minimapPos = angle
            UpdatePosition()
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnClick", function(self)
        if addon.OpenConfig then
            addon.OpenConfig()
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Monk Stagger Bar")
        GameTooltip:AddLine("Left Click: Open Config", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move Icon", 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    UpdatePosition()
end

-- Slash Command
SLASH_MONKSTAGGERBAR1 = "/msb"
SLASH_MONKSTAGGERBAR2 = "/monkstagger"
SlashCmdList["MONKSTAGGERBAR"] = function(msg)
    if addon.OpenConfig then
        addon.OpenConfig()
    end
end
