pfUI:RegisterModule("honor", "vanilla", function ()
  -- pfUI Octo :: Honor (23 Nov 2026). User, with OctoWoW's Honor tab, ERROR's 0-100 rank bar and
  -- TurtleHonorSpyEnhanced: "make this page ... up to date ... merge this info it gets into the honor window all in
  -- one", then "make it look amazing like PvP use art ... battle and worn".
  -- TurtleHonorSpyEnhanced (Citrin) has no licence: its feature list only, written fresh. OctoWoW's Honor tab is
  -- Turtle WoW's (FrameXML HonorFrame, server prefix TW_HONOR): rank % moves live in steps of 1/255 as honor comes
  -- in, a week holds 20 000 honor (seen in HonorSpy's records) and resets on Wednesday 00:00 UTC.
  --   tracker  every honor gain from the chat lines (kills, awards, quest turn-ins), battleground wins / losses and
  --            each step of rank %, per character in pfUI_cache.honor["realm^name"]; HonorSpy's own records are copied
  --            in once when it is loaded (HN.Import)
  --   page     the game's Honor tab drawn again over its own: rank and badge, the server's honor points, a big rank
  --            progress bar (0 / 25 / 50 / 75 / 100, today's gain lit), honor still needed for the next rank (learnt
  --            from your own records), the week's honor against the cap with the reset countdown, the game's numbers
  --            and the last days. The Arena tab and the server's honor points message are left alone.
  -- Settings C.honor; options Quality of Life > Honor (honor-options.lua); /honor.
  local HN = { STEPS = 255, WEEK = 604800, FIRST_WED = 518400 }
  pfUI.honor = HN
  local function G() return C.honor end
  local floor = math.floor

  -- ---------------------------------------------------------------- numbers

  function HN.Fmt(n)
    n = floor((tonumber(n) or 0) + .5)
    local s = tostring(math.abs(n))
    local out = ""
    while string.len(s) > 3 do
      out = " " .. string.sub(s, -3) .. out
      s = string.sub(s, 1, -4)
    end
    return (n < 0 and "-" or "") .. s .. out
  end
  -- the start of this honor week (Wednesday 00:00 UTC), and seconds until the next
  function HN.WeekStart(now)
    now = now or time()
    return HN.FIRST_WED + floor((now - HN.FIRST_WED) / HN.WEEK) * HN.WEEK
  end
  function HN.ResetIn(now)
    now = now or time()
    return HN.WeekStart(now) + HN.WEEK - now
  end
  function HN.Span(secs)
    secs = math.max(0, floor(secs or 0))
    local d, h, m = floor(secs / 86400), floor(math.mod(secs, 86400) / 3600), floor(math.mod(secs, 3600) / 60)
    if d > 0 then return d .. "d " .. h .. "h" end
    if h > 0 then return h .. "h " .. m .. "m" end
    return m .. "m"
  end
  function HN.Day(t) return date("%Y-%m-%d", t or time()) end
  -- the page's number columns: label / day on the left, four columns right-aligned to these edges
  -- (x from the page's left; w = the page's width)
  function HN.ColX(w, c)
    local left, label = 14, 78
    return floor(left + label + c * (w - left * 2 - label) / 4 + .5)
  end
  HN.DASH = "|cff6e6659-|r"
  -- a count, or a grey dash for none
  function HN.Num(v)
    v = tonumber(v) or 0
    if v == 0 then return HN.DASH end
    return HN.Fmt(v)
  end
  -- a change with its sign: green up, red down, grey none
  function HN.Signed(v, unit)
    v = tonumber(v) or 0
    if math.abs(v) < .005 then return "|cff8c8478" .. "0.00" .. (unit or "") .. "|r" end
    if v > 0 then return "|cff73ff73+" .. string.format("%.2f", v) .. (unit or "") .. "|r" end
    return "|cffff6659" .. string.format("%.2f", v) .. (unit or "") .. "|r"
  end
  -- a frame's width from its edges (seen in game 23 Nov 2026: GetWidth of a frame sized only by its anchors came
  -- back far too small on this client, and the 0-100 scale, the marks and the table were squeezed to the left)
  function HN.Wid(f, fallback)
    local l, r = f:GetLeft(), f:GetRight()
    if l and r and r - l > 1 then return r - l end
    local w = f:GetWidth()
    if w and w > 1 then return w end
    return fallback or 0
  end

  -- ---------------------------------------------------------------- records

  -- this character's records: { log = { entries, oldest first }, weeks = { [weekStart] = honor }, day, week }
  -- entry: t, k = kill | award | turnin | bg | tick, h = honor, n = victim, vr = victim's rank, z = zone,
  --        r = your rank id, p = rank % (0..1), w = 1 won / 0 lost (bg)
  function HN.Key() return (GetRealmName() or "?") .. "^" .. (UnitName("player") or "?") end
  function HN.Store()
    pfUI_cache.honor = pfUI_cache.honor or {}
    local k = HN.Key()
    local s = pfUI_cache.honor[k]
    if not s then
      s = { log = {}, weeks = {} }
      pfUI_cache.honor[k] = s
    end
    s.log = s.log or {}
    s.weeks = s.weeks or {}
    return s
  end
  function HN.Rank()
    local r = UnitPVPRank and UnitPVPRank("player") or 0
    local p = GetPVPRankProgress and GetPVPRankProgress() or 0
    return tonumber(r) or 0, tonumber(p) or 0
  end
  function HN.Add(e)
    local s = HN.Store()
    e.t = e.t or time()
    if not e.r then e.r, e.p = HN.Rank() end
    if not e.z and e.k ~= "tick" then e.z = GetRealZoneText and GetRealZoneText() or nil end
    table.insert(s.log, e)
    HN.Prune(s)
    if HN.onAdd then HN.onAdd(e) end
    return e
  end
  -- old records go (C.honor.keepdays), and never more than 8000
  function HN.Prune(s)
    local log = s.log
    local keep = (tonumber(G().keepdays) or 60) * 86400
    local cut = time() - keep
    local n = table.getn(log)
    local drop = 0
    while drop < n and (log[drop + 1].t or 0) < cut do drop = drop + 1 end
    if n - drop > 8000 then drop = n - 8000 end
    if drop > 0 then
      local out = {}
      for i = drop + 1, n do table.insert(out, log[i]) end
      s.log = out
    end
  end

  -- ---------------------------------------------------------------- reading the chat

  -- "Name dies, honorable kill Rank: Knight-Champion  (Estimated Honor Points: 12)"
  function HN.ParseKill(msg)
    local _, _, v, r, n = string.find(msg or "", "^(.+) dies, honorable kill Rank: ([^%(]+)%(Estimated Honor Points: (%d+)%)")
    if v then
      r = string.gsub(r, "%s+$", "")
      return v, r, tonumber(n)
    end
  end
  -- "You have been awarded 25 honor points." / "You gain 25 honor"
  function HN.ParseAward(msg)
    local l = string.lower(msg or "")
    local _, _, a = string.find(l, "awarded (%d+) honor")
    if not a then _, _, a = string.find(l, "you gain (%d+) honor") end
    return a and tonumber(a) or nil
  end
  -- a battleground's end: 1 won, 0 lost, nil not an end line
  function HN.ParseResult(msg, faction)
    local l = string.lower(msg or "")
    local won = string.find(l, "wins") or string.find(l, "victor") or string.find(l, "conquer")
    if not won then return nil end
    local horde, alliance = string.find(l, "horde"), string.find(l, "alliance")
    if not horde and not alliance then return nil end
    faction = string.lower(faction or "")
    if (horde and faction == "horde") or (alliance and faction == "alliance") then return 1 end
    return 0
  end
  local function InBG()
    if pfUI.context and pfUI.context.Zone then
      local z = pfUI.context.Zone()
      if z == "bg" or z == "arena" then return true end
    end
    for i = 1, (MAX_BATTLEFIELD_QUEUES or 3) do
      local st = GetBattlefieldStatus and GetBattlefieldStatus(i)
      if st == "active" then return true end
    end
    return false
  end
  HN.InBG = InBG

  HN.quest = 0     -- a quest was handed in just now: the next award is a turn-in
  HN.lastAward = nil
  HN.lastResult = 0
  function HN.OnChat(ev, msg)
    if ev == "CHAT_MSG_COMBAT_HONOR_GAIN" then
      local v, r, n = HN.ParseKill(msg)
      if v then
        HN.Add({ k = "kill", n = v, vr = r, h = n or 0, bg = InBG() and 1 or nil })
        return true
      end
    end
    if ev == "CHAT_MSG_COMBAT_HONOR_GAIN" or ev == "CHAT_MSG_SYSTEM" then
      local a = HN.ParseAward(msg)
      if a then
        -- (the same award can come as both lines: once)
        local now = GetTime()
        if HN.lastAward and HN.lastAward[1] == a and now - HN.lastAward[2] < 2 then return true end
        HN.lastAward = { a, now }
        local turnin = now - (HN.quest or 0) < 4
        HN.Add({ k = turnin and "turnin" or "award", h = a, bg = InBG() and 1 or nil })
        return true
      end
    end
    if string.find(ev, "^CHAT_MSG_BG_SYSTEM") then
      local w = HN.ParseResult(msg, UnitFactionGroup("player"))
      if w and time() - (HN.lastResult or 0) > 60 then
        HN.lastResult = time()
        HN.Add({ k = "bg", w = w, h = 0 })
        return true
      end
    end
  end
  -- rank % moved: one "tick" record (the rate the next-rank guess learns from)
  function HN.CheckTick()
    local s = HN.Store()
    local r, p = HN.Rank()
    if s.lastR ~= r or math.abs((s.lastP or -1) - p) > .0001 then
      if s.lastR then HN.Add({ k = "tick", h = 0, r = r, p = p, pr = s.lastR, pp = s.lastP }) end
      s.lastR, s.lastP = r, p
    end
  end
  -- where today and this week started (rank and %), and the week's honor as the game reports it
  function HN.Baselines()
    local s = HN.Store()
    local r, p = HN.Rank()
    local today, week = HN.Day(), HN.WeekStart()
    if not s.day or s.day.d ~= today then s.day = { d = today, r = r, p = p } end
    if not s.week or s.week.w ~= week then s.week = { w = week, r = r, p = p } end
    local _, wh = 0, 0
    if GetPVPThisWeekStats then _, wh = GetPVPThisWeekStats() end
    wh = tonumber(wh) or 0
    if wh > (s.weeks[week] or 0) then s.weeks[week] = wh end
    return s
  end

  -- ---------------------------------------------------------------- what the records say

  local GAIN = { kill = true, award = true, turnin = true }
  -- honor per 1/255 step of rank % at rank r, from your own records (nil while too few steps are known)
  function HN.Rate(r, log)
    log = log or HN.Store().log
    local honor, steps, acc, lastR, lastP = 0, 0, 0, nil, nil
    for _, e in ipairs(log) do
      if GAIN[e.k] then acc = acc + (e.h or 0) end
      if e.r and e.p then
        if lastR == e.r and lastP and e.p > lastP + .0001 then
          local st = floor((e.p - lastP) * HN.STEPS + .5)
          if e.r == r and st > 0 and acc > 0 then honor, steps = honor + acc, steps + st end
          acc = 0
        elseif lastR and lastR ~= e.r then
          -- (a new rank: what came before counted for the old one)
          acc = 0
        end
        lastR, lastP = e.r, e.p
      end
    end
    if steps < 8 then return nil, steps end
    return honor / steps, steps
  end
  -- honor still needed for the next rank (nil while it is learning), and the next rank's name
  function HN.ToNext()
    local r, p = HN.Rank()
    local nextName = GetPVPRankInfo and GetPVPRankInfo(r + 1)
    if not nextName or r <= 0 then return nil, nil end
    local rate = HN.Rate(r)
    if not rate then return nil, nextName end
    return (1 - p) * HN.STEPS * rate, nextName
  end
  -- today's and this week's gain in rank % points (a rank up counts as 100)
  function HN.Gains()
    local s = HN.Baselines()
    local r, p = HN.Rank()
    local function D(b) return b and ((r + p) - (b.r + b.p)) * 100 or 0 end
    return D(s.day), D(s.week)
  end
  -- honor in the records since time t
  function HN.HonorSince(t, log)
    local sum = 0
    for _, e in ipairs(log or HN.Store().log) do
      if (e.t or 0) >= t and GAIN[e.k] then sum = sum + (e.h or 0) end
    end
    return sum
  end
  -- the last n days with anything in them, newest first:
  -- { d, honor, kills, won, lost, bgh, world, quest, award, gain }
  function HN.Days(n, log)
    log = log or HN.Store().log
    local by, order = {}, {}
    for _, e in ipairs(log) do
      local d = HN.Day(e.t)
      local x = by[d]
      if not x then
        x = { d = d, t = e.t, honor = 0, kills = 0, won = 0, lost = 0, bgh = 0, world = 0, quest = 0, award = 0 }
        by[d] = x
        table.insert(order, x)
      end
      if GAIN[e.k] then
        local h = e.h or 0
        x.honor = x.honor + h
        if e.k == "turnin" then x.quest = x.quest + h
        elseif e.bg then x.bgh = x.bgh + h
        elseif e.k == "kill" then x.world = x.world + h
        else x.award = x.award + h end
      end
      if e.k == "kill" then x.kills = x.kills + 1 end
      if e.k == "bg" then if e.w == 1 then x.won = x.won + 1 else x.lost = x.lost + 1 end end
      if e.r and e.p then
        if not x.r0 then x.r0, x.p0 = e.r, e.p end
        x.r1, x.p1 = e.r, e.p
      end
    end
    -- newest day first (records copied in from HonorSpy may sit out of order)
    table.sort(order, function(a, b) return a.d > b.d end)
    local out = {}
    for i = 1, table.getn(order) do
      local x = order[i]
      x.gain = x.r0 and ((x.r1 + x.p1) - (x.r0 + x.p0)) * 100 or 0
      table.insert(out, x)
      if table.getn(out) >= (n or 7) then break end
    end
    return out
  end

  -- ---------------------------------------------------------------- HonorSpy's records, once

  -- TurtleHonorSpyEnhanced keeps one history per realm and faction (HonorSpyDB.realms["Realm - Faction"].hs);
  -- copied into this character's records the first time it is seen loaded. Its own records are left as they are.
  function HN.Import(force)
    local s = HN.Store()
    if s.imported and not force then return 0 end
    local db = _G.HonorSpyDB
    local key = (GetRealmName() or "?") .. " - " .. (UnitFactionGroup("player") or "?")
    local hs = db and db.realms and db.realms[key] and db.realms[key].hs
    if not hs or type(hs.honorHistory) ~= "table" then return 0 end
    local have = {}
    for _, e in ipairs(s.log) do have[(e.t or 0) .. (e.k or "") .. (e.h or 0) .. (e.n or "")] = true end
    local add = {}
    local KIND = { kill = "kill", award = "award", turnin = "turnin", bgresult = "bg", tick = "tick" }
    local BGS = { ["Warsong Gulch"] = true, ["Arathi Basin"] = true, ["Alterac Valley"] = true }
    for _, x in pairs(hs.honorHistory) do
      local k = type(x) == "table" and KIND[x.type or ""]
      if k and x.t then
        local e = { t = x.t, k = k, h = tonumber(x.amount) or 0, n = x.victim, vr = x.victimRank, z = x.zone,
          r = x.rankNum, p = x.rankPct }
        if k == "bg" then e.w = (x.result == "win") and 1 or 0 end
        if x.zone and BGS[x.zone] then e.bg = 1 end
        local id = e.t .. e.k .. e.h .. (e.n or "")
        if not have[id] then have[id] = true table.insert(add, e) end
      end
    end
    for _, e in ipairs(add) do table.insert(s.log, e) end
    table.sort(s.log, function(a, b) return (a.t or 0) < (b.t or 0) end)
    if type(hs.weekApiHonor) == "table" then
      for w, h in pairs(hs.weekApiHonor) do
        local wk, hv = tonumber(w), tonumber(h)
        if wk and hv and hv > (s.weeks[wk] or 0) then s.weeks[wk] = hv end
      end
    end
    s.imported = time()
    HN.Prune(s)
    return table.getn(add)
  end

  -- ---------------------------------------------------------------- events

  local ev = CreateFrame("Frame", "pfHonorTracker")
  HN.events = ev
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "CHAT_MSG_COMBAT_HONOR_GAIN", "CHAT_MSG_SYSTEM", "CHAT_MSG_BG_SYSTEM_NEUTRAL",
    "CHAT_MSG_BG_SYSTEM_ALLIANCE", "CHAT_MSG_BG_SYSTEM_HORDE", "PLAYER_PVP_RANK_CHANGED", "PLAYER_PVP_KILLS_CHANGED",
    "UPDATE_FACTION", "QUEST_COMPLETE" }) do ev:RegisterEvent(e) end
  -- (not on every client: no error when it is missing)
  pcall(ev.RegisterEvent, ev, "QUEST_TURNED_IN")
  ev:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
      HN.ready = true
      if not HN.sessionAt then
        HN.sessionAt = time()
        local _, wh = 0, 0
        if GetPVPThisWeekStats then _, wh = GetPVPThisWeekStats() end
        HN.sessionHonor = tonumber(wh) or 0
        HN.sessionWeek = HN.WeekStart()
      end
      if G().import ~= "0" then
        local n = HN.Import()
        if n > 0 then
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r honor: copied " .. n .. " records from HonorSpy - its history is on your Honor tab now.")
        end
      end
      HN.Baselines()
      HN.CheckTick()
    elseif not HN.ready then
      return
    elseif event == "QUEST_COMPLETE" or event == "QUEST_TURNED_IN" then
      HN.quest = GetTime()
    elseif event == "PLAYER_PVP_RANK_CHANGED" or event == "UPDATE_FACTION" or event == "PLAYER_PVP_KILLS_CHANGED" then
      HN.CheckTick()
      HN.Baselines()
    else
      HN.OnChat(event, arg1)
    end
    if HN.page and HN.page:IsVisible() and HN.Paint then HN.Paint() end
  end)

  _G.SLASH_PFHONOR1 = "/honor"
  _G.SlashCmdList.PFHONOR = function(msg)
    if msg == "import" then
      local n = HN.Import(true)
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r honor: " .. (n > 0 and ("copied " .. n .. " records from HonorSpy.")
        or "nothing new to copy (HonorSpy must be loaded)."))
      return
    end
    if ToggleCharacter then ToggleCharacter("HonorFrame") end
  end

  -- ---------------------------------------------------------------- the page

  local ART = "img:honor\\"
  -- the bar colour: faction (Horde red / Alliance blue), class, accent or your own
  function HN.BarColor()
    local mode = G().barcolor or "faction"
    if mode == "class" then
      local _, class = UnitClass("player")
      local c = class and RAID_CLASS_COLORS[class]
      if c then return c.r, c.g, c.b end
    elseif mode == "accent" and GetAccentColor then
      return GetAccentColor()
    elseif mode == "custom" then
      local r, g, b = GetStringColor(G().barcustom or "0.7,0.1,0.08,1")
      return tonumber(r) or .7, tonumber(g) or .1, tonumber(b) or .08
    end
    if UnitFactionGroup("player") == "Alliance" then return .16, .4, .9 end
    return .78, .12, .08
  end
  local BRONZE = { .86, .68, .38 }
  local function Font(fs, size, flags, num)
    fs:SetFont(num and (pfUI.font_unit or pfUI.font_default) or pfUI.font_default, size, flags or "OUTLINE")
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    return fs
  end
  local function Text(parent, size, r, g, b, justify, num)
    local fs = Font(parent:CreateFontString(nil, "OVERLAY"), size, "OUTLINE", num)
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetJustifyH(justify or "LEFT")
    return fs
  end
  local function Tex(parent, layer, path, r, g, b, a)
    local t = parent:CreateTexture(nil, layer)
    if path then t:SetTexture(path) end
    if r then t:SetVertexColor(r, g, b, a or 1) end
    return t
  end
  -- a worn, scratched strip of a heading: CAPITALS in bronze with a fading rule after it
  -- rsize: a text on the right end of the line (the rule stops before it)
  local function Heading(parent, text, y, rsize)
    local h = Text(parent, 10, BRONZE[1], BRONZE[2], BRONZE[3])
    h:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    h:SetText(string.upper(text))
    local rt
    if rsize then
      rt = Text(parent, rsize, 1, 1, 1, "RIGHT", true)
      rt:SetPoint("RIGHT", parent, "TOPRIGHT", -14, y - 6)
    end
    local rule = Tex(parent, "ARTWORK", "Interface\\Buttons\\WHITE8X8")
    rule:SetHeight(1)
    rule:SetPoint("LEFT", h, "RIGHT", 6, 0)
    if rt then rule:SetPoint("RIGHT", rt, "LEFT", -8, 0) else rule:SetPoint("RIGHT", parent, "RIGHT", -12, 0) end
    rule:SetGradientAlpha("HORIZONTAL", BRONZE[1], BRONZE[2], BRONZE[3], .55, BRONZE[1], BRONZE[2], BRONZE[3], 0)
    return h, rule, rt
  end

  -- a bar made of worn metal: back, fill (two parts: before today / today's gain), ticks, spark, text
  function HN.NewBar(parent, h, ticks)
    local b = CreateFrame("Frame", nil, parent)
    b:SetHeight(h)
    b.back = Tex(b, "BACKGROUND", "Interface\\Buttons\\WHITE8X8", .03, .02, .02, .85)
    b.back:SetAllPoints(b)
    b.groove = Tex(b, "BORDER", pfUI.media[ART .. "bar"], .18, .15, .13, .9)
    b.groove:SetAllPoints(b)
    b.fill = Tex(b, "ARTWORK", pfUI.media[ART .. "bar"])
    b.fill:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.fill:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.gain = Tex(b, "ARTWORK", pfUI.media[ART .. "bar"])
    b.gain:SetPoint("TOPLEFT", b.fill, "TOPRIGHT", 0, 0)
    b.gain:SetPoint("BOTTOMLEFT", b.fill, "BOTTOMRIGHT", 0, 0)
    b.spark = Tex(b, "OVERLAY", pfUI.media[ART .. "spark"], 1, .85, .6, .8)
    b.spark:SetBlendMode("ADD")
    b.spark:SetWidth(h * 1.6)
    b.spark:SetHeight(h * 2.2)
    -- a dark edge and a faint bronze line inside it
    b.edge = {}
    for i = 1, 4 do b.edge[i] = Tex(b, "OVERLAY", "Interface\\Buttons\\WHITE8X8", 0, 0, 0, 1) end
    b.edge[1]:SetPoint("BOTTOMLEFT", b, "TOPLEFT", -1, 0) b.edge[1]:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT", 1, 0) b.edge[1]:SetHeight(1)
    b.edge[2]:SetPoint("TOPLEFT", b, "BOTTOMLEFT", -1, 0) b.edge[2]:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 1, 0) b.edge[2]:SetHeight(1)
    b.edge[3]:SetPoint("TOPRIGHT", b, "TOPLEFT", 0, 0) b.edge[3]:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", 0, 0) b.edge[3]:SetWidth(1)
    b.edge[4]:SetPoint("TOPLEFT", b, "TOPRIGHT", 0, 0) b.edge[4]:SetPoint("BOTTOMLEFT", b, "BOTTOMRIGHT", 0, 0) b.edge[4]:SetWidth(1)
    b.shine = Tex(b, "OVERLAY", "Interface\\Buttons\\WHITE8X8")
    b.shine:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.shine:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
    b.shine:SetHeight(1)
    b.shine:SetVertexColor(BRONZE[1], BRONZE[2], BRONZE[3], .35)
    b.marks = {}
    if ticks then
      -- the quarters tall and glowing, the eighths short (the ERROR bar's marks)
      for i = 1, 7 do
        local m = Tex(b, "OVERLAY", pfUI.media[ART .. "tick"])
        m:SetBlendMode("ADD")
        local big = math.mod(i, 2) == 0
        m:SetWidth(big and 10 or 8)
        m:SetHeight(big and h + 8 or h * .55)
        m:SetVertexColor(1, .95, .85, big and .9 or .5)
        m.at = i / 8
        m.big = big
        table.insert(b.marks, m)
      end
    end
    b.text = Text(b, h >= 18 and 13 or 10, 1, 1, 1, "CENTER", true)
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    -- v = the part before today, g = today's gain (lit brighter), coloured r1, g1, b1
    function b:Set(v, g, r1, g1, b1)
      local w = HN.Wid(self, 0)
      v = math.max(0, math.min(1, v or 0))
      g = math.max(0, math.min(1 - v, g or 0))
      r1, g1, b1 = r1 or .78, g1 or .12, b1 or .08
      self.fill:SetWidth(math.max(.01, w * v))
      self.fill:SetGradient("HORIZONTAL", r1 * .45, g1 * .45, b1 * .45, r1, g1, b1)
      if v <= 0 then self.fill:Hide() else self.fill:Show() end
      self.gain:SetWidth(math.max(.01, w * g))
      self.gain:SetVertexColor(math.min(1, r1 * .6 + .5), math.min(1, g1 * .6 + .42), math.min(1, b1 * .6 + .2), 1)
      if g <= 0 then self.gain:Hide() else self.gain:Show() end
      self.spark:ClearAllPoints()
      self.spark:SetPoint("CENTER", self, "LEFT", w * (v + g), 0)
      if v + g > .005 and v + g < .995 then self.spark:Show() else self.spark:Hide() end
      for _, m in ipairs(self.marks) do
        m:ClearAllPoints()
        m:SetPoint(m.big and "BOTTOM" or "CENTER", self, m.big and "BOTTOMLEFT" or "LEFT", w * m.at, m.big and -4 or 0)
      end
    end
    return b
  end

  -- the names on the game's Honor tab that our page covers (the Arena tab and its buttons stay)
  local HIDE = { "HonorFrameCurrentPVPTitle", "HonorFrameCurrentPVPRank", "HonorFrameCurrentHonor", "HonorFrameCurrentSessionTitle",
    "HonorFrameYesterdayTitle", "HonorFrameThisWeekTitle", "HonorFrameLastWeekTitle", "HonorFrameLifeTimeTitle",
    "HonorFramePvPIcon", "HonorFrameHonorIcon", "HonorFrameCurrentHK", "HonorFrameCurrentDK", "HonorFrameYesterdayHK",
    "HonorFrameYesterdayContribution", "HonorFrameThisWeekHK", "HonorFrameThisWeekContribution", "HonorFrameLastWeekHK",
    "HonorFrameLastWeekContribution", "HonorFrameLastWeekStanding", "HonorFrameLifeTimeHK", "HonorFrameLifeTimeDK",
    "HonorFrameLifeTimeRank", "HonorFrameRankButton", "HonorFrameCurrentHonorButton", "HonorFrameProgressBar" }
  HN.HIDE = HIDE
  -- the game's parts: see-through and not catching the mouse (not hidden: the game shows some again)
  function HN.Cover(on)
    for _, name in ipairs(HIDE) do
      local f = _G[name]
      if f then
        f:SetAlpha(on and 0 or 1)
        if f.EnableMouse and f.GetObjectType and f:GetObjectType() ~= "FontString" and f:GetObjectType() ~= "Texture" then
          f:EnableMouse(not on)
        end
      end
    end
  end

  -- the server's honor points (OctoWoW sends them to the game's page; read from its text)
  function HN.Points()
    local fs = _G.HonorFrameCurrentHonor
    local t = fs and fs.GetText and fs:GetText()
    if not t or t == "" then return nil end
    return t
  end

  function HN.BuildPage(parent)
    local p = CreateFrame("Frame", "pfHonorPage", parent)
    HN.page = p
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, -66)
    p:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -38, 80)
    p:SetFrameLevel((parent:GetFrameLevel() or 1) + 3)
    -- the battle behind it: the game's battleground loading screen (dwarf against orc), dark and worn.
    -- (seen in game 23 Nov 2026: the shade sat UNDER the scene - two textures in one draw layer come in any
    -- order. Every art piece has a layer of its own, on a frame under the page's numbers and bars.)
    local art = CreateFrame("Frame", nil, p)
    art:SetAllPoints(p)
    art:SetFrameLevel(math.max(0, p:GetFrameLevel() - 1))
    p.art = art
    p.scene = Tex(art, "BACKGROUND", "Interface\\Glues\\LoadingScreens\\LoadScreenPvpBattleground")
    p.scene:SetAllPoints(p)
    p.scene:SetTexCoord(.02, .98, .22, 1)
    p.shade = Tex(art, "BORDER", "Interface\\Buttons\\WHITE8X8")
    p.shade:SetAllPoints(p)
    p.grime = Tex(art, "ARTWORK", pfUI.media[ART .. "grime"])
    p.grime:SetAllPoints(p)
    p.crest = Tex(p, "BACKGROUND", nil)
    p.crest:SetWidth(190)
    p.crest:SetHeight(190)
    p.crest:SetPoint("CENTER", p, "TOPRIGHT", -70, -118)
    p.crest:SetBlendMode("ADD")
    p.scratch = Tex(p, "BACKGROUND", pfUI.media[ART .. "scratch"])
    p.scratch:SetAllPoints(p)
    p.scratch:SetBlendMode("ADD")
    p.burn = Tex(art, "OVERLAY", pfUI.media[ART .. "burn"])
    p.burn:SetAllPoints(p)
    -- edges: black outside, a bronze line just inside
    p.edges = {}
    for _, ins in ipairs({ 0, 2 }) do
      local r, g, b, a = 0, 0, 0, 1
      if ins > 0 then r, g, b, a = BRONZE[1], BRONZE[2], BRONZE[3], .28 end
      local top = Tex(p, "ARTWORK", "Interface\\Buttons\\WHITE8X8", r, g, b, a)
      top:SetPoint("TOPLEFT", p, "TOPLEFT", ins, -ins) top:SetPoint("TOPRIGHT", p, "TOPRIGHT", -ins, -ins) top:SetHeight(1)
      local bot = Tex(p, "ARTWORK", "Interface\\Buttons\\WHITE8X8", r, g, b, a)
      bot:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", ins, ins) bot:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -ins, ins) bot:SetHeight(1)
      local lft = Tex(p, "ARTWORK", "Interface\\Buttons\\WHITE8X8", r, g, b, a)
      lft:SetPoint("TOPLEFT", p, "TOPLEFT", ins, -ins) lft:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", ins, ins) lft:SetWidth(1)
      local rgt = Tex(p, "ARTWORK", "Interface\\Buttons\\WHITE8X8", r, g, b, a)
      rgt:SetPoint("TOPRIGHT", p, "TOPRIGHT", -ins, -ins) rgt:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -ins, ins) rgt:SetWidth(1)
      table.insert(p.edges, top) table.insert(p.edges, bot) table.insert(p.edges, lft) table.insert(p.edges, rgt)
    end

    -- header: badge, rank, the server's honor points
    p.badgeGlow = Tex(p, "ARTWORK", pfUI.media[ART .. "spark"], 1, .75, .35, .45)
    p.badgeGlow:SetBlendMode("ADD")
    p.badgeGlow:SetWidth(70)
    p.badgeGlow:SetHeight(70)
    p.badgeGlow:SetPoint("CENTER", p, "TOPLEFT", 32, -30)
    p.badge = Tex(p, "OVERLAY", nil)
    p.badge:SetWidth(38)
    p.badge:SetHeight(38)
    p.badge:SetPoint("CENTER", p, "TOPLEFT", 32, -30)
    p.rank = Text(p, 16, 1, .82, .45)
    p.rank:SetPoint("TOPLEFT", p, "TOPLEFT", 58, -14)
    p.sub = Text(p, 10, .7, .65, .58)
    p.sub:SetPoint("TOPLEFT", p.rank, "BOTTOMLEFT", 0, -3)
    p.points = Text(p, 17, 1, .9, .6, "RIGHT", true)
    p.points:SetPoint("TOPRIGHT", p, "TOPRIGHT", -12, -14)
    p.pointsIcon = Tex(p, "OVERLAY", nil)
    p.pointsIcon:SetWidth(26)
    p.pointsIcon:SetHeight(26)
    p.pointsIcon:SetPoint("RIGHT", p.points, "LEFT", -1, -2)
    p.pointsLabel = Text(p, 9, .6, .55, .48, "RIGHT")
    p.pointsLabel:SetPoint("TOPRIGHT", p.points, "BOTTOMRIGHT", 0, -3)
    p.pointsLabel:SetText("HONOR POINTS")

    -- rank progress
    local _, _, pct = Heading(p, "Rank progress", -52, 15)
    p.pct = pct
    p.scale = {}
    for i = 0, 4 do
      local s = Text(p, 10, .95, .92, .86, "CENTER", true)
      s:SetText(tostring(i * 25))
      p.scale[i] = s
    end
    p.bar = HN.NewBar(p, 24, true)
    p.bar:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -84)
    p.bar:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16, -84)
    p.gainText = Text(p, 10, .75, .7, .62)
    p.gainText:SetPoint("TOPLEFT", p.bar, "BOTTOMLEFT", 0, -6)
    p.toNext = Text(p, 10, .75, .7, .62, "RIGHT")
    p.toNext:SetPoint("TOPRIGHT", p.bar, "BOTTOMRIGHT", 0, -6)

    -- the week's honor against the cap
    Heading(p, "This week", -134)
    p.week = HN.NewBar(p, 14, false)
    p.week:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -150)
    p.week:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16, -150)
    p.session = Text(p, 10, .75, .7, .62)
    p.session:SetPoint("TOPLEFT", p.week, "BOTTOMLEFT", 0, -6)
    p.reset = Text(p, 10, .75, .7, .62, "RIGHT")
    p.reset:SetPoint("TOPRIGHT", p.week, "BOTTOMRIGHT", 0, -6)

    -- (23 Nov 2026, user on the first in-game look: "ALL INLINE AND CLEAN ... easy to see") both tables sit on ONE
    -- column grid (HN.ColX): every heading and number right-aligned to the same column edges, the label / day on
    -- the left; zeros as a grey dash. The day list's heading used to be one spaced-out string that never lined up.
    Heading(p, "Kills and honor", -190)
    p.cells = {}
    for c, name in ipairs({ "TODAY", "YESTERDAY", "THIS WEEK", "LAST WEEK" }) do
      local hd = Text(p, 9, .62, .56, .48, "RIGHT")
      hd:SetText(name)
      p.cells["h" .. c] = hd
    end
    for r, name in ipairs({ "Kills", "Honor" }) do
      local l = Text(p, 11, .85, .8, .7)
      l:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -216 - (r - 1) * 15)
      l:SetText(name)
      for c = 1, 4 do p.cells[r .. ":" .. c] = Text(p, 11, 1, 1, 1, "RIGHT", true) end
    end

    -- the last days: a striped row each, a soft bar behind it as long as the day's honor
    Heading(p, "Last days", -252)
    p.dayCols = {}
    for c, name in ipairs({ "HONOR", "KILLS", "BG W-L", "RANK %" }) do
      local hd = Text(p, 9, .62, .56, .48, "RIGHT")
      hd:SetText(name)
      p.dayCols[c] = hd
    end
    p.days = {}
    for i = 1, 6 do
      local row = CreateFrame("Button", nil, p)
      row:SetHeight(14)
      row:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -276 - (i - 1) * 14)
      row:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, -276 - (i - 1) * 14)
      row.zebra = Tex(row, "BACKGROUND", "Interface\\Buttons\\WHITE8X8", 1, .9, .75, math.mod(i, 2) == 1 and .05 or 0)
      row.zebra:SetAllPoints(row)
      row.meter = Tex(row, "BORDER", "Interface\\Buttons\\WHITE8X8")
      row.meter:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
      row.meter:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
      row.hl = Tex(row, "ARTWORK", "Interface\\Buttons\\WHITE8X8", 1, .8, .5, 0)
      row.hl:SetAllPoints(row)
      row.day = Text(row, 11, .88, .83, .72)
      row.honor = Text(row, 11, 1, .9, .6, "RIGHT", true)
      row.kills = Text(row, 11, .95, .95, .95, "RIGHT", true)
      row.bg = Text(row, 11, .95, .95, .95, "RIGHT", true)
      row.gain = Text(row, 11, .45, 1, .45, "RIGHT", true)
      row:SetScript("OnEnter", function()
        this.hl:SetVertexColor(1, .8, .5, .1)
        local x = this.data
        if not x then return end
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine(date("%A %d %B", x.t or time()), 1, .82, .45)
        GameTooltip:AddDoubleLine("Honor", HN.Fmt(x.honor), .75, .7, .62, 1, 1, 1)
        if x.bgh > 0 then GameTooltip:AddDoubleLine("  Battlegrounds", HN.Fmt(x.bgh), .6, .6, .6, 1, 1, 1) end
        if x.world > 0 then GameTooltip:AddDoubleLine("  World kills", HN.Fmt(x.world), .6, .6, .6, 1, 1, 1) end
        if x.quest > 0 then GameTooltip:AddDoubleLine("  Quests", HN.Fmt(x.quest), .6, .6, .6, 1, 1, 1) end
        if x.award > 0 then GameTooltip:AddDoubleLine("  Other awards", HN.Fmt(x.award), .6, .6, .6, 1, 1, 1) end
        GameTooltip:AddDoubleLine("Honorable kills", x.kills, .75, .7, .62, 1, 1, 1)
        if x.won + x.lost > 0 then GameTooltip:AddDoubleLine("Battlegrounds won / lost", x.won .. " / " .. x.lost, .75, .7, .62, 1, 1, 1) end
        GameTooltip:AddDoubleLine("Rank progress", string.format("%+.2f%%", x.gain), .75, .7, .62, .45, 1, .45)
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() this.hl:SetVertexColor(1, .8, .5, 0) GameTooltip:Hide() end)
      p.days[i] = row
    end
    p.empty = Text(p, 10, .6, .55, .48, "CENTER")
    p.empty:SetPoint("TOP", p, "TOP", 0, -290)
    p.empty:SetText("Your honor shows here day by day as you earn it.")

    -- the rank bar's tooltip
    local hot = CreateFrame("Frame", nil, p)
    hot:SetPoint("TOPLEFT", p.bar, "TOPLEFT", 0, 16)
    hot:SetPoint("BOTTOMRIGHT", p.bar, "BOTTOMRIGHT", 0, -16)
    hot:EnableMouse(true)
    hot:SetScript("OnEnter", function()
      local r, pc = HN.Rank()
      local name, num = GetPVPRankInfo and GetPVPRankInfo(r)
      local dg, wg = HN.Gains()
      local need, nextName = HN.ToNext()
      local rate, steps = HN.Rate(r)
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine("Rank progress", 1, .82, .45)
      GameTooltip:AddDoubleLine(name or "No rank", string.format("%.2f%%", pc * 100), .75, .7, .62, 1, 1, 1)
      GameTooltip:AddDoubleLine("Today", string.format("%+.2f%%", dg), .75, .7, .62, .45, 1, .45)
      GameTooltip:AddDoubleLine("This week", string.format("%+.2f%%", wg), .75, .7, .62, .45, 1, .45)
      if nextName then
        GameTooltip:AddLine(" ")
        if need then
          GameTooltip:AddDoubleLine("To " .. nextName, "~" .. HN.Fmt(need) .. " honor", .75, .7, .62, 1, .9, .6)
          GameTooltip:AddLine(string.format("About %s honor a 1%%, learnt from your last %d steps at this rank.",
            HN.Fmt(rate * HN.STEPS / 100), steps), .55, .55, .55, 1)
        else
          GameTooltip:AddLine("Learning how much honor a step of this rank takes (" .. (steps or 0) .. " of 8 steps seen).", .55, .55, .55, 1)
        end
      end
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Rank % rises as you earn honor. At 100% you reach the next rank.", .55, .55, .55, 1)
      GameTooltip:Show()
    end)
    hot:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- a second's tick while shown (the reset countdown, new honor)
    p:SetScript("OnUpdate", function()
      if (this.tick or 0) > GetTime() then return end
      this.tick = GetTime() + 1
      HN.Paint()
    end)
    p:SetScript("OnShow", function() HN.Cover(true) HN.Paint() end)
    p:SetScript("OnHide", function() GameTooltip:Hide() end)
    HN.Look()
    return p
  end

  -- the art's strength (C.honor.art "1" | "0", artdark 0..1)
  function HN.Look()
    local p = HN.page
    if not p then return end
    local art = G().art ~= "0"
    local dark = tonumber(G().artdark) or .8
    if art then p.scene:Show() p.grime:Show() p.scratch:Show() p.burn:Show() else p.scene:Hide() p.grime:Hide() p.scratch:Hide() p.burn:Hide() end
    p.scene:SetVertexColor(1, 1, 1, 1)
    p.shade:SetVertexColor(.03, .02, .015, art and dark or .92)
    p.scratch:SetVertexColor(1, 1, 1, .22)
    p.grime:SetVertexColor(1, 1, 1, .9)
    local faction = UnitFactionGroup("player") or "Horde"
    p.crest:SetTexture("Interface\\PvPRankBadges\\PvPRank" .. faction)
    local r, g, b = HN.BarColor()
    p.crest:SetVertexColor(r, g, b, art and .16 or .08)
  end

  function HN.Paint()
    local p = HN.page
    if not p or not p:IsVisible() then return end
    local w = HN.Wid(p, 328)
    local r, pc = HN.Rank()
    local name, num = nil, 0
    if GetPVPRankInfo then name, num = GetPVPRankInfo(r) end
    num = tonumber(num) or 0
    -- header
    if num > 0 then
      p.badge:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", num))
      p.badge:Show()
      p.badgeGlow:Show()
    else
      p.badge:Hide()
      p.badgeGlow:Hide()
    end
    p.rank:SetText(name or "No rank yet")
    local lhk, _, best = 0, 0, 0
    if GetPVPLifetimeStats then lhk, _, best = GetPVPLifetimeStats() end
    p.sub:SetText((num > 0 and ("Rank " .. num) or "No rank yet") .. "  |cff5c554a|||r  |cffffffff" .. HN.Fmt(lhk) .. "|r lifetime kills")
    local pts = HN.Points()
    p.points:SetText(pts and HN.Fmt(string.gsub(pts, "%s", "")) or "...")
    p.pointsIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. (UnitFactionGroup("player") or "Horde"))
    p.pointsIcon:SetTexCoord(.09, .63, .05, .63)
    -- rank bar
    local dg, wg = HN.Gains()
    local today = math.max(0, math.min(pc, dg / 100))
    local cr, cg, cb = HN.BarColor()
    p.bar:Set(pc - today, today, cr, cg, cb)
    -- (the % on the heading line, large: inside the bar it sat on the 50 mark)
    p.pct:SetText(string.format("%.2f%%", pc * 100))
    p.bar.text:SetText("")
    local bw = HN.Wid(p.bar, w - 32)
    for i = 0, 4 do
      p.scale[i]:ClearAllPoints()
      p.scale[i]:SetPoint("BOTTOM", p.bar, "TOPLEFT", bw * i / 4, 6)
    end
    local nextName = GetPVPRankInfo and GetPVPRankInfo(r + 1)
    p.gainText:SetText(HN.Signed(dg, "%") .. " today   " .. HN.Signed(wg, "%") .. " this week")
    local need = G().estimate ~= "0" and HN.ToNext() or nil
    if need then
      p.toNext:SetText("~" .. HN.Fmt(need) .. " honor to |cffffd27a" .. nextName .. "|r")
    elseif nextName then
      p.toNext:SetText("Next |cffffd27a" .. nextName .. "|r")
    else
      p.toNext:SetText("")
    end
    -- the week
    local cap = tonumber(G().cap) or 20000
    local wk, wh = 0, 0
    if GetPVPThisWeekStats then wk, wh = GetPVPThisWeekStats() end
    wh = tonumber(wh) or 0
    p.week:Set(cap > 0 and math.min(1, wh / cap) or 0, 0, 1, .72, .3)
    p.week.text:SetText(HN.Fmt(wh) .. " / " .. HN.Fmt(cap) .. (cap > 0 and string.format("   %d%%", floor(wh * 100 / cap)) or ""))
    p.reset:SetText("Resets in " .. HN.Span(HN.ResetIn()))
    -- table: today = this session's kills (the game's "Today") and today's honor from the records
    local s = HN.Store()
    local sk = GetPVPSessionStats and GetPVPSessionStats() or 0
    local yk, _, yh = 0, 0, 0
    if GetPVPYesterdayStats then yk, _, yh = GetPVPYesterdayStats() end
    local lk, _, lh = 0, 0, 0
    if GetPVPLastWeekStats then lk, _, lh = GetPVPLastWeekStats() end
    local dayStart = time() - (tonumber(date("%H")) * 3600 + tonumber(date("%M")) * 60 + tonumber(date("%S")))
    local vals = {
      { sk, yk, wk, lk },
      { HN.HonorSince(dayStart, s.log), yh, wh, lh },
    }
    for c = 1, 4 do
      local x = HN.ColX(w, c)
      p.cells["h" .. c]:ClearAllPoints()
      p.cells["h" .. c]:SetPoint("TOPRIGHT", p, "TOPLEFT", x, -204)
      for rr = 1, 2 do
        local cell = p.cells[rr .. ":" .. c]
        cell:ClearAllPoints()
        cell:SetPoint("TOPRIGHT", p, "TOPLEFT", x, -216 - (rr - 1) * 15)
        cell:SetText(HN.Num(vals[rr][c]))
        if rr == 1 then cell:SetTextColor(.95, .95, .95) else cell:SetTextColor(1, .9, .6) end
      end
    end
    if HN.sessionAt and HN.sessionWeek == HN.WeekStart() then
      local got = math.max(0, wh - (HN.sessionHonor or 0))
      local hrs = math.max(1 / 60, (time() - HN.sessionAt) / 3600)
      p.session:SetText("Session |cffffe699+" .. HN.Fmt(got) .. "|r  |cff5c554a|||r  |cffffe699" .. HN.Fmt(got / hrs) .. "|r an hour")
    else
      p.session:SetText("")
    end
    -- last days, on the same columns as the table above
    local days = HN.Days(table.getn(p.days), s.log)
    local most = 1
    for _, x in ipairs(days) do if x.honor > most then most = x.honor end end
    for c = 1, 4 do
      p.dayCols[c]:ClearAllPoints()
      p.dayCols[c]:SetPoint("TOPRIGHT", p, "TOPLEFT", HN.ColX(w, c), -266)
    end
    local rowW = w - 20
    for i, row in ipairs(p.days) do
      local x = days[i]
      row.data = x
      if x then
        row:Show()
        local t = x.t or time()
        row.day:ClearAllPoints()
        row.day:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.day:SetText(HN.Day(t) == HN.Day() and "Today" or date("%a %d %b", t))
        local cols = { row.honor, row.kills, row.bg, row.gain }
        for c, fs in ipairs(cols) do
          fs:ClearAllPoints()
          fs:SetPoint("RIGHT", row, "LEFT", HN.ColX(w, c) - 10, 0)
        end
        row.honor:SetText(HN.Num(x.honor))
        row.kills:SetText(HN.Num(x.kills))
        row.bg:SetText((x.won + x.lost > 0) and (x.won .. "-" .. x.lost) or HN.DASH)
        row.gain:SetText(HN.Signed(x.gain, ""))
        row.meter:SetWidth(math.max(.01, rowW * x.honor / most))
        row.meter:SetVertexColor(cr, cg, cb, .2)
      else
        row:Hide()
      end
    end
    if table.getn(days) == 0 then
      p.empty:Show()
      for c = 1, 4 do p.dayCols[c]:Hide() end
    else
      p.empty:Hide()
      for c = 1, 4 do p.dayCols[c]:Show() end
    end
  end

  -- on the game's Honor tab (OctoWoW's HonorFrame; C.honor.page "0" = the game's own page)
  function HN.Attach()
    local hf = _G.HonorFrame
    if not hf or HN.page or G().page == "0" then return end
    HN.BuildPage(hf)
    HN.Cover(true)
    -- the server's honor points arrive after the page opens: draw them then
    local cur = _G.HonorFrameCurrentHonor
    if cur and cur.SetText and not cur.pfHonor then
      cur.pfHonor = true
      local set = cur.SetText
      cur.SetText = function(self, t)
        set(self, t)
        if HN.page and HN.page:IsVisible() then HN.Paint() end
      end
    end
  end
  HN.Attach()
end)
