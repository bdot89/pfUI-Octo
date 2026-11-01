-- load pfUI environment
setfenv(1, pfUI:GetEnvironment())

--[[ libclient ]]--
-- What this client's DLLs add over the plain 1.12 API, behind one set of calls.
-- Every call checks that the DLL function is there and falls back to the plain
-- 1.12 answer (or nil) when it is not, so nothing needs SuperWoW, ClassicAPI or
-- nampower to work - they only make the data better.
--
--  libclient.GUID(unit)
--    The unit's GUID ("0x..."): ClassicAPI UnitGUID, nampower GetUnitGUID or
--    SuperWoW's second UnitExists return. nil without any of them.
--
--  libclient.Aura(unit, index, harmful, texture)
--    ClassicAPI's data for UnitBuff / UnitDebuff(unit, index):
--    name, duration, timeleft, caster, spellId, dispelType, stacks.
--    timeleft / caster are nil when the client did not see the cast.
--    `texture` (the plain UnitBuff texture) guards against index drift: on
--    Turtle-style servers extra debuffs can sit in buff slots, which the plain
--    UnitBuff counts as buffs and ClassicAPI does not.
--
--  libclient.Cast(unit)
--    ClassicAPI's cast or channel of a unit token or GUID:
--    name, texture, startMs, endMs, channel, notInterruptible, delayMs.
--
--  libclient.Distance(unit)
--    Yards from the player (centre to centre): ClassicAPI UnitDistanceSquared,
--    SuperWoW UnitPosition, UnitXP_SP3. nil when none can tell.
--
--  libclient.InRange(unit, yards)
--    true / false when a DLL can tell, nil when not (yards defaults to 40;
--    40 uses ClassicAPI's reach-aware UnitInRange).
--
--  libclient.Stealthed()
--    ClassicAPI IsStealthed(), nil without it.
--
--  libclient.PlayerAura(spellId)
--    true when ClassicAPI finds that spell id among the player's auras.

-- return instantly when another libclient is already active
if pfUI.api.libclient then return end

local libclient = {}

-- names of real unit tokens (C_Spell / C_UnitAuras raise "Unknown unit" on names)
local function IsToken(unit)
  if type(unit) ~= "string" then return nil end
  if pfValidUnits and pfValidUnits[unit] then return true end
  if string.find(unit, "^0x") or string.find(unit, "^nameplate%d+$") then return true end
  return nil
end
libclient.IsToken = IsToken

function libclient.HasSuperWoW()
  return SUPERWOW_VERSION and true or nil
end

function libclient.HasClassicAPI()
  return (C_UnitAuras or C_Spell) and true or nil
end

function libclient.GUID(unit)
  if not unit then return end
  if C_UnitAuras and _G.UnitGUID then
    local ok, guid = pcall(_G.UnitGUID, unit)
    if ok and guid and guid ~= "" then return guid end
  end
  if _G.GetUnitGUID then
    local ok, guid = pcall(_G.GetUnitGUID, unit)
    if ok and guid and guid ~= "" then return guid end
  end
  if SUPERWOW_VERSION then
    local _, guid = UnitExists(unit)
    if guid and guid ~= "" then return guid end
  end
end

function libclient.Aura(unit, index, harmful, texture)
  if not (C_UnitAuras and C_UnitAuras.UnitAura) or not IsToken(unit) or not index then return end
  local ok, name, icon, stacks, dtype, duration, expires, source, _, _, spellId =
    pcall(C_UnitAuras.UnitAura, unit, index, harmful and "HARMFUL" or "HELPFUL")
  if not ok or not name then return end
  if texture and icon and string.lower(icon) ~= string.lower(texture) then return end

  local timeleft
  if expires and expires > 0 and duration and duration > 0 then
    timeleft = expires - GetTime()
    if timeleft < 0 then timeleft = 0 end
  end

  local caster = source
  if caster and caster ~= "player" and UnitIsUnit(caster, "player") then caster = "player" end

  return name, duration, timeleft, caster, spellId, dtype, stacks
end

function libclient.Cast(unit)
  if not C_Spell or not IsToken(unit) then return end
  if C_Spell.UnitCastingInfo then
    local ok, name, _, texture, startMs, endMs, _, _, noint, _, _, delay = pcall(C_Spell.UnitCastingInfo, unit)
    if ok and name and startMs and endMs then return name, texture, startMs, endMs, nil, noint, delay end
  end
  if C_Spell.UnitChannelInfo then
    local ok, name, _, texture, startMs, endMs, _, noint = pcall(C_Spell.UnitChannelInfo, unit)
    if ok and name and startMs and endMs then return name, texture, startMs, endMs, true, noint end
  end
end

function libclient.Distance(unit)
  -- (1 Nov 2026, Fresnel: crash to desktop with UnitXP SP3, no log - a DLL
  -- reading a unit that is not there crashes outside Lua, where pcall cannot
  -- catch it: ask the DLLs only about units that exist)
  if not unit or not UnitExists(unit) then return end
  if C_UnitAuras and _G.UnitDistanceSquared then
    local ok, sq, checked = pcall(_G.UnitDistanceSquared, unit)
    if ok and checked and sq then return math.sqrt(sq) end
  end
  if SUPERWOW_VERSION and _G.UnitPosition then
    local x1, y1, z1 = _G.UnitPosition("player")
    local x2, y2, z2 = _G.UnitPosition(unit)
    if x1 and y1 and z1 and x2 and y2 and z2 then
      return ((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)^.5
    end
  end
  -- (the game's own UnitXP returns experience, a number, for anything: only
  -- UnitXP SP3 answers "inSight" with true / false. brues-code's build has no
  -- "nop" command - testing with it took everyone's SP3 for missing, 1 Nov 2026)
  if libclient.hasSP3 == nil then
    local ok, r = pcall(_G.UnitXP or function() end, "inSight", "player", "player")
    libclient.hasSP3 = ok and type(r) == "boolean"
  end
  if libclient.hasSP3 then
    local ok, d = pcall(_G.UnitXP, "distanceBetween", "player", unit)
    if ok and type(d) == "number" and d >= 0 then return d end
  end
end

function libclient.InRange(unit, yards)
  yards = yards or 40
  if not unit or not UnitExists(unit) then return end
  if UnitIsUnit(unit, "player") then return true end
  if yards == 40 and C_UnitAuras and _G.UnitInRange then
    local ok, inrange, checked = pcall(_G.UnitInRange, unit)
    if ok and checked then return inrange and true or false end
  end
  local d = libclient.Distance(unit)
  if d then return d <= yards end
end

function libclient.Stealthed()
  if C_UnitAuras and _G.IsStealthed then
    local ok, s = pcall(_G.IsStealthed)
    if ok then return s and true or false end
  end
end

function libclient.PlayerAura(spellId)
  if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) or not spellId then return end
  local ok, data = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellId)
  return ok and data and true or nil
end

-- ---------------------------------------------------------------- 25 Oct 2026
-- (user: "I have updated classic api use this wherever we can"; shapes from
-- brues-code/ClassicAPI docs/API.md of that day - NOT seen in game yet)

--  libclient.ItemGUID(bag, slot) / libclient.ItemGUID(nil, invSlot)
--    The item instance's GUID ("0x..."): the very copy, through moves between
--    bags and the character. nil without ClassicAPI or for an empty place.
function libclient.ItemGUID(bag, slot)
  if not (C_Item and C_Item.GetItemGUID) then return end
  local loc = bag and { bagID = bag, slotIndex = slot } or { equipmentSlotIndex = slot }
  local ok, guid = pcall(C_Item.GetItemGUID, loc)
  if ok and guid and guid ~= "" then return guid end
end

--  libclient.IsBound(bag, slot)
--    true / false from ClassicAPI's soulbound bit; nil without it (the caller
--    reads the tooltip then).
function libclient.IsBound(bag, slot)
  if not (C_Item and C_Item.IsBound) then return end
  local ok, bound = pcall(C_Item.IsBound, { bagID = bag, slotIndex = slot })
  if ok then return bound and true or false end
end

--  libclient.LineOfSight(unit)
--    true / false when ClassicAPI can tell (terrain, buildings), nil when not.
function libclient.LineOfSight(unit)
  if not (C_UnitAuras and _G.UnitInLineOfSight) or not unit or not UnitExists(unit) then return end
  local ok, los = pcall(_G.UnitInLineOfSight, unit)
  if ok and los ~= nil then return los and true or false end
end

--  libclient.Copy(text [, plain])
--    Puts text on the Windows clipboard (ClassicAPI CopyToClipboard); plain =
--    without colour codes and links. Returns true when it was copied.
function libclient.Copy(text, plain)
  if not _G.CopyToClipboard or not text then return end
  local ok, n = pcall(_G.CopyToClipboard, text, plain and true or nil)
  return ok and n and n > 0 or nil
end

--  libclient.SwingEvents()
--    true when the client sends PLAYER_SWING (each reset of an attack timer,
--    arg1 = seconds to the next swing, arg2 = 0 main hand / 1 off hand / 2 ranged).
function libclient.SwingEvents()
  if not C_SwingTimer then return end
  if C_EventUtils and C_EventUtils.IsEventValid then
    local ok, valid = pcall(C_EventUtils.IsEventValid, "PLAYER_SWING")
    if ok and not valid then return end
  end
  return true
end

--  libclient.SpellIcon(spellId)
--    The spell's icon path: ClassicAPI C_Spell.GetSpellTexture, else SuperWoW
--    SpellInfo (name, rank, texture). nil when neither is there.
function libclient.SpellIcon(id)
  if not id then return end
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, tex = pcall(C_Spell.GetSpellTexture, id)
    if ok and tex then return tex end
  end
  if SUPERWOW_VERSION and _G.SpellInfo then
    local ok, _, _, tex = pcall(_G.SpellInfo, id)
    if ok and tex then return tex end
  end
end

-- add libclient to pfUI API
pfUI.api.libclient = libclient
