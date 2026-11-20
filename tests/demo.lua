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
-- (20 Nov 2026, user: Start in a real fight said no in chat, then Stop did nothing and nothing started until a reload)
do
  local svC = _G.UnitAffectingCombat
  _G.UnitAffectingCombat = function(u) return u == "player" and 1 or nil end
  local started = DM.Start("raid")
  ok(not started and not DM.on and not pfDemoBar:IsShown(), "in a real fight: the demo does not start")
  _G.UnitAffectingCombat = svC
  local again = DM.Start("raid")
  ok(again and DM.on, "out of the fight it starts at once, no reload")
  DM.Stop(true)
  ok(not DM.on, "and stops")
  -- a step of Stop that errors in the game: the rest still runs, the demo is off, the next Start works
  DM.Start("raid")
  local svJ = DM.Joins
  DM.Joins = function() error("test: Joins broke") end
  DM.Stop(true)
  ok(not DM.on and not pfDemoBar:IsShown() and rawget(env, "GetNumRaidMembers") == before.GetNumRaidMembers,
    "a broken stop step: the demo is still off and pfUI's functions are back")
  DM.Joins = svJ
  -- a part of Start that errors: put back at once, said in chat, and the next Start works
  local svK = DM.MakeKit
  DM.MakeKit = function() error("test: kit broke") end
  ok(DM.Start("raid") == false and not DM.on and rawget(env, "GetNumRaidMembers") == before.GetNumRaidMembers,
    "a broken start: nothing left half on")
  DM.MakeKit = svK
  ok(DM.Start("raid") and DM.on, "the next Start works, no reload")
  DM.Stop(true)
end
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
pfUI_config.unitframes.group.hide_in_raid = "1"
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
-- (20 Nov 2026, user: buttons to trigger events during the test) every event runs; the threat ones and deaths / res
if DM.EVENTS then
  local function Run(n) for _ = 1, n do Mock.now = Mock.now + .5 DM.Step(.5) DM.Threat(.5) end end
  local failed = {}
  for _, e in ipairs(DM.EVENTS) do
    if e.key ~= "wipe" and e.key ~= "kill" and not DM.Event(e.key) then table.insert(failed, e.key) end
  end
  ok(table.getn(failed) == 0, "every demo event runs (" .. table.concat(failed, ", ") .. ")")
  DM.thEvent = nil
  DM.SetPhase("rest") DM.SetPhase("boss")
  DM.Event("over")
  Run(6)
  local holder
  for _, e in ipairs(TH.list or {}) do if e.tank then holder = e.name end end
  ok(holder == me, "Overthreat: the boss turns to you (" .. tostring(holder) .. ")")
  Run(14)
  holder = nil
  for _, e in ipairs(TH.list or {}) do if e.tank then holder = e.name end end
  ok(holder and holder ~= me, "then the tank taunts it back")
  DM.Event("dots")
  Run(2)
  local p = TH.Predict and TH.Predict()
  ok(p and p.stopNow and p.aggroIn > 0 and p.aggroIn <= 5 and TH.SoonText({ aggroIn = p.aggroIn, stopNow = true }),
    "DoTs pull aggro: the countdown runs on your threat (" .. tostring(p and p.aggroIn) .. " s)")
  DM.thEvent = nil
  DM.Event("death")
  local dead = 0
  for _, u in ipairs(DM.list) do if u.dead then dead = dead + 1 end end
  ok(dead >= 1, "Someone dies")
  DM.Event("res")
  dead = 0
  for _, u in ipairs(DM.list) do if u.dead then dead = dead + 1 end end
  ok(dead == 0, "Res everyone brings them all up")
  DM.Event("wipe")
  Run(30)
  ok(DM.phase ~= "boss" and DM.wiped ~= false, "Wipe: the raid goes down and the fight ends (" .. tostring(DM.phase) .. ")")
  ok(DM.forceWipe == nil, "the wipe is over once the fight is")
  ok(DM.Event("kill") and true, "Kill the boss")
end
DM.Stop(true)
ok(TH == nil or TH.list == nil, "threat list cleared at stop")
ok(TH == nil or TH.demoPredict == nil, "the demo's own countdown gone at stop")
ok(DM.Event("over") == false, "no events without a demo running")
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
-- (19 Nov 2026, user: "no party frames are showing up") the user's settings: party frames hide in raids, raid demo first
local hir = pfUI_config.unitframes.group.hide_in_raid
pfUI_config.unitframes.group.hide_in_raid = "1"
DM.Start("raid")
for _ = 1, 3 do Mock.now = Mock.now + .3 _G.this = DM.ticker Mock.Run(DM.ticker, "OnUpdate", .3) end
DM.Stop(true)
ok(DM.Start("dungeon") and DM.kind == "dungeon", "the dungeon demo starts")
for _ = 1, 12 do
  Mock.now = Mock.now + .3
  _G.this = DM.ticker Mock.Run(DM.ticker, "OnUpdate", .3)
  for _, f in pairs(pfUI.uf.frames) do
    if f:GetScript("OnUpdate") then _G.this = f _G.arg1 = .3 pcall(f:GetScript("OnUpdate")) end
  end
end
local shownP = 0
for i = 1, 4 do if pfUI.uf.group and pfUI.uf.group[i] and pfUI.uf.group[i]:IsShown() then shownP = shownP + 1 end end
ok(shownP == 4, "the four party frames show (" .. shownP .. ")")
ok(table.getn(DM.Ensure(false)) == 0, "nothing the dungeon needs is missing")
-- a frame switched off is named with the reason, never forced on
local gv = pfUI_config.unitframes.group.visible
pfUI_config.unitframes.group.visible = "0"
for i = 1, 4 do local f = pfUI.uf.group and pfUI.uf.group[i] if f then pcall(f.UpdateVisibility, f) end end
local said
local keepAdd = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(self, t) said = t end
DM.Ensure(true)
DEFAULT_CHAT_FRAME.AddMessage = keepAdd
ok(said and string.find(said, "switched off", 1, true), "a switched-off frame is named in chat: " .. tostring(said))
pfUI_config.unitframes.group.visible = gv
pfUI_config.unitframes.group.hide_in_raid = hir
-- the other modules' tests run and come back, the samples show
ok(DM.ShowSamples() and DM.cycled, "CoolDownManager / OctoTotems / OctoConsumes samples on, module tests started")
local c0 = DM.cycled
Mock.now = Mock.now + DM.CYCLETIME + 1
_G.this = DM.ticker Mock.Run(DM.ticker, "OnUpdate", .3)
ok(DM.cycled > c0, "the module tests start again before they run out")
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
end
-- (19 Nov 2026, the user's AFK camera is switched off) the demo's own AFK screen
do
  local keepCam = rawget(_G, "pfAFKCam")
  _G.pfAFKCam = nil
  ok(DM.Start("afk") and DM.afkUsesOwn and DM.afkOwn and DM.afkOwn:IsShown() and not UIParent:IsShown(),
    "without pfUI's AFK camera: the demo's own AFK screen, the interface hidden")
  for _ = 1, 6 do Mock.now = Mock.now + 2 DM.Step(2) end
  _G.this = DM.afkOwn
  Mock.Run(DM.afkOwn, "OnClick")
  ok(not DM.on and not DM.afkOwn:IsShown() and UIParent:IsShown(), "a click ends it and the interface comes back")
  _G.pfAFKCam = keepCam
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

-- (19 Nov 2026, user: "make sure it is all cycling properly") each demo, two minutes on its own clock at 4x
for _, kind in ipairs({ "raid", "dungeon", "dummy", "pvp", "showcase" }) do
  ok(DM.Start(kind), kind .. " demo starts")
  DM.speed = 4
  local phases, seen, errs = {}, 0, nil
  local keepOn = DM.onPhase
  local calls = 0
  DM.onPhase = function(ph) calls = calls + 1 if not phases[ph] then phases[ph] = true seen = seen + 1 end end
  for _ = 1, 240 do
    Mock.now = Mock.now + .5
    _G.this = DM.ticker
    local good, err = pcall(Mock.Run, DM.ticker, "OnUpdate", .5)
    if not good then errs = err break end
    if not DM.on then break end
  end
  DM.onPhase = keepOn
  local names = {}
  for k in pairs(phases) do table.insert(names, k) end
  local want = (kind == "dummy" and 1) or (kind == "pvp" and 2) or 3
  ok(not errs and DM.on and seen >= want, kind .. " keeps cycling (" .. table.concat(names, ", ") .. ")" .. (errs and (": " .. tostring(errs)) or ""))
  if kind == "dummy" then ok(calls >= 10, "the dummy stepped through its ranks " .. calls .. " times") end
  if kind == "pvp" then ok(calls >= 6, "one enemy after another (" .. calls .. " changes)") end
  if kind == "showcase" then ok(DM.showIndex and DM.showIndex > 3, "the showcase moved through its captions (" .. tostring(DM.showIndex) .. ")") end
  DM.Stop(true)
end
DM.speed = 1
ok(rawget(env, "UnitName") == before.UnitName and UIParent:IsShown(), "after every demo: all put back, the interface shown")
Mock.now = now

-- (20 Nov 2026, user: "the demo uses spells that are to your class also the procs ... a direct test to you")
do
  local keep = {}
  for _, k in ipairs({ "UnitClass", "GetSpellName", "GetSpellTexture", "GetActionTexture", "UnitBuff" }) do keep[k] = rawget(_G, k) end
  local book, slots = {}, {}
  _G.GetSpellName = function(i) return book[i] and book[i][1], "Rank 1" end
  _G.GetSpellTexture = function(i) return book[i] and ("Interface\\Icons\\" .. book[i][2]) end
  _G.GetActionTexture = function(s) return slots[s] and ("Interface\\Icons\\" .. slots[s]) end
  _G.UnitBuff = function(u, i) return nil end
  local fired = {}
  local EV = pfUI.sct and pfUI.sct.CT and pfUI.sct.CT.EV
  local keepFire = EV and EV.Fire
  if EV then EV.Fire = function(self, kind, data) table.insert(fired, { kind, data and data.spell }) end end
  local function Saw(kind, spell)
    for _, f in ipairs(fired) do if f[1] == kind and (not spell or f[2] == spell) then return true end end
  end

  -- a warlock: Shadow Bolt and the DoTs, on the dummy
  _G.UnitClass = function() return "Warlock", "WARLOCK" end
  book = { { "Shadow Bolt", "Spell_Shadow_ShadowBolt" }, { "Corruption", "Spell_Shadow_AbominationExplosion" },
    { "Curse of Agony", "Spell_Shadow_CurseOfSargeras" } }
  ok(DM.Start("dummy") and DM.kit and DM.kit.class == "WARLOCK", "the demo reads your class")
  ok(DM.kit.hits[1].name == "Shadow Bolt" and table.getn(DM.kit.hits) == 1 and DM.kit.dots[1].name == "Corruption",
    "your kit: the spells you know (Shadow Bolt; Corruption, Curse of Agony)")
  for _ = 1, 30 do Mock.now = Mock.now + .5 DM.Step(.5) end
  ok(Saw("outSpell", "Shadow Bolt") and Saw("outDot", "Corruption"), "your Shadow Bolt and Corruption ticks in your combat text")
  local onBoss = {}
  for i = 1, 16 do local tex = env.UnitDebuff("target", i) if tex then onBoss[tex] = true end end
  ok(onBoss["Interface\\Icons\\Spell_Shadow_AbominationExplosion"] and onBoss["Interface\\Icons\\Spell_Shadow_CurseOfSargeras"],
    "your DoTs on the pretend target (its frame shows them)")
  local D = pfUI.dots
  local saved = D and DM.savedDFake
  ok(D and D.FAKE and D.FAKE[1][5][1] and D.FAKE[1][5][1][1] == "Corruption", "OctoDoTs' sample mobs carry your DoTs")
  DM.Stop(true)
  ok(not D or D.FAKE == saved, "OctoDoTs' own samples back after Stop")

  -- a warrior: Mortal Strike's cooldown and the global cooldown on your bars, Overpower lighting up, a proc on you
  _G.UnitClass = function() return "Warrior", "WARRIOR" end
  book = { { "Mortal Strike", "Ability_Warrior_SavageBlow" }, { "Overpower", "Ability_MeleeDamage" }, { "Heroic Strike", "Ability_Rogue_Ambush" },
    { "Rend", "Ability_Gouge" } }
  slots = { [1] = "Ability_Warrior_SavageBlow", [2] = "Ability_MeleeDamage", [3] = "Ability_Rogue_Ambush" }
  fired = {}
  ok(DM.Start("dummy") and DM.kit.class == "WARRIOR" and DM.kit.melee, "a warrior's kit")
  local R = pfUI.meters and pfUI.meters.test and pfUI.meters.test.ROSTER
  local wrow
  for _, row in ipairs(R or {}) do if row[2] == "WARRIOR" then wrow = row end end
  local hasMS = false
  for _, s in ipairs(wrow and wrow[3] or {}) do if s[1] == "Mortal Strike" then hasMS = true end end
  ok(not R or (wrow[1] == _G.UnitName("player") and hasMS), "the meters' test fight has you in it, with your Mortal Strike")
  local sawCD, sawGCD, sawReact, sawProc = false, false, false, false
  for _ = 1, 80 do
    Mock.now = Mock.now + .25
    DM.Step(.25)
    local s, d = env.GetActionCooldown(1)
    if s and d and d > 5 then sawCD = true end
    local s3, d3 = env.GetActionCooldown(3)
    if s3 and d3 and d3 > 1 and d3 < 2 then sawGCD = true end
    if env.IsUsableAction(2) == 1 then sawReact = true end
    for i = 1, 3 do if env.UnitBuff("player", i) then sawProc = true end end
  end
  ok(sawCD, "Mortal Strike's 6 s cooldown on its action button")
  ok(sawGCD, "the global cooldown on your other buttons")
  ok(sawReact and Saw("reactive", "Overpower"), "Overpower usable (the reactive glow) and its combat text alert")
  ok(sawProc and Saw("buffGain"), "a proc of yours as a buff on you (Enrage / Flurry)")
  ok(Saw("outMelee") and Saw("outSpell", "Mortal Strike"), "your swings and Mortal Strike in your combat text")
  local s, d = env.GetSpellCooldown(1, "spell")
  ok(s ~= nil, "GetSpellCooldown answers for your spellbook (CoolDownManager reads it)")
  DM.Stop(true)
  ok(rawget(env, "GetActionCooldown") == nil or rawget(env, "GetActionCooldown") == keep.GetActionCooldown, "GetActionCooldown put back")
  ok(rawget(env, "UnitBuff") == before.UnitBuff, "UnitBuff put back")
  ok(not wrow or wrow[1] == "Garrosh", "the meters' own test fight back after Stop")
  if EV then EV.Fire = keepFire end
  for k, v in pairs(keep) do _G[k] = v end
  Mock.now = now
end

-- (20 Nov 2026, crash #132 on a disconnect) PLAYER_LEAVING_WORLD = the full stop; PLAYER_LOGOUT = no unit call at all
do
  ok(DM.Start("raid"), "a demo for the leaving-world test")
  _G.event, _G.this = "PLAYER_LEAVING_WORLD", DM.ticker
  Mock.Run(DM.ticker, "OnEvent")
  ok(not DM.on and rawget(env, "UnitName") == before.UnitName, "PLAYER_LEAVING_WORLD stops the demo, everything back")

  -- the last test here: the logout handler unregisters the demo's clock
  local keepSct = pfUI.sct and pfUI.sct.B and pfUI.sct.B.db and pfUI.sct.B.db.sct and pfUI.sct.B.db.sct.enabled
  if pfUI.sct and pfUI.sct.B and pfUI.sct.B.db then pfUI.sct.B.db.sct.enabled = false end
  ok(DM.Start("dungeon") and DM.ctOn, "a demo running (it switched combat text on for itself)")
  local stubbed, called = {}, {}
  for k, v in pairs(_G) do
    if type(k) == "string" and type(v) == "function" and (string.find(k, "^Unit") or k == "SetCVar" or k == "GetCVar"
      or k == "GetNumRaidMembers" or k == "GetNumPartyMembers" or k == "GetRaidRosterInfo") then
      stubbed[k] = v
    end
  end
  for k in pairs(stubbed) do
    local name = k
    _G[k] = function() table.insert(called, name) error("unit call at logout: " .. name) end
  end
  _G.event, _G.this = "PLAYER_LOGOUT", DM.ticker
  local good, err = pcall(Mock.Run, DM.ticker, "OnEvent")
  for k, v in pairs(stubbed) do _G[k] = v end
  ok(good and table.getn(called) == 0, "PLAYER_LOGOUT during a demo calls no unit function or CVar ("
    .. table.concat(called, ", ") .. ") " .. tostring(err))
  ok(not DM.on and rawget(env, "UnitName") == before.UnitName and rawget(env, "GetNumRaidMembers") == before.GetNumRaidMembers,
    "and still puts pfUI's own functions back")
  ok(pfUI.sct.B.db.sct.enabled == false, "the combat text switch saved as it was before the demo")
  if pfUI.sct and pfUI.sct.B and pfUI.sct.B.db then pfUI.sct.B.db.sct.enabled = keepSct end
  -- (at a real logout nothing more runs; here the later tests need the meters' test fight off and the clock back)
  if pfUI.meters and pfUI.meters.testOn then pfUI.meters.TestMode(false) end
  DM.Cycle(.01)
end
