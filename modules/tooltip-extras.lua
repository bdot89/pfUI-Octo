pfUI:RegisterModule("tooltip-extras", "vanilla:tbc", function ()
  -- More facts in the game's tooltips, in pfUI's own look (17 Nov 2026, user: "look at this
  -- [PrettyOctoTooltip] ... I dont want to copy their look but want some of the features ... where it
  -- drops ... fast no lag", then MobStats: "could also be integrated into this").
  --   items      item level (ClassicAPI), where it drops / who sells it (pfQuest's database inside
  --              pfUI), what it disenchants into with the Enchanting it needs
  --   nodes      herb / ore: the skill it needs against yours, what it gives
  --   creatures  skinning skill and what skinning gives; mob armour, melee hits and resistances
  --              (MobStats' formulas, MIT, Roman Kharitonov)
  -- Data: modules/tooltip-data.lua (PrettyOctoTooltip, MIT). Disenchant bands as in PrettyOctoTooltip's
  -- Data/Disenchant.lua (Warcraft Wiki's tables). Everything is worked out when a tooltip shows and kept
  -- per item / name / creature, so a tooltip costs a table lookup after the first time.
  -- Settings C.tooltip.x_* : "1" always, "shift" only while Shift is held, "0" off. QoL > Tooltips.
  local TX = {}
  pfUI.tipExtras = TX
  local D = pfUI.tipData or {}
  local lc = pfUI.api and pfUI.api.libclient

  local function Want(key)
    local v = C.tooltip[key]
    return v == "1" or (v == "shift" and IsShiftKeyDown())
  end
  TX.Want = Want

  -- the look: soft grey headings, white names, the numbers right in their own colour
  local HEAD = { .55, .75, 1 }
  local DIM = "|cff8c8c8c"
  local function Head(tt, text, right, rr, rg, rb)
    if right then
      tt:AddDoubleLine(text, right, HEAD[1], HEAD[2], HEAD[3], rr or .8, rg or .8, rb or .8)
    else
      tt:AddLine(text, HEAD[1], HEAD[2], HEAD[3])
    end
  end
  local function Row(tt, left, right, rr, rg, rb)
    tt:AddDoubleLine("  " .. left, right or "", 1, 1, 1, rr or .8, rg or .8, rb or .8)
  end
  local function Count(a, b)
    if not a then return "" end
    if not b or a == b then return tostring(a) end
    return a .. "-" .. b
  end
  local function Pct(p)
    if not p then return "" end
    if p >= 10 then return math.floor(p + .5) .. "%" end
    if p >= 1 then return string.format("%.1f%%", p) end
    return string.format("%.2f%%", p)
  end
  -- drop chance colours: likely green, fair white, rare grey
  local function ChanceColor(p)
    if not p then return .8, .8, .8 end
    if p >= 25 then return .35, .95, .45 end
    if p >= 5 then return 1, 1, 1 end
    return .6, .6, .6
  end

  -- ---------------------------------------------------------------- your skills (cached)
  local skills, skillsAt = {}, -100
  function TX.Skill(name)
    local now = GetTime()
    if now - skillsAt > 5 and GetNumSkillLines then
      skillsAt = now
      skills = {}
      for i = 1, (tonumber(GetNumSkillLines()) or 0) do
        local n, header, _, rank = GetSkillLineInfo(i)
        if n and not header then skills[n] = tonumber(rank) or 0 end
      end
    end
    return skills[name]
  end
  -- the colour of a gather / skin as the game's trainers show it: red can't, orange always a point,
  -- yellow mostly, green rarely, grey never
  function TX.SkillColor(have, need)
    if not have or have < need then return 1, .25, .2 end
    if have < need + 25 then return 1, .5, .15 end
    if have < need + 50 then return 1, .9, .2 end
    if have < need + 100 then return .3, .9, .35 end
    return .55, .55, .55
  end
  local function SkillLine(tt, prof, need)
    local have = TX.Skill(prof)
    local r, g, b = TX.SkillColor(have, need)
    local right = need .. (have and (DIM .. "  you " .. have .. "|r") or (DIM .. "  you don't have it|r"))
    tt:AddDoubleLine(prof, right, HEAD[1], HEAD[2], HEAD[3], r, g, b)
  end

  -- ---------------------------------------------------------------- item level
  local ilvl = {}
  function TX.ItemLevel(id, link)
    if not id then return nil end
    local v = ilvl[id]
    if v ~= nil then return v or nil end
    v = false
    local C_Item = _G.C_Item
    if C_Item and C_Item.GetDetailedItemLevelInfo then
      local ok, n = pcall(C_Item.GetDetailedItemLevelInfo, link or id)
      if ok and tonumber(n) and tonumber(n) > 0 then v = tonumber(n) end
    end
    ilvl[id] = v
    return v or nil
  end

  -- ---------------------------------------------------------------- where it comes from (pfQuest)
  local function Loc(db, id)
    local t = pfDB and pfDB[db] and (pfDB[db]["loc"] or pfDB[db]["enUS"])
    local n = t and t[id]
    if type(n) == "table" then n = n["T"] or n[1] end
    return type(n) == "string" and n or nil
  end
  local function ZoneOf(db, id)
    local d = pfDB and pfDB[db] and pfDB[db]["data"] and pfDB[db]["data"][id]
    local c = d and d["coords"] and d["coords"][1]
    local z = c and c[3]
    return z and Loc("zones", z) or nil
  end
  local sources = {}
  -- { drops = { { name, chance, zone } } (most likely first), ndrops, objects = {...}, vendors = {...} }
  function TX.Sources(id)
    if not id then return nil end
    local s = sources[id]
    if s ~= nil then return s or nil end
    s = false
    local e = pfDB and pfDB["items"] and pfDB["items"]["data"] and pfDB["items"]["data"][id]
    if type(e) == "table" and (e["U"] or e["O"] or e["V"]) then
      s = { drops = {}, ndrops = 0, objects = {}, vendors = {} }
      for uid, chance in pairs(e["U"] or {}) do
        local name = Loc("units", uid)
        if name then
          s.ndrops = s.ndrops + 1
          table.insert(s.drops, { name, tonumber(chance) or 0, uid })
        end
      end
      table.sort(s.drops, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
      for oid, chance in pairs(e["O"] or {}) do
        local name = Loc("objects", oid)
        if name then table.insert(s.objects, { name, tonumber(chance) or 0, oid }) end
      end
      table.sort(s.objects, function(a, b) return a[2] > b[2] end)
      for vid in pairs(e["V"] or {}) do
        local name = Loc("units", vid)
        if name then table.insert(s.vendors, { name, 0, vid }) end
      end
      table.sort(s.vendors, function(a, b) return a[1] < b[1] end)
      if s.ndrops == 0 and table.getn(s.objects) == 0 and table.getn(s.vendors) == 0 then s = false end
    end
    sources[id] = s
    return s or nil
  end
  -- a line already in the tooltip that names this (another add-on, e.g. Atlas, said it)
  local function Said(tt, text)
    local n = tt:NumLines() or 0
    for i = 2, n do
      local l = _G[tt:GetName() .. "TextLeft" .. i]
      local t = l and l:GetText()
      if t and string.find(t, text, 1, true) then return true end
    end
  end
  function TX.AddSources(tt, id)
    local s = TX.Sources(id)
    if not s then return end
    local more = IsShiftKeyDown()
    local max = more and 8 or math.max(1, tonumber(C.tooltip.x_srcrows) or 3)
    local top = s.drops[1]
    if top and not (Said(tt, top[1]) and not more) then
      -- a world drop: many creatures, each a sliver
      if s.ndrops > 12 and top[2] < 1 then
        Head(tt, "World drop", s.ndrops .. " creatures", .6, .6, .6)
      else
        Head(tt, "Drops from")
        for i = 1, math.min(max, s.ndrops) do
          local d = s.drops[i]
          local zone = ZoneOf("units", d[3])
          local r, g, b = ChanceColor(d[2])
          Row(tt, d[1] .. (zone and (DIM .. "  " .. zone .. "|r") or ""), d[2] > 0 and Pct(d[2]) or "", r, g, b)
        end
        if s.ndrops > max then tt:AddLine("  " .. (s.ndrops - max) .. " more" .. (more and "" or " - hold Shift"), .5, .5, .5) end
      end
    end
    if s.objects[1] then
      Head(tt, "Found in")
      for i = 1, math.min(more and 5 or 2, table.getn(s.objects)) do
        local o = s.objects[i]
        local zone = ZoneOf("objects", o[3])
        Row(tt, o[1] .. (zone and (DIM .. "  " .. zone .. "|r") or ""), o[2] > 0 and Pct(o[2]) or "", ChanceColor(o[2]))
      end
    end
    local mf = _G.MerchantFrame
    if s.vendors[1] and not (mf and mf.IsShown and mf:IsShown()) then
      local n = table.getn(s.vendors)
      Head(tt, "Sold by", n > 1 and (n .. " vendors") or nil, .6, .6, .6)
      for i = 1, math.min(more and 5 or 1, n) do
        local v = s.vendors[i]
        local zone = ZoneOf("units", v[3])
        Row(tt, v[1] .. (zone and (DIM .. "  " .. zone .. "|r") or ""))
      end
    end
  end

  -- ---------------------------------------------------------------- disenchanting
  local NEXUS = 20725
  TX.DE_NAMES = {
    [10940] = "Strange Dust", [11083] = "Soul Dust", [11137] = "Vision Dust", [11176] = "Dream Dust",
    [16204] = "Illusion Dust",
    [10938] = "Lesser Magic Essence", [10939] = "Greater Magic Essence",
    [10998] = "Lesser Astral Essence", [11082] = "Greater Astral Essence",
    [11134] = "Lesser Mystic Essence", [11135] = "Greater Mystic Essence",
    [11174] = "Lesser Nether Essence", [11175] = "Greater Nether Essence",
    [16202] = "Lesser Eternal Essence", [16203] = "Greater Eternal Essence",
    [10978] = "Small Glimmering Shard", [11084] = "Large Glimmering Shard",
    [11138] = "Small Glowing Shard", [11139] = "Large Glowing Shard",
    [11177] = "Small Radiant Shard", [11178] = "Large Radiant Shard",
    [14343] = "Small Brilliant Shard", [14344] = "Large Brilliant Shard",
    [NEXUS] = "Nexus Crystal",
  }
  -- uncommon: { low, high, dust, dust count, essence, essence count, shard, main %, other %, shard % }
  local GREEN = {
    { 5, 15, 10940, { 1, 2 }, 10938, { 1, 2 }, nil, 80, 20, 0 },
    { 16, 20, 10940, { 2, 3 }, 10939, { 1, 2 }, 10978, 75, 20, 5 },
    { 21, 25, 10940, { 4, 6 }, 10998, { 1, 2 }, 10978, 75, 15, 10 },
    { 26, 30, 11083, { 1, 2 }, 11082, { 1, 2 }, 11084, 75, 20, 5 },
    { 31, 35, 11083, { 2, 5 }, 11134, { 1, 2 }, 11138, 75, 20, 5 },
    { 36, 40, 11137, { 1, 2 }, 11135, { 1, 2 }, 11139, 75, 20, 5 },
    { 41, 45, 11137, { 2, 5 }, 11174, { 1, 2 }, 11177, 75, 20, 5 },
    { 46, 50, 11176, { 1, 2 }, 11175, { 1, 2 }, 11178, 75, 20, 5 },
    { 51, 55, 11176, { 2, 5 }, 16202, { 1, 2 }, 14343, 75, 20, 5 },
    { 56, 60, 16204, { 1, 2 }, 16203, { 1, 2 }, 14344, 75, 20, 5 },
    { 61, 99, 16204, { 2, 5 }, 16203, { 2, 3 }, 14344, 75, 20, 5 },
  }
  local BLUE = {
    { 5, 25, 10978 }, { 26, 30, 11084 }, { 31, 35, 11138 }, { 36, 40, 11139 }, { 41, 45, 11177 },
    { 46, 50, 11178 }, { 51, 55, 14343 }, { 56, 99, 14344 },
  }
  local PURPLE = {
    { 40, 45, 11177, { 2, 4 } }, { 46, 50, 11178, { 2, 4 } }, { 51, 55, 14343, { 2, 4 } },
    { 56, 60, NEXUS, { 1, 1 } }, { 61, 99, NEXUS, { 1, 2 } },
  }
  local WEAPONLOC = { INVTYPE_WEAPON = 1, INVTYPE_2HWEAPON = 1, INVTYPE_WEAPONMAINHAND = 1, INVTYPE_WEAPONOFFHAND = 1,
                      INVTYPE_RANGED = 1, INVTYPE_RANGEDRIGHT = 1, INVTYPE_THROWN = 1 }
  local NEVER = { INVTYPE_BODY = 1, INVTYPE_TABARD = 1, INVTYPE_BAG = 1, INVTYPE_AMMO = 1, INVTYPE_QUIVER = 1 }
  local CRAFTED_WANDS = { [11287] = 1, [11288] = 1, [11289] = 1, [11290] = 1 }
  local function Band(list, level)
    for _, e in ipairs(list) do if level >= e[1] and level <= e[2] then return e end end
  end
  -- the Enchanting skill an item of this level needs
  function TX.DESkill(level, quality)
    if level <= 20 then return quality == 3 and 25 or 1 end
    if level <= 60 then return 25 + math.floor((level - 21) / 5) * 25 end
    return 225
  end
  -- { skill, rows = { { id, count = {a, b}, chance } } } or nil
  function TX.Disenchant(id, quality, level, equipLoc)
    if not (id and quality and level and equipLoc) or equipLoc == "" or NEVER[equipLoc] or CRAFTED_WANDS[id] then return end
    local weapon = WEAPONLOC[equipLoc]
    local rows
    if quality == 2 then
      local e = Band(GREEN, level)
      if not e then return end
      local dust, ess = { id = e[3], count = e[4] }, { id = e[5], count = e[6] }
      local main, other = dust, ess
      if weapon then main, other = ess, dust end
      main.chance, other.chance = e[8], e[9]
      local shard = e[10]
      if weapon and level >= 51 then other.chance, shard = 22, 3 end
      rows = { main, other }
      if e[7] then table.insert(rows, { id = e[7], count = { 1, 1 }, chance = shard }) end
    elseif quality == 3 then
      local e = Band(BLUE, level)
      if not e then return end
      if e[3] == 14344 then
        rows = { { id = 14344, count = { 1, 1 }, chance = 99.5 }, { id = NEXUS, count = { 1, 1 }, chance = .5 } }
      else
        rows = { { id = e[3], count = { 1, 1 }, chance = 100 } }
      end
    elseif quality == 4 then
      local e = Band(PURPLE, level)
      if not e then return end
      rows = { { id = e[3], count = e[4], chance = 100 } }
    else
      return
    end
    return { skill = TX.DESkill(level, quality), rows = rows }
  end
  -- what the results are worth at the auction house (pfUI Octo's auction prices), copper or nil
  local function Worth(rows)
    local AH = pfUI.auction
    if not (AH and AH.Value) then return nil end
    local total = 0
    for _, r in ipairs(rows) do
      local ok, price = pcall(AH.Value, tostring(r.id))
      if not ok or not tonumber(price) then
        local ok2, p2 = pcall(AH.Value, r.id .. ":0:0")
        price = ok2 and tonumber(p2) or nil
      end
      if not price then
        if r.chance >= 5 then return nil end
      else
        total = total + r.chance / 100 * (r.count[1] + r.count[2]) / 2 * price
      end
    end
    return total > 0 and math.floor(total) or nil
  end
  function TX.AddDisenchant(tt, id)
    local v = C.tooltip.x_disenchant
    if v == "0" then return end
    -- "auto": always for an enchanter, with Shift for anyone else
    if v == "auto" and not TX.Skill("Enchanting") and not IsShiftKeyDown() then return end
    if v == "shift" and not IsShiftKeyDown() then return end
    local _, _, quality, minlevel, _, _, _, equipLoc = _G.GetItemInfo(id)
    quality = tonumber(quality)
    if not quality or quality < 2 or quality > 4 then return end
    local level = TX.ItemLevel(id) or tonumber(minlevel)
    if not level or level < 1 then return end
    local de = TX.Disenchant(id, quality, level, equipLoc)
    if not de then return end
    local have = TX.Skill("Enchanting")
    local r, g, b = 1, .25, .2
    if have and have >= de.skill then r, g, b = .3, .9, .35 end
    tt:AddDoubleLine("Disenchants into", "Enchanting " .. de.skill, HEAD[1], HEAD[2], HEAD[3], r, g, b)
    for _, row in ipairs(de.rows) do
      local name = _G.GetItemInfo(row.id) or TX.DE_NAMES[row.id] or ("item " .. row.id)
      local cr, cg, cb = ChanceColor(row.chance)
      Row(tt, Count(row.count[1], row.count[2]) .. " x " .. name, Pct(row.chance), cr, cg, cb)
    end
    local worth = Worth(de.rows)
    if worth and CreateGoldString then tt:AddDoubleLine("  Worth about", CreateGoldString(worth), .6, .6, .6, 1, 1, 1) end
  end

  -- ---------------------------------------------------------------- items
  function TX.Item(tt, id, link)
    if not id then return end
    local added = false
    local n0 = tt:NumLines() or 0
    -- the item level beside the name
    if C.tooltip.x_ilvl ~= "0" and (C.tooltip.x_ilvl ~= "shift" or IsShiftKeyDown()) then
      local lvl = TX.ItemLevel(id, link)
      local right = _G[tt:GetName() .. "TextRight1"]
      if lvl and right and (right:GetText() or "") == "" then
        right:SetText("|cffd8b45aItem Level " .. lvl .. "|r")
        right:Show()
        added = true
      end
    end
    -- the sections are written into a buffer first, so the blank line above them is only added
    -- when there is something to show
    local buf = TX.Buffer(tt)
    if Want("x_sources") and pfDB then TX.AddSources(buf, id) end
    if C.tooltip.x_disenchant ~= "0" then TX.AddDisenchant(buf, id) end
    if buf.Flush(n0 > 1) then added = true end
    if added then tt:Show() end
  end
  -- a stand-in tooltip that keeps AddLine / AddDoubleLine calls; Flush(gap) writes them out
  function TX.Buffer(tt)
    local b = { rows = {} }
    function b.AddLine(_, text, r, g, bl, wrap)
      table.insert(b.rows, { 1, text, r, g, bl, wrap })
    end
    function b.AddDoubleLine(_, l, rt, lr, lg, lb, rr, rg, rb)
      table.insert(b.rows, { 2, l, rt, lr, lg, lb, rr, rg, rb })
    end
    function b.NumLines() return tt:NumLines() end
    function b.GetName() return tt:GetName() end
    function b.Flush(gap)
      if table.getn(b.rows) == 0 then return false end
      if gap then tt:AddLine(" ") end
      for _, r in ipairs(b.rows) do
        if r[1] == 1 then tt:AddLine(r[2], r[3], r[4], r[5], r[6])
        else tt:AddDoubleLine(r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]) end
      end
      return true
    end
    return b
  end

  -- ---------------------------------------------------------------- herb and ore nodes
  function TX.Node(tt, name)
    if not (name and D.nodeSkills) then return end
    local sk = D.nodeSkills[name]
    if not sk then return end
    local loot = D.nodeLoot and D.nodeLoot[name]
    local prof = "Mining"
    if loot and loot[1] then
      local first = loot[1][2] or ""
      if not string.find(first, "Ore") and not string.find(name, "Vein") and not string.find(name, "Deposit") then prof = "Herbalism" end
    elseif not string.find(name, "Vein") and not string.find(name, "Deposit") then
      prof = "Herbalism"
    end
    if not TX.ProfWanted("x_gather", prof) then return end
    SkillLine(tt, prof, sk[2])
    if loot then
      local more = IsShiftKeyDown()
      if loot.taps and loot.taps[2] and loot.taps[2] > 1 then
        tt:AddLine("  " .. Count(loot.taps[1], loot.taps[2]) .. " times before it is gone", .6, .6, .6)
      end
      for i = 1, math.min(more and 10 or 3, table.getn(loot)) do
        local d = loot[i]
        Row(tt, Count(d[4], d[5]) .. " x " .. (d[2] or ("item " .. d[1])), Pct(d[3]), ChanceColor(d[3]))
      end
      if not more and table.getn(loot) > 3 then tt:AddLine("  Shift: " .. (table.getn(loot) - 3) .. " more", .5, .5, .5) end
    end
    tt:Show()
  end

  -- ---------------------------------------------------------------- creatures
  -- a creature's ID from its GUID ("0xF130" + six digits of ID + six of spawn); ClassicAPI's
  -- C_CreatureInfo.GetCreatureID when it answers
  function TX.CreatureID(guid)
    if type(guid) ~= "string" then return nil end
    local _, _, digits = string.find(guid, "^0x[Ff]1[13]0(%x%x%x%x%x%x)%x%x%x%x%x%x$")
    if not digits then return nil end
    local ci = _G.C_CreatureInfo
    if ci and ci.GetCreatureID then
      local ok, id = pcall(ci.GetCreatureID, guid)
      if ok and tonumber(id) and tonumber(id) > 0 then return tonumber(id) end
    end
    local id = tonumber(digits, 16)
    return id and id > 0 and id or nil
  end
  -- the Skinning a creature of this level needs (classic: 1 to 10 any, 11-20 x10 - 100, then x5)
  function TX.SkinSkill(level)
    level = tonumber(level) or 1
    if level <= 10 then return 1 end
    if level <= 20 then return (level - 10) * 10 end
    return level * 5
  end
  -- profession lines: "1" only if you have the profession (or Shift is held), "all" for everyone,
  -- "shift" only with Shift, "0" never (user 17 Nov 2026: "i don't need to see skinning info im not a skinner")
  function TX.ProfWanted(key, prof)
    local v = C.tooltip[key]
    if v == "0" then return false end
    if v == "all" then return true end
    if v == "shift" then return IsShiftKeyDown() and true or false end
    return (TX.Skill(prof) or IsShiftKeyDown()) and true or false
  end
  function TX.Skinning(tt, unit, guid)
    if not D.skinningLoot or not TX.ProfWanted("x_skin", "Skinning") then return end
    local cid = TX.CreatureID(guid)
    local loot = cid and D.skinningLoot(cid)
    if not loot then return end
    local level = UnitLevel(unit)
    if not level or level < 1 then level = 63 end
    SkillLine(tt, "Skinning", TX.SkinSkill(level))
    if UnitIsDead(unit) or IsShiftKeyDown() then
      for i = 1, math.min(IsShiftKeyDown() and 6 or 3, table.getn(loot)) do
        local d = loot[i]
        Row(tt, Count(d[4], d[5]) .. " x " .. (d[2] or ("item " .. d[1])), Pct(d[3]), ChanceColor(d[3]))
      end
    end
    return true
  end

  -- mob stats (MobStats 1.7's formulas): armour and its cut of your physical damage, melee hits, and
  -- the average share of your spells each school's resistance takes
  local SCHOOLS = { { 2, "Fire", "df6b6b" }, { 4, "Frost", "3dbddd" }, { 3, "Nature", "85d985" },
                    { 5, "Shadow", "cd81dc" }, { 6, "Arcane", "66d5ce" }, { 1, "Holy", "dada4b" } }
  function TX.ArmorCut(armor, plevel)
    return armor / (armor + 400 + 85 * plevel) * 100
  end
  -- one school's figure as asked: "20%", "75" or "75 (20%)"
  function TX.ResistText(raw, pct, form)
    if form == "raw" then return tostring(raw) end
    if form == "pct" then return pct .. "%" end
    return raw .. DIM .. " (" .. pct .. "%)|r"
  end
  -- average resisted %, from the resistance, your level and the mob's
  function TX.Resist(amount, plevel, mlevel, school)
    amount = math.max(0, amount or 0)
    -- Turtle-built clients (OctoWoW's): no level-based holy resistance
    local levelBased = not (school == 1 and _G.TURTLE_WOW_VERSION)
    if levelBased and mlevel > plevel then amount = amount + (mlevel - plevel) * 8 end
    local cap = math.max(20, plevel) * 5
    local ratio = amount / cap
    return (.75 * ratio - (3 / 16) * math.max(0, ratio - 2 / 3)) * 100
  end
  -- MobStats itself (if it is on) draws its own lines in the game's yellow; while ours are on, its
  -- reader answers nothing, so the tooltip shows one clean set (ours)
  function TX.MuteMobStats()
    local ms = _G.MobStats
    local app = type(ms) == "table" and rawget(ms, "ApplicationService")
    if type(app) ~= "table" or TX.msOrig or type(app.GetMobStats) ~= "function" then return end
    TX.msOrig = app.GetMobStats
    app.GetMobStats = function(self, unit)
      if C.tooltip.x_mobstats ~= "0" then return nil end
      return TX.msOrig(self, unit)
    end
  end
  TX.MuteMobStats()
  -- whole numbers as 1,234
  local function Thousands(n)
    local s = tostring(math.floor(n + .5))
    local out = ""
    while string.len(s) > 3 do
      out = "," .. string.sub(s, -3) .. out
      s = string.sub(s, 1, -4)
    end
    return s .. out
  end
  -- (17 Nov 2026, user: "the mob info is alot more important can we make it clearer and better looking"):
  -- three short lines, a soft label left, the number in white right with its meaning in grey after it;
  -- the mob's hit as a share of your health, coloured by how hard it hits you; no "Resists: None" line
  function TX.MobStats(tt, unit)
    if not Want("x_mobstats") then return end
    TX.MuteMobStats()
    if not (UnitCanAttack("player", unit) and not UnitIsFriend("player", unit) and not UnitIsPlayer(unit)) then return end
    if not UnitResistance then return end
    local plevel = UnitLevel("player") or 60
    local mlevel = UnitLevel(unit) or 0
    if mlevel <= 0 then
      mlevel = UnitClassification(unit) == "worldboss" and 63 or math.min(plevel + 10, 60)
    end
    local shown = false
    if Want("x_mobhits") and UnitDamage and UnitAttackSpeed then
      local lo, hi = UnitDamage(unit)
      local speed = UnitAttackSpeed(unit)
      lo, hi, speed = tonumber(lo), tonumber(hi), tonumber(speed)
      if lo and hi and speed and lo > 0 and speed > 0 then
        local dps = (lo + hi) / 2 / speed
        local maxhp = UnitHealthMax("player") or 0
        local share = maxhp > 0 and (lo + hi) / 2 / maxhp * 100 or nil
        local r, g, b = 1, 1, 1
        if share then
          if share >= 20 then r, g, b = 1, .3, .25 elseif share >= 8 then r, g, b = 1, .8, .25 end
        end
        tt:AddDoubleLine("Hits", Thousands(lo) .. "-" .. Thousands(hi) .. DIM .. "  every " .. string.format("%.1f", speed)
          .. "s  " .. Thousands(dps) .. " dps|r", HEAD[1], HEAD[2], HEAD[3], r, g, b)
        shown = true
      end
    end
    local armor
    if Want("x_mobarmor") then
      local _, a = UnitResistance(unit, 0)
      armor = tonumber(a)
    end
    if armor then
      armor = math.max(0, armor)
      local right = armor == 0 and (DIM .. "none|r") or (Thousands(armor) .. DIM .. "  stops " .. math.floor(TX.ArmorCut(armor, plevel) + .5) .. "% of physical|r")
      tt:AddDoubleLine("Armor", right, HEAD[1], HEAD[2], HEAD[3], 1, 1, 1)
      shown = true
    end
    -- resistances: only the ones that take something; all the same = "All x%"
    -- (20 Nov 2026, Wolfahrt: "it shows Target resistance with % and not raw values") C.tooltip.x_resistform:
    -- pct = the share your spells lose (as before), raw = the resistance itself, both = "Fire 75 (20%)"
    local form = C.tooltip.x_resistform or "both"
    local list, same, first, firstRaw = {}, true, nil, nil
    for _, s in ipairs(Want("x_mobresist") and SCHOOLS or {}) do
      local _, eff = UnitResistance(unit, s[1])
      local raw = math.max(0, math.floor(tonumber(eff) or 0))
      local p = math.floor(TX.Resist(raw, plevel, mlevel, s[1]) + .5)
      local key = p .. ":" .. raw
      if first == nil then first, firstRaw = key, raw elseif key ~= first then same = false end
      local text = TX.ResistText(raw, p, form)
      if (p > 0 or (form ~= "pct" and raw > 0)) and text then table.insert(list, "|cff" .. s[3] .. s[2] .. " " .. text .. "|r") end
    end
    if table.getn(list) > 0 then
      local _, _, fp = string.find(first or "", "^(%d+)")
      local right = (same and table.getn(list) == 6) and ("All " .. TX.ResistText(firstRaw or 0, tonumber(fp) or 0, form))
        or table.concat(list, DIM .. ", |r")
      tt:AddDoubleLine("Resists", right, HEAD[1], HEAD[2], HEAD[3], 1, 1, 1)
      shown = true
    end
    return shown
  end

  function TX.Unit(tt, unit)
    if not unit or not UnitExists(unit) or UnitIsPlayer(unit) then return end
    local guid = lc and lc.GUID and lc.GUID(unit)
    local a = TX.MobStats(tt, unit)
    local b = TX.Skinning(tt, unit, guid)
    if a or b then tt:Show() end
  end

  -- ---------------------------------------------------------------- hooking the tooltip
  -- A frame shown with GameTooltip (as sellvalue.lua): runs once each time a tooltip appears, after
  -- the game filled it. Items through libtooltip; units by mouseover; a world object (no unit, no item)
  -- by its first line.
  local f = CreateFrame("Frame", "pfTooltipExtras", GameTooltip)
  TX.frame = f
  function TX.OnShow()
    local tt = GameTooltip
    local link = libtooltip and libtooltip:GetItemLink()
    if link then
      TX.Item(tt, libtooltip:GetItemID(), link)
      return
    end
    if not tt:IsOwned(UIParent) then return end
    if UnitExists("mouseover") then
      TX.Unit(tt, "mouseover")
      return
    end
    local line = _G.GameTooltipTextLeft1 and _G.GameTooltipTextLeft1:GetText()
    if line and (tt:NumLines() or 0) <= 3 then TX.Node(tt, line) end
  end
  f:SetScript("OnShow", function()
    local ok, err = pcall(TX.OnShow)
    if not ok and DEFAULT_CHAT_FRAME and C.global.errors == "1" then DEFAULT_CHAT_FRAME:AddMessage("|cffff5555pfUI tooltip extras: " .. tostring(err)) end
  end)
  -- unit frames: their tooltips are owned by the frame, not UIParent
  local hookUnit = GameTooltip.SetUnit
  if hookUnit then
    GameTooltip.SetUnit = function(self, unit, a, b)
      local r = hookUnit(self, unit, a, b)
      if self == GameTooltip and unit and unit ~= "mouseover" then pcall(TX.Unit, self, unit) end
      return r
    end
  end
end)
