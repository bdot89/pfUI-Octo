-- pfUI Octo: OctoArcade (modules/minigames*.lua), run by tests\run.lua.
local ok = octo_ok
local MG = pfUI.minigames
ok(MG and MG.quiz and MG.aim and MG.win, "OctoArcade loaded (pfUI.minigames)")
if not MG then return end
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.arcade, "options page arcade registered")

-- the question bank: every question sound
local Q = MG.DATA.quiz
ok(table.getn(Q) >= 600, "at least 600 questions (" .. table.getn(Q) .. ")")
local cats, seenQ, bad = {}, {}, {}
for _, d in ipairs(MG.quiz.CATS) do cats[d[1]] = 0 end
for i, e in ipairs(Q) do
  local why
  if type(e.q) ~= "string" or e.q == "" then why = "no question" end
  if not cats[e.c] then why = "unknown category " .. tostring(e.c) else cats[e.c] = cats[e.c] + 1 end
  if type(e.a) ~= "table" or table.getn(e.a) ~= 4 then why = "not 4 answers" end
  local dup = {}
  for _, a in ipairs(e.a or {}) do
    if dup[a] then why = "the same answer twice: " .. a end
    dup[a] = true
    if string.find(a, "|") or string.find(a, " no[,:]") then why = "odd answer text: " .. a end
  end
  if seenQ[e.q] then why = "asked twice" end
  seenQ[e.q] = true
  if string.find(e.q, "|") then why = "| in the question" end
  if why then table.insert(bad, i .. ": " .. why .. " (" .. tostring(e.q) .. ")") end
end
ok(not bad[1], "every question has 4 different answers, a category, no repeats" .. (bad[1] and (" - " .. bad[1]) or ""))
for c, n in pairs(cats) do ok(n > 0, "category " .. c .. " has questions (" .. n .. ")") end

local keep = {}
for _, k in ipairs({ "GetTime", "UnitOnTaxi", "UnitAffectingCombat", "SendAddonMessage", "IsInGuild", "GetNumRaidMembers",
  "GetNumPartyMembers", "UnitName", "PlaySound", "MouseIsOver", "GetCursorPosition" }) do keep[k] = rawget(_G, k) end
local now = 1000
_G.GetTime = function() return now end
_G.UnitAffectingCombat = function() return nil end
_G.UnitName = function(u) if u == "player" then return "Me" end end
_G.PlaySound = function() end
local S = MG.S()

-- the quiz
MG.Show("quiz")
ok(MG.win:IsShown() and MG.cur == "quiz" and MG.quiz.cur, "quiz opens with a question")
local qz = MG.quiz
local rightAt
for i = 1, 4 do if qz.order[i] == 1 then rightAt = i end end
qz.Answer(rightAt)
ok(qz.right == 1 and qz.streak == 1, "a right answer counts and starts a streak")
local _, me = MG.Store()
ok((me.quiz.best or 0) >= 1, "best streak kept")
qz.Next()
local wrongAt
for i = 1, 4 do if qz.order[i] ~= 1 then wrongAt = i end end
qz.Answer(wrongAt)
ok(qz.streak == 0 and qz.asked == 2, "a wrong answer ends the streak")
-- a category switched off is not asked
for _, d in ipairs(qz.CATS) do S.cats[d[1]] = "0" end
S.cats.raids = "1"
qz.deck = nil
local onlyRaids = true
for _ = 1, 20 do
  qz.Next()
  if qz.cur and qz.cur.c ~= "raids" then onlyRaids = false end
end
ok(onlyRaids, "only the categories switched on are asked")
for _, d in ipairs(qz.CATS) do S.cats[d[1]] = nil end
qz.deck = nil
-- timer: out of time counts as wrong
S.quiztimer = "10"
qz.Next()
now = now + 11
MG.pages.quiz:GetScript("OnUpdate")()
ok(qz.done and qz.streak == 0, "out of time counts as wrong")
S.quiztimer = "0"

-- the aim trainer
local AM = MG.aim
S.aimmode = "gridshot"
MG.Show("aim")
AM.Start()
ok(AM.state == "run" and table.getn(AM.live) == 3, "Gridshot: three targets")
local t = AM.live[1]
now = now + .3
AM.Hit(t)
ok(AM.hits == 1 and AM.score > 0 and table.getn(AM.live) == 3, "a hit scores and a new target comes")
now = now + .1
AM.Miss(10, 10)
ok(AM.misses == 1 and AM.combo == 0, "a miss breaks the combo")
now = AM.ends + 1
MG.pages.aim:GetScript("OnUpdate")()
ok(AM.state == "done" and me.aim.gridshot and me.aim.gridshot.score == AM.score, "the round ends and its best is kept")
-- Kick: a cast that lands costs points
S.aimmode = "kick"
AM.Start()
ok(table.getn(AM.live) == 3 and AM.live[1].castTime, "Kick: casters with cast bars")
now = now + 5
MG.pages.aim:GetScript("OnUpdate")()
ok(AM.misses >= 1, "a cast that lands is a miss")
AM.Finish(true)
-- Reflex: a target too slow to click is a miss
S.aimmode = "reflex"
AM.Start()
now = now + 2
MG.pages.aim:GetScript("OnUpdate")()
ok(AM.misses == 1, "Reflex: a target that shrinks away is a miss")
AM.Finish(true)
-- every mode starts
for _, m in ipairs(AM.MODES) do
  S.aimmode = m.key
  local good = pcall(AM.Start)
  ok(good and AM.state == "run", m.name .. " starts")
  AM.Finish(true)
end
S.aimmode = "gridshot"

-- scores travel without |
local sent = {}
_G.SendAddonMessage = function(p, m, c) table.insert(sent, { p, m, c }) end
_G.IsInGuild = function() return 1 end
_G.GetNumRaidMembers = function() return 0 end
_G.GetNumPartyMembers = function() return 0 end
MG.Share("hexakill", 4200, 87)
ok(sent[1] and sent[1][1] == "pfArc" and sent[1][2] == "B^hexakill^4200^87" and sent[1][3] == "GUILD", "a best goes to the guild as B^mode^score^accuracy")
MG.Receive("B^hexakill^5100^90", "Friend")
MG.Receive("B^hexakill^100^10", "Friend")
MG.Receive("B^nosuchmode^1^1", "Friend")
local s = MG.Store()
ok(s.board.hexakill and s.board.hexakill.Friend and s.board.hexakill.Friend.v == 5100 and not s.board.nosuchmode, "others' bests kept (the higher one)")
MG.Show("board")
ok(MG.cur == "board", "Scores page draws")
-- across players: a "Q" is answered (a moment later) with our bests and the best others we know
sent = {}
me.aim.hexakill = { score = 4200, acc = 87 }
pfUI.minigames.Asked("GUILD")
now = now + 6
for _ = 1, 40 do
  now = now + .31
  -- run every OnUpdate the module made for sending
  local i = 1
  while true do
    local fr = MG.testFrames and MG.testFrames[i]
    if not fr then break end
    fr:GetScript("OnUpdate")()
    i = i + 1
  end
end
local own, relayed = false, false
for _, m in ipairs(sent) do
  if m[2] == "B^hexakill^4200^87" then own = true end
  if m[2] == "R^hexakill^Friend^5100^90" then relayed = true end
end
ok(own and relayed, "a question is answered with our best and the best others we know (" .. table.getn(sent) .. " sent)")
-- relayed scores are kept; our own name is never taken from others
MG.Receive("R^gridshot^Farplayer^3000^80", "Friend")
MG.Receive("R^gridshot^Me^99999^99", "Friend")
s = MG.Store()
ok(s.board.gridshot and s.board.gridshot.Farplayer and s.board.gridshot.Farplayer.v == 3000 and not s.board.gridshot.Me,
  "a relayed best is kept, but nobody can set yours")
MG.Receive("R^gridshot^Bad|Name^1^1", "Friend")
ok(not s.board.gridshot["Bad|Name"], "odd names refused")
-- switched off: nothing opens until it is on again
pfUI_config.disabled = pfUI_config.disabled or {}
pfUI_config.disabled.minigames = "1"
MG.Close()
MG.Show("quiz")
ok(not MG.win:IsShown(), "switched off: the window does not open")
S.onflight = "quiz"
MG.FlightStart()
ok(not MG.win:IsShown(), "switched off: no pop-up on a flight")
pfUI_config.disabled.minigames = nil
S.onflight = "pick"

-- flights
MG.Close()
S.onflight = "quiz"
S.closeland = "1"
local flying = 1
_G.UnitOnTaxi = function() return flying end
MG.flying = nil
MG.FlightStart()
ok(MG.win:IsShown() and MG.cur == "quiz", "a flight opens the quiz")
MG.FlightEnd()
ok(not MG.win:IsShown(), "landing closes it")
S.onflight = "pick"
MG.FlightStart()
ok(MG.launcher:IsShown() and not MG.win:IsShown(), "\"pick\": the small launcher shows")
MG.FlightEnd()
ok(not MG.launcher:IsShown(), "and goes on landing")
-- a round running when you land finishes first
S.onflight = "aim"
MG.FlightStart()
AM.Start()
MG.FlightEnd()
ok(MG.win:IsShown(), "a running round keeps the window on landing")
AM.Finish()
ok(not MG.win:IsShown(), "it closes when the round ends")
S.onflight = "pick"

pfUI_cache.arcade = nil
for k, v in pairs(keep) do _G[k] = v end
