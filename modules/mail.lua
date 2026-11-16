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
  -- The walk runs from the bottom of the list up, so a deleted letter never moves the ones still to do.
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
    Store().names[name] = time and time() or 0
  end
  -- names starting with what was typed: recent first, then guild and friends
  function M.Names(prefix)
    local out, seen = {}, {}
    prefix = string.lower(prefix or "")
    if prefix == "" then return out end
    local function add(n)
      if n and not seen[n] and string.sub(string.lower(n), 1, string.len(prefix)) == prefix and n ~= UnitName("player") then
        seen[n] = true
        table.insert(out, n)
      end
    end
    local recent = {}
    for n, t in pairs(Store().names) do table.insert(recent, { n, t }) end
    table.sort(recent, function(a, b) return a[2] > b[2] end)
    for _, r in ipairs(recent) do add(r[1]) end
    if GetNumGuildMembers then
      for i = 1, GetNumGuildMembers(true) do add((GetGuildRosterInfo(i))) end
    end
    if GetNumFriends then
      for i = 1, GetNumFriends() do add((GetFriendInfo(i))) end
    end
    while table.getn(out) > 8 do table.remove(out) end
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
  local function Report()
    local j = M.job
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
      local text = note or Report()
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
  -- one step: the bottom-most wanted mail gets its gold, then its item, then (empty) is deleted
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
    for i = n, 1, -1 do
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
        table.insert(queue, { item = it, subject = n > 1 and (subject .. " (" .. k .. "/" .. n .. ")") or subject,
          body = k == 1 and body or "", money = k == 1 and money or 0, cod = (k == 1 or codEach) and cod or 0 })
      end
    end
    M.sending = { to = to, queue = queue, k = 1, sent = 0 }
    if M.onChange then M.onChange() end
  end
  function M.StopSend(note)
    local s = M.sending
    M.sending = nil
    if ClearSendMail then ClearSendMail() end
    ClearCursor()
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
    local q = s.queue[s.k]
    if not q then
      M.AddName(s.to)
      M.StopSend("Sent " .. s.sent .. (s.sent == 1 and " mail" or " mails") .. " to " .. s.to .. ".")
      if M.onSent then M.onSent() end
      return
    end
    if q.item then
      local it = q.item
      local _, _, locked = GetContainerItemInfo(it.bag, it.slot)
      if locked then s.pause = now + .1 return end
      if GetContainerItemLink(it.bag, it.slot) ~= it.link then
        -- (moved or gone since it was picked: skip it, not a wrong item)
        s.k = s.k + 1
        return
      end
      if not GetSendMailItem() then
        ClearCursor()
        PickupContainerItem(it.bag, it.slot)
        ClickSendMailItemButton()
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
    SendMail(s.to, q.subject, q.body or "")
    s.waiting = now + 8
  end

  -- ---------------------------------------------------------------- events

  local ev = CreateFrame("Frame")
  M.ev = ev
  local function Tame()
    local f = rawget(_G, "MailFrame")
    if not f or f.pfOctoTamed or not M.Active() then return end
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
      return
    end
    if not M.Active() then return end
    if event == "MAIL_SHOW" then
      Tame()
      M.open = true
      M.skip = {}
      if CheckInbox then CheckInbox() end
      if M.onShow then M.onShow() end
    elseif event == "MAIL_CLOSED" then
      M.open = false
      M.job, M.pending, M.sending = nil, nil, nil
      if M.onHide then M.onHide() end
    elseif event == "MAIL_INBOX_UPDATE" then
      M.dirty = true
    elseif event == "MAIL_SEND_SUCCESS" then
      local s = M.sending
      if s and s.waiting then
        s.waiting = nil
        s.sent = s.sent + 1
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
        M.StopSend(arg1)
      end
    end
  end)
  ev:SetScript("OnUpdate", function()
    if not M.open then return end
    if M.job then M.Step() end
    if M.sending then M.SendStep() end
  end)
end)
