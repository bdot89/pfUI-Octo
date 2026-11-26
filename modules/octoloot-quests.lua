pfUI:RegisterModule("octoloot-quests", "vanilla:tbc", function ()
  -- pfUI Octo :: OctoLoot's dungeon quests (26 Nov 2026). User with Naowh Forever's Dungeon Journal: "how it maps out the
  -- quests and chains for every dungeon with a pop up guide that we could make easy and trackable with arrow waypoint
  -- options ... dungeon quests and pre quests EASY inside and out the instance ... VERY FAST use DLLS ... the octo DB with
  -- the atlas and DB ingame all working". Naowh is all rights reserved: ideas only (marks per quest, the chain, "to do"
  -- count, waypoints per step, share with the group), nothing of its code, data or art.
  --
  -- Which quests belong to which instance and side, and their reward items: Q lines in octoloot-data.lua (facts from
  -- Atlas-CFM's quest lists). Everything else is read live from pfQuest's database (pfDB, already in memory): name,
  -- objective, level, who gives and takes it and where they stand, what it needs first (the chain). Where you are with
  -- a quest: ClassicAPI C_QuestLog.IsQuestFlaggedCompleted (the server's own answer) / GetLogIndexForQuestID, else
  -- pfQuest's history and the quest log by title. Waypoints are pfQuest map pins with its arrow (addon "OCTOLOOT").
  local OL = pfUI.octoloot
  if not OL then return end
  local Q = {}
  OL.quests = Q

  local function DB(kind) return rawget(_G, "pfDB") and pfDB[kind] end
  function Q.Data(id) local d = DB("quests") return d and d.data and d.data[id] end
  function Q.Loc(id) local d = DB("quests") return d and d.loc and d.loc[id] end
  function Q.Title(id) local l = Q.Loc(id) return l and l.T or ("Quest " .. id) end
  function Q.Side() return UnitFactionGroup and UnitFactionGroup("player") == "Horde" and "H" or "A" end

  -- the instance's quests for your side: { { id, pick, rewards = { ids } } } (made once per instance)
  function Q.For(inst)
    if not inst then return {} end
    local db = OL.Load()
    local lines = db and db.quests and db.quests[inst.key]
    if not lines then return {} end
    inst.questList = inst.questList or {}
    local side = Q.Side()
    if inst.questList[side] then return inst.questList[side] end
    local out, seen = {}, {}
    for _, line in ipairs(lines) do
      local _, _, s, id, pick, rw = string.find(line, "^Q%^[^%^]*%^(%a)%^(%d+)%^(%d)%^([%d,]*)")
      id = tonumber(id)
      if id and s == side and not seen[id] then
        seen[id] = true
        local q = { id = id, pick = pick == "1", rewards = {} }
        for x in string.gfind(rw or "", "%d+") do table.insert(q.rewards, tonumber(x)) end
        table.insert(out, q)
      end
    end
    -- by level, as you would do them
    table.sort(out, function(a, b)
      local da, dbb = Q.Data(a.id), Q.Data(b.id)
      local la, lb = da and da.lvl or 0, dbb and dbb.lvl or 0
      if la ~= lb then return la < lb end
      return a.id < b.id
    end)
    inst.questList[side] = out
    return out
  end

  -- ---------------------------------------------------------------- where you are with a quest

  function Q.Done(id)
    local cq = rawget(_G, "C_QuestLog")
    if cq and cq.IsQuestFlaggedCompleted then
      local ok, v = pcall(cq.IsQuestFlaggedCompleted, id)
      if ok and v ~= nil then return v and true or false end
    end
    local h = rawget(_G, "pfQuest_history")
    return h and h[id] and true or false
  end

  -- the quest log by title (plain 1.12) - read once a paint (Q.log), dropped after
  function Q.ScanLog()
    local log = {}
    if not GetNumQuestLogEntries then return log end
    local n = GetNumQuestLogEntries() or 0
    for i = 1, n do
      local title, level, _, header, _, complete = GetQuestLogTitle(i)
      if title and not header then log[title] = { index = i, level = level, complete = complete } end
    end
    return log
  end
  function Q.LogIndex(id)
    local f = rawget(_G, "GetLogIndexForQuestID")
    if f and rawget(_G, "C_QuestLog") then
      local ok, i = pcall(f, id)
      if ok and i and i > 0 then return i end
      if ok then return nil end
    end
    Q.log = Q.log or Q.ScanLog()
    local e = Q.log[Q.Title(id)]
    return e and e.index
  end
  -- objectives done of all, and whether it is ready to hand in
  function Q.Progress(index)
    local done, total = 0, 0
    if GetNumQuestLeaderBoards then
      local n = GetNumQuestLeaderBoards(index) or 0
      for j = 1, n do
        local _, _, finished = GetQuestLogLeaderBoard(j, index)
        total = total + 1
        if finished then done = done + 1 end
      end
    end
    local _, _, _, _, _, complete = GetQuestLogTitle(index)
    return done, total, complete == 1 or complete == true or (total > 0 and done == total)
  end

  -- "done" | "log" | "ready" (you can take it) | "low" (your level) | "locked" (needs a quest first), and what it needs
  function Q.State(id)
    if Q.Done(id) then return "done" end
    local li = Q.LogIndex(id)
    if li then return "log", li end
    local d = Q.Data(id)
    local missing
    for _, p in ipairs(d and d.pre or {}) do
      if not Q.Done(p) then missing = missing or {} table.insert(missing, p) end
    end
    if missing then return "locked", missing end
    if d and d.min and (UnitLevel("player") or 1) < d.min then return "low", d.min end
    return "ready"
  end

  -- the chain up to a quest: every quest it needs first (and theirs), first ones first
  Q.chains = {}
  function Q.Chain(id)
    if Q.chains[id] then return Q.chains[id] end
    local out, seen = {}, {}
    local function walk(x, depth)
      if seen[x] or depth > 25 then return end
      seen[x] = true
      local d = Q.Data(x)
      for _, p in ipairs(d and d.pre or {}) do walk(p, depth + 1) end
      table.insert(out, x)
    end
    walk(id, 0)
    -- quests that follow it, as far as pfQuest's database knows (one after another)
    local all = DB("quests") and DB("quests").data
    if all then
      local cur, n = id, 0
      while n < 8 do
        local nextq
        for qid, d in pairs(all) do
          if d.pre and table.getn(d.pre) == 1 and d.pre[1] == cur and not seen[qid] then nextq = qid break end
        end
        if not nextq then break end
        seen[nextq] = true
        table.insert(out, nextq)
        cur = nextq
        n = n + 1
      end
    end
    Q.chains[id] = out
    return out
  end

  -- who gives / takes it: { name, kind "U"|"O"|"I", id, zone, x, y } (the first spawn the database has)
  function Q.Who(id, which)
    local d = Q.Data(id)
    local rel = d and d[which or "start"]
    if not rel then return nil end
    for _, kind in ipairs({ "U", "O", "I" }) do
      local ids = rel[kind]
      if ids and ids[1] then
        local wid = ids[1]
        local who = { kind = kind, id = wid }
        local src = kind == "U" and DB("units") or (kind == "O" and DB("objects") or DB("items"))
        who.name = src and src.loc and src.loc[wid]
        if type(who.name) == "table" then who.name = who.name.T or who.name.N end
        local data = src and src.data and src.data[wid]
        local c = data and data.coords and data.coords[1]
        if c then
          who.x, who.y = c[1], c[2]
          local z = DB("zones")
          who.zone = z and z.loc and z.loc[c[3]] or nil
        end
        who.name = who.name or ("#" .. wid)
        return who
      end
    end
  end
  function Q.WhereText(who)
    if not who then return "" end
    if who.kind == "I" then return "an item that starts it" end
    if who.zone and who.x then return string.format("%s  %d, %d", who.zone, who.x, who.y) end
    if who.zone then return who.zone end
    return "inside the instance"
  end

  -- ---------------------------------------------------------------- waypoints (pfQuest's pins and arrow)

  function Q.HasPfQuest() return rawget(_G, "pfDatabase") and rawget(_G, "pfMap") and true or false end
  function Q.Waypoint(id, which)
    if not Q.HasPfQuest() then
      UIErrorsFrame:AddMessage("Waypoints need pfQuest (Settings > pfQuest).", 1, .3, .3)
      return
    end
    local who = Q.Who(id, which or "start")
    pcall(pfMap.DeleteNode, pfMap, "OCTOLOOT")
    local meta = { addon = "OCTOLOOT", arrow = true, layer = 9, quest = Q.Title(id), questid = id,
      QTYPE = (which == "end") and "NPC_END" or "NPC_START",
      texture = (rawget(_G, "pfQuestConfig") and pfQuestConfig.path or "Interface\\AddOns\\pfQuest") .. "\\img\\"
        .. ((which == "end") and "complete_c" or "available_c") }
    local maps
    local ok = pcall(function()
      if which == "all" then
        maps = pfDatabase:SearchQuestID(id, meta)
      elseif who and who.kind == "U" then
        maps = pfDatabase:SearchMobID(who.id, meta)
      elseif who and who.kind == "O" then
        maps = pfDatabase:SearchObjectID(who.id, meta)
      end
    end)
    if not ok or not maps then
      UIErrorsFrame:AddMessage("pfQuest's database has no place for that one.", 1, .82, 0)
      return
    end
    pfMap.queue_update = GetTime()
    if pfQuest and pfQuest.route and pfQuest.route.SetTarget then pcall(pfQuest.route.SetTarget, meta) end
    Q.wp = { id = id, which = which or "start" }
    local where = which == "all" and "everything for it" or (who and (who.name .. " - " .. Q.WhereText(who)) or "")
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd133OctoLoot|r: waypoint for |cffffffff" .. Q.Title(id) .. "|r: " .. where
      .. "  (the pfQuest arrow points the way; /ol clear takes it off)")
  end
  function Q.ClearWaypoint()
    if not Q.HasPfQuest() then return end
    pcall(pfMap.DeleteNode, pfMap, "OCTOLOOT")
    if pfQuest and pfQuest.route and pfQuest.route.SetTarget then pcall(pfQuest.route.SetTarget, nil) end
    pfMap.queue_update = GetTime()
    Q.wp = nil
  end

  -- share every quest of this instance in your log with the group, one a second (the game shares one at a time)
  local share = CreateFrame("Frame")
  share:Hide()
  share:SetScript("OnUpdate", function()
    if (this.at or 0) > GetTime() then return end
    this.at = GetTime() + 1.1
    local nxt = table.remove(this.list or {}, 1)
    if not nxt then this:Hide() return end
    SelectQuestLogEntry(nxt)
    if GetQuestLogPushable and GetQuestLogPushable() then QuestLogPushQuest() end
  end)
  function Q.ShareAll(inst)
    local list = {}
    for _, q in ipairs(Q.For(inst)) do
      local li = Q.LogIndex(q.id)
      if li then table.insert(list, li) end
    end
    if table.getn(list) == 0 then UIErrorsFrame:AddMessage("None of this instance's quests are in your log.", 1, .82, 0) return end
    share.list, share.at = list, 0
    share:Show()
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd133OctoLoot|r: sharing " .. table.getn(list) .. " quest(s) with your group.")
  end

  -- ---------------------------------------------------------------- the rows OctoLoot draws

  Q.ICON = {
    done = "Interface\\RaidFrame\\ReadyCheck-Ready", log = "Interface\\GossipFrame\\ActiveQuestIcon",
    ready = "Interface\\GossipFrame\\AvailableQuestIcon", low = "Interface\\GossipFrame\\AvailableQuestIcon",
    locked = "Interface\\GossipFrame\\AvailableQuestIcon",
  }
  -- the level colour as the game's quest log draws it
  function Q.LevelColor(lvl)
    local me = UnitLevel("player") or 1
    local d = (lvl or me) - me
    if d >= 5 then return 1, .1, .1 end
    if d >= 3 then return 1, .5, .25 end
    if d >= -2 then return 1, 1, 0 end
    if d >= -8 then return .25, .75, .25 end
    return .5, .5, .5
  end

  -- one quest as a row: { quest = id, ... } with its state worked out
  function Q.Row(id, extra)
    local d = Q.Data(id)
    local st, more = Q.State(id)
    local e = { quest = id, state = st, lvl = d and d.lvl or 0, min = d and d.min or 0 }
    local who = Q.Who(id, "start")
    if st == "done" then e.info = "|cff55ff77Done|r"
    elseif st == "log" then
      local dn, tot, ready = Q.Progress(more)
      e.info = ready and "|cff55ff77Ready to hand in|r" or ("In your log  " .. dn .. " / " .. tot)
      e.right = ready and "|cff55ff77ready|r" or (tot > 0 and (dn .. "/" .. tot) or "")
    elseif st == "locked" then
      local names = {}
      for _, p in ipairs(more) do table.insert(names, Q.Title(p)) end
      e.info = "|cffff9a55Needs first:|r " .. table.concat(names, ", ")
    elseif st == "low" then e.info = "|cffff6655From level " .. more .. "|r"
    else e.info = "From " .. (who and who.name or "?") .. "  |cff8c8c8c" .. Q.WhereText(who) .. "|r" end
    if extra then for k, v in pairs(extra) do e[k] = v end end
    return e
  end

  -- an instance's quests in groups: in your log, ready to take, not yet, done
  function Q.ListEntries(inst)
    Q.log = nil
    local out = {}
    local list = Q.For(inst)
    local groups = { log = {}, ready = {}, low = {}, locked = {}, done = {} }
    for _, q in ipairs(list) do
      local e = Q.Row(q.id)
      table.insert(groups[e.state] or groups.ready, e)
    end
    local function add(key, head, note)
      local g = groups[key]
      if table.getn(g) == 0 then return end
      table.insert(out, { head = head .. "  " .. table.getn(g), note = note })
      for _, e in ipairs(g) do table.insert(out, e) end
    end
    add("log", "In your log", "click one for its guide - Alt-click for a waypoint")
    add("ready", "Ready to take", "you can pick these up now")
    add("locked", "Needs a quest first", "the guide shows the whole chain")
    add("low", "Not your level yet", "")
    add("done", "Done", "")
    if table.getn(out) == 0 then
      table.insert(out, { head = "No quests for this one", note = "the lists know none for your side" })
    end
    return out
  end
  -- how many you can still do here (in the log or ready to take)
  function Q.ToDo(inst)
    Q.log = nil
    local n = 0
    for _, q in ipairs(Q.For(inst)) do
      local st = Q.State(q.id)
      if st == "log" or st == "ready" then n = n + 1 end
    end
    return n, table.getn(Q.For(inst))
  end

  -- one quest's guide: objective, giver and hand-in (waypoints), the chain step by step, what it asks for, the rewards
  function Q.PageEntries(id, inst)
    Q.log = nil
    local out = {}
    local d = Q.Data(id)
    local loc = Q.Loc(id)
    local st, more = Q.State(id)
    local status = ({ done = "done", log = "in your log", ready = "you can take it", low = "from level " .. tostring(more),
      locked = "needs a quest first" })[st] or ""
    table.insert(out, { head = Q.Title(id), big = true, note = "level " .. (d and d.lvl or "?") .. "  -  " .. status })
    if loc and loc.O and loc.O ~= "" then table.insert(out, { text = (string.gsub(loc.O, "%$B", " ")) }) end
    local start, ender = Q.Who(id, "start"), Q.Who(id, "end")
    table.insert(out, { head = "Where to go", note = "click a line: a waypoint, and pfQuest's arrow points there" })
    if start then
      table.insert(out, { title = "Given by " .. start.name, sub = Q.WhereText(start), icon = Q.ICON.ready, plain = true,
        where = "a waypoint to " .. start.name, go = function() Q.Waypoint(id, "start") end })
    end
    if ender then
      table.insert(out, { title = "Hand in to " .. ender.name, sub = Q.WhereText(ender), icon = Q.ICON.log, plain = true,
        where = "a waypoint to " .. ender.name, go = function() Q.Waypoint(id, "end") end })
    end
    table.insert(out, { title = "Everything for it on the map", sub = "giver, objectives and hand-in", icon = "Interface\\Icons\\INV_Misc_Map_01",
      plain = true, where = "every pin for it", go = function() Q.Waypoint(id, "all") end })
    if Q.wp then
      table.insert(out, { title = "Clear the waypoint", sub = "takes OctoLoot's pins and arrow off", icon = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
        plain = true, where = "nothing - clears it", go = function() Q.ClearWaypoint() OL.PaintMain() end })
    end
    local chain = Q.Chain(id)
    if table.getn(chain) > 1 then
      local doneN = 0
      for _, c in ipairs(chain) do if Q.Done(c) then doneN = doneN + 1 end end
      table.insert(out, { head = "The chain  " .. doneN .. " / " .. table.getn(chain), note = "every step in order - click one for its guide" })
      for i, c in ipairs(chain) do
        table.insert(out, Q.Row(c, { step = i, here = (c == id) }))
      end
    end
    -- what it asks you to bring
    local items = d and d.obj and d.obj.I
    if items and table.getn(items) > 0 then
      table.insert(out, { head = "It asks for", note = "" })
      for _, iid in ipairs(items) do
        local it = OL.Item(iid)
        if not it then
          local il = DB("items") and DB("items").loc and DB("items").loc[iid]
          it = { id = iid, q = 1, name = type(il) == "string" and il or ("Item " .. iid) }
        end
        table.insert(out, { item = it, view = true })
      end
    end
    -- the rewards (the instance's list knows them)
    local rewards, pick
    for _, q in ipairs(Q.For(inst or OL.inst)) do if q.id == id then rewards, pick = q.rewards, q.pick end end
    if rewards and table.getn(rewards) > 0 then
      table.insert(out, { head = pick and "Rewards  -  choose one of these" or "Rewards", note = "" })
      for _, iid in ipairs(rewards) do
        local it = OL.Item(iid)
        if it then table.insert(out, { item = it, view = true }) end
      end
    end
    return out
  end

  -- the quest's tooltip: its objective and where you are with it
  function Q.Tip(owner, e)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local r, g, b = Q.LevelColor(e.lvl)
    GameTooltip:AddLine("[" .. (e.lvl or "?") .. "] " .. Q.Title(e.quest), r, g, b)
    local loc = Q.Loc(e.quest)
    if loc and loc.O then GameTooltip:AddLine((string.gsub(loc.O, "%$B", " ")), .9, .9, .9, 1) end
    GameTooltip:AddLine(" ")
    if e.info then GameTooltip:AddLine(e.info, 1, 1, 1, 1) end
    local who = Q.Who(e.quest, "start")
    if who then GameTooltip:AddDoubleLine("Given by", who.name .. "  |cff8c8c8c" .. Q.WhereText(who) .. "|r", .7, .7, .7, 1, 1, 1) end
    GameTooltip:AddLine("Click: its guide   Alt-click: waypoint to the giver   Shift-click: link", .5, .51, .55)
    GameTooltip:Show()
  end
  function Q.Click(e, button)
    if IsAltKeyDown() then
      local st = Q.State(e.quest)
      Q.Waypoint(e.quest, st == "log" and "all" or "start")
    elseif IsShiftKeyDown() then
      local box = ChatFrameEditBox
      if box then
        if not box:IsVisible() then box:Show() end
        local d = Q.Data(e.quest)
        box:Insert("|cffffff00|Hquest:" .. e.quest .. ":" .. (d and d.lvl or 0) .. "|h[" .. Q.Title(e.quest) .. "]|h|r")
      end
    else
      OL.ShowQuest(e.quest)
    end
  end

  -- /ol clear: take the waypoint off
  OL.ClearWaypoint = Q.ClearWaypoint

  -- walking into an instance with quests still to do for it: one line in chat (C.octoloot.questhint), once per visit
  local hint = CreateFrame("Frame")
  hint:RegisterEvent("PLAYER_ENTERING_WORLD")
  hint:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  hint:SetScript("OnEvent", function()
    if C.octoloot.questhint == "0" then return end
    local inside, kind = IsInInstance and IsInInstance()
    if not inside or (kind ~= "party" and kind ~= "raid") then hint.last = nil return end
    this.at = GetTime() + 3
    this:Show()
  end)
  hint:SetScript("OnUpdate", function()
    if not this.at or GetTime() < this.at then return end
    this.at = nil
    this:Hide()
    local wasOpen = OL.db ~= nil
    local inst = OL.Here()
    if not inst or hint.last == inst.key then
      if not wasOpen and not (OL.frame and OL.frame:IsShown()) then OL.Unload() end
      return
    end
    hint.last = inst.key
    local todo, total = Q.ToDo(inst)
    local inLog = 0
    for _, q in ipairs(Q.For(inst)) do if Q.LogIndex(q.id) then inLog = inLog + 1 end end
    if todo > 0 then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd133OctoLoot|r: " .. inst.name .. " - |cffffffff" .. inLog .. "|r of its quests in your log, |cffffffff"
        .. todo .. "|r to do in all.  |cff66ccff/ol quests|r for the guide.")
    end
    -- the tables were only read for this: let them go again
    if not wasOpen and not (OL.frame and OL.frame:IsShown()) then OL.Unload() end
  end)
  hint:Hide()
end)
