pfUI:RegisterModule("auction-ledger", "vanilla", function ()
  -- pfUI Octo :: auction house, phase 3 (16 Nov 2026; Bread on Discord: "Will it have a ledger for
  -- real-time sales", with a link to Midas; user: "build the best AH addon ever"). Midas (Rebo) is
  -- MIT; it targets the Classic Era client, so this is written for 1.12 from its feature list:
  --   ledger   every sale, purchase, expiry and outbid, the moment the game says so (system line),
  --            priced from what you had up; the auction house's mail then gives the exact gold
  --   alerts   a sale pops up with a coin sound wherever you are
  --   deals    AH.DealFilter: auctions well under the item's usual price, ranked by profit
  --   worth    gold + what your bags would fetch + what you have up
  --   sharing  the day's lows you scan go to guild and group (prefix pfAP), theirs come to you
  local AH = pfUI.auction
  if not AH then return end
  local L = { out = {}, outN = 0 }
  AH.ledger = L
  local function S() return C.auction end
  local CUT = .05
  L.KINDS = { sold = "Sold", bought = "Bought", won = "Won", expired = "Expired", cancelled = "Cancelled", outbid = "Outbid", posted = "Posted" }

  local function St()
    local st = AH.Store()
    st.ledger = st.ledger or {}
    st.mine = st.mine or {}
    st.bids = st.bids or {}
    st.mail = st.mail or {}
    return st
  end
  -- amount: copper, + came in, - went out; est = a figure worked out, not yet confirmed by the mail
  function L.Add(kind, name, count, amount, est, who)
    local st = St()
    local e = { t = time and time() or 0, k = kind, n = name, c = count, a = amount or 0, est = est and 1 or nil, who = who }
    table.insert(st.ledger, e)
    while table.getn(st.ledger) > 1500 do table.remove(st.ledger, 1) end
    if AH.onChange then AH.onChange("ledger") end
    return e
  end
  function L.Entries() return St().ledger end
  -- { sold, spent, net, sales, buys } over the last `seconds` (nil = everything)
  function L.Sum(seconds)
    local out = { sold = 0, spent = 0, net = 0, sales = 0, buys = 0 }
    local from = seconds and ((time and time() or 0) - seconds) or 0
    for _, e in ipairs(St().ledger) do
      if e.t >= from then
        if e.k == "sold" then out.sold, out.sales = out.sold + e.a, out.sales + 1
        elseif e.k == "bought" or e.k == "won" then out.spent, out.buys = out.spent - e.a, out.buys + 1 end
        out.net = out.net + e.a
      end
    end
    return out
  end

  -- ---------------------------------------------------------------- what you have up (to price a sale)

  function L.Snapshot()
    local mine = {}
    for _, r in ipairs(AH.Owned()) do
      mine[r.name] = mine[r.name] or {}
      table.insert(mine[r.name], { c = r.count, bid = r.minBid, buy = r.buyout, high = r.bid })
    end
    St().mine = mine
    return mine
  end
  -- one of your auctions of that name leaves the list: the cheapest first (it sells first)
  local function TakeMine(name)
    local list = St().mine[name]
    if not list or table.getn(list) == 0 then return nil end
    local best = 1
    for i, a in ipairs(list) do
      local pa, pb = (a.buy > 0 and a.buy or a.bid) / a.c, (list[best].buy > 0 and list[best].buy or list[best].bid) / list[best].c
      if pa < pb then best = i end
    end
    local a = table.remove(list, best)
    if table.getn(list) == 0 then St().mine[name] = nil end
    return a
  end

  -- ---------------------------------------------------------------- the game's own lines

  local function Pat(global, fallback)
    local text = rawget(_G, global)
    if type(text) ~= "string" or not string.find(text, "%%s") then text = fallback end
    text = string.gsub(text, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    return "^" .. string.gsub(text, "%%s", "(.+)") .. "$"
  end
  L.LINES = {
    { "sold", Pat("ERR_AUCTION_SOLD_S", "A buyer has been found for your auction of %s.") },
    { "won", Pat("ERR_AUCTION_WON_S", "You won an auction for %s") },
    { "expired", Pat("ERR_AUCTION_EXPIRED_S", "Your auction of %s has expired.") },
    { "outbid", Pat("ERR_AUCTION_OUTBID_S", "You have been outbid on %s.") },
    { "cancelled", Pat("ERR_AUCTION_REMOVED_S", "Your auction of %s has been cancelled by the seller.") },
  }
  function L.Toast(text, sound)
    if S().salealert == "0" then return end
    if UIErrorsFrame then UIErrorsFrame:AddMessage(text, 1, .82, .1, 1, 5) end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r auctions: " .. text)
    if sound and S().salesound ~= "0" and PlaySound then PlaySound("LOOTWINDOWCOINSOUND") end
  end
  -- a system line: returns the kind it was, or nil
  function L.System(msg)
    if type(msg) ~= "string" then return nil end
    for _, l in ipairs(L.LINES) do
      local _, _, name = string.find(msg, l[2])
      if name then
        local kind = l[1]
        if kind == "sold" then
          local a = TakeMine(name)
          local gross = a and ((a.high and a.high > 0 and a.buy == 0) and a.high or (a.buy > 0 and a.buy or a.bid)) or 0
          local net = math.floor(gross * (1 - CUT))
          L.Add("sold", name, a and a.c or 1, net, true)
          L.Toast("Sold: " .. name .. (a and a.c > 1 and (" x" .. a.c) or "") .. (net > 0 and ("  for about " .. AH.Money(net)) or ""), true)
        elseif kind == "won" then
          local cost = St().bids[name]
          St().bids[name] = nil
          L.Add("won", name, 1, cost and -cost or 0, true)
          L.Toast("Won: " .. name .. (cost and ("  for " .. AH.Money(cost)) or ""), true)
        elseif kind == "expired" then
          local a = TakeMine(name)
          L.Add("expired", name, a and a.c or 1, 0)
        elseif kind == "cancelled" then
          local a = TakeMine(name)
          L.Add("cancelled", name, a and a.c or 1, 0)
        elseif kind == "outbid" then
          L.Add("outbid", name, 1, 0)
          L.Toast("Outbid on " .. name)
        end
        return kind
      end
    end
  end
  AH.onPosted = function(j)
    local dep = AH.Deposit(j.key, j.size, j.minutes / 60)
    L.Add("posted", j.name, j.size, dep and -dep or 0, true)
    local st = St()
    st.mine[j.name] = st.mine[j.name] or {}
    table.insert(st.mine[j.name], { c = j.size, bid = j.bid, buy = j.buyout, high = 0 })
  end
  AH.onBought = function(row, how, cost)
    if how == "buyout" then
      L.Add("bought", row.name, row.count, -cost)
    else
      St().bids[row.name] = cost
    end
  end

  -- ---------------------------------------------------------------- the auction house's mail: exact gold

  -- an invoice not seen before (the same mail is read many times while it lies in the inbox)
  local function NewMail(kind, name, bid, expiry)
    local st = St()
    local now = time and time() or 0
    for i = table.getn(st.mail), 1, -1 do
      local m = st.mail[i]
      if m.x < now - 86400 then table.remove(st.mail, i)
      elseif m.k == kind and m.n == name and m.b == bid and math.abs(m.x - expiry) < 300 then return false end
    end
    table.insert(st.mail, { k = kind, n = name, b = bid, x = expiry })
    return true
  end
  function L.ReadMail()
    if not (GetInboxNumItems and GetInboxInvoiceInfo and GetInboxHeaderInfo) then return 0 end
    local fresh = 0
    local now = time and time() or 0
    for i = 1, (GetInboxNumItems() or 0) do
      local kind, name, player, bid, buyout, deposit, cut = GetInboxInvoiceInfo(i)
      if kind and name then
        bid, deposit, cut = tonumber(bid) or 0, tonumber(deposit) or 0, tonumber(cut) or 0
        local _, _, _, _, _, _, daysLeft = GetInboxHeaderInfo(i)
        local expiry = now + (tonumber(daysLeft) or 0) * 86400
        if NewMail(kind, name, bid, expiry) then
          fresh = fresh + 1
          local list = St().ledger
          local want = (kind == "seller") and { sold = true } or { won = true, bought = true }
          local amount = (kind == "seller") and (bid + deposit - cut) or -bid
          local hit
          for n = table.getn(list), 1, -1 do
            local e = list[n]
            if want[e.k] and e.n == name and (e.est or e.a == amount) and now - e.t < 4 * 86400 then hit = e break end
          end
          if hit then
            hit.a, hit.est, hit.who = amount, nil, player or hit.who
          else
            L.Add(kind == "seller" and "sold" or "bought", name, 1, amount, nil, player)
          end
        end
      end
    end
    if fresh > 0 and AH.onChange then AH.onChange("ledger") end
    return fresh
  end

  -- ---------------------------------------------------------------- deals

  -- a search filter: buyouts under `pct` % of the item's usual price (known for `days` days or more),
  -- that would clear `profit` copper a stack after the auction house's cut
  function L.DealFilter(pct, profit, days)
    pct, profit, days = (pct or 70) / 100, profit or 0, days or 3
    return function(row)
      if not row.unit then return false end
      local value, n = AH.Value(row.key)
      if not value or n < days or row.unit > value * pct then return false end
      row.value = value
      row.profit = math.floor((value * (1 - CUT) - row.unit) * row.count)
      row.share = row.unit / value
      return row.profit >= profit
    end
  end
  function L.FindDeals(pct, profit, days, onPage, onDone)
    return AH.Search({ filter = L.DealFilter(pct, profit, days) }, onPage, onDone)
  end

  -- ---------------------------------------------------------------- what you are worth

  function L.Worth()
    local out = { gold = GetMoney and GetMoney() or 0, bags = 0, up = 0, items = 0 }
    local list = AH.Bags()
    for _, e in ipairs(list) do
      local v = AH.Value(e.key) or AH.Vendor(e.key)
      if v then out.bags, out.items = out.bags + v * e.total, out.items + 1 end
    end
    for _, auctions in pairs(St().mine) do
      for _, a in ipairs(auctions) do out.up = out.up + ((a.buy > 0 and a.buy or a.bid) * (1 - CUT)) end
    end
    out.bags, out.up = math.floor(out.bags), math.floor(out.up)
    out.total = out.gold + out.bags + out.up
    return out
  end
  -- "[Linen Cloth]: usual 1s 5c each (6 days), cheapest now 98c" for the chat box
  function L.PriceLine(link, key, name)
    local value, days = AH.Value(key)
    if not value then return (link or name or "?") .. ": no price known yet" end
    local low = AH.LowestOther(key)
    return (link or name or "?") .. ": usual " .. AH.Money(value, true) .. " each (" .. days .. (days == 1 and " day" or " days") .. ")"
      .. (low and (", cheapest now " .. AH.Money(low, true)) or "")
  end

  -- ---------------------------------------------------------------- prices shared (pfAP)

  local PREFIX = "pfAP"
  local function Where() return (GetRealmName and GetRealmName() or "?") .. "-" .. (UnitFactionGroup and UnitFactionGroup("player") or "?") end
  local record = AH.Record
  AH.Record = function(key, unit)
    local st = AH.Store().h[key]
    local before = st and st.day == AH.Day() and st.min or nil
    record(key, unit)
    -- (a new low for today from your own scan goes out; what came in from others does not go round again)
    if not L.receiving and S().share ~= "0" and key and unit and unit > 0 and (not before or unit < before) then
      if not L.out[key] then L.outN = L.outN + 1 end
      L.out[key] = math.floor(unit + .5)
    end
  end
  function L.Channels()
    local list = {}
    if IsInGuild and IsInGuild() then table.insert(list, "GUILD") end
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then table.insert(list, "RAID")
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then table.insert(list, "PARTY") end
    return list
  end
  -- one message of the waiting prices: "Realm-Faction|day|key=copper,key=copper"
  function L.Pack()
    if L.outN <= 0 then return nil end
    local msg = Where() .. "|" .. AH.Day() .. "|"
    local head = string.len(msg)
    for key, unit in pairs(L.out) do
      local piece = key .. "=" .. unit
      if string.len(msg) + string.len(piece) + 1 > 240 then break end
      msg = msg .. (string.len(msg) > head and "," or "") .. piece
      L.out[key] = nil
      L.outN = L.outN - 1
    end
    return msg
  end
  function L.Receive(msg, from)
    if S().share == "0" or type(msg) ~= "string" or from == UnitName("player") then return 0 end
    local _, _, where, day, body = string.find(msg, "^(.-)|(%d+)|(.*)$")
    if where ~= Where() or tonumber(day) ~= AH.Day() then return 0 end
    local n = 0
    L.receiving = true
    for key, unit in string.gfind(body, "([%d:]+)=(%d+)") do
      unit = tonumber(unit)
      if unit and unit > 0 and unit < 2000000000 and string.len(key) < 24 then
        record(key, unit)
        n = n + 1
      end
    end
    L.receiving = nil
    L.got = (L.got or 0) + n
    return n
  end

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "CHAT_MSG_SYSTEM", "CHAT_MSG_ADDON", "MAIL_INBOX_UPDATE", "MAIL_SHOW", "AUCTION_OWNED_LIST_UPDATE" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function()
    if event == "CHAT_MSG_SYSTEM" then L.System(arg1)
    elseif event == "CHAT_MSG_ADDON" then if arg1 == PREFIX then L.Receive(arg2, arg4) end
    elseif event == "AUCTION_OWNED_LIST_UPDATE" then if AH.open then L.Snapshot() end
    else this.mailAt = GetTime() + .5 end
  end)
  ev:SetScript("OnUpdate", function()
    local now = GetTime()
    if this.mailAt and now >= this.mailAt then
      this.mailAt = nil
      pcall(L.ReadMail)
    end
    if L.outN > 0 and (this.sendAt or 0) <= now and not AH.Searching() and type(SendAddonMessage) == "function" then
      this.sendAt = now + 1.5
      local chans = L.Channels()
      if table.getn(chans) == 0 then
        L.out, L.outN = {}, 0
      else
        local msg = L.Pack()
        if msg then for _, c in ipairs(chans) do SendAddonMessage(PREFIX, msg, c) end end
      end
    end
  end)
end)
