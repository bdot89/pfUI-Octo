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
  -- an icon's own options, in the order of its right-click menu (user, 15 Nov 2026, of
  -- EllesmereUI's menu: "add all the options ... everything identical"). Each: the entry's
  -- key, the menu line, the choices, the choice when nothing is set; `more` = a second
  -- group in the same sub-menu.
  -- (user, 15 Nov 2026: "as many animations and glow options as you can ... the more like WA the better")
  local GLOW = { { key = "off", label = "Off" }, { key = "soft", label = "Soft outer glow" }, { key = "pulse", label = "Pulsing fill" },
                 { key = "border", label = "Bright border" }, { key = "ants", label = "Marching lines (pixel glow)" },
                 { key = "sparks", label = "Circling sparks (autocast shine)" }, { key = "button", label = "Action button glow" },
                 { key = "ring", label = "Expanding rings" }, { key = "corners", label = "Corner brackets" },
                 { key = "blink", label = "Blinking border" }, { key = "rainbow", label = "Rainbow border" },
                 { key = "double", label = "Border and outer glow" } }
  local LOOP = { { key = "none", label = "None" }, { key = "pulse", label = "Pulse (grows and shrinks)" }, { key = "bounce", label = "Bounce" },
                 { key = "float", label = "Float up and down" }, { key = "shake", label = "Shake" }, { key = "wobble", label = "Wobble" },
                 { key = "spin", label = "Spin" }, { key = "blink", label = "Blink" }, { key = "breathe", label = "Fade in and out" } }
  local SHOT = { { key = "none", label = "None" }, { key = "pop", label = "Pop (big, then settles)" }, { key = "grow", label = "Grow in" },
                 { key = "drop", label = "Drop in" }, { key = "spin", label = "One spin" }, { key = "shake", label = "Shake" },
                 { key = "white", label = "White flash" } }
  CDM.GLOWLIST, CDM.LOOPS, CDM.SHOTS = GLOW, LOOP, SHOT
  local ONOFF = { { key = "1", label = "On" }, { key = "0", label = "Off" } }
  CDM.GLOWCOLORS = {
    { key = "", label = "The shared glow colour" }, { key = "gold", label = "Gold", c = { 1, .82, .2 } },
    { key = "white", label = "White", c = { 1, 1, 1 } }, { key = "red", label = "Red", c = { 1, .25, .2 } },
    { key = "orange", label = "Orange", c = { 1, .55, .1 } }, { key = "green", label = "Green", c = { .3, 1, .4 } },
    { key = "blue", label = "Blue", c = { .3, .65, 1 } }, { key = "purple", label = "Purple", c = { .75, .4, 1 } },
    { key = "class", label = "My class colour" },
  }
  CDM.SPEC = {
    { key = "proc", label = "Proc Glow", def = "off", opts = GLOW,
      tip = "Glows while the spell is ready AND can be used right now: Overpower after a dodge, Execute under 20%, Revenge..." },
    { key = "act", label = "Active State", def = "full", tip = "What the icon does while the spell's effect is on you.",
      opts = { { key = "full", label = "Its time left and a coloured edge" }, { key = "time", label = "Its time left only" },
               { key = "off", label = "Nothing (the cooldown as always)" } } },
    { key = "actglow", label = "Active State Glow", def = "off", opts = GLOW, tip = "Glows while the spell's effect is on you." },
    { key = "maxglow", label = "Max Charges Glow", def = "off", opts = GLOW,
      tip = "Glows while its effect has all its charges or stacks (the most seen on you: Inner Fire's 20)." },
    { key = "idle", label = "Non Active State", def = "normal", tip = "How the icon looks while it is ready and nothing is running.",
      opts = { { key = "normal", label = "Normal" }, { key = "dim", label = "Dimmed" }, { key = "grey", label = "Grey" },
               { key = "hide", label = "Hidden" } } },
    { key = "desat", label = "Cooldown Saturation", def = "1",
      opts = { { key = "1", label = "Grey while on cooldown" }, { key = "0", label = "Keeps its colours" } } },
    { key = "cdfx", label = "Cooldown State Effect", def = "normal", tip = "How the icon looks while on cooldown, and when it comes off it.",
      opts = { { key = "normal", label = "Normal" }, { key = "dim", label = "Dimmed" }, { key = "hide", label = "Hidden" } },
      more = { key = "flash", head = "When it comes ready", def = "0",
               opts = { { key = "1", label = "Flashes for a few seconds" }, { key = "0", label = "No flash" } } } },
    { key = "thresh", label = "Threshold Text", def = "3", tip = "The cooldown's time turns red in its last seconds.",
      opts = { { key = "0", label = "Off" }, { key = "3", label = "Red under 3 seconds" }, { key = "5", label = "Red under 5 seconds" },
               { key = "10", label = "Red under 10 seconds" } } },
    { key = "swipe", label = "Cooldown Swipe", def = "1", opts = ONOFF, tip = "The dark shade that shrinks away as the cooldown runs.",
      more = { key = "text", head = "Time left as a number", def = "1", opts = ONOFF } },
    { key = "sound", label = "Audio Effect on CD Ready", def = "", opts = "SOUNDS" },
    { key = "gcolor", label = "Glow Effect Color", def = "", opts = "GLOWCOLORS" },
    -- more than the model has (extra = under their own rule in the menu)
    { key = "gspeed", label = "Glow Speed", def = "1", extra = true,
      opts = { { key = ".5", label = "Slow" }, { key = "1", label = "Normal" }, { key = "2", label = "Fast" } } },
    { key = "anim_ready", label = "Animation: Comes Ready", def = "none", opts = SHOT, extra = true, tip = "Plays once when the cooldown ends." },
    { key = "anim_proc", label = "Animation: Usable Now", def = "none", opts = LOOP, extra = true,
      tip = "Runs while the spell is ready and can be used right now (Overpower, Execute...)." },
    { key = "anim_act", label = "Animation: Active", def = "none", opts = LOOP, extra = true, tip = "Runs while its effect is on you." },
    { key = "anim_cd", label = "Animation: On Cooldown", def = "none", opts = LOOP, extra = true },
  }
  function CDM.Opts(spec)
    if type(spec.opts) == "string" then return CDM[spec.opts] end
    return spec.opts
  end
  -- an entry's choice for a key (its own, else the usual one)
  function CDM.Get(e, key)
    local v = e[key]
    if v ~= nil and v ~= "" then return v end
    for _, s in ipairs(CDM.SPEC) do
      if s.key == key then return s.def end
      if s.more and s.more.key == key then return s.more.def end
    end
  end
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
    if type(s.maxc) ~= "table" then s.maxc = {} end
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
        out[Lower(name)] = { name = name, ends = (type(expires) == "number" and expires > 0) and expires or nil,
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
          out[Lower(name)] = { name = name, ends = (type(left) == "number" and left > 0) and (now + left) or nil,
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
    if e.kind == "aura" then
      -- (an effect or proc followed by its name alone: always "known"; its picture is kept once seen)
      st.known, st.tex = true, e.tex
    elseif e.kind == "item" then
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
    if CDM.Get(e, "act") ~= "off" then
      local a = CDM.buffs[(e.buff and e.buff ~= "") and Lower(e.buff) or k]
      if a then
        st.active = true
        st.aleft = a.ends and math.max(0, a.ends - now) or nil
        if a.count and a.count > 1 then
          st.count = a.count
          -- (all its charges: the most ever seen on you)
          local top = S().maxc[k] or 0
          if a.count > top then top = a.count S().maxc[k] = top end
          st.maxed = a.count >= top
        end
        if e.kind == "aura" and a.tex then e.tex = a.tex st.tex = a.tex end
        if not st.tex then st.tex = a.tex end
      end
    end
    st.state = st.active and "active" or (st.left and "cd" or "ready")
    if st.known and st.state == "ready" and (CDM.Get(e, "proc") ~= "off" or CDM.Get(e, "anim_proc") ~= "none") then
      st.usable = CDM.Usable(e)
    end
    return st
  end
  -- is it drawn now: known, its talent condition met, not hidden in this state
  function CDM.Wanted(e, st)
    if not st.known or not CDM.TalentOK(e) then return false end
    if st.state == "ready" then return CDM.Get(e, "idle") ~= "hide" end
    if st.state == "cd" then return CDM.Get(e, "cdfx") ~= "hide" end
    return true
  end

  -- can the spell be used right now (reactive ones: Overpower, Execute...): ClassicAPI when it
  -- answers, else the action button that holds the spell; no button = yes
  CDM.slots = {}
  function CDM.Usable(e)
    if e.kind == "item" then return true end
    local b = CDM.book[Lower(e.name)]
    if not b then return false end
    local cs = rawget(_G, "C_Spell")
    if type(cs) == "table" and type(cs.IsSpellUsable) == "function" then
      local ok, usable = pcall(cs.IsSpellUsable, e.name)
      if ok and usable ~= nil then return usable and true or false end
    end
    if not (HasAction and GetActionTexture and IsUsableAction) then return true end
    local now = GetTime()
    if not CDM.slotsAt or now - CDM.slotsAt > 5 then
      CDM.slotsAt, CDM.slots = now, {}
      for slot = 1, 120 do
        if HasAction(slot) and not (GetActionText and GetActionText(slot)) then
          local tex = GetActionTexture(slot)
          if tex and not CDM.slots[tex] then CDM.slots[tex] = slot end
        end
      end
    end
    local slot = b.tex and CDM.slots[b.tex]
    if not slot then return true end
    return IsUsableAction(slot) and true or false
  end

  -- talents: name (lower) -> points in it
  function CDM.Talents()
    if CDM.talents then return CDM.talents end
    local out, list = {}, {}
    if GetNumTalentTabs and GetNumTalents and GetTalentInfo then
      for tab = 1, GetNumTalentTabs() do
        for i = 1, GetNumTalents(tab) do
          local name, tex, _, _, rank = GetTalentInfo(tab, i)
          if name then
            out[Lower(name)] = tonumber(rank) or 0
            table.insert(list, { name = name, tex = tex, rank = tonumber(rank) or 0 })
          end
        end
      end
    end
    CDM.talents, CDM.talentList = out, list
    return out
  end
  -- e.talent = a talent's name; e.talentnot = "1": only WITHOUT it
  function CDM.TalentOK(e)
    if not e.talent or e.talent == "" then return true end
    local has = (CDM.Talents()[Lower(e.talent)] or 0) > 0
    if e.talentnot == "1" then return not has end
    return has
  end
  function CDM.GlowColor(e)
    local key = e.gcolor
    if key == "class" then
      local _, class = UnitClass("player")
      local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
      if c then return c.r, c.g, c.b end
    end
    for _, o in ipairs(CDM.GLOWCOLORS) do
      if o.key == key and o.c then return o.c[1], o.c[2], o.c[3] end
    end
    return CDM.Color("glowcolor", 1, .82, .2, 1)
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
    b.fill = b.over:CreateTexture(nil, "ARTWORK")
    b.fill:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.fill:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.fill:SetTexture(WHITE)
    b.fill:SetBlendMode("ADD")
    b.fill:Hide()
    b.rim = CreateFrame("Frame", nil, b)
    b.rim:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
    b.rim:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
    b.rim:SetFrameLevel(b:GetFrameLevel() + 3)
    b.rim:SetBackdrop({ edgeFile = WHITE, edgeSize = 2 })
    b.rim:Hide()
    b.white = b.over:CreateTexture(nil, "OVERLAY")
    b.white:SetAllPoints(b.icon)
    b.white:SetTexture(WHITE)
    b.white:SetBlendMode("ADD")
    b.white:Hide()
    -- glows and animations move every frame (nothing to do = one test)
    b:SetScript("OnUpdate", function()
      if this.busy or this.moved or this.turned then CDM.Animate(this, GetTime()) end
    end)
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
  function CDM.Paint(b, e, st, size, flash, now, at)
    b.e, b.state = e, st.state
    local zoom = Num(S().zoom, .08)
    b.icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
    b.icon:SetTexture((e.icon and e.icon ~= "" and e.icon) or st.tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    local r, g, bl, a = CDM.Color("bordercolor", .2, .2, .24, 1)
    if st.state == "active" and CDM.Get(e, "act") == "full" then r, g, bl, a = CDM.Color("activecolor", .3, .9, .4, 1) end
    b.edged = st.state == "active" and CDM.Get(e, "act") == "full"
    b:SetBackdropBorderColor(r, g, bl, a)
    local oncd = st.state == "cd"
    local idle = st.state == "ready" and CDM.Get(e, "idle") or "normal"
    if b.icon.SetDesaturated then b.icon:SetDesaturated((oncd and e.desat ~= "0") or idle == "grey") end
    b.baseAlpha = ((oncd and CDM.Get(e, "cdfx") == "dim") or idle == "dim") and .4 or 1
    b.zoom = zoom
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
    if S().timers == "0" or e.text == "0" then
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
    -- one glow at a time: all charges, then active, then usable now, then the ready flash
    local style = "off"
    if st.state == "active" and st.maxed then style = CDM.Get(e, "maxglow") end
    if style == "off" and st.state == "active" then style = CDM.Get(e, "actglow") end
    if style == "off" and st.state == "ready" and st.usable then style = CDM.Get(e, "proc") end
    if style == "off" and st.state == "ready" and flash and CDM.Get(e, "flash") == "1" then style = "soft" end
    b.lit = style
    b.gr, b.gg, b.gb = CDM.GlowColor(e)
    b.gspeed = Num(CDM.Get(e, "gspeed"), 1)
    -- the animation of the state it is in, and the one-off when it came ready (at)
    local loop = "none"
    if st.state == "active" then loop = CDM.Get(e, "anim_act")
    elseif st.state == "cd" then loop = CDM.Get(e, "anim_cd")
    elseif st.usable then loop = CDM.Get(e, "anim_proc") end
    b.animLoop = loop
    b.animShot, b.shotAt = CDM.Get(e, "anim_ready"), (st.state == "ready") and at or nil
    CDM.Animate(b, now or GetTime())
  end

  -- ---------------------------------------------------------------- glows and animations
  -- Drawn every frame from what Paint decided (b.lit, b.animLoop, b.animShot / shotAt). Our own
  -- drawing with the game's textures and pfUI's art; the ideas are WeakAuras' glow kinds and
  -- animations (pixel glow, autocast shine, button glow; pulse, bounce, shake, spin...).
  local ART = "Interface\\AddOns\\pfUI\\img\\"
  local SHOTLEN = .6
  local function Fx(b)
    if b.fx then return b.fx end
    local g = CreateFrame("Frame", nil, b)
    g:SetAllPoints(b)
    g:SetFrameLevel(b:GetFrameLevel() + 4)
    g.dash, g.spark, g.corner = {}, {}, {}
    for i = 1, 8 do
      g.dash[i] = g:CreateTexture(nil, "OVERLAY")
      g.dash[i]:SetTexture(WHITE)
      g.dash[i]:Hide()
    end
    for i = 1, 4 do
      g.spark[i] = g:CreateTexture(nil, "OVERLAY")
      g.spark[i]:SetTexture(ART .. "plates\\cp-glow")
      g.spark[i]:SetBlendMode("ADD")
      g.spark[i]:Hide()
    end
    for i = 1, 8 do
      g.corner[i] = g:CreateTexture(nil, "OVERLAY")
      g.corner[i]:SetTexture(WHITE)
      g.corner[i]:Hide()
    end
    g.button = g:CreateTexture(nil, "OVERLAY")
    g.button:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    g.button:SetBlendMode("ADD")
    g.button:SetPoint("CENTER", b, "CENTER", 0, 0)
    g.button:Hide()
    g.ring = g:CreateTexture(nil, "OVERLAY")
    g.ring:SetTexture(ART .. "bars\\btn-ring")
    g.ring:SetBlendMode("ADD")
    g.ring:SetPoint("CENTER", b, "CENTER", 0, 0)
    g.ring:Hide()
    b.fx = g
    return g
  end
  -- a place p along the edge of a w x h box, clockwise from the top left: x, y (down), side
  local function Edge(w, h, p)
    p = math.mod(p, 2 * (w + h))
    if p < w then return p, 0, 1 end
    if p < w + h then return w, p - w, 2 end
    if p < 2 * w + h then return w - (p - w - h), h, 3 end
    return 0, h - (p - 2 * w - h), 4
  end
  CDM.Edge = Edge
  local function Rainbow(t)
    local h = math.mod(t, 1) * 6
    local x = 1 - math.abs(math.mod(h, 2) - 1)
    if h < 1 then return 1, x, 0 elseif h < 2 then return x, 1, 0 elseif h < 3 then return 0, 1, x
    elseif h < 4 then return 0, x, 1 elseif h < 5 then return x, 0, 1 end
    return 1, 0, x
  end
  function CDM.Animate(b, now)
    local style = b.lit or "off"
    local r, g, bl = b.gr or 1, b.gg or .82, b.gb or .2
    local t = now * (b.gspeed or 1)
    local wave = math.abs(math.sin(t * 4))
    local size = b.bsize or b:GetWidth() or 36
    if style == "soft" or style == "double" then b.glow:SetBackdropBorderColor(r, g, bl, .45 + .55 * wave) b.glow:Show() else b.glow:Hide() end
    if style == "pulse" then b.fill:SetVertexColor(r, g, bl, .12 + .33 * wave) b.fill:Show() else b.fill:Hide() end
    if style == "border" or style == "double" then
      b.rim:SetBackdropBorderColor(r, g, bl, 1) b.rim:Show()
    elseif style == "blink" then
      b.rim:SetBackdropBorderColor(r, g, bl, math.mod(t * 3, 1) < .5 and 1 or 0) b.rim:Show()
    elseif style == "rainbow" then
      local rr, rg, rb = Rainbow(t * .5)
      b.rim:SetBackdropBorderColor(rr, rg, rb, 1) b.rim:Show()
    else
      b.rim:Hide()
    end
    local fx = b.fx
    local need = style == "ants" or style == "sparks" or style == "button" or style == "ring" or style == "corners"
    if need then fx = Fx(b) end
    if fx then
      local per = 4 * size
      for i = 1, 8 do
        local d = fx.dash[i]
        if style == "ants" then
          local len = per / 16
          local x, y, side = Edge(size, size, t * 22 + (i - 1) * per / 8)
          d:ClearAllPoints()
          if side == 1 or side == 3 then
            d:SetWidth(len) d:SetHeight(2)
            d:SetPoint("CENTER", b, "TOPLEFT", math.max(len / 2, math.min(size - len / 2, x)), -y)
          else
            d:SetWidth(2) d:SetHeight(len)
            d:SetPoint("CENTER", b, "TOPLEFT", x, -math.max(len / 2, math.min(size - len / 2, y)))
          end
          d:SetVertexColor(r, g, bl, 1)
          d:Show()
        else
          d:Hide()
        end
      end
      for i = 1, 4 do
        local s = fx.spark[i]
        if style == "sparks" then
          local x, y = Edge(size, size, t * 40 + (i - 1) * per / 4)
          s:ClearAllPoints()
          s:SetWidth(size * .42) s:SetHeight(size * .42)
          s:SetPoint("CENTER", b, "TOPLEFT", x, -y)
          s:SetVertexColor(r, g, bl, 1)
          s:Show()
        else
          s:Hide()
        end
      end
      if style == "button" then
        fx.button:SetWidth(size * 1.75) fx.button:SetHeight(size * 1.75)
        fx.button:SetVertexColor(r, g, bl, .55 + .45 * wave)
        fx.button:Show()
      else
        fx.button:Hide()
      end
      if style == "ring" then
        local k = math.mod(t, 1)
        fx.ring:SetWidth(size * (1 + k * .9)) fx.ring:SetHeight(size * (1 + k * .9))
        fx.ring:SetVertexColor(r, g, bl, 1 - k)
        fx.ring:Show()
      else
        fx.ring:Hide()
      end
      for i = 1, 8 do
        local c = fx.corner[i]
        if style == "corners" then
          -- two bars per corner, sliding in and out
          local corner = math.floor((i - 1) / 2)
          local horiz = math.mod(i, 2) == 1
          local out = 1 + 3 * wave
          local len = size * .32
          local px = (corner == 0 or corner == 3) and "LEFT" or "RIGHT"
          local py = (corner < 2) and "TOP" or "BOTTOM"
          local sx = (px == "LEFT") and -out or out
          local sy = (py == "TOP") and out or -out
          c:ClearAllPoints()
          c:SetWidth(horiz and len or 2) c:SetHeight(horiz and 2 or len)
          c:SetPoint(py .. px, b, py .. px, sx, sy)
          c:SetVertexColor(r, g, bl, 1)
          c:Show()
        else
          c:Hide()
        end
      end
    end

    -- the icon's own movement
    local dx, dy, grow, alpha, rot, white = 0, 0, 0, 1, 0, 0
    local loop = b.animLoop
    if loop == "pulse" then grow = 2.5 * math.sin(now * 6)
    elseif loop == "bounce" then dy = math.abs(math.sin(now * 6)) * size * .16
    elseif loop == "float" then dy = math.sin(now * 3) * size * .07
    elseif loop == "shake" then dx = math.sin(now * 45) * 1.6
    elseif loop == "wobble" then rot = math.sin(now * 7) * .22
    elseif loop == "spin" then rot = now * 3
    elseif loop == "blink" then alpha = math.mod(now * 2.5, 1) < .5 and 1 or .25
    elseif loop == "breathe" then alpha = .6 + .4 * math.abs(math.sin(now * 2.5)) end
    local shot = b.animShot
    if shot and shot ~= "none" and b.shotAt and now >= b.shotAt and now - b.shotAt < SHOTLEN then
      local k = (now - b.shotAt) / SHOTLEN
      if shot == "pop" then grow = grow + size * .22 * (1 - k)
      elseif shot == "grow" then grow = grow - size * .3 * (1 - k)
      elseif shot == "drop" then dy = dy + size * .6 * (1 - k) * math.abs(math.cos(k * 4.7))
      elseif shot == "spin" then rot = rot + (1 - k) * 6.2832
      elseif shot == "shake" then dx = dx + math.sin(now * 60) * 3 * (1 - k)
      elseif shot == "white" then white = 1 - k end
    end
    b.icon:SetAlpha((b.baseAlpha or 1) * alpha)
    if white > 0 then b.white:SetVertexColor(1, 1, 1, white * .8) b.white:Show() elseif b.white then b.white:Hide() end
    local z = b.zoom or .08
    if rot ~= 0 then
      local c, s = math.cos(rot), math.sin(rot)
      local h = (.5 - z) / (math.abs(c) + math.abs(s))
      local function P(x, y) return .5 + (x * c - y * s) * h, .5 + (x * s + y * c) * h end
      local ulx, uly = P(-1, -1)
      local llx, lly = P(-1, 1)
      local urx, ury = P(1, -1)
      local lrx, lry = P(1, 1)
      b.icon:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
      b.turned = true
    elseif b.turned then
      b.turned = nil
      b.icon:SetTexCoord(z, 1 - z, z, 1 - z)
    end
    if b.bx and b.host then
      local moved = dx ~= 0 or dy ~= 0 or grow ~= 0
      if moved or b.moved then
        b.moved = moved
        b:SetWidth(size + 2 * grow)
        b:SetHeight(size + 2 * grow)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", b.host, "TOPLEFT", b.bx - grow + dx, -(b.by - grow) + dy)
      end
    end
    b.busy = style ~= "off" or (loop and loop ~= "none") or (shot and shot ~= "none" and b.shotAt and now - b.shotAt < SHOTLEN) or false
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
      b.host, b.bx, b.by, b.bsize = frame, x, y, size
      CDM.Paint(b, rows[i].e, rows[i].st, size, rows[i].flash, now, rows[i].at)
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
          rt.flash, rt.readyAt = now + 4, now
          if e.sound and e.sound ~= "" and now >= (CDM.quietUntil or 0) then CDM.PlaySound(e.sound) end
        end
        rt.was, rt.dur = st.state, st.dur or rt.dur
        if st.state == "cd" then rt.flash = nil end
        if CDM.Wanted(e, st) then
          table.insert(rows, { e = e, st = st, flash = rt.flash and rt.flash > now, at = rt.readyAt })
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
        local s = { known = true, tex = st.tex, state = kind, count = st.count, usable = kind == "ready", maxed = kind == "active" }
        if kind == "cd" then s.left, s.dur = left, span elseif kind == "active" then s.aleft = left end
        -- (the picked icon runs through all three states so each choice shows)
        if CDM.demo == e.name then
          local step = math.mod(math.floor(now / 3), 3)
          s.state = (step == 0) and "ready" or (step == 1 and "cd" or "active")
          s.usable, s.maxed = s.state == "ready", s.state == "active"
          s.left, s.dur, s.aleft = nil, nil, nil
          local t = 3 - math.mod(now, 3)
          if s.state == "cd" then s.left, s.dur = t, 3 elseif s.state == "active" then s.aleft = t end
        end
        table.insert(rows, { e = e, st = s, flash = s.state == "ready", at = (CDM.demo == e.name) and (math.floor(now / 9) * 9) or nil })
      end
    end
    if table.getn(rows) == 0 then
      local tex = { "Spell_Holy_PowerInfusion", "Spell_Frost_FrostNova", "Spell_Nature_Lightning", "INV_Misc_PocketWatch_01" }
      for i = 1, 4 do
        local kind = kinds[i]
        local s = { known = true, tex = "Interface\\Icons\\" .. tex[i], state = kind }
        if kind == "cd" then s.left, s.dur = 12, 30 elseif kind == "active" then s.aleft = 8 end
        table.insert(rows, { e = { name = "Sample " .. i, actglow = "soft" }, st = s })
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
    else this.book = GetTime() + .5 CDM.talents = nil CDM.slotsAt = nil end
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
