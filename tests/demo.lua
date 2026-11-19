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

-- the dungeon (5): a party, no raid; packs by marks, the sheeped one last, kicks, then the end boss
ok(DM.Start("dungeon") and DM.kind == "dungeon", "the dungeon demo starts")
ok(env.GetNumRaidMembers() == 0 and env.GetNumPartyMembers() == 4 and env.UnitInRaid("party1") == nil, "a party of five, not a raid")
ok(env.UnitName("party1") == DM.units.party1.name and DM.tank == DM.units.party1 and env.UnitIsPartyLeader("party1") == 1, "party1 tanks and leads")
ok(DM.pack and table.getn(DM.pack) >= 3 and env.GetRaidTargetIndex("target") == 8, "a pack; skull on your target")
local sheep
for _, m in ipairs(DM.pack) do if m.cc then sheep = m end end
ok(sheep and sheep.debuffs[1] and string.find(sheep.debuffs[1].tex, "Polymorph"), "the moon stands polymorphed")
local chatKeep, kicks = DEFAULT_CHAT_FRAME.AddMessage, 0
DEFAULT_CHAT_FRAME.AddMessage = function(self, t) if t and string.find(t, "interrupts") then kicks = kicks + 1 end end
local sawBoss, packs, targets = false, 0, {}
for _ = 1, 600 do
  Mock.now = Mock.now + .5
  DM.Step(.5)
  if DM.boss then targets[DM.boss.name] = true end
  if DM.phase == "boss" then sawBoss = true end
  if DM.phase == "rest" then break end
end
DEFAULT_CHAT_FRAME.AddMessage = chatKeep
local nt = 0
for _ in pairs(targets) do nt = nt + 1 end
ok(nt >= 5, "every mob of both packs became the target in turn (" .. nt .. ")")
ok(sawBoss and DM.phase == "rest", "both packs, then the end boss, then a rest")
ok(kicks > 0, "casts get kicked (" .. kicks .. ")")
DM.Stop(true)

-- PvP: enemy players on your target, the dead come back
ok(DM.Start("pvp") and DM.kind == "pvp", "the PvP demo starts")
local mine = _G.UnitFactionGroup("player")
ok(env.UnitIsPlayer("target") == 1 and env.UnitIsPVP("target") == 1 and env.UnitCanAttack("player", "target") == 1
  and env.UnitFactionGroup("target") ~= mine and select(2, env.UnitClass("target")) == DM.boss.class, "an enemy player of the other faction on your target")
local first, foes = DM.boss, {}
local revived = false
for _ = 1, 400 do
  Mock.now = Mock.now + .5
  DM.Step(.5)
  if DM.boss then foes[DM.boss] = true end
  for _, u in ipairs(DM.list) do if u.wasDead and not u.dead then revived = true end u.wasDead = u.dead end
end
local nf = 0
for _ in pairs(foes) do nf = nf + 1 end
ok(nf >= 3 and DM.on, "one enemy after another (" .. nf .. "), never a rest or a wipe")
ok(DM.Threat and (not TH or TH.list == nil), "no threat list against players")
DM.Stop(true)

-- AFK: pfUI's AFK screen with chat; never marks you AFK; it closing ends the demo
local cam = getglobal("pfAFKCam")
if cam and cam.start then
  local afkSent = false
  local keepChat = rawget(_G, "SendChatMessage")
  _G.SendChatMessage = function(m, chan) if chan == "AFK" then afkSent = true end end
  ok(DM.Start("afk") and DM.kind == "afk", "the AFK demo starts")
  ok(cam._spinning, "the AFK screen is up")
  env.SendChatMessage("", "AFK")
  ok(not afkSent, "it never marks you AFK for real")
  for _ = 1, 6 do Mock.now = Mock.now + 2 DM.Step(2) end
  cam:stop()
  Mock.now = Mock.now + 1
  DM.Step(1)
  ok(not DM.on, "the AFK screen closing ends the demo")
  _G.SendChatMessage = keepChat
else
  ok(DM.Start("afk") == false, "without the AFK screen the AFK demo says so")
end

-- the showcase: the raid underneath, a caption that steps through the modules
ok(DM.Start("showcase") and DM.roster == "raid" and env.GetNumRaidMembers() == 40, "the showcase runs on the raid demo")
local c1 = DM.caption
ok(c1 and string.find(c1, "Raid frames"), "first caption: " .. tostring(c1))
DM.Next()
ok(DM.caption ~= c1 and DM.showIndex == 2, "Next = the next caption")
for _ = 1, 20 do Mock.now = Mock.now + 1 DM.Step(1) end
ok(DM.showIndex >= 3, "the captions move on by themselves")
DM.Stop(true)
ok(DM.caption == nil and rawget(env, "UnitName") == before.UnitName, "showcase stopped, everything back")
Mock.now = now
