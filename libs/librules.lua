-- load pfUI environment
setfenv(1, pfUI:GetEnvironment())

--[[ librules ]]--
-- pfUI Octo (9 Nov 2026): item rules written once, used by the loot filter
-- (modules/lootfilter.lua) and the bag categories (modules/bags-octo.lua).
-- Bread (Discord), on Bagshui: "you can make categories using itemIDs with a
-- combination of prompts to automate sorting ... picks up keywords like iron
-- ore, iron bar but excludes armor/weapon/quests". Written fresh (Bagshui's
-- licence not checked): a rule is a Lua expression over these checks,
-- joined with and / or / not and brackets, e.g.
--   (Name("Ore", "Bar") or Tooltip("Smelted")) and Type("Trade Goods") and not Type("Armor", "Quest")
--
-- Checks (text is matched anywhere, any case; several arguments = any of them):
--   Name(...)        NameIs(...)     ID(...)
--   Type(...)        Subtype(...)    Equip(...)  (no argument: anything you can wear)
--   Quality(...)     "poor" "common" "uncommon" "rare" "epic" "legendary", or 0-6
--   MinQuality(q)    MaxQuality(q)
--   Level(min, max)  the level needed to use it
--   Tooltip(...)     any tooltip line
--   BoE()  BoP()  Soulbound()  Quest()  Stackable()  Count(min)
--   Value(min, max)  vendor price in copper, when the client tells it (ClassicAPI)
--
--   pfUI.rules.Compile(text)       -> fn or nil, error
--   pfUI.rules.Info(item, bag, slot) item = ID, "item:..." or a link; bag/slot for the tooltip
--   pfUI.rules.Match(fn, info)     -> true / false (an error counts as false)
--   pfUI.rules.Test(text, item)    -> matched, error (for the "Try it" box)

if pfUI.rules then return end
local R = {}
pfUI.rules = R

local lower, find, gsub = string.lower, string.find, string.gsub

R.QUALITY = { poor = 0, grey = 0, gray = 0, common = 1, white = 1, uncommon = 2, green = 2, rare = 3, blue = 3,
  epic = 4, purple = 4, legendary = 5, orange = 5, artifact = 6 }
R.QUALITY_NAMES = { [0] = "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact" }

local function Q(v)
  if type(v) == "number" then return v end
  if type(v) == "string" then return R.QUALITY[lower(v)] or tonumber(v) end
end

-- ---------------------------------------------------------------- the item
-- GetItemInfo: 1.12 gives name, link, quality, min level, type, subtype,
-- stack, equip slot, texture; ClassicAPI may give the later order (item
-- level and min level, then type ..., texture, sell price). Told apart by
-- the fifth answer: text in 1.12, a number in the later order.
function R.ItemInfo(id)
  if not id or type(_G.GetItemInfo) ~= "function" then return nil end
  local a = { _G.GetItemInfo(id) }
  if not a[1] then return nil end
  local t = { name = a[1], link = a[2], quality = tonumber(a[3]) }
  if type(a[5]) == "number" then
    t.ilvl, t.level, t.type, t.subtype, t.stack, t.equip, t.tex, t.value = a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11]
  else
    t.level, t.type, t.subtype, t.stack, t.equip, t.tex = a[4], a[5], a[6], a[7], a[8], a[9]
  end
  t.level, t.stack, t.value = tonumber(t.level), tonumber(t.stack), tonumber(t.value)
  return t
end

function R.IdOf(item)
  if type(item) == "number" then return item end
  if type(item) == "string" then
    local _, _, id = find(item, "item:(%d+)")
    return tonumber(id or item)
  end
end

function R.Info(item, bag, slot, count)
  local id = R.IdOf(item)
  local t = R.ItemInfo(id) or {}
  t.id, t.bag, t.slot = id, bag, slot
  t.count = count or t.count
  if not t.name and type(item) == "string" then
    local _, _, n = find(item, "%[(.-)%]")
    t.name = n
  end
  return t
end

-- tooltip lines, read once per item and only when a rule asks
local function Lines(info)
  if info.lines then return info.lines end
  local lines = {}
  local lib = pfUI.api and pfUI.api.libtipscan
  local scan = lib and lib:GetScanner("rules")
  if scan then
    local ok
    if info.bag and info.slot then
      ok = pcall(scan.SetBagItem, scan, info.bag, info.slot)
    elseif info.id then
      ok = pcall(scan.SetHyperlink, scan, "item:" .. info.id .. ":0:0:0")
    end
    if ok then
      local text = scan:Text()
      for i = 1, table.getn(text or {}) do
        local l, r = text[i][1], text[i][2]
        if l then table.insert(lines, lower(l)) end
        if r then table.insert(lines, lower(r)) end
      end
    end
  end
  info.lines = lines
  return lines
end
R.Lines = Lines

-- ---------------------------------------------------------------- checks
local cur -- the item being tested
local function Has(text, list)
  if not text then return false end
  text = lower(text)
  for i = 1, table.getn(list) do
    if find(text, lower(tostring(list[i])), 1, true) then return true end
  end
  return false
end
local function TipHas(words)
  local lines = Lines(cur)
  for i = 1, table.getn(lines) do
    for j = 1, table.getn(words) do
      if find(lines[i], lower(words[j]), 1, true) then return true end
    end
  end
  return false
end

-- up to 12 words per check, as a list (no "...": the game's Lua 5.0 and the
-- tests' LuaJIT read it differently)
local function L(a, b, c, d, e, f, g, h, i, j, k, l)
  local t, all = {}, { a, b, c, d, e, f, g, h, i, j, k, l }
  for n = 1, 12 do if all[n] ~= nil then table.insert(t, all[n]) end end
  return t
end
local env = {}
function env.Name(a, b, c, d, e, f, g, h, i, j, k, l) return Has(cur.name, L(a, b, c, d, e, f, g, h, i, j, k, l)) end
function env.NameIs(a, b, c, d, e, f, g, h, i, j, k, l)
  local n, list = cur.name and lower(cur.name), L(a, b, c, d, e, f, g, h, i, j, k, l)
  for x = 1, table.getn(list) do if n == lower(tostring(list[x])) then return true end end
  return false
end
function env.ID(a, b, c, d, e, f, g, h, i, j, k, l)
  local list = L(a, b, c, d, e, f, g, h, i, j, k, l)
  for x = 1, table.getn(list) do if tonumber(list[x]) == cur.id then return true end end
  return false
end
function env.Type(a, b, c, d, e, f, g, h, i, j, k, l) return Has(cur.type, L(a, b, c, d, e, f, g, h, i, j, k, l)) end
function env.Subtype(a, b, c, d, e, f, g, h, i, j, k, l) return Has(cur.subtype, L(a, b, c, d, e, f, g, h, i, j, k, l)) end
function env.Equip(a, b, c, d, e, f, g, h, i, j, k, l)
  local slot, list = cur.equip, L(a, b, c, d, e, f, g, h, i, j, k, l)
  if table.getn(list) == 0 then return slot ~= nil and slot ~= "" end
  return Has(slot, list) or Has(slot and _G[slot], list)
end
function env.Quality(a, b, c, d, e, f, g, h, i, j, k, l)
  local list = L(a, b, c, d, e, f, g, h, i, j, k, l)
  for x = 1, table.getn(list) do if Q(list[x]) == cur.quality then return true end end
  return false
end
function env.MinQuality(q) return cur.quality ~= nil and cur.quality >= (Q(q) or 0) end
function env.MaxQuality(q) return cur.quality ~= nil and cur.quality <= (Q(q) or 6) end
function env.Level(lo, hi)
  local l = cur.level or 0
  return l >= (tonumber(lo) or 0) and l <= (tonumber(hi) or 999)
end
function env.Tooltip(a, b, c, d, e, f, g, h, i, j, k, l) return TipHas(L(a, b, c, d, e, f, g, h, i, j, k, l)) end
function env.BoE() return TipHas({ lower(_G.ITEM_BIND_ON_EQUIP or "Binds when equipped") }) end
function env.BoP() return TipHas({ lower(_G.ITEM_BIND_ON_PICKUP or "Binds when picked up") }) end
function env.Soulbound() return TipHas({ lower(_G.ITEM_SOULBOUND or "Soulbound") }) end
function env.Quest()
  return Has(cur.type, { "Quest" }) or TipHas({ lower(_G.ITEM_BIND_QUEST or "Quest Item"), "quest item" })
end
function env.Stackable() return (cur.stack or 1) > 1 end
function env.Count(n) return (cur.count or 1) >= (tonumber(n) or 1) end
function env.Value(lo, hi)
  local v = cur.value
  if not v then return false end
  return v >= (tonumber(lo) or 0) and v <= (tonumber(hi) or 1e12)
end
R.env = env

-- ---------------------------------------------------------------- rules
local cache = {}
function R.Compile(text)
  if type(text) ~= "string" or not find(text, "%S") then return nil, "empty rule" end
  local c = cache[text]
  if c then return c.fn, c.err end
  local fn, err = loadstring("return (" .. text .. "\n)", "rule")
  if fn then
    setfenv(fn, setmetatable({}, { __index = env }))
  else
    err = gsub(tostring(err), "^.-:%d+: ", "")
  end
  cache[text] = { fn = fn, err = err }
  return fn, err
end

function R.Match(fn, info)
  if not fn or not info then return false end
  local prev = cur
  cur = info
  local ok, res = pcall(fn)
  cur = prev
  return ok and res and true or false, (not ok) and res or nil
end

function R.Test(text, item)
  local fn, err = R.Compile(text)
  if not fn then return false, err end
  local info = type(item) == "table" and item or R.Info(item)
  if not info.name then return false, "item not known to the client yet" end
  local hit, rerr = R.Match(fn, info)
  return hit, rerr
end
