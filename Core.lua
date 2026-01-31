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
    locked = false,
    minimapPos = 225,
    colors = {
        light = {r=0, g=1, b=0},
        moderate = {r=1, g=1, b=0},
        heavy = {r=1, g=0, b=0},
        runicPower = {r=0, g=0.82, b=1},
        runesReady = {r=0.69, g=0.38, b=1},
        runesRecharging = {r=0.4, g=0.4, b=0.4},
        fury = {r=0.64, g=0.19, b=0.79}, -- DH Purple
        rage = {r=1, g=0, b=0},
        energy = {r=1, g=1, b=0},
        mana = {r=0, g=0, b=1},
        holyPower = {r=1, g=0.9, b=0},
        paladinMana = {r=0, g=0, b=1},
        hunterFocus = {r=1, g=0.5, b=0.25}, -- Orange
        warlockShards = {r=0.58, g=0.51, b=0.79}, -- Purple
        warlockMana = {r=0, g=0, b=1}, -- Blue
    },
    runeHeightRatio = 0.2,
    druidBottomRatio = 0.2,
    paladinManaRatio = 0.2,
    paladinManaRatio = 0.2,
    warlockManaRatio = 0.2,
    barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
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
        addon.UpdateLayout()
    end)
    
    -- Initialize Minimap Button
    if MonkStaggerBarDB.minimapPos == nil then
        MonkStaggerBarDB.minimapPos = 225
    end
    addon.CreateMinimapButton()
    
    -- Initialize Active Module
    if addon.InitializeModule then
        addon.InitializeModule()
    end
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
