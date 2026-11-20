pfUI:RegisterModule("demo-options", "vanilla", function ()
  -- pfUI Octo :: the Demo mode page, a tab under Quality of Life (19 Nov 2026, modules/demo.lua). One tile per demo,
  -- what joins in, and the controls while one runs.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local DM = pfUI.demo
  if not W or not O or not O.AddPage or not DM then return end
  local function G() return C.demo end
  local function Chk(p, label, desc, key) return O.PfChk(p, label, desc, G, key) end
  local I = "Interface\\Icons\\"

  local function Build(p)
    W.Heading(p, "Demo mode", { about = "A pretend raid, dungeon, battleground, target dummy or AFK screen on your own screen, "
      .. "with all your settings running: your real frames fill with a made-up group and enemy, with cast bars, debuffs to "
      .. "cure, raid warnings, threat, meters and combat text. It loops until you stop it. Nothing real happens: the game and "
      .. "other add-ons see none of it, nothing is sent to anyone, and Stop puts everything back. Use Edit on the bar at the "
      .. "top of the screen to change things while it runs." })

    W.Card(p, "Start a demo", { icon = I .. "INV_Misc_Head_Dragon_01", tip = "Pick one; it runs until you press Stop." })
    W.Tiles(p, {
      { "Raid (40)", "Bosses, trash, wipes, on a loop", I .. "INV_Misc_Head_Dragon_01", function() DM.Start("raid") end, "go" },
      { "Dungeon (5)", "Packs, kicks, sheep, end boss", I .. "INV_Misc_Key_03", function() DM.Start("dungeon") end, "go" },
      { "Target dummy", "Every rank and crest in turn", I .. "INV_Misc_Bone_HumanSkull_01", function() DM.Start("dummy") end, "go" },
    })
    W.Tiles(p, {
      { "PvP", "Enemy players, flags, honour", I .. "INV_BannerPVP_02", function() DM.Start("pvp") end, "go" },
      { "AFK", "Your AFK screen and chat", I .. "Spell_Nature_Sleep", function() DM.Start("afk") end, "go" },
      { "Showcase", "A guided tour of pfUI Octo", I .. "INV_Misc_Spyglass_03", function() DM.Start("showcase") end, "go" },
    })
    W.Live(p, function()
      if not DM.on then return "|cff888888No demo running.|r" end
      local b = DM.boss
      return "Running: |cffffffff" .. (DM.LABEL[DM.kind] or "Raid") .. "|r" .. (b and (" - " .. b.name .. " " .. math.floor(b.hp / b.max * 100 + .5) .. "%") or "")
        .. (DM.paused and "  |cffffaa33paused|r" or "") .. "  |cff888888" .. DM.speed .. "x|r"
    end)
    W.Buttons(p, {
      { "Stop the demo", function() DM.Stop() end, 150, "Everything back as it really is.", role = "danger" },
      { "Skip to the next part", function() DM.Next() end, 170, "Trash, boss, kill, rest." },
    })

    -- (20 Nov 2026, user: "a button we can press during the test that triggers events") DM.EVENTS, also on the demo
    -- bar's Events menu
    W.Card(p, "Make it happen", { icon = I .. "Ability_Warrior_Challange",
      tip = "While a demo runs (not AFK or the target dummy): press one to see how your setup shows it. One that needs a "
        .. "fight starts the boss first." })
    W.Live(p, function()
      if not DM.on then return "|cff888888Start a demo above, then press any of these - or use Events on the demo bar.|r" end
      if DM.kind == "afk" or DM.kind == "dummy" then return "|cffffaa33These need a group: the Raid, Dungeon, PvP or Showcase demo.|r" end
      return "|cff40d977Ready:|r press one - it happens at once on your frames, meters, threat and combat text."
    end)
    local row, last = {}, nil
    for _, e in ipairs(DM.EVENTS or {}) do
      if last and e.group ~= last and table.getn(row) > 0 then W.Buttons(p, row) row = {} end
      last = e.group
      local key = e.key
      table.insert(row, { e.label, function() DM.Event(key) end, 150, e.tip,
        role = (e.group == "Deaths" and (key == "res" or key == "bres")) and "go" or (e.group == "Deaths" and "danger" or "open") })
      if table.getn(row) == 4 then W.Buttons(p, row) row = {} end
    end
    if table.getn(row) > 0 then W.Buttons(p, row) end

    W.Card(p, "What joins in", { icon = I .. "INV_Misc_Gear_01" })
    Chk(p, "Boss on your target frame", "Your target frame, target of target and the raid's targets show the boss (its crest or "
      .. "dragons, its cast bar).", "target")
    Chk(p, "Meters", "The meter windows show the test fight while the demo runs.", "meters")
    Chk(p, "Combat text", "Sample combat text while the demo runs.", "ctext")
    Chk(p, "Raid warnings", "Boss abilities and pulls in the middle of the screen, with the raid warning sound.", "warnings")
    -- (the number box only has room for a number: the user's screenshot read "sses")
    O.PfSld(p, "Wipe every ... bosses", "0 = never, 1 = every boss, 3 = every third. The raid goes down on that pull and "
      .. "tries the same boss again.", 0, 6, 1, G, "wipes")
    -- (20 Nov 2026) you: the class kit the running demo casts
    W.Live(p, function()
      local k = DM.kit
      if not k then return "|cff888888Every demo but AFK casts your own class's spells, DoTs, cooldowns and procs.|r" end
      local function Names(list, n)
        local out = {}
        for i, e in ipairs(list or {}) do if i <= n then table.insert(out, e.name) end end
        return table.concat(out, ", ")
      end
      return "You (" .. (k.class or "?") .. "): |cffffffff" .. Names(k.hits, 4) .. "|r"
        .. (k.dots[1] and ("  DoTs: |cffffffff" .. Names(k.dots, 3) .. "|r") or "")
        .. (k.procs[1] and ("  Procs: |cffffffff" .. Names(k.procs, 2) .. "|r") or "")
    end)
    -- what cannot join in because it is switched off
    W.Live(p, function()
      local off = {}
      for _, m in ipairs({ { "cdm", "CoolDownManager" }, { "consumes", "OctoConsumes" }, { "octototems", "OctoTotems" },
        { "dots", "OctoDoTs" }, { "rinse", "OctoRinse" }, { "swing", "Swing Timer" }, { "plates", "Nameplates" },
        { "meters", "Meters" }, { "raid", "Raid frames" }, { "group", "Party frames" } }) do
        if C.disabled and C.disabled[m[1]] == "1" then table.insert(off, m[2]) end
      end
      if table.getn(off) == 0 then return "|cff55ff66Everything joins in.|r" end
      return "|cffffaa33Switched off, so not in the demo:|r " .. table.concat(off, ", ")
    end)
    W.Note(p, "/demo [raid | dungeon | dummy | pvp | afk | showcase] starts one, /demo stop ends it, /demo next skips ahead. "
      .. "A real fight ends the demo by itself. The AFK demo ends when you click or press a key.")
  end

  O:AddPage("Demo Mode", "demo", "Demo mode", Build)
end)
