-- pfUI Octo combat text: the detailed tests that came with the engine from
-- OctoBG (its tests\run.lua, 19 Oct 2026), run by tests\run.lua after the
-- basic ones. Nampower events drive it as in game; the mock gives nameplates
-- (Mock.Plate) and units (Mock.Enemy).
local ok = octo_ok
local B = pfUI.sctB
local CT = B.SCT

-- start from the default settings (earlier tests changed some)
local function Wipe(t) for k in pairs(t) do t[k] = nil end end
local function Fill(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      Fill(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end
Wipe(B.db.sct)
Fill(B.db.sct, B.DEFAULTS.sct)
Mock.party, Mock.raid = 0, 0
Mock.target = nil
-- a unit OctoBG's tests made earlier (a healer by GUID below)
Mock.Enemy("0x00000000000000A1", "Rogueone", "ROGUE", 1, 1)

-- events and the clock reach only the combat text (the rest of pfUI needs
-- more of the client than the mock has)
local function Fire(ev, a1, a2, a3, a4, a5, a6, a7, a8, a9)
  B.Dispatch(ev, a1, a2, a3, a4, a5, a6, a7, a8, a9)
end
local function Tick(seconds, dt)
  dt = dt or 0.05
  local t = 0
  while t < seconds do
    Mock.now = Mock.now + dt
    Mock.clock = Mock.clock + dt
    for _, f in ipairs({ pfSCTCore, pfCombatTextContainer }) do
      if f and f.scripts.OnUpdate then Mock.Run(f, "OnUpdate", dt) end
    end
    t = t + dt
  end
end

local CT = B.SCT
local ME = "0x0000000000000001"
local FOE = "0x00000000000000C1"
Mock.Enemy(FOE, "Punchbag", "WARRIOR", 15, 0)
CT:Clear()
local function LiveText(match)
  for i = 1, CT.nlive do
    local o = CT.live[i]
    if string.find(o.fs.text or "", match, 1, true) then return o end
  end
  return nil
end
ok(CT.panels.inc and CT.panels.note, "combat text areas built")

-- your melee crit on an enemy with a nameplate: rises from the plate
local plate = Mock.Plate(FOE)
Mock.target = FOE
Fire("AUTO_ATTACK_SELF", ME, FOE, 512, 0x80, 1, 1, 0, 0, 0)
local o = LiveText("512")
ok(o and o.plate == plate, "your melee rises from the enemy's nameplate")
ok(o and o.crit, "melee crit flagged (hitInfo 0x80)")
-- no plate: the fallback area
local FOE2 = "0x00000000000000C2"
Mock.Enemy(FOE2, "Noplate", "MAGE", 20, 5)
Fire("AUTO_ATTACK_SELF", ME, FOE2, 333, 0, 1, 1, 0, 0, 0)
o = LiveText("333")
ok(o and not o.plate and o.areaKey == "out", "no plate: falls back to Outgoing")
-- a dodge on your swing: miss text and the Overpower reactive (the book knows it)
Fire("SPELLS_CHANGED")
Fire("AUTO_ATTACK_SELF", ME, FOE, 0, 0, 2, 1, 0, 0, 0)
ok(LiveText("Dodge"), "your dodged swing shows Dodge")
ok(LiveText("Overpower!"), "Overpower alert after a dodge")

-- spells on screen with merging
B.db.sct.events.outSpell.area = "out"
Fire("SPELL_DAMAGE_EVENT_SELF", FOE, ME, 133, 400, "0,0,0", 0, 2, "0,0,0,0")
Fire("SPELL_DAMAGE_EVENT_SELF", FOE2, ME, 133, 450, "0,0,50", 2, 2, "0,0,0,0")
ok(not LiveText("850"), "merge waits for the window")
Tick(0.6)
ok(LiveText("850 x2"), "two hits merged into one text (" .. tostring(LiveText("x2") and LiveText("x2").fs.text) .. ")")
-- a DoT tick (aura type 3)
B.db.sct.events.outDot.area = "out"
B.db.sct.merge = false
Fire("SPELL_DAMAGE_EVENT_SELF", FOE, ME, 172, 77, "0,0,0", 0, 5, "0,0,0,3")
ok(LiveText("77"), "damage over time tick")

-- incoming
Fire("AUTO_ATTACK_OTHER", FOE, ME, 300, 0, 1, 1, 20, 0, 0)
o = LiveText("-300")
ok(o and o.areaKey == "inc", "melee hit on you in Incoming")
ok(o and string.find(o.fs.text, "blocked", 1, true), "blocked amount shown")
Fire("AUTO_ATTACK_OTHER", FOE, ME, 0, 0, 3, 1, 0, 0, 0)
ok(LiveText("Parry"), "your parry shows")
ok(LiveText("Revenge!"), "Revenge alert after your parry")
Fire("SPELL_MISS_OTHER", FOE, ME, 116, 2)
ok(LiveText("Resist"), "resisted spell on you")
Fire("SPELL_DAMAGE_EVENT_OTHER", ME, FOE, 116, 640, "0,0,0", 2, 4, "0,0,0,0")
ok(LiveText("-640"), "spell crit on you")
Fire("SPELL_HEAL_ON_SELF", ME, "0x00000000000000D1", 2061, 1300, 1, 0)
ok(LiveText("+1300"), "heal on you")
Fire("SPELL_ENERGIZE_ON_SELF", ME, ME, 29131, 1, 20, 0)
ok(LiveText("+20 Rage"), "rage gain")
Fire("ENVIRONMENTAL_DMG_SELF", ME, 2, 220, 0, 0)
ok(LiveText("Falling"), "falling damage")
-- auras and procs
B.db.sct.procs = "Spell16870"
Fire("BUFF_ADDED_SELF", ME, 3, 16870, 1, 60, 2, 0)
ok(LiveText("Spell16870!"), "proc alert for a listed buff")
Fire("BUFF_ADDED_SELF", ME, 4, 1243, 1, 60, 3, 0)
ok(LiveText("[Spell1243]"), "buff gained")
Fire("DEBUFF_ADDED_SELF", ME, 1, 12826, 1, 60, 32, 0)
ok(LiveText("[Spell12826]"), "debuff on you")
-- (user, 26 Oct 2026: "[Inner Fire (30)]" twice) the same aura news twice
-- shows once; charges going down show nothing
local function LiveCount(match)
  local n = 0
  for i = 1, CT.nlive do
    if string.find(CT.live[i].fs.text or "", match, 1, true) then n = n + 1 end
  end
  return n
end
Fire("BUFF_ADDED_SELF", ME, 5, 588, 30, 60, 4, 2)
Fire("BUFF_ADDED_SELF", ME, 5, 588, 30, 60, 4, 2)
ok(LiveCount("[Spell588 (30)]") == 1, "the same stacks news twice: one text (" .. LiveCount("[Spell588 (30)]") .. ")")
Fire("BUFF_ADDED_SELF", ME, 5, 588, 29, 60, 4, 2)
ok(LiveCount("[Spell588 (29)]") == 0, "a charge used up: no text")
-- low health, combo points, interrupt
Mock.playerHp = 30
Fire("UNIT_HEALTH", "player")
ok(LiveText("Low Health!"), "low health warning")
Mock.playerHp = 100
Mock.cp = 5
Fire("PLAYER_COMBO_POINTS")
B.db.sct.events.combo.on = true
Mock.cp = 0
Fire("PLAYER_COMBO_POINTS")
Mock.cp = 5
Fire("PLAYER_COMBO_POINTS")
ok(LiveText("Finish It!"), "five combo points")
Fire("SPELLCAST_INTERRUPTED")
ok(LiveText("Interrupted!"), "your cast interrupted")
-- chat lines from the client's own formats
Fire("CHAT_MSG_COMBAT_HONOR_GAIN", "Punchbag dies, honorable kill Rank: Sergeant (Estimated Honor Points: 198)")
ok(LiveText("+198 Honor"), "honor gain")
Fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Your Warsong Outriders reputation has increased by 35.")
ok(LiveText("35 Warsong Outriders"), "reputation gain")
Fire("CHAT_MSG_SKILL", "Your skill in Swords has increased to 287.")
ok(LiveText("Swords: 287"), "skill gain")
Fire("CHAT_MSG_COMBAT_HOSTILE_DEATH", "You have slain Punchbag!")
ok(LiveText("Killing Blow! Punchbag"), "killing blow")
B.db.sct.events.loot.on, B.db.sct.events.money.on, B.db.sct.events.xp.on = true, true, true
Fire("CHAT_MSG_LOOT", "You receive loot: |cff1eff00|Hitem:2589:0:0:0|h[Linen Cloth]|h|rx3.")
ok(LiveText("+Linen Cloth x3"), "loot with count")
Fire("CHAT_MSG_MONEY", "You loot 1 Gold, 5 Silver")
ok(LiveText("+1 Gold, 5 Silver"), "money")
Fire("CHAT_MSG_COMBAT_XP_GAIN", "Defias Thug dies, you gain 120 experience.")
ok(LiveText("+120 XP"), "experience")
Fire("CHAT_MSG_SPELL_SELF_BUFF", "You gain 1 extra attack through Sword Specialization.")
ok(LiveText("Extra Attack!"), "extra attack")
Fire("CHAT_MSG_SPELL_SELF_DAMAGE", "You interrupt Punchbag's Frostbolt.")
ok(LiveText("Interrupted Punchbag: Frostbolt"), "your interrupt")
-- cooldown ready
Mock.cdStart = GetTime()
Mock.book[4][2] = 2
B.db.sct.cdReadyMin = 2
Fire("SPELL_UPDATE_COOLDOWN")
Tick(0.5)
Tick(2)
ok(LiveText("Recklessness ready!"), "cooldown ready")
-- OctoBG's alerts arrive through CT:Notify (OctoBG's SCTLink.lua)
B.db.sct.events.obgCd.on = true
CT:Notify("obgCd", "Punchbag: Ice Block")
ok(LiveText("Punchbag: Ice Block"), "OctoBG's enemy cooldown alert as combat text")
-- every movement and crit style, in an area and on the plate
for i = 1, table.getn(CT.MOVES) do
  B.db.sct.areas.extra.enabled = true
  B.db.sct.areas.extra.anim = CT.MOVES[i].key
  B.db.sct.plates.hit = CT.MOVES[i].key
  CT:Show("m" .. i, 1, 1, 1, "extra", {})
  CT:Show("p" .. i, 1, 1, 1, "plate", { guid = FOE, target = true })
  Tick(0.1)
end
for i = 1, table.getn(CT.CRITS) do
  B.db.sct.areas.extra.crit = CT.CRITS[i].key
  B.db.sct.plates.crit = CT.CRITS[i].key
  CT:Show("c" .. i, 1, 0, 0, "extra", { crit = true })
  CT:Show("pc" .. i, 1, 0, 0, "plate", { crit = true, guid = FOE, target = false, kind = "crit" })
end
-- (user, 26 Oct 2026: "give crits options for movement same as hits") a crit's
-- entrance and movement are two settings; old settings keep their look
do
  local X = B.db.sct.areas.extra
  CT:Clear()
  X.anim, X.crit, X.critPath, X.critOwn = "vertical", "pow", nil, nil
  CT:Show("old", 1, 0, 0, "extra", { crit = true })
  ok(LiveText("old") and LiveText("old").move == "pin", "an old Pow crit still stays in place")
  X.critPath = "fountain"
  CT:Show("own", 1, 0, 0, "extra", { crit = true })
  local o = LiveText("own")
  ok(o and o.move == "fountain" and o.critStyle == "pow", "a Pow crit can move: slams in, then flies like a fountain")
  X.critPath = "same"
  CT:Show("same", 1, 0, 0, "extra", { crit = true })
  ok(LiveText("same") and LiveText("same").move == "vertical", "crits can move the same as the hits")
  X.critOwn, X.critTime, X.critHeight = true, 5, 333
  CT:Show("long", 1, 0, 0, "extra", { crit = true })
  o = LiveText("long")
  ok(o and o.H == 333 and o.dur > X.time, "crits have their own time and travel")
  X.critOwn, X.critPath = nil, nil
  local P = B.db.sct.plates
  local savedMove, savedCrit = P.critMove, P.crit
  P.crit, P.critMove, P.critPath = "flash", "rainfall", nil
  CT:Show("pold", 1, 0, 0, "plate", { crit = true, guid = FOE, target = true, kind = "crit" })
  ok(LiveText("pold") and LiveText("pold").move == "rainfall", "an old nameplate crit movement still applies")
  P.critPath = "still"
  CT:Show("pstill", 1, 0, 0, "plate", { crit = true, guid = FOE, target = true, kind = "crit" })
  ok(LiveText("pstill") and LiveText("pstill").move == "pin", "nameplate crits can stay in place with any entrance")
  P.critPath, P.critMove, P.crit = nil, savedMove, savedCrit
  CT:Clear()
end
-- (user, 26 Oct 2026: "horizontal choice should show left and right ... vertical up and down ... diagonal")
do
  local X = B.db.sct.areas.extra
  local function Keys(move, t, crit)
    local s = {}
    for _, c in ipairs(CT.AimControls(move, t, crit)) do table.insert(s, c.key) end
    return table.concat(s, ",")
  end
  ok(Keys("horizontal", {}) == "lean,side", "horizontal offers its height and side (" .. Keys("horizontal", {}) .. ")")
  ok(Keys("vertical", {}) == "dir,lean", "vertical offers up / down and straight / diagonal")
  ok(Keys("vertical", { lean = "side" }) == "dir,lean,side,leanAmt", "a diagonal to the side adds Side and Angle")
  ok(Keys("vertical", { lean = "left" }) == "dir,lean,leanAmt", "a diagonal left adds Angle only")
  ok(Keys("fireworks", {}) == "", "fireworks have nothing to turn")
  ok(Keys("horizontal", { lean = "rise" }, true) == "critLean,critSide,critLeanAmt", "crit choices use the crit keys")
  CT:Clear()
  X.anim, X.dir, X.lean, X.leanAmt, X.side = "vertical", "up", "right", 1, "alt"
  CT:Show("lean", 1, 1, 1, "extra", {})
  local o = LiveText("lean")
  Tick(0.5)
  local x, y = CT.Bend(o, CT.MOVE.vertical(o, 0.5))
  ok(o.lean == 1 and x > 0 and math.abs(x - y) < 0.01, "vertical leans right at 45 degrees")
  X.anim, X.lean, X.side = "horizontal", "level", "left"
  CT:Show("lvl", 1, 1, 1, "extra", {})
  o = LiveText("lvl")
  x, y = CT.Bend(o, CT.MOVE.horizontal(o, 0.5))
  ok(o.flat and y == 0 and x < 0, "horizontal can go level, always left")
  X.lean = "fall"
  CT:Show("fall", 1, 1, 1, "extra", {})
  o = LiveText("fall")
  x, y = CT.Bend(o, CT.MOVE.horizontal(o, 0.5))
  ok(y < 0, "horizontal can fall diagonally")
  X.dir, X.anim = "alt", "vertical"
  CT:Show("a1", 1, 1, 1, "extra", {})
  CT:Show("a2", 1, 1, 1, "extra", {})
  ok(LiveText("a1").d == -LiveText("a2").d, "up and down taking turns")
  X.side = "random"
  CT:Show("r", 1, 1, 1, "extra", {})
  ok(LiveText("r").s == 1 or LiveText("r").s == -1, "random side")
  -- a crit with its own movement turns its own way; the hits keep theirs
  X.anim, X.dir, X.lean, X.side, X.leanAmt = "vertical", "up", nil, "alt", nil
  X.critPath, X.critDir = "vertical", "down"
  CT:Show("cdown", 1, 0, 0, "extra", { crit = true })
  CT:Show("hup", 1, 1, 1, "extra", {})
  ok(LiveText("cdown").d == -1 and LiveText("hup").d == 1, "crits can go down while hits go up")
  X.critPath, X.critDir = nil, nil
  CT:Clear()
end
for _, d in ipairs({ "down", "up" }) do
  B.db.sct.areas.extra.dir = d
  for _, s in ipairs({ "alt", "dmgLeft", "dmgRight", "left", "right" }) do
    B.db.sct.areas.extra.side = s
    B.db.sct.areas.extra.anim = "sprinkler"
    CT:Show("s", 1, 1, 1, "extra", { heal = true })
  end
end
Tick(4)
ok(CT.nlive == 0 or CT.nlive < 10, "texts expire (" .. CT.nlive .. " left)")
-- a burst never exceeds the limit
for i = 1, 150 do CT:Show(tostring(i), 1, 1, 1, "inc", {}) end
ok(CT.nlive <= 90, "at most 90 texts on screen")
CT:Clear()
-- the plate goes away mid-animation: its texts end
CT:Show("bye", 1, 1, 1, "plate", { guid = FOE, target = true })
plate.shown = false
Tick(0.1)
ok(not LiveText("bye"), "text ends when its nameplate hides")
-- test mode: rounds on every nameplate for a minute
CT:Clear()
plate.shown = true
CT:TestMode(true)
ok(CT:Testing(), "combat text test mode on")
Tick(0.9)
local onPlate = false
for i = 1, CT.nlive do if CT.live[i].plate == plate then onPlate = true end end
ok(onPlate and CT.nlive >= 2, "test mode puts text on the nameplate and in the areas (" .. CT.nlive .. ")")
CT:TestMode(false)
ok(not CT:Testing(), "test mode off")
CT:Clear()
CT:TestPlates()
ok(LiveText("2468") and LiveText("+850"), "test on nameplates")
CT:Clear()
SlashCmdList.PFUI("sct test")
ok(CT:Testing(), "/pfui sct test")
Tick(61)
ok(not CT:Testing(), "test mode ends after a minute")
CT:Clear()
-- previews, commands
CT:Preview("normal")
CT:Preview("crit")
CT:Preview("plate")
SlashCmdList.PFUISCTDISPLAY("'Heal Me' 10 0 0")
ok(LiveText("Heal Me"), "/sctdisplay")
CT:GameNumbers("dmg", false)
ok(Mock.cvars.CombatDamage == "0", "game damage numbers off")
Tick(5)

-- ---------------------------------------------------------------- on / off, crits, Blizzard numbers, sounds, fonts
CT:SetEnabled(false)
ok(not B.db.sct.enabled and Mock.cvars.CombatDamage == "1" and Mock.cvars.PetMeleeDamage == "1", "off: the game's own numbers are back")
CT:Show("nope", 1, 1, 1, "out", {})
ok(not LiveText("nope"), "off: nothing shown")
SlashCmdList.PFUI("sct on")
ok(B.db.sct.enabled and Mock.cvars.CombatDamage == "0", "/pfui sct on: ours again, the game's off")
-- Blizzard's scrolling text over you (LoadOnDemand): the switch takes it along,
-- and healer GUIDs ("+875 [0x...]") become names even when it loads late
local fctMsgs, fctUpdates = {}, 0
LoadAddOn = function(name)
  if name == "Blizzard_CombatText" then
    CombatText = CreateFrame("Frame")
    CombatText_UpdateDisplayedMessages = function() fctUpdates = fctUpdates + 1 end
    CombatText_AddMessage = function(m) table.insert(fctMsgs, m) end   -- the game's own, unhooked
    Fire("ADDON_LOADED", "Blizzard_CombatText")
  end
end
SHOW_COMBAT_TEXT = "0"
CT:SetEnabled(false)
ok(SHOW_COMBAT_TEXT == "1" and fctUpdates >= 1, "off: Blizzard's scrolling text back on and updated")
CombatText_AddMessage("+875 [0x00000000000000A1]")
CombatText_AddMessage("+500 [0x00000000000000FF]")
ok(fctMsgs[1] == "+875 [Rogueone]" and fctMsgs[2] == "+500", "healer GUIDs shown as names (" .. tostring(fctMsgs[1]) .. ", " .. tostring(fctMsgs[2]) .. ")")
SlashCmdList.PFUI("sct on")
ok(SHOW_COMBAT_TEXT == "0", "on: Blizzard's scrolling text off, so heals don't show twice")
LoadAddOn, CombatText, CombatText_UpdateDisplayedMessages, CombatText_AddMessage, SHOW_COMBAT_TEXT = nil, nil, nil, nil, nil
CT:Clear()
local L = B.db.sct.critLook
L.mark, L.tint, L.glow = "bang", true, true
CT:Show("2468", 1, 1, 1, "out", { crit = true })
local oc = LiveText("2468!")
ok(oc and oc.hasGlow and oc.glow:IsShown(), "crit: marked and flashing")
ok(oc and oc.fs.color and oc.fs.color[1] == L.r and oc.fs.color[2] == L.g, "crit in its own colour")
L.mark, L.tint = "none", false
B.db.sct.style = "blizzard"
B.db.sct.events.outSpell.area = "plate"
Mock.target = FOE
Fire("SPELL_DAMAGE_EVENT_SELF", FOE, ME, 585, 1183, "0,0,0", 2, 1, "0,0,0,0")
local ob = LiveText("1183")
ok(ob and ob.fs.text == "1183" and ob.fs.color[1] == 1 and ob.fs.color[2] == 1 and ob.fs.color[3] == 0,
  "Blizzard numbers: a bare yellow number for a spell (" .. tostring(ob and ob.fs.text) .. ")")
ok(ob and ob.critStyle == "blizzard" and ob.move == "vertical", "Blizzard numbers: the crit pops and moves straight up")
Tick(0.1)
ok(ob and ob.scale and ob.scale > 1, "the pop swells the crit")
B.db.sct.style = "octo"
L.numberOnly = true
Tick(1)
Fire("SPELL_DAMAGE_EVENT_SELF", FOE, ME, 133, 2222, "0,0,0", 2, 2, "0,0,0,0")
ok(LiveText("2222") and LiveText("2222").fs.text == "2222", "crits show only the number")
L.numberOnly = false
CT:Clear()
Fire("CHAT_MSG_COMBAT_HOSTILE_DEATH", "You have slain Punchbag!")
local okb = LiveText("Killing Blow!")
ok(okb and okb.hasGlow, "killing blow is ticked big: flash")
local wasCrit = B.db.sct.events.killBlow.crit
B.db.sct.events.killBlow.big, B.db.sct.events.killBlow.crit = false, false
CT:Clear()
Fire("CHAT_MSG_COMBAT_HOSTILE_DEATH", "You have slain Punchbag!")
ok(LiveText("Killing Blow!") and not LiveText("Killing Blow!").hasGlow, "unticked big and crit: a plain text")
B.db.sct.events.killBlow.big, B.db.sct.events.killBlow.crit = true, wasCrit
CT:Clear()
local sBefore = table.getn(Mock.sounds)
CT.PlaySound("gun1")
ok(Mock.sounds[sBefore + 1] == "Sound\\Item\\Weapons\\Gun\\GunFire01.wav", "gunshot sound")
B.db.sct.mySounds[2] = "finishhim.mp3"
CT.PlaySound("my2")
ok(Mock.sounds[sBefore + 2] == "Interface\\AddOns\\pfUI\\img\\sct\\sounds\\custom\\finishhim.mp3", "your own sound file")
CT.PlaySound("my3")
ok(table.getn(Mock.sounds) == sBefore + 2, "an empty sound slot plays nothing")
B.db.sct.killSound = "ragslay"
local nSounds = 0
for i = 1, table.getn(CT.SOUNDS) do if CT.SOUNDS[i].key then nSounds = nSounds + 1 end end
ok(nSounds >= 50, nSounds .. " sounds to pick from")

-- ---------------------------------------------------------------- nameplates: merging, stacking, edge
CT:Clear()
plate.shown = true
Mock.target = FOE
Fire("AUTO_ATTACK_SELF", ME, FOE, 300, 0, 1, 1, 0, 0, 0)
Fire("AUTO_ATTACK_SELF", ME, FOE, 200, 0, 1, 1, 0, 0, 0)
ok(LiveText("500 x2") and not LiveText("300"), "the same swing twice on one plate adds up")
Tick(0.5)
Fire("AUTO_ATTACK_SELF", ME, FOE, 111, 0, 1, 1, 0, 0, 0)
ok(LiveText("111") and LiveText("500 x2"), "after the merge window: a new text")
B.db.sct.plates.hit = "vertical"
CT:Clear()
CT:Show("first", 1, 1, 1, "plate", { guid = FOE, target = true })
CT:Show("second", 1, 1, 1, "plate", { guid = FOE, target = true })
local o1, o2 = LiveText("first"), LiveText("second")
ok(o1 and o2 and o1.start < o2.start, "lines on a plate stack instead of overlapping")
-- (1 Nov 2026) two texts at once in one screen area on opposite sides stack too
CT:Clear()
CT:Show("tick one", 0, 1, 0, "healing", {})
local t1 = LiveText("tick one")
if t1 then t1.side = -t1.side end
CT:Show("tick two", 0, 1, 0, "healing", {})
local t2 = LiveText("tick two")
ok(t1 and t2 and t1.lane == t2.lane and t1.start < t2.start, "two texts at once in one area keep a line apart, whatever their side")
-- the notification area: a big crit message (killing blow) and a normal one take lines
do
  local note = B.db.sct.areas.note
  if note and note.anim == "static" then
    CT:Clear()
    CT:Show("xp line", 1, 1, 0, "note", {})
    CT:Show("killing blow", 1, 0, 0, "note", { crit = true, big = true })
    local x, k = LiveText("xp line"), LiveText("killing blow")
    ok(x and k and x.move == "static" and k.move == "static" and x.slot ~= k.slot,
      "a killing blow and an XP line in the notification area take separate lines")
  end
end
-- two areas placed on one spot share the lane (a mana gain and a heal of one tick)
do
  local areas = B.db.sct.areas
  local h, i = areas.heal, areas.inc
  if h and i and h.x and i.x then
    local kx, ky = i.x, i.y
    i.x, i.y = h.x, h.y
    CT:Clear()
    CT:Show("mana tick", 0, 0, 1, "heal", {})
    CT:Show("heal tick", 0, 1, 0, "inc", {})
    local m, hh = LiveText("mana tick"), LiveText("heal tick")
    ok(m and hh and m.lane == hh.lane and m.start < hh.start, "texts from two areas on one spot keep a line apart")
    i.x, i.y = kx, ky
  end
end
B.db.sct.plates.hit = "fountain"
-- a plate at the left edge of the screen: its text stays inside
plate.GetCenter = function() return 2, 300 end
plate.GetEffectiveScale = function() return 1 end
pfCombatTextContainer.GetEffectiveScale = function() return 1 end
pfCombatTextContainer.w, pfCombatTextContainer.h = 1024, 768
CT:Show("edge", 1, 1, 1, "plate", { guid = FOE, target = true })
local oe = LiveText("edge")
ok(oe and oe.fs.point and oe.fs.point[2] == pfCombatTextContainer and oe.fs.point[4] >= 10,
  "text of a plate at the screen edge stays on screen (x " .. tostring(oe and oe.fs.point and oe.fs.point[4]) .. ")")
plate.GetCenter, plate.GetEffectiveScale = nil, nil
CT:Clear()

-- ---------------------------------------------------------------- teammates' damage on nameplates
local MATE = "0x00000000000000F1"
local mate = Mock.Enemy(MATE, "Buddy", "PALADIN", 5, 5, { faction = "Horde" })
Mock.units.party1 = mate
Mock.party = 1
Fire("PARTY_MEMBERS_CHANGED")
ok(CT.EV.team[MATE] and CT.EV.team[MATE].class == "PALADIN", "party member in the teammates list")
Fire("AUTO_ATTACK_OTHER", MATE, FOE, 420, 0, 1, 1, 0, 0, 0)
local om = LiveText("420")
ok(om and om.team and om.plate == plate and om.px == B.db.sct.team.x, "teammate's swing on the enemy's plate, beside yours")
Fire("SPELL_DAMAGE_EVENT_OTHER", FOE, MATE, 20925, 600, "0,0,0", 2, 1, "0,0,0,0")
ok(LiveText("600") and LiveText("600").crit, "teammate's spell crit")
Fire("SPELL_DAMAGE_EVENT_OTHER", FOE, MATE, 172, 77, "0,0,0", 0, 5, "0,0,0,3")
ok(not LiveText("77"), "their damage over time stays hidden by default")
Fire("SPELL_MISS_OTHER", MATE, FOE, 133, 3)
ok(not LiveText("Dodge"), "their misses stay hidden by default")
Fire("AUTO_ATTACK_OTHER", MATE, FOE2, 777, 0, 1, 1, 0, 0, 0)
ok(not LiveText("777"), "teammate's hit on an enemy without a plate: nothing on screen")
local OUTSIDER = "0x00000000000000F2"
Mock.Enemy(OUTSIDER, "Outsider", "MAGE", 6, 6, { faction = "Horde" })
Fire("AUTO_ATTACK_OTHER", OUTSIDER, FOE, 313, 0, 1, 1, 0, 0, 0)
ok(not LiveText("313"), "strangers' hits are not shown")
B.db.sct.team.names = "outsider, someone"
CT.EV:Roster()
Fire("AUTO_ATTACK_OTHER", OUTSIDER, FOE, 314, 0, 1, 1, 0, 0, 0)
ok(LiveText("314"), "a named player's hits are shown")
B.db.sct.team.on = false
Fire("AUTO_ATTACK_OTHER", MATE, FOE, 999, 0, 1, 1, 0, 0, 0)
ok(not LiveText("999"), "teammates switch off")
B.db.sct.team.on, B.db.sct.team.names = true, ""
CT:Clear()

