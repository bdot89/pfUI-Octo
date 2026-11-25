-- pfUI Octo: fixes from the code review of 1.2.52 (25 Nov 2026), run by tests\run.lua
local ok = octo_ok

-- loading a profile makes it the current one (UpdateConfig only fills a missing value)
do
  local O = pfUI.octoui and pfUI.octoui.Options
  if O and O.ProfileLoad then
    local keepCfg, keepProfiles, keepReload = pfUI_config, pfUI_profiles, rawget(_G, "ReloadUI")
    local keepLoad = pfUI.LoadConfig
    pfUI_profiles = { Raid = { global = { profile = "Old" }, chat = { right = { enable = "0" } } } }
    _G.ReloadUI = function() end
    pfUI.LoadConfig = function() end
    O.ProfileLoad("Raid")
    local picked, rchat = pfUI_config.global.profile, pfUI_config.chat.right.enable
    _G.pfUI_config, pfUI_profiles, _G.ReloadUI, pfUI.LoadConfig = keepCfg, keepProfiles, keepReload, keepLoad
    ok(picked == "Raid", "a loaded profile is the current one (" .. tostring(picked) .. ")")
    ok(rchat == (keepCfg.chat and keepCfg.chat.right and keepCfg.chat.right.enable) or rchat == nil or rchat == "0",
      "the right chat keeps its own state")
  end
end

-- names heard: old ones go, and never more than U.MAX
do
  local U = pfUI.octoUsers
  if U and U.Prune then
    local s = U.Store()
    local keep = {}
    for k, v in pairs(s) do keep[k] = v s[k] = nil end
    local now = time()
    s.Gone = { t = now - 40 * 86400 }
    s.Here = { t = now - 86400 }
    U.Prune()
    ok(s.Here and not s.Gone, "names not heard for 30 days are forgotten")
    local keepMax = U.MAX
    U.MAX = 3
    for i = 1, 6 do s["N" .. i] = { t = now - i } end
    U.Prune()
    local n = 0
    for _ in pairs(s) do n = n + 1 end
    ok(n == 3 and s.N1 and s.N2 and not s.N6, "at most U.MAX names, the newest kept (" .. n .. ")")
    U.MAX = keepMax
    for k in pairs(s) do s[k] = nil end
    for k, v in pairs(keep) do s[k] = v end
  end
end

-- the old whisper store: silent names go
do
  local WH = pfUI.whispers
  if WH and WH.Prune then
    local keepKeep = WH.KEEP_DAYS
    pfUI_cache.whispers = pfUI_cache.whispers or {}
    local key
    for k in pairs(pfUI_cache.whispers) do key = k end
    if key then
      local s = pfUI_cache.whispers[key]
      s.ReviewOld = { { t = time() - 90 * 86400, dir = "in", msg = "hi" } }
      s.ReviewNew = { { t = time(), dir = "in", msg = "hi" } }
      WH.Prune()
      ok(not s.ReviewOld and s.ReviewNew, "whisper history of a name silent for 60 days goes")
      s.ReviewNew = nil
    end
    WH.KEEP_DAYS = keepKeep
  end
end

-- flight times from others: one route between two names, and a limit
do
  local FL = pfUI.flight
  if FL and FL.Receive then
    local keepTimes, keepOn = pfUI_cache.flighttimes, nil
    pfUI_cache.flighttimes = {}
    local keepShare = C and C.flight and C.flight.share
    if pfUI_config.flight then pfUI_config.flight.share = "1" end
    FL.peerN = nil
    ok(FL.Receive("Booty Bay>Ratchet^60", "Pal") == true, "a route from another player is taken")
    ok(not FL.Receive("A>B>C^60", "Pal") and not FL.Receive("A|cff>B^60", "Pal"), "keys that are not one route are not")
    local keepMax = FL.PEER_MAX
    FL.PEER_MAX = 2
    FL.Receive("X1>Y1^60", "Pal")
    ok(not FL.Receive("X2>Y2^60", "Pal"), "no more than FL.PEER_MAX routes from others")
    FL.PEER_MAX, FL.peerN = keepMax, nil
    pfUI_cache.flighttimes = keepTimes
    if pfUI_config.flight then pfUI_config.flight.share = keepShare end
    _ = keepOn
  end
end

-- the earthen bulwark keeps your own width while it sits under the totem bars
do
  local BW = pfUI.bulwark
  if BW and BW.Paint and pfUI_config.bulwark then
    local keep = pfUI_config.bulwark.width
    pfUI_config.bulwark.width = "222"
    BW.attached, BW.attachW = true, 160
    local f = { SetWidth = function(self, w) self.w = w end }
    pcall(BW.Paint, f, nil)
    ok(f.w == 160 and pfUI_config.bulwark.width == "222", "attached: drawn at the totem bars' width, your width kept")
    BW.attached, BW.attachW = nil, nil
    pfUI_config.bulwark.width = keep
  end
end
