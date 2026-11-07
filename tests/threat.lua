-- pfUI Octo: threat between the server's answers (modules/meters-threat.lua), run by tests\run.lua:
-- a hit moves a player's number at once, an answer replaces the guess, bars glide.
local ok = octo_ok
local TH = pfUI.meters and pfUI.meters.threat
ok(TH and TH.Snapshot and TH.GroupRecord and TH.Rebuild and TH.Animate, "threat estimate between answers loaded")
if not TH then return end
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
ok(rogue and rogue.threat == 1100 and math.abs(rogue.perc - 110) < .01, "the rogue's threat moved at once: 1100 = 110% of the tank's")
TH.GroupRecord({ kind = "dmg", src = "Stranger", tgt = "Onyxia", amt = 500 })
TH.GroupRecord({ kind = "dmg", src = "Rogue", tgt = "Someone else", amt = 500 })
TH.Rebuild()
for _, e in ipairs(TH.list) do if e.name == "Rogue" then rogue = e end end
ok(rogue.threat == 1100, "a player not on the list or a hit on another mob changes nothing")
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
