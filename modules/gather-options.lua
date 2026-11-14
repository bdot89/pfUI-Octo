pfUI:RegisterModule("gather-options", "vanilla", function ()
  -- pfUI Octo :: the Gathering page (9 Nov 2026, modules/gather.lua), a tab
  -- under Quality of Life: the switch, a live line, the box's look, and
  -- Off / Show / Priority for every herb and ore node.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local GF = pfUI.gather
  if not W or not O or not O.AddPage or not GF then return end
  local function G() return C.gather end
  local function Chk(p, label, desc, key, after) return O.PfChk(p, label, desc, G, key, after) end
  local function Sld(p, label, desc, min, max, step, key, fmt, after) return O.PfSld(p, label, desc, min, max, step, G, key, after, fmt) end
  local function Redraw() if GF.frame or GF.preview then GF.Draw() end end

  local function Nodes(p, prof)
    for i = 1, table.getn(GF.NODES) do
      local n = GF.NODES[i]
      if n[2] == prof then
        local name = n[1]
        W.Dropdown(p, name, "Needs " .. n[3] .. " skill. Off: never shown. Priority: listed first and pings when it comes into sight.",
          GF.STATES, function() return GF.State(name) end, function(v) GF.SetState(name, v) end)
      end
    end
  end

  local function Build(p)
    GF.LoadDB()
    W.Heading(p, "Gathering", { on = O.KeySwitch(G, "enable", "Shows the nearest herbs and ore around you, on or off."),
      about = "Lists the herb and ore nodes near you with how far away they are and an arrow pointing at them, "
        .. "so you don't have to keep watching the minimap on a route. It only sees what the game has loaded around you "
        .. "(about the range you can see the node in the world). Priority nodes go to the top and can ping when they appear. "
        .. "Needs the ClassicAPI DLL (Install pfUI Octo DLLs.bat)." })

    W.Live(p, function()
      if not GF.Available() then
        return "|cffff5555Needs ClassicAPI:|r its object finder was not found. Close the game, run |cffffd100Install pfUI Octo DLLs.bat|r, start again."
      end
      if G().enable ~= "1" then return "|cffff5555Off|r" end
      local n = table.getn(GF.found or {})
      local line = "|cff55ff55On|r   in sight: " .. n
      if n > 0 then line = line .. "   nearest: " .. GF.found[1].name .. " " .. math.floor(GF.found[1].dist + .5) .. " yd" end
      if not GF.Facing() then line = line .. "   |cffffcc00(no facing from the client: no arrows)|r" end
      if type(GF.dbLoaded) == "number" then
        line = line .. "   node list: pfQuest's (" .. table.getn(GF.NODES) .. " kinds)"
      else
        line = line .. "   node list: the short built-in one |cffffcc00(pfQuest's database did not load)|r"
      end
      return line
    end)

    W.Card(p, "What to look for", { icon = "Interface\\Icons\\INV_Misc_Flower_02", tip = "Which kinds of node the box looks for." })
    Chk(p, "Herbs", nil, "herbs")
    Chk(p, "Ore and stone", nil, "ore")
    Chk(p, "Fishing pools", "Schools and wreckage you can fish from.", "fish")
    Chk(p, "Treasure chests", "Every chest in the quest database.", "chests")
    Chk(p, "Only what I can gather", "Hides nodes your Herbalism, Mining or Fishing skill is too low for, and a whole profession you don't have.", "skill")
    W.Edit(p, "Extra object IDs", "More objects to look for by their game object ID, for example a custom node or a chest: "
      .. "12345=Name, 67890 (the name is optional).", function() return G().extra end, function(v) G().extra = v end, 260)

    W.Card(p, "Priority", { icon = "Interface\\Icons\\INV_Misc_Herb_BlackLotus", tip = "Nodes set to Priority on the lists below." })
    Chk(p, "Tell me when one appears", "When a priority node comes into sight the box flashes.", "alert")
    Chk(p, "With a sound", nil, "sound")
    Chk(p, "With a chat line", nil, "chat")

    W.Card(p, "The box", { icon = "Interface\\Icons\\INV_Misc_Spyglass_02", tip = "Move it with Move Frames." })
    Sld(p, "Rows", "How many nodes it lists at most.", 1, 5, 1, "rows", nil, Redraw)
    Sld(p, "Width", nil, 140, 320, 10, "width", O.Px, Redraw)
    Sld(p, "Looks per second", "How often it checks. 2 is plenty; more costs a little more.", 1, 5, 1, "rate")
    Chk(p, "Hide when nothing is near", "Off: it says \"No nodes in sight\".", "hideempty", Redraw)
    W.Buttons(p, {
      { "Show a sample", function() GF.Preview(not GF.preview) end, 130, "Fill the box with three made-up nodes to place and size it. Click again to stop." },
      { "Check the client", function() GF.Probe() end, 130, "Prints what the game answers for the nodes near you (for bug reports)." },
    })

    -- (14 Nov 2026: nodes remembered, for zones the quest database has no spawns for)
    W.Card(p, "Remembered on the map", { icon = "Interface\\Icons\\INV_Misc_Map_01", tip = "Every node you come near is remembered - for all "
      .. "your characters - and shown on the world map, so zones the quest database knows nothing about (Moonwhisper Coast...) "
      .. "fill in as you play. Works with the box above switched off too. Needs ClassicAPI." })
    Chk(p, "Remember the nodes I pass", "Herbs, veins and pools the finder sees are kept with their place.", "record")
    Chk(p, "Show them on the world map", "A small flower, pick or fish where each one was seen; hover for its name.", "mappins",
      function() GF.pinsDirty = true end)
    Sld(p, "Pin size", nil, 6, 24, 1, "pinsize", O.Px, function() GF.pinsDirty = true end)
    W.Live(p, function()
      local nodes, zones = GF.Count()
      local key = GF.ZoneKey()
      local z = key and pfUI_cache.gathernodes and pfUI_cache.gathernodes[key]
      local here = ""
      if z then
        here = "   This zone: " .. table.getn(z.nodes) .. (z.fit and "" or "  |cffffcc00(walk about 40 yards each way so the map can place them)|r")
      end
      return "Remembered: |cffffffff" .. nodes .. "|r nodes in |cffffffff" .. zones .. "|r zones." .. here
    end)
    W.Buttons(p, {
      { "Forget this zone's", function() GF.Forget() end, 150, "Drops the nodes remembered in the zone you are in.", role = "off" },
      { "Forget all", function()
        if GF.sureAt and GetTime() < GF.sureAt then GF.sureAt = nil GF.Forget(true)
        else GF.sureAt = GetTime() + 3 DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r gathering: click Forget all again within 3 s.") end
      end, 110, "Click twice: every remembered node, in every zone.", role = "off" },
    })

    W.Card(p, "Herbs", { icon = "Interface\\Icons\\INV_Misc_Flower_02", tip = "Off, Show or Priority for each herb." })
    Nodes(p, "Herbalism")
    W.Card(p, "Ore and stone", { icon = "Interface\\Icons\\Trade_Mining", tip = "Off, Show or Priority for each vein and deposit." })
    Nodes(p, "Mining")
    W.Card(p, "Fishing pools", { icon = "Interface\\Icons\\Trade_Fishing", tip = "Off, Show or Priority for each kind of pool." })
    Nodes(p, "Fishing")
    W.Note(p, "Commands: /gather (this page), /gather on, /gather off, /gather probe")
  end

  O:AddPage("Gathering", "gather", "Gathering", Build)
end)
