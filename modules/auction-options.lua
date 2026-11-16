pfUI:RegisterModule("auction-options", "vanilla", function ()
  -- pfUI Octo :: the Auctions section (15 Nov 2026, modules/auction.lua + auction-window.lua).
  -- Its own module so the section - and its on / off switch - stays when the auction house is
  -- switched off (then neither the engine nor the window is made).
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local function AH() return pfUI.auction end
  local function G() return C.auction end
  local function Pct(v) return math.floor(v * 100 + .5) .. "%" end

  local function Build(p)
    local ah = AH()
    W.Heading(p, "Auction house", { on = O.ModuleSwitch("auction", "The auction house"),
      about = "pfUI Octo's own auction window, in place of the game's at an auctioneer: search every page at once and sort by "
        .. "price each, bid or buy out, sell stacks of any size at a price taken from what is up now, see and cancel your "
        .. "auctions, and bid again where you were outbid. It remembers what things sell for. Off = the game's own window "
        .. "(or another auction add-on), and nothing of this is loaded." })
    if not ah then
      W.Note(p, "The auction house is off. Use the switch at the top right to turn it back on (takes a reload).")
      return
    end
    W.Live(p, function()
      local other = ah.Other()
      local s = other and ("|cffffcc00" .. other .. " is also switched on: it keeps the auction window and ours stands aside.|r")
        or "|cff55ff55On: it opens when you talk to an auctioneer.|r"
      return s .. "   Prices known: |cffffffff" .. ah.Known() .. "|r items"
    end)
    if ah.Other() then
      W.Buttons(p, { { "Switch " .. ah.Other() .. " off", function()
        if DisableAddOn then DisableAddOn(ah.Other()) end
        pfUI.gui.settingChanged = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r auction house: the other add-on is switched off from the next reload.")
      end, 190, "Turns the other auction add-on off (from the next reload) so pfUI Octo's opens. Its folder and saved data stay.", role = "off" } })
    end

    W.Card(p, "Selling", { icon = "Interface\\Icons\\INV_Misc_Coin_02", tip = "What the Sell tab fills in for you." })
    O.PfSld(p, "Undercut by", "How far under the cheapest other seller \"Undercut cheapest\" goes: copper, or percent with the box below.", 0, 100, 1, G, "undercut")
    O.PfChk(p, "Undercut in percent", "Off: the number above is copper. On: it is a share of their price.", G, "undercutpct")
    O.PfSld(p, "Starting price", "The starting price as a share of the buyout, when you only fill in a buyout.", 50, 100, 1, G, "bidshare", nil, function(v) return v .. "%" end)
    W.Dropdown(p, "Auctions last", "The length picked when an item has no saved choice.",
      { { key = "2", label = "2 hours" }, { key = "8", label = "8 hours" }, { key = "24", label = "24 hours" } },
      function() return G().hours or "24" end, function(v) G().hours = v end)
    O.PfChk(p, "Start with every stack I have", "Off: the number of stacks starts at 1.", G, "allstacks")
    O.PfChk(p, "Look prices up when I pick an item", "Picking an item on the Sell tab searches the auction house for it at once.", G, "autolookup")

    W.Card(p, "Window", { icon = "Interface\\Icons\\INV_Misc_Note_01", tip = "Drag its title bar to move it; the place is kept." })
    O.PfSld(p, "Size", nil, .6, 1.4, .05, G, "scale", nil, Pct)
    O.PfChk(p, "Open on the tab I was on", "Off: it always opens on Browse.", G, "lasttab")
    O.PfChk(p, "Right-click a bag item to sell it", "While the auction window is up, right-clicking an item in your bags puts it on the Sell tab.", G, "bagclick")
    O.PfChk(p, "Auction price in item tooltips", "An item's usual auction price (each, and for the stack) in its tooltip, everywhere.", G, "tooltip")
    W.Buttons(p, { { "Back to its first place", function() G().x, G().y = "", "" end, 170, "Forget where you dragged the window." } })

    W.Card(p, "Sales, ledger and sharing", { icon = "Interface\\Icons\\INV_Misc_Coin_01",
      tip = "The Ledger tab notes every sale, purchase, expiry and outbid as it happens; the auction house's mail then gives the exact gold." })
    O.PfChk(p, "Tell me when something sells", "A line in the middle of the screen and in chat the moment a buyer is found - also when you are won or outbid on a bid - wherever you are.", G, "salealert")
    O.PfChk(p, "With a coin sound", nil, G, "salesound")
    O.PfChk(p, "Share prices with guild and group", "The day's lowest prices your searches see go to other pfUI Octo players in your guild and group, and theirs come to you: everyone's price history fills faster.", G, "share")
    W.Live(p, function()
      local L = ah.ledger
      if not L then return "|cffffcc00The ledger part is not loaded (restart the game once after updating).|r" end
      local s = L.Sum(7 * 86400)
      return "Last 7 days: sold |cffffffff" .. ah.Money(s.sold, true) .. "|r in " .. s.sales .. " sales, spent |cffffffff" .. ah.Money(s.spent, true)
        .. "|r.   Prices from others this session: |cffffffff" .. (L.got or 0) .. "|r"
    end)
    W.Buttons(p, { { "Empty the ledger", function()
      if ah.sureL and GetTime() < ah.sureL then
        ah.sureL = nil
        ah.Store().ledger = {}
      else
        ah.sureL = GetTime() + 3
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r auction house: click Empty the ledger again within 3 s.")
      end
    end, 150, "Click twice: every line of the ledger of this realm and faction is dropped.", role = "off" } })

    W.Card(p, "Speed", { icon = "Interface\\Icons\\Spell_Nature_TimeStop", tip = "Why a full search is fast or slow." })
    W.Note(p, "The game makes every auction search wait 5 seconds after the one before. The small AuctionQueryThrottle DLL "
      .. "takes that wait away, so a search of every page runs as fast as the server answers. \"Install pfUI Octo DLLs.bat\" in "
      .. "the pfUI folder installs it with the others (game closed). Without it everything here still works, a page every 5 seconds.")

    W.Card(p, "Price history", { icon = "Interface\\Icons\\INV_Misc_PocketWatch_01", tip = "Per realm and faction, for all your characters." })
    W.Note(p, "Every search notes the cheapest buyout of each item it sees, one figure a day. An item's usual price is the middle of its "
      .. "last days, so one silly auction does not move it. The Browse tab's last column shows each auction against that price.")
    W.Buttons(p, { { "Forget all prices", function()
      if ah.sureAt and GetTime() < ah.sureAt then
        ah.sureAt = nil
        ah.Store().h = {}
      else
        ah.sureAt = GetTime() + 3
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r auction house: click Forget all prices again within 3 s.")
      end
    end, 150, "Click twice: the price history of this realm and faction is dropped.", role = "off" } })
    W.Note(p, "Search words: the search box takes several searches at once, split by \";\", each with words after \"/\": "
      .. "|cffffffffexact|r, |cffffffffusable|r, |cffffffffuncommon|r / |cffffffffrare|r / |cffffffffepic|r (and better), "
      .. "|cffffffff20-30|r (levels), |cffffffffmax 1g 20s|r (price each), or a kind of item (|cffffffffweapon|r, |cffffffffarmor|r...). "
      .. "Example: |cffffd24dlinen cloth/exact; silk cloth/max 2s; /rare/40-50/weapon|r. \"Saved\" keeps the ones you use often.")
    W.Note(p, "In the window: Alt + click a row buys it out at once, Ctrl + click bids, Shift + click links the item in chat. "
      .. "\"Game window\" in its title bar shows the game's own auction window beside it.")
  end

  O:AddPage("Auctions", "auction", "Auction house", Build)
end)
