pfUI:RegisterModule("dots-target", "vanilla", function ()
  -- pfUI Octo :: OctoDoTs > Target bar (18 Nov 2026; user: "A druid friend wants to be able to track bleeds and his dots on
  -- his target ... a simple bar that is movable ... just be spell icons ... He can choose what he wants to track what
  -- debuffs etc and what to ignore easily with icons in a UI bar add this into a menu in Octo Dots at the top").
  -- A row of your own debuffs on your target - DoTs, bleeds (Rake, Rip, Pounce), Faerie Fire... - each as its spell icon
  -- with the time left and a dark shade that drains as it runs out. It reads them with OctoDoTs' own reader (D.Read:
  -- ClassicAPI's real timers, else SuperWoW + the data file's durations, else pfUI's target debuff timers), only for the
  -- target, ten times a second. Settings C.dots.tb_* ; per spell C.dots.tb_list[lower name] = "track" | "ignore".
  local D = pfUI.dots
  if not D or not D.Read then return end
  local TB = {}
  D.tbar = TB
  pfUI.dotsTarget = TB
  local _, myClass = UnitClass("player")
  TB.class = myClass

  local function S() return C.dots end
  local function On(k) return C.dots[k] == "1" end
  local function Num(k, d) return tonumber(C.dots[k]) or d end
  local function Low(s) return string.lower(s or "") end
  local function List()
    if type(C.dots.tb_list) ~= "table" then C.dots.tb_list = {} end
    return C.dots.tb_list
  end
  local function Seen()
    if type(C.dots.tb_seen) ~= "table" then C.dots.tb_seen = {} end
    return C.dots.tb_seen
  end
  function TB.State(name) return List()[Low(name)] end
  -- click cycle in the options: nothing -> track -> ignore -> nothing
  function TB.Cycle(name)
    local l, k = List(), Low(name)
    if l[k] == nil then l[k] = "track" elseif l[k] == "track" then l[k] = "ignore" else l[k] = nil end
    TB.dirty = true
  end

  -- ---------------------------------------------------------------- which spells there are (for the picker)

  -- name -> icon from your spell book (DoTs and bleeds you know)
  local book
  function TB.BookIcons()
    if book then return book end
    book = {}
    local i = 1
    while true do
      local name = GetSpellName(i, BOOKTYPE_SPELL or "spell")
      if not name then break end
      if not book[Low(name)] then book[Low(name)] = GetSpellTexture(i, BOOKTYPE_SPELL or "spell") end
      i = i + 1
      if i > 500 then break end
    end
    return book
  end
  function TB.Icon(name)
    local k = Low(name)
    return Seen()[k] or TB.BookIcons()[k]
  end
  -- your class's debuffs from OctoDoTs' data, then what was seen on targets: { { name, icon } } sorted by name
  function TB.Spells()
    local out, have = {}, {}
    local function Add(name)
      local k = Low(name)
      if name and name ~= "" and not have[k] then
        have[k] = true
        table.insert(out, { name = name, icon = TB.Icon(name) })
      end
    end
    for _, sp in pairs(D.DATA.spells or {}) do if sp[3] == myClass then Add(sp[1]) end end
    for _, r in ipairs(D.DATA.raid or {}) do if r.class == myClass then Add(r.name) end end
    for k, v in pairs(Seen()) do if type(v) == "string" and not have[k] then Add(TB.SeenName(k)) end end
    for k in pairs(List()) do if not have[k] then Add(TB.SeenName(k)) end end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
  end
  -- seen names are kept lower case; show them in title case
  function TB.SeenName(k)
    return (string.gsub(k, "(%a)([%w']*)", function(a, b) return string.upper(a) .. b end))
  end

  -- ---------------------------------------------------------------- reading your debuffs on the target

  local u = { auras = {}, na = 0 }
  TB.unit = u
  -- your debuffs on the target that the settings let through, and the tracked ones missing: { { name, icon, ends, dur,
  -- stacks, missing } } in the chosen order
  local shown, pool = {}, {}
  function TB.Collect(now)
    for i = table.getn(shown), 1, -1 do shown[i] = nil end
    if table.setn then pcall(table.setn, shown, 0) end
    if not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then return shown end
    u.guid = D.Guid and D.Guid("target") or "target"
    u.plain = not (D.Classic() or (D.SuperWoW() and string.find(u.guid or "", "^0x")))
    if u.plain then u.guid = "target" end
    D.Read(u, now)
    local list, mode, got = List(), S().tb_mode or "all", {}
    local n = 0
    for i = 1, u.na do
      local a = u.auras[i]
      if a and a.kind == "mine" and a.name then
        local k = Low(a.name)
        if a.icon and Seen()[k] ~= a.icon then Seen()[k] = a.icon end
        local st = list[k]
        if st ~= "ignore" and (mode == "all" or st == "track") and not got[k] then
          got[k] = true
          n = n + 1
          local e = pool[n] or {}
          pool[n] = e
          e.name, e.icon, e.ends, e.dur, e.stacks, e.missing = a.name, a.icon or TB.Icon(a.name), a.ends, a.dur, a.stacks, nil
          table.insert(shown, e)
        end
      end
    end
    -- tracked ones that are not up: greyed, so you see what to put on
    if On("tb_missing") then
      for k, st in pairs(list) do
        if st == "track" and not got[k] then
          n = n + 1
          local e = pool[n] or {}
          pool[n] = e
          e.name, e.icon, e.ends, e.dur, e.stacks, e.missing = TB.SeenName(k), TB.Icon(k), nil, nil, 0, true
          table.insert(shown, e)
        end
      end
    end
    local order = S().tb_order or "time"
    table.sort(shown, function(a, b)
      if a.missing ~= b.missing then return not a.missing end
      if order == "time" and a.ends and b.ends and a.ends ~= b.ends then return a.ends < b.ends end
      return a.name < b.name
    end)
    return shown
  end

  -- ---------------------------------------------------------------- the bar

  local MAX = 12
  local function Font() return pfUI.font_unit or pfUI.font_default or STANDARD_TEXT_FONT end
  local function NewIcon(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.edge = f:CreateTexture(nil, "BACKGROUND")
    f.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.edge:SetAllPoints(f)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetTexCoord(.08, .92, .08, .92)
    f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    -- a dark shade over the part of the time already gone (drains from the top)
    f.shade = f:CreateTexture(nil, "OVERLAY")
    f.shade:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.shade:SetVertexColor(0, 0, 0, .55)
    f.shade:SetPoint("TOPLEFT", f.tex, "TOPLEFT", 0, 0)
    f.shade:SetPoint("TOPRIGHT", f.tex, "TOPRIGHT", 0, 0)
    f.time = f:CreateFontString(nil, "OVERLAY")
    f.time:SetPoint("BOTTOM", f, "BOTTOM", 0, 2)
    f.stack = f:CreateFontString(nil, "OVERLAY")
    f.stack:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -2)
    return f
  end
  -- draws one icon from an entry at time t
  function TB.PaintIcon(f, e, t)
    local size = Num("tb_size", 34)
    f:SetWidth(size)
    f:SetHeight(size)
    f.tex:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    f.time:SetFont(Font(), math.max(8, math.floor(size * .36)), "OUTLINE")
    f.stack:SetFont(Font(), math.max(7, math.floor(size * .3)), "OUTLINE")
    f.stack:SetText((e.stacks or 0) > 1 and e.stacks or "")
    if e.missing then
      f.tex:SetVertexColor(.35, .35, .35)
      f.edge:SetVertexColor(.5, .15, .15, 1)
      f.shade:Hide()
      f.time:SetText("")
      return
    end
    f.tex:SetVertexColor(1, 1, 1)
    local left = e.ends and (e.ends - t)
    local warn = Num("tb_warn", 3)
    if left and left <= warn then f.edge:SetVertexColor(1, .2, .2, 1) else f.edge:SetVertexColor(0, 0, 0, 1) end
    if On("tb_timer") and left then
      f.time:SetText(D.TimeText(left))
      if left <= warn then f.time:SetTextColor(1, .3, .3) else f.time:SetTextColor(1, 1, 1) end
    else
      f.time:SetText("")
    end
    if On("tb_drain") and left and e.dur and e.dur > 0 then
      local gone = math.max(0, math.min(1, 1 - left / e.dur))
      local h = (size - 2) * gone
      if h < .5 then f.shade:Hide() else f.shade:SetHeight(h) f.shade:Show() end
    else
      f.shade:Hide()
    end
  end
  -- lays a list of entries out on a holder frame (the bar and the options' preview)
  function TB.Layout(holder, list, t)
    holder.icons = holder.icons or {}
    local size, gap = Num("tb_size", 34), Num("tb_gap", 3)
    local n = math.min(MAX, table.getn(list))
    local grow = S().tb_grow or "RIGHT"
    for i = 1, n do
      local f = holder.icons[i] or NewIcon(holder)
      holder.icons[i] = f
      TB.PaintIcon(f, list[i], t)
      f:ClearAllPoints()
      local x = (i - 1) * (size + gap)
      if grow == "LEFT" then f:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -x, 0)
      elseif grow == "CENTER" then f:SetPoint("TOPLEFT", holder, "TOP", x - (n * (size + gap) - gap) / 2, 0)
      else f:SetPoint("TOPLEFT", holder, "TOPLEFT", x, 0) end
      f:Show()
    end
    for i = n + 1, table.getn(holder.icons) do holder.icons[i]:Hide() end
    holder:SetHeight(size)
    holder:SetWidth(math.max(size, MAX * (size + gap) - gap))
  end

  local bar = CreateFrame("Frame", "pfDotTargetBar", UIParent)
  TB.frame = bar
  bar:SetFrameStrata("MEDIUM")
  bar:SetPoint("CENTER", UIParent, "CENTER", 0, -170)
  bar:SetWidth(200)
  bar:SetHeight(34)
  bar:EnableMouse(false)
  if UpdateMovable then UpdateMovable(bar) end

  -- made-up debuffs for the preview, the test and layout mode
  TB.FAKE = { { "Rake", "Ability_Druid_Disembowel", 9, 3 }, { "Rip", "Ability_GhoulFrenzy", 12, 10 },
              { "Moonfire", "Spell_Nature_StarFall", 12, 2 }, { "Faerie Fire (Feral)", "Spell_Nature_FaerieFire", 40, 31 } }
  local fake = {}
  function TB.Fake(t)
    for i, d in ipairs(TB.FAKE) do
      local e = fake[i] or {}
      fake[i] = e
      local cyc = math.mod(t, d[3])
      e.name, e.icon, e.dur, e.ends, e.stacks, e.missing = d[1], "Interface\\Icons\\" .. d[2], d[3], t + (d[3] - math.mod(d[4] + cyc, d[3])), 0, nil
    end
    local e = fake[5] or {}
    fake[5] = e
    e.name, e.icon, e.missing, e.ends, e.dur = "Insect Swarm", "Interface\\Icons\\Spell_Nature_InsectSwarm", true, nil, nil
    return fake
  end
  function TB.Test(secs) TB.testUntil = GetTime() + (secs or 20) end
  function TB.Testing()
    if TB.testUntil and GetTime() < TB.testUntil then return true end
    return pfUI.unlock and pfUI.unlock.IsShown and pfUI.unlock:IsShown() and true or nil
  end
  function TB.ApplyLayout()
    bar:SetAlpha(Num("tb_alpha", 1))
    TB.dirty = true
  end
  function TB.ResetPosition()
    if C.position then C.position["pfDotTargetBar"] = nil end
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, -170)
    if UpdateMovable then UpdateMovable(bar) end
  end

  -- ten times a second while there is a target to read (and while testing / in layout mode)
  local next = 0
  local driver = CreateFrame("Frame", "pfDotTargetBarDriver", UIParent)
  driver:RegisterEvent("PLAYER_TARGET_CHANGED")
  driver:RegisterEvent("PLAYER_REGEN_DISABLED")
  driver:RegisterEvent("PLAYER_REGEN_ENABLED")
  driver:SetScript("OnEvent", function() next = 0 end)
  driver:SetScript("OnUpdate", function()
    local t = GetTime()
    if t < next and not TB.dirty then return end
    next = t + .1
    TB.dirty = nil
    if not On("tb_on") then bar:Hide() return end
    local list
    if TB.Testing() then
      list = TB.Fake(t)
    else
      if On("tb_combat") and not UnitAffectingCombat("player") then bar:Hide() return end
      list = TB.Collect(t)
    end
    if table.getn(list) == 0 then bar:Hide() return end
    TB.Layout(bar, list, t)
    bar:Show()
  end)
  TB.ApplyLayout()

  -- ---------------------------------------------------------------- the page: first under OctoDoTs

  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local ICON = "Interface\\Icons\\"
  local function Chk(p, label, desc, key) return W.Check(p, label, desc, function() return C.dots[key] == "1" end,
    function(v) C.dots[key] = v and "1" or "0" TB.ApplyLayout() end) end
  local function Sld(p, label, desc, min, max, step, key, fmt) return W.Slider(p, label, desc, min, max, step,
    function() return tonumber(C.dots[key]) or min end, function(v) C.dots[key] = tostring(v) TB.ApplyLayout() end, fmt) end
  local function Drop(p, label, desc, options, key) return W.Dropdown(p, label, desc, options,
    function() return C.dots[key] end, function(v) C.dots[key] = v TB.ApplyLayout() end) end

  -- the spell grid: click = track (green) / ignore (red) / nothing
  local function Picker(p)
    local row = W.Row(p, 40, 0, 4)
    row.cells = {}
    local function Paint()
      local spells = TB.Spells()
      local cw, size = 46, 36
      local cols = math.max(1, math.floor(((row:GetWidth() or 760) + 6) / cw))
      for _, c in ipairs(row.cells) do c:Hide() end
      for i, s in ipairs(spells) do
        local c = row.cells[i]
        if not c then
          c = CreateFrame("Button", nil, row)
          c:SetWidth(size)
          c:SetHeight(size)
          c.edge = c:CreateTexture(nil, "BACKGROUND")
          c.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
          c.edge:SetAllPoints(c)
          c.tex = c:CreateTexture(nil, "ARTWORK")
          c.tex:SetTexCoord(.08, .92, .08, .92)
          c.tex:SetPoint("TOPLEFT", c, "TOPLEFT", 2, -2)
          c.tex:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -2, 2)
          c.mark = c:CreateFontString(nil, "OVERLAY")
          c.mark:SetFont(Font(), 11, "OUTLINE")
          c.mark:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -1, 1)
          c:SetScript("OnClick", function() TB.Cycle(this.spell) Paint() end)
          c:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:SetText(this.spell, 1, 1, 1)
            local st = TB.State(this.spell)
            GameTooltip:AddLine(st == "track" and "|cff40d977Tracked|r - always on the bar (greyed when missing)"
              or st == "ignore" and "|cffff6060Ignored|r - never on the bar"
              or "Shown when it is up (with \"All of mine\")", 1, 1, 1, 1)
            GameTooltip:AddLine("Click: tracked > ignored > neither", .6, .62, .66)
            GameTooltip:Show()
          end)
          c:SetScript("OnLeave", function() GameTooltip:Hide() end)
          row.cells[i] = c
        end
        c.spell = s.name
        c.tex:SetTexture(s.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local st = TB.State(s.name)
        if st == "track" then
          c.edge:SetVertexColor(.25, .85, .47, 1) c.tex:SetVertexColor(1, 1, 1) c.mark:SetText("|cff40d977+|r")
        elseif st == "ignore" then
          c.edge:SetVertexColor(.9, .25, .25, 1) c.tex:SetVertexColor(.4, .4, .4) c.mark:SetText("|cffff6060x|r")
        else
          c.edge:SetVertexColor(.2, .21, .24, 1) c.tex:SetVertexColor(1, 1, 1) c.mark:SetText("")
        end
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", row, "TOPLEFT", math.mod(i - 1, cols) * cw + 4, -math.floor((i - 1) / cols) * cw - 2)
        c:Show()
      end
      row:SetHeight(math.max(40, math.ceil(table.getn(spells) / cols) * cw + 4))
      if p.body then W.Measure(p) end
    end
    row.Paint = Paint
    TB.picker = row
    Paint()
  end

  local function Page(p)
    W.Heading(p, "Target bar", { on = { function() return C.dots.tb_on == "1" end,
      function(v) C.dots.tb_on = v and "1" or "0" TB.ApplyLayout() end, "The target bar on or off." },
      about = "A row of icons: your own debuffs on your target - DoTs and bleeds - with the time left and a shade that "
        .. "drains as they run out. Pick below which to always track and which to ignore. Move it in layout mode." })
    W.Pin(p, "Preview", "Made-up debuffs drawn by the real bar code with your settings; the grey one is a tracked debuff "
      .. "that is missing. Click this bar to fold it away.", function(pp)
      local box = (W.ZoomBox or W.Box)(pp, 70)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetFrameStrata("FULLSCREEN")
      holder:SetPoint("CENTER", box, "CENTER", 0, 0)
      holder:SetWidth(200)
      holder:SetHeight(34)
      holder:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + .1
        local t = GetTime()
        TB.Layout(this, TB.Fake(t), t)
        local n = 0
        for _, f in ipairs(this.icons) do if f:IsShown() then n = n + 1 end end
        local size, gap = Num("tb_size", 34), Num("tb_gap", 3)
        this:SetWidth(math.max(size, n * (size + gap) - gap))
        local grow = S().tb_grow or "RIGHT"
        for i = 1, n do
          local f = this.icons[i]
          f:ClearAllPoints()
          f:SetPoint("TOPLEFT", this, "TOPLEFT", (grow == "LEFT" and (n - i) or (i - 1)) * (size + gap), 0)
        end
      end)
      W.Buttons(pp, {
        { "Test on my bar (20 s)", function() if TB.testUntil and GetTime() < TB.testUntil then TB.testUntil = 0 else TB.Test(20) end TB.dirty = true end,
          nil, "Shows the bar with the made-up debuffs for 20 seconds, to place it.", on = function() return TB.testUntil and GetTime() < TB.testUntil end },
        { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, nil, "Drag the bar where you want it." },
        { "Reset position", function() TB.ResetPosition() end, nil, "Under your character again." },
      })
    end)

    W.Card(p, "Your spells", { icon = ICON .. "Ability_Druid_Disembowel", tip = "Your class's debuffs, and any you have put on "
      .. "a target since. Click an icon: green = always track, red = ignore, none = shown when up." })
    W.Note(p, "|cff40d977Green|r always on the bar (grey while missing)   |cffff6060Red|r never   |cff8a8f99Plain|r shown while up")
    Picker(p)
    W.Edit(p, "Add a spell", "A debuff by name (its icon shows once you have used it), then Enter. It is tracked.",
      function() return "" end, function(v) if v and v ~= "" then List()[Low(v)] = "track" if TB.picker then TB.picker.Paint() end end end, 240)

    W.Card(p, "What it shows", { icon = ICON .. "INV_Misc_Spyglass_02" })
    Drop(p, "Shows", "All of mine: every debuff you put on the target, except ignored ones. Only tracked: just the green ones.",
      { { key = "all", label = "All of mine (minus ignored)" }, { key = "list", label = "Only tracked ones" } }, "tb_mode")
    Drop(p, "Order", nil, { { key = "time", label = "Running out first" }, { key = "name", label = "By name" } }, "tb_order")
    Chk(p, "Tracked ones while missing", "Grey icons for tracked debuffs that are not on the target - what to put on next.", "tb_missing")
    Chk(p, "Only in combat", nil, "tb_combat")

    W.Card(p, "Look", { icon = ICON .. "INV_Misc_Gem_Pearl_04" })
    Sld(p, "Icon size", nil, 16, 64, 1, "tb_size", function(v) return v .. " px" end)
    Sld(p, "Gap", nil, 0, 12, 1, "tb_gap", function(v) return v .. " px" end)
    Drop(p, "Grows", nil, { { key = "RIGHT", label = "To the right" }, { key = "LEFT", label = "To the left" },
      { key = "CENTER", label = "From the middle" } }, "tb_grow")
    Chk(p, "Time left on the icon", nil, "tb_timer")
    Chk(p, "Shade drains as it runs out", nil, "tb_drain")
    Sld(p, "Red under", "The time text and edge turn red when this little is left.", 0, 10, 1, "tb_warn", function(v) return v .. " s" end)
    Sld(p, "Opacity", nil, .2, 1, .05, "tb_alpha", function(v) return math.floor(v * 100 + .5) .. "%" end)
  end
  O:AddPage("OctoDoTs", "dottarget", "Target bar", Page)
end)
