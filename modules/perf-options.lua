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
    W.Buttons(p, { { "Raid stress test (60 s)", function() PF.Stress(60) end, 170,
      "A pretend 40-man raid fight for a minute: the Demo's raid (40 players, a boss, casts, heals, damage), 40 mobs "
      .. "on OctoDoTs with 14 debuffs each (800 aura changes a second, adds dying and coming back), a raid's combat log (400 lines a second) to every add-on that listens (needs ClassicAPI; add-ons that save fights record it too), plus 40 characters, 50 adds and AoE on screen (target a mob first to make it the boss). Then says your FPS, worst frames, memory and "
      .. "OctoDoTs' share in chat. Click again to stop. Also /pfstress [seconds] [lite] (lite = no characters on screen)." } })
    W.Buttons(p, { { "Open the live window", function() if PF.win then PF.win.Toggle(true) end end, 170,
      "A window of its own (/pfperf): FPS, memory, every script's time and memory like pfDebug, and each add-on's CPU and memory - safe to scan." } })
    Chk(p, "Performance HUD", "A small click-through text in a corner: FPS, latency, memory and the 5 busiest scripts right now, "
      .. "updated once a second. Move it in layout mode. Also /pfperf hud.", "hud", function() if PF.win then PF.win.SetHUD(G().hud == "1") end end)

    -- (20 Nov 2026) the monitor's refresh rate and what follows from it
    local lc = pfUI.api.libclient
    local function Copy(text, what)
      if lc and lc.Copy and lc.Copy(text, true) then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: copied " .. what .. " - paste it with Ctrl+V.")
      else
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: " .. what .. ": |cffffffff" .. text .. "|r (copying needs ClassicAPI).")
      end
    end
    local pick = {}
    local function Picked() return pick.hz or PF.CurrentHz() or 60 end
    W.Card(p, "Your monitor", { icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
      tip = "Tell the game your screen's refresh rate (Hz). Many games stay at 60 Hz on a faster screen until it is set." })
    W.Live(p, function()
      local hz = PF.CurrentHz()
      local s = "The game draws at |cffffffff" .. (hz and (hz .. " Hz") or "?") .. "|r, vsync |cffffffff" ..
        (PF.CVar("gxVSync") == "1" and "on" or "off") .. "|r, now |cffffffff" .. (GetFramerate and math.floor(GetFramerate() + .5) or 0) .. " FPS|r."
      if PF.Windowed() then s = s .. "\n|cffffcc00Windowed mode: the desktop's own rate is used, the setting below counts in full screen.|r" end
      if not PF.ratesFromGame then s = s .. "\n|cff999999The game did not list your screen's rates: the usual ones are offered.|r" end
      return s
    end, 2)
    local rates = {}
    for _, hz in ipairs(PF.Rates()) do table.insert(rates, { key = tostring(hz), label = hz .. " Hz" }) end
    W.Dropdown(p, "Refresh rate", "Your monitor's Hz. Only the rates the game offers for your screen are listed.", rates,
      function() return tostring(Picked()) end, function(v) pick.hz = tonumber(v) end)
    W.Dropdown(p, "Vsync", "On: no tearing, the game waits for the screen (frames = your Hz). Off: every frame it can make, "
      .. "a little less mouse delay - add the frame cap below so it doesn't run hotter than it needs.",
      { { key = "1", label = "On (no tearing)" }, { key = "0", label = "Off + frame cap" } },
      function() return pick.vsync or PF.CVar("gxVSync") or "0" end, function(v) pick.vsync = v end)
    W.Check(p, "Triple buffering", "With vsync on: smoother when the frame rate dips under your Hz, a frame more delay.",
      function() if pick.triple ~= nil then return pick.triple end return PF.CVar("gxTripleBuffer") == "1" end, function(v) pick.triple = v end)
    Chk(p, "G-Sync / FreeSync screen", "The frame cap goes 3 under your Hz, so it stays inside the screen's own sync.", "vrr")
    if type(_G.SetMaxAnimFramerate) == "function" then
      Chk(p, "Animations at your Hz", "ClassicAPI's animations change 30 times a second unless told otherwise: this makes them "
        .. "follow your screen.", "hzanim", function() PF.ApplyAnim() end)
    end
    W.Buttons(p, {
      { "Apply", function()
        local v = pick.vsync or PF.CVar("gxVSync") or "0"
        local t = pick.triple
        if t == nil then t = PF.CVar("gxTripleBuffer") == "1" end
        if not PF.SetDisplay(Picked(), v == "1", t) then DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: the screen is already set like that.") end
      end, 110, "Sets them and restarts the graphics (a second of black). Not kept within 15 s = put back by itself.", role = "go" },
      { "Copy frame cap (Linux)", function() Copy(PF.CapLines(Picked()).steam, "the Steam / Lutris launch option") end, 170,
        "DXVK_FRAME_RATE=<n> %command% - paste into Steam's Launch Options (Lutris: System options > Environment variables, without %command%)." },
      { "Copy frame cap (dxvk.conf)", function() Copy(PF.CapLines(Picked()).conf, "the dxvk.conf line") end, 180,
        "d3d9.maxFrameRate = <n> - one line in dxvk.conf in the game folder (Windows and Linux; OctoLauncher's DXVK reads it)." },
    })
    W.Note(p, "1.12 has no frame cap of its own: vsync caps at your Hz, or with vsync off DXVK can cap it (the two copy buttons).")

    -- (20 Nov 2026) Linux (Wine / Proton / Lutris)
    W.Card(p, "Playing on Linux", { icon = "Interface\\Icons\\INV_Misc_Gear_01",
      tip = "For the game run through Wine, Proton or Lutris. The game can't tell, so switch it on yourself." })
    Chk(p, "I play on Linux (Wine / Proton)", "Sets the parts ticked below and keeps your own values to put back when switched off.",
      "linux", function() PF.ApplyLinux() end)
    for _, e in ipairs(PF.LINUX) do Chk(p, e.label, e.tip, e.key, function() if G().linux == "1" then PF.ApplyLinux() end end) end
    Chk(p, "Lower effects in dungeons too, memory ceiling on", "Raid graphics (below) also in 5-mans, and the memory ceiling: "
      .. "Wine and DXVK share the 32-bit game's room, so running out comes sooner.", "lxfx", function() if G().linux == "1" then PF.ApplyLinux() end end)
    W.Live(p, function()
      local have, miss = {}, {}
      for _, d in ipairs(PF.DLLs()) do if d[2] then table.insert(have, d[1]) else table.insert(miss, d[1]) end end
      local s = "DLLs loaded: |cff55ff55" .. (table.getn(have) > 0 and table.concat(have, ", ") or "none") .. "|r"
      if table.getn(miss) > 0 then s = s .. "\nNot loaded: |cff999999" .. table.concat(miss, ", ") .. "|r" end
      if table.getn(have) == 0 then s = s .. "\n|cffffcc00None loaded: start the game through VanillaFixes.exe, not WoW.exe.|r" end
      return s
    end, 3)
    W.Buttons(p, { { "Copy launch option", function() Copy("DXVK_FRAME_RATE=" .. PF.CapFor(Picked()) .. " gamemoderun %command%", "the Steam launch option") end, 160,
      "Steam's Launch Options: the frame cap + Feral GameMode (only if you have gamemode installed; else take gamemoderun out)." } })
    W.Note(p, "Get the DLLs with the Octo DLL Installer's install-linux.sh (github.com/bdot89/OctoDLLInstaller). Outside the game: "
      .. "keep DXVK on (not WineD3D), Fsync / Esync on in Lutris, GameMode on. A short stutter the first time you see a new "
      .. "spell or zone is DXVK building its shader cache - it goes away.")

    -- (20 Nov 2026) PerfBoost: far-away players, pets and trash drawn less
    W.Card(p, "Fewer far-away players (PerfBoost)", { icon = "Interface\\Icons\\INV_Gizmo_02",
      tip = "The biggest gain in raids and cities: drawing forty players costs far more than any add-on." })
    if not PF.HasPB() then
      W.Note(p, "|cffffcc00PerfBoost isn't loaded.|r Tick it under Optional extras in the Octo DLL Installer (Linux: install-linux.sh), "
        .. "then start the game through VanillaFixes. In the game's own video options: lower Spell Detail and Terrain Distance.")
    else
      if IsAddOnLoaded and IsAddOnLoaded("PerfBoostSettings") then
        W.Note(p, "|cffffcc00PerfBoostSettings is on:|r it sets these again at login from its own profile. Change them there, or turn it off to set them here.")
      end
      local looks = {}
      for _, k in ipairs({ "all", "balanced", "raid" }) do
        local key = k
        table.insert(looks, { PF.PBLOOKS[key].label, function() PF.SetPBLook(key) end, 150, "Sets the five distances below.", role = "pick",
          on = function() return PF.PBLook() == key end })
      end
      W.Buttons(p, looks)
      for _, e in ipairs(PF.PB) do
        local cv = e.cvar
        W.Slider(p, e.label, e.tip .. " -1 = no limit.", -1, 100, 1, function() return tonumber(PF.CVar(cv)) or -1 end,
          function(v) pcall(SetCVar, cv, tostring(v)) end, function(v) return (tonumber(v) or -1) < 0 and "all" or (v .. " yd") end)
      end
      W.Check(p, "Always draw players flagged for PvP", "Enemy players stay drawn however far: never hidden in world PvP.",
        function() return PF.CVar("PB_AlwaysRenderPVP") == "1" end, function(v) pcall(SetCVar, "PB_AlwaysRenderPVP", v and "1" or "0") end)
      W.Check(p, "Always draw raid-marked ones", "Anyone with a raid mark stays drawn.",
        function() return PF.CVar("PB_AlwaysRenderRaidMarks") == "1" end, function(v) pcall(SetCVar, "PB_AlwaysRenderRaidMarks", v and "1" or "0") end)
    end

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
    O.PfSld(p, "Ceiling", "Lua memory never goes past this: at it, a clean-up runs at once, even in a fight.", 300, 1200, 50, G,
      "gcmax", function() PF.Steer() end, function(v) return v .. " MB" end)
    -- (27 Nov 2026) the chat warning when add-ons hold a lot
    O.PfSld(p, "Warn in chat above", "When add-ons hold more than this (after a clean-up), one chat line says so and what "
      .. "helps - the game has 4 GB for everything, and running out crashes it (\"Not enough memory\"). 0 = never.", 0, 800, 50, G,
      "memwarn", nil, function(v) return tonumber(v) == 0 and "Off" or (v .. " MB") end)
    Chk(p, "Clean up two seconds after a fight", nil, "gcafter")
    Chk(p, "Clean up after a loading screen", nil, "gcload")
    W.Buttons(p, { { "Clean up now", function() PF.Clean("by hand") end, 130, "Runs the clean-up at once (a short hitch)." } })
    Chk(p, "Game's own UI ticker 30 times a second", "The game runs its fades, flashes, chat-frame mouse check, button pulses and "
      .. "battleground map dots every frame - the costliest script in /pfperf. This runs them 30 times a second at their real speed. "
      .. "Off = every frame, as the game does.", "uitick")
    Chk(p, "Lighter world frame script", "The game's world frame looks over its popups and breath bars every frame, work that "
      .. "only matters while the interface is hidden (Alt+Z, the map). On: only then. Off = as the game does.", "wftick")
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
  end

  O:AddPage("Settings", "stperf", "Performance", Build)

  -- ---------------------------------------------------------------- nampower's own settings (20 Nov 2026)
  -- (user: "can we not bring the settings into our pfui ?") nampower.dll keeps its settings as NP_* CVars (saved by the
  -- game in Config.wtf, for every character - not part of pfUI profiles or layouts). Names, defaults and meanings from
  -- brues-code/nampower README (checked against the DLL's strings 20 Nov). Left out: the deprecated event toggles
  -- (pfUI registers the events it wants), the demon autocast data, NP_NameplateDistance (Nameplates page) and the
  -- per-token unit events (pet / party / raid / mouseover: pfUI's frames may count on them).
  local NP = {}
  pfUI.nampowerOptions = NP
  -- { cvar, label, tip, default, min, max, step, unit } ; min = nil = on / off
  NP.CARDS = {
    { "Spell queue", "Interface\\Icons\\Spell_Holy_BorrowedTime", "Press your next spell a little early and it goes off the moment the last one ends - no gap from your ping.", {
      { "QueueCastTimeSpells", "Queue spells with a cast time", "Frostbolt, Heal ... pressed during the last part of a cast go off right after it.", "1" },
      { "QueueInstantSpells", "Queue instant spells", "Instants on the global cooldown, pressed just before it ends.", "1" },
      { "QueueChannelingSpells", "Queue during channels", "Spells pressed near the end of a channel wait for it (and channels can be queued).", "1" },
      { "QueueTargetingSpells", "Queue ground spells", "Blizzard, Flamestrike, Rain of Fire ... queued too (cast at your cursor).", "1" },
      { "QueueOnSwingSpells", "Queue on-swing spells", "Heroic Strike, Cleave, Maul, Raptor Strike. Off by default since nampower 1.17.2.", "0" },
      { "QueueSpellsOnCooldown", "Queue spells coming off cooldown", "A spell with only a moment of cooldown left waits for it instead of 'Spell is not ready yet'.", "1" },
      { "SpellQueueWindowMs", "Queue window", "How long before a cast ends the next one can be queued. Bigger = easier, but a misclick is harder to take back.", "500", 0, 1000, 10, "ms" },
      { "CooldownQueueWindowMs", "Cooldown window", "How much cooldown may be left for a spell to be queued.", "250", 0, 1000, 10, "ms" },
      { "TargetingQueueWindowMs", "Ground spell window", "The queue window for ground spells.", "500", 0, 1000, 10, "ms" },
      { "OnSwingBufferCooldownMs", "On-swing wait", "After an on-swing spell, how long before the next on-swing spell can be queued.", "500", 0, 1000, 10, "ms" },
    } },
    { "Channels", "Interface\\Icons\\Spell_Nature_Lightning", "Drain Life, Arcane Missiles, Blizzard, Mind Flay, Tranquility ...", {
      { "ChannelQueueWindowMs", "Channel queue window", "How long before a channel ends the next spell can be queued.", "1500", 0, 3000, 50, "ms" },
      { "ChannelLatencyReductionPercentage", "End channels early by", "This much of your ping is taken off the end of a channel, so the next spell starts sooner without losing the last tick.", "75", 0, 100, 5, "%" },
      { "InterruptChannelsOutsideQueueWindow", "A new spell stops the channel", "Outside the queue window, casting stops your channel at once (the game's own way). Off = it waits.", "0" },
      { "DoubleCastToEndChannelEarly", "Press twice to end it on the next tick", "Press the same spell twice within 350 ms during a channel: it ends after its next tick.", "0" },
    } },
    { "Ground spells", "Interface\\Icons\\Spell_Arcane_Blink", "Spells you aim on the ground with the green circle.", {
      { "QuickcastTargetingSpells", "Quick cast every ground spell", "They land on your cursor at once, no circle to click.", "0" },
      { "QuickcastOnDoubleCast", "Quick cast by pressing twice", "Press a ground spell twice to cast it at the cursor (the game would cancel the circle instead).", "0" },
    } },
    { "Safety", "Interface\\Icons\\Spell_Holy_SealOfSacrifice", "Stops a few costly accidents.", {
      { "PreventRightClickTargetChange", "Right-click doesn't change target in combat", "Turning the camera with the right mouse button no longer picks someone else in a fight.", "0" },
      { "PreventRightClickPvPAttack", "Right-click doesn't attack PvP-flagged players", "No accidental PvP flag from a right-click.", "0" },
      { "PreventMountingWhenBuffCapped", "No mounting with 32 buffs", "With a full buff bar the mount aura can't land and you could not get off again: this blocks the mount instead.", "1" },
      { "SpamProtectionEnabled", "Spam protection", "While the server answers your cast, more presses of it are ignored (spamming confuses the queue).", "1" },
      { "RetryServerRejectedSpells", "Retry spells the server turned down", "'Not ready yet' / 'another action in progress' from the server: tried again by itself.", "1" },
    } },
    { "Chat bubbles", "Interface\\Icons\\INV_Misc_Note_01", "Speech bubbles over heads.", {
      { "ChatBubbleDistance", "Bubble distance", "How far away chat bubbles are still drawn.", "60", 10, 150, 5, "yd" },
      { "ChatBubblesWhisper", "Bubbles for whispers", nil, "0" },
      { "ChatBubblesRaid", "Bubbles for raid leader and warnings", nil, "0" },
      { "ChatBubblesBattleground", "Bubbles for battleground chat", nil, "0" },
    } },
    { "Extras", "Interface\\Icons\\INV_Misc_Book_09", nil, {
      { "EnableEnhancedTooltips", "More on tooltips", "Proc chance, internal cooldowns and item cooldowns on spell and item tooltips.", "1" },
      { "EnableLocalSetRaidTarget", "Raid marks when alone", "Marks work for you even out of a group (only you see them).", "1" },
      { "PreserveGreaterDemonAutocast", "Warlocks: keep Felguard / Doomguard autocast", "Their autocast choices come back when you resummon or swap them.", "1" },
    } },
    { "Fine tuning (advanced)", "Interface\\Icons\\INV_Misc_PocketWatch_01", "Leave these alone unless you know why: nampower's defaults suit most connections.", {
      { "MinBufferTimeMs", "Smallest buffer", "Added to each cast so the server never gets it too early. nampower adjusts it, never below this.", "55", 0, 200, 5, "ms" },
      { "NonGcdBufferTimeMs", "Buffer after off-GCD spells", "Wait after each spell that isn't on the global cooldown.", "100", 0, 300, 5, "ms" },
      { "MaxBufferIncreaseMs", "Biggest buffer step", "How much the buffer may grow each time the server turns a cast down.", "30", 0, 100, 5, "ms" },
      { "OptimizeBufferUsingPacketTimings", "Tune the buffer from your ping", "Uses your latency and the server's timings to set the buffer.", "0" },
      { "ReplaceMatchingNonGcdCategory", "Newer off-GCD spell replaces the queued one", "Two off-GCD spells of the same kind: the last one pressed goes.", "0" },
    }, true },
    { "Unit events (advanced)", "Interface\\Icons\\Spell_ChargePositive", "nampower can send health / mana / aura events for every unit around you by GUID. In crowds that is a lot of events.", {
      { "EnableUnitEventsGuid", "Unit events by GUID", "Health, mana and aura events for every unit near you, named by GUID (like SuperWoW). Add-ons that track any unit by GUID (DoT trackers, auto markers) want this.", "1" },
      { "EnableUnitEventsGuidFiltering", "Filter the busiest GUID events", "Keeps the GUID events but drops the ones that fire hundreds of times a second in raids (they have their own _GUID events). Keep it on.", "1" },
    }, true },
  }
  local function Get(cv)
    local ok, v = pcall(GetCVar, "NP_" .. cv)
    if ok then return v end
  end
  local function Set(cv, v) pcall(SetCVar, "NP_" .. cv, tostring(v)) end
  NP.Get, NP.Set = Get, Set
  function NP.Loaded() return Get("SpellQueueWindowMs") ~= nil end
  -- every setting back to nampower's own default
  function NP.Defaults()
    for _, c in ipairs(NP.CARDS) do for _, s in ipairs(c[4]) do if Get(s[1]) ~= nil then Set(s[1], s[4]) end end end
  end
  -- how many differ from the defaults
  function NP.Changed()
    local n = 0
    for _, c in ipairs(NP.CARDS) do
      for _, s in ipairs(c[4]) do
        local v = Get(s[1])
        if v ~= nil and tonumber(v) ~= tonumber(s[4]) then n = n + 1 end
      end
    end
    return n
  end

  local function BuildNP(p)
    W.Heading(p, "nampower", { about = "The settings of nampower.dll: spell queueing (your next spell goes off with no gap "
      .. "from your ping), channels, ground spells, safety and chat bubbles. Saved by the game for all your characters." })
    if not NP.Loaded() then
      W.Note(p, "|cffffcc00nampower isn't loaded.|r Get it with the Octo DLL Installer (Linux: install-linux.sh) and start the "
        .. "game through VanillaFixes.exe (OctoLauncher's Play with vanillaFixes on). Then come back here.")
      return
    end
    W.Live(p, function()
      local v = ""
      if type(_G.GetNampowerVersion) == "function" then
        local ok, a, b, c = pcall(_G.GetNampowerVersion)
        if ok and a then v = " " .. a .. "." .. (b or 0) .. "." .. (c or 0) end
      end
      local n = NP.Changed()
      return "nampower" .. v .. " is loaded.  " .. (n == 0 and "|cff999999All on nampower's defaults.|r" or ("|cffffd24d" .. n .. " changed from its defaults.|r"))
    end, 2)
    W.Buttons(p, { { "Back to nampower's defaults", function() NP.Defaults() if O.Rebuild then O:Rebuild("stnampower") end end, 200,
      "Every setting on this page back to what nampower ships with.", role = "danger" } })
    for _, card in ipairs(NP.CARDS) do
      W.Card(p, card[1], { icon = card[2], tip = card[3], folded = card[5] })
      for _, s in ipairs(card[4]) do
        local cv, def = s[1], s[4]
        if Get(cv) ~= nil then
          local tip = (s[3] and (s[3] .. " ") or "") .. "nampower's default: " .. (s[5] and (def .. " " .. s[8]) or (def == "1" and "on" or "off")) .. ". (NP_" .. cv .. ")"
          if s[5] then
            local u = s[8]
            W.Slider(p, s[2], tip, s[5], s[6], s[7], function() return tonumber(Get(cv)) or tonumber(def) end,
              function(v) Set(cv, math.floor(v + .5)) end, function(v) return (v or 0) .. " " .. u end)
          else
            W.Check(p, s[2], tip, function() return Get(cv) == "1" end, function(v) Set(cv, v and "1" or "0") end)
          end
        end
      end
    end
    W.Note(p, "Nameplate distance is on the Nameplates page. The settings above are the game's own (Config.wtf): profiles "
      .. "and UI layouts don't change them.")
  end
  O:AddPage("Settings", "stnampower", "nampower", BuildNP)
end)
