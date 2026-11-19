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

    W.Card(p, "What joins in", { icon = I .. "INV_Misc_Gear_01" })
    Chk(p, "Boss on your target frame", "Your target frame, target of target and the raid's targets show the boss (its crest or "
      .. "dragons, its cast bar).", "target")
    Chk(p, "Meters", "The meter windows show the test fight while the demo runs.", "meters")
    Chk(p, "Combat text", "Sample combat text while the demo runs.", "ctext")
    Chk(p, "Raid warnings", "Boss abilities and pulls in the middle of the screen, with the raid warning sound.", "warnings")
    O.PfSld(p, "A wipe every", "0 = never. The raid goes down on that pull and tries the same boss again.", 0, 6, 1, G, "wipes", nil,
      function(v) v = tonumber(v) or 0 if v == 0 then return "Never" end return v == 1 and "Every boss" or (v .. " bosses") end)
    W.Note(p, "/demo [raid | dungeon | dummy | pvp | afk | showcase] starts one, /demo stop ends it, /demo next skips ahead. "
      .. "A real fight ends the demo by itself. The AFK demo ends when you click or press a key.")
  end

  O:AddPage("Demo Mode", "demo", "Demo mode", Build)
end)
