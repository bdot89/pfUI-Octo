pfUI:RegisterModule("octoshare-feeds", "vanilla:tbc", function ()
  -- pfUI Octo :: OctoShare feeds (27 Nov 2026, phase 2). The NEW crowd data that nothing shared before, each one a tiny
  -- record through OctoShare.Emit (prefix pfOS) - so it rides the same throttle-safe governor (paced, silent in combat)
  -- and the same realm channel, and is collected by the master the same way. Off unless C.octoshare.enable = "1".
  --   bgq  a battleground queue popped: how long you waited  ->  "bgq^<map>^<faction>^<seconds>"
  --   bgr  a battleground ended: did your side win            ->  "bgr^<map>^<faction>^<1|0>"
  --   pop  where you are, now and then: an activity heatmap   ->  "pop^<zone>^<faction>"
  --   death  you died: where, your level, what hit you last   ->  "death^<zone>^<level>^<killer>"   (28 Nov 2026)
  --   crit   you beat your own biggest crit / crit heal       ->  "crit^<amount>^<spell>^<dmg|heal>"
  -- The master turns these into "queues are fast now", realm PvP win rates and a where-is-everyone heatmap.
  local OS = pfUI.octoshare
  if not OS or not OS.Emit then return end

  local function Faction() return (UnitFactionGroup and UnitFactionGroup("player")) or "?" end
  local function Clean(s) return (string.gsub(s or "", "[%^|,`]", " ")) end   -- keep our separators out of a value

  -- ---------------------------------------------------------------- battlegrounds
  local F = { status = {}, reported = nil }
  OS.feeds = F

  -- queue pop: the moment a queue turns to "confirm", read how long it waited
  function F.CheckQueues()
    for i = 1, 3 do
      local ok, status, map = pcall(GetBattlefieldStatus, i)
      if not ok then status = nil end
      local was = F.status[i]
      if status == "confirm" and was ~= "confirm" then
        local secs = 0
        local ok2, ms = pcall(GetBattlefieldTimeWaited, i)
        if ok2 and ms and ms > 0 then secs = math.floor(ms / 1000) end
        if map and secs > 0 and secs < 36000 then
          OS.Emit("bgq", Clean(map) .. "^" .. Faction() .. "^" .. secs)
        end
      end
      F.status[i] = status
    end
  end

  -- result: when a battleground has a winner, report win / loss once for this match
  function F.CheckResult()
    local ok, winner = pcall(GetBattlefieldWinner)
    if not ok or winner == nil then F.reported = nil return end
    if F.reported then return end
    F.reported = true
    local map = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "?"
    -- winner: 0 = Horde, 1 = Alliance (vanilla). Our side won when it matches our faction.
    local mine = Faction() == "Alliance" and 1 or 0
    OS.Emit("bgr", Clean(map) .. "^" .. Faction() .. "^" .. (winner == mine and 1 or 0))
  end

  -- ---------------------------------------------------------------- population heatmap
  -- one small ping of your zone now and then (default every 6 min). The governor holds it in combat, so it only ever
  -- goes out while you are idle - never in a fight. The master counts pings per zone per hour.
  F.POP_EVERY = 360
  function F.Ping()
    local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText())
    if not zone or zone == "" then return end
    OS.Emit("pop", Clean(zone) .. "^" .. Faction())
  end

  -- ---------------------------------------------------------------- deaths
  -- the last thing that hurt you (combat log, 1.12 English lines), kept 15 s; PLAYER_DEAD reports it. Sent through the
  -- governor, so it waits until you are out of combat like everything else.
  F.lastHit, F.lastHitAt = nil, 0
  function F.Hurt(msg)
    if type(msg) ~= "string" then return end
    local _, _, who = string.find(msg, "^(.+)'s .+ hits you for")
    if not who then _, _, who = string.find(msg, "^(.+)'s .+ crits you for") end
    if not who then _, _, who = string.find(msg, "^(.+) hits you for") end
    if not who then _, _, who = string.find(msg, "^(.+) crits you for") end
    if not who then _, _, who = string.find(msg, "^You suffer %d+ .- damage from (.+)'s ") end
    if who and string.len(who) < 60 then
      F.lastHit, F.lastHitAt = who, (GetTime and GetTime() or 0)
    end
  end
  function F.Died()
    local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "?"
    local killer = ""
    if F.lastHit and (GetTime and GetTime() or 0) - F.lastHitAt < 15 then killer = F.lastHit end
    OS.Emit("death", Clean(zone) .. "^" .. (UnitLevel and UnitLevel("player") or 0) .. "^" .. Clean(killer))
    F.lastHit = nil
  end

  -- ---------------------------------------------------------------- personal crit records
  -- only a NEW best is sent (kept in pfUI_cache.octoshare.rec), so this is rare: a handful of lines a week
  function F.Records()
    -- (never assign the saved variable itself here: modules run in pfUI's environment, so it would shadow the real one)
    if type(pfUI_cache) ~= "table" then F.recTmp = F.recTmp or {} return F.recTmp end
    if type(pfUI_cache.octoshare) ~= "table" then pfUI_cache.octoshare = {} end
    local d = pfUI_cache.octoshare
    d.rec = type(d.rec) == "table" and d.rec or {}
    return d.rec
  end
  function F.Crit(msg, heal)
    if type(msg) ~= "string" then return end
    local _, spell, amount
    if heal then
      _, _, spell, amount = string.find(msg, "^Your (.+) critically heals .- for (%d+)")
    else
      _, _, spell, amount = string.find(msg, "^Your (.+) crits .- for (%d+)")
      if not spell then
        _, _, amount = string.find(msg, "^You crit .- for (%d+)")
        if amount then spell = "Melee" end
      end
    end
    amount = tonumber(amount)
    if not spell or not amount or amount <= 0 or amount > 100000 then return end
    local kind = heal and "heal" or "dmg"
    local rec = F.Records()
    if amount <= (tonumber(rec[kind]) or 0) then return end
    rec[kind] = amount
    OS.Emit("crit", amount .. "^" .. Clean(spell) .. "^" .. kind)
  end

  -- ---------------------------------------------------------------- events + tick
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
  ev:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
  ev:RegisterEvent("PLAYER_DEAD")
  ev:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS")
  ev:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE")
  ev:RegisterEvent("CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS")
  ev:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE")
  ev:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")
  ev:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
  ev:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
  ev:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
  ev:SetScript("OnEvent", function()
    if not OS.Enabled() then return end
    if event == "UPDATE_BATTLEFIELD_STATUS" then F.CheckQueues()
    elseif event == "UPDATE_BATTLEFIELD_SCORE" then F.CheckResult()
    elseif event == "PLAYER_DEAD" then F.Died()
    elseif event == "CHAT_MSG_COMBAT_SELF_HITS" or event == "CHAT_MSG_SPELL_SELF_DAMAGE" then F.Crit(arg1, false)
    elseif event == "CHAT_MSG_SPELL_SELF_BUFF" then F.Crit(arg1, true)
    else F.Hurt(arg1) end
  end)
  ev:SetScript("OnUpdate", function()
    if not OS.Enabled() then return end
    local now = GetTime and GetTime() or 0
    if (this.popAt or 0) > now then return end
    this.popAt = now + F.POP_EVERY + math.random() * 60   -- jitter so a whole guild logging in together does not ping at once
    F.Ping()
  end)
end)
