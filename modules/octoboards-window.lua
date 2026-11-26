pfUI:RegisterModule("octoboards-window", "vanilla", function ()
  -- pfUI Octo :: OctoBoards window (26 Nov 2026): one window, three tabs - Awards (tonight's podium and award cards on the
  -- raid's own loading-screen art), Boards (categories left, ranked rows right, scope and period chips) and Player (a
  -- player's card: crowns, every number with its rank). Clicking a name anywhere opens that player's card.
  -- Art is the game's own: raid loading screens (Interface\Glues\LoadingScreens), spell / item icons, pfUI's class icons.
  local LB = pfUI.boards
  if not LB then return end
  local W = pfUI.octoui and pfUI.octoui.W
  local PAL = (W and W.C) or { bg = { .067, .071, .078 }, panel = { .094, .098, .11 }, card = { .125, .13, .145 },
    line = { .23, .24, .27 }, text = { .92, .92, .93 }, dim = { .6, .61, .65 }, accent = { .2, .7, 1 }, label = { .52, .53, .57 } }
  local ICON = "Interface\\Icons\\"
  local GLUE = "Interface\\Glues\\LoadingScreens\\"
  local FONTS = "Interface\\AddOns\\pfUI\\fonts\\"
  local TITLE = FONTS .. "FiraSansCondensed-SemiBold.ttf"
  local BODY = FONTS .. "FiraSansCondensed-Regular.ttf"
  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local WIDTH, HEIGHT, BANNER = 880, 600, 150
  local GOLD, SILVER, BRONZE = { 1, .82, .3 }, { .78, .8, .86 }, { .8, .52, .3 }
  local MEDAL = { GOLD, SILVER, BRONZE }
  local UI = {}
  local floor = math.floor
  LB.ui = UI

  -- zone -> loading screen
  UI.ART = { ["Molten Core"] = "LoadScreenMoltenCore", ["Blackwing Lair"] = "LoadScreenBlackWingLair",
    ["Onyxia's Lair"] = "LoadScreenMoltenCore", ["Zul'Gurub"] = "LoadScreenZulGurub", ["Naxxramas"] = "LoadScreenNaxxramas",
    ["Ruins of Ahn'Qiraj"] = "LoadScreenAhnQiraj20man", ["Ahn'Qiraj"] = "LoadScreenAhnQiraj40man",
    ["Temple of Ahn'Qiraj"] = "LoadScreenAhnQiraj40man", ["Warsong Gulch"] = "LoadScreenWarsongGulch" }
  function UI.ArtFor(zone, kind)
    local a = zone and UI.ART[zone]
    if a then return GLUE .. a end
    if kind == "pvp" then return GLUE .. "LoadScreenPvpBattleground" end
    return GLUE .. "LoadScreenEasternKingdom"
  end

  -- ------------------------------------------------------------------ small parts
  local function Font(fs, path, size, r, g, b)
    -- (a font file that does not load leaves the string without one: the game's font then)
    pcall(fs.SetFont, fs, path, size, "")
    if not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "") end
    fs:SetTextColor(r or PAL.text[1], g or PAL.text[2], b or PAL.text[3])
    fs:SetShadowColor(0, 0, 0, .9)
    fs:SetShadowOffset(1, -1)
    return fs
  end
  local function Text(parent, size, path, r, g, b, layer)
    return Font(parent:CreateFontString(nil, layer or "OVERLAY"), path or BODY, size, r, g, b)
  end
  local function Fill(parent, c, a, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetTexture(WHITE)
    t:SetVertexColor(c[1], c[2], c[3], a or 1)
    return t
  end
  local function Edge(f, c, a)
    local function L(p1, p2, w, h)
      local t = Fill(f, c, a, "BORDER")
      t:SetPoint(p1, f, p1)
      t:SetPoint(p2, f, p2)
      if w then t:SetWidth(w) else t:SetHeight(h) end
    end
    L("TOPLEFT", "TOPRIGHT", nil, 1) L("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    L("TOPLEFT", "BOTTOMLEFT", 1) L("TOPRIGHT", "BOTTOMRIGHT", 1)
  end
  -- an icon with a thin dark frame (cropped like the game's buttons)
  local function Icon(parent, size, path, layer)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetWidth(size) holder:SetHeight(size)
    local bg = Fill(holder, { 0, 0, 0 }, 1)
    bg:SetAllPoints(holder)
    local t = holder:CreateTexture(nil, layer or "ARTWORK")
    t:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
    t:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
    t:SetTexCoord(.08, .92, .08, .92)
    if path then t:SetTexture(path) end
    holder.tex = t
    return holder
  end
  local function ClassIcon(tex, class)
    local c = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if c and pfUI.media and pfUI.media["img:classicons"] then
      tex:SetTexture(pfUI.media["img:classicons"])
      tex:SetTexCoord(c[1], c[2], c[3], c[4])
    else
      tex:SetTexture(ICON .. "INV_Misc_QuestionMark")
      tex:SetTexCoord(.08, .92, .08, .92)
    end
  end
  UI.ClassIcon = ClassIcon
  -- a plain word button; role = accent wash when lit
  local function Chip(parent, label, w, onClick, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w or 80) b:SetHeight(24)
    b.bg = Fill(b, PAL.card, .9)
    b.bg:SetAllPoints(b)
    b.line = Fill(b, PAL.accent, 1, "ARTWORK")
    b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    b.line:SetHeight(2)
    b.text = Text(b, 13, BODY)
    b.text:SetPoint("CENTER", b, "CENTER", 0, 1)
    b.text:SetText(label)
    function b.Lit(on)
      b.on = on
      if on then b.line:Show() b.bg:SetVertexColor(PAL.accent[1] * .25, PAL.accent[2] * .25, PAL.accent[3] * .25, .95)
        b.text:SetTextColor(1, 1, 1)
      else b.line:Hide() b.bg:SetVertexColor(PAL.card[1], PAL.card[2], PAL.card[3], .9) b.text:SetTextColor(PAL.dim[1], PAL.dim[2], PAL.dim[3]) end
    end
    b:SetScript("OnClick", function() if onClick then onClick(b) end end)
    b:SetScript("OnEnter", function()
      if not b.on then b.text:SetTextColor(1, 1, 1) end
      if tip then GameTooltip:SetOwner(b, "ANCHOR_TOP") GameTooltip:SetText(tip, 1, 1, 1, 1, 1) GameTooltip:Show() end
    end)
    b:SetScript("OnLeave", function() b.Lit(b.on) GameTooltip:Hide() end)
    b.Lit(false)
    return b
  end
  UI.Chip = Chip

  -- ------------------------------------------------------------------ the window
  function UI.Build()
    if UI.frame then return UI.frame end
    local f = CreateFrame("Frame", "pfOctoBoards", UIParent)
    UI.frame = f
    f:SetWidth(WIDTH) f:SetHeight(HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true) f:EnableMouse(true) f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    f:Hide()
    table.insert(UISpecialFrames, "pfOctoBoards")
    local bg = Fill(f, PAL.bg, .97)
    bg:SetAllPoints(f)
    Edge(f, PAL.line, 1)
    -- the banner: the raid's own loading screen, darkened into the window
    f.art = f:CreateTexture(nil, "BORDER")
    f.art:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.art:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    f.art:SetHeight(BANNER)
    f.art:SetTexCoord(0, 1, .28, .52)
    f.shade = f:CreateTexture(nil, "ARTWORK")
    f.shade:SetTexture(WHITE)
    f.shade:SetAllPoints(f.art)
    f.shade:SetVertexColor(PAL.bg[1], PAL.bg[2], PAL.bg[3], 1)
    if f.shade.SetGradientAlpha then f.shade:SetGradientAlpha("VERTICAL", PAL.bg[1], PAL.bg[2], PAL.bg[3], 1, PAL.bg[1], PAL.bg[2], PAL.bg[3], .15) end
    f.title = Text(f, 30, TITLE)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -18)
    f.title:SetText("OctoBoards")
    f.sub = Text(f, 13, BODY, PAL.dim[1], PAL.dim[2], PAL.dim[3])
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 1, -2)
    f.sub:SetText("Who did the most - tonight, this week and all time")
    f.place = Text(f, 22, TITLE, GOLD[1], GOLD[2], GOLD[3])
    f.place:SetPoint("BOTTOMLEFT", f.art, "BOTTOMLEFT", 22, 30)
    f.placeSub = Text(f, 13, BODY, .85, .85, .88)
    f.placeSub:SetPoint("TOPLEFT", f.place, "BOTTOMLEFT", 1, -2)
    -- close
    local x = CreateFrame("Button", nil, f)
    x:SetWidth(24) x:SetHeight(24)
    x:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    x.text = Text(x, 18, TITLE, PAL.dim[1], PAL.dim[2], PAL.dim[3])
    x.text:SetPoint("CENTER", x, "CENTER", 0, 0)
    x.text:SetText("x")
    x:SetScript("OnClick", function() f:Hide() end)
    x:SetScript("OnEnter", function() x.text:SetTextColor(1, .4, .35) end)
    x:SetScript("OnLeave", function() x.text:SetTextColor(PAL.dim[1], PAL.dim[2], PAL.dim[3]) end)
    -- tabs: words on the banner, the open one white with an accent line under it
    f.tabs = {}
    local prev
    for _, t in ipairs({ { "awards", "Awards" }, { "boards", "Boards" }, { "community", "Community" }, { "player", "Player" } }) do
      local key, label = t[1], t[2]
      local b = CreateFrame("Button", nil, f)
      b:SetHeight(30)
      b.text = Text(b, 17, TITLE)
      b.text:SetPoint("CENTER", b, "CENTER", 0, 2)
      b.text:SetText(label)
      b:SetWidth(b.text:GetStringWidth() + 26)
      b.line = Fill(b, PAL.accent, 1, "ARTWORK")
      b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 8, 0)
      b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -8, 0)
      b.line:SetHeight(3)
      if prev then b:SetPoint("RIGHT", prev, "LEFT", -2, 0) else b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -46, -16) end
      prev = b
      b:SetScript("OnClick", function() UI.Open(key) end)
      b:SetScript("OnEnter", function() if UI.tab ~= key then b.text:SetTextColor(1, 1, 1) end end)
      b:SetScript("OnLeave", function() UI.PaintTabs() end)
      f.tabs[key] = b
    end
    -- (tabs read left to right: Awards Boards Player - the loop placed them right to left)
    f.tabs.player:ClearAllPoints() f.tabs.player:SetPoint("TOPRIGHT", f, "TOPRIGHT", -46, -16)
    f.tabs.community:ClearAllPoints() f.tabs.community:SetPoint("RIGHT", f.tabs.player, "LEFT", -2, 0)
    f.tabs.boards:ClearAllPoints() f.tabs.boards:SetPoint("RIGHT", f.tabs.community, "LEFT", -2, 0)
    f.tabs.awards:ClearAllPoints() f.tabs.awards:SetPoint("RIGHT", f.tabs.boards, "LEFT", -2, 0)
    -- pages
    f.pages = {}
    for _, k in ipairs({ "awards", "boards", "community", "player" }) do
      local p = CreateFrame("Frame", nil, f)
      p:SetPoint("TOPLEFT", f, "TOPLEFT", 18, k == "awards" and (-BANNER - 6) or -92)
      -- (26 Nov 2026, seen in game: an empty band under the art and the last cards past the bottom) Boards and Player
      -- start over the faded part of the banner
      p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 16)
      p:Hide()
      f.pages[k] = p
    end
    UI.BuildAwards(f.pages.awards)
    UI.BuildBoards(f.pages.boards)
    UI.BuildPlayer(f.pages.player)
    UI.BuildCommunity(f.pages.community)
    f:SetScript("OnUpdate", function()
      if (this.at or 0) > GetTime() then return end
      this.at = GetTime() + 2
      UI.Refresh()
    end)
    return f
  end
  function UI.PaintTabs()
    for k, b in pairs(UI.frame.tabs) do
      if k == UI.tab then b.text:SetTextColor(1, 1, 1) b.line:Show()
      else b.text:SetTextColor(PAL.dim[1], PAL.dim[2], PAL.dim[3]) b.line:Hide() end
    end
  end
  function UI.Open(tab, who)
    local f = UI.Build()
    UI.tab = tab or UI.tab or "awards"
    if who then UI.who = who end
    for k, p in pairs(f.pages) do if k == UI.tab then p:Show() else p:Hide() end end
    UI.PaintTabs()
    f:Show()
    UI.Refresh()
  end
  LB.Show = UI.Open
  function UI.Refresh()
    if not UI.frame or not UI.frame:IsShown() then return end
    if UI.tab == "awards" then UI.PaintAwards() elseif UI.tab == "boards" then UI.PaintBoards() elseif UI.tab == "community" then UI.PaintCommunity() else UI.PaintPlayer() end
  end
  -- the banner's art and its big line
  function UI.Banner(zone, kind, line)
    local f = UI.frame
    f.art:SetTexture(UI.ArtFor(zone, kind))
    f.place:SetText(zone or "")
    f.placeSub:SetText(line or "")
  end

  -- ------------------------------------------------------------------ Awards
  function UI.BuildAwards(p)
    -- the podium: three places, the winner in the middle and highest
    p.podium = {}
    local hs = { 92, 66, 48 }
    local xs = { 0, -150, 150 }
    for i = 1, 3 do
      local col = CreateFrame("Button", nil, p)
      col:SetWidth(132) col:SetHeight(170)
      col:SetPoint("BOTTOM", p, "TOP", xs[i], -186)
      col.block = Fill(col, MEDAL[i], .22, "BORDER")
      col.block:SetPoint("BOTTOMLEFT", col, "BOTTOMLEFT", 0, 0)
      col.block:SetPoint("BOTTOMRIGHT", col, "BOTTOMRIGHT", 0, 0)
      col.block:SetHeight(hs[i])
      col.top = Fill(col, MEDAL[i], 1, "ARTWORK")
      col.top:SetPoint("BOTTOMLEFT", col.block, "TOPLEFT", 0, -2)
      col.top:SetPoint("BOTTOMRIGHT", col.block, "TOPRIGHT", 0, -2)
      col.top:SetHeight(2)
      col.place = Text(col, i == 1 and 34 or 26, TITLE, MEDAL[i][1], MEDAL[i][2], MEDAL[i][3])
      col.place:SetPoint("CENTER", col.block, "CENTER", 0, 6)
      col.place:SetText(i)
      col.value = Text(col, 12, BODY, .9, .9, .92)
      col.value:SetPoint("TOP", col.place, "BOTTOM", 0, -1)
      col.name = Text(col, 15, TITLE)
      col.name:SetPoint("BOTTOM", col.block, "TOP", 0, 6)
      col.icon = Icon(col, i == 1 and 40 or 34)
      col.icon:SetPoint("BOTTOM", col.name, "TOP", 0, 4)
      if i == 1 then
        col.crown = Icon(col, 22, ICON .. "INV_Crown_01")
        col.crown:SetPoint("BOTTOM", col.icon, "TOP", 0, 3)
      end
      col:SetScript("OnClick", function() if col.who then UI.Open("player", col.who) end end)
      p.podium[i] = col
    end
    p.podiumLabel = Text(p, 11, BODY, PAL.label[1], PAL.label[2], PAL.label[3])
    p.podiumLabel:SetPoint("TOP", p, "TOP", 0, -2)
    p.podiumLabel:SetText("TOP DAMAGE")
    -- the award cards, three to a row
    p.cards = {}
    local cw, ch = 274, 62
    for i = 1, 6 do
      local c = CreateFrame("Button", nil, p)
      c:SetWidth(cw) c:SetHeight(ch)
      local r, k = floor((i - 1) / 3), math.mod(i - 1, 3)
      c:SetPoint("TOPLEFT", p, "TOPLEFT", k * (cw + 9), -198 - r * (ch + 9))
      local bg = Fill(c, PAL.card, .95)
      bg:SetAllPoints(c)
      c.accent = Fill(c, GOLD, 1, "BORDER")
      c.accent:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
      c.accent:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
      c.accent:SetWidth(3)
      c.icon = Icon(c, 40)
      c.icon:SetPoint("LEFT", c, "LEFT", 12, 0)
      c.title = Text(c, 11, BODY, PAL.label[1], PAL.label[2], PAL.label[3])
      c.title:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, 0)
      c.who = Text(c, 17, TITLE)
      c.who:SetPoint("LEFT", c.icon, "RIGHT", 10, -2)
      c.value = Text(c, 12, BODY, .85, .86, .9)
      c.value:SetPoint("BOTTOMLEFT", c.icon, "BOTTOMRIGHT", 10, 0)
      c:SetScript("OnClick", function() if c.name then UI.Open("player", c.name) end end)
      c:SetScript("OnEnter", function() bg:SetVertexColor(PAL.card[1] + .04, PAL.card[2] + .04, PAL.card[3] + .05, 1) end)
      c:SetScript("OnLeave", function() bg:SetVertexColor(PAL.card[1], PAL.card[2], PAL.card[3], .95) end)
      p.cards[i] = c
    end
    -- the bottom row
    p.empty = Text(p, 14, BODY, PAL.dim[1], PAL.dim[2], PAL.dim[3])
    p.empty:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 2, 8)
    p.copy = Chip(p, "Copy for Discord", 140, function() UI.CopyNight() end, "Tonight's podium and awards as text with emojis, ready to paste in Discord.")
    p.copy:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 2)
    p.older = Chip(p, "Earlier nights", 120, function() UI.night = (UI.night or 0) + 1 UI.PaintAwards() end,
      "Steps back through your last five raid and dungeon nights.")
    p.older:SetPoint("RIGHT", p.copy, "LEFT", -8, 0)
    p.latest = Chip(p, "Tonight", 80, function() UI.night = 0 UI.PaintAwards() end)
    p.latest:SetPoint("RIGHT", p.older, "LEFT", -8, 0)
  end
  -- the night shown: 0 = tonight, 1.. = earlier ones; a sample before any
  function UI.Night()
    local d = LB.DB()
    local i = UI.night or 0
    if i > 0 then
      local n = d.nights[i]
      if n then return n end
      UI.night = 0
    end
    return d.night or LB.SampleNight()
  end
  function UI.PaintAwards()
    local p = UI.frame.pages.awards
    local n = UI.Night()
    local mins = floor(((n.last or 0) - (n.start or 0)) / 60)
    local dur = mins >= 60 and (floor(mins / 60) .. "h " .. math.mod(mins, 60) .. "m") or (mins .. "m")
    local count = 0
    for _ in pairs(n.p) do count = count + 1 end
    UI.Banner(n.zone, n.kind, count .. " players  -  " .. n.bosses .. (n.bosses == 1 and " boss  -  " or " bosses  -  ")
      .. n.fights .. " fights  -  " .. dur .. (n.sample and "   (a sample: your first raid or dungeon fills this in)" or ""))
    local pod = LB.Podium(n)
    for i = 1, 3 do
      local col, r = p.podium[i], pod[i]
      if r then
        col.who = r.name
        col.name:SetText(r.name)
        col.name:SetTextColor(LB.ClassColor(r.class))
        ClassIcon(col.icon.tex, r.class)
        col.value:SetText(LB.Num(r.value, "big"))
        col:Show()
      else
        col:Hide()
      end
    end
    local awards = {}
    for _, a in ipairs(LB.Awards(n)) do if a.key ~= "dm" then table.insert(awards, a) end end
    for i, c in ipairs(p.cards) do
      local a = awards[i]
      if a then
        c.name = a.who
        c.icon.tex:SetTexture(ICON .. a.icon)
        c.title:SetText(string.upper(a.title))
        c.who:SetText(a.who)
        c.who:SetTextColor(LB.ClassColor(a.class))
        c.value:SetText(a.text)
        c:Show()
      else
        c:Hide()
      end
    end
    p.empty:SetText((UI.night or 0) > 0 and ("Night " .. UI.night .. " back") or "")
    p.latest.Lit((UI.night or 0) == 0)
    p.older.Lit((UI.night or 0) > 0)
  end
  function UI.CopyNight()
    local text = LB.DiscordText(UI.Night())
    local lc = pfUI.api and pfUI.api.libclient
    if lc and lc.Copy and lc.Copy(text, true) then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffOctoBoards|r: copied - paste it in Discord with Ctrl+V.")
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffOctoBoards|r: copying needs ClassicAPI. The text:")
      for l in string.gfind(text, "[^\n]+") do DEFAULT_CHAT_FRAME:AddMessage(l) end
    end
  end

  -- ------------------------------------------------------------------ Boards
  UI.cat, UI.stat, UI.scope, UI.period = "combat", "kl", "guild", "week"
  local ROWS = 10
  function UI.BuildBoards(p)
    -- categories, left
    p.cats = {}
    for i, c in ipairs(LB.CATS) do
      local key = c[1]
      local b = CreateFrame("Button", nil, p)
      b:SetWidth(186) b:SetHeight(34)
      b:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -(i - 1) * 37)
      b.bg = Fill(b, PAL.card, .9)
      b.bg:SetAllPoints(b)
      b.edge = Fill(b, PAL.accent, 1, "BORDER")
      b.edge:SetPoint("TOPLEFT", b, "TOPLEFT") b.edge:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT") b.edge:SetWidth(3)
      b.icon = Icon(b, 24, ICON .. c[3])
      b.icon:SetPoint("LEFT", b, "LEFT", 10, 0)
      b.text = Text(b, 14, TITLE)
      b.text:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
      b.text:SetText(c[2])
      b:SetScript("OnClick", function()
        UI.cat = key
        for _, s in ipairs(LB.STATS) do if s[4] == key then UI.stat = s[1] break end end
        UI.PaintBoards()
      end)
      p.cats[key] = b
    end
    -- right: the board's stat picker, scope and period
    p.right = CreateFrame("Frame", nil, p)
    p.right:SetPoint("TOPLEFT", p, "TOPLEFT", 202, 0)
    p.right:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
    p.stats = {}
    for i = 1, 7 do
      local b = CreateFrame("Button", nil, p.right)
      b:SetWidth(36) b:SetHeight(36)
      b:SetPoint("TOPLEFT", p.right, "TOPLEFT", (i - 1) * 42, 0)
      b.icon = Icon(b, 36)
      b.icon:SetAllPoints(b)
      b.ring = CreateFrame("Frame", nil, b)
      b.ring:SetAllPoints(b)
      Edge(b.ring, GOLD, 1)
      b:SetScript("OnClick", function() if b.key then UI.stat = b.key UI.PaintBoards() end end)
      b:SetScript("OnEnter", function()
        if not b.key then return end
        GameTooltip:SetOwner(b, "ANCHOR_TOP")
        GameTooltip:SetText(LB.BY[b.key][2], 1, 1, 1)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      p.stats[i] = b
    end
    p.statName = Text(p.right, 22, TITLE)
    p.statName:SetPoint("TOPLEFT", p.right, "TOPLEFT", 0, -46)
    p.scopes = {}
    local prev
    for _, s in ipairs({ { "guild", "Guild" }, { "raid", "Raid" }, { "friends", "Friends" }, { "all", "Everyone" } }) do
      local key = s[1]
      local b = Chip(p.right, s[2], 70, function() UI.scope = key UI.PaintBoards() end)
      if prev then b:SetPoint("RIGHT", prev, "LEFT", -4, 0) else b:SetPoint("TOPRIGHT", p.right, "TOPRIGHT", -170, -46) end
      prev = b
      p.scopes[key] = b
    end
    -- (left to right)
    p.scopes.all:ClearAllPoints() p.scopes.all:SetPoint("TOPRIGHT", p.right, "TOPRIGHT", -170, -46)
    p.scopes.friends:ClearAllPoints() p.scopes.friends:SetPoint("RIGHT", p.scopes.all, "LEFT", -4, 0)
    p.scopes.raid:ClearAllPoints() p.scopes.raid:SetPoint("RIGHT", p.scopes.friends, "LEFT", -4, 0)
    p.scopes.guild:ClearAllPoints() p.scopes.guild:SetPoint("RIGHT", p.scopes.raid, "LEFT", -4, 0)
    p.periods = {}
    p.periods.all = Chip(p.right, "All time", 76, function() UI.period = "all" UI.PaintBoards() end)
    p.periods.all:SetPoint("TOPRIGHT", p.right, "TOPRIGHT", 0, -46)
    p.periods.week = Chip(p.right, "This week", 84, function() UI.period = "week" UI.PaintBoards() end)
    p.periods.week:SetPoint("RIGHT", p.periods.all, "LEFT", -4, 0)
    -- the ranked rows
    p.rows = {}
    for i = 1, ROWS + 1 do
      local r = CreateFrame("Button", nil, p.right)
      r:SetHeight(28)
      r:SetPoint("TOPLEFT", p.right, "TOPLEFT", 0, -82 - (i - 1) * 30 - (i > ROWS and 8 or 0))
      r:SetPoint("RIGHT", p.right, "RIGHT", 0, 0)
      r.bg = Fill(r, PAL.card, .75)
      r.bg:SetAllPoints(r)
      r.bar = Fill(r, PAL.accent, .18, "BORDER")
      r.bar:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
      r.bar:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
      r.rank = Text(r, 16, TITLE)
      r.rank:SetPoint("LEFT", r, "LEFT", 8, 0)
      r.rank:SetWidth(30)
      r.rank:SetJustifyH("LEFT")
      r.icon = Icon(r, 22)
      r.icon:SetPoint("LEFT", r, "LEFT", 40, 0)
      r.name = Text(r, 15, TITLE)
      r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
      r.value = Text(r, 15, TITLE)
      r.value:SetPoint("RIGHT", r, "RIGHT", -10, 0)
      r:SetScript("OnClick", function() if r.who then UI.Open("player", r.who) end end)
      r:SetScript("OnEnter", function() r.bg:SetVertexColor(PAL.card[1] + .05, PAL.card[2] + .05, PAL.card[3] + .06, .9) end)
      r:SetScript("OnLeave", function() UI.PaintBoards() end)
      p.rows[i] = r
    end
    p.note = Text(p.right, 12, BODY, PAL.dim[1], PAL.dim[2], PAL.dim[3])
    p.note:SetPoint("BOTTOMLEFT", p.right, "BOTTOMLEFT", 0, 4)
    p.note:SetPoint("RIGHT", p.right, "RIGHT", 0, 0)
    p.note:SetJustifyH("LEFT")
  end
  function UI.PaintBoards()
    local p = UI.frame.pages.boards
    -- (the page sits over the banner's faded part: no zone line here)
    UI.Banner(nil, nil, "")
    UI.frame.place:SetText("")
    for k, b in pairs(p.cats) do
      if k == UI.cat then b.edge:Show() b.bg:SetVertexColor(PAL.accent[1] * .22, PAL.accent[2] * .22, PAL.accent[3] * .22, .95) b.text:SetTextColor(1, 1, 1)
      else b.edge:Hide() b.bg:SetVertexColor(PAL.card[1], PAL.card[2], PAL.card[3], .9) b.text:SetTextColor(PAL.dim[1], PAL.dim[2], PAL.dim[3]) end
    end
    local n = 0
    for _, s in ipairs(LB.STATS) do
      if s[4] == UI.cat then
        n = n + 1
        local b = p.stats[n]
        if b then
          b.key = s[1]
          b.icon.tex:SetTexture(ICON .. s[3])
          if s[1] == UI.stat then b.ring:Show() b:SetAlpha(1) else b.ring:Hide() b:SetAlpha(.55) end
          b:Show()
        end
      end
    end
    for i = n + 1, table.getn(p.stats) do p.stats[i]:Hide() p.stats[i].key = nil end
    local s = LB.BY[UI.stat]
    p.statName:SetText(s and s[2] or "")
    for k, b in pairs(p.scopes) do b.Lit(k == UI.scope) end
    for k, b in pairs(p.periods) do b.Lit(k == UI.period) end
    local rows = LB.Board(UI.stat, UI.scope, UI.period)
    local top = rows[1] and rows[1].value or 0
    local mine
    for _, r in ipairs(rows) do if r.me then mine = r end end
    for i = 1, ROWS + 1 do
      local row, r = p.rows[i], rows[i]
      if i == ROWS + 1 then r = mine and mine.rank > ROWS and mine or nil end
      if r then
        row.who = r.name
        local c = MEDAL[r.rank]
        if c then row.rank:SetTextColor(c[1], c[2], c[3]) else row.rank:SetTextColor(PAL.dim[1], PAL.dim[2], PAL.dim[3]) end
        row.rank:SetText(r.rank)
        ClassIcon(row.icon.tex, r.class)
        row.name:SetText(r.name .. (r.me and "  |cff8a8f99(you)|r" or ""))
        row.name:SetTextColor(LB.ClassColor(r.class))
        row.value:SetText(LB.Value(UI.stat, r.value))
        local cr, cg, cb = LB.ClassColor(r.class)
        row.bar:SetVertexColor(cr, cg, cb, r.me and .32 or .2)
        row.bar:SetWidth(math.max(1, (row:GetWidth() or 600) * (top > 0 and r.value / top or 0)))
        if r.me then row.bg:SetVertexColor(PAL.accent[1] * .2, PAL.accent[2] * .2, PAL.accent[3] * .2, .9)
        else row.bg:SetVertexColor(PAL.card[1], PAL.card[2], PAL.card[3], .75) end
        row:Show()
      else
        row.who = nil
        row:Hide()
      end
    end
    p.note:SetText(table.getn(rows) <= 1 and "Only your numbers so far. Other pfUI Octo users in your guild or raid show up here when they log in."
      or ((s and s[5] == "set" and UI.period == "week") and "The game keeps this one all time only: pick All time." or
      "Click a name for that player's card. Counted from the day each player installed pfUI Octo."))
  end

  -- ------------------------------------------------------------------ Player
  UI.ppriod = "all"
  function UI.BuildPlayer(p)
    p.portrait = p:CreateTexture(nil, "ARTWORK")
    p.portrait:SetWidth(64)
    p.portrait:SetHeight(64)
    p.portrait:SetPoint("TOPLEFT", p, "TOPLEFT", 2, -2)
    p.ring = CreateFrame("Frame", nil, p)
    p.ring:SetPoint("TOPLEFT", p.portrait, "TOPLEFT", -1, 1)
    p.ring:SetPoint("BOTTOMRIGHT", p.portrait, "BOTTOMRIGHT", 1, -1)
    Edge(p.ring, GOLD, 1)
    p.name = Text(p, 26, TITLE)
    p.name:SetPoint("TOPLEFT", p.portrait, "TOPRIGHT", 14, -4)
    p.info = Text(p, 13, BODY, PAL.dim[1], PAL.dim[2], PAL.dim[3])
    p.info:SetPoint("TOPLEFT", p.name, "BOTTOMLEFT", 1, -3)
    -- crowns: boards this player leads in the guild this week
    p.crowns = {}
    for i = 1, 10 do
      local c = CreateFrame("Button", nil, p)
      c:SetWidth(26) c:SetHeight(26)
      c:SetPoint("TOPLEFT", p.info, "BOTTOMLEFT", (i - 1) * 30, -6)
      c.icon = Icon(c, 26)
      c.icon:SetAllPoints(c)
      c.ring = CreateFrame("Frame", nil, c)
      c.ring:SetAllPoints(c)
      Edge(c.ring, GOLD, 1)
      c:SetScript("OnEnter", function()
        if not c.key then return end
        GameTooltip:SetOwner(c, "ANCHOR_TOP")
        GameTooltip:SetText("|cffffd24dFirst in the guild this week|r", 1, 1, 1)
        GameTooltip:AddLine(LB.BY[c.key][2], 1, 1, 1)
        GameTooltip:Show()
      end)
      c:SetScript("OnLeave", function() GameTooltip:Hide() end)
      p.crowns[i] = c
    end
    p.period = {}
    p.period.all = Chip(p, "All time", 76, function() UI.ppriod = "all" UI.PaintPlayer() end)
    p.period.all:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -2)
    p.period.week = Chip(p, "This week", 84, function() UI.ppriod = "week" UI.PaintPlayer() end)
    p.period.week:SetPoint("RIGHT", p.period.all, "LEFT", -4, 0)
    p.mine = Chip(p, "Me", 50, function() UI.who = nil UI.PaintPlayer() end, "Your own card.")
    p.mine:SetPoint("RIGHT", p.period.week, "LEFT", -12, 0)
    p.nextp = Chip(p, ">", 28, function() UI.StepPlayer(1) end, "Next player")
    p.nextp:SetPoint("RIGHT", p.mine, "LEFT", -4, 0)
    p.prevp = Chip(p, "<", 28, function() UI.StepPlayer(-1) end, "Previous player")
    p.prevp:SetPoint("RIGHT", p.nextp, "LEFT", -4, 0)
    -- the numbers: four to a row
    p.tiles = {}
    local tw, th = 204, 44
    for i, s in ipairs(LB.STATS) do
      local key = s[1]
      local t = CreateFrame("Button", nil, p)
      t:SetWidth(tw) t:SetHeight(th)
      local r, k = floor((i - 1) / 4), math.mod(i - 1, 4)
      t:SetPoint("TOPLEFT", p, "TOPLEFT", k * (tw + 7), -96 - r * (th + 5))
      local bg = Fill(t, PAL.card, .9)
      bg:SetAllPoints(t)
      t.icon = Icon(t, 30, ICON .. s[3])
      t.icon:SetPoint("LEFT", t, "LEFT", 7, 0)
      t.label = Text(t, 11, BODY, PAL.label[1], PAL.label[2], PAL.label[3])
      t.label:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 8, 1)
      t.label:SetText(s[2])
      t.value = Text(t, 16, TITLE)
      t.value:SetPoint("BOTTOMLEFT", t.icon, "BOTTOMRIGHT", 8, -1)
      t.rank = Text(t, 11, BODY, PAL.dim[1], PAL.dim[2], PAL.dim[3])
      t.rank:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -7, 6)
      t:SetScript("OnClick", function() UI.cat, UI.stat = s[4], key UI.Open("boards") end)
      t:SetScript("OnEnter", function()
        bg:SetVertexColor(PAL.card[1] + .04, PAL.card[2] + .04, PAL.card[3] + .05, 1)
        GameTooltip:SetOwner(t, "ANCHOR_TOP")
        GameTooltip:SetText(s[2], 1, 1, 1)
        if t.mineText then GameTooltip:AddLine("You: " .. t.mineText, .6, .8, 1) end
        GameTooltip:AddLine("Click: this board.", .6, .62, .66)
        GameTooltip:Show()
      end)
      t:SetScript("OnLeave", function() bg:SetVertexColor(PAL.card[1], PAL.card[2], PAL.card[3], .9) GameTooltip:Hide() end)
      p.tiles[key] = t
    end
  end
  -- everyone known, you first
  function UI.Players()
    local list = { LB.MeName() }
    local names = {}
    for name in pairs(LB.DB().others) do table.insert(names, name) end
    table.sort(names)
    for _, n in ipairs(names) do table.insert(list, n) end
    return list
  end
  function UI.StepPlayer(d)
    local list = UI.Players()
    local cur = UI.who or LB.MeName()
    local at = 1
    for i, n in ipairs(list) do if n == cur then at = i end end
    at = math.mod(at - 1 + d + table.getn(list), table.getn(list)) + 1
    UI.who = list[at] ~= LB.MeName() and list[at] or nil
    UI.PaintPlayer()
  end
  function UI.PaintPlayer()
    local p = UI.frame.pages.player
    local name = UI.who or LB.MeName()
    local o = LB.Player(name)
    UI.Banner(nil, nil, "")
    UI.frame.place:SetText("")
    if not o then
      p.name:SetText(name)
      p.info:SetText("Not seen yet - their numbers come when they log in with pfUI Octo.")
      return
    end
    local unit = (name == LB.MeName() and "player") or (UnitName("target") == name and "target") or nil
    if unit and SetPortraitTexture then
      SetPortraitTexture(p.portrait, unit)
      p.portrait:SetTexCoord(0, 1, 0, 1)
    else
      ClassIcon(p.portrait, o.class)
    end
    p.name:SetText(name)
    p.name:SetTextColor(LB.ClassColor(o.class))
    local cls = o.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[o.class]) or
      (string.upper(string.sub(o.class, 1, 1)) .. string.lower(string.sub(o.class, 2)))) or ""
    p.info:SetText("Level " .. (o.level or "?") .. " " .. cls .. (o.t and ("   -   seen " .. date("%d %b", o.t)) or ""))
    for k, b in pairs(p.period) do b.Lit(k == UI.ppriod) end
    p.mine.Lit(UI.who == nil)
    local wk = LB.Week()
    local t = UI.ppriod == "week" and ((o.me or o.wk == wk) and o.week or {}) or o.all
    local me = LB.Me()
    local myT = UI.ppriod == "week" and me.week or me.all
    local crowns = 0
    for _, s in ipairs(LB.STATS) do
      local tile = p.tiles[s[1]]
      local v = t and t[s[1]] or 0
      tile.value:SetText(v > 0 and LB.Value(s[1], v) or "|cff666a72-|r")
      local rank = v > 0 and LB.Rank(name, s[1], "guild", UI.ppriod)
      tile.rank:SetText(rank and ("#" .. rank) or "")
      if rank and MEDAL[rank] then tile.rank:SetTextColor(MEDAL[rank][1], MEDAL[rank][2], MEDAL[rank][3])
      else tile.rank:SetTextColor(PAL.dim[1], PAL.dim[2], PAL.dim[3]) end
      tile.mineText = (name ~= LB.MeName() and myT[s[1]]) and LB.Value(s[1], myT[s[1]]) or nil
      -- a crown: first in the guild this week (and more than one player on that board)
      local wr = v > 0 and LB.Rank(name, s[1], "guild", "week")
      if wr == 1 and table.getn(LB.Board(s[1], "guild", "week")) > 1 and crowns < table.getn(p.crowns) then
        crowns = crowns + 1
        local c = p.crowns[crowns]
        c.key = s[1]
        c.icon.tex:SetTexture(ICON .. s[3])
        c:Show()
      end
    end
    for i = crowns + 1, table.getn(p.crowns) do p.crowns[i]:Hide() p.crowns[i].key = nil end
  end

  -- ------------------------------------------------------------------ Community (Chronicle)
  -- (26 Nov 2026, user: "fun data from chronicle ... boards of realms and all the realms combined to bring the community
  -- together ... FUN FUN FUN") pfUI.boardsChronicle is written by tools\Sync-Chronicle.ps1 from Chronicle's public API:
  -- boards[key][scope] = { { name, class, guild, realm, value, extra } } best first, scope "all" or a realm's name.
  -- key, title, icon, section, how the value reads, what a row is (player | guild | raid | realm | boss), a fun line
  UI.CBOARDS = {
    { "realmwar", "Realm wars", "INV_BannerPVP_02", "Realm wars", "n", "realm", "Boss kills this week - which realm is on top?" },
    { "guildweek", "Guild of the week", "INV_Misc_Head_Dragon_01", "Realm wars", "n", "guild", "Most bosses killed" },
    { "turnout", "Biggest turnout", "Spell_Holy_PrayerOfHealing02", "Realm wars", "n", "raid", "The most players in one raid" },
    { "unfinished", "Unfinished business", "Spell_Shadow_DeathScream", "Realm wars", "n", "guild", "Bosses pulled but not killed - the most stubborn guilds" },
    { "topparse", "Top parse", "Spell_Fire_Fireball02", "Hall of fame", "parse", "player", "Best average score (out of 100) against their class, 4+ boss kills" },
    { "classtop", "Best of each class", "INV_Crown_01", "Hall of fame", "parse", "player", "The number one of every class" },
    { "perfect", "Perfect 99", "Spell_Holy_SealOfMight", "Hall of fame", "n", "player", "Boss kills with a score of 99 or more" },
    { "alive", "Never dies", "Spell_Holy_DispelMagic", "Hall of fame", "n", "player", "Boss kills alive from pull to kill" },
    { "absorbs", "Shield master", "INV_Shield_06", "Hall of fame", "big", "player", "Most damage soaked by shields" },
    { "pacifist", "Pacifist", "Spell_Holy_Heal", "Hall of fame", "big", "player", "All healing, (almost) no damage" },
    { "glass", "Glass cannon", "Spell_Nature_Lightning", "Hall of fame", "n", "player", "Deaths of players averaging 75+ scores" },
    { "floor", "Floor inspector", "INV_Misc_Bone_HumanSkull_01", "Hall of fame", "n", "player", "Most deaths on bosses" },
    { "rising", "Rising star", "Ability_Rogue_Sprint", "Hall of fame", "parse", "player", "Biggest jump in average score since last week" },
    { "loyal", "Loyal raider", "INV_Misc_Book_09", "Hall of fame", "n", "player", "Most raids this week" },
    { "nightowl", "Night owls", "Spell_Nature_Sleep", "Raid life", "none", "raid", "The latest raid starts (server time)" },
    { "marathon", "Marathon", "Ability_Mount_Gryphon_01", "Raid life", "mins", "raid", "The longest raid nights" },
    { "bossbully", "Boss of the week", "Spell_Fire_Fireball02", "Raid life", "n", "boss", "The boss that killed the most raiders" },
  }
  UI.cboard, UI.cscope = "realmwar", "all"
  UI.REALMCOL = { { .95, .45, .3 }, { .45, .75, 1 }, { .7, .5, 1 }, { .5, .9, .5 } }
  local CROWS = 10
  local function Data() return rawget(pfUI, "boardsChronicle") end
  function UI.CValue(v, how)
    v = tonumber(v) or 0
    if how == "parse" then return string.format("%.1f", v) end
    if how == "mins" then local h = floor(v / 60) return h > 0 and (h .. "h " .. math.mod(v, 60) .. "m") or (v .. "m") end
    if how == "none" then return "" end
    return LB.Num(v, how == "big" and "big" or nil)
  end
  function UI.BuildCommunity(p)
    -- the boards, left, under their section headings
    p.list = {}
    local y, section = 0, nil
    for _, d in ipairs(UI.CBOARDS) do
      local key = d[1]
      if d[4] ~= section then
        section = d[4]
        local h = Text(p, 11, BODY, PAL.accent[1], PAL.accent[2], PAL.accent[3])
        h:SetPoint("TOPLEFT", p, "TOPLEFT", 2, -y - 2)
        h:SetText(string.upper(section))
        y = y + 16
      end
      local b = CreateFrame("Button", nil, p)
      b:SetWidth(186) b:SetHeight(22)
      b:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -y)
      b.bg = Fill(b, PAL.card, .9)
      b.bg:SetAllPoints(b)
      b.edge = Fill(b, PAL.accent, 1, "BORDER")
      b.edge:SetPoint("TOPLEFT", b, "TOPLEFT") b.edge:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT") b.edge:SetWidth(3)
      b.icon = Icon(b, 18, ICON .. d[3])
      b.icon:SetPoint("LEFT", b, "LEFT", 6, 0)
      b.text = Text(b, 13, TITLE)
      b.text:SetPoint("LEFT", b.icon, "RIGHT", 7, 0)
      b.text:SetText(d[2])
      b:SetScript("OnClick", function() UI.cboard = key UI.PaintCommunity() end)
      p.list[key] = b
      y = y + 24
    end
    p.right = CreateFrame("Frame", nil, p)
    p.right:SetPoint("TOPLEFT", p, "TOPLEFT", 202, 0)
    p.right:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
    p.bicon = Icon(p.right, 40)
    p.bicon:SetPoint("TOPLEFT", p.right, "TOPLEFT", 0, 0)
    p.title = Text(p.right, 22, TITLE)
    p.title:SetPoint("TOPLEFT", p.bicon, "TOPRIGHT", 10, 2)
    p.line = Text(p.right, 12, BODY, PAL.dim[1], PAL.dim[2], PAL.dim[3])
    p.line:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 1, -2)
    -- realm chips (All realms + each realm in the data)
    p.scopes = {}
    p.rows = {}
    for i = 1, CROWS do
      local r = CreateFrame("Button", nil, p.right)
      r:SetHeight(32)
      r:SetPoint("TOPLEFT", p.right, "TOPLEFT", 0, -82 - (i - 1) * 34)
      r:SetPoint("RIGHT", p.right, "RIGHT", 0, 0)
      r.bg = Fill(r, PAL.card, .75)
      r.bg:SetAllPoints(r)
      r.bar = Fill(r, PAL.accent, .18, "BORDER")
      r.bar:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
      r.bar:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
      r.rank = Text(r, 16, TITLE)
      r.rank:SetPoint("LEFT", r, "LEFT", 8, 0)
      r.icon = Icon(r, 24)
      r.icon:SetPoint("LEFT", r, "LEFT", 38, 0)
      r.name = Text(r, 15, TITLE)
      r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 1)
      r.sub = Text(r, 11, BODY, PAL.dim[1], PAL.dim[2], PAL.dim[3])
      r.sub:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, -1)
      r.value = Text(r, 16, TITLE)
      r.value:SetPoint("TOPRIGHT", r, "TOPRIGHT", -10, -3)
      r.extra = Text(r, 11, BODY, PAL.dim[1], PAL.dim[2], PAL.dim[3])
      r.extra:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -10, 3)
      p.rows[i] = r
    end
    p.empty = Text(p.right, 14, BODY, PAL.dim[1], PAL.dim[2], PAL.dim[3])
    p.empty:SetPoint("TOPLEFT", p.right, "TOPLEFT", 0, -90)
    p.empty:SetPoint("RIGHT", p.right, "RIGHT", 0, 0)
    p.empty:SetJustifyH("LEFT")
    p.foot = Text(p.right, 11, BODY, PAL.label[1], PAL.label[2], PAL.label[3])
    p.foot:SetPoint("BOTTOMLEFT", p.right, "BOTTOMLEFT", 0, 6)
    p.copy = Chip(p.right, "Copy for Discord", 140, function() UI.CopyCommunity() end, "This board's top 5 as text with emojis, ready for Discord.")
    p.copy:SetPoint("BOTTOMRIGHT", p.right, "BOTTOMRIGHT", 0, 2)
  end
  function UI.CDef(key) for _, d in ipairs(UI.CBOARDS) do if d[1] == key then return d end end end
  function UI.CRows(key, scope)
    local data = Data()
    local b = data and data.boards and data.boards[key]
    if not b then return {} end
    return b[scope] or b.all or {}
  end
  -- realm chips: made the first time the data names its realms
  function UI.CScopes(p)
    local data = Data()
    local names = { "all" }
    for _, r in ipairs(data and data.realms or {}) do table.insert(names, r) end
    if p.scopeKey == table.concat(names, "^") then return end
    p.scopeKey = table.concat(names, "^")
    for _, b in pairs(p.scopes) do b:Hide() end
    p.scopes = {}
    local prev
    for i = table.getn(names), 1, -1 do
      local key = names[i]
      local b = Chip(p.right, key == "all" and "All realms" or key, key == "all" and 84 or 74, function() UI.cscope = key UI.PaintCommunity() end)
      if prev then b:SetPoint("RIGHT", prev, "LEFT", -4, 0) else b:SetPoint("TOPRIGHT", p.right, "TOPRIGHT", 0, -50) end
      prev = b
      p.scopes[key] = b
    end
  end
  function UI.PaintCommunity()
    local p = UI.frame.pages.community
    UI.Banner(nil, nil, "")
    UI.frame.place:SetText("")
    local data = Data()
    UI.CScopes(p)
    for k, b in pairs(p.list) do
      if k == UI.cboard then b.edge:Show() b.bg:SetVertexColor(PAL.accent[1] * .22, PAL.accent[2] * .22, PAL.accent[3] * .22, .95) b.text:SetTextColor(1, 1, 1)
      else b.edge:Hide() b.bg:SetVertexColor(PAL.card[1], PAL.card[2], PAL.card[3], .9) b.text:SetTextColor(PAL.dim[1], PAL.dim[2], PAL.dim[3]) end
    end
    local d = UI.CDef(UI.cboard) or UI.CBOARDS[1]
    -- the realm war is one board for all realms
    local scope = d[1] == "realmwar" and "all" or UI.cscope
    for k, b in pairs(p.scopes) do b.Lit(k == scope) if d[1] == "realmwar" and k ~= "all" then b:SetAlpha(.4) else b:SetAlpha(1) end end
    p.bicon.tex:SetTexture(ICON .. d[3])
    p.title:SetText(d[2])
    p.line:SetText(d[7])
    local rows = UI.CRows(d[1], scope)
    local top = rows[1] and tonumber(rows[1][5]) or 0
    if not data then
      p.empty:SetText("No Chronicle data yet. Run tools\\Sync-Chronicle.ps1 in the pfUI folder (a few minutes the first time), then /reload.")
    elseif not rows[1] then
      p.empty:SetText(d[1] == "rising" and "Rising star needs last week's numbers: run the sync again next week." or "Nobody on this board yet for this realm.")
    else
      p.empty:SetText("")
    end
    local realmIndex = {}
    for i, r in ipairs(data and data.realms or {}) do realmIndex[r] = i end
    for i = 1, CROWS do
      local row, e = p.rows[i], rows[i]
      if e then
        local name, class, guild, realm, value, extra = e[1], e[2], e[3], e[4], e[5], e[6]
        local m = MEDAL[i]
        if m then row.rank:SetTextColor(m[1], m[2], m[3]) else row.rank:SetTextColor(PAL.dim[1], PAL.dim[2], PAL.dim[3]) end
        row.rank:SetText(i)
        local cr, cg, cb = .85, .85, .87
        if d[6] == "player" then
          ClassIcon(row.icon.tex, class)
          cr, cg, cb = LB.ClassColor(class)
          row.sub:SetText((guild ~= "" and ("<" .. guild .. ">  ") or "") .. (scope == "all" and realm or ""))
        else
          local ic = d[6] == "realm" and "INV_BannerPVP_02" or d[6] == "boss" and "INV_Misc_Bone_HumanSkull_01" or "INV_BannerPVP_01"
          row.icon.tex:SetTexture(ICON .. ic)
          row.icon.tex:SetTexCoord(.08, .92, .08, .92)
          if d[6] == "realm" then
            local c = UI.REALMCOL[realmIndex[name] or 1]
            cr, cg, cb = c[1], c[2], c[3]
            row.sub:SetText("")
          else
            cr, cg, cb = 1, .82, .4
            row.sub:SetText((d[6] == "raid" and guild or "") .. (scope == "all" and realm ~= "" and ("  -  " .. realm) or ""))
          end
        end
        row.name:SetText(d[6] == "guild" and ("<" .. name .. ">") or name)
        row.name:SetTextColor(cr, cg, cb)
        row.value:SetText(UI.CValue(value, d[5]))
        row.extra:SetText(extra or "")
        row.bar:SetVertexColor(cr, cg, cb, d[6] == "realm" and .35 or .16)
        row.bar:SetWidth(math.max(1, (row:GetWidth() or 600) * (top > 0 and (tonumber(value) or 0) / top or 0)))
        row:Show()
      else
        row:Hide()
      end
    end
    p.foot:SetText(data and ("From Chronicle (octo.chronicleclassic.com): " .. (data.raids or 0) .. " raids, " .. (data.players or 0)
      .. " players, last " .. (data.days or 7) .. " days - updated " .. (data.updated or "?")) or "")
  end
  function UI.CopyCommunity()
    local d = UI.CDef(UI.cboard) or UI.CBOARDS[1]
    local scope = d[1] == "realmwar" and "all" or UI.cscope
    local rows = UI.CRows(d[1], scope)
    local medal = { ":first_place:", ":second_place:", ":third_place:", ":four:", ":five:" }
    local lines = { ":crossed_swords: **" .. d[2] .. "** - " .. (scope == "all" and "all realms" or scope) .. " - " .. d[7] }
    for i = 1, math.min(5, table.getn(rows)) do
      local e = rows[i]
      local v = UI.CValue(e[5], d[5])
      table.insert(lines, medal[i] .. " " .. (d[6] == "guild" and ("<" .. e[1] .. ">") or e[1])
        .. (e[3] ~= "" and d[6] == "player" and (" <" .. e[3] .. ">") or "") .. (v ~= "" and (" - **" .. v .. "**") or "")
        .. (e[6] ~= "" and (" (" .. e[6] .. ")") or ""))
    end
    table.insert(lines, "_from Chronicle via pfUI Octo's OctoBoards_")
    local text = table.concat(lines, "\n")
    local lc = pfUI.api and pfUI.api.libclient
    if lc and lc.Copy and lc.Copy(text, true) then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffOctoBoards|r: copied - paste it in Discord with Ctrl+V.")
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffOctoBoards|r: copying needs ClassicAPI. The text:")
      for l in string.gfind(text, "[^\n]+") do DEFAULT_CHAT_FRAME:AddMessage(l) end
    end
  end
end)
