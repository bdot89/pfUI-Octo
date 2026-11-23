pfUI:RegisterModule("firstrun", "vanilla:tbc", function ()
  -- The install wizard, laid out like ElvUI's installer: one window with the
  -- steps listed on the left, the current step's text and choices on the
  -- right, and Previous / Next / Skip at the bottom. Each step stays a
  -- separate page built by its function (pfUI.firstrun:AddStep), and
  -- pfUI_init[step] records the finished ones, as before. Run it again with
  -- /pfui install or Settings > General > Firstrun.
  pfUI.firstrun = CreateFrame("Frame", "pfFirstRunWizard", UIParent)
  pfUI.firstrun.steps = {}

  pfUI.firstrun:RegisterEvent("PLAYER_ENTERING_WORLD")
  -- (23 Nov 2026, Barbeque_Squirrel: the installer came back at every loading screen after its X was used)
  -- PLAYER_ENTERING_WORLD fires at every zone change: only the first one, at login / reload, may open it
  pfUI.firstrun:SetScript("OnEvent", function()
    this:UnregisterEvent("PLAYER_ENTERING_WORLD")
    pfUI.firstrun:NextStep()
  end)

  local accent -- "|cffrrggbb" of the accent colour, set when a page is built

  function pfUI.firstrun:AddStep(name, func, title)
    if not name then return end
    table.insert(pfUI.firstrun.steps, { name = name, func = func, title = title or name })
  end

  local current -- the page on screen
  function pfUI.firstrun:NextStep()
    if current then current:Hide() current = nil end

    for id, step in ipairs(pfUI.firstrun.steps) do
      if not pfUI_init[step.name] then
        local f = step.func()
        f.id = id
        f.name = step.name
        f:UpdateSteps()
        if id == table.getn(pfUI.firstrun.steps) then f.next:SetText(T["Finish"]) end
        if id == 1 then f.prev:Disable() end
        f:Show()
        current = f
        return
      end
    end
  end

  -- starts over from the first step
  function pfUI.firstrun:Restart()
    for _, step in ipairs(pfUI.firstrun.steps) do pfUI_init[step.name] = nil end
    pfUI.firstrun:NextStep()
  end

  local function Font(parent, size, layer)
    local s = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontWhite")
    s:SetFont(pfUI.font_default, size, "OUTLINE")
    return s
  end

  -- main function to create wizard windows
  local function CreateFirstRunPage(title)
    local ar, ag, ab = GetAccentColor()
    accent = rgbhex(ar, ag, ab)

    local f = CreateFrame("Frame", nil, UIParent)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetWidth(560)
    f:SetHeight(360)
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    CreateBackdrop(f, nil, nil, .9)
    CreateBackdropShadow(f)

    -- header
    f.header = Font(f, C.global.font_size + 6)
    f.header:SetPoint("TOPLEFT", 12, -10)
    f.header:SetText(accent .. "pf|rUI " .. accent .. "Octo|r " .. T["Installation"])

    f.close = CreateFrame("Button", nil, f)
    f.close:SetPoint("TOPRIGHT", -8, -8)
    f.close:SetWidth(12)
    f.close:SetHeight(12)
    f.close.texture = f.close:CreateTexture(nil, "OVERLAY")
    f.close.texture:SetTexture(pfUI.media["img:close"])
    f.close.texture:SetAllPoints()
    f.close.texture:SetVertexColor(1, .25, .25, 1)
    SkinButton(f.close, 1, .5, .5)
    f.close:SetScript("OnClick", function() f:Hide() current = nil end)

    -- step list
    f.side = CreateFrame("Frame", nil, f)
    f.side:SetPoint("TOPLEFT", 10, -36)
    f.side:SetPoint("BOTTOMLEFT", 10, 10)
    f.side:SetWidth(140)
    CreateBackdrop(f.side, nil, true, .6)
    f.side.lines = {}

    function f:UpdateSteps()
      for i, step in ipairs(pfUI.firstrun.steps) do
        local line = f.side.lines[i] or Font(f.side, C.global.font_size)
        f.side.lines[i] = line
        line:SetPoint("TOPLEFT", 8, -8 - (i-1) * (C.global.font_size + 8))
        line:SetJustifyH("LEFT")
        if i == f.id then
          line:SetText(accent .. "> " .. step.title .. "|r")
        elseif pfUI_init[step.name] then
          line:SetText("|cff888888" .. step.title .. "|r")
        else
          line:SetText(step.title)
        end
      end
    end

    -- page
    f.title = Font(f, C.global.font_size + 4)
    f.title:SetPoint("TOPLEFT", f.side, "TOPRIGHT", 14, -4)
    f.title:SetJustifyH("LEFT")
    f.title:SetText(accent .. (title or "") .. "|r")

    f.text = Font(f, C.global.font_size + 1)
    f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -10)
    f.text:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetJustifyV("TOP")
    f.text:SetHeight(110)

    -- the step's buttons and boxes go in here
    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", f.side, "TOPRIGHT", 10, -150)
    f.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 44)

    -- progress and buttons
    f.progress = CreateFrame("StatusBar", nil, f)
    f.progress:SetPoint("BOTTOMLEFT", f.side, "BOTTOMRIGHT", 100, 8)
    f.progress:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -100, 18)
    f.progress:SetHeight(12)
    f.progress:SetStatusBarTexture(pfUI.media["img:bar"])
    f.progress:SetStatusBarColor(ar, ag, ab, 1)
    CreateBackdrop(f.progress)
    f.ptext = Font(f.progress, C.global.font_size - 1)
    f.ptext:SetAllPoints()

    local _UpdateSteps = f.UpdateSteps
    function f:UpdateSteps()
      _UpdateSteps(f)
      local total = table.getn(pfUI.firstrun.steps)
      f.progress:SetMinMaxValues(0, total)
      f.progress:SetValue(f.id or 0)
      f.ptext:SetText((f.id or 0) .. " / " .. total)
    end

    f.next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.next:SetWidth(80)
    f.next:SetHeight(20)
    f.next:SetPoint("LEFT", f.progress.backdrop, "RIGHT", 8, 0)
    f.next:SetText(T["Next"])
    f.next:SetScript("OnClick", function()
      if f.NextScript then f.NextScript() end
      pfUI_init[f.name] = true
      pfUI.firstrun:NextStep()
    end)
    SkinButton(f.next)

    f.prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.prev:SetWidth(80)
    f.prev:SetHeight(20)
    f.prev:SetPoint("RIGHT", f.progress.backdrop, "LEFT", -8, 0)
    f.prev:SetText(T["Previous"])
    f.prev:SetScript("OnClick", function()
      local before = f.id and pfUI.firstrun.steps[f.id - 1]
      if before then
        pfUI_init[before.name] = nil
        pfUI.firstrun:NextStep()
      end
    end)
    SkinButton(f.prev)

    -- ElvUI's "Skip Process": mark every step done without changing anything
    f.skip = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.skip:SetWidth(60)
    f.skip:SetHeight(16)
    f.skip:SetPoint("RIGHT", f.close, "LEFT", -10, 0)
    f.skip:SetText(T["Skip"])
    f.skip:SetScript("OnClick", function()
      for _, step in ipairs(pfUI.firstrun.steps) do pfUI_init[step.name] = true end
      f:Hide()
      current = nil
    end)
    SkinButton(f.skip)

    f:Hide()
    return f
  end

  -- a centred tick box in the content area
  local function Checkbox(f, name, label, checked)
    local box = CreateFrame("CheckButton", name, f.content, "UICheckButtonTemplate")
    box:SetChecked(checked)
    box.text = Font(f.content, C.global.font_size + 1)
    box.text:SetPoint("LEFT", box, "RIGHT", 6, 0)
    box.text:SetText(label)
    box:SetPoint("TOPLEFT", 10, -20)
    SkinCheckbox(box, 18)
    return box
  end

  local function Button(f, label, width, func)
    local b = CreateFrame("Button", nil, f.content, "UIPanelButtonTemplate")
    b:SetWidth(width)
    b:SetHeight(22)
    b:SetText(label)
    b:SetScript("OnClick", func)
    SkinButton(b)
    return b
  end

  -- welcome dialog
  pfUI.firstrun:AddStep("init", function()
    local f = CreateFirstRunPage(T["Welcome"])
    f.text:SetText(T["Welcome to pfUI Octo!\n\nThis installer sets up your interface in a few steps: the look, where your raid frames go, game settings and chat.\n\nEvery step can be skipped and changed later in the options (/pfui). Run this installer again with /pfui install."])
    return f
  end, T["Welcome"])

  -- choose profile
  pfUI.firstrun:AddStep("profile", function()
    local f = CreateFirstRunPage(T["Profile"])
    f.text:SetText(T["Pick a look. |cffffffffOcto|r is the recommended ElvUI-style layout: thin pixel borders, dark panels and clean fonts.\n\nChoosing a profile replaces your current settings and reloads the UI. Keep your settings with \"Next\"."])

    local function Load(config)
      _G["pfUI_config"] = config
      pfUI:LoadConfig()
      pfUI_init["profile"] = true
      ReloadUI()
    end

    f.Octo = Button(f, accent .. "Octo|r (" .. T["Recommended"] .. ")", 240, function() Load(pfUI.octo.Profile()) end)
    f.Octo:SetPoint("TOP", 0, -4)

    local others = { "Modern", "Slim", "Nostalgia", "Legacy" }
    for i, name in ipairs(others) do
      local profile = name
      local b = Button(f, profile, 90, function() Load(CopyTable(pfUI_profiles[profile])) end)
      b:SetPoint("TOP", (i - 2.5) * 96, -34)
      f[profile] = b
    end

    f.Slider = CreateFrame("Slider", "pfFirstRunWizardScaleSlider", f.content, "OptionsSliderTemplate")
    f.Slider.text = f.Slider:CreateFontString("Status", "LOW", "GameFontWhite")
    f.Slider.text:SetPoint("TOP", f.Slider, "BOTTOM", 0, 2)
    f.Slider.text:SetText(T["Scale"])

    f.Slider:SetWidth(240)
    f.Slider:SetHeight(20)
    f.Slider:SetPoint("TOP", 0, -76)
    f.Slider:SetOrientation('HORIZONTAL')
    f.Slider:SetMinMaxValues(0.5, 2.0)
    f.Slider:SetValue(UIParent:GetScale())

    f.Slider:SetScript("OnMouseUp", function()
      local scale = round(this:GetValue(),2)
      SetCVar("uiScale", scale)
      SetCVar("useUiScale", 1)
      UIParent:SetScale(scale)
      this:SetValue(scale)
    end)

    f.Slider:SetScript("OnValueChanged", function()
      local scale = round(this:GetValue(),2)
      this:SetValue(scale)
    end)

    f.Slider:SetScript("OnUpdate", function()
      local scale = round(this:GetValue(),2)
      this.text:SetText(T["Scale"] .. ": " .. scale * 100 .. "%")
    end)

    SkinSlider(f.Slider)

    return f
  end, T["Profile"])

  -- role layout: healers get the raid frames in the middle (ElvUI's healer layout)
  pfUI.firstrun.SetRaidLayout = function(role)
    C.position = C.position or {}
    if role == "HEALER" then
      -- pfRaidCluster is as big as the whole raid grid (octo: one box), so
      -- centring it centres the raid frames
      C.position["pfRaidCluster"] = { anchor = "BOTTOM", xpos = 0, ypos = 180 }
    else
      C.position["pfRaidCluster"] = nil
    end
    if pfRaidCluster then UpdateMovable(pfRaidCluster) end
  end

  pfUI.firstrun:AddStep("layout", function()
    local f = CreateFirstRunPage(T["Layout"])
    f.text:SetText(T["What do you play most?\n\n|cffffffffTank / DPS|r keeps the raid frames at the bottom left, above the chat.\n|cffffffffHealer|r puts them in the middle of the screen, above your action bars, where your eyes are.\n\nMove anything later with /moveui."])

    f.dps = Button(f, T["Tank / DPS"], 150, function() pfUI.firstrun.SetRaidLayout("DPS") f.next:Click() end)
    f.dps:SetPoint("TOP", -80, -20)
    f.healer = Button(f, T["Healer"], 150, function() pfUI.firstrun.SetRaidLayout("HEALER") f.next:Click() end)
    f.healer:SetPoint("TOP", 80, -20)
    return f
  end, T["Layout"])

  -- (21 Nov 2026, user with another add-on's onboarding: "i like this option ... when first loading the addon up
  -- after install") which of pfUI Octo's own parts you want, as tiles: click one to turn it on or off. Ideas only, our
  -- look: icon, name, one line, a tick in the corner, lit in the accent when on. Off = C.disabled[mod] (the same
  -- switch as the options' power dots) or the part's own setting; the last step's reload applies them.
  -- { module or setting, title, line, icon }; set = { group, key, on value, off value }
  pfUI.firstrun.PARTS = {
    { mod = "meters", "Meters", "Damage, healing and threat windows with full breakdowns.", "Ability_Marksmanship" },
    { mod = "sct", "Combat Text", "Your damage and heals scrolling round you and on nameplates.", "Spell_Fire_FlameBolt" },
    { mod = "swing", "Swing Timer", "Your swings and shots as bars, with Slam and twist marks.", "INV_Sword_04" },
    { mod = "cdm", "CoolDownManager", "Your cooldowns on bars that glow when they are ready.", "INV_Misc_PocketWatch_01" },
    { mod = "dots", "OctoDoTs", "Every DoT and debuff on every mob, with timers.", "Spell_Shadow_AbominationExplosion" },
    { mod = "rinse", "OctoRinse", "One button to cure your group, boss by boss.", "Spell_Holy_DispelMagic" },
    { mod = "octototems", "OctoTotems", "Totem bars, sets, timers and smart heals for shamans.", "Spell_Nature_StoneSkinTotem" },
    { mod = "consumes", "OctoConsumes", "Tells you which flask, food or oil is missing.", "INV_Potion_62" },
    { mod = "gear", "ItemRack", "Gear sets, slot buttons, a trinket queue and talent specs.", "INV_Chest_Plate06" },
    { mod = "octolazy", "OctoLazy", "Rolls by your rules, accepts invites, skips gossip.", "Spell_Holy_SealOfSalvation" },
    { mod = "auction", "Auction House", "Fast searches, prices, shopping lists and a ledger.", "INV_Misc_Coin_01" },
    { mod = "mail", "Mailbox", "Collect all that never stalls, many items in one go.", "INV_Letter_15" },
    { mod = "bagcategories", "Bag Categories", "Your bags sorted into groups: gear, food, herbs...", "INV_Misc_Bag_08" },
    { mod = "lootfilter", "Loot Filter", "Leaves the loot you never want behind.", "INV_Misc_Coin_02" },
    { set = { "autoloot", "enable", "1", "0" }, "Auto Loot", "Loots every corpse around you after a fight.", "INV_Misc_Bag_10_Blue" },
    { set = { "worldbuffs", "enable", "1", "0" }, "World Buffs", "A countdown for Onyxia, Nefarian, Rend and Hakkar buffs.", "INV_Misc_Head_Dragon_01" },
    { set = { "flight", "enable", "1", "0" }, "Flight Timer", "How long your flight takes, as a bar.", "INV_Feather_01" },
    { set = { "appearance.worldmap", "transports", "1", "0" }, "Boats & Zeppelins", "Where every boat, zeppelin and the tram is on the map.", "INV_Misc_Map_01" },
    { set = { "raidtools", "show", "lead", "never" }, "Raid Tools", "Ready check, pull timer and marks when you lead.", "Ability_Warrior_BattleShout" },
    { mod = "chat-whispers", "Whisper Window", "Your whispers in a window of their own, one tab each.", "INV_Scroll_03" },
    { mod = "demo", "Demo Mode", "Try every frame in a made-up raid, dungeon or battleground.", "INV_Misc_Key_03" },
    { mod = "art", "Art", "Crests and dragons on frames and nameplates.", "INV_Misc_Gem_Variety_01" },
  }
  -- the settings table of "a.b" (nil when missing)
  local function Group(path)
    local t = C
    for part in string.gfind(path, "[^%.]+") do t = t and t[part] end
    return t
  end
  function pfUI.firstrun.PartOn(p)
    if p.mod then return not (C.disabled and C.disabled[p.mod] == "1") end
    local g = Group(p.set[1])
    return g and g[p.set[2]] ~= p.set[4] and true or false
  end
  function pfUI.firstrun.SetPart(p, on)
    if p.mod then
      C.disabled = C.disabled or {}
      C.disabled[p.mod] = on and "0" or "1"
    else
      local g = Group(p.set[1])
      if g then g[p.set[2]] = on and p.set[3] or p.set[4] end
    end
  end
  -- someone who finished the installer before this step existed is not shown it on its own (/pfui install shows it)
  if pfUI_init and pfUI_init.finalize and pfUI_init.modules == nil then pfUI_init.modules = true end

  pfUI.firstrun:AddStep("modules", function()
    local f = CreateFirstRunPage(T["Which parts do you want?"])
    f.text:SetText(T["Click a part to turn it on or off. Everything can be changed later in the options."])
    f.text:SetHeight(20)
    -- a bigger page for the tiles
    f:SetWidth(920)
    f:SetHeight(560)
    f.content:ClearAllPoints()
    f.content:SetPoint("TOPLEFT", f.side, "TOPRIGHT", 10, -56)
    f.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 44)
    local ar, ag, ab = GetAccentColor()
    local PARTS = pfUI.firstrun.PARTS
    f.want = {}
    for i, p in ipairs(PARTS) do f.want[i] = pfUI.firstrun.PartOn(p) end
    local COLS, W, H, GAP = 4, 180, 62, 6
    f.tiles = {}
    local function Paint(t)
      local on = f.want[t.i]
      if on then
        (t.backdrop or t):SetBackdropBorderColor(ar, ag, ab, 1)
        t.name:SetTextColor(ar, ag, ab, 1)
        t.tick:SetVertexColor(ar, ag, ab, 1)
        t.mark:Show()
        t.icon:SetDesaturated(nil)
        t.icon:SetAlpha(1)
        t.line:SetTextColor(.8, .8, .8, 1)
      else
        (t.backdrop or t):SetBackdropBorderColor(.25, .25, .27, 1)
        t.name:SetTextColor(.55, .55, .55, 1)
        t.tick:SetVertexColor(.2, .2, .22, 1)
        t.mark:Hide()
        if t.icon.SetDesaturated then t.icon:SetDesaturated(1) end
        t.icon:SetAlpha(.45)
        t.line:SetTextColor(.45, .45, .45, 1)
      end
    end
    local function Count()
      local n = 0
      for i = 1, table.getn(PARTS) do if f.want[i] then n = n + 1 end end
      f.count:SetText(accent .. n .. "|r " .. T["of"] .. " " .. table.getn(PARTS) .. " " .. T["on"])
    end
    for i, p in ipairs(PARTS) do
      local t = CreateFrame("Button", nil, f.content)
      t.i = i
      t:SetWidth(W)
      t:SetHeight(H)
      t:SetPoint("TOPLEFT", f.content, "TOPLEFT", math.mod(i - 1, COLS) * (W + GAP), -math.floor((i - 1) / COLS) * (H + GAP))
      CreateBackdrop(t, nil, true, .85)
      t.icon = t:CreateTexture(nil, "ARTWORK")
      t.icon:SetTexture("Interface\\Icons\\" .. p[3])
      t.icon:SetTexCoord(.08, .92, .08, .92)
      t.icon:SetWidth(32)
      t.icon:SetHeight(32)
      t.icon:SetPoint("TOPLEFT", t, "TOPLEFT", 8, -8)
      t.name = Font(t, C.global.font_size + 1)
      t.name:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 8, 1)
      t.name:SetPoint("RIGHT", t, "RIGHT", -24, 0)
      t.name:SetJustifyH("LEFT")
      t.name:SetText(T[p[1]])
      t.line = t:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      t.line:SetFont(pfUI.font_default, C.global.font_size - 1, "")
      t.line:SetPoint("TOPLEFT", t.name, "BOTTOMLEFT", 0, -3)
      t.line:SetPoint("RIGHT", t, "RIGHT", -8, 0)
      t.line:SetHeight(28)
      t.line:SetJustifyH("LEFT")
      t.line:SetJustifyV("TOP")
      t.line:SetText(T[p[2]])
      -- the tick in the corner: a square, filled in the accent when on
      t.tick = t:CreateTexture(nil, "OVERLAY")
      t.tick:SetTexture(1, 1, 1, 1)
      t.tick:SetWidth(12)
      t.tick:SetHeight(12)
      t.tick:SetPoint("TOPRIGHT", t, "TOPRIGHT", -7, -7)
      t.mark = t:CreateTexture(nil, "OVERLAY")
      t.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
      t.mark:SetWidth(18)
      t.mark:SetHeight(18)
      t.mark:SetPoint("CENTER", t.tick, "CENTER", 1, 0)
      t.hl = t:CreateTexture(nil, "HIGHLIGHT")
      t.hl:SetAllPoints()
      t.hl:SetTexture(1, 1, 1, .05)
      t:SetScript("OnClick", function()
        f.want[this.i] = not f.want[this.i]
        Paint(this)
        Count()
      end)
      Paint(t)
      f.tiles[i] = t
    end
    -- all on / all off and how many are on
    local function All(on)
      for i, t in ipairs(f.tiles) do f.want[i] = on Paint(t) end
      Count()
    end
    f.allOn = Button(f, T["All on"], 80, function() All(true) end)
    f.allOn:ClearAllPoints()
    f.allOn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -94, -36)
    f.allOff = Button(f, T["All off"], 80, function() All(false) end)
    f.allOff:ClearAllPoints()
    f.allOff:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -36)
    f.count = Font(f, C.global.font_size)
    f.count:SetPoint("RIGHT", f.allOn, "LEFT", -12, 0)
    Count()
    f.NextScript = function()
      local changed
      for i, p in ipairs(PARTS) do
        if pfUI.firstrun.PartOn(p) ~= f.want[i] then
          pfUI.firstrun.SetPart(p, f.want[i])
          changed = true
        end
      end
      -- (the last step's Reload UI applies them)
      if changed then pfUI.firstrun.partsChanged = true end
    end
    return f
  end, T["Parts"])

  -- optimized cvars dialog
  pfUI.firstrun:AddStep("cvars", function()
    local f = CreateFirstRunPage(T["Game Settings"])
    f.text:SetText(T["Do you want me to set up the recommended Blizzard UI settings? This will enable settings that can be found in the Interface section of your client. Options like Buff Durations, Instant Quest Text, Auto Selfcast and others will be set."])
    f.checkbox = Checkbox(f, "pfCheckBoxCVAR", T["Setup Optimized Game Settings"], true)

    f.NextScript = function()
      if f.checkbox:GetChecked() then
        pfUI.SetupCVars()
      end
    end

    return f
  end, T["Game Settings"])

  -- right chat dialog
  pfUI.firstrun:AddStep("chat_right", function()
    local f = CreateFirstRunPage(T["Chat: Loot & Spam"])
    f.text:SetText(T["Do you want me to create and manage a specific Chatframe called \"Loot & Spam\"? This chat will display world channels, loot information and miscellaneous messages, that would otherwise clutter your main chatframe."])
    f.checkbox = Checkbox(f, "pfCheckBoxChatRight", T["Enable \"Loot & Spam\" Window"], true)

    f.NextScript = function()
      if not pfUI.chat then message("Couldn't apply settings. Chat module is disabled.") return end
      pfUI.chat.SetupRightChat(f.checkbox:GetChecked())
    end

    return f
  end, T["Loot & Spam"])

  -- chat position dialog
  pfUI.firstrun:AddStep("chat_position", function()
    local f = CreateFirstRunPage(T["Chat: Layout"])
    f.text:SetText(T["Do you want me to adjust the layout of your chatframes? This would make sure, that every window is placed on its dedicated position."])
    f.checkbox = Checkbox(f, "pfCheckBoxChatPosition", T["Align Chat Windows"], true)

    f.NextScript = function()
      if not pfUI.chat then message("Couldn't apply settings. Chat module is disabled.") return end
      if f.checkbox:GetChecked() then
        pfUI.chat.SetupPositions()
      end
    end

    return f
  end, T["Chat Layout"])

  -- chat channels dialog
  pfUI.firstrun:AddStep("chat_channels", function()
    local f = CreateFirstRunPage(T["Chat: Channels"])
    f.text:SetText(T["Do you want me to setup the chat channels of your chatframes? This would set important or personal messages to the left chat and world channels and lootinformation to the right chat."])
    f.checkbox = Checkbox(f, "pfCheckBoxChatChannels", T["Setup All Chat Channels"], true)

    f.NextScript = function()
      if not pfUI.chat then message("Couldn't apply settings. Chat module is disabled.") return end
      if f.checkbox:GetChecked() then
        pfUI.chat.SetupChannels()
      end
    end

    return f
  end, T["Chat Channels"])

  -- finalize dialog
  pfUI.firstrun:AddStep("finalize", function()
    local f = CreateFirstRunPage(T["Finished"])
    f.text:SetText(T["Your interface is now set up.\n\n|cffffffff/pfui|r opens the options, |cffffffff/moveui|r moves frames, |cffffffff/export|r shares your profile as a text string.\n\nHave a nice trip!"])
    if pfUI.firstrun.partsChanged then
      f.text:SetText(f.text:GetText() .. "\n\n" .. accent .. T["Reload now to turn the parts you picked on or off."] .. "|r")
    end
    f.reload = Button(f, T["Reload UI"], 120, function() pfUI_init["finalize"] = true ReloadUI() end)
    f.reload:SetPoint("TOP", 0, -20)
    return f
  end, T["Finished"])
end)
