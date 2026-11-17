-- pfUI Octo: cooldown bars (modules/cdm.lua, cdm-options.lua), run by tests\run.lua.
-- The spell book read, filling bars by cooldown length, a newly learnt spell finding its
-- place, states (ready / cooldown / active with stacks), hiding, moving, removing.
local ok = octo_ok
local CDM = pfUI.cdm
ok(CDM and CDM.ScanBook and CDM.Fill and CDM.State and CDM.Layout, "cooldown bars loaded (pfUI.cdm)")
if not CDM then return end
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.cdmbars, "options page Cooldowns > Bars registered")
local S = pfUI_config.cdm
ok(S and S.timers == "1" and S.glowcolor == "1,.82,.2,1" and type(S.bars) == "table", "defaults (C.cdm)")
ok(getglobal("pfCDM1") and getglobal("pfCDM6") and rawget(_G, "SLASH_PFCDM1") == "/cdm", "six bar frames and /cdm")

ok(CDM.ParseCD("5 min cooldown") == 300 and CDM.ParseCD("30 sec cooldown") == 30 and CDM.ParseCD("1.5 min cooldown") == 90
  and CDM.ParseCD("1 hour cooldown") == 3600 and CDM.ParseCD("Instant") == nil, "cooldown lengths read from tooltip text")

local keep = {}
for _, k in ipairs({ "GetSpellName", "GetSpellTexture", "IsSpellPassive", "GetSpellCooldown", "C_UnitAuras", "GetPlayerBuff",
                     "GetPlayerBuffTexture", "GetPlayerBuffTimeLeft", "GetPlayerBuffApplications", "GetTime" }) do keep[k] = rawget(_G, k) end
local barsWas, removedWas, knownWas = S.bars, S.removed, S.known
S.bars, S.removed, S.known = {}, {}, {}

local now = 1000
_G.GetTime = function() return now end
-- a priest's book: two ranks of one spell, a passive, one with no cooldown
local BOOK = {
  { "Smite", 0 }, { "Psychic Scream", 30 }, { "Psychic Scream", 30 }, { "Fade", 30 }, { "Power Infusion", 180 },
  { "Shadowfiend", 300 }, { "Spirit Tap", 0, true }, { "Inner Fire", 0 }, { "Desperate Prayer", 600 },
}
local running = {}
_G.GetSpellName = function(i) return BOOK[i] and BOOK[i][1] end
_G.GetSpellTexture = function(i) return "Interface\\Icons\\Spell_" .. i end
_G.IsSpellPassive = function(i) return BOOK[i] and BOOK[i][3] end
_G.GetSpellCooldown = function(i)
  local r = BOOK[i] and running[BOOK[i][1]]
  if r then return r[1], r[2], 1 end
  return 0, 0, 1
end
_G.C_UnitAuras = nil
_G.GetPlayerBuff = function() return -1 end

CDM.ScanBook()
ok(CDM.book["psychic scream"] and CDM.book["psychic scream"].index == 3 and not CDM.book["spirit tap"] and CDM.book["smite"],
  "the spell book: highest rank of each spell, no passives")
-- (no tooltip in the test: lengths come from what the client says while they run)
for _, s in ipairs(BOOK) do if s[2] > 0 then running[s[1]] = { now - 1, s[2] } end end
ok(CDM.LearnCDs() == true and CDM.BaseCD("Power Infusion") == 180 and CDM.BaseCD("Smite") == nil, "a spell seen on cooldown is known to have one")
local added = CDM.Fill()
local bars = CDM.Bars()
local function Names(bar)
  local t = {}
  for _, e in ipairs(bar.spells) do table.insert(t, e.name) end
  return table.concat(t, ",")
end
ok(added == 5 and bars[1].name == "Cooldowns" and bars[2].name == "Utility", "two bars to start with, filled (" .. added .. ")")
ok(Names(bars[1]) == "Fade,Psychic Scream,Power Infusion" and Names(bars[2]) == "Shadowfiend,Desperate Prayer",
  "up to 3 min on Cooldowns, longer on Utility, shortest first (" .. Names(bars[1]) .. " / " .. Names(bars[2]) .. ")")
ok(CDM.Fill() == 0, "filling again adds nothing twice")

-- a new spell with a cooldown finds its place
table.insert(BOOK, { "Silence", 45 })
running["Silence"] = { now - 1, 45 }
CDM.ScanBook()
CDM.LearnCDs()
ok(CDM.Fill() == 1 and Names(bars[1]) == "Fade,Psychic Scream,Silence,Power Infusion", "a newly learnt spell slots in by its length (" .. Names(bars[1]) .. ")")

-- states
running = { ["Fade"] = { now - 10, 30 } }
local st = CDM.State(bars[1].spells[1], now)
ok(st.known and st.state == "cd" and math.abs(st.left - 20) < .01 and st.dur == 30, "on cooldown: 20 s of 30 left")
running = { ["Fade"] = { now - .5, 1.5 } }
ok(CDM.State(bars[1].spells[1], now).state == "ready", "the global cooldown is not a cooldown")
running = {}
ok(CDM.State(bars[1].spells[1], now).state == "ready", "ready")
ok(CDM.State({ name = "Mind Flay" }, now).known == false, "a spell you do not know is not drawn")

-- Inner Fire: no cooldown, added by hand, its buff's time and charges show
ok(CDM.Add(1, "Inner Fire", "spell") and CDM.Add(1, "Inner Fire", "spell") == nil, "a spell is added once")
_G.GetPlayerBuff = function(i) return i == 0 and 0 or -1 end
_G.GetPlayerBuffTexture = function() return "Interface\\Icons\\Spell_Holy_InnerFire" end
_G.GetPlayerBuffTimeLeft = function() return 540 end
_G.GetPlayerBuffApplications = function() return 20 end
CDM.names = { ["0:Interface\\Icons\\Spell_Holy_InnerFire"] = "Inner Fire" }
CDM.ReadBuffs()
local _, _, inner = CDM.Where("Inner Fire")
st = CDM.State(inner, now)
ok(st.state == "active" and st.count == 20 and math.abs(st.aleft - 540) < .01, "active: the buff's time and its 20 charges")
inner.act = "off"
ok(CDM.State(inner, now).state == "ready", "\"show while active\" off: plain")
inner.act = nil
-- ClassicAPI's auras
_G.C_UnitAuras = { UnitAura = function(unit, i)
  if i == 1 then return "Power Infusion", "Interface\\Icons\\Spell_Holy_PowerInfusion", 0, nil, 15, now + 12 end
end }
CDM.ReadBuffs()
local _, _, pi = CDM.Where("Power Infusion")
st = CDM.State(pi, now)
ok(st.state == "active" and math.abs(st.aleft - 12) < .01 and st.count == nil, "ClassicAPI auras: active with 12 s left")
pi.buff = "Something Else"
ok(CDM.State(pi, now).state == "ready", "\"effect to watch\" names another buff")
pi.buff = nil
_G.C_UnitAuras = nil
CDM.buffs = {}

-- hiding: only-on-cooldown icons leave, the rest stay; the frame keeps its room
bars[1].sort = "1"
CDM.Sort(bars[1])
for _, e in ipairs(bars[1].spells) do e.idle = "hide" end
running = { ["Silence"] = { now - 5, 45 } }
local rows, known = CDM.Rows(1, now)
ok(table.getn(rows) == 1 and rows[1].e.name == "Silence" and known == 5, "only-while-on-cooldown: 1 of 5 shown (" .. table.getn(rows) .. " of " .. known .. ")")
local frame = getglobal("pfCDM1")
bars[1].size, bars[1].spacing, bars[1].per, bars[1].center = "30", "2", "12", "1"
local n = CDM.Layout(frame, frame.buttons, bars[1], rows, known, function() return CDM.NewButton(frame) end, now)
local _, _, _, x = frame.buttons[1]:GetPoint(1)
ok(n == 1 and frame:GetWidth() == 5 * 30 + 4 * 2 and math.abs(x - (158 - 30) / 2) < .01, "the bar keeps its width; the one icon sits in the middle (" .. tostring(x) .. ")")
ok(frame.buttons[1].state == "cd" and frame.buttons[1].time:GetText() == "40", "the icon shows 40 s")
for _, e in ipairs(bars[1].spells) do e.idle = nil end

-- coming ready: a glow for a few seconds
CDM.rt = {}
local _, _, sil = CDM.Where("Silence")
sil.flash = "1"
CDM.Rows(1, now)
running = {}
now = now + 41
rows = CDM.Rows(1, now)
local flash
for _, r in ipairs(rows) do if r.e == sil then flash = r.flash end end
ok(flash == true, "off cooldown: it flashes")
now = now + 5
rows = CDM.Rows(1, now)
for _, r in ipairs(rows) do if r.e == sil then flash = r.flash end end
ok(not flash, "and stops after a few seconds")

-- moving and removing
ok(CDM.Shift("Silence", -1) and bars[1].sort == "0", "moved by hand: the bar stops sorting itself")
ok(CDM.MoveTo("Silence", 2) and CDM.Where("Silence") == 2, "moved to another bar")
ok(CDM.Remove("Silence") and not CDM.Where("Silence") and CDM.Fill() == 0, "removed: it does not fill in again")
S.removed = {}
ok(CDM.Fill() == 1, "until asked to fill again")

-- the icon's own options (its right-click menu)
do
  local _, _, fade = CDM.Where("Fade")
  local btn = CDM.NewButton(getglobal("pfCDM1"), true)
  local function Lit() local st = CDM.State(fade, now) CDM.Paint(btn, fade, st, 30, false, now) return btn.lit, st end
  running, CDM.buffs = {}, {}
  ok(CDM.Get(fade, "proc") == "off" and CDM.Get(fade, "thresh") == "3" and CDM.Get(fade, "flash") == "0", "an option not set gives its usual choice")
  -- Proc Glow: only while it can be used
  local usable = true
  local csWas = rawget(_G, "C_Spell")
  _G.C_Spell = { IsSpellUsable = function() return usable end }
  fade.proc = "pulse"
  ok(Lit() == "pulse", "Proc Glow: lit while ready and usable")
  usable = false
  ok(Lit() == "off", "not while it cannot be used")
  running = { ["Fade"] = { now - 1, 30 } }
  usable = true
  ok(Lit() == "off", "nor on cooldown")
  _G.C_Spell = csWas
  -- Cooldown State Effect / Non Active State
  fade.cdfx = "dim"
  Lit()
  ok(btn.icon:GetAlpha() == .4, "Cooldown State Effect: dimmed on cooldown")
  fade.cdfx = "hide"
  ok(CDM.Wanted(fade, CDM.State(fade, now)) == false, "or hidden")
  running, fade.cdfx, fade.proc = {}, nil, nil
  fade.idle = "dim"
  Lit()
  ok(btn.icon:GetAlpha() == .4, "Non Active State: dimmed while ready")
  fade.idle = nil
  -- Active State Glow and Max Charges Glow
  local _, _, inner = CDM.Where("Inner Fire")
  inner.actglow, inner.maxglow = "soft", "border"
  S.maxc = {}
  CDM.buffs = { ["inner fire"] = { name = "Inner Fire", count = 20, ends = now + 500 } }
  local st = CDM.State(inner, now)
  CDM.Paint(btn, inner, st, 30, false, now)
  ok(st.maxed and btn.lit == "border" and btn.rim:IsShown() and not btn.glow:IsShown(), "Max Charges Glow: all 20 charges")
  CDM.buffs["inner fire"].count = 12
  st = CDM.State(inner, now)
  CDM.Paint(btn, inner, st, 30, false, now)
  ok(not st.maxed and btn.lit == "soft" and btn.glow:IsShown() and st.count == 12, "charges used: the Active State Glow instead, 12 shown")
  inner.act = "time"
  CDM.Paint(btn, inner, st, 30, false, now)
  ok(btn.edged == false, "Active State \"time only\": no coloured edge")
  inner.act, inner.actglow, inner.maxglow = nil, nil, nil
  CDM.buffs = {}
  -- Glow Effect Color
  fade.gcolor = "red"
  local gr, gg = CDM.GlowColor(fade)
  ok(gr == 1 and gg == .25, "Glow Effect Color: the icon's own")
  fade.gcolor = nil
  -- Talent Conditions
  local tk = {}
  for _, k in ipairs({ "GetNumTalentTabs", "GetNumTalents", "GetTalentInfo" }) do tk[k] = rawget(_G, k) end
  local rank = 0
  _G.GetNumTalentTabs = function() return 1 end
  _G.GetNumTalents = function() return 2 end
  _G.GetTalentInfo = function(tab, i) if i == 1 then return "Improved Fade", "tex", 1, 1, rank, 2 end return "Silent Resolve", "tex", 1, 2, 5, 5 end
  CDM.talents = nil
  fade.talent = "Improved Fade"
  ok(CDM.TalentOK(fade) == false and CDM.Wanted(fade, CDM.State(fade, now)) == false, "Talent Conditions: hidden without the talent")
  rank = 2
  CDM.talents = nil
  ok(CDM.TalentOK(fade) == true, "shown with it")
  fade.talentnot = "1"
  ok(CDM.TalentOK(fade) == false, "\"lacks\" turns it round")
  fade.talent, fade.talentnot = nil, nil
  -- the menu itself: every line of the model, in its order
  local CPO = pfUI.cdmOptions
  if CPO and CPO.MenuLines then
    local want = { "Remove Spell", "Proc Glow", "Active State", "Active State Glow", "Max Charges Glow", "Non Active State",
      "Cooldown Saturation", "Cooldown State Effect", "Threshold Text", "Cooldown Swipe", "Audio Effect on CD Ready",
      "Glow Effect Color", "Replace with Buff: None", "Talent Conditions: None", "Add Custom Icon" }
    local got = {}
    for _, d in ipairs(CPO.MenuLines("Fade")) do if not d.rule then table.insert(got, d.label) end end
    local same = true
    for i, w in ipairs(want) do if got[i] ~= w then same = false end end
    ok(same, "the right-click menu's lines, in order (" .. table.concat(got, " | ") .. ")")
    local sub
    for _, d in ipairs(CPO.MenuLines("Fade")) do if d.label == "Cooldown State Effect" then sub = d.sub() end end
    ok(sub and table.getn(sub) == 6 and sub[1].on == true and sub[4].head, "a sub-menu lists its choices, the one in use marked")
    if sub then sub[2].fn() end
    ok(fade.cdfx == "dim", "picking one sets it")
    fade.cdfx = nil
    local good, err = pcall(function()
      local m = CPO.OpenMenu(UIParent, "Fade")
      m.rows[3].enter(m.rows[3])
      m:Hide()
    end)
    ok(good, "the menu opens with a sub-menu " .. tostring(err or ""))
  end
  -- the Add card's lists come up shown (they did nothing in game: the menu was made, never shown)
  if CPO and CPO.Pop and CPO.SpellMenu then
    local opts = CPO.SpellMenu()
    local picked
    local m1 = CPO.Pop(UIParent, opts, 260, true, function(key) picked = key end)
    local m2 = CPO.Pop(UIParent, { { key = "a", label = "A" } }, 260, false, function() end)
    ok(table.getn(opts) > 0 and m2 and m2:IsShown() and m1 and not m1:IsShown(), "a spell / item list is shown, and closes the one before (" .. table.getn(opts) .. " spells)")
    m2:Hide()
  end
  -- every glow kind and every animation draws, and the icon comes back to its place
  do
    local host = getglobal("pfCDM1")
    local b2 = CDM.NewButton(host, true)
    b2.host, b2.bx, b2.by, b2.bsize = host, 40, 0, 30
    b2:SetWidth(30) b2:SetHeight(30)
    b2:SetPoint("TOPLEFT", host, "TOPLEFT", 40, 0)
    local good, err, n = true, nil, 0
    for _, gl in ipairs(CDM.GLOWLIST) do
      fade.proc = gl.key
      local okay, e2 = pcall(function()
        local st2 = CDM.State(fade, now)
        st2.usable = true
        CDM.Paint(b2, fade, st2, 30, false, now)
        CDM.Animate(b2, now + .37)
      end)
      if not okay then good, err = false, gl.key .. ": " .. tostring(e2) end
      if b2.lit == gl.key then n = n + 1 end
    end
    ok(good and n == table.getn(CDM.GLOWLIST) and n >= 12, "every glow kind draws (" .. n .. ") " .. tostring(err or ""))
    fade.proc = "ants"
    local st2 = CDM.State(fade, now)
    st2.usable = true
    CDM.Paint(b2, fade, st2, 30, false, now)
    ok(b2.fx and b2.fx.dash[1]:IsShown() and b2.fx.dash[8]:IsShown() and not b2.fx.ring:IsShown(), "marching lines: eight dashes round the edge")
    fade.proc = nil
    local x1, y1 = CDM.Edge(30, 30, 45)
    local x2, y2 = CDM.Edge(30, 30, 100)
    ok(x1 == 30 and y1 == 15 and x2 == 0 and y2 == 20, "a place along the edge, clockwise")
    good, err = true, nil
    for _, a in ipairs(CDM.LOOPS) do
      fade.anim_proc = a.key
      local okay, e2 = pcall(function()
        local st3 = CDM.State(fade, now)
        st3.usable = true
        CDM.Paint(b2, fade, st3, 30, false, now + .21)
      end)
      if not okay then good, err = false, a.key .. ": " .. tostring(e2) end
    end
    ok(good and table.getn(CDM.LOOPS) >= 9, "every running animation draws " .. tostring(err or ""))
    fade.anim_proc = "bounce"
    local st3 = CDM.State(fade, now)
    st3.usable = true
    CDM.Paint(b2, fade, st3, 30, false, now + .2)
    local _, _, _, bx, by = b2:GetPoint(1)
    ok(bx == 40 and by > 0, "bounce lifts the icon (" .. tostring(by) .. ")")
    fade.anim_proc = nil
    CDM.Paint(b2, fade, CDM.State(fade, now), 30, false, now + .2)
    _, _, _, bx, by = b2:GetPoint(1)
    ok(bx == 40 and by == 0 and b2:GetWidth() == 30 and not b2.busy, "animation off: back at its place and size")
    good, err = true, nil
    for _, a in ipairs(CDM.SHOTS) do
      fade.anim_ready = a.key
      local okay, e2 = pcall(function() CDM.Paint(b2, fade, CDM.State(fade, now), 30, false, now + .2, now) end)
      if not okay then good, err = false, a.key .. ": " .. tostring(e2) end
    end
    ok(good and table.getn(CDM.SHOTS) >= 7, "every comes-ready animation draws " .. tostring(err or ""))
    fade.anim_ready = "pop"
    CDM.Paint(b2, fade, CDM.State(fade, now), 30, false, now + .2, now)
    ok(b2:GetWidth() > 30 and b2.busy, "pop: bigger just after it came ready")
    CDM.Paint(b2, fade, CDM.State(fade, now), 30, false, now + 2, now)
    ok(b2:GetWidth() == 30 and not b2.busy, "and its own size again after")
    fade.anim_ready = nil
    b2:Hide()
  end
  -- an item's proc, followed by its name alone
  local proc = CDM.Add(2, "Unstable Power", "aura")
  proc.idle = "hide"
  CDM.buffs = {}
  local ps = CDM.State(proc, now)
  ok(ps.known and ps.state == "ready" and CDM.Wanted(proc, ps) == false, "a proc is on the bar but hidden while it is not up")
  CDM.buffs = { ["unstable power"] = { name = "Unstable Power", count = 8, ends = now + 15, tex = "Interface\\Icons\\Spell_Lightning_LightningBolt01" } }
  ps = CDM.State(proc, now)
  ok(ps.state == "active" and ps.count == 8 and math.abs(ps.aleft - 15) < .01 and CDM.Wanted(proc, ps) and proc.tex == "Interface\\Icons\\Spell_Lightning_LightningBolt01",
    "up: its time, stacks and picture show")
  CDM.buffs = {}
  ok(CDM.State(proc, now).tex == "Interface\\Icons\\Spell_Lightning_LightningBolt01", "its picture is kept for next time")
  CDM.Remove("Unstable Power")
  for k, v in pairs(tk) do _G[k] = v end
  CDM.talents = nil
end

-- (17 Nov 2026, Bread) macros, keybinds, what a click does, the not-usable look - each optional
do
  local mk = {}
  for _, k in ipairs({ "GetMacroInfo", "GetMacroIndexByName", "HasAction", "GetActionText", "GetActionTexture",
                       "IsUsableAction", "GetBonusBarOffset", "C_Spell", "CastSpellByName", "RunMacro" }) do mk[k] = rawget(_G, k) end
  local MACROS = { { "Fear", "Interface\\Icons\\Fear", "/stopcasting\n/cast [mod:shift] Fade; Psychic Scream(Rank 2)" },
                   { "Hi", "Interface\\Icons\\Wave", "/wave" } }
  _G.GetMacroInfo = function(i) local m = MACROS[i] if m then return m[1], m[2], m[3] end end
  _G.GetMacroIndexByName = function(n) for i, m in ipairs(MACROS) do if m[1] == n then return i end end return 0 end
  ok(CDM.MacroTarget(MACROS[1][3]) == "Psychic Scream" and CDM.MacroTarget("/script CastSpellByName(\"Fade\")") == "Fade"
    and CDM.MacroTarget("/wave") == nil, "the spell a macro casts is read from its text")
  local m = CDM.Add(1, "Fear", "macro")
  running["Psychic Scream"] = { now - 5, 30 }
  local st = CDM.State(m, now)
  ok(m and st.known and st.tex == "Interface\\Icons\\Fear" and st.state == "cd" and math.abs(st.left - 25) < .01 and st.target == "Psychic Scream",
    "a macro on a bar: its picture and the cooldown of what it casts")
  ok(CDM.Macros()["hi"] and CDM.Macros()["hi"].index == 2, "the macro list for the menu")
  local ran
  _G.RunMacro = function(i) ran = i end
  CDM.Use(m)
  ok(ran == 1, "using it runs the macro")
  _G.RunMacro = mk.RunMacro

  -- keybinds: the button the spell sits on (main bar first)
  local scream = CDM.book["psychic scream"]
  local slots = { [5] = { tex = scream.tex }, [27] = { tex = scream.tex }, [30] = { text = "Fear", tex = "Interface\\Icons\\Fear" } }
  _G.HasAction = function(s) return slots[s] and 1 or nil end
  _G.GetActionText = function(s) return slots[s] and slots[s].text end
  _G.GetActionTexture = function(s) return slots[s] and slots[s].tex end
  _G.GetBonusBarOffset = function() return 0 end
  local bindWas = Mock.bindings
  Mock.bindings = { ["SHIFT-5"] = "ACTIONBUTTON5", ["F"] = "MULTIACTIONBAR3BUTTON3", ["CTRL-BUTTON4"] = "MULTIACTIONBAR3BUTTON6" }
  CDM.slotsAt = nil
  local _, _, se = CDM.Where("Psychic Scream")
  ok(se and CDM.Key(se) == "S5", "a spell's key: the main bar's button first (" .. tostring(se and CDM.Key(se)) .. ")")
  ok(CDM.Key(m) == "CM4", "a macro's key, shortened (" .. tostring(CDM.Key(m)) .. ")")
  Mock.bindings = {}
  CDM.slotsAt = nil
  ok(CDM.Key(se) == "", "no bound button: no key")
  Mock.bindings = bindWas
  CDM.slotsAt = nil

  -- clicks: left uses, right opens the options, unless changed
  local bar = CDM.Bars()[1]
  ok(CDM.ClickDoes(bar, "LeftButton") == "use" and CDM.ClickDoes(bar, "RightButton") == "options", "clicks as before by default")
  bar.lclick, bar.rclick = "none", "use"
  ok(CDM.ClickDoes(bar, "LeftButton") == "none" and CDM.ClickDoes(bar, "RightButton") == "use", "what a click does is a choice")
  bar.lclick, bar.rclick = nil, nil

  -- not usable (no rage): normal unless picked
  _G.C_Spell = { IsSpellUsable = function() return false end }
  running["Psychic Scream"] = nil
  st = CDM.State(se, now)
  ok(st.state == "ready" and st.usable == nil, "Not Usable State off: nothing asked")
  se.nouse = "grey"
  st = CDM.State(se, now)
  local b = CDM.NewButton(UIParent, true)
  local grey
  b.icon.SetDesaturated = function(_, v) grey = v end
  CDM.Paint(b, se, st, 36, false, now)
  ok(st.usable == false and grey, "Not Usable State grey: greyed while it cannot be used")
  se.nouse = "dim"
  CDM.Paint(b, se, st, 36, false, now)
  ok(b.baseAlpha < 1 and not grey, "dimmed instead")
  se.nouse = nil
  CDM.Remove("Fear")
  for k, v in pairs(mk) do _G[k] = v end
  CDM.slotsAt = nil
end

-- the page builds with a picked icon too
if O and O.Rebuild and pfUI.cdmOptions then
  pfUI.cdmOptions.bar, pfUI.cdmOptions.pick = 1, "Fade"
  local good, err = pcall(function() O:Rebuild("cdmbars") end)
  ok(good, "the page builds with an icon picked " .. tostring(err or ""))
  pfUI.cdmOptions.pick = nil
end

S.bars, S.removed, S.known = barsWas, removedWas, knownWas
CDM.book, CDM.rt, CDM.buffs, CDM.names = {}, {}, {}, {}
for k, v in pairs(keep) do _G[k] = v end
for _, k in ipairs({ "C_UnitAuras", "GetPlayerBuffApplications" }) do if keep[k] == nil then _G[k] = nil end end
