pfUI:RegisterModule("octorank", "vanilla:tbc", function ()
  -- pfUI Octo :: OctoRanks (24 Nov 2026). User: OctoRank (made from WhoDidIt) "merge this into our pfUI making it very
  -- light ... seamlessly work with WDI times are shared between both versions on the same chat channel so nothing is
  -- ever lost ... it will NEVER clash with WDI. EVER if both are installed they work as 1 ... make sure people know
  -- about the ranking that it is done automatically when you run dungeons".
  --
  -- The engine is OctoRank itself in pfUI\octorank (tools\Sync-OctoRank.ps1), under OctoRank's own names, so:
  --   WhoDidIt loaded         -> WhoDidIt runs everything; our copy and the add-on stand aside. This file merges the
  --                              5-man runs both ways between WhoDidItDB and OctoRankDB, so turning either off loses nothing.
  --   OctoRank add-on loaded  -> it runs (it is the same code and the same saved table, OctoRankDB); we offer once to
  --                              switch it off, since pfUI has it now.
  --   neither                 -> pfUI's copy runs: the WDIBoard channel, 5-man timing and sharing, raid rankings, logger.
  -- All three are one network: the same hidden channel and messages.
  local OR = {}
  pfUI.octorank = OR

  -- which engine runs: "wdi" | "addon" | "pfui" | nil (switched off), and its table
  function OR.Engine()
    if IsAddOnLoaded("WhoDidIt") and type(WhoDidIt) == "table" then return "wdi", WhoDidIt end
    if IsAddOnLoaded("OctoRank") and type(OctoRank) == "table" then return "addon", OctoRank end
    if ORANK_PFUI and type(OctoRank) == "table" and not OctoRank.off then return "pfui", OctoRank end
    return nil
  end
  -- the saved table of the engine that runs (WhoDidIt's or OctoRank's - the same keys)
  function OR.DB()
    local kind = OR.Engine()
    if kind == "wdi" then return type(WhoDidItDB) == "table" and WhoDidItDB or nil end
    if kind then return type(OctoRankDB) == "table" and OctoRankDB or nil end
  end
  function OR.Opts()
    local db = OR.DB()
    if db then
      db.opts = db.opts or {}
      return db.opts
    end
  end
  function OR.Name(kind)
    kind = kind or OR.Engine()
    if kind == "wdi" then return "WhoDidIt" end
    if kind == "addon" then return "the OctoRank add-on" end
    if kind == "pfui" then return "pfUI Octo" end
    return "nobody (switched off)"
  end

  -- ---------------------------------------------------------------- merging the saves
  -- The 5-man runs of one save into the other: a group's best per dungeon (the faster time wins), withdrawn runs (never
  -- come back), group names (the newest), your own run history (every run once). into = a table like WhoDidItDB.
  local function copy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = v end
    return o
  end
  local function outId(key, gk, secs) return key .. "~" .. gk .. "~" .. tostring(secs) end

  function OR.MergeInto(into, from, engine)
    if type(into) ~= "table" or type(from) ~= "table" then return 0 end
    local n = 0
    -- withdrawals first, so a run withdrawn on either side stays out
    if type(from.runsWithdrawn) == "table" then
      if type(into.runsWithdrawn) ~= "table" then into.runsWithdrawn = {} end
      for rlm, list in pairs(from.runsWithdrawn) do
        if type(list) == "table" then
          into.runsWithdrawn[rlm] = into.runsWithdrawn[rlm] or {}
          local to = into.runsWithdrawn[rlm]
          for id, e in pairs(list) do
            if to[id] == nil and type(e) == "table" then to[id] = copy(e) n = n + 1 end
          end
        end
      end
    end
    if type(from.dungeons) == "table" then
      if type(into.dungeons) ~= "table" then into.dungeons = {} end
      for rlm, keys in pairs(from.dungeons) do
        if type(keys) == "table" then
          for key, groups in pairs(keys) do
            if type(groups) == "table" then
              for gk, rec in pairs(groups) do
                if type(rec) == "table" and tonumber(rec.t) then
                  local mine = into.dungeons[rlm] and into.dungeons[rlm][key] and into.dungeons[rlm][key][gk]
                  if not mine or rec.t < mine.t then
                    local R = engine and engine.Runs
                    if R and R.Merge then
                      -- the engine's own rules (withdrawals, the 60 fastest kept)
                      local ok, changed = pcall(R.Merge, R, rlm, key, gk, copy(rec))
                      if ok and changed then n = n + 1 end
                    else
                      local out = into.runsWithdrawn and into.runsWithdrawn[rlm] and into.runsWithdrawn[rlm][outId(key, gk, rec.t)]
                      if not out then
                        into.dungeons[rlm] = into.dungeons[rlm] or {}
                        into.dungeons[rlm][key] = into.dungeons[rlm][key] or {}
                        into.dungeons[rlm][key][gk] = copy(rec)
                        n = n + 1
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
    if type(from.groupNames) == "table" then
      if type(into.groupNames) ~= "table" then into.groupNames = {} end
      for gk, g in pairs(from.groupNames) do
        local have = into.groupNames[gk]
        if type(g) == "table" and (not have or (g.at or 0) > (have.at or 0)) then into.groupNames[gk] = copy(g) end
      end
    end
    if type(from.myRuns) == "table" then
      if type(into.myRuns) ~= "table" then into.myRuns = {} end
      local seen = {}
      local function id(e) return tostring(e.k) .. "~" .. tostring(e.gk) .. "~" .. tostring(e.t) .. "~" .. tostring(e.d) end
      for _, e in ipairs(into.myRuns) do seen[id(e)] = e end
      local added
      for _, e in ipairs(from.myRuns) do
        if type(e) == "table" then
          local have = seen[id(e)]
          if not have then
            local c = copy(e)
            table.insert(into.myRuns, c)
            seen[id(e)] = c
            added = true
            n = n + 1
          elseif e.wd and not have.wd then
            have.wd = true
          end
        end
      end
      -- newest first, as the engines keep it
      if added then table.sort(into.myRuns, function(a, b) return (a.d or 0) > (b.d or 0) end) end
    end
    return n
  end

  -- WhoDidIt on: both saves get each other's runs (at login, and WhoDidIt's into ours at logout so pfUI's file has the newest)
  function OR.Sync(both)
    local kind, eng = OR.Engine()
    if kind ~= "wdi" or type(WhoDidItDB) ~= "table" then return 0 end
    if type(_G.OctoRankDB) ~= "table" then _G.OctoRankDB = {} end
    local n = 0
    if both then n = n + OR.MergeInto(WhoDidItDB, OctoRankDB, eng) end
    n = n + OR.MergeInto(OctoRankDB, WhoDidItDB)
    OR.synced = n
    return n
  end

  -- ---------------------------------------------------------------- opening it
  local function UIof()
    local _, eng = OR.Engine()
    return eng and eng.UI
  end
  -- what: "five" (5-man boards) | "raids" | "logs" | nil (the window as it was)
  function OR.Open(what)
    local UI = UIof()
    if not UI then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffOcto|cffffd100Ranks|r: switched off - turn it on in pfUI's options (OctoRanks), then reload.")
      return
    end
    if pfUI.gui and pfUI.gui.IsShown and pfUI.gui:IsShown() then pfUI.gui:Hide() end
    local ok = pcall(function()
      if what == "five" then
        UI.rk.five = true
        UI:SetMode("rankings")
      elseif what == "raids" then
        UI.rk.five = nil
        UI:SetMode("rankings")
      elseif what == "logs" then
        UI:SetMode("logs")
      elseif UI.Toggle then
        UI:Toggle()
      end
      if UI.Open and what then UI:Open() end
    end)
    if not ok and UI.Toggle then pcall(UI.Toggle, UI) end
  end

  -- /orank and /octorank when only WhoDidIt is there (the engine's own command otherwise); /ranks always
  if not SlashCmdList["OCTORANK"] then
    _G.SLASH_OCTORANK1 = "/orank"
    _G.SLASH_OCTORANK2 = "/octorank"
    SlashCmdList["OCTORANK"] = function() OR.Open("five") end
  end
  _G.SLASH_PFOCTORANKS1 = "/ranks"
  _G.SLASH_PFOCTORANKS2 = "/octoranks"
  SlashCmdList["PFOCTORANKS"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "raids" or msg == "logs" then OR.Open(msg) elseif msg == "options" then
      if pfUI.octoui and pfUI.octoui.Options then pfUI.octoui.Options:Open("orank") end
    else OR.Open("five") end
  end

  -- ---------------------------------------------------------------- telling people
  StaticPopupDialogs["PFUI_OCTORANK_ADDON"] = {
    text = "OctoRank is built into pfUI Octo now (options > OctoRanks).\n\nYour times stay: it is the same save. "
      .. "Switch the separate OctoRank add-on off? (takes a reload)",
    button1 = "Off and reload", button2 = "Keep it",
    OnAccept = function()
      DisableAddOn("OctoRank")
      ReloadUI()
    end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
  }

  function OR.Hello()
    local kind = OR.Engine()
    if not kind then return end
    if not pfUI_cache.octorankHello then
      pfUI_cache.octorankHello = 1
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffOcto|cffffd100Ranks|r: every level-60 dungeon run is timed and ranked for you "
        .. "- from the first pull after zoning in to the last boss - and shared with everyone on the realm. Nothing to switch on. "
        .. "|cffffd100/ranks|r or pfUI options > OctoRanks.")
    end
    if kind == "addon" and not pfUI_cache.octorankAsked then
      pfUI_cache.octorankAsked = 1
      StaticPopup_Show("PFUI_OCTORANK_ADDON")
    end
  end

  -- the first time in each timed dungeon: say once that this run is ranked
  -- (the engine times any 5-man instance and knows which dungeon it was when its last boss dies)
  function OR.ZoneNote()
    if not OR.Engine() or not IsInInstance then return end
    local inside, kind = IsInInstance()
    if not inside or kind ~= "party" or (UnitLevel("player") or 0) < 60 then return end
    local zone = GetRealZoneText and GetRealZoneText() or ""
    if zone == "" then return end
    pfUI_cache.octorankZones = pfUI_cache.octorankZones or {}
    if pfUI_cache.octorankZones[zone] then return end
    pfUI_cache.octorankZones[zone] = 1
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffOcto|cffffd100Ranks|r: this " .. zone .. " run is being timed for the rankings, "
      .. "from your first pull to the last boss. Your group's time goes on the realm's board by itself - |cffffd100/ranks|r shows it.")
  end

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  ev:RegisterEvent("PLAYER_LOGOUT")
  ev:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
      pcall(OR.Sync, true)
    elseif event == "PLAYER_LOGOUT" then
      -- (tables only: no unit calls at logout)
      pcall(OR.Sync, false)
    elseif event == "PLAYER_ENTERING_WORLD" then
      if not OR.helloed then
        OR.helloed = true
        pcall(OR.Hello)
      end
      pcall(OR.ZoneNote)
    else
      pcall(OR.ZoneNote)
    end
  end)
end)
