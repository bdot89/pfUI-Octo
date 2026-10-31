pfUI:RegisterModule("minimap-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the Minimap section in OctoBG's look (23 Oct 2026). User:
  -- "Add a preview frame in minimap options make everything selectable
  -- changeable moveable ... every frame that we have and shape to be able
  -- to have stuff edited around it". Then (same day) "menu is messy can we
  -- compact it like the rest": two pages, each with the same pinned preview:
  --   Map               looks, shape (picture tiles), border, art (one card,
  --                     a tab per layer), size, opacity, zoom
  --   Buttons and text  one card for the picked part (tabs, or click it in
  --                     the preview), a card of details, the addon buttons
  -- Every setting of pfUI's Minimap pages (Minimap, Addon Buttons, Map Style,
  -- Buttons & Extras; hidden from the topic list and Find now) is here.
  -- Preview: click a part to pick it, drag it (or the map) to move it, Shift
  -- + wheel to size it, right-click to put it back. Parts set to Never are
  -- left out unless picked.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage or not pfUI.minimap then return end
  local map = pfUI.minimap
  local MO = { sel = "zone", layer = 1, previews = {} }
  pfUI.minimapOcto = MO

  local function S() return C.mapstyle end
  local function MM() return C.appearance.minimap end
  local function AB() return C.abuttons end
  local function U() if map.ApplyStyle then map.ApplyStyle() end end
  local function Pct(v) return math.floor(v + .5) .. "%" end
  local function Px(v) return v .. " px" end
  local function Sec(v) return v == 0 and "never" or (v .. " s") end
  local function Alpha(v) return math.floor(v * 100 + .5) .. "%" end

  local function PfList(list)
    local out = {}
    for _, e in ipairs(list or {}) do
      local _, _, k, l = string.find(e, "^(.-):(.*)$")
      if k then table.insert(out, { key = k, label = l }) end
    end
    return out
  end
  local function DD(name) return PfList(pfUI.gui and pfUI.gui.dropdowns and pfUI.gui.dropdowns[name]) end

  local function Drop(p, label, desc, options, group, key, after)
    return W.Dropdown(p, label, desc, options, function() return group()[key] end, function(v)
      group()[key] = v
      if after then after(v) else U() end
    end)
  end
  local function Chk(p, label, desc, group, key, after) return O.PfChk(p, label, desc, group, key, after or U) end
  local function Sld(p, label, desc, min, max, step, group, key, fmt, after) return O.PfSld(p, label, desc, min, max, step, group, key, after or U, fmt) end
  local function ColorOf(str)
    local r, g, b, a = GetStringColor(str or "1,1,1,1")
    return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
  end
  local function Color(p, label, desc, getKey)
    return W.Color(p, label, desc, function() return ColorOf(S()[getKey()]) end, function(r, g, b, a)
      S()[getKey()] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
      U()
    end)
  end
  local function Accent()
    if GetAccentColor then return GetAccentColor() end
    return .2, .55, .9
  end
  local function MapSize() pfUI.minimap:UpdateConfig() end

  -- ---------------------------------------------------------------- parts

  local NAMES = {
    zone = "Zone name", coords = "Coordinates", clock = "Clock", ping = "Who pinged", tracking = "Tracking",
    mail = "Mail", battlefield = "Battleground", pvp = "PvP icon", abutton = "Addon buttons arrow", bar = "Bar under the map",
  }
  local SHORT = {
    zone = "Zone", coords = "Coords", clock = "Clock", ping = "Pinged", tracking = "Tracking",
    mail = "Mail", battlefield = "Battleground", pvp = "PvP", abutton = "Arrow", bar = "Bar under",
  }
  local ORDER = { "zone", "coords", "clock", "ping", "tracking", "mail", "battlefield", "pvp", "abutton", "bar" }
  MO.NAMES = NAMES

  -- shown always / on mouse-over / never, for every part
  local function Mode(key)
    if key == "zone" or key == "coords" then
      local v = (key == "zone") and MM().zonetext or MM().coordstext
      return (v == "on" and "show") or (v == "mouseover" and "hover") or "hide"
    elseif key == "ping" then
      return S().ping == "1" and "show" or "hide"
    elseif key == "pvp" then
      return C.unitframes.player.showPVPMinimap == "1" and "show" or "hide"
    elseif key == "bar" then
      return C.panel.other.minimap == "none" and "hide" or "show"
    end
    return S()[key] or "show"
  end
  local function SetMode(key, v)
    if key == "zone" or key == "coords" then
      local word = (v == "show" and "on") or (v == "hover" and "mouseover") or "off"
      if key == "zone" then MM().zonetext = word else MM().coordstext = word end
    elseif key == "ping" then
      S().ping = (v == "hide") and "0" or "1"
    elseif key == "pvp" then
      C.unitframes.player.showPVPMinimap = (v == "hide") and "0" or "1"
    elseif key == "bar" then
      if v == "hide" then
        if C.panel.other.minimap ~= "none" then S().barwas = C.panel.other.minimap end
        C.panel.other.minimap = "none"
      elseif C.panel.other.minimap == "none" then
        C.panel.other.minimap = S().barwas or "zone"
      end
    else
      S()[key] = v
    end
    U()
  end
  MO.Mode, MO.SetMode = Mode, SetMode
  -- a part set to "never" that you drag or size in the preview comes on, so
  -- you see what you change (user, 25 Oct 2026: "nothing moves or edits when
  -- i do it in the preview" - the zone name was set to never)
  function MO.Wake(key)
    if key and key ~= "map" and Mode(key) == "hide" then
      SetMode(key, "show")
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r map: " .. (NAMES[key] or key) .. " was set to never show - it shows again.")
    end
  end
  local MODEWORD = { show = "always", hover = "while the mouse is over the map", hide = "never" }
  local MODES = { { key = "show", label = "Always" }, { key = "hover", label = "Mouse over the map" }, { key = "hide", label = "Never" } }
  local ONOFF = { { key = "show", label = "Always" }, { key = "hide", label = "Never" } }

  -- each page has its own preview: the one in view is "the" preview
  function MO.Current()
    local last
    for _, pv in ipairs(MO.previews) do
      if pv.holder:IsVisible() then return pv end
      last = pv
    end
    return last
  end
  function MO.Layout()
    local pv = MO.Current()
    if pv then pv.Layout() end
  end

  -- picks a part: the Part card follows it, and opens
  function MO.Pick(key)
    MO.sel = key
    if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection("mmparts", "Part") else O:Open("mmparts") end
    O:Refresh()
    if MO.Layout then MO.Layout() end
  end
  -- the map's own cards
  function MO.OpenMap(card)
    if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection("mmmap", card) else O:Open("mmmap") end
  end

  -- ---------------------------------------------------------------- preview

  local MAPPX = 150
  local SHAPES = {
    { key = "square", label = "Square" }, { key = "round", label = "Round" }, { key = "rounded", label = "Rounded square" },
    { key = "rounder", label = "Rounder square" }, { key = "squircle", label = "Squircle" }, { key = "octagon", label = "Octagon" },
    { key = "diamond", label = "Diamond" }, { key = "corner-tl", label = "Round, square top left" },
    { key = "corner-tr", label = "Round, square top right" }, { key = "corner-bl", label = "Round, square bottom left" },
    { key = "corner-br", label = "Round, square bottom right" },
  }
  local function ShapeArt(shape)
    if shape == "square" then return "Interface\\Buttons\\WHITE8X8" end
    return pfUI.media["img:minimap\\mask-" .. shape]
  end

  local function Turn(tex, angle)
    local c, s = math.cos(angle), math.sin(angle)
    local function P(x, y) return .5 + (x - .5) * c - (y - .5) * s, .5 + (x - .5) * s + (y - .5) * c end
    local ulx, uly = P(0, 0)
    local llx, lly = P(0, 1)
    local urx, ury = P(1, 0)
    local lrx, lry = P(1, 1)
    tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
  end

  local function ZoneWord()
    return (GetMinimapZoneText and GetMinimapZoneText() ~= "" and GetMinimapZoneText()) or "The Barrens"
  end

  -- what each part looks like in the preview
  local function Sample(key)
    if key == "zone" then return "text", ZoneWord(), 2
    elseif key == "coords" then return "text", "47.3, 52.1", 0
    elseif key == "clock" then return "text", date("%H:%M"), 0
    elseif key == "ping" then return "text", "|cffff7d0aJaina|r", 0
    elseif key == "tracking" then
      local t = GetTrackingTexture and GetTrackingTexture()
      return "icon", t or "Interface\\Icons\\Ability_Tracking", tonumber(MM().tracking_size) or 16
    elseif key == "mail" then return "icon", pfUI.media["img:mail"], 18
    elseif key == "battlefield" then
      local f = UnitFactionGroup and UnitFactionGroup("player")
      return "icon", "Interface\\BattlefieldFrame\\Battleground-" .. ((f == "Horde") and "Horde" or "Alliance"), 32
    elseif key == "pvp" then return "icon", pfUI.media["img:pvp"], 16
    elseif key == "abutton" then return "arrow", nil, 12
    elseif key == "bar" then return "bar", ZoneWord(), 0
    end
  end

  local function Preview(p)
    W.Pin(p, "Preview", "Your map with every part around it, where it sits in game. Click a part to pick it, drag it - "
      .. "or the map - to move it, hold Shift and scroll the mouse wheel over it to make it bigger or smaller, right-click "
      .. "it to put it back. Parts set to Never are left out until you pick them. Click this bar to fold it away.", function(pp)
      local box = (W.ZoomBox or W.Box)(pp, 236)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      local base = holder:GetFrameLevel()
      local ar, ag, ab = Accent()

      -- the map: art under it, the shape, its border, art above
      local mock = CreateFrame("Button", nil, holder)
      mock:SetWidth(MAPPX)
      mock:SetHeight(MAPPX)
      mock:SetPoint("CENTER", box, "CENTER", 0, 14)
      mock:SetFrameLevel(base + 2)
      local under = CreateFrame("Frame", nil, holder)
      under:SetAllPoints(mock)
      under:SetFrameLevel(base + 1)
      local over = CreateFrame("Frame", nil, holder)
      over:SetAllPoints(mock)
      over:SetFrameLevel(base + 4)
      mock.fill = mock:CreateTexture(nil, "BACKGROUND")
      mock.fill:SetAllPoints(mock)
      mock.shade = mock:CreateTexture(nil, "BORDER")
      mock.shade:SetPoint("CENTER", mock, "CENTER", 0, 0)
      mock.arrow = mock:CreateTexture(nil, "ARTWORK")
      mock.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
      mock.arrow:SetWidth(22)
      mock.arrow:SetHeight(22)
      mock.arrow:SetPoint("CENTER", mock, "CENTER", 0, 0)
      local frame = CreateFrame("Frame", nil, over)
      frame:SetAllPoints(mock)
      CreateBackdrop(frame)
      local outline = over:CreateTexture(nil, "OVERLAY")
      outline:SetAllPoints(mock)
      local art = {}
      for i = 1, 3 do
        art[i] = { up = over:CreateTexture(nil, "ARTWORK"), down = under:CreateTexture(nil, "BACKGROUND"), angle = 0 }
      end

      -- one spot per part
      local hots = {}
      for _, part in ipairs(map.PARTS or {}) do
        local h = CreateFrame("Button", nil, holder)
        h:SetFrameLevel(base + (part.key == "bar" and 3 or 6))
        h.key, h.part = part.key, part
        h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        h:EnableMouseWheel(true)
        h.pick = h:CreateTexture(nil, "BACKGROUND")
        h.pick:SetPoint("TOPLEFT", h, "TOPLEFT", -2, 2)
        h.pick:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 2, -2)
        h.pick:SetTexture("Interface\\Buttons\\WHITE8X8")
        h.pick:SetVertexColor(ar, ag, ab, .35)
        h.hl = h:CreateTexture(nil, "HIGHLIGHT")
        h.hl:SetAllPoints(h)
        h.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        h.hl:SetVertexColor(ar, ag, ab, .3)
        local kind = Sample(part.key)
        if kind == "text" or kind == "bar" then
          if kind == "bar" then CreateBackdrop(h) end
          h.text = h:CreateFontString(nil, "OVERLAY")
          h.text:SetPoint("CENTER", h, "CENTER", 0, 0)
        elseif kind == "icon" then
          h.icon = h:CreateTexture(nil, "ARTWORK")
          h.icon:SetAllPoints(h)
        else
          h.icon = W.Arrow(h, 12, "down")
          h.icon:SetPoint("CENTER", h, "CENTER", 0, 0)
        end
        hots[part.key] = h
      end
      hots.map, mock.key = mock, "map"
      mock:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      mock:EnableMouseWheel(true)

      local function Scale()
        local size = Minimap:GetWidth()
        if not size or size <= 0 then size = tonumber(MM().size) or 140 end
        return MAPPX / size
      end

      local function Layout()
        local s = S()
        local f = Scale()
        -- shape, border, art
        local shape = s.shape or "square"
        mock.fill:SetTexture(ShapeArt(shape))
        mock.fill:SetVertexColor(.42, .36, .23, 1)
        mock.shade:SetTexture(ShapeArt(shape))
        mock.shade:SetVertexColor(.5, .44, .3, 1)
        mock.shade:SetWidth(MAPPX * .7)
        mock.shade:SetHeight(MAPPX * .7)
        if s.border == "pfui" and shape == "square" then frame:Show() else frame:Hide() end
        if s.border == "outline" then
          outline:SetTexture(pfUI.media["img:minimap\\outline-" .. shape])
          local r, g, b, a = ColorOf(s.outlinecolor)
          if s.outlineaccent == "1" then r, g, b = Accent() end
          outline:SetVertexColor(r, g, b, a)
          outline:Show()
        else
          outline:Hide()
        end
        for i = 1, 3 do
          local l = art[i]
          local tex = s["art" .. i]
          l.up:Hide()
          l.down:Hide()
          l.tex, l.speed = nil, 0
          if tex and tex ~= "none" then
            local t = s["art" .. i .. "above"] == "1" and l.up or l.down
            local px = MAPPX * (tonumber(s["art" .. i .. "size"]) or 130) / 100
            t:SetTexture(tex)
            t:ClearAllPoints()
            t:SetPoint("CENTER", mock, "CENTER", 0, 0)
            t:SetWidth(px)
            t:SetHeight(px)
            t:SetVertexColor(ColorOf(s["art" .. i .. "color"]))
            t:SetBlendMode(s["art" .. i .. "blend"] == "BLEND" and "BLEND" or "ADD")
            Turn(t, math.rad(l.angle))
            t:Show()
            l.tex, l.speed = t, tonumber(s["art" .. i .. "speed"]) or 0
          end
        end
        -- every part where it sits, as big as it is; Never = left out
        for _, part in ipairs(map.PARTS or {}) do
          local h = hots[part.key]
          local kind, what, extra = Sample(part.key)
          local sc = map.PartScale(part) * f
          if kind == "text" then
            h.text:SetFont(pfUI.font_default, math.max(6, (C.global.font_size + (extra or 0)) * sc), "OUTLINE")
            h.text:SetText(what)
            h:SetWidth(math.max(12, (h.text:GetStringWidth() or 30) + 4))
            h:SetHeight(math.max(8, (C.global.font_size + (extra or 0)) * sc + 4))
          elseif kind == "bar" then
            h.text:SetFont(pfUI.font_default, math.max(6, C.global.font_size * sc), "OUTLINE")
            h.text:SetText(what)
            h:SetWidth(MAPPX * map.PartScale(part))
            h:SetHeight(math.max(10, C.global.font_size * 1.5 * sc))
          elseif kind == "icon" then
            local real = part.get()
            local w = real and real:GetWidth() or 0
            if not w or w <= 0 or w > 64 then w = extra end
            h.icon:SetTexture(what)
            h:SetWidth(math.max(6, w * sc))
            h:SetHeight(math.max(6, w * sc))
          else
            h:SetWidth(math.max(8, extra * sc))
            h:SetHeight(math.max(8, extra * sc))
            h.icon:SetWidth(math.max(6, 10 * sc))
            h.icon:SetHeight(math.max(6, 10 * sc))
          end
          local pt = map.PartPoint(part)
          local x, y = map.PartOffset(part)
          h:ClearAllPoints()
          h:SetPoint(pt, mock, map.Rel and map.Rel(part, pt) or pt, x * f, y * f)
          local mode = Mode(part.key)
          local picked = MO.sel == part.key
          if mode == "hide" and not picked then
            h:Hide()
          else
            h:Show()
            h:SetAlpha(mode == "hide" and .35 or (mode == "hover" and .75 or 1))
          end
          if picked then h.pick:Show() else h.pick:Hide() end
        end
      end
      table.insert(MO.previews, { hots = hots, Layout = Layout, holder = holder })

      -- mouse: click = pick, drag = move, Shift + wheel = size, right-click = back
      local function Tip(h)
        GameTooltip:SetOwner(h, "ANCHOR_TOP")
        local key = h.key
        if key == "map" then
          GameTooltip:AddLine("The map")
          GameTooltip:AddLine("Click: shape and border", 1, 1, 1)
          GameTooltip:AddLine("Drag: move the map on your screen", 1, 1, 1)
          GameTooltip:AddLine("Shift + mouse wheel: bigger / smaller", 1, 1, 1)
          GameTooltip:AddLine("Right-click: size back to 140 px", 1, 1, 1)
        else
          GameTooltip:AddLine(NAMES[key] or key)
          GameTooltip:AddLine("Click: pick it", 1, 1, 1)
          GameTooltip:AddLine("Drag: move it", 1, 1, 1)
          GameTooltip:AddLine("Shift + mouse wheel: bigger / smaller", 1, 1, 1)
          GameTooltip:AddLine("Right-click: put it back", 1, 1, 1)
          GameTooltip:AddLine("Shows: " .. (MODEWORD[Mode(key)] or "always"), .7, .7, .7)
        end
        GameTooltip:Show()
      end
      local function Wire(h)
        h:SetScript("OnEnter", function() Tip(this) end)
        h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        h:SetScript("OnMouseDown", function()
          if arg1 == "RightButton" then return end
          local cx, cy = GetCursorPosition()
          if this.key == "map" then
            local m = pfUI.minimap
            this.down = { cx, cy, m:GetLeft() or 0, m:GetTop() or 0 }
          else
            local x, y = map.PartOffset(this.part)
            this.down = { cx, cy, x, y }
          end
          this.moved = nil
          MO.dragging = this
        end)
        h:SetScript("OnMouseUp", function()
          local moved = this.moved
          this.down, this.moved = nil, nil
          MO.dragging = nil
          if moved then
            if this.key == "map" and pfUI.api and pfUI.api.SaveMovable then pfUI.api.SaveMovable(pfUI.minimap) end
            O:Refresh()
          end
        end)
        h:SetScript("OnClick", function()
          if this.dragged then this.dragged = nil return end
          local key = this.key
          if arg1 == "RightButton" then
            if key == "map" then
              MM().size = "140"
              MapSize()
            else
              map.ResetPart(key)
            end
            Layout()
            O:Refresh()
            return
          end
          if key == "map" then MO.OpenMap("Shape and border") else MO.Pick(key) end
        end)
        h:SetScript("OnMouseWheel", function()
          local key = this.key
          if IsShiftKeyDown() then
            if key == "map" then
              MM().size = tostring(math.max(80, math.min(400, (tonumber(MM().size) or 140) + 5 * (arg1 or 0))))
              MapSize()
            else
              MO.Wake(key)
              map.SizePart(key, (tonumber(S()[key .. "scale"]) or 100) + 10 * (arg1 or 0))
            end
            Layout()
            O:Refresh()
          elseif pfUI.plates and pfUI.plates.PassWheel then
            pfUI.plates.PassWheel(this)
          end
        end)
      end
      for _, h in pairs(hots) do Wire(h) end
      -- each page has its own preview: the one in view is "the" preview




      holder:SetScript("OnUpdate", function()
        -- dragging: a part follows the mouse in the map's units; the map
        -- itself moves on your screen
        local h = MO.dragging
        if h and h.down and h:IsVisible() then
          local d = h.down
          local x, y = GetCursorPosition()
          if h.key == "map" then
            local m = pfUI.minimap
            local k = m:GetEffectiveScale() or 1
            local dx, dy = (x - d[1]) / k, (y - d[2]) / k
            if h.moved or math.abs(dx) + math.abs(dy) >= 3 then
              h.moved, h.dragged = true, true
              local top = (UIParent:GetTop() or 0) * (UIParent:GetEffectiveScale() or 1) / k
              m:ClearAllPoints()
              m:SetPoint("TOPLEFT", UIParent, "TOPLEFT", d[3] + dx, d[4] + dy - top)
            end
          else
            local k = (holder:GetEffectiveScale() or 1) * Scale()
            local dx, dy = (x - d[1]) / k, (y - d[2]) / k
            if h.moved or math.abs(dx) + math.abs(dy) >= 3 / Scale() then
              if not h.moved then MO.Wake(h.key) end
              h.moved, h.dragged = true, true
              map.MovePart(h.key, d[3] + dx, d[4] + dy)
              Layout()
            end
          end
        end
        -- spin the art
        for i = 1, 3 do
          local l = art[i]
          if l.tex and l.speed ~= 0 then
            l.angle = math.mod(l.angle + l.speed * (arg1 or 0), 360)
            Turn(l.tex, math.rad(l.angle))
          end
        end
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + .2

        Layout()
      end)
      Layout()

      -- what the mouse does, on screen
      local band = W.Row(pp, 20, 0, 3)
      local bg = band:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(band)
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      bg:SetVertexColor(ar, ag, ab, .22)
      local how = band:CreateFontString(nil, "OVERLAY")
      how:SetFont(W.UIFont(), 11, "OUTLINE")
      how:SetPoint("LEFT", band, "LEFT", 12, 0)
      local k = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
      how:SetText(k .. "Click|r  pick     " .. k .. "Drag|r  move (the map too)     " .. k .. "Shift + wheel|r  bigger / smaller     "
        .. k .. "Right-click|r  put it back")
      W.HowTo(pp, band, how:GetText(), nil, 0)
      W.Buttons(pp, {
        { "Put every part back", function()
          for _, part in ipairs(map.PARTS or {}) do map.ResetPart(part.key) end
          Layout()
          O:Refresh()
        end, 160, "Every button and text around the map goes back to pfUI's own place and size." },
      })
    end)
  end

  -- ---------------------------------------------------------------- map page

  -- a row of lit picture buttons (looks, shapes, art layers, parts)
  local function Tiles(p, list, perRow, w, h, isOn, onClick, tip)
    local btns, rows = {}, {}
    for r = 1, math.ceil(table.getn(list) / perRow) do rows[r] = W.Row(p, h + 2, 0, 4) end
    for i, it in ipairs(list) do
      local b = W.Button(rows[math.floor((i - 1) / perRow) + 1], it.icon and "" or it.label, w, h)
      b:SetPoint("LEFT", b:GetParent(), "LEFT", math.mod(i - 1, perRow) * (w + 6), 0)
      b.key = it.key
      if it.icon then
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetTexture(it.icon)
        t:SetWidth(h - 10)
        t:SetHeight(h - 10)
        t:SetPoint("CENTER", b, "CENTER", 0, 0)
        t:SetVertexColor(.85, .75, .5)
      end
      b:SetScript("OnClick", function() onClick(this.key) end)
      W.Tip(b, it.label, tip)
      btns[i] = b
    end
    local function Paint() for _, b in ipairs(btns) do W.Pick(b, isOn(b.key)) end end
    if rows[1] then
      rows[1]:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + .3
        Paint()
      end)
    end
    Paint()
    table.insert(p.items, { Refresh = Paint })
    return btns
  end

  local ART = {
    { "none", "None" },
    { "Spells\\AuraRune256", "Rune circle" }, { "Spells\\AuraRune256b", "Rune circle 2" },
    { "Spells\\AuraRune_A", "Rune circle A" }, { "Spells\\AuraRune_B", "Rune circle B" },
    { "Spells\\AuraRune_C", "Rune circle C" }, { "Spells\\AuraRune_D", "Rune circle D" },
    { "Spells\\Holy_Rune_128", "Holy rune" }, { "Spells\\Holy_Rune1", "Holy rune 2" },
    { "Spells\\Ice_Rune_128", "Frost rune" }, { "Spells\\Fire_Rune_128", "Fire rune" },
    { "Spells\\Nature_Rune_128", "Nature rune" }, { "Spells\\InnerFire_Rune_128", "Inner Fire rune" },
    { "Spells\\DemonRune6", "Demon rune" }, { "Spells\\DemonRune7", "Demon rune 2" },
    { "Spells\\Death_Rune", "Death rune" }, { "Spells\\starrune", "Star rune" },
    { "Spells\\Circle", "Circle" }, { "Spells\\DoubleRing128", "Double ring" },
    { "Spells\\WhiteRingThin128", "Thin ring" }, { "Spells\\WhiteRingFat128", "Fat ring" },
    { "Spells\\FireRing128", "Fire ring" }, { "Spells\\T_VFX_Ring_Bow_A", "Bow ring" },
    { "Spells\\GENERICGLOW64", "Soft glow" }, { "Spells\\Blue_GlowB", "Blue glow" },
    { "Spells\\GREEN_GLOW2", "Green glow" }, { "Spells\\Shockwave_Ice1", "Frost wave" },
    { "Spells\\ShockwaveWater1", "Water wave" }, { "Spells\\STARBURSTS", "Starbursts" },
  }
  local function ArtList()
    local out = {}
    for _, a in ipairs(ART) do table.insert(out, { key = a[1], label = a[2], icon = a[1] ~= "none" and a[1] or nil }) end
    return out
  end
  local function ArtName(tex)
    for _, a in ipairs(ART) do if a[1] == tex then return a[2] end end
    return "None"
  end

  local function BuildMap(p)
    W.Heading(p, "Minimap", { on = O.ModuleSwitch("minimap", "Minimap"), about = "The map's look: a ready-made style, its shape, border, the spell art around it, "
      .. "size and opacity. Buttons and texts around it are on \"Buttons and text\"." })
    Preview(p)
    -- (31 Oct 2026, user: menus "overwhelming")
    O.CardTabs(p, {
      { "look", "Look", "INV_Misc_Gem_Variety_01", { "Looks", "Shape and border", "Size, opacity and zoom" } },
      { "art", "Art", "Spell_Holy_InnerFire", { "Art" } },
      { "hide", "Hide by itself", "INV_Misc_Eye_01", { "Hide by itself" } },
    })
    -- (user, 24 Oct 2026: hidden by itself in battlegrounds, raids...)
    if pfUI.context and pfUI.context.MapCard then pfUI.context.MapCard(p, W) end

    W.Card(p, "Looks", { tip = "Shape, border and art in one click. Buttons, sizes and places stay as they are." })
    local looks = {}
    for _, pr in ipairs(map.PRESETS or {}) do table.insert(looks, { key = pr[1], label = pr[2], set = pr[3] }) end
    local function LookOn(key)
      local s = S()
      for _, l in ipairs(looks) do
        if l.key == key then
          for k, v in pairs(l.set) do if s[k] ~= v then return false end end
          return true
        end
      end
    end
    Tiles(p, looks, 5, 126, 22, LookOn, function(key) map.ApplyPreset(key) O:Refresh() end,
      "Shape, border and art in one click.")

    W.Card(p, "Shape and border", { tip = "Every part around the map can be dragged to fit any shape." })
    local shapes = {}
    for _, s in ipairs(SHAPES) do table.insert(shapes, { key = s.key, label = s.label, icon = ShapeArt(s.key) }) end
    Tiles(p, shapes, 11, 52, 40, function(key) return (S().shape or "square") == key end,
      function(key) S().shape = key U() O:Refresh() end, "Click to give the map this shape.")
    Drop(p, "Border", "pfUI's frame works on the square map only.", {
      { key = "pfui", label = "pfUI frame (square only)" }, { key = "outline", label = "Outline of the shape" }, { key = "none", label = "None" },
    }, S, "border")
    Color(p, "Outline colour", nil, function() return "outlinecolor" end)
    Chk(p, "Accent colour outline", "The outline takes pfUI Octo's accent colour.", S, "outlineaccent")

    W.Card(p, "Art", { tip = "Up to three layers of the game's spell art round the map. Pick a layer, then its art." })
    local layers = {}
    for i = 1, 3 do table.insert(layers, { key = i, label = "Layer " .. i }) end
    local tabs = Tiles(p, layers, 3, 140, 22, function(key) return MO.layer == key end,
      function(key) MO.layer = key O:Refresh() end, "Pick the layer to change.")
    -- the layer's art in its tab's name
    table.insert(p.items, { Refresh = function()
      for i, b in ipairs(tabs) do
        local tex = S()["art" .. i]
        b:SetText("Layer " .. i .. ((tex and tex ~= "none") and (": " .. ArtName(tex)) or ": off"))
      end
    end })
    local function L(suffix) return function() return "art" .. MO.layer .. suffix end end
    W.Dropdown(p, "Art", "Each choice shows its picture. None switches the layer off.", ArtList(),
      function() return S()[L("")()] end, function(v) S()[L("")()] = v U() O:Refresh() end)
    W.Check(p, "Over the map", "Off: under the map, showing only round its edge.",
      function() return S()[L("above")()] == "1" end, function(v) S()[L("above")()] = v and "1" or "0" U() end)
    Color(p, "Colour and opacity", nil, L("color"))
    W.Dropdown(p, "Blend", "Glow brightens what is under it; Normal paints over it.",
      { { key = "ADD", label = "Glow (add)" }, { key = "BLEND", label = "Normal" } },
      function() return S()[L("blend")()] end, function(v) S()[L("blend")()] = v U() end)
    W.Slider(p, "Size", "% of the map's size.", 50, 250, 5,
      function() return tonumber(S()[L("size")()]) or 130 end, function(v) S()[L("size")()] = tostring(v) U() end, Pct)
    W.Slider(p, "Spin", "Degrees a second; minus turns the other way.", -90, 90, 1,
      function() return tonumber(S()[L("speed")()]) or 0 end, function(v) S()[L("speed")()] = tostring(v) U() end,
      function(v) return v .. " / s" end)

    W.Card(p, "Size, opacity and zoom")
    Sld(p, "Map size", "Or Shift + wheel over the map in the preview.", 80, 400, 5, MM, "size", Px, MapSize)
    Sld(p, "Your arrow", "The size of your own arrow on the map.", .5, 3, .1, MM, "arrowscale", Alpha, MapSize)
    Sld(p, "Opacity", nil, .1, 1, .05, S, "alpha", Alpha)
    Sld(p, "Opacity in combat", nil, .1, 1, .05, S, "combatalpha", Alpha)
    Sld(p, "Zoom back out after", "The map zooms all the way out after this long (0 = never).", 0, 60, 1, S, "autozoom", Sec)
    O.TabFilter(p)
  end

  -- ---------------------------------------------------------------- buttons and text page

  -- each addon button: in the panel, left on the map, or hidden
  local PLACES = { { "panel", "Panel" }, { "map", "On map" }, { "hide", "Hidden" } }
  local function ButtonList(p)
    local rows = {}
    local note = W.Live(p, function()
      local ab = pfUI.addonbuttons
      if not ab or not ab.List then return "Addon buttons are off: tick Gather addon buttons and reload." end
      local n = table.getn(MO.found or {})
      return n == 0 and "No addon buttons found on the map yet." or (n .. " addon button" .. (n == 1 and "" or "s") .. " found - pick where each goes:")
    end)
    -- (30: 18 were found on the user's map and only 12 had rows)
    for i = 1, 30 do
      local row = W.Row(p, 22, 0, 2)
      row.name = W.Font(row:CreateFontString(nil, "OVERLAY"), 11, .85, .85, .85)
      row.name:SetPoint("LEFT", row, "LEFT", 4, 0)
      row.name:SetWidth(260)
      row.name:SetJustifyH("LEFT")
      row.btns = {}
      for j, pl in ipairs(PLACES) do
        local b = W.Button(row, pl[2], 80, 20)
        b:SetPoint("LEFT", row, "LEFT", 270 + (j - 1) * 86, 0)
        b.place = pl[1]
        b:SetScript("OnClick", function()
          local name = this:GetParent().button
          if name and pfUI.addonbuttons then
            pfUI.addonbuttons:SetPlace(name, this.place)
            local f = _G[name]
            local seen = (this.place == "map" and f and f.IsVisible) and (f:IsVisible() and " (showing)" or (" (|cffff5555not showing|r: " .. (pfUI.addonbuttons.Chain and pfUI.addonbuttons:Chain(name) or "?") .. ")")) or ""
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r map: " .. name .. " - " .. ((this.place == "panel" and "in the panel") or (this.place == "map" and "on the map") or "hidden") .. seen .. ".")
          end
          if MO.PaintButtons then MO.PaintButtons() end
        end)
        row.btns[j] = b
      end
      -- its own size (user, 25 Oct 2026: "sizeable individually ... a slider
      -- next to each option ... next to Hidden"); 0 = the size for all
      local s = W.SliderBar(row, 120)
      s:SetPoint("LEFT", row, "LEFT", 270 + 3 * 86 + 8, 0)
      s:SetMinMaxValues(0, 40)
      s:SetValueStep(1)
      s.text = W.Font(row:CreateFontString(nil, "OVERLAY"), 11, .85, .85, .85)
      s.text:SetPoint("LEFT", s, "RIGHT", 8, 0)
      s:SetScript("OnValueChanged", function()
        local v = math.floor((this:GetValue() or 0) + .5)
        this.text:SetText(v == 0 and "size: all" or (v .. " px"))
        if this.painting then return end
        local name = this:GetParent().button
        if name and pfUI.addonbuttons and pfUI.addonbuttons.SetSize then pfUI.addonbuttons:SetSize(name, v) end
      end)
      W.Tip(s, "Size", "This button's own size, on the map or in the panel. All the way left = the size for all.")
      row.size = s
      rows[i] = row
    end
    local function Paint()
      local ab = pfUI.addonbuttons
      MO.found = (ab and ab.List) and ab:List() or {}
      for i, row in ipairs(rows) do
        local name = MO.found[i]
        row.button = name
        -- (empty rows shrink away: the card is only as tall as its list)
        if name then
          row:SetHeight(22)
          row:Show()
          local pretty = string.gsub(string.gsub(name, "MinimapButton", ""), "Minimap", "")
          row.name:SetText(pretty ~= "" and pretty or name)
          local at = ab:GetPlace(name)
          for _, b in ipairs(row.btns) do W.Pick(b, b.place == at) end
          if row.size and ab.GetSize then
            row.size.painting = true
            row.size:SetValue(ab:GetSize(name))
            row.size.painting = nil
            local v = ab:GetSize(name)
            row.size.text:SetText(v == 0 and "size: all" or (v .. " px"))
            if at == "hide" then row.size:Hide() row.size.text:Hide() else row.size:Show() row.size.text:Show() end
          end
        else
          row:SetHeight(.1)
          row:Hide()
        end
      end
    end
    MO.PaintButtons = function()
      Paint()
      W.Measure(p)
    end
    Paint()
    table.insert(p.items, { Refresh = Paint })
    return note
  end

  local function BuildParts(p)
    W.Heading(p, "Buttons and text", { about = "Everything on and around the map. Pick a part - here or by clicking it "
      .. "in the preview - then set when it shows, its size and its place. Drag parts in the preview to fit any shape." })
    Preview(p)

    W.Card(p, "Part", { tip = "The part you picked. Click a part in the preview to pick it there." })
    local list = {}
    for _, k in ipairs(ORDER) do table.insert(list, { key = k, label = SHORT[k] }) end
    Tiles(p, list, 5, 126, 22, function(key) return MO.sel == key end,
      function(key) MO.sel = key O:Refresh() if MO.Layout then MO.Layout() end end, "Pick this part.")
    W.Live(p, function()
      return "Editing: |cffffffff" .. (NAMES[MO.sel] or MO.sel) .. "|r   shows " .. (MODEWORD[Mode(MO.sel)] or "always")
    end)
    local function Part() return map.Part and map.Part(MO.sel) end
    W.Dropdown(p, "Shows", "Mouse over the map: it shows while the mouse is over the map.", MODES,
      function() return Mode(MO.sel) end, function(v)
        -- (who pinged, the PvP icon and the bar are on or off)
        if v == "hover" and (MO.sel == "ping" or MO.sel == "pvp" or MO.sel == "bar") then v = "show" end
        SetMode(MO.sel, v)
        O:Refresh()
      end)
    W.Slider(p, "Size", "Or Shift + wheel over it in the preview.", 50, 250, 5,
      function() return tonumber(S()[MO.sel .. "scale"]) or 100 end, function(v) map.SizePart(MO.sel, v) end, Pct)
    W.Slider(p, "Left / right", "Or drag it in the preview.", -200, 200, 1,
      function() local pt = Part() if not pt then return 0 end local x = map.PartOffset(pt) return x end,
      function(v) local pt = Part() if not pt then return end local _, y = map.PartOffset(pt) map.MovePart(MO.sel, v, y) end, Px)
    W.Slider(p, "Up / down", nil, -200, 200, 1,
      function() local pt = Part() if not pt then return 0 end local _, y = map.PartOffset(pt) return y end,
      function(v) local pt = Part() if not pt then return end local x = map.PartOffset(pt) map.MovePart(MO.sel, x, v) end, Px)
    W.Buttons(p, { { "Put it back", function() map.ResetPart(MO.sel) O:Refresh() end, 110, "pfUI's own place and size for this part." } })

    W.Card(p, "Details", { tip = "Settings that belong to one part only." })
    Drop(p, "Clock time", nil, { { key = "local", label = "Local time" }, { key = "server", label = "Server time" } }, S, "clocktime")
    Drop(p, "Coordinates corner", "Picking a corner puts the coordinates in it.", DD("minimap_cords_position"), MM, "coordsloc", function()
      map.ResetPart("coords")
      O:Refresh()
    end)
    Drop(p, "Bar under the map says", "What the bar shows. Takes a reload.", DD("panel_values"), function() return C.panel.other end, "minimap", function(v)
      if v ~= "none" then S().barwas = v end
      U()
    end)
    Chk(p, "Tracking when off", "A question mark when no tracking is on. Takes a reload.", MM, "tracking_pulse", function() end)

    W.Card(p, "Addon buttons", { tip = "Other addons' minimap buttons, gathered into a panel the arrow opens." })
    local function ABU() if pfUI.addonbuttons and pfUI.addonbuttons.UpdateConfig then pfUI.addonbuttons:UpdateConfig() end U() end
    Chk(p, "Gather addon buttons", "Off: every addon button stays on the map. Takes a reload.", AB, "enable", function() end)
    Drop(p, "Panel opens", "The arrow moves to that edge unless you dragged it.", DD("addonbuttons_position"), AB, "position", function()
      map.ResetPart("abutton")
      ABU()
      O:Refresh()
    end)
    Chk(p, "Open at login", nil, AB, "showdefault", ABU)
    Chk(p, "Close in combat", nil, AB, "hideincombat", ABU)
    Sld(p, "Buttons a row", nil, 1, 20, 1, AB, "rowsize", nil, ABU)
    Sld(p, "Button size", "0 = as big as fits the map's width (they never grow then); more = that size in px.", 0, 48, 1, AB, "size",
      function(v) return (tonumber(v) or 0) == 0 and "fit" or (v .. " px") end, ABU)
    Sld(p, "Gap", nil, 0, 10, 1, AB, "spacing", Px, ABU)
    ButtonList(p)
    W.Live(p, function()
      return "|cff888888A button still on the map? Hold the mouse over it and type |r/abp add|cff888888 - it joins the list.|r"
    end)
  end

  -- (replaced first: AddPage rebuilds the topic list, which must not see
  -- pfUI's own Minimap category under the same name)
  O.replaced[T["Minimap"]] = true
  O:AddPage("Minimap", "mmmap", "Map", BuildMap)
  O:AddPage("Minimap", "mmparts", "Buttons and text", BuildParts)
end)
