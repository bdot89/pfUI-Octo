-- pfUI Octo: OctoTotems (modules/octototems.lua), run by tests\run.lua: the generated totem data, the spell book scan,
-- set throwing (one a press / all with nampower's queue), range from the drop point, the advisor, smart heal ranks,
-- the section's pages and the preview.
local ok = octo_ok
local TT = pfUI.octototems
ok(TT and TT.ThrowSet and TT.Preview and TT.Active, "OctoTotems loaded (pfUI.octototems)")
if not TT then return end
-- (19 Nov 2026) pfUI's own small totem bar (modules\totems.lua) is a different module: never share its names
ok(pfUI.totems ~= TT and _G.pfOctoTotems and _G.pfOctoTotems ~= _G.pfTotems, "pfUI's own totem bar (pfUI.totems, pfTotems) left alone")
ok(pfUI_config.totems and pfUI_config.totems.iconsize and not pfUI_config.totems.sets, "pfUI's C.totems keeps only its own settings")
local D = pfUI.totemData
ok(D and D["Searing Totem"] and D["Searing Totem"].el == 1 and D["Searing Totem"].dur["Rank 6"] == 55, "data: Searing Totem fire, rank 6 = 55 s")
ok(D["Windfury Totem"] and D["Windfury Totem"].dur["Rank 3"] == 90 and D["Tremor Totem"].el == 2 and D["Mana Tide Totem"].el == 3, "data: server's own Windfury 3 (90 s), elements")
local O = pfUI.octoui and pfUI.octoui.Options
local tabs = {}
for _, s in ipairs(O and O.octo or {}) do if s[1] == "OctoTotems" then for i, pg in ipairs(s[2]) do tabs[i] = pg[1] end end end
ok(tabs[1] == "totembars" and tabs[2] == "totemsets" and tabs[5] == "bulwark", "OctoTotems tabs: Bars, Sets, ..., Earthen Bulwark (" .. table.concat(tabs, ", ") .. ")")
local S = pfUI_config.octototems
ok(S.enable == "1" and table.getn(S.sets) == 3 and S.sets[1].name == "Default", "defaults: 3 sets")

local keep = {}
for _, k in ipairs({ "GetSpellName", "GetSpellTexture", "GetSpellCooldown", "CastSpellByName", "QueueSpellByName", "GetTotemInfo",
  "UnitPosition", "UnitDebuff", "UnitExists", "UnitIsDeadOrGhost", "GetNumRaidMembers", "GetTime" }) do keep[k] = rawget(_G, k) end
local book = {
  { "Searing Totem", "Rank 1" }, { "Searing Totem", "Rank 6" }, { "Stoneskin Totem", "Rank 6" }, { "Strength of Earth Totem", "Rank 5" },
  { "Mana Spring Totem", "Rank 4" }, { "Poison Cleansing Totem", "" }, { "Windfury Totem", "Rank 3" }, { "Tremor Totem", "" },
  { "Totemic Recall", "" }, { "Lightning Shield", "Rank 7" }, { "Healing Wave", "Rank 1" }, { "Healing Wave", "Rank 2" },
}
_G.GetSpellName = function(i) local b = book[i] if b then return b[1], b[2] end end
_G.GetSpellTexture = function() return "Interface\\Icons\\X" end
_G.GetSpellCooldown = function() return 0, 0 end
TT.Scan()
ok(TT.book["Searing Totem"] and TT.book["Searing Totem"].rank == "Rank 6" and TT.book["Searing Totem"].lowrank == "Rank 1", "spell book: highest and rank 1")
ok(TT.book["Totemic Recall"] and TT.book["Lightning Shield"] and not TT.book["Grounding Totem"], "spell book: recall, shield; unknown left out")
local fire = TT.ElementTotems(1)
ok(table.getn(fire) == 1 and fire[1] == "Searing Totem", "known fire totems")
TT.SetOrder(2, { "Tremor Totem", "Stoneskin Totem" })
local earth = TT.ElementTotems(2)
ok(earth[1] == "Tremor Totem" and earth[2] == "Stoneskin Totem", "saved order")
S.order = {}

-- active totems from GetTotemInfo, range from where they were dropped
local now = 100
_G.GetTime = function() return now end
local slots = {}
local keepInfo = TT.TotemInfo
TT.TotemInfo = function(i) local s = slots[i] if s then return 1, s[1], s[2], s[3], "x" end end
local px, py = 0, 0
_G.UnitPosition = function() return px, py, 0 end
local casts = {}
_G.CastSpellByName = function(s) table.insert(casts, s) end
_G.QueueSpellByName = nil
S.cur = "1"
S.sets[1] = { name = "Default", t1 = "Searing Totem", t2 = "Strength of Earth Totem", t3 = "Mana Spring Totem", t4 = "Windfury Totem", order = "2,1,3,4" }
TT.ThrowSet()
ok(casts[1] == "Strength of Earth Totem(Rank 5)" and table.getn(casts) == 1, "one press = the first missing totem in order (" .. tostring(casts[1]) .. ")")
slots[2] = { "Strength of Earth Totem", now, 120 }
casts = {}
_G.QueueSpellByName = function(s) table.insert(casts, "Q:" .. s) end
TT.ThrowSet()
ok(table.getn(casts) == 3 and casts[1] == "Q:Searing Totem(Rank 6)" and casts[3] == "Q:Windfury Totem(Rank 3)", "nampower: every missing totem queued on one press (" .. table.concat(casts, ", ") .. ")")
_G.QueueSpellByName = nil
local a = TT.Active(2)
ok(a and a.range == true and a.left == 120, "active: in range at the drop point")
px = 30
a = TT.Active(2)
ok(a and a.range == false, "30 yd away = out of range")
casts = {}
slots[1] = { "Searing Totem", now, 55 } slots[3] = { "Mana Spring Totem", now, 60 } slots[4] = { "Windfury Totem", now, 90 }
TT.drop[1], TT.drop[3], TT.drop[4] = nil, nil, nil
TT.ThrowSet()
ok(casts[1] == "Strength of Earth Totem(Rank 5)", "out of range counts as missing (re-drop)")
px = 0
TT.drop = {}
casts = {}
S.refresh = "0"
local need = TT.Needed((TT.Cur()))
ok(table.getn(need) == 0, "all down and in range: nothing needed (" .. table.concat(need, ", ") .. ")")
ok(table.getn(TT.Needed((TT.Cur()), true)) == 4, "force: the whole set")

-- watch: a slot cleared early = destroyed
TT.state = {}
TT.Watch(now)
slots[1] = nil
local said = {}
local keepSay = TT.Say
TT.Say = function(t) table.insert(said, t) end
TT.Watch(now + 5)
ok(said[1] and string.find(said[1], "destroyed"), "early gone = destroyed (" .. tostring(said[1]) .. ")")
TT.Say = keepSay

-- advisor: poison on party1 lights Poison Cleansing
_G.GetNumRaidMembers = function() return 0 end
_G.UnitExists = function(u) return u == "player" or u == "party1" end
_G.UnitIsDeadOrGhost = function() return nil end
_G.UnitDebuff = function(u, i) if u == "party1" and i == 1 then return "tex", 1, "Poison" end end
local adv = TT.Advice()
ok(adv["Poison Cleansing Totem"] == 1, "advisor: poison -> Poison Cleansing Totem")

-- sets
local n = table.getn(S.sets)
local i = TT.NewSet("Nefarian")
ok(table.getn(S.sets) == n + 1 and TT.SetIndex("Nefarian") == i, "new set")
ok(TT.DeleteSet(i) and table.getn(S.sets) == n, "delete set")
ok(table.concat(TT.SetOrderList({ order = "4,4,1" }), ",") == "4,1,2,3", "throw order fills the missing elements")

-- every page of the section builds
for _, k in ipairs({ "totembars", "totemsets", "totemalerts", "totemheal", "bulwark" }) do
  local good, e = pcall(function() O.pages[k] = nil O:Page(k) end)
  ok(good, "page " .. k .. " builds (" .. tostring(e) .. ")")
end

-- preview builds with the made-up state (every totem of the data shown)
local box = CreateFrame("Frame", nil, UIParent)
local okp, err = TT.Preview(box, 105)
ok(okp and box.pbars and box.pbars[1] and box.pbars[1].shown >= 1, "preview built (" .. tostring(err) .. ")")
ok(TT.fake == nil, "preview leaves no fake state behind")

for k, fn in pairs(keep) do _G[k] = fn end
for _, k in ipairs({ "QueueSpellByName", "GetTotemInfo", "UnitPosition", "UnitDebuff" }) do if keep[k] == nil then _G[k] = nil end end
TT.drop, TT.state = {}, {}
TT.TotemInfo = keepInfo
TT.Scan()

-- (19 Nov 2026, user: "text goes behind search bar") the line under the big title stops before Find
do
  local O2 = pfUI.octoui and pfUI.octoui.Options
  local v = O2 and O2.frame and O2.frame.version
  ok(v and O2.subRoom and O2.subRoom > 300 and O2.SetSubtitle, "subtitle has a room left of Find")
  if v and O2.SetSubtitle then
    local long = string.rep("word ", 200)
    local shown = O2.SetSubtitle(v, long, O2.subRoom)
    ok((v:GetStringWidth() or 0) <= O2.subRoom and string.find(shown, "%.%.%.$"), "a too long line is cut with ...")
    local cut = {}
    for name, t in pairs(O2.SUBTITLE or {}) do
      if O2.SetSubtitle(v, t, O2.subRoom) ~= t then table.insert(cut, name) end
    end
    ok(table.getn(cut) == 0, "every section's line fits whole (" .. table.concat(cut, ", ") .. ")")
  end
end

-- (19 Nov 2026, user: "just icons you click and set. reset button") the set editor grid: fixed icons, click = in the set
do
  local TO = pfUI.octototemsOptions
  local O3 = pfUI.octoui.Options
  pcall(function() O3.pages.totembars = nil O3:Page("totembars") end)
  local g = TO and TO.grid
  ok(g and g.rows and g.rows[1] and g.rows[1].icons[1], "set editor grid built")
  if g and g.rows[1].icons[1] then
    TO.edit = 1
    local set = TO.EditSet()
    set.t1 = ""
    local ic = g.rows[1].icons[1]
    local w0 = ic:GetWidth()
    _G.arg1 = "LeftButton"
    _G.this = ic
    ic:GetScript("OnClick")()
    ok(set.t1 == ic.totem, "click puts the totem in the set (" .. tostring(set.t1) .. ")")
    ic:GetScript("OnEnter")()
    ok(ic:GetWidth() == w0, "hovering does not resize it")
    ic:GetScript("OnClick")()
    ok(set.t1 == "", "click again takes it out")
    set.t1 = "Searing Totem"
  end
end
