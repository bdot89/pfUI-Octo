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

        -- set back to default scale
        WorldMapFrame:SetScale(scale or .85)
      end)

      HookScript(WorldMapFrame, "OnMouseWheel", function()
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
        pfUI.api.DragStart(WorldMapFrame)
      end)

      HookScript(WorldMapFrame, "OnDragStop",function()
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
    if not WorldMapButton.coords then
      WorldMapButton.coords = CreateFrame("Frame", "pfWorldMapButtonCoords", WorldMapButton)
      WorldMapButton.coords.text = WorldMapButton.coords:CreateFontString(nil, "OVERLAY")
      WorldMapButton.coords.text:SetPoint("BOTTOMRIGHT", WorldMapButton, "BOTTOMRIGHT", -10, 10)
      WorldMapButton.coords.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      WorldMapButton.coords.text:SetTextColor(1, 1, 1)
      WorldMapButton.coords.text:SetJustifyH("RIGHT")

      WorldMapButton.coords:SetScript("OnUpdate", function()
        local width  = WorldMapButton:GetWidth()
        local height = WorldMapButton:GetHeight()
        local mx, my = WorldMapButton:GetCenter()
        local scale  = WorldMapButton:GetEffectiveScale()
        local x, y   = GetCursorPosition()

        if mx and my then
          mx = (( x / scale ) - ( mx - width / 2)) / width * 100
          my = (( my + height / 2 ) - ( y / scale )) / height * 100
        end

        if mx and my and MouseIsOver(WorldMapButton) then
          WorldMapButton.coords.text:SetText(string.format('%.1f / %.1f', mx, my))
        else
          WorldMapButton.coords.text:SetText("")
        end
      end)
    end
  end)

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
  function Z.Scroll(h, v)
    local mh, mv = Z.Range(Z.zoom)
    h = math.max(0, math.min(mh, h or 0))
    v = math.max(0, math.min(mv, v or 0))
    Z.scroll:SetHorizontalScroll(h)
    Z.scroll:SetVerticalScroll(v)
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
    if s.UpdateScrollChildRect then s:UpdateScrollChildRect() end
    Z.Scroll(cx - fx / z, cy - fy / z)
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
    if Z.scroll.UpdateScrollChildRect then Z.scroll:UpdateScrollChildRect() end
    Z.Scroll(0, 0)
  end
  function Z.Setup()
    if Z.scroll or not Z.Wanted() then return end
    local s = CreateFrame("ScrollFrame", "WorldMapScrollFrame", WorldMapFrame)
    Z.scroll = s
    s:SetWidth(WorldMapDetailFrame:GetWidth() or 1002)
    s:SetHeight(WorldMapDetailFrame:GetHeight() or 668)
    s:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOP", -502, -69)
    WorldMapDetailFrame:SetParent(s)
    WorldMapDetailFrame:ClearAllPoints()
    WorldMapDetailFrame:SetPoint("TOPLEFT", s, "TOPLEFT", 0, 0)
    s:SetScrollChild(WorldMapDetailFrame)
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
end)
