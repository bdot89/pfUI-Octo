pfUI:RegisterModule("minigames-options", "vanilla", function ()
  -- pfUI Octo :: OctoArcade's page, "Minigames" under Quality of Life (22 Nov 2026, modules/minigames.lua).
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local MG = pfUI.minigames
  local ICON = "Interface\\Icons\\"

  local function G() return MG and MG.S() or C.minigames or {} end
  local function Chk(p, label, desc, key)
    return W.Check(p, label, desc, function() return G()[key] == "1" end, function(v) G()[key] = v and "1" or "0" end)
  end
  local function Drop(p, label, desc, key, options)
    return W.Dropdown(p, label, desc, options, function() return G()[key] end, function(v) G()[key] = v end)
  end

  local function Build(p)
    W.Heading(p, "Minigames", { on = O.ModuleSwitch("minigames", "OctoArcade"), about = "OctoArcade: a classic Azeroth quiz "
      .. "and an aim trainer to pass the time on flights - they pop up when a flight starts, and open any time from here, "
      .. "/arcade, /quiz or /aim. Your bests go to your guild and group, and theirs show in Scores." })
    if not MG then W.Note(p, "OctoArcade is switched off: click the switch above and reload.") return end
    W.Tiles(p, {
      { "Quiz", "Normal, Heroic and Mythic runs - " .. table.getn(MG.DATA.quiz) .. " questions", ICON .. "INV_Misc_Book_09", function() MG.Show("quiz") end, "open" },
      { "Aim Trainer", "Six modes, from Gridshot to Kick", ICON .. "Ability_Marksmanship", function() MG.Show("aim") end, "go" },
      { "Scores", "Leaderboards with realm tags", ICON .. "INV_Misc_Note_06", function() MG.Show("board") end, "open" },
    })

    W.Card(p, "On flights", { icon = ICON .. "Ability_Mount_Gryphon_01" })
    Drop(p, "When a flight starts", "What opens by itself when you take a flight.", "onflight", {
      { key = "pick", label = "A small launcher to pick a game" }, { key = "quiz", label = "The quiz" },
      { key = "aim", label = "The aim trainer" }, { key = "off", label = "Nothing" } })
    Chk(p, "Close when you land", "A round that is running is finished first.", "closeland")

    W.Card(p, "Quiz", { icon = ICON .. "INV_Misc_Book_09" })
    Drop(p, "Practice: time per question", "For practice only (Normal, Heroic and Mythic have their own clocks). A bar runs down; out of time counts as wrong.", "quiztimer", {
      { key = "0", label = "No timer" }, { key = "10", label = "10 seconds" }, { key = "15", label = "15 seconds" },
      { key = "20", label = "20 seconds" }, { key = "30", label = "30 seconds" } })
    Chk(p, "Practice: next question by itself", "Goes on a moment after you answer (longer after a wrong one, to read why).", "quiznext")
    local cats = MG.quiz.CATS
    local count = {}
    for _, e in ipairs(MG.DATA.quiz) do count[e.c] = (count[e.c] or 0) + 1 end
    for _, d in ipairs(cats) do
      local key = d[1]
      W.Check(p, d[2] .. " |cff8a8f99(" .. (count[key] or 0) .. ")|r", "Practice asks questions from this category. Normal, Heroic and Mythic always use every category, so the boards stay fair.",
        function() return G().cats[key] ~= "0" end,
        function(v) G().cats[key] = v and "1" or "0" MG.quiz.deck = nil end)
    end

    W.Card(p, "Aim trainer", { icon = ICON .. "Ability_Marksmanship" })
    local modes = {}
    for _, m in ipairs(MG.aim.MODES) do table.insert(modes, { key = m.key, label = m.name .. " - " .. m.tip }) end
    Drop(p, "Mode", nil, "aimmode", modes)
    Drop(p, "Round length", nil, "aimtime", { { key = "15", label = "15 seconds" }, { key = "30", label = "30 seconds" },
      { key = "60", label = "60 seconds" } })
    W.Slider(p, "Target size", "Smaller is harder. Precision targets are about half this.", 24, 64, 2,
      function() return tonumber(G().aimsize) or 44 end, function(v) G().aimsize = tostring(v) end,
      function(v) return v .. " px" end)
    Drop(p, "Targets", "What the targets look like.", "aimfaces", {
      { key = "enemy", label = "The other faction's faces" }, { key = "creatures", label = "Murlocs, kobolds, gnolls and more" },
      { key = "class", label = "Class pictures" }, { key = "marks", label = "Raid marks" }, { key = "spells", label = "Spell icons" } })
    Chk(p, "Sounds", "A click on a hit, a buzz on a miss, a fanfare for a new best.", "sound")

    W.Card(p, "Scores", { icon = ICON .. "INV_Misc_Note_06" })
    Chk(p, "Share my bests", "New bests go to your guild and group, so they show on their Scores too.", "share")
    W.Check(p, "Share on the realm channel", "pfUI joins a hidden OctoArcade channel: every new best you set goes to everyone on the realm with pfUI Octo, "
      .. "and when you log in your boards fill from the top scores. You never see the channel in your chat.",
      function() return G().realm ~= "0" end,
      function(v)
        G().realm = v and "1" or "0"
        if v then MG.JoinRealm() else MG.LeaveRealm() end
      end)
    W.Slider(p, "Window size", nil, .7, 1.5, .05, function() return tonumber(G().scale) or 1 end,
      function(v) G().scale = tostring(v) if MG.win:IsShown() then MG.win:SetScale(v) end end,
      function(v) return math.floor(v * 100 + .5) .. "%" end)
    W.Buttons(p, {
      { "Clear my records", function()
        local _, me = MG.Store()
        me.quiz = { asked = 0, right = 0, streak = 0 }
        me.aim = {}
      end, nil, "Your quiz runs, practice streak and aim trainer bests start again.", role = "danger" },
      { "Clear the scoreboard", function() local s = MG.Store() s.board = {} end, nil,
        "Forgets the other players' scores (your own stay).", role = "danger" },
    })
  end
  O:AddPage("Quality of Life", "arcade", "Minigames", Build)
end)
