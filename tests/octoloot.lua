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

-- a boss never drops greys or whites unless the quest needs them (the other sections' pages list reagents and quest items)
local grey = 0
for _, x in ipairs(db.list) do
  if x.kind == "d" or x.kind == "r" or x.kind == "w" then
    for _, b in ipairs(x.bosses) do
      for _, g in ipairs(OL.Loot(b)) do
        for _, e in ipairs(g.items) do
          local itm = e.id and OL.Item(e.id)
          if itm and itm.q < 2 and not (e.pct and e.pct < 0) then grey = grey + 1 end
        end
      end
    end
  end
end
ok(grey == 0, "no grey / white boss drops outside quest drops (" .. grey .. ")")

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
  if not OL.ART[x.key] and (x.kind == "d" or x.kind == "r") then table.insert(noart, x.key) end
  for _, b in ipairs(x.bosses) do
    for _, g in ipairs(OL.Loot(b)) do
      for _, e in ipairs(g.items) do if e.id and not OL.ItemIndex()[e.id] then bad = bad + 1 end end
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

-- (26 Nov 2026, user: "PvP sets, collections, pvp rewards, crafting ... EVERYTHING") the other sections
OL.Unload()
local pdb = OL.Load()
ok(pdb and not pdb.pagesRead and type(pfUI.octolootPages) == "string", "the sections' pages are not read until one is wanted")
pdb = OL.LoadPages()
local kinds2 = {}
for _, x in ipairs(pdb.list) do kinds2[x.kind] = (kinds2[x.kind] or 0) + 1 end
ok((kinds2.e or 0) >= 10 and (kinds2.c or 0) >= 10 and (kinds2.f or 0) >= 20 and (kinds2.p or 0) >= 5 and (kinds2.x or 0) >= 10,
  "events, collections, factions, PvP and crafting groups (" .. (kinds2.e or 0) .. "/" .. (kinds2.c or 0) .. "/" .. (kinds2.f or 0)
  .. "/" .. (kinds2.p or 0) .. "/" .. (kinds2.x or 0) .. ")")
local ad = pdb.by["f-ArgentDawn"]
local revered
for _, b in ipairs(ad and ad.bosses or {}) do if b.name == "Revered" then revered = b end end
ok(ad and revered and table.getn(OL.Loot(revered)[1].items) > 0, "Argent Dawn: a page per standing (Revered has items)")
local bs = pdb.by["x-AtlasCFMLoot_SmithingMenu"]
local recipe
for _, b in ipairs(bs and bs.bosses or {}) do
  for _, g in ipairs(OL.Loot(b)) do for _, e in ipairs(g.items) do if e.spell and not recipe then recipe = OL.Recipe(e.spell) end end end
end
ok(bs and recipe and table.getn(recipe.reagents) > 0 and recipe.skill == 164, "Blacksmithing: recipes with their reagents")
local cord = OL.SetOf(16925)
ok(cord and string.find(cord.name, "Transcendence", 1, true) and table.getn(cord.pieces) >= 8, "a set piece knows its set (Belt of Transcendence)")
local to = OL.Swaps(16812)
ok(table.getn(to) >= 1, "a swap list: Gloves of Prophecy swap for another item")
local ents = OL.ItemEntries(OL.Item(16925))
local hasSet, hasWhere = false, false
for _, e in ipairs(ents) do
  if e.head and string.find(e.head, "Set:", 1, true) then hasSet = true end
  if e.head == "Where it comes from" then hasWhere = true end
end
ok(hasSet and hasWhere, "an item's own page: its set and where it comes from")
local used = OL.UsedIn(12359)
ok(table.getn(used) > 5, "Thorium Bar is used to make many recipes (" .. table.getn(used) .. ")")
-- wishlist and QuickLook (per character)
pfUI_config.octoloot.wish, pfUI_config.octoloot.quick = nil, nil
OL.ToggleWish(17204)
ok(OL.Wished(17204) and table.getn(OL.WishList()) == 1, "Alt-click puts an item on the wishlist")
local wp = OL.WishPage()
ok(wp and wp.bosses[1] and string.find(wp.bosses[1].lootText, "17204", 1, true), "the wishlist page lists it")
OL.ToggleWish(17204)
ok(not OL.Wished(17204), "and takes it off again")
OL.Pin(pdb.by.MoltenCore)
local q1 = OL.QuickEntry(1)
ok(q1 and q1.key == "MoltenCore" and q1.title == "Molten Core", "QuickLook pins an instance")
OL.Unpin(1)
ok(OL.QuickEntry(1) == nil, "and frees the slot")
local okw, errw = pcall(function()
  OL.Show()
  OL.PickKind("f")
  OL.PickKind("x")
  OL.ShowItem(OL.Item(16925))
  OL.Back()
  OL.PickKind("wish")
  OL.PickKind("c")
  OL.frame:Hide()
end)
ok(okw, "every section, an item's page and Back paint: " .. tostring(errw))
OL.Unload()

-- (26 Nov 2026, user with Naowh's Dungeon Journal) dungeon quests: which ones from the data, the rest from pfQuest's database
do
  local Qm = OL.quests
  ok(Qm and Qm.For and Qm.PageEntries and Qm.Waypoint, "the quests part loaded (pfUI.octoloot.quests)")
  local qdb = OL.Load()
  local brd = qdb.by.BlackrockDepths
  local keepDB, keepHist = rawget(_G, "pfDB"), rawget(_G, "pfQuest_history")
  -- a small pfQuest database: a three-step chain, a giver with a place
  rawset(_G, "pfDB", {
    quests = { data = { [3801] = { lvl = 50, min = 45, start = { U = { 8888 } }, ["end"] = { U = { 8888 } } },
      [3802] = { lvl = 52, min = 48, pre = { 3801 }, start = { U = { 8888 } }, ["end"] = { O = { 164689 } }, obj = { I = { 10999 } } } },
      loc = { [3801] = { T = "Dark Iron Legacy", O = "Talk to Franclorn." }, [3802] = { T = "Dark Iron Legacy", O = "Slay Fineous Darkvire.$BReturn." } } },
    units = { data = { [8888] = { coords = { { 34.5, 85.2, 25 } } } }, loc = { [8888] = "Franclorn Forgewright" } },
    objects = { data = {}, loc = { [164689] = "Shrine of Thaurissan" } },
    items = { data = {}, loc = { [10999] = "Ironfel" } },
    zones = { loc = { [25] = "Blackrock Mountain" } },
  })
  rawset(_G, "pfQuest_history", {})
  local list = brd and Qm.For(brd) or {}
  local withRewards = 0
  for _, q in ipairs(list) do if table.getn(q.rewards) > 0 then withRewards = withRewards + 1 end end
  ok(table.getn(list) >= 10 and withRewards >= 5, "Blackrock Depths: its quests for your side (" .. Qm.Side() .. "), with rewards ("
    .. table.getn(list) .. " / " .. withRewards .. ")")
  ok(Qm.State(3802) == "locked", "a quest whose first step is not done says what it needs")
  pfQuest_history[3801] = { 1, 50 }
  local st = Qm.State(3802)
  ok(st == "ready" or st == "low", "with the first step done it can be taken (" .. tostring(st) .. ")")
  local chain = Qm.Chain(3802)
  ok(chain[1] == 3801 and chain[2] == 3802, "the chain: first step first")
  local who = Qm.Who(3802, "start")
  ok(who and who.name == "Franclorn Forgewright" and Qm.WhereText(who) == "Blackrock Mountain  34, 85", "the giver and where he stands")
  local pe = Qm.PageEntries(3802, brd)
  local gotChain, gotGiver, gotText = false, false, false
  for _, e in ipairs(pe) do
    if e.head and string.find(e.head, "The chain", 1, true) then gotChain = true end
    if e.title and string.find(e.title, "Given by Franclorn", 1, true) and e.go then gotGiver = true end
    if e.text and string.find(e.text, "Slay Fineous", 1, true) then gotText = true end
  end
  ok(gotChain and gotGiver and gotText, "a quest's guide: objective, giver with a waypoint, the chain")
  local le = Qm.ListEntries(brd)
  ok(table.getn(le) > 2 and le[1].head, "the quests view lists them under headings")
  local okq, errq = pcall(function()
    OL.Show()
    OL.Select(brd)
    OL.view = "quests"
    OL.PaintMain()
    OL.ShowQuest(3802)
    OL.Back()
    OL.frame:Hide()
  end)
  ok(okq, "the quests view and a guide paint: " .. tostring(errq))
  rawset(_G, "pfDB", keepDB)
  rawset(_G, "pfQuest_history", keepHist)
  OL.view = "loot"
  OL.Unload()
end

-- tooltips anywhere: the texts are searched, no tables made
OL.tipCache = nil
local tf = OL.TipFacts(16925)
ok(OL.db == nil and tf.set and string.find(tf.set.name, "Transcendence", 1, true), "a tooltip names the set without loading the tables")
local tb = OL.TipFacts(12359)
local usedBS = tb.used[164] or 0
ok(usedBS > 0, "a reagent's tooltip: used in Blacksmithing (" .. usedBS .. ")")
local tr = OL.TipFacts(17204)
ok(table.getn(tr.drops) > 0 and tr.drops[1].group == "Molten Core", "the drop lines know the boss's instance (" .. tostring(tr.drops[1] and tr.drops[1].group) .. ")")
ok(OL.TipFacts(16925) == tf, "asked again: the kept answer")

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

-- (27 Nov 2026, Lobo: "there isnt a trash drop section for Dragonmaw Retreat ... Dragonmaw Bulwark or the pieces")
do
  local tdb = OL.Load()
  local dr = tdb and tdb.by and tdb.by["DragonmawRetreat"]
  local trash
  for _, b in ipairs(dr and dr.bosses or {}) do if b.name == "Trash mobs" then trash = b end end
  local has = {}
  for _, g in ipairs(trash and OL.Loot(trash) or {}) do for _, e in ipairs(g.items) do has[e.id] = e.pct end end
  ok(trash and has[58102] and has[58111] == 1.35 and has[58115], "Dragonmaw Retreat has its trash mobs: the Bulwark and the Dragonmaw pieces")
end
