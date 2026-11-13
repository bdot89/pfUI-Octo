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

  -- ---------------------------------------------------------------- clock and ping

  local clock = CreateFrame("Button", "pfMinimapClock", map)
  clock:SetHeight(C.global.font_size + 4)
  clock:SetWidth(60)
  clock:SetFrameLevel(Minimap:GetFrameLevel() + 4)
  clock.text = clock:CreateFontString(nil, "OVERLAY", "GameFontWhite")
  clock.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  clock.text:SetAllPoints()
  clock:SetScript("OnUpdate", function()
    if (this.tick or 0) > GetTime() then return end
    this.tick = GetTime() + 1
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
    if tonumber(S[p.key .. "x"] or "") and S[p.key .. "pt"] and S[p.key .. "pt"] ~= "" then return S[p.key .. "pt"] end
    return p.point()
  end

  function map.PartOffset(p)
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

  function map.PartScale(p) return (tonumber(S[p.key .. "scale"]) or 100) / 100 end

  local function PlacePart(p)
    local f = p.get()
    if not f then return end
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
    if not p then return end
    S[key .. "pt"] = map.PartPoint(p)
    S[key .. "x"], S[key .. "y"] = tostring(math.floor(x + .5)), tostring(math.floor(y + .5))
    PlacePart(p)
  end
  function map.SizePart(key, pct)
    local p = map.Part(key)
    if not p then return end
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
    end
  end

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
    if S.border == "outline" then
      outline.tex:SetTexture(pfUI.media["img:minimap\\outline-" .. shape])
      local r, g, b, a = Color(S.outlinecolor)
      if S.outlineaccent == "1" then r, g, b = GetAccentColor() end
      outline.tex:SetVertexColor(r, g, b, a)
      outline:Show()
    else
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

    -- every part in its place (clock and ping lines too)
    HookButtons()
    map.PlaceParts()

    ApplyElements()
    map:SetAlpha(UnitAffectingCombat("player") and (tonumber(S.combatalpha) or 1) or (tonumber(S.alpha) or 1))
  end

  -- spin the art
  above:SetScript("OnUpdate", function()
    for i = 1, 3 do
      local l = layers[i]
      if l.speed and l.speed ~= 0 and l.tex then
        l.angle = math.mod(l.angle + l.speed * arg1, 360)
        Turn(l.tex, rad(l.angle))
      end
    end
  end)

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
    { "pfui", T["pfUI square"], { shape = "square", border = "pfui", art1 = "none", art2 = "none", art3 = "none" } },
    { "clean", T["Clean round"], { shape = "round", border = "outline", outlinecolor = "0,0,0,1", outlineaccent = "0",
        art1 = "Spells\\GENERICGLOW64", art1size = "125", art1color = "0,0,0,0.8", art1blend = "BLEND", art1speed = "0", art1above = "0",
        art2 = "none", art3 = "none" } },
    { "accent", T["Accent round"], { shape = "round", border = "outline", outlineaccent = "1", outlinecolor = "1,1,1,1",
        art1 = "none", art2 = "none", art3 = "none" } },
    { "rounded", T["Rounded square"], { shape = "rounded", border = "outline", outlinecolor = "0,0,0,1", outlineaccent = "0",
        art1 = "none", art2 = "none", art3 = "none" } },
    { "runes", T["Rune circle"], { shape = "round", border = "outline", outlinecolor = "0.85,0.65,0.2,1", outlineaccent = "0",
        art1 = "Spells\\AuraRune256", art1size = "140", art1color = "1,0.82,0.3,0.9", art1blend = "ADD", art1speed = "6", art1above = "1",
        art2 = "none", art3 = "none" } },
    { "arcane", T["Arcane"], { shape = "round", border = "outline", outlinecolor = "0.4,0.6,1,1", outlineaccent = "0",
        art1 = "Spells\\AuraRune_A", art1size = "145", art1color = "0.4,0.6,1,0.9", art1blend = "ADD", art1speed = "-8", art1above = "1",
        art2 = "Spells\\Blue_GlowB", art2size = "135", art2color = "0.3,0.5,1,0.7", art2blend = "ADD", art2speed = "0", art2above = "0",
        art3 = "none" } },
    { "holy", T["Holy"], { shape = "round", border = "outline", outlinecolor = "1,0.9,0.5,1", outlineaccent = "0",
        art1 = "Spells\\Holy_Rune_128", art1size = "145", art1color = "1,0.9,0.5,0.9", art1blend = "ADD", art1speed = "5", art1above = "1",
        art2 = "Spells\\GENERICGLOW64", art2size = "140", art2color = "1,0.85,0.4,0.6", art2blend = "ADD", art2speed = "0", art2above = "0",
        art3 = "none" } },
    { "fel", T["Fel"], { shape = "round", border = "outline", outlinecolor = "0.3,1,0.2,1", outlineaccent = "0",
        art1 = "Spells\\DemonRune6", art1size = "150", art1color = "0.3,1,0.2,0.9", art1blend = "ADD", art1speed = "-10", art1above = "1",
        art2 = "Spells\\GREEN_GLOW2", art2size = "135", art2color = "0.2,1,0.2,0.6", art2blend = "ADD", art2speed = "0", art2above = "0",
        art3 = "none" } },
    { "frost", T["Frost"], { shape = "round", border = "outline", outlinecolor = "0.6,0.85,1,1", outlineaccent = "0",
        art1 = "Spells\\Ice_Rune_128", art1size = "145", art1color = "0.6,0.85,1,0.9", art1blend = "ADD", art1speed = "4", art1above = "1",
        art2 = "Spells\\WhiteRingThin128", art2size = "118", art2color = "0.7,0.9,1,0.8", art2blend = "ADD", art2speed = "0", art2above = "1",
        art3 = "none" } },
    { "fire", T["Fire"], { shape = "round", border = "outline", outlinecolor = "1,0.45,0.1,1", outlineaccent = "0",
        art1 = "Spells\\Fire_Rune_128", art1size = "145", art1color = "1,0.5,0.15,0.9", art1blend = "ADD", art1speed = "12", art1above = "1",
        art2 = "Spells\\FireRing128", art2size = "125", art2color = "1,0.4,0.1,0.7", art2blend = "ADD", art2speed = "-6", art2above = "0",
        art3 = "none" } },
  }
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
