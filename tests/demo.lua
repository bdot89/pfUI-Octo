-- pfUI Octo: Demo mode (modules/demo.lua, demo-options.lua), run by tests\run.lua.
-- The pretend raid answers pfUI's unit questions only while it runs and puts every function back after;
-- the fight loops trash -> boss -> kill / wipe -> rest; a real fight stops it.
local ok = octo_ok
local DM = pfUI.demo
ok(DM and DM.Start and DM.Stop and DM.Step and DM.Fake, "demo mode loaded (pfUI.demo)")
if not DM then return end
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.demo, "options page Demo mode registered")
local S = pfUI_config.demo
ok(S and S.speed == "1" and S.target == "1" and S.wipes == "3", "defaults (C.demo)")
ok(getglobal("pfDemoBar") and rawget(_G, "SLASH_PFDEMO1") == "/demo", "the bar at the top and /demo")
if O and O.Select then
  local good, err = pcall(function() O:Select("o:demo") end)
  ok(good and O.pages.demo, "the Demo mode page builds: " .. tostring(err))
end

local env = pfUI.env
local before = { UnitName = rawget(env, "UnitName"), GetNumRaidMembers = rawget(env, "GetNumRaidMembers"),
  UnitHealth = rawget(env, "UnitHealth"), UnitInRaid = rawget(env, "UnitInRaid") }
local realName = _G.UnitName
ok(DM.Start("raid") and DM.on and pfUIDemoCheck == nil, "the raid demo starts")
ok(env.GetNumRaidMembers() == 40 and env.UnitInRaid("player") == 1, "pfUI sees a raid of 40 with you in it")
local r5 = DM.units.raid5
ok(r5 and env.UnitName("raid5") == r5.name and env.UnitHealthMax("raid5") == r5.max and select(2, env.UnitClass("raid5")) == r5.class,
  "raid5 is a made-up raider")
ok(_G.UnitName == realName and rawget(_G, "GetNumRaidMembers") ~= env.GetNumRaidMembers, "the game's own functions are left alone")
local name1 = env.GetRaidRosterInfo(1)
ok(name1 == _G.UnitName("player"), "raid1 is you")
ok(env.UnitName("party1") == DM.units.raid2.name, "party1 is the second raider")
ok(env.UnitName("target") == DM.boss.name and env.UnitClassification("target") == "elite" and env.UnitCanAttack("player", "target") == 1
  and env.UnitIsFriend("player", "raid7") == 1, "the target is the trash mob, hostile; raiders friendly")
ok(env.UnitIsUnit("targettarget", "raid2") == 1, "target of target = the main tank")
-- pfUI's own raid frames take them: the roster sort hands out raid ids, the frames show
if pfUI.uf and pfUI.uf.raid and pfUI.uf.raid.GetScript and pfUI.uf.raid:GetScript("OnUpdate") then
  _G.this = pfUI.uf.raid
  pcall(Mock.Run, pfUI.uf.raid, "OnUpdate", .1)
  local shown, total = 0, 0
  for _, f in pairs(pfUI.uf.frames) do
    if f.label == "raid" and tonumber(f.id) and tonumber(f.id) > 1 then
      total = total + 1
      pcall(pfUI.uf.UpdateVisibility, f)
      if f:IsShown() then shown = shown + 1 end
    end
  end
  ok(total > 0 and shown > 0, "pfUI's raid frames show the pretend raiders (" .. shown .. " of " .. total .. ")")
end

-- a boss: abilities, debuffs, a cast bar, its health going down
local now = Mock.now
DM.SetPhase("boss")
ok(DM.boss and env.UnitClassification("target") == "worldboss" and env.GetRaidTargetIndex("target") == 8, "a boss with a skull")
local hp0 = DM.boss.hp
local sawDebuff, sawCast, sawHurt = false, false, false
for _ = 1, 60 do
  Mock.now = Mock.now + .5
  DM.Step(.5)
  for i = 2, 40 do
    local tex, _, kind = env.UnitDebuff("raid" .. i, 1)
    if tex and kind then sawDebuff = true end
    if env.UnitHealth("raid" .. i) < env.UnitHealthMax("raid" .. i) then sawHurt = true end
  end
  if env.UnitCastingInfo("target") or env.UnitChannelInfo("target") then sawCast = true end
  if DM.phase ~= "boss" then break end
end
ok(DM.phase ~= "boss" or DM.boss.hp < hp0, "the boss loses health")
ok(sawHurt and sawDebuff and sawCast, "raiders get hurt, curable debuffs land, the boss casts (" .. tostring(sawHurt) .. tostring(sawDebuff) .. tostring(sawCast) .. ")")
for _ = 1, 400 do
  if DM.phase == "rest" then break end
  Mock.now = Mock.now + 1
  DM.Step(1)
end
ok(DM.phase == "rest" and DM.boss == nil, "kill, then rest")
for _ = 1, 20 do Mock.now = Mock.now + 1 DM.Step(1) if DM.phase ~= "rest" then break end end
local healthy = true
for i = 2, 40 do if env.UnitIsDead("raid" .. i) then healthy = false end end
ok(DM.phase == "trash" and healthy, "after the rest everyone is up and the next pull starts")

-- a wipe every boss: the raid goes down and the same boss comes back
S.wipes = "1"
local idx = DM.bossIndex
DM.SetPhase("boss")
local first = DM.bossIndex
for _ = 1, 300 do
  if DM.phase ~= "boss" then break end
  Mock.now = Mock.now + 1
  DM.Step(1)
end
ok(DM.wiped and DM.retry, "a wipe")
DM.SetPhase("rest")
DM.SetPhase("boss")
ok(DM.bossIndex == first and first ~= idx, "the same boss again after a wipe")
S.wipes = "3"

-- pause, speed, next
DM.CycleSpeed()
ok(DM.speed == 2 and S.speed == "2", "speed 1x -> 2x")
DM.speed, S.speed = 1, "1"
DM.Next()
ok(DM.phase == "ended", "Next skips the boss")

-- a real fight stops it, and everything is back
_G.event = "PLAYER_REGEN_DISABLED"
_G.this = DM.ticker
Mock.Run(DM.ticker, "OnEvent")
ok(not DM.on, "a real fight ends the demo")
ok(rawget(env, "UnitName") == before.UnitName and rawget(env, "GetNumRaidMembers") == before.GetNumRaidMembers
  and rawget(env, "UnitHealth") == before.UnitHealth and rawget(env, "UnitInRaid") == before.UnitInRaid, "every function put back as it was")
ok(DM.Fake("raid5") == nil and not getglobal("pfDemoBar"):IsShown(), "no pretend units, the bar gone")
Mock.now = now

-- (19 Nov 2026, the user's first run) threat on the boss, the target's health number, nothing sent to a pretend raid
local TH = pfUI.meters and pfUI.meters.threat
local sent = 0
local keepSend = rawget(_G, "SendAddonMessage")
_G.SendAddonMessage = function() sent = sent + 1 end
local keepRaid, keepParty = rawget(_G, "GetNumRaidMembers"), rawget(_G, "GetNumPartyMembers")
_G.GetNumRaidMembers, _G.GetNumPartyMembers = function() return 0 end, function() return 0 end
DM.Start("raid")
DM.SetPhase("boss")
for _ = 1, 10 do Mock.now = Mock.now + .5 DM.Step(.5) DM.Threat(.5) end
ok(TH and TH.list and table.getn(TH.list) > 5 and TH.list[1].tank and TH.list[1].perc == 100, "the threat meter: the tank on top, the raid under it")
local me = _G.UnitName("player")
local mine
for _, e in ipairs(TH and TH.list or {}) do if e.name == me then mine = e end end
ok(mine and mine.perc > 0, "you are on the threat list")
if TH and TH.Ask then TH.Ask() end
env.SendAddonMessage("TEST", "x", "RAID")
ok(sent == 0, "nothing goes out to a raid that is not there")
local lh = pfUI.libhealth
if lh and lh.GetUnitHealth then
  local cur, max = lh:GetUnitHealth("target")
  ok(cur == math.floor(DM.boss.hp) and max == DM.boss.max, "the boss's health number on the target frame (was 0)")
end
DM.Stop(true)
ok(TH == nil or TH.list == nil, "threat list cleared at stop")
_G.SendAddonMessage, _G.GetNumRaidMembers, _G.GetNumPartyMembers = keepSend, keepRaid, keepParty

-- the target dummy: every rank in turn, the raid left alone
ok(DM.Start("dummy") and DM.phase == "dummy", "the target dummy demo starts")
ok(env.UnitClassification("target") == "normal" and env.UnitName("target") == "Training Dummy", "rank 1: a normal dummy")
ok(rawget(env, "GetNumRaidMembers") == before.GetNumRaidMembers and DM.Fake("raid5") == nil, "no pretend raid with the dummy")
local seen = {}
for _ = 1, 5 do seen[env.UnitClassification("target")] = true DM.Next() end
ok(seen.normal and seen.elite and seen.rare and seen.rareelite and seen.worldboss, "Next steps through normal, elite, rare, rare elite, boss")
for _ = 1, 30 do Mock.now = Mock.now + 1 DM.Step(1) end
ok(DM.boss and DM.boss.hp > 0, "the dummy never dies")
DM.Stop(true)
ok(rawget(env, "UnitName") == before.UnitName and (not lh or lh.GetUnitHealth ~= nil), "dummy stopped, everything back")
Mock.now = now
