pfUI:RegisterModule("swing-options", "vanilla", function ()
  -- pfUI Octo :: the Swing Timer section (24 Oct 2026, modules/swing.lua).
  -- One page with every setting of WeaponSwingTimer's bars (its option list
  -- as the model; GPL-3, nothing copied), a pinned preview that runs the
  -- three bars on a made-up fight with the real drawing code, and a test on
  -- the real bars. Click a bar in the preview for its card; Shift + wheel
  -- over it = its height.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local ST = pfUI.swing
  if not W or not O or not O.AddPage or not ST then return end
  local SO = {}
  pfUI.swingOcto = SO

  local function G(bar) return function() return C.swing[bar] end end
  local function Px(v) return v .. " px" end
  local function Pct(v) return math.floor(v * 100 + .5) .. "%" end
  local function Up() ST.ApplyLayout() if SO.Layout then SO.Layout() end end
  local function Chk(p, label, desc, group, key) return O.PfChk(p, label, desc, group, key, Up) end
  local function Sld(p, label, desc, min, max, step, group, key, fmt) return O.PfSld(p, label, desc, min, max, step, group, key, Up, fmt) end
  local function Drop(p, label, desc, options, group, key)
    return W.Dropdown(p, label, desc, options, function() return group()[key] end, function(v) group()[key] = v Up() end)
  end
  local function Color(p, label, desc, group, key)
    return W.Color(p, label, desc, function()
      local r, g, b, a = GetStringColor(group()[key] or "1,1,1,1")
      return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
    end, function(r, g, b, a)
      group()[key] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
      Up()
    end)
  end

  -- the bar textures: the four looks, then every pfUI bar texture
  local function BarList()
    local out = {}
    for _, b in ipairs(ST.BARS) do table.insert(out, { key = b.key, label = b.label, texture = b.tex }) end
    local list = pfUI.gui and pfUI.gui.dropdowns and pfUI.gui.dropdowns.uf_bartexture
    for _, e in ipairs(list or {}) do
      local _, _, k, l = string.find(e, "^(.-):(.*)$")
      if k then table.insert(out, { key = k, label = l, texture = k }) end
    end
    return out
  end

  local CARD = { player = "Your swing", target = "Target's swing", ranged = "Auto Shot and wand", cast = "Aimed and Multi-Shot" }
  function SO.Open(card)
    if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection("stbars", card) else O:Open("stbars") end
  end

  -- ---------------------------------------------------------------- preview

  local function Preview(p)
    W.Pin(p, "Preview", "Your bars on a made-up fight, drawn by the real bar code with your settings: your swing "
      .. "(main and off hand; every third swing a Heroic Strike waits on it), your target's swing, Auto Shot and an Aimed Shot cast. Click "
      .. "a bar for its settings, hold Shift and scroll the mouse wheel over it for a taller or shorter bar. Click "
      .. "this bar to fold it away.", function(pp)
      local box = (W.ZoomBox or W.Box)(pp, 170)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      -- a made-up fight with its own clock
      local st = { mhStart = 0, ohStart = -.7, tgStart = -.4, rgStart = 0, mhSpeed = 2.6, ohSpeed = 1.8, tgSpeed = 2.0,
                   rgSpeed = 2.9, lastSwing = 0, tgName = "Onyxia", n = 0, preview = true }
      -- (a wand for every class but hunters, as on the real bar)
      local _, cls = UnitClass("player")
      st.wand = cls ~= "HUNTER"
      SO.state = st
      local bars = {}
      local ys = { player = -14, target = -64, ranged = -98, cast = -140 }
      for _, bar in ipairs({ "player", "target", "ranged", "cast" }) do
        local f = ST.NewBar(nil, holder)
        f:SetFrameStrata("FULLSCREEN")
        f.bar = bar
        local hot = CreateFrame("Button", nil, holder)
        hot:SetFrameLevel(f:GetFrameLevel() + 6)
        hot:SetAllPoints(f)
        hot.bar = bar
        hot:RegisterForClicks("LeftButtonUp")
        hot:SetScript("OnClick", function() SO.Open(CARD[this.bar]) end)
        hot:EnableMouseWheel(true)
        hot:SetScript("OnMouseWheel", function()
          if IsShiftKeyDown() then
            local set = C.swing[this.bar]
            set.height = tostring(math.max(4, math.min(40, (tonumber(set.height) or 12) + (arg1 or 0))))
            Up()
            O:Refresh()
          elseif pfUI.plates and pfUI.plates.PassWheel then
            pfUI.plates.PassWheel(this)
          end
        end)
        hot:SetScript("OnEnter", function()
          GameTooltip:SetOwner(this, "ANCHOR_TOP")
          GameTooltip:AddLine(CARD[this.bar])
          GameTooltip:AddLine("Click: its settings", 1, 1, 1)
          GameTooltip:AddLine("Shift + mouse wheel: taller / shorter", 1, 1, 1)
          GameTooltip:Show()
        end)
        hot:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.hot = hot
        bars[bar] = f
      end
      SO.bars = bars

      local function Layout()
        local fit = math.min(1, ((box:GetWidth() or 600) - 40) / 300)
        for bar, f in pairs(bars) do
          local set = C.swing[bar]
          local two = (bar == "player" and set.offhand == "1") or (bar == "ranged" and set.onebar ~= "1" and not st.wand)
          ST.Layout(f, set, two)
          f:SetScale(math.min(1, ((box:GetWidth() or 600) - 40) / math.max(1, tonumber(set.width) or 300)))
          f:ClearAllPoints()
          f:SetPoint("TOP", box, "TOP", 0, ys[bar] / (f:GetScale() or 1))
          f:SetAlpha(set.enabled == "1" and 1 or .3)
        end
        SO.fit = fit
      end
      SO.Layout = Layout
      Layout()

      holder:SetScript("OnUpdate", function()
        local t = GetTime()
        -- the fight: swings, a queued Heroic Strike every third swing, shots
        if t - st.mhStart >= st.mhSpeed then
          st.mhStart, st.lastSwing = t, t
          st.n = st.n + 1
        end
        st.queued = (math.mod(st.n, 3) == 2 and t - st.mhStart > st.mhSpeed * .4) and "queue" or nil
        if t - st.ohStart >= st.ohSpeed then st.ohStart = t end
        if t - st.tgStart >= st.tgSpeed then st.tgStart = t end
        if t - st.rgStart >= st.rgSpeed then st.rgStart = t end
        -- an Aimed Shot, a pause, a Multi-Shot, a pause
        if not st.cast or t > st.cast.start + st.cast.dur + 1 then
          local aimed = not st.cast or st.cast.name ~= "Aimed Shot"
          st.cast = { name = aimed and "Aimed Shot" or "Multi-Shot", kind = aimed and "aimed" or "multi", start = t,
                      dur = aimed and 3 or .5 }
        end
        for bar, f in pairs(bars) do ST.Paint(f, bar, t, st) end
      end)

      local ar, ag, ab = .2, .55, .9
      if GetAccentColor then ar, ag, ab = GetAccentColor() end
      local band = W.Row(pp, 20, 0, 3)
      local bg = band:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(band)
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      bg:SetVertexColor(ar, ag, ab, .22)
      local how = band:CreateFontString(nil, "OVERLAY")
      how:SetFont(W.UIFont(), 11, "OUTLINE")
      how:SetPoint("LEFT", band, "LEFT", 12, 0)
      local k = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
      how:SetText(k .. "Click|r a bar  its settings     " .. k .. "Shift + wheel|r  taller / shorter     " .. k .. "Move frames|r  move the bars")
      W.HowTo(pp, band, how:GetText(), nil, 0)
      W.Buttons(pp, {
        { "Test on my bars (20 s)", function()
          if ST.testUntil and GetTime() < ST.testUntil then ST.testUntil = 0 else ST.Test(20) end
        end, nil, "Your real bars run a made-up fight for 20 seconds, so you can place them. Click again to stop.",
          on = function() return ST.testUntil and GetTime() < ST.testUntil end },
        { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, nil, "Drag the bars where you want them." },
      })
    end)
  end

  -- ---------------------------------------------------------------- page

  -- the cards every bar has
  local function Common(p, bar)
    local g = G(bar)
    Chk(p, "Show it", nil, g, "enabled")
    Sld(p, "Width", nil, 50, 600, 1, g, "width", Px)
    Sld(p, "Height", "Or Shift + wheel over it in the preview.", 4, 40, 1, g, "height", Px)
    Sld(p, "Text size", nil, 6, 24, 1, g, "fontsize", Px)
    Sld(p, "Opacity in combat", nil, 0, 1, .05, g, "alpha", Pct)
    Sld(p, "Opacity out of combat", nil, 0, 1, .05, g, "oocalpha", Pct)
    Chk(p, "Fade when idle", "Goes to its out-of-combat opacity a moment after the last swing.", g, "fadeidle")
  end

  local function Build(p)
    W.Heading(p, "Swing Timer", { on = O.ModuleSwitch("swing", "Swing Timer"), about = "Bars counting down to your next swing, your target's next swing and your next Auto "
      .. "Shot or wand shot - WeaponSwingTimer's bars, built in. Swings come from SuperWoW when it runs (the exact hand), "
      .. "else from the combat log." })
    Preview(p)
    -- (31 Oct 2026, user: menus "overwhelming"; Look shows under every tab)
    O.CardTabs(p, {
      { "melee", "Melee", "INV_Sword_04", { "Your swing", "Queued attacks", "Target's swing" } },
      { "ranged", "Ranged", "INV_Weapon_Bow_02", { "Auto Shot and wand", "Aimed and Multi-Shot" } },
      { "class", "Class marks", "Ability_Warrior_DecisiveStrike", { "Warrior: Slam", "Paladin: seal twisting" } },
    })

    W.Card(p, "Look", { tip = "The same looks for every bar." })
    if ST.STYLES then
      local styles = {}
      for _, s in ipairs(ST.STYLES) do
        local tex = s.bar
        for _, b in ipairs(ST.BARS) do if b.key == s.bar then tex = b.tex end end
        table.insert(styles, { key = s.key, label = s.label, texture = tex })
      end
      W.Dropdown(p, "Style", "A whole look in one pick: bar, border, spark and how dark the empty part is. "
        .. "The settings under it change one piece at a time.", styles,
        function() return ST.CurrentStyle() end, function(v) ST.ApplyStyle(v) Up() end)
    end
    Drop(p, "Bar", "Classic, Plain, Minimalist, Cooldown Manager, or any pfUI bar texture.", BarList(), function() return C.swing.look end, "bar")
    Drop(p, "Border", nil, ST.BORDERS, function() return C.swing.look end, "border")
    Chk(p, "Spark", "A bright line where the bar ends.", function() return C.swing.look end, "spark")
    Sld(p, "Back opacity", "The empty part of the bar.", 0, 1, .05, function() return C.swing.look end, "backalpha", Pct)

    W.Card(p, "Your swing", { tip = "Main hand on top; the off hand under it when you dual wield." })
    Common(p, "player")
    Chk(p, "Off hand bar", nil, G("player"), "offhand")
    Chk(p, "Both in one bar", "The off hand as a thin bar inside the main hand's.", G("player"), "combined")
    Chk(p, "Bar fills up", "Off: the bar empties as the swing comes.", G("player"), "fill")
    Chk(p, "Left text", "Main hand / Off hand.", G("player"), "lefttext")
    Chk(p, "Time left", nil, G("player"), "righttext")
    Color(p, "Main hand", nil, G("player"), "maincolor")
    Color(p, "Off hand", nil, G("player"), "offcolor")
    Color(p, "Text", nil, G("player"), "textcolor")

    W.Card(p, "Queued attacks", { tip = "The main hand bar changes colour while an attack waits on your next swing." })
    Color(p, "Heroic Strike / Raptor Strike", nil, G("warrior"), "queuecolor")
    Color(p, "Cleave", nil, G("warrior"), "cleavecolor")
    Color(p, "Maul", nil, G("warrior"), "maulcolor")

    W.Card(p, "Target's swing", { tip = "Your target's swing at you; shows while you fight it." })
    Common(p, "target")
    Chk(p, "Bar fills up", nil, G("target"), "fill")
    Chk(p, "Name", nil, G("target"), "lefttext")
    Chk(p, "Time left", nil, G("target"), "righttext")
    Color(p, "Bar", nil, G("target"), "maincolor")
    Color(p, "Text", nil, G("target"), "textcolor")

    W.Card(p, "Auto Shot and wand", { tip = "A wand: one bar, full when the next shot is ready. Auto Shot (hunters): the reload, then the half-second aim (moving restarts it)." })
    Common(p, "ranged")
    Chk(p, "One bar", "Auto Shot: reload and aim in one bar (its colour changes for the aim). A wand is always one bar.", G("ranged"), "onebar")
    Chk(p, "Texts", nil, G("ranged"), "text")
    Color(p, "Reload / wand", nil, G("ranged"), "cooldowncolor")
    Color(p, "Aim", nil, G("ranged"), "castcolor")
    Chk(p, "Multi-Shot clip zone", "A red zone on the reload: a Multi-Shot started in it pushes your next Auto Shot back.", G("cast"), "clip")
    Color(p, "Clip zone", nil, G("cast"), "clipcolor")

    W.Card(p, "Aimed and Multi-Shot", { tip = "A cast bar for your Aimed Shot and Multi-Shot." })
    Common(p, "cast")
    Chk(p, "Aimed Shot", nil, G("cast"), "aimed")
    Chk(p, "Multi-Shot", nil, G("cast"), "multi")
    Chk(p, "Texts", "The shot's name and the time left.", G("cast"), "text")
    Chk(p, "Latency", "A red part at the cast's end as long as your latency: you can move once the bar reaches it.", G("cast"), "latency")
    Color(p, "Bar", nil, G("cast"), "castcolor")
    Color(p, "Latency part", nil, G("cast"), "latencycolor")

    W.Card(p, "Warrior: Slam", { tip = "Marks on your main hand bar for Slam (warriors who know it)." })
    Chk(p, "Show Slam marks", nil, G("warrior"), "slam")
    Sld(p, "Slam window", "How much of the swing's end is marked: Slam started in it delays your next swing the least.", 0, .5, .01, G("warrior"), "slamdelay",
      function(v) return string.format("%.2f s", v) end)
    Color(p, "Slam window", nil, G("warrior"), "slamcolor")
    Chk(p, "GCD mark", "A spark 1.5 s before the swing: an attack after it still leaves the global cooldown done in time for Slam.", G("warrior"), "slamgcd")
    Color(p, "GCD mark", nil, G("warrior"), "gcdcolor")
    Chk(p, "With one-handers too", "Off: only with a two-hander.", G("warrior"), "slamonehand")

    W.Card(p, "Paladin: seal twisting", { tip = "Lines on your main hand bar for seal twisting (paladins)." })
    Chk(p, "Twist line", "0.4 s before the swing: change seal after it and both seals hit.", G("paladin"), "twist")
    Chk(p, "GCD line", "1.5 s before the swing: the last moment to start a 1.5 s global cooldown that ends in time.", G("paladin"), "gcd")
    Color(p, "Twist line", nil, G("paladin"), "twistcolor")
    Color(p, "GCD line", nil, G("paladin"), "gcdcolor")
    Sld(p, "Line height", "How far the lines stand out above and below the bar.", 0, 20, 1, G("paladin"), "offset", Px)
    O.TabFilter(p)
  end

  O:AddPage("Swing Timer", "stbars", "Bars", Build)
end)
