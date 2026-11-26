pfUI:RegisterModule("octoloot-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the OctoLoot page (26 Nov 2026), opened from the big "OctoLoot" entry at the top of the sidebar and the
  -- window's Options button. Its own module, so the switch stays here while OctoLoot is off.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local function OL() return pfUI.octoloot end
  C.octoloot = C.octoloot or {}

  O.SUBTITLE = O.SUBTITLE or {}
  O.SUBTITLE["OctoLoot"] = "Every boss on OctoWoW and what it drops, from the server's own database."

  local function Count()
    local ol = OL()
    if not ol or type(pfUI.octolootData) ~= "string" then return 0, 0, 0 end
    local i, b, n = 0, 0, 0
    for k in string.gfind(pfUI.octolootData, "\n(%u)%^") do
      if k == "I" then i = i + 1 elseif k == "B" then b = b + 1 elseif k == "N" then n = n + 1 end
    end
    return i, b, n
  end

  local function Build(p)
    W.Heading(p, "OctoLoot", { on = O.ModuleSwitch("octoloot", "OctoLoot"),
      about = "Every dungeon, raid and world boss with what it drops on this server: the drop chances and the groups the "
        .. "server rolls once a kill come from the OctoWoW database (octowow.st/db), so they include OctoWoW's own bosses "
        .. "and items. Only green and better, and quest drops - never greys.\n\nIt costs nothing in fights: the data is "
        .. "one text that is read into tables only while the window is open, and let go a minute after you close it. No "
        .. "events, nothing running while it is shut.\n\nMaps: when Atlas-CFM's folder is in your AddOns (it can stay "
        .. "switched off) its map pictures show on the Map and Entrance buttons." })

    W.Live(p, function()
      local ol = OL()
      if not ol then
        if C.disabled and C.disabled.octoloot == "1" then return "|cffff5555Switched off.|r Turn it on above, then reload." end
        return "|cffff5555Not running.|r A reload starts it."
      end
      local i, b, n = Count()
      local loaded = ol.db and "|cff55ff55open now|r" or "|cff9a9ca3asleep (no tables in memory)|r"
      local maps = ol.HasMaps() and "|cff55ff55maps from Atlas-CFM|r" or "|cff9a9ca3no maps (Atlas-CFM's folder is not there)|r"
      return string.format("|cffffffff%d|r instances, |cffffffff%d|r bosses, |cffffffff%d|r items  -  %s  -  %s", i, b, n, loaded, maps)
    end)

    W.Tiles(p, {
      { "Open OctoLoot", "Every instance and its loot", "Interface\\Icons\\INV_Box_02", function() if OL() then OL().Show() end end, "open" },
      { "Where I am", "The instance you stand in", "Interface\\Icons\\INV_Misc_Map_01", function()
        local ol = OL()
        if not ol then return end
        local inst = ol.Here()
        if inst then ol.Select(inst) else ol.Show() end
      end, "open" },
      { "Molten Core", "The first raid", "Interface\\Icons\\Spell_Fire_LavaSpawn", function()
        local ol = OL()
        if not ol then return end
        local db = ol.Load()
        if db and db.by.MoltenCore then ol.Select(db.by.MoltenCore) end
      end, "open" },
    })

    W.Card(p, "The window", { icon = "Interface\\Icons\\INV_Misc_Spyglass_02" })
    W.Check(p, "Open on the instance I am in", "Inside a dungeon or raid the window opens on it; elsewhere on the last one you looked at.",
      function() return C.octoloot.openhere ~= "0" end,
      function(v) C.octoloot.openhere = v and "1" or "0" end)
    W.Check(p, "Let go of the data when closed", "A minute after the window closes its tables are dropped, so it holds no memory. "
      .. "Off keeps them for a faster open.",
      function() return C.octoloot.unload ~= "0" end,
      function(v) C.octoloot.unload = v and "1" or "0" end)
    W.Check(p, "Dungeon quests note when I go in", "Walking into a dungeon or raid with quests still to do for it: one chat line with "
      .. "how many are in your log and how many to do (/ol quests opens the guide).",
      function() return C.octoloot.questhint ~= "0" end,
      function(v) C.octoloot.questhint = v and "1" or "0" end)
    W.Check(p, "Minimap button", "The gold chest on the minimap's edge: click opens OctoLoot, right-click this page, drag it round.",
      function() return C.octoloot.minimap ~= "0" end,
      function(v)
        C.octoloot.minimap = v and "1" or "0"
        local ol = OL()
        if ol and ol.ShowMinimap then ol.ShowMinimap() end
      end)
    W.Check(p, "Markers on the world map", "Every dungeon and raid entrance and world boss gets a pin on its zone's map: "
      .. "green doorway = dungeon, orange skull = raid, purple horned skull = world boss. Hover for what it is, click to "
      .. "open it here.",
      function() return C.octoloot.mapmarks ~= "0" end,
      function(v)
        C.octoloot.mapmarks = v and "1" or "0"
        local ol = OL()
        if ol and ol.PaintPins then ol.PaintPins() end
      end)
    W.Slider(p, "Window size", "The whole OctoLoot window's scale.", .6, 1.4, .05,
      function() return tonumber(C.octoloot.scale) or 1 end,
      function(v)
        C.octoloot.scale = v
        local ol = OL()
        if ol and ol.frame then ol.frame:SetScale(v) end
      end, function(v) return math.floor(v * 100 + .5) .. "%" end)
    if W.KeyBind then W.KeyBind(p, "Key to open it", "Opens and closes the OctoLoot window.", "PFOCTOLOOT") end
    W.Note(p, "Also: |cffffffff/octoloot|r or |cffffffff/ol|r (and |cffffffff/atlas|r while no Atlas add-on is on). "
      .. "Put a name after it to search: |cffffffff/ol perdition|r.", 0, true)

    W.Card(p, "Item tooltips", { icon = "Interface\\Icons\\INV_Misc_Note_01",
      tip = "Lines OctoLoot adds to every item tooltip in the game - bags, bank, chat links, the auction house. Worked out once per item, no tables kept." })
    W.Check(p, "OctoLoot lines in item tooltips", "The set it is in, what it swaps for, the faction / PvP / event / crafting page it is on, "
      .. "the recipe that makes it and what it is used to make. Where it drops comes from pfUI's own tooltip lines "
      .. "(pfQuest's database); turn those off (QoL > Tooltips) and OctoLoot shows the server's drop chances instead.",
      function() return C.octoloot.tip ~= "0" end,
      function(v) C.octoloot.tip = v and "1" or "0" end)
    W.Check(p, "What it is used to make", "\"Used in Blacksmithing 8, Engineering 4\" on reagents.",
      function() return C.octoloot.tipreagent ~= "0" end,
      function(v) C.octoloot.tipreagent = v and "1" or "0" end)
    W.Check(p, "Only my professions", "\"Used in\" names only the professions this character has.",
      function() return C.octoloot.tipmine == "1" end,
      function(v) C.octoloot.tipmine = v and "1" or "0" end)
    W.Slider(p, "Pages and drops shown", "How many faction / PvP / event pages (and drops, when shown) a tooltip lists.", 1, 10, 1,
      function() return tonumber(C.octoloot.tiprows) or 4 end,
      function(v) C.octoloot.tiprows = v if pfUI.octoloot then pfUI.octoloot.tipCache = nil end end)

    W.Card(p, "Using it", { icon = "Interface\\Icons\\INV_Misc_Book_09" })
    W.Note(p, "Nine sections: Dungeons, Raids, World, Events, Collections, Factions, PvP, Crafting and your Wishlist.\n"
      .. "Pick a group on the left, then a boss or page. The percentage is the chance a kill drops that item; \"One of these\" "
      .. "groups are rolled once a kill.\nClick an item for everything about it: what it swaps for, its set, every boss, "
      .. "vendor or page it comes from, the recipe that makes it and what it is used to make - every line opens what it names.\n"
      .. "Shift-click links it, Ctrl-click tries it on, Alt-click puts it on your wishlist, right-click searches for it.\n"
      .. "Right-click a group (or press Pin) to keep it on one of the six QuickLook buttons under the list.", 0, true)
  end

  O:AddPage("OctoLoot", "octoloot", "OctoLoot", Build)
end)
