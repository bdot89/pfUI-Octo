pfUI:RegisterModule("perf-options", "vanilla", function ()
  -- pfUI Octo :: Settings > Performance (16 Nov 2026, modules\perf.lua): smooth fights, raid graphics, measuring.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local PF = pfUI.perf
  if not W or not O or not O.AddPage or not PF or not PF.Hold then return end
  local function G() return C.perf end
  local function Chk(p, label, desc, key, after) return O.PfChk(p, label, desc, G, key, after) end
  local function FX() if PF.ApplyFX then PF.ApplyFX() end end

  local function Build(p)
    W.Heading(p, "Performance", { about = "Smoother fights and more frames: the game's memory clean-up kept out of fights, "
      .. "costly screen effects lowered in raids, and a way to measure what takes the time." })
    p.items = p.items or {}
    W.Live(p, function()
      local fps = GetFramerate and math.floor(GetFramerate() + .5) or 0
      local mb = PF.kb and string.format("%.1f", PF.kb / 1024) or "?"
      local rate = PF.rate and string.format("%.0f", PF.rate) or "?"
      local s = "FPS |cffffffff" .. fps .. "|r    Lua memory |cffffffff" .. mb .. " MB|r    growing |cffffffff" .. rate .. " KB/s|r"
      if PF.held then s = s .. "    |cff55ff55clean-up held for the fight|r" end
      if PF.last then s = s .. "\nLast clean-up " .. PF.last.why .. ": " .. string.format("%.1f", PF.last.freed / 1024) .. " MB freed in " .. PF.last.ms .. " ms" end
      return s
    end, 2)
    PF.Watch(true, O.frame)
    W.Buttons(p, { { "Open the live window", function() if PF.win then PF.win.Toggle(true) end end, 170,
      "A window of its own (/pfperf): FPS, memory, every script's time and memory like pfDebug, and each add-on's CPU and memory - safe to scan." } })
    Chk(p, "Performance HUD", "A small click-through text in a corner: FPS, latency, memory and the 5 busiest scripts right now, "
      .. "updated once a second. Move it in layout mode. Also /pfperf hud.", "hud", function() if PF.win then PF.win.SetHUD(G().hud == "1") end end)

    W.Card(p, "Smooth fights", { icon = "Interface\\Icons\\Spell_Nature_TimeStop",
      tip = "The game cleans its Lua memory all at once and the picture stops while it does: kept out of fights here." })
    Chk(p, "No memory clean-up during fights", "The clean-up waits until the fight is over instead of hitching in the middle of a pull.", "gc")
    O.PfSld(p, "Room for it", "How much more memory a fight may use before the clean-up runs anyway.", 50, 400, 10, G, "gcextra", nil, function(v) return v .. " MB" end)
    -- (18 Nov 2026: out-of-memory crashes, #132 in d3d9.dll) the ceiling
    Chk(p, "Memory ceiling (stops out-of-memory crashes)", "Lua lets its garbage pile up until memory doubles before "
      .. "cleaning. With pfQuest's database that can run the game out of memory (crash #132 in d3d9.dll). On: garbage may "
      .. "only grow by the room below, and never past the ceiling - in a fight too.", "gccap", function() PF.Steer() end)
    O.PfSld(p, "Room outside fights", "How much garbage may pile up before a clean-up when you are not fighting. Smaller = less "
      .. "memory, a short hitch a little more often.", 32, 256, 8, G, "gcroom", function() PF.Steer() end, function(v) return v .. " MB" end)
    O.PfSld(p, "Ceiling", "Lua memory never goes past this: at it, a clean-up runs at once, even in a fight.", 400, 1200, 50, G,
      "gcmax", function() PF.Steer() end, function(v) return v .. " MB" end)
    Chk(p, "Clean up two seconds after a fight", nil, "gcafter")
    Chk(p, "Clean up after a loading screen", nil, "gcload")
    W.Buttons(p, { { "Clean up now", function() PF.Clean("by hand") end, 130, "Runs the clean-up at once (a short hitch)." } })
    Chk(p, "Game's own UI ticker 30 times a second", "The game runs its fades, flashes, chat-frame mouse check, button pulses and "
      .. "battleground map dots every frame - the costliest script in /pfperf. This runs them 30 times a second at their real speed. "
      .. "Off = every frame, as the game does.", "uitick")
    if not PF.CanGC() then W.Note(p, "|cffffcc00This client does not let add-ons steer the clean-up.|r") end

    W.Card(p, "Raid graphics", { icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02",
      tip = "Forty players casting at once: these effects cost the most frames. Your own settings come back when you leave." })
    Chk(p, "Lower effects in raids", "Only while you are inside; leaving puts your own settings back.", "raidfx", FX)
    W.Dropdown(p, "Where", "Nowhere: never lowered, your own settings everywhere.", { { key = "off", label = "Nowhere (off)" }, { key = "raid", label = "Raids" }, { key = "group", label = "Raids and dungeons" },
      { key = "all", label = "Every instance (battlegrounds too)" } }, function() return G().raidfxwhere end, function(v) G().raidfxwhere = v FX() end)
    for _, fx in ipairs(PF.FX) do Chk(p, fx.label, fx.tip, fx.key, FX) end
    O.PfSld(p, "View distance in raids", "With \"Shorter view distance\".", 177, 777, 10, G, "farclip", FX, function(v) return v .. " yd" end)
    W.Live(p, function()
      local on = PF.fxOn or {}
      if table.getn(on) == 0 then return PF.WantFX() and "Nothing lowered." or "Not lowered here (only in the places picked above)." end
      return "|cff55ff55Lowered now:|r " .. table.concat(on, ", ")
    end)

    W.Card(p, "Measure", { icon = "Interface\\Icons\\INV_Misc_PocketWatch_02",
      tip = "ClassicAPI's profiler: CPU time of each add-on and of the busiest frames. Measuring itself costs a little, so switch it off after." })
    if not PF.CanMeasure() then
      W.Note(p, "|cffffcc00Measuring needs ClassicAPI|r (\"Install pfUI Octo DLLs.bat\").")
    else
      W.Live(p, function()
        if not PF.profiling then return "Measuring is |cffffcc00off|r. Switch it on (the game reloads), play - a raid boss is best - then come back here." end
        local r = PF.report
        if not r or (PF.reportAt or 0) < GetTime() - 3 then r = PF.Measure() PF.reportAt = GetTime() end
        if not r then return "No numbers yet." end
        return table.concat(PF.Lines(r, 8), "\n")
      end, 30)
      W.Buttons(p, {
        { PF.profiling and "Stop measuring (reload)" or "Start measuring (reload)", function() PF.SetProfiling(not PF.profiling) end, 190,
          "Switches the game's profiler (scriptProfile) and reloads." },
        { "Reset numbers", function() PF.Reset() end, 130, "Counts from now on: reset before the pull." },
      })
      W.Note(p, "Or in chat: /pfperf on, /pfperf (the live window), /pfperf chat (the top lines in chat), /pfperf reset, /pfperf off. A screenshot of these lines after a raid boss shows what to make faster next.")
    end

    W.Card(p, "More frames outside the add-on", { folded = true, icon = "Interface\\Icons\\INV_Gizmo_02",
      tip = "Most raid frames go on drawing forty players, not on add-ons." })
    W.Note(p, "The biggest gain in raids is drawing fewer far-away players: the PerfBoost DLL (gitea.com/avitasia/perf_boost) "
      .. "sets player and pet render distances, in and out of combat. Add it with your DLL installer if you want it. "
      .. "In the game's own video options: lower Spell Detail and Terrain Distance, and turn off Full Screen Glow there too.")
  end

  O:AddPage("Settings", "stperf", "Performance", Build)
end)
