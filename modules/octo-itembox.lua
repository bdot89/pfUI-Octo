-- pfUI Octo :: item box widget (9 Nov 2026). User, on the Loot Filter's rule
-- text: "could we also add another way of doing it? Maybe with a box and icons
-- of the things you have saved ... you can add things by dragging and
-- dropping or selecting from a list". Used by the Loot Filter and the bag
-- Categories pages for their item lists.
--
--   W.ItemBox(p, label, desc, get, set, after)
--     get() -> { itemID, ... }   set(list)   after() runs after a change
--   An icon per item (hover: its tooltip, right-click: take it out), then a
--   "+" slot: drop an item from your bags or character on it, or click it to
--   pick from what you carry. Typing an item ID works too.
local B = pfUI.octoui
local W = B and B.W
if not W then return end

local FIELD, LINE, HI = { .07, .07, .09 }, { .22, .22, .27 }, { .3, .65, 1 }
local SIZE, GAP = 30, 4

-- ------------------------------------------------- what is on the cursor
-- 1.12 cannot say which item the cursor holds, so the pick-up calls are
-- followed: the bag slot or worn slot last picked up, while the cursor holds it
W.cursorItem = nil
local function IdOfLink(link)
  if type(link) ~= "string" then return nil end
  local _, _, id = string.find(link, "item:(%d+)")
  return tonumber(id)
end
W.IdOfLink = IdOfLink
local function Follow(name, read)
  local orig = _G[name]
  if type(orig) ~= "function" then return end
  _G[name] = function(a, b, c)
    local r = orig(a, b, c)
    local has = _G.CursorHasItem and _G.CursorHasItem()
    W.cursorItem = has and read(a, b) or nil
    return r
  end
end
Follow("PickupContainerItem", function(bag, slot) return _G.GetContainerItemLink and IdOfLink(_G.GetContainerItemLink(bag, slot)) end)
Follow("PickupInventoryItem", function(slot) return _G.GetInventoryItemLink and IdOfLink(_G.GetInventoryItemLink("player", slot)) end)
-- the item the cursor holds now, nil when it holds none (or one not followed)
function W.CursorItem()
  if not (_G.CursorHasItem and _G.CursorHasItem()) then W.cursorItem = nil return nil end
  return W.cursorItem
end

local function Texture(id)
  local a = { _G.GetItemInfo and _G.GetItemInfo(id) }
  for i = 9, 10 do
    if type(a[i]) == "string" and string.find(a[i], "Interface") then return a[i] end
  end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end
W.ItemTexture = Texture

local function Slot(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(SIZE) b:SetHeight(SIZE)
  W.Flat(b, FIELD, 1, LINE)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  b.icon:SetTexCoord(.08, .92, .08, .92)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnLeave", function()
    this:SetBackdropBorderColor(LINE[1], LINE[2], LINE[3], 1)
    if GameTooltip then GameTooltip:Hide() end
  end)
  return b
end

-- the picker: every different item in your bags, click one to add it
local picker
local function Picker(anchor, add)
  if not picker then
    local f = CreateFrame("Frame", "pfOctoItemPicker", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    W.Flat(f, { .05, .05, .07 }, .97, LINE)
    f.title = W.Font(f:CreateFontString(nil, "OVERLAY"), 11, .9, .9, .9)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -7)
    f.title:SetText("Click an item to add it")
    local x = CreateFrame("Button", nil, f)
    x:SetWidth(18) x:SetHeight(18)
    x:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    x.t = W.Font(x:CreateFontString(nil, "OVERLAY"), 12, 1, .35, .35)
    x.t:SetPoint("CENTER", x, "CENTER", 0, 0)
    x.t:SetText("x")
    x:SetScript("OnClick", function() f:Hide() end)
    f.slots = {}
    table.insert(UISpecialFrames, "pfOctoItemPicker")
    picker = f
  end
  local f = picker
  local seen, list = {}, {}
  for bag = 0, 4 do
    local n = _G.GetContainerNumSlots and _G.GetContainerNumSlots(bag) or 0
    for slot = 1, n do
      local id = IdOfLink(_G.GetContainerItemLink(bag, slot))
      if id and not seen[id] then seen[id] = true table.insert(list, id) end
    end
  end
  local cols = 10
  for i = 1, math.max(table.getn(list), table.getn(f.slots)) do
    local s = f.slots[i]
    if not s and list[i] then
      s = Slot(f)
      f.slots[i] = s
    end
    if s then
      local id = list[i]
      if id then
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + math.mod(i - 1, cols) * (SIZE + GAP), -26 - math.floor((i - 1) / cols) * (SIZE + GAP))
        s.icon:SetTexture(Texture(id))
        s.id = id
        s:SetScript("OnEnter", function()
          this:SetBackdropBorderColor(HI[1], HI[2], HI[3], 1)
          GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
          GameTooltip:SetHyperlink("item:" .. this.id .. ":0:0:0")
          GameTooltip:Show()
        end)
        s:SetScript("OnClick", function() f.add(this.id) f:Hide() end)
        s:Show()
      else
        s:Hide()
      end
    end
  end
  local rows = math.max(1, math.ceil(table.getn(list) / cols))
  f:SetWidth(16 + cols * (SIZE + GAP) - GAP)
  f:SetHeight(34 + rows * (SIZE + GAP))
  if table.getn(list) == 0 then f.title:SetText("Your bags are empty") else f.title:SetText("Click an item to add it") end
  f.add = add
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
  f:Show()
end
W.ItemPicker = Picker

function W.ItemBox(p, label, desc, get, set, after)
  local list = get() or {}
  local n = table.getn(list) + 1
  local width = W.WIDTH - 60
  local cols = math.max(1, math.floor((width + GAP) / (SIZE + GAP)))
  local rows = math.ceil(n / cols)
  local row = W.Row(p, 18 + rows * (SIZE + GAP) + 26, 0, 6)
  local title = W.Font(row:CreateFontString(nil, "OVERLAY"), 11, .85, .85, .85)
  title:SetPoint("TOPLEFT", row, "TOPLEFT", 10, 0)
  title:SetText(label)
  if desc then W.Tip(row, label, desc) end

  local function Changed(newList)
    set(newList)
    if after then after() end
  end
  -- the list as saved now (the drawn icons can be a change behind)
  local function Now() return get() or {} end
  local function Has(id)
    local cur = Now()
    for i = 1, table.getn(cur) do if tonumber(cur[i]) == id then return true end end
  end
  local function Add(id)
    id = tonumber(id)
    if not id or Has(id) then return end
    local cur, out = Now(), {}
    for i = 1, table.getn(cur) do out[i] = cur[i] end
    table.insert(out, id)
    Changed(out)
  end
  local function Remove(id)
    local cur, out = Now(), {}
    for i = 1, table.getn(cur) do if tonumber(cur[i]) ~= tonumber(id) then table.insert(out, cur[i]) end end
    Changed(out)
  end
  row.Add, row.Remove = Add, Remove

  for i = 1, n do
    local s = Slot(row)
    s:SetPoint("TOPLEFT", row, "TOPLEFT", 10 + math.mod(i - 1, cols) * (SIZE + GAP), -18 - math.floor((i - 1) / cols) * (SIZE + GAP))
    local id = list[i]
    if id then
      s.id = id
      s.icon:SetTexture(Texture(id))
      s:SetScript("OnEnter", function()
        this:SetBackdropBorderColor(HI[1], HI[2], HI[3], 1)
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. this.id .. ":0:0:0")
        GameTooltip:AddLine("Right-click to take it out", .6, .6, .6)
        GameTooltip:Show()
      end)
      s:SetScript("OnClick", function() if arg1 == "RightButton" then Remove(this.id) end end)
    else
      -- the add slot: a drop target and a button for the picker
      s.icon:SetTexture("Interface\\PaperDollInfoFrame\\Character-Plus")
      s.icon:SetTexCoord(0, 1, 0, 1)
      s.icon:SetVertexColor(.4, 1, .4)
      local function Take()
        local cur = W.CursorItem()
        if cur then
          if _G.ClearCursor then _G.ClearCursor() end
          W.cursorItem = nil
          Add(cur)
          return true
        end
      end
      s:SetScript("OnReceiveDrag", Take)
      s:SetScript("OnClick", function() if not Take() then Picker(this, Add) end end)
      s:SetScript("OnEnter", function()
        this:SetBackdropBorderColor(HI[1], HI[2], HI[3], 1)
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Add an item")
        GameTooltip:AddLine("Drop an item from your bags here, or click to pick one from your bags.", 1, 1, 1, 1)
        GameTooltip:Show()
      end)
    end
  end

  -- typing: an item ID (or a pasted link), Enter adds it
  local eb = W.EditBox(row, 200)
  eb:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -18 - rows * (SIZE + GAP) - 2)
  eb:SetScript("OnEnterPressed", function()
    local t = this:GetText() or ""
    this:SetText("")
    this:ClearFocus()
    Add(IdOfLink(t) or tonumber(t))
  end)
  W.Tip(eb, "Add by item ID", "Type an item ID (for example 2589 for Linen Cloth), then press Enter.")
  local hint = W.Font(row:CreateFontString(nil, "OVERLAY"), 10, .55, .55, .6)
  hint:SetPoint("LEFT", eb, "RIGHT", 8, 0)
  hint:SetText("or type an item ID and press Enter  -  right-click an icon to take it out")
  return row
end
