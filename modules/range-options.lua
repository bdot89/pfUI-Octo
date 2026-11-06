pfUI:RegisterModule("range-options", "vanilla", function ()
  -- pfUI Octo :: the Target range page (6 Nov 2026, modules/range.lua), under Unit Frames.
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

  local function Build(p)
    W.Heading(p, "Target range", { on = O.KeySwitch(G, "enable", "Range to your target on or off.", function() RG.Layout() end),
      about = "A small frame under the target frame with the distance to your target in yards, an arrow showing which way "
        .. "it is, and a bar that shows whether you are closing in or backing off. Exact with ClassicAPI, SuperWoW or "
        .. "UnitXP SP3; without them it shows a band (under 10, 10 - 28, over 28). Move Frames moves it." })

    W.Card(p, "Try it", { icon = "Interface\\Icons\\Ability_Hunter_SniperShot", tip = "Without a target: a made-up one moving in and out." })
    W.Buttons(p, {
      { "Show a sample", function() RG.Test(10) end, 140, "Ten seconds of a pretend target, so you can see the colours, the arrow and the bar." },
      { "Dock under the target frame", function() RG.ResetPlace() end, 210, "Puts it back under the target frame after you moved it." },
    })

    W.Card(p, "Show", { icon = "Interface\\Icons\\INV_Misc_Spyglass_02" })
    W.Dropdown(p, "On", "Which targets get the range.", { { key = "all", label = "Every target" }, { key = "enemy", label = "Enemies" },
      { key = "friend", label = "Friends" } }, function() return G().showfor end, function(v) G().showfor = v end)
    Chk(p, "On yourself too", "Targeting yourself shows nothing otherwise.", "self")
    Chk(p, "Direction arrow", "Points at the target from where you face. Needs positions (ClassicAPI or SuperWoW).", "arrow")
    Chk(p, "Closing / backing off bar", "Green to the right = you are closing in, red to the left = it is moving away.", "trend")

    W.Card(p, "Look", { icon = "Interface\\Icons\\INV_Misc_Note_01" })
    Sld(p, "Size", "The whole frame.", 60, 200, 5, "scale", function(v) return v .. "%" end)
    Sld(p, "Text size", nil, 10, 30, 1, "fontsize", function(v) return v .. " px" end)
    W.Dropdown(p, "Decimals", "Yards as 12, 12.3 or 12.34.", { { key = "0", label = "None" }, { key = "1", label = "One" }, { key = "2", label = "Two" } },
      function() return G().decimals end, function(v) G().decimals = v end)
    Sld(p, "Bar full at", "How fast you must close in for the bar to fill: yards a second.", 5, 40, 1, "maxvel", function(v) return v .. " yd/s" end)

    W.Card(p, "Ranges and colours", { icon = "Interface\\Icons\\Spell_Nature_Lightning", tip = "The number is coloured by how far the target is." })
    Sld(p, "Close (melee)", nil, 3, 10, 1, "melee", Yd)
    Color(p, "Close", nil, "c_near")
    Sld(p, "Spell range", "Most spells reach 30 yards.", 10, 40, 1, "spell", Yd)
    Color(p, "In spell range", nil, "c_mid")
    Sld(p, "Far", "Longest reach you care about (bows, 40 yard spells).", 20, 60, 1, "far", Yd)
    Color(p, "Far", nil, "c_far")
    Color(p, "Out of range", nil, "c_out")

    W.Card(p, "Arrow direction", { icon = "Interface\\Icons\\INV_Misc_Map_01",
      tip = "The clients disagree on which way their position numbers run, so the arrow learns it by watching you run forward." })
    W.Live(p, function()
      local f = RG.Facing()
      local sum = 0
      for k = 1, 8 do sum = sum + (RG.votes[k] or 0) end
      return (f and "Facing: found." or "|cffff5555Facing not found|r (the minimap arrow).") .. "  Learnt from " .. sum .. " steps; reading no. "
        .. tostring(G().axis) .. "."
    end)
    Chk(p, "Flip the arrow", "If it points the wrong way round (left for right), turn this on.", "flip")
    W.Buttons(p, { { "Learn the direction again", function() G().axis = "1" for k = 1, 8 do RG.votes[k] = 0 end end, 200,
      "Run forward for a few seconds afterwards." } })
  end

  O:AddPage("Unit Frames", "ufrange", "Target range", Build)
end)
