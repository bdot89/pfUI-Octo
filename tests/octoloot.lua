-- pfUI Octo: OctoLoot (modules/octoloot.lua + octoloot-data.lua, tools\Make-OctoLootData.ps1), run by tests\run.lua.
local ok = octo_ok
local OL = pfUI.octoloot
ok(OL and OL.Load and OL.Unload and OL.Toggle, "OctoLoot loaded (pfUI.octoloot)")
if not OL then return end

-- the data is one text until the window wants it
ok(type(pfUI.octolootData) == "string" and string.len(pfUI.octolootData) > 100000, "the data ships as one text")
ok(not string.find(pfUI.octolootData, "|", 1, true), "no | in the data (chat links are built, not stored)")
ok(OL.db == nil, "no tables at login: nothing read until the window opens")

local db = OL.Load()
ok(db and table.getn(db.list) >= 50, "instances read (" .. (db and table.getn(db.list) or 0) .. ")")
local mc = db and db.by.MoltenCore
ok(mc and mc.kind == "r" and mc.players == 40 and mc.short == "MC", "Molten Core: a 40-player raid, MC")
local rag
for _, b in ipairs(mc and mc.bosses or {}) do if b.name == "Ragnaros" then rag = b end end
ok(rag and rag.id == 11502 and rag.num == "12)", "Ragnaros: npc 11502, number 12 on the map")
local groups = rag and OL.Loot(rag) or {}
local loose, rolled, eye = 0, 0, nil
for _, g in ipairs(groups) do
  if g.chance then rolled = rolled + 1 else loose = loose + 1 end
  for _, e in ipairs(g.items) do if e.id == 17204 then eye = e end end
end
ok(rolled >= 3 and groups[1] and groups[1].chance == nil, "Ragnaros: loose drops first, then the groups the server rolls")
ok(eye and eye.pct > 0 and eye.pct < 10, "the Eye of Sulfuras is a rare loose drop")
local it = OL.Item(17204)
ok(it and it.q == 5 and it.name == "Eye of Sulfuras" and it.icon == "INV_Misc_Gem_Pearl_05", "items: quality, name and icon")
local perd = OL.Item(18816)
ok(perd and perd.q == 4 and perd.cl == 2 and OL.TypeText(perd) == "Dagger", "Perdition's Blade: an epic dagger")
ok(OL.Link(perd) == "|cffa335ee|Hitem:18816:0:0:0|h[Perdition's Blade]|h|r" or string.find(OL.Link(perd), "|Hitem:18816:0:0:0|h", 1, true),
  "chat link built for an item")

-- never greys or whites unless the quest needs them
local grey = 0
for id in pairs(db.raw) do
  local x = OL.Item(id)
  if x and x.q < 2 then
    local quest = false
    for _, s in ipairs(OL.Sources()[id] or {}) do if s.pct < 0 then quest = true end end
    if not quest then grey = grey + 1 end
  end
end
ok(grey == 0, "no grey / white items outside quest drops (" .. grey .. ")")

-- search: an item finds its boss, a boss its instance
local res = OL.Search("perdition")
local found
for _, r in ipairs(res) do if r.kind == "item" and r.item.id == 18816 and r.src.boss == rag then found = true end end
ok(found, "searching an item names the boss that drops it")
local res2 = OL.Search("onyxia")
local inst
for _, r in ipairs(res2) do if r.kind == "inst" then inst = r.inst end end
ok(inst and inst.key == "OnyxiasLair", "searching finds instances")

-- every instance has its own art, every boss with loot parses
local noart, bad = {}, 0
for _, x in ipairs(db.list) do
  if not OL.ART[x.key] and x.kind ~= "w" then table.insert(noart, x.key) end
  for _, b in ipairs(x.bosses) do
    for _, g in ipairs(OL.Loot(b)) do
      for _, e in ipairs(g.items) do if not db.raw[e.id] then bad = bad + 1 end end
    end
  end
end
ok(table.getn(noart) == 0, "every dungeon and raid has a loading screen banner (" .. table.concat(noart, ", ") .. ")")
ok(bad == 0, "every dropped item has its line (" .. bad .. " missing)")

-- the window: builds, opens on Molten Core, every view paints, closing lets go of the tables
local okShow, err = pcall(function() OL.Show() end)
ok(okShow and OL.frame and OL.frame:IsShown(), "the window opens: " .. tostring(err))
if okShow then
  OL.Select(db.by.MoltenCore)
  ok(OL.inst == db.by.MoltenCore and OL.frame.banner.name:GetText() == "Molten Core", "the banner shows the picked instance")
  OL.boss = rag
  local okP, errP = pcall(OL.PaintMain)
  ok(okP and table.getn(OL.entries) > 10, "Ragnaros's loot paints: " .. tostring(errP))
  -- (26 Nov 2026, user: "when it says one of these 12 they are out of line") headings run across, items two a line
  local L = OL.Lines({ { item = 1 }, { head = "A" }, { item = 2 }, { item = 3 }, { item = 4 }, { head = "B" }, { item = 5 } })
  ok(table.getn(L) == 6 and L[1][1].item == 1 and L[1][2] == nil and L[2].head and L[3][1].item == 2 and L[3][2].item == 3
    and L[4][1].item == 4 and L[4][2] == nil and L[5].head and L[6][1].item == 5,
    "a heading always starts a new line, so a group's items never run on from the line before")
  local mixed = false
  for _, line in ipairs(OL.lines or {}) do if line.head and (line[1] or line[2]) then mixed = true end end
  ok(OL.lines and table.getn(OL.lines) > 5 and not mixed, "Ragnaros's table: heading lines hold no items")
  OL.boss = nil
  okP, errP = pcall(OL.PaintMain)
  ok(okP and table.getn(OL.entries) > 100, "Everything here lists the whole raid: " .. tostring(errP))
  okP, errP = pcall(OL.RunSearch, "sulfuras")
  ok(okP and OL.results and table.getn(OL.results) > 0, "the search paints its results: " .. tostring(errP))
  okP, errP = pcall(function() OL.kind = "w" OL.PaintList() OL.kind = "d" OL.PaintList() end)
  ok(okP, "the world and dungeon lists paint: " .. tostring(errP))
  OL.frame:Hide()
  ok(OL.unloadAt ~= nil, "closing starts the minute before the tables go")
  OL.Unload()
  ok(OL.db == nil and OL.sources == nil, "Unload lets go of every table")
  OL.inst, OL.boss, OL.results = nil, nil, nil
end
ok(getglobal("BINDING_NAME_PFOCTOLOOT") ~= nil, "key binding name for OctoLoot")

-- (26 Nov 2026, Lo5t1ncyb3r: "just need the world markers") pins from the M lines alone, without reading everything
OL.marks = nil
local marks = OL.Marks()
ok(table.getn(marks) >= 50 and OL.db == nil, "world map markers read from their own lines (" .. table.getn(marks) .. "), no tables")
local mcm, kinds, badkey = nil, {}, 0
local keys = {}
for k in string.gfind(pfUI.octolootData, "I%^(%w+)%^") do keys[k] = true end
for _, m in ipairs(marks) do
  kinds[m.kind] = true
  if not keys[m.key] then badkey = badkey + 1 end
  if m.key == "MoltenCore" and m.zone == "Searing Gorge" then mcm = m end
end
ok(mcm and mcm.kind == "r" and mcm.x > .3 and mcm.x < .4 and mcm.y > .8, "Molten Core's entrance in Searing Gorge")
ok(kinds.d and kinds.r and kinds.w and badkey == 0, "dungeons, raids and world bosses, every marker an instance OctoLoot has")
local meta = OL.Meta("OnyxiasLair")
ok(meta and meta.name == "Onyxia's Lair" and meta.players == 40 and OL.Meta("BlackfathomDeeps").name == "Blackfathom Deeps",
  "a pin's tooltip reads only its instance's line (first line too)")
local okPin, errPin = pcall(OL.PaintPins)
ok(okPin, "pins paint (or stay hidden) without the map open: " .. tostring(errPin))
