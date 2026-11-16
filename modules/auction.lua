pfUI:RegisterModule("auction", "vanilla", function ()
  -- pfUI Octo :: auction house (15 Nov 2026; user, with aux and AuctionQueryThrottle: "merge them
  -- both together make it into our style ... make this AH the best ever"). aux (shirsig) has no
  -- licence, so nothing of it is copied: the user chose "write our own", with aux's feature list
  -- as the model. This file is the engine; auction-window.lua draws it, auction-options.lua is
  -- the Auctions section. AuctionQueryThrottle is a DLL (brues-code, GPL-3): it only lifts the
  -- client's 5 s wait between searches, so nothing here depends on it - searches go out the moment
  -- CanSendAuctionQuery() says yes, which with the DLL is as soon as the server has answered.
  --
  --   search   AH.Search(q, onPage, onDone): every page of a query, rows kept in AH.rows
  --            q = { name, minLevel, maxLevel, class, subclass, slot, quality, usable, exact,
  --                  maxUnit (copper each), first (one page only) }
  --   history  pfUI_cache.auction["Realm-Faction"].h[item] = { day, min, days = { older daily
  --            lows } }: the lowest buyout each seen per day; AH.Value = the middle of the last
  --            days (one cheap or silly auction does not move it)
  --   buy      AH.Buy(row, "bid" | "buyout"): the row is found again on its page by what it is
  --            (name, count, prices, owner), never by a remembered index
  --   post     AH.Post(key, size, stacks, bid, buyout, hours): a queue that splits / joins bag
  --            stacks to the asked size, one step a tick, waiting for item locks
  --   mine     AH.Owned() / AH.Bids() from the owner / bidder lists; AH.Cancel(row)
  local AH = { rows = {}, total = 0, bag = {} }
  pfUI.auction = AH
  local function S() return C.auction end
  local function Num(key, d) return tonumber(S()[key]) or d end
  AH.PAGE = 50
  AH.LEFT = { "under 30 min", "under 2 h", "under 8 h", "under 24 h" }
  AH.HOURS = { [2] = 120, [8] = 480, [24] = 1440 }

  -- ---------------------------------------------------------------- money

  -- 12345 -> "1g 23s 45c" (coloured)
  function AH.Money(c, plain)
    c = math.floor((tonumber(c) or 0) + .5)
    if c <= 0 then return plain and "0c" or "|cff8080800c|r" end
    local g, s, k = math.floor(c / 10000), math.floor(math.mod(c, 10000) / 100), math.mod(c, 100)
    local out = ""
    if g > 0 then out = g .. (plain and "g" or "|cffffd700g|r") end
    if s > 0 then out = out .. (out ~= "" and " " or "") .. s .. (plain and "s" or "|cffc7c7cfs|r") end
    if k > 0 and g < 100 then out = out .. (out ~= "" and " " or "") .. k .. (plain and "c" or "|cffeda55fc|r") end
    return out
  end
  -- "1g 20s 5c", "1.5g", "120s", "1.5" (gold) -> copper; nil when it reads as nothing
  function AH.ParseMoney(text)
    if type(text) ~= "string" then return nil end
    text = string.lower(string.gsub(text, "|c%x%x%x%x%x%x%x%x", ""))
    text = string.gsub(string.gsub(text, "|r", ""), ",", ".")
    local total, any = 0, false
    for n, unit in string.gfind(text, "([%d%.]+)%s*([gsc])") do
      local v = tonumber(n)
      if v then
        any = true
        total = total + v * ((unit == "g" and 10000) or (unit == "s" and 100) or 1)
      end
    end
    if not any then
      local v = tonumber((string.gsub(text, "%s", "")))
      if not v then return nil end
      total = v * 10000
    end
    return math.floor(total + .5)
  end

  -- ---------------------------------------------------------------- price history

  function AH.Store()
    pfUI_cache.auction = pfUI_cache.auction or {}
    local key = (GetRealmName and GetRealmName() or "?") .. "-" .. (UnitFactionGroup and UnitFactionGroup("player") or "?")
    pfUI_cache.auction[key] = pfUI_cache.auction[key] or { h = {} }
    return pfUI_cache.auction[key]
  end
  -- "item:1234:0:567:0" in a link -> "1234" or "1234:567" (random suffix)
  function AH.ItemKey(link)
    if type(link) ~= "string" then return nil end
    local _, _, id, suffix = string.find(link, "item:(%d+):%d*:(%d*)")
    if not id then return nil end
    if suffix and suffix ~= "" and suffix ~= "0" then return id .. ":" .. suffix end
    return id
  end
  function AH.Day() return math.floor((time and time() or 0) / 86400) end
  -- a buyout price each seen now
  function AH.Record(key, unit)
    if not key or not unit or unit <= 0 then return end
    local h = AH.Store().h
    local r = h[key]
    local day = AH.Day()
    if not r then
      h[key] = { day = day, min = unit, days = {} }
      return
    end
    if r.day ~= day then
      table.insert(r.days, r.min)
      while table.getn(r.days) > 10 do table.remove(r.days, 1) end
      r.day, r.min = day, unit
    elseif unit < r.min then
      r.min = unit
    end
  end
  -- the item's usual price each: the middle of the daily lows kept (today's included)
  function AH.Value(key)
    local r = key and AH.Store().h[key]
    if not r then return nil end
    local list = { r.min }
    for _, v in ipairs(r.days) do table.insert(list, v) end
    table.sort(list)
    local n = table.getn(list)
    if math.mod(n, 2) == 1 then return list[(n + 1) / 2], n end
    return math.floor((list[n / 2] + list[n / 2 + 1]) / 2 + .5), n
  end
  function AH.Known()
    local n = 0
    for _ in pairs(AH.Store().h) do n = n + 1 end
    return n
  end

  -- ---------------------------------------------------------------- reading a list

  -- one auction of the list "list" | "owner" | "bidder" as a row
  function AH.Read(kind, i, page)
    local name, tex, count, quality, usable, level, minBid, inc, buyout, bid, high, owner = GetAuctionItemInfo(kind, i)
    if not name then return nil end
    local link = GetAuctionItemLink and GetAuctionItemLink(kind, i)
    count = (count and count > 0) and count or 1
    local row = { kind = kind, name = name, tex = tex, count = count, quality = quality or 1, usable = usable, level = level or 0,
      minBid = minBid or 0, inc = inc or 0, buyout = buyout or 0, bid = bid or 0, high = high, owner = owner,
      link = link, key = AH.ItemKey(link), left = GetAuctionItemTimeLeft and GetAuctionItemTimeLeft(kind, i) or 0,
      page = page or 0, index = i }
    row.unit = row.buyout > 0 and (row.buyout / count) or nil
    -- what a bid costs now, in all and each
    row.next = (row.bid > 0) and (row.bid + row.inc) or row.minBid
    if row.buyout > 0 and row.next > row.buyout then row.next = row.buyout end
    row.bidunit = row.next / count
    return row
  end
  -- the same auction? (rows move as others sell: found by what it is)
  function AH.Same(a, b)
    return a and b and a.name == b.name and a.count == b.count and a.minBid == b.minBid and a.buyout == b.buyout
      and a.bid == b.bid and (a.owner == b.owner or not a.owner or not b.owner)
  end
  function AH.Find(row)
    local n = GetNumAuctionItems(row.kind)
    local at = AH.Read(row.kind, row.index, row.page)
    if AH.Same(row, at) then return row.index end
    for i = 1, (n or 0) do
      if AH.Same(row, AH.Read(row.kind, i, row.page)) then return i end
    end
  end

  -- ---------------------------------------------------------------- searching

  local function Fits(q, row)
    if q.exact and q.name and string.lower(row.name) ~= string.lower(q.name) then return false end
    if q.maxUnit and (not row.unit or row.unit > q.maxUnit) then return false end
    if q.filter and not q.filter(row) then return false end
    return true
  end
  -- Search text (phase 2, 15 Nov 2026): "name/word/word; another name/word". Words: exact, usable,
  -- uncommon | rare | epic (and better), 20-30 (levels), max 1g 20s (price each), or a kind of item
  -- (weapon, armor, trade goods... as the auction house names them). base = the window's own choices.
  local QUALITY = { uncommon = 2, green = 2, rare = 3, blue = 3, epic = 4, purple = 4 }
  local function Trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
  function AH.ParseQuery(text, base)
    local list = {}
    for part in string.gfind((text or "") .. ";", "(.-);") do
      part = Trim(part)
      if part ~= "" or table.getn(list) == 0 then
        local q = {}
        for k, v in pairs(base or {}) do q[k] = v end
        local first = true
        for word in string.gfind(part .. "/", "(.-)/") do
          word = Trim(word)
          local low = string.lower(word)
          if first then
            q.name = word
            first = false
          elseif low == "exact" then q.exact = true
          elseif low == "usable" then q.usable = true
          elseif QUALITY[low] then q.quality = QUALITY[low]
          elseif string.find(low, "^%d+%s*%-%s*%d+$") then
            local _, _, a, b = string.find(low, "^(%d+)%s*%-%s*(%d+)$")
            q.minLevel, q.maxLevel = tonumber(a), tonumber(b)
          elseif string.find(low, "^max%s") or string.find(low, "^[%d%.]+%s*[gsc]") then
            q.maxUnit = AH.ParseMoney((string.gsub(low, "^max%s*", ""))) or q.maxUnit
          elseif low ~= "" and GetAuctionItemClasses then
            for i, name in ipairs({ GetAuctionItemClasses() }) do
              if type(name) == "string" and string.find(string.lower(name), low, 1, true) == 1 then q.class = i break end
            end
          end
        end
        if q.exact and (not q.name or q.name == "") then q.exact = nil end
        table.insert(list, q)
      end
    end
    return list
  end
  -- Item names to offer while you type (16 Nov 2026; user: "it brings up the items in a drop down that
  -- match the name we have typed so far ... deviate scale, deviate fish"). Names = the built-in quest
  -- database's item list (this client's language, the server's own items too); built at the first
  -- letter typed and dropped again when the auction house closes. Items the price history has seen
  -- come first, then names that start with the text, then names that hold it.
  local JUNK = { "^OLD", "^Deprecated", "^DEPRECATED", "^Monster %- ", "^TEST", "^Test ", "%(old%)", "%(OLD%)", "^%[", "^zzOLD" }
  function AH.Names()
    if AH.names then return AH.names end
    local out = { low = {}, name = {}, seen = {} }
    local db = rawget(_G, "pfDB")
    local items = type(db) == "table" and db["items"]
    local hist = AH.Store().h
    if type(items) == "table" then
      local loc = GetLocale and GetLocale() or "enUS"
      local had = {}
      for _, key in ipairs({ loc, loc .. "-turtle", "enUS", "enUS-turtle" }) do
        local list = items[key]
        if type(list) == "table" and not had[list] then
          had[list] = true
          for id, name in pairs(list) do
            if type(name) == "string" and name ~= "" then
              local junk = false
              for _, p in ipairs(JUNK) do if string.find(name, p) then junk = true break end end
              local low = string.lower(name)
              if not junk and not had[low] then
                had[low] = true
                table.insert(out.low, low)
                table.insert(out.name, name)
                table.insert(out.seen, hist[tostring(id)] and true or false)
              end
            end
          end
        end
      end
    end
    AH.names = out
    return out
  end
  -- up to `max` names for what is typed (two letters or more)
  function AH.Complete(text, max)
    text = string.lower(Trim(text))
    max = max or 10
    if string.len(text) < 2 then return {} end
    local n = AH.Names()
    -- the name starts with it (seen on the auction house first), then a later word of the name starts
    -- with it ("scale" finds Deviate Scale), then it is anywhere inside
    local tiers = { {}, {}, {}, {}, {}, {} }
    for i = 1, table.getn(n.low) do
      local at = string.find(n.low[i], text, 1, true)
      if at then
        local base = (at == 1 and 1) or (string.sub(n.low[i], at - 1, at - 1) == " " and 3) or 5
        table.insert(tiers[base + (n.seen[i] and 0 or 1)], n.name[i])
      end
    end
    local out = {}
    for _, t in ipairs(tiers) do
      table.sort(t, function(a, b)
        local la, lb = string.len(a), string.len(b)
        if la ~= lb then return la < lb end
        return a < b
      end)
      for _, name in ipairs(t) do
        if table.getn(out) >= max then return out end
        table.insert(out, name)
      end
    end
    return out
  end
  -- Shopping lists (16 Nov 2026; user, of Auctionator - All Rights Reserved, the idea only: "i like the
  -- shopping lists"): named lists of searches (the search box's own words work in each), run in one go;
  -- the results fold into one line an item: cheapest each and how many are up.
  function AH.Lists()
    local st = AH.Store()
    if type(st.lists) ~= "table" then st.lists = { { name = "Shopping list", terms = {} } } end
    return st.lists
  end
  function AH.ListNew(name)
    name = Trim(name)
    if name == "" then return nil end
    local l = { name = name, terms = {} }
    table.insert(AH.Lists(), l)
    return l, table.getn(AH.Lists())
  end
  function AH.ListAdd(i, term)
    local l = AH.Lists()[i]
    term = Trim(term)
    if not l or term == "" then return false end
    for _, t in ipairs(l.terms) do if string.lower(t) == string.lower(term) then return false end end
    table.insert(l.terms, term)
    return true
  end
  -- "Name^term^term": a list as one line of text, to hand to someone
  function AH.ListExport(i)
    local l = AH.Lists()[i]
    if not l then return "" end
    local out = l.name
    for _, t in ipairs(l.terms) do out = out .. "^" .. t end
    return out
  end
  function AH.ListImport(text)
    local parts = {}
    for p in string.gfind((text or "") .. "^", "(.-)%^") do
      p = Trim(p)
      if p ~= "" then table.insert(parts, p) end
    end
    if table.getn(parts) < 2 then return nil end
    local l, i = AH.ListNew(parts[1])
    if not l then return nil end
    for n = 2, table.getn(parts) do AH.ListAdd(i, parts[n]) end
    return l, i
  end
  -- every search of a list, one after the other, into one result
  function AH.SearchList(i, onPage, onDone)
    local l = AH.Lists()[i]
    if not l or table.getn(l.terms) == 0 then return false end
    local all = {}
    for _, term in ipairs(l.terms) do
      for _, q in ipairs(AH.ParseQuery(term)) do table.insert(all, q) end
    end
    local first = table.remove(all, 1)
    AH.Search(first, onPage, onDone, all)
    return true
  end
  -- the rows folded by item: { key, name, tex, quality, link, low (cheapest buyout each), count (how many
  -- are up in all), auctions }
  function AH.Group(rows)
    local by, list = {}, {}
    for _, r in ipairs(rows or AH.rows) do
      local k = r.key or r.name
      local g = by[k]
      if not g then
        g = { key = r.key, name = r.name, tex = r.tex, quality = r.quality, link = r.link, count = 0, auctions = 0 }
        by[k] = g
        table.insert(list, g)
      end
      g.count, g.auctions = g.count + r.count, g.auctions + 1
      if r.unit and (not g.low or r.unit < g.low) then g.low = r.unit end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
  end
  -- vendor price each (pfUI's own table), and about what posting costs: 5% of it per 2 hours
  function AH.Vendor(key)
    local _, _, id = string.find(key or "", "^(%d+)")
    local data = id and rawget(_G, "pfSellData")
    local line = type(data) == "table" and data[tonumber(id)]
    if type(line) ~= "string" then return nil end
    local _, _, sell = string.find(line, "^(%-?%d+)")
    sell = tonumber(sell)
    if sell and sell > 0 then return sell end
  end
  function AH.Deposit(key, count, hours)
    local v = AH.Vendor(key)
    if not v then return nil end
    return math.floor(v * (count or 1) * .05 * ((AH.HOURS[tonumber(hours) or 24] or 1440) / 120))
  end
  -- the cheapest buyout each among the rows held, others' only
  function AH.LowestOther(key)
    local low
    local me = UnitName("player")
    for _, r in ipairs(AH.rows) do
      if r.key == key and r.unit and r.owner ~= me and (not low or r.unit < low) then low = r.unit end
    end
    return low
  end
  -- queue = more searches to run after q, their rows joining the same list
  function AH.Search(q, onPage, onDone, queue)
    AH.rows, AH.total = {}, 0
    AH.scan = { q = q or {}, page = (q and q.page) or 0, state = "wait", tries = 0, onPage = onPage, onDone = onDone, pages = 0, queue = queue }
    AH.query = AH.scan.q
    return AH.scan
  end
  function AH.Stop(why)
    local s = AH.scan
    AH.scan = nil
    if s and s.onDone then s.onDone(why or "stopped", s) end
  end
  function AH.Searching() return AH.scan ~= nil end
  local function Send(s)
    local q = s.q
    QueryAuctionItems(q.name or "", q.minLevel, q.maxLevel, q.slot, q.class, q.subclass, s.page, q.usable and 1 or nil, q.quality)
    s.state, s.sentAt = "sent", GetTime()
    AH.listPage, AH.listQuery = s.page, q
  end
  -- the list came in
  function AH.OnList()
    local s = AH.scan
    local batch, total = GetNumAuctionItems("list")
    batch, total = batch or 0, total or 0
    if not s or s.state ~= "sent" then
      -- (owners' names arrive a moment after the page: fill them in on the rows of that page)
      for _, row in ipairs(AH.rows) do
        if row.page == AH.listPage and not row.owner then
          local at = AH.Read("list", row.index, row.page)
          if at and at.name == row.name and at.buyout == row.buyout then row.owner = at.owner end
        end
      end
      if AH.onChange then AH.onChange() end
      return
    end
    for i = 1, batch do
      local row = AH.Read("list", i, s.page)
      if row then
        if row.unit then AH.Record(row.key, row.unit) end
        row.q = s.q
        s.seen = (s.seen or 0) + 1
        if not s.q.silent and Fits(s.q, row) then table.insert(AH.rows, row) end
      end
    end
    AH.total = total
    s.pages = math.ceil(total / AH.PAGE)
    s.tries = 0
    if s.onPage then s.onPage(s) end
    if s.q.first or s.page + 1 >= s.pages or batch == 0 then
      -- (several searches in a row: the next one starts, its rows join the others)
      local nextq = s.queue and table.remove(s.queue, 1)
      if nextq then
        s.q, s.page, s.state, s.done = nextq, 0, "wait", (s.done or 0) + 1
        AH.query = nextq
      else
        AH.scan = nil
        if s.onDone then s.onDone("done", s) end
      end
    else
      s.page, s.state = s.page + 1, "wait"
    end
    if AH.onChange then AH.onChange() end
  end
  function AH.ScanTick(now)
    local s = AH.scan
    if not s then return end
    if not AH.open then AH.Stop("closed") return end
    if s.state == "wait" then
      if CanSendAuctionQuery() then Send(s) end
    elseif now - (s.sentAt or now) > 8 then
      -- (no answer: ask again, three times at most)
      s.tries = s.tries + 1
      if s.tries > 3 then AH.Stop("no answer") else s.state = "wait" end
    end
  end

  -- ---------------------------------------------------------------- buying

  function AH.Cost(row, how) return how == "buyout" and row.buyout or row.next end
  -- "ok" | why not
  function AH.CanBuy(row, how)
    if not row then return "nothing picked" end
    if how == "buyout" and row.buyout <= 0 then return "no buyout price" end
    if row.owner and row.owner == UnitName("player") then return "your own auction" end
    if how ~= "buyout" and row.high then return "you are the high bidder" end
    if GetMoney() < AH.Cost(row, how) then return "not enough money" end
    return "ok"
  end
  local function Place(row, how)
    local i = AH.Find(row)
    if not i then return false end
    PlaceAuctionBid(row.kind, i, AH.Cost(row, how))
    if AH.onBought then AH.onBought(row, how, AH.Cost(row, how)) end
    row.gone = true
    for n, r in ipairs(AH.rows) do
      if r == row then table.remove(AH.rows, n) break end
    end
    if AH.onChange then AH.onChange() end
    return true
  end
  function AH.Buy(row, how)
    local why = AH.CanBuy(row, how)
    if why ~= "ok" then return false, why end
    if row.kind ~= "list" or (AH.listPage == row.page and AH.listQuery == (row.q or AH.query) and not AH.scan) then
      if Place(row, how) then return true end
      if row.kind ~= "list" then return false, "it is gone" end
    end
    -- its page is not the one the client holds: fetch that page again, then buy
    if AH.scan then return false, "wait for the search to finish" end
    AH.pending = { row = row, how = how, at = GetTime() }
    AH.fetch = { state = "wait" }
    return true, "fetching its page"
  end
  function AH.FetchTick(now)
    local f, p = AH.fetch, AH.pending
    if not f or not p then AH.fetch, AH.pending = nil, nil return end
    if f.state == "wait" then
      if CanSendAuctionQuery() then
        local q = p.row.q or AH.query or {}
        QueryAuctionItems(q.name or "", q.minLevel, q.maxLevel, q.slot, q.class, q.subclass, p.row.page, q.usable and 1 or nil, q.quality)
        f.state, f.sentAt = "sent", now
        AH.listPage, AH.listQuery = p.row.page, q
      end
    elseif f.state == "got" then
      AH.fetch, AH.pending = nil, nil
      if not Place(p.row, p.how) and AH.onNote then AH.onNote("That auction is gone.") end
    elseif now - (f.sentAt or now) > 8 then
      AH.fetch, AH.pending = nil, nil
      if AH.onNote then AH.onNote("The auction house did not answer.") end
    end
  end

  -- ---------------------------------------------------------------- your bags

  local scanner
  local function Bound(bag, slot)
    if not scanner and libtipscan and libtipscan.GetScanner then scanner = libtipscan:GetScanner("auction") end
    if not scanner or not scanner.SetBagItem then return false end
    scanner:SetBagItem(bag, slot)
    local ok, found = pcall(scanner.Find, scanner, ITEM_SOULBOUND or "Soulbound")
    return ok and found and true or false
  end
  -- what can be sold: key -> { key, name, link, tex, quality, total, slots = { { bag, slot, count } } }
  function AH.Bags()
    local out, list = {}, {}
    for bag = 0, 4 do
      for slot = 1, (GetContainerNumSlots(bag) or 0) do
        local link = GetContainerItemLink(bag, slot)
        local key = AH.ItemKey(link)
        if key and not Bound(bag, slot) then
          local tex, count, locked = GetContainerItemInfo(bag, slot)
          count = (count and count > 0) and count or 1
          local e = out[key]
          if not e then
            local _, _, name = string.find(link, "%[(.-)%]")
            local _, _, color = string.find(link, "|c(%x%x%x%x%x%x%x%x)")
            e = { key = key, name = name or "?", link = link, tex = tex, color = color, total = 0, slots = {} }
            out[key] = e
            table.insert(list, e)
          end
          e.total = e.total + count
          table.insert(e.slots, { bag = bag, slot = slot, count = count, locked = locked })
        end
      end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    AH.bag = out
    return list, out
  end

  -- ---------------------------------------------------------------- posting

  -- prices to start from for an item: { low (cheapest buyout each seen in the last search), value, mine }
  function AH.Suggest(key, name)
    local low, lowOther
    for _, r in ipairs(AH.rows) do
      if r.key == key and r.unit then
        if not low or r.unit < low then low = r.unit end
        if r.owner ~= UnitName("player") and (not lowOther or r.unit < lowOther) then lowOther = r.unit end
      end
    end
    local value = AH.Value(key)
    local saved = AH.Store().p and AH.Store().p[key]
    return { low = low, other = lowOther, value = value, saved = saved }
  end
  -- under the cheapest other seller by the setting (copper, or a share), never under the floor share of the usual price
  function AH.Undercut(unit)
    if not unit then return nil end
    local by = Num("undercut", 1)
    local price = (S().undercutpct == "1") and (unit * (1 - by / 100)) or (unit - by)
    return math.max(1, math.floor(price))
  end
  function AH.Post(key, size, stacks, bid, buyout, hours)
    local _, bags = AH.Bags()
    local e = bags[key]
    if not e then return false, "not in your bags" end
    size, stacks = math.floor(tonumber(size) or 0), math.floor(tonumber(stacks) or 0)
    if size < 1 or stacks < 1 then return false, "nothing to post" end
    if e.total < size then return false, "you have only " .. e.total end
    if (tonumber(bid) or 0) < 1 then return false, "no starting price" end
    if (tonumber(buyout) or 0) > 0 and buyout < bid then return false, "the buyout is under the starting price" end
    AH.job = { key = key, name = e.name, size = size, left = stacks, bid = math.floor(bid), buyout = math.floor(tonumber(buyout) or 0),
      minutes = AH.HOURS[tonumber(hours) or 24] or 1440, posted = 0, idle = 0 }
    -- (what you asked for this item, to offer it again)
    local st = AH.Store()
    st.p = st.p or {}
    st.p[key] = { bid = bid / size, buyout = (tonumber(buyout) or 0) / size, size = size, hours = tonumber(hours) or 24 }
    return true
  end
  local function Free()
    for bag = 0, 4 do
      for slot = 1, (GetContainerNumSlots(bag) or 0) do
        if not GetContainerItemLink(bag, slot) then return bag, slot end
      end
    end
  end
  local function EndJob(why)
    local j = AH.job
    AH.job = nil
    if AH.onNote and j then
      AH.onNote(j.posted .. " x " .. j.name .. " posted" .. (why and (" (" .. why .. ")") or "") .. ".")
    end
    if AH.onChange then AH.onChange() end
  end
  function AH.PostTick(now)
    local j = AH.job
    if not j then return end
    if not AH.open then EndJob("the auction house closed") return end
    if j.hold and now < j.hold then return end
    j.hold = nil
    if CursorHasItem and CursorHasItem() then ClearCursor() j.hold = now + .2 return end
    -- (the last one is still going up)
    if GetAuctionSellItemInfo and GetAuctionSellItemInfo() then
      j.idle = j.idle + 1
      if j.idle > 40 then ClickAuctionSellItemButton() ClearCursor() EndJob("the auction house did not take it") end
      j.hold = now + .1
      return
    end
    j.idle = 0
    if j.left < 1 then EndJob() return end
    local _, bags = AH.Bags()
    local e = bags[j.key]
    if not e or e.total < j.size then EndJob("no more in your bags") return end
    for _, s in ipairs(e.slots) do if s.locked then j.hold = now + .1 return end end
    -- a stack of the right size: up it goes
    for _, s in ipairs(e.slots) do
      if s.count == j.size then
        PickupContainerItem(s.bag, s.slot)
        ClickAuctionSellItemButton()
        ClearCursor()
        local name = GetAuctionSellItemInfo()
        if not name then EndJob("it cannot be auctioned") return end
        StartAuction(j.bid, j.buyout, j.minutes)
        if AH.onPosted then AH.onPosted(j) end
        j.left, j.posted = j.left - 1, j.posted + 1
        j.hold = now + .15
        if AH.onChange then AH.onChange() end
        return
      end
    end
    -- a bigger one: split the size off into a free slot
    for _, s in ipairs(e.slots) do
      if s.count > j.size then
        local fb, fs = Free()
        if not fb then EndJob("no free bag slot to split a stack") return end
        SplitContainerItem(s.bag, s.slot, j.size)
        PickupContainerItem(fb, fs)
        j.hold = now + .25
        return
      end
    end
    -- only smaller ones: put two together and look again
    local a, b
    for _, s in ipairs(e.slots) do
      if s.count < j.size then
        if not a then a = s elseif not b then b = s end
      end
    end
    if a and b then
      PickupContainerItem(a.bag, a.slot)
      PickupContainerItem(b.bag, b.slot)
      j.hold = now + .25
      return
    end
    EndJob("stacks of that size cannot be made")
  end

  -- ---------------------------------------------------------------- your auctions and bids

  function AH.Mine(kind)
    local out = {}
    local n = GetNumAuctionItems(kind) or 0
    for i = 1, n do
      local row = AH.Read(kind, i, 0)
      if row then table.insert(out, row) end
    end
    return out
  end
  function AH.Owned() return AH.Mine("owner") end
  function AH.Bids() return AH.Mine("bidder") end
  function AH.Cancel(row)
    local i = AH.Find(row)
    if not i then return false end
    CancelAuction(i)
    return true
  end
  function AH.Ask(kind)
    if kind == "owner" and GetOwnerAuctionItems then GetOwnerAuctionItems(0) end
    if kind == "bidder" and GetBidderAuctionItems then GetBidderAuctionItems(0) end
  end

  -- ---------------------------------------------------------------- the auction house opening

  -- another auction addon has the window: ours stands aside
  function AH.Other()
    if IsAddOnLoaded then
      for _, n in ipairs({ "aux-addon", "aux", "Auctionator", "Auctioneer" }) do
        if IsAddOnLoaded(n) then return n end
      end
    end
  end
  function AH.Active() return S().enable ~= "0" and not AH.Other() end
  local function TameBlizzard()
    local f = rawget(_G, "AuctionFrame")
    if not f or not f.UnregisterEvent or f.pfOctoTamed or not AH.Active() then return end
    f.pfOctoTamed = true
    -- (its own opening and "closing it closes the auction house" go; ours does both)
    f:UnregisterEvent("AUCTION_HOUSE_SHOW")
    f:SetScript("OnHide", nil)
  end
  -- an item's usual auction price in its tooltip (as pfUI's vendor price is added: a frame that shows with the tooltip)
  function AH.TooltipLine(link, count)
    if S().tooltip == "0" then return nil end
    local key = AH.ItemKey(link)
    local value, days = AH.Value(key)
    if not value then return nil end
    count = math.max(1, tonumber(count) or 1)
    return "Auction:", AH.Money(value) .. (count > 1 and ("|cff555555  //  |r" .. AH.Money(value * count)) or "")
      .. "|cff777777  (" .. days .. (days == 1 and " day)" or " days)") .. "|r"
  end
  if GameTooltip and libtooltip and libtooltip.GetItemLink then
    local tip = CreateFrame("Frame", nil, GameTooltip)
    AH.tip = tip
    tip:SetScript("OnShow", function()
      local link = libtooltip:GetItemLink()
      if not link then return end
      local left, right = AH.TooltipLine(link, libtooltip.GetItemCount and libtooltip:GetItemCount())
      if left then
        GameTooltip:AddDoubleLine(left, right, .6, .8, 1, 1, 1, 1)
        -- (today's cheapest, when it differs from the usual price: green = cheap today, red = dear)
        local key = AH.ItemKey(link)
        local r = AH.Store().h[key]
        local value = AH.Value(key)
        if r and value and r.day == AH.Day() and r.min ~= value then
          local cheap = r.min < value
          GameTooltip:AddDoubleLine("Cheapest today:", AH.Money(r.min) .. (cheap and "  |cff40e060" or "  |cffff7060")
            .. math.floor(r.min / value * 100 + .5) .. "%|r", .6, .8, 1, 1, 1, 1)
        end
        GameTooltip:Show()
      end
    end)
  end

  local ev = CreateFrame("Frame")
  AH.ev = ev
  for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_ITEM_LIST_UPDATE", "AUCTION_OWNED_LIST_UPDATE",
                       "AUCTION_BIDDER_LIST_UPDATE", "ADDON_LOADED", "BAG_UPDATE" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
      if arg1 == "Blizzard_AuctionUI" then TameBlizzard() end
    elseif event == "AUCTION_HOUSE_SHOW" then
      if not AH.Active() then return end
      TameBlizzard()
      local f = rawget(_G, "AuctionFrame")
      if f and f.IsShown and f:IsShown() then f:Hide() end
      AH.open = true
      AH.hideGame = GetTime() + 1.5
      if AH.Show then AH.Show() end
    elseif event == "AUCTION_HOUSE_CLOSED" then
      AH.open = false
      AH.scan, AH.fetch, AH.pending = nil, nil, nil
      AH.names = nil
      if AH.Hide then AH.Hide() end
    elseif not AH.open then
      return
    elseif event == "AUCTION_ITEM_LIST_UPDATE" then
      if AH.fetch and AH.fetch.state == "sent" then AH.fetch.state = "got" return end
      AH.OnList()
    elseif event == "BAG_UPDATE" then
      AH.bagsDirty = true
    elseif AH.onChange then
      AH.onChange(event)
    end
  end)
  ev:SetScript("OnUpdate", function()
    if not AH.open then return end
    local now = GetTime()
    if (this.next or 0) > now then return end
    this.next = now + .05
    -- (the game may load and show its own window just after ours opened: away with it, unless asked for)
    if AH.hideGame and now < AH.hideGame then
      local a = rawget(_G, "AuctionFrame")
      if a and a.IsShown then
        TameBlizzard()
        if a:IsShown() then a:Hide() end
      end
    end
    AH.ScanTick(now)
    AH.FetchTick(now)
    AH.PostTick(now)
  end)
end)
