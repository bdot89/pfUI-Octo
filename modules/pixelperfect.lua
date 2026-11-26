pfUI:RegisterModule("pixelperfect", "vanilla:tbc", function ()
  -- pre-calculated min values
  local statics = {
    [4] = 1.4222222222222,
    [5] = 1.1377777777778,
    [6] = 0.94814814814815,
    [7] = 0.81269841269841,
    [8] = 0.71111111111111,
  }

  -- octo (31 Oct 2026, user: "a UI scale slider like in the original pfUI"):
  -- C.global.uiscale = an exact scale picked on Settings > General; it wins
  -- over the presets above. The game's own uiScale CVar only takes .64 - 1,
  -- so the exact number is set on UIParent at every login by us.
  local function own()
    local v = tonumber(C.global.uiscale or "")
    if v and v >= .3 and v <= 2 then return v end
  end

  -- (26 Nov 2026, Wolfahrt's /pfload: pixelperfect 80 ms at login) a new scale makes the client lay out every frame on
  -- UIParent again, and it ran at load and again at entering the world: the scale and the CVars are only set when they
  -- differ from what they already are
  local function SetScaleIf(v)
    local now = UIParent:GetScale()
    if not now or math.abs(now - v) > .0005 then UIParent:SetScale(v) end
  end
  local function CVarIf(name, v)
    local cur = tonumber(GetCVar(name))
    if not cur or math.abs(cur - tonumber(v)) > .0005 then SetCVar(name, v) end
  end
  -- pixel perfect
  local function pixelperfect()
    local mine = own()
    if mine then
      CVarIf("uiScale", math.max(.64, math.min(1, mine)))
      CVarIf("useUiScale", 1)
      SetScaleIf(mine)
      return
    end
    local conf = tonumber(C.global.pixelperfect) or 0
    if conf < 4 then
      -- restore gamesettings (octo: pfUI compared the CVar string with the
      -- number 1 and set the scale to that "1" - every login went to .9)
      local scale = tonumber(GetCVar("uiScale"))
      if GetCVar("useUiScale") == "1" and scale then
        SetScaleIf(scale)
      else
        SetScaleIf(.9)
      end
    else
      local scale = conf and statics[conf] or 1

      CVarIf("uiScale", scale)
      CVarIf("useUiScale", 1)

      SetScaleIf(scale)
    end
  end

  -- pixelperfect: native UIScale listener
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", function()
    if own() or (tonumber(C.global.pixelperfect) or 0) > 0 then pixelperfect() end
  end)
  if own() or (tonumber(C.global.pixelperfect) or 0) > 0 then pixelperfect() end

  pfUI.pixelperfect = {
    UpdateConfig = pixelperfect,
    -- the scale that fits one game pixel to one screen pixel
    Perfect = function()
      local _, _, w, h = string.find(GetCVar("gxResolution") or "", "(%d+)x(%d+)")
      h = tonumber(h)
      return h and h > 0 and 768 / h or nil
    end,
    -- an exact scale (nil = back to the presets / the game's own)
    Set = function(v)
      C.global.uiscale = v and string.format("%.3f", v) or ""
      pixelperfect()
    end,
  }
end)
