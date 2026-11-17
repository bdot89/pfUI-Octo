-- pfUI Octo: SuperWoW / ClassicAPI / nampower use across the modules
-- (libs\libclient.lua and its users), run by tests\run.lua. First without
-- ClassicAPI (the plain-API fallbacks must keep working), then with stubs
-- shaped like ClassicAPI's docs (API.md: C_UnitAuras.UnitAura, C_Spell.Unit-
-- CastingInfo / UnitChannelInfo, UnitInRange, UnitDistanceSquared, IsStealthed,
-- GetTotemInfo). The stubs follow the docs; the real DLL is not verified here.
local ok = octo_ok
local DIR = octo_dir
local env = pfUI:GetEnvironment()
local LC = pfUI.api.libclient
ok(LC and LC.Aura and LC.Cast and LC.Distance and LC.InRange, "libclient loaded")

-- reload one of pfUI's lib files (they decide some paths at load)
local function Reload(file)
  local h = io.open(DIR .. "/" .. file, "rb")
  local src = h:read("*a")
  h:close()
  local fn, err = loadstring(src, "@" .. file)
  ok(fn, "reload parses: " .. file .. " " .. tostring(err))
  if fn then
    local good, e = pcall(fn)
    ok(good, "reload runs: " .. file .. " " .. tostring(e))
  end
end

-- a target with one buff and one debuff
local TGT = "0x00000000000C0001"
local savedTarget = Mock.target
Mock.Enemy(TGT, "Arcanist", "MAGE", 20, 0, {
  buffs = { { "Interface\\Icons\\Spell_Holy_PowerWordShield", 1, nil, 10901 } },
  debuffs = { { "Interface\\Icons\\Spell_Shadow_ShadowWordPain", 1, "Magic", 10894 } },
})
Mock.target = TGT

-- ---------------------------------------------------------------- without ClassicAPI
C_UnitAuras, C_Spell = nil, nil
ok(not LC.HasClassicAPI(), "no ClassicAPI in the mock by default")
ok(LC.Aura("target", 1, true, "x") == nil, "no ClassicAPI: Aura gives nothing")
ok(LC.Cast("target") == nil, "no ClassicAPI: Cast gives nothing")
ok(LC.Stealthed() == nil, "no ClassicAPI: Stealthed unknown (callers scan buff icons)")
ok(LC.GUID("player") == "0x0000000000000001", "GUID from nampower / SuperWoW (" .. tostring(LC.GUID("player")) .. ")")
-- SuperWoW's UnitPosition (mock: x 20, y 0) gives a distance
local d = LC.Distance("target")
ok(d and math.abs(d - 20) < .01, "SuperWoW distance 20 yd (" .. tostring(d) .. ")")
ok(LC.InRange("target", 40) == true and LC.InRange("target", 10) == false, "InRange from the distance")
ok(env.superwow_active == true, "SuperWoW mode on at load (SUPERWOW_VERSION), not after the first cast event")

-- libdebuff without ClassicAPI: name from the tooltip scan, no timer
local lib = pfUI.api.libdebuff
-- (the mock's tooltip scanner has no lines)
local scan = pfUI.api.libtipscan:GetScanner("libdebuff")
if scan and not scan.NumLines then scan.NumLines = function() return 0 end end
local name, _, tex, _, dtype, duration, left = lib:UnitDebuff("target", 1)
ok(tex == "Interface\\Icons\\Spell_Shadow_ShadowWordPain" and dtype == "Magic" and duration == nil,
  "plain libdebuff: texture and type, no timer (" .. tostring(duration) .. ")")

-- range for every class by position
ok(pfUI.api.librange:UnitInSpellRange("target") == 1, "librange: SuperWoW position says in range (any class)")

-- ---------------------------------------------------------------- ClassicAPI stubs
local now = GetTime()
local AURAS = {
  HELPFUL = { { "Power Word: Shield", "Interface\\Icons\\Spell_Holy_PowerWordShield", 1, "Magic", 30, now + 21, "party1", 10901 } },
  HARMFUL = { { "Shadow Word: Pain", "Interface\\Icons\\Spell_Shadow_ShadowWordPain", 1, "Magic", 24, now + 18, "player", 10894 } },
}
local cast = nil
C_UnitAuras = {
  UnitAura = function(unit, index, filter)
    if unit ~= "target" then return nil end
    local a = AURAS[filter or "HELPFUL"][index]
    if not a then return nil end
    -- name, icon, count, dispelType, duration, expirationTime, source, isStealable,
    -- nameplateShowPersonal, spellId
    return a[1], a[2], a[3], a[4], a[5], a[6], a[7], false, false, a[8]
  end,
  GetPlayerAuraBySpellID = function(id) if id == 17941 then return { spellId = id } end end,
}
C_Spell = {
  UnitCastingInfo = function(unit)
    if cast and (unit == "target" or unit == TGT) and not cast.channel then
      return cast.name, cast.name, cast.icon, cast.s, cast.e, false, "Cast-3-0-0-0-1-1", cast.noint, 1, nil, cast.delay
    end
  end,
  UnitChannelInfo = function(unit)
    if cast and (unit == "target" or unit == TGT) and cast.channel then
      return cast.name, cast.name, cast.icon, cast.s, cast.e, false, cast.noint, 1
    end
  end,
}
local savedG = { UnitInRange = rawget(_G, "UnitInRange"), UnitDistanceSquared = rawget(_G, "UnitDistanceSquared"),
  IsStealthed = rawget(_G, "IsStealthed"), UnitGUID = rawget(_G, "UnitGUID"), GetTotemInfo = rawget(_G, "GetTotemInfo"),
  CooldownFrame_SetTimer = rawget(_G, "CooldownFrame_SetTimer") }
local inrange = true
_G.UnitInRange = function(u) if u == "target" then return inrange, true end return false, false end
_G.UnitDistanceSquared = function(u) if u == "target" then return 900, true end return 0, false end
_G.IsStealthed = function() return true end
ok(LC.HasClassicAPI(), "ClassicAPI stubs seen")

-- auras: timer, caster, the texture guard
local an, adur, aleft, acaster, aid, atype = LC.Aura("target", 1, true, "Interface\\ICONS\\spell_shadow_shadowwordpain")
ok(an == "Shadow Word: Pain" and adur == 24 and math.abs(aleft - 18) < .01 and acaster == "player" and aid == 10894 and atype == "Magic",
  "ClassicAPI aura: name, 24 s with 18 left, yours, id, type (" .. tostring(an) .. " " .. tostring(adur) .. " " .. tostring(aleft) .. " " .. tostring(acaster) .. ")")
ok(LC.Aura("target", 1, true, "Interface\\Icons\\Other") == nil, "texture guard: a different icon at that index gives nothing")
ok(LC.Aura("Arcanist", 1, true) == nil, "a name is not a unit token: nothing asked")

-- libdebuff now: ClassicAPI's name, timer and caster
name, _, tex, _, dtype, duration, left, caster = lib:UnitDebuff("target", 1)
ok(name == "Shadow Word: Pain" and duration == 24 and math.abs(left - 18) < .01 and caster == "player",
  "libdebuff takes ClassicAPI's timer and caster (" .. tostring(name) .. " " .. tostring(duration) .. " " .. tostring(caster) .. ")")
local own = lib:UnitOwnDebuff("target", 1)
ok(own == "Shadow Word: Pain", "own debuff found by ClassicAPI's caster")

-- distance / range
d = LC.Distance("target")
ok(d and math.abs(d - 30) < .01, "ClassicAPI distance from UnitDistanceSquared 900 -> 30 (" .. tostring(d) .. ")")
ok(LC.InRange("target", 40) == true, "40 yd uses UnitInRange")
inrange = false
ok(pfUI.api.librange:UnitInSpellRange("target") == nil, "librange: UnitInRange says out of range")
inrange = true
ok(pfUI.api.librange:UnitInSpellRange("target") == 1, "librange: UnitInRange says in range")
ok(LC.Stealthed() == true, "IsStealthed read")
ok(pfUI.barsOcto and pfUI.barsOcto.Stealthed and pfUI.barsOcto.Stealthed() == true, "action bars: stealth from IsStealthed")
ok(LC.PlayerAura(17941) and not LC.PlayerAura(1), "player aura by spell id")

-- cast bars: libcast decides at load, so load it again with C_Spell there
local savedCast = { env.UnitCastingInfo, env.UnitChannelInfo, pfUI.api.libcast }
pfUI.api.libcast = nil
Reload("libs/libcast.lua")
cast = { name = "Polymorph", icon = "Interface\\Icons\\Spell_Nature_Polymorph", s = now * 1000, e = now * 1000 + 1500, noint = true, delay = 300 }
local cn, rank, _, ctex, cs, ce, _, noint, delay = env.UnitCastingInfo("target")
ok(cn == "Polymorph" and ce - cs == 1500 and noint == true and delay == 300 and rank == "",
  "UnitCastingInfo from ClassicAPI with can't-interrupt and pushback (" .. tostring(cn) .. ")")
ok(env.UnitChannelInfo("target") == nil, "a cast is not a channel")
cast.channel = true
ok(env.UnitChannelInfo("target") == "Polymorph" and env.UnitCastingInfo("target") == nil, "a channel is not a cast")
cast = nil
ok(env.UnitCastingInfo("target") == nil, "no ClassicAPI cast: libcast's own data (none)")

-- the target cast bar paints a can't-interrupt cast in its colour
local cb = pfUI.castbar and pfUI.castbar.target
if cb then
  cast = { name = "Polymorph", icon = "Interface\\Icons\\Spell_Nature_Polymorph", s = now * 1000, e = now * 1000 + 1500, noint = true }
  cb.endTime = nil
  Mock.Run(cb, "OnUpdate")
  local r, g, b = cb.bar:GetStatusBarColor()
  local nr, ng, nb = pfUI.api.strsplit(",", pfUI_config.appearance.castbar.nointcolor)
  ok(tonumber(r) == tonumber(nr) and tonumber(g) == tonumber(ng) and tonumber(b) == tonumber(nb),
    "cast bar: can't-interrupt colour (" .. tostring(r) .. "," .. tostring(g) .. "," .. tostring(b) .. ")")
  cast.noint = false
  Mock.Run(cb, "OnUpdate")
  r = cb.bar:GetStatusBarColor()
  local cr = pfUI.api.strsplit(",", pfUI_config.appearance.castbar.castbarcolor)
  ok(tonumber(r) == tonumber(cr), "cast bar: normal colour again (" .. tostring(r) .. ")")
  cast = nil
  Mock.Run(cb, "OnUpdate")
else
  ok(false, "target cast bar exists in the mock")
end
env.UnitCastingInfo, env.UnitChannelInfo, pfUI.api.libcast = savedCast[1], savedCast[2], savedCast[3]

-- unit frame buffs: timer and purge frame from ClassicAPI
local UO = pfUI.ufExtras
local tf = pfUI.uf and pfUI.uf.target
if UO and UO.Auras and tf and tf.buffs and tf.buffs[1] then
  local timers = {}
  _G.CooldownFrame_SetTimer = function(cd, s, dur, on) timers[cd] = { s, dur, on } end
  env.CooldownFrame_SetTimer = nil
  local b = tf.buffs[1]
  b:Show()
  local border
  if b.backdrop then b.backdrop.SetBackdropBorderColor = function(self, r, g, bl) border = { r, g, bl } end end
  local savedPurge = tf.config.o_purge
  tf.config.o_purge = "1"
  UO.Auras(tf)
  local t = timers[b.cd]
  ok(t and t[2] == 30 and math.abs(t[1] - (now + 21 - 30)) < .01, "target buff gets ClassicAPI's timer (30 s, 21 left)")
  ok(border and DebuffTypeColor and DebuffTypeColor.Magic and border[3] == DebuffTypeColor.Magic.b,
    "enemy magic buff framed for purge")
  tf.config.o_purge = "0"
  UO.Auras(tf)
  ok(not b.octoPurge, "purge frame off again")
  tf.config.o_purge = savedPurge
  _G.CooldownFrame_SetTimer = savedG.CooldownFrame_SetTimer
  b:Hide()
else
  ok(false, "unit frame extras and a target frame with buffs in the mock")
end

-- tooltip: who cast it
local tip = GameTooltip
tip:SetOwner(UIParent, "ANCHOR_NONE")
pfUI_config.tooltip.auracaster = "1"
-- (an earlier test may have its own party1 and UnitName for it: keep them)
local savedParty = Mock.units["party1"]
if not savedParty then Mock.Enemy("party1", "Priestly", "PRIEST", 5, 0) end
tip:SetUnitBuff("target", 1)
local found
for _, l in ipairs(tip.lines or {}) do if string.find(tostring(l), "^Cast by %S") then found = true end end
ok(found, "buff tooltip says who cast it (" .. table.concat(tip.lines or {}, " | ") .. ")")
pfUI_config.tooltip.auracaster = "0"
tip:SetOwner(UIParent, "ANCHOR_NONE")
tip:SetUnitBuff("target", 1)
ok(table.getn(tip.lines or {}) == 0, "switched off: no caster line")
pfUI_config.tooltip.auracaster = "1"
if not savedParty then Mock.units["party1"] = nil end

-- totems: ClassicAPI's tracker (libtotem decides at load)
local savedTotem = env.GetTotemInfo
_G.GetTotemInfo = function(slot)
  if slot == 1 then return true, "Searing Totem", now - 5, 55, "Interface\\Icons\\Spell_Fire_SearingTotem", 1, 10438 end
  return true, "", 0, 0, nil, 1, 0
end
Reload("libs/libtotem.lua")
local active, tname, tstart, tdur = env.GetTotemInfo(1)
ok(active == 1 and tname == "Searing Totem" and tdur == 55, "GetTotemInfo from ClassicAPI's tracker")
ok(env.GetTotemInfo(2) == nil, "an empty slot (tool held, no totem) is not a totem")
env.GetTotemInfo = savedTotem

-- ---------------------------------------------------------------- Thirdparty > Integrations
-- rows only for addons whose folder is there (enabled or not)
local Has = pfUI.gui and pfUI.gui.HasAddon
ok(Has, "integrations page has its installed check")
if Has then
  local realInfo = GetAddOnInfo
  _G.GetAddOnInfo = function(name)
    if name == "EvenBetterCharacterStats" then return name, name, "", nil, 1, "DISABLED" end
    if name == "WIM" then return nil, nil, nil, nil, nil, "MISSING" end
    if name == "Broken" then error("no such addon") end
    return realInfo(name)
  end
  ok(Has("BetterCharacterStats", "EvenBetterCharacterStats"), "an installed (even disabled) addon shows its row")
  ok(not Has("WIM"), "a missing addon has no row")
  ok(not Has("Broken") and not Has("ShaguDPS"), "an error or nothing back means no row")
  _G.GetAddOnInfo = realInfo
end

-- ---------------------------------------------------------------- spell icons (queued spell on the cast bar)
do
  local savedSpell = C_Spell
  C_Spell = { GetSpellTexture = function(id) return id == 133 and "Interface\\Icons\\Spell_Fire_FlameBolt" or nil end }
  ok(LC.SpellIcon(133) == "Interface\\Icons\\Spell_Fire_FlameBolt", "spell icon by id from ClassicAPI")
  ok(LC.SpellIcon(nil) == nil, "no id, no icon")
  C_Spell = savedSpell
end

-- ---------------------------------------------------------------- loot roll history (/loothistory)
-- (the loot module needs more of the client than the mock has: line 372's
-- table; these run once it starts there)
local LH = pfUI.loot and pfUI.loot.history
if LH and LH.Refresh then
  local savedAuras, savedLH = C_UnitAuras, rawget(_G, "C_LootHistory")
  LH:Refresh()
  ok(LH.empty:GetText() and string.find(LH.empty:GetText(), "ClassicAPI"), "no ClassicAPI: the window says it needs it")
  C_UnitAuras = savedAuras or {}
  _G.C_LootHistory = {
    GetNumItems = function() return 2 end,
    GetItem = function(i)
      if i == 1 then return 11, "item:2589:0:0:0", 2, true, 2 end
      return 12, "item:2592:0:0:0", 1, false, nil
    end,
    GetPlayerInfo = function(i, p)
      if p == 1 then return "Arcanist", "MAGE", 2, 40, false, true end
      return "Shemp", "WARRIOR", 1, 88, true, false
    end,
    Clear = function() end,
  }
  LH:Refresh()
  local r1, r2 = LH.rows[1], LH.rows[2]
  ok(r1.entry and r1.entry.rollID == 12 and string.find(r1.right:GetText() or "", "Rolling"), "newest roll first, still rolling")
  ok(r2.entry and r2.entry.rollID == 11 and string.find(r2.right:GetText() or "", "Shemp"), "finished roll names the winner")
  _G.this = r2
  r2:GetScript("OnClick")()
  ok(LH.rows[3].entry and LH.rows[3].entry.kind == "player" and LH.rows[4].entry, "click an item: everyone's roll under it")
  C_UnitAuras, _G.C_LootHistory = savedAuras, savedLH
end

-- ---------------------------------------------------------------- the tooltip anchor
-- (user, 26 Oct 2026: a friend couldn't find it) "anchor" finds it in the
-- options' search, and moving its box in layout mode makes tooltips use it
do
  local found
  for _, e in pairs(pfUI.gui and pfUI.gui.searchDB or {}) do
    if e[0] and string.find(string.lower(e[0]), "anchor", 1, true) and string.find(string.lower(e[0]), "tooltip", 1, true) then found = true end
  end
  ok(found, "the search finds the tooltip anchor")
  local a = pfUI.tooltip and pfUI.tooltip.anchorframe
  if a and a.OnMove and pfUI.unlock then
    local savedPos, savedWhere = pfUI_config.position["pfTooltipAnchor"], pfUI_config.tooltip.position
    pfUI_config.tooltip.position = "bottom"
    pfUI_config.position["pfTooltipAnchor"] = { anchor = "CENTER", xpos = 0, ypos = 0 }
    pfUI.unlock:Show()
    a:OnMove()
    ok(pfUI_config.tooltip.position == "free", "moving the anchor box: tooltips show there")
    pfUI.unlock:Hide()
    pfUI_config.tooltip.position = "bottom"
    a:OnMove()
    ok(pfUI_config.tooltip.position == "bottom", "outside layout mode nothing changes")
    pfUI_config.position["pfTooltipAnchor"], pfUI_config.tooltip.position = savedPos, savedWhere
  end
end

-- ---------------------------------------------------------------- layout mode: Hide a frame
local UH = pfUI.unlockHidden
ok(UH and UH.Apply, "layout mode can hide frames")
if UH and UH.Apply then
  local f = CreateFrame("Frame", "pfTestHideMe", UIParent)
  pfUI.movables = pfUI.movables or {}
  pfUI.movables["pfTestHideMe"] = f
  pfUI_config.unlock.hidden = pfUI_config.unlock.hidden or {}
  pfUI_config.unlock.hidden["pfTestHideMe"] = "1"
  UH.Apply()
  ok(f:GetParent() == _G.pfUnlockHider and UH.IsHidden(f), "a hidden frame sits under the hidden parent")
  UH.Back(f)
  ok(f:GetParent() == UIParent, "Show puts it back on its own parent")
  pfUI_config.unlock.hidden["pfTestHideMe"] = nil
  pfUI.movables["pfTestHideMe"] = nil
end

-- ---------------------------------------------------------------- layout mode: mirror lines, Match order
local U = pfUI.unlock
if U and U.MirrorLines and U.Likeness then
  local savedx = pfUI_config.unlock.mirrorx
  pfUI_config.unlock.mirrorx = "300"
  local mx = U.MirrorLines()
  local w = GetScreenWidth()
  ok(math.abs(mx[1] - (w / 2 - 300)) < .01 and math.abs(mx[2] - (w / 2 + 300)) < .01, "mirror lines: the pair sits the same way either side of the middle")
  pfUI_config.unlock.mirrorx = savedx

  local function Box(name, label, bw, bh)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetWidth(bw) f:SetHeight(bh)
    f.drag = { label = label }
    return f
  end
  local inc = Box("pfTestCTIn", "CombatTextIncoming", 200, 300)
  local out = Box("pfTestCTOut", "CombatTextOutgoing", 200, 300)
  local pet = Box("pfTestPartyPet", "PartyPet1", 80, 20)
  local s1, s2 = U.Likeness(inc, out), U.Likeness(inc, pet)
  ok(s1 > s2, "Match: Combat Text: Outgoing comes before Party Pet for Combat Text: Incoming (" .. s1 .. " / " .. s2 .. ")")
end

-- ---------------------------------------------------------------- bag sorting
local BS = pfUI.api.libbagsort
ok(BS and BS.Sort and BS.Step, "bag sort lib loaded")
if BS and BS.Step then
  local saved = {}
  local function Stub(name, fn) saved[name] = rawget(_G, name) _G[name] = fn end
  local function It(id, name, quality, equip, count, stack)
    return { link = "|cffffffff|Hitem:" .. id .. ":0:0:0|h[" .. name .. "]|h|r", id = id, name = name,
             quality = quality, equip = equip or "", count = count or 1, stack = stack or 1 }
  end
  local bag = { [1] = It(4306, "Silk Cloth", 1, nil, 5, 20), [2] = It(2589, "Grey Junk", 0),
                [3] = It(6948, "Hearthstone", 1), [4] = It(4306, "Silk Cloth", 1, nil, 12, 20), [5] = nil,
                [6] = It(10000, "Plate Helm", 2, "INVTYPE_HEAD") }
  local cursor
  Stub("GetContainerNumSlots", function(b) return b == 0 and 6 or 0 end)
  Stub("GetContainerItemLink", function(b, s) return b == 0 and bag[s] and bag[s].link end)
  Stub("GetContainerItemInfo", function(b, s) local it = b == 0 and bag[s] return it and "tex", it and it.count, nil end)
  Stub("GetItemInfo", function(id)
    for _, it in pairs(bag) do if it.id == id then return it.name, it.link, it.quality, 1, "Type", "Sub", it.stack, it.equip end end
  end)
  Stub("CursorHasItem", function() return cursor ~= nil end)
  Stub("SplitContainerItem", function(b, s, n) bag[s].count = bag[s].count - n cursor = { item = bag[s], n = n, split = true } end)
  Stub("PickupContainerItem", function(b, s)
    local here = bag[s]
    if not cursor then bag[s] = nil cursor = here and { item = here, from = s } return end
    if here and here.id == cursor.item.id and here ~= cursor.item then
      here.count = here.count + (cursor.n or cursor.item.count)
      cursor = nil
      return
    end
    if cursor.split then bag[s] = It(cursor.item.id, cursor.item.name, cursor.item.quality, cursor.item.equip, cursor.n, cursor.item.stack)
    else bag[s] = cursor.item end
    if here and cursor.from then bag[cursor.from] = here end
    cursor = nil
  end)
  local slots = {}
  for s = 1, 6 do slots[s] = { bag = 0, slot = s } end
  local n = 0
  while BS.Step(slots) and n < 50 do n = n + 1 end
  ok(bag[1] and bag[1].name == "Hearthstone" and bag[2] and bag[2].name == "Plate Helm" and bag[3] and bag[3].count == 17
    and bag[6] and bag[6].name == "Grey Junk", "plain sort: hearthstone, gear, stacks topped up (17), grey last (" .. n .. " moves)")
  for k, v in pairs(saved) do _G[k] = v end

  -- ClassicAPI: one call, the client sorts
  local savedAuras, savedCont = C_UnitAuras, rawget(_G, "C_Container")
  local sorted
  C_UnitAuras = C_UnitAuras or {}
  _G.C_Container = { SortBags = function() sorted = "bags" end, SortBankBags = function() sorted = "bank" end }
  ok(BS:Sort("bags") and sorted == "bags" and not BS.run, "ClassicAPI: C_Container.SortBags, no cursor moves")
  sorted = nil
  local savedBank = rawget(_G, "BankFrame")
  _G.BankFrame = { IsShown = function() return nil end }
  ok(not BS:Sort("bank") and sorted == nil, "the bank only while it is open")
  _G.BankFrame.IsShown = function() return 1 end
  ok(BS:Sort("bank") and sorted == "bank", "an open bank: C_Container.SortBankBags")
  C_UnitAuras, _G.C_Container, _G.BankFrame = savedAuras, savedCont, savedBank
end

-- ---------------------------------------------------------------- unit frame events
-- ClassicAPI frame:RegisterUnitEvent: a unit frame hears only its own unit
do
  local reg = {}
  local f = { unitevents = true,
    RegisterUnitEvent = function(self, e, u) reg[e] = u end,
    UnregisterEvent = function(self, e) reg[e] = nil end }
  pfUI.uf.RegisterUnitEvents(f, "raid3")
  ok(reg.UNIT_HEALTH == "raid3" and reg.UNIT_AURA == "raid3", "unit frame: its own unit's events only (RegisterUnitEvent)")
  pfUI.uf.RegisterUnitEvents(f, "")
  ok(reg.UNIT_HEALTH == nil and reg.UNIT_AURA == nil, "unit frame without a unit: unit events dropped")
  local named = { unitname = "focus", unitevents = true, RegisterUnitEvent = function() error("filtered") end }
  ok(pcall(pfUI.uf.RegisterUnitEvents, named, "player"), "a frame following a name keeps plain events")

  -- a health tick refreshes the bars only; coming into sight refreshes it all
  local saved = { this = rawget(_G, "this"), event = rawget(_G, "event"), arg1 = rawget(_G, "arg1"),
                  vis = rawget(_G, "UnitIsVisible") }
  local seen = true
  _G.UnitIsVisible = function() return seen end
  local h = { label = "party", id = "1" }
  _G.this, _G.event, _G.arg1 = h, "UNIT_HEALTH", "party1"
  pfUI.uf.OnEvent()
  ok(h.update_full, "first health event of a frame: full refresh")
  h.update_full = nil
  pfUI.uf.OnEvent()
  ok(h.update_base and not h.update_full, "next health event: bars only, no aura / portrait rescan")
  h.update_base, seen = nil, false
  pfUI.uf.OnEvent()
  ok(h.update_full, "unit out of sight: full refresh")
  _G.this, _G.event, _G.arg1, _G.UnitIsVisible = saved.this, saved.event, saved.arg1, saved.vis
end

-- ---------------------------------------------------------------- info panels: own size, never a scale
local PL = pfUI.panel and pfUI.panel.left
ok(PL and pfUI.panel.Size, "panels have their own size")
if PL and pfUI.panel.Size then
  local cfg = pfUI_config.panel.left
  local ow, oh = cfg.pwidth, cfg.pheight
  PL:SetScale(1.3)
  cfg.pwidth, cfg.pheight = "300", "30"
  pfUI.panel.Size("left")
  ok(PL:GetWidth() == 300 and PL:GetHeight() == 30, "width and height set apart (" .. tostring(PL:GetWidth()) .. " x " .. tostring(PL:GetHeight()) .. ")")
  ok(PL:GetScale() ~= 1.3, "a scale of its own is dropped")
  ok(PL.left and PL.left:GetHeight() == 30, "its texts are as tall as the bar")
  cfg.pwidth, cfg.pheight = ow, oh
  pfUI.panel.Size("left")
end

-- ---------------------------------------------------------------- back to the plain mock
C_UnitAuras, C_Spell = nil, nil
for k, v in pairs(savedG) do rawset(_G, k, v) end
Mock.units[TGT] = nil
Mock.target = savedTarget

-- (16 Nov 2026, Lobo: "libpredict.lua:860: bad argument #2 to 'insert'") with ClassicAPI, UnitName returns the
-- realm too: a bare UnitName(...) as the last argument of table.insert adds a third argument. Wrap it: (UnitName(u)).
do
  local bad = {}
  for _, dir in ipairs({ "modules", "libs", "api" }) do
    local p = io.popen and io.popen('dir /b "' .. string.gsub(DIR, "/", "\\") .. '\\' .. dir .. '\\*.lua"')
    if p then
      for name in p:lines() do
        local fh = io.open(DIR .. "/" .. dir .. "/" .. name, "r")
        if fh then
          local n = 0
          for line in fh:lines() do
            n = n + 1
            if string.find(line, "insert%([^%(%)]*,%s*UnitName%(") then table.insert(bad, dir .. "/" .. name .. ":" .. n) end
          end
          fh:close()
        end
      end
      p:close()
    end
  end
  octo_ok(table.getn(bad) == 0, "no table.insert(..., UnitName(...)) without brackets" .. (bad[1] and (": " .. table.concat(bad, ", ")) or ""))
end

-- (17 Nov 2026) ClassicAPI's timers and change events (libclient.Every / On / Seen, and their users)
do
  local LCx = pfUI.api.libclient
  -- Every without C_Timer: a throttled OnUpdate, `this` = the frame
  local keepCT = rawget(_G, "C_Timer")
  _G.C_Timer = nil
  local fr = CreateFrame("Frame")
  local runs, who = 0, nil
  LCx.Every(fr, 1, function() runs = runs + 1 who = _G.this end)
  local up = fr:GetScript("OnUpdate")
  local t0 = Mock.now
  _G.this = fr up()
  Mock.now = t0 + .5 _G.this = fr up()
  Mock.now = t0 + 1.1 _G.this = fr up()
  octo_ok(runs == 2 and who == fr, "Every without ClassicAPI: a throttled OnUpdate (" .. runs .. " runs)")
  -- with C_Timer: the OnUpdate goes once the ticker has fired; the ticker runs fn with this = the frame
  local made = {}
  _G.C_Timer = { NewTicker = function(secs, cb) local t = { secs = secs, cb = cb } table.insert(made, t) return t end }
  local fr2 = CreateFrame("Frame")
  local n2, who2 = 0, nil
  LCx.Every(fr2, .25, function() n2 = n2 + 1 who2 = _G.this end)
  octo_ok(made[1] and made[1].secs == .25 and fr2:GetScript("OnUpdate") ~= nil, "Every with C_Timer: ticker made, OnUpdate kept until it fires")
  _G.this = nil
  made[1].cb()
  octo_ok(n2 == 1 and who2 == fr2 and _G.this == nil, "the ticker runs it with this = the frame (and puts this back)")
  _G.this = fr2 fr2:GetScript("OnUpdate")()
  octo_ok(fr2:GetScript("OnUpdate") == nil, "after the ticker has fired the OnUpdate is gone")
  fr2:Hide()
  made[1].cb()
  octo_ok(n2 == 1, "a hidden frame's ticker does nothing (as an OnUpdate would not run)")
  _G.C_Timer = keepCT
  -- the event hub: counts and hands on
  local got
  LCx.On("OCTO_TEST_EVENT", function(ev, a1) got = a1 end)
  octo_ok(LCx.Seen("OCTO_TEST_EVENT") == nil, "an event not seen yet reads nil (the old way stays)")
  local h = LCx.hub:GetScript("OnEvent")
  _G.event, _G.arg1 = "OCTO_TEST_EVENT", "x"
  h()
  octo_ok(got == "x" and LCx.Seen("OCTO_TEST_EVENT") == 1, "the hub hands an event on and counts it")
  -- moving / standing
  _G.event = "PLAYER_STOPPED_MOVING" h()
  octo_ok(LCx.Moving() == false, "standing still from PLAYER_STOPPED_MOVING")
  _G.event = "PLAYER_STARTED_MOVING" h()
  octo_ok(LCx.Moving() == true, "moving from PLAYER_STARTED_MOVING")
  LCx.moving = nil
  -- cast bars: an event for the bar's unit wakes it, and from then it rests a second when idle
  local cb = pfUI.castbar and pfUI.castbar.player
  if cb then
    cb.restUntil = Mock.now + 5
    _G.event, _G.arg1 = "UNIT_SPELLCAST_START", "player"
    h()
    octo_ok(cb.restUntil == nil and pfUI.castbar.evSeen.player, "UNIT_SPELLCAST_START for the player wakes the player cast bar")
    _G.event, _G.arg1 = "UNIT_SPELLCAST_START", "raid7"
    cb.restUntil = Mock.now + 5
    h()
    octo_ok(cb.restUntil ~= nil, "another unit's cast leaves it resting")
    cb.restUntil = nil
  end
  -- action bars: the range event marks the bar as event-driven
  local bars = _G.pfActionBar
  if bars and rawget(_G, "C_ActionBar") then
    _G.event, _G.arg1 = "ACTION_RANGE_CHECK_UPDATE", 5
    h()
    octo_ok(bars.rangeEvents, "ACTION_RANGE_CHECK_UPDATE: the action bars go by the event")
  end
  _G.event, _G.arg1 = nil, nil
  local PWx = pfUI.perf and pfUI.perf.win
  if PWx and PWx.EventLines then
    local lines = PWx.EventLines()
    octo_ok(string.find(lines[1], "C_Timer", 1, true) and table.getn(lines) == table.getn(PWx.EVENTS) + 1, "/pfperf events lists the timers and events")
  end
end
