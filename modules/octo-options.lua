pfUI:RegisterModule("octo-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the options window in OctoBG's look.
  -- User, 20 Oct 2026 (screenshots of ElvUI and of OctoBG's options): "copy
  -- Octo BGS style of UI and update PFUI into being my own addon". pfUI's own
  -- window (pfUI.gui, so everything that opens, closes or reloads it keeps
  -- working) gets OctoBG's shell: the title row, a quick bar (Move frames,
  -- Keybinds, Install, Profiles, Background, Find a setting), a folding topic
  -- list on the left and the page on the right.
  --
  -- Two kinds of page live in it:
  --   * Octo pages - built with octo-widgets.lua (folding cards, switches,
  --     sliders), registered with O:AddPage(group, key, label, build).
  --     Combat text's pages (sct-options.lua) are these.
  --   * pfUI's own pages - every category and page made by CreateGUIEntry.
  --     Their areas are moved into the page panel and shown from here; the
  --     old tree buttons are kept (hidden) because gui.lua still drives them.
  -- The Find box searches both (pfUI's labels via pfUI.gui.searchDB).

  local B = pfUI.octoui
  local W = B and B.W
  local g = pfUI.gui
  if not W or not g or not g.frames then return end
  local K = W.C

  local O = B.Options or { pages = {}, groups = {}, BUILD = {} }
  B.Options = O
  O.pages, O.BUILD = O.pages or {}, O.BUILD or {}
  O.octo = O.octo or {}   -- { { name, { { key, label }, ... } }, ... } in order
  -- pfUI categories an Octo section replaces (name -> true): hidden from the
  -- topic list and from Find (plates-options.lua replaces "Nameplates")
  O.replaced = O.replaced or {}
  -- the topic list, most used first: { section title, { sources... } };
  -- a source is an Octo section or a pfUI category, by name
  O.NAV = {
    { "Settings", { "Settings" } },
    { "Blizzard UI", { "Blizzard UI" } },
    { "UI layouts", { "UI layouts" } },
    { "Unit Frames", { "Unit Frames", "Castbar" } },
    { "Action Bars", { "Action Bars", "Actionbar" } },
    { "Nameplates", { "Nameplates" } },
    { "Art & Extras", { "Art", "WeirdUtils" } },
    { "Chat & Panels", { "Chat", "Panel", "XP Bar" } },
    { "Minimap & Buffs", { "Minimap", "Buffs" } },
    { "Bags & Loot", { "Bags", "Bags & Bank", "Loot", "Auto Loot" } },
    { "Combat", { "Combat Text", "Meters", "Swing Timer" } },
    { "Gear", { "Gear" } },
    { "Tooltip", { "Tooltip" } },
    { "Add-ons", { "Thirdparty", "Components" } },
    { "About", { "About" } },
  }

  -- (wider and taller since 22 Oct 2026; it shrinks itself to fit the screen)
  local WIDTH, HEIGHT, NAV_W, NAV_ROW = 1080, 740, 196, 20
  local SEARCH = "[" .. T["Search"] .. "]"

  -- ---------------------------------------------------------------- one colour language

  -- (user, 25 Oct 2026, after the talent specs window: "copy this colour and
  -- layout ... keep it a rule Red for off green for on etc purple for multi
  -- choice ... keep it all the same and make this look highly prof")
  --   go / on    green   Activate, Wear, Test, Show, New, ticked boxes, ON
  --   danger     red     Delete, Reset, Remove, Clear, OFF
  --   pick       purple  dropdowns and menus: one of many
  --   save       gold    Save, Copy, Buy, Import / Export
  --   open       blue    Open, Move frames, Options, other pages
  -- Done here, on top of the widgets, so every Octo page follows it.
  W.ROLE = {
    go = { .25, .85, .4 }, on = { .25, .85, .4 }, danger = { .95, .3, .3 }, off = { .95, .3, .3 },
    pick = { .68, .45, 1 }, save = { 1, .78, .2 }, open = { .35, .7, 1 },
  }
  -- a button in its role's colour: dark fill, bright edge and words
  function W.Tint(b, role)
    local col = role and W.ROLE[role]
    if not b or not col or not b.SetBackdropColor then return b end
    b.role = role
    local function Paint()
      if b.picked then return end
      b:SetBackdropColor(col[1] * .28, col[2] * .28, col[3] * .28, 1)
      b:SetBackdropBorderColor(col[1] * .85, col[2] * .85, col[3] * .85, 1)
      if b.label then b.label:SetTextColor(math.min(1, col[1] + .3), math.min(1, col[2] + .3), math.min(1, col[3] + .3)) end
    end
    b.PaintRole = Paint
    Paint()
    b:SetScript("OnMouseUp", Paint)
    return b
  end
  -- a button's role from its words (first match wins)
  W.ROLEWORDS = {
    { "danger", { "delete", "remove", "reset", "clear", "forget", "unbind", "take off", "turn off", " off", "disable", "stop" } },
    { "save", { "save", "copy", "buy", "export", "import", "match", "rename", "share" } },
    { "go", { "activate", "wear", "apply", "test", "start", "try", "show", "switch", "new", "add", "+ ", "play", "turn on", "dress" } },
    { "open", { "open", "move", "keybind", "options", "gear sets", "layouts", "profiles", "install", "find", "breakdown", "page" } },
    { "pick", { "pick", "choose", "look", "..." } },
  }
  function W.RoleOf(text)
    local t = " " .. string.lower(string.gsub(text or "", "|c%x%x%x%x%x%x%x%x", "")) .. " "
    for _, r in ipairs(W.ROLEWORDS) do
      for _, w in ipairs(r[2]) do
        if string.find(t, w, 1, true) then return r[1] end
      end
    end
  end

  -- rows of buttons: each tinted by its role (d.role, else its words); lit
  -- buttons ("on" while something holds) light green, not blue
  local Buttons = W.Buttons
  W.Buttons = function(p, list)
    local row = Buttons(p, list)
    local kids = { row:GetChildren() }
    for i = 1, table.getn(list) do
      local b, d = kids[i], list[i]
      if b and d and not (d.on or d[5]) then
        local role = d.role or W.RoleOf(d[1])
        if role then W.Tint(b, role) end
      end
    end
    return row
  end
  local Lit = W.Lit
  W.Lit = function(b, on)
    Lit(b, on)
    if on then
      local g = W.ROLE.on
      b:SetBackdropBorderColor(g[1], g[2], g[3], 1)
      b:SetBackdropColor(g[1] * .35, g[2] * .35, g[3] * .35, 1)
    elseif b.PaintRole then
      b.PaintRole()
    end
  end
  -- switches: green ON, red OFF (the pill and the word)
  local Toggle = W.Toggle
  W.Toggle = function(parent)
    local b = Toggle(parent)
    local set = b.Set
    b.Set = function(on)
      set(on)
      if not on then
        local r = W.ROLE.off
        local regions = { b:GetRegions() }
        for _, t in ipairs(regions) do
          if t.GetDrawLayer and t:GetDrawLayer() == "ARTWORK" and t.SetVertexColor then t:SetVertexColor(r[1] * .7, r[2] * .7, r[3] * .7, 1) end
        end
      end
    end
    b.Set(b.on and true or false)
    return b
  end
  local Switch = W.Switch
  W.Switch = function(parent, get, set, tip)
    local f = Switch(parent, get, set, tip)
    local refresh = f.Refresh
    f.Refresh = function()
      refresh()
      if not get() then
        local r = W.ROLE.off
        for _, fs in ipairs({ f:GetRegions() }) do
          if fs.GetText and fs:GetText() == "OFF" then fs:SetTextColor(r[1], r[2] + .1, r[3] + .1) end
        end
      end
    end
    return f
  end
  -- tick boxes: green inside when ticked
  local CheckBox = W.CheckBox
  W.CheckBox = function(parent, size)
    local cb = CheckBox(parent, size)
    local t = cb:GetCheckedTexture()
    local g = W.ROLE.on
    if t then t:SetVertexColor(g[1], g[2], g[3], 1) end
    return cb
  end
  -- dropdowns (pick one of many): a purple edge and arrow
  local DropBox = W.DropBox
  W.DropBox = function(parent, width)
    local f, text, a, b = DropBox(parent, width)
    local pc = W.ROLE.pick
    f:SetBackdropBorderColor(pc[1] * .7, pc[2] * .7, pc[3] * .7, 1)
    for _, t in ipairs({ f:GetRegions() }) do
      if t.GetDrawLayer and t:GetDrawLayer() == "OVERLAY" and t.SetVertexColor and not t.GetText then t:SetVertexColor(pc[1], pc[2], pc[3], 1) end
    end
    return f, text, a, b
  end

  -- every menu closes on a click anywhere outside it (user, 25 Oct 2026, the
  -- trinket queue menu): ClassicAPI's GLOBAL_MOUSE_DOWN (fires for clicks on
  -- frames and on the world); without it a menu closes 1.5 s after the mouse
  -- has left it and what opened it
  local Menu = W.Menu
  -- (rightToo: its entries take right-clicks too; onPick reads arg1)
  W.Menu = function(anchor, options, width, onPick, rightToo)
    local m = Menu(anchor, options, width, onPick)
    if rightToo then
      for _, e in ipairs({ m:GetChildren() }) do
        if e.RegisterForClicks then e:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
      end
    end
    m.anchor = anchor
    m.away = 0
    m:SetScript("OnUpdate", function()
      if W.globalClicks then return end
      if MouseIsOver(this) or (this.anchor and this.anchor.IsVisible and this.anchor:IsVisible() and MouseIsOver(this.anchor)) then
        this.away = 0
      else
        this.away = (this.away or 0) + (arg1 or 0)
        if this.away > 1.5 then this:Hide() end
      end
    end)
    return m
  end
  local clicks = CreateFrame("Frame")
  W.globalClicks = pcall(clicks.RegisterEvent, clicks, "GLOBAL_MOUSE_DOWN") and C_EventUtils ~= nil or nil
  clicks:SetScript("OnEvent", function()
    for _, m in ipairs(W.menus or {}) do
      if m:IsShown() and not MouseIsOver(m)
        and not (m.anchor and m.anchor.IsVisible and m.anchor:IsVisible() and MouseIsOver(m.anchor)) then
        m:Hide()
      end
    end
  end)

  -- The "how to use this preview" strips (user, 25 Oct 2026: "this looks horrid
  -- on all pages hard to read and no alignment"): W.HowTo(page, band, text
  -- [, text2]) reads the old one-line text ("|cff..KEY|r  what it does" pairs)
  -- and draws a grid instead - each key a keycap (white on a dark button with
  -- an accent edge), what it does in light grey beside it, columns lined up;
  -- the band becomes a dark card with an accent edge and grows to fit.
  -- reserve = px kept free at the right end (a status text there).
  -- A preview box you can look closer into (user, 25 Oct 2026: "make all
  -- preview windows able to be zoomed in and out on and dragged ... if you
  -- scroll outside of anything you can edit it will zoom and you can drag").
  -- W.Box with a ScrollFrame in it (the client clips what is drawn there),
  -- a canvas as its child and a stage on the canvas: callers draw on the
  -- stage, which is as big as the box. The wheel anywhere that does not use
  -- it itself zooms (towards the mouse; parts that pass a plain wheel on with
  -- PassWheel reach the stage's OnMouseWheel), dragging empty space moves
  -- the view, a double-click or "Fit" puts it back. Parts the zoom pushed
  -- out of the box stop taking the mouse (the client clips the drawing but
  -- not the mouse). Returns the stage; stage.view = the zoom state.
  W.ZOOM_MIN, W.ZOOM_MAX = 1, 5
  function W.ZoomBox(p, h)
    p.hasZoom = true
    local box = W.Box(p, h)
    local bw = box:GetWidth() or 700
    local sf = CreateFrame("ScrollFrame", nil, box)
    sf:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    sf:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    -- (the previews draw in the FULLSCREEN layer, over the window: the clip
    -- is in that layer too, so what they put there is cut at the box)
    sf:SetFrameStrata("FULLSCREEN")
    local canvas = CreateFrame("Frame", nil, sf)
    canvas:SetWidth(bw - 2)
    canvas:SetHeight(h - 2)
    sf:SetScrollChild(canvas)
    -- (the box's dark fill went over the drawing - every preview came out dark,
    -- user 26 Oct 2026: the fill is under it now, inside the clip; the box keeps
    -- only its edge)
    box:SetBackdropColor(0, 0, 0, 0)
    local under = canvas:CreateTexture(nil, "BACKGROUND")
    under:SetTexture("Interface\\Buttons\\WHITE8X8")
    under:SetAllPoints(canvas)
    under:SetVertexColor(W.C.field[1], W.C.field[2], W.C.field[3], .9)
    local stage = CreateFrame("Frame", nil, canvas)
    stage:SetWidth(bw)
    stage:SetHeight(h)
    stage:SetPoint("CENTER", canvas, "CENTER", 0, 0)
    stage.outer = box
    local V = { z = 1, x = 0, y = 0, stage = stage, box = box }
    stage.view = V

    -- the mouse's spot on the canvas, from its centre (canvas units)
    local function Cursor()
      local cx, cy = GetCursorPosition()
      local s = canvas:GetEffectiveScale() or 1
      local l, b = canvas:GetLeft(), canvas:GetBottom()
      if not l then return 0, 0 end
      return cx / s - l - canvas:GetWidth() / 2, cy / s - b - canvas:GetHeight() / 2
    end
    -- parts pushed out of the box by the zoom: no mouse there
    local function Shield()
      local l, r, b, t = sf:GetLeft(), sf:GetRight(), sf:GetBottom(), sf:GetTop()
      if not l then return end
      local ss = sf:GetEffectiveScale()
      local function Walk(f)
        for _, k in ipairs({ f:GetChildren() }) do
          if k.IsMouseEnabled and (k:IsMouseEnabled() or k.octoNoMouse) then
            local x, y = k:GetCenter()
            local ks = k:GetEffectiveScale() / ss
            local out = x and (x * ks < l or x * ks > r or y * ks < b or y * ks > t)
            if out and not k.octoNoMouse then
              k.octoNoMouse = true
              k:EnableMouse(false)
            elseif not out and k.octoNoMouse then
              k.octoNoMouse = nil
              k:EnableMouse(true)
            end
          end
          Walk(k)
        end
      end
      Walk(stage)
    end
    local function Place()
      stage:SetScale(V.z)
      stage:ClearAllPoints()
      -- (offsets are in the stage's own units: scaled by the zoom)
      stage:SetPoint("CENTER", canvas, "CENTER", V.x / V.z, V.y / V.z)
      V.shield = 2
      if V.fit then
        local zoomed = V.z > 1.001 or V.x ~= 0 or V.y ~= 0
        V.fit.text:SetText(zoomed and (math.floor(V.z * 100 + .5) .. "%   |cffffffffFit|r") or "wheel: zoom")
        V.fit.text:SetAlpha(zoomed and 1 or .5)
      end
    end
    -- keep some of the picture in the box
    local function Clamp()
      local mx, my = (bw * V.z) / 2, (h * V.z) / 2
      V.x = math.max(-mx, math.min(mx, V.x))
      V.y = math.max(-my, math.min(my, V.y))
    end
    function V.Zoom(dir)
      local z1 = V.z
      local z2 = math.max(W.ZOOM_MIN, math.min(W.ZOOM_MAX, z1 * (dir > 0 and 1.2 or 1 / 1.2)))
      if z2 == z1 then return end
      -- the spot under the mouse stays under it
      local ux, uy = Cursor()
      V.x = ux - (ux - V.x) * z2 / z1
      V.y = uy - (uy - V.y) * z2 / z1
      V.z = z2
      if z2 <= W.ZOOM_MIN + .001 then V.x, V.y = 0, 0 end
      Clamp()
      Place()
    end
    function V.Fit()
      V.z, V.x, V.y = 1, 0, 0
      Place()
    end
    -- (PassWheel(part) walks up from the part's parent: the stage or, for
    -- the stage itself, the canvas)
    stage:SetScript("OnMouseWheel", function() V.Zoom(arg1 or 0) end)
    canvas:SetScript("OnMouseWheel", function() V.Zoom(arg1 or 0) end)

    -- empty space: behind everything drawn on the stage
    local pan = CreateFrame("Button", nil, canvas)
    pan:SetAllPoints(sf)
    pan:SetFrameLevel(canvas:GetFrameLevel())
    stage:SetFrameLevel(canvas:GetFrameLevel() + 2)
    pan:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pan:EnableMouseWheel(true)
    pan:SetScript("OnMouseWheel", function() V.Zoom(arg1 or 0) end)
    pan:SetScript("OnMouseDown", function()
      local ux, uy = Cursor()
      this.from = { ux, uy, V.x, V.y }
    end)
    pan:SetScript("OnMouseUp", function() this.from = nil end)
    pan:SetScript("OnDoubleClick", function() V.Fit() end)
    pan:SetScript("OnUpdate", function()
      local f = this.from
      if f and V.z > W.ZOOM_MIN + .001 then
        local ux, uy = Cursor()
        V.x, V.y = f[3] + ux - f[1], f[4] + uy - f[2]
        Clamp()
        Place()
      end
      if V.shield then
        V.shield = V.shield - 1
        if V.shield <= 0 then V.shield = nil Shield() end
      end
    end)
    V.pan = pan

    -- the zoom and "Fit" in the top right corner (only while zoomed)
    local fit = CreateFrame("Button", nil, box)
    fit:SetFrameLevel(canvas:GetFrameLevel() + 30)
    fit:SetWidth(90)
    fit:SetHeight(16)
    -- (bottom left: a page's own labels sit along the top - "SAMPLE BUTTON")
    fit:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 6, 4)
    fit.text = fit:CreateFontString(nil, "OVERLAY")
    fit.text:SetFont(W.UIFont(), 10, "OUTLINE")
    fit.text:SetAllPoints(fit)
    fit.text:SetJustifyH("LEFT")
    fit.text:SetTextColor(.75, .78, .82)
    fit:SetScript("OnClick", function() V.Fit() end)
    V.fit = fit
    Place()
    return stage
  end

  function W.HowToPairs(text)
    local out = {}
    -- (plain "Key: what it does" pieces, three or more spaces apart, too)
    if text and not string.find(text, "|c", 1, true) then
      local t = string.gsub(text, "%s%s%s+", "~")
      for seg in string.gfind(t, "[^~]+") do
        local _, _, key, act = string.find(seg, "^%s*(.-):%s*(.-)%s*$")
        if key and key ~= "" then table.insert(out, { key, act }) end
      end
      return out
    end
    for key, act in string.gfind(text or "", "|c%x%x%x%x%x%x%x%x(.-)|r([^|]*)") do
      act = string.gsub(act, "^%s+", "")
      act = string.gsub(act, "%s+$", "")
      table.insert(out, { key, act })
    end
    return out
  end
  -- the picture for a key: the game's own cursors (names checked in the
  -- client's listfile) and a spyglass for zoom
  function W.HowIcon(key, act)
    local k, a = string.lower(key or ""), string.lower(act or "")
    if string.find(a, "zoom", 1, true) then return "Interface\\Icons\\INV_Misc_Spyglass_02" end
    if string.find(k, "drag", 1, true) then return "Interface\\Cursor\\Pickup" end
    if string.find(k, "wheel", 1, true) then return "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up" end
    if string.find(k, "move frames", 1, true) then return "Interface\\Icons\\INV_Misc_Map_01" end
    if string.find(k, "right", 1, true) then return "Interface\\Cursor\\Interact" end
    return "Interface\\Cursor\\Point"
  end
  function W.HowTo(p, band, text, text2, reserve)
    if not band then return end
    local pairs_ = W.HowToPairs(text)
    for _, e in ipairs(W.HowToPairs(text2)) do table.insert(pairs_, e) end
    if table.getn(pairs_) == 0 then return end
    -- a preview you can zoom: say how (user, 25 Oct 2026: "add how it can be
    -- zoomed in on and dragged make it clear with icons")
    if p and p.hasZoom then
      local has
      for _, e in ipairs(pairs_) do if string.find(string.lower(e[2] or ""), "zoom") then has = true end end
      if not has then
        table.insert(pairs_, { "Wheel", "zoom in / out" })
        table.insert(pairs_, { "Drag", "empty space: move the view" })
        table.insert(pairs_, { "Double-click", "fit the view again" })
      end
    end
    -- the old text and colour wash go
    for _, r in ipairs({ band:GetRegions() }) do
      if r.GetText then
        -- (only the old help lines: a status text beside them stays)
        local t = r:GetText()
        if t and table.getn(W.HowToPairs(t)) > 0 then r:Hide() end
      elseif r.GetDrawLayer and r:GetDrawLayer() == "BACKGROUND" then r:Hide() end
    end
    if band.howto then for _, c in ipairs(band.howto) do c:Hide() end end
    band.howto = {}
    W.Flat(band, W.C.card, 1, W.C.line)
    local ar, ag, ab = W.C.accent[1], W.C.accent[2], W.C.accent[3]
    if GetAccentColor then ar, ag, ab = GetAccentColor() end
    if not band.howEdge then
      band.howEdge = band:CreateTexture(nil, "ARTWORK")
      band.howEdge:SetTexture("Interface\\Buttons\\WHITE8X8")
      band.howEdge:SetPoint("TOPLEFT", band, "TOPLEFT", 1, -1)
      band.howEdge:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT", 1, 1)
      band.howEdge:SetWidth(3)
    end
    band.howEdge:SetVertexColor(ar, ag, ab, 1)
    local width = (band:GetWidth() or 700) - 20 - (reserve or 0)
    local cols = width >= 640 and 4 or (width >= 420 and 3 or 2)
    local colw = math.floor(width / cols)
    local ROW = 22
    -- (31 Oct 2026, user: the menus are "overwhelming"; two rows of hints with
    -- cut-off words. One row now: the first ones, and "?" with all of them.)
    local all = pairs_
    if table.getn(pairs_) > cols then
      pairs_ = {}
      for i = 1, cols - 1 do pairs_[i] = all[i] end
      table.insert(pairs_, { "?", "All mouse controls", more = true })
    end
    for i, e in ipairs(pairs_) do
      local col = math.mod(i - 1, cols)
      local row = math.floor((i - 1) / cols)
      local cell = CreateFrame("Frame", nil, band)
      cell:SetWidth(colw)
      cell:SetHeight(ROW)
      cell:SetPoint("TOPLEFT", band, "TOPLEFT", 12 + col * colw, -5 - row * ROW)
      -- a small picture of the mouse action before the key
      local pic = cell:CreateTexture(nil, "ARTWORK")
      pic:SetWidth(16)
      pic:SetHeight(16)
      pic:SetPoint("LEFT", cell, "LEFT", 0, 0)
      pic:SetTexture(W.HowIcon(e[1], e[2]))
      local cap = CreateFrame("Frame", nil, cell)
      cap:SetHeight(17)
      cap:SetPoint("LEFT", pic, "RIGHT", 4, 0)
      W.Flat(cap, W.C.btn, 1, W.C.line)
      cap:SetBackdropBorderColor(ar * .8, ag * .8, ab * .8, 1)
      local kt = W.Font(cap:CreateFontString(nil, "OVERLAY"), 10, 1, 1, 1)
      kt:SetPoint("CENTER", cap, "CENTER", 0, 0)
      kt:SetText(e[1])
      cap:SetWidth(math.max(28, math.floor((kt:GetStringWidth() or 30) + 12)))
      local at = W.Font(cell:CreateFontString(nil, "OVERLAY"), 11, .82, .83, .87)
      at:SetPoint("LEFT", cap, "RIGHT", 6, 0)
      at:SetPoint("RIGHT", cell, "RIGHT", -6, 0)
      at:SetJustifyH("LEFT")
      at:SetText(e[2])
      if e.more then
        pic:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        pic:SetTexCoord(.08, .92, .08, .92)
        cell:EnableMouse(true)
        cell:SetScript("OnEnter", function()
          GameTooltip:SetOwner(this, "ANCHOR_TOP")
          GameTooltip:SetText("Mouse controls", 1, .82, 0)
          for _, a in ipairs(all) do GameTooltip:AddDoubleLine(a[1], a[2], ar, ag, ab, 1, 1, 1) end
          GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
      end
      table.insert(band.howto, cell)
    end
    local rows = math.ceil(table.getn(pairs_) / cols)
    band:SetHeight(rows * ROW + 10)
    if p and W.Measure then pcall(W.Measure, p) end
  end

  -- a picture on every card (user: "add more artwork throughout"): one given
  -- by the page, else one found from the card's words (names checked in the
  -- client's listfile, 25 Oct 2026)
  W.CARDART = {
    { { "automatic", "auto ", "status", "time" }, "INV_Misc_PocketWatch_01" },
    { { "spec", "talent", "brain" }, "Spell_Shadow_ShadowWordDominate" },
    { { "switch", "swap" }, "Spell_Arcane_Blink" },
    { { "wait" }, "Spell_Nature_TimeStop" },
    { { "colour", "color", "look", "skin", "border", "background" }, "INV_Fabric_Silk_02" },
    { { "text", "font", "word", "name", "letter" }, "INV_Scroll_03" },
    { { "preview", "test", "try", "sample" }, "INV_Misc_Spyglass_02" },
    { { "where", "position", "place", "frame", "layout", "map", "zone" }, "INV_Misc_Map_01" },
    { { "sound", "popup", "alert", "warn", "message", "notice" }, "INV_Misc_Bell_01" },
    { { "key", "bind" }, "INV_Misc_Key_01" },
    { { "gear", "set", "equip", "item", "wear" }, "INV_Chest_Cloth_17" },
    { { "trinket", "ring" }, "INV_Jewelry_Ring_03" },
    { { "threat", "tank", "aggro" }, "Ability_Warrior_DefensiveStance" },
    { { "heal" }, "Spell_Holy_Heal02" },
    { { "damage", "swing", "weapon", "melee" }, "INV_Sword_04" },
    { { "cast", "spell" }, "Spell_Nature_Lightning" },
    { { "aura", "buff", "debuff" }, "Spell_Holy_MagicalSentry" },
    { { "chat", "whisper", "tell" }, "INV_Letter_15" },
    { { "raid", "party", "group" }, "INV_Banner_02" },
    { { "share", "profile", "export", "import", "report" }, "INV_Misc_Book_11" },
    { { "boss", "elite" }, "INV_Misc_Head_Dragon_01" },
    { { "data", "number", "fight", "segment" }, "INV_Misc_Book_08" },
    { { "bar", "button", "slot" }, "INV_Misc_StoneTablet_05" },
    { { "icon", "picture", "art" }, "INV_Misc_Gem_Pearl_04" },
    { { "remove", "delete" }, "INV_Misc_Bomb_04" },
    { { "window", "meter" }, "INV_Misc_EngGizmos_01" },
  }
  function W.CardArt(title)
    local t = " " .. string.lower(string.gsub(title or "", "|c%x%x%x%x%x%x%x%x", "")) .. " "
    for _, e in ipairs(W.CARDART) do
      for _, w in ipairs(e[1]) do
        if string.find(t, w, 1, true) then return "Interface\\Icons\\" .. e[2] end
      end
    end
    return "Interface\\Icons\\INV_Misc_Rune_01"
  end
  local Card = W.Card
  W.Card = function(p, title, o)
    o = o or {}
    if o.icon == nil then o.icon = W.CardArt(title) end
    if o.icon == false then o.icon = nil end
    return Card(p, title, o)
  end

  -- ---------------------------------------------------------------- helpers for pages

  -- Check / slider / dropdown bound to a key of a settings table (tbl is a
  -- function, so a reset table is picked up). As in OctoBG's Options.lua.
  function O.Chk(p, label, desc, tbl, key, after)
    return W.Check(p, label, desc, function() return tbl()[key] end, function(v)
      tbl()[key] = v
      if after then after(v) end
    end)
  end
  function O.Sld(p, label, desc, min, max, step, tbl, key, after, fmt)
    return W.Slider(p, label, desc, min, max, step, function() return tbl()[key] end, function(v)
      tbl()[key] = v
      if after then after(v) end
    end, fmt)
  end
  function O.Drop(p, label, desc, options, tbl, key, after)
    return W.Dropdown(p, label, desc, options, function() return tbl()[key] end, function(v)
      tbl()[key] = v
      if after then after(v) end
    end)
  end
  function O.On(tbl, key, after, tip)
    return { function() return tbl()[key] end, function(v)
      tbl()[key] = v
      if after then after(v) end
    end, tip }
  end
  function O.Pct(v) return math.floor(v * 100 + 0.5) .. "%" end
  function O.Px(v) return v .. " px" end
  function O.Sec(v) return v .. " s" end

  -- pfUI's string settings ("1" / "0", numbers as text) as Octo widgets
  function O.PfChk(p, label, desc, group, key, after)
    return W.Check(p, label, desc, function() return group()[key] == "1" end, function(v)
      group()[key] = v and "1" or "0"
      if after then after(v) end
    end)
  end
  function O.PfSld(p, label, desc, min, max, step, group, key, after, fmt)
    return W.Slider(p, label, desc, min, max, step, function() return tonumber(group()[key]) end, function(v)
      group()[key] = tostring(v)
      if after then after(v) end
    end, fmt)
  end

  -- ON / OFF for a whole pfUI module (user, 24 Oct 2026: "things like this
  -- should be simply able to be toggled on and off"). pfUI starts or skips a
  -- module at load, so the change asks for a reload when the window closes.
  function O.ModuleSwitch(mod, what)
    return { function() return not (C.disabled and C.disabled[mod] == "1") end, function(v)
      C.disabled = C.disabled or {}
      C.disabled[mod] = v and "0" or "1"
      pfUI.gui.settingChanged = true
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: " .. (what or mod) .. (v and " on" or " off")
        .. " after a reload - close the options to reload.")
    end, (what or mod) .. " on or off (takes a reload: the options window offers it when you close it)." }
  end
  -- ON / OFF for a "1" / "0" setting; after(v) runs when it changes
  -- the flag of the language in use is lit and underlined, the others dimmed
  function O.PaintFlags()
    local fl = pfUI.gui and pfUI.gui.flags
    if not fl then return end
    local cur = W.Lang()
    for _, b in ipairs(fl) do
      local on = b.lang == cur
      b.tex:SetAlpha(on and 1 or .55)
      if on then b.mark:Show() else b.mark:Hide() end
    end
  end
  function O.SetLanguage(code)
    if W.Lang() == code then return end
    C.global.language = code
    O.PaintFlags()
    CreateQuestionDialog(T["Do you want to reload the UI now?"], function() ReloadUI() end)
  end

  function O.KeySwitch(group, key, tip, after)
    return { function() return group()[key] ~= "0" end, function(v)
      group()[key] = v and "1" or "0"
      if after then after(v) end
    end, tip }
  end

  -- A feature whose page needs its module running would lose its page - and
  -- its switch - once switched off. Then a stand-in page holds the switch.
  O.STANDIN = {
    { "actionbar", "Action Bars", "abgeneral", "General", "Action bars" },
    { "swing", "Swing Timer", "stbars", "Bars", "Swing Timer" },
    { "minimap", "Minimap", "mmmap", "Map", "Minimap" },
    { "meters", "Meters", "mtwindows", "Windows", "Meters" },
    { "gear", "Gear", "gearsets", "Gear sets", "Gear sets" },
  }
  function O:AddStandIns()
    for _, s in ipairs(O.STANDIN) do
      if C.disabled and C.disabled[s[1]] == "1" and not self.BUILD[s[3]] then
        local mod, title = s[1], s[5]
        self:AddPage(s[2], s[3], s[4], function(p)
          W.Heading(p, title, { on = O.ModuleSwitch(mod, title),
            about = title .. " is switched off. Switch it on and close the options to reload; its settings come back." })
          W.Note(p, title .. " is off. Use the switch at the top right to turn it back on.")
        end)
      end
    end
  end

  -- a page of the Octo kind; group = the topic list section it goes under
  function O:AddPage(group, key, label, build)
    local sec
    for _, s in ipairs(self.octo) do if s[1] == group then sec = s end end
    if not sec then
      sec = { group, {} }
      table.insert(self.octo, sec)
    end
    table.insert(sec[2], { key, label })
    self.BUILD[key] = build
    if self.frame then self:BuildNav() end
  end

  -- ---------------------------------------------------------------- the shell

  local function QuickTip(frame, title, text)
    frame:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
      GameTooltip:AddLine(title)
      GameTooltip:AddLine(text, 1, 1, 1, 1)
      GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  local hidden = CreateFrame("Frame", nil, g)
  hidden:Hide()
  O.hidden = hidden

  function O:Build()
    local f = g
    self.frame = f
    f:SetWidth(WIDTH)
    f:SetHeight(HEIGHT)
    f:SetClampedToScreen(true)

    -- flat backdrop (pfUI's backdrop frame takes OctoBG's colours)
    local bd = f.backdrop or f
    W.Flat(bd, K.bg, 1, K.lineHi)
    if f.backdrop_shadow then f.backdrop_shadow:Hide() end

    -- pfUI's title bar parts make way
    for _, k in ipairs({ "share", "install", "hoverbind", "unlock", "search", "close" }) do
      if f[k] then f[k]:Hide() end
    end
    f.title:ClearAllPoints()
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
    W.Font(f.title, 15, K.text[1], K.text[2], K.text[3])
    f.title:SetText("|cff33ccffpfUI|r Octo")
    f.version:ClearAllPoints()
    f.version:SetPoint("LEFT", f.title, "RIGHT", 10, -1)
    W.Font(f.version, 11, K.dim[1], K.dim[2], K.dim[3])
    f.version:SetText("v" .. (pfUI.version.octo or "?") .. "  -  your whole interface: frames, bars, meters, map and combat text")
    local close = W.Button(f, "X", 22, 22)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
    close:SetScript("OnClick", function() g:Hide() end)
    W.Tip(close, "Close", "Escape closes it too.")

    -- language flags (4 Nov 2026; user: "add flags at the top linked to languages quick easy"):
    -- one click sets pfUI's language and offers the reload it needs
    O.LANGS = {
      { "enUS", "English" }, { "deDE", "German" }, { "frFR", "French" }, { "esES", "Spanish" },
      { "ruRU", "Russian" }, { "koKR", "Korean" }, { "zhCN", "Chinese (Simplified)" }, { "zhTW", "Chinese (Traditional)" },
    }
    f.flags = {}
    local nflags = table.getn(O.LANGS)
    for i, l in ipairs(O.LANGS) do
      local b = CreateFrame("Button", nil, f)
      b:SetWidth(26)
      b:SetHeight(16)
      b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40 - (nflags - i) * 31, -10)
      b.tex = b:CreateTexture(nil, "ARTWORK")
      b.tex:SetAllPoints(b)
      b.tex:SetTexture("Interface\\AddOns\\pfUI\\img\\flags\\" .. l[1])
      b.tex:SetTexCoord(0, 1, 0, .625)
      b.mark = b:CreateTexture(nil, "OVERLAY")
      b.mark:SetTexture(K.accent[1], K.accent[2], K.accent[3], 1)
      b.mark:SetHeight(2)
      b.mark:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
      b.mark:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -2)
      b.lang, b.name = l[1], l[2]
      b:SetScript("OnClick", function() O.SetLanguage(this.lang) end)
      b:SetScript("OnEnter", function()
        this.tex:SetAlpha(1)
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(this.name)
        GameTooltip:AddLine("Switch pfUI to this language (it reloads).", 1, 1, 1, 1)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() O.PaintFlags() end)
      f.flags[i] = b
    end
    O.PaintFlags()

    self:BuildQuickBar(f)

    local nav = CreateFrame("Frame", nil, f)
    nav:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -74)
    nav:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
    nav:SetWidth(NAV_W)
    nav:EnableMouseWheel(true)
    nav:SetScript("OnMouseWheel", function()
      O.navOffset = (O.navOffset or 0) - arg1 * NAV_ROW * 3
      O:LayoutNav()
    end)
    W.Flat(nav, K.panel, 1, K.line)
    self.navFrame = nav
    -- the list fills whatever height the panel has, laid out again when it changes
    nav:SetScript("OnSizeChanged", function() if O.groups then O:LayoutNav() end end)
    nav:SetScript("OnShow", function() if O.groups then O:LayoutNav() end end)
    -- (1.12 sends no OnSizeChanged to a frame sized by its anchors: when the
    -- window changes height - fitting the screen - the list kept its first,
    -- smaller room and showed ten sections with empty space under them, user
    -- 25 Oct 2026. A watcher lays it out again whenever the height moves.)
    local watch = CreateFrame("Frame", nil, nav)
    watch:SetScript("OnUpdate", function()
      local h = nav:GetHeight() or 0
      if h > 110 and math.abs(h - (nav.laidH or 0)) > 1 and O.groups then
        nav.laidH = h
        O:LayoutNav()
      end
    end)
    nav.up = W.Arrow(nav, 9, "up")
    nav.up:SetPoint("TOP", nav, "TOP", 0, -2)
    nav.down = W.Arrow(nav, 9, "down")
    nav.down:SetPoint("BOTTOM", nav, "BOTTOM", 0, 2)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", NAV_W + 18, -74)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    W.Flat(content, K.panel, 1, K.line)
    self.content = content

    -- pfUI Octo or Blizzard, per section, over the page (octo-blizzard.lua;
    -- user, 23 Oct 2026: "EVERY PAGE / ADDON Should be easily toggled on or
    -- off at the top"). Shown on the pages of a section that has one; the
    -- page panel moves down under it.
    local swap = CreateFrame("Frame", nil, f)
    swap:SetPoint("TOPLEFT", f, "TOPLEFT", NAV_W + 18, -74)
    swap:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -74)
    swap:SetHeight(32)
    W.Flat(swap, K.panel, 1, K.line)
    swap:Hide()
    swap.parts = {}
    for i = 1, 3 do
      local part = {}
      part.label = W.Font(swap:CreateFontString(nil, "OVERLAY"), 12, K.text[1], K.text[2], K.text[3])
      part.octo = W.Button(swap, "pfUI Octo", 76, 22)
      part.blizz = W.Button(swap, "Blizzard", 68, 22)
      part.octo.which, part.blizz.which = "octo", "blizz"
      for _, b in ipairs({ part.octo, part.blizz }) do
        b:SetScript("OnClick", function()
          local BZ = pfUI.blizz
          if BZ and this.id then (BZ.Pick or BZ.Set)(this.id, this.which) end
          O:PaintSwap()
        end)
      end
      swap.parts[i] = part
    end
    swap.note = W.Font(swap:CreateFontString(nil, "OVERLAY"), 10, K.dim[1], K.dim[2], K.dim[3])
    swap.note:SetPoint("RIGHT", swap, "RIGHT", -10, 0)
    swap.note:SetText("switches at once - no reload")
    self.swap = swap

    -- pfUI's page area fills the page panel; its tree column is gone
    local root = g.frames
    root.area:ClearAllPoints()
    root.area:SetAllPoints(content)
    root.area:SetFrameLevel(content:GetFrameLevel() + 1)
    if root.area.backdrop then root.area.backdrop:Hide() end
    for _, k in ipairs({ "tree", "divider", "moreUp", "more", "wheel" }) do
      if root.area[k] then root.area[k]:Hide() end
    end
    if root.area.wheel then root.area.wheel:EnableMouseWheel(false) end

    self:BuildGrip(f)
    self:ApplyAlpha()
    self:BuildNav()
  end

  -- The window's size (user, 22 Oct 2026: "a window resize slider on the
  -- bottom right ... make the dragger stand out"): a grip in the accent
  -- colour; dragging it scales the whole window, its top left corner stays
  -- put. Right-click = normal size. Kept per account (B.Store().winscale).
  function O:ApplyScale(s)
    s = math.max(.6, math.min(1.6, s or tonumber(B.Store().winscale) or 1))
    local f = self.frame
    local l, t = f:GetLeft(), f:GetTop()
    local old = f:GetEffectiveScale() or 1
    f:SetScale(s)
    if l and t then
      -- keep the top left corner where it was on screen
      local new = f:GetEffectiveScale() or 1
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * old / new, t * old / new)
    end
    B.Store().winscale = s
  end

  function O:BuildGrip(f)
    local grip = CreateFrame("Button", nil, f)
    grip:SetWidth(26)
    grip:SetHeight(26)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(f:GetFrameLevel() + 20)
    grip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local tex = grip:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(grip)
    tex:SetTexture("Interface\\AddOns\\pfUI\\img\\octo\\resize-bottomright")
    tex:SetVertexColor(K.accent[1], K.accent[2], K.accent[3], 1)
    local glow = grip:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("TOPLEFT", grip, "TOPLEFT", -6, 6)
    glow:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", 4, -4)
    glow:SetTexture("Interface\\AddOns\\pfUI\\img\\plates\\cp-glow")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(K.accent[1], K.accent[2], K.accent[3], .7)
    grip:SetScript("OnEnter", function()
      glow:SetVertexColor(1, 1, 1, .9)
      GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
      GameTooltip:AddLine("Window size")
      GameTooltip:AddLine("Drag: bigger or smaller", 1, 1, 1)
      GameTooltip:AddLine("Right-click: normal size", 1, 1, 1)
      GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function()
      glow:SetVertexColor(K.accent[1], K.accent[2], K.accent[3], .7)
      GameTooltip:Hide()
    end)
    grip:SetScript("OnMouseDown", function()
      if arg1 == "RightButton" then return end
      local x, y = GetCursorPosition()
      this.from = { x, y, f:GetScale() or 1 }
      this:SetScript("OnUpdate", function()
        local d = this.from
        if not d then return end
        local cx, cy = GetCursorPosition()
        -- right and down = bigger, about 1 % per 6 px
        local move = ((cx - d[1]) + (d[2] - cy)) / (UIParent:GetEffectiveScale() or 1)
        O:ApplyScale(d[3] * (1 + move / 600))
      end)
    end)
    grip:SetScript("OnMouseUp", function()
      this.from = nil
      this:SetScript("OnUpdate", nil)
    end)
    grip:SetScript("OnClick", function()
      if arg1 == "RightButton" then O:ApplyScale(1) end
    end)
    self.grip = grip
    if tonumber(B.Store().winscale) then
      f:SetScale(math.max(.6, math.min(1.6, tonumber(B.Store().winscale))))
    else
      -- never bigger than the screen the first time it opens
      local sw, sh = UIParent:GetWidth() or WIDTH, UIParent:GetHeight() or HEIGHT
      local fit = math.min(1, (sw - 40) / WIDTH, (sh - 40) / HEIGHT)
      if fit > .5 and fit < 1 then f:SetScale(fit) end
    end
  end

  -- The strip under the title, on every page.
  function O:BuildQuickBar(f)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -36)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -36)
    bar:SetHeight(32)
    W.Flat(bar, K.panel, 1, K.line)
    self.quick = bar

    local x = 8
    local function Btn(text, width, tip, fn)
      local b = W.Button(bar, text, width, 22)
      b:SetPoint("LEFT", bar, "LEFT", x, 0)
      b:SetScript("OnClick", fn)
      QuickTip(b, text, tip)
      x = x + width + 6
      return b
    end
    Btn(T["Move Frames"], 100, "Every frame gets a box you can drag. Boxes snap to each other and to the grid. "
      .. "Alt-click two boxes to give the second the first one's size; right-click a box for its options.", function()
      if pfUI.unlock then
        -- layout mode closes this window and opens it again when done
        pfUI.unlock:Show()
      end
    end)
    -- Keybinds: pfUI's hover binding or the Key Map keyboard (user, 20 Oct 2026)
    local kb
    kb = Btn(T["Keybinds"], 80, "Pick how to bind keys: hover an action button and press a key, or a "
      .. "picture of your keyboard to drag spells onto (/keymap).", function()
      if not kb.menu then
        kb.menu = W.Menu(kb, {
          { key = "hover", label = "Original hover binding" },
          { key = "keymap", label = "Keyboard layout (Key Map)" },
          { key = "keybinds", label = "Every key binding (list)" },
        }, 200, function(k)
          if k == "keybinds" then
            if pfUI.keybinds then pfUI.keybinds:Toggle() end
          elseif k == "keymap" then
            if pfUI.keymap then pfUI.keymap:Toggle() end
          elseif pfUI.hoverbind then
            g:Hide()
            pfUI.hoverbind:Show()
          end
        end)
      end
      local open = kb.menu:IsShown()
      W.CloseMenus()
      if not open then kb.menu:Show() end
    end)
    Btn(T["Install"], 70, "Run the setup again: profile, layout, chat (/pfui install).", function()
      if pfUI.firstrun then
        g:Hide()
        pfUI.firstrun:Restart()
      end
    end)
    Btn(T["Profiles"], 80, "Named profiles for every character on this account, and profile strings to share (Settings > General).", function()
      -- (31 Oct 2026, GratisNinja: opening this froze the game 5 - 10 s and
      -- put this character's string on the clipboard over the one being
      -- moved - it pressed Export by itself. Now it opens the Profiles card.)
      if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection("stgeneral", "Profiles") else O:Open("stgeneral") end
    end)

    -- background opacity of this window
    local bl = W.Font(bar:CreateFontString(nil, "OVERLAY"), 12, K.text[1], K.text[2], K.text[3])
    bl:SetPoint("LEFT", bar, "LEFT", x + 10, 0)
    bl:SetText("Background")
    local s = W.SliderBar(bar, 70, "pfOctoQuickAlpha")
    s:SetPoint("LEFT", bl, "RIGHT", 10, 0)
    s:SetMinMaxValues(0.3, 1)
    s:SetValueStep(0.05)
    local sv = W.Font(bar:CreateFontString(nil, "OVERLAY"), 11, K.accent[1], K.accent[2], K.accent[3])
    sv:SetPoint("LEFT", s, "RIGHT", 8, 0)
    s:SetScript("OnValueChanged", function()
      if this.loading then return end
      B.Store().alpha = math.floor(this:GetValue() * 20 + 0.5) / 20
      sv:SetText(math.floor(B.Store().alpha * 100 + 0.5) .. "%")
      W.SliderPaint(this)
      O:ApplyAlpha()
    end)
    QuickTip(s, "Background", "How solid this window's background is: lower to see the game through it.")
    self.quickAlpha, self.quickAlphaText = s, sv

    -- find a setting
    local find = W.EditBox(bar, 190, "pfOctoQuickFind")
    find:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
    local hint = W.Font(find:CreateFontString(nil, "OVERLAY"), 11, K.dim[1], K.dim[2], K.dim[3])
    hint:SetPoint("LEFT", find, "LEFT", 7, 0)
    hint:SetText("Find a setting")
    local function Hint() if find.typing or (find:GetText() or "") ~= "" then hint:Hide() else hint:Show() end end
    find.OnFocus = Hint
    find:SetScript("OnEscapePressed", function()
      this:SetText("")
      this:ClearFocus()
    end)
    find:SetScript("OnEnterPressed", function()
      this:ClearFocus()
      local r = O.results
      if r and r[1] then O:Reveal(r[1]) end
    end)
    find:SetScript("OnTextChanged", function()
      Hint()
      O:Search(this:GetText())
    end)
    QuickTip(find, "Find a setting", "Type a word (\"font\", \"crit\", \"castbar\"): every setting that mentions it is "
      .. "listed. Click one to go straight to it. Enter goes to the first.")
    self.quickFind = find
  end

  function O:RefreshQuick()
    if not self.quick then return end
    local a = B.Store().alpha or 0.95
    self.quickAlpha.loading = true
    self.quickAlpha:SetValue(a)
    self.quickAlpha.loading = nil
    W.SliderPaint(self.quickAlpha)
    self.quickAlphaText:SetText(math.floor(a * 100 + 0.5) .. "%")
  end

  -- The window's and its panels' backgrounds follow the Background slider.
  function O:ApplyAlpha()
    if not self.frame then return end
    local a = B.Store().alpha or 0.95
    local bd = self.frame.backdrop or self.frame
    bd:SetBackdropColor(K.bg[1], K.bg[2], K.bg[3], a)
    for _, p in ipairs({ self.quick, self.navFrame, self.content }) do
      p:SetBackdropColor(K.panel[1], K.panel[2], K.panel[3], a)
    end
  end

  -- ---------------------------------------------------------------- topic list

  -- One topic: a flat row; the picked one gets a blue wash and a blue edge.
  local function NavButton(label, indent)
    local b = CreateFrame("Button", nil, O.navFrame)
    b:SetHeight(NAV_ROW)
    b.sel = W.Fill(b, K.accent, 0.16, "BACKGROUND")
    b.sel:SetAllPoints(b)
    b.sel:Hide()
    b.bar = W.Fill(b, K.accent, 1, "BORDER")
    b.bar:SetWidth(2)
    b.bar:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.bar:Hide()
    local hl = W.Fill(b, { 1, 1, 1 }, 0.05, "HIGHLIGHT")
    hl:SetAllPoints(b)
    b.text = W.Font(b:CreateFontString(nil, "OVERLAY"), 12, K.dim[1], K.dim[2], K.dim[3])
    b.text:SetPoint("LEFT", b, "LEFT", 10, 0)
    b.text:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetText(label)
    b.indent = indent
    b:EnableMouseWheel(true)
    b:SetScript("OnMouseWheel", O.navFrame:GetScript("OnMouseWheel"))
    return b
  end

  local function NavMark(b, on)
    if on then
      b.sel:Show()
      b.bar:Show()
      b.text:SetTextColor(1, 1, 1)
    else
      b.sel:Hide()
      b.bar:Hide()
      b.text:SetTextColor(K.dim[1], K.dim[2], K.dim[3])
    end
  end

  -- A picture for each section (user, 20 Oct 2026: "use actual picture and
  -- logos of spells"), from the game's icons; every name checked against
  -- the client's MPQ file lists. Keyed by the section name, lower case,
  -- letters only.
  local ICON = "Interface\\Icons\\"
  O.ICONS = {
    combattext = "Spell_Fire_FlameBolt", settings = "INV_Misc_Gear_01", unitframes = "INV_Misc_Head_Human_01",
    bagsbank = "INV_Misc_Bag_08", bags = "INV_Misc_Bag_08", loot = "INV_Misc_Coin_01", minimap = "INV_Misc_Map_01",
    buffs = "Spell_Holy_WordFortitude", actionbar = "Ability_DualWield", panel = "INV_Misc_Note_01",
    xpbar = "INV_Misc_Book_11", tooltip = "INV_Letter_15", castbar = "Spell_Nature_Lightning",
    chat = "INV_Scroll_03", nameplates = "Ability_Hunter_SniperShot", meters = "Ability_Marksmanship",
    thirdparty = "INV_Gizmo_01", components = "Trade_Engineering", about = "INV_Misc_QuestionMark",
    skins = "INV_Misc_Orb_01", threat = "Ability_Warrior_DefensiveStance", uilayouts = "INV_Misc_Map_01",
    actionbars = "Ability_DualWield", chatpanels = "INV_Scroll_03", minimapbuffs = "INV_Misc_Map_01",
    bagsloot = "INV_Misc_Bag_08", addons = "INV_Gizmo_01", swingtimer = "INV_Sword_04", gear = "INV_Chest_Plate06", weirdutils = "Ability_Hunter_MarkedForDeath", autoloot = "INV_Misc_Bag_10_Blue", artextras = "INV_Misc_Gem_Variety_01", combat = "Spell_Fire_FlameBolt", art = "INV_Misc_Gem_Variety_01",
  }
  function O.IconFor(name)
    local k = string.gsub(string.lower(name or ""), "[^%a]", "")
    return ICON .. (O.ICONS[k] or "INV_Misc_Rune_01")
  end

  -- A section header that folds its topics open or shut (one open at a time).
  -- A section without topics (a pfUI category with one page) opens its page.
  local function NavHeader(label, single)
    local h = CreateFrame("Button", nil, O.navFrame)
    h:SetHeight(24)
    h.icon = W.Arrow(h, 9, "right")
    h.icon:SetPoint("RIGHT", h, "RIGHT", -6, 0)
    if single then h.icon:Hide() end
    h.pic = h:CreateTexture(nil, "ARTWORK")
    h.pic:SetTexture(O.IconFor(label))
    h.pic:SetTexCoord(.08, .92, .08, .92)
    h.pic:SetWidth(18)
    h.pic:SetHeight(18)
    h.pic:SetPoint("LEFT", h, "LEFT", 4, 0)
    h.sel = W.Fill(h, K.accent, 0.16, "BACKGROUND")
    h.sel:SetAllPoints(h)
    h.sel:Hide()
    local hl = W.Fill(h, { 1, 1, 1 }, 0.04, "HIGHLIGHT")
    hl:SetAllPoints(h)
    h.text = W.Font(h:CreateFontString(nil, "OVERLAY"), 13, K.text[1], K.text[2], K.text[3])
    h.text:SetPoint("LEFT", h, "LEFT", 30, 0)
    h.text:SetPoint("RIGHT", h, "RIGHT", -18, 0)
    h.text:SetJustifyH("LEFT")
    h.text:SetText(label)
    h:EnableMouseWheel(true)
    h:SetScript("OnMouseWheel", O.navFrame:GetScript("OnMouseWheel"))
    -- (29 Oct 2026) About flashes NEW while a newer pfUI Octo was seen
    if label == "About" then
      local new = W.Font(h:CreateFontString(nil, "OVERLAY"), 12, 1, .82, .25)
      new:SetPoint("RIGHT", h, "RIGHT", -8, 0)
      new:SetText("NEW")
      new:Hide()
      h.newMark = new
      local tick = CreateFrame("Frame", nil, h)
      tick:SetScript("OnUpdate", function()
        local newer = pfUI.octoUpdate and pfUI.octoUpdate.Newer()
        if not newer then new:Hide() return end
        new:Show()
        new:SetAlpha(.35 + .65 * math.abs(math.sin(GetTime() * 3)))
      end)
    end
    return h
  end

  -- pfUI's categories and pages, in their order: key "l:<category>" or
  -- "l:<category>/<page>"; O.legacy[key] = { cat = button, page = button }
  local function LegacyList()
    local out = {}
    for _, cat in ipairs(g.frames.order or {}) do
      local name = cat.text and cat.text:GetText()
      if name and name ~= SEARCH and not O.replaced[name] then
        local entry = { name = name, cat = cat, pages = {} }
        for _, child in ipairs(cat.children or {}) do
          table.insert(entry.pages, { name = child.text:GetText(), btn = child })
        end
        table.insert(out, entry)
      end
    end
    return out
  end

  -- (re)builds the topic list: Octo sections first, then pfUI's categories
  function O:BuildNav()
    if not self.navFrame then return end
    self.navItems = self.navItems or {}
    for _, it in ipairs(self.navItems) do it:Hide() end
    self.navItems, self.groups, self.nav, self.groupOf, self.legacy = {}, {}, {}, {}, {}

    local function Group(name, single)
      local grp = { header = NavHeader(name, single), buttons = {}, name = name }
      grp.header.group = grp
      table.insert(self.navItems, grp.header)
      table.insert(self.groups, grp)
      return grp
    end
    local function Topic(grp, key, label)
      local b = NavButton(label, 12)
      b.key = key
      b:SetScript("OnClick", function() O:Select(this.key) end)
      table.insert(grp.buttons, b)
      table.insert(self.navItems, b)
      self.nav[key] = b
      self.groupOf[key] = grp
    end

    -- every source (an Octo section or a pfUI category) by name
    local sources, order = {}, {}
    for _, sec in ipairs(self.octo) do
      sources[sec[1]] = { octo = sec }
      table.insert(order, sec[1])
    end
    for _, e in ipairs(LegacyList()) do
      -- pfUI's own children are hidden away; gui.lua keeps driving them
      e.cat:SetParent(hidden)
      for _, pg in ipairs(e.pages) do pg.btn:SetParent(hidden) end
      sources[e.name] = { legacy = e }
      table.insert(order, e.name)
    end

    -- the sections in O.NAV's order (user, 22 Oct 2026: "reorder them in order
    -- of importance", grouped); anything not named there follows in its own order
    local plan, used = {}, {}
    for _, n in ipairs(O.NAV) do
      local list = {}
      for _, src in ipairs(n[2]) do
        local name = T[src] or src
        if sources[name] and not used[name] then table.insert(list, name) used[name] = true end
      end
      if table.getn(list) > 0 then table.insert(plan, { T[n[1]] or n[1], list }) end
    end
    for _, name in ipairs(order) do
      if not used[name] then table.insert(plan, { name, { name } }) end
    end

    local function Opener(grp)
      grp.header:SetScript("OnClick", function()
        O.openGroup = (O.openGroup ~= this.group) and this.group or nil
        -- opening a section shows its first page, as OctoBG's did once picked
        if O.openGroup == this.group and this.group.buttons[1] then
          O:Select(this.group.buttons[1].key)
        else
          O:LayoutNav()
        end
      end)
    end

    for _, sec in ipairs(plan) do
      local title, list = sec[1], sec[2]
      local only = sources[list[1]]
      if table.getn(list) == 1 and only.legacy and table.getn(only.legacy.pages) == 0 then
        -- one pfUI category without pages: the header is the topic
        local e = only.legacy
        local grp = Group(title, true)
        local key = "l:" .. e.name
        self.legacy[key] = { cat = e.cat }
        self.nav[key] = grp.header
        self.groupOf[key] = grp
        grp.single = key
        grp.header.key = key
        grp.header:SetScript("OnClick", function() O:Select(this.key) end)
      else
        local grp = Group(title)
        local merged = table.getn(list) > 1
        for _, name in ipairs(list) do
          local s = sources[name]
          if s.octo then
            for _, pg in ipairs(s.octo[2]) do Topic(grp, "o:" .. pg[1], pg[2]) end
          else
            local e = s.legacy
            if table.getn(e.pages) == 0 then
              local key = "l:" .. e.name
              self.legacy[key] = { cat = e.cat }
              Topic(grp, key, e.name)
            end
            for _, pg in ipairs(e.pages) do
              local key = "l:" .. e.name .. "/" .. pg.name
              self.legacy[key] = { cat = e.cat, page = pg.btn }
              -- pages of several categories in one section say whose they are
              Topic(grp, key, merged and (e.name .. ": " .. pg.name) or pg.name)
            end
          end
        end
        Opener(grp)
      end
    end
    self.navCount = self:CountLegacy()
    self:LayoutNav()
  end

  -- pfUI's categories and pages (the list is rebuilt when this changes)
  function O:CountLegacy()
    local n = 0
    for _, cat in ipairs(g.frames.order or {}) do
      n = n + 1 + table.getn(cat.children or {})
    end
    return n
  end

  -- Stacks the topic list (each header with its topics when open), scrolled
  -- by the mouse wheel when it is taller than the column.
  function O:LayoutNav()
    local nav = self.navFrame
    local rows, y = {}, 6
    for _, grp in ipairs(self.groups) do
      y = y + 2
      table.insert(rows, { grp.header, 0, y, 24 })
      y = y + 25
      local open = (self.openGroup == grp)
      if not grp.single then W.Turn(grp.header.icon, open and "down" or "right") end
      for _, b in ipairs(grp.buttons) do
        if open then
          table.insert(rows, { b, b.indent, y, NAV_ROW })
          y = y + NAV_ROW + 1
        else
          b:Hide()
        end
      end
    end
    local room = (nav:GetHeight() or 0) - 10
    if room >= 100 then nav.laidH = room + 10 end
    if room < 100 then
      -- the height is not known yet (the client reports it a frame late):
      -- a guess now, the real layout on the next frame. (A fixed 540 used to
      -- stay, and in the taller window the last sections vanished instead of
      -- moving down when a section opened - user, 22 Oct 2026.)
      room = 540
      nav:SetScript("OnUpdate", function()
        this:SetScript("OnUpdate", nil)
        if (this:GetHeight() or 0) > 110 then O:LayoutNav() end
      end)
    end
    local most = math.max(0, y - room)
    -- keep the open section in view
    if self.reveal then
      for _, r in ipairs(rows) do
        if r[1] == self.reveal then
          if r[3] - (self.navOffset or 0) < 6 then self.navOffset = r[3] - 6 end
          if r[3] + r[4] - (self.navOffset or 0) > room then self.navOffset = r[3] + r[4] - room end
        end
      end
      self.reveal = nil
    end
    local off = math.max(0, math.min(most, self.navOffset or 0))
    self.navOffset = off
    for _, r in ipairs(rows) do
      local b, top = r[1], r[3] - off
      if top < 2 or top + r[4] > room + 6 then
        b:Hide()
      else
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", nav, "TOPLEFT", 6 + r[2], -top)
        b:SetWidth(NAV_W - 12 - r[2])
        b:Show()
      end
    end
    if off > 0 then nav.up:Show() else nav.up:Hide() end
    if off < most then nav.down:Show() else nav.down:Hide() end
  end

  -- ---------------------------------------------------------------- pages

  -- every pfUI category area fills the page panel (new ones too)
  local function AnchorLegacy()
    for _, cat in ipairs(g.frames.order or {}) do
      if cat.area and not cat.area.octoPlaced then
        cat.area:ClearAllPoints()
        cat.area:SetAllPoints(O.content)
        cat.area.octoPlaced = true
      end
    end
  end

  local function HideLegacy(except)
    for _, cat in ipairs(g.frames.order or {}) do
      if cat ~= except and cat.area then cat.area:Hide() end
    end
  end

  function O:Page(key)
    local p = self.pages[key]
    if p then return p end
    p = W.Page(self.content)
    p.key = key
    p.frame:SetFrameLevel(self.content:GetFrameLevel() + 2)
    for _, sec in ipairs(self.octo) do
      for _, pg in ipairs(sec[2]) do
        if pg[1] == key then p.icon = O.IconFor(sec[1]) end
      end
    end
    self.BUILD[key](p)
    W.Done(p)
    self.pages[key] = p
    return p
  end

  -- Builds a page again (one whose cards depend on things added since: a new
  -- UI layout, a new talent spec); shown again at once when it is on screen.
  function O:Rebuild(key)
    local p = self.pages[key]
    if not p then return end
    p.frame:Hide()
    self.pages[key] = nil
    for i = table.getn(W.index), 1, -1 do
      if W.index[i].page == p then table.remove(W.index, i) end
    end
    if self.current == "o:" .. key and pfUI.gui and pfUI.gui:IsShown() then self:Select(self.current) end
  end

  local function HideOcto(except)
    for _, q in pairs(O.pages) do
      if q ~= except then q.frame:Hide() end
    end
    if O.searchPage and O.searchPage ~= except then O.searchPage.frame:Hide() end
  end

  -- Shows one Octo page (or the search results), hides the rest.
  function O:Show(p)
    W.CloseMenus()
    HideLegacy()
    HideOcto(p)
    p.frame:Show()
    W.Refresh(p)
  end

  -- Shows one of pfUI's pages in the page panel.
  function O:ShowLegacy(key)
    local l = self.legacy[key]
    if not l then return end
    W.CloseMenus()
    HideOcto()
    AnchorLegacy()
    HideLegacy(l.cat)
    l.cat.area:Show()
    if l.page then
      for _, child in ipairs(l.cat.children or {}) do
        if child ~= l.page and child.area then child.area:Hide() end
      end
      l.page.area:Show()
    end
  end

  -- the switch strip for the section this page is in
  function O:LayoutSwap(key)
    local swap, BZ = self.swap, pfUI.blizz
    if not swap then return end
    local grp = key and self.groupOf and self.groupOf[key]
    local ids = BZ and grp and BZ.GROUPS and BZ.GROUPS[grp.name]
    self.content:ClearAllPoints()
    self.content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -12, 12)
    if not ids then
      swap:Hide()
      self.content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", NAV_W + 18, -74)
      return
    end
    self.content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", NAV_W + 18, -110)
    local x = 10
    for i, part in ipairs(swap.parts) do
      local id = ids[i]
      local s = id and BZ.S[id]
      if s then
        part.label:ClearAllPoints()
        part.label:SetPoint("LEFT", swap, "LEFT", x, 0)
        part.label:SetText(s.label)
        local lw = math.max(60, (part.label:GetStringWidth() or 60) + 10)
        part.octo:ClearAllPoints()
        part.octo:SetPoint("LEFT", swap, "LEFT", x + lw, 0)
        part.blizz:ClearAllPoints()
        part.blizz:SetPoint("LEFT", part.octo, "RIGHT", 2, 0)
        part.octo.id, part.blizz.id = id, id
        part.label:Show() part.octo:Show() part.blizz:Show()
        x = x + lw + 76 + 2 + 68 + 20
      else
        part.label:Hide() part.octo:Hide() part.blizz:Hide()
      end
    end
    -- (three sections fill the strip: no room for the note)
    if ids[3] then swap.note:Hide() else swap.note:Show() end
    swap:Show()
    self:PaintSwap()
  end
  function O:PaintSwap()
    local BZ = pfUI.blizz
    if not self.swap or not BZ then return end
    for _, part in ipairs(self.swap.parts) do
      if part.octo.id then
        local blizz = BZ.IsBlizz(part.octo.id)
        W.Lit(part.octo, not blizz)
        W.Lit(part.blizz, blizz)
      end
    end
  end

  function O:Select(key)
    if not key or not (self.nav[key]) then key = self.first end
    if not key then return end
    self.current = key
    self.searching = nil
    self:LayoutSwap(key)
    for k, b in pairs(self.nav) do
      if b.sel and b.bar then NavMark(b, k == key) elseif b.sel then
        if k == key then b.sel:Show() else b.sel:Hide() end
      end
    end
    if self.groupOf[key] then
      self.openGroup = self.groupOf[key]
      self.reveal = self.groupOf[key].header
    end
    self:LayoutNav()
    if string.sub(key, 1, 2) == "o:" then
      self:Show(self:Page(string.sub(key, 3)))
    else
      self:ShowLegacy(key)
    end
  end

  -- The topic key of a pfUI category (and page) by their names, forgiving:
  -- colour codes, case and punctuation do not matter; a page that is not in
  -- that category is looked for in every category; a category alone gives
  -- its first page.
  local function Norm(s)
    s = string.gsub(s or "", "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    s = string.gsub(string.lower(s), "[^%w]", "")
    return s
  end
  function O:FindLegacy(cat, page)
    local nc, np = Norm(cat), page and Norm(page)
    local catFirst, anyPage
    for _, grp in ipairs(self.groups or {}) do
      local gname = Norm(grp.header.text:GetText())
      if grp.single then
        if gname == nc and not catFirst then catFirst = grp.single end
      else
        for _, b in ipairs(grp.buttons) do
          local _, _, kc, kp = string.find(b.key or "", "^l:(.-)/(.*)$")
          -- a category without pages inside a merged section ("l:Castbar")
          local _, _, whole = string.find(b.key or "", "^l:([^/]+)$")
          if whole and Norm(whole) == nc and not catFirst then catFirst = b.key end
          if kc then
            local sameCat = Norm(kc) == nc
            if sameCat and np and Norm(kp) == np then return b.key end
            if sameCat and not catFirst then catFirst = b.key end
            if np and not anyPage and Norm(kp) == np then anyPage = b.key end
          end
        end
      end
    end
    return catFirst or anyPage
  end

  -- Opens the window on a page: an Octo page key ("ctgeneral"), or a pfUI
  -- category (and page) by their shown names.
  function O:Open(key, page)
    if not g:IsShown() then
      self.opening = true
      g:Show()
      self.opening = nil
    end
    if key and self.BUILD[key] then
      -- an Octo page with tabs can open on one (unitframes-options: a frame)
      if page and self.tabs and self.tabs[key] then self.tabs[key](page) end
      self:Select("o:" .. key)
    elseif key and self.replaced[key] then
      -- pfUI's category has Octo pages now: open the section's first page
      local first
      for _, s in ipairs(self.octo) do
        if s[1] == key and s[2][1] then first = s[2][1][1] end
      end
      self:Select(first and ("o:" .. first) or self.current)
    elseif key then
      self:Select(self:FindLegacy(key, page) or self.current)
    else
      self:Select(self.current)
    end
  end

  -- ---------------------------------------------------------------- find a setting

  local RESULT_ROWS = 60

  -- Every page built once (hidden), so the search knows every setting.
  function O:BuildAll()
    if self.allBuilt then return end
    for key in pairs(self.BUILD) do
      local p = self:Page(key)
      if self.current ~= "o:" .. key then p.frame:Hide() end
    end
    -- pfUI's pages fill searchDB when first shown
    for _, cat in ipairs(g.frames.order or {}) do
      if cat.area then
        local was = cat.area:IsShown()
        cat.area:Show()
        for _, child in ipairs(cat.children or {}) do
          if child.area and not child.area:IsShown() then
            child.area:Show()
            child.area:Hide()
          end
        end
        if not was then cat.area:Hide() end
      end
    end
    self.allBuilt = true
    if self.current and not self.searching then self:Select(self.current) end
  end

  function O:SearchPage()
    if self.searchPage then return self.searchPage end
    local p = W.Page(self.content)
    p.frame:SetFrameLevel(self.content:GetFrameLevel() + 2)
    W.Heading(p, "Find a setting")
    p.count = W.Live(p, function() return O.searchText or "" end)
    p.rows = {}
    for i = 1, RESULT_ROWS do
      local row = W.Row(p, 22, 0, 2)
      local b = CreateFrame("Button", nil, row)
      b:SetAllPoints(row)
      W.Flat(b, K.card, 1, K.line)
      local hl = W.Fill(b, K.accent, 0.2, "HIGHLIGHT")
      hl:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
      hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
      b.text = W.Font(b:CreateFontString(nil, "OVERLAY"), 12, 1, 1, 1)
      b.text:SetPoint("LEFT", b, "LEFT", 10, 0)
      b.text:SetPoint("RIGHT", b, "RIGHT", -8, 0)
      b.text:SetJustifyH("LEFT")
      b:SetScript("OnClick", function() if this.entry then O:Reveal(this.entry) end end)
      row.b = b
      p.rows[i] = row
    end
    W.Done(p)
    self.searchPage = p
    return p
  end

  -- pfUI's own labels that hold the text: { label, where, frame, key }
  local function FindLegacy(text, out)
    local db = g.searchDB
    if not db then return end
    for _, obj in pairs(db) do
      local cap = obj[0]
      local n = table.getn(obj)
      local cat, page = obj[n], (n > 1) and obj[1] or nil
      local cname = cap and cat and cat.text and cat.text:GetText()
      local pname = page and page.text and page.text:GetText()
      if cname and not O.replaced[cname] then
        local where = cname .. (pname and (" > " .. pname) or "")
        local s = W.Score(text, cap, where)
        if s then
          table.insert(out, { legacy = true, label = cap, where = where, score = s,
                              key = "l:" .. cname .. (pname and ("/" .. pname) or ""), region = obj[-1] })
        end
      end
    end
  end

  function O:Search(text)
    if not self.frame then return end
    text = string.gsub(text or "", "^%s*(.-)%s*$", "%1")
    if string.len(text) < 2 then
      self.results = nil
      if self.searching then
        self.searching = nil
        self:Select(self.current)
      end
      return
    end
    self:BuildAll()
    local res = W.Find(text)
    FindLegacy(string.lower(text), res)
    -- best match first; equal ones keep the window's order
    for i, e in ipairs(res) do e.order = i end
    table.sort(res, function(a, b)
      if a.score ~= b.score then return a.score > b.score end
      return a.order < b.order
    end)
    self.results = res
    local p = self:SearchPage()
    local n = table.getn(res)
    if n == 0 then
      O.searchText = "Nothing matches \"" .. text .. "\"."
    else
      O.searchText = n .. " match" .. ((n == 1) and "" or "es") .. " for \"" .. text .. "\", best first - click one to go straight to it."
        .. ((n > RESULT_ROWS) and ("  |cff999999(best " .. RESULT_ROWS .. " shown)|r") or "")
    end
    for i = 1, RESULT_ROWS do
      local row, e = p.rows[i], res[i]
      if e then
        row.b.entry = e
        local where
        if e.legacy then
          where = e.where
        else
          where = e.page.title or e.page.key
          if e.card then where = where .. " > " .. (e.card.title or "Preview") end
        end
        row.b.text:SetText(e.label .. "   |cff999999" .. where .. "|r")
        row:Show()
      else
        row.b.entry = nil
        row:Hide()
      end
    end
    for _, b in pairs(self.nav) do if b.bar then NavMark(b, false) elseif b.sel then b.sel:Hide() end end
    self.searching = true
    self:Show(p)
  end

  -- Opens a search result's page (and card), scrolls to it and makes it glow.
  function O:Reveal(e)
    self.searching = nil
    if e.legacy then
      self:Select(e.key)
      local region = e.region
      local sf = region and region:GetParent() and region:GetParent().parent
      if sf and sf.SetVerticalScroll then
        local top, at = region:GetParent():GetTop(), region:GetTop()
        if top and at then sf:SetVerticalScroll(math.max(0, top - at - 40)) end
      end
      if region then W.Flash(region) end
      return
    end
    local p = e.page
    self:Select("o:" .. p.key)
    -- pages that show some cards at a time (section tabs) show this one's
    if p.onReveal then p.onReveal(e) end
    if e.card and not W.IsOpen(e.card) then W.SetOpen(e.card, true) end
    p.after = function()
      local top, at = p.body:GetTop(), e.region:GetTop()
      if top and at then
        local off = math.max(0, top - at - 40)
        local sb = getglobal(p.frame:GetName() .. "ScrollBar")
        if sb then sb:SetValue(off) else p.frame:SetVerticalScroll(off) end
      end
      W.Flash(e.region)
    end
    W.Measure(p)
  end

  -- Re-read the open page (after a setting changed somewhere).
  function O:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    self:RefreshQuick()
    local p = self.searching and self.searchPage
    if not p and self.current and string.sub(self.current, 1, 2) == "o:" then
      p = self.pages[string.sub(self.current, 3)]
    end
    if p then W.Refresh(p) end
  end

  -- ---------------------------------------------------------------- pfUI's pages, restyled

  -- pfUI's own pages get OctoBG's look once built: group boxes as cards with
  -- a title bar, square blue tick boxes, thin blue sliders with a round knob,
  -- flat text boxes, dropdowns and buttons, Roboto. Layout stays pfUI's.
  local function Field(f, col, line)
    local t = f and (f.backdrop or f)
    if t and t.SetBackdrop then W.Flat(t, col or K.field, 1, line or K.line) end
  end

  -- A pfUI number box ("200", "-12", "0.8") gets a slider beside it (user,
  -- 20 Oct 2026: "using sliders instead of numbers ... having the option to
  -- put numbers in also for accuracy"). The range is a guess from the
  -- setting's name and value; typing a bigger number widens it.
  local function Range(key, v)
    key = string.lower(key or "")
    local function Nice(n) return math.max(10, math.ceil(n / 10) * 10) end
    if (string.find(key, "alpha") or string.find(key, "opacity") or string.find(key, "transp")) and v <= 1 then
      return 0, 1, .05
    end
    if string.find(key, "scale") and v <= 5 then return .5, math.max(2, v), .05 end
    local dec = math.floor(v) ~= v
    if string.find(key, "off") or string.find(key, "pos") or string.find(key, "[xy]$") or v < 0 then
      local lim = Nice(math.max(50, math.abs(v) * 2))
      return -lim, lim, dec and .1 or 1
    end
    return 0, Nice(math.max(20, v * 2)), dec and .1 or 1
  end

  function O.NumberSlider(c)
    local v = tonumber(c.category and c.config and c.category[c.config])
    if not v or c.octoSlider then return end
    local lo, hi, step = Range(c.config, v)
    local inp = c.input
    inp:ClearAllPoints()
    inp:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -19)
    inp:SetWidth(64)
    inp:SetHeight(20)
    inp:SetJustifyH("RIGHT")
    local s = W.SliderBar(c, 100, nil)
    s:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -21)
    s:SetPoint("RIGHT", inp, "LEFT", -10, 0)
    s:SetMinMaxValues(lo, hi)
    s:SetValueStep(step)
    c.octoSlider = s
    local function Paint()
      local a, b = s:GetMinMaxValues()
      local w = (s:GetWidth() or 0) - 14
      local f = (b > a) and (s:GetValue() - a) / (b - a) or 0
      if not s.fillToThumb then s.fill:SetWidth(math.max(1, f * math.max(w, 1) + 4)) end
    end
    local function Fmt(n)
      if step >= 1 then return tostring(math.floor(n + .5)) end
      local t = string.format("%.2f", n)
      t = string.gsub(t, "0+$", "")
      return (string.gsub(t, "%.$", ""))
    end
    s.loading = true
    s:SetValue(math.max(lo, math.min(hi, v)))
    s.loading = nil
    s:SetScript("OnValueChanged", function()
      Paint()
      if this.loading then return end
      local n = math.floor(this:GetValue() / step + .5) * step
      -- the text box saves it (its OnTextChanged), as typing would
      inp:SetText(Fmt(n))
    end)
    s:SetScript("OnShow", Paint)
    s:SetScript("OnSizeChanged", Paint)
    local old = inp:GetScript("OnTextChanged")
    inp:SetScript("OnTextChanged", function()
      if old then old() end
      local n = tonumber(this:GetText())
      if n then
        local a, b = s:GetMinMaxValues()
        if n > b then
          local _, nb = Range(c.config, n)
          s:SetMinMaxValues(a, math.max(nb, n))
        end
        s.loading = true
        s:SetValue(n)
        s.loading = nil
        Paint()
      end
    end)
    W.Tip(s, c.caption and c.caption:GetText(), "Drag, or type an exact number in the box.")
    Paint()
  end

  local function SkinCell(c)
    local kind = c.cellkind
    if c.caption then W.Font(c.caption, 12, K.text[1], K.text[2], K.text[3]) end
    if c.tex then c.tex:SetTexture(1, 1, 1, .04) end
    if kind == "checkbox" and c.input and c.input.SetCheckedTexture then
      c.input:SetWidth(16)
      c.input:SetHeight(16)
      Field(c.input, K.field, K.lineHi)
      c.input:SetCheckedTexture(B.U.WHITE)
      local t = c.input:GetCheckedTexture()
      if t then
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", c.input, "TOPLEFT", 3, -3)
        t:SetPoint("BOTTOMRIGHT", c.input, "BOTTOMRIGHT", -3, 3)
        t:SetVertexColor(K.accent[1], K.accent[2], K.accent[3], 1)
      end
    elseif kind == "slider" and c.input and c.input.SetThumbTexture then
      local s = c.input
      if s.backdrop then s.backdrop:Hide() end
      if s.SetBackdrop then s:SetBackdrop(nil) end
      s:SetHeight(16)
      s:SetThumbTexture(W.ART.disc)
      local th = s:GetThumbTexture()
      if th then
        th:SetWidth(14)
        th:SetHeight(14)
        th:SetVertexColor(.95, .95, .96, 1)
      end
      local track = W.Fill(s, K.off, 1, "BACKGROUND")
      track:SetHeight(4)
      track:SetPoint("LEFT", s, "LEFT", 3, 0)
      track:SetPoint("RIGHT", s, "RIGHT", -3, 0)
      s.fill = W.Fill(s, K.accent, 1, "BORDER")
      s.fill:SetHeight(4)
      s.fill:SetPoint("LEFT", s, "LEFT", 3, 0)
      W.FillToThumb(s)
      local function Paint()
        local lo, hi = s:GetMinMaxValues()
        local w = (s:GetWidth() or 0) - 14
        local f = (hi and lo and hi > lo) and (s:GetValue() - lo) / (hi - lo) or 0
        if not s.fillToThumb then s.fill:SetWidth(math.max(1, f * math.max(w, 1) + 4)) end
      end
      -- the value: a box to type an exact number in
      local box
      if c.value then
        c.value:Hide()
        box = W.NumberBox(c, 64)
        box:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -1)
        box.Restore = function() box:SetText(c.value:GetText() or "") end
        box.OnNumber = function(text)
          local n = W.ParseNumber(text)
          if n then s:SetValue(n) end
        end
        box.Restore()
        W.Tip(box, c.caption and c.caption:GetText(), "Click and type a number for an exact value, then press Enter.")
      end
      local old = s:GetScript("OnValueChanged")
      s:SetScript("OnValueChanged", function()
        if old then old() end
        Paint()
        if box and not box.typing then box.Restore() end
      end)
      s:SetScript("OnShow", Paint)
      s:SetScript("OnSizeChanged", Paint)
      Paint()
    elseif kind == "dropdown" and c.input then
      Field(c.input)
      if c.input.text then W.Font(c.input.text, 11, K.text[1], K.text[2], K.text[3]) end
      if c.input.button and c.input.button.icon then
        c.input.button.icon:SetVertexColor(K.dim[1], K.dim[2], K.dim[3], 1)
      end
      if c.input.menuframe then Field(c.input.menuframe, K.card, K.lineHi) end
    elseif (kind == "text" or kind == "list") and c.input then
      Field(c.input)
      if c.input.SetFont then c.input:SetFont(W.UIFont(), 12, "") end
      if kind == "text" and c.numtype == "number" then O.NumberSlider(c) end
    elseif kind == "button" and c.button then
      Field(c.button, K.btn, K.line)
      local fs = c.button.GetFontString and c.button:GetFontString()
      if fs then W.Font(fs, 11, K.text[1], K.text[2], K.text[3]) end
    elseif kind == "color" and c.color then
      Field(c.color, K.field, K.lineHi)
    end
  end

  local function SkinGroup(grp)
    W.Flat(grp, K.card, 1, K.line)
    if grp.caption then
      local bar = W.Fill(grp, K.head, 1, "BORDER")
      bar:SetPoint("TOPLEFT", grp, "TOPLEFT", 1, -1)
      bar:SetPoint("TOPRIGHT", grp, "TOPRIGHT", -1, -1)
      bar:SetHeight(22)
      W.Font(grp.caption, 12, K.text[1], K.text[2], K.text[3])
      grp.caption:ClearAllPoints()
      grp.caption:SetPoint("TOPLEFT", grp, "TOPLEFT", 12, -6)
    end
  end

  function O.SkinPage(page)
    if not page or page.octoSkinned then return end
    page.octoSkinned = true
    if page.title then
      W.Font(page.title, 17, K.text[1], K.text[2], K.text[3])
      -- the section's picture before the title
      local area = page.parent and page.parent.GetParent and page.parent:GetParent()
      local btn = area and area.button
      local cat = btn and (btn.isChild and btn.parent or btn)
      if cat and cat.text then
        local ic = page:CreateTexture(nil, "ARTWORK")
        ic:SetTexture(O.IconFor(cat.text:GetText()))
        ic:SetTexCoord(.08, .92, .08, .92)
        ic:SetWidth(22)
        ic:SetHeight(22)
        local p1, rel, p2, x, y = page.title:GetPoint()
        ic:SetPoint("TOPLEFT", page, "TOPLEFT", x or 12, (y or -12) + 3)
        page.title:ClearAllPoints()
        page.title:SetPoint("TOPLEFT", page, "TOPLEFT", (x or 12) + 30, y or -12)
      end
    end
    for _, grp in ipairs(page.groups or {}) do SkinGroup(grp) end
    for _, c in ipairs({ page:GetChildren() }) do
      if c.cellkind then SkinCell(c) end
    end
  end
  g.OnPageBuilt = O.SkinPage

  -- ---------------------------------------------------------------- card tabs
  -- (31 Oct 2026, user: menus "overwhelming". A long page of cards gets tabs:
  -- one group of cards shows at a time, the first card of a group opens.)
  -- sections = { { key, label, icon name, { card titles } }, ... }; call
  -- O.CardTabs(p, sections) where the tabs go and O.TabFilter(p) at the end
  -- of the page's build. Cards in no section show under every tab.
  function O.CardTabs(p, sections)
    local t = { list = sections, of = {}, cur = p.tabsCur or sections[1][1] }
    for _, s in ipairs(sections) do
      for _, title in ipairs(s[4]) do t.of[title] = s[1] end
    end
    p.tabs = t
    local row = W.Row(p, 24, 0, 6)
    local n = table.getn(sections)
    local w = math.floor((W.CW - (n - 1) * 4) / n)
    local btns = {}
    for i, s in ipairs(sections) do
      local b = W.Button(row, s[2], w, 22)
      b:SetPoint("LEFT", row, "LEFT", (i - 1) * (w + 4), 0)
      b.key = s[1]
      local pic = b:CreateTexture(nil, "OVERLAY")
      pic:SetTexture("Interface\\Icons\\" .. s[3])
      pic:SetTexCoord(.08, .92, .08, .92)
      pic:SetWidth(16)
      pic:SetHeight(16)
      pic:SetPoint("LEFT", b, "LEFT", 5, 0)
      if b.label then
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", pic, "RIGHT", 5, 0)
        b.label:SetPoint("RIGHT", b, "RIGHT", -4, 0)
        b.label:SetJustifyH("LEFT")
      end
      W.Tip(b, s[2], "Shows: " .. table.concat(s[4], ", ") .. ".")
      b:SetScript("OnClick", function() O.TabSet(p, this.key) end)
      btns[i] = b
    end
    table.insert(p.items, { Refresh = function()
      for _, b in ipairs(btns) do W.Pick(b, b.key == p.tabs.cur) end
      O.TabFilter(p)
    end })
    p.tabFirst = p.last
    -- Find a setting / a preview click on a card in another tab: that tab first
    p.onReveal = function(e)
      local s = e.card and t.of[e.card.title]
      if s and s ~= t.cur then O.TabSet(p, s, true) end
    end
  end

  function O.TabFilter(p)
    local t = p and p.tabs
    if not t or not p.cards or not p.tabFirst then return end
    local prev, gap = p.tabFirst, 13
    for _, c in ipairs(p.cards) do
      local s = t.of[c.title]
      if not s or s == t.cur then
        c.card:ClearAllPoints()
        c.card:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
        c.card:Show()
        prev, gap = c.card, 9
      else
        c.card:Hide()
      end
    end
    p.last = prev
  end

  function O.TabSet(p, key, keepFolds)
    local t = p and p.tabs
    if not t then return end
    t.cur, p.tabsCur = key, key
    if not keepFolds then
      for _, c in ipairs(p.cards) do
        if t.of[c.title] == key then
          if not W.IsOpen(c) then W.SetOpen(c, true) end
          break
        end
      end
    end
    O.TabFilter(p)
    local sb = getglobal((p.frame:GetName() or "") .. "ScrollBar")
    if sb then sb:SetValue(0) elseif p.frame.SetVerticalScroll then p.frame:SetVerticalScroll(0) end
    if O.Refresh then O:Refresh() end
  end

  -- ---------------------------------------------------------------- Settings > General

  -- (31 Oct 2026, user: "a UI scale slider like in the original pfUI in the
  -- settings menu"). The scale is applied a moment after the slider stops,
  -- not while it moves: the window itself rescales under the mouse.
  local function BuildGeneral(p)
    local PP = pfUI.pixelperfect
    W.Heading(p, "Scale, profiles and look", { about = "UI scale, named profiles for every character, and the character window's look." })
    W.Card(p, "UI scale", { icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
      tip = "How big everything on the screen is. Kept per character, and applied at every login." })
    local wait = CreateFrame("Frame")
    wait:Hide()
    wait:SetScript("OnUpdate", function()
      if GetTime() < this.at then return end
      this:Hide()
      if PP and PP.Set then PP.Set(this.v) end
    end)
    local function Later(v)
      wait.v, wait.at = v, GetTime() + .35
      wait:Show()
    end
    W.Slider(p, "Scale", "Drag, or click the number and type one. Below .64 or above 1 works too (the game's own menu cannot do that).",
      .4, 1.2, .01, function() return UIParent:GetScale() end, Later,
      function(v) return string.format("%.2f", v) end)
    local function Pick(v) return function()
      if PP and PP.Set then PP.Set(v) end
      if O.Refresh then O:Refresh() end
    end end
    local perfect = PP and PP.Perfect and PP.Perfect()
    local list = {}
    if perfect then table.insert(list, { "Pixel perfect", Pick(perfect), 110 }) end
    table.insert(list, { "Small", Pick(.64), 70 })
    table.insert(list, { "Medium", Pick(.8), 70 })
    table.insert(list, { "Large", Pick(1), 70 })
    W.Buttons(p, list)
    W.Note(p, "Pixel perfect makes one game pixel one screen pixel" .. (perfect and (" (" .. string.format("%.2f", perfect) .. " on " .. (GetCVar("gxResolution") or "") .. ")") or "")
      .. ": the sharpest borders, but small on big screens.")
  end
  -- named profiles (pfUI_profiles is per account: every character sees them).
  -- A profile keeps the look and settings, not this character's UI layouts
  -- (their copies of every setting are this character's screens and large).
  O.prof = O.prof or {}
  function O.ProfileSave(name)
    if not name or name == "" then return end
    local copy = CopyTable(C)
    copy.layouts = nil
    pfUI_profiles[name] = copy
  end
  function O.ProfileLoad(name)
    local src = name and pfUI_profiles[name]
    if not src then return end
    local keep = { layouts = C.layouts, rchat = C.chat and C.chat.right and C.chat.right.enable }
    _G.pfUI_config = CopyTable(src)
    pfUI_config.layouts = keep.layouts
    pfUI:UpdateConfig("global", nil, "profile", name)
    if keep.rchat then pfUI:UpdateConfig("chat", "right", "enable", keep.rchat) end
    pfUI:LoadConfig()
    ReloadUI()
  end
  local function ProfileCard(p)
    W.Card(p, "Profiles", { icon = "Interface\\Icons\\INV_Misc_Book_11",
      tip = "Named profiles are kept for your whole account: save one here, load it on any other character." })
    local function List()
      local out = {}
      for name in pairs(pfUI_profiles or {}) do table.insert(out, { key = name, label = name }) end
      table.sort(out, function(a, b) return a.label < b.label end)
      return out
    end
    W.Dropdown(p, "Profile", "Pick one, then Load, Save over it or Delete.", List,
      function() return O.prof.pick end, function(v) O.prof.pick = v end)
    W.Buttons(p, {
      { "Load", function()
        local n = O.prof.pick
        if n and pfUI_profiles[n] then
          CreateQuestionDialog("Load profile '" .. n .. "'? The UI reloads; your UI layouts stay.", function() O.ProfileLoad(n) end)
        end
      end, 80, "This character takes the picked profile's settings (reloads)." },
      { "Save", function()
        local n = O.prof.pick
        if n then CreateQuestionDialog("Save your settings over profile '" .. n .. "'?", function() O.ProfileSave(n) end) end
      end, 80, "Your settings now go into the picked profile." },
      { "New profile", function()
        CreateQuestionDialog("A name for the new profile:", function()
          local name = string.gsub(this:GetParent().input:GetText() or "", "^%s*(.-)%s*$", "%1")
          if name ~= "" then
            O.ProfileSave(name)
            O.prof.pick = name
            if O.Refresh then O:Refresh() end
          end
        end, false, true)
      end, 110, "Saves your settings now under a new name." },
      { "Delete", function()
        local n = O.prof.pick
        if n and pfUI_profiles[n] then
          CreateQuestionDialog("Delete profile '" .. n .. "'?", function()
            pfUI_profiles[n] = nil
            O.prof.pick = nil
            if O.Refresh then O:Refresh() end
          end)
        end
      end, 80, "Removes the picked profile for every character." },
    })
    W.Buttons(p, { { "Share as text...", function() if pfShare then pfShare:Show() end end, 140,
      "A string to give to someone else (Export builds it - large settings take a few seconds)." } })
  end
  local general = BuildGeneral
  local function CharCard(p)
    W.Card(p, "Character window", { icon = "Interface\\Icons\\INV_Chest_Cloth_17",
      tip = "The character and inspect windows' look: a dark title shade with a thin line, your race's scenery behind the "
        .. "model and a square Enchants button. Off: pfUI's plain look. Takes a reload." })
    W.Check(p, "New character window look", nil, function() return C.appearance.charlook ~= "0" end,
      function(v) C.appearance.charlook = v and "1" or "0" pfUI.gui.settingChanged = true end)
  end
  BuildGeneral = function(p) general(p) ProfileCard(p) CharCard(p) end
  -- ("Scale, profiles and look": pfUI's own Settings > General is a different page, 1 Nov 2026)
  O:AddPage("Settings", "stgeneral", "Scale, profiles and look", BuildGeneral)

  -- ---------------------------------------------------------------- Blizzard UI
  -- (1 Nov 2026, user: "a Blizzard UI tab on the side ... a hard switch that moves
  -- everything to blizzard unlocked to move and make how you want with all the pfUI
  -- functionability"). One switch for every part, each part on its own below, and
  -- Move frames: the game's own frames get boxes too while they are Blizzard's.
  local function BuildBlizz(p)
    local BZ = pfUI.blizz
    W.Heading(p, "Blizzard UI", { about = "The game's own frames - player and target, action bars, minimap, buffs, "
      .. "chat and the rest - instead of pfUI Octo's, with everything pfUI Octo adds (meters, combat text, gear sets, "
      .. "specs, nameplate extras...) still on. Blizzard's frames move in Move frames like pfUI's, and each UI layout "
      .. "keeps its own places. Changes at once, no reload; Esc menu > \"pfUI Octo: undo Blizzard\" always goes back." })
    if not BZ or not BZ.PickAll then
      W.Note(p, "This needs pfUI Octo's Blizzard switches (module octo-blizzard), which are off.")
      return
    end
    W.Card(p, "The whole UI", { icon = "Interface\\Icons\\INV_Misc_Book_09",
      tip = "Every part at once. Switching to Blizzard's asks to be kept: not kept within 15 s, it goes back by itself." })
    W.Buttons(p, {
      { "Everything Blizzard's", function() BZ.PickAll(true) if O.Refresh then O:Refresh() end end, 170,
        "Every part to the game's own frames (kept only when you say so).", role = "pick" },
      { "Everything pfUI Octo's", function() BZ.PickAll(false) if O.Refresh then O:Refresh() end end, 170,
        "Every part back to pfUI Octo's frames.", role = "go" },
      { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, 120,
        "Boxes on every frame, Blizzard's too: drag them where you want them.", role = "open" },
    })
    W.Live(p, function()
      local n, all = 0, 0
      for _, id in ipairs(BZ.ORDER) do
        if BZ.S and BZ.S[id] then
          all = all + 1
          if BZ.IsBlizz(id) then n = n + 1 end
        end
      end
      return "Blizzard's now: |cffffffff" .. n .. " of " .. all .. "|r parts"
    end, 1)

    W.Card(p, "Each part", { icon = "Interface\\Icons\\INV_Misc_Gear_01",
      tip = "Ticked: the game's own frames for that part. The same switches sit at the top of each part's page." })
    for _, id in ipairs(BZ.ORDER) do
      local s = BZ.S and BZ.S[id]
      if s then
        local key = id
        W.Check(p, "Blizzard's " .. string.lower(s.label), nil, function() return BZ.IsBlizz(key) end,
          function(v) BZ.Pick(key, v and "blizz" or "octo") end)
      end
    end
  end
  O:AddPage("Blizzard UI", "blizzui", "Blizzard UI", BuildBlizz)

  -- ---------------------------------------------------------------- open / close

  O:Build()

  local onShow = g:GetScript("OnShow")
  g:SetScript("OnShow", function()
    if onShow then onShow() end
    -- categories added since (late modules, the search page) join the list
    -- (stand-in pages for switched-off features, once every module has run)
    if not O.standinsAdded then O.standinsAdded = true O:AddStandIns() end
    if O.navCount ~= O:CountLegacy() then O:BuildNav() end
    O.first = O.first or (O.octo[1] and O.octo[1][2][1] and ("o:" .. O.octo[1][2][1][1]))
    O:RefreshQuick()
    O:LayoutNav()
    if not O.opening then O:Select(O.current) end
  end)
  local onHide = g:GetScript("OnHide")
  g:SetScript("OnHide", function()
    W.CloseMenus()
    if onHide then onHide() end
  end)
end)
