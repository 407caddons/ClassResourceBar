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

-- Helper: Create Dropdown (Simple version using UIDropDownMenu)
local function CreateDropdown(parent, name, label, items, getFunc, setFunc, yOffset)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    labelText:SetText(label)

    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", -15, -5)
    
    local function OnClick(self)
        UIDropDownMenu_SetSelectedValue(dropdown, self.value)
        setFunc(self.value)
    end

    local function Initialize(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, item in ipairs(items) do
            info.text = item.text
            info.value = item.value
            info.func = OnClick
            info.checked = (item.value == getFunc())
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dropdown, Initialize)
    UIDropDownMenu_SetSelectedValue(dropdown, getFunc())
    UIDropDownMenu_SetText(dropdown, "") -- Will be set by selection
    for _, item in ipairs(items) do
        if item.value == getFunc() then
            UIDropDownMenu_SetText(dropdown, item.text)
            break
        end
    end
    
    return dropdown
end

function addon.OpenConfig()
    if configFrame then 
        configFrame:Show()
        return 
    end

    -- Main Window
    configFrame = CreateFrame("Frame", "MSBConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    configFrame:SetSize(600, 500)
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
    
    tinsert(UISpecialFrames, "MSBConfigFrame")

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

        CreateCheckbox(page, "MSBHideFlying", "Hide While Flying", 
            function() return MonkStaggerBarDB.hideWhileFlying end,
            function(checked)
                MonkStaggerBarDB.hideWhileFlying = checked
                if addon.CheckFlyingState then 
                    addon.CheckFlyingState(0.2) -- Force check 
                end
            end, -250)

        local textureItems = {
            { text = "Default", value = "Interface\\TargetingFrame\\UI-StatusBar" },
            { text = "Smooth", value = "Interface\\AddOns\\ClassResourceBar\\MonkStaggerBarIcon.png" }, -- Placeholder for smooth if no specific path, but let's find better ones
            { text = "Raid", value = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
            { text = "Flat", value = "Interface\\Buttons\\WHITE8X8" },
            { text = "Glaze", value = "Interface\\ChatFrame\\ChatFrameBackground" },
        }
        
        -- Override smooth with a more standard "smooth" texture path if possible, or just standard ones
        textureItems[2].value = "Interface\\Buttons\\UI-Listbox-Highlight" -- A common smooth-ish look

        CreateDropdown(page, "MSBTextureDropdown", "Bar Texture", textureItems,
            function() return MonkStaggerBarDB.barTexture or "Interface\\TargetingFrame\\UI-StatusBar" end,
            function(v)
                MonkStaggerBarDB.barTexture = v
                if addon.UpdateTextures then addon.UpdateTextures() end
            end, -300)

        return page
    end
    
    local function CreateMonkPage()
        local page = CreateFrame("Frame", nil, contentFrame)
        page:SetAllPoints(true)
        page:Hide()
        
        -- Stagger Colors
        CreateColorPicker(page, "MSBColorStaggerLight", "Stagger Light", 
            function() 
                local c = MonkStaggerBarDB.colors.light or {r=0, g=1, b=0}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.light = {r=r, g=g, b=b}
                if addon.UpdateStagger then addon.UpdateStagger() end
            end, -20)
            
        CreateColorPicker(page, "MSBColorStaggerModerate", "Stagger Moderate", 
            function() 
                local c = MonkStaggerBarDB.colors.moderate or {r=1, g=1, b=0}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.moderate = {r=r, g=g, b=b}
                if addon.UpdateStagger then addon.UpdateStagger() end
            end, -50)
            
        CreateColorPicker(page, "MSBColorStaggerHeavy", "Stagger Heavy", 
            function() 
                local c = MonkStaggerBarDB.colors.heavy or {r=1, g=0, b=0}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.heavy = {r=r, g=g, b=b}
                if addon.UpdateStagger then addon.UpdateStagger() end
            end, -80)

        -- New Sliders
         CreateSlider(page, "MSBMonkManaRatio", "Mana Bar Height %", 0, 100, 5, 
            function() return (MonkStaggerBarDB.monkManaRatio or 0.2) * 100 end,
            function(val) 
                MonkStaggerBarDB.monkManaRatio = val / 100
                if addon.OnLayoutUpdate then addon.OnLayoutUpdate() end
            end, -130)
            
        CreateSlider(page, "MSBMonkEnergyRatio", "WW Energy Height %", 0, 100, 5, 
            function() return (MonkStaggerBarDB.windwalkerEnergyRatio or 0.2) * 100 end,
            function(val) 
                MonkStaggerBarDB.windwalkerEnergyRatio = val / 100
                if addon.OnLayoutUpdate then addon.OnLayoutUpdate() end
            end, -170)

        -- New Colors
        CreateColorPicker(page, "MSBColorChi", "Chi Color", 
            function() 
                local c = MonkStaggerBarDB.colors.chi or {r=0.71, g=1, b=0.92}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.chi = {r=r, g=g, b=b}
                if addon.UpdateMonkLayout then addon.UpdateMonkLayout() end
            end, -220)
            
        CreateColorPicker(page, "MSBColorMonkMana", "Mana Color", 
            function() 
                local c = MonkStaggerBarDB.colors.monkMana or {r=0, g=0.5, b=1}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.monkMana = {r=r, g=g, b=b}
                if addon.UpdateMonkLayout then addon.UpdateMonkLayout() end
            end, -260)
            
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
            
        -- Astral Power Color
        CreateColorPicker(page, "MSBColorAstral", "Astral Power Color", 
            function() 
                local c = MonkStaggerBarDB.colors.astralPower or {r=0, g=0.5, b=1}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.astralPower = {r=r, g=g, b=b}
                if addon.UpdateDruidLayout then addon.UpdateDruidLayout() end
            end, -190)
            
        return page
    end

    local function CreateEvokerPage()
        local page = CreateFrame("Frame", nil, contentFrame)
        page:SetAllPoints(true)
        page:Hide()
        
        CreateSlider(page, "MSBEvokerManaRatio", "Mana Bar Height %", 0, 100, 5, 
            function() return (MonkStaggerBarDB.evokerManaRatio or 0.2) * 100 end,
            function(val) 
                MonkStaggerBarDB.evokerManaRatio = val / 100
                if addon.OnLayoutUpdate then addon.OnLayoutUpdate() end
            end, -20)
            
         CreateColorPicker(page, "MSBColorEssence", "Essence Color", 
            function() 
                local c = MonkStaggerBarDB.colors.essence or {r=0.4, g=0.8, b=0.9}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.essence = {r=r, g=g, b=b}
                if addon.UpdateEvokerResources then addon.UpdateEvokerResources() end
            end, -70)
        
        CreateColorPicker(page, "MSBColorEvokerMana", "Mana Bar Color", 
            function() 
                local c = MonkStaggerBarDB.colors.evokerMana or {r=0, g=0.5, b=1}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.evokerMana = {r=r, g=g, b=b}
                if addon.UpdateEvokerResources then addon.UpdateEvokerResources() end
            end, -110)
            
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
    
    local function CreateMagePage()
        local page = CreateFrame("Frame", nil, contentFrame)
        page:SetAllPoints(true)
        page:Hide()
        
        CreateSlider(page, "MSBMageManaRatio", "Mana Bar Height %", 0, 100, 5, 
            function() return (MonkStaggerBarDB.mageManaRatio or 0.2) * 100 end,
            function(val) 
                MonkStaggerBarDB.mageManaRatio = val / 100
                if addon.OnLayoutUpdate then addon.OnLayoutUpdate() end
            end, -20)
            
        CreateColorPicker(page, "MSBColorArcaneCharges", "Arcane Charges Color", 
            function() 
                local c = MonkStaggerBarDB.colors.arcaneCharges or {r=0.1, g=0.5, b=1}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.arcaneCharges = {r=r, g=g, b=b}
                if addon.UpdateMageResources then addon.UpdateMageResources() end
            end, -70)
            
        CreateColorPicker(page, "MSBColorMageMana", "Mana Bar Color", 
            function() 
                local c = MonkStaggerBarDB.colors.mageMana or {r=0, g=0, b=1}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.mageMana = {r=r, g=g, b=b}
                if addon.UpdateMageResources then addon.UpdateMageResources() end
            end, -110)
            
        return page
    end

    local function CreatePriestPage()
        local page = CreateFrame("Frame", nil, contentFrame)
        page:SetAllPoints(true)
        page:Hide()
        
        CreateSlider(page, "MSBPriestManaRatio", "Mana Bar Height %", 0, 100, 5, 
            function() return (MonkStaggerBarDB.priestManaRatio or 0.2) * 100 end,
            function(val) 
                MonkStaggerBarDB.priestManaRatio = val / 100
                if addon.OnLayoutUpdate then addon.OnLayoutUpdate() end
            end, -20)
            
        CreateColorPicker(page, "MSBColorInsanity", "Insanity Color", 
            function() 
                local c = MonkStaggerBarDB.colors.insanity or {r=0.4, g=0, b=0.8}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.insanity = {r=r, g=g, b=b}
                if addon.UpdatePriestResources then addon.UpdatePriestResources() end
            end, -70)
            
        CreateColorPicker(page, "MSBColorPriestMana", "Mana Bar Color", 
            function() 
                local c = MonkStaggerBarDB.colors.priestMana or {r=0, g=0, b=1}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.priestMana = {r=r, g=g, b=b}
                if addon.UpdatePriestResources then addon.UpdatePriestResources() end
            end, -110)
            
        return page
    end

    local function CreateRoguePage()
        local page = CreateFrame("Frame", nil, contentFrame)
        page:SetAllPoints(true)
        page:Hide()
        
        CreateSlider(page, "MSBRogueEnergyRatio", "Energy Bar Height %", 0, 100, 5, 
            function() return (MonkStaggerBarDB.rogueEnergyRatio or 0.2) * 100 end,
            function(val) 
                MonkStaggerBarDB.rogueEnergyRatio = val / 100
                if addon.OnLayoutUpdate then addon.OnLayoutUpdate() end
            end, -20)
            
        CreateColorPicker(page, "MSBColorComboPoints", "Combo Points Color", 
            function() 
                local c = MonkStaggerBarDB.colors.comboPoints or {r=1, g=0.9, b=0}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.comboPoints = {r=r, g=g, b=b}
                if addon.UpdateRogueResources then addon.UpdateRogueResources() end
            end, -70)
            
        CreateColorPicker(page, "MSBColorRogueEnergy", "Energy Bar Color", 
            function() 
                local c = MonkStaggerBarDB.colors.energy or {r=1, g=1, b=0}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.energy = {r=r, g=g, b=b}
                if addon.UpdateRogueResources then addon.UpdateRogueResources() end
            end, -110)
            
        return page
    end

    local function CreateShamanPage()
        local page = CreateFrame("Frame", nil, contentFrame)
        page:SetAllPoints(true)
        page:Hide()
        
        CreateSlider(page, "MSBShamanManaRatio", "Mana Bar Height %", 0, 100, 5, 
            function() return (MonkStaggerBarDB.shamanManaRatio or 0.2) * 100 end,
            function(val) 
                MonkStaggerBarDB.shamanManaRatio = val / 100
                if addon.OnLayoutUpdate then addon.OnLayoutUpdate() end
            end, -20)
            
        CreateColorPicker(page, "MSBColorMaelstrom", "Maelstrom Color", 
            function() 
                local c = MonkStaggerBarDB.colors.maelstrom or {r=0, g=0.5, b=1}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.maelstrom = {r=r, g=g, b=b}
                if addon.UpdateShamanResources then addon.UpdateShamanResources() end
            end, -70)
            
        CreateColorPicker(page, "MSBColorShamanMana", "Mana Bar Color", 
            function() 
                local c = MonkStaggerBarDB.colors.shamanMana or {r=0, g=0, b=1}
                return c.r, c.g, c.b 
            end,
            function(r,g,b) 
                MonkStaggerBarDB.colors.shamanMana = {r=r, g=g, b=b}
                if addon.UpdateShamanResources then addon.UpdateShamanResources() end
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
    pages["Mage"] = CreateMagePage()
    pages["Priest"] = CreatePriestPage()
    pages["Rogue"] = CreateRoguePage()
    pages["Shaman"] = CreateShamanPage()
    
    -- Nav Buttons
    local navButtons = {}
    
    local function SwitchTo(name)
        -- Hide all pages
        for k, v in pairs(pages) do
            v:Hide()
        end
        
        -- Show selected page
        if pages[name] then
            pages[name]:Show()
            activePage = name
        end
        
        -- Update Buttons (Highlight active)
        for btnName, btn in pairs(navButtons) do
            if btnName == name then
                btn:LockHighlight()
                btn:SetEnabled(false) -- Disable to look "pressed"/active
            else
                btn:UnlockHighlight()
                btn:SetEnabled(true)
            end
        end
    end

    local function CreateNavButton(label, yOffset)
        local btn = CreateFrame("Button", nil, navFrame, "UIPanelButtonTemplate")
        btn:SetSize(110, 24)
        btn:SetPoint("TOPLEFT", navFrame, "TOPLEFT", 0, yOffset)
        btn:SetText(label)
        btn:SetScript("OnClick", function() SwitchTo(label) end)
        navButtons[label] = btn
    end
    
    -- Sorted Alphabetically
    CreateNavButton("General", -10)
    
    CreateNavButton("Death Knight", -40)
    CreateNavButton("Demon Hunter", -70)
    CreateNavButton("Druid", -100)
    CreateNavButton("Evoker", -130)
    CreateNavButton("Hunter", -160)
    CreateNavButton("Mage", -190)
    CreateNavButton("Monk", -220)
    CreateNavButton("Paladin", -250)
    CreateNavButton("Priest", -280)
    CreateNavButton("Rogue", -310)
    CreateNavButton("Shaman", -340)
    CreateNavButton("Warlock", -370)
    CreateNavButton("Warrior", -400)
    
    SwitchTo("General")
end

-- PLACEHOLDER FOR NEW CONFIG FUNCTIONS --
-- I am inserting them before the page registration so they are defined

