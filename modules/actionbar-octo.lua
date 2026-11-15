pfUI:RegisterModule("actionbar-octo", "vanilla:tbc", function ()
  -- pfUI Octo action bars: Bartender4's ideas on pfUI's own bars (user, 22 Oct
  -- 2026: "rebuilding the Action bar module ... like Bartender, with as many
  -- options and looks"). Bartender4 is All Rights Reserved: nothing of it is
  -- copied, only its feature list was read. pfUI's actionbar.lua builds the
  -- bars as before; after each of its updates this adds:
  --   per bar   scale, opacity, fade to a chosen opacity on mouse-off (pfUI's
  --             autohide hid them fully), visibility rules: in / out of
  --             combat, with / without a pet, only with a target, hidden
  --             while stealthed
  --   buttons   border skins (as the nameplates'), icon zoom
  --   looks     one-click styles (pfUI.barsOcto.PRESETS)
  -- Settings: C.bars["barN"] (scale, alpha, fadeto, vis_*) and C.bars (skin,
  -- zoom, look). Options: Action Bars (actionbar-options.lua).
  if not pfUI.bars then return end
  local BARS = pfUI.bars
  local AB = {}
  pfUI.barsOcto = AB

  AB.NAMES = { [1] = "Main bar", [6] = "Top bar", [5] = "Left bar", [3] = "Right bar", [4] = "Vertical bar",
    [2] = "Paging bar", [7] = "Stance bar 1", [8] = "Stance bar 2", [9] = "Stance bar 3", [10] = "Stance bar 4",
    [11] = "Shapeshift bar", [12] = "Pet bar" }
  -- in the order the options list them
  AB.ORDER = { 1, 6, 5, 3, 4, 2, 7, 8, 9, 10, 11, 12 }

  local function DB(i) return C.bars["bar" .. i] end

  -- ---------------------------------------------------------------- button skins

  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local ART = "Interface\\AddOns\\pfUI\\img\\bars\\"
  AB.ART = ART

  -- A skin is a set of parts drawn round and over each button (25 Oct 2026,
  -- user: "Why is neon looking like this ... add more bar looks from other
  -- addons"). Neon used to be pfUI's glow texture 6 px wide in the accent
  -- colour - for a priest the class colour is white, so every button, empty
  -- ones too, sat in a thick grey-white box. Parts (each with its own colour
  -- setting C.bars.skin_<part>, "" = the skin's own colour):
  --   edge   { size, off, "bevel" }  a line off px out from the icon; bevel =
  --          light top and left, dark bottom and right (a raised frame)
  --   line2  a 1 px outline round the edge line (two-tone)
  --   outer  { size, off, "glow" | "glow2" }  a soft halo or shadow outside
  --   gloss  a shine over the icon's top    shade  dark inner edges
  --   frame  the game's own button frame (UI-Quickslot2, as Bartender's and
  --          Dominos' default buttons)
  -- Ideas from Masque's skins (Apathy: thin square lines; Entropy: the same in
  -- metal colours; Dream; Zoomed), ElvUI's pixel borders and shadows and the
  -- game's frame. Only the ideas: nothing of their code or art is used.
  -- Everything hangs on pfUI's backdrop, so a hidden empty slot hides it all.
  AB.SKINS = {
    { key = "pfui", label = "Thin black (pfUI)" },
    { key = "shadow", label = "Soft shadow", outer = { 5, 0, "glow2" }, colors = { outer = "0,0,0,.85" } },
    { key = "thick", label = "Thick black", edge = { 2, 0 }, colors = { edge = "0,0,0,1" } },
    { key = "accent", label = "Thin colour line", edge = { 1, 0 }, colors = { edge = "accent" } },
    { key = "outlined", label = "Colour line, black outline", edge = { 1, 0 }, line2 = true,
      colors = { edge = "accent", line2 = "0,0,0,1" } },
    { key = "neon", label = "Neon", edge = { 1, 0 }, outer = { 5, 1, "glow" }, shade = true,
      colors = { edge = ".2,.95,1,1", outer = ".05,.75,1,.6", shade = "0,0,0,.35" } },
    { key = "gold", label = "Gold line", edge = { 1, 0 }, outer = { 4, 1, "glow2" }, colors = { edge = ".9,.72,.3,1", outer = "0,0,0,.7" } },
    { key = "gloss", label = "Glossy", edge = { 1, 0 }, gloss = true, shade = true,
      colors = { edge = "0,0,0,1", gloss = "1,1,1,.4", shade = "0,0,0,.3" } },
    { key = "bevel", label = "Bevel", edge = { 2, 0, "bevel" }, shade = true, colors = { edge = ".5,.52,.56,1", shade = "0,0,0,.25" } },
    { key = "steel", label = "Metal", edge = { 3, 0, "bevel" }, line2 = true, outer = { 4, 3, "glow2" }, gloss = true,
      colors = { edge = ".7,.73,.8,1", line2 = "0,0,0,1", outer = "0,0,0,.6", gloss = "1,1,1,.18" } },
    { key = "glass", label = "Glass", edge = { 1, 0 }, gloss = true, colors = { edge = "1,1,1,.4", gloss = "1,1,1,.6" } },
    { key = "dark", label = "Dark frame", edge = { 3, 0 }, line2 = true, outer = { 4, 3, "glow2" }, shade = true,
      colors = { edge = ".08,.08,.09,1", line2 = ".32,.33,.36,1", outer = "0,0,0,.6", shade = "0,0,0,.4" } },
    { key = "blizz", label = "Game frame", frame = true, colors = { frame = "1,1,1,1" } },
  }
  local SKINBY = {}
  for _, s in ipairs(AB.SKINS) do SKINBY[s.key] = s end
  AB.SKINBY = SKINBY
  -- the parts with a colour each, in the order the options show them
  AB.PARTS = { "edge", "line2", "outer", "gloss", "shade", "frame" }

  local function ClassRGB()
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
  end

  -- "r,g,b,a", or "accent" for the UI's accent colour
  local function ParseColor(str)
    if str == "accent" then
      if GetAccentColor then
        local r, g, b = GetAccentColor()
        return r, g, b, 1
      end
      return .2, .7, 1, 1
    end
    local r, g, b, a = GetStringColor(str or "1,1,1,1")
    return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
  end
  AB.ParseColor = ParseColor

  -- a part's colour: your setting, else the skin's own (own = true: always
  -- the skin's own, for the look tiles)
  function AB.PartColor(sk, part, own)
    local str = not own and C.bars["skin_" .. part]
    if not str or str == "" then str = sk.colors and sk.colors[part] or "1,1,1,1" end
    local r, g, b, a = ParseColor(str)
    if not own and C.bars["skin_" .. part .. "_class"] == "1" then
      local cr, cg, cb = ClassRGB()
      if cr then r, g, b = cr, cg, cb end
    end
    return r, g, b, a
  end
  -- edge / outer thickness: your setting, else the skin's own
  function AB.PartSize(sk, part, own)
    local v = not own and tonumber(C.bars["skin_" .. part .. "size"])
    return v or (sk[part] and sk[part][1]) or 0
  end

  -- four lines: the band from off to off + size px outside f
  local function Band(t, first, f, size, off, r, g, b, a, bevel)
    local o = off + size
    local top, bottom, left, right = t[first], t[first + 1], t[first + 2], t[first + 3]
    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", f, "TOPLEFT", -o, o) top:SetPoint("TOPRIGHT", f, "TOPRIGHT", o, o) top:SetHeight(size)
    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -o, -o) bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", o, -o) bottom:SetHeight(size)
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", f, "TOPLEFT", -o, o - size) left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -o, -o + size) left:SetWidth(size)
    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", f, "TOPRIGHT", o, o - size) right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", o, -o + size) right:SetWidth(size)
    if bevel then
      local lr, lg, lb = math.min(1, r * 1.45 + .08), math.min(1, g * 1.45 + .08), math.min(1, b * 1.45 + .08)
      top:SetVertexColor(lr, lg, lb, a) left:SetVertexColor(lr, lg, lb, a)
      bottom:SetVertexColor(r * .4, g * .4, b * .4, a) right:SetVertexColor(r * .4, g * .4, b * .4, a)
    else
      for i = first, first + 3 do t[i]:SetVertexColor(r, g, b, a) end
    end
    for i = first, first + 3 do t[i]:Show() end
  end

  -- gloss, shade and the game frame are drawn on the button itself (over the
  -- icon, under its texts) and follow pfUI's backdrop: shown with it, hidden
  -- with it (pfUI hides the backdrop of an empty slot it does not show)
  local OVER = { "octoGloss", "octoShade", "octoFrame" }
  local function OverShow()
    local f = this:GetParent()
    for _, k in ipairs(OVER) do
      local t = f and f[k]
      if t then if t.want then t:Show() else t:Hide() end end
    end
  end
  local function OverHide()
    local f = this:GetParent()
    for _, k in ipairs(OVER) do if f and f[k] then f[k]:Hide() end end
  end
  local function Over(f, key, tex, blend)
    local t = f[key]
    if not t then
      t = f:CreateTexture(nil, "BORDER")
      t:SetTexture(tex)
      t:SetBlendMode(blend)
      f[key] = t
    end
    return t
  end

  -- draw skin `key` on button f (own: in the skin's own colours and sizes)
  function AB.Draw(f, key, own)
    local sk = SKINBY[key or "pfui"] or SKINBY.pfui
    local holder = f.backdrop or f
    if holder ~= f and not holder.octoOver then
      holder.octoOver = true
      holder:SetScript("OnShow", OverShow)
      holder:SetScript("OnHide", OverHide)
    end
    -- edge and its outline
    local es = sk.edge and AB.PartSize(sk, "edge", own) or 0
    if es > 0 then
      if not f.octoSkin then
        f.octoSkin = CreateFrame("Frame", nil, holder)
        f.octoSkin.t = {}
        for i = 1, 8 do
          f.octoSkin.t[i] = f.octoSkin:CreateTexture(nil, "OVERLAY")
          f.octoSkin.t[i]:SetTexture(WHITE)
        end
      end
      local s = f.octoSkin
      s:SetFrameLevel(holder:GetFrameLevel() + 1)
      local off = sk.edge[2] or 0
      local r, g, b, a = AB.PartColor(sk, "edge", own)
      Band(s.t, 1, f, es, off, r, g, b, a, sk.edge[3] == "bevel")
      if sk.line2 then
        local r2, g2, b2, a2 = AB.PartColor(sk, "line2", own)
        Band(s.t, 5, f, 1, off + es, r2, g2, b2, a2)
      else
        for i = 5, 8 do s.t[i]:Hide() end
      end
      s:Show()
    elseif f.octoSkin then
      f.octoSkin:Hide()
    end
    -- halo / shadow
    local os = sk.outer and AB.PartSize(sk, "outer", own) or 0
    if os > 0 then
      if not f.octoOuter then f.octoOuter = CreateFrame("Frame", nil, holder) end
      local o = f.octoOuter
      o:SetFrameLevel(holder:GetFrameLevel())
      local d = (sk.outer[2] or 0) + os
      o:ClearAllPoints()
      o:SetPoint("TOPLEFT", f, "TOPLEFT", -d, d)
      o:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", d, -d)
      o:SetBackdrop({ edgeFile = pfUI.media["img:" .. (sk.outer[3] or "glow2")], edgeSize = os,
                      insets = { left = 0, right = 0, top = 0, bottom = 0 } })
      o:SetBackdropBorderColor(AB.PartColor(sk, "outer", own))
      o:Show()
    elseif f.octoOuter then
      f.octoOuter:Hide()
    end
    -- over the icon
    local showing = holder == f or holder:IsShown()
    local t = Over(f, "octoGloss", ART .. "btn-gloss", "ADD")
    t:SetAllPoints(f)
    t:SetVertexColor(AB.PartColor(sk, "gloss", own))
    t.want = sk.gloss and true or nil
    t = Over(f, "octoShade", ART .. "btn-inner", "BLEND")
    t:SetAllPoints(f)
    t:SetVertexColor(AB.PartColor(sk, "shade", own))
    t.want = sk.shade and true or nil
    -- (the game's frame is 66 px round a 36 px button)
    t = Over(f, "octoFrame", "Interface\\Buttons\\UI-Quickslot2", "BLEND")
    local w = tonumber(f:GetWidth()) or 36
    t:ClearAllPoints()
    t:SetPoint("CENTER", f, "CENTER", 0, 0)
    t:SetWidth(w * 66 / 36)
    t:SetHeight(w * 66 / 36)
    t:SetVertexColor(AB.PartColor(sk, "frame", own))
    t.want = sk.frame and true or nil
    for _, k in ipairs(OVER) do
      if f[k].want and showing then f[k]:Show() else f[k]:Hide() end
    end
  end

  local function Skin(f) AB.Draw(f, C.bars.skin) end

  local function Zoom(f)
    if not f.icon then return end
    local z = tonumber(C.bars.zoom) or .08
    f.icon:SetTexCoord(z, 1 - z, z, 1 - z)
  end

  AB.Skin, AB.Zoom = Skin, Zoom

  -- ---------------------------------------------------------------- effects
  -- (user, 22 Oct 2026: "build the action bar ideas from EllesmereUI": press
  -- and hover looks, proc glows, cooldown swipe and edge, empty slot fill,
  -- equipped border. EllesmereUI's licence reserves its rights: only its
  -- feature list was read. Art: tools\MakePlateArt.ps1 -> img\bars.)

  -- a setting's colour, or the class colour when its "_class" switch is on
  local function Col(key)
    local r, g, b, a = GetStringColor(C.bars[key] or "1,1,1,1")
    r, g, b, a = tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
    if C.bars[key .. "_class"] == "1" then
      local _, class = UnitClass("player")
      local c = class and RAID_CLASS_COLORS[class]
      if c then r, g, b = c.r, c.g, c.b end
    end
    return r, g, b, a
  end
  AB.Col = Col

  -- hover and press looks
  AB.STYLES = {
    { key = "pfui", label = "pfUI glow" },
    { key = "light", label = "Light", add = .25 },
    { key = "medium", label = "Medium", add = .45 },
    { key = "strong", label = "Strong", add = .7 },
    { key = "fill", label = "Solid colour" },
    { key = "border", label = "Border only" },
    { key = "inner", label = "Inner glow", tex = "btn-inner", add = 1 },
    { key = "gloss", label = "Gloss", tex = "btn-gloss", add = 1 },
    { key = "corners", label = "Corners", tex = "btn-corners" },
    { key = "none", label = "None" },
  }
  local STYLEBY = {}
  for _, s in ipairs(AB.STYLES) do STYLEBY[s.key] = s end

  -- a layer over a button: a fill and four edge lines
  function AB.Layer(parent, level)
    local l = CreateFrame("Frame", nil, parent)
    l:SetAllPoints(parent)
    l:SetFrameLevel(parent:GetFrameLevel() + (level or 1))
    l.fill = l:CreateTexture(nil, "OVERLAY")
    l.fill:SetAllPoints(l)
    l.edges = {}
    for i = 1, 4 do
      l.edges[i] = l:CreateTexture(nil, "OVERLAY")
      l.edges[i]:SetTexture(WHITE)
    end
    return l
  end

  -- a layer's four edge lines, px thick, in one colour
  function AB.Edges(l, px, r, g, b, a)
    local e = l.edges
    e[1]:ClearAllPoints() e[1]:SetPoint("TOPLEFT", l, "TOPLEFT") e[1]:SetPoint("TOPRIGHT", l, "TOPRIGHT") e[1]:SetHeight(px)
    e[2]:ClearAllPoints() e[2]:SetPoint("BOTTOMLEFT", l, "BOTTOMLEFT") e[2]:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT") e[2]:SetHeight(px)
    e[3]:ClearAllPoints() e[3]:SetPoint("TOPLEFT", l, "TOPLEFT") e[3]:SetPoint("BOTTOMLEFT", l, "BOTTOMLEFT") e[3]:SetWidth(px)
    e[4]:ClearAllPoints() e[4]:SetPoint("TOPRIGHT", l, "TOPRIGHT") e[4]:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT") e[4]:SetWidth(px)
    for i = 1, 4 do e[i]:SetVertexColor(r, g, b, a or 1) e[i]:Show() end
  end

  -- paint a layer in a style; prefix: "hover" / "press" (C.bars keys
  -- <prefix>_style, _color, _color_class, _size). Returns false for pfUI's own.
  function AB.Paint(l, prefix, style)
    style = style or C.bars[prefix .. "_style"] or "pfui"
    local s = STYLEBY[style] or STYLEBY.pfui
    local r, g, b, a = Col(prefix .. "_color")
    l.fill:Hide()
    for i = 1, 4 do l.edges[i]:Hide() end
    if s.key == "pfui" or s.key == "none" then return s.key == "none" end
    if s.key == "border" then
      AB.Edges(l, tonumber(C.bars[prefix .. "_size"]) or 1, r, g, b, a)
      return true
    end
    l.fill:SetTexture(s.tex and (ART .. s.tex) or WHITE)
    l.fill:SetBlendMode(s.add and "ADD" or "BLEND")
    l.fill:SetVertexColor(r, g, b, a * (s.add or 1))
    l.fill:Show()
    return true
  end

  -- the press layer shows while the button is held (mouse or key)
  local function PressDown() local p = this.octoPress if p and p.on then p:Show() p.untilT = GetTime() + 3 end end
  local function PressUp() if this.octoPress then this.octoPress:Hide() end end
  local function PressKey()
    local p = _G.this.octoPress
    if not (p and p.on) then return end
    if keystate == "down" then
      p:Show()
      p.untilT = GetTime() + 3
    elseif keystate == "up" then
      p:Hide()
    end
  end
  -- (a press never sticks: a lost key-up ends it after 3 s)
  local function PressWatch() if GetTime() > (this.untilT or 0) then this:Hide() end end

  -- slot backgrounds, under the icon
  AB.SLOTS = {
    { key = "pfui", label = "pfUI's" },
    { key = "solid", label = "Solid colour" },
    { key = "grad", label = "Gradient", tex = "btn-grad" },
    { key = "stripes", label = "Stripes", tex = "btn-stripes" },
    { key = "dots", label = "Dots", tex = "btn-dots" },
    { key = "game", label = "The game's empty slot", path = "Interface\\Buttons\\UI-Quickslot" },
  }
  local SLOTBY = {}
  for _, s in ipairs(AB.SLOTS) do SLOTBY[s.key] = s end
  function AB.Slot(f, holder, style)
    holder = holder or f.backdrop or f
    local s = SLOTBY[style or C.bars.slot_style or "pfui"]
    if not s or s.key == "pfui" then
      if f.octoSlot then f.octoSlot:Hide() end
      return
    end
    if not f.octoSlot then
      f.octoSlot = holder:CreateTexture(nil, "ARTWORK")
      f.octoSlot:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
      f.octoSlot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    end
    f.octoSlot:SetTexture(s.path or (s.tex and (ART .. s.tex)) or WHITE)
    -- (the game's slot is a picture: its own colours, a tint only)
    if s.path then
      -- (the slot is the middle of its 64 px picture: unverified crop)
      f.octoSlot:SetTexCoord(.14, .86, .14, .86)
      local r, g, b = Col("slot_color")
      f.octoSlot:SetVertexColor(math.min(1, r + .6), math.min(1, g + .6), math.min(1, b + .6), 1)
    else
      f.octoSlot:SetTexCoord(0, 1, 0, 1)
      f.octoSlot:SetVertexColor(Col("slot_color"))
    end
    f.octoSlot:Show()
  end

  -- ------------------------------------------------ proc glows

  AB.GLOWS = {
    { key = "ants", label = "Marching lines" },
    { key = "pulse", label = "Pulsing inner glow" },
    { key = "shine", label = "Circling sparks" },
    { key = "border", label = "Soft outer glow" },
  }

  -- ants: dashes running round the edge
  local function Ants(g, t)
    local f = g:GetParent()
    local w, h = tonumber(f:GetWidth()) or 36, tonumber(f:GetHeight()) or 36
    local per = 2 * (w + h)
    local n = math.max(1, math.min(16, tonumber(C.bars.glow_lines) or 8))
    local th = tonumber(C.bars.glow_thick) or 2
    local len = per / n / 2
    local shift = math.mod(t * (tonumber(C.bars.glow_speed) or 4) * 10, per)
    for i = 1, 16 do
      local d = g.dash[i]
      if i > n then
        d:Hide()
      else
        -- start of the dash along the edge, clockwise from the top left
        local p = math.mod(shift + (i - 1) * per / n, per)
        local l = len
        d:ClearAllPoints()
        if p < w then
          l = math.min(l, w - p)
          d:SetPoint("TOPLEFT", f, "TOPLEFT", p, 0) d:SetWidth(l) d:SetHeight(th)
        elseif p < w + h then
          p = p - w
          l = math.min(l, h - p)
          d:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -p) d:SetWidth(th) d:SetHeight(l)
        elseif p < 2 * w + h then
          p = p - w - h
          l = math.min(l, w - p)
          d:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -p, 0) d:SetWidth(l) d:SetHeight(th)
        else
          p = p - 2 * w - h
          l = math.min(l, h - p)
          d:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, p) d:SetWidth(th) d:SetHeight(l)
        end
        d:Show()
      end
    end
  end

  -- shine: four sparks circling the edge
  local function Shine(g, t)
    local f = g:GetParent()
    local w, h = tonumber(f:GetWidth()) or 36, tonumber(f:GetHeight()) or 36
    local per = 2 * (w + h)
    local shift = math.mod(t * (tonumber(C.bars.glow_speed) or 4) * 8, per)
    for i = 1, 4 do
      local p = math.mod(shift + (i - 1) * per / 4, per)
      local x, y
      if p < w then x, y = p, 0
      elseif p < w + h then x, y = w, -(p - w)
      elseif p < 2 * w + h then x, y = w - (p - w - h), -h
      else x, y = 0, -(h - (p - 2 * w - h)) end
      local s = g.spark[i]
      s:ClearAllPoints()
      s:SetPoint("CENTER", f, "TOPLEFT", x, y)
      s:Show()
    end
  end

  local function GlowUpdate()
    local g = this
    local t = GetTime() - (g.start or 0)
    local style = C.bars.glow_style or "ants"
    local speed = tonumber(C.bars.glow_speed) or 4
    if style == "ants" then Ants(g, t)
    elseif style == "shine" then Shine(g, t)
    else
      local pulse = .55 + .45 * math.sin(t * speed * 1.2)
      if style == "pulse" then g.inner:SetAlpha(pulse) else g.outer:SetAlpha(pulse) end
    end
    -- the burst as it starts: a ring grows and fades
    if g.burst:IsShown() then
      local k = t / .4
      if k >= 1 then
        g.burst:Hide()
      else
        local sz = (tonumber(g:GetParent():GetWidth()) or 36) * (1 + k)
        g.burst:SetWidth(sz) g.burst:SetHeight(sz)
        g.burst:SetAlpha(1 - k)
      end
    end
  end

  function AB.Glow(f, on)
    local g = f.octoGlow
    if not on then
      if g and g:IsShown() then g:Hide() end
      return
    end
    if not g then
      g = CreateFrame("Frame", nil, f)
      g:SetAllPoints(f)
      g:SetFrameLevel(f:GetFrameLevel() + 4)
      g.dash = {}
      for i = 1, 16 do g.dash[i] = g:CreateTexture(nil, "OVERLAY") g.dash[i]:SetTexture(WHITE) end
      g.spark = {}
      for i = 1, 4 do
        g.spark[i] = g:CreateTexture(nil, "OVERLAY")
        g.spark[i]:SetTexture("Interface\\AddOns\\pfUI\\img\\plates\\cp-glow")
        g.spark[i]:SetBlendMode("ADD")
      end
      g.inner = g:CreateTexture(nil, "OVERLAY")
      g.inner:SetAllPoints(g)
      g.inner:SetTexture(ART .. "btn-inner")
      g.inner:SetBlendMode("ADD")
      g.outer = CreateFrame("Frame", nil, g)
      g.outer:SetPoint("TOPLEFT", g, "TOPLEFT", -6, 6)
      g.outer:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", 6, -6)
      g.outer:SetBackdrop({ edgeFile = pfUI.media["img:glow"], edgeSize = 8 })
      g.burst = g:CreateTexture(nil, "OVERLAY")
      g.burst:SetPoint("CENTER", g, "CENTER")
      g.burst:SetTexture(ART .. "btn-ring")
      g.burst:SetBlendMode("ADD")
      g:SetScript("OnUpdate", GlowUpdate)
      f.octoGlow = g
    end
    if g:IsShown() and g.lit then return end
    -- (re)paint for the style picked now
    local style = C.bars.glow_style or "ants"
    local r, gg, b, a = Col("glow_color")
    local th = tonumber(C.bars.glow_thick) or 2
    for i = 1, 16 do g.dash[i]:SetVertexColor(r, gg, b, a) g.dash[i]:Hide() end
    for i = 1, 4 do
      g.spark[i]:SetVertexColor(r, gg, b, a)
      g.spark[i]:SetWidth(th * 5) g.spark[i]:SetHeight(th * 5)
      g.spark[i]:Hide()
    end
    g.inner:SetVertexColor(r, gg, b, a)
    if style == "pulse" then g.inner:Show() else g.inner:Hide() end
    g.outer:SetBackdropBorderColor(r, gg, b, a)
    if style == "border" then g.outer:Show() else g.outer:Hide() end
    g.burst:SetVertexColor(r, gg, b, a)
    if C.bars.glow_burst == "1" then g.burst:Show() else g.burst:Hide() end
    g.start = GetTime()
    g.lit = true
    g:Show()
  end
  -- call after a glow setting changes, so lit glows repaint
  function AB.GlowRepaint()
    for _, f in pairs(BARS.buttons or {}) do
      if f.octoGlow then f.octoGlow.lit = nil end
    end
  end

  -- what glows: reactive abilities while usable, and spells a proc made free
  -- (icon names, lower case, without "interface\icons\")
  AB.REACTIVE = {
    ability_meleedamage = true,        -- Overpower
    ability_warrior_revenge = true,    -- Revenge
    inv_sword_48 = true,               -- Execute
    ability_warrior_challange = true,  -- Riposte, Counterattack
    ability_hunter_swiftstrike = true, -- Mongoose Bite
    ability_thunderclap = true,        -- Hammer of Wrath
  }
  -- buff icon -> the spell it lights
  AB.PROCS = {
    spell_shadow_twilight = "spell_shadow_shadowbolt", -- Shadow Trance (Nightfall)
  }
  -- the same by the buff's spell id (ClassicAPI): exact, whatever the icon
  AB.PROC_IDS = {
    [17941] = "spell_shadow_shadowbolt", -- Shadow Trance (Nightfall)
  }
  local function Icon(tex)
    if not tex then return end
    local _, _, name = string.find(string.lower(tex), "([^\\]+)$")
    return name
  end
  AB.Icon = Icon

  local procLit = {}
  local function ScanProcs()
    for k in pairs(procLit) do procLit[k] = nil end
    if libclient and libclient.HasClassicAPI() then
      for id, lit in pairs(AB.PROC_IDS) do
        if libclient.PlayerAura(id) then procLit[lit] = true end
      end
    end
    for i = 1, 32 do
      local tex = UnitBuff("player", i)
      if not tex then break end
      local lit = AB.PROCS[Icon(tex) or ""]
      if lit then procLit[lit] = true end
    end
  end

  function AB.ShouldGlow(f)
    if not f or not f.id or (f.bar and f.bar > 10) then return false end
    local icon = Icon(f.texture)
    if not icon then return false end
    if GetTime() < (AB.testUntil or 0) then return true end
    if C.bars.glow_procs == "1" and procLit[icon] then return true end
    if C.bars.glow_reactive == "1" and AB.REACTIVE[icon] then
      local usable = IsUsableAction(f.id)
      return usable and true or false
    end
    if C.bars.glow_reactive == "1" or (C.bars.glow_names or "") ~= "" then
      local name = AB.SlotName(f.id, f.texture)
      if name and ((C.bars.glow_reactive == "1" and AB.REACTIVE_NAMES[name]) or AB.OwnNames()[name]) then
        local usable = IsUsableAction(f.id)
        return usable and true or false
      end
    end
    return false
  end

  -- reactive spells found by name (their icon is shared with other spells)
  AB.REACTIVE_NAMES = {
    ["arcane surge"] = true, -- usable after an enemy resists your spell
  }
  -- the player's own list: C.bars.glow_names = "Name, Name"
  local ownText, ownSet = nil, {}
  function AB.OwnNames()
    local t = C.bars.glow_names or ""
    if t ~= ownText then
      ownText, ownSet = t, {}
      for n in string.gfind(t, "[^,;]+") do
        n = string.lower(string.gsub(string.gsub(n, "^%s+", ""), "%s+$", ""))
        if n ~= "" then ownSet[n] = true end
      end
    end
    return ownSet
  end
  -- spell name on an action slot, read once per slot + icon
  local nameOf = {}
  function AB.SlotName(slot, tex)
    local c = nameOf[slot]
    if c and c.tex == tex then return c.name end
    local name
    -- never a tooltip scan on a macro: macro add-ons (SuperCleveRoidMacros) work out the
    -- macro's conditions on every SetAction (Geekoi, 15 Nov 2026: Pick Pocket macros froze)
    if GetActionText(slot) then
      nameOf[slot] = { tex = tex }
      return nil
    end
    if pfUI.keymap and pfUI.keymap.ActionSpell then
      name = pfUI.keymap.ActionSpell(slot)
    end
    name = name and string.lower(name) or nil
    nameOf[slot] = { tex = tex, name = name }
    return name
  end

  -- ------------------------------------------------ cooldown swipe

  AB.CDSTYLES = {
    { key = "clock", label = "Clock (game)" },
    { key = "drain", label = "Drains down" },
    { key = "rise", label = "Fills up" },
    { key = "fade", label = "Fades out" },
    { key = "none", label = "None" },
  }

  local function DrainUpdate()
    local d = this
    local left = (d.start + d.duration) - GetTime()
    if left <= 0 or d.duration <= 0 then d:Hide() return end
    local frac = left / d.duration
    local f = d:GetParent()
    local h = tonumber(f:GetHeight()) or 36
    local style = d.style
    if style == "fade" then
      d.dark:SetHeight(h)
      d.dark:SetAlpha(frac)
      d.edge:Hide()
      return
    end
    d.dark:SetAlpha(1)
    d.dark:SetHeight(math.max(.01, h * frac))
  end

  -- start / stop the swipe on a button (pfUI's CooldownFrame_SetTimer calls)
  function AB.Drain(f, start, duration, enable)
    local style = C.bars.cd_style or "clock"
    local d = f.octoDrain
    local gcd = tonumber(C.appearance.cd.threshold) or 1.5
    if style == "clock" or style == "none" or not start or start <= 0 or not duration or duration < gcd or enable == 0 then
      if d then d:Hide() end
      return
    end
    if not d then
      d = CreateFrame("Frame", nil, f)
      d:SetAllPoints(f)
      d:SetFrameLevel(f:GetFrameLevel() + 1)
      d.dark = d:CreateTexture(nil, "ARTWORK")
      d.dark:SetTexture(WHITE)
      d.edge = d:CreateTexture(nil, "OVERLAY")
      d.edge:SetTexture(ART .. "btn-edge")
      d.edge:SetBlendMode("ADD")
      d:SetScript("OnUpdate", DrainUpdate)
      f.octoDrain = d
    end
    d.style = style
    d.start, d.duration = start, duration
    d.dark:ClearAllPoints()
    d.edge:ClearAllPoints()
    -- drain: the dark part shrinks down to the bottom; rise: up to the top
    local anchor = style == "rise" and "TOP" or "BOTTOM"
    d.dark:SetPoint(anchor .. "LEFT", d, anchor .. "LEFT")
    d.dark:SetPoint(anchor .. "RIGHT", d, anchor .. "RIGHT")
    d.dark:SetVertexColor(Col("cd_color"))
    local other = anchor == "TOP" and "BOTTOM" or "TOP"
    d.edge:SetPoint("LEFT", d.dark, other .. "LEFT", 0, 0)
    d.edge:SetPoint("RIGHT", d.dark, other .. "RIGHT", 0, 0)
    d.edge:SetHeight(math.max(4, (tonumber(f:GetHeight()) or 36) / 5))
    d.edge:SetVertexColor(Col("cd_edgecolor"))
    if C.bars.cd_edge == "1" and style ~= "fade" then d.edge:Show() else d.edge:Hide() end
    d:Show()
  end

  hooksecurefunc("CooldownFrame_SetTimer", function(cd, start, duration, enable)
    local f = cd and cd.octoButton
    if f then AB.Drain(f, start, duration, enable) end
  end)

  -- ------------------------------------------------ equipped border

  AB.EQSTYLES = {
    { key = "fill", label = "Green tint (pfUI)" },
    { key = "border", label = "Quality border" },
    { key = "both", label = "Tint and border" },
    { key = "none", label = "None" },
  }
  local scan
  local quality = {}
  -- the item's quality colour: the scanning tooltip's name line
  function AB.Quality(f)
    local key = (f.texture or "") .. (f.id or 0)
    if quality[key] then return unpack(quality[key]) end
    if not scan then
      scan = CreateFrame("GameTooltip", "pfOctoBarScan", nil, "GameTooltipTemplate")
    end
    local r, g, b = .2, .8, .2
    if scan.SetAction and f.id and not GetActionText(f.id) then
      scan:SetOwner(WorldFrame, "ANCHOR_NONE")
      scan:SetAction(f.id)
      local line = _G["pfOctoBarScanTextLeft1"]
      if line and line.GetTextColor then
        local lr, lg, lb = line:GetTextColor()
        if lr then r, g, b = lr, lg, lb end
      end
      scan:Hide()
    end
    quality[key] = { r, g, b }
    return r, g, b
  end

  function AB.Equipped(f)
    if not f.equipped then return end
    local style = C.bars.eq_style or "fill"
    local on = f.equipped:IsShown()
    f.equipped:SetAlpha((style == "fill" or style == "both") and 1 or 0)
    local want = on and (style == "border" or style == "both")
    if not want then
      if f.octoEq then f.octoEq:Hide() end
      return
    end
    if not f.octoEq then f.octoEq = AB.Layer(f, 3) end
    local l = f.octoEq
    local r, g, b = AB.Quality(f)
    AB.Edges(l, tonumber(C.bars.eq_size) or 2, r, g, b, 1)
    l.fill:Hide()
    l:Show()
  end

  -- ------------------------------------------------ on every button

  function AB.Effects(f)
    -- hover: our layer rides on pfUI's highlight frame (shown on mouse-over
    -- and key down); pfUI's own glow border hides under another style
    if f.highlight then
      if not f.octoHover then f.octoHover = AB.Layer(f.highlight, 0) end
      local ours = AB.Paint(f.octoHover, "hover")
      f.highlight:SetBackdropBorderColor(1, 1, 1, ours and 0 or .8)
    end
    -- press
    if not f.octoPress then
      f.octoPress = AB.Layer(f, 2)
      f.octoPress:Hide()
      f.octoPress:SetScript("OnUpdate", PressWatch)
      if f.HookScript then
        f:HookScript("OnMouseDown", PressDown)
        f:HookScript("OnMouseUp", PressUp)
        f:HookScript("OnClick", PressKey)
      end
    end
    f.octoPress.on = AB.Paint(f.octoPress, "press") and C.bars.press_style ~= "none" or nil
    -- cooldown swipe: the game's clock shows only in "clock"
    if f.cd then
      f.cd.octoButton = f
      if (C.bars.cd_style or "clock") == "clock" then
        f.cd.pfCooldownStyleAnimation = 1
        f.cd:SetAlpha(1)
      else
        f.cd.pfCooldownStyleAnimation = 0
        f.cd:SetAlpha(0)
      end
      if f.octoDrain then f.octoDrain:Hide() end
    end
    AB.Slot(f)
    AB.Equipped(f)
    if f.octoGlow then f.octoGlow.lit = nil end
  end

  -- try the effects on your own bars: every button with an action glows,
  -- runs a cooldown and flashes its press look for a few seconds
  function AB.Test(seconds)
    seconds = seconds or 6
    local now = GetTime()
    AB.testUntil = now + seconds
    for i = 1, 10 do
      local bar = BARS[i]
      if bar and bar:IsShown() then
        for j = 1, 12 do
          local f = bar[j]
          if f and f:IsShown() and f.texture then
            if f.octoGlow then f.octoGlow.lit = nil end
            AB.Glow(f, true)
            if f.cd and CooldownFrame_SetTimer then CooldownFrame_SetTimer(f.cd, now, seconds, 1) end
            if f.octoPress and f.octoPress.on then
              f.octoPress:Show()
              f.octoPress.untilT = now + .4
            end
          end
        end
      end
    end
  end

  -- glows and equipped borders follow the game (5 times a second)
  local watch = CreateFrame("Frame")
  watch:RegisterEvent("PLAYER_AURAS_CHANGED")
  watch:RegisterEvent("PLAYER_ENTERING_WORLD")
  watch:SetScript("OnEvent", ScanProcs)
  watch:SetScript("OnUpdate", function()
    if (this.tick or 0) > GetTime() then return end
    this.tick = GetTime() + .2
    for i = 1, 10 do
      local bar = BARS[i]
      if bar and bar:IsShown() then
        for j = 1, 12 do
          local f = bar[j]
          if f and f:IsShown() then
            AB.Glow(f, AB.ShouldGlow(f))
            if f.equipped and (f.octoEq or C.bars.eq_style ~= "fill") then AB.Equipped(f) end
          end
        end
      end
    end
  end)

  -- ---------------------------------------------------------------- visibility

  -- stealth / prowl by the buff's icon
  local function Stealthed()
    -- ClassicAPI's IsStealthed reads the state itself (Shadowmeld, Prowl, Stealth...)
    local real = libclient and libclient.Stealthed()
    if real ~= nil then return real end
    for i = 1, 32 do
      local tex = UnitBuff("player", i)
      if not tex then break end
      if string.find(tex, "Ability_Stealth") or string.find(tex, "Ability_Ambush") then return true end
    end
  end
  AB.Stealthed = Stealthed

  -- should bar i show now, by its rules?
  function AB.Wanted(i)
    local d = DB(i)
    if not d or d.enable ~= "1" then return false end
    local fighting = UnitAffectingCombat("player")
    if d.vis_combat == "combat" and not fighting then return false end
    if d.vis_combat == "nocombat" and fighting then return false end
    local pet = UnitExists("pet")
    if d.vis_pet == "pet" and not pet then return false end
    if d.vis_pet == "nopet" and pet then return false end
    if d.vis_target == "target" and not UnitExists("target") then return false end
    if d.vis_stealth == "hide" and Stealthed() then return false end
    return true
  end

  -- bars 1 - 10 follow their rules (shapeshift and pet bars show and hide
  -- with your forms and pet already)
  function AB.Visibility()
    for i = 1, 10 do
      local bar = BARS[i]
      if bar and DB(i) and DB(i).enable == "1" then
        if AB.Wanted(i) then
          if not bar:IsShown() then bar:Show() end
        elseif bar:IsShown() then
          bar:Hide()
        end
      end
    end
  end

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_PET", "PLAYER_TARGET_CHANGED",
                       "PLAYER_AURAS_CHANGED", "UPDATE_SHAPESHIFT_FORMS", "PLAYER_ENTERING_WORLD" }) do
    ev:RegisterEvent(e)
  end
  ev:SetScript("OnEvent", function() AB.Visibility() end)

  -- ---------------------------------------------------------------- apply

  function AB.Apply()
    for i = 1, 12 do
      local bar, d = BARS[i], DB(i)
      if bar and d then
        local scale = tonumber(d.scale) or 1
        if math.abs((bar:GetScale() or 1) - scale) > .001 then bar:SetScale(scale) end
        -- one size for both places that set it: layout mode keeps the bar's
        -- scale in C.position too (24 Oct 2026: a bar sized with the mouse
        -- wheel in layout mode went back to this setting after Esc)
        local pos = bar.GetName and bar:GetName() and C.position[bar:GetName()]
        if pos and pos.scale then pos.scale = scale end
        if not bar.OnScale then
          local n = i
          bar.OnScale = function(_, s) DB(n).scale = tostring(s) end
        end
        local alpha = tonumber(d.alpha) or 1
        bar.octoAlpha = alpha
        bar.fadeTo = math.min(alpha, tonumber(d.fadeto) or 0)
        -- (autohide moves the opacity itself; else it is the bar's own)
        if d.autohide ~= "1" then bar:SetAlpha(alpha) end
        -- the bar's backdrop colour ("" = pfUI's)
        local bbg = C.bars.bar_bg
        if bar.backdrop and bbg and bbg ~= "" then bar.backdrop:SetBackdropColor(ParseColor(bbg)) end
        for j = 1, 12 do
          local f = bar[j]
          if f then
            Skin(f)
            -- (the swipe's direction can change without a reload)
            if f.cd then f.cd.pfCooldownReverse = tonumber(C.bars.cooldown_reverse) or 0 end
            Zoom(f)
            AB.Effects(f)
          end
        end
      end
    end
    AB.Visibility()
  end

  -- one bar the size of another (user, 25 Oct 2026: "match size buttons so
  -- you can easily match your other action bars"): button size, the gap
  -- between buttons and the bar's scale. Bars with the same buttons and rows
  -- then have boxes of the same size. Layout mode's Match and the Bars
  -- page's "Match all bars" use it; the caller runs pfUI.bars:UpdateConfig().
  AB.SIZEKEYS = { "icon_size", "spacing", "scale" }
  function AB.BarIndex(frame)
    for i = 1, 12 do if BARS[i] and BARS[i] == frame then return i end end
  end
  function AB.CopySize(from, to)
    local s, d = DB(from), DB(to)
    if not s or not d or from == to then return end
    for _, k in ipairs(AB.SIZEKEYS) do d[k] = s[k] end
    -- layout mode keeps the scale in C.position too (see AB.Apply)
    local bar = BARS[to]
    local pos = bar and bar.GetName and bar:GetName() and C.position[bar:GetName()]
    if pos and pos.scale then pos.scale = tonumber(d.scale) or 1 end
    return true
  end
  -- every other bar that is on (1 - 10: stance and pet bars keep their own)
  function AB.MatchAll(from)
    local n = 0
    for i = 1, 10 do
      if i ~= from and DB(i) and DB(i).enable == "1" and AB.CopySize(from, i) then n = n + 1 end
    end
    return n
  end

  -- after every pfUI bar update
  local UpdateConfig = BARS.UpdateConfig
  BARS.UpdateConfig = function(self)
    UpdateConfig(self)
    AB.Apply()
  end

  -- ---------------------------------------------------------------- looks

  -- one-click looks: { key, label, global keys, every bar's keys, the idea }
  local function L(key, label, skin, zoom, slot, spacing, background, showempty, idea)
    return { key, label, { skin = skin, zoom = zoom, slot_style = slot },
             { spacing = spacing, background = background, showempty = showempty }, idea }
  end
  AB.PRESETS = {
    L("pfui", "pfUI", "pfui", ".08", "pfui", "1", "1", "1", "pfUI's own: thin black borders on a bar backdrop."),
    L("clean", "Clean", "shadow", ".1", "pfui", "3", "0", "0", "A soft shadow under each button, no bar backdrop (ElvUI's idea)."),
    L("bold", "Bold", "thick", ".12", "pfui", "4", "0", "1", "Thick black frames, empty slots kept."),
    L("neon", "Neon", "neon", ".1", "pfui", "6", "0", "0", "A bright line with a coloured halo. Pick its colours under Look colours."),
    L("classic", "Classic", "gold", "0", "pfui", "2", "1", "1", "Gold lines round whole icons."),
    L("minimal", "Minimal", "accent", ".15", "pfui", "2", "0", "0", "One thin line in the UI's accent colour (Masque's Apathy idea)."),
    L("pixel", "Pixel", "outlined", ".08", "pfui", "3", "0", "0", "A coloured line in a black outline (ElvUI's pixel borders)."),
    L("zoomed", "Zoomed", "pfui", ".2", "pfui", "1", "0", "0", "Big icons packed close together (Masque's Zoomed idea)."),
    L("glossy", "Glossy", "gloss", ".08", "grad", "3", "0", "1", "A shine on top and darker edges (Masque's gloss skins)."),
    L("bevel", "Bevel", "bevel", ".08", "grad", "3", "0", "1", "Raised frames: light on top, dark below."),
    L("metal", "Metal", "steel", ".08", "grad", "5", "0", "1", "Metal frames; colour them copper, gold or cobalt (Masque's Entropy idea)."),
    L("glass", "Glass", "glass", ".08", "solid", "3", "0", "0", "See-through edges with a strong shine."),
    L("dark", "Dark", "dark", ".1", "solid", "5", "0", "1", "Heavy dark frames with a light rim (retail's buttons)."),
    L("game", "Game", "blizz", "0", "game", "6", "0", "1", "The game's own button frame (Bartender's and Dominos' default)."),
  }
  -- back to a skin's own colours and sizes
  function AB.ClearColors()
    for _, part in ipairs(AB.PARTS) do
      C.bars["skin_" .. part] = ""
      C.bars["skin_" .. part .. "_class"] = "0"
    end
    C.bars.skin_edgesize, C.bars.skin_outersize = "", ""
  end
  function AB.ApplyPreset(key)
    for _, p in ipairs(AB.PRESETS) do
      if p[1] == key then
        for k, v in pairs(p[3]) do C.bars[k] = v end
        for i = 1, 12 do
          for k, v in pairs(p[4]) do DB(i)[k] = v end
        end
        AB.ClearColors()
      end
    end
    BARS:UpdateConfig()
  end
  -- the look in use: one that matches every key; else the first with the same
  -- skin (third return false: your changes on top of it)
  function AB.CurrentLook()
    local near
    for _, p in ipairs(AB.PRESETS) do
      local same = true
      for k, v in pairs(p[3]) do if C.bars[k] ~= v then same = false end end
      for i = 1, 12 do
        for k, v in pairs(p[4]) do if DB(i)[k] ~= v then same = false end end
      end
      if same then return p[1], p[2], true end
      if not near and p[3].skin == C.bars.skin then near = p end
    end
    if near then return near[1], near[2], false end
  end

  AB.Apply()
end)
