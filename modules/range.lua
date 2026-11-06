pfUI:RegisterModule("range", "vanilla", function ()
  -- pfUI Octo :: target range (6 Nov 2026; user: "add range into my target frame ... a lot better and
  -- accurate ... tidy and neat"; their own Rangecheck addon was the model). A small frame under the target
  -- frame (movable: Move Frames; right-click it there = its options), shown while you have a target:
  --   distance   exact yards: UnitXP SP3's edge to edge number (as the game's own range checks), else
  --              ClassicAPI UnitDistanceSquared / SuperWoW UnitPosition (centre to centre); with none of
  --              them a band from CheckInteractDistance (< 10, 10 - 28, 28 +)
  --   colour     by band (melee / spell / far ranges and four colours), or one colour of your own
  --   trend      a bar from the middle: green to the right = closing, red to the left = backing off
  -- (a direction arrow was tried and taken out the same day: it did not work in game.)
  -- The frame is always as wide as the widest number it can show, so the text never spills out.
  -- Settings: C.range (page "Target range" under Unit Frames). Nothing here runs without a target.
  local RG = {}
  pfUI.range = RG
  local G = function() return C.range end
  local function On(k) return G()[k] == "1" end
  local function Num(k, d) return tonumber(G()[k]) or d end
  local floor, abs = math.floor, math.abs
  local lc = pfUI.api and pfUI.api.libclient

  -- ------------------------------------------------------------------ the distance
  -- ClassicAPI's number is centre to centre; UnitXP SP3's "distanceBetween" takes the bodies' size off, as
  -- the game's own range checks do (first look in game: 12.7 yd against 9.8 yd on the same target). So UnitXP
  -- SP3's is the default when there is one: C.range.source edge | melee | centre
  local function SP3()
    if not lc then return false end
    if lc.hasSP3 == nil then
      local ok, r = pcall(_G.UnitXP or function() end, "inSight", "player", "player")
      lc.hasSP3 = ok and type(r) == "boolean"
    end
    return lc.hasSP3
  end
  -- distance to the target in yards (exact), or nil and a band (text)
  function RG.Distance()
    if not UnitExists("target") then return end
    if UnitIsUnit("target", "player") then return end
    local src = G().source or "edge"
    if src ~= "centre" and SP3() then
      local ok, d
      if src == "melee" then ok, d = pcall(_G.UnitXP, "distanceBetween", "player", "target", "meleeAutoAttack")
      else ok, d = pcall(_G.UnitXP, "distanceBetween", "player", "target") end
      if ok and type(d) == "number" and d >= 0 then return d end
    end
    local d = lc and lc.Distance and lc.Distance("target")
    if d then return d end
    if CheckInteractDistance then
      if CheckInteractDistance("target", 3) then return nil, "< 10" end
      if CheckInteractDistance("target", 4) then return nil, "10 - 28" end
      return nil, "28+"
    end
  end

  function RG.Colour(d)
    local key = "c_out"
    if d then
      if d <= Num("melee", 5) then key = "c_near"
      elseif d <= Num("spell", 30) then key = "c_mid"
      elseif d <= Num("far", 40) then key = "c_far" end
    end
    local r, g, b = GetStringColor(G()[key] or "1,1,1,1")
    return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1
  end
  -- the one colour of "One colour" as numbers
  function RG.Fixed()
    local r, g, b = GetStringColor(G().textcolor or "1,1,1,1")
    return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, 1
  end

  -- ------------------------------------------------------------------- the frame
  local f = CreateFrame("Frame", "pfTargetRange", UIParent)
  RG.frame = f
  f:SetFrameStrata("MEDIUM")
  f:SetWidth(100)
  f:SetHeight(30)
  f:EnableMouse(false)
  CreateBackdrop(f, nil, true)
  f:Hide()

  f.text = f:CreateFontString(nil, "OVERLAY")
  f.text:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, 16, "OUTLINE")
  f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.text:SetJustifyH("CENTER")
  f.holder = CreateFrame("Frame", nil, f)
  f.holder:SetHeight(5)
  f.hbg = f.holder:CreateTexture(nil, "BACKGROUND")
  f.hbg:SetAllPoints(f.holder)
  f.hbg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
  f.hbg:SetVertexColor(.5, .5, .5, .2)
  f.mid = f.holder:CreateTexture(nil, "OVERLAY")
  f.mid:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
  f.mid:SetWidth(1)
  f.mid:SetHeight(5)
  f.mid:SetPoint("CENTER", f.holder, "CENTER", 0, 0)
  f.mid:SetVertexColor(.8, .8, .8, .8)
  f.closer = f.holder:CreateTexture(nil, "ARTWORK")
  f.closer:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
  f.closer:SetHeight(5)
  f.closer:SetWidth(.01)
  f.closer:SetPoint("LEFT", f.mid, "RIGHT", 0, 0)
  f.closer:SetVertexColor(.3, .9, .3, .9)
  f.further = f.holder:CreateTexture(nil, "ARTWORK")
  f.further:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
  f.further:SetHeight(5)
  f.further:SetWidth(.01)
  f.further:SetPoint("RIGHT", f.mid, "LEFT", 0, 0)
  f.further:SetVertexColor(.95, .3, .3, .9)

  -- docked under the target frame; Move Frames puts it anywhere (and it stays there)
  function RG.Dock()
    f:ClearAllPoints()
    local host = _G.pfTarget or _G.TargetFrame
    if host then f:SetPoint("TOP", host, "BOTTOM", 0, -4) else f:SetPoint("CENTER", UIParent, "CENTER", 0, -120) end
  end
  function RG.TextFont()
    local path = G().font
    if not path or path == "" then path = pfUI.font_default or STANDARD_TEXT_FONT end
    return path
  end
  -- the widest text it can ever show: the longest number at this many decimals, or the longest band
  function RG.Widest()
    local dec = floor(Num("decimals", 1))
    local unit = On("unit") and " yd" or ""
    local num = "888" .. (dec > 0 and ("." .. string.rep("8", dec)) or "") .. unit
    local best = 0
    for _, s in ipairs({ num, "10 - 28" .. unit, "< 10" .. unit, "28+" .. unit, "--" .. unit }) do
      f.text:SetText(s)
      local w = f.text:GetStringWidth() or 0
      if w > best then best = w end
    end
    return best
  end
  -- every part is its own switch (box, number's "yd", bar); the frame is as big as what is on, and always
  -- wide enough for the widest number, so nothing spills out of the box
  function RG.Layout()
    f:SetScale(Num("scale", 100) / 100)
    local size = Num("fontsize", 16)
    local outline = G().outline
    if outline == nil or outline == "none" then outline = "" end
    f.text:SetFont(RG.TextFont(), size, outline)
    if G().shadow == "1" then f.text:SetShadowOffset(1, -1) f.text:SetShadowColor(0, 0, 0, 1) else f.text:SetShadowOffset(0, 0) end
    local pad = On("box") and 8 or 2
    local trend = On("trend")
    local w = RG.Widest() + 4
    f:SetWidth(math.max(40, pad * 2 + w))
    f:SetHeight(pad * 2 + size + 2 + (trend and 9 or 0))
    f.text:ClearAllPoints()
    f.text:SetPoint("CENTER", f, "CENTER", 0, trend and 4 or 0)
    f.holder:ClearAllPoints()
    f.holder:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", pad, pad - (On("box") and 2 or 0))
    f.holder:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad - (On("box") and 2 or 0))
    if trend then f.holder:Show() else f.holder:Hide() end
    if f.backdrop then if On("box") then f.backdrop:Show() else f.backdrop:Hide() end end
    if f.backdrop_shadow then if On("box") then f.backdrop_shadow:Show() else f.backdrop_shadow:Hide() end end
  end
  RG.Dock()
  UpdateMovable(f)
  RG.Layout()
  function RG.ResetPlace()
    if C.position then C.position["pfTargetRange"] = nil end
    RG.Dock()
  end

  -- ------------------------------------------------------------------ each frame
  local prev, prevT, vel = nil, 0, 0
  function RG.Draw(dist, band, now)
    local text
    if dist then
      local dec = floor(Num("decimals", 1))
      text = string.format("%." .. dec .. "f", dist) .. (On("unit") and " yd" or "")
    else
      text = (band or "--") .. (On("unit") and " yd" or "")
    end
    f.text:SetText(text)
    if G().colormode == "fixed" then f.text:SetTextColor(RG.Fixed()) else f.text:SetTextColor(RG.Colour(dist)) end

    if On("trend") then
      if dist and prev then
        local dt = now - prevT
        if dt > .001 then vel = vel + .25 * ((dist - prev) / dt - vel) end
      else
        vel = 0
      end
      if dist then prev, prevT = dist, now else prev = nil end
      local half = floor((f.holder:GetWidth() or 120) / 2)
      local maxv = Num("maxvel", 15)
      f.closer:SetWidth(.01)
      f.further:SetWidth(.01)
      if vel < -.3 then f.closer:SetWidth(math.max(.01, floor(math.min(1, -vel / maxv) * half)))
      elseif vel > .3 then f.further:SetWidth(math.max(.01, floor(math.min(1, vel / maxv) * half))) end
    end
  end

  -- a made-up target for the options: moving in and out
  RG.testUntil = 0
  function RG.Test(seconds) RG.testUntil = GetTime() + (seconds or 8) end

  local driver = CreateFrame("Frame")
  driver:SetScript("OnUpdate", function()
    if (this.t or 0) > GetTime() then return end
    this.t = GetTime() + .05
    local now = GetTime()
    if not On("enable") then f:Hide() return end
    -- Move Frames: a made-up reading, so there is something to see and drag
    if pfUI.unlock and pfUI.unlock:IsShown() then
      RG.Draw(22.5, nil, now)
      f:Show()
      return
    end
    if now < RG.testUntil then
      RG.Draw(22 + 20 * math.sin(now * .6), nil, now)
      f:Show()
      return
    end
    if not UnitExists("target") then prev = nil f:Hide() return end
    if UnitIsUnit("target", "player") and not On("self") then f:Hide() return end
    if G().showfor == "enemy" and not UnitCanAttack("player", "target") then f:Hide() return end
    if G().showfor == "friend" and UnitCanAttack("player", "target") then f:Hide() return end
    local d, band = RG.Distance()
    RG.Draw(d, band, now)
    f:Show()
  end)
end)
