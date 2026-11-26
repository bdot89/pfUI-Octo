-- pfUI Octo :: OctoLoot builder, step 1b (26 Nov 2026): runs Atlas-CFM's data tables (sets, factions, PvP rewards,
-- world events, crafting) and menus on a stand-in AtlasCFM with name lookups that return their keys, and writes the
-- FACTS they hold (which item ids sit under which heading of which page, and the menus naming the pages) as plain lines.
-- Nothing of this is copied into pfUI as code. Run by tools\Make-OctoLootData.ps1 through DmorphOcto's LuaHost:
--   LuaHost.exe dump-atlas.lua <Atlas-CFM\CFMLoot\Data folder> <out file>
local DATA, OUT = arg and arg[1], arg and arg[2]
DATA = DATA or OCTOLOOT_DATA
OUT = OUT or OCTOLOOT_OUT

local function keys() return setmetatable({}, { __index = function(_, k) return k end }) end
AtlasCFM = {
  Localization = setmetatable({}, { __index = function(t, k) local v = keys() rawset(t, k, v) return v end }),
  Colors = setmetatable({}, { __index = function() return "" end }),
  Server = { AUTO = "Auto", TURTLE = "TURTLE", TURTLE1 = "TURTLE1", VANILLA_PLUS = "VANILLA_PLUS", CLASSIC = "CLASSIC",
    NOT_TURTLE = "NOT_TURTLE", NOT_VANILLA_PLUS = "NOT_VANILLA_PLUS", NOT_CLASSIC = "NOT_CLASSIC", NOT_TURTLE1 = "NOT_TURTLE1",
    STRICT_TURTLE = "=TURTLE", STRICT_TURTLE1 = "=TURTLE1" },
  MenuData = {}, InstanceData = {}, PATH = "",
}
setmetatable(AtlasCFM.Server, { __index = function(_, k) return k end })
-- submenus are functions that hand a menu table to PrepMenu: caught here
local caught
AtlasCFM.LootBrowserUI = { PrepMenu = function(title, menu, parent, icon) caught = { title = title, menu = menu, parent = parent, icon = icon } end }
AtlasCFMLoot_Data = {}
-- the client calls some files make at load
GetLocale = function() return "enUS" end
UnitFactionGroup = function() return "Alliance" end
CreateFrame = function() return setmetatable({}, { __index = function() return function() end end }) end
local function run(rel)
  local f, err = loadfile(DATA .. "/" .. rel)
  if not f then io.stderr:write("skip " .. rel .. ": " .. tostring(err) .. "\n") return end
  local ok, e = pcall(f)
  if not ok then io.stderr:write("error " .. rel .. ": " .. tostring(e) .. "\n") end
end
for _, f in ipairs({ "PvP/PVPRewards.lua", "Tables/Spells.lua", "Tables/Factions.lua", "Tables/Events.lua", "Tables/Sets.lua",
  "Tables/Crafting.lua", "Tables/WeaponSkills.lua", "Menu/Sets.lua", "Menu/Factions.lua", "Menu/PvP.lua", "Menu/WorldEvents.lua",
  "Menu/Crafting.lua", "Menu/World.lua" }) do run(f) end
-- the instance files only for their exchange lists (an item's "container": what it can be swapped for)
local function each(dir)
  local p = io.popen('dir /b "' .. string.gsub(DATA .. "/" .. dir, "/", "\\") .. '\\*.lua" 2>nul')
  if not p then return {} end
  local t = {}
  for l in p:lines() do table.insert(t, dir .. "/" .. l) end
  p:close()
  return t
end
for _, d in ipairs({ "Instances", "World", "PvP" }) do for _, f in ipairs(each(d)) do run(f) end end

local out = {}
local function clean(s) return (string.gsub(tostring(s or ""), "[%^\n|]", " ")) end
local function servers(e)
  if type(e) ~= "table" or type(e.servers) ~= "table" then return "" end
  local t = {}
  for _, s in ipairs(e.servers) do table.insert(t, type(s) == "table" and tostring(s[1]) or tostring(s)) end
  return table.concat(t, ",")
end
-- the submenu functions named by any menu entry: their menus under the function's name (T^function^title^parent^icon)
local named = {}
for _, list in pairs(AtlasCFM.MenuData) do
  if type(list) == "table" then
    for _, e in ipairs(list) do
      if type(e) == "table" and type(e.lootpage) == "string" and type(_G[e.lootpage]) == "function" then named[e.lootpage] = true end
    end
  end
end
local more = true
while more do
  more = false
  for fname in pairs(named) do
    if not AtlasCFM.MenuData[fname] then
      caught = nil
      pcall(_G[fname])
      if caught and type(caught.menu) == "table" then
        AtlasCFM.MenuData[fname] = caught.menu
        table.insert(out, table.concat({ "T", fname, clean(caught.title), clean(caught.parent), clean(caught.icon) }, "^"))
        for _, e in ipairs(caught.menu) do
          if type(e) == "table" and type(e.lootpage) == "string" and type(_G[e.lootpage]) == "function" and not named[e.lootpage] then
            named[e.lootpage] = true
            more = true
          end
        end
      else
        AtlasCFM.MenuData[fname] = {}
      end
    end
  end
end
-- menus: M^menu^name^icon^page^extra^servers
for menu, list in pairs(AtlasCFM.MenuData) do
  if type(list) == "table" then
    for _, e in ipairs(list) do
      if type(e) == "table" and e.name then
        table.insert(out, table.concat({ "M", clean(menu), clean(e.name), clean(e.icon), clean(e.lootpage), clean(e.Extra), servers(e) }, "^"))
      elseif type(e) == "table" then
        table.insert(out, "M^" .. clean(menu) .. "^-")
      end
    end
  end
end
-- pages: P^page, then H^heading^icon^servers | E^id^dropRate^disc^servers | S (a gap)
local pages = {}
for k in pairs(AtlasCFMLoot_Data) do table.insert(pages, k) end
table.sort(pages)
for _, k in ipairs(pages) do
  local list = AtlasCFMLoot_Data[k]
  if type(list) == "table" then
    table.insert(out, "P^" .. clean(k))
    for _, e in ipairs(list) do
      if type(e) ~= "table" then
      elseif e.id then
        local skill = type(e.skill) == "table" and table.concat(e.skill, ",") or ""
        table.insert(out, table.concat({ "E", tostring(e.id), tostring(e.dropRate or ""), clean(e.disc), servers(e), skill }, "^"))
      elseif e.name then
        table.insert(out, table.concat({ "H", clean(e.name), clean(e.icon), servers(e) }, "^"))
      else
        table.insert(out, "S")
      end
    end
  end
end
-- exchanges: C^item^swap,swap (from every loot list anywhere: instances, tables, PvP)
local swaps, seenT = {}, {}
local function walk(t, depth)
  if type(t) ~= "table" or seenT[t] or depth > 8 then return end
  seenT[t] = true
  if type(t.id) == "number" and type(t.container) == "table" then
    local ids = swaps[t.id] or {}
    swaps[t.id] = ids
    for _, c in ipairs(t.container) do
      local cid = type(c) == "table" and c[1] or c
      local srv = type(c) == "table" and type(c.servers) == "table" and c.servers or nil
      local ok = true
      if srv then
        ok = false
        for _, s in ipairs(srv) do if string.find(tostring(s), "TURTLE", 1, true) then ok = true end end
      end
      if type(cid) == "number" and ok then ids[cid] = true end
    end
  end
  for _, v in pairs(t) do walk(v, depth + 1) end
end
walk(AtlasCFMLoot_Data, 0)
walk(AtlasCFM.InstanceData, 0)
local nswap = 0
for id, set in pairs(swaps) do
  local l = {}
  for c in pairs(set) do table.insert(l, c) end
  if table.getn(l) > 0 then
    table.sort(l)
    nswap = nswap + 1
    table.insert(out, "C^" .. id .. "^" .. table.concat(l, ","))
  end
end
print(nswap .. " items with swaps")
local fh = io.open(OUT, "wb")
fh:write(table.concat(out, "\n"))
fh:close()
print(table.getn(pages) .. " pages, " .. table.getn(out) .. " lines")
