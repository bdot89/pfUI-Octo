pfUI:RegisterModule("procs-options", "vanilla", function ()
  -- pfUI Octo :: the OctoProcs section (20 Nov 2026, modules/procs.lua). Its own module so the section - and its
  -- on / off switch - stays when OctoProcs is switched off. One page: try it, its look, your class's procs (each
  -- on / off and where it shows) and your own (any buff or reactive spell by name).
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local function P() return pfUI.procs end
  local function G() return C.procs end
  local function Up() if P() then P().Refresh() end end
  local function Again() Up() O:Rebuild("procs") end
  local function Chk(p, label, desc, key) return O.PfChk(p, label, desc, G, key, Up) end
  local function Sld(p, label, desc, min, max, step, key, fmt) return O.PfSld(p, label, desc, min, max, step, G, key, Up, fmt) end
  local function Px(v) return v .. " px" end
  local function Pct(v) return math.floor(v * 100 + .5) .. "%" end

  local KINDS = { { key = "buff", label = "A buff on me" }, { key = "spell", label = "A spell I can use now" },
    { key = "ready", label = "A cooldown ready in a fight" } }
  local function Places()
    local out = {}
    for _, pl in ipairs(P() and P().PLACES or {}) do table.insert(out, { key = pl.key, label = pl.label }) end
    return out
  end
  -- all = the one for every proc ("Auto" first); else a proc's own ("As the rest" first)
  local function Looks(all)
    local out = { all and { key = "auto", label = "Auto (by where it is)" } or { key = "default", label = "As the rest" } }
    if not all then table.insert(out, { key = "auto", label = "Auto (by where it is)" }) end
    for _, l in ipairs(P() and P().LOOKS or {}) do table.insert(out, { key = l.key, label = l.label }) end
    return out
  end
  local new = { name = "", kind = "buff", place = "top" }

  local function Build(p)
    W.Heading(p, "OctoProcs", { on = O.ModuleSwitch("procs", "OctoProcs"), about = "Something big and pulsing round your "
      .. "character the moment a proc is up: Clearcasting, Shadow Trance, Overpower, Riposte, Execute... Its icon, a glow, "
      .. "a countdown and stacks, with a glow at the screen's edge and a sound if you want them. ClassicAPI reads your buffs "
      .. "and Nampower your reactive spells, so nothing has to be on your bars." })
    W.Buttons(p, {
      { "Try it (8 s)", function() if P() then P().Test() end end, 120, "Every proc of yours on screen for 8 seconds.",
        on = function() return P() and P().testing end },
      { "Stop", function() if P() then P().StopTest() end end, 80, "Ends the try." },
    })
    W.Note(p, "Move frames (in the footer) moves them all: drag the OctoProcs box.")

    W.Card(p, "Look", { tip = "How every alert looks. Auto: wings at the sides, a crown above, a ring below." })
    W.Dropdown(p, "Look", "For every proc (each one can have its own below).", Looks(true), function() return G().lookall or "auto" end,
      function(v) G().lookall = v Up() end)
    Sld(p, "Icon size", "Everything is sized from this.", 24, 128, 2, "size", Px)
    Sld(p, "Art size", "The wings, crown, beam or glow against the icon.", .5, 2, .05, "artsize", Pct)
    Sld(p, "Side offset", "How far from the middle the side ones sit.", 40, 400, 5, "spread", Px)
    Sld(p, "Top offset", "Extra height for the ones above.", -100, 300, 5, "height", Px)
    Chk(p, "Spell icon on the art", "Off: only the wings, crown or beam.", "icons")
    Chk(p, "Burst as it starts", "A flash of light the moment a proc comes up.", "burst")
    Chk(p, "Names", "The proc's name under it.", "names")
    Chk(p, "Screen edge glow", "The edges of your screen glow in the colour of the newest proc.", "edge")
    Sld(p, "Edge glow strength", nil, .05, 1, .05, "edgealpha", Pct)
    Sld(p, "Edge glow width", nil, 30, 300, 10, "edgesize", Px)

    W.Card(p, "Pulse", { tip = "Each alert breathes between these: fainter and smaller, then brighter and bigger." })
    Chk(p, "Pulse", "Off: still, at the most opacity and size.", "pulse")
    Sld(p, "Pulse speed", nil, .2, 6, .1, "speed")
    Sld(p, "Least opacity", nil, 0, 1, .05, "alphamin", Pct)
    Sld(p, "Most opacity", nil, 0, 1, .05, "alphamax", Pct)
    Sld(p, "Least size", nil, .5, 2, .05, "sizemin", Pct)
    Sld(p, "Most size", nil, .5, 2, .05, "sizemax", Pct)

    W.Card(p, "Timers and sound", { tip = "What it says and plays." })
    Chk(p, "Countdown", "Seconds left, red under 3.", "timer")
    Chk(p, "One countdown for a pair", "Both sides: the number on one only.", "onetimer")
    Sld(p, "Countdown size", nil, .2, .8, .02, "timersize", Pct)
    Sld(p, "Stacking procs from", "Procs that stack (Hot Streak) show from this many stacks.", 1, 5, 1, "stacksfrom")
    Chk(p, "Only in a fight", "Nothing shows out of combat.", "combatonly")
    local CT = pfUI.sctB and pfUI.sctB.SCT
    local sounds = { { key = "none", label = "No sound (mute)" }, { key = "RaidWarning", label = "Raid warning" } }
    for _, s in ipairs(CT and CT.SOUNDS or {}) do
      if s.key and s.key ~= "none" and s.key ~= "RaidWarning" then table.insert(sounds, { key = s.key, label = s.label }) end
    end
    W.Dropdown(p, "Sound", "When a proc comes up. Picking one plays it.", sounds, function() return G().sound or "none" end,
      function(v)
        G().sound = v
        if v ~= "none" then if CT and CT.PlaySound then CT.PlaySound(v) else PlaySound(v) end end
      end)

    local _, class = UnitClass("player")
    local mine = P() and P().Mine() or {}
    W.Card(p, "Your procs", { tip = "Your class's (" .. (class or "?") .. "): each on or off, where it shows, its look and colour." })
    local any
    for _, e in ipairs(mine) do
      if not e.custom then
        any = true
        local name, entry = e.name, e
        local what = e.kind == "buff" and "buff" or (e.kind == "spell" and "usable" or "cooldown ready")
        W.Check(p, name .. "  |cff888888(" .. what .. ")|r", nil, function() return G().off[name] ~= "1" end,
          function(v) G().off[name] = (not v) and "1" or nil Up() end)
        W.Dropdown(p, "   Where", nil, Places(), function() return entry.place end, function(v) G().place[name] = v Again() end)
        W.Dropdown(p, "   Look", nil, Looks(), function() return G().look[name] or "default" end,
          function(v) G().look[name] = (v ~= "default") and v or nil Up() end)
        W.Color(p, "   Colour", "Its art, edge and glow.", function()
          local r, g, b = P().Col(G().col[name] or entry.col)
          return r, g, b, 1
        end, function(r, g, b) G().col[name] = string.format("%.2f,%.2f,%.2f", r, g, b) Up() end)
      end
    end
    if not any then W.Note(p, "Nothing built in for your class yet: add your own below.") end

    W.Card(p, "Your own", { tip = "Any buff, or any reactive spell, by its exact name." })
    W.Edit(p, "Name", "As the game writes it, like Clearcasting or Riposte.", function() return new.name end,
      function(v) new.name = v or "" end)
    W.Dropdown(p, "It is", nil, KINDS, function() return new.kind end, function(v) new.kind = v end)
    W.Dropdown(p, "Where", nil, Places(), function() return new.place end, function(v) new.place = v end)
    W.Buttons(p, {
      { "Add", function()
        local n = string.gsub(new.name or "", "^%s*(.-)%s*$", "%1")
        if n == "" then return end
        -- its icon from your spell book, when it is a spell of yours
        local icon
        local book = P() and P().book or {}
        if book[n] then icon = GetSpellTexture(book[n], BOOKTYPE_SPELL or "spell") end
        table.insert(G().custom, { name = n, kind = new.kind, place = new.place, icon = icon })
        new.name = ""
        Again()
      end, 80, "Adds it to the list." },
    })
    for i, c in ipairs(G().custom) do
      local idx = i
      W.Buttons(p, {
        { "Remove", function() table.remove(G().custom, idx) Again() end, 80, "Takes " .. (c.name or "?") .. " off the list." },
      })
      W.Note(p, (c.name or "?") .. "  |cff888888" .. (c.kind or "buff") .. ", " .. (c.place or "top") .. "|r", 4, true)
    end
    W.Live(p, function() return "|cffffd100/procs|r this page   |cffffd100/procs test|r try it   (|cffffd100/procdoc|r works too)" end)
  end

  O:AddPage("OctoProcs", "procs", "Procs", Build)
end)
