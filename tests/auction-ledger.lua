-- pfUI Octo: auction house phase 3 (modules/auction-ledger.lua + the Deals / Ledger tabs),
-- run by tests\run.lua: a sale told by the game, priced from what was up, confirmed by the
-- mail; purchases; deals; net worth; prices shared.
local ok = octo_ok
local AH = pfUI.auction
local L = AH and AH.ledger
ok(L and L.System and L.ReadMail and L.DealFilter and L.Worth, "ledger loaded (pfUI.auction.ledger)")
if not L then return end
local S = pfUI_config.auction
ok(S.salealert == "1" and S.share == "1" and S.dealpct == "70", "defaults (sale alerts, sharing, deals at 70%)")

local NAMES = { "GetRealmName", "UnitFactionGroup", "UnitName", "time", "GetTime", "GetMoney", "PlaySound", "GetNumAuctionItems", "GetAuctionItemInfo",
  "GetAuctionItemLink", "GetAuctionItemTimeLeft", "GetInboxNumItems", "GetInboxInvoiceInfo", "GetInboxHeaderInfo", "GetContainerNumSlots",
  "GetContainerItemLink", "GetContainerItemInfo", "IsInGuild", "GetNumRaidMembers", "GetNumPartyMembers", "SendAddonMessage", "pfSellData" }
local keep = {}
for _, k in ipairs(NAMES) do keep[k] = rawget(_G, k) end
local cacheWas = pfUI_cache.auction
pfUI_cache.auction = nil
local now, clock = 2000000000, 500
_G.time = function() return now end
_G.GetTime = function() return clock end
_G.GetRealmName = function() return "Octo" end
_G.UnitFactionGroup = function() return "Horde" end
_G.UnitName = function() return "Me" end
_G.GetMoney = function() return 500000 end
local sounds = 0
_G.PlaySound = function() sounds = sounds + 1 end

-- what you have up: two Linen Cloth stacks (20 for 10s, 20 for 12s) and a Copper Bar
local up = { { "Linen Cloth", 20, 900, 1000, 0 }, { "Linen Cloth", 20, 1100, 1200, 0 }, { "Copper Bar", 5, 400, 0, 450 } }
_G.GetNumAuctionItems = function(kind) return kind == "owner" and table.getn(up) or 0, table.getn(up) end
_G.GetAuctionItemInfo = function(kind, i)
  local a = up[i]
  if kind ~= "owner" or not a then return nil end
  return a[1], "tex", a[2], 1, 1, 0, a[3], 50, a[4], a[5], nil, "Me"
end
_G.GetAuctionItemLink = function(kind, i) return up[i] and ("|Hitem:" .. (up[i][1] == "Copper Bar" and 2840 or 2589) .. ":0:0:0|h[" .. up[i][1] .. "]|h") end
_G.GetAuctionItemTimeLeft = function() return 4 end
local mine = L.Snapshot()
ok(mine["Linen Cloth"] and table.getn(mine["Linen Cloth"]) == 2 and mine["Copper Bar"][1].high == 450, "what you have up is noted, to price a sale")

-- the game says it sold: the cheapest stack, less the auction house's cut, with a coin sound
ok(L.System("A buyer has been found for your auction of Linen Cloth.") == "sold", "the game's line is read")
local e = L.Entries()[1]
ok(e and e.k == "sold" and e.n == "Linen Cloth" and e.c == 20 and e.a == 950 and e.est == 1, "a sale is in the ledger at once: 20 for about 9s 50c (1000 less 5%)")
ok(sounds == 1, "with a coin sound")
ok(table.getn(pfUI_cache.auction["Octo-Horde"].mine["Linen Cloth"]) == 1, "and that stack is off the list of what is up")
-- an auction with a bid and no buyout sells at the bid
L.System("A buyer has been found for your auction of Copper Bar.")
ok(L.Entries()[2].a == math.floor(450 * .95), "no buyout: sold at the high bid")
S.salesound = "0"
L.System("Your auction of Linen Cloth has expired.")
ok(L.Entries()[3].k == "expired" and L.Entries()[3].a == 0 and sounds == 2 and pfUI_cache.auction["Octo-Horde"].mine["Linen Cloth"] == nil, "an expiry is noted without gold")
S.salesound = "1"
ok(L.System("You have been outbid on Thorium Bar.") == "outbid" and L.System("Hello there") == nil, "outbid is noted; other lines are left alone")

-- the mail gives the exact gold: the estimate is replaced, not added again
local mail = { { "seller", "Linen Cloth", "Buyer", 1000, 1000, 60, 50, 29.99 } }
_G.GetInboxNumItems = function() return table.getn(mail) end
_G.GetInboxInvoiceInfo = function(i) local m = mail[i] if m then return m[1], m[2], m[3], m[4], m[5], m[6], m[7] end end
_G.GetInboxHeaderInfo = function(i) return nil, nil, "Auction House", "x", 0, 0, mail[i][8] end
ok(L.ReadMail() == 1 and e.a == 1010 and e.est == nil and e.who == "Buyer", "the mail's invoice gives the exact gold (bid + deposit - cut) and the buyer")
local n = table.getn(L.Entries())
now = now + 600
mail[1][8] = 29.99 - 600 / 86400
ok(L.ReadMail() == 0 and table.getn(L.Entries()) == n, "the same mail read again changes nothing")
-- a purchase: buyouts are exact at once, a won bid is priced from the bid
AH.onBought({ name = "Silk Cloth", count = 10 }, "buyout", 3000)
AH.onBought({ name = "Mageweave Cloth", count = 5 }, "bid", 2500)
L.System("You won an auction for Mageweave Cloth")
local last = L.Entries()[table.getn(L.Entries())]
ok(last.k == "won" and last.a == -2500, "a won bid costs what you bid")
table.insert(mail, { "buyer", "Silk Cloth", "Seller", 3000, 3000, 0, 0, 29.5 })
n = table.getn(L.Entries())
ok(L.ReadMail() == 1 and table.getn(L.Entries()) == n, "the mail for a buyout already noted adds no second line")
local sum = L.Sum(86400)
ok(sum.sold == 1010 + math.floor(450 * .95) and sum.spent == 5500 and sum.sales == 2 and sum.buys == 2 and sum.net == sum.sold - sum.spent,
  "today's totals: sold " .. sum.sold .. ", spent " .. sum.spent)
now = now + 10 * 86400
ok(L.Sum(86400).sold == 0 and L.Sum().sold == sum.sold, "older lines fall out of \"today\" but stay in the ledger")

-- deals: under 70% of a price known for 3 days, with a profit after the cut
local day = AH.Day()
pfUI_cache.auction["Octo-Horde"].h["2589"] = { day = day, min = 100, days = { 100, 100, 100 } }
pfUI_cache.auction["Octo-Horde"].h["2840"] = { day = day, min = 500, days = {} }
local filter = L.DealFilter(70, 100, 3)
local cheap = { key = "2589", unit = 50, count = 20 }
ok(filter(cheap) == true and cheap.value == 100 and cheap.profit == (95 - 50) * 20 and cheap.share == .5, "a stack at half its usual price is a deal: profit " .. tostring(cheap.profit))
ok(filter({ key = "2589", unit = 80, count = 20 }) == false, "80% of usual is not")
ok(filter({ key = "2840", unit = 100, count = 1 }) == false, "a price seen on one day only does not count")
ok(filter({ key = "2589", unit = 60, count = 1 }) == false and filter({ key = "2589", count = 1 }) == false, "nor a profit under the floor, nor an auction with no buyout")

-- what you are worth: gold + bags at the usual price + what is up, less the cut
local bags = { { 2589, 40 }, { 9999, 3 } }
_G.GetContainerNumSlots = function(bag) return bag == 0 and table.getn(bags) or 0 end
_G.GetContainerItemLink = function(bag, slot) local s = bags[slot] return s and ("|cffffffff|Hitem:" .. s[1] .. ":0:0:0|h[Thing" .. s[1] .. "]|h|r") end
_G.GetContainerItemInfo = function(bag, slot) local s = bags[slot] if s then return "tex", s[2], nil end end
_G.pfSellData = { [9999] = "30,120" }
AH.onPosted({ key = "2589", name = "Linen Cloth", size = 20, bid = 900, buyout = 1000, minutes = 1440 })
local w = L.Worth()
ok(w.gold == 500000 and w.bags == 40 * 100 + 3 * 30 and w.up == 950 and w.total == 500000 + 4090 + 950,
  "worth: gold, bags at the usual price (vendor price when unknown), auctions up less the cut (" .. w.bags .. " + " .. w.up .. ")")
ok(L.PriceLine("[Linen Cloth]", "2589") == "[Linen Cloth]: usual 1s each (4 days)" and string.find(L.PriceLine(nil, "1", "Odd"), "no price known"), "a price line for chat")

-- sharing: a new low of your own scan goes out, others' come in and do not go round again
pfUI_cache.auction["Octo-Horde"].h = {}
L.out, L.outN = {}, 0
AH.Record("2589", 120)
AH.Record("2589", 110)
AH.Record("2589", 130)
ok(L.outN == 1 and L.out["2589"] == 110, "the day's low of an item waits to be shared, once")
local msg = L.Pack()
ok(msg == "Octo-Horde^" .. AH.Day() .. "^2589=110" and not string.find(msg, "|", 1, true) and L.outN == 0, "packed as realm, day and prices (" .. tostring(msg) .. ")")
ok(L.Receive("Octo-Horde^" .. AH.Day() .. "^2840=450,7911:1200=99000,bad=1", "Khijazi") == 2 and AH.Value("2840") == 450 and AH.Value("7911:1200") == 99000,
  "another player's prices are taken")
ok(L.outN == 0, "and not sent on again")
ok(L.Receive("Other-Horde^" .. AH.Day() .. "^2840=1", "Khijazi") == 0 and L.Receive("Octo-Horde^" .. (AH.Day() - 1) .. "^2840=1", "Khijazi") == 0
  and L.Receive("Octo-Horde^" .. AH.Day() .. "^2840=1", "Me") == 0 and AH.Value("2840") == 450, "not from another realm, another day, or yourself")
S.share = "0"
AH.Record("4306", 500)
ok(L.outN == 0 and L.Receive("Octo-Horde^" .. AH.Day() .. "^2840=1", "Khijazi") == 0, "sharing off: nothing out, nothing in")
S.share = "1"

-- the two new tabs draw
do
  local UI = AH.ui
  AH.rows = { cheap }
  cheap.name, cheap.owner, cheap.left, cheap.buyout, cheap.next, cheap.minBid, cheap.bid = "Linen Cloth", "Seller", 3, 1000, 900, 900, 0
  cheap.level, cheap.quality, cheap.bidunit, cheap.kind, cheap.page, cheap.index = 0, 1, 45, "list", 0, 1
  local good, err = pcall(function()
    AH.Show()
    UI.Open("deals")
    UI.Open("ledger")
    UI.ledgerShow = "sold"
    UI.PaintLedger()
  end)
  ok(good and UI.pages.deals and UI.pages.ledger, "the Deals and Ledger tabs draw " .. tostring(err or ""))
  ok(table.getn(UI.lists.deals.data) == 1 and UI.lists.deals.data[1].profit == cheap.profit, "Deals lists the deal with its profit")
  local sold = 0
  for _, d in ipairs(UI.lists.ledger.data) do if d.k == "sold" then sold = sold + 1 end end
  ok(sold == 2 and table.getn(UI.lists.ledger.data) == 2, "the Ledger's Sold filter shows the two sales")
  pfUI_cache.auction["Octo-Horde"].h["2589"] = { day = AH.Day(), min = 110, days = { 90, 100, 120 } }
  ok(UI.pages.sell.chart and UI.pages.sell.chart.Set("2589") == 4 and UI.pages.sell.chart.bars[4]:IsShown() and not UI.pages.sell.chart.bars[5]:IsShown(),
    "the price chart draws a bar per day seen")
  AH.open = false
  getglobal("pfAuction"):Hide()
end

AH.rows, AH.scan = {}, nil
L.out, L.outN = {}, 0
pfUI_cache.auction = cacheWas
for _, k in ipairs(NAMES) do _G[k] = keep[k] end

-- item names offered while typing (16 Nov 2026)
do
  local AH = pfUI.auction
  local dbWas, cacheWas2 = rawget(_G, "pfDB"), pfUI_cache.auction
  pfUI_cache.auction = nil
  _G.pfDB = { items = { enUS = { [6470] = "Deviate Scale", [6522] = "Deviate Fish", [6471] = "Perfect Deviate Scale", [10] = "OLD Deviate Thing",
    [11] = "Scale of Onyxia", [12] = "Linen Cloth" }, ["enUS-turtle"] = { [90001] = "Deviate Delight Recipe", [6522] = "Deviate Fish" } } }
  AH.names = nil
  AH.Store().h["6522"] = { day = AH.Day(), min = 50, days = {} }
  local list = AH.Complete("deviate", 10)
  ok(table.getn(list) == 4 and list[1] == "Deviate Fish", "typing \"deviate\" offers four names, the one seen on the auction house first (" .. table.concat(list, ", ") .. ")")
  ok(list[2] == "Deviate Scale" and list[3] == "Deviate Delight Recipe" and list[4] == "Perfect Deviate Scale", "then names starting with it (shortest first), then names holding it")
  ok(table.getn(AH.Complete("d", 10)) == 0 and table.getn(AH.Complete("zzz", 10)) == 0, "one letter or no match: nothing offered")
  ok(table.getn(AH.Complete("scale", 2)) == 2 and AH.Complete("scale", 2)[1] == "Scale of Onyxia" and AH.Complete("scale", 2)[2] == "Deviate Scale", "a name starting with it, then a later word starting with it; the list is capped")
  local UI = AH.ui
  local B = UI.pages.browse
  ok(B.sug and B.sg and B.sg.Take, "the Browse box has its name list")
  local h, n, t = UI.NamePart("linen cloth/exact; devi/max 2s")
  ok(h == "linen cloth/exact;" and n == " devi" and t == "/max 2s", "the name being typed is the part after the last ; and before its /")
  local searched
  local realSearch = AH.Search
  AH.Search = function(q, a, b, queue) searched = { q, queue } end
  B.name:SetText("linen cloth/exact; devi/max 2s")
  B.sg.Update()
  ok(table.getn(B.sg.list) == 4 and B.sug:IsShown(), "the list shows under the box")
  B.sg.Step(1)
  B.sg.Step(1)
  ok(B.sg.sel == 2, "Tab / arrow keys walk the list")
  UI.EnterName()
  ok(B.name:GetText() == "linen cloth/exact; Deviate Scale/max 2s" and not B.sug:IsShown(), "Enter takes the picked name and keeps the rest of the box (" .. tostring(B.name:GetText()) .. ")")
  ok(searched and searched[1].name == "linen cloth" and searched[2][1].name == "Deviate Scale" and searched[2][1].maxUnit == 200, "and searches")
  B.name:SetText("Deviate Fish")
  B.sg.Update()
  ok(table.getn(B.sg.list) == 0, "a name typed in full is not offered again")
  pfUI_config.auction.suggest = "0"
  B.name:SetText("devi")
  B.sg.Update()
  ok(table.getn(B.sg.list) == 0, "switched off: no list")
  pfUI_config.auction.suggest = "1"
  B.name:SetText("")
  AH.Search = realSearch
  AH.names = nil
  _G.pfDB = dbWas
  pfUI_cache.auction = cacheWas2
end

-- shopping lists, the folded results, the stack column (16 Nov 2026)
do
  local AH = pfUI.auction
  local cacheWas3 = pfUI_cache.auction
  pfUI_cache.auction = nil
  local lists = AH.Lists()
  ok(table.getn(lists) == 1 and lists[1].name == "Shopping list", "one empty shopping list to start with")
  local l, i = AH.ListNew("  Alchemy ")
  ok(l and i == 2 and l.name == "Alchemy" and AH.ListNew("  ") == nil, "a new list by name")
  ok(AH.ListAdd(2, "Deviate Scale/exact") and AH.ListAdd(2, "briarthorn/max 5s") and AH.ListAdd(2, "DEVIATE scale/exact") == false and AH.ListAdd(2, " ") == false,
    "searches added once each")
  local text = AH.ListExport(2)
  ok(text == "Alchemy^Deviate Scale/exact^briarthorn/max 5s" and not string.find(text, "|", 1, true), "a list as one line of text (" .. text .. ")")
  local l2, i2 = AH.ListImport("Tailoring ^ Linen Cloth/exact^Wool Cloth")
  ok(l2 and i2 == 3 and l2.name == "Tailoring" and table.getn(l2.terms) == 2 and l2.terms[2] == "Wool Cloth" and AH.ListImport("just a name") == nil, "and read back in")
  local got
  local realSearch = AH.Search
  AH.Search = function(q, a, b, queue) got = { q, queue } end
  ok(AH.SearchList(2) == true and got[1].name == "Deviate Scale" and got[1].exact and got[2][1].name == "briarthorn" and got[2][1].maxUnit == 500,
    "a list runs all its searches in a row")
  ok(AH.SearchList(1) == false, "an empty list does not search")
  AH.Search = realSearch
  local groups = AH.Group({
    { key = "1", name = "Deviate Scale", count = 2, unit = 500, tex = "t" }, { key = "1", name = "Deviate Scale", count = 17, unit = 824 },
    { key = "1", name = "Deviate Scale", count = 1 }, { key = "2", name = "Briarthorn", count = 20, unit = 90 } })
  ok(table.getn(groups) == 2 and groups[1].name == "Briarthorn" and groups[2].count == 20 and groups[2].auctions == 3 and groups[2].low == 500,
    "results fold into one line an item: 20 Deviate Scale in 3 auctions, cheapest 5s")
  local UI = AH.ui
  local good, err = pcall(function()
    AH.Show()
    UI.Open("shop")
    UI.shop, UI.shopRan = 2, true
    AH.rows = { { key = "1", name = "Deviate Scale", count = 2, unit = 500, tex = "t", quality = 1, level = 0, left = 4, owner = "Teff", buyout = 1000, bid = 0,
      minBid = 900, next = 900, bidunit = 450, kind = "list", page = 0, index = 1 } }
    UI.PaintShop()
  end)
  ok(good and UI.lists.shop and table.getn(UI.lists.shop.data) == 1 and table.getn(UI.pages.shop.terms.data) == 2, "the Shopping tab draws its lists, searches and folded results " .. tostring(err or ""))
  local bl = UI.lists.browse
  UI.only = "nothing"
  UI.Open("browse")
  ok(table.getn(bl.data) == 0, "an item clicked on the Shopping tab shows only its auctions on Browse")
  UI.only = nil
  UI.Open("browse")
  ok(table.getn(bl.data) == 1 and bl.rows[1].stack and bl.rows[1].stack:GetText() == "2" and bl.rows[1].cell[1]:GetText() == "Deviate Scale",
    "the stack's size has its own column; the name stands alone (" .. tostring(bl.rows[1].cell[1]:GetText()) .. ")")
  ok(string.find(UI.Left(1), "under 30 min", 1, true) and string.find(UI.Left(1), "|cffff5a4a", 1, true) and UI.Left(9) == "", "time left is coloured, red when nearly over")
  ok(UI.Seller("Me") ~= "Me" and UI.Seller("Teff") == "Teff" and UI.Seller(nil) == "", "your own name stands out in the seller column")
  AH.rows = {}
  AH.open = false
  getglobal("pfAuction"):Hide()
  pfUI_cache.auction = cacheWas3
end

-- the Shopping tab's Add box offers names the same way: a picked one goes on the list at once
do
  local AH = pfUI.auction
  local UI = AH.ui
  local H = UI.pages.shop
  local dbWas, cacheWas4 = rawget(_G, "pfDB"), pfUI_cache.auction
  pfUI_cache.auction = nil
  _G.pfDB = { items = { enUS = { [6470] = "Deviate Scale", [6522] = "Deviate Fish" } } }
  AH.names = nil
  UI.shop = 1
  ok(H.sg and H.sg.frame, "the Add box has its own name list")
  H.add:SetText("devi")
  H.sg.Update()
  ok(table.getn(H.sg.list) == 2 and H.sg.frame:IsShown(), "typing in it offers the names")
  H.sg.Step(1)
  H.sg.Enter()
  local terms = AH.Lists()[1].terms
  ok(table.getn(terms) == 1 and terms[1] == "Deviate Fish/exact" and (H.add:GetText() or "") == "" and not H.sg.frame:IsShown(),
    "a picked name goes on the list as that exact item, and the box is empty for the next (" .. tostring(terms[1]) .. ")")
  H.add:SetText("silk cloth/max 2s")
  H.sg.Update()
  H.sg.Enter()
  ok(table.getn(terms) == 2 and terms[2] == "silk cloth/max 2s", "Enter with none picked adds what is typed")
  H.add:SetText("")
  AH.names = nil
  _G.pfDB = dbWas
  pfUI_cache.auction = cacheWas4
end

-- the game's own auction tabs stay quiet while hidden (16 Nov 2026, in game: Blizzard_AuctionUI.lua:836
-- "arithmetic on field 'page'" when My auctions asked for the owner list)
do
  local AH = pfUI.auction
  local names = { "AuctionFrame", "AuctionFrameBrowse", "AuctionFrameBid", "AuctionFrameAuctions",
    "AuctionFrameBrowse_OnEvent", "AuctionFrameBid_OnEvent", "AuctionFrameAuctions_OnEvent", "IsAddOnLoaded" }
  local was = {}
  for _, k in ipairs(names) do was[k] = rawget(_G, k) end
  local calls = 0
  local function Tab(shown) return { IsVisible = function() return shown end } end
  _G.AuctionFrame = { UnregisterEvent = function() end, SetScript = function() end }
  _G.AuctionFrameBrowse, _G.AuctionFrameBid, _G.AuctionFrameAuctions = Tab(false), Tab(false), Tab(true)
  _G.AuctionFrameAuctions.page = 3
  for _, n in ipairs({ "AuctionFrameBrowse", "AuctionFrameBid", "AuctionFrameAuctions" }) do
    _G[n .. "_OnEvent"] = function() calls = calls + 1 return n end
  end
  _G.IsAddOnLoaded = function() return nil end
  AH.ev:GetScript("OnEvent")(AH.ev, "ADDON_LOADED", "Blizzard_AuctionUI")
  local okEv = true
  if AH.ev.GetScript and AH.ev:GetScript("OnEvent") then
    local e, a = _G.event, _G.arg1
    _G.event, _G.arg1 = "ADDON_LOADED", "Blizzard_AuctionUI"
    AH.ev:GetScript("OnEvent")()
    _G.event, _G.arg1 = e, a
  else okEv = false end
  ok(okEv and _G.AuctionFrameBrowse.page == 0 and _G.AuctionFrameBid.page == 0 and _G.AuctionFrameAuctions.page == 3,
    "the game's tabs start on page 0; one already set keeps its page")
  _G.AuctionFrameBid_OnEvent()
  _G.AuctionFrameBrowse_OnEvent()
  ok(calls == 0, "a hidden game tab ignores the list events")
  ok(_G.AuctionFrameAuctions_OnEvent() == "AuctionFrameAuctions" and calls == 1, "a shown one works as ever")
  for _, k in ipairs(names) do _G[k] = was[k] end
end
