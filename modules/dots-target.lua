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

  -- ---------------------------------------------------------------- per spell: glow, numbers, animation

  -- (18 Nov 2026, user: "add right click options here the same as we have in cooldown manager with some options for
  -- cooldown glows and numbers and animations for each spell nothing to bulky just some nice clean options").
  -- C.dots.tb_spell[lower name] = { glow, when, color, timer, tsize, tpos, low, put } ; TB.Get falls back to TB.SPEC's def.
  TB.SPEC = {
    { key = "glow", label = "Glow", def = "off", opts = {
      { key = "off", label = "Off" }, { key = "border", label = "Bright border" }, { key = "soft", label = "Soft outer glow" },
      { key = "pulse", label = "Pulsing fill" }, { key = "blink", label = "Blinking border" } } },
    { key = "when", label = "Glow when", def = "low", opts = {
      { key = "low", label = "Running out (red time)" }, { key = "always", label = "Always while up" },
      { key = "missing", label = "Missing (tracked)" } } },
    { key = "color", label = "Glow colour", def = "gold", opts = {
      { key = "gold", label = "Gold" }, { key = "red", label = "Red" }, { key = "white", label = "White" },
      { key = "green", label = "Green" }, { key = "blue", label = "Blue" }, { key = "purple", label = "Purple" },
      { key = "class", label = "My class colour" } } },
    { key = "timer", label = "Time left", def = "", opts = {
      { key = "", label = "As the bar (Look card)" }, { key = "1", label = "Shown" }, { key = "0", label = "Hidden" } } },
    { key = "tsize", label = "Number size", def = "normal", opts = {
      { key = "small", label = "Small" }, { key = "normal", label = "Normal" }, { key = "big", label = "Big" } } },
    { key = "tpos", label = "Number place", def = "bottom", opts = {
      { key = "bottom", label = "Bottom" }, { key = "center", label = "Middle" }, { key = "top", label = "Top" } } },
    { key = "low", label = "Animation: running out", def = "none", opts = {
      { key = "none", label = "None" }, { key = "pulse", label = "Pulse" }, { key = "bounce", label = "Bounce" },
      { key = "shake", label = "Shake" }, { key = "blink", label = "Blink" } } },
    { key = "put", label = "Animation: put on / renewed", def = "none", opts = {
      { key = "none", label = "None" }, { key = "pop", label = "Pop" }, { key = "flash", label = "White flash" } } },
  }
  TB.COLORS = { gold = { 1, .82, .2 }, red = { 1, .25, .2 }, white = { 1, 1, 1 }, green = { .3, 1, .4 },
                blue = { .3, .65, 1 }, purple = { .75, .4, 1 } }
  local function SpellOpts(name, make)
    if type(C.dots.tb_spell) ~= "table" then C.dots.tb_spell = {} end
    local k = Low(name)
    local o = C.dots.tb_spell[k]
    if not o and make then o = {} C.dots.tb_spell[k] = o end
    return o
  end
  function TB.Get(name, key)
    local o = SpellOpts(name)
    if o and o[key] ~= nil then return o[key] end
    for _, s in ipairs(TB.SPEC) do if s.key == key then return s.def end end
  end
  function TB.Set(name, key, v)
    local o = SpellOpts(name, true)
    local def
    for _, s in ipairs(TB.SPEC) do if s.key == key then def = s.def end end
    if v == def then o[key] = nil else o[key] = v end
    if not next(o) then C.dots.tb_spell[Low(name)] = nil end
    TB.dirty = true
  end
  function TB.ResetSpell(name)
    if type(C.dots.tb_spell) == "table" then C.dots.tb_spell[Low(name)] = nil end
    TB.dirty = true
  end
  function TB.Custom(name) return SpellOpts(name) ~= nil end

  -- ---------------------------------------------------------------- the bar

  local MAX = 12
  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local function Font() return pfUI.font_unit or pfUI.font_default or STANDARD_TEXT_FONT end
  local function NewIcon(parent)
    local f = CreateFrame("Button", nil, parent)
    f:EnableMouse(false)
    f.edge = f:CreateTexture(nil, "BACKGROUND")
    f.edge:SetTexture(WHITE)
    f.edge:SetAllPoints(f)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetTexCoord(.08, .92, .08, .92)
    f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    -- a dark shade over the part of the time already gone (drains from the top)
    f.shade = f:CreateTexture(nil, "OVERLAY")
    f.shade:SetTexture(WHITE)
    f.shade:SetVertexColor(0, 0, 0, .55)
    f.shade:SetPoint("TOPLEFT", f.tex, "TOPLEFT", 0, 0)
    f.shade:SetPoint("TOPRIGHT", f.tex, "TOPRIGHT", 0, 0)
    -- glows: a soft outer glow, a bright border, a pulsing fill; a white flash for "put on"
    f.glow = CreateFrame("Frame", nil, f)
    f.glow:SetPoint("TOPLEFT", f, "TOPLEFT", -5, 5)
    f.glow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 5, -5)
    f.glow:SetBackdrop({ edgeFile = pfUI.media and pfUI.media["img:glow"] or WHITE, edgeSize = 7 })
    f.glow:Hide()
    f.rim = CreateFrame("Frame", nil, f)
    f.rim:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
    f.rim:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
    f.rim:SetFrameLevel(f:GetFrameLevel() + 3)
    f.rim:SetBackdrop({ edgeFile = WHITE, edgeSize = 2 })
    f.rim:Hide()
    f.over = CreateFrame("Frame", nil, f)
    f.over:SetAllPoints(f)
    f.over:SetFrameLevel(f:GetFrameLevel() + 4)
    f.fill = f.over:CreateTexture(nil, "ARTWORK")
    f.fill:SetAllPoints(f.tex)
    f.fill:SetTexture(WHITE)
    f.fill:SetBlendMode("ADD")
    f.fill:Hide()
    f.white = f.over:CreateTexture(nil, "OVERLAY")
    f.white:SetAllPoints(f.tex)
    f.white:SetTexture(WHITE)
    f.white:SetBlendMode("ADD")
    f.white:Hide()
    f.time = f.over:CreateFontString(nil, "OVERLAY")
    f.stack = f.over:CreateFontString(nil, "OVERLAY")
    f.stack:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -2)
    -- glows and animations move every frame only while one runs
    f:SetScript("OnUpdate", function() if this.busy then TB.Animate(this, GetTime()) end end)
    return f
  end
  -- one frame of glow / animation
  function TB.Animate(f, now)
    local style, c = f.glowStyle, f.glowColor or TB.COLORS.gold
    local wave = math.abs(math.sin(now * 4))
    if style == "soft" then f.glow:SetBackdropBorderColor(c[1], c[2], c[3], .45 + .55 * wave) f.glow:Show() else f.glow:Hide() end
    if style == "border" then f.rim:SetBackdropBorderColor(c[1], c[2], c[3], 1) f.rim:Show()
    elseif style == "blink" then f.rim:SetBackdropBorderColor(c[1], c[2], c[3], math.mod(now * 3, 1) < .5 and 1 or 0) f.rim:Show()
    else f.rim:Hide() end
    if style == "pulse" then f.fill:SetVertexColor(c[1], c[2], c[3], .12 + .33 * wave) f.fill:Show() else f.fill:Hide() end
    -- the icon itself: insets of the picture move (the frame stays where the bar put it)
    local grow, dx, dy, alpha, white = 0, 0, 0, 1, 0
    local loop = f.lowAnim
    if loop == "pulse" then grow = 2 * math.sin(now * 7)
    elseif loop == "bounce" then dy = math.abs(math.sin(now * 7)) * 4
    elseif loop == "shake" then dx = math.sin(now * 45) * 1.6
    elseif loop == "blink" then alpha = math.mod(now * 2.5, 1) < .5 and 1 or .3 end
    if f.putAt and now - f.putAt < .45 then
      local k = (now - f.putAt) / .45
      if f.putAnim == "pop" then grow = grow + 6 * (1 - k) elseif f.putAnim == "flash" then white = 1 - k end
    end
    if grow ~= 0 or dx ~= 0 or dy ~= 0 or f.moved then
      f.tex:ClearAllPoints()
      f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", 1 - grow + dx, -1 + grow + dy)
      f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1 + grow + dx, 1 - grow + dy)
      f.moved = grow ~= 0 or dx ~= 0 or dy ~= 0
    end
    f.tex:SetAlpha(alpha)
    if white > 0 then f.white:SetVertexColor(1, 1, 1, white * .8) f.white:Show() else f.white:Hide() end
    f.busy = (style and style ~= "off") or (loop and loop ~= "none") or (f.putAt and now - f.putAt < .45) or f.moved or false
    if not f.busy then f.tex:SetAlpha(1) end
  end
  -- draws one icon from an entry at time t
  function TB.PaintIcon(f, e, t)
    local size = Num("tb_size", 34)
    f:SetWidth(size)
    f:SetHeight(size)
    f.spell = e.name
    f.tex:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local tsize = TB.Get(e.name, "tsize")
    local mul = tsize == "small" and .28 or tsize == "big" and .46 or .36
    f.time:SetFont(Font(), math.max(8, math.floor(size * mul)), "OUTLINE")
    f.time:ClearAllPoints()
    local tpos = TB.Get(e.name, "tpos")
    if tpos == "center" then f.time:SetPoint("CENTER", f, "CENTER", 0, 0)
    elseif tpos == "top" then f.time:SetPoint("TOP", f, "TOP", 0, -2)
    else f.time:SetPoint("BOTTOM", f, "BOTTOM", 0, 2) end
    f.stack:SetFont(Font(), math.max(7, math.floor(size * .3)), "OUTLINE")
    f.stack:SetText((e.stacks or 0) > 1 and e.stacks or "")
    -- glow: its style, when, colour
    local glow, when = TB.Get(e.name, "glow"), TB.Get(e.name, "when")
    local col = TB.Get(e.name, "color")
    if col == "class" then
      local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[myClass]
      f.glowColor = cc and { cc.r, cc.g, cc.b } or TB.COLORS.gold
    else
      f.glowColor = TB.COLORS[col] or TB.COLORS.gold
    end
    local left = e.ends and (e.ends - t)
    local warn = Num("tb_warn", 3)
    local low = left and left <= warn
    local lit = false
    if e.missing then lit = when == "missing" elseif when == "always" then lit = true elseif when == "low" then lit = low and true or false end
    f.glowStyle = lit and glow or "off"
    f.lowAnim = (not e.missing and low) and TB.Get(e.name, "low") or "none"
    -- put on / renewed: its end jumped later than it was
    local put = TB.Get(e.name, "put")
    f.putAnim = put
    if put ~= "none" and not e.missing and e.ends and f.lastSpell == e.name and f.lastEnds and e.ends > f.lastEnds + .5 then f.putAt = t end
    if put ~= "none" and not e.missing and f.lastSpell ~= e.name then f.putAt = t end
    f.lastSpell, f.lastEnds = e.name, e.ends
    f.busy = true
    if e.missing then
      f.tex:SetVertexColor(.35, .35, .35)
      f.edge:SetVertexColor(.5, .15, .15, 1)
      f.shade:Hide()
      f.time:SetText("")
      return
    end
    f.tex:SetVertexColor(1, 1, 1)
    if low then f.edge:SetVertexColor(1, .2, .2, 1) else f.edge:SetVertexColor(0, 0, 0, 1) end
    local tset = TB.Get(e.name, "timer")
    local showTime = (tset == "1") or (tset ~= "0" and On("tb_timer"))
    if showTime and left then
      f.time:SetText(D.TimeText(left))
      if low then f.time:SetTextColor(1, .3, .3) else f.time:SetTextColor(1, 1, 1) end
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
    -- a box the size of the room you gave it (C.dots.tb_slots icons), so layout mode shows a tidy box and the icons never
    -- shift it about; more icons than that still show, past its edge
    local slots = math.max(1, math.min(MAX, Num("tb_slots", 6)))
    holder:SetWidth(math.max(size, slots * (size + gap) - gap))
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
    local list
    -- (18 Nov 2026, user: "there is no move box when unlocked") in layout mode / the test it shows sample icons even while
    -- switched off - it used to hide itself every tick, taking its layout-mode box with it
    if TB.Testing() then
      list = TB.Fake(t)
    elseif not On("tb_on") then
      bar:Hide()
      return
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

  -- (18 Nov 2026) an icon's right-click menu: each option of TB.SPEC with its choice now; a click opens its choices,
  -- a pick applies at once and the menu comes back for the next change. "Back to the usual" clears the spell's own.
  function TB.Menu(anchor, name)
    if not name then return end
    if W.CloseMenus then W.CloseMenus() end
    local opts = { { label = name, group = true } }
    for _, s in ipairs(TB.SPEC) do
      local cur, curLabel = TB.Get(name, s.key), ""
      for _, o in ipairs(s.opts) do if o.key == cur then curLabel = o.label end end
      table.insert(opts, { key = s.key, label = s.label .. ":  |cffffd24d" .. curLabel .. "|r" })
    end
    table.insert(opts, { key = "#reset", label = TB.Custom(name) and "|cffff8080Back to the usual|r" or "|cff8a8f99Back to the usual|r" })
    local m = W.Menu(anchor, opts, 280, function(key)
      if key == "#reset" then TB.ResetSpell(name) TB.Menu(anchor, name) return end
      local spec
      for _, s in ipairs(TB.SPEC) do if s.key == key then spec = s end end
      if not spec then return end
      local cur = TB.Get(name, key)
      local choices = { { label = spec.label .. " - " .. name, group = true } }
      for _, o in ipairs(spec.opts) do
        table.insert(choices, { key = o.key, label = (o.key == cur and "|cff40d977> |r" or "   ") .. o.label })
      end
      local sub = W.Menu(anchor, choices, 280, function(v)
        TB.Set(name, key, v)
        if TB.picker then TB.picker.Paint() end
        TB.Menu(anchor, name)
      end)
      if sub and sub.Show then sub:Show() end
    end)
    if m and m.Show then m:Show() end
    return m
  end

  -- the spell grid: click = track (green) / ignore (red) / nothing; right-click = its glow, numbers, animations
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
          c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
          c:SetScript("OnClick", function()
            if arg1 == "RightButton" then TB.Menu(this, this.spell) return end
            TB.Cycle(this.spell)
            Paint()
          end)
          c:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:SetText(this.spell, 1, 1, 1)
            local st = TB.State(this.spell)
            GameTooltip:AddLine(st == "track" and "|cff40d977Tracked|r - always on the bar (greyed when missing)"
              or st == "ignore" and "|cffff6060Ignored|r - never on the bar"
              or "Shown when it is up (with \"All of mine\")", 1, 1, 1, 1)
            GameTooltip:AddLine("Click: tracked > ignored > neither", .6, .62, .66)
            GameTooltip:AddLine("Right-click: glow, numbers, animations" .. (TB.Custom(this.spell) and " (|cffffd24dset|r)" or ""), .35, .7, 1)
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

  -- (18 Nov 2026, user: "Show both. Show Bars only. Show Single target bar only. for people who dont want the
  -- cursive bars up and vice versa") what OctoDoTs puts on the screen, at the top of this page
  function TB.Which()
    if C.dots.tb_on ~= "1" then return "bars" end
    return C.dots.which == "target" and "target" or "both"
  end
  function TB.SetWhich(v)
    C.dots.tb_on = (v == "bars") and "0" or "1"
    C.dots.which = (v == "target") and "target" or "both"
    TB.ApplyLayout()
    if pfUI.dots and pfUI.dots.Paint then pcall(pfUI.dots.Paint, GetTime()) end
  end

  local function Page(p)
    W.Heading(p, "Target bar", { on = { function() return C.dots.tb_on == "1" end,
      function(v) C.dots.tb_on = v and "1" or "0" TB.ApplyLayout() end, "The target bar on or off." },
      about = "A row of icons: your own debuffs on your target - DoTs and bleeds - with the time left and a shade that "
        .. "drains as they run out. Pick below which to always track and which to ignore. Move it in layout mode." })
    W.Card(p, "What shows", { tip = "OctoDoTs' two displays: the bars (every enemy with its debuffs, Cursive style) and "
      .. "this target bar (your debuffs on your target as icons)." })
    W.Dropdown(p, "Show", "Both: the bars and the target bar. Bars only: the target bar is off. "
      .. "Target bar only: the bars stay away (they still show in layout mode so they can be moved).",
      { { key = "both", label = "Both" }, { key = "bars", label = "Bars only" }, { key = "target", label = "Target bar only" } },
      TB.Which, function(v) TB.SetWhich(v) W.Refresh(p) end)
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
        -- the preview's icons take clicks: right-click = that spell's options
        for _, f in ipairs(this.icons) do
          if not f.menuReady then
            f.menuReady = true
            f:EnableMouse(true)
            f:RegisterForClicks("RightButtonUp", "LeftButtonUp")
            f:SetScript("OnClick", function() TB.Menu(this, this.spell) end)
            f:SetScript("OnEnter", function()
              GameTooltip:SetOwner(this, "ANCHOR_TOP")
              GameTooltip:SetText(this.spell or "", 1, 1, 1)
              GameTooltip:AddLine("Click or right-click: its glow, numbers and animations", .35, .7, 1)
              GameTooltip:Show()
            end)
            f:SetScript("OnLeave", function() GameTooltip:Hide() end)
          end
        end
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
    W.Note(p, "|cff40d977Green|r always on the bar (grey while missing)   |cffff6060Red|r never   |cff8a8f99Plain|r shown while up   |cff59b3ffRight-click|r glow, numbers, animations")
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
    Sld(p, "Room for icons", "How many icons wide the bar's box is (layout mode shows this box).", 1, 12, 1, "tb_slots",
      function(v) return v .. " icons" end)
    Drop(p, "Grows", nil, { { key = "RIGHT", label = "To the right" }, { key = "LEFT", label = "To the left" },
      { key = "CENTER", label = "From the middle" } }, "tb_grow")
    Chk(p, "Time left on the icon", nil, "tb_timer")
    Chk(p, "Shade drains as it runs out", nil, "tb_drain")
    Sld(p, "Red under", "The time text and edge turn red when this little is left.", 0, 10, 1, "tb_warn", function(v) return v .. " s" end)
    Sld(p, "Opacity", nil, .2, 1, .05, "tb_alpha", function(v) return math.floor(v * 100 + .5) .. "%" end)
  end
  -- (18 Nov 2026, user: "This box should be put after the general options") dots-options.lua adds it right after General
  TB.Page = Page
end)
