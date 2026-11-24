-- pfUI Octo: auction house (modules/auction.lua, auction-window.lua, auction-options.lua),
-- run by tests\run.lua against a made-up auction house: money text, price history, searching
-- every page, buying an auction that moved, posting stacks (split / join), cancelling, the window.
local ok = octo_ok
local AH = pfUI.auction
ok(AH and AH.Search and AH.Buy and AH.Post and AH.Value, "auction house loaded (pfUI.auction)")
if not AH then return end
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.auction, "options page Auctions registered")
local S = pfUI_config.auction
ok(S and S.undercut == "1" and S.hours == "24" and S.bidshare == "95", "defaults (C.auction)")
ok(getglobal("pfAuction") and AH.ui and AH.Show, "the window exists")
-- (16 Nov 2026, Lobo) Browse and Deals show the whole stack's buyout as "Total"
do
  local function HasTotal(list)
    for _, c in ipairs(list and list.cols or {}) do if c[1] == "Total" and c[4] == "buyout" then return true end end
  end
  local B = AH.ui and AH.ui.pages and AH.ui.pages.browse
  local K = AH.ui and AH.ui.pages and AH.ui.pages.deals
  ok(B and HasTotal(B.list), "Browse has a Total column (whole stack buyout)")
  ok(not K or HasTotal(K.list), "Deals has a Total column")
end

-- money
ok(AH.Money(12345, true) == "1g 23s 45c" and AH.Money(500000, true) == "50g" and AH.Money(0, true) == "0c" and AH.Money(1020000, true) == "102g",
  "copper as words (" .. AH.Money(12345, true) .. ")")
ok(AH.ParseMoney("1g 20s 5c") == 12005 and AH.ParseMoney("1.5g") == 15000 and AH.ParseMoney("120s") == 12000 and AH.ParseMoney("2") == 20000
  and AH.ParseMoney("45c") == 45 and AH.ParseMoney("") == nil and AH.ParseMoney("abc") == nil and AH.ParseMoney(AH.Money(98765)) == 98765,
  "prices typed in any of the usual ways")
ok(AH.ItemKey("|cffffffff|Hitem:2589:0:0:0|h[Linen Cloth]|h|r") == "2589" and AH.ItemKey("|Hitem:9999:0:1234:0|h[x]|h") == "9999:1234" and AH.ItemKey("nope") == nil,
  "an item's key from its link (random suffix kept)")

local keep = {}
local NAMES = { "QueryAuctionItems", "CanSendAuctionQuery", "GetNumAuctionItems", "GetAuctionItemInfo", "GetAuctionItemLink", "GetAuctionItemTimeLeft",
  "PlaceAuctionBid", "CancelAuction", "GetMoney", "GetTime", "time", "GetContainerNumSlots", "GetContainerItemLink", "GetContainerItemInfo",
  "PickupContainerItem", "SplitContainerItem", "ClickAuctionSellItemButton", "StartAuction", "GetAuctionSellItemInfo", "CursorHasItem", "ClearCursor",
  "IsAddOnLoaded", "UnitName", "GetRealmName", "UnitFactionGroup", "CloseAuctionHouse", "PlaySound", "GetOwnerAuctionItems", "GetBidderAuctionItems" }
for _, k in ipairs(NAMES) do keep[k] = rawget(_G, k) end
local cacheWas = pfUI_cache.auction
pfUI_cache.auction = nil
local now, day = 1000, 20000
_G.GetTime = function() return now end
_G.time = function() return day * 86400 + 100 end
_G.GetRealmName = function() return "Octo" end
_G.UnitFactionGroup = function() return "Horde" end
_G.UnitName = function() return "Me" end
_G.IsAddOnLoaded = function() return nil end
_G.CloseAuctionHouse = function() end
_G.PlaySound = function() end
_G.GetOwnerAuctionItems = function() end
_G.GetBidderAuctionItems = function() end
local money = 1000000
_G.GetMoney = function() return money end

-- history: one figure a day, the usual price = the middle
AH.Record("2589", 120)
AH.Record("2589", 90)
AH.Record("2589", 200)
ok(AH.Value("2589") == 90, "today's lowest is kept")
for _, v in ipairs({ 100, 110, 5, 105 }) do day = day + 1 AH.Record("2589", v) end
local v, n = AH.Value("2589")
ok(v == 100 and n == 5, "the usual price is the middle of the days: one silly 5c auction does not move it (" .. tostring(v) .. ")")
ok(AH.Value("nothing") == nil and AH.Known() == 1, "an item never seen has no price")

-- the made-up auction house: 120 Linen Cloth auctions over three pages, a few of other things
local ALL = {}
for i = 1, 120 do
  table.insert(ALL, { "Linen Cloth", 2589, (math.mod(i, 4) + 1) * 5, 1000 + i * 10, 2000 + i * 20, 0, "Seller" .. math.mod(i, 7) })
end
ALL[7][5] = 0                       -- no buyout
ALL[60] = { "Linen Cloth", 2589, 20, 100, 400, 0, "Cheap" }   -- 20c each: the cheapest
ALL[61] = { "Linen Bandage", 1251, 10, 500, 900, 0, "Other" }
local view, sentPage, canSend, queries = {}, nil, true, 0
_G.CanSendAuctionQuery = function() return canSend end
_G.QueryAuctionItems = function(name, minL, maxL, slot, class, sub, page)
  queries = queries + 1
  sentPage = page
  view = {}
  for i = page * 50 + 1, math.min(table.getn(ALL), page * 50 + 50) do table.insert(view, ALL[i]) end
end
_G.GetNumAuctionItems = function(kind) return table.getn(view), table.getn(ALL) end
_G.GetAuctionItemInfo = function(kind, i)
  local a = view[i]
  if not a then return nil end
  return a[1], "Interface\\Icons\\INV_Fabric_Linen_01", a[3], 1, 1, 0, a[4], 50, a[5], a[6], a[8], a[7]
end
_G.GetAuctionItemLink = function(kind, i) local a = view[i] return a and ("|cffffffff|Hitem:" .. a[2] .. ":0:0:0|h[" .. a[1] .. "]|h|r") end
_G.GetAuctionItemTimeLeft = function() return 3 end
local placed = {}
_G.PlaceAuctionBid = function(kind, i, amount)
  table.insert(placed, { view[i], amount })
  -- (bought out: it leaves the page and the rest move up)
  if view[i] and amount == view[i][5] then table.remove(view, i) end
end
local function Answer() AH.OnList() end

AH.open = true
local pagesSeen, doneWhy = 0, nil
AH.Search({ name = "Linen Cloth", exact = true }, function() pagesSeen = pagesSeen + 1 end, function(why) doneWhy = why end)
ok(AH.Searching() and queries == 0, "a search waits its turn")
canSend = false
AH.ScanTick(now)
ok(queries == 0, "nothing is sent while the client says wait")
canSend = true
for p = 1, 3 do
  AH.ScanTick(now)
  Answer()
  now = now + .3
end
ok(queries == 3 and pagesSeen == 3 and doneWhy == "done" and not AH.Searching(), "every page is fetched, one after the other (" .. queries .. " pages)")
ok(table.getn(AH.rows) == 119 and AH.total == 120, "exact name: the 119 Linen Cloth of 120 auctions (" .. table.getn(AH.rows) .. ")")
local cheap, nobuy
for _, r in ipairs(AH.rows) do
  if r.owner == "Cheap" then cheap = r end
  if r.buyout == 0 then nobuy = r end
end
ok(cheap and cheap.unit == 20 and cheap.page == 1 and cheap.count == 20 and cheap.key == "2589" and cheap.next == 100 and cheap.bidunit == 5,
  "a row: price each, its page, what a bid costs")
ok(nobuy and nobuy.unit == nil, "an auction with no buyout has no price each")
ok(AH.Value("2589") == 90 and pfUI_cache.auction["Octo-Horde"].h["2589"].min == 20, "the search fed the history (today's low 20c, the usual price now 90c)")
ok(AH.Value("1251") == 90, "also for what the name filter left out")
-- a price cap
AH.Search({ name = "Linen Cloth", maxUnit = 150, first = true })
AH.ScanTick(now)
Answer()
ok(not AH.Searching() and queries == 4 and table.getn(AH.rows) > 0 and table.getn(AH.rows) < 50, "one page only, with a price cap (" .. table.getn(AH.rows) .. ")")

-- buying: the cheap one is on page 2 (index 1 of our pages), the client holds another page
AH.Search({ name = "Linen Cloth", exact = true })
for p = 1, 3 do AH.ScanTick(now) Answer() end
for _, r in ipairs(AH.rows) do if r.owner == "Cheap" then cheap = r end end
ok(AH.CanBuy(cheap, "buyout") == "ok" and AH.CanBuy(nobuy, "buyout") == "no buyout price", "what can be bought")
local okay, why = AH.Buy(cheap, "buyout")
ok(okay and why == "fetching its page" and table.getn(placed) == 0, "its page is not the one loaded: fetched first")
AH.FetchTick(now)
ok(sentPage == 1 and AH.fetch.state == "sent", "the page is asked for")
-- (someone bought the auction before it: everything moved up one)
table.remove(view, 1)
AH.fetch.state = "got"
AH.FetchTick(now)
ok(table.getn(placed) == 1 and placed[1][1][7] == "Cheap" and placed[1][2] == 400, "bought by what it is, not by where it was (" .. tostring(placed[1] and placed[1][1][7]) .. ")")
local still
for _, r in ipairs(AH.rows) do if r == cheap then still = true end end
ok(not still and table.getn(AH.rows) == 118, "and it leaves the results")
money = 10
ok(AH.CanBuy(AH.rows[1], "buyout") == "not enough money", "no money: no")
money = 1000000
view[3][7] = "Me"
local mine = AH.Read("list", 3, 1)
ok(AH.CanBuy(mine, "bid") == "your own auction", "not your own auctions")
-- a bid on a row of the loaded page goes straight away
local r5 = AH.Read("list", 5, 1)
AH.listPage, AH.listQuery, AH.query = 1, AH.query, AH.query
okay = AH.Buy(r5, "bid")
ok(okay and placed[2] and placed[2][2] == r5.minBid, "a bid at the starting price")

-- selling: 47 Linen Cloth in stacks of 20, 20 and 7
local bags = { [0] = { { 2589, 20 }, { 2589, 20 }, false, { 2589, 7 }, false, { 6948, 1 } } }
_G.GetContainerNumSlots = function(bag) return bags[bag] and table.getn(bags[bag]) or 0 end
_G.GetContainerItemLink = function(bag, slot)
  local s = bags[bag] and bags[bag][slot]
  if not s then return nil end
  return "|cffffffff|Hitem:" .. s[1] .. ":0:0:0|h[" .. (s[1] == 2589 and "Linen Cloth" or "Hearthstone") .. "]|h|r"
end
_G.GetContainerItemInfo = function(bag, slot) local s = bags[bag] and bags[bag][slot] if s then return "tex", s[2], nil end end
local cursor, sellSlot, started = nil, nil, {}
_G.CursorHasItem = function() return cursor ~= nil end
_G.ClearCursor = function() cursor = nil end
_G.PickupContainerItem = function(bag, slot)
  local s = bags[bag][slot]
  if cursor and cursor.split then
    -- (dropping a split-off part)
    if not s then bags[bag][slot] = { cursor.id, cursor.n } elseif s[1] == cursor.id then s[2] = s[2] + cursor.n end
    cursor = nil
  elseif cursor and s and cursor.from ~= s then
    -- (onto another stack: joined)
    s[2] = s[2] + cursor.from[2]
    bags[cursor.bag][cursor.slot] = false
    cursor = nil
  elseif s then
    cursor = { from = s, bag = bag, slot = slot }
  end
end
_G.SplitContainerItem = function(bag, slot, n)
  local s = bags[bag][slot]
  s[2] = s[2] - n
  cursor = { split = true, id = s[1], n = n }
end
_G.ClickAuctionSellItemButton = function()
  if cursor and cursor.from then sellSlot = cursor cursor = nil end
end
_G.GetAuctionSellItemInfo = function() if sellSlot then return "Linen Cloth", "tex", sellSlot.from[2] end end
_G.StartAuction = function(bid, buyout, minutes)
  table.insert(started, { sellSlot.from[2], bid, buyout, minutes })
  bags[sellSlot.bag][sellSlot.slot] = false
  sellSlot = nil
end
local list, by = AH.Bags()
ok(table.getn(list) == 2 and by["2589"].total == 47 and table.getn(by["2589"].slots) == 3, "your bags: 47 Linen Cloth in three stacks")
ok(AH.Undercut(100) == 99, "undercut by one copper")
S.undercut, S.undercutpct = "5", "1"
ok(AH.Undercut(1000) == 950, "or by a share")
S.undercut, S.undercutpct = "1", "0"
local sug = AH.Suggest("2589", "Linen Cloth")
ok(sug.value == 90 and sug.low and sug.other, "prices to start from: usual " .. tostring(sug.value) .. ", cheapest now " .. tostring(sug.other))
local can, err = AH.Post("2589", 50, 1, 100, 200, 24)
ok(can == false and err == "you have only 47", "more than you have: refused")
can, err = AH.Post("2589", 10, 1, 300, 200, 24)
ok(can == false, "a buyout under the starting price: refused")
-- four stacks of 10: needs splitting the 20s
can = AH.Post("2589", 10, 4, 900, 1000, 8)
ok(can and AH.job and AH.job.minutes == 480, "a job of four stacks of 10 for 8 hours")
for i = 1, 60 do now = now + .3 AH.PostTick(now) end
ok(table.getn(started) == 4 and not AH.job, "four auctions went up (" .. table.getn(started) .. ")")
local good = true
for _, s in ipairs(started) do if s[1] ~= 10 or s[2] ~= 900 or s[3] ~= 1000 or s[4] ~= 480 then good = false end end
ok(good, "each a stack of 10 at the asked prices")
local _, left = AH.Bags()
ok(left["2589"].total == 7, "7 are left in the bags")
ok(pfUI_cache.auction["Octo-Horde"].p["2589"].size == 10 and pfUI_cache.auction["Octo-Horde"].p["2589"].buyout == 100, "the prices asked are remembered, each")
-- joining small stacks: 7 + 5 -> one of 12
bags[0][1] = { 2589, 5 }
started = {}
can = AH.Post("2589", 12, 1, 100, 0, 24)
for i = 1, 30 do now = now + .3 AH.PostTick(now) end
ok(can and table.getn(started) == 1 and started[1][1] == 12 and started[1][3] == 0, "two small stacks joined into the one asked for, no buyout")

-- your auctions
view = { { "Linen Cloth", 2589, 10, 900, 1000, 950, "Me" }, { "Linen Cloth", 2589, 10, 900, 1000, 0, "Me" } }
local owned = AH.Owned()
ok(table.getn(owned) == 2 and owned[1].bid == 950 and owned[1].kind == "owner", "your auctions, one with a bid")
local cancelled
_G.CancelAuction = function(i) cancelled = i end
table.remove(view, 1)
ok(AH.Cancel(owned[2]) and cancelled == 1, "cancelling finds it where it is now")
ok(AH.Cancel(owned[1]) == false, "one that is gone is not cancelled by mistake")

-- phase 2: search words, several searches in a row, reading everything, deposit, tooltip
do
  local cw = rawget(_G, "GetAuctionItemClasses")
  _G.GetAuctionItemClasses = function() return "Weapon", "Armor", "Container", "Consumable", "Trade Goods" end
  local list = AH.ParseQuery("Linen Cloth/exact; silk cloth/max 2s 50c; /rare/40-50/weapon/usable", { quality = 2 })
  ok(table.getn(list) == 3 and list[1].name == "Linen Cloth" and list[1].exact and list[1].quality == 2, "search words: three searches, the first exact (the window's quality kept)")
  ok(list[2].name == "silk cloth" and list[2].maxUnit == 250 and not list[2].exact, "a price cap each")
  ok(list[3].name == "" and list[3].quality == 3 and list[3].minLevel == 40 and list[3].maxLevel == 50 and list[3].class == 1 and list[3].usable,
    "no name: rare and better, levels 40-50, weapons, usable")
  ok(table.getn(AH.ParseQuery("")) == 1 and AH.ParseQuery("")[1].name == "", "an empty box is one search for everything")
  _G.GetAuctionItemClasses = cw
  -- our own sub-categories (filters on the whole class)
  local cons, tg = AH.KindsFor("Consumable"), AH.KindsFor("Trade Goods")
  ok(cons and tg and not AH.KindsFor("Weapon"), "own sub-categories for Consumable and Trade Goods only")
  local function K(list, name) for _, k in ipairs(list) do if k.name == name then return k end end end
  ok(AH.InKind(K(cons, "Flasks"), { name = "Flask of the Titans" }) and not AH.InKind(K(cons, "Flasks"), { name = "Elixir of the Mongoose" }), "Flasks takes flasks only")
  ok(AH.InKind(K(cons, "Everything else"), { name = "Gnomish Battle Chicken" }) and not AH.InKind(K(cons, "Everything else"), { name = "Major Healing Potion" }),
    "Everything else = what no other one takes")
  ok(AH.InKind(K(tg, "Herbs"), { name = "Black Lotus" }) and AH.InKind(K(tg, "Ore, bars & stone"), { name = "Thorium Bar" })
    and not AH.InKind(K(tg, "Cloth"), { name = "Thorium Bar" }), "Trade Goods: herbs, bars, cloth")
  ok(table.getn(AH.ParseQuery("", { tag = K(cons, "Food") }) ) == 1 and AH.ParseQuery("", { tag = K(cons, "Food") })[1].tag == K(cons, "Food"),
    "the picked sub-category rides along with the search")
  -- two searches in a row join one list
  local done
  local q2 = AH.ParseQuery("Linen Cloth/exact; Linen Bandage/exact")
  queries = 0
  AH.Search(table.remove(q2, 1), nil, function() done = true end, q2)
  for i = 1, 6 do AH.ScanTick(now) Answer() if not AH.Searching() then break end end
  local bandage, cloth = 0, 0
  for _, r in ipairs(AH.rows) do if r.name == "Linen Bandage" then bandage = bandage + 1 else cloth = cloth + 1 end end
  ok(done and bandage == 1 and cloth > 100 and queries >= 4, "two searches run one after the other into one list (" .. cloth .. " + " .. bandage .. ")")
  ok(AH.rows[1].q and AH.rows[1].q.name == "Linen Cloth", "each row knows the search it came from (to fetch its page again)")
  local mineWas = view
  ok(AH.LowestOther("2589") ~= nil and AH.LowestOther("nothing") == nil, "the cheapest other seller of an item")
  -- reading everything: prices noted, nothing listed
  local st
  -- (20 Nov 2026, Lobo: it "chugs" in Durotar) a breath between pages, and the list is not redrawn per page
  local changes, oldChange = 0, AH.onChange
  AH.onChange = function() changes = changes + 1 end
  AH.Search({ silent = true }, nil, function(why, s) st = s end)
  queries = 0
  AH.ScanTick(now) Answer()
  AH.ScanTick(now)
  ok(queries == 1, "reading every auction: the next page waits a moment (" .. queries .. " asked at once)")
  for i = 1, 8 do now = now + AH.READGAP AH.ScanTick(now) Answer() if not AH.Searching() then break end end
  AH.onChange = oldChange
  ok(st and st.seen == table.getn(ALL) and table.getn(AH.rows) == 0, "reading every auction lists nothing and reads them all (" .. tostring(st and st.seen) .. ")")
  ok(changes == 0, "reading every auction does not redraw the list each page (" .. changes .. ")")
  -- deposit from the vendor price
  local sellWas = rawget(_G, "pfSellData")
  _G.pfSellData = { [2589] = "13,55" }
  -- (21 Nov 2026) the client's own deposit: vendor x stack x (minutes / 120) x (1 + (limit - stack) x 5%) x 2.5%, a stack
  local keepGII = rawget(_G, "GetItemInfo")
  _G.GetItemInfo = function(id) if id == 2589 then return "Linen Cloth", "item:2589", 1, 0, "Trade Goods", "Trade Goods", 20 end end
  ok(AH.Vendor("2589") == 13 and AH.Vendor("1") == nil and AH.Deposit("2589", 20, 24, 20) == 78 and AH.Deposit("2589", 20, 2, 20) == 6,
    "deposit: a full stack, 72 h and 6 h (" .. tostring(AH.Deposit("2589", 20, 24, 20)) .. ", " .. tostring(AH.Deposit("2589", 20, 2, 20)) .. ")")
  ok(AH.Deposit("2589", 20, 24, 5) == 4 * math.floor(13 * 5 * 12 * 1.75 * .025),
    "deposit: four stacks of 5 pay more each, as the game's own window says (" .. tostring(AH.Deposit("2589", 20, 24, 5)) .. ")")
  _G.GetItemInfo = keepGII
  -- (21 Nov 2026, Javelin: "it shows length of 2h/8h/24h where it actually is 6h, 24h and 72h")
  ok(AH.HourText(2) == "6 h" and AH.HourText(8) == "24 h" and AH.HourText(24) == "72 h" and AH.HOURS[24] == 1440,
    "auction lengths shown as this server's 6 / 24 / 72 h; what is sent stays 120 / 480 / 1440 minutes")
  ok(AH.LEFT[4] == "over 8 h", "the longest time-left bucket: over 8 h")
  _G.pfSellData = sellWas
  -- the tooltip line
  local left, right = AH.TooltipLine("|Hitem:2589:0:0:0|h[Linen Cloth]|h", 20)
  ok(left == "Auction:" and string.find(right, "//", 1, true) and AH.TooltipLine("|Hitem:77:0:0:0|h[x]|h", 1) == nil, "an item's usual price for its tooltip, each and for the stack")
  S.tooltip = "0"
  ok(AH.TooltipLine("|Hitem:2589:0:0:0|h[Linen Cloth]|h", 20) == nil, "switched off: no line")
  S.tooltip = "1"
end

-- another auction add-on on: ours stands aside
_G.IsAddOnLoaded = function(n) return n == "aux-addon" and 1 or nil end
ok(AH.Other() == "aux-addon" and AH.Active() == false, "with aux switched on ours stands aside")
_G.IsAddOnLoaded = function() return nil end
ok(AH.Active() == true, "without it ours opens")

-- the window: every tab draws
do
  local UI = AH.ui
  AH.Search({ name = "Linen Cloth", exact = true })
  view = {}
  for p = 1, 3 do AH.ScanTick(now) Answer() end
  local okay2, err2 = pcall(function()
    AH.Show()
    for _, t in ipairs(UI.TABS) do UI.Open(t[1]) end
    UI.Open("browse")
  end)
  ok(okay2 and getglobal("pfAuction"):IsShown(), "the window opens and every tab draws " .. tostring(err2 or ""))
  local l = UI.lists.browse
  ok(table.getn(l.data) == table.getn(AH.rows) and l.rows[1].d and l.rows[1].d.unit and l.rows[2].d.unit >= l.rows[1].d.unit, "Browse lists the rows, cheapest each first")
  l.sel = l.rows[1].d
  UI.PaintBuy()
  ok(UI.pages.browse.buy.text:GetText() == "Buyout  " .. AH.Money(l.sel.buyout), "the Buyout button says what it costs")
  -- (17 Nov 2026) nothing up: the last prices seen show in the empty list
  do
    local dbWas, rowsWas, scanWas = rawget(_G, "pfDB"), AH.rows, AH.scan
    _G.pfDB = { items = { enUS = { [12359] = "Thorium Bar", [12360] = "Arcanite Bar", [3577] = "Gold Bar" } } }
    local h = AH.Store().h
    h["12359"] = { day = AH.Day() - 3, min = 5000, days = { 5200, 4800 } }
    h["3577"] = { day = AH.Day(), min = 9000, days = {} }
    local known = AH.LastKnown("thorium bar", true)
    ok(table.getn(known) == 1 and known[1].name == "Thorium Bar" and known[1].last == 5000 and known[1].ago == 3 and known[1].value == 5000,
      "last known price of an item by name")
    ok(table.getn(AH.LastKnown("bar")) == 2 and AH.LastKnown("bar")[1].name == "Thorium Bar", "by part of the name: every one with prices, most days first")
    AH.rows, AH.scan = {}, nil
    UI.searched = { { "Thorium Bar", true } }
    UI.Status("done")
    local t = UI.pages.browse.empty:GetText() or ""
    ok(UI.pages.browse.empty:IsShown() and string.find(t, "None up right now", 1, true) and string.find(t, "Thorium Bar", 1, true)
      and string.find(t, "3 days ago", 1, true), "an empty search shows when it was last seen and at what price")
    UI.searched = { { "Nothingite", true } }
    UI.Status("done")
    ok(string.find(UI.pages.browse.empty:GetText() or "", "no price seen yet", 1, true), "never seen: says so")
    AH.rows = rowsWas
    UI.Status("done")
    ok(table.getn(AH.rows) == 0 or not UI.pages.browse.empty:IsShown(), "rows found: no note")
    h["12359"], h["3577"] = nil, nil
    _G.pfDB, AH.scan, UI.searched = dbWas, scanWas, nil
  end
  -- (17 Nov 2026, Lobo) Ctrl + click tries the item on and never bids; Alt + click buys only while it is on
  do
    local dressed, bought
    local dressWas, buyWas, thisWas = rawget(_G, "DressUpItemLink"), UI.Buy, rawget(_G, "this")
    _G.DressUpItemLink = function(link) dressed = link end
    UI.Buy = function(how) bought = how end
    local r = l.rows[1]
    r.d.link = r.d.link or "|cffffffff|Hitem:2589:0:0:0|h[Linen Cloth]|h|r"
    _G.this = r
    Mock.ctrl = true  r:GetScript("OnClick")()  Mock.ctrl = nil
    ok(dressed and string.find(dressed, "^item:%d+") and not bought, "Ctrl + click a row tries the item on, no bid")
    _G.arg1 = "LeftButton"
    S.altbuy = "0"
    Mock.alt = true  r:GetScript("OnClick")()
    ok(not bought, "Alt + click switched off: nothing bought")
    S.altbuy = "1"
    r:GetScript("OnClick")()  Mock.alt = nil
    ok(bought == "buyout", "Alt + click on: bought out")
    _G.DressUpItemLink, UI.Buy, _G.this = dressWas, buyWas, thisWas
  end
  -- (17 Nov 2026, Lobo) after a buyout, picks, several at once, colours
  do
    local dataWas, selWas = l.data, l.sel
    -- (these check the plain list, one line per auction; folding is checked in auction-ledger.lua)
    local foldWas = l.fold
    l.fold = nil
    local function R(seq, unit, count, owner) return { name = "Dense Blasting Powder", key = "15992", unit = unit, count = count, buyout = unit * count,
      next = unit * count, bidunit = unit, minBid = unit, bid = 0, owner = owner, seq = seq, kind = "list", level = 1, left = 2, quality = 1, inc = 0, index = seq, page = 0 } end
    local a, b, c, d, e = R(1, 1996, 10, "Claank"), R(2, 1998, 6, "Nyxthra"), R(3, 1996, 10, "Claank"), R(4, 2400, 5, "Bob"), R(5, 1996, 10, "Claank")
    l.sortBy, l.desc = "unit", false
    l.Set({ e, d, c, b, a })
    ok(l.data[1] == a and l.data[2] == c and l.data[3] == e and l.data[4] == b and l.data[5] == d, "equal prices keep one order (as read)")
    l.Set({ d, a, e, b, c })
    ok(l.data[1] == a and l.data[2] == c and l.data[3] == e, "and the same order after sorting again")
    -- bought the middle one of three equal ones: the cheapest left goes next, not the dearer one below
    c.gone = true
    l.Set({ a, e, b, d })
    ok(UI.NextAfter(l, c, 2) == a, "after a buy: the cheapest of the same item left is picked [" .. tostring(UI.NextAfter(l, c, 2) and UI.NextAfter(l, c, 2).seq) .. "]")
    ok(UI.NextAfter(l, d, 5) == nil or UI.NextAfter(l, d, 5).unit <= d.unit, "the dearest bought: a cheaper one is fine")
    c.gone = nil
    l.Set({ a, b, c, d, e })
    l.PickRange(a, e)
    ok(table.getn(l.Picked()) == 3 and l.sel == e, "Shift + drag over rows picks them all")
    l.PickRange(c, a)
    ok(table.getn(l.Picked()) == 2, "upwards too")
    UI.PaintBuy()
    ok(string.find(UI.pages.browse.buy.text:GetText() or "", "^Buy 2"), "the Buyout button says how many [" .. tostring(UI.pages.browse.buy.text:GetText()) .. "]")
    -- several at once: cheapest first, one after the other
    local buyWas, openWas, bought = AH.Buy, AH.open, {}
    AH.Buy = function(r, how) table.insert(bought, r) r.gone = true return true end
    AH.open = true
    UI.RunQueue({ kind = "buyout", rows = { d, a, b } })
    for t = 1, 10 do UI.QueueStep(1000 + t) end
    ok(table.getn(bought) == 3 and not UI.queue, "the queue buys every picked one [" .. table.getn(bought) .. "]")
    -- (19 Nov 2026, "possible to spam buyout") a click while a page is fetched waits its turn, the pick moves down
    for _, r in ipairs({ a, b, c, d, e }) do r.gone = nil end
    l.Set({ a, b, d })
    l.picks, l.sel = {}, b
    AH.pending = { row = a }
    local moneyWas = _G.GetMoney
    _G.GetMoney = function() return 1e9 end
    local okw, ew = pcall(UI.Buy, "buyout")
    ok(okw and UI.List() == l and UI.waiting and UI.waiting[1] and UI.waiting[1].row == b and l.sel == d, "a click during a fetch waits and the pick moves to the next row (" .. tostring(ew) .. ", " .. tostring(UI.List() == l) .. ", " .. tostring(AH.CanBuy(b, "buyout")) .. ", w " .. tostring(UI.waiting and UI.waiting[1] and UI.waiting[1].row.seq) .. ", sel " .. tostring(l.sel and l.sel.seq) .. ", bought " .. table.getn(bought) .. ")")
    bought = {}
    AH.pending = nil
    UI.WaitStep()
    ok(bought[1] == b and not UI.waiting, "it is bought once the last one went through")
    _G.GetMoney = moneyWas
    AH.Buy, AH.open = buyWas, openWas
    for _, r in ipairs({ a, b, c, d, e }) do r.gone = nil r.queued = nil end
    -- My auctions are read afresh: picks are found again by what they are
    local fresh = {}
    for _, r in ipairs({ a, b, c }) do local n = {} for k, v in pairs(r) do n[k] = v end table.insert(fresh, n) end
    l.same = AH.Same
    l.Set({ a, b, c, d, e })
    l.PickRange(a, b)
    l.Set(fresh)
    ok(table.getn(l.Picked()) == 3 and l.sel and l.sel ~= b and AH.Same(l.sel, b), "picks follow a list read again [" .. table.getn(l.Picked()) .. "]")
    l.same, l.picks = nil, {}
    -- prices against the usual one in colour
    ok(string.find(UI.PctText(102), "ffe040", 1, true) and string.find(UI.PctText(60), "40e060", 1, true) and string.find(UI.PctText(150), "ff4a3a", 1, true),
      "Of usual: 102% yellow, 60% green, 150% red")
    ok(UI.HEADTIPS.ofusual and UI.HEADTIPS.unit, "column heads explain themselves")
    l.Set(dataWas)
    l.sel = selWas
    l.fold = foldWas
  end
  bags[0] = { { 2589, 20 }, { 2589, 20 } }
  AH.bagsDirty = true
  okay2, err2 = pcall(function()
    UI.Open("sell")
    S.autolookup = "0"
    UI.PickSell(UI.bagList[1])
    UI.Price("value")
  end)
  S.autolookup = "1"
  ok(okay2 and tostring(UI.pages.sell.size:GetText()) == "12" and AH.ParseMoney(UI.pages.sell.buyp:GetText()) == 90, "Sell: your last stack size and the usual price are filled in " .. tostring(err2 or "") .. " [" .. tostring(UI.pages.sell.size:GetText()) .. " / " .. tostring(UI.pages.sell.buyp:GetText()) .. " / " .. tostring(AH.Value("2589")) .. "]")
  local nums = UI.SellNumbers()
  ok(nums and nums.size == 12 and nums.stacks == 1 and nums.buy == 90 and nums.bid == 85, "the starting price follows the buyout (95%)")
  -- (20 Nov 2026, Wolfahrt: "click on item to align on prices", as Aux) a click on an auction lines your price up with it
  do
    UI.MatchPrice({ unit = 200, owner = "Rival" })
    local m = UI.SellNumbers()
    ok(m and m.buy == AH.Undercut(200) and m.buy < 200, "clicking someone's auction: just under it (" .. tostring(m and m.buy) .. ")")
    UI.MatchPrice({ unit = 150, owner = UnitName("player") })
    m = UI.SellNumbers()
    ok(m and m.buy == 150, "clicking your own: the same price")
    ok(pfUI_config.auction.sellprice == "under", "a picked item starts under the cheapest by default")
    UI.Price("value")
  end
  -- (19 Nov 2026, user: "quick option for list 1 by 1 add sliders under the numbers")
  do
    local P = UI.pages.sell
    UI.OneByOne()
    local n1 = UI.SellNumbers()
    ok(n1 and n1.size == 1 and n1.stacks == 40, "1 by 1: stack size 1, as many as you have [" .. tostring(n1 and n1.stacks) .. "]")
    P.size:SetText("20") UI.PaintSell()
    local lo, hi = P.stacksS:GetMinMaxValues()
    ok(P.sizeS and hi == 2, "the stacks slider goes up to what fits (" .. tostring(hi) .. ")")
    _G.this = P.sizeS
    P.sizeS.quiet = nil
    P.sizeS:SetValue(10)
    P.sizeS:GetScript("OnValueChanged")()
    ok(P.size:GetText() == "10", "dragging the size slider writes the box [" .. tostring(P.size:GetText()) .. "]")
    UI.FullStacks()
    local nf = UI.SellNumbers()
    ok(nf and nf.size * nf.stacks <= 40 and nf.size >= 20, "Full stacks: the biggest stack, as many as fit")
    -- (19 Nov 2026, user: "the remaining ... should go in the stack size auto") 20 posted, 16 left
    P.size:SetText("20") P.stacks:SetText("1")
    UI.FitLeft({ name = "Bronze Bar", total = 16, slots = {} })
    ok(P.size:GetText() == "16" and P.stacks:GetText() == "1", "after posting, the leftover goes into the stack size [" .. tostring(P.size:GetText()) .. "]")
    P.size:SetText("5") P.stacks:SetText("4")
    UI.FitLeft({ name = "Bronze Bar", total = 16, slots = {} })
    ok(P.size:GetText() == "5" and P.stacks:GetText() == "3", "or fewer stacks of the same size when they still fit")
    -- (24 Nov 2026, Wolfahrt: 24 in stacks of 20, the 4 left needed "Full stacks" again) the bags changed while the
    -- post was still running; once it ends the next refresh fits the 4, with no new bag change
    if UI.Refresh and UI.Open then
      local keepSell, keepJob, keepTab = UI.sell, AH.job, UI.tab
      UI.tab = "sell"
      UI.sell = { name = "Dream Dust", key = "dd", total = 4, slots = {} }
      P.size:SetText("20") P.stacks:SetText("1")
      AH.bagsDirty = nil
      AH.job = nil
      local wasShown = UI.frame:IsShown()
      UI.frame:Show()
      UI.bagList = UI.bagList or {}
      local good, err = pcall(UI.Refresh)
      ok(good and P.size:GetText() == "4" and P.stacks:GetText() == "1",
        "after the post ends the 4 left go in the stack size [" .. tostring(P.size:GetText()) .. (good and "" or (": " .. tostring(err))) .. "]")
      if not wasShown then UI.frame:Hide() end
      UI.sell, AH.job, UI.tab = keepSell, keepJob, keepTab
    end
  end
  -- saved searches
  UI.pages.browse.name:SetText("linen cloth/exact")
  UI.SearchPick("!save")
  local st = AH.Store()
  ok(st.saved[1] == "linen cloth/exact" and UI.SearchMenu()[3].key == "s:linen cloth/exact", "a search is saved and offered in the menu")
  UI.SearchPick("!save")
  ok(table.getn(st.saved) == 1, "not twice")
  UI.forgetNext = true
  UI.SearchPick("s:linen cloth/exact")
  ok(table.getn(st.saved) == 0, "and removed again")
  -- a bag item right-clicked goes to the Sell tab
  UI.Open("browse")
  AH.open = true
  getglobal("pfAuction"):Show()
  S.autolookup = "0"
  ok(UI.SellKey("2589") == true and UI.tab == "sell" and UI.sell and UI.sell.key == "2589", "an item of your bags is put on the Sell tab")
  ok(UI.SellKey("424242") == false, "one that is not there (soulbound) is refused")
  S.autolookup = "1"
  -- undercut check: your auctions against the others'
  view = { { "Linen Cloth", 2589, 10, 900, 5000, 0, "Me" } }
  local ownedView = view
  local realNum, realInfo = _G.GetNumAuctionItems, _G.GetAuctionItemInfo
  local okay3, err3 = pcall(function()
    UI.Open("owner")
    UI.CheckUndercuts()
    for i = 1, 5 do AH.ScanTick(now) Answer() if not AH.Searching() then break end end
  end)
  ok(okay3 and UI.checked, "the undercut check runs a search per item you have up " .. tostring(err3 or ""))
  ok(AH.LowestOther("2589") and AH.LowestOther("2589") < 500, "and knows the cheapest other seller (" .. tostring(AH.LowestOther("2589")) .. " each against your 500)")
  getglobal("pfAuction"):Hide()
end

AH.open, AH.scan, AH.job, AH.fetch, AH.pending, AH.rows = false, nil, nil, nil, nil, {}
pfUI_cache.auction = cacheWas
for _, k in ipairs(NAMES) do _G[k] = keep[k] end

-- (17 Nov 2026) Escape and the game menu: the game's auction window goes through the panel list, and a
-- panel slot left holding a hidden window is emptied before Escape counts it
do
  local E = pfUI.escapefix
  ok(E and E.ClearStale, "escapefix loaded")
  if E then
    local hideWas = rawget(_G, "HideUIPanel")
    local through
    _G.HideUIPanel = function(f) through = f UIParent.doublewide = nil f:Hide() end
    local a = CreateFrame("Frame", "AuctionFrameEscTest", UIParent)
    a:Show()
    UIParent.doublewide = a
    AH.HideGame(a)
    ok(through == a and not a:IsShown() and UIParent.doublewide == nil, "the game's auction window is hidden through HideUIPanel")
    _G.HideUIPanel = hideWas
    local b = CreateFrame("Frame", nil, UIParent)
    b:Hide()
    UIParent.left = b
    local c = CreateFrame("Frame", nil, UIParent)
    c:Show()
    UIParent.center = c
    ok(E.ClearStale() == 1 and UIParent.left == nil and UIParent.center == c, "a slot holding a hidden window is emptied, a shown one kept")
    UIParent.center = nil
  end
end
