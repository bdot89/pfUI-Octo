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
  "GetNumPartyMembers", "UnitName", "PlaySound", "MouseIsOver", "GetCursorPosition", "GetRealmName" }) do keep[k] = rawget(_G, k) end
local now = 1000
_G.GetTime = function() return now end
_G.UnitAffectingCombat = function() return nil end
_G.UnitName = function(u) if u == "player" then return "Me" end end
_G.PlaySound = function() end
_G.GetRealmName = function() return "N'zoth" end
local S = MG.S()

-- the quiz
MG.Show("quiz")
ok(MG.win:IsShown() and MG.cur == "quiz" and MG.quiz.view == "lobby", "the quiz opens on the difficulty cards")
MG.quiz.Practice()
ok(MG.quiz.view == "practice" and MG.quiz.cur, "practice asks a question")
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

-- realm tags
ok(MG.RealmTag("N'zoth") == "NZ" and MG.RealmTag("Y'Shaarj") == "YS" and MG.RealmTag("C'Thun") == "CT"
  and MG.RealmTag("Nostalrius") == "NO" and MG.MyRealm() == "NZ", "realm tags NZ / YS / CT, others two letters")
-- points: faster is worth more, the difficulty multiplies, a streak adds up to 50%
do
  local N, M = qz.DIFF.normal, qz.DIFF.mythic
  ok(qz.Points(N, 20, 1) == 1000 and qz.Points(N, 0, 1) == 250 and qz.Points(N, 10, 1) > 250 and qz.Points(N, 10, 1) < 1000,
    "points fall from 1000 to 250 as the clock runs")
  ok(qz.Points(M, 10, 1) == 2000 and qz.Points(N, 20, 3) == 1200 and qz.Points(N, 20, 20) == 1500, "x2 on Mythic, streak bonus capped at +50%")
  ok(N.n == 10 and qz.DIFF.heroic.n == 25 and M.n == 40, "10, 25 and 40 questions")
end
-- a Normal run, every answer right
do
  local quiz = MG.pages.quiz:GetScript("OnUpdate")
  local sent = {}
  _G.SendAddonMessage = function(p, m, c) table.insert(sent, { p, m, c }) end
  _G.IsInGuild = function() return 1 end
  _G.GetNumRaidMembers = function() return 0 end
  _G.GetNumPartyMembers = function() return 0 end
  qz.StartRun("normal")
  ok(qz.view == "run" and qz.run.state == "count" and table.getn(qz.run.list) == 10, "a Normal run: 10 questions after a countdown")
  now = now + 3.1
  quiz()
  ok(qz.run.state == "ask" and qz.run.pos == 1, "then the first question")
  local seen, allCats = {}, {}
  for _ = 1, 10 do
    local r = qz.run
    seen[r.list[r.pos]] = true
    allCats[r.e.c] = true
    local at
    for i = 1, 4 do if r.order[i] == 1 then at = i end end
    now = now + 2
    qz.RunAnswer(at)
    now = now + 2
    quiz()
  end
  local n = 0
  for _ in pairs(seen) do n = n + 1 end
  local _, me3 = MG.Store()
  ok(n == 10 and qz.view == "result" and qz.run.right == 10, "ten different questions, all right, then the results")
  ok(me3.quiz.runs.normal and me3.quiz.runs.normal.score == qz.run.score and qz.run.score > 10000, "the best Normal run is kept (" .. qz.run.score .. ")")
  local shared
  for _, m in ipairs(sent) do if string.find(m[2], "^B%^qnormal%^%d+%^10%^NZ$") then shared = true end end
  ok(shared, "and goes to the guild on the Normal board")
  local rows = MG.Rows("qnormal")
  ok(rows[1] and rows[1].you and rows[1].realm == "NZ", "you top the Normal board, tagged NZ")
  -- a slow, wrong run does not replace it
  qz.StartRun("normal")
  now = now + 3.1
  quiz()
  now = now + 21
  quiz()
  ok(qz.run.marks[1] == "wrong" and qz.run.state == "shown", "out of time on a run: wrong, no points")
  for _ = 1, 30 do now = now + 25 quiz() end
  ok(qz.view == "result" and qz.run.score == 0 and me3.quiz.runs.normal.score > 10000, "a run with no points keeps the old best")
  -- closing the window mid-run ends it
  qz.StartRun("mythic")
  ok(table.getn(qz.run.list) == 40, "Mythic: 40 questions")
  MG.Close()
  ok(not qz.run and qz.view == "lobby", "closing the window mid-run ends the run")
  MG.Show("quiz")
  ok(qz.view == "lobby", "and the tab opens on the cards again")
end
-- boards with realms
do
  MG.Receive("B^qmythic^52000^38^YS", "Yshplayer")
  MG.Receive("B^qmythic^41000^35^CT", "Cthplayer")
  MG.Receive("R^qmythic^Twin^30000^30^YS", "Friend")
  MG.Receive("R^qmythic^Twin^31000^31^CT", "Friend")
  MG.Receive("B^qmythic^1^1^yS", "Lowercase")
  local rows = MG.Rows("qmythic")
  ok(rows[1] and rows[1].name == "Yshplayer" and rows[1].realm == "YS" and rows[2].realm == "CT", "boards carry the realm (" .. tostring(rows[1] and rows[1].realm) .. ")")
  ok(MG.Entry("qmythic", "Twin", "YS").v == 30000 and MG.Entry("qmythic", "Twin", "CT").v == 31000, "the same name on two realms is two players")
  ok(not MG.Entry("qmythic", "Lowercase", "yS") and not MG.Entry("qmythic", "Lowercase"), "a bad realm tag is refused")
  -- kept before realms were: taken as ours
  local s3 = MG.Store()
  s3.board.gridshot = s3.board.gridshot or {}
  s3.board.gridshot.Oldie = { v = 10, t = 1 }
  ok(MG.Rows("gridshot")[1] and true, "old entries still show")
  MG.Keep("gridshot", "Oldie", 20, 50)
  ok(not s3.board.gridshot.Oldie and s3.board.gridshot["Oldie-NZ"].v == 20, "an old entry moves to its realm key")
  -- the Scores tab
  MG.boardSel = "qmythic"
  MG.Show("board")
  local t = MG.pages.board.table
  ok(t.rows[1]:IsShown() and t.rows[1].tag:GetText() == "YS" and t.rows[1].name:GetText() == "Yshplayer", "the Scores tab shows realm tags")
  for _, b in ipairs(MG.BOARDS) do
    MG.boardSel = b.key
    ok(pcall(MG.Board), "board " .. b.key .. " draws")
  end
  -- the realm channel line carries the tag and the quiz boards
  local line = MG.RealmLine()
  ok(line and string.find(line, "^OA1 @NZ ") and string.find(line, "qnormal:%d+:10"), "the realm line has @NZ and the quiz runs: " .. tostring(line))
  local before = MG.Entry("qheroic", "Farrealm", "CT")
  MG.ReadRealm("OA1 @CT qheroic:9000:20 gridshot:500:70", "Farrealm")
  ok(not before and MG.Entry("qheroic", "Farrealm", "CT").v == 9000, "a realm line is kept under its realm")
  MG.Show("quiz")
  local _, me4 = MG.Store()
  ok(qz.view == "lobby" and tostring(qz.lb.cards[1].best:GetText()) == tostring(me4.quiz.runs.normal.score)
    and string.find(qz.lb.cards[3].top:GetText() or "", "Yshplayer", 1, true), "the lobby cards show your best and each board's leader")
end

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
-- pick another mode in the middle of a round: it stops, the new mode is ready
S.aimmode = "gridshot"
AM.Start()
local chip
for _, b in ipairs(MG.pages.aim.chips) do if b.key == "hexakill" then chip = b end end
_G.this = chip
chip:GetScript("OnClick")()
ok(AM.state == "idle" and S.aimmode == "hexakill" and table.getn(AM.live) == 0, "a mode can be picked while a round runs")
-- 3, 2, 1, GO!
AM.Begin()
ok(AM.state == "count" and table.getn(AM.live) == 0, "a countdown first")
now = now + 2.3
MG.pages.aim:GetScript("OnUpdate")()
ok(AM.state == "run" and table.getn(AM.live) == 6, "then the round (Hexakill: six targets)")
AM.Finish(true)
-- grades
ok(AM.Grade(97, true) == "S" and AM.Grade(90) == "A" and AM.Grade(80) == "B" and AM.Grade(50) == "D", "grades from accuracy")
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
ok(sent[1] and sent[1][1] == "pfArc" and sent[1][2] == "B^hexakill^4200^87^NZ" and sent[1][3] == "GUILD", "a best goes to the guild as B^mode^score^accuracy^realm")
MG.Receive("B^hexakill^5100^90", "Friend")
MG.Receive("B^hexakill^100^10", "Friend")
MG.Receive("B^nosuchmode^1^1", "Friend")
local s = MG.Store()
ok(MG.Entry("hexakill", "Friend") and MG.Entry("hexakill", "Friend").v == 5100 and not s.board.nosuchmode, "others' bests kept (the higher one)")
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
  if m[2] == "B^hexakill^4200^87^NZ" then own = true end
  if m[2] == "R^hexakill^Friend^5100^90^NZ" then relayed = true end
end
ok(own and relayed, "a question is answered with our best and the best others we know (" .. table.getn(sent) .. " sent)")
-- relayed scores are kept; our own name is never taken from others
MG.Receive("R^gridshot^Farplayer^3000^80", "Friend")
MG.Receive("R^gridshot^Me^99999^99", "Friend")
s = MG.Store()
ok(MG.Entry("gridshot", "Farplayer") and MG.Entry("gridshot", "Farplayer").v == 3000 and not MG.Entry("gridshot", "Me"),
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

-- the realm channel: one line a login, read by everyone in it, never shown in chat
do
  local keep2 = {}
  for _, k in ipairs({ "JoinChannelByName", "GetChannelName", "SendChatMessage", "LeaveChannelByName" }) do keep2[k] = rawget(_G, k) end
  local joined, said = 0, {}
  local chanId = 0
  _G.JoinChannelByName = function(n) if n == "OctoArcade" then joined = joined + 1 chanId = 5 end end
  _G.GetChannelName = function(n) if n == "OctoArcade" then return chanId end return 0 end
  _G.SendChatMessage = function(msg, kind, lang, id) table.insert(said, { msg, kind, id }) end
  local envSend = pfUI.env and rawget(pfUI.env, "SendChatMessage")
  if pfUI.env then pfUI.env.SendChatMessage = _G.SendChatMessage end
  local _, me2 = MG.Store()
  me2.aim.gridshot = { score = 1234, acc = 88 }
  me2.quiz.best = 7
  local line = MG.RealmLine()
  ok(line and string.sub(line, 1, 4) == "OA1 " and string.find(line, "gridshot:1234:88") and string.find(line, "quiz:7:0")
    and not string.find(line, "|"), "one plain line with every best: " .. tostring(line))
  S.realm, S.share = "1", "1"
  MG.realmSaid = nil
  MG.JoinRealm()
  MG.SayRealm()
  MG.SayRealm()
  local tick = MG.chanTick:GetScript("OnUpdate")
  local function Run(secs)
    for _ = 1, secs * 4 do
      now = now + .25
      _G.this = MG.chanTick
      tick()
    end
  end
  Run(2)
  ok(joined == 1 and table.getn(said) == 1 and said[1][2] == "CHANNEL" and said[1][3] == 5, "joined, and said once on the channel (joined " .. joined .. ", said " .. table.getn(said) .. ", " .. tostring(said[1] and said[1][2]) .. " " .. tostring(said[1] and said[1][3]) .. ")")
  ok(string.find(said[1][1], "^OA1 @NZ %? ") and string.find(said[1][1], "gridshot:1234:88"), "the login line asks for the boards: " .. said[1][1])
  -- a new best goes to the whole realm a few seconds later, two in a row as one line
  said = {}
  me2.aim.reflex = { score = 3300, acc = 91 }
  MG.Share("reflex", 3300, 91)
  me2.aim.hexakill = { score = 6100, acc = 80 }
  MG.Share("hexakill", 6100, 80)
  Run(1)
  ok(table.getn(said) == 0, "not at once")
  Run(4)
  ok(table.getn(said) == 1 and string.find(said[1][1], "^OA1 @NZ hexakill:6100:80 reflex:3300:91$"), "then one line with both new bests: " .. tostring(said[1] and said[1][1]))
  -- someone logs in and asks: we answer with the top 3 of every board, unless someone else answers first
  said = {}
  MG.answerHeard, MG.answerSent = nil, nil
  MG.ReadRealm("OA1 @YS ? qnormal:900:3", "Newbie")
  ok(MG.answerAt and MG.Entry("qnormal", "Newbie", "YS").v == 900, "a login line is read, and an answer is planned")
  Run(14)
  local answer, short = "", true
  for _, m in ipairs(said) do
    answer = answer .. m[1] .. "\n"
    if string.len(m[1]) > 255 or string.sub(m[1], 1, 8) ~= "OA2 @NZ " then short = false end
  end
  ok(said[1] and short and string.find(answer, "reflex:Me%-NZ:3300:91") and string.find(answer, "qmythic:Yshplayer%-YS:52000:38")
    and not string.find(answer, "|"), "the answer: the boards, with realms, in short lines: " .. answer)
  said = {}
  MG.ReadRealm("OA1 @CT ? gridshot:10:10", "Another")
  ok(not MG.answerAt, "we answered a moment ago: someone else's turn")
  MG.answerSent = nil
  MG.ReadRealm("OA1 @CT ? gridshot:10:10", "Another")
  MG.ReadRealm("OA2 @CT qmythic:Topdog-CT:88000:40 gridshot:Aimer-YS:9000:95", "Fasterone")
  Run(14)
  ok(table.getn(said) == 0 and MG.Entry("qmythic", "Topdog", "CT").v == 88000 and MG.Entry("gridshot", "Aimer", "YS").v == 9000,
    "another answer came first: we stay quiet, and its boards are kept")
  -- reading someone's line
  local n = MG.ReadRealm("OA1 hexakill:7000:92 quiz:12:0 reflex:2500:80", "Otherrealmer")
  ok(n == 3 and MG.Entry("hexakill", "Otherrealmer").v == 7000 and MG.Entry("quiz", "Otherrealmer").v == 12, "a realm line fills the board")
  ok(not MG.ReadRealm("hello there", "Chatter"), "ordinary chat is ignored")
  -- hidden from the chat
  ok(MG.IsOurChannel("OctoArcade", "5. OctoArcade") and not MG.IsOurChannel("World", "1. World"), "our channel is recognised")
  -- switched off: nothing is said
  S.realm = "0"
  MG.realmSaid = nil
  said = {}
  MG.SayRealm()
  ok(table.getn(said) == 0, "realm sharing off: nothing is said")
  S.realm = "1"
  for k, v in pairs(keep2) do _G[k] = v end
  if pfUI.env then pfUI.env.SendChatMessage = envSend end
end

-- the launcher's light never leaves the sign
do
  local mq = MG.launcher.marquee
  local w = mq:GetWidth() or 328
  local outside
  for i = 0, 50 do
    MG.PaintSweep(i / 50)
    for _, t in ipairs(mq.beams) do
      if t:IsShown() then
        local _, _, _, x = t:GetPoint(3)
        local tw = t:GetWidth() or 0
        if (x or 0) < -0.01 or (x or 0) + tw > w + 0.01 then outside = (x or 0) .. "+" .. tw end
      end
    end
  end
  ok(not outside, "the sweep of light stays inside the sign" .. (outside and (" (" .. outside .. ")") or ""))
  MG.PaintSweep(1.5)
  local any
  for _, t in ipairs(mq.beams) do if t:IsShown() then any = true end end
  ok(not any, "between sweeps there is no light")
end

pfUI_cache.arcade = nil
for k, v in pairs(keep) do _G[k] = v end
