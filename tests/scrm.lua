-- SuperCleveRoidMacros built in (20 Nov 2026, user: "merge the SCRM into this version so it works across all it will
-- fetch over any you had and just carry on working"): scrm\ from tools\Sync-SCRM.ps1, guarded; pfUI's bars leave
-- its macros to it; a separate copy is switched off once.
local ok = octo_ok
local DIR = "."
local function read(p)
  local h = io.open(DIR .. "/" .. p, "rb")
  if not h then return nil end
  local s = h:read("*a")
  h:close()
  return s
end

-- the test client has no ClassicAPI: the copy stays out of the way
ok(pfUIOctoSCRMSkip == true and string.find(pfUIOctoSCRMWhy or "", "ClassicAPI", 1, true) ~= nil,
  "no ClassicAPI 1.15.8: the built-in SuperCleveRoidMacros steps aside (" .. tostring(pfUIOctoSCRMWhy) .. ")")
ok(rawget(_G, "CleveRoids") == nil and rawget(_G, "SRCM_LOADED") ~= true and not (pfUI.bars and pfUI.bars.skip_macro), "and none of it ran: the bars still read macros")

-- the guard's choices
do
  local guard = read("scrm/guard.lua")
  local keep = { GetNumAddOns = _G.GetNumAddOns, GetAddOnInfo = _G.GetAddOnInfo, v = rawget(_G, "CLASSIC_API_VERSION") }
  local list = {}
  _G.GetNumAddOns = function() return table.getn(list) end
  _G.GetAddOnInfo = function(i) local a = list[i] return a[1], a[1], "", a[2], a[3] end
  local function Run() assert(loadstring(guard))() end
  rawset(_G, "CLASSIC_API_VERSION", 11508)
  list = { { "pfUI", 1, 1 }, { "Cursive", 1, 1 } }
  Run()
  ok(pfUIOctoSCRM and not pfUIOctoSCRMSkip, "ClassicAPI 1.15.8 and no other copy: ours runs")
  list = { { "pfUI", 1, 1 }, { "SuperCleveRoidMacros-main", 1, 1 } }
  Run()
  ok(pfUIOctoSCRMSkip and pfUIOctoSCRMStandalone == "SuperCleveRoidMacros-main", "a separate copy (any folder name) is on: ours steps aside")
  list = { { "pfUI", 1, 1 }, { "SuperCleveRoidMacros", nil, 1 } }
  Run()
  ok(pfUIOctoSCRM, "a separate copy switched off does not count")
  rawset(_G, "CLASSIC_API_VERSION", 11507)
  list = {}
  Run()
  ok(pfUIOctoSCRMSkip and not pfUIOctoSCRMReady, "ClassicAPI older than 1.15.8: steps aside")
  -- (21 Nov 2026, Lobo: both copies ran with the separate one on) enabled is enough to count; only an outright
  -- "cannot load" leaves it out
  local On = pfUIOctoSCRMOn_
  ok(On and On("SuperCleveRoidMacros", 1, nil) and On("SuperCleveRoidMacros", true, true) and not On("SuperCleveRoidMacros", nil, 1)
    and not On("SuperCleveRoidMacros", 1, false) and not On("pfUI", 1, 1) and not On("Cursive", 1, 1),
    "a separate copy counts when enabled, even without a 'loadable' answer")
  rawset(_G, "CLASSIC_API_VERSION", 11508)
  list = { { "pfUI", 1, 1 }, { "SuperCleveRoidMacros", 1, nil } }
  Run()
  ok(pfUIOctoSCRMSkip and pfUIOctoSCRMStandalone == "SuperCleveRoidMacros", "so ours steps aside for it")
  rawset(_G, "CLASSIC_API_VERSION", keep.v)
  _G.GetNumAddOns, _G.GetAddOnInfo = keep.GetNumAddOns, keep.GetAddOnInfo
  Run()
end

-- the copy: every file guarded, the patches in, the .toc loads it with its saved variables
do
  local xml = read("scrm/scrm.xml") or ""
  local n, bad = 0, {}
  for f in string.gfind(xml, 'Script file="([^"]+)"') do
    if f ~= "guard.lua" and f ~= "check.lua" then
      n = n + 1
      local src = read("scrm/" .. string.gsub(f, "\\", "/")) or ""
      if string.sub(src, 1, 33) ~= "if pfUIOctoSCRMSkip then return e" then table.insert(bad, f) end
    end
  end
  ok(n > 30 and table.getn(bad) == 0, "every built-in SuperCleveRoidMacros file starts with the guard (" .. n .. " files, "
    .. table.concat(bad, ", ") .. ")")
  local core, init = read("scrm/Core.lua") or "", read("scrm/Init.lua") or ""
  ok(string.find(core, 'pfUIOctoSCRM and arg1 == "pfUI"', 1, true) and string.find(core, "if not pfUIOctoSCRM then pcall(DisableAddOn", 1, true)
    and string.find(core, 'pfUIOctoSCRM and addon == "pfUI"', 1, true), "it starts on pfUI's load and never switches pfUI off")
  ok(string.find(init, "and not pfUIOctoSCRM then", 1, true), "no folder-name warning about pfUI's macrotweak")
  local toc = read("pfUI.toc") or ""
  ok(string.find(toc, "scrm\\scrm.xml", 1, true) and string.find(toc, "CleveRoidMacros, CleveRoids_LearnedDurations", 1, true),
    "pfUI.toc loads it and keeps its saved variables")
  ok(read("scrm/LICENSE-SuperCleveRoidMacros") ~= nil, "its licence goes with it")
  -- (20 Nov 2026, STAB: "scrm\Core.lua:5312: attempt to call field 'IndexActionSlot' (a nil value)" over and over)
  -- check.lua runs last: a copy that did not load fully is switched off and says what is missing, once
  local last
  for f in string.gfind(xml, 'Script file="([^"]+)"') do last = f end
  ok(last == "check.lua", "check.lua is the last file it loads")
  do
    local keep = { skip = rawget(_G, "pfUIOctoSCRMSkip"), on = rawget(_G, "pfUIOctoSCRM"), cr = rawget(_G, "CleveRoids"),
      broken = rawget(_G, "pfUIOctoSCRMBroken") }
    local unreg = 0
    rawset(_G, "pfUIOctoSCRMSkip", false)
    rawset(_G, "pfUIOctoSCRM", true)
    rawset(_G, "CleveRoids", { Frame = { UnregisterAllEvents = function() unreg = unreg + 1 end } })
    assert(loadfile("scrm/check.lua"))()
    ok(string.find(tostring(pfUIOctoSCRMBroken), "IndexActionSlot", 1, true) and unreg == 1 and pfUIOctoSCRMSkip == true,
      "half loaded: switched off, its events stopped, the missing parts named (" .. tostring(pfUIOctoSCRMBroken) .. ")")
    local full = {}
    for _, n in ipairs(pfUIOctoSCRMNEED) do full[n] = function() end end
    ok(pfUIOctoSCRMCheck(full) == nil, "fully loaded: nothing missing")
    rawset(_G, "pfUIOctoSCRMSkip", keep.skip)
    rawset(_G, "pfUIOctoSCRM", keep.on)
    rawset(_G, "CleveRoids", keep.cr)
    rawset(_G, "pfUIOctoSCRMBroken", keep.broken)
  end
end

-- (Wolfahrt, 20 Nov 2026: "the newest SCRM does not work with this version of PFui") pfUI's bars stop reading
-- its macros, and a scan made before it loaded is dropped
do
  local S = pfUI.scrm
  ok(S and S.Apply and S.Login, "pfUI's side of it is there")
  if S and pfUI.bars then
    local keepSkip, keepFlag = pfUI.bars.skip_macro, rawget(_G, "SRCM_LOADED")
    pfUI.bars.skip_macro = nil
    local b
    for _, button in pairs(pfUI.bars.buttons or {}) do b = button break end
    if b then b.spellslot = 5 end
    rawset(_G, "SRCM_LOADED", true)
    S.Apply()
    ok(pfUI.bars.skip_macro and (not b or b.spellslot == nil), "with it loaded the bars leave macros to it")
    -- a separate copy is switched off once, and left alone when turned on again
    local off = 0
    local keep = { d = _G.DisableAddOn, s = rawget(_G, "pfUIOctoSCRMStandalone"), r = rawget(_G, "pfUIOctoSCRMReady"), t = pfUI_cache.scrmTakeover }
    _G.DisableAddOn = function() off = off + 1 end
    rawset(_G, "pfUIOctoSCRMStandalone", "SuperCleveRoidMacros")
    rawset(_G, "pfUIOctoSCRMReady", true)
    pfUI_cache.scrmTakeover = nil
    S.Login()
    S.Login()
    ok(off == 1 and pfUI_cache.scrmTakeover == "SuperCleveRoidMacros", "the separate copy is switched off once (" .. off .. ")")
    rawset(_G, "pfUIOctoSCRMReady", false)
    pfUI_cache.scrmTakeover = nil
    S.Login()
    ok(off == 1, "never when ours cannot run")
    _G.DisableAddOn = keep.d
    rawset(_G, "pfUIOctoSCRMStandalone", keep.s)
    rawset(_G, "pfUIOctoSCRMReady", keep.r)
    pfUI_cache.scrmTakeover = keep.t
    pfUI.bars.skip_macro = keepSkip
    rawset(_G, "SRCM_LOADED", keepFlag)
  end
end
