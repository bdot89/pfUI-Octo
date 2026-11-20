pfUI:RegisterModule("octototems", "vanilla", function ()
  -- pfUI Octo :: OctoTotems (19 Nov 2026; user with Call of Elements 3.4.1 (sica42's fork): "our own version of
  -- this implemented fully ... its own page and preview all the options + more merge with the bulwark", "use dlls
  -- where we can"). Call of Elements has no licence, so only its feature list was read; nothing copied.
  -- Totems, elements, ranks and durations come from the client's Spell.dbc (modules\octototems-data.lua, generated).
  -- Named octototems / C.octototems / pfOctoTotems*: pfUI's own small totem bar is modules\totems.lua (pfUI.totems,
  -- C.totems, pfTotems) and stays as it is.
  --   bars      one per element (or all four side by side): anchor button + the rest open / on hover / closed /
  --             hidden, any direction, own order and hidden totems, timers, cooldown, range, set and advice marks
  --   sets      named sets of up to four totems with a throw order; one press throws what is missing (nampower's
  --             QueueSpellByName: the whole set on one press), PvP class sets and sets named after a target
  --   alerts    10 / 5 s left, expired, destroyed, out of range, recall reminder; shield and weapon imbue reminders
  --   advisor   poison / disease / fear-charm-sleep on your group -> the cleansing / Tremor totem glows
  --   heals     battle heal / best heal keys: the most hurt group member, the smallest rank that covers it
  -- DLLs: ClassicAPI GetTotemInfo / GetTotemTimeLeft (real slots: early deaths and recalls; through pfUI's
  -- libtotem), C_Spell.IsSpellUsable (mana / usable); nampower QueueSpellByName; SuperWoW / UnitXP position
  -- (range from where the totem was dropped) and CastSpellByName(spell, unit) (heals without a target swap).
  local TT = {}
  pfUI.octototems = TT
  TT.DATA = pfUI.totemData or {}
  TT.EL = {
    { key = "fire",  name = "Fire",  col = { 1, .42, .12 } },
    { key = "earth", name = "Earth", col = { .78, .58, .3 } },
    { key = "water", name = "Water", col = { .3, .62, 1 } },
    { key = "air",   name = "Air",   col = { .72, .86, 1 } },
  }
  TT.RECALL = "Totemic Recall"
  TT.SHIELDS = { "Water Shield", "Lightning Shield", "Earth Shield" }
  TT.IMBUES = { "Rockbiter Weapon", "Flametongue Weapon", "Frostbrand Weapon", "Windfury Weapon" }
  TT.HEALS = { battle = { "Lesser Healing Wave", "Healing Wave" }, best = { "Healing Wave", "Lesser Healing Wave" } }
  -- the buff a totem puts on you (range check without a position)
  TT.BUFF = {
    ["Strength of Earth Totem"] = "Strength of Earth", ["Stoneskin Totem"] = "Stoneskin", ["Grace of Air Totem"] = "Grace of Air",
    ["Windfury Totem"] = "Windfury Totem", ["Mana Spring Totem"] = "Mana Spring", ["Healing Stream Totem"] = "Healing Stream",
    ["Frost Resistance Totem"] = "Frost Resistance", ["Fire Resistance Totem"] = "Fire Resistance",
    ["Nature Resistance Totem"] = "Nature Resistance", ["Tranquil Air Totem"] = "Tranquil Air", ["Windwall Totem"] = "Windwall",
    ["Flametongue Totem"] = "Flametongue Totem", ["Grounding Totem"] = "Grounding Totem Effect", ["Mana Tide Totem"] = "Mana Tide",
  }
  -- what the advisor answers with
  TT.CURES = { Poison = "Poison Cleansing Totem", Disease = "Disease Cleansing Totem" }
  TT.TREMOR = { "Fear", "Sleep", "Charm", "Psychic Scream", "Mind Control", "Bellowing Roar", "Intimidating Shout", "Panic",
    "Terrify", "Terrifying Screech", "Seduction", "Howl of Terror", "Intimidating Growl", "Crystalline Slumber", "Druid's Slumber",
    "Death Coil", "Scare Beast", "Hibernate", "Wyvern Sting", "Fear Ward" }
  TT.CLASSES = { "WARRIOR", "ROGUE", "MAGE", "WARLOCK", "HUNTER", "PRIEST", "DRUID", "PALADIN", "SHAMAN" }

  local function S() return C.octototems end
  local function On(key) return S()[key] == "1" end
  local function Num(key, def) return tonumber(S()[key]) or def end
  function TT.Col(key, r, g, b, a)
    local s = S()[key]
    if type(s) == "string" and s ~= "" then
      local _, _, cr, cg, cb, ca = string.find(s, "^%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,?%s*([%d%.]*)")
      if cr then return tonumber(cr), tonumber(cg), tonumber(cb), tonumber(ca) or 1 end
    end
    return r, g, b, a or 1
  end
  function TT.ElCol(i)
    local e = TT.EL[i]
    return TT.Col("col_" .. e.key, e.col[1], e.col[2], e.col[3], 1)
  end

  local _, class = UnitClass("player")
  TT.shaman = class == "SHAMAN"

  -- DLLs ------------------------------------------------------------------
  function TT.Nampower() return _G.QueueSpellByName and true or false end
  function TT.HasPos() return _G.UnitPosition and true or false end
  function TT.Pos()
    if _G.UnitPosition then
      local ok, x, y, z = pcall(_G.UnitPosition, "player")
      if ok and x then return x, y, z end
    end
  end
  function TT.ClassicTotems() return _G.C_UnitAuras and _G.GetTotemInfo and true or false end

  -- spell book --------------------------------------------------------------
  -- TT.book[name] = { id = highest rank's book index, rank = its rank text, low = rank 1 index, lowrank, tex }
  TT.book = {}
  local function Rank(r) local _, _, n = string.find(r or "", "(%d+)") return tonumber(n) or 0 end
  function TT.Scan()
    TT.book = {}
    if not GetSpellName then return end
    local i = 1
    while true do
      local name, rank = GetSpellName(i, BOOKTYPE_SPELL or "spell")
      if not name then break end
      local want = TT.DATA[name] or name == TT.RECALL
      if not want then for _, n in ipairs(TT.SHIELDS) do if n == name then want = true end end end
      if not want then for _, n in ipairs(TT.IMBUES) do if n == name then want = true end end end
      if not want then for _, n in ipairs(TT.HEALS.best) do if n == name then want = true end end end
      if not want and name == "Chain Heal" then want = true end
      if want then
        local b = TT.book[name]
        if not b then
          b = { id = i, rank = rank, low = i, lowrank = rank, ranks = {} }
          TT.book[name] = b
        end
        if Rank(rank) >= Rank(b.rank) then b.id, b.rank = i, rank end
        if Rank(rank) < Rank(b.lowrank) then b.low, b.lowrank = i, rank end
        table.insert(b.ranks, { id = i, rank = rank })
        b.tex = GetSpellTexture and GetSpellTexture(i, BOOKTYPE_SPELL or "spell") or b.tex
      end
      i = i + 1
    end
  end
  function TT.Known(name) return TT.book[name] ~= nil end
  function TT.Icon(name)
    local b = TT.book[name]
    if b and b.tex then return b.tex end
    local d = TT.DATA[name]
    return d and d.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
  end
  -- totems of an element, known ones (or all of the data for previews), in the saved order
  function TT.ElementTotems(el, all)
    local list = {}
    for name, d in pairs(TT.DATA) do
      if d.el == el and (all or TT.book[name]) then table.insert(list, name) end
    end
    local order = {}
    local saved = S().order and S().order[TT.EL[el].key] or ""
    local n = 0
    for name in string.gfind(saved, "[^,]+") do n = n + 1 order[name] = n end
    table.sort(list, function(a, b)
      local oa, ob = order[a] or 100, order[b] or 100
      if oa ~= ob then return oa < ob end
      return a < b
    end)
    return list
  end
  function TT.SetOrder(el, list) S().order[TT.EL[el].key] = table.concat(list, ",") end
  function TT.Duration(name, rank)
    local d = TT.DATA[name]
    if not d then return 0 end
    if d.dur[rank or ""] then return d.dur[rank or ""] end
    local best = 0
    for _, v in pairs(d.dur) do if v > best then best = v end end
    return best
  end

  -- casting -----------------------------------------------------------------
  TT.last = {} -- [el] = { name, rank, at, x, y }
  local function SpellText(name, low)
    local b = TT.book[name]
    if not b then return name end
    local r = low and b.lowrank or b.rank
    if r and r ~= "" then return name .. "(" .. r .. ")", r end
    return name, r
  end
  TT.SpellText = SpellText
  function TT.Cast(name, low, queue)
    if not TT.book[name] then return false end
    local text, rank = SpellText(name, low)
    local d = TT.DATA[name]
    if d then TT.pending = { el = d.el, name = name, rank = rank or "", at = GetTime() } end
    if queue and _G.QueueSpellByName then
      local ok = pcall(_G.QueueSpellByName, text)
      if ok then return true end
    end
    CastSpellByName(text)
    return true
  end
  function TT.Cooldown(name)
    local b = TT.book[name]
    if not b or not GetSpellCooldown then return 0, 0 end
    local start, dur = GetSpellCooldown(b.id, BOOKTYPE_SPELL or "spell")
    return start or 0, dur or 0
  end
  -- seconds of real cooldown left (the global cooldown does not count)
  function TT.CooldownLeft(name)
    local start, dur = TT.Cooldown(name)
    if not start or start <= 0 or not dur or dur <= 1.6 then return 0 end
    return math.max(0, start + dur - GetTime())
  end
  function TT.Usable(name)
    local b = TT.book[name]
    if not b then return false end
    local CS = _G.C_Spell
    if CS and CS.IsSpellUsable then
      local ok, usable, nomana = pcall(CS.IsSpellUsable, name)
      if ok and usable ~= nil then return usable and true or false, nomana end
    end
    return true
  end

  -- active totems -----------------------------------------------------------
  -- TT.Active(el) -> { name, start, dur, left, range = true|false|nil, x, y } or nil
  TT.drop = {}
  -- pfUI's libtotem GetTotemInfo (ClassicAPI's real slots first, its cast tracker as the fallback)
  function TT.TotemInfo(el)
    if GetTotemInfo then return GetTotemInfo(el) end
  end
  function TT.Active(el)
    if TT.fake then return TT.fake[el] end
    local have, name, start, dur = TT.TotemInfo(el)
    if not have or not name or name == "" then TT.drop[el] = nil return nil end
    local _, _, base = string.find(name, "^(.-)%s*[IVX]*$")
    base = TT.DATA[name] and name or base or name
    local drop = TT.drop[el]
    if not drop or drop.start ~= start then
      local x, y = TT.Pos()
      local rank = ""
      if TT.pending and TT.pending.el == el and GetTime() - TT.pending.at < 3 then rank = TT.pending.rank end
      drop = { start = start, x = x, y = y, rank = rank }
      TT.drop[el] = drop
    end
    -- ClassicAPI's duration is the server's; libtotem's table is classic - use the client's data then
    local d = dur
    if not TT.ClassicTotems() then
      local mine = TT.Duration(base, drop.rank)
      if mine > 0 then d = mine end
    end
    local left = start + (d or 0) - GetTime()
    if _G.GetTotemTimeLeft and TT.ClassicTotems() then
      local ok, l = pcall(_G.GetTotemTimeLeft, el)
      if ok and type(l) == "number" and l > 0 then left = l end
    end
    if left <= 0 then return nil end
    return { name = base, start = start, dur = d, left = left, range = TT.InRange(el, base, drop), x = drop.x, y = drop.y }
  end

  -- buffs on you, by name (cached per buff index + texture until auras change)
  TT.names = {}
  local scanner
  local function Scanner()
    if not scanner and libtipscan and libtipscan.GetScanner then scanner = libtipscan:GetScanner("octototems") end
    return scanner
  end
  function TT.Buffs()
    local out = {}
    if not GetPlayerBuff then return out end
    for i = 0, 31 do
      local bid = GetPlayerBuff(i, "HELPFUL")
      if type(bid) ~= "number" or bid < 0 then break end
      local tex = GetPlayerBuffTexture and GetPlayerBuffTexture(bid)
      local key = bid .. ":" .. tostring(tex)
      local name = TT.names[key]
      if name == nil then
        local sc = Scanner()
        if sc and sc.SetPlayerBuff then sc:SetPlayerBuff(bid) name = sc:Line(1) end
        TT.names[key] = name or false
      end
      if name then
        local left = GetPlayerBuffTimeLeft and GetPlayerBuffTimeLeft(bid) or 0
        out[name] = type(left) == "number" and left or 0
      end
    end
    return out
  end

  -- in range: distance from where it was dropped (SuperWoW / UnitXP position), else its buff on you
  function TT.InRange(el, name, drop)
    if TT.fake then return true end
    local range = Num("range", 20)
    if drop and drop.x then
      local x, y = TT.Pos()
      if x then
        local dx, dy = x - drop.x, y - drop.y
        return math.sqrt(dx * dx + dy * dy) <= range
      end
    end
    local buff = TT.BUFF[name]
    if buff and drop and GetTime() - (drop.start or 0) > 2 then
      return (TT.buffs or {})[buff] ~= nil
    end
    return nil
  end

  -- sets --------------------------------------------------------------------
  -- C.octototems.sets = { { name, t1..t4 = totem names, order = "2,1,3,4" } }; C.octototems.cur = index
  function TT.Sets() return S().sets end
  function TT.Cur()
    local sets = TT.Sets()
    local i = tonumber(S().cur) or 1
    if TT.override and sets[TT.override] then i = TT.override end
    return sets[i] or sets[1], i
  end
  function TT.SetIndex(name)
    for i, s in ipairs(TT.Sets()) do if s.name == name then return i end end
  end
  function TT.UseSet(i, quiet)
    local sets = TT.Sets()
    if type(i) == "string" then i = TT.SetIndex(i) end
    if not i or not sets[i] then return false end
    S().cur = tostring(i)
    TT.override = nil
    if not quiet and On("setnotice") then TT.Say("Totem set: |cffffffff" .. sets[i].name .. "|r") end
    TT.Refresh()
    return true
  end
  function TT.NextSet(step)
    local sets = TT.Sets()
    local n = table.getn(sets)
    if n == 0 then return end
    local _, i = TT.Cur()
    i = math.mod(i - 1 + (step or 1) + n, n) + 1
    TT.UseSet(i)
  end
  function TT.SetOrderList(set)
    local out, seen = {}, {}
    for v in string.gfind(set.order or "", "%d") do
      local n = tonumber(v)
      if n and n >= 1 and n <= 4 and not seen[n] then table.insert(out, n) seen[n] = true end
    end
    for n = 1, 4 do if not seen[n] then table.insert(out, n) end end
    return out
  end
  function TT.NewSet(name)
    local list = TT.Sets()
    table.insert(list, { name = name or ("Set " .. (table.getn(list) + 1)), t1 = "", t2 = "", t3 = "", t4 = "", order = "2,1,3,4" })
    return table.getn(list)
  end
  function TT.DeleteSet(i)
    local list = TT.Sets()
    if table.getn(list) <= 1 or not list[i] then return false end
    table.remove(list, i)
    for k, v in pairs(S().pvp) do
      local n = tonumber(v)
      if n == i then S().pvp[k] = "" elseif n and n > i then S().pvp[k] = tostring(n - 1) end
    end
    if (tonumber(S().cur) or 1) >= i then S().cur = tostring(math.max(1, (tonumber(S().cur) or 1) - 1)) end
    return true
  end
  function TT.InSet(set, name)
    local d = TT.DATA[name]
    return set and d and set["t" .. d.el] == name
  end
  function TT.PutInSet(set, name)
    local d = TT.DATA[name]
    if not set or not d then return end
    if set["t" .. d.el] == name then set["t" .. d.el] = "" else set["t" .. d.el] = name end
  end

  -- what a throw of the set would cast now, in order
  function TT.Needed(set, force)
    local out = {}
    if not set then return out end
    local refresh = Num("refresh", 0)
    for _, el in ipairs(TT.SetOrderList(set)) do
      local name = set["t" .. el]
      if name and name ~= "" and TT.book[name] then
        local a = TT.Active(el)
        local need = force or not a or a.name ~= name
        if not need and a and On("redrop") and a.range == false then need = true end
        if not need and a and refresh > 0 and a.left < refresh then need = true end
        if need and TT.CooldownLeft(name) <= 0 then table.insert(out, name) end
      end
    end
    return out
  end
  -- one press: the next missing totem (all of them with nampower's queue)
  function TT.ThrowSet(name, force)
    local set = TT.Cur()
    if name and name ~= "" then
      local i = TT.SetIndex(name)
      if i then set = TT.Sets()[i] end
    end
    local list = TT.Needed(set, force or TT.restart)
    TT.restart = nil
    if table.getn(list) == 0 then
      if On("setnotice") then TT.Say("Every totem of the set is down.") end
      return false
    end
    if TT.Nampower() and On("queueall") then
      for _, n in ipairs(list) do TT.Cast(n, false, true) end
    else
      TT.Cast(list[1])
    end
    return true
  end
  function TT.Restart() TT.restart = true end
  function TT.Recall()
    if TT.book[TT.RECALL] then CastSpellByName(TT.RECALL) return true end
    return false
  end

  -- advisor -----------------------------------------------------------------
  local function IsTremor(name)
    if not name then return false end
    for _, w in ipairs(TT.TREMOR) do if string.find(name, w, 1, true) then return true end end
    return false
  end
  TT.tremorTex = {}
  function TT.Advice()
    local out = {}
    if not On("advisor") then return out end
    local units = { "player" }
    local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if raid == 0 then for i = 1, 4 do table.insert(units, "party" .. i) table.insert(units, "partypet" .. i) end end
    local sc = Scanner()
    for _, u in ipairs(units) do
      if UnitExists(u) and not UnitIsDeadOrGhost(u) then
        for i = 1, 16 do
          local tex, _, kind = UnitDebuff(u, i)
          if not tex then break end
          local totem = kind and TT.CURES[kind]
          if not totem and TT.book["Tremor Totem"] then
            -- a debuff's picture names it well enough: read its name once per picture
            local tr = TT.tremorTex[tex]
            if tr == nil and sc and sc.SetUnitDebuff then
              sc:SetUnitDebuff(u, i)
              tr = IsTremor(sc:Line(1)) and true or false
              TT.tremorTex[tex] = tr
            end
            if tr then totem = "Tremor Totem" end
          end
          if totem and TT.book[totem] then
            local a = TT.Active(TT.DATA[totem].el)
            if not a or a.name ~= totem then out[totem] = (out[totem] or 0) + 1 end
          end
        end
      end
    end
    return out
  end
  function TT.ThrowAdvised()
    for name in pairs(TT.advice or {}) do
      if TT.CooldownLeft(name) <= 0 then TT.Cast(name) return true end
    end
    return false
  end

  -- smart heals -------------------------------------------------------------
  TT.healamt = {}
  function TT.HealAmount(id)
    if TT.healamt[id] then return TT.healamt[id] end
    local sc = Scanner()
    if not sc or not sc.SetSpell then return 0 end
    sc:SetSpell(id, BOOKTYPE_SPELL or "spell")
    local amt, mana = 0, 0
    for l = 1, 8 do
      local t = sc:Line(l)
      if t then
        local _, _, lo, hi = string.find(t, "(%d+) to (%d+)")
        if lo and amt == 0 then amt = (tonumber(lo) + tonumber(hi)) / 2 end
        local _, _, m = string.find(t, "^(%d+) Mana")
        if m then mana = tonumber(m) end
      end
    end
    TT.healamt[id] = { amt = amt, mana = mana }
    return TT.healamt[id]
  end
  function TT.HealTarget()
    local units = { "player" }
    local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if raid > 0 then for i = 1, raid do table.insert(units, "raid" .. i) end
    else for i = 1, 4 do table.insert(units, "party" .. i) end end
    local best, bestp, bestmiss
    local below = Num("healbelow", 90) / 100
    for _, u in ipairs(units) do
      if UnitExists(u) and UnitIsConnected(u) and not UnitIsDeadOrGhost(u) and UnitIsFriend("player", u) then
        local hp, max = UnitHealth(u), UnitHealthMax(u)
        local near = u == "player" or (pfUI.api.UnitInRange and pfUI.api.UnitInRange(u)) or CheckInteractDistance(u, 4)
        if max and max > 0 and near then
          local p = hp / max
          if p < below and (not bestp or p < bestp) then best, bestp, bestmiss = u, p, max - hp end
        end
      end
    end
    return best, bestmiss
  end
  function TT.PickHeal(mode, missing)
    for _, name in ipairs(TT.HEALS[mode] or TT.HEALS.best) do
      local b = TT.book[name]
      if b then
        table.sort(b.ranks, function(x, y) return Rank(x.rank) < Rank(y.rank) end)
        local pick
        for _, r in ipairs(b.ranks) do
          local h = TT.HealAmount(r.id)
          pick = r
          if h.amt and h.amt >= missing * Num("healcover", 90) / 100 then break end
        end
        if pick then return name, pick.rank end
      end
    end
  end
  function TT.Heal(mode)
    local u, missing = TT.HealTarget()
    if not u then
      if On("setnotice") then TT.Say("Nobody needs a heal.") end
      return false
    end
    local name, rank = TT.PickHeal(mode, missing)
    if not name then return false end
    local text = rank and rank ~= "" and (name .. "(" .. rank .. ")") or name
    if _G.SUPERWOW_VERSION then
      CastSpellByName(text, u)
      return true
    end
    if UnitIsUnit(u, "target") then CastSpellByName(text) return true end
    local had = UnitExists("target")
    TargetUnit(u)
    CastSpellByName(text)
    if had then TargetLastTarget() else ClearTarget() end
    return true
  end

  -- messages ----------------------------------------------------------------
  function TT.Say(text, r, g, b)
    if TT.fake then return end
    if On("alerttext") and UIErrorsFrame then UIErrorsFrame:AddMessage(text, r or 1, g or .82, b or .2, 1, 3) end
    if On("alertchat") and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffOctoTotems|r " .. text) end
  end
  local function Sound()
    if On("alertsound") and PlaySoundFile then PlaySoundFile("Sound\\Interface\\RaidWarning.wav") end
  end

  -- buttons -----------------------------------------------------------------
  TT.bars = {}
  local function NewButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if pfUI.api.CreateBackdrop then pfUI.api.CreateBackdrop(b, nil, true) end
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(.08, .92, .08, .92)
    b.cd = CreateFrame("Model", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints(b.icon)
    b.over = CreateFrame("Frame", nil, b)
    b.over:SetAllPoints(b)
    b.over:SetFrameLevel(b:GetFrameLevel() + 3)
    b.edge = b.over:CreateTexture(nil, "OVERLAY")
    b.edge:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.edge:SetBlendMode("ADD")
    b.edge:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.edge:Hide()
    b.timer = b.over:CreateFontString(nil, "OVERLAY")
    b.timer:SetPoint("BOTTOM", b, "BOTTOM", 0, 2)
    b.cdtext = b.over:CreateFontString(nil, "OVERLAY")
    b.cdtext:SetPoint("CENTER", b, "CENTER", 0, 0)
    -- a font from the start: SetText on a font string with none raises "Font not set" (the reminder button is
    -- never painted by TT.PaintButton, 19 Nov 2026, Lobo)
    local font0 = pfUI.font_unit or pfUI.font_default or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    -- the game's font object first: if SetFont refuses a path, the text still has a font
    if b.timer.SetFontObject and GameFontNormalSmall then b.timer:SetFontObject(GameFontNormalSmall) b.cdtext:SetFontObject(GameFontNormalSmall) end
    b.timer:SetFont(font0, 12, "OUTLINE")
    b.cdtext:SetFont(font0, 14, "OUTLINE")
    b.mark = b.over:CreateTexture(nil, "OVERLAY")
    b.mark:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.mark:SetWidth(5) b.mark:SetHeight(5)
    b.mark:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
    b.mark:Hide()
    b.bar = b.over:CreateTexture(nil, "OVERLAY")
    b.bar:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 1)
    b.bar:SetHeight(2)
    b.bar:Hide()
    b:SetScript("OnClick", function() TT.Click(this, arg1) end)
    b:SetScript("OnEnter", function() TT.Enter(this) end)
    b:SetScript("OnLeave", function() TT.Leave(this) end)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function()
      if IsShiftKeyDown() and this.totem and TT.book[this.totem] and PickupSpell then
        local bk = TT.book[this.totem]
        PickupSpell(IsControlKeyDown() and bk.low or bk.id, BOOKTYPE_SPELL or "spell")
      end
    end)
    return b
  end
  TT.NewButton = NewButton

  local function ModDown(key)
    if key == "alt" then return IsAltKeyDown() end
    if key == "ctrl" then return IsControlKeyDown() end
    if key == "shift" then return IsShiftKeyDown() end
    return false
  end
  function TT.Click(b, button)
    if b.preview then if b.onPreview then b.onPreview(b, button) end return end
    if b.kind == "recall" then TT.Recall() return end
    if button == "RightButton" then TT.Menu(b) return end
    local name = b.totem
    if not name then return end
    if IsControlKeyDown() and On("ctrlset") then
      local set = TT.Cur()
      if set and not TT.InSet(set, name) then TT.PutInSet(set, name) TT.Refresh() end
    end
    TT.Cast(name, ModDown(S().rank1mod))
  end
  function TT.Enter(b)
    if b.bar0 then
      b.bar0.hoverAt = GetTime()
      b.bar0.hover = true
      if not b.preview then TT.LayoutBar(b.bar0.el) end
    end
    if not On("tooltip") or not b.totem then return end
    GameTooltip:SetOwner(b, S().tipside == "left" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
    local bk = TT.book[b.totem]
    if bk and GameTooltip.SetSpell then GameTooltip:SetSpell(bk.id, BOOKTYPE_SPELL or "spell")
    else GameTooltip:SetText(b.totem) end
    local set = TT.Cur()
    if set and TT.InSet(set, b.totem) then GameTooltip:AddLine("In the set: " .. set.name, 1, .82, 0) end
    if TT.advice and TT.advice[b.totem] then GameTooltip:AddLine("Advised: " .. TT.advice[b.totem] .. " of your group need it", .3, 1, .3) end
    GameTooltip:AddLine("Ctrl-click: put it in the set. Shift-drag: onto an action bar. Right-click: sets and options.", .6, .6, .6, 1)
    GameTooltip:Show()
  end
  function TT.Leave(b)
    GameTooltip:Hide()
    if b.bar0 then b.bar0.hover = false b.bar0.hoverAt = GetTime() end
  end

  function TT.Menu(anchor)
    local W = pfUI.octoui and pfUI.octoui.W
    if not W or not W.Menu then return end
    local items = { { label = "Totem sets", group = true } }
    local _, cur = TT.Cur()
    for i, s in ipairs(TT.Sets()) do
      table.insert(items, { key = i, label = (i == cur and "|cff55ff55> |r" or "   ") .. s.name })
    end
    table.insert(items, { key = "throw", label = "Throw the set" })
    table.insert(items, { key = "recall", label = "Totemic Recall" })
    table.insert(items, { key = "options", label = "Options..." })
    local m = W.Menu(anchor, items, 170, function(key)
      if key == "throw" then TT.ThrowSet()
      elseif key == "recall" then TT.Recall()
      elseif key == "options" then TT.Open("totembars")
      elseif type(key) == "number" then TT.UseSet(key) end
    end)
    if m and m.Show then m:Show() end
  end
  function TT.Open(key)
    local O = pfUI.octoui and pfUI.octoui.Options
    if O and O.Open and pfUI.gui then pfUI.gui:Show() O:Open(key or "totembars") end
  end

  -- paints one button for a totem now
  function TT.PaintButton(b, name, el, size, now)
    b.totem = name
    b:SetWidth(size) b:SetHeight(size)
    b.icon:SetTexture(TT.Icon(name))
    local font = pfUI.font_unit or pfUI.font_default or STANDARD_TEXT_FONT
    local fsig = font .. Num("timersize", 12)
    if b.fsig ~= fsig then
      b.fsig = fsig
      b.timer:SetFont(font, Num("timersize", 12), "OUTLINE")
      b.cdtext:SetFont(font, Num("timersize", 12) + 2, "OUTLINE")
    end
    local a = TT.Active(el)
    local active = a and a.name == name
    local er, eg, eb = TT.ElCol(el)
    -- timer text and bar
    if active and On("timers") then
      local left = a.left
      b.timer:SetText(left >= 60 and string.format("%d:%02d", math.floor(left / 60), math.mod(math.floor(left), 60)) or tostring(math.ceil(left)))
      if left <= Num("warn2", 5) then b.timer:SetTextColor(1, .25, .2)
      elseif left <= Num("warn1", 10) then b.timer:SetTextColor(1, .82, .2)
      else b.timer:SetTextColor(1, 1, 1) end
      if On("timerbar") and a.dur and a.dur > 0 then
        b.bar:SetWidth(math.max(1, (size - 2) * math.min(1, left / a.dur)))
        b.bar:SetVertexColor(er, eg, eb, 1)
        b.bar:Show()
      else b.bar:Hide() end
    else
      b.timer:SetText("")
      b.bar:Hide()
    end
    -- cooldown: swipe + red digits once its totem is gone
    local start, dur = TT.Cooldown(name)
    if On("cooldown") and start and start > 0 and dur and dur > 1.6 then
      if CooldownFrame_SetTimer then CooldownFrame_SetTimer(b.cd, start, dur, 1) end
      local left = start + dur - GetTime()
      if not active and On("cdtext") and left > 0 then b.cdtext:SetText(math.ceil(left)) b.cdtext:SetTextColor(1, .3, .3)
      else b.cdtext:SetText("") end
    else
      b.cd:Hide()
      b.cdtext:SetText("")
    end
    -- looks: active edge, out of range red, advised glow, set mark, no mana blue
    local usable, nomana = TT.Usable(name)
    if TT.fake then usable, nomana = true, false end
    if active and a.range == false then b.icon:SetVertexColor(1, .3, .3)
    elseif nomana then b.icon:SetVertexColor(.4, .5, 1)
    elseif not usable then b.icon:SetVertexColor(.4, .4, .4)
    else b.icon:SetVertexColor(1, 1, 1) end
    local edge = b.edge
    edge:SetWidth(size * 1.75) edge:SetHeight(size * 1.75)
    local advised = TT.advice and TT.advice[name]
    if advised then
      local p = .55 + .45 * math.abs(math.sin((now or GetTime()) * 4))
      edge:SetVertexColor(.3, 1, .3, p)
      edge:Show()
    elseif active and On("activeedge") then
      edge:SetVertexColor(er, eg, eb, .9)
      edge:Show()
    else
      edge:Hide()
    end
    local set = TT.Cur()
    if On("setmark") and TT.InSet(set, name) then
      b.mark:SetVertexColor(1, .82, .2, 1)
      b.mark:Show()
    else b.mark:Hide() end
    if b.backdrop and b.backdrop.SetBackdropBorderColor then
      if On("elementborder") then b.backdrop:SetBackdropBorderColor(er * .7, eg * .7, eb * .7, 1)
      else b.backdrop:SetBackdropBorderColor(0, 0, 0, 1) end
    end
  end

  -- the anchor totem of an element: active / set / first, per C.octototems.anchor
  function TT.Anchor(el, list)
    local mode = S().anchor or "active"
    local set = TT.Cur()
    local a = TT.Active(el)
    local inset = set and set["t" .. el] ~= "" and set["t" .. el]
    if inset and not TT.book[inset] and not TT.fake then inset = nil end
    if mode == "active" and a then return a.name end
    if (mode == "active" or mode == "set") and inset then return inset end
    return list[1]
  end

  -- what a bar shows, in order: { anchor, others... }
  function TT.BarList(el, hover, all)
    local list = TT.ElementTotems(el, all)
    local hidden = S().hide or {}
    local shown = {}
    for _, n in ipairs(list) do if not hidden[n] then table.insert(shown, n) end end
    local anchor = TT.Anchor(el, shown) or list[1]
    if not anchor then return {} end
    local out = { anchor }
    local mode = S()["mode_" .. TT.EL[el].key] or "flex"
    if mode == "hidden" then return {} end
    local static = Num("static", 1)
    for _, n in ipairs(shown) do
      if n ~= anchor then
        local a = TT.Active(el)
        local docked = On("dock") and ((a and a.name == n) or (TT.advice and TT.advice[n]) or TT.CooldownLeft(n) > 0)
        if mode == "open" or (mode == "flex" and (hover or table.getn(out) < static or docked)) or (mode == "closed" and docked) then
          table.insert(out, n)
        end
      end
    end
    return out
  end

  local DIRS = { up = { 0, 1 }, down = { 0, -1 }, left = { -1, 0 }, right = { 1, 0 } }
  function TT.LayoutBar(el, now)
    local bar = TT.bars[el]
    if not bar then return end
    TT.LayoutInto(bar, el, now)
  end
  -- lays a bar's buttons out on any frame (the real bars and the options preview); all = every totem of the data
  function TT.LayoutInto(bar, el, now, all, hover)
    local list = TT.BarList(el, hover or bar.hover or (bar.hoverAt and GetTime() - bar.hoverAt < Num("flexdelay", .6)), all)
    local size, gap = Num("size", 36), Num("spacing", 3)
    local d = DIRS[S()["dir_" .. TT.EL[el].key] or "up"] or DIRS.up
    bar.buttons = bar.buttons or {}
    for i, name in ipairs(list) do
      local b = bar.buttons[i]
      if not b then
        b = NewButton(bar)
        b.bar0 = bar
        bar.buttons[i] = b
      end
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", (i - 1) * (size + gap) * d[1], (i - 1) * (size + gap) * d[2])
      TT.PaintButton(b, name, el, size, now)
      b:Show()
    end
    for i = table.getn(list) + 1, table.getn(bar.buttons) do bar.buttons[i]:Hide() end
    bar:SetWidth(size) bar:SetHeight(size)
    bar.shown = table.getn(list)
    bar.list = list
    return list
  end

  -- the frames: pfOctoTotems (all four side by side) or one per element (pfOctoTotemFire...)
  local holder = CreateFrame("Frame", "pfOctoTotems", UIParent)
  holder:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
  holder:SetWidth(160) holder:SetHeight(36)
  TT.holder = holder
  local recall = NewButton(holder)
  recall.kind = "recall"
  TT.recall = recall
  for i, e in ipairs(TT.EL) do
    local f = CreateFrame("Frame", "pfOctoTotem" .. e.name, UIParent)
    f.el = i
    f:SetWidth(36) f:SetHeight(36)
    f:SetPoint("BOTTOM", UIParent, "BOTTOM", (i - 2.5) * 46, 240)
    TT.bars[i] = f
  end

  -- the elements left to right (C.octototems.barorder = "air,water,fire,earth"; 19 Nov 2026, Lobo): a list of TT.EL
  -- indexes, every element once (missing ones added at the end in the usual order)
  function TT.BarOrder()
    local out, seen = {}, {}
    for key in string.gfind(S().barorder or "", "[^,%s]+") do
      for i, e in ipairs(TT.EL) do
        if e.key == key and not seen[i] then seen[i] = true table.insert(out, i) end
      end
    end
    for i = 1, 4 do if not seen[i] then table.insert(out, i) end end
    return out
  end

  function TT.Place()
    local size, gap = Num("size", 36), Num("spacing", 3)
    local together = (S().layout or "together") == "together"
    local changed = TT.placed ~= S().layout
    TT.placed = S().layout
    local x = 0
    local order = TT.BarOrder()
    for k = 1, 4 do
      local i = order[k]
      local f = TT.bars[i]
      if together then
        if changed then
          f:SetParent(holder)
          if pfUI.api.RemoveMovable then pfUI.api.RemoveMovable(f) end
        end
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", x, 0)
        x = x + size + gap
      elseif changed then
        f:SetParent(UIParent)
        f:ClearAllPoints()
        f:SetPoint("BOTTOM", UIParent, "BOTTOM", (i - 2.5) * 46, 240)
        if UpdateMovable then UpdateMovable(f) end
      end
    end
    if On("recall") and (TT.book[TT.RECALL] or TT.fake) then
      recall:ClearAllPoints()
      if together then recall:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", x, 0) x = x + size + gap
      else recall:SetPoint("LEFT", TT.bars[order[4]], "RIGHT", gap, 0) end
      recall:SetWidth(size) recall:SetHeight(size)
      recall.icon:SetTexture(TT.Icon(TT.RECALL) ~= "Interface\\Icons\\INV_Misc_QuestionMark" and TT.Icon(TT.RECALL) or "Interface\\Icons\\Spell_Nature_Purge")
      recall:Show()
    else
      recall:Hide()
    end
    holder:SetWidth(math.max(size, x - gap))
    holder:SetHeight(size)
  end

  -- the shield / imbue reminder button
  local remind = NewButton(UIParent)
  remind.kind = "remind"
  TT.remind = remind
  remind:SetScript("OnClick", function() if this.spell then CastSpellByName(this.spell) end end)
  remind:SetPoint("BOTTOMRIGHT", holder, "TOPLEFT", -4, 4)
  remind:Hide()
  function TT.ShieldName()
    local want = S().shield or "auto"
    if want ~= "auto" and want ~= "" then return TT.book[want] and want or nil end
    for _, n in ipairs(TT.SHIELDS) do if TT.book[n] then return n end end
  end
  function TT.Reminders(buffs)
    local out = {}
    local shield = TT.ShieldName()
    if On("remindshield") and shield and not buffs[shield] then table.insert(out, { spell = shield, text = shield .. " is down" }) end
    if On("remindimbue") and GetWeaponEnchantInfo and GetInventoryItemLink("player", 16) then
      local has = GetWeaponEnchantInfo()
      if not has then
        local want = S().imbue or "auto"
        if want == "auto" or want == "" or not TT.book[want] then
          want = nil
          for _, n in ipairs(TT.IMBUES) do if TT.book[n] then want = n break end end
        end
        if want then table.insert(out, { spell = want, text = "No weapon imbue" }) end
      end
    end
    return out
  end

  -- what changed since the last tick -> alerts
  TT.state = {}
  function TT.Watch(now)
    for el = 1, 4 do
      local a = TT.Active(el)
      local st = TT.state[el] or {}
      if a then
        if st.name ~= a.name or st.start ~= a.start then st = { name = a.name, start = a.start } end
        local w1, w2 = Num("warn1", 10), Num("warn2", 5)
        if On("warn") and a.dur and a.dur > w1 + 2 and a.left <= w1 and not st.w1 then st.w1 = true TT.Say(a.name .. ": " .. w1 .. " s left") end
        if On("warn") and a.dur and a.dur > w2 + 2 and a.left <= w2 and not st.w2 then st.w2 = true TT.Say(a.name .. ": " .. w2 .. " s left", 1, .4, .2) Sound() end
        if On("rangealert") and a.range == false and not st.far then st.far = true TT.Say(a.name .. " is out of range", 1, .3, .3) end
        if a.range ~= false then st.far = nil end
        st.left = a.left
      elseif st.name then
        if (st.left or 0) > 1.5 then
          if On("destroyed") then TT.Say(st.name .. " was destroyed", 1, .25, .2) Sound() end
        elseif On("expired") then
          TT.Say(st.name .. " has run out", 1, .6, .2)
        end
        st = {}
      end
      TT.state[el] = st
    end
    -- every totem out of range -> recall reminder
    local any, far = false, true
    for el = 1, 4 do
      local a = TT.Active(el)
      if a then any = true if a.range ~= false then far = false end end
    end
    if any and far and On("recallremind") then
      if not TT.farAt then TT.farAt = now TT.Say("All your totems are out of range - recall them?", 1, .5, .2) end
    else
      TT.farAt = nil
    end
  end

  -- PvP sets: an enemy player's class picks its set; a set named like the target picks that
  function TT.Target()
    TT.override = nil
    if not UnitExists("target") then return end
    local name = UnitName("target")
    if On("namesets") and name then
      local i = TT.SetIndex(name)
      if i then TT.override = i return end
    end
    if On("pvpauto") and UnitIsPlayer("target") and UnitCanAttack("player", "target") then
      local _, c = UnitClass("target")
      local i = c and tonumber(S().pvp[c] or "")
      if i and TT.Sets()[i] then TT.override = i end
    end
  end

  -- Call of Elements itself loaded: ours stands aside (its bars and ours would both answer the same keys)
  TT.aside = IsAddOnLoaded and IsAddOnLoaded("CallOfElements") and true or false
  function TT.Reapply()
    local r = TT.reminders and TT.reminders[1]
    if r then CastSpellByName(r.spell) return true end
    return false
  end
  function TT.Wanted()
    if not On("enable") or not TT.shaman or TT.aside then return false end
    if On("hideooc") and not (UnitAffectingCombat and UnitAffectingCombat("player")) then
      for el = 1, 4 do if TT.Active(el) then return true end end
      return false
    end
    return true
  end

  function TT.Refresh(now)
    now = now or GetTime()
    -- (19 Nov 2026) a running demo (modules/demo.lua) shows the sample bars too
    local layout = (pfUI.unlock and pfUI.unlock.IsShown and pfUI.unlock:IsShown()) or (pfUI.demo and pfUI.demo.ShowSamples and pfUI.demo.ShowSamples())
    TT.Place()
    local show = TT.Wanted() or (layout and On("enable"))
    local together = (S().layout or "together") == "together"
    holder:SetScale(Num("scale", 1))
    holder:SetAlpha(Num("alpha", 1))
    if not show then
      holder:Hide()
      for i = 1, 4 do TT.bars[i]:Hide() end
      remind:Hide()
      return
    end
    holder:Show()
    -- layout mode on a character with no totems (or not a shaman): made-up bars so the boxes have a size
    local sample = layout and not TT.Wanted()
    for i = 1, 4 do
      TT.bars[i]:Show()
      if not together then TT.bars[i]:SetScale(Num("scale", 1)) TT.bars[i]:SetAlpha(Num("alpha", 1)) end
      if sample then
        TT.fake = TT.Sample(now)
        pcall(TT.LayoutInto, TT.bars[i], i, now, true)
        TT.fake = nil
      else
        TT.LayoutBar(i, now)
      end
    end
    if recall:IsShown() then
      local p = TT.farAt and (.55 + .45 * math.abs(math.sin(now * 4))) or nil
      if p then recall.edge:SetVertexColor(1, .5, .2, p) recall.edge:SetWidth(Num("size", 36) * 1.75) recall.edge:SetHeight(Num("size", 36) * 1.75) recall.edge:Show()
      else recall.edge:Hide() end
    end
    local list = TT.reminders or {}
    if list[1] and On("remindbutton") then
      remind.spell = list[1].spell
      remind:SetWidth(Num("size", 36)) remind:SetHeight(Num("size", 36))
      remind.icon:SetTexture(TT.Icon(list[1].spell))
      remind.edge:SetVertexColor(1, .3, .3, .55 + .45 * math.abs(math.sin(now * 4)))
      remind.edge:SetWidth(Num("size", 36) * 1.75) remind.edge:SetHeight(Num("size", 36) * 1.75)
      remind.edge:Show()
      remind.timer:SetText("")
      remind:Show()
    else
      remind:Hide()
    end
  end

  if UpdateMovable then UpdateMovable(holder) end

  -- a made-up state for the options preview: TT.Fake(now) fills TT.fake / TT.advice for one paint
  function TT.Sample(now)
    local t = math.mod(now or GetTime(), 30)
    return {
      [1] = { name = "Searing Totem", start = 0, dur = 55, left = 55 - t * 1.5, range = true },
      [2] = { name = "Stoneskin Totem", start = 0, dur = 120, left = 120 - t, range = true },
      [3] = t > 12 and { name = "Healing Stream Totem", start = 0, dur = 60, left = 60 - t, range = t < 24 } or nil,
      [4] = { name = "Windfury Totem", start = 0, dur = 120, left = 9 - math.mod(t, 9) + .5, range = true },
    }
  end

  -- the options preview: four bars + recall on `box` from the made-up state, every totem of the data shown
  function TT.Preview(box, now, hover)
    box.pbars = box.pbars or {}
    local keepAdvice, keepFake = TT.advice, TT.fake
    TT.fake = TT.Sample(now)
    TT.advice = On("advisor") and { ["Poison Cleansing Totem"] = 1 } or {}
    local size, gap = Num("size", 36), Num("spacing", 3)
    local x = 0
    local order = TT.BarOrder()
    local ok, err = pcall(function()
      for k = 1, 4 do
        local el = order[k]
        local f = box.pbars[el]
        if not f then
          f = CreateFrame("Frame", nil, box)
          f.el = el
          box.pbars[el] = f
        end
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", x, 0)
        local list = TT.LayoutInto(f, el, now, true, hover == el)
        for i = 1, table.getn(list) do
          local b = f.buttons[i]
          b.preview = true
          b.onPreview = box.onPreview
          b.pel = el
        end
        x = x + size + gap
      end
    end)
    TT.fake, TT.advice = keepFake, keepAdvice
    box:SetWidth(math.max(size, x - gap))
    box:SetHeight(size)
    return ok, err
  end

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_AURAS_CHANGED", "PLAYER_TARGET_CHANGED", "PLAYER_TOTEM_UPDATE" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then TT.Scan() TT.healamt = {} end
    if event == "PLAYER_AURAS_CHANGED" then TT.names = {} end
    if event == "PLAYER_TARGET_CHANGED" then TT.Target() end
    this.tick = 0
  end)
  ev:SetScript("OnUpdate", function()
    if (this.tick or 0) > GetTime() then return end
    this.tick = GetTime() + .1
    if not TT.shaman then
      if pfUI.unlock and pfUI.unlock.IsShown and pfUI.unlock:IsShown() and On("enable") then TT.Refresh() else
        holder:Hide() for i = 1, 4 do TT.bars[i]:Hide() end
        this.tick = GetTime() + 2
      end
      return
    end
    local now = GetTime()
    TT.buffs = TT.Buffs()
    if (this.slow or 0) <= now then
      this.slow = now + .5
      TT.advice = TT.Advice()
      TT.reminders = TT.Reminders(TT.buffs)
      local list = TT.reminders
      for _, r in ipairs(list) do
        TT.remindAt = TT.remindAt or {}
        if (TT.remindAt[r.spell] or 0) < now and (On("remindooc") or (UnitAffectingCombat and UnitAffectingCombat("player"))) then
          TT.remindAt[r.spell] = now + Num("remindevery", 30)
          TT.Say(r.text, 1, .35, .35)
          if On("remindsound") and PlaySoundFile then PlaySoundFile("Sound\\Interface\\RaidWarning.wav") end
        end
      end
      for name, n in pairs(TT.advice) do
        TT.adviceAt = TT.adviceAt or {}
        if (TT.adviceAt[name] or 0) < now then
          TT.adviceAt[name] = now + 10
          TT.Say(name .. " advised (" .. n .. ")", .3, 1, .3)
        end
      end
    end
    TT.Watch(now)
    TT.Refresh(now)
  end)

  -- slash + bindings ----------------------------------------------------------
  _G.BINDING_HEADER_PFTOTEMS = "pfUI Octo: OctoTotems"
  _G.BINDING_NAME_PFTOTEMSET = "Throw the totem set"
  _G.BINDING_NAME_PFTOTEMSETFORCE = "Throw the whole set again"
  _G.BINDING_NAME_PFTOTEMADVISED = "Throw the advised totem"
  _G.BINDING_NAME_PFTOTEMNEXTSET = "Next totem set"
  _G.BINDING_NAME_PFTOTEMPRIORSET = "Previous totem set"
  _G.BINDING_NAME_PFTOTEMRECALL = "Totemic Recall"
  _G.BINDING_NAME_PFTOTEMBATTLEHEAL = "Battle heal (fast, most hurt)"
  _G.BINDING_NAME_PFTOTEMBESTHEAL = "Best heal (efficient, most hurt)"
  _G.BINDING_NAME_PFTOTEMSHIELD = "Put the shield / imbue back on"

  function TT.Slash(msg)
    msg = msg or ""
    local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
    cmd = string.lower(cmd or "")
    if cmd == "" or cmd == "config" then TT.Open("totembars")
    elseif cmd == "throwset" then TT.ThrowSet(rest)
    elseif cmd == "forcethrowset" then TT.ThrowSet(rest, true)
    elseif cmd == "advised" then TT.ThrowAdvised()
    elseif cmd == "nextset" then TT.NextSet(1)
    elseif cmd == "priorset" then TT.NextSet(-1)
    elseif cmd == "set" then if not TT.UseSet(rest) then TT.Say("No set called " .. rest) end
    elseif cmd == "restartset" then TT.Restart()
    elseif cmd == "reset" then TT.Restart() TT.state = {} TT.override = nil
    elseif cmd == "recall" then TT.Recall()
    elseif cmd == "heal" or cmd == "battleheal" then TT.Heal("battle")
    elseif cmd == "bestheal" then TT.Heal("best")
    elseif cmd == "resetframes" then
      for _, f in ipairs({ holder, TT.bars[1], TT.bars[2], TT.bars[3], TT.bars[4] }) do
        if C.position then C.position[f:GetName()] = nil end
      end
      holder:ClearAllPoints() holder:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
      TT.Refresh()
    elseif cmd == "reload" then TT.Scan() TT.Refresh()
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffOctoTotems|r /totems [config | throwset [set] | forcethrowset | advised | nextset | priorset | set <name> | restartset | reset | recall | battleheal | bestheal | resetframes | reload]")
    end
  end
  _G.SLASH_PFTOTEMS1 = "/totems"
  _G.SLASH_PFTOTEMS2 = "/octototems"
  _G.SlashCmdList.PFTOTEMS = TT.Slash
  if not (IsAddOnLoaded and IsAddOnLoaded("CallOfElements")) then
    _G.SLASH_PFTOTEMSCOE1 = "/coe"
    _G.SlashCmdList.PFTOTEMSCOE = TT.Slash
  end

  TT.Scan()
end)
