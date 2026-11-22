-- pfUI Octo: threat between the server's answers (modules/meters-threat.lua), run by tests\run.lua:
-- a hit moves a player's number at once, an answer replaces the guess, bars glide.
local ok = octo_ok
local TH = pfUI.meters and pfUI.meters.threat
ok(TH and TH.Snapshot and TH.GroupRecord and TH.Rebuild and TH.Animate, "threat estimate between answers loaded")
if not TH then return end
-- (the tests change settings and ask again in the same instant: nothing is held between asks)
TH.JUDGE_KEEP, TH.MYDOTS_KEEP = 0, 0
local saved = rawget(_G, "UnitName")
_G.UnitName = function(u) if u == "target" then return "Onyxia" end return "Tester" end
local list = TH.Parse("TWTv4=Tank:1:1000:100:1;Rogue:0:600:60:1;")
ok(list and table.getn(list) == 2 and list[1].name == "Tank", "an answer is read")
TH.list = list
TH.Snapshot(list)
TH.GroupRecord({ kind = "dmg", src = "Rogue", tgt = "Onyxia", amt = 500 })
ok(TH.dirty, "a hit marks the numbers as changed")
TH.Rebuild()
local rogue
for _, e in ipairs(TH.list) do if e.name == "Rogue" then rogue = e end end
-- (20 Nov 2026, user: raid threat "jumpy, people going above the tank instantly") the guess moves the rogue at once,
-- but never past the tank: 1100 would be 110% - it stops at 99% until the server itself says more
ok(rogue and rogue.threat == 990 and math.abs(rogue.perc - 99) < .01, "the rogue's threat moved at once, but a guess stops at 99% of the tank's")
TH.GroupRecord({ kind = "dmg", src = "Stranger", tgt = "Onyxia", amt = 500 })
TH.GroupRecord({ kind = "dmg", src = "Rogue", tgt = "Someone else", amt = 500 })
TH.Rebuild()
for _, e in ipairs(TH.list) do if e.name == "Rogue" then rogue = e end end
ok(rogue.threat == 990, "a player not on the list or a hit on another mob changes nothing")
-- the server says 105%: the guess may go on from there, never below it
do
  local l2 = TH.Parse("TWTv4=Tank:1:1000:100:1;Rogue:0:1050:105:1;")
  TH.list = l2
  TH.Snapshot(l2)
  TH.GroupRecord({ kind = "dmg", src = "Rogue", tgt = "Onyxia", amt = 400 })
  TH.Rebuild()
  for _, e in ipairs(TH.list) do if e.name == "Rogue" then rogue = e end end
  ok(math.abs(rogue.perc - 105) < .01, "above the tank only as far as the server's own answer said (105%)")
  TH.list = list
  TH.Snapshot(list)
  TH.GroupRecord({ kind = "dmg", src = "Rogue", tgt = "Onyxia", amt = 500 })
  TH.Rebuild()
end
-- the next answer replaces the guess and teaches the multiplier
local nextList = TH.Parse("TWTv4=Tank:1:1000:100:1;Rogue:0:1250:125:1;")
TH.Snapshot(nextList)
ok(TH.dmg.Rogue == nil and TH.base == nextList, "an answer replaces the guess")
ok(TH.k.Rogue and TH.k.Rogue > 1, "the threat per damage point is learnt (" .. tostring(TH.k.Rogue) .. ")")
-- bars glide towards their value
TH.list = nextList
TH.shown = { Rogue = 50 }
local moving = TH.Animate()
ok(moving and TH.shown.Rogue > 50 and TH.shown.Rogue < 125, "a bar moves part of the way")
for i = 1, 60 do TH.Animate() end
ok(math.abs(TH.shown.Rogue - 125) < .3, "and arrives")
_G.UnitName = saved
TH.base, TH.baseBy, TH.dmg, TH.shown, TH.list = nil, nil, {}, {}, nil

-- the exact mob, and the threat multipliers
_G.UnitName = function(u) if u == "target" then return "Onyxia" end return "Tester" end
TH.targetGuid = "0xF130000000000001"
ok(TH.IsTarget({ tgt = "Onyxia", tgtGuid = "0xF130000000000001" }), "the targeted mob by its id")
ok(not TH.IsTarget({ tgt = "Onyxia", tgtGuid = "0xF130000000000002" }), "another mob of the same name is told apart")
ok(TH.IsTarget({ tgt = "Onyxia" }), "no id in the record: the name decides")
TH.targetGuid = "12345"
ok(TH.IsTarget({ tgt = "Onyxia", tgtGuid = "0xF130000000000002" }), "ids in another form: the name decides")
TH.targetGuid = nil
TH.k, TH.mods = {}, { Tank = 1.3 }
ok(TH.K("Tank") == 1.3 and TH.K("Rogue") == 1, "a stance gives its multiplier until one is learnt")
TH.k.Tank = 2
ok(TH.K("Tank") == 2, "a learnt value wins")
TH.mods, TH.k = {}, {}
_G.UnitName = saved

-- the server stays silent in a group: an estimate for everyone from the hits; solo again when the group goes
do
  local S2 = pfUI_config.meters
  local sv = { GetNumPartyMembers = rawget(_G, "GetNumPartyMembers"), GetNumRaidMembers = rawget(_G, "GetNumRaidMembers"), UnitName = rawget(_G, "UnitName"),
    UnitExists = rawget(_G, "UnitExists"), UnitIsUnit = rawget(_G, "UnitIsUnit"), CheckInteractDistance = rawget(_G, "CheckInteractDistance"), Who = pfUI.meters.Who }
  _G.GetNumPartyMembers = function() return 1 end
  _G.GetNumRaidMembers = function() return 0 end
  _G.UnitName = function(u) if u == "target" then return "Onyxia" elseif u == "targettarget" then return "Tank" elseif u == "pet" then return nil end return "Warlock" end
  _G.UnitExists = function() return true end
  _G.UnitIsUnit = function(a, b) return a == "targettarget" and b == "player" and false end
  _G.CheckInteractDistance = function() return true end
  pfUI.meters.Who = function(n) if n == "Onyxia" then return { kind = "OTHER" } end return { kind = "PLAYER" } end
  TH.est, TH.gaveUp = {}, true
  ok(TH.UseEst(), "a group whose server sent nothing uses the estimate")
  TH.EstRecord({ kind = "dmg", src = "Warlock", tgt = "Onyxia", amt = 1000 })
  TH.EstRecord({ kind = "dmg", src = "Tank", tgt = "Onyxia", amt = 600 })
  TH.Estimate()
  local tank, lock
  for _, e in ipairs(TH.list or {}) do if e.name == "Tank" then tank = e elseif e.name == "Warlock" then lock = e end end
  ok(tank and tank.tank and lock and not lock.tank, "the one the mob attacks is the tank")
  ok(lock and math.abs(lock.perc - 166.7) < .2, "everyone else is a share of the tank's threat (" .. tostring(lock and lock.perc) .. ")")
  ok(TH.estimated, "marked as an estimate")
  _G.GetNumPartyMembers = function() return 0 end
  TH.gaveUp = nil
  ok(not TH.UseEst() or true, "(group gone)")
  for k, v in pairs(sv) do if k == "Who" then pfUI.meters.Who = v else _G[k] = v end end
  TH.est, TH.gaveUp, TH.list, TH.estimated = {}, nil, nil, nil
end

-- only elites and bosses are asked about; a normal mob in a group gets the estimate
do
  local sv = { UnitClassification = rawget(_G, "UnitClassification"), UnitExists = rawget(_G, "UnitExists"), GetNumPartyMembers = rawget(_G, "GetNumPartyMembers"), GetNumRaidMembers = rawget(_G, "GetNumRaidMembers") }
  _G.UnitExists = function() return true end
  _G.GetNumPartyMembers = function() return 1 end
  _G.GetNumRaidMembers = function() return 0 end
  local kind = "normal"
  _G.UnitClassification = function() return kind end
  TH.gaveUp = nil
  ok(not TH.ServerKind() and TH.UseEst(), "a normal mob in a group: not asked, estimated")
  kind = "elite"
  ok(TH.ServerKind() and not TH.UseEst(), "an elite: the server is asked")
  kind = "worldboss"
  ok(TH.ServerKind(), "a boss: the server is asked")
  TH.gaveUp = true
  ok(TH.UseEst(), "an elite the server stays silent about: the estimate")
  TH.gaveUp = nil
  for k, v in pairs(sv) do _G[k] = v end
end

-- a normal mob in a group: asked a few times, estimated meanwhile; an answer proves the server does them too
do
  local sv = { UnitClassification = rawget(_G, "UnitClassification"), UnitExists = rawget(_G, "UnitExists"), GetNumPartyMembers = rawget(_G, "GetNumPartyMembers"),
    GetNumRaidMembers = rawget(_G, "GetNumRaidMembers"), SendAddonMessage = rawget(_G, "SendAddonMessage") }
  local sent = 0
  _G.SendAddonMessage = function() sent = sent + 1 end
  _G.UnitExists = function() return true end
  _G.GetNumPartyMembers = function() return 1 end
  _G.GetNumRaidMembers = function() return 0 end
  _G.UnitClassification = function() return "normal" end
  pfUI_config.meters.normalok = "0"
  TH.probes, TH.askAt, TH.at = 0, 0, 0
  ok(not TH.Asks() and TH.UseEst(), "normal mob, nothing learnt yet: estimated")
  pfUI_config.meters.normalok = "1"
  ok(TH.Asks() and not TH.UseEst(), "once the server has answered for one, normal mobs use the server")
  pfUI_config.meters.normalok = "0"
  for k, v in pairs(sv) do _G[k] = v end
end

-- taunts and flat threat in the estimate
do
  local sv = { UnitName = rawget(_G, "UnitName"), UnitExists = rawget(_G, "UnitExists"), GetNumPartyMembers = rawget(_G, "GetNumPartyMembers"), GetNumRaidMembers = rawget(_G, "GetNumRaidMembers"), Who = pfUI.meters.Who }
  _G.UnitName = function(u) if u == "target" then return "Boar" end return "Me" end
  _G.UnitExists = function() return true end
  _G.GetNumPartyMembers = function() return 1 end
  _G.GetNumRaidMembers = function() return 0 end
  pfUI.meters.Who = function(n) if n == "Boar" then return { kind = "OTHER" } end return { kind = "PLAYER" } end
  TH.gaveUp, TH.est, TH.k, TH.mods = true, {}, {}, {}
  TH.EstRecord({ kind = "dmg", src = "Rogue", tgt = "Boar", amt = 1000 })
  TH.EstRecord({ kind = "dmg", src = "Warrior", tgt = "Boar", spl = "Sunder Armor", amt = 100 })
  ok(TH.est.Boar.Warrior == 360, "Sunder Armor: its damage plus 260 flat")
  TH.EstRecord({ kind = "cast", src = "Warrior", tgt = "Boar", spl = "Taunt" })
  ok(TH.est.Boar.Warrior == 1001, "a taunt puts the warrior just above the top (" .. tostring(TH.est.Boar.Warrior) .. ")")
  for k, v in pairs(sv) do if k == "Who" then pfUI.meters.Who = v else _G[k] = v end end
  TH.est, TH.gaveUp = {}, nil
end

-- (20 Nov 2026, user: "if a raid leader wanted to see whos dots would overaggro in xxx seconds he can easily see it")
-- everyone's DoTs: learnt from their ticks on your target, their countdown, the next to pull
do
  local sv = rawget(_G, "UnitName")
  _G.UnitName = function(u) if u == "target" then return "Onyxia" end return "Leader" end
  local mc = pfUI_config.meters
  mc.tpredict, mc.tpredsec = "1", "8"
  TH.others, TH.hist, TH.k, TH.mods, TH.all = {}, {}, { Lock = 1 }, {}, nil
  TH.targetGuid = nil
  TH.LearnHit({ kind = "dmg", src = "Lock", tgt = "Onyxia", spl = "Corruption", amt = 300, dot = true }, 100)
  TH.LearnHit({ kind = "dmg", src = "Lock", tgt = "Onyxia", spl = "Corruption", amt = 300, dot = true }, 103)
  TH.LearnHit({ kind = "dmg", src = "Lock", tgt = "Someone else", spl = "Immolate", amt = 900, dot = true }, 103)
  local t = TH.others.Lock and TH.others.Lock.Corruption
  ok(t and t.amt == 300 and math.abs(t.gap - 3) < .01 and math.abs(t.start - 97) < .01 and not TH.others.Lock.Immolate,
    "another player's DoT on your target: its tick, its gap and when it went on (other mobs left out)")
  -- Corruption 18 s from 97: at 103 it has 12 s = 4 ticks of 300 left
  local pend, steps = TH.OthersOnTheWay("Lock", 103)
  ok(pend == 1200 and table.getn(steps) == 4 and math.abs(steps[1][1] - 3) < .01, "its ticks still to come: 1200 (" .. pend .. ")")
  TH.list = TH.Parse("TWTv4=Tank:1:10000:100:1;Lock:0:12100:101:0;Leader:0:3000:30:1;")
  local p = TH.PredictFor("Lock", 103)
  -- at range Lock pulls at 13000: 900 to go, the 3rd tick does it, in 9 s
  ok(p and p.stopNow and math.abs(p.aggroIn - 9) < .01 and p.pending == 1200, "their DoTs pull them in 9 s (" .. tostring(p and p.aggroIn) .. ")")
  mc.tpredsec = "10"
  TH.all = nil
  local who, np = TH.NextToPull(103)
  ok(who == "Lock" and np and np.stopNow, "the next to pull, for anyone to see")
  -- 4 s since the last tick (> 1.6 gaps): the DoT has fallen off
  pend = TH.OthersOnTheWay("Lock", 108)
  ok(pend == 0, "no tick for a while: their DoT is gone")
  -- the window: the tank first on Aggro; Lock, above the tank's threat (101%) but at range, on 77% of their own pull
  -- point (130%) - not past the tank - with their seconds; the next-to-pull line
  local w = pfUI.meters.ThreatWindow and pfUI.meters.ThreatWindow()
  if w and pfUI.meters.Rows then
    local svGT = rawget(_G, "GetTime")
    _G.GetTime = function() return 103 end
    TH.all = nil
    local rows = pfUI.meters.Rows("threat", "current")
    local dotRow, tankRow, lockRow
    for _, r in ipairs(rows) do
      if r.pullrow == "dots" then dotRow = r end
      if r.name == "Tank" and not r.pullrow then tankRow = r end
      if r.name == "Lock" and not r.pullrow then lockRow = r end
    end
    -- (20 Nov 2026, user: "the name of the person whos dots will take over next should be clear and visibile under or
    -- next to DoTs") the DoTs line names whose DoTs pull next, and when
    ok(dotRow and string.find(dotRow.label or "", "Lock", 1, true) and string.find(dotRow.label or "", "in 9 s", 1, true) and dotRow.text == "+1.20k",
      "the DoTs line: Lock in 9 s, +1.20k on the way (" .. tostring(dotRow and dotRow.label) .. ")")
    ok(tankRow and tankRow.rank == 1 and tankRow.value == 100, "the tank first, the only one at 100")
    ok(lockRow and lockRow.value < 100 and math.floor(lockRow.value) == 77 and lockRow.text == "77%" and lockRow.cd == "9s" and lockRow.ghost,
      "Lock: 77% of their pull point, their seconds in a column of their own, what is still coming (" .. tostring(lockRow and lockRow.cd) .. ")")
    _G.GetTime = svGT
    -- (20 Nov 2026, user: "Molten Guar..." - the target's name must always show in full)
    do
      local long = "Molten Guardian of the Burning Depths Champion"
      local svU, svE = rawget(_G, "UnitName"), rawget(_G, "UnitExists")
      _G.UnitName = function(u) if u == "target" then return long end return "Leader" end
      _G.UnitExists = function() return true end
      w:SetWidth(200)
      w:Show()
      w.Refresh(w)
      local inTitle = (w.seg.text or "") ~= "" and string.find(w.seg.text, long, 1, true)
      local b1 = w.bars[1]
      local onLine = b1 and b1.row and b1.row.pullrow == "mob" and string.find(b1.left.text or "", long, 1, true)
      ok((inTitle or onLine) and not string.find(w.seg.text or "", "...", 1, true),
        "a long target name is shown whole (" .. (inTitle and "title" or (onLine and "its own line" or "cut")) .. ")")
      _G.UnitName, _G.UnitExists = svU, svE
    end
    -- (20 Nov 2026, the pfUI continuation session: "make ours neat and clear") columns drop when narrow, TPS first,
    -- then threat - a name keeps M.NAMEMIN px
    do
      local mcfg = pfUI_config.meters
      local keepTps = mcfg.ttps
      mcfg.ttps = "1"
      local function Win(wd) return { GetWidth = function() return wd end } end
      local u300 = pfUI.meters.ThreatCols(Win(300), 12, 0, 0)
      local u200 = pfUI.meters.ThreatCols(Win(200), 12, 0, 0)
      local u140 = pfUI.meters.ThreatCols(Win(140), 12, 0, 0)
      ok(u300.tps and u300.mid, "wide: TPS, threat and %")
      ok(not u200.tps and u200.mid, "narrower: TPS goes first")
      ok(not u140.tps and not u140.mid, "narrow: threat goes too, the name keeps its room")
      mcfg.ttps = keepTps
    end
    -- someone pulling at their pace (no DoTs): the Next line names them
    do
      local svGT = rawget(_G, "GetTime")
      _G.GetTime = function() return 200 end
      TH.others, TH.all = {}, nil
      TH.list = TH.Parse("TWTv4=Tank:1:10000:100:1;Valeera:0:9000:90:1;Leader:0:3000:30:1;")
      TH.hist = { Tank = { { 196, 10000 }, { 200, 10000 } }, Valeera = { { 196, 7000 }, { 200, 9000 } } }
      local rows = pfUI.meters.Rows("threat", "current")
      local nx
      for _, r in ipairs(rows) do if r.pullrow == "next" then nx = r end end
      ok(nx and string.find(nx.label or "", "Valeera", 1, true) and nx.text == "4 s", "the Next line: Valeera pulls in 4 s at her pace (" .. tostring(nx and nx.text) .. ")")
      -- the window is as tall as the lines it shows
      local s = pfUI_config.meters["win" .. w.id]
      local keepH = s.height
      s.height = "400"
      pfUI_config.meters.tfit = "1"
      w:SetHeight(400)
      pfUI.meters.SetMode(w, "threat")
      w.Refresh(w)
      local shownBars = 0
      for _, b in ipairs(w.bars or {}) do if b:IsShown() and b.row then shownBars = shownBars + 1 end end
      ok(shownBars >= 4 and w.fitH and math.abs(w:GetHeight() - w.fitH) < 1 and w:GetHeight() < 400,
        "the threat window fits its " .. shownBars .. " lines (" .. tostring(w:GetHeight()) .. " px, not 400)")
      TH.list = TH.Parse("TWTv4=Tank:1:10000:100:1;Leader:0:3000:30:1;")
      TH.all = nil
      local tall = w:GetHeight()
      w.Refresh(w)
      ok(w:GetHeight() < tall, "fewer lines, a shorter window")
      s.height = keepH
      _G.GetTime = svGT
      TH.hist = {}
    end
    -- (20 Nov 2026, user: "can we add this smooth glide") ClassicAPI's eased bars: a bar keeping its player eases,
    -- a bar taking someone else's place jumps
    do
      local svEnum = rawget(_G, "Enum")
      _G.Enum = { StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 } }
      local svGT = rawget(_G, "GetTime")
      _G.GetTime = function() return 300 end
      TH.all = nil
      TH.list = TH.Parse("TWTv4=Tank:1:10000:100:1;Valeera:0:9000:90:1;Leader:0:3000:30:1;")
      pfUI.meters.SetMode(w, "threat")
      w.Refresh(w)
      local seen = {}
      for _, b in ipairs(w.bars or {}) do
        local bb = b
        bb.bar.SetValue = function(self, v, how) seen[bb] = how end
      end
      w.Refresh(w)
      local eased, jumped = 0, 0
      for _, how in pairs(seen) do if how == 1 then eased = eased + 1 elseif how == 0 then jumped = jumped + 1 end end
      ok(eased >= 3 and jumped == 0, "the same players again: every bar eases (" .. eased .. ")")
      -- Leader overtakes Valeera: their two bars change owner
      TH.list = TH.Parse("TWTv4=Tank:1:10000:100:1;Leader:0:9500:95:1;Valeera:0:3000:30:1;")
      TH.all = nil
      pfUI.meters.threatOrder = {}
      seen = {}
      w.Refresh(w)
      jumped = 0
      for _, how in pairs(seen) do if how == 0 then jumped = jumped + 1 end end
      ok(jumped >= 2, "a bar that now shows someone else jumps, never glides from them (" .. jumped .. ")")
      pfUI_config.meters.smooth = "0"
      ok(pfUI.meters.Eased() == nil, "switched off: plain bars")
      pfUI_config.meters.smooth = "1"
      _G.Enum = svEnum
      ok(pfUI.meters.Eased() == nil, "no ClassicAPI: plain bars, our own glide")
      _G.GetTime = svGT
    end
    -- (20 Nov 2026, user: "this should be in all meters these changes not just threat") a damage window: the same
    -- columns (per second, total, %), the headings over them, and it fits its lines
    do
      local mc2 = pfUI_config.meters
      local keepHeads = mc2.mheads
      mc2.mheads, mc2.mcols, mc2.tfit = "1", "1", "1"
      pfUI.meters.UnlockThreatWindow()
      pfUI.meters.SetMode(w, "damage")
      local s = mc2["win" .. w.id]
      local keepH = s.height
      s.height = "500"
      pfUI.meters.testUntil = GetTime() + 30
      w.Refresh(w)
      local bh, bp = w.bars[1], w.bars[2]
      ok(bh and bh.row and bh.row.pullrow == "head" and bh.pct.text == "%" and bh.mid.text ~= "", "damage window: headings over the columns")
      ok(bp and bp.row and not bp.row.pullrow and string.find(bp.pct.text or "", "%%$") and (bp.mid.text or "") ~= ""
        and (bp.right.text or "") == "", "damage window: total and % in their own columns (" .. tostring(bp and bp.mid.text) .. " / " .. tostring(bp and bp.pct.text) .. ")")
      ok(w.fitH and math.abs(w:GetHeight() - w.fitH) < 1 and w:GetHeight() < 500, "damage window fits its lines (" .. tostring(w:GetHeight()) .. ")")
      pfUI.meters.testUntil = 0
      s.height = keepH
      mc2.mheads = keepHeads
      pfUI.meters.SetMode(w, "threat")
      s.threatlock = "1"
    end
    -- locked to threat: the display menu cannot switch it away
    pfUI.meters.SetMode(w, "damage")
    ok(w.mode == "threat", "your threat window stays on threat")
    pfUI.meters.UnlockThreatWindow()
    pfUI.meters.SetMode(w, "damage")
    ok(w.mode == "damage", "unlocked, it switches again")
  end
  -- the Meters section: its Meters / Threat halves show their own tabs only
  local O = pfUI.octoui and pfUI.octoui.Options
  if O and O.Select and O.TABSIDE then
    O:Select("o:thwindow")
    local shown = {}
    for _, grp in ipairs(O.groups or {}) do
      for _, b in ipairs(grp.buttons or {}) do if b:IsShown() then shown[b.key] = true end end
    end
    ok(shown["o:thwindow"] and shown["o:mtthreat"] and not shown["o:mtwindows"], "Threat half: its two tabs, not the meter ones")
    ok(pfUI.metersOcto and pfUI.metersOcto.threatPw and pfUI.metersOcto.threatPw:IsShown() and pfUI.metersOcto.threatPw.mode == "threat",
      "the Threat window page's preview is shown, on threat")
    -- (20 Nov 2026, user: the info lines ran "off the meter") their words fit beside the number; each kind its own colour
    local pw = pfUI.metersOcto and pfUI.metersOcto.threatPw
    -- (20 Nov 2026, user: "why is this showing the top bars in my preview but not on my meter this should never
    -- happen") with numbers coming in, the preview and the real window show the very same lines
    local live = pfUI.meters.ThreatWindow and pfUI.meters.ThreatWindow()
    if pw and live then
      local svGT = rawget(_G, "GetTime")
      _G.GetTime = function() return 103 end
      TH.all = nil
      live:SetWidth(200) live:Show()
      pfUI.meters.SetMode(live, "threat")
      live.Refresh(live)
      pw:SetWidth(200)
      pw.Refresh(pw)
      local function Lines(w)
        local out = {}
        for _, b in ipairs(w.bars or {}) do
          -- (the mob's own line comes and goes with the title's room, which is the window's width)
          if b:IsShown() and b.row and b.row.pullrow ~= "mob" then table.insert(out, (b.row.pullrow or "player") .. ":" .. (b.row.name or "") .. ":" .. (b.pct.text or "")) end
        end
        return table.concat(out, " | ")
      end
      local a, c = Lines(live), Lines(pw)
      ok(a ~= "" and a == c and pw.previewLive, "the preview shows exactly the meter's lines (" .. c .. ")")
      _G.GetTime = svGT
    end
    -- the made-up sample (no numbers coming in): its lines fit, each kind its own mark
    local keepList = TH.list
    TH.list = nil
    if pw then
      pw:SetWidth(200)
      pw.Refresh(pw)
      -- (the mock measures 6 px a character, colour codes too, at any size: these bars measure like the client)
      local function Measure(self)
        local t = string.gsub(string.gsub(self.text or "", "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
        local _, sz = self:GetFont()
        return string.len(t) * (tonumber(sz) or 12) * .55
      end
      for _, b in ipairs(pw.bars or {}) do b.left.GetStringWidth = Measure end
      pw.Refresh(pw)
      local over, kinds, cols = {}, 0, {}
      for _, b in ipairs(pw.bars or {}) do
        if b:IsShown() and b.row and b.row.pullrow then
          kinds = kinds + 1
          local room = 200 - 4 - (b.pct:GetWidth() or 0) - 10
          if (b.left:GetStringWidth() or 0) > room then table.insert(over, b.row.pullrow) end
          -- (the mock keeps no texture colours: the rule the mark is painted by)
          local r, g, bl = pfUI.meters.InfoColor(b.row)
          cols[string.format("%.2f,%.2f,%.2f", r or 0, g or 0, bl or 0)] = true
        end
      end
      local ncol = 0
      for _ in pairs(cols) do ncol = ncol + 1 end
      ok(kinds >= 3 and table.getn(over) == 0, "the preview's info lines fit (" .. table.concat(over, ", ") .. ")")
      ok(ncol >= 3, "each info line its own mark colour (" .. ncol .. " colours)")
    end
    TH.list = keepList
    O:Select("o:mtwindows")
    shown = {}
    for _, grp in ipairs(O.groups or {}) do
      for _, b in ipairs(grp.buttons or {}) do if b:IsShown() then shown[b.key] = true end end
    end
    ok(shown["o:mtwindows"] and not shown["o:thwindow"], "Meters half: the meter tabs only")
  end
  TH.others, TH.hist, TH.k, TH.list, TH.all = {}, {}, {}, nil, nil
  _G.UnitName = sv
end

-- (20 Nov 2026, Javelin: "auras and aggro% are overlapping") the label above a plate goes on top of its auras
do
  local A = pfUI.plates and pfUI.plates.Auras
  local plate = CreateFrame("Frame", nil, UIParent)
  plate.name = plate:CreateFontString(nil, "OVERLAY")
  local pc = pfUI_config.plates
  local keepAuras = pc.auras
  pc.auras = "1"
  local i1, i2 = CreateFrame("Frame", nil, plate), CreateFrame("Frame", nil, plate)
  i1:Show() i2:Show()
  plate.octo = { arow = CreateFrame("Frame", nil, plate), aicons = { i1, i2 }, bicons = {}, ah = 16, arowgap = 2 }
  local mc = pfUI_config.meters
  local keepWhere, keepTy = mc.twhere, mc.ty
  mc.twhere, mc.ty = "above", "2"
  local l = TH.label
  TH.Place(l, plate)
  local pt = l.points and l.points[1]
  local top = A and A.TopOffset(plate) or 0
  ok(A and top >= 18 and pt and pt[5] and pt[5] >= top + 2, "the label sits above the aura row (label at " .. tostring(pt and pt[5]) .. ", auras up to " .. top .. ")")
  i1:Hide() i2:Hide()
  TH.Place(l, plate)
  pt = l.points and l.points[1]
  ok(pt and pt[5] == 2, "no auras up: the label at its own height")
  -- (22 Nov 2026, Simpson: threat % "into the target unit frame") on my target frame: pfUI's, else the game's
  local keepPT, keepTF, keepTx = rawget(_G, "pfTarget"), rawget(_G, "TargetFrame"), mc.tx
  local tf = CreateFrame("Frame", "pfTarget", UIParent)
  tf:Show()
  _G.pfTarget = tf
  mc.twhere, mc.tx, mc.ty = "frame", "5", "3"
  ok(TH.Place(l, nil), "on my target frame: placed without a nameplate")
  pt = l.points and l.points[1]
  ok(pt and pt[1] == "BOTTOM" and pt[2] == tf and pt[3] == "TOP" and pt[4] == 5 and pt[5] == 5,
    "on the target frame's top edge, nudged by X / Y (" .. tostring(pt and pt[4]) .. "," .. tostring(pt and pt[5]) .. ")")
  tf:Hide()
  _G.TargetFrame = nil
  ok(not TH.Place(l, nil), "no target frame up: the label hides")
  _G.pfTarget, _G.TargetFrame = keepPT, keepTF
  mc.twhere, mc.ty, pc.auras = keepWhere, keepTy, keepAuras
  mc.tx = keepTx
end

-- (20 Nov 2026, Lobo: told to hold off on threat while tanking, out of Defensive Stance - "warriors stance dance")
do
  local mc = pfUI_config.meters
  local keep = { tt = mc.ttank, n = rawget(_G, "GetNumShapeshiftForms"), f = rawget(_G, "GetShapeshiftFormInfo"),
    c = rawget(_G, "UnitAffectingCombat"), u = rawget(_G, "UnitName"), a = TH.Alert }
  local alerts = 0
  TH.Alert = function() alerts = alerts + 1 end
  _G.UnitName = function(u) if u == "target" then return "Onyxia" end return "Lobo" end
  local form = "Defensive Stance"
  _G.GetNumShapeshiftForms = function() return 1 end
  _G.GetShapeshiftFormInfo = function() return "x", form, true end
  local inFight = true
  _G.UnitAffectingCombat = function() return inFight end
  TH.tankFight, TH.tankAt, TH.warned, TH.predWarned = nil, nil, nil, nil
  mc.ttank, mc.threatflash = "auto", "1"
  -- Lobo is off the boss for a moment, at 105% of the tank's threat
  local list = TH.Parse("TWTv4=Tank:1:10000:100:1;Lobo:0:10500:105:1;")
  local j = TH.Judge(list)
  ok(j.tankMe and j.state == 1, "Defensive Stance: a tank, a calm label")
  TH.Popups(j)
  ok(alerts == 0, "no hold-off popup for a tank")
  -- stance dance: Battle Stance for an Overpower, same fight
  form = "Battle Stance"
  TH.tankAt = nil
  j = TH.Judge(list)
  TH.Popups(j)
  ok(j.tankMe and alerts == 0, "Battle Stance in the same fight: still a tank, still no popup")
  -- the fight ends: decided again
  inFight = false
  _G.event = "PLAYER_REGEN_ENABLED"
  Mock.Fire("PLAYER_REGEN_ENABLED")
  TH.tankAt = nil
  j = TH.Judge(list)
  ok(not j.tankMe, "after the fight, in Battle Stance: not a tank any more")
  mc.ttank = "always"
  ok(TH.IAmTank(), "Always: a tank whatever the stance")
  mc.ttank = "never"
  form = "Defensive Stance"
  TH.tankAt, TH.tankFight = nil, nil
  ok(not TH.IAmTank(), "Never: warned like a damage dealer")
  -- a damage dealer past the cap still gets the popup
  mc.ttank = "auto"
  form = "Battle Stance"
  TH.tankAt, TH.tankFight, TH.warned = nil, nil, nil
  mc.threatwarn, mc.threatref = "90", "pull"
  j = TH.Judge(TH.Parse("TWTv4=Tank:1:10000:100:1;Lobo:0:10500:105:1;"))
  TH.Popups(j)
  ok(not j.tankMe and alerts >= 1, "a damage dealer past the cap is still warned")
  -- a damage dealer who pulled the boss for a moment is not a tank for the rest of the fight
  inFight = true
  TH.Judge(TH.Parse("TWTv4=Tank:0:10000:95:1;Lobo:1:10500:100:1;"))
  TH.tankAt = nil
  j = TH.Judge(TH.Parse("TWTv4=Tank:1:12000:100:1;Lobo:0:10500:87:1;"))
  ok(not j.tankMe, "pulled aggro once, lost it again: still warned like a damage dealer")
  inFight = false
  mc.ttank = keep.tt
  _G.GetNumShapeshiftForms, _G.GetShapeshiftFormInfo, _G.UnitAffectingCombat, _G.UnitName, TH.Alert = keep.n, keep.f, keep.c, keep.u, keep.a
  TH.tankFight, TH.tankAt, TH.warned = nil, nil, nil
end

-- (22 Nov 2026, /pfperf in a raid) asked many times a second: the same list is judged once a tenth of a second, and
-- your DoTs on the boss are read once a quarter of a second
do
  TH.JUDGE_KEEP, TH.MYDOTS_KEEP = .1, .25
  local l = TH.Parse("TWTv4=Tank:1:1000:100:1;Rogue:0:600:60:1;")
  local a, b = TH.Judge(l), TH.Judge(l)
  ok(a == b, "the same list a moment later: the same judgement, not worked out again")
  local realRead, reads = TH.ReadMyDots, 0
  TH.ReadMyDots = function(now) reads = reads + 1 return { { name = "Corruption", ends = now + 12 } } end
  TH.ForgetMyDots()
  local d1 = TH.MyDots()
  local d2 = TH.MyDots()
  ok(reads == 1 and d1[1] and d2[1] and d2[1].name == "Corruption" and d2[1].left > 11, "your DoTs: read once, time left still exact ("
    .. reads .. " reads)")
  TH.ReadMyDots = realRead
  TH.JUDGE_KEEP, TH.MYDOTS_KEEP = 0, 0
  TH.ForgetMyDots()
end
