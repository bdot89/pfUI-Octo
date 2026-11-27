pfUI:RegisterModule("map", "vanilla:tbc", function ()
  table.insert(UISpecialFrames, "WorldMapFrame")

  local function UpdateTooltipScale()
    -- load scale data
    local tooltipscale = tonumber(C.appearance.worldmap.tooltipsize)
    local scale = WorldMapFrame:GetScale()

    -- apply tooltip scale
    if tooltipscale > 0 then
      WorldMapTooltip:SetScale(tooltipscale/scale)
    else
      WorldMapTooltip:SetScale(1)
    end
  end

  -- register config update handler
  pfUI.map = { UpdateConfig = UpdateTooltipScale }

  function _G.ToggleWorldMap()
    if WorldMapFrame:IsShown() then
      WorldMapFrame:Hide()
    else
      WorldMapFrame:Show()
    end
  end

  C.position["WorldMapFrame"] = C.position["WorldMapFrame"] or { alpha = 1.0, scale = 0.7 }
  C.position["WorldMapFrame"].parent = nil
  local alpha = C.position["WorldMapFrame"].alpha
  local scale = C.position["WorldMapFrame"].scale

  local pfMapLoader = CreateFrame("Frame")
  pfMapLoader:RegisterEvent("PLAYER_ENTERING_WORLD")
  pfMapLoader:SetScript("OnEvent", function()
    -- do not load if other map addon is loaded
    if Cartographer then return end
    if METAMAP_TITLE then return end

    UIPanelWindows["WorldMapFrame"] = { area = "center" }

    WorldMapFrame:SetMovable(true)
    WorldMapFrame:EnableMouse(true)
    WorldMapFrame:RegisterForDrag("LeftButton")

    -- make sure the hooks get only applied once
    if not this.hooked then
      this.hooked = true

      HookScript(WorldMapFrame, "OnShow", function()
        -- customize
        this:EnableKeyboard(false)
        this:EnableMouseWheel(1)

        -- set back to default scale (or fill the screen: fullscreen map, below)
        if pfUI.map.fullscreen and pfUI.map.fullscreen.On() then
          pfUI.map.fullscreen.Apply()
        else
          WorldMapFrame:SetScale(scale or .85)
        end
      end)

      HookScript(WorldMapFrame, "OnMouseWheel", function()
        if pfUI.map.fullscreen and pfUI.map.fullscreen.On() then return end
        if IsShiftKeyDown() then
          alpha = clamp(WorldMapFrame:GetAlpha() + arg1/10, 0.1, 1.0)
          WorldMapFrame:SetAlpha(alpha)
        end

        if IsControlKeyDown() then
          local oldscale = WorldMapFrame:GetScale()
          local point, rel, relpoint, offx, offy = WorldMapFrame:GetPoint()
          scale = clamp(oldscale + arg1/10, 0.1, 2.0)

          -- recalculate world frame position based on old and new scale
          if point == "TOPLEFT" and relpoint == "TOPLEFT" then
            offx = offx*oldscale/scale
            offy = offy*oldscale/scale
            WorldMapFrame:SetPoint(point, rel, relpoint, offx, offy)
          end

          WorldMapFrame:SetScale(scale)
          UpdateTooltipScale()
        end

        SaveMovable(this, true)
      end)

      HookScript(WorldMapFrame, "OnDragStart", function()
        if pfUI.map.fullscreen and pfUI.map.fullscreen.On() then return end
        pfUI.api.DragStart(WorldMapFrame)
      end)

      HookScript(WorldMapFrame, "OnDragStop",function()
        if pfUI.map.fullscreen and pfUI.map.fullscreen.On() then return end
        pfUI.api.DragStop(WorldMapFrame)
        SaveMovable(this, true)
      end)
    end

    WorldMapFrame:SetAlpha(alpha)
    WorldMapFrame:SetScale(scale)
    UpdateTooltipScale()

    WorldMapFrame:ClearAllPoints()
    WorldMapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    WorldMapFrame:SetWidth(WorldMapButton:GetWidth() + 15)
    WorldMapFrame:SetHeight(WorldMapButton:GetHeight() + 55)
    LoadMovable(WorldMapFrame)

    -- skin
    WorldMapFrameCloseButton:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", 0, 0)
    CreateBackdrop(WorldMapFrame)
    CreateBackdropShadow(WorldMapFrame)

    BlackoutWorld:Hide()
    StripTextures(WorldMapFrame)

    SkinButton(WorldMapZoomOutButton)
    SkinCloseButton(WorldMapFrameCloseButton, WorldMapFrame, -3, -3)
    SkinDropDown(WorldMapContinentDropDown)
    SkinDropDown(WorldMapZoneDropDown)
    if WorldMapZoneMinimapDropDown then
      SkinDropDown(WorldMapZoneMinimapDropDown)
    end
    local point, anchor, anchorPoint, x, y = WorldMapZoneDropDown:GetPoint()
    WorldMapZoneDropDown:ClearAllPoints()
    WorldMapZoneDropDown:SetPoint(point, anchor, anchorPoint, x+8, y)

    -- coordinates
    -- (25 Nov 2026, Lo5t1ncyb3r: "the world map doesn't show character cords in the lower left like it did before the
    -- add in zoom feature") the coordinates lived on a frame inside WorldMapButton, which the zoom moves into its
    -- scroll frame: that frame was no longer drawn or updated. They sit on the map window now, over the visible map
    -- (the zoom's scroll frame, else WorldMapButton): your own position bottom left, the cursor's bottom right. The
    -- cursor's are read from WorldMapButton, which is zoomed and moved with the picture, so they are right at any zoom.
    pfUI.map.Coords()
    if pfUI.map.fullscreen then pfUI.map.fullscreen.Setup() end
  end)

  function pfUI.map.Coords()
      if WorldMapButton.coords then return end
      local cf = CreateFrame("Frame", "pfWorldMapButtonCoords", WorldMapFrame)
      WorldMapButton.coords = cf
      cf:SetFrameStrata(WorldMapFrame:GetFrameStrata())
      cf:SetFrameLevel((WorldMapFrame:GetFrameLevel() or 1) + 20)
      cf:SetAllPoints(WorldMapFrame)
      cf.text = cf:CreateFontString(nil, "OVERLAY")
      cf.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      cf.text:SetTextColor(1, 1, 1)
      cf.text:SetJustifyH("RIGHT")
      cf.player = cf:CreateFontString(nil, "OVERLAY")
      cf.player:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      cf.player:SetTextColor(1, .82, 0)
      cf.player:SetJustifyH("LEFT")

      -- where the map shows: the zoom's scroll frame when it is there, else the map itself
      function cf.Area()
        local z = pfUI.map and pfUI.map.zoom
        return (z and z.scroll) or WorldMapButton
      end
      function cf.Place()
        local area = cf.Area()
        if cf.area == area then return end
        cf.area = area
        cf.text:ClearAllPoints()
        cf.text:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -10, 10)
        cf.player:ClearAllPoints()
        cf.player:SetPoint("BOTTOMLEFT", area, "BOTTOMLEFT", 10, 10)
      end
      -- the cursor's map coordinates (0 - 100), or nil when it is not over the visible map
      function cf.Cursor()
        local width, height = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
        local mx, my = WorldMapButton:GetCenter()
        local scale = WorldMapButton:GetEffectiveScale()
        local x, y = GetCursorPosition()
        if not (mx and my and width and height and width > 0 and height > 0) then return end
        if not (MouseIsOver(WorldMapButton) and MouseIsOver(cf.Area())) then return end
        return ((x / scale) - (mx - width / 2)) / width * 100, ((my + height / 2) - (y / scale)) / height * 100
      end
      -- yours, on the map being shown (0, 0 = you are not on it)
      function cf.Player()
        local px, py = GetPlayerMapPosition("player")
        if not px or not py or (px == 0 and py == 0) then return end
        return px * 100, py * 100
      end
      cf:SetScript("OnUpdate", function()
        cf.Place()
        local mx, my = cf.Cursor()
        if mx then cf.text:SetText(string.format("%.1f / %.1f", mx, my)) else cf.text:SetText("") end
        local px, py = cf.Player()
        if px then cf.player:SetText(string.format("%s: %.1f / %.1f", UnitName("player") or "", px, py)) else cf.player:SetText("") end
      end)
  end

  pfUI.map.loader = pfMapLoader

  -- ---------------------------------------------------------------- zoom inside the map (Magnify built in)
  -- (21 Nov 2026, Lo5t1ncyb3r: "why just put in magnify with the addon..seems only fair") Written fresh, no Magnify code.
  -- The map picture (WorldMapDetailFrame) goes into a clipping scroll frame named WorldMapScrollFrame (the name pfQuest's
  -- and the gathering buttons already look for), and the clickable map (WorldMapButton: player arrow, party, every
  -- add-on's pins) goes inside the picture, so both zoom together. Plain wheel = zoom at the cursor (1x - Z.MAX), drag =
  -- move the view (a drag is not a click into a zone), a new zone or continent = back to 1x. Shift / Ctrl + wheel stay
  -- pfUI's own opacity / window size. Off: C.appearance.worldmap.zoom = "0". Stands aside for Magnify, Cartographer and
  -- MetaMap.
  local Z = { zoom = 1, MAX = 4, STEP = 1.25 }
  pfUI.map.zoom = Z
  function Z.Wanted()
    if C.appearance.worldmap.zoom == "0" then return false end
    if rawget(_G, "Cartographer") or rawget(_G, "METAMAP_TITLE") then return false end
    if _G.IsAddOnLoaded and (_G.IsAddOnLoaded("Magnify") or _G.IsAddOnLoaded("Magnify-WotLK")) then return false end
    return true
  end
  -- the largest scroll offsets at a zoom (offsets are in the map picture's own units)
  function Z.Range(z)
    local s = Z.scroll
    local dw, dh = WorldMapDetailFrame:GetWidth() or 1002, WorldMapDetailFrame:GetHeight() or 668
    local sw, sh = s:GetWidth() or dw, s:GetHeight() or dh
    return math.max(0, dw - sw / z), math.max(0, dh - sh / z)
  end
  -- (21 Nov 2026, user: zooming "just scrolls randomly and moves where i picked" - the scroll frame's offsets are not in
  -- the units the retail client uses.) The scroll frame only clips now; the map picture hangs in a fixed canvas (the
  -- scroll child) by its top left: a point offset is in the picture's own (zoomed) units, so (-h, v) puts map point
  -- (h, v) - the view's top left, in map units - exactly at the canvas's top left.
  function Z.Scroll(h, v)
    local mh, mv = Z.Range(Z.zoom)
    h = math.max(0, math.min(mh, h or 0))
    v = math.max(0, math.min(mv, v or 0))
    WorldMapDetailFrame:ClearAllPoints()
    WorldMapDetailFrame:SetPoint("TOPLEFT", Z.canvas or Z.scroll, "TOPLEFT", -h, v)
    Z.h, Z.v = h, v
  end
  -- zoom to z, keeping the map point under (fx, fy) - the cursor, in the scroll frame's units from its top left - in place
  function Z.SetZoom(z, fx, fy)
    if not Z.scroll then return end
    z = math.max(1, math.min(Z.MAX, z))
    local old = Z.zoom
    local s = Z.scroll
    fx = fx or (s:GetWidth() or 0) / 2
    fy = fy or (s:GetHeight() or 0) / 2
    local cx, cy = (Z.h or 0) + fx / old, (Z.v or 0) + fy / old
    Z.zoom = z
    WorldMapDetailFrame:SetScale(z)
    Z.Scroll(cx - fx / z, cy - fy / z)
    Z.Markers()
  end
  -- (25 Nov 2026, mechanism: pfQuest's map dots changed size with the zoom - "extremely tiny" / out of proportion)
  -- the markers ride inside the zoomed picture, so they grew and shrank with it. They keep their size on screen
  -- now: sized 1 / zoom inside it (size, not scale: a point's offsets follow the frame's own scale and would move).
  -- pfQuest's pins by their defsize (its animations size them from it; pfMap:UpdateNode sets it again, so that is
  -- wrapped), the game's party / raid dots by the size they had at 1x. The player arrow is a model, which on 1.12
  -- does not follow its parent's scale: it is left as it is.
  local function FitFrame(f, zf)
    if not f or not f.GetWidth then return end
    if not f.octoW then f.octoW, f.octoH = f:GetWidth(), f:GetHeight() end
    if f.octoW and f.octoW > 0 then f:SetWidth(f.octoW / zf) f:SetHeight((f.octoH or f.octoW) / zf) end
  end
  local function FitPin(pin, zf)
    pin.octoDef = pin.octoDef or pin.defsize
    if not pin.octoDef then return end
    pin.defsize = pin.octoDef / zf
    pin:SetWidth(pin.defsize)
    pin:SetHeight(pin.defsize)
  end
  Z.FitPin = FitPin
  -- (27 Nov 2026, mechanism: "if you accept a quest while your map is zoomed in it still makes the dots ultra tiny")
  -- pfQuest's turtle-pfQuest-worldmap.lua (in pfquest\, it sets pfMap.customContinentTransforms) already sizes every
  -- world map pin by 1 / WorldMapButton's effective scale - which takes in our zoom, through its SetScale hook on
  -- WorldMapDetailFrame. Our 1 / zoom on top made them 1 / zoom squared each time pfQuest redrew its pins (a new
  -- quest). With that file the pins are left to it; we only ask for the redraw at once (its own waits up to 1 s).
  function Z.PinsSelfScale()
    local pm = rawget(_G, "pfMap")
    return pm and pm.customContinentTransforms ~= nil
  end
  function Z.Markers()
    local zf = Z.zoom or 1
    local pm = rawget(_G, "pfMap")
    if pm and type(pm.pins) == "table" and Z.PinsSelfScale() then
      Z.pinsDirty = true
    elseif pm and type(pm.pins) == "table" then
      if not pm.octoZoomWrapped and type(pm.UpdateNode) == "function" then
        pm.octoZoomWrapped = true
        local orig = pm.UpdateNode
        pm.UpdateNode = function(self, frame, a, b, c, d)
          local r = orig(self, frame, a, b, c, d)
          if frame and frame.defsize then
            frame.octoDef = frame.defsize
            local f2 = Z.zoom or 1
            if f2 ~= 1 then FitPin(frame, f2) end
          end
          return r
        end
      end
      for _, pin in pairs(pm.pins) do FitPin(pin, zf) end
      pm.queue_update = GetTime()
    end
    for i = 1, 4 do FitFrame(rawget(_G, "WorldMapParty" .. i), zf) end
    for i = 1, 40 do FitFrame(rawget(_G, "WorldMapRaid" .. i), zf) end
  end
  -- the cursor in the scroll frame's units from its top left, or nil when it is not over the map
  function Z.Cursor()
    local s = Z.scroll
    local x, y = GetCursorPosition()
    local es = s:GetEffectiveScale() or 1
    local l, t = s:GetLeft(), s:GetTop()
    if not l or not t then return end
    local fx, fy = x / es - l, t - y / es
    if fx < 0 or fy < 0 or fx > (s:GetWidth() or 0) or fy > (s:GetHeight() or 0) then return end
    return fx, fy
  end
  function Z.Wheel(delta)
    local fx, fy = Z.Cursor()
    if not fx then return false end
    Z.SetZoom(Z.zoom * (delta > 0 and Z.STEP or 1 / Z.STEP), fx, fy)
    return true
  end
  function Z.Reset()
    if not Z.scroll then return end
    Z.zoom = 1
    WorldMapDetailFrame:SetScale(1)
    Z.Scroll(0, 0)
    Z.Markers()
  end
  function Z.Setup()
    if Z.scroll or not Z.Wanted() then return end
    local s = CreateFrame("ScrollFrame", "WorldMapScrollFrame", WorldMapFrame)
    Z.scroll = s
    s:SetWidth(WorldMapDetailFrame:GetWidth() or 1002)
    s:SetHeight(WorldMapDetailFrame:GetHeight() or 668)
    s:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOP", -502, -69)
    -- the scroll child: a fixed, unscaled canvas the size of the view (never scrolled); the picture hangs in it
    local canvas = CreateFrame("Frame", nil, s)
    Z.canvas = canvas
    canvas:SetWidth(s:GetWidth() or 1002)
    canvas:SetHeight(s:GetHeight() or 668)
    s:SetScrollChild(canvas)
    WorldMapDetailFrame:SetParent(canvas)
    WorldMapDetailFrame:ClearAllPoints()
    WorldMapDetailFrame:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
    -- the clickable map rides inside the picture: it zooms with it
    WorldMapButton:SetParent(WorldMapDetailFrame)
    WorldMapButton:SetFrameLevel(WorldMapDetailFrame:GetFrameLevel() + 2)
    Z.h, Z.v = 0, 0
    -- drag to move the view; a drag is not a click (no zooming into the zone under the mouse)
    HookScript(WorldMapButton, "OnMouseDown", function()
      if arg1 ~= "LeftButton" or Z.zoom <= 1 then return end
      local x, y = GetCursorPosition()
      Z.drag = { x = x, y = y, h = Z.h or 0, v = Z.v or 0 }
      Z.dragged = nil
    end)
    HookScript(WorldMapButton, "OnMouseUp", function() Z.drag = nil end)
    -- (23 Nov 2026, mechanism on Discord: after using the zoom, the ping when the map opens "happens in the wrong
    -- location") The game places WorldMapPing (a Model) by the player's map position against the picture's top-left,
    -- in units that do not follow the picture's zoom. The player marker (WorldMapPlayer) is placed right at every zoom,
    -- so the ping is hung on it after the game's own update each frame (-7 / -9 = the game's own nudge).
    -- (27 Nov 2026: still wrong for mechanism and Javelin - Z.PingCheck below now replaces the game's ping)
    local click = WorldMapButton:GetScript("OnClick")
    WorldMapButton:SetScript("OnClick", function()
      if Z.dragged then Z.dragged = nil return end
      if click then click() end
    end)
    s:SetScript("OnUpdate", function()
      -- the zoomed map reaches past the window: it takes the mouse only where it shows
      local want = Z.zoom <= 1 or (MouseIsOver(s) and true or false)
      if want ~= Z.mouseOn then
        Z.mouseOn = want
        WorldMapButton:EnableMouse(want)
      end
      local d = Z.drag
      if d then
        if not IsMouseButtonDown("LeftButton") then Z.drag = nil return end
        local x, y = GetCursorPosition()
        local es = s:GetEffectiveScale() or 1
        local dx, dy = (x - d.x) / es, (y - d.y) / es
        if Z.dragged or math.abs(dx) + math.abs(dy) > 4 then
          Z.dragged = true
          Z.Scroll(d.h - dx / Z.zoom, d.v + dy / Z.zoom)
        end
      end
      -- a new zone or continent on the map: back to the whole map
      local c, zn = GetCurrentMapContinent and GetCurrentMapContinent() or 0, GetCurrentMapZone and GetCurrentMapZone() or 0
      local key = tostring(c) .. ":" .. tostring(zn)
      if Z.mapKey and Z.mapKey ~= key and Z.zoom ~= 1 then Z.Reset() end
      Z.mapKey = key
      -- pfQuest's pins after a zoom step (Z.PinsSelfScale), at most ~6 times a second
      if Z.pinsDirty and GetTime() > (Z.pinsNext or 0) then
        Z.pinsDirty = nil
        Z.pinsNext = GetTime() + .15
        local pm = rawget(_G, "pfMap")
        if pm and type(pm.UpdateNodes) == "function" then pcall(pm.UpdateNodes, pm) end
      end
    end)
  end
  -- the plain wheel zooms (Shift / Ctrl + wheel are pfUI's opacity and size, above)
  local zl = CreateFrame("Frame")
  zl:RegisterEvent("PLAYER_ENTERING_WORLD")
  zl:SetScript("OnEvent", function()
    if this.done then return end
    this.done = true
    if not pcall(Z.Setup) then Z.scroll = nil return end
    if not Z.scroll then return end
    HookScript(WorldMapFrame, "OnMouseWheel", function()
      if IsShiftKeyDown() or IsControlKeyDown() then return end
      Z.Wheel(arg1 or 0)
    end)
    HookScript(WorldMapFrame, "OnHide", function() Z.drag = nil end)
  end)

  -- (24 Nov 2026, Simpson: "there is a ping on the map whenever i open it ... it's offset from the player arrow. how do i
  -- get rid of it?") The 1.2.31 fix above only ran with the map zoom on. The ping is a Model, and on 1.12 a model does
  -- not follow its parent's scale - pfUI's resized map puts it beside you. Now it is pinned on your arrow whatever the
  -- zoom, and C.appearance.worldmap.ping = "0" (Quality of Life > Map) hides it.
  -- (24 Nov 2026, Simpson: pfQuest's "Current Zone Only" button on the map "does not work anymore") pfQuest levels its
  -- menu against WorldMapButton when it loads; the zoom then moves WorldMapButton into the zoomed picture, and the map's
  -- click layer ended up over the menu's arrow (Level Range, set 10 higher, kept working). Every map menu goes above
  -- the map each time it opens, in the order they stack.
  Z.MENUS = { "pfQuestMapDropdown", "pfQuestMapLevelDropdown", "ModernMapMarkersFilter_Blizz", "ModernMapMarkersFind_Blizz",
    "pfMapMarksButton" }
  function Z.RaiseMenus()
    local top = 0
    for _, f in ipairs({ _G.WorldMapButton, _G.WorldMapDetailFrame, Z.scroll, Z.canvas }) do
      if f and f.GetFrameLevel then top = math.max(top, f:GetFrameLevel() or 0) end
    end
    for i, name in ipairs(Z.MENUS) do
      local m = rawget(_G, name)
      if m and m.SetFrameLevel then
        local lvl = top + 20 + i * 4
        if (m:GetFrameLevel() or 0) < lvl then m:SetFrameLevel(lvl) end
        local arrow = rawget(_G, name .. "Button")
        if arrow and arrow.SetFrameLevel then arrow:SetFrameLevel(m:GetFrameLevel() + 2) end
        -- (our marks list hangs under its button)
        local list = name == "pfMapMarksButton" and rawget(_G, "pfMapMarks")
        if list then list:SetFrameLevel(m:GetFrameLevel() + 2) end
      end
    end
  end
  if _G.WorldMapFrame then HookScript(WorldMapFrame, "OnShow", Z.RaiseMenus) end

  -- (27 Nov 2026, mechanism + Javelin: the ping is "still in the wrong place") Moving the model never worked: a 1.12
  -- Model draws by its own rules whatever its frame's scale and place. The game's ping is hidden now and our own
  -- pulse - plain textures, which do follow the map's size and zoom - plays on the centre of your arrow instead.
  local P = {}
  Z.ping = P
  function P.Make()
    if P.f or not _G.WorldMapButton then return P.f end
    local f = CreateFrame("Frame", "pfWorldMapPing", WorldMapButton)
    P.f = f
    f:SetFrameLevel((WorldMapButton:GetFrameLevel() or 1) + 30)
    f:SetWidth(1)
    f:SetHeight(1)
    f.rings = {}
    for i = 1, 2 do
      local t = f:CreateTexture(nil, "OVERLAY")
      t:SetTexture(pfUI.media["img:circleparty"])
      t:SetBlendMode("ADD")
      t:SetVertexColor(1, .82, .2, 1)
      t:SetPoint("CENTER", f, "CENTER", 0, 0)
      f.rings[i] = t
    end
    f:Hide()
    f:SetScript("OnUpdate", function()
      local me = _G.WorldMapPlayer
      local t = GetTime() - (this.start or 0)
      if t > 3 or not me or not me:IsVisible() then this:Hide() return end
      this:ClearAllPoints()
      this:SetPoint("CENTER", me, "CENTER", 0, 0)
      -- the size on screen stays the same at any map zoom
      local zf = (Z.scroll and Z.zoom) or 1
      for i, ring in ipairs(this.rings) do
        local p = math.mod(t + (i - 1) * .5, 1)
        local size = (12 + 44 * p) / zf
        ring:SetWidth(size)
        ring:SetHeight(size)
        ring:SetAlpha((1 - p) * .9)
      end
    end)
    return f
  end
  -- once per opening of the map (the game may show its ping again every frame while it runs)
  function P.Play()
    if P.played then return end
    local f = P.Make()
    if not f then return end
    P.played = true
    f.start = GetTime()
    f:Show()
  end
  function Z.PingCheck()
    local ping = _G.WorldMapPing
    if not ping or not ping:IsVisible() then return end
    ping:Hide()
    if C.appearance.worldmap.ping ~= "0" then P.Play() end
  end
  if _G.WorldMapFrame then
    local pw = CreateFrame("Frame", nil, WorldMapFrame)
    pw:SetScript("OnUpdate", Z.PingCheck)
    HookScript(WorldMapFrame, "OnHide", function() P.played = nil if P.f then P.f:Hide() end end)
  end

  -- ---------------------------------------------------------------- fullscreen map
  -- (27 Nov 2026, mechanism: "should be a button to make map fullscreen too ... like in newer clients") A button
  -- by the close button blows the window up to fill the screen (and back). The window's own size, place and opacity
  -- are kept for when you go back; Ctrl + wheel and dragging wait while it is full. Kept on between openings
  -- (C.appearance.worldmap.fullscreen).
  local FS = {}
  pfUI.map.fullscreen = FS
  function FS.On() return C.appearance.worldmap.fullscreen == "1" end
  function FS.Apply()
    local wm = _G.WorldMapFrame
    if not wm or not wm:GetWidth() or wm:GetWidth() <= 0 then return end
    if FS.On() then
      local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
      local s = math.min(pw / wm:GetWidth(), ph / wm:GetHeight())
      wm:SetScale(s)
      wm:ClearAllPoints()
      wm:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
      wm:SetAlpha(1)
    else
      wm:SetScale(scale or .85)
      wm:SetAlpha(alpha or 1)
      wm:ClearAllPoints()
      wm:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
      LoadMovable(wm)
    end
    UpdateTooltipScale()
    if FS.button then FS.button.text:SetText(FS.On() and T["Window"] or T["Fullscreen"]) end
    if Z.Markers then pcall(Z.Markers) end
  end
  function FS.Toggle()
    C.appearance.worldmap.fullscreen = FS.On() and "0" or "1"
    FS.Apply()
  end
  function FS.Setup()
    if FS.button or not _G.WorldMapFrame or not _G.WorldMapFrameCloseButton then return end
    local b = CreateFrame("Button", "pfWorldMapFullscreenButton", WorldMapFrame)
    FS.button = b
    b:SetWidth(70)
    b:SetHeight(18)
    b:SetFrameLevel((WorldMapFrameCloseButton:GetFrameLevel() or 1))
    b:SetPoint("RIGHT", WorldMapFrameCloseButton, "LEFT", -6, 0)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
    b.text:SetAllPoints(b)
    SkinButton(b)
    b:SetScript("OnClick", FS.Toggle)
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
      GameTooltip:AddLine(FS.On() and T["Back to the window"] or T["Map fills the screen"])
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    FS.Apply()
  end
end)
