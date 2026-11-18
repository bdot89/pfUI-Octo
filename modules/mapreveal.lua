pfUI:RegisterModule("mapreveal", "vanilla:tbc", function ()
  -- do not load if other map addon is loaded
  if Cartographer then return end
  if METAMAP_TITLE then return end

  pfUI.mapreveal = {}
  function pfUI.mapreveal:UpdateConfig()
    WorldMapFrame_Update()
  end

  pfUI.mapreveal.onmap = CreateFrame("CheckButton", "pfUI_mapreveal_onmap", WorldMapFrame, "UICheckButtonTemplate")
  pfUI.mapreveal.onmap:SetNormalTexture("")
  pfUI.mapreveal.onmap:SetPushedTexture("")
  pfUI.mapreveal.onmap:SetHighlightTexture("")
  pfUI.mapreveal.onmap.text = _G["pfUI_mapreveal_onmapText"]
  CreateBackdrop(pfUI.mapreveal.onmap, nil, true)
  pfUI.mapreveal.onmap:SetWidth(14)
  pfUI.mapreveal.onmap:SetHeight(14)
  pfUI.mapreveal.onmap:SetPoint("LEFT", WorldMapZoomOutButton, "RIGHT", 20, 0)
  pfUI.mapreveal.onmap.text:SetPoint("LEFT", pfUI.mapreveal.onmap, "RIGHT", 2, 0)
  pfUI.mapreveal.onmap.text:SetText(T["Reveal Unexplored Areas"])
  pfUI.mapreveal.onmap:SetScript("OnShow", function()
    this:SetChecked(C.appearance.worldmap.mapreveal == "1")
  end)
  pfUI.mapreveal.onmap:SetScript("OnClick", function ()
    if this:GetChecked() then
      C.appearance.worldmap.mapreveal = "1"
    else
      C.appearance.worldmap.mapreveal = "0"
    end
    pfUI.mapreveal:UpdateConfig()
  end)

  local errata = {
    ["Interface\\WorldMap\\Tirisfal\\BRIGHTWATERLAKE"] = {offsetX={587,584}},
    ["Interface\\WorldMap\\Silverpine\\BERENSPERIL"] = {offsetY={417,415}},
  }

  local function create_hash(prefix, textureName, textureWidth, textureHeight, offsetX, offsetY, mapPointX, mapPointY)
    local hash = string.format(":%s:%s:%s:%s",textureWidth,textureHeight,offsetX,offsetY)
    if (mapPointX ~= 0 or mapPointY ~= 0) then
      hash = string.format("%s:%s:%s",hash,tostring(mapPointX),tostring(mapPointY))
    end
    if string.sub(textureName, 0, string.len(prefix)) == prefix then
      return string.format("%s%s",string.sub(textureName, string.len(prefix) + 1),hash)
    end
    return string.format("|%s",hash)
  end

  local function unpack_hash(prefix, hash)
    local _, stored_prefix, textureName, textureWidth, textureHeight, offsetX, offsetY, mapPointX, mapPointY, name
    _, _, stored_prefix, textureName, textureWidth, textureHeight, offsetX, offsetY = string.find(hash, "^([|]?)([^:]+):([^:]+):([^:]+):([^:]+):([^:]+)")
    if (not textureName or not offsetY) then
      return
    end
    if (offsetY) then
      _, _, mapPointX, mapPointY = string.find(hash,"^[|]?[^:]+:[^:]+:[^:]+:[^:]+:[^:]+:([^:]+):([^:]+)")
    end
    if (not mapPointY) then
      mapPointX = 0 mapPointY = 0
    end
    if (stored_prefix ~= "|") then
      name = textureName
      textureName = string.format("%s%s",prefix,textureName)
    end
    -- coerce to number by addition; cheaper than tonumber()
    return textureName, textureWidth + 0, textureHeight + 0, offsetX + 0, offsetY + 0, mapPointX + 0, mapPointY + 0, name
  end

  local explores = {}
  local explorecaches = {}

  local exploreEnter = function()
    WorldMapTooltip:ClearLines()
    WorldMapTooltip:SetOwner(this, "ANCHOR_TOP")
    WorldMapTooltip:AddLine(T["Exploration Point"]..":", .3, 1, .8)
    WorldMapTooltip:AddLine(this.name, 1, 1, 1)
    WorldMapTooltip:Show()

    -- (octo: the tiles are kept by the overlay's own name, this.area; pfUI
    -- looked them up by the tooltip text, so hovering never lit them)
    if not explorecaches[this.area] then return end
    if C.appearance.worldmap.mapreveal == "0" then return end
    for texture in pairs(explorecaches[this.area]) do
      texture:SetVertexColor(1,1,1,1)
    end
  end

  local exploreLeave = function()
    WorldMapTooltip:Hide()
    if not explorecaches[this.area] then return end
    if C.appearance.worldmap.mapreveal == "0" then return end
    local r,g,b,a = GetStringColor(C.appearance.worldmap.mapreveal_color)
    for texture in pairs(explorecaches[this.area]) do
      texture:SetVertexColor(r,g,b,a)
    end
  end

  -- an exploration point (magnifying glass) in the middle of an overlay
  local function Explore(i, mapFileName, name, textureWidth, textureHeight, offsetX, offsetY, unknown)
    explores[i] = explores[i] or CreateFrame("Frame", nil, WorldMapDetailFrame)
    local explore = explores[i]
    explore:SetWidth(16)
    explore:SetHeight(16)
    explore:ClearAllPoints()
    explore:SetPoint("TOPLEFT", "WorldMapDetailFrame", "TOPLEFT", offsetX+textureWidth/2, -offsetY-textureHeight/2)
    explore:SetScript("OnEnter", exploreEnter)
    explore:SetScript("OnLeave", exploreLeave)
    explore:EnableMouse(true)
    explore:SetFrameLevel(255)
    explore.name = mapFileName .. " (" .. (name or "?") .. ")"
    explore.area = name
    explore.tex = explore.tex or explore:CreateTexture("", "OVERLAY")
    explore.tex:SetBlendMode("ADD")
    explore.tex:SetTexCoord(.08, .92, .08, .92)
    explore.tex:SetAllPoints()

    if C.appearance.worldmap.mapexploration == "1" and unknown then
      explore.tex:SetTexture("Interface\\WorldMap\\WorldMap-MagnifyingGlass")
      explore:Show()
    else
      explore:Hide()
    end
  end

  -- the game's overlay texture n (more are made when a zone needs them)
  local function Overlay(n)
    if n > NUM_WORLDMAP_OVERLAYS then
      for j = NUM_WORLDMAP_OVERLAYS + 1, n do
        _G.WorldMapDetailFrame:CreateTexture(string.format("%s%s","WorldMapOverlay",j), "ARTWORK")
      end
      NUM_WORLDMAP_OVERLAYS = n
    end
    return _G[string.format("%s%s","WorldMapOverlay",n)]
  end

  -- octo (from the ClassicAPI pfUI fork): ClassicAPI reads every overlay of
  -- the viewed zone from the client's own WorldMapOverlay.dbc, tiles worked
  -- out - OctoWoW's own zones too, which pfUI's measured table does not have.
  -- Returns true when it drew the map; the measured table is the fallback.
  local function ClassicReveal(mapFileName, alreadyknown, r, g, b, a)
    if not (C_UnitAuras and C_Map and C_Map.GetMapOverlays) then return end
    local ok, list = pcall(C_Map.GetMapOverlays)
    if not ok or type(list) ~= "table" or not list[1] then return end

    local known = {}
    for path in pairs(alreadyknown) do known[string.upper(path)] = true end

    local textureCount = 0
    for i, ov in ipairs(list) do
      local name = ov.textureName
      if name and name ~= "" then
        local isknown = known[string.upper(ov.texturePath or "")]
        Explore(i, mapFileName, name, ov.textureWidth or 0, ov.textureHeight or 0, ov.offsetX or 0, ov.offsetY or 0, not isknown)
        if C.appearance.worldmap.mapreveal == "1" or isknown then
          for _, tile in ipairs(ov.tiles or {}) do
            textureCount = textureCount + 1
            local texture = Overlay(textureCount)
            texture:SetWidth(tile.width)
            texture:SetHeight(tile.height)
            texture:SetTexCoord(0, tile.texCoordX, 0, tile.texCoordY)
            texture:ClearAllPoints()
            texture:SetPoint("TOPLEFT", "WorldMapDetailFrame", "TOPLEFT", tile.offsetX, -tile.offsetY)
            texture:SetTexture(tile.file)
            explorecaches[name] = explorecaches[name] or {}
            explorecaches[name][texture] = true
            if isknown then texture:SetVertexColor(1,1,1,1) else texture:SetVertexColor(r,g,b,a) end
            texture:Show()
          end
        end
      end
    end
    return true
  end

  local function pfWorldMapFrame_Update()
    -- create metatable if not yet created
    this.overlayData = this.overlayData or setmetatable(pfMapOverlayData, {__index = function(t,k)
      local v = {}
      rawset(t,k,v)
      return v
    end})

    local r,g,b,a = GetStringColor(C.appearance.worldmap.mapreveal_color)
    local mapFileName, textureHeight, textureWidth = GetMapInfo()

    if (not mapFileName) then mapFileName = "World" end

    local prefix = string.format("Interface\\WorldMap\\%s\\",mapFileName)
    local numOverlays = GetNumMapOverlays()

    local alreadyknown = {}
    for i=1, numOverlays do
      local textureName, textureWidth, textureHeight, offsetX, offsetY, mapPointX, mapPointY = GetMapOverlayInfo(i)
      local overlayHash = create_hash(textureName, textureWidth, textureHeight, offsetX, offsetY, mapPointX, mapPointY)
      alreadyknown[textureName] = overlayHash
    end

    -- hide all exploration points
    for k, frame in pairs(explores) do
      frame:Hide()
    end
    for k in pairs(explorecaches) do explorecaches[k] = nil end

    -- (18 Nov 2026, Wolfahrt) ClassicAPI first again: it reads the client's own WorldMapOverlay.dbc, the
    -- boxes the game draws explored pieces in. A render of Thalassian Highlands from the game files showed
    -- those right; the old measured list (now rebuilt from the same DBC, tools\Make-MapOverlays.ps1) put
    -- pieces in the wrong places and twice - 1.1.55 had wrongly put that list first.
    if ClassicReveal(mapFileName, alreadyknown, r, g, b, a) then return end
    local zoneData = this.overlayData[mapFileName]
    local textureCount = 0
    local texturePixelWidth, textureFileWidth, texturePixelHeight, textureFileHeight
    for i, hash in ipairs(zoneData) do
      local textureName, textureWidth, textureHeight, offsetX, offsetY, mapPointX, mapPointY, name = unpack_hash(prefix, hash)

      Explore(i, mapFileName, name, textureWidth, textureHeight, offsetX, offsetY, not alreadyknown[textureName])

      if C.appearance.worldmap.mapreveal == "1" or alreadyknown[textureName] then
        if errata[textureName] and errata[textureName].offsetX and errata[textureName].offsetX[1] == offsetX then
          offsetX = errata[textureName].offsetX[2]
        end
        if errata[textureName] and errata[textureName].offsetY and errata[textureName].offsetY[1] == offsetY then
          offsetY = errata[textureName].offsetY[2]
        end
        local numTexturesHorz = math.ceil(textureWidth / 256)
        local numTexturesVert = math.ceil(textureHeight / 256)
        local neededTextures = textureCount + (numTexturesHorz * numTexturesVert)
        local texture, texturePixelWidth, textureFileWidth, texturePixelHeight, textureFileHeight
        if (neededTextures > NUM_WORLDMAP_OVERLAYS) then
          for j = NUM_WORLDMAP_OVERLAYS + 1, neededTextures do
            _G.WorldMapDetailFrame:CreateTexture(string.format("%s%s","WorldMapOverlay",j), "ARTWORK")
          end
          NUM_WORLDMAP_OVERLAYS = neededTextures
        end
        for j = 1, numTexturesVert do
          if (j < numTexturesVert) then
            texturePixelHeight,textureFileHeight = 256,256
          else
            texturePixelHeight = mod(textureHeight, 256)
            if (texturePixelHeight == 0) then texturePixelHeight = 256 end
            textureFileHeight = 16
            while (textureFileHeight < texturePixelHeight) do
              textureFileHeight = textureFileHeight * 2
            end
          end
          for k = 1, numTexturesHorz do
            if (textureCount > NUM_WORLDMAP_OVERLAYS) then
              return
            end
            texture = _G[string.format("%s%s","WorldMapOverlay",(textureCount + 1))]
            if (k < numTexturesHorz) then
              texturePixelWidth, textureFileWidth = 256,256
            else
              texturePixelWidth = mod(textureWidth, 256)
              if (texturePixelWidth == 0) then texturePixelWidth = 256 end
              textureFileWidth = 16
              while (textureFileWidth < texturePixelWidth) do
                textureFileWidth = textureFileWidth * 2
              end
            end
            texture:SetWidth(texturePixelWidth)
            texture:SetHeight(texturePixelHeight)
            texture:SetTexCoord(0, texturePixelWidth / textureFileWidth, 0, texturePixelHeight / textureFileHeight)
            texture:ClearAllPoints()
            texture:SetPoint("TOPLEFT", "WorldMapDetailFrame", "TOPLEFT", offsetX + (256 *(k - 1)), -(offsetY +(256 *(j - 1))))
            texture:SetTexture(string.format("%s%s",textureName,(((j - 1) * numTexturesHorz) + k)))

            explorecaches[name] = explorecaches[name] or {}
            explorecaches[name][texture] = true

            if not alreadyknown[textureName] then
              texture:SetVertexColor(r,g,b,a)
            else
              texture:SetVertexColor(1,1,1,1)
            end
            texture:Show()
            textureCount = textureCount + 1
          end
        end
      end
    end
  end

  -- hook map reveal functions before and after the actual call
  local pfHookWorldMapFrame_Update = _G.WorldMapFrame_Update
  _G.WorldMapFrame_Update = function(self)
    -- hide all previously set textures
    for i = 1, NUM_WORLDMAP_OVERLAYS do
      _G[string.format("%s%s","WorldMapOverlay",i)]:Hide()
    end

    -- let the game put its explored tiles on the map
    pfHookWorldMapFrame_Update(self)

    -- let the addon extend it with its own data
    pfWorldMapFrame_Update()
  end
end)
