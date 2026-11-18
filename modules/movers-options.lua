pfUI:RegisterModule("movers-options", "vanilla", function ()
  -- pfUI Octo :: Settings > Move anything (18 Nov 2026, modules\movers.lua): the switch that gives the game's frames
  -- boxes in layout mode, opacity per frame, picked frames, and the game windows moved with Shift + drag.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local MV = pfUI.movers
  if not W or not O or not O.AddPage or not MV then return end
  local ICON = "Interface\\Icons\\"

  local function Again() if O.Rebuild then O:Rebuild("stmovers") end end

  local function Build(p)
    W.Heading(p, "Move anything", { about = "Layout mode moves pfUI's frames. With Move anything the game's own frames - "
      .. "quest tracker, battleground score, raid warnings, error text, zone name, item link tooltip - and any frame of "
      .. "any add-on you pick get boxes too, with the same snapping, sizes and hiding. Game windows move with Shift + drag." })

    W.Card(p, "Layout mode", { icon = ICON .. "INV_Misc_Spyglass_02", tip = "The same switch as in layout mode's top bar." })
    W.Check(p, "Game frames get boxes in layout mode", "Off keeps layout mode tidy. Their places, sizes and opacity stay "
      .. "either way.", function() return MV.Showing() end, function(v) MV.SetShowing(v) end)
    W.Buttons(p, {
      { "Open layout mode", function() if pfUI.unlock then pfUI.unlock:Show() end end, 140, "Move, size and hide frames." },
      { "Pick a frame", function() MV.StartPick() end, 120, "Point at any frame of any add-on and press Enter." },
    })

    -- opacity per frame: the game's frames that exist now, then the picked ones
    W.Card(p, "Opacity", { icon = ICON .. "Spell_Shadow_Charm", tip = "How see-through each frame is. Size and hiding are "
      .. "in layout mode (wheel, size box, Hide in the nudge box)." })
    local names = {}
    for _, b in ipairs(MV.BLIZZ) do if _G[b[1]] then table.insert(names, b[1]) end end
    for name, v in pairs(C.movers.picked or {}) do if v == "1" then table.insert(names, name) end end
    for _, name in ipairs(names) do
      local n = name
      W.Slider(p, MV.Label(n), nil, .1, 1, .05, function() return tonumber((C.movers.alpha or {})[n]) or 1 end,
        function(v) MV.SetAlpha(n, v) end, function(v) return math.floor(v * 100 + .5) .. "%" end)
    end

    W.Card(p, "Picked frames", { icon = ICON .. "INV_Misc_Gear_01", tip = "Frames of other add-ons you made movable." })
    local any
    for name, v in pairs(C.movers.picked or {}) do
      if v == "1" then
        any = true
        local n = name
        W.Buttons(p, { { "Stop moving " .. MV.Label(n), function() MV.Unpick(n) Again() end, 260,
          "Takes its box away and puts it back where its add-on had it.", role = "danger" } })
      end
    end
    if not any then W.Note(p, "None yet. Use Pick a frame, or type a frame's name below.") end
    W.Edit(p, "Frame name", "The exact frame name (case sensitive), then Enter. /moveany <name> does the same.",
      function() return "" end, function(v) if v and v ~= "" and MV.PickName(v, true) then Again() end end, 240)

    W.Card(p, "Game windows", { icon = ICON .. "INV_Misc_Book_09", tip = "Character, spellbook, quest log, talents, trainers, "
      .. "vendors, mail and more." })
    W.Check(p, "Shift + drag moves game windows", "They open where you left them from then on.",
      function() return C.movers.windows == "1" end, function(v) C.movers.windows = v and "1" or "0" end)
    local moved = {}
    for name in pairs(C.movers.win or {}) do table.insert(moved, name) end
    table.sort(moved)
    for _, name in ipairs(moved) do
      local n = name
      W.Buttons(p, { { "Forget " .. MV.Label(n), function() MV.ForgetWindow(n) Again() end, 220,
        "It opens in the game's own place again." } })
    end
    if moved[1] then
      W.Buttons(p, { { "Forget every window", function()
        for _, n in ipairs(moved) do MV.ForgetWindow(n) end
        Again()
      end, 180, "All of them back to the game's places.", role = "danger" } })
    else
      W.Note(p, "No window moved yet: hold Shift and drag one.")
    end
  end

  O:AddPage("Settings", "stmovers", "Move anything", Build)
end)
