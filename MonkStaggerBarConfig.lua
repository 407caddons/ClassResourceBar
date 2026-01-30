local addonName, addon = ...

local configFrame
local activePage = "General"
local pages = {}

-- Helper: Create Slider
local function CreateSlider(parent, name, label, minVal, maxVal, step, getFunc, setFunc, yOffset)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOP", parent, "TOP", -20, yOffset) -- Shift left to make room
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    
    _G[name .. "Low"]:SetText(minVal)
    _G[name .. "High"]:SetText(maxVal)
    _G[name .. "Text"]:SetText(label)
    
    -- EditBox for direct input
    local editBox = CreateFrame("EditBox", nil, slider, "InputBoxTemplate")
    editBox:SetSize(40, 20)
    editBox:SetPoint("LEFT", slider, "RIGHT", 15, 0)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(5)
    
    editBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            -- Clamp
            if val < minVal then val = minVal end
            if val > maxVal then val = maxVal end
            
            slider:SetValue(val)
            self:ClearFocus()
        else
            self:SetText(slider:GetValue())
        end
    end)
    
    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(slider:GetValue())
        self:ClearFocus()
    end)

    slider:SetScript("OnValueChanged", function(self, value)
        -- Round value if step is integer-like
        if step >= 1 then value = math.floor(value + 0.5) end
        
        if not self.isUpdating then
            setFunc(value)
        end
        editBox:SetText(value)
    end)
    
    -- Set Initial
    slider:SetValue(getFunc())
    editBox:SetText(slider:GetValue())
    return slider
end

-- Helper: Create Checkbox
local function CreateCheckbox(parent, name, label, getFunc, setFunc, yOffset)
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    _G[name .. "Text"]:SetText(label)
    
    cb:SetChecked(getFunc())
    
    cb:SetScript("OnClick", function(self)
        setFunc(self:GetChecked())
    end)
    return cb
end

-- Helper: Create Color Picker
local function CreateColorPicker(parent, name, label, getFunc, setFunc, yOffset)
    local button = CreateFrame("Button", name, parent)
    button:SetSize(200, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    button:EnableMouse(true)
    button:RegisterForClicks("AnyUp")
    
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetSize(24, 24)
    button.bg:SetPoint("LEFT")
    button.bg:SetColorTexture(1, 1, 1)
    
    button.color = button:CreateTexture(nil, "OVERLAY")
    button.color:SetPoint("LEFT", button.bg, "LEFT", 2, 0)
    button.color:SetSize(20, 20)
    
    local r, g, b = getFunc()
    button.color:SetColorTexture(r, g, b)
    
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.text:SetPoint("LEFT", button.bg, "RIGHT", 10, 0)
    button.text:SetText(label)
    
    button:SetScript("OnClick", function(self)
        local r, g, b = getFunc()
        
        local function SwatchFunc()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            setFunc(newR, newG, newB)
            button.color:SetColorTexture(newR, newG, newB)
        end
        
        local function CancelFunc(previousValues)
            local newR, newG, newB
            if previousValues then
                newR, newG, newB = previousValues.r, previousValues.g, previousValues.b
            else
                newR, newG, newB = r, g, b
            end
            setFunc(newR, newG, newB)
            button.color:SetColorTexture(newR, newG, newB)
        end

        if ColorPickerFrame.SetupColorPickerAndShow then
            local info = {
                swatchFunc = SwatchFunc,
                cancelFunc = CancelFunc,
                r = r, g = g, b = b,
                hasOpacity = false,
            }
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame.func = SwatchFunc
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.cancelFunc = CancelFunc
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame:Show()
        end
    end)
end

function addon.OpenConfig()
    if configFrame then 
        configFrame:Show()
        return 
    end

    -- Main Window
    configFrame = CreateFrame("Frame", "MonkStaggerBarConfig", UIParent, "BasicFrameTemplateWithInset")
    configFrame:SetSize(500, 400)
    configFrame:SetPoint("CENTER")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    
    configFrame.title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    configFrame.title:SetPoint("LEFT", configFrame.TitleBg, "LEFT", 5, 0)
    configFrame.title:SetText("Monk Stagger Bar Config")

    -- Hide Default Close Button (Broken/Unclickable)
    local defaultCloseBtn = _G[configFrame:GetName() .. "CloseButton"]
    if defaultCloseBtn then defaultCloseBtn:Hide() end
    
    tinsert(UISpecialFrames, "MonkStaggerBarConfig")

    -- Navigation Frame (Left)
    local navFrame = CreateFrame("Frame", nil, configFrame)
    navFrame:SetPoint("TOPLEFT", 10, -30)
    navFrame:SetPoint("BOTTOMLEFT", 10, 10)
    navFrame:SetWidth(120)

    -- Content Frame (Right)
    local contentFrame = CreateFrame("Frame", nil, configFrame)
    contentFrame:SetPoint("TOPLEFT", navFrame, "TOPRIGHT", 10, 0)
    contentFrame:SetPoint("BOTTOMRIGHT", -10, 10)

    -- Page Creators
    local function CreateGeneralPage()
        local page = CreateFrame("Frame", nil, contentFrame)
        page:SetAllPoints(true)
        
        CreateSlider(page, "MSBWidth", "Width", 50, 500, 1, 
            function() return MonkStaggerBarDB.width end, 
            function(v) 
                MonkStaggerBarDB.width = v 
                if addon.UpdateLayout then addon.UpdateLayout() end
            end, -20)

        CreateSlider(page, "MSBHeight", "Height", 5, 100, 1, 
            function() return MonkStaggerBarDB.height end, 
            function(v) 
                MonkStaggerBarDB.height = v 
                if addon.UpdateLayout then addon.UpdateLayout() end
            end, -70)
            
        CreateSlider(page, "MSBX", "X Position", -1000, 1000, 1, 
            function() return MonkStaggerBarDB.x end, 
            function(v) 
                MonkStaggerBarDB.x = v 
                if addon.UpdateLayout then addon.UpdateLayout() end
            end, -120)

        CreateSlider(page, "MSBY", "Y Position", -1000, 1000, 1, 
            function() return MonkStaggerBarDB.y end, 
            function(v) 
                MonkStaggerBarDB.y = v 
                if addon.UpdateLayout then addon.UpdateLayout() end
            end, -170)
            
        CreateCheckbox(page, "MSBDragCheck", "Unlock Frame", 
            function() return MonkStaggerBarDB.locked == false end, -- Logic inverse for checkbox label "Unlock"? Or just simple.
            -- Actually let's stick to "Unlock Frame" so checked = unlocked.
            function(checked)
                if checked then
                    if addon.Frame then
                        addon.Frame:EnableMouse(true)
                        if addon.Frame.resizeGrip then addon.Frame.resizeGrip:Show() end
                    end
                    print("|cff00ff00MSB:|r Frame Unlocked")
                else
                    if addon.Frame then
                        addon.Frame:EnableMouse(false)
                        if addon.Frame.resizeGrip then addon.Frame.resizeGrip:Hide() end
                    end
                    print("|cff00ff00MSB:|r Frame Locked")
                end
            end, -220)

        return page
    end
    
    local function CreateMonkPage()
        local page = CreateFrame("Frame", nil, contentFrame)
        page:SetAllPoints(true)
        page:Hide()
        
        -- Energy Ratio Slider
        CreateSlider(page, "MSBMonkEnergyRatio", "Energy Bar Height %", 0, 100, 5, 
            function() return (MonkStaggerBarDB.monkEnergyRatio or 0) * 100 end,
            function(val) 
                MonkStaggerBarDB.monkEnergyRatio = val / 100
                if addon.UpdateMonkLayout then addon.UpdateMonkLayout() end
                if addon.UpdateEnergy then addon.UpdateEnergy() end
            end, -20)
        
        CreateColorPicker(page, "MSBColorLight", "Light Stagger", 
            function() return MonkStaggerBarDB.colors.light.r, MonkStaggerBarDB.colors.light.g, MonkStaggerBarDB.colors.light.b end, 
            function(r,g,b) 
                MonkStaggerBarDB.colors.light = {r=r, g=g, b=b}
                if addon.UpdateStagger then addon.UpdateStagger() end
            end, -70)
            
        CreateColorPicker(page, "MSBColorModerate", "Moderate Stagger", 
            function() return MonkStaggerBarDB.colors.moderate.r, MonkStaggerBarDB.colors.moderate.g, MonkStaggerBarDB.colors.moderate.b end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.moderate = {r=r, g=g, b=b}
                if addon.UpdateStagger then addon.UpdateStagger() end
            end, -110)
            
        CreateColorPicker(page, "MSBColorHeavy", "Heavy Stagger", 
            function() return MonkStaggerBarDB.colors.heavy.r, MonkStaggerBarDB.colors.heavy.g, MonkStaggerBarDB.colors.heavy.b end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.heavy = {r=r, g=g, b=b}
                if addon.UpdateStagger then addon.UpdateStagger() end
            end, -150)
            
        -- Energy Color
        CreateColorPicker(page, "MSBColorMonkEnergy", "Energy Bar Color", 
            function() 
                local c = MonkStaggerBarDB.colors.monkEnergy or {r=1, g=1, b=0}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.monkEnergy = {r=r, g=g, b=b}
                if addon.UpdateMonkLayout then addon.UpdateMonkLayout() end
            end, -190)
            
        return page
    end
    
    local function CreateDKPage()
        local page = CreateFrame("Frame", nil, contentFrame)
        page:SetAllPoints(true)
        page:Hide()
        
        CreateSlider(page, "MSBRuneHeight", "Rune Height %", 0, 100, 1, 
            function() return (MonkStaggerBarDB.runeHeightRatio or 0.2) * 100 end, 
            function(v) 
                MonkStaggerBarDB.runeHeightRatio = v / 100
                if addon.UpdateLayout then addon.UpdateLayout() end
            end, -20)
            
        CreateColorPicker(page, "MSBColorRP", "Runic Power Color", 
            function() 
                local c = MonkStaggerBarDB.colors.runicPower or {r=0, g=0.82, b=1}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.runicPower = {r=r, g=g, b=b}
                if addon.UpdateRunicPower then addon.UpdateRunicPower() end
            end, -70)

        CreateColorPicker(page, "MSBColorRunesReady", "Runes Ready Color", 
            function() 
                local c = MonkStaggerBarDB.colors.runesReady or {r=0.69, g=0.38, b=1}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.runesReady = {r=r, g=g, b=b}
                if addon.UpdateRunes then addon.UpdateRunes() end
            end, -110)
            
        CreateColorPicker(page, "MSBColorRunesRecharge", "Runes Recharging Color", 
            function() 
                local c = MonkStaggerBarDB.colors.runesRecharging or {r=0.4, g=0.4, b=0.4}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.runesRecharging = {r=r, g=g, b=b}
                if addon.UpdateRunes then addon.UpdateRunes() end
            end, -150)
            
        return page
    end
    
    local function CreateDHPage()
        local page = CreateFrame("Frame", nil, contentFrame)
        page:SetAllPoints(true)
        page:Hide()
        
        CreateColorPicker(page, "MSBColorFury", "Fury Bar Color", 
            function() 
                local c = MonkStaggerBarDB.colors.fury or {r=0.64, g=0.19, b=0.79}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.fury = {r=r, g=g, b=b}
                if addon.UpdateFury then addon.UpdateFury() end
            end, -20)
            
        return page
    end
    
    local function CreateDruidPage()
        local page = CreateFrame("Frame", nil, contentFrame)
        page:SetAllPoints(true)
        page:Hide()
        
        -- Ratio Slider
        local ratioSlider = CreateSlider(page, "MSBDruidRatio", "Bottom Bar Height %", 10, 90, 5, 
            function() return (MonkStaggerBarDB.druidBottomRatio or 0.2) * 100 end,
            function(val) 
                MonkStaggerBarDB.druidBottomRatio = val / 100
                if addon.UpdateDruidLayout then addon.UpdateDruidLayout() end
            end, -20)
        
        -- Rage Color
        CreateColorPicker(page, "MSBColorRage", "Rage Color", 
            function() 
                local c = MonkStaggerBarDB.colors.rage or {r=1, g=0, b=0}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.rage = {r=r, g=g, b=b}
                if addon.UpdateDruidLayout then addon.UpdateDruidLayout() end
            end, -70)
            
        -- Energy Color
        CreateColorPicker(page, "MSBColorEnergy", "Energy Color", 
            function() 
                local c = MonkStaggerBarDB.colors.energy or {r=1, g=1, b=0}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.energy = {r=r, g=g, b=b}
                if addon.UpdateDruidLayout then addon.UpdateDruidLayout() end
            end, -110)
            
        -- Mana Color
         CreateColorPicker(page, "MSBColorMana", "Mana Color", 
            function() 
                local c = MonkStaggerBarDB.colors.mana or {r=0, g=0, b=1}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.mana = {r=r, g=g, b=b}
                if addon.UpdateDruidLayout then addon.UpdateDruidLayout() end
            end, -150)
            
        return page
    end

    local function CreateEvokerPage()
        local page = CreateFrame("Frame", nil, contentFrame)
        page:SetAllPoints(true)
        page:Hide()
        
        CreateColorPicker(page, "MSBColorEvokerMana", "Mana Bar Color", 
            function() 
                local c = MonkStaggerBarDB.colors.evokerMana or {r=0, g=0.5, b=1}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.evokerMana = {r=r, g=g, b=b}
                if addon.UpdateResources then addon.UpdateResources() end
            end, -20)
            
        return page
    end

    local function CreateWarriorPage()
        local page = CreateFrame("Frame", nil, contentFrame)
        page:SetAllPoints(true)
        page:Hide()
        
        CreateColorPicker(page, "MSBColorWarriorRage", "Rage Bar Color", 
            function() 
                local c = MonkStaggerBarDB.colors.rage or {r=1, g=0, b=0}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.rage = {r=r, g=g, b=b}
                if addon.UpdateRage then addon.UpdateRage() end
            end, -20)
            
        return page
    end

    local function CreatePaladinPage()
        local page = CreateFrame("Frame", nil, contentFrame)
        page:SetAllPoints(true)
        page:Hide()
        
        CreateSlider(page, "MSBPaladinManaRatio", "Mana Bar Height %", 0, 100, 5, 
            function() return (MonkStaggerBarDB.paladinManaRatio or 0.2) * 100 end,
            function(val) 
                MonkStaggerBarDB.paladinManaRatio = val / 100
                if addon.OnLayoutUpdate then addon.OnLayoutUpdate() end
            end, -20)
            
        CreateColorPicker(page, "MSBColorHolyPower", "Holy Power Color", 
            function() 
                local c = MonkStaggerBarDB.colors.holyPower or {r=1, g=0.9, b=0}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.holyPower = {r=r, g=g, b=b}
                if addon.UpdatePaladinResources then addon.UpdatePaladinResources() end
            end, -70)
            
        CreateColorPicker(page, "MSBColorPaladinMana", "Mana Bar Color", 
            function() 
                local c = MonkStaggerBarDB.colors.paladinMana or {r=0, g=0, b=1}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.paladinMana = {r=r, g=g, b=b}
                if addon.UpdatePaladinResources then addon.UpdatePaladinResources() end
            end, -110)
            
        return page
    end

    local function CreateHunterPage()
        local page = CreateFrame("Frame", nil, contentFrame)
        page:SetAllPoints(true)
        page:Hide()
        
        CreateColorPicker(page, "MSBColorHunterFocus", "Focus Bar Color", 
            function() 
                local c = MonkStaggerBarDB.colors.hunterFocus or {r=1, g=0.5, b=0.25}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.hunterFocus = {r=r, g=g, b=b}
                if addon.UpdateFocus then addon.UpdateFocus() end
            end, -20)
            
        return page
    end

    local function CreateWarlockPage()
        local page = CreateFrame("Frame", nil, contentFrame)
        page:SetAllPoints(true)
        page:Hide()
        
        CreateSlider(page, "MSBWarlockManaRatio", "Mana Bar Height %", 0, 100, 5, 
            function() return (MonkStaggerBarDB.warlockManaRatio or 0.2) * 100 end,
            function(val) 
                MonkStaggerBarDB.warlockManaRatio = val / 100
                if addon.OnLayoutUpdate then addon.OnLayoutUpdate() end
            end, -20)
            
        CreateColorPicker(page, "MSBColorWarlockShards", "Soul Shard Color", 
            function() 
                local c = MonkStaggerBarDB.colors.warlockShards or {r=0.58, g=0.51, b=0.79}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.warlockShards = {r=r, g=g, b=b}
                if addon.UpdateWarlockResources then addon.UpdateWarlockResources() end
            end, -70)
            
        CreateColorPicker(page, "MSBColorWarlockMana", "Mana Bar Color", 
            function() 
                local c = MonkStaggerBarDB.colors.warlockMana or {r=0, g=0, b=1}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.warlockMana = {r=r, g=g, b=b}
                if addon.UpdateWarlockResources then addon.UpdateWarlockResources() end
            end, -110)
            
        return page
    end

    pages["General"] = CreateGeneralPage()
    pages["Monk"] = CreateMonkPage()
    pages["Death Knight"] = CreateDKPage()
    pages["Demon Hunter"] = CreateDHPage()
    pages["Druid"] = CreateDruidPage()
    pages["Evoker"] = CreateEvokerPage()
    pages["Warrior"] = CreateWarriorPage()
    pages["Paladin"] = CreatePaladinPage()
    pages["Hunter"] = CreateHunterPage()
    pages["Warlock"] = CreateWarlockPage()
    
    -- Nav Buttons
    local function SwitchTo(name)
        for k, v in pairs(pages) do
            v:Hide()
        end
        pages[name]:Show()
        activePage = name
    end

    local function CreateNavButton(label, yOffset)
        local btn = CreateFrame("Button", nil, navFrame, "UIPanelButtonTemplate")
        btn:SetSize(110, 24)
        btn:SetPoint("TOPLEFT", navFrame, "TOPLEFT", 0, yOffset)
        btn:SetText(label)
        btn:SetScript("OnClick", function() SwitchTo(label) end)
    end
    
    CreateNavButton("General", -10)
    CreateNavButton("Monk", -40)
    CreateNavButton("Death Knight", -70)
    CreateNavButton("Demon Hunter", -100)
    CreateNavButton("Druid", -130)
    CreateNavButton("Evoker", -160)
    CreateNavButton("Warrior", -190)
    CreateNavButton("Paladin", -220)
    CreateNavButton("Hunter", -250)
    CreateNavButton("Warlock", -280)
    
    SwitchTo("General")
end
