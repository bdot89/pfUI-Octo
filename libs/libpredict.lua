-- load pfUI environment
setfenv(1, pfUI:GetEnvironment())

--[[ libpredict ]]--
-- A pfUI library that detects, receives and sends heal and resurrection predictions.
-- Healing predictions are done by caching the last known "normal" heal value of the
-- spell when last being used. Those chaches are cleared when new talents are detected.
-- The API provides function calls similar to later WoW expansions such as:
--   UnitGetIncomingHeals(unit)
--   UnitHasIncomingResurrection(unit)
--
-- The library is able to receive and send compatible messages to HealComm (vanilla)
-- and HealComm (tbc) including the ressurections of both versions. It has an option
-- to disable the sending of those messages in case one of the mentioned libraries
-- is already active.

-- return instantly when another libpredict is already active
if pfUI.api.libpredict then return end

local senttarget
local heals, ress, events, hots = {}, {}, {}, {}

local PRAYER_OF_HEALING
do -- Prayer of Healing
  local locales = {
    ["deDE"] = "Gebet der Heilung",
    ["enUS"] = "Prayer of Healing",
    ["esES"] = "Rezo de curación",
    ["frFR"] = "Prière de soins",
    ["koKR"] = "치유의 기원",
    ["ruRU"] = "Молитва исцеления",
    ["zhCN"] = "治疗祷言",
  }

  PRAYER_OF_HEALING = locales[GetLocale()] or locales["enUS"]
end

local REJUVENATION
do -- Rejuvenation
  local locales = {
    ["deDE"] = "Verjüngung",
    ["enUS"] = "Rejuvenation",
    ["esES"] = "Rejuvenecimiento",
    ["frFR"] = "Récupération",
    ["koKR"] = "회복",
    ["ruRU"] = "Омоложение",
    ["zhCN"] = "回春术",
  }

  REJUVENATION = locales[GetLocale()] or locales["enUS"]
end

local RENEW
do -- Renew
  local locales = {
    ["deDE"] = "Erneuerung",
    ["enUS"] = "Renew",
    ["esES"] = "Renovar",
    ["frFR"] = "Rénovation",
    ["koKR"] = "소생",
    ["ruRU"] = "Обновление",
    ["zhCN"] = "恢复",
  }

  RENEW = locales[GetLocale()] or locales["enUS"]
end

local REGROWTH
do -- Regrowth
  local locales = {
    ["deDE"] = "Nachwachsen",
    ["enUS"] = "Regrowth",
    ["esES"] = "Recrecimiento",
    ["frFR"] = "Rétablissement",
    ["koKR"] = "재생",
    ["ruRU"] = "Восстановление",
    ["zhCN"] = "愈合",
  }

  REGROWTH = locales[GetLocale()] or locales["enUS"]
end

local libpredict = CreateFrame("Frame")
libpredict:RegisterEvent("UNIT_HEALTH")
libpredict:RegisterEvent("CHAT_MSG_ADDON")
libpredict:RegisterEvent("PLAYER_TARGET_CHANGED")
libpredict:SetScript("OnEvent", function()
  if event == "CHAT_MSG_ADDON" and (arg1 == "HealComm" or arg1 == "CTRA") then
    this:ParseChatMessage(arg4, arg2, arg1)
  elseif event == "UNIT_HEALTH" then
    local name = UnitName(arg1)
    if ress[name] and not UnitIsDeadOrGhost(arg1) then
      ress[UnitName(arg1)] = nil
    end
  end
end)

libpredict:SetScript("OnUpdate", function()
  -- only housekeeping (readers check the end times themselves): twice a second
  local now = GetTime()
  if (this.tick or 0) > now then return end
  this.tick = now + .5

  -- update on timeout events
  for timestamp, targets in pairs(events) do
    if now >= timestamp then
      events[timestamp] = nil
    end
  end
end)

function libpredict:ParseComm(sender, msg)
  local msgtype, target, heal, time

  if msg == "Healstop" or msg == "GrpHealstop" then
    msgtype = "Stop"
  elseif msg == "Resurrection/stop/" then
    msgtype = "RessStop"
  elseif msg then
    local msgobj = {strsplit("/", msg)}

    if msgobj and msgobj[1] and msgobj[2] then
      -- legacy healcomm object
      if msgobj[1] == "GrpHealdelay" or msgobj[1] == "Healdelay" then
        msgtype, time = "Delay", msgobj[2]
      end

      if msgobj[1] and msgobj[1] == "Resurrection" and msgobj[2] then
        msgtype, target = "Ress", msgobj[2]
      end

      if msgobj[1] == "Heal" and msgobj[2] then
        msgtype, target, heal, time = "Heal", msgobj[2], msgobj[3], msgobj[4]
      end

      if msgobj[1] == "GrpHeal" and msgobj[2] then
        msgtype, target, heal, time = "Heal", {}, msgobj[2], msgobj[3]
        for i=4,8 do
          if msgobj[i] then table.insert(target, msgobj[i]) end
        end
      end

      if msgobj[1] == "Reju" or msgobj[1] == "Renew" or msgobj[1] == "Regr" then --hots
        msgtype, target, heal, time = "Hot", msgobj[2], msgobj[1], msgobj[3]
      end
    elseif select and UnitCastingInfo then
      -- latest healcomm
      msgtype = tonumber(string.sub(msg, 1, 3))
      if not msgtype then return end

      if msgtype == 0 then
        msgtype = "Heal"
        heal = tonumber(string.sub(msg, 4, 8))
        target = string.sub(msg,9, -1)

        local starttime = select(5, UnitCastingInfo(sender))
        local endtime = select(6, UnitCastingInfo(sender))
        if not starttime or not endtime then return end
        time = endtime - starttime
      elseif msgtype == 1 then
        msgtype = "Stop"
      elseif msgtype == 2 then
        msgtype = "Heal"
        heal = tonumber(string.sub(msg,4, 8))
        target = {strsplit(":", string.sub(msg,9, -1))}
        local starttime = select(5, UnitCastingInfo(sender))
        local endtime = select(6, UnitCastingInfo(sender))
        if not starttime or not endtime then return end
        time = endtime - starttime
      end
    end
  end

  return msgtype, target, heal, time
end

function libpredict:ParseChatMessage(sender, msg, comm)
  local msgtype, target, heal, time

  if comm == "HealComm" then
    msgtype, target, heal, time = libpredict:ParseComm(sender, msg)
  elseif comm == "CTRA" then
    local _, _, cmd, ctratarget = string.find(msg, "(%a+)%s?([^#]*)")
    if cmd and ctratarget and cmd == "RES" and ctratarget ~= "" and ctratarget ~= UNKNOWN then
      msgtype = "Ress"
      target = ctratarget
    end
  end

  if msgtype == "Stop" and sender then
    libpredict:HealStop(sender)
    return
  elseif ( msg == "RessStop" or msg == "RESNO" ) and sender then
    libpredict:RessStop(sender)
    return
  elseif msgtype == "Delay" and time then
    libpredict:HealDelay(sender, time)
  elseif msgtype == "Heal" and target and heal and time then
    if type(target) == "table" then
      for _, name in pairs(target) do
        libpredict:Heal(sender, name, heal, time)
      end
    else
      libpredict:Heal(sender, target, heal, time)
    end
  elseif msgtype == "Ress" then
    libpredict:Ress(sender, target)
  elseif msgtype == "Hot" then
    libpredict:Hot(sender, target, heal, time)
  end
end

function libpredict:AddEvent(time, target)
  events[time] = events[time] or {}
  table.insert(events[time], target)
end

function libpredict:Heal(sender, target, amount, duration)
  if not sender or not target or not amount or not duration then
    return
  end

  local timeout = duration/1000 + GetTime()
  heals[target] = heals[target] or {}
  heals[target][sender] = { amount, timeout }
  libpredict:AddEvent(timeout, target)
end

function libpredict:Hot(sender, target, spell, duration)
  hots[target] = hots[target] or {}
  hots[target][spell] = hots[target][spell] or {}

  hots[target][spell].duration = duration
  hots[target][spell].start = GetTime()

  -- update aura events of relevant unitframes
  if pfUI and pfUI.uf and pfUI.uf.frames then
    for _, frame in pairs(pfUI.uf.frames) do
      if frame.namecache == target then
        frame.update_aura = true
      end
    end
  end
end

function libpredict:HealStop(sender)
  for ttarget, t in pairs(heals) do
    for tsender in pairs(heals[ttarget]) do
      if sender == tsender then
        heals[ttarget][tsender] = nil
      end
    end
  end
end

function libpredict:HealDelay(sender, delay)
  local delay = delay/1000
  for target, t in pairs(heals) do
    for tsender, amount in pairs(heals[target]) do
      if sender == tsender then
        amount[2] = amount[2] + delay
        libpredict:AddEvent(amount[2], target)
      end
    end
  end
end

function libpredict:Ress(sender, target)
  ress[target] = ress[target] or {}
  ress[target][sender] = true
end

function libpredict:RessStop(sender)
  for ttarget, t in pairs(ress) do
    for tsender in pairs(ress[ttarget]) do
      if sender == tsender then
        ress[ttarget][tsender] = nil
      end
    end
  end
end

function libpredict:UnitGetIncomingHeals(unit)
  if not unit or not UnitName(unit) then return 0 end
  if UnitIsDeadOrGhost(unit) then return 0 end
  local name = UnitName(unit)

  local sumheal = 0
  if not heals[name] then
    return sumheal
  else
    for sender, amount in pairs(heals[name]) do
      if amount[2] <= GetTime() then
        heals[name][sender] = nil
      else
        sumheal = sumheal + amount[1]
      end
    end
  end
  return sumheal
end

function libpredict:UnitHasIncomingResurrection(unit)
  if not unit or not UnitName(unit) then return nil end
  local name = UnitName(unit)

  if not ress[name] then
    return nil
  else
    for sender, val in pairs(ress[name]) do
      if val == true then
        return val
      end
    end
  end
  return nil
end

local spell_queue = { "DUMMY", "DUMMYRank 9", "TARGET" }
local realm = GetRealmName()
local player = UnitName("player")
local cache, gear_string = {}, ""
local resetcache = CreateFrame("Frame")
local rejuvDuration, renewDuration = 12, 15 --default durations
local hotsetbonus = libtipscan:GetScanner("hotsetbonus")
resetcache:RegisterEvent("PLAYER_ENTERING_WORLD")
resetcache:RegisterEvent("LEARNED_SPELL_IN_TAB")
resetcache:RegisterEvent("CHARACTER_POINTS_CHANGED")
resetcache:RegisterEvent("UNIT_INVENTORY_CHANGED")
resetcache:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" then
    -- load and initialize previous caches of spell amounts
    pfUI_cache["prediction"] = pfUI_cache["prediction"] or {}
    pfUI_cache["prediction"][realm] = pfUI_cache["prediction"][realm] or {}
    pfUI_cache["prediction"][realm][player] = pfUI_cache["prediction"][realm][player] or {}
    pfUI_cache["prediction"][realm][player]["heals"] = pfUI_cache["prediction"][realm][player]["heals"] or {}
    cache = pfUI_cache["prediction"][realm][player]["heals"]
  end

  if event == "UNIT_INVENTORY_CHANGED" or "PLAYER_ENTERING_WORLD" then
    -- skip non-player events
    if arg1 and arg1 ~= "player" then return end

    local gear = ""
    for id = 1, 18 do
      gear = gear .. (GetInventoryItemLink("player",id) or "")
    end

    -- abort when inventory didn't change
    if gear == gear_string then return end
    gear_string = gear

    local setBonusCounter
    setBonusCounter = 0
    for i=1,10 do --there is no need to check slots above 10
      hotsetbonus:SetInventoryItem("player", i)
      if hotsetbonus:Find(L["healduration"]["Rejuvenation"]) then setBonusCounter = setBonusCounter + 1 end
    end
    rejuvDuration = setBonusCounter == 8 and 15 or 12
    setBonusCounter = 0
    for i =1,10 do
      hotsetbonus:SetInventoryItem("player", i)
      if hotsetbonus:Find(L["healduration"]["Renew"]) then setBonusCounter = setBonusCounter + 1 end
    end
    renewDuration = setBonusCounter == 5 and 18 or 15
  end

  -- flag all cached heals for renewal
  for k in pairs(cache) do
    if type(cache[k]) == "number" or type(cache[k]) == "string" then
      -- migrate old data
      local oldval = cache[k]
      cache[k] = { [1] = oldval }
    end

    -- flag for reset
    cache[k][2] = true
  end
end)

local function UpdateCache(spell, heal, crit)
  local heal = heal and tonumber(heal)
  if not spell or not heal then return end

  if not cache[spell] or cache[spell][2] then
    -- skills or equipment changed, save whatever is detected
    cache[spell] = cache[spell] or {}
    cache[spell][1] = crit and heal*2/3 or heal
    cache[spell][2] = crit
  elseif not crit and cache[spell][1] < heal then
    -- safe the best heal we can get
    cache[spell][1] = heal
    cache[spell][2] = nil
  end
end

-- Gather Data by User Actions
hooksecurefunc("CastSpell", function(id, bookType)
  if not libpredict.sender.enabled then return end
  local effect, rank = libspell.GetSpellInfo(id, bookType)
  if not effect then return end
  spell_queue[1] = effect
  spell_queue[2] = effect.. ( rank or "" )
  spell_queue[3] = UnitName("target") and UnitCanAssist("player", "target") and UnitName("target") or UnitName("player")
end)

hooksecurefunc("CastSpellByName", function(effect, target)
  if not libpredict.sender.enabled then return end
  local effect, rank = libspell.GetSpellInfo(effect)
  if not effect then return end
  local mouseover = pfUI and pfUI.uf and pfUI.uf.mouseover and pfUI.uf.mouseover.unit
  mouseover = mouseover and UnitCanAssist("player", mouseover) and UnitName(mouseover)

  local default = UnitName("target") and UnitCanAssist("player", "target") and UnitName("target") or UnitName("player")

  target = target and type(target) == "string" and UnitName(target) or target
  target = target and target == true and UnitName("player") or target
  target = target and target == 1 and UnitName("player") or target

  spell_queue[1] = effect
  spell_queue[2] = effect.. ( rank or "" )
  spell_queue[3] = target or mouseover or default
end)

local scanner = libtipscan:GetScanner("prediction")
hooksecurefunc("UseAction", function(slot, target, selfcast)
  if not libpredict.sender.enabled then return end
  if GetActionText(slot) or not IsCurrentAction(slot) then return end
  scanner:SetAction(slot)
  local effect, rank = scanner:Line(1)
  if not effect then return end
  spell_queue[1] = effect
  spell_queue[2] = effect.. ( rank or "" )
  spell_queue[3] = selfcast and UnitName("player") or UnitName("target") and UnitCanAssist("player", "target") and UnitName("target") or UnitName("player")
end)

libpredict.sender = CreateFrame("Frame", "pfPredictionSender", UIParent)
libpredict.sender.enabled = true
libpredict.sender.SendHealCommMsg = function(self, msg)
  SendAddonMessage("HealComm", msg, "RAID")
  SendAddonMessage("HealComm", msg, "BATTLEGROUND")
end
libpredict.sender.SendResCommMsg = function(self, msg)
  SendAddonMessage("CTRA", msg, "RAID")
  SendAddonMessage("CTRA", msg, "BATTLEGROUND")
end

libpredict.sender:SetScript("OnUpdate", function()
  -- trigger delayed regrowth timers
  if this.regrowth_timer and GetTime() > this.regrowth_timer  then
    local target = this.regrowth_target or player
    local duration = 21

    libpredict:Hot(player, target, "Regr", duration)
    libpredict.sender:SendHealCommMsg("Regr/"..target.."/"..duration.."/")
    this.regrowth_target = this.regrowth_target_next
    this.regrowth_timer = nil
  end
end)

-- tbc
libpredict.sender:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
libpredict.sender:RegisterEvent("UNIT_SPELLCAST_START")
libpredict.sender:RegisterEvent("UNIT_SPELLCAST_STOP")
libpredict.sender:RegisterEvent("UNIT_SPELLCAST_FAILED")
libpredict.sender:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
libpredict.sender:RegisterEvent("UNIT_SPELLCAST_SENT")

-- vanilla
libpredict.sender:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
libpredict.sender:RegisterEvent("SPELLCAST_START")
libpredict.sender:RegisterEvent("SPELLCAST_STOP")
libpredict.sender:RegisterEvent("SPELLCAST_FAILED")
libpredict.sender:RegisterEvent("SPELLCAST_INTERRUPTED")
libpredict.sender:RegisterEvent("SPELLCAST_DELAYED")

-- force cache updates
libpredict.sender:RegisterEvent("UNIT_INVENTORY_CHANGED")
libpredict.sender:RegisterEvent("SKILL_LINES_CHANGED")

libpredict.sender:SetScript("OnEvent", function()
  if event == "CHAT_MSG_SPELL_SELF_BUFF" then -- vanilla
    -- octo (28 Oct 2026): the critical lines first ("Your X critically heals Y" also fits
    -- "Your %s heals %s", with "X critically" as the spell), and each line's own captures (the two
    -- critical ones read the target's name / nothing as the amount, so crits never counted).
    -- Every heal also teaches libpredict.Learn the typical size of that spell for you.
    local spell, _, heal = cmatch(arg1, HEALEDCRITSELFOTHER) -- "Your %s critically heals %s for %d."
    if spell and heal then
      if spell == spell_queue[1] then UpdateCache(spell_queue[2], heal, true) end
      if libpredict.Learn and not libpredict.clogLearns then libpredict.Learn(player, spell, nil, heal, true) end
      return
    end

    local spell, heal = cmatch(arg1, HEALEDCRITSELFSELF) -- "Your %s critically heals you for %d."
    if spell and heal then
      if spell == spell_queue[1] then UpdateCache(spell_queue[2], heal, true) end
      if libpredict.Learn and not libpredict.clogLearns then libpredict.Learn(player, spell, nil, heal, true) end
      return
    end

    local spell, _, heal = cmatch(arg1, HEALEDSELFOTHER) -- "Your %s heals %s for %d."
    if spell and heal then
      if spell == spell_queue[1] then UpdateCache(spell_queue[2], heal) end
      if libpredict.Learn and not libpredict.clogLearns then libpredict.Learn(player, spell, nil, heal) end
      return
    end

    local spell, heal = cmatch(arg1, HEALEDSELFSELF) -- "Your %s heals you for %d."
    if spell and heal then
      if spell == spell_queue[1] then UpdateCache(spell_queue[2], heal) end
      if libpredict.Learn and not libpredict.clogLearns then libpredict.Learn(player, spell, nil, heal) end
      return
    end
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" and arg2 == "SPELL_HEAL" and arg4 == player then -- tbc
    local spell, heal, crit = arg10, arg12, arg13
    if spell and heal and crit then
      if spell == spell_queue[1] then UpdateCache(spell_queue[2], heal, true) end
    elseif spell and heal then
      if spell == spell_queue[1] then UpdateCache(spell_queue[2], heal) end
    end
  elseif event == "UNIT_SPELLCAST_SENT" then
    if pfUI.client >= 20000 then
      if arg4 then senttarget = arg4 end -- fix tbc mouseover macros (arg4 = the target's name)
    elseif arg1 == "player" then
      -- octo (28 Oct 2026): ClassicAPI sends this on 1.12 as unit, target unit token, cast GUID, spell
      -- id. Its arg4 (a number) was taken as the target's name, so every own heal went to a "player"
      -- called 10917 and no frame showed it. Its arg2 names the unit the cast went at (none for self).
      senttarget = type(arg2) == "string" and arg2 ~= "" and UnitName(arg2) or nil
    end
  elseif strfind(event, "SPELLCAST_START", 1) then
    local spell, time = arg1, arg2

    if strfind(event, "UNIT_", 1) then -- tbc
      if arg1 ~= "player" then return end
      local spellname, _, _, _, starttime, endtime = UnitCastingInfo("player")
      -- ClassicAPI adds UNIT_SPELLCAST_START to vanilla: the plain SPELLCAST_START event already
      -- handles casts there, so skip this one (avoids nil times and double heal predictions)
      if pfUI.client < 20000 or not spellname or not starttime or not endtime then return end
      spell, time = spellname, endtime - starttime
    end

    -- (octo, 28 Oct 2026: the size your heals really have (running average), else the spell's text
    -- plus your healing power; pfUI's biggest-heal cache only for spells that guess cannot read)
    local known = libpredict:Guess(spell, spell_queue[2], nil, player, time)
      or (cache[spell_queue[2]] and cache[spell_queue[2]][1])
    if spell_queue[1] == spell and known then
      local sender = player
      local target = senttarget or spell_queue[3]
      local amount = known
      local casttime = time

      if spell == REGROWTH then
        if this.regrowth_timer then
          this.regrowth_target_next = spell_queue[3]
        else
          this.regrowth_target = spell_queue[3]
        end
      end

      if spell == PRAYER_OF_HEALING then
        target = sender

        for i=1,4 do
          if CheckInteractDistance("party"..i, 4) then
            libpredict:Heal(player, UnitName("party"..i), amount, casttime)
            if pfUI.client < 20000 then -- vanilla
              libpredict.sender:SendHealCommMsg("Heal/" .. UnitName("party"..i) .. "/" .. amount .. "/" .. casttime .. "/")
            else -- tbc
              libpredict.sender:SendHealCommMsg(string.format("002%05d%s", math.min(amount, 99999), UnitName("party"..i)))
            end
            libpredict.sender.healing = true
          end
        end
      end

      -- (octo: drawn here always - the original pfUI way, which worked; ClassicAPI / SuperWoW cast
      -- events (below) replace it with exact data when they come. HealStop first: one bar, never two)
      if spell ~= PRAYER_OF_HEALING then libpredict:HealStop(player) end
      libpredict:Heal(player, target, amount, casttime)
      if libpredict.Note then libpredict.Note("click", spell, target, amount, casttime) end
      if pfUI.client < 20000 then -- vanilla
        libpredict.sender:SendHealCommMsg("Heal/" .. target .. "/" .. amount .. "/" .. casttime .. "/")
      else -- tbc
        libpredict.sender:SendHealCommMsg(string.format("002%05d%s", math.min(amount, 99999), target))
      end
      libpredict.sender.healing = true

    elseif spell_queue[1] == spell and L["resurrections"][spell] then
      local target = senttarget or spell_queue[3]
      libpredict:Ress(player, target)
      libpredict.sender:SendHealCommMsg("Resurrection/" .. target .. "/start/")
      libpredict.sender:SendResCommMsg("RES " .. target)
      libpredict.sender.resurrecting = true
    end
  elseif strfind(event, "SPELLCAST_FAILED", 1) or strfind(event, "SPELLCAST_INTERRUPTED", 1) then
    if strfind(event, "UNIT_", 1) and arg1 ~= "player" then return end
    if libpredict.sender.healing then
      libpredict:HealStop(player)
      if pfUI.client < 20000 then -- vanilla
        libpredict.sender:SendHealCommMsg("HealStop")
      else -- tbc
        libpredict.sender:SendHealCommMsg("001F")
      end
      libpredict.sender.healing = nil
    elseif libpredict.sender.resurrecting then
      local target = senttarget or spell_queue[3]
      libpredict:RessStop(player)
      libpredict.sender:SendHealCommMsg("Resurrection/stop/")
      libpredict.sender:SendResCommMsg("RESNO " .. target)
      libpredict.sender.resurrecting = nil
    end
    if spell_queue[1] == REGROWTH then
      this.regrowth_timer = nil
    end
  elseif event == "SPELLCAST_DELAYED" then
    if libpredict.sender.healing then
      libpredict:HealDelay(player, arg1)
      libpredict.sender:SendHealCommMsg("Healdelay/" .. arg1 .. "/")
    end
  elseif strfind(event, "SPELLCAST_STOP", 1) then
    if strfind(event, "UNIT_", 1) and arg1 ~= "player" then return end
    libpredict:HealStop(player)
    if pfUI.client < 20000 then -- vanilla
      if spell_queue[1] == REJUVENATION then
        libpredict:Hot(player, spell_queue[3], "Reju", rejuvDuration)
        libpredict.sender:SendHealCommMsg("Reju/"..spell_queue[3].."/"..rejuvDuration.."/")
      elseif spell_queue[1] == RENEW then
        libpredict:Hot(player, spell_queue[3], "Renew", renewDuration)
        libpredict.sender:SendHealCommMsg("Renew/"..spell_queue[3].."/"..renewDuration.."/")
      elseif spell_queue[1] == REGROWTH then
        this.regrowth_timer = GetTime() + 0.1
      end
    else -- tbc
      --todo
    end
  end
end)

function libpredict:GetHotDuration(unit, spell)
  if unit == UNKNOWNOBJECT or unit == UNKOWNBEING then return end

  local start, duration, timeleft

  local unitdata = hots[UnitName(unit)]
  if unitdata and unitdata[spell] and (unitdata[spell].start + unitdata[spell].duration) > GetTime() - 1 then
    start = unitdata[spell].start
    duration = unitdata[spell].duration
    timeleft = (start + duration) - GetTime()
  end

  return start, duration, timeleft
end

-- ---------------------------------------------------------------- everyone's heals
-- pfUI Octo (28 Oct 2026; user: "HEAL PREDICTION IS HUGE ... MUST SHOW ALL HEALS IN ALL
-- FRAMES"). HealComm messages only come from healers who run a HealComm addon. With
-- ClassicAPI (UNIT_SPELLCAST_* for every unit, UnitSpellTargetName, its combat log) or
-- SuperWoW (UNIT_CASTEVENT: caster and target GUIDs) every heal cast in sight is seen,
-- from anyone. Its size: what that healer's spell (and rank) healed last time (combat
-- log, or the heal lines in chat), else the same spell from anyone, else the spell's own
-- "for X to Y" text. A HealComm message from the same healer simply replaces it (same
-- sender). ClassicAPI calls as in brues-code's pfUI fork (MIT, like pfUI).
do
  local HEALS = {
    ["Healing Wave"] = true, ["Lesser Healing Wave"] = true, ["Chain Heal"] = true,
    ["Flash Heal"] = true, ["Greater Heal"] = true, ["Heal"] = true, ["Lesser Heal"] = true,
    ["Holy Light"] = true, ["Flash of Light"] = true, ["Healing Touch"] = true,
  }
  HEALS[PRAYER_OF_HEALING] = true
  HEALS[REGROWTH] = true
  libpredict.HEALS = HEALS

  -- learned[caster][key] = amount; anyone[key] = amount (key = name or "name rank")
  local learned, anyone, guessed = {}, {}, {}
  -- (user, 28 Oct 2026: own heals must show "acuratly". A typical heal, not the biggest one:
  -- each normal heal moves the size a third of the way to itself; a critical one only counts
  -- (as 1/1.5 of itself) while nothing else is known)
  local function Blend(old, amount, crit)
    if crit then return old or math.floor(amount / 1.5) end
    if not old then return amount end
    return math.floor(old + (amount - old) / 3 + .5)
  end
  -- /pfheal: each of your predictions and what the heal really did, in chat (user, 28 Oct 2026:
  -- "STILL NOT WORKING" - one cast with this on shows where it goes wrong)
  local function Say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI heal|r " .. msg) end
  -- (and a moment later, what every pfUI frame of that player does with it)
  local frameCheck = CreateFrame("Frame")
  frameCheck:Hide()
  frameCheck:SetScript("OnUpdate", function()
    if GetTime() < (this.at or 0) then return end
    this:Hide()
    local name, found = this.name, 0
    for _, f in pairs(pfUI.uf and pfUI.uf.frames or {}) do
      local unit = f.label and (f.label .. (f.id or ""))
      if unit and unit ~= "" and UnitName(unit) == name and f:IsVisible() and not f.octoPreview then
        found = found + 1
        local inc = f.incHeal
        Say(string.format("  frame |cffffffff%s|r (%s): incoming %d, health %d / %d, green %s%s",
          tostring(f:GetName() or "?"), unit, libpredict:UnitGetIncomingHeals(unit), UnitHealth(unit) or 0, UnitHealthMax(unit) or 0,
          inc and inc:IsShown() and string.format("|cff55ff55shown|r %dx%d px", inc:GetWidth() or 0, inc:GetHeight() or 0) or "|cffff5555hidden|r",
          inc and inc.texture and string.format(" alpha %.2f", (inc.GetEffectiveAlpha and inc:GetEffectiveAlpha() or inc:GetAlpha() or 1)) or ""))
      end
    end
    if found == 0 then Say("  |cffff5555no pfUI frame shows " .. tostring(name) .. "|r") end
  end)
  function libpredict.Note(source, spell, target, amount, ms)
    if not libpredict.debug then return end
    frameCheck.name, frameCheck.at = target, GetTime() + .3
    frameCheck:Show()
    Say(string.format("%s on |cffffffff%s|r: |cff55ff55%d|r in %.1f s  |cff999999(from the %s%s, healing power %d)|r",
      tostring(spell), tostring(target), tonumber(amount) or 0, (tonumber(ms) or 0) / 1000,
      source == "cast" and "cast event" or "button click", source == "cast" and "" or "",
      libpredict.HealPower and libpredict.HealPower() or 0))
  end
  _G.SLASH_PFHEAL1 = "/pfheal"
  _G.SlashCmdList.PFHEAL = function()
    libpredict.debug = not libpredict.debug
    Say(libpredict.debug and "readout on: cast a heal - each prediction and what it landed for shows here. /pfheal again: off."
      or "readout off.")
    if libpredict.debug then
      Say(string.format("ClassicAPI cast events: %s   SuperWoW: %s   own heals from the cast: %s   sending HealComm: %s",
        (type(_G.UnitSpellTargetName) == "function" and C_Spell and C_Spell.UnitCastingInfo) and "yes" or "no",
        SUPERWOW_VERSION and "yes" or "no", libpredict.ownByCast and "yes" or "no",
        libpredict.sender and libpredict.sender.enabled and "yes" or "no (another HealComm addon does it)"))
    end
  end

  local function Learn(caster, name, rank, amount, crit)
    amount = tonumber(amount)
    if not caster or not name or not amount or amount <= 0 then return end
    if libpredict.debug and caster == player then
      Say(string.format("%s landed for |cffffd100%d|r%s", name, amount, crit and " (critical)" or ""))
    end
    learned[caster] = learned[caster] or {}
    local mine = learned[caster]
    mine[name] = Blend(mine[name], amount, crit)
    anyone[name] = Blend(anyone[name], amount, crit)
    if rank and rank ~= "" then
      mine[name .. rank] = Blend(mine[name .. rank], amount, crit)
      anyone[name .. rank] = Blend(anyone[name .. rank], amount, crit)
    end
  end
  libpredict.Learn = Learn

  -- a spell's own text: "Heals a friendly target for 307 to 353" -> 330
  local scan = CreateFrame("GameTooltip", "pfPredictScan", UIParent, "GameTooltipTemplate")
  local function FromText(text)
    if not text then return end
    local _, _, lo, hi = string.find(text, "(%d+) to (%d+)")
    if lo then return (tonumber(lo) + tonumber(hi)) / 2 end
  end
  local function FromBook(name, rank)
    local best
    -- (1 Nov 2026: a freeze casting Regrowth - the walk is bounded by the
    -- book's real size now; it used to wait for GetSpellName to give nil)
    local total = 0
    for t = 1, (GetNumSpellTabs and GetNumSpellTabs() or 0) do
      local _, _, _, num = GetSpellTabInfo(t)
      total = total + (tonumber(num) or 0)
    end
    for i = 1, math.min(total, 1024) do
      local n, r = GetSpellName(i, BOOKTYPE_SPELL or "spell")
      if not n then break end
      if n == name and (not rank or rank == "" or r == rank) then
        scan:SetOwner(UIParent, "ANCHOR_NONE")
        scan:ClearLines()
        scan:SetSpell(i, BOOKTYPE_SPELL)
        for l = 1, (scan:NumLines() or 0) do
          local fs = _G["pfPredictScanTextLeft" .. l]
          local v = fs and FromText(fs:GetText())
          if v then best = v end
        end
      end
    end
    return best
  end

  -- your +healing: ClassicAPI's GetSpellBonusHealing, else the "Increases healing done ... by up to X"
  -- lines of what you wear (read again when your gear changes)
  local gearScan = CreateFrame("GameTooltip", "pfPredictGear", UIParent, "GameTooltipTemplate")
  local bonus
  local function HealPower()
    if type(_G.GetSpellBonusHealing) == "function" then
      local ok, v = pcall(_G.GetSpellBonusHealing)
      if ok and tonumber(v) then return tonumber(v) end
    end
    if bonus then return bonus end
    bonus = 0
    for slot = 1, 19 do
      gearScan:SetOwner(UIParent, "ANCHOR_NONE")
      gearScan:ClearLines()
      if GetInventoryItemLink("player", slot) then
        gearScan:SetInventoryItem("player", slot)
        for l = 1, (gearScan:NumLines() or 0) do
          local fs = _G["pfPredictGearTextLeft" .. l]
          local t = fs and fs:GetText()
          if t and string.find(string.lower(t), "healing") then
            local _, _, n = string.find(t, "up to (%d+)")
            if not n then _, _, n = string.find(t, "%+(%d+) [Hh]ealing") end
            if n then bonus = bonus + tonumber(n) end
          end
        end
      end
    end
    return bonus
  end
  local gearWatch = CreateFrame("Frame")
  gearWatch:RegisterEvent("UNIT_INVENTORY_CHANGED")
  gearWatch:SetScript("OnEvent", function() if arg1 == "player" then bonus = nil end end)
  libpredict.HealPower = HealPower

  -- a heal's size before it lands; key = name .. rank as the own cast queue keeps it.
  -- Known sizes (running average of real heals) first. Else, as LibHealComm does it: the spell's
  -- own base heal plus, for your own, your +healing times its coefficient (cast time / 3.5 s)
  function libpredict:Guess(name, key, spellId, caster, ms)
    if not name or not HEALS[name] then return nil end
    key = key or name
    local c = caster and learned[caster]
    if c and (c[key] or c[name]) then return c[key] or c[name] end
    local base = libpredict:BaseHeal(name, key, spellId)
    if base and caster == player then
      local secs = math.min(3.5, math.max(1.5, (tonumber(ms) or 2500) / 1000))
      -- (Prayer of Healing / Chain Heal spread over several: a third of the usual share)
      if name == PRAYER_OF_HEALING or name == "Chain Heal" then secs = secs / 3 end
      return math.floor(base + HealPower() * secs / 3.5 + .5)
    end
    if anyone[key] or anyone[name] then return anyone[key] or anyone[name] end
    return base
  end
  -- the spell's own "heals for X to Y" average (no gear), remembered per spell and rank
  function libpredict:BaseHeal(name, key, spellId)
    key = key or name
    if guessed[key] == nil then
      local v
      if spellId and C_Spell and C_Spell.GetSpellDescription then
        local ok, d = pcall(C_Spell.GetSpellDescription, spellId)
        if ok then v = FromText(d) end
      end
      if not v then v = FromBook(name, string.sub(key, string.len(name) + 1)) end
      guessed[key] = v or false
    end
    return guessed[key] or nil
  end

  -- Prayer of Healing: everyone in the caster's group (party, or the raid subgroup)
  local function GroupOf(caster)
    local out = {}
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
      local group
      for i = 1, GetNumRaidMembers() do
        local n, _, sub = GetRaidRosterInfo(i)
        if n == caster then group = sub end
      end
      for i = 1, GetNumRaidMembers() do
        local n, _, sub = GetRaidRosterInfo(i)
        if group and sub == group then table.insert(out, n) end
      end
    else
      table.insert(out, caster)
      if UnitName("player") ~= caster then table.insert(out, UnitName("player")) end
      for i = 1, 4 do
        local n = UnitName("party" .. i)
        if n and n ~= caster then table.insert(out, n) end
      end
    end
    return out
  end

  -- a heal being cast by someone else: on its target(s) until it lands or stops
  local casting = {}   -- key (cast GUID / caster GUID) -> { caster, targets, amount }
  -- (your own heals go this way too when ClassicAPI or SuperWoW tells the cast: libpredict.ownByCast)
  local function Start(key, caster, target, name, rank, spellId, ms)
    if not caster or (caster == player and not libpredict.ownByCast) or not HEALS[name] or not ms or ms <= 0 then return end
    local amount = libpredict:Guess(name, name .. (rank or ""), spellId, caster, ms)
    if not amount then return end
    local targets = (name == PRAYER_OF_HEALING) and GroupOf(caster) or { target or caster }
    -- (yours: this replaces what the button-click way drew, so there is one bar)
    if caster == player then
      libpredict:HealStop(player)
      if libpredict.Note then libpredict.Note("cast", name .. (rank and rank ~= "" and (" (" .. rank .. ")") or ""), targets[1], amount, ms) end
    end
    for _, t in ipairs(targets) do libpredict:Heal(caster, t, amount, ms) end
    casting[key] = { caster = caster, targets = targets }
  end
  local function Stop(key)
    local c = key and casting[key]
    if not c then return end
    casting[key] = nil
    libpredict:HealStop(c.caster)
  end
  local function Delay(key, endsAt)
    local c = key and casting[key]
    if not c or not endsAt then return end
    for _, t in ipairs(c.targets) do
      local h = heals[t] and heals[t][c.caster]
      if h then h[2] = endsAt libpredict:AddEvent(endsAt, t) end
    end
  end
  libpredict.OtherStart, libpredict.OtherStop = Start, Stop

  -- (user, 28 Oct 2026: party members ressing someone must show, so nobody casts a second res)
  -- a res being cast by someone else: the res icon on the dead target until it lands or stops.
  -- Yours already go out through the cast queue and HealComm.
  local ressing = {}   -- key -> caster
  local function RessStart(key, caster, target, name)
    if not caster or caster == player or not target or not name or not L["resurrections"][name] then return end
    libpredict:Ress(caster, target)
    ressing[key] = caster
    return true
  end
  local function RessEnd(key)
    local caster = key and ressing[key]
    if not caster then return end
    ressing[key] = nil
    libpredict:RessStop(caster)
  end
  libpredict.OtherRess, libpredict.OtherRessEnd = RessStart, RessEnd

  local capi = pfUI.client < 20000 and type(_G.UnitSpellTargetName) == "function"
    and C_Spell and C_Spell.GetSpellName and C_Spell.UnitCastingInfo
  local others = CreateFrame("Frame", "pfPredictionOthers", UIParent)
  libpredict.others = others
  -- your own heals from the cast itself (exact spell, rank, target and time) instead of
  -- guessing them from the button clicked
  libpredict.ownByCast = (capi or (pfUI.client < 20000 and SUPERWOW_VERSION ~= nil)) and true or nil
  -- (with the combat log your heals are learnt there: the chat lines would count each twice)
  libpredict.clogLearns = capi and type(_G.CombatLogGetCurrentEventInfo) == "function" or nil
  -- an own cast with no target named: the unit it was sent at (UNIT_SPELLCAST_SENT), else yourself
  local function OwnTarget(unit)
    local ok, t = pcall(_G.UnitSpellTargetName, unit)
    if ok and t and t ~= "" then return t end
    return senttarget or player
  end
  if capi then
    for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
                         "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED", "COMBAT_LOG_EVENT_UNFILTERED" }) do
      others:RegisterEvent(e)
    end
  elseif pfUI.client < 20000 then
    -- SuperWoW without ClassicAPI; plain 1.12: only HealComm and the chat lines
    others:RegisterEvent("UNIT_CASTEVENT")
  end
  -- other players' heals in chat teach the sizes when the combat log is not there
  for _, e in ipairs({ "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF", "CHAT_MSG_SPELL_PARTY_BUFF", "CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF" }) do
    others:RegisterEvent(e)
  end
  local cmatch = pfUI.api.cmatch
  others:SetScript("OnEvent", function()
    if event == "UNIT_SPELLCAST_START" then
      -- (every unit token a caster has fires its own copy: the cast GUID says it is one cast)
      local unit, guid, id = arg1, arg2, arg3
      if not unit or not guid or casting[guid] then return end
      -- (yours come as "player"; your other tokens - target of target... - are copies)
      local mine = UnitIsUnit(unit, "player")
      if mine and unit ~= "player" then return end
      local name = C_Spell.GetSpellName(id)
      if not name then return end
      local target
      if mine then target = OwnTarget(unit) else
        local ok, t = pcall(_G.UnitSpellTargetName, unit)
        target = ok and t or nil
      end
      if RessStart(guid, UnitName(unit), target, name) or not HEALS[name] then return end
      local _, _, _, s, e = C_Spell.UnitCastingInfo(unit)
      local rank = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id) or ""
      Start(guid, UnitName(unit), target, name, rank, id, (s and e) and (e - s) or nil)
    elseif event == "UNIT_SPELLCAST_DELAYED" then
      local _, _, _, _, e = C_Spell.UnitCastingInfo(arg1)
      if e then Delay(arg2, e / 1000) end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_SUCCEEDED" then
      Stop(arg2)
      RessEnd(arg2)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
      local info = _G.CombatLogGetCurrentEventInfo
      if type(info) ~= "function" then return end
      local _, sub, _, _, src, _, _, _, _, _, _, id, name, _, amount, _, _, crit = info()
      -- (your own too: the sizes your gear really gives)
      if sub == "SPELL_HEAL" and src then
        local rank = id and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id) or ""
        Learn(src, name, rank, amount, crit)
      end
    elseif event == "UNIT_CASTEVENT" then
      -- SuperWoW: arg1 caster GUID, arg2 target GUID, arg3 START / CAST / FAIL..., arg4 spell id, arg5 ms
      if arg3 == "START" then
        -- (not "SpellInfo and SpellInfo(x)": an "and" keeps only the first of its returns - the rank was lost)
        local name, rank
        if SpellInfo then name, rank = SpellInfo(arg4) end
        if not name then return end
        local caster = UnitName(arg1)
        local target = arg2 and arg2 ~= "" and arg2 ~= "0x0000000000000000" and UnitName(arg2) or nil
        if RessStart(arg1, caster, target, name) or not HEALS[name] then return end
        if caster == player and not target then target = senttarget or player end
        Start(arg1, caster, target, name, rank, arg4, arg5)
      elseif arg3 == "CAST" or arg3 == "FAIL" then
        Stop(arg1)
        RessEnd(arg1)
      end
    elseif cmatch and arg1 then
      -- the critical lines first: "X's Y critically heals Z" also fits "X's Y heals Z"
      -- (with "Y critically" as the spell)
      local LINES = { { HEALEDCRITOTHEROTHER, true, true }, { HEALEDCRITOTHERSELF, true }, { HEALEDOTHEROTHER, false, true }, { HEALEDOTHERSELF, false } }
      for _, l in ipairs(LINES) do
        if l[1] then
          local who, spell, a3, a4 = cmatch(arg1, l[1])
          local amt = l[3] and a4 or a3
          if who and amt then Learn(who, spell, nil, amt, l[2]) return end
        end
      end
    end
  end)
end

pfUI.api.libpredict = libpredict
