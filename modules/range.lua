pfUI:RegisterModule("range", "vanilla", function ()
  -- pfUI Octo :: target range (6 Nov 2026; user: "add range into my target frame ... a lot better and
  -- accurate ... direction to target, range etc, all tidy and neat"; their own Rangecheck addon was the
  -- model: distance text + a bar that shows closing / retreating). A small frame under the target frame
  -- (movable: Move Frames), shown while you have a target:
  --   distance   exact yards: ClassicAPI UnitDistanceSquared, else SuperWoW UnitPosition, else UnitXP SP3
  --              (libclient.Distance); with none of them a band from CheckInteractDistance (< 10, 10 - 28, 28 +)
  --   colour     by band: melee / spell / far ranges (settings), four colours
  --   arrow      points at the target from where you face (positions + the minimap arrow's facing)
  --   trend      a bar from the middle: green to the right = closing, red to the left = backing off
  -- Settings: C.range (page "Target range" under Unit Frames). Nothing here is called without a target.
  local RG = {}
  pfUI.range = RG
  local G = function() return C.range end
  local function On(k) return G()[k] == "1" end
  local function Num(k, d) return tonumber(G()[k]) or d end
  local floor, abs, atan2, sin, cos, pi = math.floor, math.abs, math.atan2, math.sin, math.cos, math.pi
  local lc = pfUI.api and pfUI.api.libclient

  -- ------------------------------------------------------------------ what is known
  -- the player's facing, from the arrow model the game keeps on the minimap (as pfQuest does)
  local arrow
  local function FindArrow()
    if arrow ~= nil then return arrow or nil end
    arrow = false
    if not Minimap or not Minimap.GetChildren then return end
    for _, v in ipairs({ Minimap:GetChildren() }) do
      if v.IsObjectType and v:IsObjectType("Model") and not v:GetName() and v.GetModel then
        local m = v:GetModel()
        if type(m) == "string" and string.find(string.lower(m), "minimaparrow", 1, true) then arrow = v break end
      end
    end
    return arrow or nil
  end
  function RG.Facing()
    local m = FindArrow()
    return m and m.GetFacing and m:GetFacing() or nil
  end

  local function Pos(unit)
    if not _G.UnitPosition or not UnitExists(unit) then return end
    local ok, x, y = pcall(_G.UnitPosition, unit)
    x, y = tonumber(x), tonumber(y)
    if ok and x and y then return x, y end
  end
  -- the clients disagree on which of the two numbers is north and which way is west: eight ways to
  -- read them, picked once by running forward (RG.Calibrate), kept in C.range.axis
  local TR = {
    function(a, b) return a, b end, function(a, b) return b, a end, function(a, b) return -a, b end,
    function(a, b) return a, -b end, function(a, b) return -a, -b end, function(a, b) return b, -a end,
    function(a, b) return -b, a end, function(a, b) return -b, -a end,
  }
  -- (not "x and f(a, b)": and keeps only the first of two returns)
  local function Tr(a, b)
    local fn = TR[floor(Num("axis", 1))]
    if fn then return fn(a, b) end
  end
  local function Wrap(a)
    while a > pi do a = a - 2 * pi end
    while a < -pi do a = a + 2 * pi end
    return a
  end
  -- target direction relative to where you face, radians: 0 = ahead, positive = to the left
  function RG.Bearing()
    local f = RG.Facing()
    local px, py = Pos("player")
    local tx, ty = Pos("target")
    if not (f and px and tx) then return end
    local ax, ay = Tr(px, py)
    local bx, by = Tr(tx, ty)
    if not (ax and bx) then return end
    if abs(bx - ax) < .01 and abs(by - ay) < .01 then return end
    return Wrap(atan2(by - ay, bx - ax) - f)
  end
  -- votes: each ~0.25 s of running, the reading whose direction of travel matches your facing gets one
  RG.votes = { 0, 0, 0, 0, 0, 0, 0, 0 }
  local last = { t = 0 }
  function RG.Calibrate(now)
    if now - last.t < .25 then return end
    local f = RG.Facing()
    local x, y = Pos("player")
    local sp = _G.GetUnitSpeed and _G.GetUnitSpeed("player") or 0
    if not (f and x) then last.x = nil return end
    if last.x and (tonumber(sp) or 0) > 3 and now - last.t < .6 then
      local dx, dy = x - last.x, y - last.y
      if dx * dx + dy * dy > .25 then
        local best, bestErr, second = nil, 9, 9
        for k = 1, 8 do
          local a, b = TR[k](dx, dy)
          local e = abs(Wrap(atan2(b, a) - f))
          if e < bestErr then second, bestErr, best = bestErr, e, k elseif e < second then second = e end
        end
        if best and bestErr < .5 and second - bestErr > .5 then RG.votes[best] = RG.votes[best] + 1 end
        local top, sum, pick = 0, 0, nil
        for k = 1, 8 do sum = sum + RG.votes[k] if RG.votes[k] > top then top, pick = RG.votes[k], k end end
        if pick and top >= 6 and top >= sum * .6 and floor(Num("axis", 1)) ~= pick then G().axis = tostring(pick) end
      end
    end
    last.x, last.y, last.t = x, y, now
  end

  -- distance to the target, in yards (exact) or a band (text, no number)
  function RG.Distance()
    if not UnitExists("target") then return end
    if UnitIsUnit("target", "player") then return end
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

  -- ------------------------------------------------------------------- the frame
  local f = CreateFrame("Frame", "pfTargetRange", UIParent)
  RG.frame = f
  f:SetFrameStrata("MEDIUM")
  f:SetWidth(150)
  f:SetHeight(42)
  f:EnableMouse(false)
  CreateBackdrop(f, nil, true)
  f:Hide()

  f.arrow = f:CreateTexture(nil, "OVERLAY")
  f.arrow:SetTexture("Interface\\AddOns\\pfUI\\img\\plates\\arrow")
  f.arrow:SetWidth(24)
  f.arrow:SetHeight(24)
  f.arrow:SetPoint("LEFT", f, "LEFT", 8, 4)
  f.text = f:CreateFontString(nil, "OVERLAY")
  f.text:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, 16, "OUTLINE")
  f.text:SetPoint("LEFT", f.arrow, "RIGHT", 6, 0)
  f.text:SetPoint("RIGHT", f, "RIGHT", -8, 4)
  f.text:SetJustifyH("CENTER")
  f.holder = CreateFrame("Frame", nil, f)
  f.holder:SetHeight(5)
  f.holder:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 6)
  f.holder:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 6)
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
  function RG.Layout()
    local s = Num("scale", 100) / 100
    f:SetScale(s)
    local fs = Num("fontsize", 16)
    f.text:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, fs, "OUTLINE")
    if On("arrow") then f.arrow:Show() f.text:SetPoint("LEFT", f.arrow, "RIGHT", 6, 0) else f.arrow:Hide() f.text:SetPoint("LEFT", f, "LEFT", 8, 4) end
    if On("trend") then f.holder:Show() f:SetHeight(42) else f.holder:Hide() f:SetHeight(32) end
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
  function RG.Draw(dist, band, bearing, now)
    local text
    if dist then
      local dec = floor(Num("decimals", 1))
      text = string.format("%." .. dec .. "f", dist) .. " yd"
    else
      text = (band or "--") .. " yd"
    end
    f.text:SetText(text)
    f.text:SetTextColor(RG.Colour(dist))

    if On("arrow") then
      if bearing then
        f.arrow:SetVertexColor(RG.Colour(dist))
        pfUI.octoui.U.Rotate(f.arrow, (bearing + pi / 2) * (On("flip") and -1 or 1))
        f.arrow:SetAlpha(1)
      else
        f.arrow:SetAlpha(.25)
      end
    end

    if On("trend") then
      if dist and prev then
        local dt = now - prevT
        if dt > .001 then
          vel = vel + .25 * ((dist - prev) / dt - vel)
        end
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

  -- a made-up target for the options: 8 s of a figure moving in and out, round and round
  RG.testUntil = 0
  function RG.Test(seconds) RG.testUntil = GetTime() + (seconds or 8) end

  local tick = 0
  f:SetScript("OnUpdate", function() end)
  local driver = CreateFrame("Frame")
  driver:SetScript("OnUpdate", function()
    if (this.t or 0) > GetTime() then return end
    this.t = GetTime() + .05
    local now = GetTime()
    if not On("enable") then f:Hide() return end
    if (_G.UnitExists and UnitExists("target")) or now < RG.testUntil then RG.Calibrate(now) end
    if now < RG.testUntil then
      local ph = (now * .6)
      RG.Draw(22 + 20 * sin(ph), nil, Wrap(ph * 1.7), now)
      f:Show()
      return
    end
    if not UnitExists("target") then prev = nil f:Hide() return end
    if UnitIsUnit("target", "player") and not On("self") then f:Hide() return end
    if G().showfor == "enemy" and not UnitCanAttack("player", "target") then f:Hide() return end
    if G().showfor == "friend" and UnitCanAttack("player", "target") then f:Hide() return end
    local d, band = RG.Distance()
    RG.Draw(d, band, d and RG.Bearing() or nil, now)
    f:Show()
  end)
end)
