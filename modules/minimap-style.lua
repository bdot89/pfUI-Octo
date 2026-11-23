pfUI:RegisterModule("minimap-style", "vanilla:tbc", function ()
  -- pfUI Octo map styles: SexyMap's ideas on pfUI's minimap.
  --   shape    square, round (the game's mask), rounded, rounder, squircle,
  --            octagon, diamond and four "one square corner" shapes
  --            (img\minimap\mask-*.tga, tools\MakeMinimapMasks.ps1)
  --   border   pfUI's frame (square only), a thin outline that follows the
  --            shape (img\minimap\outline-*.tga, any colour or the accent), or none
  --   art      up to three layers of the game's spell art (rune circles,
  --            rings, glows) around the map: size, colour, blend, above or
  --            below the map, spinning at their own speed
  --   buttons  tracking, mail, battleground, addon buttons and the clock:
  --            always, only while the mouse is over the map, or never
  --   extras   a clock, who pinged the map, zoom back out after a while,
  --            opacity in and out of combat, one-click presets
  -- Settings: C.mapstyle (strings). Options: Minimap > Map Style.
  if not pfUI.minimap then return end
  local map = pfUI.minimap
  local S = C.mapstyle
  local cos, sin, rad, floor = math.cos, math.sin, math.rad, math.floor

  -- ---------------------------------------------------------------- the guard
  -- (user, 13 Nov 2026: "my minimap keeps dissapearing i have to put it to blizzard frames then back to
  -- make it show again". Nothing in the settings hides it, so: once a second, when the map should be
  -- on screen, whatever is wrong is put right - the game's Minimap out of pfUI's frame or hidden,
  -- pfUI's frame hidden, see-through or flat - and noted (pfUI_cache.maplog, /pfmap) with what it was,
  -- so the cause shows. Whenever pfUI's frame shows again the Minimap is hidden and shown once: on
  -- 1.12 a frame that came out of a hidden parent stays unseen until then.)
  do
    local guard = CreateFrame("Frame", "pfMinimapGuard", UIParent)
    map.guard = guard
    -- you hid it yourself with the game's Toggle Minimap key: left alone until toggled back
    hooksecurefunc("ToggleMinimap", function() guard.toggled = not Minimap:IsShown() or nil end)

    local function Wanted()
      if pfUI.blizz and pfUI.blizz.IsBlizz and pfUI.blizz.IsBlizz("minimap") then return false end
      if map.octoAway or map.octoHidden then return false end
      if pfUI.farmmap and pfUI.farmmap:IsShown() then return false end
      if pfUI.context and (pfUI.context.mapHidden or (C.mapauto and C.mapauto[pfUI.context.zone or "world"] == "1")) then return false end
      if pfUI.unlock and pfUI.unlock:IsShown() then return false end
      if guard.toggled then return false end
      return true
    end
    local function Note(what)
      pfUI_cache.maplog = pfUI_cache.maplog or {}
      local log = pfUI_cache.maplog
      table.insert(log, date("%d %b %H:%M:%S") .. "  " .. what .. "  (" .. tostring(GetRealZoneText and GetRealZoneText() or "?") .. ")")
      while table.getn(log) > 30 do table.remove(log, 1) end
      guard.told = guard.told or {}
      if not guard.told[what] then
        guard.told[what] = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: the minimap was put back (" .. what .. "). /pfmap lists every time.")
      end
    end
    local function Reshow() if Minimap:IsShown() then Minimap:Hide() Minimap:Show() end end
    function map.GuardCheck()
      if not Wanted() then return end
      local fixed
      if not map:IsShown() then map:Show() fixed = "pfUI's map frame was hidden" end
      local alpha = UnitAffectingCombat("player") and (tonumber(C.mapstyle.combatalpha) or 1) or (tonumber(C.mapstyle.alpha) or 1)
      if alpha > .05 and (map:GetAlpha() or 1) < .05 then map:SetAlpha(alpha) fixed = fixed or "pfUI's map frame was see-through" end
      if Minimap:GetParent() ~= map then
        Minimap:SetParent(map)
        Minimap:ClearAllPoints()
        Minimap:SetPoint("CENTER", map, "CENTER", .5, -.5)
        Minimap:SetFrameLevel(1)
        Minimap:Show()
        Reshow()
        fixed = fixed or "the game's Minimap was outside pfUI's frame"
      end
      if not Minimap:IsShown() then Minimap:Show() fixed = fixed or "the game's Minimap was hidden" end
      if (map:GetHeight() or 0) < 20 or (Minimap:GetWidth() or 0) < 20 then
        if map.UpdateConfig then pcall(map.UpdateConfig, map) end
        fixed = fixed or "the map had no size"
      end
      if not fixed and Minimap:IsShown() and not Minimap:IsVisible() then
        -- (something above pfUI's frame is hidden: say what)
        local p, name = map:GetParent(), "?"
        while p do
          if not p:IsShown() then name = (p.GetName and p:GetName()) or "a frame without a name" break end
          p = p.GetParent and p:GetParent()
        end
        if not guard.parentTold then guard.parentTold = true Note("hidden by its parent " .. name .. " - not changed") end
        return
      end
      if fixed then
        if map.ApplyStyle then pcall(map.ApplyStyle) end
        Note(fixed)
      end
    end
    guard:SetScript("OnUpdate", function()
      this.t = (this.t or 0) + arg1
      -- (the Minimap shown again a moment after pfUI's frame came back)
      if this.reshow and GetTime() >= this.reshow then this.reshow = nil Reshow() end
      if this.t < 1 then return end
      this.t = 0
      map.GuardCheck()
    end)
    local onShow = map:GetScript("OnShow")
    map:SetScript("OnShow", function()
      if onShow then onShow() end
      guard.reshow = GetTime() + .1
    end)
    _G.SLASH_PFMAP1 = "/pfmap"
    _G.SlashCmdList.PFMAP = function()
      local log = pfUI_cache.maplog or {}
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r minimap: put back " .. table.getn(log) .. " time(s)" .. (table.getn(log) == 0 and "." or ":"))
      for _, l in ipairs(log) do DEFAULT_CHAT_FRAME:AddMessage("  " .. l) end
      DEFAULT_CHAT_FRAME:AddMessage(string.format("  now: frame shown %s, alpha %.2f, size %dx%d; Minimap shown %s, visible %s, in pfUI's frame %s",
        tostring(map:IsShown() and true or false), map:GetAlpha() or 0, map:GetWidth() or 0, map:GetHeight() or 0,
        tostring(Minimap:IsShown() and true or false), tostring(Minimap:IsVisible() and true or false), tostring(Minimap:GetParent() == map)))
      map.GuardCheck()
    end
  end

  local MASKS = { square = pfUI.media["img:minimap"], round = "Textures\\MinimapMask" }
  local function MaskOf(shape)
    return MASKS[shape] or pfUI.media["img:minimap\\mask-" .. shape]
  end

  -- ---------------------------------------------------------------- outline and art

  local outline = CreateFrame("Frame", "pfMinimapOutline", map)
  outline:SetAllPoints(Minimap)
  outline:SetFrameLevel(Minimap:GetFrameLevel() + 3)
  outline.tex = outline:CreateTexture(nil, "OVERLAY")
  outline.tex:SetAllPoints()
  -- (17 Nov 2026, user: "find more profesional skins"; EllesmereUI's "Solid" border with a size and a
  -- black / class / custom colour as the idea) a crisp line round the square map, drawn outside it
  outline.edge = {}
  for i = 1, 4 do
    outline.edge[i] = outline:CreateTexture(nil, "OVERLAY")
    outline.edge[i]:SetTexture("Interface\\Buttons\\WHITE8X8")
  end
  function map.BorderColor()
    local mode = S.bordercolor or "black"
    if S.outlineaccent == "1" and mode == "black" then mode = "accent" end
    if mode == "class" then
      local _, class = UnitClass("player")
      local c = class and RAID_CLASS_COLORS[class]
      if c then return c.r, c.g, c.b, 1 end
    elseif mode == "accent" then
      local r, g, b = GetAccentColor()
      return r, g, b, 1
    elseif mode == "custom" then
      local r, g, b, a = GetStringColor(S.outlinecolor or "0,0,0,1")
      return tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or 1
    end
    return 0, 0, 0, 1
  end
  local function SolidEdges(show)
    local e = outline.edge
    if not show then for i = 1, 4 do e[i]:Hide() end return end
    local px = math.max(1, tonumber(S.bordersize) or 1)
    local r, g, b, a = map.BorderColor()
    e[1]:ClearAllPoints() e[1]:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", -px, 0) e[1]:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", px, 0) e[1]:SetHeight(px)
    e[2]:ClearAllPoints() e[2]:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", -px, 0) e[2]:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", px, 0) e[2]:SetHeight(px)
    e[3]:ClearAllPoints() e[3]:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", 0, 0) e[3]:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMLEFT", 0, 0) e[3]:SetWidth(px)
    e[4]:ClearAllPoints() e[4]:SetPoint("TOPLEFT", Minimap, "TOPRIGHT", 0, 0) e[4]:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMRIGHT", 0, 0) e[4]:SetWidth(px)
    for i = 1, 4 do e[i]:SetVertexColor(r, g, b, a) e[i]:Show() end
  end

  local above = CreateFrame("Frame", "pfMinimapArtAbove", map)
  above:SetAllPoints(Minimap)
  above:SetFrameLevel(Minimap:GetFrameLevel() + 2)
  -- under the map (level 0, the map is 1): fades and hides with the minimap
  local below = CreateFrame("Frame", "pfMinimapArtBelow", map)
  below:SetAllPoints(Minimap)
  below:SetFrameLevel(0)

  local layers = {}
  for i = 1, 3 do
    layers[i] = { up = above:CreateTexture(nil, "ARTWORK"), down = below:CreateTexture(nil, "BACKGROUND"), angle = 0 }
  end

  -- a square texture turned by angle (8-value SetTexCoord around the middle)
  local function Turn(tex, angle)
    local c, s = cos(angle), sin(angle)
    local function P(x, y) return .5 + (x - .5) * c - (y - .5) * s, .5 + (x - .5) * s + (y - .5) * c end
    local ulx, uly = P(0, 0)
    local llx, lly = P(0, 1)
    local urx, ury = P(1, 0)
    local lrx, lry = P(1, 1)
    tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
  end

  local function Color(str)
    local r, g, b, a = GetStringColor(str or "1,1,1,1")
    return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
  end

  -- ---------------------------------------------------------------- glow

  -- (23 Nov 2026, Javelin: a gentle glow made from the spell art sat further from the round map at the top
  -- right than at the bottom left - the game's glow pictures are not centred in their files. The user: "more
  -- glows and options ... clean and pixel perfect ... colour changing ... animation".) Our own glows,
  -- img\minimap\glow\<style>-<shape>.tga, made by tools\MakeMinimapGlows.ps1 from the very shape that masks
  -- the map: each pixel's true distance to the shape's edge, so the glow is even all the way round. A glow
  -- picture spans F map half-widths each way: drawn at the map's size * F, centred on the map, its edge
  -- lands on the map's edge. F MUST match the generator's numbers.
  -- { key, name, F, tip }
  map.GLOWS = {
    { "soft",   "Soft",        1.24, "A gentle glow hugging the edge." },
    { "tight",  "Tight",       1.13, "A short, close glow." },
    { "wide",   "Wide",        1.45, "A big soft glow far out from the edge." },
    { "neon",   "Neon line",   1.20, "A bright line right on the edge with a soft glow round it." },
    { "halo",   "Halo ring",   1.32, "A glowing ring with a dark gap between it and the map." },
    { "double", "Double ring", 1.12, "Two thin lines round the map." },
    { "inner",  "Inner glow",  1.04, "Glow inside the map, along its edge (always over the map)." },
  }
  map.GLOWSWEEP = { tex = "img:minimap\\glow\\sweep-round", F = 1.24 }
  local GLOWSHAPES = { square = true, round = true, rounded = true, rounder = true, squircle = true, octagon = true,
    diamond = true, ["corner-tl"] = true, ["corner-tr"] = true, ["corner-bl"] = true, ["corner-br"] = true }
  function map.GlowSpec(key)
    for _, g in ipairs(map.GLOWS) do if g[1] == key then return g end end
  end
  function map.GlowTex(style, shape)
    if not GLOWSHAPES[shape or ""] then shape = "square" end
    return pfUI.media["img:minimap\\glow\\" .. style .. "-" .. shape]
  end
  -- over the map or under it (under: only the part outside the map shows)
  function map.GlowAbove(s)
    return s.glow == "inner" or s.glowabove == "1"
  end
  -- seconds a cycle, never 0
  local function Period(s) return math.max(.3, tonumber(s.glowspeed) or 3) end
  local TAU = 2 * math.pi
  -- hue 0..1 -> r, g, b at full strength
  local function Hue(h)
    h = math.mod(h, 1) * 6
    local i = floor(h)
    local f = h - i
    if i == 0 then return 1, f, 0 elseif i == 1 then return 1 - f, 1, 0 elseif i == 2 then return 0, 1, f
    elseif i == 3 then return 0, 1 - f, 1 elseif i == 4 then return f, 0, 1 end
    return 1, 0, 1 - f
  end
  map.GlowHue = Hue
  -- does the glow show at all now (in / out of combat)
  function map.GlowWanted(s, combat)
    if not map.GlowSpec(s.glow) then return false end
    if s.glowwhen == "combat" then return combat and true or false end
    if s.glowwhen == "ooc" then return not combat end
    return true
  end
  -- its colour and strength at time `now`: colour mode, combat colour, animation, a ping flash
  function map.GlowColor(s, now, combat, flash)
    local r, g, b, a = Color(s.glowcolor)
    local per = Period(s)
    local mode = s.glowcolormode or "custom"
    if combat and s.glowcombat == "1" then
      r, g, b = Color(s.glowcombatcolor)
    elseif mode == "class" then
      local _, class = UnitClass("player")
      local c = class and RAID_CLASS_COLORS[class]
      if c then r, g, b = c.r, c.g, c.b end
    elseif mode == "accent" and GetAccentColor then
      r, g, b = GetAccentColor()
    elseif mode == "shift" then
      local r2, g2, b2 = Color(s.glowcolor2)
      local k = .5 - .5 * cos(now * TAU / per)
      r, g, b = r + (r2 - r) * k, g + (g2 - g) * k, b + (b2 - b) * k
    elseif mode == "rainbow" then
      r, g, b = Hue(now / (per * 4))
    end
    -- brightness from the animation, between glowmin % and full
    local lo = math.min(1, math.max(0, (tonumber(s.glowmin) or 35) / 100))
    local anim, m = s.glowanim or "none", 1
    local ph = math.mod(now / per, 1)
    if anim == "pulse" then
      m = lo + (1 - lo) * (.5 + .5 * sin(ph * TAU))
    elseif anim == "breathe" then
      -- slow in, slow out, a little longer bright than dim
      m = lo + (1 - lo) * math.pow(.5 - .5 * cos(ph * TAU), .7)
    elseif anim == "heartbeat" then
      local function Beat(c) local x = (ph - c) / .045 return math.exp(-x * x) end
      m = lo + (1 - lo) * math.max(Beat(.1), .65 * Beat(.3))
    elseif anim == "flicker" then
      -- three slow waves out of step: a living flame, never a strobe
      local w = .5 * sin(now * 7.1) + .3 * sin(now * 3.3 + 1.3) + .2 * sin(now * 13.7 + .4)
      m = lo + (1 - lo) * (.5 + .5 * w)
    end
    if flash and flash > 0 then
      m = math.max(m, flash)
      r, g, b = r + (1 - r) * flash * .6, g + (1 - g) * flash * .6, b + (1 - b) * flash * .6
    end
    return r, g, b, a * m
  end
  -- size and texture of a glow on `anchor` (a map `size` px wide): t = the glow, sw = the sweep's arc
  function map.GlowLayout(t, sw, anchor, size, s)
    local g = map.GlowSpec(s.glow)
    t:Hide()
    if sw then sw:Hide() end
    if not g then return false end
    local shape = s.shape or "square"
    t:SetTexture(map.GlowTex(g[1], shape))
    t:ClearAllPoints()
    t:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    t:SetWidth(size * g[3])
    t:SetHeight(size * g[3])
    t:SetBlendMode(s.glowblend == "BLEND" and "BLEND" or "ADD")
    t:Show()
    -- the sweep: a bright arc running round the round map, on top of the glow
    if sw and s.glowanim == "sweep" and shape == "round" then
      sw:SetTexture(pfUI.media[map.GLOWSWEEP.tex])
      sw:ClearAllPoints()
      sw:SetPoint("CENTER", anchor, "CENTER", 0, 0)
      sw:SetWidth(size * map.GLOWSWEEP.F)
      sw:SetHeight(size * map.GLOWSWEEP.F)
      sw:SetBlendMode("ADD")
      sw:Show()
    end
    return true
  end
  -- colour (and the sweep's turn) at `now`
  function map.GlowPaint(t, sw, s, now, combat, flash)
    local r, g, b, a = map.GlowColor(s, now, combat, flash)
    if not map.GlowWanted(s, combat) then a = 0 end
    t:SetVertexColor(r, g, b, a)
    if sw and sw:IsShown() then
      -- (with Sweep the glow keeps full strength: the running arc is the animation)
      sw:SetVertexColor(r, g, b, a)
      -- one turn a cycle, clockwise
      local ang = -math.mod(now / Period(s), 1) * TAU
      local c, n = cos(ang), sin(ang)
      local function P(x, y) return .5 + (x - .5) * c - (y - .5) * n, .5 + (x - .5) * n + (y - .5) * c end
      local ulx, uly = P(0, 0)
      local llx, lly = P(0, 1)
      local urx, ury = P(1, 0)
      local lrx, lry = P(1, 1)
      sw:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
    end
  end
  -- does the glow change by itself over time (so it needs a ticker)
  function map.GlowMoves(s)
    if not map.GlowSpec(s.glow) then return false end
    local anim = s.glowanim or "none"
    if anim ~= "none" then return true end
    local mode = s.glowcolormode or "custom"
    return mode == "shift" or mode == "rainbow"
  end

  -- the real map's glow: under the map (only round its edge) or over it, and the sweep's arc above both
  local glow = {
    down = below:CreateTexture(nil, "BORDER"), up = above:CreateTexture(nil, "BORDER"),
    sweep = above:CreateTexture(nil, "OVERLAY"), flashUntil = 0,
  }
  map.glow = glow
  local function InCombat() return UnitAffectingCombat("player") and true or false end
  function map.GlowTick()
    local now = GetTime()
    local flash = glow.flashUntil > now and (glow.flashUntil - now) / 1.2 or 0
    if glow.tex then map.GlowPaint(glow.tex, glow.sweep, S, now, InCombat(), flash) end
  end
  -- 30 times a second, only while the glow changes by itself or a ping flash fades
  glow.ticker = CreateFrame("Frame", nil, map)
  local function Ticker()
    this.t = (this.t or 0) + (arg1 or 0)
    if this.t < .033 then return end
    this.t = 0
    map.GlowTick()
    if not glow.moves and glow.flashUntil <= GetTime() then this:SetScript("OnUpdate", nil) end
  end
  function map.GlowCheck()
    glow.moves = glow.tex and map.GlowMoves(S) or false
    glow.ticker:SetScript("OnUpdate", (glow.moves or glow.flashUntil > GetTime()) and Ticker or nil)
  end
  function map.ApplyGlow()
    glow.down:Hide()
    glow.up:Hide()
    glow.tex = nil
    local t = map.GlowAbove(S) and glow.up or glow.down
    if map.GlowLayout(t, glow.sweep, Minimap, Minimap:GetWidth(), S) then glow.tex = t end
    map.GlowTick()
    map.GlowCheck()
  end
  -- someone pinged the map: the glow flashes bright and fades in 1.2 s
  glow.ticker:RegisterEvent("MINIMAP_PING")
  glow.ticker:RegisterEvent("PLAYER_REGEN_DISABLED")
  glow.ticker:RegisterEvent("PLAYER_REGEN_ENABLED")
  glow.ticker:SetScript("OnEvent", function()
    if event == "MINIMAP_PING" then
      if S.glowping ~= "1" or not glow.tex then return end
      glow.flashUntil = GetTime() + 1.2
      map.GlowCheck()
    else
      -- (into / out of combat: its combat colour, or shown only in / out of combat)
      map.GlowTick()
    end
  end)

  -- ---------------------------------------------------------------- clock and ping

  local clock = CreateFrame("Button", "pfMinimapClock", map)
  clock:SetHeight(C.global.font_size + 4)
  clock:SetWidth(60)
  clock:SetFrameLevel(Minimap:GetFrameLevel() + 4)
  clock.text = clock:CreateFontString(nil, "OVERLAY", "GameFontWhite")
  clock.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  clock.text:SetAllPoints()
  libclient.Every(clock, 1, function()
    local h, m
    if S.clocktime ~= "server" then
      h, m = tonumber(date("%H")), tonumber(date("%M"))
    end
    if not h or not m then h, m = GetGameTime() end
    h, m = tonumber(h) or 0, tonumber(m) or 0
    if C.global.twentyfour == "1" then
      this.text:SetText(string.format("%02d:%02d", h, m))
    else
      local pm = h >= 12 and " pm" or " am"
      h = math.mod(h, 12)
      if h == 0 then h = 12 end
      this.text:SetText(string.format("%d:%02d", h, m) .. pm)
    end
  end)
  clock:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
    local h, m = GetGameTime()
    GameTooltip:AddDoubleLine(T["Server time"], string.format("%02d:%02d", h, m), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T["Local time"], date("%H:%M"), 1, 1, 1, 1, 1, 1)
    GameTooltip:Show()
  end)
  clock:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local ping = CreateFrame("Frame", "pfMinimapPing", map)
  ping:SetHeight(C.global.font_size + 4)
  ping:SetFrameLevel(Minimap:GetFrameLevel() + 4)
  ping.text = ping:CreateFontString(nil, "OVERLAY", "GameFontWhite")
  ping.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  ping.text:SetAllPoints()
  ping:Hide()
  ping:RegisterEvent("MINIMAP_PING")
  ping:SetScript("OnEvent", function()
    if S.ping ~= "1" or not arg1 then return end
    local name = UnitName(arg1)
    if not name then return end
    local _, class = UnitClass(arg1)
    local color = class and RAID_CLASS_COLORS[class]
    this.text:SetText(color and rgbhex(color) .. name .. "|r" or name)
    this.until_ = GetTime() + 3
    this:SetAlpha(1)
    this:Show()
  end)
  ping:SetScript("OnUpdate", function()
    local left = (this.until_ or 0) - GetTime()
    if left <= 0 then this:Hide() elseif left < 1 then this:SetAlpha(left) end
  end)

  -- ---------------------------------------------------------------- buttons

  -- element key -> its frame (looked up each time: some are made later)
  local ELEMENTS = {
    tracking = function() return pfUITracking end,
    mail = function() return MiniMapMailFrame end,
    battlefield = function() return MiniMapBattlefieldFrame end,
    abutton = function() return pfMinimapButton end,
    clock = function() return clock end,
    -- the side bar: shown always or while the mouse is over the map (S.dockshow)
    dockshow = function() return map.dock and map.DockOn and map.DockOn() and map.dock or nil end,
  }

  local hover = CreateFrame("Frame", nil, map)
  hover.alpha = 0
  hover:SetScript("OnUpdate", function()
    -- settled (not fading): the mouse is looked for 20 times a second
    local now = GetTime()
    if hover.alpha == hover.want and (hover.tick or 0) > now then return end
    hover.tick = now + .05
    -- fade the "on mouse-over" elements in while the mouse is over the map or them
    local over = MouseIsOver(map)
    if not over then
      for key, get in pairs(ELEMENTS) do
        local f = get()
        if f and S[key] == "hover" and f:IsVisible() and MouseIsOver(f) then over = true end
      end
    end
    local want = over and 1 or 0
    hover.want = want
    if hover.alpha ~= want then
      local step = arg1 * 5
      if want > hover.alpha then hover.alpha = math.min(1, hover.alpha + step) else hover.alpha = math.max(0, hover.alpha - step) end
      for key, get in pairs(ELEMENTS) do
        local f = get()
        if f and S[key] == "hover" then f:SetAlpha(hover.alpha) end
      end
    end

    -- zoom back out after a while (SexyMap's auto zoom)
    local secs = tonumber(S.autozoom) or 0
    if secs > 0 then
      local zoom = Minimap:GetZoom()
      if zoom ~= hover.zoom then hover.zoom, hover.zoomAt = zoom, GetTime() end
      if zoom > 0 and GetTime() - (hover.zoomAt or 0) > secs then
        Minimap:SetZoom(0)
        hover.zoom = 0
      end
    end
  end)

  local function ApplyElements()
    for key, get in pairs(ELEMENTS) do
      local f = get()
      if f then
        local mode = S[key] or "show"
        if mode == "hide" then
          f:SetAlpha(0)
          if f.EnableMouse then f:EnableMouse(false) end
        else
          f:SetAlpha(mode == "hover" and hover.alpha or 1)
          if f.EnableMouse then f:EnableMouse(true) end
        end
      end
    end
  end

  -- ---------------------------------------------------------------- parts around the map

  -- Every part on or around the map has a place of its own (user, 23 Oct
  -- 2026: "every frame that we have and shape to be able to have stuff
  -- edited around it"): a point of the map, an offset from it and a size.
  -- S[key .. "x"] / ["y"] = "" keeps pfUI's own place (or Move frames');
  -- S[key .. "scale"] in %. Zone, coordinates, clock and ping always follow
  -- these (their defaults are pfUI's places).
  local function CoordPoint()
    local l = C.appearance.minimap.coordsloc
    return (l == "topleft" and "TOPLEFT") or (l == "topright" and "TOPRIGHT") or (l == "bottomright" and "BOTTOMRIGHT") or "BOTTOMLEFT"
  end
  local function ButtonPoint()
    local p = C.abuttons.position
    return (p == "top" and "TOP") or (p == "left" and "LEFT") or (p == "right" and "RIGHT") or "BOTTOM"
  end
  -- default offsets from a point: 3 px in from the map's edge
  local function Inset(pt, n)
    local x = (string.find(pt, "LEFT") and n) or (string.find(pt, "RIGHT") and -n) or 0
    local y = (string.find(pt, "TOP") and -n) or (string.find(pt, "BOTTOM") and n) or 0
    return x, y
  end
  local PARTS = {
    { key = "zone", label = T["Zone name"], get = function() return pfUI.minimapZone end, always = true,
      point = function() return "TOP" end, def = function() return 0, -3 end },
    { key = "coords", label = T["Coordinates"], get = function() return pfUI.minimapCoordinates end, always = true,
      point = CoordPoint, def = function() return Inset(CoordPoint(), 3) end },
    { key = "clock", label = T["Clock"], get = function() return clock end, always = true,
      point = function() return S.clockpos == "top" and "TOP" or "BOTTOM" end,
      def = function() if S.clockpos == "top" then return 0, -3 end return 0, 3 end },
    { key = "ping", label = T["Who pinged"], get = function() return ping end, always = true,
      point = function() return "BOTTOM" end,
      def = function() if S.clockpos == "top" then return 0, 3 end return 0, C.global.font_size + 8 end },
    { key = "tracking", label = T["Tracking"], get = function() return pfUITracking end,
      point = function() return "TOPLEFT" end, def = function() return -10, -10 end },
    { key = "mail", label = T["Mail"], get = function() return MiniMapMailFrame end,
      point = function() return "TOPRIGHT" end, def = function() return 0, 0 end },
    { key = "battlefield", label = T["Battleground"], get = function() return MiniMapBattlefieldFrame end,
      point = function() return "BOTTOMRIGHT" end, def = function() return 4, -4 end },
    { key = "pvp", label = T["PvP icon"], get = function() return pfUI.minimap.pvpicon end,
      point = function() return "BOTTOMRIGHT" end, def = function() return -5, 5 end },
    { key = "abutton", label = T["Addon buttons arrow"], get = function() return pfMinimapButton end,
      point = ButtonPoint, def = function() return Inset(ButtonPoint(), 4) end },
    -- the panel under the map: its top against the map's bottom
    { key = "bar", label = T["Bar under the map"], get = function() return pfUI.panel and pfUI.panel.minimap end,
      point = function() return "TOP" end, rel = "BOTTOM",
      def = function() local _, b = GetBorderSize() return 0, -(tonumber(b) or 1) * 3 end },
  }
  map.PARTS = PARTS
  function map.Part(key)
    for _, p in ipairs(PARTS) do if p.key == key then return p end end
  end

  -- a frame's point in the map's units, from that point of the map
  local function PointXY(f, pt)
    local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
    if not (l and r and t and b) then return end
    local x = (string.find(pt, "LEFT") and l) or (string.find(pt, "RIGHT") and r) or (l + r) / 2
    local y = (string.find(pt, "TOP") and t) or (string.find(pt, "BOTTOM") and b) or (t + b) / 2
    return x, y
  end

  -- where a part is now (x, y from its point of the map), as stored or as it sits
  function map.PartPoint(p)
    if map.Docked and map.Docked(p.key) and map.DockSpot(p.key) then return "CENTER" end
    if tonumber(S[p.key .. "x"] or "") and S[p.key .. "pt"] and S[p.key .. "pt"] ~= "" then return S[p.key .. "pt"] end
    return p.point()
  end

  function map.PartOffset(p)
    if map.Docked and map.Docked(p.key) then
      local dx, dy = map.DockSpot(p.key)
      if dx then return dx, dy end
    end
    local sx, sy = tonumber(S[p.key .. "x"] or ""), tonumber(S[p.key .. "y"] or "")
    if sx and sy then return sx, sy end
    local f = p.get()
    if f and not p.always and f:GetLeft() and Minimap:GetLeft() then
      local pt = p.point()
      local fx, fy = PointXY(f, pt)
      local mx, my = PointXY(Minimap, map.Rel(p, pt))
      local fs, ms = f:GetEffectiveScale() or 1, Minimap:GetEffectiveScale() or 1
      if fx and mx then
        return math.floor((fx * fs - mx * ms) / ms + .5), math.floor((fy * fs - my * ms) / ms + .5)
      end
    end
    return p.def()
  end

  -- the map's point a part hangs from (the bar: its top from the map's bottom)
  function map.Rel(p, pt) return (p.rel and pt == p.point()) and p.rel or pt end

  function map.PartScale(p)
    -- docked: as big as the side bar's buttons
    if map.Docked and map.Docked(p.key) then
      local f = p.get()
      local w = f and f:GetWidth() or 0
      if w > 0 and w <= 64 then return (tonumber(S.docksize) or 22) / w end
    end
    return (tonumber(S[p.key .. "scale"]) or 100) / 100
  end

  local function PlacePart(p)
    local f = p.get()
    if not f then return end
    -- (in the side bar: the bar places it)
    if map.Docked and map.Docked(p.key) then return end
    local sc = map.PartScale(p)
    f:SetScale(sc)
    local sx, sy = tonumber(S[p.key .. "x"] or ""), tonumber(S[p.key .. "y"] or "")
    local pt = p.point()
    if sx and sy then
      -- (the point it was dragged from, kept if pfUI's default changes later)
      if S[p.key .. "pt"] and S[p.key .. "pt"] ~= "" then pt = S[p.key .. "pt"] end
    elseif p.always then
      sx, sy = p.def()
    else
      return
    end
    -- offsets are in the frame's own scale
    local k = (Minimap:GetEffectiveScale() or 1) / (f:GetEffectiveScale() or 1)
    f:ClearAllPoints()
    f:SetPoint(pt, Minimap, map.Rel(p, pt), sx * k, sy * k)
    if p.key == "bar" then f:SetWidth(Minimap:GetWidth()) end
    -- the text lines are as wide as the map; their words line up with the point
    if p.key == "zone" or p.key == "coords" or p.key == "ping" then
      f:SetWidth(Minimap:GetWidth() - 6)
      local fs = f.text
      if fs then
        fs:SetJustifyH((string.find(pt, "LEFT") and "LEFT") or (string.find(pt, "RIGHT") and "RIGHT") or "CENTER")
      end
    end
  end

  -- zone name and coordinates shown: on / mouse over the map / off
  local function ShowTexts()
    local z, c = pfUI.minimapZone, pfUI.minimapCoordinates
    local over = MouseIsOver(Minimap)
    if z then
      local mode = C.appearance.minimap.zonetext
      if mode == "on" or (mode == "mouseover" and over) then
        if not z:IsShown() then
          z:Show()
          local fn = z:GetScript("OnEvent")
          if fn then fn() end
        end
      elseif z:IsShown() then
        z:Hide()
      end
    end
    if c then
      local mode = C.appearance.minimap.coordstext
      if mode == "on" or (mode == "mouseover" and over) then c:Show() elseif c:IsShown() then c:Hide() end
    end
    -- the bar under the map: "none" hides it at once (its words need a reload)
    local bar = pfUI.panel and pfUI.panel.minimap
    if bar then
      if C.panel.other.minimap == "none" then bar:Hide() else bar:Show() end
    end
  end

  function map.PlaceParts()
    for _, p in ipairs(PARTS) do PlacePart(p) end
    ShowTexts()
    if pfUI.minimap.pvpicon then
      local fn = pfUI.minimap.pvpicon:GetScript("OnEvent")
      if fn then fn() end
    end
  end

  -- the options' preview moves and sizes parts with these
  function map.MovePart(key, x, y)
    local p = map.Part(key)
    if not p or (map.Docked and map.Docked(key)) then return end
    S[key .. "pt"] = map.PartPoint(p)
    S[key .. "x"], S[key .. "y"] = tostring(math.floor(x + .5)), tostring(math.floor(y + .5))
    PlacePart(p)
  end
  function map.SizePart(key, pct)
    local p = map.Part(key)
    if not p or (map.Docked and map.Docked(key)) then return end
    S[key .. "scale"] = tostring(math.max(50, math.min(250, math.floor(pct + .5))))
    PlacePart(p)
  end
  -- right-click: pfUI's own place and size again
  function map.ResetPart(key)
    local p = map.Part(key)
    if not p then return end
    S[key .. "x"], S[key .. "y"], S[key .. "pt"], S[key .. "scale"] = "", "", "", "100"
    local f = p.get()
    if not f then return end
    f:SetScale(1)
    if p.always then
      PlacePart(p)
    elseif key == "abutton" and pfUI.addonbuttons and pfUI.addonbuttons.ProcessButtons then
      pfUI.addonbuttons:ProcessButtons()
    elseif key == "bar" then
      -- pfUI's own: as wide as the map, right under it
      local _, y = p.def()
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", pfUI.minimap, "BOTTOMLEFT", 0, y)
      f:SetPoint("TOPRIGHT", pfUI.minimap, "BOTTOMRIGHT", 0, y)
    else
      local pt, x, y = p.point(), p.def()
      f:ClearAllPoints()
      f:SetPoint(pt, Minimap, map.Rel(p, pt), x, y)
    end
  end

  -- pfUI's addon buttons put their arrow back on every update: ours after
  local function HookButtons()
    local ab = pfUI.addonbuttons
    if not ab or ab.octoHooked or not ab.ProcessButtons then return end
    ab.octoHooked = true
    local process = ab.ProcessButtons
    ab.ProcessButtons = function(self)
      process(self)
      local p = map.Part("abutton")
      if p then PlacePart(p) end
      if map.LayoutDock then map.LayoutDock() end
    end
  end

  -- ---------------------------------------------------------------- the side bar
  -- (17 Nov 2026, user with another client's map: "how clean it looks with the buttons on the side this
  -- should be an option in ours"; EllesmereUI's button row as the idea, nothing copied.) The map's
  -- buttons - tracking, mail, battleground queue, the addon buttons arrow, zoom - in one strip along a
  -- side of the map, each the same size, packed with no gaps (mail and the queue only while the game
  -- shows them). C.mapstyle: dock ("0" | left | right | top | bottom), dockbtns (order), docksize,
  -- dockgap (between buttons), dockdist (from the map), dockalign (start | center | end), dockstrip (a strip behind them),
  -- dockshow (show | hover).
  map.DOCKABLE = { "tracking", "mail", "battlefield", "abutton", "zoom" }
  local dock = CreateFrame("Frame", "pfMinimapDock", map)
  map.dock = dock
  dock:SetFrameLevel(Minimap:GetFrameLevel() + 3)
  dock:Hide()
  dock.bg = dock:CreateTexture(nil, "BACKGROUND")
  dock.bg:SetAllPoints(dock)
  dock.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  dock.edge = {}
  for i = 1, 4 do
    dock.edge[i] = dock:CreateTexture(nil, "BORDER")
    dock.edge[i]:SetTexture("Interface\\Buttons\\WHITE8X8")
    dock.edge[i]:SetVertexColor(0, 0, 0, 1)
  end
  dock.edge[1]:SetPoint("TOPLEFT", dock, "TOPLEFT", 0, 0) dock.edge[1]:SetPoint("TOPRIGHT", dock, "TOPRIGHT", 0, 0) dock.edge[1]:SetHeight(1)
  dock.edge[2]:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0) dock.edge[2]:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 0, 0) dock.edge[2]:SetHeight(1)
  dock.edge[3]:SetPoint("TOPLEFT", dock, "TOPLEFT", 0, 0) dock.edge[3]:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0) dock.edge[3]:SetWidth(1)
  dock.edge[4]:SetPoint("TOPRIGHT", dock, "TOPRIGHT", 0, 0) dock.edge[4]:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 0, 0) dock.edge[4]:SetWidth(1)

  -- (17 Nov 2026, user: "it looks aweful" - the game's gold zoom rings, a tiny mail icon in a big frame,
  -- a strip the whole map's height.) Now every button is the same pfUI box: its own frame sized to the
  -- box (never scaled, so borders stay 1 px), the icon filling it inset 3 px, plain +/- glyphs for zoom;
  -- the strip behind them (off by default) is only as long as the buttons.
  local function Glyph(b, plus)
    b.glyphH = b:CreateTexture(nil, "ARTWORK")
    b.glyphH:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.glyphH:SetPoint("CENTER", b, "CENTER", 0, 0)
    if plus then
      b.glyphV = b:CreateTexture(nil, "ARTWORK")
      b.glyphV:SetTexture("Interface\\Buttons\\WHITE8X8")
      b.glyphV:SetPoint("CENTER", b, "CENTER", 0, 0)
    end
    function b.PaintGlyph(lit)
      local c = lit and 1 or .8
      local s = math.max(6, math.floor((b:GetWidth() or 22) * .46 + .5))
      b.glyphH:SetWidth(s) b.glyphH:SetHeight(2) b.glyphH:SetVertexColor(c, c, c, 1)
      if b.glyphV then b.glyphV:SetWidth(2) b.glyphV:SetHeight(s) b.glyphV:SetVertexColor(c, c, c, 1) end
    end
  end
  -- zoom buttons of our own (only in the side bar)
  local function ZoomButton(name, delta)
    local b = CreateFrame("Button", name, map)
    b:SetWidth(22)
    b:SetHeight(22)
    CreateBackdrop(b, nil, true)
    Glyph(b, delta > 0)
    b.PaintGlyph(false)
    b:SetScript("OnClick", function()
      local z = Minimap:GetZoom() + delta
      if z >= 0 and z <= Minimap:GetZoomLevels() - 1 then Minimap:SetZoom(z) end
    end)
    b:SetScript("OnEnter", function()
      this.PaintGlyph(true)
      GameTooltip:SetOwner(this, "ANCHOR_LEFT")
      GameTooltip:AddLine(delta > 0 and (ZOOM_IN or "Zoom in") or (ZOOM_OUT or "Zoom out"))
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() this.PaintGlyph(false) GameTooltip:Hide() end)
    b:Hide()
    return b
  end
  map.zoomin = ZoomButton("pfMinimapZoomIn", 1)
  map.zoomout = ZoomButton("pfMinimapZoomOut", -1)

  local DOCKGET = {
    tracking = function() return pfUITracking end,
    mail = function() return MiniMapMailFrame end,
    battlefield = function() return MiniMapBattlefieldFrame end,
    abutton = function() return pfMinimapButton end,
  }
  -- the icon inside a button that has no box of its own (gets one from us: dock.slot[key])
  local ICONOF = {
    mail = function() return MiniMapMailIcon end,
    battlefield = function() return MiniMapBattlefieldIcon end,
  }
  dock.slot = {}
  local function Slot(key)
    if not dock.slot[key] then
      local s = CreateFrame("Frame", nil, dock)
      CreateBackdrop(s, nil, true)
      dock.slot[key] = s
    end
    return dock.slot[key]
  end
  local function DockList()
    local list = {}
    for k in string.gfind(S.dockbtns or "", "[^,]+") do table.insert(list, k) end
    return list
  end
  function map.DockOn() return S.dock and S.dock ~= "0" and S.dock ~= "" end
  function map.Docked(key)
    if not map.DockOn() then return false end
    for _, k in ipairs(DockList()) do if k == key then return true end end
    return false
  end
  -- the frames the bar holds now, in order (a frame the game hides, or set to Never, takes no place)
  function map.DockFrames(all)
    local out = {}
    for _, k in ipairs(DockList()) do
      if k == "zoom" then
        table.insert(out, { key = "zoom", f = map.zoomin, plus = true })
        table.insert(out, { key = "zoom", f = map.zoomout })
      else
        local get = DOCKGET[k]
        local f = get and get()
        if f and S[k] ~= "hide" and (all or f:IsShown()) then table.insert(out, { key = k, f = f }) end
      end
    end
    return out
  end
  -- where the bar and each of its buttons sit, from the centre of the game's Minimap, in its units:
  -- bar = { x, y, w, h }, spots[i] = { x, y } (centres); n buttons. The strip is as long as its buttons
  -- and lines up with the map's top / left end, its middle or its bottom / right end.
  function map.DockRect(n)
    local side = S.dock
    local size = tonumber(S.docksize) or 22
    local gap = tonumber(S.dockgap) or 4
    local dist = tonumber(S.dockdist) or 4
    local pad = S.dockstrip == "1" and 3 or 0
    local w = Minimap:GetWidth() or 140
    local _, border = GetBorderSize()
    border = tonumber(border) or 1
    local half = w / 2 + border
    local thick = size + pad * 2
    -- bottom: under the bar under the map, when it shows
    local extra = 0
    if side == "bottom" and pfUI.panel and pfUI.panel.minimap and pfUI.panel.minimap:IsShown() then
      extra = (pfUI.panel.minimap:GetHeight() or 0) + border * 3
    end
    local run = n * size + math.max(0, n - 1) * gap
    local len = run + pad * 2
    -- the strip's middle along the side (+ = towards the top / right end of the side, from the top-left
    -- for the start): start = flush with the map's top (left) edge
    local mid
    if S.dockalign == "center" then mid = 0
    elseif S.dockalign == "end" then mid = -(half - len / 2)
    else mid = half - len / 2 end
    local bar, spots = {}, {}
    local across = half + dist + thick / 2 + extra
    if side == "left" or side == "right" then
      bar.x, bar.y, bar.w, bar.h = (side == "left" and -across or across), mid, thick, len
      local top = mid + len / 2 - pad
      for i = 1, n do spots[i] = { bar.x, top - size / 2 - (i - 1) * (size + gap) } end
    else
      -- (along the top / bottom, "start" is the left end)
      bar.x, bar.y, bar.w, bar.h = -mid, (side == "top" and across or -across), len, thick
      local left = -mid - len / 2 + pad
      for i = 1, n do spots[i] = { left + size / 2 + (i - 1) * (size + gap), bar.y } end
    end
    return bar, spots, size
  end
  local dockSig
  -- a button's own size and its icon's points, kept the first time it goes in the bar
  local function Keep(key, f)
    if f.octoDockKept then return end
    f.octoDockKept = { w = f:GetWidth(), h = f:GetHeight(), scale = f:GetScale() }
    local icon = ICONOF[key] and ICONOF[key]()
    if icon then
      local pts = {}
      for i = 1, (icon.GetNumPoints and icon:GetNumPoints() or 0) do
        local a, rel, b, x, y = icon:GetPoint(i)
        table.insert(pts, { a, rel, b, x, y })
      end
      f.octoDockKept.icon = { w = icon:GetWidth(), h = icon:GetHeight(), pts = pts }
    end
  end
  -- a button out of the bar: its own parent, size and icon again, and its place (yours, else pfUI's)
  local function Undock(key, f)
    if not f.octoDockParent then return end
    f:SetParent(f.octoDockParent)
    f.octoDockParent = nil
    local k = f.octoDockKept
    if k then
      if k.w and k.w > 0 then f:SetWidth(k.w) end
      if k.h and k.h > 0 then f:SetHeight(k.h) end
      local icon = ICONOF[key] and ICONOF[key]()
      if icon and k.icon then
        icon:ClearAllPoints()
        for _, pt in ipairs(k.icon.pts) do icon:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
        if k.icon.w and k.icon.w > 0 then icon:SetWidth(k.icon.w) end
        if k.icon.h and k.icon.h > 0 then icon:SetHeight(k.icon.h) end
      end
      f.octoDockKept = nil
    end
    f:SetScale(1)
    if dock.slot[key] then dock.slot[key]:Hide() end
    if f:IsShown() then f:Hide() f:Show() end
    local p = map.Part(key)
    if not p then return end
    if tonumber(S[key .. "x"] or "") and tonumber(S[key .. "y"] or "") then
      PlacePart(p)
    elseif key == "abutton" and pfUI.addonbuttons and pfUI.addonbuttons.ProcessButtons then
      pfUI.addonbuttons:ProcessButtons()
    else
      local pt = p.point()
      local x, y = p.def()
      f:ClearAllPoints()
      f:SetPoint(pt, Minimap, map.Rel(p, pt), x, y)
      f:SetScale(map.PartScale(p))
    end
  end
  function map.LayoutDock()
    for key, get in pairs(DOCKGET) do
      local f = get()
      if f and f.octoDockParent and not map.Docked(key) then Undock(key, f) end
    end
    for _, s in pairs(dock.slot) do s:Hide() end
    if not map.DockOn() then
      dock:Hide()
      map.zoomin:Hide()
      map.zoomout:Hide()
      dockSig = nil
      return
    end
    local list = map.DockFrames()
    local bar, spots, size = map.DockRect(table.getn(list))
    local k = (Minimap:GetEffectiveScale() or 1) / (dock:GetEffectiveScale() or 1)
    dock:ClearAllPoints()
    dock:SetPoint("CENTER", Minimap, "CENTER", bar.x * k, bar.y * k)
    dock:SetWidth(math.max(1, bar.w * k))
    dock:SetHeight(math.max(1, bar.h * k))
    if S.dockstrip == "1" and table.getn(list) > 0 then
      local r, g, b, a = GetStringColor(C.appearance.border.background)
      dock.bg:SetVertexColor(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or .8)
      dock.bg:Show()
      for i = 1, 4 do dock.edge[i]:Show() end
    else
      dock.bg:Hide()
      for i = 1, 4 do dock.edge[i]:Hide() end
    end
    dock:Show()
    map.zoomin:Hide()
    map.zoomout:Hide()
    local px = size * k
    local sig = ""
    for i, e in ipairs(list) do
      local f = e.f
      if e.key ~= "zoom" then Keep(e.key, f) end
      if f.GetParent and f:GetParent() ~= dock then
        if not f.octoDockParent then f.octoDockParent = f:GetParent() or map end
        f:SetParent(dock)
        if f:IsShown() then f:Hide() f:Show() end
      end
      if e.key == "zoom" then f:Show() end
      f:SetScale(1)
      f:SetWidth(px)
      f:SetHeight(px)
      f:ClearAllPoints()
      f:SetPoint("CENTER", Minimap, "CENTER", spots[i][1] * k, spots[i][2] * k)
      f:SetFrameLevel(dock:GetFrameLevel() + 3)
      if f.PaintGlyph then f.PaintGlyph(false) end
      -- an icon with no box of its own: one of ours behind it, the icon filling it
      local icon = ICONOF[e.key] and ICONOF[e.key]()
      if icon then
        local s = Slot(e.key)
        s:ClearAllPoints()
        s:SetAllPoints(f)
        s:SetFrameLevel(dock:GetFrameLevel() + 1)
        s:Show()
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
      end
      sig = sig .. e.key .. ","
    end
    dockSig = sig
  end
  -- mail and the battleground queue come and go: the bar closes up behind them
  libclient.Every(dock, .3, function()
    if not map.DockOn() then return end
    local sig = ""
    for _, e in ipairs(map.DockFrames()) do sig = sig .. e.key .. "," end
    if sig ~= dockSig then map.LayoutDock() end
  end)
  -- (the options' preview asks a docked part's place with these)
  function map.DockSpot(key)
    local list = map.DockFrames(true)
    local bar, spots, size = map.DockRect(table.getn(list))
    for i, e in ipairs(list) do
      if e.key == key then return spots[i][1], spots[i][2], size end
    end
  end

  -- (20 Nov 2026, Javelin: pfQuest's pins showed outside a round map - it took pfUI's map to be square)
  -- true when a point x right / y down of the map's middle, with room for a pin of `pad` px, lies inside the
  -- map's shape. The same shapes as tools\MakeMinimapMasks.ps1.
  function map.PinInside(x, y, pad)
    local h = (Minimap:GetWidth() or 140) / 2 - (pad or 8)
    if h <= 0 then return false end
    local u, v = x / h, -y / h
    local au, av = math.abs(u), math.abs(v)
    if au > 1 or av > 1 then return false end
    local shape = S.shape or "square"
    if shape == "round" then return u * u + v * v <= 1
    elseif shape == "squircle" then return au * au * au * au + av * av * av * av <= 1
    elseif shape == "octagon" then return au + av <= 1.4142
    elseif shape == "diamond" then return au + av <= 1
    elseif shape == "rounded" or shape == "rounder" then
      local r = shape == "rounded" and 0.22 or 0.45
      local qx, qy = au - (1 - r), av - (1 - r)
      if qx <= 0 or qy <= 0 then return true end
      return qx * qx + qy * qy <= r * r
    elseif shape == "corner-tl" or shape == "corner-tr" or shape == "corner-bl" or shape == "corner-br" then
      local left, top = u <= 0, v >= 0
      local sq = (shape == "corner-tl" and left and top) or (shape == "corner-tr" and not left and top)
        or (shape == "corner-bl" and left and not top) or (shape == "corner-br" and not left and not top)
      if sq then return true end
      return u * u + v * v <= 1
    end
    return true
  end

  -- (20 Nov 2026, Javelin again, "look at the edges": pins half over the round map's ring) pfQuest's own check only
  -- runs in our built-in copy; with the separate pfQuest add-on (the launcher's) its square test let pins up to the
  -- frame's edge. So pfUI looks at every shown minimap pin itself, ten times a second, where it really is now (its
  -- centre against the map's), with room for the pin's own size and the ring: outside = see-through and no mouse,
  -- back as it was once inside. Works with any pfQuest; does nothing on a square map.
  map.pinsOut = {}
  function map.ClipPins()
    local pfm = rawget(_G, "pfMap")
    local out = map.pinsOut
    local shape = S.shape or "square"
    local cx, cy = Minimap:GetCenter()
    if not (pfm and type(pfm.mpins) == "table" and cx) or shape == "square" then
      for pin, a in pairs(out) do pin:SetAlpha(a) pin:EnableMouse(true) out[pin] = nil end
      return 0
    end
    local ms = Minimap:GetEffectiveScale() or 1
    local n = 0
    for _, pin in pairs(pfm.mpins) do
      if pin:IsShown() then
        local px, py = pin:GetCenter()
        if px then
          local ps = (pin:GetEffectiveScale() or ms) / ms
          local dx, dy = px * ps - cx, py * ps - cy
          local pad = (pin:GetWidth() or 14) * ps / 2 + 3
          if map.PinInside(dx, -dy, pad) then
            if out[pin] then pin:SetAlpha(out[pin]) pin:EnableMouse(true) out[pin] = nil end
          else
            if not out[pin] then out[pin] = pin:GetAlpha() end
            pin:SetAlpha(0)
            pin:EnableMouse(false)
            n = n + 1
          end
        end
      elseif out[pin] then
        pin:SetAlpha(out[pin])
        out[pin] = nil
      end
    end
    return n
  end
  local clip = CreateFrame("Frame")
  clip.t = 0
  clip:SetScript("OnUpdate", function()
    this.t = this.t + arg1
    if this.t < .1 then return end
    this.t = 0
    map.ClipPins()
  end)

  -- ---------------------------------------------------------------- apply

  function map.ApplyStyle()
    local shape = S.shape or "square"
    local size = Minimap:GetWidth()

    -- shape
    Minimap:SetMaskTexture(MaskOf(shape))

    -- border: pfUI's square frame, an outline of the shape, or nothing
    local frame = S.border == "pfui" and shape == "square"
    if map.backdrop then if frame then map.backdrop:Show() else map.backdrop:Hide() end end
    if map.backdrop_shadow then if frame then map.backdrop_shadow:Show() else map.backdrop_shadow:Hide() end end
    -- solid: a crisp line of its own size on the square map, the shape's outline on the others
    local line = S.border == "outline" or S.border == "solid"
    if line then
      if shape == "square" then
        outline.tex:Hide()
        SolidEdges(true)
      else
        SolidEdges(false)
        outline.tex:SetTexture(pfUI.media["img:minimap\\outline-" .. shape])
        outline.tex:SetVertexColor(map.BorderColor())
        outline.tex:Show()
      end
      outline:Show()
    else
      SolidEdges(false)
      outline:Hide()
    end

    -- art layers
    for i = 1, 3 do
      local l = layers[i]
      local tex = S["art" .. i]
      l.up:Hide()
      l.down:Hide()
      l.speed = 0
      if tex and tex ~= "none" then
        local t = S["art" .. i .. "above"] == "1" and l.up or l.down
        local px = size * (tonumber(S["art" .. i .. "size"]) or 130) / 100
        t:SetTexture(tex)
        t:ClearAllPoints()
        t:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
        t:SetWidth(px)
        t:SetHeight(px)
        t:SetVertexColor(Color(S["art" .. i .. "color"]))
        t:SetBlendMode(S["art" .. i .. "blend"] == "BLEND" and "BLEND" or "ADD")
        Turn(t, rad(l.angle))
        t:Show()
        l.tex = t
        l.speed = tonumber(S["art" .. i .. "speed"]) or 0
      end
    end
    -- our own glow (pcall: a missing picture never stops the rest of the look)
    if map.ApplyGlow then pcall(map.ApplyGlow) end

    -- every part in its place (clock and ping lines too)
    HookButtons()
    map.PlaceParts()
    map.LayoutDock()

    ApplyElements()
    map:SetAlpha(UnitAffectingCombat("player") and (tonumber(S.combatalpha) or 1) or (tonumber(S.alpha) or 1))
    if map.SpinCheck then map.SpinCheck() end
  end

  -- spin the art (octo, 22 Nov 2026: the script only while some layer spins - it looped over the three every frame)
  local function Spin()
    for i = 1, 3 do
      local l = layers[i]
      if l.speed and l.speed ~= 0 and l.tex then
        l.angle = math.mod(l.angle + l.speed * arg1, 360)
        Turn(l.tex, rad(l.angle))
      end
    end
  end
  function map.SpinCheck()
    local any
    for i = 1, 3 do
      local l = layers[i]
      if l.speed and l.speed ~= 0 and l.tex then any = true end
    end
    above:SetScript("OnUpdate", any and Spin or nil)
  end
  map.SpinCheck()

  -- opacity in / out of combat, and re-apply after pfUI rebuilds the map
  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_REGEN_DISABLED")
  events:RegisterEvent("PLAYER_REGEN_ENABLED")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:SetScript("OnEvent", function()
    if event == "PLAYER_REGEN_DISABLED" then
      map:SetAlpha(tonumber(S.combatalpha) or 1)
    elseif event == "PLAYER_REGEN_ENABLED" then
      map:SetAlpha(tonumber(S.alpha) or 1)
    else
      map.ApplyStyle()
    end
  end)

  local UpdateConfig = map.UpdateConfig
  map.UpdateConfig = function(self)
    UpdateConfig(self)
    map.ApplyStyle()
  end

  -- ---------------------------------------------------------------- presets

  -- SexyMap-style looks in one click: only the style keys change
  local PRESETS = {
    -- (17 Nov 2026, user: "find more profesional skins and looks for our map clean") plain looks first:
    -- one crisp line, no art; the spell-art looks after them
    { "solid", T["Clean square"], { shape = "square", border = "solid", bordercolor = "black", bordersize = "1", outlineaccent = "0",
        art1 = "none", art2 = "none", art3 = "none" } },
    { "classline", T["Square, class colour"], { shape = "square", border = "solid", bordercolor = "class", bordersize = "1", outlineaccent = "0",
        art1 = "none", art2 = "none", art3 = "none" } },
    { "accentline", T["Square, accent line"], { shape = "square", border = "solid", bordercolor = "accent", bordersize = "2", outlineaccent = "0",
        art1 = "none", art2 = "none", art3 = "none" } },
    { "pfui", T["pfUI square"], { shape = "square", border = "pfui", art1 = "none", art2 = "none", art3 = "none" } },
    { "clean", T["Clean round"], { shape = "round", border = "solid", bordercolor = "black", outlineaccent = "0",
        art1 = "none", art2 = "none", art3 = "none" } },
    { "roundclass", T["Round, class colour"], { shape = "round", border = "solid", bordercolor = "class", outlineaccent = "0",
        art1 = "none", art2 = "none", art3 = "none" } },
    { "accent", T["Accent round"], { shape = "round", border = "outline", outlineaccent = "0", bordercolor = "accent", outlinecolor = "1,1,1,1",
        art1 = "none", art2 = "none", art3 = "none" } },
    { "rounded", T["Rounded square"], { shape = "rounded", border = "outline", outlinecolor = "0,0,0,1", outlineaccent = "0", bordercolor = "custom",
        art1 = "none", art2 = "none", art3 = "none" } },
    { "runes", T["Rune circle"], { shape = "round", border = "outline", outlinecolor = "0.85,0.65,0.2,1", outlineaccent = "0", bordercolor = "custom",
        art1 = "Spells\\AuraRune256", art1size = "140", art1color = "1,0.82,0.3,0.9", art1blend = "ADD", art1speed = "6", art1above = "1",
        art2 = "none", art3 = "none" } },
    { "arcane", T["Arcane"], { shape = "round", border = "outline", outlinecolor = "0.4,0.6,1,1", outlineaccent = "0", bordercolor = "custom",
        art1 = "Spells\\AuraRune_A", art1size = "145", art1color = "0.4,0.6,1,0.9", art1blend = "ADD", art1speed = "-8", art1above = "1",
        art2 = "Spells\\Blue_GlowB", art2size = "135", art2color = "0.3,0.5,1,0.7", art2blend = "ADD", art2speed = "0", art2above = "0",
        art3 = "none" } },
    { "holy", T["Holy"], { shape = "round", border = "outline", outlinecolor = "1,0.9,0.5,1", outlineaccent = "0", bordercolor = "custom",
        art1 = "Spells\\Holy_Rune_128", art1size = "145", art1color = "1,0.9,0.5,0.9", art1blend = "ADD", art1speed = "5", art1above = "1",
        art2 = "Spells\\GENERICGLOW64", art2size = "140", art2color = "1,0.85,0.4,0.6", art2blend = "ADD", art2speed = "0", art2above = "0",
        art3 = "none" } },
    { "fel", T["Fel"], { shape = "round", border = "outline", outlinecolor = "0.3,1,0.2,1", outlineaccent = "0", bordercolor = "custom",
        art1 = "Spells\\DemonRune6", art1size = "150", art1color = "0.3,1,0.2,0.9", art1blend = "ADD", art1speed = "-10", art1above = "1",
        art2 = "Spells\\GREEN_GLOW2", art2size = "135", art2color = "0.2,1,0.2,0.6", art2blend = "ADD", art2speed = "0", art2above = "0",
        art3 = "none" } },
    { "frost", T["Frost"], { shape = "round", border = "outline", outlinecolor = "0.6,0.85,1,1", outlineaccent = "0", bordercolor = "custom",
        art1 = "Spells\\Ice_Rune_128", art1size = "145", art1color = "0.6,0.85,1,0.9", art1blend = "ADD", art1speed = "4", art1above = "1",
        art2 = "Spells\\WhiteRingThin128", art2size = "118", art2color = "0.7,0.9,1,0.8", art2blend = "ADD", art2speed = "0", art2above = "1",
        art3 = "none" } },
    { "fire", T["Fire"], { shape = "round", border = "outline", outlinecolor = "1,0.45,0.1,1", outlineaccent = "0", bordercolor = "custom",
        art1 = "Spells\\Fire_Rune_128", art1size = "145", art1color = "1,0.5,0.15,0.9", art1blend = "ADD", art1speed = "12", art1above = "1",
        art2 = "Spells\\FireRing128", art2size = "125", art2color = "1,0.4,0.1,0.7", art2blend = "ADD", art2speed = "-6", art2above = "0",
        art3 = "none" } },
  }
  -- (23 Nov 2026) looks with our own glow, after the plain ones; every other look switches the glow off
  local NOART = { art1 = "none", art2 = "none", art3 = "none" }
  local function GlowLook(key, name, set)
    for k, v in pairs(NOART) do if set[k] == nil then set[k] = v end end
    set.glowanim = set.glowanim or "none"
    set.glowabove = set.glowabove or "0"
    set.glowblend = set.glowblend or "ADD"
    table.insert(PRESETS, 5, { key, name, set })
  end
  for _, p in ipairs(PRESETS) do if p[3].glow == nil then p[3].glow = "none" end end
  -- (inserted at 5 each, so they read in reverse here: Soft glow first)
  GlowLook("shadow", T["Square, soft shadow"], { shape = "square", border = "solid", bordercolor = "black", bordersize = "1",
    outlineaccent = "0", glow = "wide", glowcolormode = "custom", glowcolor = "0,0,0,0.75", glowblend = "BLEND" })
  GlowLook("rainbow", T["Rainbow neon"], { shape = "round", border = "solid", bordercolor = "black", outlineaccent = "0",
    glow = "neon", glowcolormode = "rainbow", glowcolor = "1,1,1,0.9", glowabove = "1", glowspeed = "3" })
  GlowLook("sweep", T["Running light"], { shape = "round", border = "solid", bordercolor = "black", outlineaccent = "0",
    glow = "soft", glowcolormode = "accent", glowcolor = "1,1,1,0.6", glowanim = "sweep", glowspeed = "4" })
  GlowLook("halo", T["Halo, breathing"], { shape = "round", border = "solid", bordercolor = "black", outlineaccent = "0",
    glow = "halo", glowcolormode = "class", glowcolor = "1,1,1,0.9", glowanim = "breathe", glowspeed = "4", glowmin = "45" })
  GlowLook("neon", T["Neon accent"], { shape = "round", border = "none", outlineaccent = "0",
    glow = "neon", glowcolormode = "accent", glowcolor = "1,1,1,1", glowabove = "1" })
  GlowLook("softglow", T["Soft glow"], { shape = "round", border = "solid", bordercolor = "black", outlineaccent = "0",
    glow = "soft", glowcolormode = "custom", glowcolor = "0.45,1,0.5,0.85" })
  map.PRESETS = PRESETS

  function map.ApplyPreset(key)
    for _, p in ipairs(PRESETS) do
      if p[1] == key then
        for k, v in pairs(p[3]) do S[k] = v end
      end
    end
    map.ApplyStyle()
  end

  map.ApplyStyle()

  -- ---------------------------------------------------------------- options

  if not pfUI.gui or not pfUI.gui.CreateGUIEntry then return end
  local CreateGUIEntry, CreateConfig = pfUI.gui.CreateGUIEntry, pfUI.gui.CreateConfig
  local function U() map.ApplyStyle() end

  local SHAPES = {
    "square:" .. T["Square"], "round:" .. T["Round"], "rounded:" .. T["Rounded square"], "rounder:" .. T["Rounder square"],
    "squircle:" .. T["Squircle"], "octagon:" .. T["Octagon"], "diamond:" .. T["Diamond"],
    "corner-tl:" .. T["Round, square top left"], "corner-tr:" .. T["Round, square top right"],
    "corner-bl:" .. T["Round, square bottom left"], "corner-br:" .. T["Round, square bottom right"],
  }
  local BORDERS = { "pfui:" .. T["pfUI frame (square only)"], "outline:" .. T["Outline of the shape"], "none:" .. T["None"] }
  local ART = {
    "none:" .. T["None"],
    "Spells\\AuraRune256:" .. T["Rune circle"], "Spells\\AuraRune256b:" .. T["Rune circle 2"],
    "Spells\\AuraRune_A:" .. T["Rune circle A"], "Spells\\AuraRune_B:" .. T["Rune circle B"],
    "Spells\\AuraRune_C:" .. T["Rune circle C"], "Spells\\AuraRune_D:" .. T["Rune circle D"],
    "Spells\\Holy_Rune_128:" .. T["Holy rune"], "Spells\\Holy_Rune1:" .. T["Holy rune 2"],
    "Spells\\Ice_Rune_128:" .. T["Frost rune"], "Spells\\Fire_Rune_128:" .. T["Fire rune"],
    "Spells\\Nature_Rune_128:" .. T["Nature rune"], "Spells\\InnerFire_Rune_128:" .. T["Inner Fire rune"],
    "Spells\\DemonRune6:" .. T["Demon rune"], "Spells\\DemonRune7:" .. T["Demon rune 2"],
    "Spells\\Death_Rune:" .. T["Death rune"], "Spells\\starrune:" .. T["Star rune"],
    "Spells\\Circle:" .. T["Circle"], "Spells\\DoubleRing128:" .. T["Double ring"],
    "Spells\\WhiteRingThin128:" .. T["Thin ring"], "Spells\\WhiteRingFat128:" .. T["Fat ring"],
    "Spells\\FireRing128:" .. T["Fire ring"], "Spells\\T_VFX_Ring_Bow_A:" .. T["Bow ring"],
    "Spells\\GENERICGLOW64:" .. T["Soft glow"], "Spells\\Blue_GlowB:" .. T["Blue glow"],
    "Spells\\GREEN_GLOW2:" .. T["Green glow"], "Spells\\Shockwave_Ice1:" .. T["Frost wave"],
    "Spells\\ShockwaveWater1:" .. T["Water wave"], "Spells\\STARBURSTS:" .. T["Starbursts"],
  }
  local MODES = { "show:" .. T["Always"], "hover:" .. T["Mouse over the map"], "hide:" .. T["Never"] }

  CreateGUIEntry(T["Minimap"], T["Map Style"], function()
    local page = this
    CreateConfig(nil, T["Presets"], nil, nil, "header")
    for _, p in ipairs(PRESETS) do
      local key = p[1]
      CreateConfig(nil, p[2], nil, nil, "button", function()
        map.ApplyPreset(key)
        pfUI.gui.RefreshPage(page)
      end)
    end

    CreateConfig(nil, T["Shape And Border"], nil, nil, "header")
    CreateConfig(U, T["Use The Accent Colour For The Outline"], S, "outlineaccent", "checkbox")
    CreateConfig(U, T["Outline Colour"], S, "outlinecolor", "color")
    CreateConfig(U, T["Shape"], S, "shape", "dropdown", SHAPES)
    CreateConfig(U, T["Border"], S, "border", "dropdown", BORDERS)

    for i = 1, 3 do
      CreateConfig(nil, T["Art Layer"] .. " " .. i, nil, nil, "header")
      CreateConfig(U, T["Above The Map"], S, "art" .. i .. "above", "checkbox")
      CreateConfig(U, T["Colour And Opacity"], S, "art" .. i .. "color", "color")
      CreateConfig(U, T["Art"], S, "art" .. i, "dropdown", ART)
      CreateConfig(U, T["Blend"], S, "art" .. i .. "blend", "dropdown", { "ADD:" .. T["Glow (add)"], "BLEND:" .. T["Normal"] })
      CreateConfig(U, T["Size (% of the map)"], S, "art" .. i .. "size", "slider", { 50, 250, 5 })
      CreateConfig(U, T["Spin (degrees a second, minus = other way)"], S, "art" .. i .. "speed", "slider", { -90, 90, 1 })
    end
  end)

  CreateGUIEntry(T["Minimap"], T["Buttons & Extras"], function()
    CreateConfig(nil, T["Buttons"], nil, nil, "header")
    CreateConfig(U, T["Tracking"], S, "tracking", "dropdown", MODES)
    CreateConfig(U, T["Mail"], S, "mail", "dropdown", MODES)
    CreateConfig(U, T["Battleground"], S, "battlefield", "dropdown", MODES)
    CreateConfig(U, T["Addon Buttons Toggle"], S, "abutton", "dropdown", MODES)

    CreateConfig(nil, T["Clock"], nil, nil, "header")
    CreateConfig(U, T["Show The Clock"], S, "clock", "dropdown", MODES)
    CreateConfig(U, T["Time"], S, "clocktime", "dropdown", { "local:" .. T["Local time"], "server:" .. T["Server time"] })
    CreateConfig(U, T["Place"], S, "clockpos", "dropdown", { "bottom:" .. T["Bottom"], "top:" .. T["Top"] })

    CreateConfig(nil, T["Extras"], nil, nil, "header")
    CreateConfig(U, T["Show Who Pinged The Map"], S, "ping", "checkbox")
    CreateConfig(U, T["Zoom Back Out After (s, 0 = never)"], S, "autozoom", "slider", { 0, 60, 1 })
    CreateConfig(U, T["Opacity"], S, "alpha", "slider", { .1, 1, .05 })
    CreateConfig(U, T["Opacity In Combat"], S, "combatalpha", "slider", { .1, 1, .05 })
  end)
end)
