pfUI:RegisterModule("qol-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the Quality of Life section (8 Nov 2026; user with
  -- EllesmereUI's Quality of Life page: "can we get a QoL section like this
  -- adding all of our QoL into one page simple easy to find and navigate raid
  -- markers auto loot everything in here"). Every small helper that was spread
  -- over Settings, Bags, Loot, Tooltip, the module list and its own pages:
  --   QoL          vendor, loot, map, tooltips, screen glow, errors and the
  --                helpers that had no switch but the module list
  --   Raid Tools   the Raid Tools window (raidtools.lua), WeirdUtils' markers
  --   Screenshots  pfUI's automatic screenshots
  --   Auto Loot    its own page, listed in this section (O.NAV)
  -- The same settings stay where they were too; these are the same keys.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end

  -- pfUI reads most of these at load: a change offers the reload
  local function Reload() if pfUI.gui then pfUI.gui.settingChanged = true end end
  local function Group(a, b) return function() return b and C[a][b] or C[a] end end
  local function Chk(p, label, desc, a, b, key, after)
    -- (a settings group this client's config lacks: no row)
    if not C[a] or (b and not C[a][b]) then return end
    return O.PfChk(p, label, desc, Group(a, b), key, after or Reload)
  end
  local function Mod(p, label, desc, name)
    local sw = O.ModuleSwitch(name, label)
    return W.Check(p, label, desc .. " (Takes a reload.)", sw[1], sw[2])
  end
  local function Drop(p, label, desc, options, a, b, key, after)
    return W.Dropdown(p, label, desc, options, function() return Group(a, b)()[key] end, function(v)
      Group(a, b)()[key] = v
      if after then after(v) else Reload() end
    end)
  end

  -- ---------------------------------------------------------------- QoL
  local function BuildQoL(p)
    W.Heading(p, "Quality of life", { about = "The small helpers in one place: vendor and loot, the map, tooltips, "
      .. "screen glows, error messages, and helpers that are whole modules. The same settings are also on their own pages." })
    W.Card(p, "Vendor and loot")
    Chk(p, "Auto sell grey items", "Grey items are sold when you open a vendor.", "global", nil, "autosell")
    Chk(p, "Auto repair", "Everything is repaired when you open a vendor that repairs.", "global", nil, "autorepair")
    Chk(p, "No loot confirmation (solo)", "Bind-on-pickup loot is taken without asking while you are not in a group.", "loot", nil, "autopickup")
    Chk(p, "Loot window at the mouse", "The loot window opens where your mouse is.", "loot", nil, "mousecursor")
    Chk(p, "Loot window fits its items", "The loot window grows and shrinks with what is in it.", "loot", nil, "autoresize")
    Chk(p, "Advanced master loot menu", "A bigger master loot menu.", "loot", nil, "advancedloot")
    Chk(p, "Announce roll results", "Who won and with what, in chat.", "loot", nil, "rollannounce")
    Chk(p, "Roll timer in the item's colour", "The loot roll timer bar in the item's rarity colour.", "loot", nil, "raritytimer")

    W.Card(p, "Map and tooltips")
    Chk(p, "Reveal the whole map", "Areas you have not been to show on the world map.", "appearance", "worldmap", "mapreveal")
    Chk(p, "Map exploration points", "Marks the spots that count for exploration.", "appearance", "worldmap", "mapexploration")
    Chk(p, "Item IDs in tooltips", "The item's number in its tooltip (and the spell's on auras).", "tooltip", nil, "itemid")
    Chk(p, "How many you have", "Bags, bank and worn counts in item tooltips.", "tooltip", nil, "itemcount")
    Chk(p, "Vendor price always", "The sell price in every item tooltip, not only at a vendor.", "tooltip", "vendor", "showalways")
    Chk(p, "Always compare items", "The item you wear shows next to every item tooltip.", "tooltip", "compare", "showalways")
    Chk(p, "Compare base stats", "The comparison lists the base stats too.", "tooltip", "compare", "basestats")
    Chk(p, "Who cast a buff", "\"Cast by\" on buff and debuff tooltips.", "tooltip", nil, "auracaster")
    Chk(p, "Quest of a quest item", "Quest items name their quest in the tooltip.", "tooltip", "questitem", "showquest")
    Chk(p, "Quest item count", "How many a quest wants, in the item's tooltip.", "tooltip", "questitem", "showcount")

    W.Card(p, "Screen and messages")
    Chk(p, "Glow: in combat", "A soft glow round the screen's edge while you fight.", "appearance", "infight", "screen")
    Chk(p, "Glow: you have aggro", "The edge glows while a mob is on you.", "appearance", "infight", "aggro")
    Chk(p, "Glow: low health", "The edge glows when your health is low.", "appearance", "infight", "health")
    Chk(p, "Energy tick", "A spark on your energy bar for the next tick.", "unitframes", "player", "energy")
    Chk(p, "Mana tick", "A spark on your mana bar for the next tick (5 second rule).", "unitframes", "player", "manatick")
    Chk(p, "Add-on errors in chat", "Lua errors print in chat instead of a pop-up.", "global", nil, "errors")
    Chk(p, "One line of red errors", "\"Not enough mana\" and friends: one line at a time.", "global", nil, "errors_limit")
    Chk(p, "No red error text", "Hides the red error messages in the middle of the screen.", "global", nil, "errors_hide")
    Chk(p, "\"Screen Captured\" message", "The game's message after a screenshot.", "global", nil, "screenshotmsg")

    -- (11 Nov 2026, user / Origummy on Discord) auto attack on the target you pick, once in reach
    if C.autoattack and pfUI.autoattack then
      local AA = pfUI.autoattack
      local function A() return C.autoattack end
      W.Card(p, "Auto attack", { icon = "Ability_MeleeDamage", tip = "Your auto attack starts by itself on the target you "
        .. "pick once it is in melee reach. Stop it yourself and it leaves that target alone until you pick another. "
        .. "/autoattack on | off | why, or a key: Key Bindings > pfUI Octo: auto attack.",
        on = { function() return A().enable == "1" end, function(v) AA.Toggle(v) end, "Auto attack on or off." } })
      O.PfChk(p, "Players too", "Also start on enemy players (PvP).", A, "players", function() end)
      O.PfChk(p, "Neutral mobs too", "Also start on yellow (neutral) mobs you target.", A, "neutral", function() end)
      O.PfChk(p, "Only in combat", "Only once you are in combat - it never starts a fight.", A, "combatonly", function() end)
      O.PfChk(p, "Not on crowd control", "Never on a target that is sheeped, sapped, gouged, blinded, asleep or trapped.",
        A, "skipcc", function() end)
      O.PfSld(p, "Melee reach", "Yards counted as in reach when the game's own check is not there (ClassicAPI has it).",
        3, 10, .5, A, "reach", function() end, function(v) return v .. " yd" end)
    end

    W.Card(p, "Helpers", { tip = "Whole little modules: on or off takes a reload (the Reload button turns gold)." })
    Mod(p, "Cancel form when needed", "A spell that needs you out of a form or off a mount cancels it for you.", "autoshift")
    Mod(p, "Feign death health", "Shows a feigning hunter's real health.", "feigndeath")
    Mod(p, "Click items to auction / trade", "Clicking a bag item puts it in the auction search, the sell slot or trade.", "itemclick")
    Mod(p, "Mouseover casting", "/pfcast and /pfmouse cast on the unit under the mouse without changing target.", "mouseover")
    Mod(p, "Farm map", "/farm: a big see-through map for gathering.", "farmmode")
    Mod(p, "AFK camera", "The camera spins round you with a clock while you are away.", "afkcam")
    Mod(p, "Chat copy button", "A button on the chat to copy its last lines.", "chatcopy")
    Mod(p, "Whisper forwarding", "A chat button that forwards whispers to another character.", "whisperproxy")
    Mod(p, "Friend and guild list extras", "Last seen, class and zone colours, notes on friends.", "socialmod")
    Mod(p, "Clean macro history", "/run, /script and /cast lines stay out of the chat history.", "macrotweak")

    -- (11 Nov 2026) add-ons that do what pfUI Octo already does: listed, and asked about again
    local AC = pfUI.addoncompat
    if AC then
      W.Card(p, "Add-ons pfUI Octo already does", { tip = "At login pfUI asks about each switched-on add-on that does "
        .. "the same as a part of pfUI Octo. \"No\" is remembered; the button below asks again." })
      local found = AC.Doubled()
      if table.getn(found) == 0 then
        W.Note(p, "None switched on: nothing does the same job twice.")
      else
        for _, e in ipairs(found) do W.Note(p, "|cffffd100" .. e[1] .. "|r - " .. e[2]) end
      end
      W.Buttons(p, { { "Ask about them again", function()
        if not AC.Check() then DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI|r: no switched-on add-on does what pfUI Octo already does.") end
      end, 180, "Asks about each switched-on add-on that pfUI Octo already does, even ones you said No to." } })
    end
  end
  O:AddPage("Quality of Life", "qolgeneral", "QoL", BuildQoL)

  -- ---------------------------------------------------------------- Raid Tools
  local SHOW = {
    { key = "lead", label = "When I lead or assist" }, { key = "group", label = "In any group" },
    { key = "raid", label = "In a raid" }, { key = "always", label = "Always" }, { key = "never", label = "Never" },
  }
  local function RT() return pfUI.raidtools end
  local function RTUp() if RT() then RT().Update() end end
  local function BuildRaid(p)
    W.Heading(p, "Raid tools", { about = "A small window with Ready Check, Convert to Raid, Disband, a pull countdown "
      .. "and the eight target markers. Move it in layout mode (Move Frames). 1.12 has no world markers of its own: "
      .. "WeirdUtils' marker bar below adds them when its DLL is installed." })
    W.Card(p, "Window")
    Drop(p, "Show it", "When the Raid Tools window is on screen.", SHOW, "raidtools", nil, "show", RTUp)
    O.PfChk(p, "Start folded", "Only its title bar until you open it.", Group("raidtools"), "collapsed", RTUp)
    O.PfSld(p, "Size", "The window's scale.", .6, 1.6, .05, Group("raidtools"), "scale", RTUp, function(v) return math.floor(v * 100 + .5) .. "%" end)
    W.Buttons(p, {
      { "Show it now", function()
        C.raidtools.show = "always"
        RTUp()
        O:Refresh()
      end, 120, "Shows the window whatever the group (Show it: Always)." },
      { "Move it", function() if pfUI.unlock then pfUI.unlock:Show() end end, 100, "Layout mode: drag its box." },
    })
    if C.weirdutils then
      W.Card(p, "World markers (WeirdUtils)", { tip = "Needs the WeirdUtils DLL. All of its settings: Art & Extras > WeirdUtils." })
      O.PfChk(p, "World marker bar", "A bar of the world markers: left-click on you, right-click then click the ground, Shift-click removes.",
        Group("weirdutils"), "bar", Reload)
      O.PfChk(p, "Lock the marker bar", "It cannot be dragged.", Group("weirdutils"), "lock", Reload)
    end
  end
  O:AddPage("Quality of Life", "qolraid", "Raid Tools", BuildRaid)

  -- ---------------------------------------------------------------- Screenshots
  local BG = { { key = "0", label = "Never" }, { key = "1", label = "When we win" }, { key = "2", label = "When it ends" } }
  local LOOT = { { key = "0", label = "Never" }, { key = "3", label = "Rare or better" }, { key = "4", label = "Epic or better" }, { key = "5", label = "Legendary" } }
  local function BuildShots(p)
    W.Heading(p, "Screenshots", { about = "Screenshots taken for you at moments worth keeping, with a line saying what happened." })
    W.Card(p, "Take one when")
    Chk(p, "You level up", nil, "screenshot", nil, "levelup")
    Chk(p, "Your PvP rank goes up", nil, "screenshot", nil, "pvprank")
    Chk(p, "A reputation level goes up", nil, "screenshot", nil, "faction")
    Chk(p, "You get an honourable kill", nil, "screenshot", nil, "hk")
    Drop(p, "Battlegrounds", "The score at the end of a battleground.", BG, "screenshot", nil, "battleground")
    Drop(p, "Loot", "When you loot an item this good.", LOOT, "screenshot", nil, "loot")
    O.PfSld(p, "Every few minutes", "A screenshot every so many minutes; 0 = off.", 0, 60, 1, Group("screenshot"), "interval", Reload,
      function(v) return (v == 0) and "off" or (v .. " min") end)
    W.Card(p, "The picture")
    Chk(p, "A line saying what happened", nil, "screenshot", nil, "caption")
    Chk(p, "Hide the interface", "Everything but the game world is hidden for the picture.", "screenshot", nil, "hideui")
  end
  O:AddPage("Quality of Life", "qolshots", "Screenshots", BuildShots)
end)
