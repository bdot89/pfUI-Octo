pfUI:RegisterModule("questing-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the Questing section (9 Nov 2026; user: "add a tab at the side for
  -- questing and pfquest should be in there with an option to turn it off any other
  -- questing stuff can be put in here also").
  --   pfQuest        on / off (modules\questing.lua), its windows, and every setting
  --                  of pfQuest's own config window (pfQuest_defconfig) in our look
  --   Quest helpers  quest marks on nameplates and in bags, quest item tooltips
  -- pfQuest reads its settings at login (its own window's button is "Save & Close" =
  -- a reload), so a change here offers the reload when the options close.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local Q = pfUI.questing

  local function Reload() if pfUI.gui then pfUI.gui.settingChanged = true end end
  local function Group(a, b) return function() return b and C[a][b] or C[a] end end
  local function Chk(p, label, desc, a, b, key, after)
    if not C[a] or (b and not C[a][b]) then return end
    return O.PfChk(p, label, desc, Group(a, b), key, after or Reload)
  end

  local function State() return Q and Q.State and Q.State() or "none" end
  local STATUS = {
    builtin = "|cff55ff55On|r - the pfQuest built into pfUI.",
    off = "|cffff5555Off|r - switched off here. Map pins, tracker, /db and the quest log extras are gone until you switch it on.",
    standalone = "|cffffcc00The separate pfQuest add-on is on|r - pfUI's copy stands aside. Turn that add-on off at the "
      .. "character screen to use the one built in (the settings below are shared).",
    none = "|cffff5555pfQuest did not load.|r",
  }

  -- pfQuest's number settings are text boxes in its window: sliders here
  local NUMBERS = {
    mindropchance = { 0, 100, 1, function(v) return v .. "%" end },
    trackeralpha = { 0, 1, .05 }, trackerfontsize = { 8, 24, 1 },
    worldmaptransp = { 0, 1, .05 }, minimaptransp = { 0, 1, .05 }, nodefade = { 0, 1, .05 },
  }
  local TRACKING = {
    { key = 1, label = "All quests" }, { key = 2, label = "Tracked quests" },
    { key = 3, label = "Only what I pick" }, { key = 4, label = "Hide" },
  }
  local function PQ() return _G.pfQuest_config or {} end
  local function Pct(v) return math.floor((tonumber(v) or 0) * 100 + .5) .. "%" end

  -- ---------------------------------------------------------------- pfQuest
  local function BuildPfQuest(p)
    W.Heading(p, "pfQuest", { about = "Quest objectives, quest givers and hand-ins on the world map and minimap, the "
      .. "quest tracker, routes and the /db database of every mob, object, item and quest. Built into pfUI; "
      .. "pfQuest and pfQuest-turtle as the OctoWoW launcher installs them, by Shagu, Rivi and contributors (MIT)." })
    W.Card(p, "pfQuest", { icon = "INV_Misc_Book_08" })
    W.Note(p, STATUS[State()] or STATUS.none, 0, true)
    if State() ~= "standalone" then
      W.Check(p, "Use pfQuest", "Off puts it away at login: the game's quest log and quest watch work as without it, "
        .. "and its map pins, tracker, minimap button and /db are gone. (Takes a reload.)",
        function() return C.questing.pfquest ~= "0" end,
        function(v)
          C.questing.pfquest = v and "1" or "0"
          Reload()
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: pfQuest " .. (v and "on" or "off")
            .. " after a reload - close the options to reload.")
        end)
    end
    local live = State() == "builtin" or State() == "standalone"
    if live then
      W.Buttons(p, {
        { "Quest database", function() if _G.pfBrowser then _G.pfBrowser:Show() end end, 130,
          "Search every mob, object, item and quest (/db).", role = "open" },
        { "Quest journal", function() if _G.pfJournal then _G.pfJournal:Show() end end, 120,
          "Your quests and what they need.", role = "open" },
        { "pfQuest's own window", function() if _G.pfQuestConfig then _G.pfQuestConfig:Show() end end, 150,
          "The same settings in pfQuest's own window.", role = "open" },
      })
    end
    local def = _G.pfQuest_defconfig
    if not live or not def then return end

    W.Card(p, "What it shows", { icon = "INV_Misc_Map_01" })
    W.Dropdown(p, "Quests on the map", "Which quests get their objectives drawn.", TRACKING,
      function() return tonumber(PQ().trackingmethod) or 1 end,
      function(v) PQ().trackingmethod = v Reload() end)

    -- the rest straight from pfQuest's own list, its headings as cards
    for _, d in ipairs(def) do
      if d.type == "header" then
        W.Card(p, d.text or "")
      elseif d.type == "checkbox" and d.config then
        local key = d.config
        W.Check(p, d.text or key, "pfQuest: " .. (d.text or key) .. ". (Takes a reload.)",
          function() return PQ()[key] == "1" end,
          function(v) PQ()[key] = v and "1" or "0" Reload() end)
      elseif d.type == "text" and d.config and NUMBERS[d.config] then
        local key, n = d.config, NUMBERS[d.config]
        local fmt = n[4] or (n[2] == 1 and Pct or nil)
        W.Slider(p, d.text or key, "pfQuest: " .. (d.text or key) .. ". (Takes a reload.)", n[1], n[2], n[3],
          function() return tonumber(PQ()[key]) or tonumber(d.default) or n[1] end,
          function(v) PQ()[key] = tostring(v) Reload() end, fmt)
      elseif d.type == "button" and d.func then
        W.Buttons(p, { { d.text or "?", d.func, 170, "pfQuest asks first, then reloads.", role = "danger" } })
      end
    end
  end
  O:AddPage("Questing", "qstpfquest", "pfQuest", BuildPfQuest)

  -- ---------------------------------------------------------------- Quest helpers
  local function BuildHelpers(p)
    W.Heading(p, "Quest helpers", { about = "pfUI's own quest extras. Most are also on their own pages "
      .. "(Nameplates, Bags, Tooltip): these are the same settings." })
    W.Card(p, "Nameplates", { icon = "Ability_Hunter_SniperShot" })
    Chk(p, "Quest marks", "A mark beside the name of quest mobs, quest givers and hand-ins (from pfQuest when it is on).",
      "plates", nil, "questmark", function() if pfUI.plates and pfUI.plates.Refresh then pcall(pfUI.plates.Refresh) end end)
    Chk(p, "Colour quest mobs", "Quest mobs' bars in the objective colour.", "plates", nil, "questbar",
      function() if pfUI.plates and pfUI.plates.Refresh then pcall(pfUI.plates.Refresh) end end)
    W.Buttons(p, { { "All quest mark settings", function() O:Open("npquest") end, 170,
      "Nameplates > Quests, icons and auto: the marks' pictures, colours and size.", role = "open" } })

    W.Card(p, "Bags and tooltips", { icon = "INV_Misc_Bag_08" })
    Chk(p, "Quest marks in bags", "A ? on quest items and a ! on items that start a quest.", "bagsocto", nil, "quest",
      function() if pfUI.bagsOcto and pfUI.bagsOcto.Refresh then pcall(pfUI.bagsOcto.Refresh) end end)
    Chk(p, "Quest of a quest item", "Quest items name their quest in the tooltip.", "tooltip", "questitem", "showquest")
    Chk(p, "Quest item count", "How many a quest wants, in the item's tooltip.", "tooltip", "questitem", "showcount")
  end
  O:AddPage("Questing", "qsthelpers", "Quest helpers", BuildHelpers)
end)
