pfUI:RegisterModule("combo-options", "vanilla", function ()
  -- pfUI Octo :: Nameplates > Combo points (24 Nov 2026, modules/combo.lua): every combo point setting on one tab of its
  -- own (user: "make them in the menu easy to find and edit"), with a preview that plays them 0 to 5 and spends them -
  -- on a sample plate and on the screen bar - in your settings as you change them.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local CB = pfUI.combo
  if not W or not O or not O.AddPage or not CB then return end
  local function S() return C.plates end
  local function N() return C.nameplates end
  local function U() if CB.Refresh then CB.Refresh() end end
  local function Px(v) return v .. " px" end
  local function Pct(v) return v .. "%" end
  local function Chk(p, label, desc, group, key) return O.PfChk(p, label, desc, group, key, U) end
  local function Sld(p, label, desc, min, max, step, key, fmt) return O.PfSld(p, label, desc, min, max, step, S, key, U, fmt) end
  local function Drop(p, label, desc, list, key, after)
    local opts = {}
    for _, e in ipairs(list) do table.insert(opts, { key = e[1], label = e[2] }) end
    return W.Dropdown(p, label, desc, opts, function() return S()[key] end, function(v) S()[key] = v if after then after(v) end U() end)
  end
  local function Color(p, label, desc, key)
    return W.Color(p, label, desc, function()
      local r, g, b, a = GetStringColor(S()[key] or "1,1,1,1")
      return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
    end, function(r, g, b, a)
      S()[key] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
      U()
    end, function() return pfUI.ConfigDefault and pfUI.ConfigDefault(S(), key) end)
  end

  -- ---------------------------------------------------------------- preview

  -- the demo: 0 to 5 points a second apart, five held, then spent; or one effect on demand (CB.demo)
  local function DemoN(now)
    if CB.demo and CB.demo.untilT > now then return CB.demo.n end
    local t = math.mod(now, 7.6)
    if t < 6 then return math.min(5, math.floor(t)) end
    if t < 7 then return 5 end
    return 0
  end
  local function Preview(p)
    W.Pin(p, "Preview", "Your combo points as you set them: on a sample plate (left) and the bar on the screen (right). "
      .. "They count up, hold five, then are spent - the buttons under it play one effect.", function(pp)
      local box = (W.ZoomBox or W.Box)(pp, 120)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      local lvl = holder:GetFrameLevel()
      -- the sample plate: a name and a health bar
      local hb = CreateFrame("StatusBar", nil, holder)
      hb:SetFrameLevel(lvl + 1)
      hb:SetWidth(130)
      hb:SetHeight(10)
      hb:SetPoint("CENTER", box, "CENTER", -110, 14)
      hb:SetStatusBarTexture(pfUI.media[C.nameplates.healthtexture] or "Interface\\TargetingFrame\\UI-StatusBar")
      hb:SetMinMaxValues(0, 100)
      hb:SetValue(70)
      hb:SetStatusBarColor(.8, .15, .1, 1)
      hb.bg = hb:CreateTexture(nil, "BACKGROUND")
      hb.bg:SetAllPoints(hb)
      hb.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      hb.bg:SetVertexColor(.1, .1, .1, .9)
      local name = hb:CreateFontString(nil, "OVERLAY")
      name:SetFont(pfUI.font_default, 11, "OUTLINE")
      name:SetPoint("BOTTOM", hb, "TOP", 0, 3)
      name:SetText("Defias Pillager")
      local plateO, barO = {}, {}
      CB.Build(holder, plateO, lvl + 3)
      CB.Build(holder, barO, lvl + 3)
      local tag = holder:CreateFontString(nil, "OVERLAY")
      tag:SetFont(pfUI.font_default, 10, "OUTLINE")
      tag:SetTextColor(.6, .6, .6)
      tag:SetPoint("BOTTOM", box, "BOTTOM", 110, 8)
      tag:SetText("Screen bar")
      local tag2 = holder:CreateFontString(nil, "OVERLAY")
      tag2:SetFont(pfUI.font_default, 10, "OUTLINE")
      tag2:SetTextColor(.6, .6, .6)
      tag2:SetPoint("BOTTOM", box, "BOTTOM", -110, 8)
      tag2:SetText("On the plate")
      holder:SetScript("OnUpdate", function()
        local now = GetTime()
        local n = DemoN(now)
        local s = S()
        -- on the plate, placed as in game
        CB.Track(plateO, n, now)
        if s.cpstyle == "pfui" or s.cpplate == "0" then
          for i = 1, 5 do plateO.cp[i]:Hide() end
          plateO.cpnum:Hide()
          plateO.cpburst:Hide()
        else
          local size, gap = tonumber(s.cpsize) or 12, tonumber(s.cpgap) or 3
          local x, y = tonumber(s.cpoffx) or 0, tonumber(s.cpoffy) or 0
          local ht = s.cpstyle == "segments" and math.max(3, math.floor(size / 3)) or size
          local segW = (130 - gap * 4) / 5
          if s.cpplace == "above" then CB.Draw(plateO, n, now, name, "TOP", x, 2 + y + ht / 2, size, gap, segW)
          elseif s.cpplace == "inside" then CB.Draw(plateO, n, now, hb, "BOTTOM", x, y, size, gap, segW)
          else CB.Draw(plateO, n, now, hb, "BOTTOM", x, -3 + y - ht / 2, size, gap, segW) end
        end
        -- the screen bar (its own size)
        CB.Track(barO, n, now)
        if s.cpbar == "1" and s.cpstyle ~= "pfui" then
          local size = math.min(30, tonumber(s.cpbarsize) or 26)
          CB.Draw(barO, n, now, box, "CENTER", 110, 4, size, math.min(8, tonumber(s.cpbargap) or 5), size * 1.3)
          tag:SetText("Screen bar")
        else
          for i = 1, 5 do barO.cp[i]:Hide() end
          barO.cpnum:Hide()
          barO.cpburst:Hide()
          tag:SetText("|cff666666Screen bar: off|r")
        end
      end)
      W.Buttons(pp, {
        { "New point", function() CB.demo = { n = 3, untilT = GetTime() + 1.2 } plateO.cpprev, barO.cpprev = 2, 2 end, 100,
          "Plays the new-point animation." },
        { "Five", function() CB.demo = { n = 5, untilT = GetTime() + 2 } plateO.cpprev, barO.cpprev = 4, 4 end, 80,
          "Plays what happens at five." },
        { "Spend", function() CB.demo = { n = 0, untilT = GetTime() + 1 } plateO.cpprev, barO.cpprev = 5, 5
          plateO.cpspendAt, barO.cpspendAt = nil, nil end, 80, "Plays the spent animation." },
      })
    end)
  end

  -- picture tiles: every style, the picked one lit
  local function StyleTiles(p)
    local list = CB.STYLES
    local per, size = 9, 40
    local btns, rows = {}, {}
    for r = 1, math.ceil(table.getn(list) / per) do rows[r] = W.Row(p, size + 4, 0, 4) end
    for i, st in ipairs(list) do
      local row = rows[math.floor((i - 1) / per) + 1]
      local b = W.Button(row, "", size, size)
      b:SetPoint("LEFT", row, "LEFT", math.mod(i - 1, per) * (size + 6), 0)
      b.key = st[1]
      local t = b:CreateTexture(nil, "ARTWORK")
      t:SetWidth(size - 10)
      t:SetHeight(size - 10)
      t:SetPoint("CENTER", b, "CENTER", 0, 0)
      if st[3] then
        t:SetTexture(pfUI.media["img:plates\\" .. st[3]])
        t:SetVertexColor(1, .7, .2)
      elseif st[1] == "segments" then
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        t:SetHeight(8)
        t:SetVertexColor(1, .6, .1)
      else
        local fs = b:CreateFontString(nil, "OVERLAY")
        fs:SetFont(pfUI.font_unit or pfUI.font_default, 18, "OUTLINE")
        fs:SetPoint("CENTER", b, "CENTER", 0, 0)
        fs:SetText(st[1] == "numbers" and "5" or "pf")
        fs:SetTextColor(1, .7, .2)
        t:Hide()
      end
      b:SetScript("OnClick", function() S().cpstyle = this.key U() O:Refresh() end)
      W.Tip(b, st[2], "Click to use it.")
      btns[i] = b
    end
    local function Paint() for _, b in ipairs(btns) do W.Pick(b, S().cpstyle == b.key) end end
    Paint()
    table.insert(p.items, { Refresh = Paint })
  end

  local function Build(p)
    W.Heading(p, "Combo points", { on = { function() return N().cpdisplay == "1" end,
      function(v) N().cpdisplay = v and "1" or "0" U() end, "Your combo points on your target's plate and on the screen." },
      about = "Your combo points, every way you like them: 16 styles, colours by count or your own, animations when you gain "
        .. "a point, reach five and spend them, on your target's plate and / or a bar in the middle of the screen." })
    Preview(p)

    W.Card(p, "Look", { tip = "The shape of a point - click a picture. In a row or an arc, and how empty slots look." })
    StyleTiles(p)
    Drop(p, "Layout", "An arc lifts the middle points.", { { "row", "In a row" }, { "arc", "In an arc" } }, "cplayout")
    Sld(p, "Size", nil, 6, 34, 1, "cpsize", Px)
    Sld(p, "Gap", nil, 0, 14, 1, "cpgap", Px)
    Chk(p, "Show empty slots", "The points you do not have yet, dimmed.", S, "cpempty")
    Sld(p, "Empty slot strength", nil, 10, 90, 5, "cpemptyalpha", Pct)

    W.Card(p, "Where", { tip = "On your target's plate, and / or the bar on the screen (Screen bar card)." })
    Chk(p, "On the target's plate", nil, S, "cpplate")
    Drop(p, "Place on the plate", nil, { { "below", "Under the bars" }, { "above", "Above the name" },
      { "inside", "On the health bar" } }, "cpplace")
    Sld(p, "Left / right", nil, -80, 80, 1, "cpoffx", Px)
    Sld(p, "Up / down", nil, -40, 40, 1, "cpoffy", Px)

    W.Card(p, "Colours", { tip = "By count (yellow to red), your class colour, one colour, or a colour for each point. "
      .. "\"Full colour\" turns them all one colour at five." })
    Drop(p, "Colour", nil, { { "gradient", "Yellow to red by count" }, { "class", "Class colour" }, { "custom", "One colour" },
      { "points", "A colour for each point" } }, "cpcolor", function() O:Refresh() end)
    Color(p, "One colour", "With \"One colour\".", "cpcustom")
    for i = 1, 5 do Color(p, "Point " .. i, "With \"A colour for each point\".", "cpc" .. i) end
    Chk(p, "All one colour at five", "At five points every point takes the full colour.", S, "cpfull")
    Color(p, "Full colour", nil, "cpfullcolor")

    W.Card(p, "Animations", { tip = "When a point comes, when you have all five, and when you spend them. The buttons under "
      .. "the preview play each one." })
    Drop(p, "A new point", nil, CB.GAINS, "cpgain")
    Drop(p, "At five", nil, CB.FULLS, "cpanim5", function(v) if v ~= "none" then S().cpglow = "1" end end)
    Drop(p, "When spent", nil, CB.SPENDS, "cpspend")

    W.Card(p, "Screen bar", { on = { function() return S().cpbar == "1" end, function(v) S().cpbar = v and "1" or "0" U() end,
      "Your points in a bar in the middle of the screen - move it in Move frames." },
      tip = "A bar of your points on the screen, in the same look. It fades away with no points. Move it in Move frames." })
    Drop(p, "Shows", nil, { { "target", "With an enemy target" }, { "combat", "In combat" }, { "always", "Always" } }, "cpbarshow")
    Sld(p, "Point size", nil, 12, 60, 1, "cpbarsize", Px)
    Sld(p, "Gap", nil, 0, 20, 1, "cpbargap", Px)
    Chk(p, "Fade away with no points", nil, S, "cpbarfade")

    W.Card(p, "Extras", { tip = "The count as a number, and a sound when you reach five." })
    Chk(p, "The count as a number", "A number after the points (the Big number style is only the number).", S, "cptext")
    Sld(p, "Number size", nil, 8, 30, 1, "cptextsize", Px)
    Drop(p, "Sound at five", "Picking one plays it.", CB.SOUNDS, "cpsound", function(v) if v ~= "none" then PlaySound(v) end end)
  end
  O:AddPage("Nameplates", "npcombo", "Combo points", Build)
end)
