pfUI:RegisterModule("professions-profit", "vanilla", function ()
  -- pfUI Octo :: what a craft costs against what it sells for (25 Nov 2026, Wolfahrt on Discord: "the total price of comp
  -- VS the selling price of the crafted item (and raw gold difference). Even better: to also classify crafts by this added
  -- raw gold difference"). Prices from pfUI's auction house (AH.Value: the usual buyout each, from every search and scan
  -- you or your guild made), else the vendor's price (pfSellData "sell,buy": reagents a vendor sells cost its buy price;
  -- a crafted item nobody has seen on the auction house is worth its vendor sell price). In the profession windows:
  --   the picked recipe   "Cost 1g 20s   Sells 2g 50s   Profit +1g 30s" under its "Requires" line
  --   every recipe row    the profit (green / red) at the row's right end, so the best crafts stand out
  -- Enchants make no item: cost only. Nothing known = left out, never a guess. C.charframe.profit ("1").
  local PO = pfUI.professionsOcto
  if not PO then return end
  local PP = {}
  pfUI.professionsProfit = PP
  local function On() return C.charframe.prof ~= "0" and C.charframe.profit ~= "0" end
  local function AH() return pfUI.auction end

  -- the two windows' calls
  local T, Cr = PO.KINDS.TradeSkill, PO.KINDS.Craft
  T.itemLink = function(i) return GetTradeSkillItemLink and GetTradeSkillItemLink(i) end
  T.numReagents = function(i) return GetTradeSkillNumReagents and GetTradeSkillNumReagents(i) or 0 end
  T.reagent = function(i, r)
    local _, _, count = GetTradeSkillReagentInfo(i, r)
    return GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, r), count
  end
  T.made = function(i)
    if not GetTradeSkillNumMade then return 1 end
    local lo, hi = GetTradeSkillNumMade(i)
    lo, hi = tonumber(lo) or 1, tonumber(hi) or tonumber(lo) or 1
    return (lo + hi) / 2
  end
  T.selected = function() return GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex() end
  T.reqLabel = { "TradeSkillRequirementLabel", "TradeSkillSkillName" }
  Cr.itemLink = function(i) return GetCraftItemLink and GetCraftItemLink(i) end
  Cr.numReagents = function(i) return GetCraftNumReagents and GetCraftNumReagents(i) or 0 end
  Cr.reagent = function(i, r)
    local _, _, count = GetCraftReagentInfo(i, r)
    return GetCraftReagentItemLink and GetCraftReagentItemLink(i, r), count
  end
  Cr.made = function() return 1 end
  Cr.selected = function() return GetCraftSelectionIndex and GetCraftSelectionIndex() end
  Cr.reqLabel = { "CraftRequirementsLabel", "CraftName" }

  -- one item's price each: the auction house's usual price, else the vendor's (buy for a reagent, sell for a product)
  function PP.Price(link, buying)
    local ah = AH()
    if not ah or not ah.ItemKey then return nil end
    local key = ah.ItemKey(link)
    if not key then return nil end
    local v = ah.Value and ah.Value(key)
    if v and v > 0 then return v, "ah" end
    local _, _, id = string.find(key, "^(%d+)")
    local data = rawget(_G, "pfSellData")
    local line = id and type(data) == "table" and data[tonumber(id)]
    if type(line) == "string" then
      local _, _, sell, buy = string.find(line, "^(%-?%d+),?(%-?%d*)")
      sell, buy = tonumber(sell), tonumber(buy)
      -- (only for reagents a vendor really sells: every item has a buy price in the table)
      local db = rawget(_G, "pfDB")
      local d = type(db) == "table" and db.items and db.items.data and db.items.data[tonumber(id)]
      local sold = not (type(db) == "table" and db.items and db.items.data) or (type(d) == "table" and d.V)
      if buying and sold and buy and buy > 0 then return buy, "vendor" end
      if not buying and sell and sell > 0 then return sell, "vendor" end
    end
    return nil
  end

  -- { cost, value, profit, missing (reagents without a price), enchant (makes no item) } for recipe line i
  function PP.Craft(k, i)
    if not k.numReagents then return nil end
    local cost, missing = 0, 0
    for r = 1, k.numReagents(i) do
      local link, count = k.reagent(i, r)
      local each = link and PP.Price(link, true)
      if each then cost = cost + each * (tonumber(count) or 1) else missing = missing + 1 end
    end
    local out = { cost = cost, missing = missing }
    local link = k.itemLink(i)
    if not link or not string.find(link, "item:%d+") then
      out.enchant = true
      return out
    end
    local each, from = PP.Price(link, false)
    if each then
      out.value = each * k.made(i)
      out.from = from
      if missing == 0 then out.profit = out.value - cost end
    end
    return out
  end

  -- "1g 20s" short; signed when asked
  function PP.Short(c, signed)
    c = math.floor((tonumber(c) or 0) + .5)
    local sign = ""
    if signed then sign = c < 0 and "-" or "+" end
    c = math.abs(c)
    local g, s, cu = math.floor(c / 10000), math.floor(math.mod(c, 10000) / 100), math.mod(c, 100)
    local t
    if g > 0 then t = g .. "g" .. (s > 0 and (" " .. s .. "s") or "")
    elseif s > 0 then t = s .. "s" .. (cu > 0 and (" " .. cu .. "c") or "")
    else t = cu .. "c" end
    return sign .. t
  end

  -- the picked recipe's line
  function PP.Detail(k)
    local f = _G[k.frame]
    if not f or not f.octoProf then return end
    if not f.octoProfit then
      local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      fs:SetJustifyH("LEFT")
      f.octoProfit = fs
    end
    local fs = f.octoProfit
    local i = k.selected()
    local anchor
    for _, n in ipairs(k.reqLabel) do if not anchor and _G[n] then anchor = _G[n] end end
    if not On() or not i or i < 1 or not anchor or (k.info and k.info(i) == "header") then fs:Hide() return end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    local c = PP.Craft(k, i)
    if not c then fs:Hide() return end
    local parts = {}
    table.insert(parts, "|cffaaaaaaCost|r " .. (c.missing > 0 and ("|cff888888?|r") or PP.Short(c.cost)))
    if c.value then table.insert(parts, "|cffaaaaaaSells|r " .. PP.Short(c.value) .. (c.from == "vendor" and " |cff888888(vendor)|r" or "")) end
    if c.profit then
      table.insert(parts, "|cffaaaaaaProfit|r " .. (c.profit >= 0 and "|cff55ff55" or "|cffff5a4a") .. PP.Short(c.profit, true) .. "|r")
    end
    fs:SetText(table.concat(parts, "    "))
    fs:Show()
  end

  -- every shown recipe row: its profit at the right end
  function PP.Rows(k)
    for idx = 1, (_G[k.displayed] or 0) do
      local b = _G[k.row .. idx]
      if b then
        if not b.octoProfit then
          b.octoProfit = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
          b.octoProfit:SetPoint("RIGHT", b, "RIGHT", -4, 0)
          b.octoProfit:SetJustifyH("RIGHT")
        end
        local id = b:GetID()
        local show
        if On() and b:IsShown() and id and id > 0 and k.info and k.info(id) ~= "header" then
          local c = PP.Craft(k, id)
          if c and c.profit then
            b.octoProfit:SetText((c.profit >= 0 and "|cff55ff55" or "|cffff5a4a") .. PP.Short(c.profit, true) .. "|r")
            show = true
          end
        end
        if show then b.octoProfit:Show() else b.octoProfit:Hide() end
      end
    end
  end

  for _, kk in pairs(PO.KINDS) do
    local k = kk
    local function Hook()
      local f = _G[k.frame]
      if not f or f.octoProfitHook then return end
      f.octoProfitHook = true
      if hooksecurefunc and _G[k.update] then
        hooksecurefunc(k.update, PO.Guard("craft profit", function() PP.Rows(k) PP.Detail(k) end))
      end
    end
    if HookAddonOrVariable then HookAddonOrVariable(k.addon, Hook) else Hook() end
  end
end)
