pfUI:RegisterModule("cdm", "vanilla", function ()
  -- pfUI Octo :: cooldown bars (15 Nov 2026; user, with EllesmereUI's Cooldown Manager:
  -- "yes build it ... auto fills neatly as your cds become available. If you level up and
  -- buy a new spell which gets a CD this will find its place on the bar"). EllesmereUI's
  -- licence reserves all rights: its feature list only, written fresh, no code or art.
  --
  -- C.cdm.bars = { { name, auto = "short" | "long" | "all" | "none", sort, size, spacing, per,
  --   vertical, center, alpha, show = always | combat | target | never, click, bg,
  --   spells = { { name, kind = "spell" | "item", auto, when = always | cd | ready,
  --   glow = off | flash | ready | active | both, desat, swipe, active, buff, thresh, sound } } } }
  -- (pfUI_config is per character, so the bars are too). Frames pfCDM1..6, layout mode boxes.
  --
  -- Filling: the spell book is read (highest rank of each name; passives left out); a spell
  -- whose tooltip names a cooldown - or that is seen on one longer than the global cooldown -
  -- goes on the first bar that takes its length (short = up to 3 min, long = more), in
  -- order of cooldown length while the bar is kept sorted. Removed ones stay away
  -- (C.cdm.removed). Spells you do not know (yet / any more) take no room.
  --
  -- An icon: ready, on cooldown (shade + time), or active (its buff is on you: green time
  -- and the buff's stacks - Inner Fire's charges). ClassicAPI C_UnitAuras for the buffs
  -- when it is there, else GetPlayerBuff + a tooltip scan for the name.
  local CDM = { book = {}, rt = {}, names = {}, buffs = {}, frames = {} }
  pfUI.cdm = CDM
  local function S() return C.cdm end
  local function Num(v, d) return tonumber(v) or d end
  local function Lower(s) return string.lower(string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
  CDM.Lower = Lower
  CDM.MAXBARS, CDM.SHORT, CDM.GCD = 6, 180, 1.5
  CDM.AUTO = { { key = "short", label = "Cooldowns up to 3 minutes" }, { key = "long", label = "Cooldowns over 3 minutes" },
               { key = "all", label = "Every cooldown" }, { key = "none", label = "Nothing (only what I add)" } }
  CDM.WHEN = { { key = "always", label = "Always" }, { key = "cd", label = "Only while on cooldown or active" },
               { key = "ready", label = "Only when it is ready" } }
  CDM.GLOWS = { { key = "off", label = "No glow" }, { key = "flash", label = "A few seconds when it comes ready" },
                { key = "ready", label = "The whole time it is ready" }, { key = "active", label = "While its effect is on you" },
                { key = "both", label = "When it comes ready, and while active" } }
  CDM.SHOW = { { key = "always", label = "Always" }, { key = "combat", label = "In combat" },
               { key = "target", label = "With a target or in combat" }, { key = "never", label = "Never" } }
  CDM.SOUNDS = { { key = "", label = "No sound" }, { key = "ping", label = "Map ping" }, { key = "bell", label = "Bell" },
                 { key = "raidwarning", label = "Raid warning" }, { key = "ready", label = "Ready check" } }
  function CDM.PlaySound(key)
    if key == "ping" then PlaySoundFile("Sound\\Interface\\MapPing.wav")
    elseif key == "bell" then PlaySoundFile("Sound\\Spells\\ShaysBell.wav")
    elseif key == "raidwarning" then PlaySound("RaidWarning")
    elseif key == "ready" then PlaySound("ReadyCheck") end
  end

  -- ---------------------------------------------------------------- bars and entries

  function CDM.NewBar(name, auto)
    return { name = name, auto = auto or "none", sort = "1", size = "36", spacing = "3", per = "12", vertical = "0",
      center = "1", alpha = "1", show = "always", click = "0", bg = "0", spells = {} }
  end
  function CDM.Bars()
    local s = S()
    if type(s.bars) ~= "table" then s.bars = {} end
    if table.getn(s.bars) == 0 then
      table.insert(s.bars, CDM.NewBar("Cooldowns", "short"))
      table.insert(s.bars, CDM.NewBar("Utility", "long"))
    end
    for _, b in ipairs(s.bars) do
      if type(b.spells) ~= "table" then b.spells = {} end
    end
    if type(s.removed) ~= "table" then s.removed = {} end
    if type(s.known) ~= "table" then s.known = {} end
    return s.bars
  end
  -- where a name is: bar index, entry index, entry
  function CDM.Where(name)
    local k = Lower(name)
    for bi, b in ipairs(CDM.Bars()) do
      for i, e in ipairs(b.spells) do
        if Lower(e.name) == k then return bi, i, e end
      end
    end
  end
  function CDM.Add(bi, name, kind, auto)
    local bar = CDM.Bars()[bi]
    if not bar or not name or name == "" or CDM.Where(name) then return nil end
    local e = { name = name, kind = kind or "spell", auto = auto and "1" or nil }
    table.insert(bar.spells, e)
    S().removed[Lower(name)] = nil
    if bar.sort == "1" then CDM.Sort(bar) end
    return e
  end
  function CDM.Remove(name)
    local bi, i, e = CDM.Where(name)
    if not bi then return false end
    table.remove(CDM.Bars()[bi].spells, i)
    -- (a spell that fills in by itself stays away until it is added by hand)
    if e.kind ~= "item" then S().removed[Lower(name)] = true end
    return true
  end
  function CDM.MoveTo(name, to)
    local bi, i, e = CDM.Where(name)
    local bars = CDM.Bars()
    if not bi or not bars[to] or bi == to then return false end
    table.remove(bars[bi].spells, i)
    table.insert(bars[to].spells, e)
    if bars[to].sort == "1" then CDM.Sort(bars[to]) end
    return true
  end
  -- one place left (-1) or right (1); the bar is yours to order from then on
  function CDM.Shift(name, by)
    local bi, i = CDM.Where(name)
    if not bi then return false end
    local list = CDM.Bars()[bi].spells
    local j = i + by
    if j < 1 or j > table.getn(list) then return false end
    list[i], list[j] = list[j], list[i]
    CDM.Bars()[bi].sort = "0"
    return true
  end
  function CDM.BaseCD(name)
    local k = Lower(name)
    local b = CDM.book[k]
    return (b and b.cd) or S().known[k]
  end
  -- by cooldown length, then name; ones with no known length keep their order at the end
  function CDM.Sort(bar)
    local list = bar.spells
    for i, e in ipairs(list) do e._i = i end
    table.sort(list, function(a, b)
      local ca, cb = CDM.BaseCD(a.name), CDM.BaseCD(b.name)
      if ca and cb then
        if ca ~= cb then return ca < cb end
        return a.name < b.name
      end
      if ca or cb then return ca ~= nil end
      return a._i < b._i
    end)
    for _, e in ipairs(list) do e._i = nil end
  end

  -- ---------------------------------------------------------------- the spell book

  local scanner
  local function Scanner()
    if scanner then return scanner end
    if libtipscan and libtipscan.GetScanner then scanner = libtipscan:GetScanner("cdm") end
    return scanner
  end
  local function Pat(global, fallback)
    local text = rawget(_G, global)
    if type(text) ~= "string" or not string.find(text, "%%") then text = fallback end
    text = string.gsub(text, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    text = string.gsub(text, "%%%%%%?%.?%d*[dgsf]", "([%%d%%.,]+)")
    return text
  end
  CDM.CDPAT = {
    { Pat("SPELL_RECAST_TIME_SEC", "%.3g sec cooldown"), 1 },
    { Pat("SPELL_RECAST_TIME_MIN", "%.3g min cooldown"), 60 },
    { "([%d%.,]+) hours? cooldown", 3600 }, { "([%d%.,]+) hr cooldown", 3600 },
  }
  -- "5 min cooldown" -> 300
  function CDM.ParseCD(text)
    if type(text) ~= "string" then return nil end
    for _, p in ipairs(CDM.CDPAT) do
      local _, _, n = string.find(text, p[1])
      n = n and tonumber((string.gsub(n, ",", ".")))
      if n then return n * p[2] end
    end
  end
  local function TipCD(index)
    local sc = Scanner()
    if not sc or not sc.SetSpell then return nil end
    sc:SetSpell(index, "spell")
    local lines = sc.Text and sc:Text() or {}
    for _, l in pairs(lines) do
      if type(l) == "table" then
        local cd = CDM.ParseCD(l[2]) or CDM.ParseCD(l[1])
        if cd then return cd end
      end
    end
  end
  -- name (lower) -> { name, index (highest rank), tex, cd (seconds, when the tooltip says) }
  function CDM.ScanBook()
    local book = {}
    if not GetSpellName then CDM.book = book return book end
    for i = 1, 400 do
      local name = GetSpellName(i, "spell")
      if not name then break end
      if not (IsSpellPassive and IsSpellPassive(i, "spell")) then
        local k = Lower(name)
        book[k] = { name = name, index = i, tex = GetSpellTexture and GetSpellTexture(i, "spell") }
      end
    end
    for k, b in pairs(book) do
      local ok, cd = pcall(TipCD, b.index)
      b.cd = (ok and cd) or S().known[k]
    end
    CDM.book = book
    return book
  end
  -- spells seen on a cooldown the tooltip did not name are learnt (once a second)
  function CDM.LearnCDs()
    if not GetSpellCooldown then return false end
    local new = false
    for k, b in pairs(CDM.book) do
      if not b.cd then
        local start, dur = GetSpellCooldown(b.index, "spell")
        if start and start > 0 and dur and dur > CDM.GCD + .1 then
          b.cd = dur
          S().known[k] = dur
          new = true
        end
      end
    end
    return new
  end
  local function Takes(bar, cd)
    if bar.auto == "all" then return true end
    if bar.auto == "short" then return cd <= CDM.SHORT end
    if bar.auto == "long" then return cd > CDM.SHORT end
    return false
  end
  -- every spell with a cooldown that is on no bar yet finds its bar and its place
  function CDM.Fill()
    local bars = CDM.Bars()
    local added = 0
    local names = {}
    for k, b in pairs(CDM.book) do
      if b.cd and b.cd > CDM.GCD + .1 and not S().removed[k] then table.insert(names, k) end
    end
    table.sort(names)
    for _, k in ipairs(names) do
      local b = CDM.book[k]
      if not CDM.Where(b.name) then
        for bi, bar in ipairs(bars) do
          if Takes(bar, b.cd) then
            if CDM.Add(bi, b.name, "spell", true) then added = added + 1 end
            break
          end
        end
      end
    end
    return added
  end
  function CDM.Rescan()
    CDM.ScanBook()
    local n = CDM.Fill()
    CDM.dirty = true
    return n
  end

  -- ---------------------------------------------------------------- buffs and items

  -- name (lower) -> { ends (GetTime, or nil = no timer), count, tex }
  function CDM.ReadBuffs()
    local out = {}
    local now = GetTime()
    local ui = C_UnitAuras and C_UnitAuras.UnitAura
    if ui then
      local good = true
      for i = 1, 40 do
        local ok, name, tex, count, _, _, expires = pcall(ui, "player", i, "HELPFUL")
        if not ok then good = false break end
        if not name then break end
        out[Lower(name)] = { ends = (type(expires) == "number" and expires > 0) and expires or nil,
          count = tonumber(count) or 0, tex = type(tex) == "string" and tex or nil }
      end
      if good then CDM.buffs = out return out end
      out = {}
    end
    if GetPlayerBuff then
      for i = 0, 31 do
        local bid = GetPlayerBuff(i, "HELPFUL")
        if type(bid) ~= "number" or bid < 0 then break end
        local tex = GetPlayerBuffTexture and GetPlayerBuffTexture(bid)
        local key = bid .. ":" .. tostring(tex)
        local name = CDM.names[key]
        if name == nil then
          local sc = Scanner()
          if sc and sc.SetPlayerBuff then
            sc:SetPlayerBuff(bid)
            name = sc:Line(1)
          end
          CDM.names[key] = name or false
        end
        if name then
          local left = GetPlayerBuffTimeLeft and GetPlayerBuffTimeLeft(bid)
          out[Lower(name)] = { ends = (type(left) == "number" and left > 0) and (now + left) or nil,
            count = (GetPlayerBuffApplications and tonumber(GetPlayerBuffApplications(bid))) or 0, tex = tex }
        end
      end
    end
    CDM.buffs = out
    return out
  end

  local function LinkName(link)
    if type(link) ~= "string" then return nil end
    local _, _, name = string.find(link, "%[(.-)%]")
    return name
  end
  -- name (lower) -> { inv } or { bag, slot }, count, tex: worn first, then bags
  function CDM.Items()
    if CDM.items and not CDM.itemsDirty then return CDM.items end
    local out = {}
    for inv = 0, 19 do
      local name = LinkName(GetInventoryItemLink and GetInventoryItemLink("player", inv))
      if name then out[Lower(name)] = { name = name, inv = inv, tex = GetInventoryItemTexture("player", inv), count = 1 } end
    end
    for bag = 0, 4 do
      for slot = 1, (GetContainerNumSlots and GetContainerNumSlots(bag) or 0) do
        local name = LinkName(GetContainerItemLink(bag, slot))
        if name then
          local k = Lower(name)
          local tex, count = GetContainerItemInfo(bag, slot)
          if out[k] and out[k].bag then
            out[k].count = out[k].count + (tonumber(count) or 1)
          elseif not out[k] then
            out[k] = { name = name, bag = bag, slot = slot, tex = tex, count = tonumber(count) or 1 }
          end
        end
      end
    end
    CDM.items, CDM.itemsDirty = out, nil
    return out
  end

  -- ---------------------------------------------------------------- an entry's state

  -- { known, tex, start, dur, left (cooldown), active, aleft, count, state = ready | cd | active }
  function CDM.State(e, now)
    local st = { known = false }
    local k = Lower(e.name)
    local start, dur
    if e.kind == "item" then
      local it = CDM.Items()[k]
      if it then
        st.known, st.tex = true, it.tex
        if it.inv then start, dur = GetInventoryItemCooldown("player", it.inv)
        else start, dur = GetContainerItemCooldown(it.bag, it.slot) end
        if it.bag and it.count > 1 then st.count = it.count end
      end
    else
      local b = CDM.book[k]
      if b then
        st.known, st.tex = true, b.tex
        if GetSpellCooldown then start, dur = GetSpellCooldown(b.index, "spell") end
      end
    end
    if start and dur and start > 0 and dur > CDM.GCD + .1 then
      st.start, st.dur, st.left = start, dur, math.max(0, start + dur - now)
      if st.left <= 0 then st.start, st.dur, st.left = nil, nil, nil end
    end
    if e.active ~= "0" then
      local a = CDM.buffs[(e.buff and e.buff ~= "") and Lower(e.buff) or k]
      if a then
        st.active = true
        st.aleft = a.ends and math.max(0, a.ends - now) or nil
        if a.count and a.count > 1 then st.count = a.count end
        if not st.tex then st.tex = a.tex end
      end
    end
    st.state = st.active and "active" or (st.left and "cd" or "ready")
    return st
  end
  -- is it drawn now (its "show" choice)
  function CDM.Wanted(e, st)
    if not st.known then return false end
    if e.when == "cd" then return st.state ~= "ready" end
    if e.when == "ready" then return st.state == "ready" end
    return true
  end
  function CDM.Time(left)
    if not left then return "" end
    if left >= 3600 then return math.ceil(left / 3600) .. "h" end
    if left >= 60 then return math.ceil(left / 60) .. "m" end
    if left >= 10 then return tostring(math.floor(left + .5)) end
    return string.format("%.1f", left)
  end

  -- ---------------------------------------------------------------- icons

  local WHITE = "Interface\\Buttons\\WHITE8X8"
  function CDM.Color(key, r, g, b, a)
    local _, _, cr, cg, cb, ca = string.find(S()[key] or "", "([%d%.]+),([%d%.]+),([%d%.]+),?([%d%.]*)")
    return tonumber(cr) or r, tonumber(cg) or g, tonumber(cb) or b, tonumber(ca) or a or 1
  end
  -- one icon (on a bar, or in the options preview: preview = true)
  function CDM.NewButton(parent, preview)
    local b = CreateFrame("Button", nil, parent)
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    b:SetBackdropColor(.04, .04, .05, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    -- the cooldown's shade: comes down from the top and shrinks away
    b.shade = b:CreateTexture(nil, "OVERLAY")
    b.shade:SetTexture(0, 0, 0, .68)
    b.shade:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 1)
    b.shade:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.shade:Hide()
    b.over = CreateFrame("Frame", nil, b)
    b.over:SetAllPoints(b)
    b.over:SetFrameLevel(b:GetFrameLevel() + 2)
    b.time = b.over:CreateFontString(nil, "OVERLAY")
    b.time:SetFont(pfUI.font_default, 13, "OUTLINE")
    b.time:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.count = b.over:CreateFontString(nil, "OVERLAY")
    b.count:SetFont(pfUI.font_default, 11, "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.glow = CreateFrame("Frame", nil, b)
    b.glow:SetPoint("TOPLEFT", b, "TOPLEFT", -5, 5)
    b.glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 5, -5)
    b.glow:SetBackdrop({ edgeFile = pfUI.media and pfUI.media["img:glow"] or WHITE, edgeSize = 7 })
    b.glow:Hide()
    if preview then return b end
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function()
      if arg1 == "RightButton" then CDM.OpenOptions() return end
      if this.e then CDM.Use(this.e) end
    end)
    b:SetScript("OnEnter", function()
      local e = this.e
      if not e then return end
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      local bk = CDM.book[Lower(e.name)]
      if e.kind ~= "item" and bk and GameTooltip.SetSpell then GameTooltip:SetSpell(bk.index, "spell")
      else GameTooltip:AddLine(e.name) end
      GameTooltip:AddLine("Click: use it.  Right-click: options.", .35, .7, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end
  function CDM.Use(e)
    if e.kind == "item" then
      local it = CDM.Items()[Lower(e.name)]
      if not it then return end
      if it.inv then UseInventoryItem(it.inv) else UseContainerItem(it.bag, it.slot) end
    else
      CastSpellByName(e.name)
    end
  end
  -- paint a button for an entry in a state; flash = glowing because it just came ready
  function CDM.Paint(b, e, st, size, flash, now)
    b.e, b.state = e, st.state
    local zoom = Num(S().zoom, .08)
    b.icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
    b.icon:SetTexture((e.icon and e.icon ~= "" and e.icon) or st.tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    local r, g, bl, a = CDM.Color("bordercolor", .2, .2, .24, 1)
    if st.state == "active" then r, g, bl, a = CDM.Color("activecolor", .3, .9, .4, 1) end
    b:SetBackdropBorderColor(r, g, bl, a)
    local oncd = st.state == "cd"
    if b.icon.SetDesaturated then b.icon:SetDesaturated(oncd and e.desat ~= "0") end
    if oncd and e.swipe ~= "0" and st.dur and st.dur > 0 then
      b.shade:SetHeight(math.max(1, (size - 2) * math.min(1, st.left / st.dur)))
      b.shade:Show()
    else
      b.shade:Hide()
    end
    local fsize = math.max(8, math.floor(size * Num(S().textsize, .36) + .5))
    if b.fsize ~= fsize then
      b.fsize = fsize
      b.time:SetFont(pfUI.font_default, fsize, "OUTLINE")
      b.count:SetFont(pfUI.font_default, math.max(8, fsize - 2), "OUTLINE")
    end
    if S().timers == "0" then
      b.time:SetText("")
    elseif st.state == "active" then
      b.time:SetText(CDM.Time(st.aleft))
      b.time:SetTextColor(CDM.Color("activecolor", .3, .9, .4, 1))
    elseif oncd then
      b.time:SetText(CDM.Time(st.left))
      local th = Num(e.thresh, 3)
      if th > 0 and st.left <= th then b.time:SetTextColor(1, .25, .25) else b.time:SetTextColor(1, 1, 1) end
    else
      b.time:SetText("")
    end
    b.count:SetText(st.count and tostring(st.count) or "")
    local glow = e.glow or "off"
    local lit = (st.state == "active" and (glow == "active" or glow == "both"))
      or (st.state == "ready" and (glow == "ready" or (flash and (glow == "flash" or glow == "both"))))
    if lit then
      local gr, gg, gb = CDM.Color("glowcolor", 1, .82, .2, 1)
      b.glow:SetBackdropBorderColor(gr, gg, gb, .45 + .55 * math.abs(math.sin((now or GetTime()) * 4)))
      b.glow:Show()
    else
      b.glow:Hide()
    end
  end

  -- place the shown icons; the frame keeps the size of `room` icons so its box does not jump
  function CDM.Layout(frame, buttons, bar, rows, room, make, now)
    local size, gap = Num(bar.size, 36), Num(bar.spacing, 3)
    local per = math.max(1, Num(bar.per, 12))
    local vertical = bar.vertical == "1"
    local n = table.getn(rows)
    room = math.max(room or n, n, 1)
    local cols = math.min(room, per)
    local lines = math.max(1, math.ceil(room / per))
    local w, h = cols * size + (cols - 1) * gap, lines * size + (lines - 1) * gap
    for ii = 1, n do
      local i = ii
      local b = buttons[i]
      if not b then
        b = make()
        buttons[i] = b
      end
      local line = math.floor((i - 1) / per)
      local pos = i - 1 - line * per
      local inline = math.min(per, n - line * per)
      local x, y = pos * (size + gap), line * (size + gap)
      if bar.center ~= "0" then x = x + (w - (inline * size + (inline - 1) * gap)) / 2 end
      if vertical then x, y = y, x end
      b:SetWidth(size)
      b:SetHeight(size)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
      CDM.Paint(b, rows[i].e, rows[i].st, size, rows[i].flash, now)
      b:Show()
    end
    for i = n + 1, table.getn(buttons) do buttons[i]:Hide() end
    if vertical then w, h = h, w end
    frame:SetWidth(w)
    frame:SetHeight(h)
    return n
  end

  -- the rows a bar shows now: { e, st, flash }, and how many of its entries you know
  function CDM.Rows(bi, now)
    local bar = CDM.Bars()[bi]
    local rows, known = {}, 0
    for _, e in ipairs(bar and bar.spells or {}) do
      local st = CDM.State(e, now)
      if st.known then
        known = known + 1
        local key = Lower(e.name)
        local rt = CDM.rt[key]
        if not rt then rt = {} CDM.rt[key] = rt end
        if rt.was == "cd" and st.state ~= "cd" and (rt.dur or 0) >= 2 then
          rt.flash = now + 4
          if e.sound and e.sound ~= "" and now >= (CDM.quietUntil or 0) then CDM.PlaySound(e.sound) end
        end
        rt.was, rt.dur = st.state, st.dur or rt.dur
        if st.state == "cd" then rt.flash = nil end
        if CDM.Wanted(e, st) then
          table.insert(rows, { e = e, st = st, flash = rt.flash and rt.flash > now })
        end
      end
    end
    return rows, known
  end
  -- made-up states for layout mode and the options preview
  function CDM.Samples(bi, now)
    local bar = CDM.Bars()[bi]
    local rows = {}
    local kinds = { "ready", "cd", "active", "ready", "cd" }
    for i, e in ipairs(bar and bar.spells or {}) do
      local st = CDM.State(e, now)
      if st.known then
        local kind = kinds[math.mod(i - 1, 5) + 1]
        local span = 20 + i * 7
        local left = span - math.mod(now + i * 5, span)
        local s = { known = true, tex = st.tex, state = kind, count = st.count }
        if kind == "cd" then s.left, s.dur = left, span elseif kind == "active" then s.aleft = left end
        table.insert(rows, { e = e, st = s, flash = kind == "ready" and math.mod(i, 2) == 0 })
      end
    end
    if table.getn(rows) == 0 then
      local tex = { "Spell_Holy_PowerInfusion", "Spell_Frost_FrostNova", "Spell_Nature_Lightning", "INV_Misc_PocketWatch_01" }
      for i = 1, 4 do
        local kind = kinds[i]
        local s = { known = true, tex = "Interface\\Icons\\" .. tex[i], state = kind }
        if kind == "cd" then s.left, s.dur = 12, 30 elseif kind == "active" then s.aleft = 8 end
        table.insert(rows, { e = { name = "Sample " .. i, glow = "both" }, st = s })
      end
    end
    return rows
  end

  -- ---------------------------------------------------------------- the bars on screen

  local function MakeFrame(i)
    local f = CreateFrame("Frame", "pfCDM" .. i, UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -140 - (i - 1) * 46)
    f:SetWidth(36)
    f:SetHeight(36)
    f.buttons = {}
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 3)
    f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
    f.bg:SetTexture(0, 0, 0, .45)
    f.bg:Hide()
    if UpdateMovable then UpdateMovable(f) end
    return f
  end
  for i = 1, CDM.MAXBARS do CDM.frames[i] = MakeFrame(i) end

  function CDM.BarShown(bar)
    if bar.show == "never" then return false end
    if bar.show == "combat" then return UnitAffectingCombat("player") and true or false end
    if bar.show == "target" then return (UnitAffectingCombat("player") or UnitExists("target")) and true or false end
    return true
  end
  function CDM.Update(now)
    local bars = CDM.Bars()
    local layout = pfUI.unlock and pfUI.unlock:IsShown()
    for i = 1, CDM.MAXBARS do
      local f, bar = CDM.frames[i], bars[i]
      if not bar then
        f:Hide()
      else
        local fr = f
        local rows, known
        if layout then rows = CDM.Samples(i, now) known = table.getn(rows)
        else rows, known = CDM.Rows(i, now) end
        CDM.Layout(f, f.buttons, bar, rows, known, function() return CDM.NewButton(fr) end, now)
        local click = bar.click == "1" and not layout
        for _, b in ipairs(f.buttons) do
          if b.clicky ~= click then b.clicky = click b:EnableMouse(click) end
        end
        f:SetAlpha(Num(bar.alpha, 1))
        if bar.bg == "1" and table.getn(rows) > 0 then f.bg:Show() else f.bg:Hide() end
        if layout or (CDM.BarShown(bar) and known > 0) then f:Show() else f:Hide() end
      end
    end
  end
  function CDM.Changed()
    CDM.itemsDirty = true
    CDM.ReadBuffs()
    CDM.Update(GetTime())
  end
  function CDM.OpenOptions()
    if pfUI.gui and pfUI.octoui and pfUI.octoui.Options and pfUI.octoui.Options.Open then
      if not pfUI.gui:IsShown() then pfUI.gui:Show() end
      pfUI.octoui.Options:Open("cdmbars")
    end
  end

  -- ---------------------------------------------------------------- events

  local ev = CreateFrame("Frame")
  CDM.ev = ev
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_AURAS_CHANGED", "BAG_UPDATE",
                       "UNIT_INVENTORY_CHANGED", "CHARACTER_POINTS_CHANGED" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function()
    if event == "PLAYER_AURAS_CHANGED" then CDM.names = {} this.auras = true
    elseif event == "BAG_UPDATE" then CDM.itemsDirty = true
    elseif event == "UNIT_INVENTORY_CHANGED" then if arg1 == "player" then CDM.itemsDirty = true end
    else this.book = GetTime() + .5 end
  end)
  ev:SetScript("OnUpdate", function()
    local now = GetTime()
    if (this.next or 0) > now then return end
    this.next = now + .1
    if this.book and now >= this.book then
      this.book = nil
      -- (no ready sounds for what the first look finds already off cooldown)
      CDM.quietUntil = now + 2
      CDM.Rescan()
    end
    if this.auras or (this.buffAt or 0) <= now then
      this.auras, this.buffAt = nil, now + 1
      CDM.ReadBuffs()
      if CDM.LearnCDs() then CDM.Fill() end
    end
    CDM.Update(now)
  end)

  _G.SLASH_PFCDM1, _G.SLASH_PFCDM2 = "/cdm", "/cooldowns"
  SlashCmdList["PFCDM"] = function(msg)
    msg = Lower(msg)
    if msg == "fill" then
      S().removed = {}
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r cooldowns: " .. CDM.Rescan() .. " added.")
    else
      CDM.OpenOptions()
    end
  end
end)
