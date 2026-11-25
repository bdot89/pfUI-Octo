pfUI:RegisterModule("autovendor", "vanilla:tbc", function ()
  local rawborder, border = GetBorderSize()
  local bpad = rawborder > 1 and border - GetPerfectPixel() or GetPerfectPixel()
  local processed = {}

  local function RepairItems()
    local cost, possible = GetRepairAllCost()
    if cost > 0 and possible then
      DEFAULT_CHAT_FRAME:AddMessage(T["Your items have been repaired for"] .. " " .. CreateGoldString(cost))
      RepairAllItems()
    end
  end

  -- (25 Nov 2026, Лев on Discord with Automaton's "Sell > Always sell": add item, remove, list, purge) two lists per
  -- account (pfUI_cache.autosell): ALWAYS sold at a vendor with the greys, NEVER sold even when grey. Ctrl + Alt +
  -- right-click a bag item puts it on Always sell (again = off), Ctrl + Alt + Shift on Never sell; /sell; options in
  -- Quality of Life > Vendor and loot. ClassicAPI's one-call grey sale is only used while the lists change nothing.
  local AV = {}
  pfUI.autovendor = AV
  function AV.Lists()
    pfUI_cache.autosell = pfUI_cache.autosell or {}
    local s = pfUI_cache.autosell
    s.always = s.always or {}
    s.never = s.never or {}
    return s
  end
  function AV.IdOf(link)
    local _, _, id = string.find(link or "", "item:(%d+)")
    return tonumber(id)
  end
  local function NameOf(link)
    local _, _, n = string.find(link or "", "%[(.-)%]")
    return n
  end
  -- sell this bag item? grey or on Always sell, and not on Never sell
  function AV.Wanted(link)
    if not link then return nil end
    local id = AV.IdOf(link)
    local s = AV.Lists()
    if id and s.never[id] then return nil end
    if id and s.always[id] then return true end
    return string.find(link, "ff9d9d9d") and true or nil
  end
  -- what the lists change in the bags now (then the plain loop runs, not ClassicAPI's greys-only call)
  function AV.ListsMatter()
    local s = AV.Lists()
    for bag = 0, 4, 1 do
      for slot = 1, GetContainerNumSlots(bag), 1 do
        local id = AV.IdOf(GetContainerItemLink(bag, slot))
        if id and (s.always[id] or s.never[id]) then return true end
      end
    end
  end
  function AV.Toggle(link, which)
    local id = AV.IdOf(link)
    if not id then return end
    local s = AV.Lists()
    local list, other = s[which], s[which == "always" and "never" or "always"]
    local name = NameOf(link) or ("item " .. id)
    if list[id] then
      list[id] = nil
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI|r: " .. name .. " is off " .. (which == "always" and "Always sell" or "Never sell") .. ".")
    else
      list[id] = name
      other[id] = nil
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI|r: " .. name .. " is on " .. (which == "always" and "|cffff6a55Always sell|r - sold at every vendor" or "|cff55ff55Never sell|r - kept even when grey") .. ".")
    end
    local av = rawget(_G, "pfMoneyUpdate")
    if MerchantFrame and MerchantFrame:IsShown() and av and av.button then av.button:Update() end
  end

  local function HasGreyItems()
    for bag = 0, 4, 1 do
      for slot = 1, GetContainerNumSlots(bag), 1 do
        if AV.Wanted(GetContainerItemLink(bag,slot)) then return true end
      end
    end
    return nil
  end

  local function GetNextGreyItem()
    for bag = 0, 4, 1 do
      for slot = 1, GetContainerNumSlots(bag), 1 do
        if AV.Wanted(GetContainerItemLink(bag,slot)) and not processed[bag.."x"..slot] then
          processed[bag.."x"..slot] = true
          return bag, slot
        end
      end
    end

    return nil, nil
  end

  local autovendor = CreateFrame("Frame", "pfMoneyUpdate", nil)
  autovendor:Hide()

  autovendor:SetScript("OnShow", function()
    processed = {}
    this.count = 0
    this.engine = nil
    this.gold = GetMoney()
  end)

  autovendor:SetScript("OnUpdate", function()
    -- throttle to to one item per .1 second
    if ( this.tick or 1) > GetTime() then return else this.tick = GetTime() + .1 end

    -- octo (from the ClassicAPI pfUI fork): ClassicAPI sells every grey item
    -- in one call, one per frame inside the client (no lost sells); the loop
    -- below is the plain way
    if C_UnitAuras and C_MerchantFrame and C_MerchantFrame.SellAllJunkItems and (this.engine or not AV.ListsMatter()) then
      if not this.merchant then this:Hide() return end
      if not this.engine then
        if not HasGreyItems() then this:Hide() return end
        this.engine = GetTime() + 5
        this.count = 1
        pcall(C_MerchantFrame.SellAllJunkItems)
        return
      end
      if not HasGreyItems() or this.engine < GetTime() then this:Hide() end
      return
    end

    -- scan for the next grey item
    local bag, slot = GetNextGreyItem()
    if not bag or not slot then
      this:Hide()
      return
    end

    -- double check to only sell grey (or what is on Always sell)
    local name = GetContainerItemLink(bag,slot)
    if not AV.Wanted(name) then
      return
    end

    -- get value
    local _, icount = GetContainerItemInfo(bag, slot)
    local _, _, id = string.find(GetContainerItemLink(bag, slot), "item:(%d+):%d+:%d+:%d+")
    if pfSellData[tonumber(id)] then
      local _, _, sell, buy = strfind(pfSellData[tonumber(id)], "(.*),(.*)")
      this.count = this.count + 1
    end

    -- abort if the merchant window disappeared
    if not this.merchant then return end

    -- clear cursor and sell the item
    ClearCursor()
    UseContainerItem(bag, slot)
  end)

  autovendor:SetScript("OnHide", function()
    if this.count > 0 then
      local gold = this.gold
      QueueFunction(function()
        local income = GetMoney() - gold
        DEFAULT_CHAT_FRAME:AddMessage(T["Your vendor trash has been sold and you earned"] .. " " .. CreateGoldString(income))
      end)
    end
  end)

  autovendor:RegisterEvent("MERCHANT_SHOW")
  autovendor:RegisterEvent("MERCHANT_CLOSED")
  autovendor:RegisterEvent("MERCHANT_UPDATE")
  autovendor:SetScript("OnEvent", function()
    autovendor.button:Update()

    if event == "MERCHANT_CLOSED" then
      autovendor.merchant = nil
      autovendor:Hide()
    elseif event == "MERCHANT_SHOW" then
      autovendor.merchant = true
      if C["global"]["autorepair"] == "1" then
        RepairItems()
      end

      if C["global"]["autosell"] == "1" then
        autovendor:Show()
        autovendor.button:Hide()
      else
        autovendor.button:Show()
      end

      MerchantRepairText:SetText("")
      if MerchantRepairItemButton:IsShown() then
        autovendor.button:ClearAllPoints()
        autovendor.button:SetPoint("RIGHT", MerchantRepairItemButton, "LEFT", -4*bpad, 0)
      else
        autovendor.button:ClearAllPoints()
        autovendor.button:SetPoint("RIGHT", MerchantBuyBackItemItemButton, "LEFT", -14, 0)
      end
    end
  end)

  -- Setup Autosell button
  autovendor.button = CreateFrame("Button", "pfMerchantAutoVendorButton", MerchantFrame)
  autovendor.button:SetWidth(36)
  autovendor.button:SetHeight(36)
  autovendor.button.icon = autovendor.button:CreateTexture(nil, "ARTWORK")
  autovendor.button.icon:SetTexture("Interface\\Icons\\Spell_Shadow_SacrificialShield")
  autovendor.button:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(T["Sell Grey Items"])
    GameTooltip:Show()
  end)

  autovendor.button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  SkinButton(autovendor.button, nil, nil, nil, autovendor.button.icon)

  autovendor.button:SetScript("OnClick", function()
    autovendor:Show()
  end)

  autovendor.button.Update = function()
    if not autovendor:IsVisible() then
      if HasGreyItems() then
        autovendor.button:Enable()
        autovendor.button.icon:SetDesaturated(false)
      else
        autovendor.button:Disable()
        autovendor.button.icon:SetDesaturated(true)
      end
    else
      autovendor.button:Disable()
      autovendor.button.icon:SetDesaturated(true)
    end
  end

  -- Hook MerchantFrame_Update
  if not pfMerchantFrame_Update then
    local pfMerchantFrame_Update = MerchantFrame_Update
    function _G.MerchantFrame_Update()
      if MerchantFrame.selectedTab == 1 and C["global"]["autosell"] ~= "1" then
        autovendor.button:Show()
      else
        autovendor.button:Hide()
      end
      pfMerchantFrame_Update()
    end
  end

  -- Ctrl + Alt + right-click a bag item: Always sell on / off; with Shift too: Never sell (any bag window: they all
  -- use the item through UseContainerItem). Not while the sale itself runs.
  -- true = the click was ours (the item is not used)
  function AV.Intercept(bag, slot)
    if IsControlKeyDown and IsControlKeyDown() and IsAltKeyDown() and not autovendor:IsShown() then
      AV.Toggle(GetContainerItemLink(bag, slot), IsShiftKeyDown() and "never" or "always")
      return true
    end
  end
  if UseContainerItem and not AV.wrapped then
    AV.wrapped = true
    local use = UseContainerItem
    _G.UseContainerItem = function(bag, slot, a3, a4)
      if AV.Intercept(bag, slot) then return end
      return use(bag, slot, a3, a4)
    end
  end

  -- /sell add|never|remove <item link or name>, /sell list, /sell purge
  function AV.Find(text)
    local id = AV.IdOf(text)
    if id then return id, (string.gsub(text, "^.-%[(.-)%].*$", "%1")) end
    text = string.lower(text or "")
    if text == "" then return nil end
    for bag = 0, 4, 1 do
      for slot = 1, GetContainerNumSlots(bag), 1 do
        local link = GetContainerItemLink(bag, slot)
        local _, _, n = string.find(link or "", "%[(.-)%]")
        if n and string.lower(n) == text then return AV.IdOf(link), n end
      end
    end
    local s = AV.Lists()
    for _, list in pairs({ s.always, s.never }) do
      for lid, n in pairs(list) do if string.lower(n) == text then return lid, n end end
    end
  end
  _G.SLASH_PFAUTOSELL1 = "/pfsell"
  _G.SLASH_PFAUTOSELL2 = "/sell"
  _G.SlashCmdList["PFAUTOSELL"] = function(msg)
    local _, _, cmd, rest = string.find(msg or "", "^(%S*)%s*(.-)$")
    cmd = string.lower(cmd or "")
    local s = AV.Lists()
    local function Say(t) DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI|r: " .. t) end
    if cmd == "add" or cmd == "never" then
      local id, n = AV.Find(rest)
      if not id then Say("No such item in your bags: " .. rest) return end
      local which = cmd == "add" and "always" or "never"
      if s[which][id] then Say(n .. " is already there.") return end
      AV.Toggle("item:" .. id .. " [" .. n .. "]", which)
    elseif cmd == "remove" then
      local id, n = AV.Find(rest)
      if id and (s.always[id] or s.never[id]) then
        s.always[id], s.never[id] = nil, nil
        Say((n or rest) .. " is off both lists.")
      else
        Say("Not on a list: " .. rest)
      end
    elseif cmd == "list" then
      local a, nv = {}, {}
      for _, n in pairs(s.always) do table.insert(a, n) end
      for _, n in pairs(s.never) do table.insert(nv, n) end
      table.sort(a) table.sort(nv)
      Say("|cffff6a55Always sell|r (" .. table.getn(a) .. "): " .. (table.getn(a) > 0 and table.concat(a, ", ") or "-"))
      Say("|cff55ff55Never sell|r (" .. table.getn(nv) .. "): " .. (table.getn(nv) > 0 and table.concat(nv, ", ") or "-"))
    elseif cmd == "purge" then
      s.always = {}
      Say("Always sell is empty now.")
    else
      Say("|cffffd100/sell add <item>|r always sell it   |cffffd100/sell never <item>|r keep it even when grey   "
        .. "|cffffd100/sell remove <item>|r   |cffffd100/sell list|r   |cffffd100/sell purge|r empty Always sell   "
        .. "Or Ctrl + Alt + right-click a bag item (Shift too = never sell).")
    end
  end
end)
