pfUI:RegisterModule("range-options", "vanilla", function ()
  -- pfUI Octo :: the Target range page (6 Nov 2026, modules/range.lua), under Unit Frames. Right-click
  -- the range box in Move Frames opens it. Every part of the display is its own switch, so it can be the
  -- whole box or just the number, put anywhere; text font, size, outline and colours are choices here.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local RG = pfUI.range
  if not W or not O or not O.AddPage or not RG then return end
  local function G() return C.range end
  local function Lay() RG.Layout() end
  local function Chk(p, label, desc, key) return O.PfChk(p, label, desc, G, key, Lay) end
  local function Sld(p, label, desc, min, max, step, key, fmt) return O.PfSld(p, label, desc, min, max, step, G, key, Lay, fmt) end
  local function Yd(v) return v .. " yd" end
  local function Color(p, label, desc, key)
    return W.Color(p, label, desc, function()
      local r, g, b, a = GetStringColor(G()[key] or "1,1,1,1")
      return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
    end, function(r, g, b, a)
      G()[key] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
    end)
  end
  local function Fonts()
    local list = { { key = "", label = "pfUI's font" } }
    local dd = pfUI.gui and pfUI.gui.dropdowns and pfUI.gui.dropdowns.fonts
    if type(dd) == "function" then dd = dd() end
    for _, e in ipairs(dd or {}) do
      local _, _, k, l = string.find(e, "^(.-):(.*)$")
      if k then table.insert(list, { key = k, label = l, font = k }) end
    end
    return list
  end
  -- looks in one click
  local PRESETS = {
    { "Full box", { box = "1", trend = "1", unit = "1" } },
    { "Number and bar", { box = "0", trend = "1", unit = "1" } },
    { "Number only", { box = "0", trend = "0", unit = "0" } },
  }
  local function Preset(set)
    for k, v in pairs(set) do G()[k] = v end
    Lay()
    if O.RefreshPage then O:Refresh() end
  end

  local function Build(p)
    W.Heading(p, "Target range", { on = O.KeySwitch(G, "enable", "Range to your target on or off.", function() RG.Layout() end),
      about = "The distance to your target in yards and a bar that shows whether "
        .. "you are closing in or backing off. Choose what shows: the whole box, or only the number, which you can put "
        .. "anywhere with Move Frames (right-click it there to come back here). Exact with ClassicAPI, SuperWoW or UnitXP SP3; "
        .. "without them a band (under 10, 10 - 28, over 28)." })

    W.Card(p, "Try it", { icon = "Interface\\Icons\\Ability_Hunter_SniperShot", tip = "Without a target: a made-up one moving in and out." })
    W.Buttons(p, {
      { "Show a sample", function() RG.Test(10) end, 140, "Ten seconds of a pretend target, so you can see the colours and the bar." },
      { "Dock under the target frame", function() RG.ResetPlace() end, 210, "Puts it back under the target frame after you moved it." },
    })
    local row = {}
    for _, pr in ipairs(PRESETS) do
      local set = pr[2]
      table.insert(row, { pr[1], function() Preset(set) end, 160, "Sets the parts below in one click." })
    end
    W.Buttons(p, row)

    W.Card(p, "What shows", { icon = "Interface\\Icons\\INV_Misc_Spyglass_02", tip = "Each part is its own switch." })
    W.Dropdown(p, "On", "Which targets get the range.", { { key = "all", label = "Every target" }, { key = "enemy", label = "Enemies" },
      { key = "friend", label = "Friends" } }, function() return G().showfor end, function(v) G().showfor = v end)
    Chk(p, "On yourself too", "Targeting yourself shows nothing otherwise.", "self")
    Chk(p, "Box", "The dark box behind it. Off: only what you switch on below, nothing behind it.", "box")
    Chk(p, "Closing / backing off bar", "Green to the right = you are closing in, red to the left = it is moving away.", "trend")
    Chk(p, "\"yd\" after the number", nil, "unit")

    W.Card(p, "Text", { icon = "Interface\\Icons\\INV_Misc_Note_01", tip = "The number's font, size, outline and colour." })
    W.Dropdown(p, "Font", nil, Fonts(), function() return G().font end, function(v) G().font = v Lay() end)
    Sld(p, "Text size", nil, 8, 48, 1, "fontsize", function(v) return v .. " px" end)
    W.Dropdown(p, "Outline", nil, { { key = "none", label = "None" }, { key = "OUTLINE", label = "Thin" }, { key = "THICKOUTLINE", label = "Thick" } },
      function() return G().outline end, function(v) G().outline = v Lay() end)
    Chk(p, "Shadow", nil, "shadow")
    W.Dropdown(p, "Colour", "By distance: the four colours below. One colour: the one you pick.",
      { { key = "range", label = "By distance" }, { key = "fixed", label = "One colour" } },
      function() return G().colormode end, function(v) G().colormode = v end)
    Color(p, "Text colour", "Used when the colour is \"One colour\".", "textcolor")
    W.Dropdown(p, "Decimals", "Yards as 12, 12.3 or 12.34.", { { key = "0", label = "None" }, { key = "1", label = "One" }, { key = "2", label = "Two" } },
      function() return G().decimals end, function(v) G().decimals = v Lay() end)
    Sld(p, "Size", "The whole display, text and all.", 50, 250, 5, "scale", function(v) return v .. "%" end)
    Sld(p, "Bar full at", "How fast you must close in for the bar to fill: yards a second.", 5, 40, 1, "maxvel", function(v) return v .. " yd/s" end)

    W.Card(p, "Distance", { icon = "Interface\\Icons\\Spell_Nature_Lightning", tip = "How it is measured, and the ranges the colours change at." })
    W.Dropdown(p, "Distance measured", "Edge to edge: the bodies' size is taken off, as the game's own range checks do (UnitXP SP3, "
      .. "the default). Melee reach: how far to your melee swing. Centre to centre: the plain distance between the two (ClassicAPI / SuperWoW).",
      { { key = "edge", label = "Edge to edge (spell range)" }, { key = "melee", label = "Melee reach" }, { key = "centre", label = "Centre to centre" } },
      function() return G().source end, function(v) G().source = v end)
    Sld(p, "Close (melee)", nil, 3, 10, 1, "melee", Yd)
    Color(p, "Close", nil, "c_near")
    Sld(p, "Spell range", "Most spells reach 30 yards.", 10, 40, 1, "spell", Yd)
    Color(p, "In spell range", nil, "c_mid")
    Sld(p, "Far", "Longest reach you care about (bows, 40 yard spells).", 20, 60, 1, "far", Yd)
    Color(p, "Far", nil, "c_far")
    Color(p, "Out of range", nil, "c_out")
  end

  O:AddPage("Unit Frames", "ufrange", "Target range", Build)
end)
