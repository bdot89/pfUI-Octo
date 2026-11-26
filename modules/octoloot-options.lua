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

    W.Card(p, "Using it", { icon = "Interface\\Icons\\INV_Misc_Book_09" })
    W.Note(p, "Pick an instance on the left, then a boss - or Everything here for all its drops at once.\n"
      .. "The percentage is the chance a kill drops that item. \"One of these\" groups are rolled once a kill: one item of "
      .. "the group drops.\nShift-click an item to link it, Ctrl-click to try it on, right-click to see every boss that "
      .. "drops it.\nThe search finds items, bosses and instances as you type.", 0, true)
  end

  O:AddPage("OctoLoot", "octoloot", "OctoLoot", Build)
end)
