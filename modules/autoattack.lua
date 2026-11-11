pfUI:RegisterModule("autoattack", "vanilla", function ()
  -- pfUI Octo :: auto attack (11 Nov 2026; user, after Origummy on Discord asked for it: "an auto attack
  -- feature that is able to be toggled on and off - when in range you start auto attack on the mob you
  -- choose"). While it is on, a target you may attack that comes into melee reach gets your auto attack.
  -- It never:
  --   - starts again on a target you stopped attacking yourself (until you pick another target)
  --   - breaks your stealth, or a crowd control on the target (sheep, sap, gouge, blind, sleep, traps...)
  --   - attacks friends, the dead, or (unless allowed) other players and neutral (yellow) mobs
  -- Reach: ClassicAPI's swing range check, else UnitXP SP3's melee distance, else the centre-to-centre
  -- distance, else the game's 10 yd interact check (the user's standing rule: ClassicAPI / SuperWoW /
  -- UnitXP first, always with a plain fallback).
  -- AttackTarget() turns auto attack on AND off, so it is only called while auto attack is off
  -- (PLAYER_ENTER_COMBAT / PLAYER_LEAVE_COMBAT are the game's auto attack on / off).
  -- Settings C.autoattack (Quality of Life page), /autoattack, key binding PFAUTOATTACK.
  local AA = { attacking = false }
  pfUI.autoattack = AA
  local lc = pfUI.api and pfUI.api.libclient
  local function G() return C.autoattack end
  local function Say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI|r auto attack: " .. msg) end

  -- crowd control a swing would break (debuff pictures, 1.12 names)
  AA.CC = {
    "Spell_Nature_Polymorph", "Ability_Sap", "Ability_Gouge", "Spell_Shadow_MindSteal", "Spell_Nature_Sleep",
    "Spell_Frost_ChainsOfIce", "Spell_Nature_Slow", "INV_Spear_02", "Ability_Rogue_Disguise",
    "Spell_Holy_PrayerOfHealing", "Spell_Magic_PolymorphChicken", "Spell_Magic_PolymorphPig",
    "Ability_Hunter_Pet_Turtle",
  }
  function AA.Controlled()
    for i = 1, 16 do
      local tex = UnitDebuff("target", i)
      if not tex then return false end
      local t = string.lower(tex)
      for _, cc in ipairs(AA.CC) do
        if string.find(t, string.lower(cc), 1, true) then return true end
      end
    end
    return false
  end

  function AA.Stealthed()
    if lc and lc.Stealthed then
      local ok, s = pcall(lc.Stealthed)
      if ok and s ~= nil then return s and true or false end
    end
    if _G.IsStealthed then
      local ok, s = pcall(_G.IsStealthed)
      if ok then return s and true or false end
    end
    return false
  end

  -- true / false = in melee reach or not; nil = cannot tell
  function AA.InReach()
    -- ClassicAPI: the game's own swing range check
    if _G.C_SwingTimer and _G.C_SwingTimer.IsTargetWithinSwingRange then
      pcall(_G.C_SwingTimer.EnableRangeCheck, 0, true)
      local ok, inr = pcall(_G.C_SwingTimer.IsTargetWithinSwingRange, 0)
      if ok and inr ~= nil then return inr and true or false end
    end
    local reach = tonumber(G().reach) or 5
    -- UnitXP SP3: melee distance as the game measures it (bodies' size taken off)
    if _G.UnitXP then
      local ok, d = pcall(_G.UnitXP, "distanceBetween", "player", "target", "meleeAutoAttack")
      if ok and type(d) == "number" and d >= 0 then return d <= reach end
    end
    -- centre to centre (ClassicAPI / SuperWoW): allow for the bodies
    local d = lc and lc.Distance and lc.Distance("target")
    if d then return d <= reach + 3 end
    if CheckInteractDistance then return CheckInteractDistance("target", 3) and true or false end
  end

  -- may this target be attacked by us now? (nil, reason) when not
  function AA.Allowed()
    if not UnitExists("target") then return nil, "no target" end
    if UnitIsDead("target") or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("target")) then return nil, "dead" end
    if not UnitCanAttack("player", "target") then return nil, "friendly" end
    if UnitIsPlayer("target") and G().players ~= "1" then return nil, "a player" end
    if G().neutral ~= "1" and not UnitIsPlayer("target") then
      local r = UnitReaction and UnitReaction("target", "player")
      if r and r >= 4 then return nil, "neutral" end
    end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return nil, "you are dead" end
    if G().combatonly == "1" and not UnitAffectingCombat("player") then return nil, "not in combat" end
    if AA.Stealthed() then return nil, "stealthed" end
    if G().skipcc ~= "0" and AA.Controlled() then return nil, "crowd controlled" end
    return true
  end

  -- the target's identity, to remember "you stopped attacking this one"
  function AA.Key()
    local g = lc and lc.GUID and lc.GUID("target")
    return g or ((UnitName("target") or "?") .. ":" .. (UnitLevel("target") or 0))
  end

  function AA.Check()
    if G().enable ~= "1" or AA.attacking then return end
    if AA.stopped and AA.stopped == AA.Key() then return end
    if not AA.Allowed() then return end
    if AA.InReach() == false then return end
    -- (nil = reach unknown: the game holds the swing until you are close)
    AA.calling = GetTime()
    AttackTarget()
  end

  local f = CreateFrame("Frame")
  AA.frame = f
  f:RegisterEvent("PLAYER_ENTER_COMBAT")
  f:RegisterEvent("PLAYER_LEAVE_COMBAT")
  f:RegisterEvent("PLAYER_TARGET_CHANGED")
  f:SetScript("OnEvent", function()
    if event == "PLAYER_ENTER_COMBAT" then
      AA.attacking = true
      AA.stopped = nil
    elseif event == "PLAYER_LEAVE_COMBAT" then
      AA.attacking = false
      -- you stopped it yourself (the target is still there and fair game): leave this one alone
      if UnitExists("target") and not UnitIsDead("target") and UnitCanAttack("player", "target") then
        AA.stopped = AA.Key()
      end
    elseif event == "PLAYER_TARGET_CHANGED" then
      AA.stopped = nil
      AA.Check()
    end
  end)
  f:SetScript("OnUpdate", function()
    if (this.t or 0) > GetTime() then return end
    this.t = GetTime() + .1
    AA.Check()
  end)

  function AA.Toggle(on)
    if on == nil then on = G().enable ~= "1" end
    G().enable = on and "1" or "0"
    AA.stopped = nil
    Say(on and "|cff55ff55on|r" or "|cffff5555off|r")
    if pfUI.gui and pfUI.gui.RefreshPage then pcall(pfUI.gui.RefreshPage, "qolgeneral") end
  end

  _G.BINDING_HEADER_PFAUTOATTACK = "pfUI Octo: auto attack"
  _G.BINDING_NAME_PFAUTOATTACK = "Auto attack on / off"
  _G.SLASH_PFAUTOATTACK1 = "/autoattack"
  _G.SLASH_PFAUTOATTACK2 = "/pfaa"
  _G.SlashCmdList.PFAUTOATTACK = function(msg)
    msg = string.lower(msg or "")
    if msg == "on" then AA.Toggle(true) elseif msg == "off" then AA.Toggle(false)
    elseif msg == "why" then
      local ok, why = AA.Allowed()
      local reach = AA.InReach()
      Say((G().enable == "1" and "on" or "off") .. "; target: " .. (ok and "fair game" or tostring(why))
        .. "; reach: " .. (reach == nil and "unknown" or (reach and "in reach" or "too far"))
        .. (AA.attacking and "; attacking" or "") .. (AA.stopped and "; you stopped it on this target" or ""))
    else AA.Toggle() end
  end
end)
