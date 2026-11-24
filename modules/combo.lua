pfUI:RegisterModule("combo", "vanilla", function ()
  -- pfUI Octo :: combo points (24 Nov 2026; user: "more options for combo points ... art work and ideas ... easy to find and
  -- edit make them amazing and the best they have ever been"). Ideas from NugComboBar (a movable bar of points, fading
  -- when empty) and ComboPointsRedux (colours by count, a big number) - feature lists only, our own code and art
  -- (tools\MakeComboArt.ps1: 12 chrome shapes tinted in game).
  -- Takes over plates.lua's P.Combo / P.ComboTick (the plate's points) and adds a bar on the screen (pfComboBar):
  --   look       16 styles: orbs, gems, squares, bar segments, a big number, and diamond, hexagon, star, blood drop,
  --              flame, blade, rune, crescent, skull, chevron, heart, shard; in a row or an arc; empty slots dimmed
  --   colours    yellow to red by count, class, one colour, a colour for each point; all turn the "full" colour at 5
  --   animations a new point pops / flashes / bounces in; at 5 a glow pulse, a burst or a shake; spent points fade up
  --              or shatter
  --   extras     the count as a number beside them, a sound at 5
  -- Settings C.plates.cp*; options Nameplates > Combo points (combo-options.lua). Old settings keep working.
  local P = pfUI.plates
  if not P then return end
  local CB = {}
  pfUI.combo = CB
  local function S() return C.plates end
  local function Art(name) return pfUI.media["img:plates\\" .. name] end
  local sin, floor = math.sin, math.floor

  -- { key, name, art (nil = drawn another way) }
  CB.STYLES = {
    { "orbs", "Orbs", "cp-orb" }, { "gems", "Gems", "cp-gem" }, { "squares", "Squares", "cp-square" },
    { "diamond", "Diamonds", "cp-diamond" }, { "hex", "Hexagons", "cp-hex" }, { "star", "Stars", "cp-star" },
    { "drop", "Blood drops", "cp-drop" }, { "flame", "Flames", "cp-flame" }, { "blade", "Blades", "cp-blade" },
    { "rune", "Runes", "cp-rune" }, { "crescent", "Crescents", "cp-crescent" }, { "skull", "Skulls", "cp-skull" },
    { "chevron", "Chevrons", "cp-chevron" }, { "heart", "Hearts", "cp-heart" }, { "shard", "Shards", "cp-shard" },
    { "segments", "Bar segments" }, { "numbers", "Big number" }, { "pfui", "pfUI's small squares" },
  }
  CB.ART = {}
  for _, s in ipairs(CB.STYLES) do if s[3] then CB.ART[s[1]] = s[3] end end
  -- plates.lua's table, so its own code (and the old tests) know every shape
  for k, v in pairs(CB.ART) do P.CPSTYLE[k] = v end

  CB.GAINS = { { "none", "None" }, { "pop", "Pop" }, { "flash", "Flash" }, { "bounce", "Bounce" }, { "drop", "Drop in" } }
  CB.FULLS = { { "none", "None" }, { "glow", "Glow pulse" }, { "burst", "Burst" }, { "shake", "Shake" }, { "all", "All of them" } }
  CB.SPENDS = { { "none", "None" }, { "fade", "Fade up" }, { "shatter", "Shatter" } }
  CB.SOUNDS = { { "none", "None" }, { "RaidWarning", "Raid warning" }, { "MapPing", "Map ping" },
    { "igQuestListComplete", "Quest complete" }, { "igMainMenuOptionCheckBoxOn", "Click" } }

  local function Col(str, r, g, b)
    local cr, cg, cb = GetStringColor(str or "")
    return tonumber(cr) or r, tonumber(cg) or g, tonumber(cb) or b
  end
  -- point i's colour while n are lit
  function CB.Color(i, n)
    local s = S()
    if n and n >= 5 and s.cpfull == "1" then return Col(s.cpfullcolor, 1, .15, .1) end
    if s.cpcolor == "points" then
      local d = { "1,.95,.3", "1,.8,.2", "1,.6,.1", "1,.4,.1", "1,.2,.1" }
      return Col(s["cpc" .. i], Col(d[i]))
    end
    return P.ComboColor(i)
  end

  -- the time-based part of a point: scale, extra light, a sideways nudge, extra rise
  function CB.Anim(o, i, now, n)
    local s = S()
    local scale, light, dx, dy = 1, 0, 0, 0
    local at = o.cpgain and o.cpgain[i]
    if at and i <= n then
      local t = now - at
      local g = s.cpgain or "pop"
      if t < .35 then
        if g == "pop" then scale = 1 + .55 * sin(math.pi * t / .35)
        elseif g == "flash" then light = 1 - t / .35
        elseif g == "bounce" then scale = 1 + .6 * math.exp(-t * 9) * math.cos(t * 28)
        elseif g == "drop" then dy = 14 * (1 - t / .35) * (1 - t / .35) light = .5 * (1 - t / .35) end
      end
    end
    if n >= 5 then
      local f = s.cpanim5 or "glow"
      if s.cpglow == "0" then f = "none" end
      local ft = now - (o.cpfullAt or 0)
      if (f == "shake" or f == "all") and ft < .4 then dx = sin(ft * 70) * 2.5 * (1 - ft / .4) end
    end
    return scale, light, dx, dy
  end
  -- something is still moving on these points (the plate keeps redrawing every frame)
  function CB.Moving(o, now, n)
    local s = S()
    if n >= 5 and s.cpglow ~= "0" and (s.cpanim5 or "glow") ~= "none" then return true end
    if s.cpspend ~= "none" and o.cpspendAt and now - o.cpspendAt < .5 then return true end
    if o.cpgain then for i = 1, 5 do if o.cpgain[i] and now - o.cpgain[i] < .4 then return true end end end
    if o.cpfullAt and now - o.cpfullAt < .6 then return true end
    return false
  end

  -- a set of points: five frames (shape, glow), a burst ring and a number
  function CB.Build(parent, o, level)
    o.cp = {}
    for i = 1, 5 do
      local f = CreateFrame("Frame", nil, parent)
      f:SetFrameLevel(level)
      f.glow = f:CreateTexture(nil, "BACKGROUND")
      f.glow:SetTexture(Art("cp-glow"))
      f.glow:SetBlendMode("ADD")
      f.glow:SetPoint("CENTER", f, "CENTER", 0, 0)
      f.glow:Hide()
      f.tex = f:CreateTexture(nil, "ARTWORK")
      f.tex:SetAllPoints(f)
      f:Hide()
      o.cp[i] = f
    end
    o.cpburst = o.cp[3]:CreateTexture(nil, "OVERLAY")
    o.cpburst:SetTexture(Art("cp-glow"))
    o.cpburst:SetBlendMode("ADD")
    o.cpburst:SetPoint("CENTER", o.cp[3], "CENTER", 0, 0)
    o.cpburst:Hide()
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetFrameLevel(level + 1)
    holder:SetAllPoints(parent)
    o.cpnum = holder:CreateFontString(nil, "OVERLAY")
    o.cpnum:SetFont(pfUI.font_unit or pfUI.font_default, 14, "OUTLINE")
    o.cpnum:Hide()
  end

  -- note what changed since last time (new points, all five, spent)
  local function Track(o, n, now)
    local prev = o.cpprev or 0
    if n ~= prev then
      o.cpgain = o.cpgain or {}
      if n > prev then
        for i = prev + 1, n do o.cpgain[i] = now end
        if n >= 5 and prev < 5 then o.cpfullAt = now end
      elseif n == 0 and prev > 0 then
        o.cpspendAt, o.cpspendN = now, prev
      end
      o.cpprev = n
    end
  end
  CB.Track = Track

  -- lay the points out: places[i] = { x, y } from the middle; w, h = a point's size
  function CB.Places(n5, w, gap, layout)
    local out = {}
    for i = 1, 5 do
      local x = (i - 3) * (w + gap)
      local y = 0
      if layout == "arc" then y = -((i - 3) * (i - 3)) * (w * .18) + w * .7 end
      out[i] = { x, y }
    end
    return out
  end

  -- paint the points of o at their places round (anchor, ax, ay); n lit; now for the animations
  function CB.Draw(o, n, now, anchor, rel, ax, ay, size, gap, segW)
    local s = S()
    local style = s.cpstyle or "orbs"
    local seg = style == "segments"
    local w = seg and segW or size
    local ht = seg and math.max(3, floor(size / 3)) or size
    local places = CB.Places(5, w, gap, seg and "row" or (s.cplayout or "row"))
    local emptyA = (tonumber(s.cpemptyalpha) or 45) / 100
    local spending = s.cpspend ~= "none" and o.cpspendAt and now - o.cpspendAt < .45 and n == 0
    local st = spending and (now - o.cpspendAt) / .45 or 0
    local showN = spending and (o.cpspendN or 0) or n
    -- the big number style, or the count beside the points
    if style == "numbers" then
      for i = 1, 5 do o.cp[i]:Hide() end
      if n > 0 or spending then
        local sc = CB.Anim(o, n > 0 and n or 1, now, n)
        o.cpnum:SetFont(pfUI.font_unit or pfUI.font_default, math.max(8, size * 1.5 * sc), "OUTLINE")
        o.cpnum:ClearAllPoints()
        o.cpnum:SetPoint("CENTER", anchor, rel, ax, ay + (spending and st * 12 or 0))
        o.cpnum:SetText(tostring(showN))
        local r, g, b = CB.Color(showN, showN)
        o.cpnum:SetTextColor(r, g, b, spending and (1 - st) or 1)
        o.cpnum:Show()
      else
        o.cpnum:Hide()
      end
      return
    end
    for i = 1, 5 do
      local f = o.cp[i]
      local lit = i <= n or (spending and i <= showN)
      local sc, light, dx, dy = CB.Anim(o, i, now, n)
      if spending and i <= showN then
        -- spent: fade upwards, or fly apart
        sc = 1 + st * .4
        if s.cpspend == "shatter" then dx, dy = (i - 3) * 16 * st, -10 * st else dy = 12 * st end
      end
      f:SetWidth(w * sc)
      f:SetHeight(ht * sc)
      f:ClearAllPoints()
      f:SetPoint("CENTER", anchor, rel, ax + places[i][1] + dx, ay + places[i][2] + dy)
      if seg then
        f.tex:SetTexture(pfUI.media[s.bartexture ~= "" and s.bartexture or C.nameplates.healthtexture])
      else
        f.tex:SetTexture(Art(CB.ART[style] or "cp-orb"))
      end
      local r, g, b = CB.Color(i, spending and showN or n)
      if lit then
        local a = spending and (1 - st) or 1
        f.tex:SetVertexColor(math.min(1, r + light), math.min(1, g + light), math.min(1, b + light), a)
      else
        f.tex:SetVertexColor(.35, .35, .38, emptyA)
      end
      -- glow: the gain flash, the pulse at five
      local glowA = 0
      if lit and light > 0 then glowA = light end
      local f5 = s.cpglow == "0" and "none" or (s.cpanim5 or "glow")
      if n >= 5 and (f5 == "glow" or f5 == "all") then glowA = math.max(glowA, .45 + .4 * sin(now * 6)) end
      if glowA > 0 then
        f.glow:SetWidth(w * 2.4 * sc)
        f.glow:SetHeight(ht * 2.4 * sc)
        f.glow:SetVertexColor(r, g, b, 1)
        f.glow:SetAlpha(glowA)
        f.glow:Show()
      else
        f.glow:Hide()
      end
      if lit or (s.cpempty == "1" and not spending) then f:Show() else f:Hide() end
    end
    -- the burst: a ring of light from the middle when the fifth point comes
    local f5 = s.cpglow == "0" and "none" or (s.cpanim5 or "glow")
    local bt = now - (o.cpfullAt or -10)
    if n >= 5 and (f5 == "burst" or f5 == "all") and bt < .6 then
      local k = bt / .6
      local r, g, b = CB.Color(5, 5)
      o.cpburst:SetWidth(w * (2 + 6 * k))
      o.cpburst:SetHeight(ht * (2 + 6 * k))
      o.cpburst:SetVertexColor(r, g, b, 1)
      o.cpburst:SetAlpha(1 - k)
      o.cpburst:Show()
    else
      o.cpburst:Hide()
    end
    -- the count as a number after the points
    if s.cptext == "1" and n > 0 then
      local last = places[5]
      o.cpnum:SetFont(pfUI.font_unit or pfUI.font_default, math.max(8, (tonumber(s.cptextsize) or 12)), "OUTLINE")
      o.cpnum:ClearAllPoints()
      o.cpnum:SetPoint("LEFT", anchor, rel, ax + last[1] + w / 2 + 4, ay + last[2])
      o.cpnum:SetText(tostring(n))
      local r, g, b = CB.Color(n, n)
      o.cpnum:SetTextColor(r, g, b, 1)
      o.cpnum:Show()
    else
      o.cpnum:Hide()
    end
  end

  -- ---------------------------------------------------------------- on the plate (replaces plates.lua's)

  function P.Combo(plate, o, n)
    if not o.cp then
      CB.Build(plate, o, plate.health:GetFrameLevel() + 3)
      for i = 1, 5 do P.Hot(plate.parent, o.cp[i], "combo", 34) end
    end
    local s = S()
    local style = s.cpstyle or "orbs"
    local on = C.nameplates.cpdisplay == "1" and style ~= "pfui" and s.enable == "1" and s.cpplate ~= "0"
    if style ~= "pfui" and plate.combopoints then
      for i = 1, 5 do plate.combopoints[i]:Hide() end
    end
    n = on and n or 0
    local now = GetTime()
    Track(o, n or 0, now)
    o.cpn = n or 0
    o.cpplate = plate
    if not on then
      for i = 1, 5 do o.cp[i]:Hide() end
      o.cpburst:Hide()
      o.cpnum:Hide()
      return
    end
    CB.PlacePlate(plate, o, now)
  end
  -- where on the plate: under the bars (clear of a cast bar), above the name, or on the health bar
  function CB.PlacePlate(plate, o, now)
    local s = S()
    local size, gap = tonumber(s.cpsize) or 12, tonumber(s.cpgap) or 3
    local h, cb = plate.health, plate.castbar
    local nx, ny = P.NameOff()
    local x, y = tonumber(s.cpoffx) or 0, tonumber(s.cpoffy) or 0
    local segW = ((h:GetWidth() or 100) - gap * 4) / 5
    local ht = (s.cpstyle == "segments") and math.max(3, floor(size / 3)) or size
    if s.cpplace == "above" then
      CB.Draw(o, o.cpn or 0, now, plate.name, "TOP", x - nx, 2 + y - ny + ht / 2, size, gap, segW)
    elseif s.cpplace == "inside" then
      CB.Draw(o, o.cpn or 0, now, h, "BOTTOM", x, y, size, gap, segW)
    else
      local under = cb:IsShown() and -((tonumber(s.castheight) or 12) + 8) or -3
      CB.Draw(o, o.cpn or 0, now, h, "BOTTOM", x, under + y - ht / 2, size, gap, segW)
    end
  end
  -- every frame while something moves: redrawn with the animations
  function P.ComboTick(o, now)
    if not o.cp or not o.cpplate then o.cpglowing = nil return end
    local n = o.cpn or 0
    local moving = CB.Moving(o, now, n)
    if moving or o.cpglowing then
      if o.cp[1]:IsShown() or o.cpnum:IsShown() or n == 0 then CB.PlacePlate(o.cpplate, o, now) end
    end
    o.cpglowing = moving or nil
  end

  -- ---------------------------------------------------------------- on the screen

  -- (NugComboBar's idea) your points in the middle of the screen, movable in layout mode
  local bar = CreateFrame("Frame", "pfComboBar", UIParent)
  CB.bar = bar
  bar:SetWidth(160)
  bar:SetHeight(34)
  bar:SetPoint("CENTER", UIParent, "CENTER", 0, -140)
  bar:SetFrameStrata("MEDIUM")
  if UpdateMovable then UpdateMovable(bar) end
  CB.Build(bar, bar, bar:GetFrameLevel() + 2)
  bar.cpn = 0
  bar.fade = 1
  bar:Hide()

  function CB.BarWanted()
    local s = S()
    if s.cpbar ~= "1" then return false end
    if pfUI.unlock and pfUI.unlock:IsShown() then return true end
    local w = s.cpbarshow or "target"
    if w == "always" then return true end
    if w == "combat" then return UnitAffectingCombat("player") and true or false end
    -- target: an enemy target, or points left on it
    return UnitExists("target") and UnitCanAttack("player", "target") and true or false
  end
  function CB.BarPaint(now)
    local s = S()
    local size = tonumber(s.cpbarsize) or 26
    local gap = tonumber(s.cpbargap) or 5
    bar:SetWidth(5 * size + 4 * gap + 8)
    bar:SetHeight(size + 8)
    local n = bar.cpn or 0
    -- (in layout mode a full row shows, so the box shows its size)
    if pfUI.unlock and pfUI.unlock:IsShown() then n = 5 end
    CB.Draw(bar, n, now, bar, "CENTER", 0, 0, size, gap, size * 1.3)
    -- empty: fades away a little after (NugComboBar's idea), back at once with a point
    local target = n > 0 and 1 or ((s.cpbarfade == "1") and 0 or 1)
    bar.fade = bar.fade + (target - bar.fade) * .12
    if math.abs(bar.fade - target) < .01 then bar.fade = target end
    bar:SetAlpha(math.max(s.cpbarfade == "1" and .0 or 1, bar.fade))
  end
  function CB.BarUpdate()
    local n = GetComboPoints and GetComboPoints("target") or 0
    if S().cpstyle == "pfui" then n = 0 end
    local now = GetTime()
    Track(bar, n, now)
    bar.cpn = n
    if CB.BarWanted() then
      if not bar:IsShown() then bar.fade = n > 0 and 1 or 0 bar:Show() end
      CB.BarPaint(now)
    else
      bar:Hide()
    end
  end
  -- every frame only while a point animates or the bar fades; otherwise four times a second
  bar:SetScript("OnUpdate", function()
    local now = GetTime()
    local busy = CB.Moving(this, now, this.cpn or 0) or math.abs((this.fade or 1) - ((this.cpn or 0) > 0 and 1 or 0)) > .01
    if not busy and (this.t or 0) > now then return end
    this.t = now + .25
    CB.BarPaint(now)
  end)

  -- events: the count changed (sound at five), a new target, in / out of combat
  local ev = CreateFrame("Frame")
  CB.events = ev
  for _, e in ipairs({ "PLAYER_COMBO_POINTS", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_ENTERING_WORLD" }) do ev:RegisterEvent(e) end
  ev:SetScript("OnEvent", function()
    if event == "PLAYER_COMBO_POINTS" then
      local n = GetComboPoints and GetComboPoints("target") or 0
      local snd = S().cpsound or "none"
      if n >= 5 and (CB.lastN or 0) < 5 and snd ~= "none" then PlaySound(snd) end
      CB.lastN = n
    elseif event == "PLAYER_TARGET_CHANGED" then
      CB.lastN = GetComboPoints and GetComboPoints("target") or 0
    end
    CB.BarUpdate()
  end)
  -- the options and layout mode change things at once
  function CB.Refresh()
    CB.BarUpdate()
    if P.Refresh then P.Refresh() end
  end
end)
