pfUI:RegisterModule("mail", "vanilla", function ()
  -- pfUI Octo :: mailbox (16 Nov 2026; user, with TurtleMail: "make it our own make it better ... There
  -- should be no times when loot is locking out collecting in our mail for example having pvp marks").
  -- Our own window in place of the game's at a mailbox: the whole inbox in one list, Collect all, a
  -- letter pane, and a Send tab that mails many items at once. Nothing of TurtleMail is copied; its
  -- feature list was the model.
  --
  -- Why TurtleMail stalls: it walks the inbox from the top and moves on only when the game answers with
  -- MAIL_INBOX_UPDATE. A mail the game refuses (marks you hold the most of, full bags, a locked item)
  -- gets no answer, or the one error it knows, and the walk stops. Here every step has a time limit: a
  -- mail that does not change in time, or that the game says no to, is put aside and the next one goes.
  -- The walk goes down the list in order; every step looks again from the top (mails put aside are known by
  -- what they are, not where), so a deleted letter never makes it miss one. (16 Nov 2026, user: "the next
  -- item it should take behind the arathi basin marks is the next pearl not random" - it went bottom-up before)
  --
  --   M.Collect(kind)  kind = "all" | "gold" | "ah" | "system"; M.Stop()
  --   M.Send(to, subject, body, money, cod, items)  items = { { bag, slot, link }... }: one mail each
  --   pfUI_cache.mail["Realm-Faction"].names = { name = last time }: names the To box suggests
  local M = { skip = {}, items = {}, open = false }
  pfUI.mail = M
  local function S() return C.mail end
  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local OTHERS = { "TurtleMail", "Postal", "CT_MailMod", "GMail", "BulkMail", "MailTo", "OpenAll" }

  function M.Other()
    if IsAddOnLoaded then
      for _, n in ipairs(OTHERS) do if IsAddOnLoaded(n) then return n end end
    end
  end
  function M.Active() return S().enable ~= "0" and not M.Other() end

  -- ---------------------------------------------------------------- helpers

  function M.Money(c)
    c = math.floor((tonumber(c) or 0) + .5)
    if c <= 0 then return "|cff8080800c|r" end
    local g, s, k = math.floor(c / 10000), math.floor(math.mod(c, 10000) / 100), math.mod(c, 100)
    local out = ""
    if g > 0 then out = g .. "|cffffd700g|r" end
    if s > 0 then out = out .. (out ~= "" and " " or "") .. s .. "|cffc7c7cfs|r" end
    if k > 0 then out = out .. (out ~= "" and " " or "") .. k .. "|cffeda55fc|r" end
    return out
  end
  -- "1g 20s 5c" / "1.5g" / "1.5" (gold) -> copper; 0 when empty
  function M.ParseMoney(text)
    if type(text) ~= "string" then return 0 end
    text = string.gsub(string.lower(text), ",", ".")
    local total, any = 0, false
    for n, unit in string.gfind(text, "([%d%.]+)%s*([gsc])") do
      local v = tonumber(n)
      if v then any = true total = total + v * ((unit == "g" and 10000) or (unit == "s" and 100) or 1) end
    end
    if not any then total = (tonumber((string.gsub(text, "%s", ""))) or 0) * 10000 end
    return math.floor(total + .5)
  end
  function M.FreeSlots()
    local free = 0
    for bag = 0, 4 do
      local n = GetContainerNumSlots(bag) or 0
      for slot = 1, n do
        if not GetContainerItemLink(bag, slot) then free = free + 1 end
      end
    end
    return free
  end
  local function Store()
    pfUI_cache = pfUI_cache or {}
    pfUI_cache.mail = pfUI_cache.mail or {}
    local key = (GetRealmName and GetRealmName() or "?") .. "-" .. (UnitFactionGroup("player") or "?")
    pfUI_cache.mail[key] = pfUI_cache.mail[key] or { names = {} }
    return pfUI_cache.mail[key]
  end
  M.Store = Store
  function M.AddName(name)
    if type(name) ~= "string" or name == "" or string.find(name, " ") then return end
    local st = Store()
    st.names[name] = time and time() or 0
    -- how often: people you mail a lot come first
    st.count = st.count or {}
    st.count[name] = (st.count[name] or 0) + 1
  end
  -- this character is one of your alts on this realm and side (noted at every login, not only at a mailbox)
  function M.NoteAlt()
    local me = UnitName("player")
    if not me or me == "" or me == UNKNOWNOBJECT then return end
    local st = Store()
    st.alts = st.alts or {}
    local _, cls = UnitClass("player")
    st.alts[me] = cls or true
  end
  -- (16 Nov 2026, user: "the search in the mail is smart by name ... guildies / friend list / people online ... a
  -- drop down ... fast") Everyone you might mail, gathered once (M.People, refreshed every 20 s and when the
  -- mailbox opens): people you mailed, your group, friends, guild (online ones marked), your other characters,
  -- and everyone pfUI has seen (pfUI_playerDB: nameplates, chat, /who). Typing only filters that list.
  -- (16 Nov 2026, user: "show all our alts prio and ones we have mailed before, be highly smart") alts first, then
  -- people you mailed (most often / most lately), people who mailed you, group, friends, guild, seen
  local TAGS = { alt = 1, recent = 2, wrote = 3, group = 4, friend = 5, guild = 6, seen = 7 }
  M.TAGLABEL = { alt = "your alt", recent = "mailed", wrote = "mailed you", group = "group", friend = "friend",
                 guild = "guild", seen = "seen" }
  local function ClassKey(c)
    if not c or c == "" then return nil end
    c = string.upper(c)
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[c] then return c end
  end
  function M.People(force)
    local now = GetTime()
    if not force and M.people and now - (M.peopleAt or 0) < 20 then return M.people end
    local me = UnitName("player")
    local list, by = {}, {}
    local function add(n, tag, class, online, t)
      if type(n) ~= "string" or n == "" or n == me or string.find(n, " ") then return end
      local e = by[n]
      if not e then
        e = { name = n, low = string.lower(n), tag = tag }
        by[n] = e
        table.insert(list, e)
      elseif TAGS[tag] < TAGS[e.tag] then
        e.tag = tag
      end
      e.class = e.class or ClassKey(class)
      if online then e.online = true end
      if t then e.t = t end
    end
    local st0 = Store()
    for n, cls in pairs(st0.alts or {}) do add(n, "alt", type(cls) == "string" and cls or nil) end
    for n, t in pairs(st0.names) do
      add(n, "recent", nil, nil, t)
      if by[n] then by[n].mails = (st0.count and st0.count[n]) or 1 end
    end
    -- players whose mail is in the inbox now
    for i = 1, (GetInboxNumItems and GetInboxNumItems() or 0) do
      local h = M.Header(i)
      if h and h.kind == "player" then add(h.sender, "wrote") end
    end
    for i = 1, GetNumRaidMembers() do
      local n, _, _, _, _, cls, _, online = GetRaidRosterInfo(i)
      add(n, "group", cls, online)
    end
    for i = 1, GetNumPartyMembers() do
      local _, cls = UnitClass("party" .. i)
      add(UnitName("party" .. i), "group", cls, UnitIsConnected("party" .. i))
    end
    if GetNumFriends then
      for i = 1, GetNumFriends() do
        local n, _, cls, _, online = GetFriendInfo(i)
        add(n, "friend", cls, online)
      end
    end
    if GetNumGuildMembers and IsInGuild and IsInGuild() then
      for i = 1, GetNumGuildMembers(true) do
        local n, _, _, _, cls, _, _, _, online = GetGuildRosterInfo(i)
        add(n, "guild", cls, online)
      end
    end
    local db = rawget(_G, "pfUI_playerDB")
    if type(db) == "table" then
      for n, d in pairs(db) do add(n, "seen", type(d) == "table" and d.class or nil) end
    end
    M.people, M.peopleAt = list, now
    return list
  end
  -- what was typed: names that START with it first, then names that hold it; online and closer people first
  -- Nothing typed yet: your alts and the people you mail (shown as soon as the To box is clicked).
  -- Typed: names that start with it, then names that hold it. Within those: alts, then people you mailed
  -- (often and lately), people who mailed you, then group, friends, guild - online ones ahead - and the rest.
  local function Score(e)
    local s = (8 - (TAGS[e.tag] or 7)) * 1000
    if e.tag == "recent" then
      local days = math.max(0, ((time and time() or 0) - (e.t or 0)) / 86400)
      s = s + math.min(400, (e.mails or 1) * 40) + math.max(0, 300 - days * 10)
    end
    if e.online then s = s + 500 end
    return s
  end
  function M.Names(typed, max)
    local out = {}
    typed = string.lower(typed or "")
    local hits = {}
    for _, e in ipairs(M.People()) do
      if typed == "" then
        if e.tag == "alt" or e.tag == "recent" then table.insert(hits, { e = e, starts = true, s = Score(e) }) end
      else
        local at = string.find(e.low, typed, 1, true)
        if at then table.insert(hits, { e = e, starts = at == 1, s = Score(e) }) end
      end
    end
    table.sort(hits, function(a, b)
      if a.starts ~= b.starts then return a.starts end
      if a.s ~= b.s then return a.s > b.s end
      return a.e.low < b.e.low
    end)
    for k = 1, math.min(max or 10, table.getn(hits)) do table.insert(out, hits[k].e) end
    return out
  end

  -- one mail as a table; kind: "ah" (auction house), "system" (no reply: battlemasters, GMs...), "player"
  function M.Header(i)
    local pack, stat, sender, subject, money, cod, days, hasItem, read, returned, textMade, canReply, gm = GetInboxHeaderInfo(i)
    if not sender and not subject then return nil end
    local m = { i = i, icon = pack or stat, sender = sender or "?", subject = subject or "", money = money or 0, cod = cod or 0,
      days = days or 0, item = hasItem, read = read, returned = returned, reply = canReply, gm = gm }
    if INBOX_AUCTIONHOUSES and sender and INBOX_AUCTIONHOUSES[sender] then m.kind = "ah"
    elseif canReply and not gm then m.kind = "player"
    else m.kind = "system" end
    if hasItem then
      local name, tex, count = GetInboxItem(i)
      m.itemName, m.itemTex, m.count = name, tex, count
    end
    -- what this mail is, apart from where it is in the list
    m.sig = m.sender .. "^" .. m.subject .. "^" .. math.floor(m.days * 1440) .. "^" .. (m.itemName or "")
    return m
  end
  function M.List()
    local out = {}
    for i = 1, (GetInboxNumItems() or 0) do
      local m = M.Header(i)
      if m then table.insert(out, m) end
    end
    return out
  end
  -- how the mail at i looks now: a change means the game answered
  local function State(i)
    local m = M.Header(i)
    return (GetInboxNumItems() or 0) .. "|" .. (m and (m.sig .. m.money .. tostring(m.item) .. (m.count or 0)) or "-")
  end
  local function Wanted(m, kind)
    if m.cod > 0 or m.gm then return false end
    if kind == "gold" then return m.money > 0 end
    if kind == "ah" then return m.kind == "ah" end
    if kind == "system" then return m.kind ~= "player" end
    return true
  end
  -- an emptied letter goes, unless a player wrote something in it (and Keep letters is on)
  local function Deletable(m)
    if S().delete == "0" or m.money > 0 or m.item or m.cod > 0 then return false end
    if InboxItemCanDelete and not InboxItemCanDelete(m.i) then return false end
    if m.kind == "player" and S().keeptext ~= "0" then
      local body = GetInboxText(m.i)
      if body and string.gsub(body, "%s", "") ~= "" then return false end
    end
    return true
  end

  -- ---------------------------------------------------------------- collect

  function M.Collect(kind)
    if not M.open then return end
    M.job = { kind = kind or "all", gold = 0, items = 0, deleted = 0, skipped = 0, full = false, why = {} }
    M.skip = {}
    if M.onChange then M.onChange() end
  end
  local function Report(j)
    local parts = {}
    if j.gold > 0 then table.insert(parts, M.Money(j.gold)) end
    if j.items > 0 then table.insert(parts, j.items .. (j.items == 1 and " item" or " items")) end
    local s = table.getn(parts) > 0 and ("Collected " .. table.concat(parts, " and ")) or "Nothing to collect"
    if j.skipped > 0 then
      local why = {}
      for w, n in pairs(j.why) do table.insert(why, n .. " " .. w) end
      s = s .. ", left " .. j.skipped .. " (" .. table.concat(why, ", ") .. ")"
    end
    return s .. "."
  end
  function M.Stop(note)
    local j = M.job
    M.job, M.pending = nil, nil
    if j and S().report ~= "0" then
      local text = note or Report(j)
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r mail: " .. text)
      if M.onNote then M.onNote(text) end
    end
    if M.onChange then M.onChange() end
  end
  local function Skip(m, why)
    if not m or M.skip[m.sig] then return end
    M.skip[m.sig] = why
    if M.job then
      M.job.skipped = M.job.skipped + 1
      M.job.why[why] = (M.job.why[why] or 0) + 1
    end
  end
  M.SkipMail = Skip
  -- one step: the top-most wanted mail gets its gold, then its item, then (empty) is deleted
  function M.Step()
    local j = M.job
    if not j or not M.open then return end
    local now = GetTime()
    local p = M.pending
    if p then
      if State(p.i) ~= p.state then
        if p.what == "money" then j.gold = j.gold + p.amount
        elseif p.what == "item" then j.items = j.items + (p.count or 1)
        elseif p.what == "delete" then j.deleted = j.deleted + 1 end
        M.pending = nil
        M.waitUntil = now + .1
      elseif now > p.limit then
        -- (the game never answered: put it aside, the rest still goes)
        Skip(p.mail, p.what == "item" and "it would not come out" or "no answer")
        M.pending = nil
      end
      return
    end
    if M.waitUntil and now < M.waitUntil then return end
    local n = GetInboxNumItems() or 0
    for i = 1, n do
      local m = M.Header(i)
      if m and not M.skip[m.sig] then
        if m.cod > 0 then Skip(m, "cash on delivery")
        elseif m.gm then Skip(m, "from a GM")
        elseif Wanted(m, j.kind) then
          local what, amount
          if m.money > 0 then
            GetInboxText(i)
            TakeInboxMoney(i)
            what, amount = "money", m.money
          elseif m.item and j.kind ~= "gold" then
            if j.full or M.FreeSlots() <= (tonumber(S().reserve) or 0) then
              j.full = true
              Skip(m, "bags full")
            else
              GetInboxText(i)
              TakeInboxItem(i)
              what = "item"
            end
          elseif not m.item and Deletable(m) then
            DeleteInboxItem(i)
            what = "delete"
          else
            M.skip[m.sig] = "kept"
          end
          if what then
            M.pending = { i = i, mail = m, what = what, amount = amount, count = m.count,
              state = State(i), limit = now + (tonumber(S().wait) or 2.5) }
            return
          end
        end
      end
    end
    M.Stop()
  end

  -- one mail, all of it (right-click a row, or the letter's Take button)
  function M.TakeOne(i)
    local m = M.Header(i)
    if not m then return end
    if m.cod > 0 then
      if M.onNote then M.onNote("Cash on delivery: open the letter and pay with Take, or send it back.") end
      return
    end
    M.job = { kind = "one", sig = m.sig, gold = 0, items = 0, deleted = 0, skipped = 0, why = {} }
    M.skip = {}
    for k = 1, (GetInboxNumItems() or 0) do
      local o = M.Header(k)
      if o and o.sig ~= m.sig then M.skip[o.sig] = "other" end
    end
  end

  -- ---------------------------------------------------------------- send

  -- items = { { bag = , slot = , link = } }; one mail each, the money (or cash on delivery) on the first
  function M.Send(to, subject, body, money, cod, items, codEach)
    if not M.open or M.sending then return end
    to = string.gsub(to or "", "^%s*(.-)%s*$", "%1")
    if to == "" then if M.onNote then M.onNote("Who to? Type a name.") end return end
    items = items or {}
    local n = table.getn(items)
    if (subject or "") == "" then
      subject = n > 0 and (GetContainerItemLink(items[1].bag, items[1].slot) and
        string.gsub(GetContainerItemLink(items[1].bag, items[1].slot), "^.-%[(.-)%].*$", "%1") or "Items") or "Hi"
    end
    local queue = {}
    if n == 0 then
      table.insert(queue, { subject = subject, body = body, money = money, cod = cod })
    else
      for k, it in ipairs(items) do
        it.sent = nil
        -- (the name GetSendMailItem() must report once this one is on the mail)
        it.name = it.link and string.gsub(it.link, "^.-%[(.-)%].*$", "%1") or nil
        table.insert(queue, { item = it, subject = n > 1 and (subject .. " (" .. k .. "/" .. n .. ")") or subject,
          body = k == 1 and body or "", money = k == 1 and money or 0, cod = (k == 1 or codEach) and cod or 0 })
      end
    end
    -- (anything left on the game's send mail from before goes back first)
    if ClearSendMail then ClearSendMail() end
    M.sending = { to = to, queue = queue, items = items, k = 1, sent = 0, skipped = 0 }
    if M.onChange then M.onChange() end
  end
  function M.StopSend(note)
    local s = M.sending
    M.sending = nil
    if ClearSendMail then ClearSendMail() end
    ClearCursor()
    -- (stopped part-way: the items that went come off the list, the rest stay to send again)
    if s and s.items then
      for k = table.getn(s.items), 1, -1 do
        if s.items[k].sent then table.remove(s.items, k) end
      end
    end
    if s and note then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r mail: " .. note)
      if M.onNote then M.onNote(note) end
    end
    if M.onChange then M.onChange() end
  end
  function M.SendStep()
    local s = M.sending
    if not s or not M.open then return end
    local now = GetTime()
    if s.waiting then
      if now > s.waiting then M.StopSend("No answer from the mailbox; stopped after " .. s.sent .. " mails.") end
      return
    end
    if s.pause and now < s.pause then return end
    local total = table.getn(s.queue)
    -- (17 Nov 2026, user: 16 items queued, Send, only the first went) After a mail goes, the client can still
    -- show its item on the send mail for a moment. This used to read "something is attached" as "the next item
    -- is attached" and sent mail 2 at once with the old item, which the server refused, and the run stopped.
    -- Now: wait for the sent item to leave the bag and the send mail, take off whatever is still there (as
    -- TurtleMail does), and send only once GetSendMailItem() names the item this mail is for.
    local last = s.last
    if last then
      if GetContainerItemLink(last.bag, last.slot) ~= last.link and not GetSendMailItem() then
        s.last = nil
      elseif now - s.settleAt > 3 then
        if GetSendMailItem() then
          ClearCursor()
          ClickSendMailItemButton()
          ClearCursor()
        end
        s.last = nil
        s.pause = now + .2
        return
      else
        s.pause = now + .1
        return
      end
    end
    local q = s.queue[s.k]
    if not q then
      M.AddName(s.to)
      local note = "Sent " .. s.sent .. (s.sent == 1 and " mail" or " mails") .. " to " .. s.to .. "."
      if s.skipped > 0 then
        note = note .. " " .. s.skipped .. (s.skipped == 1 and " item was" or " items were") .. " no longer in that bag slot."
      end
      M.StopSend(note)
      if M.onSent then M.onSent() end
      return
    end
    if q.item and s.ready ~= s.k then
      local it = q.item
      local onMail = GetSendMailItem()
      if s.tried == s.k then
        -- (16 Nov 2026, Lobo on Discord: "it just stays there doing nothing") an attached item is locked in its
        -- bag: once ours is on the mail, the lock does not matter, so this asks the mail, not the bag
        if onMail and (not it.name or onMail == it.name) then
          s.ready = s.k
        elseif now - s.attachAt > 4 then
          ClearCursor()
          M.StopSend("The item would not go on mail " .. s.k .. " of " .. total .. "; stopped after " .. s.sent .. " sent.")
          return
        else
          s.pause = now + .1
          return
        end
      else
        if onMail then
          -- (not ours: back into the bag first)
          s.clearAt = s.clearAt or now
          if now - s.clearAt > 3 then
            M.StopSend("Something else stays on the mail; stopped after " .. s.sent .. " of " .. total .. " sent.")
            return
          end
          ClearCursor()
          ClickSendMailItemButton()
          ClearCursor()
          s.pause = now + .2
          return
        end
        s.clearAt = nil
        if GetContainerItemLink(it.bag, it.slot) ~= it.link then
          -- (moved or gone since it was picked: skip it, not a wrong item; the end message counts it)
          s.k, s.lockAt, s.skipped = s.k + 1, nil, s.skipped + 1
          return
        end
        local _, _, locked = GetContainerItemInfo(it.bag, it.slot)
        if locked then
          s.lockAt = s.lockAt or now
          if now - s.lockAt > 4 then
            M.StopSend("That item stays locked in your bag; stopped after " .. s.sent .. " of " .. total .. " sent.")
            return
          end
          s.pause = now + .1
          return
        end
        s.lockAt = nil
        ClearCursor()
        PickupContainerItem(it.bag, it.slot)
        ClickSendMailItemButton()
        -- (the client refused it: it is back on the cursor; its UI error says why)
        if CursorHasItem and CursorHasItem() then ClearCursor() end
        s.tried, s.attachAt = s.k, now
        s.pause = now + .1
        return
      end
    end
    SetSendMailCOD(q.cod and q.cod > 0 and q.cod or 0)
    SetSendMailMoney(not (q.cod and q.cod > 0) and q.money or 0)
    if GetSendMailPrice and GetSendMailPrice() + ((not (q.cod and q.cod > 0)) and q.money or 0) > GetMoney() then
      M.StopSend("Not enough money for the postage.")
      return
    end
    s.waiting = now + 8
    SendMail(s.to, q.subject, q.body or "")
  end

  -- ---------------------------------------------------------------- events

  local ev = CreateFrame("Frame")
  M.ev = ev
  local function Tame()
    local f = rawget(_G, "MailFrame")
    -- (16 Nov 2026) only when our window really got built (M.onShow is set at its end): a window that failed
    -- to build must leave the game's mailbox working, not hide both
    if not f or f.pfOctoTamed or not M.Active() or not M.onShow then return end
    f.pfOctoTamed = true
    -- (its own opening goes; ours opens instead. MAIL_CLOSED still hides it if the player showed it.)
    f:UnregisterEvent("MAIL_SHOW")
  end
  M.Tame = Tame
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "MAIL_SEND_SUCCESS",
    "MAIL_SEND_INFO_UPDATE", "UI_ERROR_MESSAGE", "MAIL_FAILED" }) do ev:RegisterEvent(e) end
  ev:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
      Tame()
      M.NoteAlt()
      return
    end
    if not M.Active() then return end
    if event == "MAIL_SHOW" then
      Tame()
      M.open = true
      M.skip = {}
      if CheckInbox then CheckInbox() end
      -- fresh guild online marks and friends for the name list
      if GuildRoster and IsInGuild and IsInGuild() then GuildRoster() end
      if ShowFriends then ShowFriends() end
      M.people = nil
      if M.onShow then M.onShow() end
    elseif event == "MAIL_CLOSED" then
      M.open = false
      local s = M.sending
      if s then
        M.StopSend("Mailbox closed: sent " .. s.sent .. " of " .. table.getn(s.queue) .. (s.waiting and " (the last one may have gone too)." or "."))
      end
      M.job, M.pending, M.sending = nil, nil, nil
      if M.onHide then M.onHide() end
    elseif event == "MAIL_INBOX_UPDATE" then
      M.dirty = true
    elseif event == "MAIL_SEND_SUCCESS" then
      local s = M.sending
      if s and s.waiting then
        s.waiting = nil
        s.sent = s.sent + 1
        local q = s.queue[s.k]
        if q and q.item then
          q.item.sent = true
          -- (the next one waits until the game has let go of this item: SendStep)
          s.last, s.settleAt = q.item, GetTime()
        end
        s.k = s.k + 1
        s.pause = GetTime() + .3
      end
      M.dirty = true
    elseif event == "MAIL_FAILED" then
      if M.sending then M.StopSend("The mail did not go (" .. M.sending.sent .. " sent before it).") end
    elseif event == "UI_ERROR_MESSAGE" then
      local p = M.pending
      if p and (arg1 == ERR_INV_FULL or arg1 == ERR_ITEM_MAX_COUNT or arg1 == ERR_ITEM_LOCKED
        or (ERR_MAIL_DATABASE_ERROR and arg1 == ERR_MAIL_DATABASE_ERROR)) then
        -- (the marks case: "You can't carry any more of those" - that mail waits, the rest goes on)
        if arg1 == ERR_INV_FULL and M.job then M.job.full = true end
        Skip(p.mail, arg1 == ERR_ITEM_MAX_COUNT and "you hold the most of" or (arg1 == ERR_INV_FULL and "bags full" or "refused"))
        M.pending = nil
      elseif M.sending and M.sending.waiting and (arg1 == ERR_MAIL_TO_SELF or arg1 == ERR_PLAYER_WRONG_FACTION
        or arg1 == ERR_MAIL_TARGET_NOT_FOUND or arg1 == ERR_MAIL_REACHED_CAP or arg1 == ERR_NOT_ENOUGH_MONEY) then
        M.StopSend(arg1 .. " (sent " .. M.sending.sent .. " of " .. table.getn(M.sending.queue) .. ")")
      end
    end
  end)
  ev:SetScript("OnUpdate", function()
    if not M.open then return end
    if M.job then M.Step() end
    if M.sending then M.SendStep() end
  end)
end)
