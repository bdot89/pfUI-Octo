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
