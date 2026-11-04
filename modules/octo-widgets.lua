-- pfUI Octo :: option widgets (OctoBG's look)
-- Copied from OctoBG's core\Widgets.lua (the user's own addon) at the user's
-- request (20 Oct 2026: "copy Octo BGS style of UI and update PFUI"): a page
-- is a title (with an ON / OFF switch where the feature has one), a one-line
-- summary and a stack of folding cards. Inside a card the small controls
-- (tick boxes, sliders, dropdowns, colours) sit two to a row; text boxes,
-- buttons, key bindings and notes take the whole row. What a setting does is
-- in its tooltip (hover it), not under it.
--
-- Flat look: dark panels with 1 px borders, slim toggle switches, square tick
-- boxes, thin sliders, blue for what is on or picked - drawn from a white
-- texture and the disc / tri textures in img\octo, no game artwork.
--
-- Layout flows: each widget is anchored under the one before it (or beside
-- it, for the right-hand column), cards under each other, so a folded card
-- pulls everything below it up. Fonts are set by path. After a page is drawn,
-- open cards and the scroll height are measured (a frame each). Every widget
-- has a Refresh that re-reads its setting, and every labelled one goes into
-- W.index for the window's "Find a setting" box.
--
-- Differences from OctoBG's file: pfUI paths, wider pages (the window is
-- pfUI's), folded cards saved in pfUI_cache.octoui.cards, the font list is
-- the game's fonts and pfUI's fonts folder, no game-art helpers.

pfUI.octoui = pfUI.octoui or {}
local B = pfUI.octoui
local U = {}
B.U = U
local W = { menus = {}, index = {} }
B.W = W

U.WHITE = "Interface\\ChatFrame\\ChatFrameBackground"
U.FONT = "Fonts\\FRIZQT__.TTF"

-- Texture rotation by angle a (radians) around the middle: 8-value SetTexCoord.
function U.Rotate(tex, a)
  local s, c = math.sin(a) * 0.5, math.cos(a) * 0.5
  tex:SetTexCoord(0.5 - c + s, 0.5 - s - c,
                  0.5 - c - s, 0.5 - s + c,
                  0.5 + c + s, 0.5 + s - c,
                  0.5 + c - s, 0.5 + s + c)
end

function B:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: " .. tostring(msg))
end

-- what the window remembers (folded cards, background): per account
function B.Store()
  if type(pfUI_cache) ~= "table" then pfUI_cache = {} end
  if type(pfUI_cache.octoui) ~= "table" then pfUI_cache.octoui = {} end
  if type(pfUI_cache.octoui.cards) ~= "table" then pfUI_cache.octoui.cards = {} end
  return pfUI_cache.octoui
end

-- (octo, 22 Oct 2026: wider, so the options breathe - "easier on the eye")
W.WIDTH = 800      -- page body width
local X = 6        -- page margin
W.CW = 768         -- width inside a card
local HALF = 376   -- a cell of the two-column grid
local COL2 = 390   -- where the right-hand column starts
local CTRL = 196   -- whole-row controls start here, after their label
local CARD_HEAD = 24
local CARD_TOP = 32 -- card top to its first control

local MEDIA = "Interface\\AddOns\\pfUI\\img\\octo\\"
local FONTS = "Interface\\AddOns\\pfUI\\fonts\\"

-- The flat palette.
local C = {
  bg = { 0.067, 0.071, 0.078 },     -- the window
  panel = { 0.094, 0.098, 0.11 },   -- top bar, topic list, page
  card = { 0.125, 0.13, 0.145 },
  head = { 0.165, 0.17, 0.19 },     -- card bars
  field = { 0.07, 0.073, 0.08 },    -- boxes you type or pick in
  btn = { 0.18, 0.19, 0.21 },
  line = { 0.23, 0.24, 0.27 },      -- borders
  lineHi = { 0.36, 0.38, 0.43 },
  text = { 0.92, 0.92, 0.93 },
  dim = { 0.6, 0.61, 0.65 },
  accent = { 0.2, 0.7, 1 },         -- OctoBG blue
  on = { 0.22, 0.72, 0.42 },
  off = { 0.3, 0.31, 0.35 },
}
W.C = C

local ART = { disc = MEDIA .. "disc", tri = MEDIA .. "tri", grip = MEDIA .. "resize-bottomright" }
W.ART = ART

-- ---------------------------------------------------------------- fonts

-- Does a font file load? Tried once on a hidden font string: after a failed
-- SetFont the string keeps the font it had.
local probe, fontOK = nil, {}
function W.FontOK(path)
  if not path or path == "" then return false end
  local known = fontOK[path]
  if known ~= nil then return known end
  if not probe then
    local f = CreateFrame("Frame", nil, UIParent)
    probe = f:CreateFontString(nil, "OVERLAY")
  end
  probe:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
  local base = probe:GetFont()
  probe:SetFont(path, 12, "")
  local now = probe:GetFont()
  local ok = true
  if type(base) == "string" then
    local function N(s) return string.lower(string.gsub(s or "", "/", "\\")) end
    ok = (type(now) == "string") and N(now) == N(path)
  end
  fontOK[path] = ok
  return ok
end

-- Every font a menu can offer: the game's and pfUI's fonts folder. Each is
-- shown in its own face in the menus.
W.FONTS = {
  { key = "Fonts\\FRIZQT__.TTF", label = "Friz Quadrata (game)" },
  { key = "Fonts\\ARIALN.TTF", label = "Arial Narrow (game)" },
  { key = "Fonts\\skurri.ttf", label = "Skurri (game)" },
  { key = "Fonts\\MORPHEUS.ttf", label = "Morpheus (game)" },
  { key = FONTS .. "Expressway.ttf", label = "Expressway" },
  { key = FONTS .. "MyriadPro-Cond.ttf", label = "Myriad Condensed" },
  { key = FONTS .. "Myriad-Pro.ttf", label = "Myriad Pro" },
  { key = FONTS .. "BigNoodleTitling.ttf", label = "Big Noodle Titling" },
  { key = FONTS .. "PT-Sans-Narrow-Regular.ttf", label = "PT Sans Narrow" },
  { key = FONTS .. "PT-Sans-Narrow-Bold.ttf", label = "PT Sans Narrow Bold" },
  { key = FONTS .. "FiraSansCondensed-Regular.ttf", label = "Fira Sans Condensed" },
  { key = FONTS .. "FiraSansCondensed-SemiBold.ttf", label = "Fira Sans Condensed Bold" },
  { key = FONTS .. "Roboto.ttf", label = "Roboto" },
  { key = FONTS .. "RobotoMono.ttf", label = "Roboto Mono" },
  { key = FONTS .. "Share.ttf", label = "Share" },
  { key = FONTS .. "ShareBold.ttf", label = "Share Bold" },
  { key = FONTS .. "SquadaOne.ttf", label = "Squada One" },
  { key = FONTS .. "LondrinaSolid.ttf", label = "Londrina Solid" },
  { key = FONTS .. "BalooBhaina.ttf", label = "Baloo Bhaina" },
  { key = FONTS .. "Sniglet.ttf", label = "Sniglet" },
  { key = FONTS .. "DieDieDie.ttf", label = "Die Die Die" },
  { key = FONTS .. "Continuum.ttf", label = "Continuum" },
  { key = FONTS .. "Hooge.ttf", label = "Hooge" },
  { key = FONTS .. "Homespun.ttf", label = "Homespun" },
}
for i = 1, table.getn(W.FONTS) do W.FONTS[i].font = W.FONTS[i].key end

-- The fonts that load on this install (for menus).
function W.Fonts()
  local out = {}
  for i = 1, table.getn(W.FONTS) do
    if W.FontOK(W.FONTS[i].key) then table.insert(out, W.FONTS[i]) end
  end
  return out
end

-- Fonts set by path, never by font object. The options use Roboto once it is
-- known to load; Friz Quadrata until then / if not.
W.FONT = U.FONT
local ROBOTO = FONTS .. "Roboto.ttf"
local fontChecked
-- Language (4 Nov 2026, user: translated pfUI was "just half of it"). Every text
-- Octo draws goes through W.T: an exact English text is looked up in
-- pfUI_translation[language] (env\octo_<locale>.lua add Octo's words to pfUI's
-- own table); no entry = the English text. W.seen collects what was asked for
-- (tests\run.lua with PFUI_DUMP_STRINGS=<file> writes it: the list to translate).
W.seen = {}
function W.Lang()
  local g = pfUI_config and pfUI_config.global
  local l = g and g.language
  if l and pfUI_translation and pfUI_translation[l] then return l end
  return GetLocale()
end
function W.T(s)
  if type(s) ~= "string" or s == "" then return s end
  if _G.PFUI_COLLECT then W.seen[s] = true end
  local t = pfUI_translation and pfUI_translation[W.Lang()]
  local v = t and rawget(t, s)
  if v then return v end
  return s
end

function W.UIFont()
  if not fontChecked then
    fontChecked = true
    if W.FontOK(ROBOTO) then W.FONT = ROBOTO end
  end
  -- Roboto has neither Cyrillic nor the Asian scripts: Russian uses pfUI's PT Sans,
  -- Korean / Chinese the client's own font for the game's language
  local l = W.Lang()
  if l == "ruRU" then return FONTS .. "PT-Sans-Narrow-Bold.ttf" end
  if (l == "koKR" or l == "zhCN" or l == "zhTW") and STANDARD_TEXT_FONT then return STANDARD_TEXT_FONT end
  return W.FONT
end
function W.Font(fs, size, r, g, b)
  fs:SetFont(W.UIFont(), size or 12, "")
  if not fs.octoText then
    -- every text set on it is translated
    fs.octoText = true
    local raw = fs.SetText
    fs.SetText = function(self, t) return raw(self, W.T(t)) end
  end
  fs:SetShadowColor(0, 0, 0, 0.8)
  fs:SetShadowOffset(1, -1)
  if r then fs:SetTextColor(r, g, b) end
  return fs
end

-- ---------------------------------------------------------------- flat parts

-- A flat panel: one colour inside, a 1 px border.
function W.Flat(f, col, alpha, line)
  f:SetBackdrop({ bgFile = U.WHITE, edgeFile = U.WHITE, tile = false, tileSize = 0, edgeSize = 1,
                  insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  col = col or C.panel
  line = line or C.line
  f:SetBackdropColor(col[1], col[2], col[3], alpha or 1)
  f:SetBackdropBorderColor(line[1], line[2], line[3], 1)
end

-- A plain colour texture.
function W.Fill(parent, col, alpha, layer)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND")
  t:SetTexture(U.WHITE)
  t:SetVertexColor(col[1], col[2], col[3], alpha or 1)
  return t
end

-- The mouse-over light on a button.
local function Hover(b, alpha)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture(U.WHITE)
  hl:SetVertexColor(1, 1, 1, alpha or 0.07)
  hl:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
  hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
  return hl
end
W.Hover = Hover

-- A small triangle pointing "up", "down", "right" or "left".
local TURN = { up = 0, left = 1.5708, down = 3.1416, right = -1.5708 }
function W.Arrow(parent, size, way, col)
  local t = parent:CreateTexture(nil, "OVERLAY")
  t:SetTexture(ART.tri)
  t:SetWidth(size)
  t:SetHeight(size)
  col = col or C.dim
  t:SetVertexColor(col[1], col[2], col[3], 1)
  U.Rotate(t, TURN[way or "down"])
  return t
end
function W.Turn(t, way) U.Rotate(t, TURN[way]) end

-- Hover help: the setting's name, what it does in white.
function W.Tip(frame, title, text)
  if not title and not text then return end
  frame.tipTitle, frame.tipText = title, text
  frame:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    if this.tipTitle then GameTooltip:AddLine(W.T(this.tipTitle)) end
    if this.tipText then GameTooltip:AddLine(W.T(this.tipText), 1, 1, 1, 1) end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local count = 0
local function Name(kind)
  count = count + 1
  return "pfOctoOpt" .. kind .. count
end
W.Name = Name

local function Track(p, item)
  table.insert(p.items, item)
  return item
end

-- Labelled widgets are found by the window's search box.
local function Index(p, label, desc, region)
  if not label or not p.key then return end
  -- (found by the words on screen: the search box matches the translated text)
  table.insert(W.index, { page = p, card = p.cur, label = W.T(label), desc = W.T(desc), region = region })
end

local function Changed()
  if B.Options then B.Options:Refresh() end
end
W.Changed = Changed

-- A flat button; b:SetText works (its font string is the button's).
function W.Button(parent, text, width, height, name)
  local b = CreateFrame("Button", name, parent)
  b:SetWidth(width or 120)
  b:SetHeight(height or 22)
  W.Flat(b, C.btn, 1, C.line)
  local fs = W.Font(b:CreateFontString(nil, "OVERLAY"), 11, C.text[1], C.text[2], C.text[3])
  fs:SetPoint("CENTER", b, "CENTER", 0, 0)
  b:SetFontString(fs)
  b.label = fs
  b:SetText(text)
  Hover(b)
  b:SetScript("OnMouseDown", function() this:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1) end)
  b:SetScript("OnMouseUp", function() if not this.picked then this:SetBackdropBorderColor(C.line[1], C.line[2], C.line[3], 1) end end)
  return b
end

-- A button shown as the picked one of a row (tabs).
function W.Pick(b, on)
  b.picked = on
  local l = on and C.accent or C.line
  b:SetBackdropBorderColor(l[1], l[2], l[3], 1)
  if on then b.label:SetTextColor(1, 1, 1) else b.label:SetTextColor(C.dim[1], C.dim[2], C.dim[3]) end
  -- (the picked one is filled with the accent too: clear at a glance)
  if on then
    b:SetBackdropColor(C.accent[1] * .45, C.accent[2] * .45, C.accent[3] * .45, 1)
  else
    b:SetBackdropColor(C.btn[1], C.btn[2], C.btn[3], 1)
  end
end

-- A square tick box: blue inside when ticked.
function W.CheckBox(parent, size)
  local cb = CreateFrame("CheckButton", nil, parent)
  cb:SetWidth(size or 16)
  cb:SetHeight(size or 16)
  W.Flat(cb, C.field, 1, C.lineHi)
  cb:SetCheckedTexture(U.WHITE)
  local t = cb:GetCheckedTexture()
  if t then
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", cb, "TOPLEFT", 3, -3)
    t:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", -3, 3)
    t:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
  end
  Hover(cb, 0.12)
  return cb
end

-- A slim toggle switch: a pill (disc caps and a bar) with a knob; green and
-- the knob right when on. b.Set(on) paints it.
function W.Toggle(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(32)
  b:SetHeight(16)
  local function Disc(size, layer)
    local t = b:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(ART.disc)
    t:SetWidth(size)
    t:SetHeight(size)
    return t
  end
  local l, r = Disc(18), Disc(18)
  l:SetPoint("LEFT", b, "LEFT", -1, 0)
  r:SetPoint("RIGHT", b, "RIGHT", 1, 0)
  local m = b:CreateTexture(nil, "ARTWORK")
  m:SetTexture(U.WHITE)
  m:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -1)
  m:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -8, 1)
  local knob = Disc(14, "OVERLAY")
  knob:SetVertexColor(0.95, 0.95, 0.96, 1)
  function b.Set(on)
    local col = on and C.on or C.off
    l:SetVertexColor(col[1], col[2], col[3], 1)
    r:SetVertexColor(col[1], col[2], col[3], 1)
    m:SetVertexColor(col[1], col[2], col[3], 1)
    knob:ClearAllPoints()
    if on then knob:SetPoint("RIGHT", b, "RIGHT", -1, 0) else knob:SetPoint("LEFT", b, "LEFT", 1, 0) end
    b.on = on
  end
  b.Set(false)
  return b
end

-- A thin slider: grey track, the part up to the knob in blue, a round knob.
-- Call W.SliderPaint(s) after its value changes.
function W.SliderBar(parent, width, name)
  local s = CreateFrame("Slider", name, parent)
  s:SetOrientation("HORIZONTAL")
  s:SetWidth(width)
  s:SetHeight(16)
  s:EnableMouse(true)
  s:SetThumbTexture(ART.disc)
  local th = s:GetThumbTexture()
  if th then
    th:SetWidth(14)
    th:SetHeight(14)
    th:SetVertexColor(0.95, 0.95, 0.96, 1)
  end
  local track = W.Fill(s, C.off, 1, "BACKGROUND")
  track:SetHeight(4)
  track:SetPoint("LEFT", s, "LEFT", 3, 0)
  track:SetPoint("RIGHT", s, "RIGHT", -3, 0)
  s.fill = W.Fill(s, C.accent, 1, "BORDER")
  s.fill:SetHeight(4)
  s.fill:SetPoint("LEFT", s, "LEFT", 3, 0)
  s.fill:SetWidth(1)
  s.width = width
  W.FillToThumb(s)
  return s
end

-- The blue part ends at the knob: anchored to the thumb, so it follows it
-- wherever the slider's real width ends up (user, 20 Oct 2026: "the blue on
-- the bars isnt following the dragger" - a width worked out from GetWidth
-- was wrong on sliders stretched by two anchors).
function W.FillToThumb(s)
  local th = s:GetThumbTexture()
  if not th or not s.fill then return end
  s.fill:SetPoint("RIGHT", th, "CENTER", 0, 0)
  s.fillToThumb = true
end
function W.SliderPaint(s)
  local lo, hi = s:GetMinMaxValues()
  local f = 0
  if hi and lo and hi > lo then f = (s:GetValue() - lo) / (hi - lo) end
  if not s.fillToThumb then s.fill:SetWidth(math.max(1, f * (s.width - 14) + 4)) end
end

-- A flat text box. Focus is tracked (1.12 has no EditBox:HasFocus()) and
-- lights the border; eb.OnFocus(on) is called if set.
function W.EditBox(parent, width, name)
  local eb = CreateFrame("EditBox", name, parent)
  eb:SetWidth(width)
  eb:SetHeight(20)
  W.Flat(eb, C.field, 1, C.line)
  eb:SetTextInsets(6, 6, 0, 0)
  eb:SetFont(W.UIFont(), 12, "")
  eb:SetTextColor(C.text[1], C.text[2], C.text[3])
  eb:SetAutoFocus(false)
  eb:EnableMouse(true)
  eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  eb:SetScript("OnEditFocusGained", function()
    this.typing = true
    this:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    if this.OnFocus then this.OnFocus(true) end
  end)
  eb:SetScript("OnEditFocusLost", function()
    this.typing = nil
    this:SetBackdropBorderColor(C.line[1], C.line[2], C.line[3], 1)
    if this.OnFocus then this.OnFocus(false) end
  end)
  return eb
end

-- ---------------------------------------------------------------- page and flow

-- A container is the page body or a card's inside: where its last widget is
-- (and how far right), and a left cell waiting for its right-hand neighbour.
local function Cur(p) return p.cur or p end

-- The scroll bar of a UIPanelScrollFrameTemplate made flat: no arrow buttons,
-- a thin track down the right edge and a plain thumb. Mouse wheel still scrolls.
function W.FlatScroll(sf)
  local n = sf:GetName()
  local sb = n and getglobal(n .. "ScrollBar")
  if not sb then return end
  local up, down = getglobal(n .. "ScrollBarScrollUpButton"), getglobal(n .. "ScrollBarScrollDownButton")
  if up then up:Hide() up:SetAlpha(0) end
  if down then down:Hide() down:SetAlpha(0) end
  sb:ClearAllPoints()
  sb:SetPoint("TOPLEFT", sf, "TOPRIGHT", 10, 0)
  sb:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 10, 0)
  sb:SetWidth(6)
  local track = W.Fill(sb, C.field, 1, "BACKGROUND")
  track:SetAllPoints(sb)
  sb:SetThumbTexture(U.WHITE)
  local th = sb:GetThumbTexture()
  if th then
    th:SetWidth(6)
    th:SetHeight(40)
    th:SetVertexColor(C.lineHi[1], C.lineHi[2], C.lineHi[3], 1)
  end
end

function W.Page(parent)
  local sf = CreateFrame("ScrollFrame", Name("Scroll"), parent, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
  sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -24, 8)
  W.FlatScroll(sf)
  local body = CreateFrame("Frame", nil, sf)
  body:SetWidth(W.WIDTH)
  body:SetHeight(20)
  sf:SetScrollChild(body)
  sf:Hide()
  return { frame = sf, body = body, items = {}, cards = {},
           parent = body, x0 = X, y0 = 0, width = W.WIDTH - 2 * X, lastX = 0 }
end

-- A pinned strip at the top of a page (user, 22 Oct 2026: "hard lock the
-- preview window like a header and everything scrolls underneath"): it sits
-- above the page's scrolling part, which starts below it. build(p) fills it
-- with the usual widgets (they go into the strip while it runs). A title bar
-- folds it away; folded or not is kept per page (B.Store().pins).
function W.Pin(p, title, tip, build)
  local sf = p.frame
  local panel = sf:GetParent()
  local pin = CreateFrame("Frame", nil, sf)
  pin.octoPinned = true
  pin:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
  pin:SetWidth(W.WIDTH)
  pin:SetHeight(CARD_HEAD)
  W.Flat(pin, C.card, 1, C.line)
  local head = CreateFrame("Button", nil, pin)
  head:SetPoint("TOPLEFT", pin, "TOPLEFT", 1, -1)
  head:SetPoint("TOPRIGHT", pin, "TOPRIGHT", -1, -1)
  head:SetHeight(CARD_HEAD - 2)
  local bg = W.Fill(head, C.head, 1, "BACKGROUND")
  bg:SetAllPoints(head)
  Hover(head, 0.05)
  local arrow = W.Arrow(head, 10, "down")
  arrow:SetPoint("LEFT", head, "LEFT", 8, 0)
  local t = W.Font(head:CreateFontString(nil, "OVERLAY"), 12, C.text[1], C.text[2], C.text[3])
  t:SetPoint("LEFT", arrow, "RIGHT", 7, 0)
  t:SetText(title)
  local note = W.Font(head:CreateFontString(nil, "OVERLAY"), 10, C.dim[1], C.dim[2], C.dim[3])
  note:SetPoint("RIGHT", head, "RIGHT", -10, 0)
  note:SetText("stays here while the page scrolls")
  W.Tip(head, title, tip)
  local inner = CreateFrame("Frame", nil, pin)
  inner:SetPoint("TOPLEFT", pin, "TOPLEFT", 10, -CARD_HEAD - 4)
  inner:SetWidth(W.CW)
  inner:SetHeight(1)
  -- the widgets go into the strip while build runs
  local c = { parent = inner, x0 = 0, y0 = 0, lastX = 0, width = W.CW }
  local was = p.cur
  p.cur = c
  build(p)
  p.cur = was
  local key = p.key or title
  local function Store() local s = B.Store() s.pins = s.pins or {} return s.pins end
  local function Layout()
    local open = not Store()[key]
    local h = CARD_HEAD
    if open then
      inner:Show()
      local top, bottom = inner:GetTop(), c.last and c.last:GetBottom()
      local content = (top and bottom) and (top - bottom) or (pin.contentH or 200)
      pin.contentH = content
      h = CARD_HEAD + content + 14
      W.Turn(arrow, "down")
    else
      inner:Hide()
      W.Turn(arrow, "right")
    end
    pin:SetHeight(h)
    -- the scrolling part starts under the strip
    sf:ClearAllPoints()
    sf:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8 - h - 6)
    sf:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 8)
  end
  head:SetScript("OnClick", function()
    Store()[key] = not Store()[key] or nil
    Layout()
  end)
  -- measured once it is drawn (sizes come a frame late), and on every show
  pin:SetScript("OnShow", function() this.measure = 2 end)
  pin:SetScript("OnUpdate", function()
    if not this.measure then return end
    this.measure = this.measure - 1
    if this.measure <= 0 then this.measure = nil end
    Layout()
  end)
  pin.measure = 2
  Layout()
  p.pin = pin
  return pin
end

-- Anchors a region on a new line of container c, x from its left edge.
-- (octo) a little extra room between every row of the options. It had a
-- slider once; rebuilding every page as it moved was buggy (user, 22 Oct
-- 2026: "maybe we dont need this just make sure everything is tidy").
local SPACE = 3

local function Put(c, region, x, gap)
  x = x or 0
  region:ClearAllPoints()
  if c.last then
    region:SetPoint("TOPLEFT", c.last, "BOTTOMLEFT", x - c.lastX, -((gap or 4) + SPACE))
  else
    region:SetPoint("TOPLEFT", c.parent, "TOPLEFT", c.x0 + x, -(c.y0 + (gap or 4) + SPACE))
  end
  c.last, c.lastX, c.half = region, x, nil
  return region
end

-- A cell of the two-column grid: left on a new line, or right of the cell
-- waiting there. The taller of the two carries the line on.
local function PutHalf(c, cell, gap)
  local left = c.half
  if left then
    cell:ClearAllPoints()
    cell:SetPoint("TOPLEFT", left, "TOPLEFT", COL2, 0)
    if cell:GetHeight() > left:GetHeight() then c.last, c.lastX = cell, c.lastX + COL2 end
    c.half = nil
  else
    Put(c, cell, 0, gap)
    c.half = cell
  end
  return cell
end

-- A cell frame in the current container; half width unless full.
local function Cell(p, h, full)
  local c = Cur(p)
  local f = CreateFrame("Frame", nil, c.parent)
  f:SetWidth(full and c.width or HALF)
  f:SetHeight(h)
  return f, c
end

-- Anchors a region on its own line (indent from the left).
function W.Place(p, region, indent, gap)
  return Put(Cur(p), region, indent, gap)
end

-- A blank row of a fixed height for custom controls; children go relative to it.
function W.Row(p, h, indent, gap)
  local c = Cur(p)
  local r = CreateFrame("Frame", nil, c.parent)
  r:SetWidth(c.width - (indent or 0))
  r:SetHeight(h)
  return Put(c, r, indent, gap)
end

-- Open cards are measured one frame after drawing, the page the frame after
-- (its height depends on the cards'). p.after runs once everything is placed.
function W.Measure(p, tries)
  if not p.body then return end
  p.body:SetScript("OnUpdate", function()
    this:SetScript("OnUpdate", nil)
    local unknown
    for i = 1, table.getn(p.cards) do
      local c = p.cards[i]
      if c.last and W.IsOpen(c) then
        local top, bottom = c.parent:GetTop(), c.last:GetBottom()
        if top and bottom then
          c.h = math.max(1, top - bottom)
          c.parent:SetHeight(c.h)
          c.card:SetHeight(CARD_TOP + c.h + 10)
        else
          unknown = true
        end
      end
    end
    -- (octo) positions not known yet: try again on the next frames, so no
    -- card keeps its folded height while its options show (overlapping)
    if unknown and (tries or 0) < 10 then
      W.Measure(p, (tries or 0) + 1)
      return
    end
    this:SetScript("OnUpdate", function()
      this:SetScript("OnUpdate", nil)
      local top, bottom = this:GetTop(), p.last and p.last:GetBottom()
      if top and bottom then
        this:SetHeight(math.max(20, top - bottom + 18))
        p.frame:UpdateScrollChildRect()
      end
      if p.after then
        local fn = p.after
        p.after = nil
        fn()
      end
    end)
  end)
end

function W.Done(p)
  p.cur = nil
  W.Measure(p)
end

function W.Refresh(p)
  for i = 1, table.getn(p.items) do p.items[i].Refresh() end
  W.Measure(p)
end

function W.CloseMenus()
  for i = 1, table.getn(W.menus) do W.menus[i]:Hide() end
end

function W.Space(p, h)
  W.Row(p, h or 6, 0, 0)
end

-- An empty framed box for a preview; the caller fills it.
function W.Box(p, h)
  local c = Cur(p)
  local f = CreateFrame("Frame", nil, c.parent)
  f:SetWidth(c.width)
  f:SetHeight(h)
  W.Flat(f, C.field, 0.9, C.line)
  return Put(c, f, 0, 6)
end

-- ---------------------------------------------------------------- switches

-- An ON / OFF toggle with its word beside it (green ON, grey OFF).
function W.Switch(parent, get, set, tip)
  local f = CreateFrame("Frame", nil, parent)
  f:SetWidth(64)
  f:SetHeight(18)
  local tg = W.Toggle(f)
  tg:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  local word = W.Font(f:CreateFontString(nil, "OVERLAY"), 11)
  word:SetPoint("RIGHT", tg, "LEFT", -6, 0)
  function f.Refresh()
    local on = get() and true or false
    tg.Set(on)
    word:SetText(on and "ON" or "OFF")
    if on then word:SetTextColor(C.on[1] + 0.15, C.on[2] + 0.15, C.on[3] + 0.15) else word:SetTextColor(C.dim[1], C.dim[2], C.dim[3]) end
  end
  tg:SetScript("OnClick", function()
    set(not get())
    f.Refresh()
    Changed()
  end)
  W.Tip(tg, "On / off", tip)
  f.toggle = tg
  return f
end

-- A line of small tick boxes: { { label, get, set, tip }, ... }
function W.Toggles(p, list)
  local row = W.Row(p, 22, 0, 4)
  local x = 0
  for i = 1, table.getn(list) do
    local d = list[i]
    local cb = W.CheckBox(row, 14)
    cb:SetPoint("LEFT", row, "LEFT", x, 0)
    local fs = W.Font(row:CreateFontString(nil, "OVERLAY"), 11, C.dim[1], C.dim[2], C.dim[3])
    fs:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    fs:SetText(d[1])
    cb.get, cb.set = d[2], d[3]
    cb:SetScript("OnClick", function()
      this.set(this:GetChecked() and true or false)
      Changed()
    end)
    W.Tip(cb, d[1], d[4])
    Index(p, d[1], d[4], row)
    Track(p, { Refresh = function() cb:SetChecked(cb.get() and 1 or nil) end })
    x = x + 34 + (fs:GetStringWidth() or 60)
  end
  return row
end

-- ---------------------------------------------------------------- text

-- Page title with a thin line under it. o (all optional):
--   text  = the one-line summary under it
--   about = the long explanation, shown when hovering "How it works"
--   on    = { get, set, tip } - the feature's ON / OFF switch, top right
--   extra = { { label, get, set, tip }, ... } - tick boxes under the summary
function W.Heading(p, text, o)
  o = o or {}
  p.title = text
  local fs = W.Font(p.body:CreateFontString(nil, "OVERLAY"), 17, C.text[1], C.text[2], C.text[3])
  fs:SetText(text)
  Put(p, fs, p.icon and 30 or 2, 6)
  if p.icon then
    local ic = p.body:CreateTexture(nil, "ARTWORK")
    ic:SetTexture(p.icon)
    ic:SetTexCoord(.08, .92, .08, .92)
    ic:SetWidth(22)
    ic:SetHeight(22)
    ic:SetPoint("RIGHT", fs, "LEFT", -7, 0)
  end
  -- (octo) the summary line goes into "How it works" with the rest
  if o.text then
    o.about = o.about and (o.text .. "\n\n" .. o.about) or o.text
    o.text = nil
  end
  if o.about then
    local h = CreateFrame("Button", nil, p.body)
    h:SetWidth(90)
    h:SetHeight(18)
    h:SetPoint("LEFT", fs, "RIGHT", 12, -1)
    local t = W.Font(h:CreateFontString(nil, "OVERLAY"), 11, C.accent[1], C.accent[2], C.accent[3])
    t:SetPoint("LEFT", h, "LEFT", 0, 0)
    t:SetText("How it works")
    W.Tip(h, text, o.about)
  end
  if o.on then
    local sw = W.Switch(p.body, o.on[1], o.on[2], o.on[3])
    sw:SetPoint("TOPRIGHT", p.body, "TOPRIGHT", -X - 2, -6)
    Track(p, { Refresh = sw.Refresh })
  end
  Index(p, text, o.about, fs)
  local line = W.Fill(p.body, C.line, 1, "ARTWORK")
  line:SetWidth(W.WIDTH - 2 * X)
  line:SetHeight(1)
  Put(p, line, 0, 8)
  if o.text then
    local n = W.Font(p.body:CreateFontString(nil, "OVERLAY"), 11, C.dim[1], C.dim[2], C.dim[3])
    n:SetWidth(W.WIDTH - 2 * X - 4)
    n:SetJustifyH("LEFT")
    n:SetJustifyV("TOP")
    n:SetSpacing(3)
    n:SetText(o.text)
    Put(p, n, 2, 8)
  end
  if o.extra then W.Toggles(p, o.extra) end
  return fs
end

-- A folding card. o (all optional):
--   folded = shut until opened (the open / shut state is remembered)
--   on     = { get, set, tip } - an ON / OFF switch in the card's bar
--   tip    = hover text for the bar
--   text   = one plain line at the top of the card: what it is for
-- Everything added after it goes inside, until the next card or W.Done.
function W.Card(p, title, o)
  o = o or {}
  p.cur = nil
  local card = CreateFrame("Frame", nil, p.body)
  card:SetWidth(W.WIDTH - 2 * X)
  card:SetHeight(CARD_HEAD)
  W.Flat(card, C.card, 1, C.line)
  Put(p, card, 0, (table.getn(p.cards) == 0) and 10 or 6)
  local head = CreateFrame("Button", nil, card)
  head:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
  head:SetPoint("TOPRIGHT", card, "TOPRIGHT", -1, -1)
  head:SetHeight(CARD_HEAD - 2)
  local bg = W.Fill(head, C.head, 1, "BACKGROUND")
  bg:SetAllPoints(head)
  Hover(head, 0.05)
  local icon = W.Arrow(head, 10, "down")
  icon:SetPoint("LEFT", head, "LEFT", 8, 0)
  local t = W.Font(head:CreateFontString(nil, "OVERLAY"), 12, C.text[1], C.text[2], C.text[3])
  t:SetPoint("LEFT", icon, "RIGHT", 7, 0)
  -- (25 Oct 2026) o.icon: a picture before the title, a game icon path
  if o.icon then
    local pic = head:CreateTexture(nil, "ARTWORK")
    pic:SetTexture(o.icon)
    pic:SetTexCoord(.08, .92, .08, .92)
    pic:SetWidth(16)
    pic:SetHeight(16)
    pic:SetPoint("LEFT", icon, "RIGHT", 7, 0)
    t:ClearAllPoints()
    t:SetPoint("LEFT", pic, "RIGHT", 6, 0)
  end
  t:SetText(title)
  local inside = CreateFrame("Frame", nil, card)
  inside:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -CARD_TOP)
  inside:SetWidth(W.CW)
  inside:SetHeight(1)
  local c = { parent = inside, x0 = 0, y0 = 0, lastX = 0, width = W.CW, card = card, icon = icon,
              title = title, page = p, key = (p.key or "?") .. ":" .. title, default = not o.folded }
  if o.on then
    local sw = W.Switch(head, o.on[1], o.on[2], o.on[3])
    sw:SetPoint("RIGHT", head, "RIGHT", -8, 0)
    Track(p, { Refresh = sw.Refresh })
  end
  -- (octo, user 20 Oct: "get rid of so much text") the card's line of
  -- explanation lives in its title bar's tooltip, not on the page
  local tip = o.tip
  if o.text then tip = tip and (o.text .. "\n\n" .. tip) or o.text end
  W.Tip(head, tip and title, tip)
  head.c = c
  head:SetScript("OnClick", function() W.SetOpen(this.c, not W.IsOpen(this.c)) end)
  table.insert(p.cards, c)
  Index(p, title, o.tip or o.text, head)
  p.cur = c
  W.ApplyCard(c)
  return c
end
W.Sub = W.Card

function W.IsOpen(c)
  local s = B.Store().cards[c.key]
  if s == nil then return c.default end
  return s
end

function W.ApplyCard(c)
  if W.IsOpen(c) then
    W.Turn(c.icon, "down")
    c.parent:Show()
    c.card:SetHeight(c.h and (CARD_TOP + c.h + 10) or CARD_HEAD)
  else
    W.Turn(c.icon, "right")
    c.parent:Hide()
    c.card:SetHeight(CARD_HEAD)
  end
end

function W.SetOpen(c, open)
  B.Store().cards[c.key] = open and true or false
  W.ApplyCard(c)
  W.CloseMenus()
  W.Measure(c.page)
end

-- A paragraph: grey by default, white when bright is set. Height follows the text.
function W.Note(p, text, indent, bright)
  indent = indent or 0
  local c = Cur(p)
  local fs = W.Font(c.parent:CreateFontString(nil, "OVERLAY"), 11)
  fs:SetWidth(c.width - indent)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetSpacing(3)
  fs:SetText(text)
  if bright then fs:SetTextColor(C.text[1], C.text[2], C.text[3]) else fs:SetTextColor(C.dim[1], C.dim[2], C.dim[3]) end
  Put(c, fs, indent, (indent > 0) and 2 or 6)
  return fs
end

-- A line whose text comes from fn() each time the page is shown.
function W.Live(p, fn, lines)
  local c = Cur(p)
  local fs = W.Font(c.parent:CreateFontString(nil, "OVERLAY"), 11, C.text[1], C.text[2], C.text[3])
  fs:SetWidth(c.width)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetSpacing(3)
  fs:SetText(" ")
  Put(c, fs, 0, 6)
  Track(p, { Refresh = function() fs:SetText(fn()) end })
  return fs
end

-- ---------------------------------------------------------------- controls

-- The label of a whole-row control (text box, key binding).
local function Label(row, text)
  local fs = W.Font(row:CreateFontString(nil, "OVERLAY"), 12, C.text[1], C.text[2], C.text[3])
  fs:SetPoint("LEFT", row, "LEFT", 2, 0)
  fs:SetWidth(CTRL - 10)
  fs:SetHeight(26)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("MIDDLE")
  fs:SetText(text)
  return fs
end

-- The label of a grid cell: one line along its top.
local function TopLabel(row, text, width)
  local fs = W.Font(row:CreateFontString(nil, "OVERLAY"), 12, C.text[1], C.text[2], C.text[3])
  fs:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -1)
  fs:SetWidth(width)
  fs:SetHeight(14)
  fs:SetJustifyH("LEFT")
  fs:SetText(text)
  return fs
end

-- A mouse area over a label, for its tooltip.
local function HoverArea(row, fs, title, desc)
  if not desc then return end
  local h = CreateFrame("Frame", nil, row)
  h:SetPoint("TOPLEFT", fs, "TOPLEFT", -2, 2)
  h:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 2, -2)
  h:EnableMouse(true)
  W.Tip(h, title, desc)
end

-- full: take the whole row (a label too long for half a row does by itself).
function W.Check(p, label, desc, get, set, full)
  local row, c = Cell(p, 22, full)
  local cb = W.CheckBox(row, 16)
  cb:SetPoint("LEFT", row, "LEFT", 2, 0)
  local fs = W.Font(row:CreateFontString(nil, "OVERLAY"), 12, C.text[1], C.text[2], C.text[3])
  fs:SetPoint("LEFT", cb, "RIGHT", 8, 0)
  fs:SetText(label)
  if not full and (fs:GetStringWidth() or 0) > HALF - 30 then full = true end
  row:SetWidth(full and c.width or HALF)
  local function Click()
    set(cb:GetChecked() and true or false)
    Changed()
  end
  cb:SetScript("OnClick", Click)
  -- the label toggles too
  local hit = CreateFrame("Button", nil, row)
  hit:SetPoint("TOPLEFT", fs, "TOPLEFT", -2, 2)
  hit:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 2, -2)
  hit:SetScript("OnClick", function()
    cb:SetChecked(not cb:GetChecked() and 1 or nil)
    Click()
  end)
  W.Tip(cb, label, desc)
  W.Tip(hit, label, desc)
  if full then Put(c, row, 0, 6) else PutHalf(c, row, 6) end
  Index(p, label, desc, row)
  Track(p, { Refresh = function() cb:SetChecked(get() and 1 or nil) end })
  return cb
end

local function Decimals(step)
  if step >= 1 then return 0 end
  if step >= 0.1 then return 1 end
  return 2
end

-- The value of a slider as a box you can type in (user, 20 Oct 2026:
-- "having the option to put numbers in also for accuracy"). It shows the
-- formatted value ("80%", "12 px"); click it, type a number, press Enter.
-- onEnter(text) gets what was typed; Escape puts the value back.
function W.NumberBox(parent, width)
  local eb = CreateFrame("EditBox", Name("Num"), parent)
  eb:SetWidth(width or 58)
  eb:SetHeight(16)
  eb:SetBackdrop({ bgFile = U.WHITE, edgeFile = U.WHITE, tile = false, tileSize = 0, edgeSize = 1,
                   insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  eb:SetBackdropColor(C.field[1], C.field[2], C.field[3], 0)
  eb:SetBackdropBorderColor(C.line[1], C.line[2], C.line[3], 0)
  eb:SetTextInsets(4, 4, 0, 0)
  eb:SetFont(W.UIFont(), 12, "")
  eb:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  eb:SetJustifyH("RIGHT")
  eb:SetAutoFocus(false)
  eb:EnableMouse(true)
  local hl = eb:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture(U.WHITE)
  hl:SetVertexColor(1, 1, 1, 0.06)
  hl:SetAllPoints(eb)
  eb:SetScript("OnEditFocusGained", function()
    this.typing = true
    this:SetBackdropColor(C.field[1], C.field[2], C.field[3], 1)
    this:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    this:SetTextColor(1, 1, 1)
    this:HighlightText()
  end)
  eb:SetScript("OnEditFocusLost", function()
    this.typing = nil
    this:SetBackdropColor(C.field[1], C.field[2], C.field[3], 0)
    this:SetBackdropBorderColor(C.line[1], C.line[2], C.line[3], 0)
    this:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
    this:HighlightText(0, 0)
    if this.Restore then this.Restore() end
  end)
  eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  eb:SetScript("OnEnterPressed", function()
    local text = this:GetText()
    if this.OnNumber then this.OnNumber(text) end
    this:ClearFocus()
  end)
  return eb
end

-- the first number in a typed text ("80%", "-12 px", "1.5x")
function W.ParseNumber(text)
  local _, _, n = string.find(text or "", "(%-?%d*%.?%d+)")
  return n and tonumber(n)
end

-- fmt: a function(value) -> text, or nil for a plain number
function W.Slider(p, label, desc, min, max, step, get, set, fmt)
  local row, c = Cell(p, 38)
  local lab = TopLabel(row, label, HALF - 76)
  local val = W.NumberBox(row, 64)
  val:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, 1)
  W.Tip(val, label, "Click and type a number for an exact value, then press Enter.")
  local s = W.SliderBar(row, HALF - 12, Name("Slider"))
  s:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -19)
  s:SetMinMaxValues(min, max)
  s:SetValueStep(step)
  local dec = Decimals(step)
  local shown = min
  local function Text(v)
    if fmt then return fmt(v) end
    return string.format("%." .. dec .. "f", v)
  end
  local function Show(v)
    shown = v
    if not val.typing then val:SetText(Text(v)) end
    W.SliderPaint(s)
  end
  val.Restore = function() val:SetText(Text(shown)) end
  -- a typed number: a percent shown for a 0-1 value is divided by 100;
  -- it may go past the slider's ends (the slider just sits at its end)
  val.OnNumber = function(text)
    local n = W.ParseNumber(text)
    if not n then return end
    if max <= 1 and string.find(Text(max), "%%") and n > 1 then n = n / 100 end
    n = math.floor(n / step + 0.5) * step
    if dec == 0 then n = math.floor(n + 0.5) end
    set(n)
    s.loading = true
    s:SetValue(math.max(min, math.min(max, n)))
    s.loading = nil
    Show(n)
    Changed()
  end
  s:SetScript("OnValueChanged", function()
    if this.loading then return end
    local v = min + math.floor((this:GetValue() - min) / step + 0.5) * step
    if v > max then v = max end
    set(v)
    Show(v)
  end)
  W.Tip(s, label, desc)
  HoverArea(row, lab, label, desc)
  PutHalf(c, row, 6)
  Index(p, label, desc, row)
  Track(p, { Refresh = function()
    local v = get() or min
    s.loading = true
    s:SetValue(v)
    s.loading = nil
    Show(v)
  end })
  return s
end

-- A list menu; entries light up on hover. An option with a `font` is written
-- in that font; an option with `group` starts a heading line. More than
-- MENU_ROWS lines wrap into further columns so a long list stays on screen.
local MENU_ROWS = 20
function W.Menu(anchor, options, width, onPick)
  local menu = CreateFrame("Frame", nil, UIParent)
  local n = table.getn(options)
  local cols = math.ceil(n / MENU_ROWS)
  local rows = math.min(n, MENU_ROWS)
  menu:SetWidth(width * cols)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetClampedToScreen(true)
  W.Flat(menu, C.card, 0.98, C.lineHi)
  menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  menu:Hide()
  table.insert(W.menus, menu)
  for i = 1, n do
    local o = options[i]
    local col = math.floor((i - 1) / MENU_ROWS)
    local row = math.mod(i - 1, MENU_ROWS)
    local e = CreateFrame("Button", nil, menu)
    e:SetWidth(width - 8)
    e:SetHeight(17)
    e:SetPoint("TOPLEFT", menu, "TOPLEFT", 4 + col * width, -4 - row * 17)
    local t = W.Font(e:CreateFontString(nil, "OVERLAY"), 11, C.text[1], C.text[2], C.text[3])
    t:SetPoint("LEFT", e, "LEFT", 6, 0)
    t:SetWidth(width - 20)
    t:SetJustifyH("LEFT")
    if o.font then t:SetFont(o.font, 13, "") end
    -- (octo) an icon shows as a small square before its name
    if o.icon then
      local ic = e:CreateTexture(nil, "ARTWORK")
      ic:SetTexture(o.icon)
      ic:SetWidth(14)
      ic:SetHeight(14)
      ic:SetPoint("LEFT", e, "LEFT", 4, 0)
      if o.iconColor then ic:SetVertexColor(o.iconColor[1], o.iconColor[2], o.iconColor[3]) end
      t:SetPoint("LEFT", e, "LEFT", 24, 0)
    end
    -- (octo) a texture shows as a strip behind its name
    if o.texture then
      local s = e:CreateTexture(nil, "BORDER")
      s:SetTexture(o.texture)
      s:SetVertexColor(.82, .84, .88, 1)
      s:SetPoint("TOPLEFT", e, "TOPLEFT", 1, -2)
      s:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", -1, 2)
      t:SetFont(W.UIFont(), 11, "OUTLINE")
    end
    if o.group then t:SetTextColor(C.accent[1], C.accent[2], C.accent[3]) end
    t:SetText(o.label)
    if o.key ~= nil then
      local hl = e:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints(e)
      hl:SetTexture(U.WHITE)
      hl:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.25)
      e.key = o.key
      e:SetScript("OnClick", function()
        menu:Hide()
        onPick(this.key)
      end)
    end
    -- (octo, 26 Oct 2026) an entry with a tip explains itself on hover
    if o.tip then
      e.tipTitle, e.tipText = o.label, o.tip
      e:SetScript("OnEnter", function()
        GameTooltip:SetOwner(menu, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", menu, "TOPRIGHT", 4, 0)
        GameTooltip:SetText(this.tipTitle, 1, .82, 0)
        GameTooltip:AddLine(this.tipText, 1, 1, 1, 1)
        GameTooltip:Show()
      end)
      e:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
  end
  menu:SetHeight(rows * 17 + 8)
  return menu
end

-- A flat dropdown box with a small arrow. Returns the frame, its text, and
-- the button (twice: callers may want the arrow and the box apart).
function W.DropBox(parent, width)
  local f = CreateFrame("Button", nil, parent)
  f:SetWidth(width)
  f:SetHeight(20)
  W.Flat(f, C.field, 1, C.line)
  Hover(f, 0.05)
  local text = W.Font(f:CreateFontString(nil, "OVERLAY"), 11, C.text[1], C.text[2], C.text[3])
  text:SetPoint("LEFT", f, "LEFT", 7, 0)
  text:SetPoint("RIGHT", f, "RIGHT", -20, 0)
  text:SetJustifyH("LEFT")
  local arrow = W.Arrow(f, 9, "down")
  arrow:SetPoint("RIGHT", f, "RIGHT", -7, 0)
  return f, text, f, f
end

-- A compact dropdown for custom rows: options { { key, label } }.
function W.MiniDrop(parent, width, options, get, set, menuWidth)
  local f, text, btn, hit = W.DropBox(parent, width)
  -- options may be a function: the list is read again each time the menu
  -- opens, so things made since (a new gear set) are in it (24 Oct 2026)
  local list = options
  local function Opts()
    if type(list) == "function" then return list() or {} end
    return list
  end
  local function Sig(o)
    local s = ""
    for i = 1, table.getn(o) do s = s .. tostring(o[i].key) .. "\1" .. tostring(o[i].label) .. "\2" end
    return s
  end
  local menu, sig
  local function Build()
    local o = Opts()
    local s = Sig(o)
    if menu and s == sig then return end
    if menu then menu:Hide() end
    sig = s
    menu = W.Menu(f, o, menuWidth or math.max(width, 120), function(k)
      set(k)
      Changed()
    end)
  end
  Build()
  local function Toggle()
    Build()
    local open = menu:IsShown()
    W.CloseMenus()
    if not open then menu:Show() end
  end
  btn:SetScript("OnClick", Toggle)
  -- (octo) the picked texture shows in the box too
  local sample = f:CreateTexture(nil, "BORDER")
  sample:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
  sample:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 2)
  sample:SetVertexColor(.82, .84, .88, 1)
  sample:Hide()
  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetWidth(14)
  icon:SetHeight(14)
  icon:SetPoint("LEFT", f, "LEFT", 4, 0)
  icon:Hide()
  local function Refresh()
    local k = get()
    sample:Hide()
    icon:Hide()
    text:SetPoint("LEFT", f, "LEFT", 7, 0)
    local options = Opts()
    for i = 1, table.getn(options) do
      local o = options[i]
      if o.key == k then
        W.Font(text, 11, C.text[1], C.text[2], C.text[3])
        if o.font then text:SetFont(o.font, 12, "") end
        if o.texture then
          sample:SetTexture(o.texture)
          sample:Show()
          text:SetFont(W.UIFont(), 11, "OUTLINE")
        end
        if o.icon then
          icon:SetTexture(o.icon)
          if o.iconColor then icon:SetVertexColor(o.iconColor[1], o.iconColor[2], o.iconColor[3]) else icon:SetVertexColor(1, 1, 1) end
          icon:Show()
          text:SetPoint("LEFT", f, "LEFT", 24, 0)
        end
        text:SetText(o.label)
        return
      end
    end
    W.Font(text, 11, C.text[1], C.text[2], C.text[3])
    text:SetText(tostring(k))
  end
  return f, Refresh, hit
end

-- A key binding set right here: click, press a key (with Shift / Ctrl / Alt).
-- Escape cancels, right-click clears.
local nkey = 0
local function KeyName(action)
  local k = GetBindingKey and GetBindingKey(action)
  return k or "Not set"
end
function W.KeyBind(p, label, desc, action)
  local row = W.Row(p, 26, 0, 6)
  local lab = Label(row, label)
  HoverArea(row, lab, label, desc)
  nkey = nkey + 1
  local b = W.Button(row, KeyName(action), 150, 22, Name("Key" .. nkey))
  b:SetPoint("LEFT", row, "LEFT", CTRL + 2, 0)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local function Show()
    b:SetText(KeyName(action))
  end
  local function Stop()
    b.waiting = nil
    b:EnableKeyboard(false)
    W.Pick(b, false)
    b.label:SetTextColor(C.text[1], C.text[2], C.text[3])
    Show()
  end
  b:SetScript("OnClick", function()
    if arg1 == "RightButton" then
      local k1, k2 = GetBindingKey(action)
      if k1 then SetBinding(k1) end
      if k2 then SetBinding(k2) end
      SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
      Stop()
      return
    end
    b.waiting = true
    b:EnableKeyboard(true)
    W.Pick(b, true)
    b:SetText("Press a key...")
  end)
  b:SetScript("OnKeyDown", function()
    if not this.waiting then return end
    local key = arg1
    if key == "ESCAPE" then Stop() return end
    if key == "SHIFT" or key == "CTRL" or key == "ALT" or key == "UNKNOWN" then return end
    if IsShiftKeyDown() then key = "SHIFT-" .. key end
    if IsControlKeyDown() then key = "CTRL-" .. key end
    if IsAltKeyDown() then key = "ALT-" .. key end
    local old = GetBindingAction(key)
    local k1, k2 = GetBindingKey(action)
    if k1 then SetBinding(k1) end
    if k2 then SetBinding(k2) end
    SetBinding(key, action)
    SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
    if old and old ~= "" and old ~= action then
      B:Print(key .. " was \"" .. (GetBindingText and GetBindingText(old, "BINDING_NAME_") or old) .. "\" - it is now this key.")
    end
    Stop()
  end)
  b:SetScript("OnHide", function() if this.waiting then Stop() end end)
  W.Tip(b, label, (desc and (desc .. "\n\n") or "") .. "Click, then press the key you want (Shift, Ctrl and Alt work too). "
    .. "Escape cancels, right-click clears.")
  Index(p, label, desc, row)
  Track(p, { Refresh = Show })
  return b
end

-- options: { { key = ..., label = ... }, ... }
function W.Dropdown(p, label, desc, options, get, set)
  local row, c = Cell(p, 40)
  local lab = TopLabel(row, label, HALF - 8)
  HoverArea(row, lab, label, desc)
  local f, Refresh, hit = W.MiniDrop(row, HALF - 12, options, get, set, math.max(HALF - 12, 200))
  f:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -18)
  W.Tip(hit, label, desc)
  PutHalf(c, row, 6)
  Index(p, label, desc, row)
  Track(p, { Refresh = Refresh })
  return f
end

-- A flat colour swatch; get() -> r, g, b, a.
function W.Swatch(parent, size)
  local sw = CreateFrame("Button", nil, parent)
  sw:SetWidth(size or 18)
  sw:SetHeight(size or 18)
  W.Flat(sw, C.field, 1, C.lineHi)
  local fill = sw:CreateTexture(nil, "ARTWORK")
  fill:SetTexture(U.WHITE)
  fill:SetPoint("TOPLEFT", sw, "TOPLEFT", 2, -2)
  fill:SetPoint("BOTTOMRIGHT", sw, "BOTTOMRIGHT", -2, 2)
  Hover(sw, 0.2)
  sw.fill = fill
  return sw
end

function W.Color(p, label, desc, get, set)
  local row, c = Cell(p, 22)
  local sw = W.Swatch(row, 16)
  sw:SetPoint("LEFT", row, "LEFT", 2, 0)
  local fs = W.Font(row:CreateFontString(nil, "OVERLAY"), 12, C.text[1], C.text[2], C.text[3])
  fs:SetPoint("LEFT", sw, "RIGHT", 8, 0)
  fs:SetText(label)
  local function Apply() sw.fill:SetVertexColor(get()) end
  sw:SetScript("OnClick", function()
    local r, g, b, a = get()
    ColorPickerFrame.func = function()
      local nr, ng, nb = ColorPickerFrame:GetColorRGB()
      set(nr, ng, nb, 1 - OpacitySliderFrame:GetValue())
      Apply()
    end
    ColorPickerFrame.opacityFunc = ColorPickerFrame.func
    ColorPickerFrame.cancelFunc = function()
      set(r, g, b, a)
      Apply()
    end
    ColorPickerFrame.hasOpacity = 1
    ColorPickerFrame.opacity = 1 - (a or 1)
    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    ShowUIPanel(ColorPickerFrame)
  end)
  W.Tip(sw, label, desc or "Click to pick a colour.")
  PutHalf(c, row, 6)
  Index(p, label, desc, row)
  Track(p, { Refresh = Apply })
  return sw
end

-- list: { { text, fn, width, tip }, ... } in one row
-- A button that is on (a test running, the look in use, the choice made):
-- accent edge, accent-tinted fill and white text, so what is in use is clear
-- everywhere (user, 23 Oct 2026). Off: a plain button again.
function W.Lit(b, on)
  b.picked = on
  if on then
    b:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    b:SetBackdropColor(C.accent[1] * .45, C.accent[2] * .45, C.accent[3] * .45, 1)
    b.label:SetTextColor(1, 1, 1)
  else
    b:SetBackdropBorderColor(C.line[1], C.line[2], C.line[3], 1)
    b:SetBackdropColor(C.btn[1], C.btn[2], C.btn[3], 1)
    b.label:SetTextColor(C.text[1], C.text[2], C.text[3])
  end
end

-- A row of buttons: { label, func, width, tip, on = function } - `on` (or
-- the 5th field) lights the button while it returns true. Buttons grow to
-- fit their words.
function W.Buttons(p, list)
  local row = W.Row(p, 24, 0, 6)
  local x = 0
  local lit = {}
  for i = 1, table.getn(list) do
    local d = list[i]
    local w = d[3] or 130
    local b = W.Button(row, d[1], w, 22, Name("Btn"))
    local tw = b.label.GetStringWidth and b.label:GetStringWidth()
    if tw and tw + 20 > w then w = math.floor(tw + 20) b:SetWidth(w) end
    b:SetPoint("LEFT", row, "LEFT", x, 0)
    b.fn = d[2]
    b.on = d.on or d[5]
    b:SetScript("OnClick", function()
      this.fn()
      if this.on then W.Lit(this, this.on() and true or false) end
      Changed()
    end)
    W.Tip(b, d[4] and d[1], d[4])
    Index(p, d[1], d[4], row)
    if b.on then table.insert(lit, b) end
    x = x + w + 6
  end
  if table.getn(lit) > 0 then
    local function Paint()
      for _, b in ipairs(lit) do
        local on = b.on() and true or false
        if on ~= b.picked then W.Lit(b, on) end
      end
    end
    for _, b in ipairs(lit) do W.Lit(b, b.on() and true or false) end
    row:SetScript("OnUpdate", function()
      if (this.tick or 0) > GetTime() then return end
      this.tick = GetTime() + .25
      Paint()
    end)
    if p.items then table.insert(p.items, { Refresh = Paint }) end
  end
  return row
end

function W.Edit(p, label, desc, get, set, width)
  local row = W.Row(p, 26, 0, 6)
  local lab = Label(row, label)
  HoverArea(row, lab, label, desc)
  local eb = W.EditBox(row, math.min(width or 220, Cur(p).width - CTRL - 16), Name("Edit"))
  eb:SetPoint("LEFT", row, "LEFT", CTRL + 2, 0)
  eb:SetScript("OnEnterPressed", function()
    set(this:GetText())
    this:ClearFocus()
    Changed()
  end)
  W.Tip(eb, label, (desc and (desc .. " ") or "") .. "Press Enter to save.")
  Index(p, label, desc, row)
  Track(p, { Refresh = function()
    if not eb.typing then eb:SetText(get() or "") end
  end })
  return eb
end

-- ---------------------------------------------------------------- search

-- A short glow over a region (a search result found on its page).
-- The scrolling page a region sits in (the nearest scroll frame above it).
function W.Viewport(region)
  local f = region and region:GetParent()
  while f do
    -- a pinned strip (W.Pin) does not scroll: nothing cuts it off
    if f.octoPinned then return end
    if f.GetVerticalScrollRange and f.GetObjectType and f:GetObjectType() == "ScrollFrame" then return f end
    f = f:GetParent()
  end
end

-- A region's rectangle cut to its page's visible part, in UIParent's units:
-- left, right, top, bottom, or nil when none of it shows.
function W.Visible(region, pad)
  pad = pad or 0
  -- (a zoomed preview's stage grows past its box: the box is what is seen)
  region = region.outer or region
  local l, r, t, b = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
  if not (l and r and t and b) then return end
  local k = (region:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
  l, r, t, b = l * k - pad, r * k + pad, t * k + pad, b * k - pad
  local v = W.Viewport(region)
  if v and v:GetLeft() then
    local vk = (v:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    l, r = math.max(l, v:GetLeft() * vk), math.min(r, v:GetRight() * vk)
    t, b = math.min(t, v:GetTop() * vk), math.max(b, v:GetBottom() * vk)
  end
  if r <= l or t <= b then return end
  return l, r, t, b
end

-- A short glow over a region (a search result, a card opened from the
-- preview), only over the part of it that shows on its page: it never
-- spills out of the window (user, 22 Oct 2026), even when scrolled.
function W.Flash(region)
  -- a frame (a card, a row) glows itself: an accent wash and border drawn on
  -- it, above its controls, cut off by the page's scrolling like the rest of it
  if region and region.CreateTexture and region.GetChildren then
    local g = region.octoFlash
    if not g then
      g = CreateFrame("Frame", nil, region)
      g:SetAllPoints(region)
      g.fill = g:CreateTexture(nil, "OVERLAY")
      g.fill:SetAllPoints(g)
      g.fill:SetTexture(U.WHITE)
      g.edges = {}
      for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 2 },
                             { "TOPLEFT", "BOTTOMLEFT", 2, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 2, 0 } }) do
        local e = g:CreateTexture(nil, "OVERLAY")
        e:SetTexture(U.WHITE)
        e:SetPoint(pts[1], g, pts[1], 0, 0)
        e:SetPoint(pts[2], g, pts[2], 0, 0)
        if pts[3] > 0 then e:SetWidth(pts[3]) else e:SetHeight(pts[4]) end
        g.edges[i] = e
      end
      g:SetScript("OnUpdate", function()
        this.t = (this.t or 0) - (arg1 or 0)
        if this.t <= 0 then this:Hide() return end
        -- bright, then a slow fade
        local a = math.min(1, this.t / 1.2)
        this.fill:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], .22 * a)
        for _, e in ipairs(this.edges) do e:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], a) end
      end)
      region.octoFlash = g
    end
    g:SetFrameLevel((region:GetFrameLevel() or 1) + 15)
    g.t = 2.4
    g:Show()
    return
  end
  local f = W.flash
  if not f then
    f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    W.Flat(f, C.accent, 0.18, C.accent)
    f:SetScript("OnUpdate", function()
      this.t = this.t - (arg1 or 0)
      local l, r, t, b = W.Visible(this.region, 3)
      if this.t <= 0 or not l or not this.region:IsVisible() then this:Hide() return end
      this:ClearAllPoints()
      this:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
      this:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", r, b)
      this:SetAlpha(math.min(1, this.t))
    end)
    W.flash = f
  end
  f.region = region
  f.t = 2
  f:SetAlpha(0)
  f:Show()
end

-- How well a setting matches the search (user, 26 Oct 2026: "BANG ON POINT
-- it takes you to the exact thing"): every word typed must be somewhere in
-- it; the setting's own name counts most (exact > starts with > holds the
-- whole text > holds the words), then its card / page, then its help.
-- nil = no match.
function W.Score(text, label, where, desc)
  label, where, desc = string.lower(label or ""), string.lower(where or ""), string.lower(desc or "")
  local all = label .. " " .. where .. " " .. desc
  local score = 0
  for word in string.gfind(text, "%S+") do
    if not string.find(all, word, 1, true) then return nil end
    if string.find(" " .. label, "[^%w]" .. string.gsub(word, "(%W)", "%%%1")) then score = score + 120
    elseif string.find(label, word, 1, true) then score = score + 80
    elseif string.find(where, word, 1, true) then score = score + 30
    else score = score + 5 end
  end
  local clean = string.gsub(label, "|c%x%x%x%x%x%x%x%x", "")
  if clean == text then score = score + 1000
  elseif string.sub(clean, 1, string.len(text)) == text then score = score + 600
  elseif string.find(clean, text, 1, true) then score = score + 400
  elseif string.find(where, text, 1, true) then score = score + 60 end
  -- shorter names first among equals ("Buffs" before "Buff timer colour")
  return score - string.len(clean) / 100
end

-- Index entries matching text, best first (e.score set).
function W.Find(text)
  local out = {}
  text = string.lower(text or "")
  if string.len(text) < 2 then return out end
  for i = 1, table.getn(W.index) do
    local e = W.index[i]
    local s = W.Score(text, e.label, (e.card and e.card.title or "") .. " " .. (e.page.title or ""), e.desc)
    if s then
      e.score = s
      table.insert(out, e)
    end
  end
  return out
end
