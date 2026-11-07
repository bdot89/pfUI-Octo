pfUI:RegisterModule("weirdutils-guard", "vanilla", function ()
  -- pfUI Octo :: a guard round WeirdUtils' minimap tracking calls (7 Nov 2026; Javelin: "game fatal errors when
  -- playing with the tracking button, removing or adding tracks quickly"). WeirdUtils' own tracking menu
  -- answers every click by calling WeirdUtils.SetObjectTypeBlip once for EACH of its 18 kinds - the ones that did
  -- not change too, each loading its texture again - so quick clicks make a burst of DLL calls inside one frame,
  -- and a crash in the DLL is a crash outside Lua, where nothing can catch it. Here those calls are
  --   1. dropped when they ask for what is already so (only the kind that changed gets through),
  --   2. kept in their order and made one at a time, a few frames apart.
  -- Nothing is lost: the last answer for each kind always arrives, a fraction of a second later.
  local G = {}
  pfUI.wuguard = G
  G.calls, G.passed = 0, 0

  local function Install()
    local wu = _G.WeirdUtils
    if type(wu) ~= "table" or type(wu.SetObjectTypeBlip) ~= "function" or wu.octoGuard then return end
    local raw = wu.SetObjectTypeBlip
    wu.octoGuard = true
    local applied = {}     -- key -> the last thing sent: "texture|scale"
    local queue, pending = {}, {}
    wu.SetObjectTypeBlip = function(kind, tex, scale, inc, exc)
      G.calls = G.calls + 1
      local key = tostring(kind) .. "\1" .. tostring(inc) .. "\1" .. tostring(exc)
      local sig = tostring(tex) .. "|" .. tostring(scale)
      if pending[key] then
        pending[key].tex, pending[key].scale, pending[key].sig = tex, scale, sig
        return
      end
      if applied[key] == sig then return end
      local e = { key = key, kind = kind, tex = tex, scale = scale, inc = inc, exc = exc, sig = sig }
      pending[key] = e
      table.insert(queue, e)
    end
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function()
      if (this.t or 0) > GetTime() then return end
      local e = table.remove(queue, 1)
      if not e then return end
      this.t = GetTime() + .06
      pending[e.key] = nil
      if applied[e.key] == e.sig then return end
      applied[e.key] = e.sig
      G.passed = G.passed + 1
      raw(e.kind, e.tex, e.scale, e.inc, e.exc)
    end)
    G.queue, G.frame = queue, f
  end
  Install()
  -- the DLL's table may come after this file, and its embedded addon calls in at VARIABLES_LOADED
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("VARIABLES_LOADED")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:SetScript("OnEvent", function() Install() end)
  G.Install = Install
end)
