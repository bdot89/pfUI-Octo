pfUI:RegisterModule("octolazy-options", "vanilla", function ()
  -- pfUI Octo :: the OctoLazy section (16 Nov 2026, modules/octolazy.lua): five tabs - Loot rolls,
  -- Groups, Battlegrounds, NPCs & quests, Bags, chat & more. Its own module so the section and
  -- its on / off switch stay when OctoLazy is switched off (then nothing of it is loaded).
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local R = pfUI.rules
  local function LZ() return pfUI.octolazy end
  local function G() return C.octolazy end
  local SEC = "OctoLazy"
  local tryItem = ""

  local function Off(p)
    W.Note(p, "OctoLazy is switched off. Use the switch at the top right of the Loot rolls tab to turn it back on (takes a reload).", nil, true)
  end
  local function Aside(p)
    local lz = LZ()
    if not lz or not lz.aside then return false end
    W.Note(p, "|cffffcc00_LazyPig is also switched on: it keeps the work and OctoLazy stands aside.|r")
    W.Buttons(p, { { "Switch _LazyPig off", function()
      if DisableAddOn then DisableAddOn(lz.Other()) end
      pfUI.gui.settingChanged = true
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffOctoLazy|r _LazyPig is switched off from the next reload. Its folder and settings stay.")
    end, 170, "Turns _LazyPig off (from the next reload) so OctoLazy does the work.", role = "off" } })
    return true
  end
  local function Head(p, title, about, switch)
    W.Heading(p, title, { on = switch and O.ModuleSwitch("octolazy", "OctoLazy") or nil, about = about })
    if not LZ() then Off(p) return false end
    Aside(p)
    return true
  end
  local function Chk(p, label, desc, key, after) return O.PfChk(p, label, desc, G, key, after) end
  local function Drop(p, label, desc, list, key, after)
    return W.Dropdown(p, label, desc, list, function() return G()[key] end, function(v) G()[key] = v if after then after(v) end end)
  end
  local function Secs(v) return v .. " s" end

  -- ================================================================ Loot rolls
  -- the "Matches" list: a plain choice that fills in the rule's text
  local KINDS = {
    { key = "", label = "Only the items in its box" },
    { key = 'Quality("uncommon")', label = "Green items" },
    { key = 'Quality("rare")', label = "Blue items" },
    { key = 'Quality("epic")', label = "Purple items" },
    { key = 'MaxQuality("common")', label = "Grey and white items" },
    { key = 'Equip() and Usable() and Upgrade() and MinQuality("uncommon")', label = "Upgrades I can use" },
    { key = 'Equip() and not Usable()', label = "Gear I cannot use" },
    { key = 'Known()', label = "Recipes I already know" },
    { key = 'Type("Recipe") and not Known()', label = "Recipes I do not know" },
    { key = 'BoP()', label = "Bind on pickup" },
    { key = 'BoE()', label = "Bind on equip" },
    { key = 'Type("Trade Goods", "Reagent")', label = "Trade goods" },
    { key = 'Quest()', label = "Quest items" },
    { key = "custom", label = "My own text rule (advanced)" },
  }
  local function KindOf(rule)
    rule = rule or ""
    for i = 1, table.getn(KINDS) do if KINDS[i].key == rule then return rule end end
    return "custom"
  end
  local QMAX = { { key = "2", label = "Green (uncommon)" }, { key = "3", label = "Blue (rare)" }, { key = "4", label = "Purple (epic)" }, { key = "5", label = "Everything" } }

  local function Rolls(p)
    if not Head(p, "Loot rolls", "OctoLazy rolls for you by your rules: top to bottom, the first rule that matches an item decides "
      .. "Need, Greed, Pass or Ask me. An item no rule matches is left to you, as always. Switched off = _LazyPig's jobs are "
      .. "the game's again and nothing of OctoLazy is loaded.", true) then return end
    local lz = LZ()
    W.Live(p, function()
      local on = G().rolls == "1"
      local s = on and "|cff55ff55On: rolls by your rules.|r" or "|cffffcc00Rolls are left to you (switch below).|r"
      s = s .. "   Rolled this session: |cffffffff" .. lz.stats.rolls .. "|r"
      local h = lz.history[1]
      if h then s = s .. "   Last: " .. (lz.ACTCOL[h.act] or "") .. (lz.ACTNAME[h.act] or "") .. "|r " .. (h.link or "") end
      return s
    end)

    W.Card(p, "How it rolls", { icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", tip = "When and how OctoLazy rolls for you." })
    Chk(p, "Roll for me by my rules", "Off: every roll is yours, the rules wait.", "rolls")
    Drop(p, "Roll by itself up to", "Items of a higher quality always stay for you to roll.", QMAX, "rollmax")
    O.PfSld(p, "Wait before rolling", "Time to look at the item first; 0 = at once.", 0, 15, 1, G, "rolldelay", nil, Secs)
    Chk(p, "Hold Shift when the roll shows = it is mine", "Holding Shift as the roll window comes up leaves that one roll to you.", "rollshift")
    Chk(p, "Never Need what I cannot use", "A rule's Need becomes Greed for an item your class or skills cannot use.", "needsafe")
    Chk(p, "Answer the bind on pickup question", "Rolls made by OctoLazy say yes to \"this item binds when picked up\".", "rollconfirm")
    Chk(p, "A chat line for each roll", "What was rolled, on what, and which rule did it.", "rollchat")
    Chk(p, "Yes to bind on pickup when I loot alone", "Out of a group, a bind on pickup item is looted without asking.", "lootbind")

    W.Card(p, "Ctrl + Alt", { icon = "Interface\\Icons\\INV_Misc_Gem_Emerald_02", tip = "_LazyPig's green roll key." })
    Chk(p, "Ctrl + Alt rolls every open green item", "Hold Ctrl and Alt for a moment while green roll windows are up.", "greenkey")
    Drop(p, "With", nil, { LZ().ACTS[1], LZ().ACTS[2], LZ().ACTS[3] }, "greenroll")

    local function Adv() return G().lzadvanced == "1" end
    W.Card(p, "Your rules", { icon = "Interface\\Icons\\INV_Misc_Note_02", tip = "Checked from the top; the first that matches decides. Drag items into a rule's box." })
    W.Buttons(p, {
      { "+ Need rule", function() lz.AddRule("need", "Need these") O:Rebuild("lzrolls") end, 110, "A new rule at the top: Need on the items you put in its box.", role = "go" },
      { "+ Greed rule", function() lz.AddRule("greed", "Greed these") O:Rebuild("lzrolls") end, 110, "A new rule at the top: Greed." },
      { "+ Pass rule", function() lz.AddRule("pass", "Pass these") O:Rebuild("lzrolls") end, 110, "A new rule at the top: Pass." },
    })
    W.Check(p, "Show the text rules (advanced)", "Text rules match whole kinds of items in your own words: Quality, Name, Type, Usable(), Upgrade()...",
      function() return Adv() end, function(v) G().lzadvanced = v and "1" or "0" O:Rebuild("lzrolls") end)

    local list = lz.Rules()
    for i = 1, table.getn(list) do
      local idx = i
      local function r() return lz.Rules()[idx] end
      local act = list[idx].act or "ask"
      W.Card(p, idx .. ".  " .. (lz.ACTCOL[act] or "") .. (lz.ACTNAME[act] or act) .. "|r   " .. (list[idx].name or "Rule")
        .. ((list[idx].zone and string.find(list[idx].zone, "%S")) and ("   |cff888888in " .. list[idx].zone .. "|r") or ""),
        { tip = "Rules are checked from the top; the first that matches decides." })
      W.Check(p, "Use this rule", nil, function() return r() and r().on == "1" end, function(v) if r() then r().on = v and "1" or "0" end end)
      W.Dropdown(p, "Roll", nil, lz.ACTS, function() return r() and r().act end, function(v) if r() then r().act = v O:Rebuild("lzrolls") end end)
      W.Dropdown(p, "Where", "Only in these places; elsewhere the next rule is asked.", lz.WHERE,
        function() return r() and r().where or "any" end, function(v) if r() then r().where = v end end)
      W.Dropdown(p, "Matches", "A kind of item, as well as the items in its box.", KINDS,
        function() return r() and KindOf(r().rule) end, function(v)
          if not r() then return end
          if v == "custom" then G().lzadvanced = "1" else r().rule = v end
          O:Rebuild("lzrolls")
        end)
      W.Edit(p, "Name", nil, function() return r() and r().name end, function(v) if r() then r().name = v O:Rebuild("lzrolls") end end, 260)
      W.Edit(p, "Only in", "Zones or dungeons this rule is for, split by commas (e.g. The Black Morass, Zul'Gurub). Empty: everywhere.",
        function() return r() and r().zone or "" end, function(v) if r() then r().zone = v or "" O:Rebuild("lzrolls") end end, 320)
      local zoneList = { { key = "", label = "Everywhere" } }
      for z = 1, table.getn(lz.ZONES) do table.insert(zoneList, { key = lz.ZONES[z], label = lz.ZONES[z] }) end
      W.Dropdown(p, "Add a dungeon", "Adds a dungeon or raid to \"Only in\" (Everywhere empties it).", zoneList, function() return "" end, function(v)
        if not r() then return end
        local cur = r().zone or ""
        if v == "" then r().zone = "" elseif not string.find(string.lower(cur), string.lower(v), 1, true) then
          r().zone = (string.find(cur, "%S") and (cur .. ", ") or "") .. v
        end
        O:Rebuild("lzrolls")
      end)
      W.ItemBox(p, "Items in this rule", "These items always match this rule.", function()
        local t = r() and r().items
        return type(t) == "table" and t or {}
      end, function(v) if r() then r().items = v end end, function() O:Rebuild("lzrolls") end)
      if Adv() then
        W.Edit(p, "Text rule", "For example: Quality(\"rare\") and Usable() and not Name(\"Libram\"). Empty: only the items above.",
          function() return r() and r().rule end, function(v) if r() then r().rule = v end end, 460)
        W.Live(p, function()
          local text = r() and r().rule
          if not text or text == "" then return "No text rule: only the items above match." end
          local fn, err = R.Compile(text)
          if not fn then return "|cffff5555This rule has a mistake:|r " .. tostring(err) end
          return "|cff55ff55Rule reads fine|r"
        end)
      end
      W.Buttons(p, {
        { "Move up", function() lz.MoveRule(idx, -1) O:Rebuild("lzrolls") end, 90, "Checked one place earlier." },
        { "Move down", function() lz.MoveRule(idx, 1) O:Rebuild("lzrolls") end, 90, "Checked one place later." },
        { "Delete", function() lz.RemoveRule(idx) O:Rebuild("lzrolls") end, 80, "Remove this rule.", role = "off" },
      })
    end
    W.Buttons(p, { { "Back to the starting rules", function() lz.ResetRules() O:Rebuild("lzrolls") end, 190,
      "Throws your rules away and puts the starting ones back (rep items of Zul'Gurub, The Black Morass, Naxxramas, Ahn'Qiraj...).", role = "off" } })
    if Adv() then W.Note(p, "Checks: Name, NameIs, ID, Type, Subtype, Equip, Quality(\"poor\"...\"legendary\"), MinQuality, MaxQuality, "
      .. "Level(min, max), Tooltip, BoE(), BoP(), Soulbound(), Quest(), Usable(), Known(), Upgrade(), Owned(n), Zone(...), "
      .. "Instance(\"raid\", \"dungeon\", \"pvp\", \"world\"), InRaid(), InGroup(), Class(...), Value(min, max). Join them with and / or / not.") end

    W.Card(p, "Try it", { icon = "Interface\\Icons\\INV_Misc_Spyglass_02", tip = "See what OctoLazy would roll on an item." })
    W.Edit(p, "Item", "An item ID (19708) or a link (Shift-click an item while typing here).", function() return tryItem end, function(v) tryItem = v or "" end, 260)
    W.Live(p, function()
      if tryItem == "" then return "Type an item ID or link above and press Enter." end
      local info = R.Info(tryItem)
      if not info.name then return "|cffffcc00The game does not know this item yet|r (see it once: a link, a bag, the auction house)." end
      local act, why = lz.Decide(info)
      if not act then return info.name .. ":  |cff33ccffleft to you|r  (no rule matched)" end
      return info.name .. ":  " .. (lz.ACTCOL[act] or "") .. (lz.ACTNAME[act] or act) .. "|r  (rule: " .. tostring(why) .. ")"
    end)

    W.Card(p, "Rolled this session", { icon = "Interface\\Icons\\INV_Misc_Book_09", tip = "The last rolls OctoLazy made." })
    W.Live(p, function()
      local h = lz.history
      if table.getn(h) == 0 then return "Nothing yet." end
      local out = {}
      for i = 1, math.min(8, table.getn(h)) do
        local e = h[i]
        table.insert(out, (lz.ACTCOL[e.act] or "") .. (lz.ACTNAME[e.act] or "") .. "|r " .. (e.link or "?") .. " |cff888888" .. (e.why or "") .. "|r")
      end
      return table.concat(out, "\n")
    end)
  end

  -- ================================================================ Groups
  local function Groups(p)
    if not Head(p, "Groups", "Invites, summons, resurrections and duels answered for you, the way you pick here.") then return end
    W.Card(p, "Group invites", { icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02", tip = "Who you join without being asked." })
    Chk(p, "Join guild members", nil, "invguild")
    Chk(p, "Join friends", nil, "invfriend")
    Chk(p, "Join anyone", "Also people who are not friends or in your guild.", "invstranger")
    Chk(p, "Say no to everyone else", "Invites from people who are not friends or guild members are turned down at once.", "invdecline")
    Chk(p, "Not while in a battleground or its queue", "There the invite window stays for you.", "invbg")
    Chk(p, "Say no to guild invites", "Guild invites are turned down (a chat line says who).", "guildinv")

    W.Card(p, "Summons", { icon = "Interface\\Icons\\Spell_Shadow_Twilight", tip = "A warlock's or meeting stone summon." })
    Chk(p, "Take summons", "Say no on the summon window to stop it.", "summon")
    Drop(p, "When", nil, LZ().WHEN, "summonmode")
    O.PfSld(p, "Wait", "With \"After a few seconds\".", 1, 60, 1, G, "summonwait", nil, Secs)
    Chk(p, "Wait while I am in combat", "Taken once the fight ends, if there is time left.", "summoncombat")

    W.Card(p, "Resurrections", { icon = "Interface\\Icons\\Spell_Holy_Resurrection", tip = "A priest's, paladin's or shaman's resurrection." })
    Chk(p, "Take resurrections", nil, "rez")
    Drop(p, "Where", nil, { { key = "instance", label = "In dungeons, raids and battlegrounds" }, { key = "any", label = "Everywhere" } }, "rezwhere")
    Chk(p, "Not from someone in combat", "Then the window stays for you (you might land in the fight).", "rezcombat")

    W.Card(p, "Duels", { icon = "Interface\\Icons\\INV_Sword_48", tip = "Duel requests." })
    Chk(p, "Turn duels down", "Hold Shift when it comes to see it.", "duel")
    Chk(p, "But not from friends and guild members", nil, "duelfriends")
  end

  -- ================================================================ Battlegrounds
  local function BGs(p)
    if not Head(p, "Battlegrounds", "Queues, entering and leaving, and the small chores of a battleground.") then return end
    local lz = LZ()
    W.Card(p, "When the queue pops", { icon = "Interface\\Icons\\INV_BannerPVP_02", tip = "The \"enter battleground\" window." })
    Chk(p, "Enter by myself", "Leave Queue on its window to stop it.", "bgenter")
    Drop(p, "When", nil, lz.WHEN, "bgentermode")
    O.PfSld(p, "Wait", "With \"After a few seconds\".", 1, 60, 1, G, "bgwait", nil, Secs)
    Chk(p, "Not while I am away (AFK)", nil, "bgafk")

    W.Card(p, "In the battleground", { icon = "Interface\\Icons\\INV_Misc_Rune_07", tip = "Dying, the end, shared quests." })
    Chk(p, "Release at once when I die", "Not with a soulstone up.", "bgrelease")
    Chk(p, "Leave when it is over", nil, "bgleave")
    O.PfSld(p, "Leave after", "Time to see the scores.", 0, 60, 1, G, "bgleavewait", nil, Secs)
    Chk(p, "Turn down quests shared by players", "No more \"Empty Stables\" pop-ups.", "bgquest")

    W.Card(p, "At the battle master", { icon = "Interface\\Icons\\INV_Jewelry_Amulet_07", tip = "Talking to a battle master." })
    Chk(p, "Queue at once", "As a group when you lead one; hold Shift to pick yourself.", "bgqueue")
    Chk(p, "Tell the group I queued us", nil, "bgannounce")

    W.Card(p, "Flag carriers", { icon = "Interface\\Icons\\INV_BannerPVP_01", tip = "Read from the battleground's lines." })
    W.Live(p, function()
      return "Enemy flag carrier: |cffff5555" .. (lz.efc or "none") .. "|r     Yours: |cff55ff55" .. (lz.fc or "none") .. "|r"
    end)
    W.Note(p, "Keys for them: Esc > Key Bindings > \"pfUI Octo: OctoLazy\" - target the enemy flag carrier, drop the flag "
      .. "(or Slow Fall), duel the target or cancel the duel.")
  end

  -- ================================================================ NPCs & quests
  local function NPCs(p)
    if not Head(p, "NPCs & quests", "Fewer clicks at people: menus skipped, quests taken and handed in.") then return end
    W.Card(p, "Skip the talking", { icon = "Interface\\GossipFrame\\GossipGossipIcon", tip = "When a menu has just one of these, it opens at once." })
    Chk(p, "Skip the menu", "Hold Ctrl as you talk to see it all the same.", "gossip")
    Chk(p, "Flight masters", nil, "gtaxi")
    Chk(p, "Vendors", nil, "gvendor")
    Chk(p, "Bankers", nil, "gbank")
    Chk(p, "Battle masters", nil, "gbattle")
    Chk(p, "Trainers", "Off by default: some trainers also reset talents.", "gtrainer")
    W.Edit(p, "Always pick these lines", "Menu lines picked at once, split by commas.", function() return G().gtext end, function(v) G().gtext = v or "" end, 420)

    W.Card(p, "Quests", { icon = "Interface\\GossipFrame\\AvailableQuestIcon", tip = "Taking and handing in quests." })
    Drop(p, "Quest help", nil, { { key = "off", label = "Off" }, { key = "shift", label = "While I hold Shift" }, { key = "always", label = "Always" } }, "quests")
    Chk(p, "Take new quests", "Also accepts the quest text.", "questaccept")
    Chk(p, "Repeat the last quest at the same person", "Token and repeat quests (scourge stones, marks, coins) go round fast.", "questrepeat")
    Drop(p, "With a choice of rewards", nil, { { key = "ask", label = "Let me pick" }, { key = "value", label = "Take the one that sells best" } }, "questchoice")
  end

  -- ================================================================ Bags, chat & more
  local function More(p)
    if not Head(p, "Bags, chat & more", "Bag clicks, quieter chat, Salvation, the camera and key combinations.") then return end
    local lz = LZ()
    W.Card(p, "Bags", { icon = "Interface\\Icons\\INV_Misc_Bag_08", tip = "Clicks on bag items." })
    Chk(p, "Right-click puts an item in the trade or the mail", "With the trade or mail window up. (At the auction house: Auctions > Right-click a bag item to sell it.)", "rightclick")
    Chk(p, "Shift + right-click: make stacks of a number", "A small window asks how many in each stack (not at a vendor).", "split")
    if C.global then
      O.PfChk(p, "Sell grey items at vendors", "pfUI Octo's own (the same as Quality of Life).", function() return C.global end, "autosell")
      O.PfChk(p, "Repair at vendors", "pfUI Octo's own (the same as Quality of Life).", function() return C.global end, "autorepair")
    end
    if C.loot then O.PfChk(p, "Loot window at the mouse", "pfUI Octo's own (the same as Quality of Life).", function() return C.loot end, "mousecursor") end

    W.Card(p, "Chat", { icon = "Interface\\Icons\\INV_Letter_15", tip = "Lines you would rather not see." })
    Chk(p, "Hide other players' rolls on green and blue items", "Who won is still shown.", "chatrolls")
    Chk(p, "Hide other players' grey and white loot", nil, "chatjunk")
    Chk(p, "Hide \"your share of the loot\" lines", nil, "chatmoney")
    Chk(p, "Quiet the World channel", nil, "worldmute")
    W.Edit(p, "Its name", nil, function() return G().worldname end, function(v) G().worldname = v or "World" end, 160)
    Chk(p, "In raids", nil, "worldraid")
    Chk(p, "In dungeons", nil, "worlddungeon")
    Chk(p, "In battlegrounds", nil, "worldbg")
    Chk(p, "Everywhere", nil, "worldalways")

    W.Card(p, "Salvation", { icon = "Interface\\Icons\\Spell_Holy_SealOfSalvation", tip = "Blessing of Salvation lowers threat - bad for a tank." })
    Drop(p, "Take Salvation off", nil, { { key = "off", label = "Never" }, { key = "tank", label = "When I tank (shield or Defensive Stance, bear form, Righteous Fury)" },
      { key = "always", label = "Always" } }, "salva", function() if lz.Salvation then lz.Salvation() end end)

    W.Card(p, "Camera", { icon = "Interface\\Icons\\INV_Misc_Spyglass_03", tip = "How far the camera can go out." })
    Chk(p, "Farther camera", nil, "camera", function() if G().camera == "1" then lz.Camera() elseif SetCVar then SetCVar("cameraDistanceMax", 15) end end)
    O.PfSld(p, "Up to", nil, 15, 50, 1, G, "cameradist", function() lz.Camera() end, function(v) return v .. " yd" end)

    W.Card(p, "Key combinations", { icon = "Interface\\Icons\\INV_Misc_Key_03", tip = "Held for a moment, with nothing else pressed." })
    Chk(p, "Use key combinations", "Ctrl + Alt: open a trade with your target, or accept the trade. Ctrl + Shift: follow your target. Alt + Shift: inspect them.", "keys")
    Chk(p, "Ctrl + Alt + Shift logs out", nil, "keylogout")
    W.Note(p, "More keys: Esc > Key Bindings > \"pfUI Octo: OctoLazy\" (flag carrier, drop the flag, duel, reload, log out). /lazy opens this section.")
  end

  O:AddPage(SEC, "lzrolls", "Loot rolls", Rolls)
  O:AddPage(SEC, "lzgroup", "Groups", Groups)
  O:AddPage(SEC, "lzbg", "Battlegrounds", BGs)
  O:AddPage(SEC, "lznpc", "NPCs & quests", NPCs)
  O:AddPage(SEC, "lzmore", "Bags, chat & more", More)
end)
