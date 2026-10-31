pfUI:RegisterModule("unitframes-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the Unit Frames section (user, 22 Oct 2026: "this menu needs
  -- updating also and making smaller into managable order ... a nice clean
  -- preview box for all our unit frames ... tabs that you select which unit
  -- frame you want ... all parts of the unit frame must be clickable in the
  -- preview box taking you to their specific menus").
  -- Three pages instead of pfUI's fourteen: General (what all frames share),
  -- Frames (a tab per frame, a pinned preview of it, one card per part) and
  -- Click casting. Every setting of pfUI's Unit Frames category is here (that
  -- category is hidden) except the custom indicator list.
  -- The preview is pfUI's real unit frame (pfUI.uf:CreateUnitFrame) built on
  -- the chosen frame's settings, showing your own character (or your target /
  -- pet when you have one), in a layer of its own above the window. Sample
  -- buffs, debuffs, marks and glows are put on it so every part can be clicked.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage or not pfUI.uf then return end
  local BUILD = {}
  local PfChk, PfSld = O.PfChk, O.PfSld

  local UF = { cur = "player" }
  pfUI.ufOcto = UF

  -- key (C.unitframes), tab label, pfUI.uf frame, frames in the preview,
  -- the unit it shows when it exists (else your own character)
  UF.UNITS = {
    { "player", "Player", "player", 1 },
    { "target", "Target", "target", 1, "target" },
    { "ttarget", "Target of target", "targettarget", 1, "targettarget" },
    { "tttarget", "Target's target's target", "targettargettarget", 1, "targettargettarget" },
    { "pet", "Pet", "pet", 1, "pet" },
    { "ptarget", "Pet target", "pettarget", 1, "pettarget" },
    { "focus", "Focus", "focus", 1, "target" },
    { "focustarget", "Focus target", "focustarget", 1, "targettarget" },
    { "group", "Party", "group", 4 },
    { "grouptarget", "Party targets", "group", 4 },
    { "grouppet", "Party pets", "group", 4, "pet" },
    { "raid", "Raid", "raid", 10 },
  }
  local BY = {}
  for _, u in ipairs(UF.UNITS) do BY[u[1]] = u end
  UF.BY = BY

  local function G() return C.unitframes end
  local function U() return C.unitframes[UF.cur] end
  local function Px(v) return v .. " px" end
  local function Pct(v) return math.floor(v * 100 + .5) .. "%" end
  local function Sec(v) return v .. " s" end
  local function Reload() if pfUI.gui then pfUI.gui.settingChanged = true end end

  -- after a change: the real frame, then the preview
  function UF.Apply(key)
    local u = BY[key or UF.cur]
    local real = u and pfUI.uf[u[3]]
    if real and real.UpdateConfig then real:UpdateConfig() end
    if UF.mini then UF.mini.Reconfigure(key or UF.cur) end
  end
  local function Up() UF.Apply() end
  function UF.ApplyAll()
    for _, u in ipairs(UF.UNITS) do
      local real = pfUI.uf[u[3]]
      if real and real.UpdateConfig then real:UpdateConfig() end
    end
    if UF.mini then UF.mini.Reconfigure() end
  end

  local function Chk(p, label, desc, group, key, after) return PfChk(p, label, desc, group, key, after or Up) end
  local function Sld(p, label, desc, min, max, step, group, key, fmt, after) return PfSld(p, label, desc, min, max, step, group, key, after or Up, fmt) end
  local function Drop(p, label, desc, options, group, key, after)
    return W.Dropdown(p, label, desc, options, function() return group()[key] end, function(v)
      group()[key] = v
      ;(after or Up)()
    end)
  end
  local function Color(p, label, desc, group, key, after)
    return W.Color(p, label, desc, function()
      local r, g, b, a = GetStringColor(group()[key] or "1,1,1,1")
      return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
    end, function(r, g, b, a)
      group()[key] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
      ;(after or Up)()
    end)
  end
  -- pfUI's "key:label" dropdown lists (textures and fonts show as pictures)
  local function DD(name, kind)
    local out = {}
    local list = pfUI.gui and pfUI.gui.dropdowns and pfUI.gui.dropdowns[name]
    if type(list) == "function" then list = list() end
    for _, e in ipairs(list or {}) do
      local _, _, k, l = string.find(e, "^(.-):(.*)$")
      if k then
        local o = { key = k, label = l }
        if kind == "texture" then o.texture = k elseif kind == "font" then o.font = k end
        table.insert(out, o)
      end
    end
    return out
  end

  -- ---------------------------------------------------------------- preview

  -- what a click on each part opens (card titles on Frames)
  UF.GO = {
    frame = "Frame", hp = "Health bar", power = "Power bar", portrait = "Portrait",
    buffs = "Buffs", debuffs = "Debuffs",
    icons = "Icons", glow = "Glow and indicators", class = "Class and status", border = "Border and background",
  }
  -- each of the six texts opens the Texts card on its own tab (user, 23 Oct
  -- 2026: "Both called health text when clicked take to same menu")
  UF.TEXTS = { { "hpleft", "Health left" }, { "hpcenter", "Health middle" }, { "hpright", "Health right" },
    { "powerleft", "Power left" }, { "powercenter", "Power middle" }, { "powerright", "Power right" } }
  UF.text = "hpleft"
  UF.HOTLABEL = {
    class = "Class icon, badge or status", border = "Border and background", castbar = "Cast bar (opens Cast bars)",
    frame = "The frame", hp = "Health bar", power = "Power bar", portrait = "Portrait",
    hptext = "Health text", powertext = "Power text", buffs = "Buffs", debuffs = "Debuffs",
    icons = "Icon", glow = "Glow and indicators",
  }
  for _, t in ipairs(UF.TEXTS) do
    UF.GO[t[1]] = "Texts"
    UF.HOTLABEL[t[1]] = t[2] .. " text"
  end
  -- Shift + wheel: these sizes go up / down a pixel
  UF.SIZE = {
    hp = { "height", 4, 80 }, power = { "pheight", 0, 40 }, buffs = { "buffsize", 8, 40 },
    debuffs = { "debuffsize", 8, 40 }, icons = { "raidiconsize", 8, 48 },
  }

  -- ---------------------------------------------------------------- sections
  -- (user, 25 Oct 2026: "there is no raid layout options easily accessible
  -- this menu is a bit of a mess can we tidy it up and scale the menu better
  -- so more is seen"). The Frames page had 19 cards in one long list under
  -- a preview that took half the window. Now a row of section tabs under the
  -- preview (purple: pick one) shows only that section's cards, opened:
  -- { key, tab label, picture, card titles in order }.
  local ICON = "Interface\\Icons\\"
  UF.SECTIONS = {
    { "size", "Size", "Spell_Holy_Heal", { "Frame", "Health bar", "Power bar", "Portrait" } },
    { "text", "Text", "INV_Misc_Note_01", { "All frames: text", "Texts", "Text colours and font" } },
    { "auras", "Buffs", "Spell_Holy_WordFortitude", { "Enemy buffs", "Buffs", "Debuffs", "Buff and dispel markers" } },
    { "icons", "Icons", "INV_Banner_01", { "Icons", "Class and status", "Glow and indicators" } },
    { "look", "Look", "INV_Misc_Gem_Variety_01", { "Try it on the preview", "Border and background", "Colours", "All frames: colours" } },
    { "raid", "Raid layout", "Spell_Holy_PrayerOfHealing", { "Raid layout", "All frames: party and raid" } },
    { "all", "All frames", "INV_Misc_Gear_01", { "All frames: basics", "All frames: class extras" } },
  }
  UF.sec = "size"
  UF.SECTION_OF = {}
  for _, s in ipairs(UF.SECTIONS) do
    for _, title in ipairs(s[4]) do UF.SECTION_OF[title] = s[1] end
  end

  -- every card with a game picture (the UI rule: a picture on each card)
  UF.CARDICON = {
    ["Frame"] = "INV_Misc_Head_Human_01", ["Health bar"] = "Spell_Holy_Heal02", ["Power bar"] = "INV_Potion_51",
    ["Portrait"] = "INV_Misc_Head_Dragon_01", ["All frames: text"] = "INV_Letter_15", ["Texts"] = "INV_Misc_Note_01",
    ["Text colours and font"] = "INV_Fabric_Silk_02", ["Buffs"] = "Spell_Holy_WordFortitude", ["Enemy buffs"] = "Spell_Holy_PowerWordShield",
    ["Debuffs"] = "Spell_Shadow_ShadowWordPain", ["Buff and dispel markers"] = "Spell_Holy_DispelMagic",
    ["Icons"] = "INV_Banner_01", ["Class and status"] = "INV_Misc_Bone_HumanSkull_01",
    ["Glow and indicators"] = "Spell_Nature_WispSplode", ["Border and background"] = "INV_Misc_StoneTablet_05",
    ["Colours"] = "INV_Misc_Gem_Variety_01", ["All frames: colours"] = "INV_Misc_Gem_Ruby_02",
    ["Raid layout"] = "Spell_Holy_PrayerOfHealing", ["All frames: party and raid"] = "Spell_Nature_Rejuvenation",
    ["All frames: basics"] = "INV_Misc_Gear_01", ["All frames: class extras"] = "Ability_Druid_CatForm",
  }
  local function Card(p, title, o)
    o = o or {}
    if not o.icon and UF.CARDICON[title] then o.icon = ICON .. UF.CARDICON[title] end
    return W.Card(p, title, o)
  end

  -- only the cards of the section picked, one under the other (W.Card chains
  -- every card under the one before: hidden ones are skipped here)
  function UF.Filter(p)
    p = p or O.pages.ufframes
    if not p or not p.cards or not p.ufFirst then return end
    -- Find a setting: its card's section tab first
    p.onReveal = p.onReveal or function(e)
      local s = e.card and UF.SECTION_OF[e.card.title]
      if s and s ~= UF.sec then UF.SetSection(s, true) end
    end
    local prev, gap = p.ufFirst, 13
    for _, c in ipairs(p.cards) do
      if UF.SECTION_OF[c.title] == UF.sec then
        c.card:ClearAllPoints()
        c.card:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
        c.card:Show()
        prev, gap = c.card, 9
      else
        c.card:Hide()
      end
    end
    p.last = prev
  end

  -- a section's cards, opened, from the top of the page
  function UF.SetSection(key, keepFolds)
    UF.sec = key
    local p = O.pages.ufframes
    if p then
      if not keepFolds then
        for _, c in ipairs(p.cards) do
          if UF.SECTION_OF[c.title] == key and not W.IsOpen(c) then W.SetOpen(c, true) end
        end
      end
      UF.Filter(p)
      local sb = getglobal((p.frame:GetName() or "") .. "ScrollBar")
      if sb then sb:SetValue(0) elseif p.frame.SetVerticalScroll then p.frame:SetVerticalScroll(0) end
    end
    -- (the raid layout is the raid frames': their preview)
    if key == "raid" and UF.cur ~= "raid" then
      UF.cur = "raid"
      if UF.mini then UF.mini.FitView() end
    end
    if O.Refresh then O:Refresh() end
  end

  -- ---------------------------------------------------------------- copy
  -- (user, 25 Oct 2026: "Everyframe that can match something like unit frame
  -- should have an option ... match the size, layout, style, art of another.
  -- Player and Target bars for example you can easily copy ALL the settings")
  -- A frame's settings in the parts the sections show: a key goes to the
  -- first part with a pattern it matches (keys of no part: Everything only).
  UF.COPYPARTS = {
    { "all", "Everything" },
    { "size", "Size and bars", { "^width$", "^height$", "^pheight$", "^pwidth$", "^pspace$", "^panchor$", "^poff",
      "^portrait", "bartexture$", "^invert", "^vertical", "^o_fade", "^overheal", "^healcolor$" } },
    { "text", "Text", { "^txt", "^o_tc", "^healthcolor$", "^powercolor$", "^levelcolor$", "^classcolor$", "^customfont" } },
    { "auras", "Buffs and debuffs", { "^buff", "^debuff", "^o_buff[xy]$", "^o_debuff[xy]$", "^cooldown_", "^selfdebuff$",
      "^o_purge$", "^o_flashexpire$", "^indicator", "^show_", "^all_" } },
    { "icons", "Icons and status", { "icon", "^showPVP$", "^happiness", "^o_happy", "^o_class", "^o_elite", "^o_status$",
      "^glow", "^square", "^hitindicator" } },
    { "look", "Look and colours", { "^o_skin", "^o_grad", "^o_flash$", "^o_selhl$", "^o_debuffhl$", "^o_curable$", "^defcolor$",
      "^custom", "color$", "^alpha_", "^faderange$" } },
  }
  -- never copied: where and whether it shows, the raid grid, click casting
  UF.NOCOPY = { visible = true, raidlayout = true, raidpadding = true, raidfill = true, raidgrouplabel = true,
    grouplabelxoff = true, grouplabelyoff = true, o_growx = true, o_growy = true }
  function UF.PartOf(key)
    if UF.NOCOPY[key] or string.find(key, "^clickcast") then return nil end
    for _, part in ipairs(UF.COPYPARTS) do
      for _, pat in ipairs(part[3] or {}) do
        if string.find(key, pat) then return part[1] end
      end
    end
    return "other"
  end
  -- copies part ("all" or a COPYPARTS key) of frame from's settings to frame
  -- to's; the values it had are kept for UF.Undo. Returns how many changed.
  function UF.Copy(from, to, part)
    local src, dst = C.unitframes[from], C.unitframes[to]
    if not src or not dst or from == to then return 0 end
    local was, n = {}, 0
    for k, v in pairs(src) do
      local pk = UF.PartOf(k)
      if pk and (part == "all" or pk == part) and type(v) ~= "table" and dst[k] ~= v then
        was[k] = dst[k] == nil and false or dst[k]
        dst[k] = v
        n = n + 1
      end
    end
    UF.lastCopy = { to = to, was = was, from = from, part = part }
    UF.Apply(to)
    return n
  end
  function UF.Undo()
    local lc = UF.lastCopy
    if not lc then return end
    local dst = C.unitframes[lc.to]
    for k, v in pairs(lc.was) do
      if v == false then dst[k] = nil else dst[k] = v end
    end
    UF.lastCopy = nil
    UF.Apply(lc.to)
  end

  -- "Copy from...": first the frame to copy from, then what
  local function Label(key) return BY[key] and BY[key][2] or key end
  function UF.CopyMenu(anchor)
    W.CloseMenus()
    local to = UF.cur
    local opts = {}
    if UF.lastCopy then
      table.insert(opts, { key = "!undo", label = "Undo: " .. Label(UF.lastCopy.to) .. " as before the copy", icon = ICON .. "Spell_Nature_TimeStop" })
    end
    table.insert(opts, { label = "Copy into " .. Label(to) .. " from:", group = true })
    for _, u in ipairs(UF.UNITS) do
      if u[1] ~= to then table.insert(opts, { key = u[1], label = u[2] }) end
    end
    local m = W.Menu(anchor, opts, 210, function(from)
      if from == "!undo" then
        local lc = UF.lastCopy
        UF.Undo()
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: " .. Label(lc.to) .. " is as it was before the copy.")
        if O.Refresh then O:Refresh() end
        return
      end
      local parts = { { label = "Copy from " .. Label(from) .. ":", group = true } }
      for _, part in ipairs(UF.COPYPARTS) do table.insert(parts, { key = part[1], label = part[2] }) end
      local m2 = W.Menu(anchor, parts, 210, function(part)
        local n = UF.Copy(from, to, part)
        local pl
        for _, cp in ipairs(UF.COPYPARTS) do if cp[1] == part then pl = cp[2] end end
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: " .. Label(to) .. " now has " .. Label(from) .. "'s "
          .. string.lower(pl or part) .. " (" .. n .. " settings). Copy from... > Undo puts it back.")
        if O.Refresh then O:Refresh() end
      end)
      m2:Show()
      UF.copyMenu = m2
    end)
    m:Show()
    UF.copyMenu = m
    return m
  end

  -- the tabs, in the pinned strip under the preview
  function UF.SectionTabs(p)
    local row = W.Row(p, 24, 0, 6)
    local n = table.getn(UF.SECTIONS)
    -- (room at the right end for "Copy from...")
    local w = math.floor((W.CW - 118 - (n - 1) * 4) / n)
    local copy = W.Button(row, "Copy from...", 114, 22)
    copy:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    if W.Tint then W.Tint(copy, "save") end
    W.Tip(copy, "Copy from another frame", "Give this frame the settings of another one: everything, or only its size and "
      .. "bars, text, buffs, icons or look. Position and whether it shows stay its own. The last copy can be undone here.")
    copy:SetScript("OnClick", function() UF.CopyMenu(this) end)
    UF.copyButton = copy
    local tabs = {}
    for i, s in ipairs(UF.SECTIONS) do
      local b = W.Button(row, s[2], w, 22)
      b:SetPoint("LEFT", row, "LEFT", (i - 1) * (w + 4), 0)
      b.key = s[1]
      local pic = b:CreateTexture(nil, "OVERLAY")
      pic:SetTexture(ICON .. s[3])
      pic:SetTexCoord(.08, .92, .08, .92)
      pic:SetWidth(16)
      pic:SetHeight(16)
      pic:SetPoint("LEFT", b, "LEFT", 5, 0)
      if b.label then
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", pic, "RIGHT", 5, 0)
        b.label:SetPoint("RIGHT", b, "RIGHT", -4, 0)
        b.label:SetJustifyH("LEFT")
      end
      local tip = {}
      for _, t in ipairs(s[4]) do table.insert(tip, t) end
      W.Tip(b, s[2], "Shows: " .. table.concat(tip, ", ") .. ".")
      b:SetScript("OnClick", function() UF.SetSection(this.key) end)
      tabs[i] = b
    end
    UF.secTabs = tabs
    table.insert(p.items, { Refresh = function()
      for _, b in ipairs(tabs) do W.Pick(b, b.key == UF.sec) end
    end })
    return row
  end

  function UF.Open(what)
    local title = UF.GO[what] or "Frame"
    if title == "Texts" then
      UF.text = what
      if O.Refresh then O:Refresh() end
    end
    if pfUI.plates and pfUI.plates.OpenSection then
      pfUI.plates.OpenSection("ufframes", title)
    else
      O:Open("ufframes")
    end
  end

  -- sample auras so the buff and debuff rows can be seen and clicked
  local BUFFS = { "Spell_Holy_WordFortitude", "Spell_Nature_Regeneration", "Spell_Holy_MagicalSentry", "Spell_Holy_SealOfWisdom",
    "Spell_Nature_LightningShield", "Spell_Holy_PowerWordShield" }
  local DEBUFFS = { "Spell_Shadow_ShadowWordPain", "Spell_Nature_Slow", "Spell_Fire_Immolation", "Spell_Shadow_CurseOfTounges" }

  -- the preview's frames draw in their own layer (pfUI puts unit frames on
  -- MEDIUM and parts on BACKGROUND, under the options window)
  local function Restrata(f)
    if f.SetFrameStrata then f:SetFrameStrata("FULLSCREEN") end
    for _, kid in ipairs({ f:GetChildren() }) do Restrata(kid) end
  end
  -- a preview frame does nothing on its own: no clicks, tooltips or updates
  local function Tame(f)
    f:SetScript("OnClick", nil)
    f:SetScript("OnEnter", nil)
    f:SetScript("OnLeave", nil)
    f:SetScript("OnUpdate", nil)
    f:EnableMouse(false)
    Restrata(f)
  end
  UF.Tame = Tame

  function UF.Mini(box)
    local M = { sets = {} }
    UF.mini = M
    local holder = CreateFrame("Frame", nil, box)
    holder:SetAllPoints(box)
    holder:SetFrameStrata("FULLSCREEN")
    holder:SetFrameLevel(1)
    local stage = CreateFrame("Frame", nil, holder)
    stage:SetWidth(10)
    stage:SetHeight(10)
    stage:SetPoint("CENTER", box, "CENTER", 0, 0)
    M.stage, M.zoom, M.dx, M.dy = stage, 1.4, 0, 0
    stage:SetScale(M.zoom)
    local cap = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cap:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -6)
    cap:SetTextColor(.6, .6, .6)
    M.cap = cap

    -- ------------------------------------------------ the view
    -- (user, 22 Oct 2026: "could we have mouse controls ... zoom and drag
    -- ... an alt scroll"): Alt + wheel zooms, dragging empty space (or a
    -- part that has no place of its own) moves the view, a double-click
    -- fits it again. While zoomed in, frames that do not fit wholly in the
    -- box are hidden, so nothing shows outside it.
    M.manual = nil
    local function Zoom(step)
      local z1 = M.zoom
      local z2 = math.max(.35, math.min(4, z1 * (step > 0 and 1.15 or 1 / 1.15)))
      M.manual = true
      M.dx, M.dy = M.dx * z1 / z2, M.dy * z1 / z2
      M.zoom = z2
      stage:SetScale(z2)
      stage:ClearAllPoints()
      stage:SetPoint("CENTER", box, "CENTER", M.dx, M.dy)
    end
    M.Zoom = Zoom
    function M.FitView()
      M.manual = nil
      if M.sets[UF.cur] then for _, f in ipairs(M.sets[UF.cur].frames) do f.octoOut = nil end end
    end
    -- start moving the view from the cursor (the frame running it gets an OnUpdate)
    local function PanStart(fr)
      local cx, cy = GetCursorPosition()
      fr.pan = { cx, cy, M.dx, M.dy }
    end
    local function PanMove(fr)
      local p = fr.pan
      if not p then return end
      local cx, cy = GetCursorPosition()
      local k = stage:GetEffectiveScale() or 1
      local dx, dy = (cx - p[1]) / k, (cy - p[2]) / k
      if not fr.moved and math.abs(dx) + math.abs(dy) < 3 / k then return end
      fr.moved = true
      M.manual = true
      M.dx, M.dy = p[3] + dx, p[4] + dy
      stage:ClearAllPoints()
      stage:SetPoint("CENTER", box, "CENTER", M.dx, M.dy)
    end
    -- (25 Oct 2026, user: "if you scroll outside of anything you can edit
    -- it will zoom" - the plain wheel zooms now, Alt is not needed)
    local function Wheel(fr)
      Zoom(arg1 or 0)
    end
    M.Wheel = Wheel

    -- empty space of the box: moves the view, double-click fits it
    local pan = CreateFrame("Button", nil, holder)
    pan:SetAllPoints(box)
    pan:SetFrameLevel(2)
    pan:RegisterForClicks("LeftButtonUp")
    pan:SetScript("OnMouseDown", function()
      this.moved = nil
      PanStart(this)
      this:SetScript("OnUpdate", function() PanMove(this) end)
    end)
    pan:SetScript("OnMouseUp", function()
      this.pan = nil
      this:SetScript("OnUpdate", nil)
    end)
    pan:SetScript("OnDoubleClick", function() M.FitView() end)
    pan:EnableMouseWheel(true)
    pan:SetScript("OnMouseWheel", function() Wheel(this) end)
    M.pan = pan

    -- "Fit" in the box's corner
    local fitb = CreateFrame("Button", nil, holder)
    fitb:SetFrameLevel(40)
    fitb:SetWidth(54)
    fitb:SetHeight(16)
    fitb:SetPoint("TOPRIGHT", box, "TOPRIGHT", -6, -4)
    fitb.text = fitb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fitb.text:SetAllPoints(fitb)
    fitb:SetScript("OnClick", function() M.FitView() end)
    fitb:SetScript("OnEnter", function() this.text:SetTextColor(1, 1, 1) end)
    fitb:SetScript("OnLeave", function() this.text:SetTextColor(.6, .6, .6) end)
    fitb.text:SetTextColor(.6, .6, .6)
    M.fitb = fitb

    -- ------------------------------------------------ parts you can move
    -- drag = { x key, y key, x factor, y factor, put-back x, put-back y }:
    -- a pixel on screen is that many units of the setting (pfUI moves the
    -- left / right texts two pixels per unit, and the right one inwards)
    local pp = GetPerfectPixel and GetPerfectPixel() or 1
    UF.DRAG = {
      raidIcon = { "raidiconoffx", "raidiconoffy", 1, 1, "0", "20" },
      pvpIcon = { "pvpiconoffx", "pvpiconoffy", 1, 1, "0", "0" },
      power = { "poffx", "poffy", 1, 1 / pp, "0", "0" },
      hpLeftText = { "txthpleftoffx", "txthpleftoffy", .5, 1, "0", "0" },
      hpCenterText = { "txthpcenteroffx", "txthpcenteroffy", 1, 1, "0", "0" },
      hpRightText = { "txthprightoffx", "txthprightoffy", -.5, 1, "0", "0" },
      powerLeftText = { "txtpowerleftoffx", "txtpowerleftoffy", .5, 1, "0", "0" },
      powerCenterText = { "txtpowercenteroffx", "txtpowercenteroffy", 1, 1, "0", "0" },
      powerRightText = { "txtpowerrightoffx", "txtpowerrightoffy", -.5, 1, "0", "0" },
      -- (buffs / debuffs: the corner is picked on their card; dragging moves the row
      -- freely - user, 23 Oct 2026: "i cant move the buffs")
      buffs = { "o_buffx", "o_buffy", 1, 1, "0", "0" },
      debuffs = { "o_debuffx", "o_debuffy", 1, 1, "0", "0" },
    }

    -- Parts that only come in set places (buffs in a corner, the portrait
    -- left / right / on the bar, the class icon, the elite badge) are dragged
    -- too: where the mouse is over the frame picks the place.
    -- (user, 22 Oct 2026: drag and right-click put-back on buffs and portrait)
    -- pick(rx, ry): rx / ry = the mouse across / up the frame, 0 - 1
    local function Corner(rx, ry) return (ry >= .5 and "TOP" or "BOTTOM") .. (rx < .5 and "LEFT" or "RIGHT") end
    -- each frame's own first settings (api/config.lua), for right-click
    local DEFAULTS = {
      group = { buffs = "BOTTOMLEFT", debuffs = "BOTTOMLEFT", portrait = "off" },
      raid = { buffs = "off", debuffs = "off", portrait = "off" },
      grouptarget = { portrait = "off" }, grouppet = { portrait = "off" },
    }
    local function Default(key)
      local d = DEFAULTS[UF.cur]
      if d and d[key] then return d[key] end
      if key == "o_classicon" then return "none" end
      if key == "o_elitepos" then return "TOPRIGHT" end
      if key == "portrait" then return "bar" end
      return "TOPLEFT"
    end
    UF.PLACES = {
      buffs = { key = "buffs", pick = Corner },
      debuffs = { key = "debuffs", pick = Corner },
      portrait = { key = "portrait", pick = function(rx) return (rx < .25 and "left") or (rx > .75 and "right") or "bar" end },
      class = { key = "o_classicon", pick = function(rx, ry)
        if ry >= .5 then return rx < .5 and "TOPLEFT" or "TOPRIGHT" end
        return rx < .5 and "LEFT" or "RIGHT"
      end },
      elite = { key = "o_elitepos", pick = function(rx) return rx < .5 and "TOPLEFT" or "TOPRIGHT" end },
    }
    UF.Default = Default

    -- where the mouse is over frame f: 0 - 1 across and up
    local function Over(f)
      local k = f:GetEffectiveScale() or 1
      local l, b, w, h = f:GetLeft(), f:GetBottom(), f:GetWidth(), f:GetHeight()
      if not (l and b and w and h) or w <= 0 or h <= 0 then return .5, .5 end
      local cx, cy = GetCursorPosition()
      return (cx - l * k) / (w * k), (cy - b * k) / (h * k)
    end
    UF.Over = Over

    local function DragStart(h)
      local cfg = U()
      local d = h.drag
      local cx, cy = GetCursorPosition()
      h.down = { cx, cy, tonumber(cfg[d[1]]) or 0, tonumber(cfg[d[2]]) or 0 }
      h.moved = nil
      -- snap lines (user, 31 Oct 2026: "put my mana bar over health bar they
      -- will snap together"): the part's own edges / middle at the start, and
      -- every other part of the same frame, in that frame's units
      local k = (h.f and h.f:GetEffectiveScale()) or 1
      local function Lines(r)
        local s = (r:GetEffectiveScale() or 1) / k
        local l, rt, t, b = r:GetLeft(), r:GetRight(), r:GetTop(), r:GetBottom()
        if not (l and rt and t and b) then return end
        return { l * s, (l + rt) / 2 * s, rt * s }, { b * s, (b + t) / 2 * s, t * s }
      end
      h.snapX, h.snapY = Lines(h)
      h.toX, h.toY = {}, {}
      local set = h:GetParent()
      for _, o in ipairs(set and set.hots or {}) do
        if o ~= h and o.f == h.f and o:IsShown() then
          local xs, ys = Lines(o)
          if xs then
            for i = 1, 3 do table.insert(h.toX, xs[i]) table.insert(h.toY, ys[i]) end
          end
        end
      end
    end
    -- the move pulled onto the nearest line within 6 px (Alt = free)
    local function Snap(h, dx, dy)
      if IsAltKeyDown() or not h.snapX then return dx, dy end
      local function Pull(own, to, d)
        local best
        for i = 1, 3 do
          for _, v in ipairs(to) do
            local gap = v - (own[i] + d)
            if math.abs(gap) <= 6 and (not best or math.abs(gap) < math.abs(best)) then best = gap end
          end
        end
        return d + (best or 0)
      end
      return Pull(h.snapX, h.toX, dx), Pull(h.snapY, h.toY, dy)
    end
    local function DragMove(h)
      local s = h.down
      if not s then return end
      local cx, cy = GetCursorPosition()
      local k = (h.f and h.f:GetEffectiveScale()) or stage:GetEffectiveScale() or 1
      local dx, dy = (cx - s[1]) / k, (cy - s[2]) / k
      if not h.moved and math.abs(dx) + math.abs(dy) < 3 then return end
      h.moved = true
      M.dragging = true
      -- a part with set places: the place under the mouse
      if h.drag.pick then
        local cfg = U()
        local rx, ry = Over(h.f)
        local v = h.drag.pick(rx, ry)
        if cfg[h.drag.key] ~= v then
          cfg[h.drag.key] = v
          M.Reconfigure(UF.cur)
        end
        return
      end
      local d, cfg = h.drag, U()
      dx, dy = Snap(h, dx, dy)
      local nx = tostring(math.floor(s[3] + dx * d[3] + .5))
      local ny = tostring(math.floor(s[4] + dy * d[4] + .5))
      if cfg[d[1]] == nx and cfg[d[2]] == ny then return end
      cfg[d[1]], cfg[d[2]] = nx, ny
      -- (the preview follows the mouse; the real frame on letting go)
      if (h.next or 0) < GetTime() then
        h.next = GetTime() + .04
        M.Reconfigure(UF.cur)
      end
    end
    local function DragStop(h)
      h.down = nil
      M.dragging = nil
      if h.moved then Up() end
    end

    -- a clickable spot over a part
    local function Hot(set, region, what, level, f, drag)
      local h = CreateFrame("Button", nil, set)
      h:SetFrameLevel((set:GetFrameLevel() or 1) + (level or 30))
      if region then h:SetAllPoints(region) end
      h.region, h.what, h.f, h.drag = region, what, f, drag
      h.hl = h:CreateTexture(nil, "OVERLAY")
      h.hl:SetAllPoints(h)
      h.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
      local ar, ag, ab = .2, .55, .9
      if GetAccentColor then ar, ag, ab = GetAccentColor() end
      h.hl:SetVertexColor(ar, ag, ab, .3)
      h.hl:Hide()
      h:SetScript("OnEnter", function()
        this.hl:Show()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine(UF.HOTLABEL[this.what] or this.what)
        GameTooltip:AddLine("Click: its settings", 1, 1, 1)
        if this.drag then
          GameTooltip:AddLine("Drag: move it", 1, 1, 1)
          GameTooltip:AddLine("Right-click: put it back", 1, 1, 1)
        else
          GameTooltip:AddLine("Drag: move the view", .7, .7, .7)
        end
        if UF.SIZE[this.what] then GameTooltip:AddLine("Shift + mouse wheel: bigger / smaller", 1, 1, 1) end
        GameTooltip:AddLine("Alt + mouse wheel: zoom", .7, .7, .7)
        GameTooltip:Show()
      end)
      h:SetScript("OnLeave", function() this.hl:Hide() GameTooltip:Hide() end)
      h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      h:SetScript("OnMouseDown", function()
        if arg1 == "RightButton" then return end
        this.moved = nil
        if this.drag then DragStart(this) else PanStart(this) end
        this:SetScript("OnUpdate", function()
          if this.drag then DragMove(this) else PanMove(this) end
        end)
      end)
      h:SetScript("OnMouseUp", function()
        this:SetScript("OnUpdate", nil)
        this.pan = nil
        if this.drag then DragStop(this) end
      end)
      h:SetScript("OnClick", function()
        if arg1 == "RightButton" then
          if this.drag then
            local cfg, d = U(), this.drag
            if d.pick then
              cfg[d.key] = Default(d.key)
            else
              cfg[d[1]], cfg[d[2]] = d[5], d[6]
            end
            Up()
          end
          return
        end
        -- a drag is not a click
        if this.moved then this.moved = nil return end
        if this.onclick then this.onclick() else UF.Open(this.what) end
      end)
      h:EnableMouseWheel(true)
      h:SetScript("OnMouseWheel", function()
        local s = UF.SIZE[this.what]
        if IsShiftKeyDown() and s then
          local cfg = U()
          local v = (tonumber(cfg[s[1]]) or 0) + (arg1 or 0)
          cfg[s[1]] = tostring(math.max(s[2], math.min(s[3], v)))
          Up()
        else
          Wheel(this)
        end
      end)
      table.insert(set.hots, h)
      return h
    end
    M.Hot = Hot

    -- a text's spot: as wide as its words, where they sit on the bar
    local function TextSpot(h, fs, just)
      local text = fs:GetText()
      local w = fs:GetStringWidth() or 0
      if not fs:IsVisible() or not text or text == "" or w <= 0 then h:Hide() return end
      local _, size = fs:GetFont()
      h:ClearAllPoints()
      h:SetWidth(w + 4)
      h:SetHeight((tonumber(size) or 10) + 4)
      if just == "LEFT" then h:SetPoint("LEFT", fs, "LEFT", -2, 0)
      elseif just == "RIGHT" then h:SetPoint("RIGHT", fs, "RIGHT", 2, 0)
      else h:SetPoint("CENTER", fs, "CENTER", 0, 0) end
      h:Show()
    end

    -- the data a frame shows: the real unit when it exists, else you
    local function DataUnit(key)
      local u = BY[key]
      if u and u[5] and UnitExists(u[5]) then return u[5] end
      return "player"
    end

    -- sample buffs, debuffs, icons and glow on top of what pfUI shows
    local function Samples(f, cfg)
      local function Row(list, icons, limit)
        if not list then return end
        local n = math.min(table.getn(icons), tonumber(limit) or 0)
        for i = 1, n do
          local b = list[i]
          if b and not b:IsShown() then
            b.texture:SetTexture("Interface\\Icons\\" .. icons[i])
            if b.stacks then b.stacks:SetText("") end
            b:Show()
          end
        end
      end
      Row(f.buffs, BUFFS, math.min(tonumber(cfg.bufflimit) or 0, tonumber(cfg.buffperrow) or 8))
      Row(f.debuffs, DEBUFFS, math.min(tonumber(cfg.debufflimit) or 0, tonumber(cfg.debuffperrow) or 8))
      if cfg.raidicon == "1" and f.raidIcon then
        if SetRaidTargetIconTexture then SetRaidTargetIconTexture(f.raidIcon.texture, 8) end
        f.raidIcon:Show()
      end
      -- the extras (unitframes-octo.lua): an elite badge to look at
      local X = pfUI.ufExtras
      if X and f.octoElite then
        f.octoForceElite = (cfg.o_elite and cfg.o_elite ~= "none") and "elite" or nil
        X.Update(f)
      end
      if cfg.leadericon == "1" and f.leaderIcon then f.leaderIcon:Show() end
      if cfg.looticon == "1" and f.lootIcon then f.lootIcon:Show() end
      if cfg.showPVP == "1" and f.pvpIcon then f.pvpIcon:Show() end
      if f.happinessIcon and UF.cur == "pet" and cfg.happinessicon and cfg.happinessicon ~= "0" then f.happinessIcon:Show() end
      if f.glow then
        if cfg.glowaggro == "1" then
          f.glow:SetBackdropBorderColor(1, .2, 0)
          f.glow:Show()
        elseif cfg.glowcombat == "1" then
          f.glow:SetBackdropBorderColor(1, 1, .2)
          f.glow:Show()
        else
          f.glow:Hide()
        end
      end
      if f.combat then
        if cfg.squareaggro == "1" then
          f.combat.tex:SetTexture(1, .2, 0)
          f.combat:Show()
        elseif cfg.squarecombat == "1" then
          f.combat.tex:SetTexture(1, 1, .2)
          f.combat:Show()
        else
          f.combat:Hide()
        end
      end
    end

    -- one unit's frames in the preview (made the first time its tab opens)
    local function Set(key)
      if M.sets[key] then return M.sets[key] end
      local u = BY[key]
      local set = CreateFrame("Frame", nil, stage)
      set:SetAllPoints(stage)
      set.hots, set.frames, set.texts = {}, {}, {}
      for i = 1, u[4] do
        local f = pfUI.uf:CreateUnitFrame("OctoPrev" .. key, tostring(i), C.unitframes[key])
        f:SetParent(set)
        f.label, f.id = DataUnit(key), ""
        f.octoPreview = true
        Tame(f)
        table.insert(set.frames, f)
        local D = UF.DRAG
        Hot(set, f, "frame", 20, f)
        Hot(set, f.hp, "hp", 22, f)
        Hot(set, f.power, "power", 22, f, D.power)
        Hot(set, f.portrait, "portrait", 23, f, UF.PLACES.portrait)
        for _, list in ipairs({ { f.buffs, "buffs" }, { f.debuffs, "debuffs" } }) do
          for _, b in pairs(list[1] or {}) do b.octoHot = Hot(set, b, list[2], 26, f, UF.DRAG[list[2]]) end
        end
        Hot(set, f.raidIcon, "icons", 28, f, D.raidIcon)
        Hot(set, f.pvpIcon, "icons", 28, f, D.pvpIcon)
        for _, ic in ipairs({ f.leaderIcon, f.lootIcon, f.happinessIcon, f.restIcon }) do Hot(set, ic, "icons", 28, f) end
        Hot(set, f.combat, "glow", 28, f)
        Hot(set, f.octoClass, "class", 29, f, UF.PLACES.class)
        Hot(set, f.octoElite, "class", 29, f, UF.PLACES.elite)
        Hot(set, f.octoEliteText, "class", 29, f, UF.PLACES.elite)
        for _, r in ipairs({ f.octoStatus, f.octoStatusText }) do Hot(set, r, "class", 29, f) end
        if f.octoSkin then f.octoSkin.octoHot = Hot(set, f.octoSkin, "border", 19, f) end
        for _, t in ipairs({ { f.hpLeftText, "hpleft", "LEFT", "hpLeftText" }, { f.hpCenterText, "hpcenter", "CENTER", "hpCenterText" },
            { f.hpRightText, "hpright", "RIGHT", "hpRightText" }, { f.powerLeftText, "powerleft", "LEFT", "powerLeftText" },
            { f.powerCenterText, "powercenter", "CENTER", "powerCenterText" }, { f.powerRightText, "powerright", "RIGHT", "powerRightText" } }) do
          local h = Hot(set, nil, t[2], 30, f, D[t[4]])
          table.insert(set.texts, { h, t[1], t[3] })
        end
      end
      -- the cast bar under the player, target and focus frames: a click
      -- opens the Cast bars page on its tab
      if (key == "player" or key == "target" or key == "focus") and C.castbar and C.castbar[key] then
        local f = set.frames[1]
        local cb = CreateFrame("StatusBar", nil, set)
        cb:SetMinMaxValues(0, 100)
        cb:SetValue(60)
        CreateBackdrop(cb)
        cb.text = cb:CreateFontString(nil, "OVERLAY")
        cb.text:SetPoint("LEFT", cb, "LEFT", 3, 0)
        cb.key = key
        set.castbar = cb
        local h = Hot(set, cb, "castbar", 24, f)
        h.onclick = function() O:Open("ufcastbar", key) end
        f.octoPrevCast = cb
      end
      M.sets[key] = set
      return set
    end
    M.Set = Set

    -- the sample cast bar: pfUI's look and the Cast bars page's size
    local function CastSample(set, key)
      local cb = set.castbar
      if not cb then return end
      local s = C.castbar[key]
      if s.hide_pfui == "1" then cb:Hide() return end
      local f = set.frames[1]
      local w = tonumber(s.width) or -1
      if w <= 0 then w = f:GetWidth() or 200 end
      local h = tonumber(s.height) or -1
      if h <= 0 then h = (tonumber(C.global.font_size) or 12) * 1.5 end
      cb:SetWidth(w)
      cb:SetHeight(h)
      cb:ClearAllPoints()
      cb:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -6)
      cb:SetStatusBarTexture(pfUI.media[C.appearance.castbar.texture])
      local r, g, b, a = GetStringColor(C.appearance.castbar.castbarcolor or ".7,.7,.9,.8")
      cb:SetStatusBarColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1)
      cb.text:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, tonumber(C.global.font_size) or 12, "OUTLINE")
      cb.text:SetText(s.showname == "1" and "Frostbolt" or "")
      cb:Show()
    end

    -- where the frames of a set sit on the stage (party in a column, raid
    -- in a grid as its settings say)
    local function Place(set, key)
      local cfg = C.unitframes[key]
      local n = table.getn(set.frames)
      local fw, fh = set.frames[1]:GetWidth() or 100, set.frames[1]:GetHeight() or 30
      local cols, gap = 1, 12 + (tonumber(cfg.buffsize) or 0)
      local down, left = true, false
      if key == "raid" then
        -- (25 Oct 2026) as many columns as the raid layout has, growing the
        -- way the real raid frames grow (raid.lua)
        local _, _, x = string.find(cfg.raidlayout or "", "(%d+)x")
        cols, gap = math.max(1, math.min(tonumber(x) or 5, n)), tonumber(cfg.raidpadding) or 3
        down, left = cfg.o_growy == "DOWN", cfg.o_growx == "LEFT"
      end
      local rows = math.ceil(n / cols)
      for i, f in ipairs(set.frames) do
        local c, r = math.mod(i - 1, cols), math.floor((i - 1) / cols)
        if not down then r = rows - 1 - r end
        if left then c = cols - 1 - c end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", stage, "TOPLEFT", c * (fw + gap), -r * (fh + gap))
      end
      stage:SetWidth(math.max(10, cols * fw + (cols - 1) * gap))
      stage:SetHeight(math.max(10, rows * fh + (rows - 1) * gap))
    end

    -- a frame's settings changed: pfUI builds its parts again
    function M.Reconfigure(key)
      for k, set in pairs(M.sets) do
        if not key or k == key then
          for _, f in ipairs(set.frames) do
            f.config = C.unitframes[k]
            f:UpdateConfig()
            f.label, f.id = DataUnit(k), ""
            Tame(f)
            -- (buffs made by this update need their spots)
            for _, list in ipairs({ { f.buffs, "buffs" }, { f.debuffs, "debuffs" } }) do
              for _, b in pairs(list[1] or {}) do
                if not b.octoHot then b.octoHot = Hot(set, b, list[2], 26, f, UF.DRAG[list[2]]) end
              end
            end
            if f.octoSkin and not f.octoSkin.octoHot then f.octoSkin.octoHot = Hot(set, f.octoSkin, "border", 19, f) end
          end
        end
      end
      M.Refresh()
    end

    -- the frames of the chosen tab, filled and fitted into the box
    function M.Refresh()
      local key = UF.cur
      for k, set in pairs(M.sets) do if k ~= key then set:Hide() end end
      local set = Set(key)
      set:Show()
      local cfg = C.unitframes[key]
      for _, f in ipairs(set.frames) do
        f.label, f.id = DataUnit(key), ""
        f:Show()
        -- (a unit that went away mid-update must not break the page)
        pcall(pfUI.uf.RefreshUnit, pfUI.uf, f, "all")
        -- part health and power, so the bar texture, the empty part's colour
        -- and shade show; health drops every few seconds (fading bar, flash)
        -- (in the bar's own scale, as pfUI just set it: changing the scale
        -- made the bars jump on every refresh; pfUI slides them to the value)
        local hp = math.mod(math.floor(GetTime() / 3), 2) == 0 and .85 or .45
        for _, part in ipairs({ { f.hp, hp }, { f.power, .6 } }) do
          local bar = part[1] and part[1].bar
          if bar and bar.SetValue then
            local lo, hi = bar.min or 0, bar.max
            if not hi or hi <= lo then
              hi = 100
              bar:SetMinMaxValues(0, 100)
              lo = 0
            end
            bar:SetValue(lo + (hi - lo) * part[2])
          end
        end
        Samples(f, cfg)
      end
      Place(set, key)
      CastSample(set, key)
      local u = BY[key]
      local who = DataUnit(key) == "player" and "your character" or ("your " .. DataUnit(key))
      local off = cfg.visible == "0" and "  |cffff8080(this frame is off: Frame card)|r" or ""
      cap:SetText(u[2] .. ": showing " .. who .. off)
    end

    -- texts move with their words; the frames grow or shrink to fill the box
    local function Fit()
      local set = M.sets[UF.cur]
      if not set then return end
      -- a spot is there only while its part is (a portrait drawn on the bar
      -- leaves the bar's clicks to the bar)
      local onbar = C.unitframes[UF.cur].portrait == "bar"
      for _, h in ipairs(set.hots) do
        if h.region then
          local want = h.region:IsVisible() and not (h.what == "portrait" and onbar)
          if want and not h:IsShown() then h:Show() elseif not want and h:IsShown() then h:Hide() end
        end
      end
      for _, t in ipairs(set.texts) do TextSpot(t[1], t[2], t[3]) end
      local bk = box:GetEffectiveScale() or 1
      local bl, bt = box:GetLeft(), box:GetTop()
      if not (bl and bt) then return end
      local BW, BH = (box:GetWidth() or 600) * bk, (box:GetHeight() or 150) * bk
      -- each frame's extent, from its parts' spots
      local ext = {}
      local l, r, t, b
      for _, h in ipairs(set.hots) do
        -- (spots hidden because their frame left the box still count, or a
        -- frame once out never came back - user, 31 Oct 2026)
        if (h:IsShown() or h.octoHidden) and (not h.region or h.region:IsVisible() or h.octoHidden) and h:GetLeft() then
          local k = h:GetEffectiveScale() or 1
          local hl, hr, ht, hb = h:GetLeft() * k, h:GetRight() * k, h:GetTop() * k, h:GetBottom() * k
          l, r = math.min(l or hl, hl), math.max(r or hr, hr)
          t, b = math.max(t or ht, ht), math.min(b or hb, hb)
          local e = h.f and (ext[h.f] or {})
          if e then
            e[1], e[2] = math.min(e[1] or hl, hl), math.max(e[2] or hr, hr)
            e[3], e[4] = math.max(e[3] or ht, ht), math.min(e[4] or hb, hb)
            ext[h.f] = e
          end
        end
      end
      if not l then return end
      fitb.text:SetText(M.manual and "Fit view" or "")
      -- zoomed or moved by hand: the view stays; only a frame wholly outside
      -- the box hides (one hidden when partly out made zooming in blank it)
      if M.manual then
        local L, R, T, B = bl * bk + 2, bl * bk + BW - 2, bt * bk - 2, bt * bk - BH + 2
        for _, f in ipairs(set.frames) do
          local e = ext[f]
          local out = e and (e[2] < L or e[1] > R or e[4] > T or e[3] < B) or (not e and f.octoOut)
          out = out and true or nil
          if out ~= f.octoOut then
            f.octoOut = out
            f:SetAlpha(out and 0 or 1)
            if f.octoPrevCast then f.octoPrevCast:SetAlpha(out and 0 or 1) end
            for _, h in ipairs(set.hots) do
              if h.f == f then h.octoHidden = out end
            end
          end
          -- (a refresh may give it its opacity back)
          if f.octoOut and f:GetAlpha() > 0 then f:SetAlpha(0) end
        end
        for _, h in ipairs(set.hots) do
          if h.octoHidden and h:IsShown() then h:Hide() end
        end
        return
      end
      for _, f in ipairs(set.frames) do
        if f.octoOut then
          f.octoOut = nil
          f:SetAlpha(1)
          if f.octoPrevCast then f.octoPrevCast:SetAlpha(1) end
          for _, h in ipairs(set.hots) do if h.f == f then h.octoHidden = nil end end
        end
      end
      -- (while a part is dragged the view holds still)
      if M.dragging then return end
      local availW, availH = BW - 40 * bk, BH - 34 * bk
      local needW, needH = math.max(1, r - l), math.max(1, t - b)
      local zoom = M.zoom * math.min(availW / needW, availH / needH)
      zoom = math.max(.35, math.min(2, zoom))
      -- the middle of everything on the middle of the box (a little low: the
      -- caption is at the top)
      local cx, cy = (l + r) / 2, (t + b) / 2
      local bx, by = bl * bk + BW / 2, bt * bk - BH / 2 - 6 * bk
      local sk = stage:GetEffectiveScale() or 1
      local dx, dy = M.dx + (bx - cx) / sk, M.dy + (by - cy) / sk
      if math.abs(zoom - M.zoom) > .01 or math.abs(dx - M.dx) > .5 or math.abs(dy - M.dy) > .5 then
        -- (offsets count in the stage's own scale: keep the place across zooms)
        dx, dy = dx * M.zoom / zoom, dy * M.zoom / zoom
        M.zoom, M.dx, M.dy = zoom, dx, dy
        stage:SetScale(zoom)
        stage:ClearAllPoints()
        stage:SetPoint("CENTER", box, "CENTER", dx, dy)
      end
    end
    M.Fit = Fit

    -- the sample cast fills smoothly: a 2.5 s cast, then a short pause
    function M.CastTick(now)
      local set = M.sets[UF.cur]
      local cb = set and set.castbar
      if not cb or not cb:IsShown() then return end
      if set.frames[1].octoOut then cb:SetAlpha(0) return end
      local t = math.mod(now, 3)
      cb:SetValue(math.min(100, t / 2.5 * 100))
      cb:SetAlpha(t < 2.5 and 1 or math.max(0, 1 - (t - 2.5) / .5))
    end

    holder:SetScript("OnUpdate", function()
      local now = GetTime()
      M.CastTick(now)
      if (this.fit or 0) < now then
        this.fit = now + .1
        Fit()
      end
      if (this.tick or 0) < now then
        this.tick = now + .5
        M.Refresh()
      end
    end)
    M.Refresh()
    return M
  end

  local function Preview(p)
    W.Pin(p, "Preview", "The chosen frame, built by pfUI from its settings. Pick a frame with the tabs. Click any part of it "
      .. "for its settings; drag a text, the raid mark, the PvP flag, the power bar, the buffs, the portrait, the class icon or "
      .. "the elite badge to move it (right-click puts it back); "
      .. "hold Shift and scroll over a bar, the buffs or a mark to resize it. Scroll the mouse wheel to zoom, drag empty "
      .. "space to move the view, double-click to fit it again. Click this bar to fold it away.", function(p)
      -- the frames as tabs, two rows of six
      local rows = { W.Row(p, 24, 0, 4), W.Row(p, 24, 0, 6) }
      local tabs = {}
      for n, u in ipairs(UF.UNITS) do
        local b = W.Button(rows[(n <= 6) and 1 or 2], u[2], 124, 22)
        b:SetPoint("LEFT", b:GetParent(), "LEFT", math.mod(n - 1, 6) * 128, 0)
        b.key = u[1]
        b:SetScript("OnClick", function()
          UF.cur = this.key
          if UF.mini then
            UF.mini.FitView()
            UF.mini.Refresh()
          end
          -- (the raid tab opens on its layout, the rest of its cards a tab away)
          if this.key == "raid" and UF.sec == "size" then UF.SetSection("raid", true) return end
          O:Refresh()
        end)
        tabs[n] = b
      end
      -- (25 Oct 2026: 170 -> 136 high, so more of the page shows under it)
      local mini = UF.Mini(W.Box(p, 136))
      table.insert(p.items, { Refresh = function()
        for _, b in ipairs(tabs) do W.Pick(b, b.key == UF.cur) end
        mini.Refresh()
      end })
      UF.SectionTabs(p)
      -- every mouse control, spelled out (user: "add how to do this so
      -- people know on the screens")
      local band = W.Row(p, 36, 0, 3)
      local bg = band:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(band)
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      local ar, ag, ab = .2, .55, .9
      if GetAccentColor then ar, ag, ab = GetAccentColor() end
      bg:SetVertexColor(ar, ag, ab, .22)
      local k = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
      local how = band:CreateFontString(nil, "OVERLAY")
      how:SetFont(W.UIFont(), 11, "OUTLINE")
      how:SetPoint("TOPLEFT", band, "TOPLEFT", 12, -4)
      how:SetText(k .. "Click|r a part  its settings     " .. k .. "Drag|r a text, mark, buffs, portrait or power bar  move it     "
        .. k .. "Right-click|r it  put it back     " .. k .. "Shift + wheel|r  size")
      local how2 = band:CreateFontString(nil, "OVERLAY")
      how2:SetFont(W.UIFont(), 11, "OUTLINE")
      how2:SetPoint("TOPLEFT", band, "TOPLEFT", 12, -19)
      how2:SetText(k .. "Wheel|r  zoom     " .. k .. "Drag|r empty space  move the view     " .. k .. "Double-click|r  fit the view     "
        .. k .. "Move frames|r  move them on screen")
      W.HowTo(p, band, how:GetText(), how2:GetText())
    end)
  end

  -- what only happens in a fight, played on the preview (was a row under
  -- it; now a card of the Look section, 25 Oct 2026)
  local function TestCard(p)
    local X = pfUI.ufExtras
    local mini = UF.mini
    if X and mini then
      W.Card(p, "Try it on the preview", { icon = ICON .. "Spell_Nature_Lightning",
        tip = "What only happens in a fight, played on the preview for a few seconds." })
      local trow = W.Row(p, 24, 0, 3)
      local TESTS = {
        { "Hit flash", "A red flash round the frame when it takes a hit (Border and background: Combat flash).",
          function(f) X.Flash(f, false) end },
        { "Heal flash", "A green flash when it is healed.", function(f) X.Flash(f, true) end },
        { "Debuff colour", "The frame in a debuff's colour for 3 seconds (Border and background: Debuff highlight).",
          function(f)
            f.octoForceDebuff = GetTime() + 3
            local mode = f.config.o_debuffhl
            X.ShowDebuff(f, "Magic", (mode and mode ~= "none") and mode or "both")
          end },
        { "Dead", "How a dead unit shows for 3 seconds (Class and status).", function(f) f.octoForceStatus = { nil, "Dead", GetTime() + 3 } X.Update(f) end },
        { "Offline", "How an offline unit shows for 3 seconds.", function(f) f.octoForceStatus = { "uf-offline", nil, GetTime() + 3 } X.Update(f) end },
      }
      local x = 0
      for _, tt in ipairs(TESTS) do
        local bt = W.Button(trow, "Test: " .. tt[1], 124, 22)
        bt:SetPoint("LEFT", trow, "LEFT", x, 0)
        bt.run = tt[3]
        bt:SetScript("OnClick", function()
          this.litUntil = GetTime() + 3
          local set = mini.sets[UF.cur]
          for _, f in ipairs(set and set.frames or {}) do this.run(f) end
        end)
        W.Tip(bt, "Test: " .. tt[1], tt[2])
        x = x + 128
      end
      -- (each test is lit while it shows)
      trow:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + .2
        for _, b in ipairs({ this:GetChildren() }) do
          if b.run then W.Lit(b, GetTime() < (b.litUntil or 0)) end
        end
      end)
    end
  end

  -- ---------------------------------------------------------------- general

  -- What every frame shares, on the Frames page with the preview (user, 22
  -- Oct 2026: "these general options would be better placed under the
  -- preview box ... being able to test the font would be helpful"). The
  -- font changes the frames at once: pfUI keeps it in pfUI.font_unit.
  local function GL() return C.global end
  local function FontNow()
    pfUI.font_unit = pfUI.media[C.global.font_unit] or pfUI.font_unit
    UF.ApplyAll()
  end
  UF.FontNow = FontNow

  -- (user, 29 Oct 2026: "an option to SHOW ENEMY BUFFS clear somewhere ... all ENEMY NPC AND PLAYERS
  -- buffs") the same two settings as on Nameplates > Auras, together
  function UF.EnemyBuffsCard(p)
    Card(p, "Enemy buffs", { tip = "Buffs on enemies - NPCs and players - on your target's frame and on nameplates." })
    Chk(p, "Show every enemy buff (NPCs and players)", "On: buffs the game hides on enemy players are found too (pfUI's enemy buff "
      .. "detection), so your target's frame shows all of them. Changes after a reload.", G, "buffdetect", Reload)
    Drop(p, "Buffs on the target frame", "Where your target's buffs (and an enemy's) sit. Off: none on the target frame.",
      DD("uf_buff_position"), function() return C.unitframes.target end, "buffs")
    W.Dropdown(p, "Enemy buffs on nameplates", "All: every buff an enemy has. Important: big cooldowns only (Ice Block, Shield Wall...).",
      { { key = "all", label = "All of them" }, { key = "important", label = "Important ones" }, { key = "none", label = "None" } },
      function() return C.plates and C.plates.buffshow end,
      function(v) if C.plates then C.plates.buffshow = v end if pfUI.plates and pfUI.plates.Refresh then pcall(pfUI.plates.Refresh) end end)
  end

  local function SharedTop(p)
    Card(p, "All frames: text", { tip = "The font of every unit frame; try it on the preview above. A frame can use its own on Text colours and font." })
    Drop(p, "Font", nil, DD("fonts", "font"), GL, "font_unit", FontNow)
    Sld(p, "Size", nil, 6, 24, 1, GL, "font_unit_size", Px, UF.ApplyAll)
    Drop(p, "Outline", nil, DD("fontstyle"), GL, "font_unit_style", UF.ApplyAll)
    Chk(p, "Short numbers", "12.3k instead of 12345.", G, "abbrevnum", UF.ApplyAll)
    Chk(p, "Short names", "Long names are cut.", G, "abbrevname", UF.ApplyAll)
    Drop(p, "Health bar speed", "How fast bars slide to a new value.", DD("uf_animationspeed"), G, "animation_speed", UF.ApplyAll)
    UF.EnemyBuffsCard(p)
  end

  local function SharedBottom(p)
    Card(p, "All frames: basics")
    W.Check(p, "Use pfUI's unit frames", "Off = the game's own frames (after a reload).", function() return G().disable ~= "1" end, function(v)
      G().disable = v and "0" or "1"
      Reload()
    end)
    Drop(p, "Layout", "Needs a reload.", DD("uf_layout"), G, "layout", Reload)
    Chk(p, "Target sounds", "A sound as you pick an enemy, a friend or nothing.", G, "o_targetsound", function() end)
    -- (portraits of every frame: were a card of their own)
    Sld(p, "Portrait on the bar: opacity", "For portraits drawn on the health bar.", 0, 1, .05, G, "portraitalpha", Pct, UF.ApplyAll)
    Chk(p, "Always flat pictures", "2D pictures instead of 3D models.", G, "always2dportrait", UF.ApplyAll)
    Chk(p, "Flat picture when no model", nil, G, "portraittexture", UF.ApplyAll)
    Card(p, "All frames: colours", { tip = "For every frame, unless a frame has its own (its Colours card)." })
    Chk(p, "Soft (pastel) colours", nil, G, "pastel", UF.ApplyAll)
    Drop(p, "Health bar colour", nil, DD("uf_color"), G, "custom", UF.ApplyAll)
    Color(p, "Own health colour", nil, G, "customcolor", UF.ApplyAll)
    Chk(p, "Fade to the own colour", "Low health moves towards it.", G, "customfade", UF.ApplyAll)
    Chk(p, "Own colour at full health", nil, G, "customfullhp", UF.ApplyAll)
    Chk(p, "Own health background", nil, G, "custombg", UF.ApplyAll)
    Color(p, "Health background", nil, G, "custombgcolor", UF.ApplyAll)
    Chk(p, "Own power background", nil, G, "custompbg", UF.ApplyAll)
    Color(p, "Power background", nil, G, "custompbgcolor", UF.ApplyAll)
    Color(p, "Mana", nil, G, "manacolor", UF.ApplyAll)
    Color(p, "Rage", nil, G, "ragecolor", UF.ApplyAll)
    Color(p, "Energy", nil, G, "energycolor", UF.ApplyAll)
    Color(p, "Focus", nil, G, "focuscolor", UF.ApplyAll)
    Card(p, "All frames: class extras")
    Sld(p, "Combo point width", nil, 2, 30, 1, G, "combowidth", Px, Reload)
    Sld(p, "Combo point height", nil, 2, 30, 1, G, "comboheight", Px, Reload)
    Chk(p, "Energy ticks", "A spark on your power bar for the next energy tick.", function() return C.unitframes.player end, "energy", Reload)
    Chk(p, "Mana ticks", "The same for mana after the five-second rule.", function() return C.unitframes.player end, "manatick", Reload)
    Chk(p, "Show resting", nil, function() return C.unitframes.player end, "showRest", Reload)
    Chk(p, "Druid mana bar", "Your mana while in a form (SuperWoW).", G, "druidmanabar", Reload)
    Sld(p, "Druid mana bar height", nil, 1, 10, 1, G, "druidmanaheight", Px, Reload)
    Chk(p, "Druid mana text", nil, G, "druidmanatext", Reload)
    Card(p, "All frames: party and raid")
    Chk(p, "Range check", "Fades members more than 40 yards away.", G, "rangecheck", Reload)
    Drop(p, "Range check every", nil, DD("uf_rangecheckinterval"), G, "rangechecki", Reload)
    -- (ClassicAPI UnitInLineOfSight, 25 Oct 2026)
    if _G.UnitInLineOfSight then
      Chk(p, "Out of sight fades too", "Members behind a wall or a hill fade like ones out of range: you cannot heal them.", G, "losfade")
    end
    Chk(p, "Raid frames for the party", nil, G, "raidforgroup", UF.ApplyAll)
    Chk(p, "Yourself in the raid frames", nil, G, "selfinraid", UF.ApplyAll)
    Chk(p, "Yourself in the party frames", nil, G, "selfingroup", Reload)
    Chk(p, "Hide party frames in a raid", nil, function() return C.unitframes.group end, "hide_in_raid", UF.ApplyAll)
    Drop(p, "Raid frames at most", nil, DD("maxraid"), G, "maxraid", Reload)
  end

  -- ---------------------------------------------------------------- frames

  BUILD.ufframes = function(p)
    W.Heading(p, "Unit frames", { on = { function() return C.unitframes.disable ~= "1" end, function(v) C.unitframes.disable = v and "0" or "1" pfUI.gui.settingChanged = true end, "pfUI's unit frames on or off (takes a reload)." }, about = "Pick a frame with the tabs: its preview shows at the top. Under it, pick what "
      .. "to change: size and bars, text, buffs, icons, look, the raid layout or what all frames share. Click a part of the "
      .. "preview to jump to its card. The cards named \"All frames\" change every frame." })
    Preview(p)
    -- (the cards start under the heading; UF.Filter chains the shown ones)
    p.ufFirst = p.last
    -- a card in another section (a click on the preview, layout mode's
    -- right-click): that section first
    local P = pfUI.plates
    if P and P.OpenSection and not UF.wrapped then
      UF.wrapped = true
      local OpenSection = P.OpenSection
      P.OpenSection = function(key, title)
        local sec = key == "ufframes" and UF.SECTION_OF[title]
        if sec and sec ~= UF.sec then UF.SetSection(sec, true) end
        return OpenSection(key, title)
      end
    end
    SharedTop(p)

    Card(p, "Frame", { tip = "Whether the frame shows, its tooltip and how see-through it is." })
    Chk(p, "Show this frame", nil, U, "visible")
    Chk(p, "Tooltip on mouse-over", nil, U, "showtooltip")
    Sld(p, "Opacity", nil, .1, 1, .05, U, "alpha_visible", Pct)
    Chk(p, "Fade out of range", nil, U, "faderange")
    Sld(p, "Out of range opacity", nil, 0, 1, .05, U, "alpha_outrange", Pct)
    Sld(p, "Offline opacity", nil, 0, 1, .05, U, "alpha_offline", Pct)

    Card(p, "Health bar")
    Sld(p, "Width", "The width of the whole frame.", 20, 400, 1, U, "width", Px)
    Sld(p, "Height", nil, 2, 100, 1, U, "height", Px)
    Drop(p, "Texture", nil, DD("uf_bartexture", "texture"), U, "bartexture")
    Chk(p, "Fill the other way", "The bar shows health missing.", U, "invert_healthbar")
    Chk(p, "Upright bar", "Fills from the bottom up.", U, "verticalbar")
    Color(p, "Incoming heals", nil, U, "healcolor")
    Drop(p, "Incoming heals past full", nil, DD("uf_overheal"), U, "overhealperc")
    Chk(p, "Fading bar", "The health just lost stays a moment and fades away.", U, "o_fade")
    Sld(p, "Fade time", nil, .1, 3, .1, U, "o_fadetime", Sec)
    Color(p, "Fading part", nil, U, "o_fadecolor")

    -- the six texts: one tab each (a click on a text in the preview picks it)
    Card(p, "Texts", { tip = "Three texts on the health bar and three on the power bar. Pick one with the tabs, "
      .. "or click it in the preview." })
    local trows, tbtns = { W.Row(p, 24, 0, 4), W.Row(p, 24, 0, 4) }, {}
    for i, t in ipairs(UF.TEXTS) do
      local b = W.Button(trows[i <= 3 and 1 or 2], t[2], 150, 22)
      b:SetPoint("LEFT", b:GetParent(), "LEFT", math.mod(i - 1, 3) * 156, 0)
      b.key = t[1]
      b:SetScript("OnClick", function() UF.text = this.key O:Refresh() end)
      tbtns[i] = b
    end
    local function PaintTabs() for _, b in ipairs(tbtns) do W.Pick(b, b.key == UF.text) end end
    PaintTabs()
    table.insert(p.items, { Refresh = PaintTabs })
    local function TK(suffix) return "txt" .. UF.text .. (suffix or "") end
    local function TNAME() for _, t in ipairs(UF.TEXTS) do if t[1] == UF.text then return t[2] end end return UF.text end
    W.Live(p, function() return "Editing: |cffffffff" .. TNAME() .. " text|r" end)
    W.Dropdown(p, "Shows", "What this text says.", DD("uf_texts"), function() return U()[TK()] end,
      function(v) U()[TK()] = v Up() end)
    W.Dropdown(p, "Colour", "Its own colours: as the tick boxes below say (health, power, class...).",
      { { key = "", label = "Its own colours" }, { key = "class", label = "Class colour" }, { key = "custom", label = "One colour" } },
      function() return U()["o_tc_" .. UF.text] or "" end, function(v) U()["o_tc_" .. UF.text] = v Up() end)
    W.Color(p, "Pick a colour", "Picking one switches Colour to One colour.", function()
      local r, g, b, a = GetStringColor(U()["o_tcc_" .. UF.text] or "1,1,1,1")
      return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
    end, function(r, g, b, a)
      U()["o_tcc_" .. UF.text] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
      U()["o_tc_" .. UF.text] = "custom"
      Up()
      O:Refresh()
    end)
    W.Slider(p, "Across", "Or drag it in the preview.", -50, 50, 1, function() return tonumber(U()[TK("offx")]) or 0 end,
      function(v) U()[TK("offx")] = tostring(v) Up() end, Px)
    W.Slider(p, "Up / down", nil, -50, 50, 1, function() return tonumber(U()[TK("offy")]) or 0 end,
      function(v) U()[TK("offy")] = tostring(v) Up() end, Px)
    W.Buttons(p, { { "Put it back", function()
      U()[TK("offx")], U()[TK("offy")], U()["o_tc_" .. UF.text] = "0", "0", ""
      Up()
      O:Refresh()
    end, 110, "Its place and its own colours again." } })

    Card(p, "Text colours and font", { tip = "What \"its own colours\" means for this frame, and its font." })
    Chk(p, "Health in its colour", nil, U, "healthcolor")
    Chk(p, "Power in its colour", nil, U, "powercolor")
    Chk(p, "Level in its colour", nil, U, "levelcolor")
    Chk(p, "Name in class colour", nil, U, "classcolor")
    Chk(p, "Own font for this frame", nil, U, "customfont")
    Drop(p, "Font", nil, DD("fonts", "font"), U, "customfont_name")
    Sld(p, "Font size", nil, 6, 30, 1, U, "customfont_size", Px)
    Drop(p, "Outline", nil, DD("fontstyle"), U, "customfont_style")

    Card(p, "Power bar")
    Sld(p, "Height", "0 or less hides it.", -1, 40, 1, U, "pheight", Px)
    Sld(p, "Width", "-1 = as wide as the health bar.", -1, 400, 1, U, "pwidth", Px)
    Drop(p, "Under the health bar at", nil, DD("uf_powerbar_position"), U, "panchor")
    Sld(p, "Across", nil, -100, 100, 1, U, "poffx", Px)
    Sld(p, "Up / down", nil, -50, 50, 1, U, "poffy", Px)
    Sld(p, "Gap to the health bar", "Below 0 the bars overlap.", -10, 20, 1, U, "pspace", Px)
    Drop(p, "Texture", nil, DD("uf_bartexture", "texture"), U, "pbartexture")

    Card(p, "Portrait")
    Drop(p, "Where", nil, DD("uf_portrait_position"), U, "portrait")
    Sld(p, "Width", "-1 = as tall as the frame.", -1, 200, 1, U, "portraitwidth", Px)
    Sld(p, "Height", "-1 = as tall as the frame.", -1, 200, 1, U, "portraitheight", Px)

    Card(p, "Buffs")
    Drop(p, "Where", "The corner they start from; drag them in the preview to move them from there.", DD("uf_buff_position"), U, "buffs")
    Sld(p, "Across", "Or drag them in the preview.", -200, 200, 1, U, "o_buffx", Px)
    Sld(p, "Up / down", nil, -200, 200, 1, U, "o_buffy", Px)
    Sld(p, "Size", nil, 6, 50, 1, U, "buffsize", Px)
    Sld(p, "How many", nil, 0, 32, 1, U, "bufflimit")
    Sld(p, "Per row", nil, 1, 32, 1, U, "buffperrow")
    Chk(p, "Time left as text", "Also on debuffs.", U, "cooldown_text")
    Chk(p, "Time left as a sweep", "Also on debuffs.", U, "cooldown_anim")
    Chk(p, "Sweep the other way", "The dark part grows as the time runs out (with ClassicAPI).", U, "cooldown_reverse")
    Chk(p, "Flash in the last 30 seconds (player)", "Your own buffs pulse before they run out.",
      function() return C.unitframes.player end, "o_flashexpire", function() UF.Apply("player") end)
    Chk(p, "Frame enemy buffs you can purge", "Magic buffs on enemies get a blue frame. Needs ClassicAPI (the plain game does not say a buff's type); with it others' buffs also show their time left.", U, "o_purge")

    Card(p, "Debuffs")
    Drop(p, "Where", "The corner they start from; drag them in the preview to move them from there.", DD("uf_buff_position"), U, "debuffs")
    Sld(p, "Across", "Or drag them in the preview.", -200, 200, 1, U, "o_debuffx", Px)
    Sld(p, "Up / down", nil, -200, 200, 1, U, "o_debuffy", Px)
    Sld(p, "Size", nil, 6, 50, 1, U, "debuffsize", Px)
    Sld(p, "How many", nil, 0, 32, 1, U, "debufflimit")
    Sld(p, "Per row", nil, 1, 32, 1, U, "debuffperrow")
    Chk(p, "Only your own", "Not on your own frame. Experimental.", U, "selfdebuff")

    Card(p, "Icons", { tip = "Raid mark, PvP flag, leader, loot master and (pet) happiness." })
    Chk(p, "Raid mark", nil, U, "raidicon")
    Drop(p, "Raid mark at", nil, DD("positions"), U, "raidiconalign")
    Sld(p, "Raid mark size", nil, 8, 64, 1, U, "raidiconsize", Px)
    Sld(p, "Raid mark: across", nil, -100, 100, 1, U, "raidiconoffx", Px)
    Sld(p, "Raid mark: up / down", nil, -100, 100, 1, U, "raidiconoffy", Px)
    Chk(p, "PvP flag", nil, U, "showPVP")
    Drop(p, "PvP flag at", nil, DD("positions"), U, "pvpiconalign")
    Sld(p, "PvP flag size", nil, 8, 64, 1, U, "pvpiconsize", Px)
    Sld(p, "PvP flag: across", nil, -100, 100, 1, U, "pvpiconoffx", Px)
    Sld(p, "PvP flag: up / down", nil, -100, 100, 1, U, "pvpiconoffy", Px)
    Chk(p, "Leader", nil, U, "leadericon")
    Chk(p, "Loot master", nil, U, "looticon")
    Drop(p, "Pet happiness (pet frame)", nil, DD("uf_happiness"), function() return C.unitframes.pet end, "happinessicon", function() UF.Apply("pet") end)
    Sld(p, "Pet happiness size", nil, 6, 32, 1, function() return C.unitframes.pet end, "happinesssize", Px, function() UF.Apply("pet") end)
    Chk(p, "Pet happiness only when unhappy", nil, function() return C.unitframes.pet end, "o_happysad", function() UF.Apply("pet") end)
    Chk(p, "Unhappy pet flashes", nil, function() return C.unitframes.pet end, "o_happyflash", function() UF.Apply("pet") end)

    local X = pfUI.ufExtras
    local function L(src)
      local out = {}
      for _, s in ipairs(src or {}) do table.insert(out, { key = s.key, label = s.label, texture = s.tex and (X.ART .. s.tex) or nil }) end
      return out
    end
    Card(p, "Border and background", { tip = "A border round the whole frame, a shade behind the bars, and flashes and highlights on it." })
    Drop(p, "Border", nil, L(X and X.SKINS), U, "o_skin")
    Drop(p, "Shade behind the bars", nil, L(X and X.GRADIENTS), U, "o_grad")
    Color(p, "Shade from", nil, U, "o_gradstart")
    Color(p, "Shade to", nil, U, "o_gradend")
    Chk(p, "Combat flash", "Red round the frame on a hit, green on a heal.", U, "o_flash")
    Chk(p, "Highlight your target", "A line round this frame while its unit is your target (party, raid, pet).", U, "o_selhl")
    Drop(p, "Debuff highlight", "The frame in the colour of its debuff (magic blue, curse purple, poison green, disease brown).",
      L(X and X.HIGHLIGHTS), U, "o_debuffhl")
    Chk(p, "Only what you can cure", nil, U, "o_curable")

    Card(p, "Class and status", { tip = "Class icon, class picture, the elite / rare / boss badge, and AFK, offline and dead marks." })
    Drop(p, "Class icon", "Players only.", L(X and X.CLASSICON), U, "o_classicon")
    Sld(p, "Class icon size", nil, 8, 40, 1, U, "o_classsize", Px)
    Chk(p, "Class picture as portrait", "Players show their class icon in place of the portrait.", U, "o_classport")
    Drop(p, "Elite, rare and boss", nil, L(X and X.ELITE), U, "o_elite")
    Drop(p, "Badge at", nil, L(X and X.CORNERS), U, "o_elitepos")
    Chk(p, "AFK, offline and dead marks", nil, U, "o_status")

    Card(p, "Glow and indicators", { tip = "A glow round the frame and a small square for aggro and combat; combat text on the frame." })
    Chk(p, "Glow with aggro", nil, U, "glowaggro")
    Chk(p, "Glow in combat", nil, U, "glowcombat")
    Chk(p, "Square with aggro", nil, U, "squareaggro")
    Chk(p, "Square in combat", nil, U, "squarecombat")
    Drop(p, "Square at", nil, DD("positions"), U, "squarepos")
    Sld(p, "Square size", nil, 2, 30, 1, U, "squaresize", Px)
    Chk(p, "Combat text on the frame", "Hits and heals on the portrait or bar.", U, "hitindicator")
    Drop(p, "Combat text font", nil, DD("fonts", "font"), U, "hitindicatorfont")
    Sld(p, "Combat text size", nil, 8, 40, 1, U, "hitindicatorsize", Px)

    Card(p, "Buff and dispel markers", { tip = "Small markers for your buffs, HoTs and procs, and for debuffs you can dispel. Best on party and raid frames." })
    Chk(p, "Buff markers", nil, U, "buff_indicator")
    Chk(p, "Your buffs", nil, U, "show_buffs")
    Chk(p, "HoTs", nil, U, "show_hots")
    Chk(p, "HoTs of every class", nil, U, "all_hots")
    Chk(p, "Procs", nil, U, "show_procs")
    Chk(p, "Procs of every class", nil, U, "all_procs")
    Chk(p, "Totems", nil, U, "show_totems")
    Chk(p, "Time left", nil, U, "indicator_time")
    Chk(p, "Stacks", nil, U, "indicator_stacks")
    Sld(p, "Marker size", nil, 4, 30, 1, U, "indicator_size", Px)
    Drop(p, "Marker spacing", nil, DD("spacing"), U, "indicator_spacing")
    Drop(p, "Markers at", nil, DD("positions"), U, "indicator_pos")
    Drop(p, "Dispel markers", nil, DD("uf_debuff_indicator"), U, "debuff_indicator")
    Chk(p, "Only what you can dispel", nil, U, "debuff_ind_class")
    Drop(p, "Dispel marker at", nil, DD("positions"), U, "debuff_ind_pos")
    Drop(p, "Dispel marker size", nil, DD("uf_debuff_indicator_size"), U, "debuff_ind_size")

    Card(p, "Colours", { tip = "This frame's own colours (off = the ones on General)." })
    Chk(p, "Use the colours on General", nil, U, "defcolor")
    Drop(p, "Health bar colour", nil, DD("uf_color"), U, "custom")
    Color(p, "Own health colour", nil, U, "customcolor")
    Chk(p, "Fade to the own colour", nil, U, "customfade")
    Chk(p, "Own colour at full health", nil, U, "customfullhp")
    Chk(p, "Own health background", nil, U, "custombg")
    Color(p, "Health background", nil, U, "custombgcolor")
    Chk(p, "Own power background", nil, U, "custompbg")
    Color(p, "Power background", nil, U, "custompbgcolor")
    Color(p, "Mana", nil, U, "manacolor")
    Color(p, "Rage", nil, U, "ragecolor")
    Color(p, "Energy", nil, U, "energycolor")
    Color(p, "Focus", nil, U, "focuscolor")

    -- the raid frames' grid (user, 25 Oct 2026: "no raid layout options
    -- easily accessible"): its own section and card, opened by layout mode's
    -- right-click on the raid box. Every change lays the real grid out again.
    local function R() return C.unitframes.raid end
    local function UR() UF.Apply("raid") end
    Card(p, "Raid layout", { tip = "How the raid frames are laid out: columns and rows, which way they grow, the gap, and "
      .. "the size of each frame. Layout mode (Move frames) moves the whole raid as one box; its mouse wheel sizes the "
      .. "frames a pixel at a time and keeps the grid." })
    W.Live(p, function()
      local cfg = R()
      local _, _, x, y = string.find(cfg.raidlayout or "", "(%d+)x(%d+)")
      local cl = _G.pfRaidCluster
      local size = cl and cl:GetWidth() and (math.floor(cl:GetWidth() * cl:GetScale() + .5) .. " x "
        .. math.floor(cl:GetHeight() * cl:GetScale() + .5) .. " px") or "?"
      return "|cffffffff" .. (x or "?") .. " columns x " .. (y or "?") .. " rows|r of " .. (cfg.width or "?") .. " x "
        .. (cfg.height or "?") .. " px frames - the whole raid " .. size
    end)
    Drop(p, "Columns x rows", "Columns across, rows up or down. 5 x 8 = the eight groups as rows of five.", DD("uf_raidlayout"), R, "raidlayout", UR)
    Drop(p, "Fill", "Which way the grid fills: a row at a time, or a column at a time.", DD("orientation"), R, "raidfill", UR)
    W.Dropdown(p, "Rows grow", "Where the first row is: at the bottom, the next ones above it (pfUI's way), or at the top.",
      { { key = "UP", label = "Up (first row at the bottom)" }, { key = "DOWN", label = "Down (first row at the top)" } },
      function() return R().o_growy or "UP" end, function(v) R().o_growy = v UR() end)
    W.Dropdown(p, "Columns grow", "Where the first column is.",
      { { key = "RIGHT", label = "Right (first column on the left)" }, { key = "LEFT", label = "Left (first column on the right)" } },
      function() return R().o_growx or "RIGHT" end, function(v) R().o_growx = v UR() end)
    Sld(p, "Frame width", "Each raid frame. The grid keeps its columns and rows.", 20, 400, 1, R, "width", Px, UR)
    Sld(p, "Frame height", "Each raid frame's health bar.", 4, 100, 1, R, "height", Px, UR)
    Sld(p, "Power bar height", "0 or less hides it.", -1, 40, 1, R, "pheight", Px, UR)
    Sld(p, "Gap between frames", nil, 0, 20, 1, R, "raidpadding", Px, UR)
    Chk(p, "Group labels", nil, R, "raidgrouplabel", UR)
    Sld(p, "Labels: across", nil, -50, 50, 1, R, "grouplabelxoff", Px, UR)
    Sld(p, "Labels: up / down", nil, -50, 50, 1, R, "grouplabelyoff", Px, UR)
    W.Buttons(p, { { "Move the raid frames", function()
      if _G.SlashCmdList and _G.SlashCmdList.PFMOVEUI then _G.SlashCmdList.PFMOVEUI("") end
    end, 170, "Layout mode: drag the raid box; the mouse wheel over it sizes the frames (Shift: 5 px a notch)." } })

    -- what all frames share, after this frame's own cards
    SharedBottom(p)
    TestCard(p)

    -- only the picked section shows (also after every refresh)
    UF.Filter(p)
    table.insert(p.items, { Refresh = function() UF.Filter(p) end })
  end

  -- ---------------------------------------------------------------- click casting

  BUILD.ufclick = function(p)
    W.Heading(p, "Click casting", { about = "Cast by clicking a unit frame: a spell name per mouse button and key. "
      .. "\"target\" targets, \"menu\" opens the menu." })
    W.Card(p, "Frames with click casting")
    for _, u in ipairs(UF.UNITS) do
      local key = u[1]
      PfChk(p, u[2], nil, function() return C.unitframes[key] end, "clickcast", function() UF.Apply(key) end)
    end
    local BUTTONS = { { "", "Left button" }, { "2", "Right button" }, { "3", "Middle button" }, { "4", "Button 4" }, { "5", "Button 5" } }
    for _, bt in ipairs(BUTTONS) do
      W.Card(p, bt[2])
      for _, mod in ipairs({ { "", "Click" }, { "_shift", "Shift-click" }, { "_alt", "Alt-click" }, { "_ctrl", "Ctrl-click" } }) do
        local key = "clickcast" .. bt[1] .. mod[1]
        W.Edit(p, mod[2], nil, function() return C.unitframes[key] or "" end, function(v)
          C.unitframes[key] = v or ""
        end)
      end
    end
  end

  -- layout mode's right-click on a frame opens Frames on its tab
  O.tabs = O.tabs or {}
  O.tabs.ufframes = function(key)
    if BY[key] then
      UF.cur = key
      if key == "raid" then UF.sec = "raid" end
      if UF.mini then UF.mini.Refresh() end
    end
  end

  O.replaced[T["Unit Frames"]] = true
  O:AddPage("Unit Frames", "ufframes", "Frames", BUILD.ufframes)
  O:AddPage("Unit Frames", "ufclick", "Click casting", BUILD.ufclick)
end)
