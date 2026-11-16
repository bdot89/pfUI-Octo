pfUI:RegisterModule("sct-preview", "vanilla", function ()
  -- pfUI Octo :: combat text preview (user, 22 Oct 2026: "a preview box for
  -- our SCT showing what each does, what it looks like, how it animates,
  -- where it animates ... a mock screen"). A small copy of your screen: every
  -- scroll area as an outlined box where it sits, a pretend enemy nameplate,
  -- and sample texts moving with the engine's own movements (CT.MOVE), sizes,
  -- crit styles, directions, times and speed. Every area box can be clicked
  -- (its options), dragged (moves the real area), Shift + wheel (text size)
  -- and right-clicked (back to where it started). CT.Mini(box, onPick).
  local B = pfUI.sctB
  local CT = B and B.SCT
  local W = pfUI.octoui and pfUI.octoui.W
  if not CT or not W or not CT.MOVE then return end
  local MOVE = CT.MOVE
  local random, floor = math.random, math.floor

  local SAMPLES = {
    inc = { { "-1234", 1, .25, .25 }, { "Dodge", 1, 1, 1 }, { "-386 Fire", 1, .5, .1 } },
    out = { { "2468", 1, 1, 1 }, { "612", 1, 1, 0 }, { "Parry", .8, .8, .8 } },
    heal = { { "+850", .2, 1, .2 }, { "+120 Mana", .35, .55, 1 }, { "+Combat", 1, .2, .2 } },
    note = { { "Killing Blow!", 1, .3, .3 }, { "Clearcasting", .6, .8, 1 }, { "+15 Honor", 1, .82, 0 } },
    extra = { { "Extra", .7, .7, 1 } },
    plate = { { "1840", 1, 1, 1 }, { "977", 1, 1, 0 }, { "Miss", .8, .8, .8 } },
  }
  local EDGE = { inc = { 1, .35, .35 }, out = { 1, 1, 1 }, heal = { .35, 1, .35 }, note = { 1, .82, 0 }, extra = { .6, .6, 1 } }
  local STRAIGHT_ORIGIN = { vertical = true, parabola = true, sway = true, wave = true, zigzag = true, spiral = true }
  local POOL = CT.RANDOM_POOL or { "vertical", "rainbow", "horizontal", "sprinkler", "parabola", "fountain", "rainfall", "sway",
                 "wave", "zigzag", "spiral", "bounce", "comet" }

  local function DB() return B.db.sct end

  -- where texts start in an area (as the engine's Origin)
  local function Origin(a, anim, dir)
    if CT.Origin then return CT.Origin(a, anim, dir) end
    if STRAIGHT_ORIGIN[a.anim] then return (a.dir == "down") and "TOP" or "BOTTOM" end
    return "CENTER"
  end

  -- the size crits pop in with (as the engine's Step)
  local function CritScale(cs, e)
    if cs == "pow" or cs == "shake" then if e < .12 then return 2 - e / .12 end
    elseif cs == "flash" then if e < .3 then return 2 - e / .3 end
    elseif cs == "sticky" then if e < .1 then return 1.3 - e * 3 end
    elseif cs == "blizzard" then
      if e < .08 then return 1 + e / .08 * .7 elseif e < .22 then return 1.7 - (e - .08) / .14 * .5 end
      return 1.2
    elseif cs == "zoom" then
      if e < .15 then return .3 + e / .15 * .9 elseif e < .25 then return 1.2 - (e - .15) / .1 * .2 end
    end
    return 1
  end

  -- hands the wheel to the page (the game's `this`, never a pfUI-only one)
  local function PassWheel(from)
    local f = from:GetParent()
    while f and not (f.GetScript and f:GetScript("OnMouseWheel")) do f = f:GetParent() end
    if not f then return end
    local old = _G.this
    _G.this = f
    f:GetScript("OnMouseWheel")()
    _G.this = old
  end

  function CT.Mini(box, onPick)
    local M = { live = {}, pool = {}, rects = {}, next = {} }
    local BW, BH = box:GetWidth() or 640, box:GetHeight() or 320
    local SW, SH = UIParent:GetWidth() or 1920, UIParent:GetHeight() or 1080
    if SW < 100 then SW, SH = 1920, 1080 end
    local k = math.min((BW - 12) / SW, (BH - 12) / SH)
    M.k = k
    -- text is drawn a little bigger than true scale so it can be read
    local tk = math.min(1, k * 1.8)

    -- the pretend screen: dark, a middle cross, your character, an enemy plate
    local scr = CreateFrame("Frame", nil, box)
    scr:SetWidth(SW * k)
    scr:SetHeight(SH * k)
    scr:SetPoint("CENTER", box, "CENTER", 0, 0)
    local bg = scr:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(scr)
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetGradient("VERTICAL", .05, .07, .09, .12, .15, .19)
    local function Line(w, h, x, y, a)
      local t = scr:CreateTexture(nil, "BORDER")
      t:SetTexture("Interface\\Buttons\\WHITE8X8")
      t:SetVertexColor(1, .82, 0, a)
      t:SetWidth(w)
      t:SetHeight(h)
      t:SetPoint("CENTER", scr, "CENTER", x, y)
    end
    Line(SW * k, 1, 0, 0, .25)
    Line(1, SH * k, 0, 0, .25)
    local me = scr:CreateTexture(nil, "ARTWORK")
    me:SetTexture("Interface\\AddOns\\pfUI\\img\\plates\\cp-orb")
    me:SetVertexColor(.6, .65, .75, 1)
    me:SetWidth(14)
    me:SetHeight(14)
    me:SetPoint("CENTER", scr, "CENTER", 0, -SH * k * .08)
    local meLabel = scr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    meLabel:SetPoint("TOP", me, "BOTTOM", 0, -1)
    meLabel:SetText("you")
    meLabel:SetTextColor(.6, .65, .75)

    -- the enemy's nameplate (text set to "Nameplate" rises from it)
    local plate = CreateFrame("Button", nil, scr)
    plate:SetWidth(130 * k * 1.6)
    plate:SetHeight(8)
    plate:SetPoint("CENTER", scr, "CENTER", SW * k * .18, SH * k * .1)
    local pbg = plate:CreateTexture(nil, "BACKGROUND")
    pbg:SetAllPoints(plate)
    pbg:SetTexture("Interface\\Buttons\\WHITE8X8")
    pbg:SetVertexColor(0, 0, 0, .8)
    local pbar = plate:CreateTexture(nil, "ARTWORK")
    pbar:SetTexture("Interface\\AddOns\\pfUI\\img\\plates\\bar-soft")
    pbar:SetVertexColor(.9, .2, .2, 1)
    pbar:SetPoint("TOPLEFT", plate, "TOPLEFT", 1, -1)
    pbar:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", -30, 1)
    local pname = plate:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pname:SetPoint("BOTTOM", plate, "TOP", 0, 1)
    pname:SetText("Enemy")
    pname:SetTextColor(1, 1, 1)
    M.plate = plate

    -- the area boxes
    local over = CreateFrame("Frame", nil, scr)
    over:SetAllPoints(scr)
    over:SetFrameLevel(scr:GetFrameLevel() + 6)

    local function Tip(f, title)
      f:SetScript("OnEnter", function()
        this.hl:Show()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine(title)
        GameTooltip:AddLine("Click: its options", 1, 1, 1)
        if this.key ~= "plate" then
          GameTooltip:AddLine("Drag: move it (the real area moves)", 1, 1, 1)
          GameTooltip:AddLine("Shift + mouse wheel: text size", 1, 1, 1)
          GameTooltip:AddLine("Right-click: put it back", 1, 1, 1)
        end
        GameTooltip:Show()
      end)
      f:SetScript("OnLeave", function()
        this.hl:Hide()
        GameTooltip:Hide()
      end)
    end

    local function Highlight(f)
      f.hl = f:CreateTexture(nil, "HIGHLIGHT")
      f.hl:SetAllPoints(f)
      f.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
      f.hl:SetVertexColor(1, 1, 1, .12)
      f.hl:Hide()
    end
    Highlight(plate)
    plate.key = "plate"
    Tip(plate, "Nameplate text")
    plate:SetScript("OnClick", function() if onPick then onPick("plate") end end)

    -- an area's box from its settings
    function M.Place(key)
      local a = DB().areas[key]
      local r = M.rects[key]
      if not a or not r then return end
      local h = (a.anim == "static") and (a.size + 8) or a.height
      r:SetWidth(math.max(8, a.width * k))
      r:SetHeight(math.max(6, h * k))
      r:ClearAllPoints()
      r:SetPoint("CENTER", scr, "CENTER", a.x * k, a.y * k)
      local c = EDGE[key] or { 1, 1, 1 }
      local on = a.enabled
      r:SetBackdropColor(c[1], c[2], c[3], on and .08 or .03)
      r:SetBackdropBorderColor(c[1], c[2], c[3], on and .85 or .3)
      r.label:SetText(CT.AREA_LABEL[key] .. (on and "" or " (off)"))
      r.label:SetTextColor(c[1], c[2], c[3], on and 1 or .5)
    end

    for i = 1, table.getn(CT.AREA_ORDER) do
      local key = CT.AREA_ORDER[i]
      local r = CreateFrame("Button", nil, over)
      r.key = key
      r:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
                      insets = { left = 0, right = 0, top = 0, bottom = 0 } })
      r.label = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      r.label:SetPoint("BOTTOM", r, "TOP", 0, 1)
      Highlight(r)
      Tip(r, "Combat text: " .. CT.AREA_LABEL[key])
      r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      r:SetScript("OnMouseDown", function()
        if arg1 ~= "LeftButton" then return end
        local a = DB().areas[this.key]
        local cx, cy = GetCursorPosition()
        this.from = { cx, cy, a.x, a.y }
        this.dragged = nil
        this:SetScript("OnUpdate", function()
          local d = this.from
          if not d then return end
          local x, y = GetCursorPosition()
          local s = (this:GetEffectiveScale() or 1) * k
          local dx, dy = (x - d[1]) / s, (y - d[2]) / s
          if not this.dragged and math.abs(dx) + math.abs(dy) < 6 / k then return end
          this.dragged = true
          local a = DB().areas[this.key]
          -- the whole area stays on the screen
          local hw, hh = a.width / 2, ((a.anim == "static") and (a.size + 8) or a.height) / 2
          a.x = floor(math.max(-SW / 2 + hw, math.min(SW / 2 - hw, d[3] + dx)) + .5)
          a.y = floor(math.max(-SH / 2 + hh, math.min(SH / 2 - hh, d[4] + dy)) + .5)
          M.Place(this.key)
          if (this.at or 0) < GetTime() then
            this.at = GetTime() + .1
            CT:PlaceArea(this.key)
          end
        end)
      end)
      r:SetScript("OnMouseUp", function()
        this.from = nil
        this:SetScript("OnUpdate", nil)
        if this.dragged then CT:PlaceArea(this.key) end
      end)
      r:SetScript("OnClick", function()
        if this.dragged then this.dragged = nil return end
        local key = this.key
        if arg1 == "RightButton" then
          local def = B.DEFAULTS.sct.areas[key]
          local a = DB().areas[key]
          a.x, a.y = def.x, def.y
          M.Place(key)
          CT:PlaceArea(key)
        elseif onPick then
          onPick(key)
        end
      end)
      r:EnableMouseWheel(true)
      r:SetScript("OnMouseWheel", function()
        if IsShiftKeyDown() then
          local a = DB().areas[this.key]
          a.size = math.max(8, math.min(48, (a.size or 20) + (arg1 or 0)))
          M.Place(this.key)
          CT:PlaceArea(this.key)
        else
          PassWheel(this)
        end
      end)
      M.rects[key] = r
      M.Place(key)
    end

    -- the moving texts, on top of everything
    local top = CreateFrame("Frame", nil, scr)
    top:SetAllPoints(scr)
    top:SetFrameLevel(scr:GetFrameLevel() + 12)

    local function Get()
      local o = table.remove(M.pool)
      if not o then
        o = { fs = top:CreateFontString(nil, "OVERLAY") }
      end
      return o
    end

    -- a sample text in an area (or on the plate)
    function M.Spawn(key)
      local db = DB()
      local a = key ~= "plate" and db.areas[key]
      local P = db.plates
      if a and not a.enabled then return end
      local list = SAMPLES[key]
      local s = list[random(1, table.getn(list))]
      local crit = random() < .3
      local o = Get()
      o.key = key
      local move, cs, size, dur, alpha
      if a then
        move, cs, size, dur, alpha = a.anim, crit and a.crit or nil, a.size * (crit and a.critScale or 1), a.time, a.alpha
        o.H, o.W = a.height * k, a.width * k
        o.d = (a.dir == "down") and -1 or 1
        o.origin = Origin(a)
      else
        move = P.hit
        cs, size, dur, alpha = crit and P.crit or nil, P.size * (crit and P.critScale or 1), P.time, 1
        o.H, o.W = P.height * k, P.width * k
        o.d = 1
        o.origin = "TOP"
      end
      -- a crit's own movement (as the engine's Show)
      local critT = crit and (a or P) or nil
      if critT then
        local path = CT.CritPath and CT.CritPath(critT, not a) or "same"
        if path == "still" then move = "pin" elseif path ~= "same" then move = path end
        if critT.critOwn then
          dur = critT.critTime or dur
          o.H, o.W = (critT.critHeight or o.H / k) * k, (critT.critWidth or o.W / k) * k
        end
      end
      if db.style == "blizzard" and not a then
        move = "vertical"
        if crit then cs = "blizzard" end
      end
      if move == "random" then move = POOL[random(1, table.getn(POOL))] end
      o.move, o.cs = move, cs
      o.feel = (a or P).feel or "steady"
      o.size = math.max(6, size * (db.scale or 1) * tk)
      o.dur = dur * ((crit and db.critLook and db.critLook.hold) or 1) / math.max(.25, db.speed or 1)
      o.alpha = alpha or 1
      -- which way, as the engine turns it (direction, side, diagonal)
      if CT.Aim then
        local critAim = critT and (critT.critOwn or (CT.CritPath and CT.CritPath(critT, not a) ~= "same"))
        local dir = CT.Aim(o, a or P, critAim, move, key == "heal")
        if a then o.origin = Origin(a, move, dir) end
      else
        o.s = (random() < .5) and -1 or 1
      end
      o.r1, o.r2, o.r3 = random(), random(), random()
      o.spr = (random() - .5) * 36
      o.slot = 0
      o.pinY = 0
      if move == "static" then
        for _, q in ipairs(M.live) do if q.key == key then q.slot = (q.slot or 0) + 1 end end
      end
      local font = (a and a.font ~= "" and a.font) or db.font
      local outline = (a and a.outline ~= "" and a.outline) or db.outline
      if crit and db.critLook and db.critLook.font ~= "" then font = db.critLook.font end
      o.fs:SetFont(B.SpyData.Font(font, db.font), o.size, outline)
      local text = s[1]
      if crit and db.critLook then text = CT.Mark(db.critLook.mark, text) end
      o.fs:SetText(text)
      local r, g, b = s[2], s[3], s[4]
      if crit and db.critLook and db.critLook.tint then r, g, b = db.critLook.r, db.critLook.g, db.critLook.b end
      o.fs:SetTextColor(r, g, b)
      if db.shadow then o.fs:SetShadowOffset(1, -1) else o.fs:SetShadowOffset(0, 0) end
      o.anchor = a and M.rects[key] or plate
      o.start = GetTime()
      o.fs:Show()
      table.insert(M.live, o)
    end

    -- one step of every text; false = it is over
    local function Step(o, now)
      local e = now - o.start
      if e >= o.dur then return false end
      local t = e / o.dur
      local x, y = 0, 0
      -- the engine's entrance (size + shake) and feel when it has them
      local sc, dx = 1, 0
      if CT.Entrance then
        if o.cs then sc, dx = CT.Entrance(o.cs, e) dx = dx * .5 end
      else
        sc = CritScale(o.cs, e)
      end
      if o.move ~= "pin" then
        local f = MOVE[o.move] or MOVE.vertical
        local te = t
        if CT.Ease and o.feel and o.feel ~= "steady" and o.move ~= "static" then te = CT.Ease(o.feel, t) end
        x, y = f(o, te)
        if CT.Bend then x, y = CT.Bend(o, x, y) end
        x = x + dx
      elseif o.cs == "shake" and e < .5 and not CT.Entrance then
        x = math.sin(e * 60) * 3 * (1 - e / .5)
      else
        x = dx
      end
      if sc ~= o.sc then o.fs:SetTextHeight(o.size * sc) o.sc = sc end
      local al = o.alpha
      local fo = math.max(.05, math.min(.9, DB().fade or .25))
      if e < .06 then al = al * e / .06 elseif t > 1 - fo then al = al * (1 - t) / fo end
      o.fs:ClearAllPoints()
      o.fs:SetPoint("CENTER", o.anchor, o.origin, x, y)
      -- texts that would leave the pretend screen are not drawn
      local ax, ay = o.anchor:GetCenter()
      local sx, sy = scr:GetCenter()
      if ax and sx then
        local px = ax - sx + x
        local py = ay - sy + y + ((o.origin == "TOP") and o.anchor:GetHeight() / 2 or (o.origin == "BOTTOM") and -o.anchor:GetHeight() / 2 or 0)
        if math.abs(px) > SW * k / 2 - 4 or math.abs(py) > SH * k / 2 - 4 then al = 0 end
      end
      o.fs:SetAlpha(al)
      return true
    end

    scr:SetScript("OnUpdate", function()
      local now = GetTime()
      -- a new text in each area now and then
      for _, key in ipairs({ "inc", "out", "heal", "note", "extra", "plate" }) do
        if (M.next[key] or 0) < now then
          M.next[key] = now + .55 + random() * .8 + ((key == "note") and 1 or 0)
          M.Spawn(key)
        end
      end
      local i = 1
      while i <= table.getn(M.live) do
        local o = M.live[i]
        if Step(o, now) then
          i = i + 1
        else
          o.fs:Hide()
          table.remove(M.live, i)
          table.insert(M.pool, o)
        end
      end
    end)

    -- settings changed elsewhere: every box again
    function M.Refresh()
      for key in pairs(M.rects) do M.Place(key) end
    end
    scr:SetScript("OnShow", function() M.Refresh() end)
    M.scr = scr
    return M
  end
end)
