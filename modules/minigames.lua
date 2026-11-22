pfUI:RegisterModule("minigames", "vanilla", function ()
  -- pfUI Octo :: OctoArcade - minigames for flights (22 Nov 2026; user, with Naowh Forever's quiz and aim trainer:
  -- "I want to make some minigames in the game itself when on flight they pop up but can also be accessed in the
  -- menu itself. It has a quiz i want all the questions + more about classic wow lore. And the aim trainers look at
  -- the addon and make our own version but better"). Naowh Forever reserves all rights: its features were read, none
  -- of its code, art or question text is used. The quiz bank (modules\minigames-quiz1-3.lua) is our own, 660 classic
  -- questions in 10 categories.
  --
  -- One window (pfOctoArcade) with tabs Quiz / Aim Trainer / Scores. A flight start (UnitOnTaxi) opens the game you
  -- picked or a small launcher under the screen's top (C.minigames.onflight); landing closes it unless a round runs.
  -- Aim trainer modes: Gridshot (3 targets), Hexakill (6), Reflex (one that shrinks away), Precision (small targets,
  -- centre hits score more), Tracking (keep the mouse on a moving target) and Kick (click casters before their cast
  -- bar fills - a WoW twist). Targets wear the other faction's faces, class pictures, raid marks or spell icons.
  -- Bests per mode go to guild / group (prefix pfArc, "^"-separated) and fill the Scores tab.
  local MG = { modes = {}, quiz = {}, aim = {} }
  pfUI.minigames = MG
  local DATA = pfUI.minigameData or { quiz = {} }
  MG.DATA = DATA
  local floor, min, max, random, sqrt = math.floor, math.min, math.max, math.random, math.sqrt
  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local ICON = "Interface\\Icons\\"
  local PREFIX = "pfArc"

  -- settings (defaults kept here)
  local DEF = { onflight = "pick", closeland = "1", quiztimer = "0", quiznext = "0", aimmode = "gridshot", aimtime = "30",
                aimsize = "44", aimfaces = "enemy", sound = "1", share = "1", scale = "1" }
  local function S()
    C.minigames = C.minigames or {}
    for k, v in pairs(DEF) do if C.minigames[k] == nil then C.minigames[k] = v end end
    if type(C.minigames.cats) ~= "table" then C.minigames.cats = {} end
    return C.minigames
  end
  MG.S = S
  -- per account: records and the leaderboard
  local function Store()
    pfUI_cache = pfUI_cache or {}
    pfUI_cache.arcade = pfUI_cache.arcade or {}
    local s = pfUI_cache.arcade
    s.me = s.me or {}
    s.board = s.board or {}
    local me = UnitName("player") or "?"
    s.me[me] = s.me[me] or { quiz = { asked = 0, right = 0, streak = 0 }, aim = {} }
    local mine = s.me[me]
    mine.quiz = mine.quiz or { asked = 0, right = 0, streak = 0 }
    mine.quiz.runs = mine.quiz.runs or {}
    mine.aim = mine.aim or {}
    return s, mine, me
  end
  MG.Store = Store

  local function Accent()
    if pfUI.api.GetAccentColor then
      local ok, r, g, b = pcall(pfUI.api.GetAccentColor)
      if ok and r then return r, g, b end
    end
    return .2, .7, 1
  end
  local function Font() return pfUI.font_default end
  local function Tex(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(WHITE)
    t:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    return t
  end
  local function Text(parent, size, flags, r, g, b)
    local t = parent:CreateFontString(nil, "OVERLAY")
    t:SetFont(Font(), size, flags or "")
    t:SetTextColor(r or .92, g or .92, b or .93)
    return t
  end
  local function Sound(kind)
    if S().sound ~= "1" or not PlaySound then return end
    local list = { hit = "igMainMenuOptionCheckBoxOn", miss = "igMainMenuOptionCheckBoxOff", right = "QUESTCOMPLETED",
                   wrong = "igQuestFailed", best = "LEVELUPSOUND", start = "igMainMenuOpen" }
    pcall(PlaySound, list[kind] or kind)
  end
  -- a flat button: dark fill, light edge on hover; b.text
  local function Button(parent, w, h, label)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w)
    b:SetHeight(h)
    b.bg = Tex(b, "BACKGROUND", .1, .105, .12, 1)
    b.bg:SetAllPoints(b)
    b.edge = Tex(b, "BORDER", .25, .26, .29, 1)
    b.edge:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
    b.edge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
    b.bg:SetDrawLayer("ARTWORK")
    b.text = Text(b, 12)
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(label or "")
    b:SetScript("OnEnter", function() if not this.locked then this.bg:SetVertexColor(.16, .17, .19, 1) end end)
    b:SetScript("OnLeave", function() if not this.locked then this.bg:SetVertexColor(.1, .105, .12, 1) end end)
    function b.Paint(r, g, bl, a) b.bg:SetVertexColor(r, g, bl, a or 1) end
    return b
  end
  MG.Button = Button

  -- ---------------------------------------------------------------- the window

  local W_W, W_H = 540, 430
  local win = CreateFrame("Frame", "pfOctoArcade", UIParent)
  MG.win = win
  win:SetWidth(W_W)
  win:SetHeight(W_H)
  win:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  win:SetFrameStrata("HIGH")
  win:SetClampedToScreen(true)
  win:SetMovable(true)
  win:EnableMouse(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", function() this:StartMoving() end)
  win:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local x, y = this:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if x and ux then S().x, S().y = floor(x - ux + .5), floor(y - uy + .5) end
  end)
  win:Hide()
  table.insert(UISpecialFrames, "pfOctoArcade")
  win.bg = Tex(win, "BACKGROUND", .05, .055, .065, .96)
  win.bg:SetAllPoints(win)
  win.edge = Tex(win, "BORDER", .22, .23, .26, 1)
  win.edge:SetPoint("TOPLEFT", win, "TOPLEFT", -1, 1)
  win.edge:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 1, -1)
  win.bg:SetDrawLayer("ARTWORK")
  win.top = Tex(win, "OVERLAY")
  win.top:SetHeight(2)
  win.top:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
  win.top:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0)
  win.icon = win:CreateTexture(nil, "OVERLAY")
  win.icon:SetWidth(22)
  win.icon:SetHeight(22)
  win.icon:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -10)
  win.icon:SetTexture(ICON .. "INV_Misc_Ticket_Darkmoon_01")
  win.icon:SetTexCoord(.08, .92, .08, .92)
  win.title = Text(win, 16, "OUTLINE")
  win.title:SetPoint("LEFT", win.icon, "RIGHT", 8, 0)
  win.title:SetText("OctoArcade")
  win.title:SetFont("Interface\\AddOns\\pfUI\\fonts\\BigNoodleTitling.ttf", 22, "OUTLINE")
  win.sub = Text(win, 11, nil, .6, .62, .66)
  win.sub:SetPoint("LEFT", win.title, "RIGHT", 8, -1)
  local close = Button(win, 22, 22, "x")
  close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -10, -10)
  close:SetScript("OnClick", function() MG.Close() end)
  -- tabs
  win.tabs = {}
  local TABS = { { "quiz", "Quiz", "INV_Misc_Book_09" }, { "aim", "Aim Trainer", "Ability_Marksmanship" }, { "board", "Scores", "INV_Misc_Note_06" } }
  for i, d in ipairs(TABS) do
    local t = Button(win, 116, 24, d[2])
    t.key = d[1]
    t.icon = t:CreateTexture(nil, "OVERLAY")
    t.icon:SetWidth(16)
    t.icon:SetHeight(16)
    t.icon:SetPoint("LEFT", t, "LEFT", 6, 0)
    t.icon:SetTexture(ICON .. d[3])
    t.icon:SetTexCoord(.08, .92, .08, .92)
    t.text:ClearAllPoints()
    t.text:SetPoint("LEFT", t.icon, "RIGHT", 6, 0)
    t:SetPoint("TOPLEFT", win, "TOPLEFT", 12 + (i - 1) * 120, -42)
    t:SetScript("OnClick", function() MG.Show(this.key) end)
    win.tabs[i] = t
  end
  -- the pages
  local function Page()
    local p = CreateFrame("Frame", nil, win)
    p:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -74)
    p:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -12, 12)
    p:Hide()
    return p
  end
  MG.pages = { quiz = Page(), aim = Page(), board = Page() }

  -- (22 Nov 2026, user: "can be enabled and disabled like anything else") the module switch (Quality of Life > Minigames
  -- heading, or the Helpers card) unloads it at the next reload; switched off now, nothing opens or pops up meanwhile
  function MG.On() return not (C.disabled and C.disabled.minigames == "1") end
  function MG.Show(key)
    if not MG.On() then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffOctoArcade|r is switched off (Quality of Life > Minigames).")
      return
    end
    key = key or MG.cur or "quiz"
    if UnitAffectingCombat and UnitAffectingCombat("player") then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffOctoArcade|r: not in combat.")
      return
    end
    -- another tab mid-run: the run ends (its clock would keep going while it is out of sight)
    if key ~= "quiz" and MG.quiz.Abandon then MG.quiz.Abandon() end
    MG.cur = key
    local ar, ag, ab = Accent()
    win.top:SetVertexColor(ar, ag, ab, .9)
    win:SetScale(tonumber(S().scale) or 1)
    if S().x then
      win:ClearAllPoints()
      win:SetPoint("CENTER", UIParent, "CENTER", S().x, S().y)
    end
    for k, p in pairs(MG.pages) do if k == key then p:Show() else p:Hide() end end
    for _, t in ipairs(win.tabs) do
      if t.key == key then
        t.locked = true
        t.Paint(ar * .35, ag * .35, ab * .35, 1)
        t.edge:SetVertexColor(ar, ag, ab, 1)
      else
        t.locked = nil
        t.Paint(.1, .105, .12, 1)
        t.edge:SetVertexColor(.25, .26, .29, 1)
      end
    end
    if key == "quiz" then MG.quiz.Open() elseif key == "aim" then MG.aim.Open() else MG.Board() end
    win:Show()
  end
  function MG.Close()
    if MG.aim.state == "run" or MG.aim.state == "count" then MG.aim.Finish(true) end
    if MG.quiz.Abandon then MG.quiz.Abandon() end
    win:Hide()
  end
  function MG.Toggle(key)
    if win:IsShown() and (not key or key == MG.cur) then MG.Close() else MG.Show(key) end
  end

  -- ---------------------------------------------------------------- the quiz

  -- the arcade's two fonts: tall numbers and a small pixel font for labels
  local FONTS = "Interface\\AddOns\\pfUI\\fonts\\"
  local NUM, PIX = FONTS .. "BigNoodleTitling.ttf", FONTS .. "Hooge.ttf"
  local function Big(parent, size, r, g, b)
    local t = parent:CreateFontString(nil, "OVERLAY")
    t:SetFont(NUM, size, "OUTLINE")
    t:SetTextColor(r or 1, g or 1, b or 1)
    return t
  end
  local function Pix(parent, size, r, g, b)
    local t = parent:CreateFontString(nil, "OVERLAY")
    t:SetFont(PIX, size, "OUTLINE")
    t:SetTextColor(r or .6, g or .62, b or .66)
    return t
  end
  MG.Big, MG.Pix = Big, Pix

  local QZ = MG.quiz
  QZ.CATS = { { "lore", "Lore & history" }, { "characters", "Characters" }, { "places", "Places" }, { "dungeons", "Dungeons" },
              { "raids", "Raids" }, { "classes", "Classes & races" }, { "professions", "Professions & mounts" },
              { "items", "Items & sets" }, { "pvp", "PvP" }, { "world", "Around the world" } }
  -- (22 Nov 2026, user: "make 3 difficulties Normal, Heroic, Mythic make them all have their own scoreboards you get
  -- more score the faster you answer ... 10,25,40 questions all timed ... make it all look amazing and quiz styled")
  -- Ranked runs: a set number of questions drawn from EVERY category (the category switches are for practice only, so
  -- the boards stay fair), a clock on each. A right answer is worth 1000 in the first second, falling to 250 at the
  -- buzzer, times the difficulty, plus 10% for each right answer in a row before it (up to +50%). Each difficulty has its
  -- own board (qnormal / qheroic / qmythic). The old endless quiz stays as Practice (its streak board is "quiz").
  QZ.DIFFS = {
    { key = "normal", board = "qnormal", name = "Normal", n = 10, secs = 20, mult = 1, icon = "INV_Misc_Book_11",
      col = { .3, .75, 1 }, tip = "A warm-up: ten questions, twenty seconds each." },
    { key = "heroic", board = "qheroic", name = "Heroic", n = 25, secs = 15, mult = 1.5, icon = "Spell_Holy_PowerInfusion",
      col = { .72, .45, 1 }, tip = "Twenty-five questions, fifteen seconds each, points x1.5." },
    { key = "mythic", board = "qmythic", name = "Mythic", n = 40, secs = 10, mult = 2, icon = "INV_Misc_Head_Dragon_Black",
      col = { 1, .5, .12 }, tip = "Forty questions, ten seconds each, points x2. Only the sharpest." },
  }
  QZ.DIFF = {}
  for _, d in ipairs(QZ.DIFFS) do QZ.DIFF[d.key] = d end
  -- points for a right answer with `left` seconds still on the clock; streak = right answers in a row, this one included
  function QZ.Points(d, left, streak)
    local frac = min(1, max(0, (left or 0) / max(1, d.secs - 1)))
    local bonus = 1 + min(max((streak or 1) - 1, 0), 5) * .1
    return floor((250 + 750 * frac) * d.mult * bonus + .5)
  end
  -- a grade from the share answered right
  function QZ.Grade(right, n)
    local pct = n > 0 and right / n * 100 or 0
    if pct >= 100 then return "S", 1, .82, .3 end
    if pct >= 90 then return "A", .3, 1, .55 end
    if pct >= 75 then return "B", .35, .7, 1 end
    if pct >= 60 then return "C", .8, .82, .86 end
    if pct >= 40 then return "D", 1, .6, .3 end
    return "F", 1, .35, .35
  end

  local page = MG.pages.quiz
  local function View()
    local f = CreateFrame("Frame", nil, page)
    f:SetAllPoints(page)
    f:Hide()
    return f
  end
  QZ.views = { lobby = View(), run = View(), result = View(), practice = View() }
  function QZ.View(name)
    QZ.view = name
    for k, f in pairs(QZ.views) do if k == name then f:Show() else f:Hide() end end
  end
  -- a dark panel with a coloured line on top, a small label and a big number (the run's heads-up row)
  local function Stat(parent, w, label)
    local f = CreateFrame("Frame", nil, parent)
    f:SetWidth(w)
    f:SetHeight(44)
    f.bg = Tex(f, "BACKGROUND", .08, .085, .1, 1)
    f.bg:SetAllPoints(f)
    f.line = Tex(f, "ARTWORK")
    f.line:SetHeight(2)
    f.line:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.line:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    f.label = Pix(f, 8)
    f.label:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -6)
    f.label:SetText(label)
    f.value = Big(f, 24)
    f.value:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 7, 3)
    return f
  end

  -- ---- the lobby: three difficulty cards
  local lb = QZ.views.lobby
  QZ.lb = lb
  lb.title = Big(lb, 30)
  lb.title:SetPoint("TOP", lb, "TOP", 0, 0)
  lb.title:SetText("PICK YOUR DIFFICULTY")
  lb.sub = Text(lb, 11, nil, .62, .64, .7)
  lb.sub:SetPoint("TOP", lb.title, "BOTTOM", 0, -2)
  lb.sub:SetText("Every question is on the clock - the faster you answer, the more it is worth.")
  lb.cards = {}
  local CARD_W, CARD_H = 164, 234
  for i, d in ipairs(QZ.DIFFS) do
    local r, g, b = d.col[1], d.col[2], d.col[3]
    local c = CreateFrame("Button", nil, lb)
    c:SetWidth(CARD_W)
    c:SetHeight(CARD_H)
    c:SetPoint("TOPLEFT", lb, "TOPLEFT", (i - 1) * (CARD_W + 12), -50)
    c.edge = Tex(c, "BACKGROUND", .2, .21, .24, 1)
    c.edge:SetPoint("TOPLEFT", c, "TOPLEFT", -1, 1)
    c.edge:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 1, -1)
    c.bg = Tex(c, "BORDER", .065, .07, .085, 1)
    c.bg:SetAllPoints(c)
    c.wash = Tex(c, "ARTWORK", r, g, b, .2)
    c.wash:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    c.wash:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, 0)
    c.wash:SetHeight(120)
    if c.wash.SetGradientAlpha then c.wash:SetGradientAlpha("VERTICAL", r, g, b, 0, r, g, b, .26) end
    c.line = Tex(c, "OVERLAY", r, g, b, 1)
    c.line:SetHeight(3)
    c.line:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    c.line:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, 0)
    c.ring = Tex(c, "ARTWORK", r, g, b, 1)
    c.ring:SetWidth(44)
    c.ring:SetHeight(44)
    c.ring:SetPoint("TOP", c, "TOP", 0, -16)
    c.icon = c:CreateTexture(nil, "OVERLAY")
    c.icon:SetWidth(40)
    c.icon:SetHeight(40)
    c.icon:SetPoint("CENTER", c.ring, "CENTER", 0, 0)
    c.icon:SetTexture(ICON .. d.icon)
    c.icon:SetTexCoord(.08, .92, .08, .92)
    c.name = Big(c, 32, r, g, b)
    c.name:SetPoint("TOP", c.ring, "BOTTOM", 0, -6)
    c.name:SetText(string.upper(d.name))
    c.info = Pix(c, 8, .82, .84, .88)
    c.info:SetPoint("TOP", c.name, "BOTTOM", 0, -2)
    c.info:SetText(d.n .. " QUESTIONS")
    c.info2 = Pix(c, 8)
    c.info2:SetPoint("TOP", c.info, "BOTTOM", 0, -3)
    c.info2:SetText(d.secs .. " S EACH  -  POINTS X" .. d.mult)
    c.rule = Tex(c, "ARTWORK", 1, 1, 1, .08)
    c.rule:SetHeight(1)
    c.rule:SetWidth(CARD_W - 28)
    c.rule:SetPoint("TOP", c.info2, "BOTTOM", 0, -9)
    c.bestL = Pix(c, 7)
    c.bestL:SetPoint("TOP", c.rule, "BOTTOM", 0, -7)
    c.bestL:SetText("YOUR BEST")
    c.best = Big(c, 24)
    c.best:SetPoint("TOP", c.bestL, "BOTTOM", 0, -2)
    c.top = Text(c, 10, nil, .7, .72, .78)
    c.top:SetPoint("TOP", c.best, "BOTTOM", 0, -3)
    c.top:SetWidth(CARD_W - 12)
    c.play = Button(c, CARD_W - 24, 28, "")
    c.play:SetPoint("BOTTOM", c, "BOTTOM", 0, 12)
    c.play.text:SetFont(NUM, 19, "OUTLINE")
    c.play.text:SetText("PLAY")
    c.play.Paint(r * .3, g * .3, b * .3, 1)
    c.play.edge:SetVertexColor(r, g, b, 1)
    c.play.locked = true
    c.key = d.key
    c.play.key = d.key
    local function Hover(on)
      if on then
        c.edge:SetVertexColor(r, g, b, 1)
        c.play.Paint(r * .45, g * .45, b * .45, 1)
      else
        c.edge:SetVertexColor(.2, .21, .24, 1)
        c.play.Paint(r * .3, g * .3, b * .3, 1)
      end
    end
    c:SetScript("OnEnter", function() Hover(true) end)
    c:SetScript("OnLeave", function() Hover(false) end)
    c.play:SetScript("OnEnter", function() Hover(true) end)
    c.play:SetScript("OnLeave", function() Hover(false) end)
    c:SetScript("OnClick", function() QZ.StartRun(this.key) end)
    c.play:SetScript("OnClick", function() QZ.StartRun(this.key) end)
    lb.cards[i] = c
  end
  lb.practice = Button(lb, 210, 26, "Practice - endless, at your own pace")
  lb.practice:SetPoint("BOTTOMLEFT", lb, "BOTTOMLEFT", 0, 2)
  lb.practice:SetScript("OnClick", function() QZ.Practice() end)
  lb.scores = Button(lb, 150, 26, "Leaderboards")
  lb.scores:SetPoint("BOTTOMRIGHT", lb, "BOTTOMRIGHT", 0, 2)
  lb.scores:SetScript("OnClick", function() MG.boardSel = MG.boardSel or "qnormal" MG.Show("board") end)
  function QZ.Lobby()
    QZ.View("lobby")
    win.sub:SetText("Normal, Heroic, Mythic - " .. table.getn(DATA.quiz) .. " questions")
    local _, me = Store()
    for i, d in ipairs(QZ.DIFFS) do
      local c = lb.cards[i]
      local mine = me.quiz.runs[d.key]
      c.best:SetText(mine and mine.score and mine.score > 0 and mine.score or "--")
      local rows = MG.Rows and MG.Rows(d.board) or {}
      local t = rows[1]
      c.top:SetText(t and ("|cffffd24d#1|r  " .. t.name .. " " .. MG.RealmText(t.realm) .. "  |cffffffff" .. t.v .. "|r")
        or "|cff666e7aNo scores yet - be the first|r")
    end
  end

  -- ---- a ranked run
  local rv = QZ.views.run
  rv.hud = {}
  for i, label in ipairs({ "QUESTION", "SCORE", "STREAK", "TIME" }) do
    local f = Stat(rv, 126, label)
    f:SetPoint("TOPLEFT", rv, "TOPLEFT", (i - 1) * 130, 0)
    rv.hud[i] = f
  end
  rv.timer = CreateFrame("StatusBar", nil, rv)
  rv.timer:SetPoint("TOPLEFT", rv, "TOPLEFT", 0, -48)
  rv.timer:SetPoint("TOPRIGHT", rv, "TOPRIGHT", 0, -48)
  rv.timer:SetHeight(5)
  rv.timer:SetStatusBarTexture(WHITE)
  rv.timer:SetMinMaxValues(0, 1)
  rv.timer.bg = Tex(rv.timer, "BACKGROUND", .1, .105, .12, 1)
  rv.timer.bg:SetAllPoints(rv.timer)
  rv.cat = Pix(rv, 8)
  rv.cat:SetPoint("TOP", rv, "TOP", 0, -62)
  rv.q = Text(rv, 15, "OUTLINE")
  rv.q:SetPoint("TOP", rv, "TOP", 0, -76)
  rv.q:SetWidth(490)
  rv.count = Big(rv, 80)
  rv.count:SetPoint("CENTER", rv, "CENTER", 0, -40)
  rv.answers = {}
  local ANS_W = 254
  for i = 1, 4 do
    local b = Button(rv, ANS_W, 50, "")
    b:SetPoint("TOPLEFT", rv, "TOPLEFT", math.mod(i - 1, 2) * (ANS_W + 8), -124 - floor((i - 1) / 2) * 58)
    b.badge = Tex(b, "OVERLAY")
    b.badge:SetWidth(30)
    b.badge:SetHeight(30)
    b.badge:SetPoint("LEFT", b, "LEFT", 10, 0)
    b.letter = Big(b, 22)
    b.letter:SetPoint("CENTER", b.badge, "CENTER", 0, 0)
    b.letter:SetText(string.sub("ABCD", i, i))
    b.text:ClearAllPoints()
    b.text:SetPoint("LEFT", b.badge, "RIGHT", 10, 0)
    b.text:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetFont(Font(), 12, "")
    b.id = i
    b:SetScript("OnClick", function() QZ.RunAnswer(this.id) end)
    rv.answers[i] = b
  end
  rv.verdict = Big(rv, 28)
  rv.verdict:SetPoint("TOP", rv, "TOP", 0, -244)
  rv.why = Pix(rv, 8, .85, .86, .9)
  rv.why:SetPoint("TOP", rv.verdict, "BOTTOM", 0, -2)
  rv.fact = Text(rv, 11, nil, .78, .8, .85)
  rv.fact:SetPoint("TOP", rv.why, "BOTTOM", 0, -5)
  rv.fact:SetWidth(290)
  rv.quit = Button(rv, 70, 22, "Quit")
  rv.quit:SetPoint("BOTTOMLEFT", rv, "BOTTOMLEFT", 0, 12)
  rv.quit:SetScript("OnClick", function() QZ.run = nil QZ.Lobby() end)
  rv.nextb = Button(rv, 110, 22, "Next  >")
  rv.nextb:SetPoint("BOTTOMRIGHT", rv, "BOTTOMRIGHT", 0, 12)
  rv.nextb:SetScript("OnClick", function() if QZ.run and QZ.run.state == "shown" then QZ.run.nextAt = 0 end end)
  -- one pip per question along the bottom: green right, red wrong, white now, grey still to come
  rv.pips = {}
  for i = 1, 40 do
    local p = Tex(rv, "ARTWORK", .2, .21, .24, 1)
    p:SetHeight(5)
    rv.pips[i] = p
  end
  function QZ.PaintPips()
    local r = QZ.run
    if not r then return end
    local n = r.d.n
    local w = (516 - (n - 1) * 2) / n
    for i, p in ipairs(rv.pips) do
      if i > n then p:Hide() else
        p:ClearAllPoints()
        p:SetWidth(w)
        p:SetPoint("BOTTOMLEFT", rv, "BOTTOMLEFT", (i - 1) * (w + 2), 0)
        local m = r.marks[i]
        if m == "right" then p:SetVertexColor(.25, .85, .47, 1)
        elseif m == "wrong" then p:SetVertexColor(1, .3, .3, 1)
        elseif i == r.pos then p:SetVertexColor(1, 1, 1, 1)
        else p:SetVertexColor(.2, .21, .24, 1) end
        p:Show()
      end
    end
  end
  function QZ.PaintHud()
    local r = QZ.run
    if not r then return end
    local d = r.d
    for _, f in ipairs(rv.hud) do f.line:SetVertexColor(d.col[1], d.col[2], d.col[3], 1) end
    rv.hud[1].value:SetText(min(max(r.pos, 1), d.n) .. "/" .. d.n)
    rv.hud[2].value:SetText(r.score)
    rv.hud[3].value:SetText("x" .. r.streak)
    if r.streak >= 3 then rv.hud[3].value:SetTextColor(1, .82, .3) else rv.hud[3].value:SetTextColor(1, 1, 1) end
  end
  function QZ.StartRun(key)
    local d = QZ.DIFF[key] or QZ.DIFFS[1]
    local all = {}
    for i in ipairs(DATA.quiz) do table.insert(all, i) end
    for i = table.getn(all), 2, -1 do
      local j = random(1, i)
      all[i], all[j] = all[j], all[i]
    end
    local list = {}
    for i = 1, min(d.n, table.getn(all)) do list[i] = all[i] end
    if not list[1] then return end
    QZ.run = { d = d, list = list, pos = 0, score = 0, right = 0, streak = 0, bestStreak = 0, marks = {}, took = 0,
               state = "count", goAt = GetTime() + 3 }
    QZ.View("run")
    win.sub:SetText(d.name .. " - " .. d.n .. " questions, " .. d.secs .. " s each")
    rv.cat:SetText("GET READY")
    rv.cat:SetTextColor(d.col[1], d.col[2], d.col[3])
    rv.q:SetText(string.upper(d.name) .. " - " .. d.n .. " QUESTIONS")
    for _, b in ipairs(rv.answers) do b:Hide() end
    rv.verdict:SetText("") rv.why:SetText("") rv.fact:SetText("")
    rv.nextb:Hide()
    rv.count:SetText("3")
    rv.count:Show()
    rv.timer:SetValue(1)
    rv.timer:SetStatusBarColor(d.col[1], d.col[2], d.col[3])
    rv.hud[4].value:SetText(d.secs)
    QZ.PaintHud()
    QZ.PaintPips()
    Sound("start")
  end
  function QZ.Ask()
    local r = QZ.run
    r.pos = r.pos + 1
    if r.pos > table.getn(r.list) then return QZ.EndRun() end
    local e = DATA.quiz[r.list[r.pos]]
    r.e = e
    local order = { 1, 2, 3, 4 }
    for i = 4, 2, -1 do
      local j = random(1, i)
      order[i], order[j] = order[j], order[i]
    end
    r.order = order
    local d = r.d
    rv.count:Hide()
    rv.cat:SetText(string.upper(QZ.CatName(e.c)))
    rv.q:SetText(e.q)
    for i, b in ipairs(rv.answers) do
      local txt = e.a[order[i]]
      b.text:SetText(txt or "")
      b.locked = nil
      b:SetAlpha(1)
      b.Paint(.1, .105, .12, 1)
      b.edge:SetVertexColor(.25, .26, .29, 1)
      b.badge:SetVertexColor(d.col[1] * .55, d.col[2] * .55, d.col[3] * .55, 1)
      if txt then b:Show() else b:Hide() end
    end
    rv.verdict:SetText("") rv.why:SetText("") rv.fact:SetText("")
    rv.nextb:Hide()
    r.state = "ask"
    r.asked = GetTime()
    r.deadline = r.asked + d.secs
    QZ.PaintHud()
    QZ.PaintPips()
  end
  function QZ.RunAnswer(i)
    local r = QZ.run
    if not r or r.state ~= "ask" then return end
    local now = GetTime()
    local left = max(0, r.deadline - now)
    local right = i and r.order[i] == 1
    r.state = "shown"
    r.took = r.took + (r.d.secs - left)
    for n, b in ipairs(rv.answers) do
      b.locked = true
      if r.order[n] == 1 then
        b.Paint(.1, .36, .18, 1)
        b.edge:SetVertexColor(.25, .85, .47, 1)
        b.badge:SetVertexColor(.25, .85, .47, 1)
      elseif n == i then
        b.Paint(.42, .09, .09, 1)
        b.edge:SetVertexColor(1, .35, .35, 1)
        b.badge:SetVertexColor(1, .35, .35, 1)
      else
        b:SetAlpha(.4)
      end
    end
    local took = floor((r.d.secs - left) * 10 + .5) / 10
    if right then
      r.streak = r.streak + 1
      r.bestStreak = max(r.bestStreak, r.streak)
      r.right = r.right + 1
      local pts = QZ.Points(r.d, left, r.streak)
      r.score = r.score + pts
      if not r.fastest or took < r.fastest then r.fastest = took end
      r.marks[r.pos] = "right"
      rv.verdict:SetText("+" .. pts)
      rv.verdict:SetTextColor(.3, 1, .55)
      local bonus = min(r.streak - 1, 5) * 10
      rv.why:SetText("CORRECT  -  " .. took .. " S" .. (bonus > 0 and ("  -  STREAK X" .. r.streak .. " +" .. bonus .. "%") or ""))
      Sound("right")
    else
      r.streak = 0
      r.marks[r.pos] = "wrong"
      rv.verdict:SetText(i and "WRONG" or "OUT OF TIME")
      rv.verdict:SetTextColor(1, .35, .35)
      rv.why:SetText("NO POINTS  -  STREAK LOST")
      Sound("wrong")
    end
    rv.fact:SetText(r.e.f or "")
    r.nextAt = now + (right and 1.6 or 3.2)
    rv.nextb.text:SetText(r.pos >= table.getn(r.list) and "Results  >" or "Next  >")
    rv.nextb:Show()
    QZ.PaintHud()
    QZ.PaintPips()
  end
  function QZ.EndRun()
    local r = QZ.run
    r.state = "done"
    local d = r.d
    local _, me = Store()
    local old = me.quiz.runs[d.key]
    local isBest = r.score > 0 and (not old or r.score > (old.score or 0))
    if isBest then
      me.quiz.runs[d.key] = { score = r.score, right = r.right, n = d.n, t = time() }
      MG.Share(d.board, r.score, r.right)
      Sound("best")
    end
    me.quiz.played = (me.quiz.played or 0) + 1
    QZ.ShowResult(isBest)
    if MG.after then local f = MG.after MG.after = nil f() end
  end
  function QZ.Tick(now)
    local r = QZ.run
    if not r or QZ.view ~= "run" then return end
    if r.state == "count" then
      local n = r.goAt - now
      if n <= 0 then QZ.Ask()
      else
        local s = tostring(floor(n) + 1)
        if rv.count:GetText() ~= s then rv.count:SetText(s) end
        rv.count:SetAlpha(.35 + .65 * (n - floor(n)))
      end
    elseif r.state == "ask" then
      local secs = r.d.secs
      local left = r.deadline - now
      if left <= 0 then QZ.RunAnswer(nil) return end
      local f = left / secs
      rv.timer:SetValue(f)
      local d = r.d
      if f > .5 then rv.timer:SetStatusBarColor(d.col[1], d.col[2], d.col[3])
      elseif f > .25 then rv.timer:SetStatusBarColor(1, .7, .2)
      else rv.timer:SetStatusBarColor(1, .25, .25) end
      rv.hud[4].value:SetText(string.format("%.1f", left))
      if f <= .25 then rv.hud[4].value:SetTextColor(1, .35, .35) else rv.hud[4].value:SetTextColor(1, 1, 1) end
    elseif r.state == "shown" then
      if now >= (r.nextAt or 0) then QZ.Ask() end
    end
  end

  -- ---- the results
  local rs = QZ.views.result
  rs.left = CreateFrame("Frame", nil, rs)
  rs.left:SetPoint("TOPLEFT", rs, "TOPLEFT", 0, 0)
  rs.left:SetPoint("BOTTOMLEFT", rs, "BOTTOMLEFT", 0, 0)
  rs.left:SetWidth(252)
  rs.left.bg = Tex(rs.left, "BACKGROUND", .065, .07, .085, 1)
  rs.left.bg:SetAllPoints(rs.left)
  rs.left.line = Tex(rs.left, "ARTWORK")
  rs.left.line:SetHeight(3)
  rs.left.line:SetPoint("TOPLEFT", rs.left, "TOPLEFT", 0, 0)
  rs.left.line:SetPoint("TOPRIGHT", rs.left, "TOPRIGHT", 0, 0)
  rs.title = Big(rs.left, 26)
  rs.title:SetPoint("TOP", rs.left, "TOP", 0, -12)
  rs.diff = Pix(rs.left, 8)
  rs.diff:SetPoint("TOP", rs.title, "BOTTOM", 0, -3)
  rs.grade = Big(rs.left, 84)
  rs.grade:SetPoint("TOPLEFT", rs.left, "TOPLEFT", 26, -62)
  rs.gradeL = Pix(rs.left, 7)
  rs.gradeL:SetPoint("TOP", rs.grade, "BOTTOM", 0, 0)
  rs.gradeL:SetText("GRADE")
  rs.score = Big(rs.left, 40)
  rs.score:SetPoint("TOPRIGHT", rs.left, "TOPRIGHT", -20, -70)
  rs.scoreL = Pix(rs.left, 7)
  rs.scoreL:SetPoint("TOPRIGHT", rs.score, "BOTTOMRIGHT", 0, -1)
  rs.scoreL:SetText("SCORE")
  rs.rows = {}
  for i, label in ipairs({ "Right", "Accuracy", "Average answer", "Fastest", "Best streak", "Your best", "Board rank" }) do
    local l = Text(rs.left, 10, nil, .55, .57, .62)
    l:SetPoint("TOPLEFT", rs.left, "TOPLEFT", 20, -168 - (i - 1) * 17)
    l:SetText(label)
    local v = Text(rs.left, 11, "OUTLINE")
    v:SetPoint("TOPRIGHT", rs.left, "TOPRIGHT", -20, -168 - (i - 1) * 17)
    v:SetJustifyH("RIGHT")
    rs.rows[i] = v
  end
  rs.again = Button(rs, 120, 26, "Play again")
  rs.again:SetPoint("BOTTOMLEFT", rs.left, "BOTTOMRIGHT", 12, 0)
  rs.again:SetScript("OnClick", function() if QZ.run then QZ.StartRun(QZ.run.d.key) end end)
  rs.lobby = Button(rs, 120, 26, "Difficulties")
  rs.lobby:SetPoint("BOTTOMRIGHT", rs, "BOTTOMRIGHT", 0, 0)
  rs.lobby:SetScript("OnClick", function() QZ.Lobby() end)
  rs.boardTitle = Pix(rs, 8, 1, .82, .3)
  rs.boardTitle:SetPoint("TOPLEFT", rs.left, "TOPRIGHT", 12, -4)
  function QZ.ShowResult(isBest)
    local r = QZ.run
    local d = r.d
    QZ.View("result")
    local cr, cg, cb = d.col[1], d.col[2], d.col[3]
    rs.left.line:SetVertexColor(cr, cg, cb, 1)
    rs.title:SetText(isBest and "NEW HIGH SCORE!" or "RUN COMPLETE")
    if isBest then rs.title:SetTextColor(1, .82, .3) else rs.title:SetTextColor(1, 1, 1) end
    rs.diff:SetText(string.upper(d.name) .. "  -  " .. d.n .. " QUESTIONS")
    rs.diff:SetTextColor(cr, cg, cb)
    local g, gr, gg, gb = QZ.Grade(r.right, d.n)
    rs.grade:SetText(g)
    rs.grade:SetTextColor(gr, gg, gb)
    rs.score:SetText(r.score)
    local _, me = Store()
    local best = me.quiz.runs[d.key]
    local rows = MG.Rows(d.board)
    local rank
    for n, row in ipairs(rows) do if row.you then rank = n break end end
    local vals = { r.right .. " / " .. d.n, floor(r.right / d.n * 100 + .5) .. "%",
                   string.format("%.1f s", r.took / max(1, table.getn(r.list))),
                   r.fastest and (r.fastest .. " s") or "--", "x" .. r.bestStreak, best and best.score or 0,
                   rank and ("#" .. rank .. " of " .. table.getn(rows)) or "--" }
    for i, v in ipairs(rs.rows) do v:SetText(vals[i]) end
    rs.boardTitle:SetText(string.upper(d.name) .. " LEADERBOARD")
    rs.boardTitle:SetTextColor(cr, cg, cb)
    if not rs.table then
      rs.table = MG.NewTable(rs, 12, 252)
      rs.table:SetPoint("TOPLEFT", rs.left, "TOPRIGHT", 12, -18)
    end
    rs.table.Fill(rows, MG.BOARD[d.board])
    win.sub:SetText(d.name .. " - " .. r.score .. " points")
  end

  -- ---- practice: the endless quiz, at your own pace (its own clock setting, the categories you pick)
  local qp = QZ.views.practice
  qp.cat = Text(qp, 10, nil, .55, .57, .62)
  qp.cat:SetPoint("TOPLEFT", qp, "TOPLEFT", 2, -2)
  qp.back = Button(qp, 96, 20, "<  Difficulties")
  qp.back:SetPoint("TOPRIGHT", qp, "TOPRIGHT", 0, 2)
  qp.back:SetScript("OnClick", function() QZ.Lobby() end)
  qp.timer = CreateFrame("StatusBar", nil, qp)
  qp.timer:SetPoint("TOPLEFT", qp, "TOPLEFT", 0, -22)
  qp.timer:SetPoint("TOPRIGHT", qp, "TOPRIGHT", 0, -22)
  qp.timer:SetHeight(3)
  qp.timer:SetStatusBarTexture(WHITE)
  qp.timer:SetMinMaxValues(0, 1)
  qp.q = Text(qp, 15)
  qp.q:SetPoint("TOPLEFT", qp, "TOPLEFT", 2, -32)
  qp.q:SetPoint("TOPRIGHT", qp, "TOPRIGHT", -2, -32)
  qp.q:SetJustifyH("LEFT")
  qp.answers = {}
  for i = 1, 4 do
    local b = Button(qp, 496, 32, "")
    b:SetPoint("TOPLEFT", qp, "TOPLEFT", 10, -86 - (i - 1) * 38)
    b:SetPoint("RIGHT", qp, "RIGHT", -10, 0)
    b.key = Text(b, 11, "OUTLINE", .6, .62, .66)
    b.key:SetPoint("LEFT", b, "LEFT", 10, 0)
    b.key:SetText(i)
    b.id = i
    b:SetScript("OnClick", function() QZ.Answer(this.id) end)
    qp.answers[i] = b
  end
  qp.fact = Text(qp, 12, nil, .85, .86, .9)
  qp.fact:SetPoint("TOPLEFT", qp, "TOPLEFT", 10, -242)
  qp.fact:SetPoint("TOPRIGHT", qp, "TOPRIGHT", -10, -242)
  qp.fact:SetJustifyH("LEFT")
  qp.nextb = Button(qp, 140, 28, "Next question")
  qp.nextb:SetPoint("BOTTOMRIGHT", qp, "BOTTOMRIGHT", -10, 34)
  qp.nextb:SetScript("OnClick", function() QZ.Next() end)
  qp.score = Text(qp, 11, nil, .65, .67, .72)
  qp.score:SetPoint("BOTTOMLEFT", qp, "BOTTOMLEFT", 10, 8)

  -- the deck: shuffled, every allowed question once before any repeats
  function QZ.Allowed(e)
    local off = S().cats
    return off[e.c] ~= "0"
  end
  function QZ.Deal()
    local list = {}
    for i, e in ipairs(DATA.quiz) do if QZ.Allowed(e) then table.insert(list, i) end end
    for i = table.getn(list), 2, -1 do
      local j = random(1, i)
      list[i], list[j] = list[j], list[i]
    end
    QZ.deck, QZ.pos = list, 0
  end
  function QZ.CatName(c)
    for _, d in ipairs(QZ.CATS) do if d[1] == c then return d[2] end end
    return c
  end
  function QZ.PaintScore()
    local _, me = Store()
    local q = me.quiz
    qp.score:SetText(string.format("|cffffffff%d|r / %d right   |   streak |cffffffff%d|r   |   best |cffffd24d%d|r   |   %d questions",
      QZ.right or 0, QZ.asked or 0, QZ.streak or 0, q.best or 0, table.getn(DATA.quiz)))
  end
  function QZ.Next()
    if not QZ.deck or QZ.pos >= table.getn(QZ.deck) then QZ.Deal() end
    if not QZ.deck[1] then
      qp.q:SetText("No questions: every category is switched off (options > Minigames).")
      return
    end
    QZ.pos = QZ.pos + 1
    local e = DATA.quiz[QZ.deck[QZ.pos]]
    QZ.cur = e
    QZ.done = nil
    -- shuffle the answers; remember where the right one went
    local order = { 1, 2, 3, 4 }
    for i = 4, 2, -1 do
      local j = random(1, i)
      order[i], order[j] = order[j], order[i]
    end
    QZ.order = order
    qp.cat:SetText(string.upper(QZ.CatName(e.c)) .. "   |cff666e7a-  PRACTICE|r")
    qp.q:SetText(e.q)
    for i, b in ipairs(qp.answers) do
      local txt = e.a[order[i]]
      b.text:SetText(txt or "")
      b.locked = nil
      b.Paint(.1, .105, .12, 1)
      b.edge:SetVertexColor(.25, .26, .29, 1)
      if txt then b:Show() else b:Hide() end
    end
    qp.fact:SetText("")
    qp.nextb:Hide()
    QZ.deadline = tonumber(S().quiztimer) and tonumber(S().quiztimer) > 0 and (GetTime() + tonumber(S().quiztimer)) or nil
    if QZ.deadline then qp.timer:Show() else qp.timer:Hide() end
    QZ.PaintScore()
  end
  function QZ.Answer(i)
    if QZ.done or not QZ.cur then return end
    QZ.done = true
    local right = QZ.order[i or 0] == 1
    local _, me = Store()
    local q = me.quiz
    QZ.asked = (QZ.asked or 0) + 1
    q.asked = (q.asked or 0) + 1
    for n, b in ipairs(qp.answers) do
      b.locked = true
      if QZ.order[n] == 1 then
        b.Paint(.12, .4, .2, 1)
        b.edge:SetVertexColor(.25, .85, .47, 1)
      elseif n == i then
        b.Paint(.45, .1, .1, 1)
        b.edge:SetVertexColor(1, .35, .35, 1)
      end
    end
    if right then
      QZ.right = (QZ.right or 0) + 1
      q.right = (q.right or 0) + 1
      QZ.streak = (QZ.streak or 0) + 1
      if QZ.streak > (q.best or 0) then
        q.best = QZ.streak
        MG.Share("quiz", q.best, 0)
      end
      Sound("right")
    else
      QZ.streak = 0
      Sound("wrong")
    end
    local head = right and "|cff40d977Correct!|r" or (i and "|cffff6060Not quite.|r" or "|cffff6060Out of time.|r")
    qp.fact:SetText(head .. (QZ.cur.f and ("  " .. QZ.cur.f) or ""))
    qp.nextb:Show()
    QZ.deadline = nil
    if S().quiznext == "1" then QZ.autoAt = GetTime() + (right and 1.2 or 2.5) end
    QZ.PaintScore()
  end
  function QZ.Practice()
    QZ.View("practice")
    win.sub:SetText("practice - " .. table.getn(DATA.quiz) .. " questions, no board")
    if not QZ.cur or QZ.done then QZ.Next() else QZ.PaintScore() end
  end
  -- the tab: back where you were (a run that was going, its results, practice), else the lobby
  function QZ.Open()
    if QZ.view == "run" and QZ.run and QZ.run.state ~= "done" then QZ.View("run")
    elseif QZ.view == "result" and QZ.run then QZ.View("result")
    elseif QZ.view == "practice" then QZ.Practice()
    else QZ.Lobby() end
  end
  -- leaving the window mid-run ends the run (its clock would run out while hidden)
  function QZ.Abandon()
    if QZ.run and QZ.run.state ~= "done" then QZ.run = nil QZ.view = "lobby" end
  end
  page:SetScript("OnUpdate", function()
    local now = GetTime()
    if QZ.deadline and QZ.view ~= "run" then
      local total = tonumber(S().quiztimer) or 15
      local left = QZ.deadline - now
      qp.timer:SetValue(max(0, left / total))
      local r = left < total * .3 and 1 or .2
      qp.timer:SetStatusBarColor(r, left < total * .3 and .35 or .7, left < total * .3 and .35 or 1)
      if left <= 0 then QZ.Answer(nil) end
    end
    if QZ.autoAt and now >= QZ.autoAt then QZ.autoAt = nil QZ.Next() end
    QZ.Tick(now)
  end)

  -- ---------------------------------------------------------------- the aim trainer

  local AM = MG.aim
  AM.MODES = {
    { key = "gridshot", name = "Gridshot", icon = "Ability_Marksmanship", n = 3, tip = "Three targets at once - a new one for each you hit." },
    { key = "hexakill", name = "Hexakill", icon = "Ability_Hunter_SniperShot", n = 6, tip = "Six targets at once. Speed and flow." },
    { key = "reflex", name = "Reflex", icon = "Ability_Rogue_Sprint", n = 1, tip = "One target at a time that shrinks away in 1.5 s." },
    { key = "precision", name = "Precision", icon = "Ability_Hunter_SniperShot", n = 2, tip = "Small targets. Hits nearer the middle score more." },
    { key = "tracking", name = "Tracking", icon = "Ability_Hunter_AspectOfTheFox", n = 1, tip = "Keep your mouse on the moving target. Points every tenth of a second." },
    { key = "kick", name = "Kick!", icon = "Ability_Kick", n = 3, tip = "Casters fill their cast bars: click them before the cast ends. A finished cast costs you." },
  }
  for _, m in ipairs(AM.MODES) do MG.modes[m.key] = m end
  AM.FACES = {
    enemy = function()
      local fac = UnitFactionGroup and UnitFactionGroup("player")
      local list = (fac == "Horde") and { "Human_01", "Human_02", "Dwarf_01", "Dwarf_02", "Gnome_01", "Gnome_02", "Elf_01" }
        or { "Orc_01", "Orc_02", "Troll_01", "Troll_02", "Tauren_01", "Tauren_02", "Undead_01", "Undead_02" }
      local out = {}
      for _, n in ipairs(list) do table.insert(out, { ICON .. "INV_Misc_Head_" .. n }) end
      return out
    end,
    creatures = function()
      local out = {}
      for _, n in ipairs({ "Murloc_01", "Kobold_01", "Gnoll_01", "Dragon_01", "Scourge_01", "Centaur_01", "Quillboar_01" }) do
        table.insert(out, { ICON .. "INV_Misc_Head_" .. n })
      end
      return out
    end,
    class = function()
      local out = {}
      for _, c in ipairs({ "WARRIOR", "MAGE", "ROGUE", "DRUID", "HUNTER", "SHAMAN", "PRIEST", "WARLOCK", "PALADIN" }) do
        local tc = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[c]
        if tc then table.insert(out, { pfUI.media["img:classicons"], tc }) end
      end
      return out
    end,
    marks = function()
      local out = {}
      for i = 0, 7 do
        local x, y = math.mod(i, 4) * .25, floor(i / 4) * .25
        table.insert(out, { "Interface\\TargetingFrame\\UI-RaidTargetingIcons", { x, x + .25, y, y + .25 } })
      end
      return out
    end,
    spells = function()
      local out = {}
      for _, n in ipairs({ "Spell_Frost_FrostBolt02", "Spell_Fire_FlameBolt", "Spell_Shadow_ShadowBolt", "Spell_Nature_Lightning",
                           "Spell_Holy_HolyBolt", "Spell_Holy_Heal" }) do table.insert(out, { ICON .. n }) end
      return out
    end,
  }
  local ap = MG.pages.aim
  -- (22 Nov 2026, user with the first build: the mode buttons lay over the scores, "very simple and plain make it look
  -- better and more like an actual arcade", and modes could not be changed until a round ended) the arcade cabinet:
  -- a mode row of its own, four stat panels with big numbers, a draining timer bar, a dark screen with scanlines and
  -- corner brackets, 3-2-1-GO, hit bursts, combo callouts, and a results card with a grade. A mode can be picked at
  -- any time: a round that runs just stops.

  -- mode row
  ap.chips = {}
  local CHIP_W = 83
  for i, m in ipairs(AM.MODES) do
    local b = Button(ap, CHIP_W, 26, "")
    b:SetPoint("TOPLEFT", ap, "TOPLEFT", (i - 1) * (CHIP_W + 3), 0)
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetWidth(16) b.icon:SetHeight(16)
    b.icon:SetPoint("LEFT", b, "LEFT", 5, 0)
    b.icon:SetTexture(ICON .. m.icon)
    b.icon:SetTexCoord(.08, .92, .08, .92)
    b.text:ClearAllPoints()
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
    b.text:SetFont(Font(), 11, "")
    b.text:SetText(m.name)
    b.glow = Tex(b, "OVERLAY")
    b.glow:SetHeight(2)
    b.glow:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    b.key = m.key
    b:SetScript("OnClick", function()
      -- any time: a round that runs stops, the new mode is ready
      if AM.state == "run" or AM.state == "count" then AM.Finish(true) end
      S().aimmode = this.key
      AM.Idle()
      Sound("hit")
    end)
    b:SetScript("OnEnter", function()
      if not this.locked then this.bg:SetVertexColor(.16, .17, .19, 1) end
      GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
      GameTooltip:SetText(MG.modes[this.key].name, 1, 1, 1)
      GameTooltip:AddLine(MG.modes[this.key].tip, .8, .82, .86, 1)
      local _, me = Store()
      local best = me.aim[this.key]
      GameTooltip:AddLine(best and ("Your best: " .. best.score) or "No best yet", 1, .82, .3)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
      if not this.locked then this.bg:SetVertexColor(.1, .105, .12, 1) end
      GameTooltip:Hide()
    end)
    ap.chips[i] = b
  end

  -- stat panels
  ap.hud = {}
  local HUD = { "TIME", "SCORE", "ACCURACY", "COMBO" }
  local PANEL_W = 126
  for i, label in ipairs(HUD) do
    local f = CreateFrame("Frame", nil, ap)
    f:SetWidth(PANEL_W)
    f:SetHeight(44)
    f:SetPoint("TOPLEFT", ap, "TOPLEFT", (i - 1) * (PANEL_W + 4), -32)
    f.bg = Tex(f, "BACKGROUND", .08, .085, .1, 1)
    f.bg:SetAllPoints(f)
    f.line = Tex(f, "ARTWORK")
    f.line:SetHeight(1)
    f.line:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.line:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    f.label = Pix(f, 8)
    f.label:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -6)
    f.label:SetText(label)
    f.value = Big(f, 24)
    f.value:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 7, 3)
    ap.hud[i] = f.value
    ap.hud[i].panel = f
  end
  -- the timer bar
  ap.timer = CreateFrame("StatusBar", nil, ap)
  ap.timer:SetPoint("TOPLEFT", ap, "TOPLEFT", 0, -80)
  ap.timer:SetPoint("TOPRIGHT", ap, "TOPRIGHT", 0, -80)
  ap.timer:SetHeight(4)
  ap.timer:SetStatusBarTexture(WHITE)
  ap.timer:SetMinMaxValues(0, 1)
  ap.timer.bg = Tex(ap.timer, "BACKGROUND", .1, .105, .12, 1)
  ap.timer.bg:SetAllPoints(ap.timer)

  -- the screen
  local area = CreateFrame("Button", nil, ap)
  ap.area = area
  area:SetPoint("TOPLEFT", ap, "TOPLEFT", 0, -88)
  area:SetPoint("BOTTOMRIGHT", ap, "BOTTOMRIGHT", 0, 0)
  area:RegisterForClicks("LeftButtonDown", "RightButtonDown")
  area.bg = Tex(area, "BACKGROUND", .03, .045, .08, 1)
  area.bg:SetAllPoints(area)
  area.shade = Tex(area, "BACKGROUND", 0, 0, 0, 1)
  area.shade:SetAllPoints(area)
  if area.shade.SetGradientAlpha then area.shade:SetGradientAlpha("VERTICAL", 0, 0, 0, .55, 0, 0, 0, 0) end
  for i = 1, 3 do
    local h = Tex(area, "BORDER", 1, 1, 1, .03)
    h:SetHeight(1)
    h:SetPoint("LEFT", area, "LEFT", 0, 0)
    h:SetPoint("RIGHT", area, "RIGHT", 0, 0)
    h:SetPoint("TOP", area, "TOP", 0, -i * 66)
    local v = Tex(area, "BORDER", 1, 1, 1, .03)
    v:SetWidth(1)
    v:SetPoint("TOP", area, "TOP", 0, 0)
    v:SetPoint("BOTTOM", area, "BOTTOM", 0, 0)
    v:SetPoint("LEFT", area, "LEFT", i * 129, 0)
  end
  -- scanlines
  for i = 1, 84 do
    local s = Tex(area, "BORDER", 0, 0, 0, .18)
    s:SetHeight(1)
    s:SetPoint("LEFT", area, "LEFT", 0, 0)
    s:SetPoint("RIGHT", area, "RIGHT", 0, 0)
    s:SetPoint("TOP", area, "TOP", 0, -i * 3)
  end
  area.edge = {}
  for i, pt in ipairs({ { "TOPLEFT", "TOPRIGHT", 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 1 }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
    local e = Tex(area, "ARTWORK")
    if pt[3] then e:SetHeight(1) else e:SetWidth(1) end
    e:SetPoint(pt[1], area, pt[1], 0, 0)
    e:SetPoint(pt[2], area, pt[2], 0, 0)
    area.edge[i] = e
  end
  -- corner brackets
  area.corners = {}
  for _, c in ipairs({ { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }) do
    local h = Tex(area, "OVERLAY")
    h:SetWidth(18) h:SetHeight(3)
    h:SetPoint(c[1], area, c[1], 0, 0)
    local v = Tex(area, "OVERLAY")
    v:SetWidth(3) v:SetHeight(18)
    v:SetPoint(c[1], area, c[1], 0, 0)
    table.insert(area.corners, h)
    table.insert(area.corners, v)
  end
  -- the idle / countdown words
  area.mode = Big(area, 34)
  area.mode:SetPoint("CENTER", area, "CENTER", 0, 42)
  area.small = Text(area, 12, nil, .78, .8, .84)
  area.small:SetPoint("TOP", area.mode, "BOTTOM", 0, -6)
  area.small:SetWidth(440)
  area.best = Text(area, 12, "OUTLINE", 1, .82, .3)
  area.best:SetPoint("TOP", area.small, "BOTTOM", 0, -8)
  area.press = Pix(area, 12, 1, 1, 1)
  area.press:SetPoint("TOP", area.best, "BOTTOM", 0, -16)
  area.press:SetText("CLICK TO START")
  area.count = Big(area, 72)
  area.count:SetPoint("CENTER", area, "CENTER", 0, 0)
  area.count:Hide()
  area.call = Big(area, 30, 1, .82, .3)
  area.call:SetPoint("TOP", area, "TOP", 0, -14)
  area.call:Hide()
  -- keep the old names the rest uses
  area.big = area.mode
  area:SetScript("OnClick", function()
    if AM.state == "idle" or AM.state == "done" then
      if AM.state == "done" and GetTime() < (AM.lockUntil or 0) then return end
      AM.Begin()
    elseif AM.state == "run" then
      AM.Miss()
    end
  end)

  -- results card
  local card = CreateFrame("Frame", nil, area)
  ap.card = card
  card:SetWidth(320)
  card:SetHeight(214)
  card:SetPoint("CENTER", area, "CENTER", 0, 0)
  card:SetFrameLevel(area:GetFrameLevel() + 20)
  card.bg = Tex(card, "BACKGROUND", .04, .05, .07, .97)
  card.bg:SetAllPoints(card)
  card.edge = Tex(card, "BORDER")
  card.edge:SetPoint("TOPLEFT", card, "TOPLEFT", -1, 1)
  card.edge:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 1, -1)
  card.bg:SetDrawLayer("ARTWORK")
  card.title = Big(card, 24)
  card.title:SetPoint("TOP", card, "TOP", 0, -10)
  card.grade = Big(card, 78)
  card.grade:SetPoint("TOPLEFT", card, "TOPLEFT", 22, -40)
  card.gradeLabel = Pix(card, 8)
  card.gradeLabel:SetPoint("TOP", card.grade, "BOTTOM", 0, -2)
  card.gradeLabel:SetText("GRADE")
  card.score = Big(card, 34)
  card.score:SetPoint("TOPRIGHT", card, "TOPRIGHT", -18, -42)
  card.scoreLabel = Pix(card, 8)
  card.scoreLabel:SetPoint("TOPRIGHT", card.score, "BOTTOMRIGHT", 0, -1)
  card.scoreLabel:SetText("SCORE")
  card.rows = {}
  local ROWS = { "Hits", "Misses", "Accuracy", "Reaction", "Best combo", "Score", "Best" }
  for i, label in ipairs(ROWS) do
    local col, row = math.mod(i - 1, 2), floor((i - 1) / 2)
    local l = Text(card, 10, nil, .55, .57, .62)
    l:SetPoint("TOPLEFT", card, "TOPLEFT", 108 + col * 104, -96 - row * 16)
    l:SetText(label)
    local v = Text(card, 11, "OUTLINE")
    v:SetPoint("TOPLEFT", card, "TOPLEFT", 166 + col * 104, -96 - row * 16)
    card.rows[i] = v
    if i == 6 then l:Hide() v:Hide() end
  end
  card.again = Button(card, 140, 26, "Play again")
  card.again:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 14, 12)
  card.again:SetScript("OnClick", function() if GetTime() >= (AM.lockUntil or 0) then AM.Begin() end end)
  card.next = Button(card, 140, 26, "Next mode")
  card.next:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -14, 12)
  card.next:SetScript("OnClick", function()
    local cur = S().aimmode
    for i, m in ipairs(AM.MODES) do
      if m.key == cur then
        S().aimmode = AM.MODES[math.mod(i, table.getn(AM.MODES)) + 1].key
        break
      end
    end
    AM.Idle()
  end)
  card:Hide()

  -- targets: a pool of buttons
  AM.pool, AM.live = {}, {}
  local DISC = "Interface\\AddOns\\pfUI\\img\\octo\\disc"
  local function NewTarget()
    local t = CreateFrame("Button", nil, area)
    t:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    t:SetFrameLevel(area:GetFrameLevel() + 3)
    t.halo = t:CreateTexture(nil, "BACKGROUND")
    t.halo:SetTexture(DISC)
    t.halo:SetPoint("CENTER", t, "CENTER", 0, 0)
    t.halo:SetBlendMode("ADD")
    t.ring = t:CreateTexture(nil, "BORDER")
    t.ring:SetTexture(DISC)
    t.ring:SetPoint("CENTER", t, "CENTER", 0, 0)
    t.pic = t:CreateTexture(nil, "ARTWORK")
    t.pic:SetPoint("TOPLEFT", t, "TOPLEFT", 3, -3)
    t.pic:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -3, 3)
    t.cast = CreateFrame("StatusBar", nil, t)
    t.cast:SetPoint("TOPLEFT", t, "BOTTOMLEFT", -6, -4)
    t.cast:SetPoint("TOPRIGHT", t, "BOTTOMRIGHT", 6, -4)
    t.cast:SetHeight(6)
    t.cast:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    t.cast:SetStatusBarColor(1, .7, .1, 1)
    t.cast:SetMinMaxValues(0, 1)
    t.castbg = Tex(t.cast, "BACKGROUND", 0, 0, 0, .8)
    t.castbg:SetPoint("TOPLEFT", t.cast, "TOPLEFT", -1, 1)
    t.castbg:SetPoint("BOTTOMRIGHT", t.cast, "BOTTOMRIGHT", 1, -1)
    t:SetScript("OnClick", function() AM.Hit(this) end)
    return t
  end
  -- floating "+120" / "-50" texts and hit bursts
  AM.pops, AM.bursts = {}, {}
  local function Pop(x, y, text, r, g, b)
    local p
    for _, e in ipairs(AM.pops) do if not e.on then p = e break end end
    if not p then
      p = Big(area, 18)
      table.insert(AM.pops, p)
    end
    p:ClearAllPoints()
    p:SetPoint("CENTER", area, "TOPLEFT", x, -y)
    p:SetText(text)
    p:SetTextColor(r, g, b)
    p.on, p.t0, p.x, p.y = true, GetTime(), x, y
    p:Show()
  end
  local function Burst(x, y, size, r, g, b)
    local e
    for _, o in ipairs(AM.bursts) do if not o.on then e = o break end end
    if not e then
      e = area:CreateTexture(nil, "OVERLAY")
      e:SetTexture(DISC)
      e:SetBlendMode("ADD")
      table.insert(AM.bursts, e)
    end
    e:ClearAllPoints()
    e:SetPoint("CENTER", area, "TOPLEFT", x, -y)
    e:SetVertexColor(r, g, b, 1)
    e.on, e.t0, e.size = true, GetTime(), size
    e:Show()
  end
  local function Callout(text)
    area.call:SetText(text)
    area.call.t0 = GetTime()
    area.call:Show()
  end

  local function Faces()
    local f = AM.FACES[S().aimfaces] or AM.FACES.enemy
    local list = f()
    if not list[1] then list = AM.FACES.spells() end
    return list
  end
  -- a free spot in the area, not on another target
  local function Spot(size)
    local w, h = area:GetWidth() or 516, area:GetHeight() or 260
    local x, y
    for _ = 1, 12 do
      x = random(floor(size / 2) + 8, floor(w - size / 2 - 8))
      y = random(floor(size / 2) + 8, floor(h - size / 2 - 16))
      local free = true
      for _, o in ipairs(AM.live) do
        if (o.x - x) * (o.x - x) + (o.y - y) * (o.y - y) < (size + 10) * (size + 10) then free = false break end
      end
      if free then break end
    end
    return x, y
  end
  local function Place(t, x, y, size)
    t.x, t.y, t.size = x, y, size
    t:SetWidth(size)
    t:SetHeight(size)
    t.ring:SetWidth(size * 1.3)
    t.ring:SetHeight(size * 1.3)
    t.halo:SetWidth(size * 1.9)
    t.halo:SetHeight(size * 1.9)
    t:ClearAllPoints()
    t:SetPoint("CENTER", area, "TOPLEFT", x, -y)
  end
  function AM.Spawn()
    local m = MG.modes[S().aimmode] or MG.modes.gridshot
    local t = table.remove(AM.pool) or NewTarget()
    local size = tonumber(S().aimsize) or 44
    if m.key == "precision" then size = floor(size * .55) end
    if m.key == "tracking" then size = floor(size * 1.1) end
    local x, y = Spot(size)
    Place(t, x, y, size)
    local face = AM.faces[random(1, table.getn(AM.faces))]
    t.pic:SetTexture(face[1])
    if face[2] then t.pic:SetTexCoord(face[2][1], face[2][2], face[2][3], face[2][4]) else t.pic:SetTexCoord(.08, .92, .08, .92) end
    local ar, ag, ab = Accent()
    t.ring:SetVertexColor(ar, ag, ab, .55)
    t.halo:SetVertexColor(ar, ag, ab, .18)
    t.born = GetTime()
    t.base = size
    t.life = (m.key == "reflex") and 1.5 or nil
    if m.key == "kick" then
      t.castTime = 1.6 + random() * 1.6
      t.cast:Show()
    else
      t.castTime = nil
      t.cast:Hide()
    end
    if m.key == "tracking" then
      local a = random() * 6.283
      t.vx, t.vy = math.cos(a) * 120, math.sin(a) * 120
    else
      t.vx, t.vy = nil, nil
    end
    t:SetAlpha(1)
    t:Show()
    table.insert(AM.live, t)
  end
  local function Retire(t)
    for i, o in ipairs(AM.live) do if o == t then table.remove(AM.live, i) break end end
    t:Hide()
    table.insert(AM.pool, t)
  end

  local CALLS = { [5] = "COMBO x5", [10] = "COMBO x10!", [20] = "ON FIRE! x20", [30] = "UNSTOPPABLE x30", [50] = "GODLIKE x50" }
  local function Points()
    return floor(100 * (1 + min(AM.combo, 20) * .05))
  end
  function AM.Hit(t)
    if AM.state ~= "run" then return end
    local m = MG.modes[S().aimmode]
    if m.key == "tracking" then return end
    local now = GetTime()
    -- humanly possible clicks only (20 a second)
    if now - (AM.lastClick or 0) < .05 then return end
    AM.lastClick = now
    AM.hits = AM.hits + 1
    AM.combo = AM.combo + 1
    if AM.combo > AM.bestCombo then AM.bestCombo = AM.combo end
    if CALLS[AM.combo] then Callout(CALLS[AM.combo]) end
    AM.react = AM.react + (now - t.born)
    local pts = Points()
    if m.key == "precision" then
      -- distance of the click from the target's middle
      local cx, cy = GetCursorPosition()
      local s = t:GetEffectiveScale()
      local tx, ty = t:GetCenter()
      if cx and tx then
        local d = sqrt((cx / s - tx) ^ 2 + (cy / s - ty) ^ 2) / (t.size / 2)
        pts = floor(pts * (1.6 - min(1, d)))
        if d < .3 then Callout("BULLSEYE!") end
      end
    elseif m.key == "kick" and t.castTime then
      -- kicked early = more
      local f = (now - t.born) / t.castTime
      pts = floor(pts * (1.5 - f))
      if f < .35 then Callout("INTERRUPTED!") end
    end
    AM.score = AM.score + pts
    Pop(t.x, t.y - t.size / 2 - 8, "+" .. pts, .3, 1, .55)
    Burst(t.x, t.y, t.size, .3, 1, .55)
    Sound("hit")
    Retire(t)
    if m.key ~= "reflex" then AM.Spawn() else AM.gapUntil = now + .25 + random() * .5 end
    AM.PaintHud()
  end
  function AM.Miss(x, y, why)
    if AM.state ~= "run" then return end
    local now = GetTime()
    if not why and now - (AM.lastClick or 0) < .05 then return end
    AM.lastClick = now
    AM.misses = AM.misses + 1
    if AM.combo >= 10 then Callout("COMBO BROKEN") end
    AM.combo = 0
    AM.score = max(0, AM.score - 50)
    if not x then
      local cx, cy = GetCursorPosition()
      local s = area:GetEffectiveScale()
      local left, top = area:GetLeft(), area:GetTop()
      if cx and left then x, y = cx / s - left, top - cy / s end
    end
    if x then
      Pop(x, y, why or "-50", 1, .3, .3)
      Burst(x, y, 20, 1, .25, .25)
    end
    Sound("miss")
    AM.shake = now + .15
    AM.PaintHud()
  end

  function AM.PaintHud()
    local total = tonumber(S().aimtime) or 30
    local left = (AM.state == "run") and max(0, AM.ends - GetTime()) or total
    ap.hud[1]:SetText(string.format("%.1f", left))
    if AM.state == "run" and left < 5 then ap.hud[1]:SetTextColor(1, .3, .3) else ap.hud[1]:SetTextColor(1, 1, 1) end
    ap.hud[2]:SetText(AM.score or 0)
    local shots = (AM.hits or 0) + (AM.misses or 0)
    ap.hud[3]:SetText(shots > 0 and (floor(AM.hits / shots * 100 + .5) .. "%") or "--")
    ap.hud[4]:SetText("x" .. (AM.combo or 0))
    if (AM.combo or 0) >= 10 then ap.hud[4]:SetTextColor(1, .82, .3) else ap.hud[4]:SetTextColor(1, 1, 1) end
    local f = left / total
    ap.timer:SetValue(f)
    local ar, ag, ab = Accent()
    if f > .5 then ap.timer:SetStatusBarColor(ar, ag, ab)
    elseif f > .2 then ap.timer:SetStatusBarColor(1, .7, .2)
    else ap.timer:SetStatusBarColor(1, .25, .25) end
  end
  -- the accent colour on the cabinet's lines (it can change in the options)
  local function PaintCabinet()
    local ar, ag, ab = Accent()
    for _, e in ipairs(area.edge) do e:SetVertexColor(ar, ag, ab, .45) end
    for _, c in ipairs(area.corners) do c:SetVertexColor(ar, ag, ab, 1) end
    for _, v in ipairs(ap.hud) do v.panel.line:SetVertexColor(ar, ag, ab, .8) end
    card.edge:SetVertexColor(ar, ag, ab, .8)
    area.mode:SetTextColor(ar + (1 - ar) * .45, ag + (1 - ag) * .45, ab + (1 - ab) * .45)
  end
  local function Best(key)
    local _, me = Store()
    return me.aim[key]
  end
  function AM.Idle()
    AM.state = "idle"
    for i = table.getn(AM.live), 1, -1 do Retire(AM.live[i]) end
    card:Hide()
    area.count:Hide()
    area.call:Hide()
    PaintCabinet()
    local m = MG.modes[S().aimmode] or MG.modes.gridshot
    local ar, ag, ab = Accent()
    for _, b in ipairs(ap.chips) do
      if b.key == m.key then
        b.locked = true
        b.Paint(ar * .3, ag * .3, ab * .3, 1)
        b.edge:SetVertexColor(ar, ag, ab, 1)
        b.glow:SetVertexColor(ar, ag, ab, 1)
        b.glow:Show()
      else
        b.locked = nil
        b.Paint(.1, .105, .12, 1)
        b.edge:SetVertexColor(.25, .26, .29, 1)
        b.glow:Hide()
      end
    end
    win.sub:SetText(m.name)
    area.mode:SetText(string.upper(m.name))
    area.small:SetText(m.tip .. "  " .. (tonumber(S().aimtime) or 30) .. " s rounds.")
    local b = Best(m.key)
    area.best:SetText(b and string.format("HIGH SCORE  %d   (%d%% accuracy)", b.score or 0, b.acc or 0) or "No high score yet - set one!")
    area.mode:Show() area.small:Show() area.best:Show() area.press:Show()
    AM.score, AM.hits, AM.misses, AM.combo = 0, 0, 0, 0
    AM.PaintHud()
  end
  function AM.Open()
    if AM.state ~= "run" and AM.state ~= "done" and AM.state ~= "count" then AM.Idle() end
    local m = MG.modes[S().aimmode] or MG.modes.gridshot
    win.sub:SetText(m.name)
  end
  -- 3, 2, 1, GO! then the round
  function AM.Begin()
    card:Hide()
    area.mode:Hide() area.small:Hide() area.best:Hide() area.press:Hide()
    AM.state = "count"
    AM.countAt = GetTime()
    AM.countShown = nil
    area.count:Show()
  end
  function AM.Start()
    local m = MG.modes[S().aimmode] or MG.modes.gridshot
    card:Hide()
    area.count:Hide()
    area.mode:Hide() area.small:Hide() area.best:Hide() area.press:Hide()
    for i = table.getn(AM.live), 1, -1 do Retire(AM.live[i]) end
    AM.faces = Faces()
    AM.state = "run"
    AM.score, AM.hits, AM.misses, AM.combo, AM.bestCombo, AM.react = 0, 0, 0, 0, 0, 0
    AM.track, AM.trackAll = 0, 0
    AM.ends = GetTime() + (tonumber(S().aimtime) or 30)
    AM.gapUntil = nil
    AM.last = GetTime()
    for _ = 1, m.n do AM.Spawn() end
    Sound("start")
    AM.PaintHud()
  end
  -- a grade from accuracy (tracking: time on target)
  function AM.Grade(acc, best)
    if acc >= 95 and best then return "S", 1, .82, .3 end
    if acc >= 95 then return "A+", .3, 1, .55 end
    if acc >= 88 then return "A", .3, 1, .55 end
    if acc >= 78 then return "B", .35, .7, 1 end
    if acc >= 65 then return "C", .8, .82, .86 end
    return "D", 1, .35, .35
  end
  function AM.Finish(quiet)
    AM.state = "done"
    AM.lockUntil = GetTime() + 1
    for i = table.getn(AM.live), 1, -1 do Retire(AM.live[i]) end
    area.count:Hide()
    if quiet then AM.Idle() return end
    local key = S().aimmode
    local shots = AM.hits + AM.misses
    local acc = shots > 0 and floor(AM.hits / shots * 100 + .5) or 0
    if key == "tracking" then acc = AM.trackAll > 0 and floor(AM.track / AM.trackAll * 100 + .5) or 0 end
    local react = AM.hits > 0 and floor(AM.react / AM.hits * 1000 + .5) or nil
    local _, me = Store()
    local old = me.aim[key]
    local isBest = (not old or AM.score > (old.score or 0)) and AM.score > 0
    if isBest then
      me.aim[key] = { score = AM.score, acc = acc, t = time() }
      MG.Share(key, AM.score, acc)
      Sound("best")
    end
    card.isBest = isBest
    card.title:SetText(isBest and "NEW HIGH SCORE!" or "ROUND OVER")
    card.title:SetTextColor(1, isBest and .82 or 1, isBest and .3 or 1)
    local g, r, gg, b = AM.Grade(acc, isBest)
    card.grade:SetText(g)
    card.grade:SetTextColor(r, gg, b)
    card.score:SetText(AM.score)
    local vals = { AM.hits, AM.misses, acc .. "%", react and (react .. " ms") or "--", "x" .. AM.bestCombo, AM.score,
                   me.aim[key] and me.aim[key].score or 0 }
    if key == "tracking" then vals[1], vals[2] = floor(AM.track * 10) / 10 .. " s on", floor((AM.trackAll - AM.track) * 10) / 10 .. " s off" end
    for i, v in ipairs(card.rows) do v:SetText(vals[i]) end
    card:Show()
    AM.PaintHud()
    if MG.after then local f = MG.after MG.after = nil f() end
  end

  -- every frame
  ap:SetScript("OnUpdate", function()
    local now = GetTime()
    for _, p in ipairs(AM.pops) do
      if p.on then
        local a = (now - p.t0) / .7
        if a >= 1 then p.on = nil p:Hide()
        else
          p:SetAlpha(1 - a * a)
          p:ClearAllPoints()
          p:SetPoint("CENTER", area, "TOPLEFT", p.x, -(p.y - a * 22))
        end
      end
    end
    for _, e in ipairs(AM.bursts) do
      if e.on then
        local a = (now - e.t0) / .25
        if a >= 1 then e.on = nil e:Hide()
        else
          local s = e.size * (1 + a * 1.2)
          e:SetWidth(s) e:SetHeight(s)
          e:SetAlpha(1 - a)
        end
      end
    end
    if area.call:IsShown() then
      local a = (now - (area.call.t0 or now)) / .9
      if a >= 1 then area.call:Hide() else area.call:SetAlpha(1 - a * a) end
    end
    if card:IsShown() and card.isBest then
      card.title:SetAlpha(.55 + .45 * math.abs(math.sin(now * 5)))
    end
    if AM.state == "idle" or AM.state == "done" then
      area.press:SetAlpha(.35 + .65 * math.abs(math.sin(now * 3)))
    end
    -- the countdown
    if AM.state == "count" then
      local e = now - AM.countAt
      local step = floor(e / .55)
      local words = { "3", "2", "1", "GO!" }
      if step >= 4 then AM.Start() return end
      if AM.countShown ~= step then
        AM.countShown = step
        area.count:SetText(words[step + 1])
        Sound(step == 3 and "start" or "hit")
      end
      local f = (e - step * .55) / .55
      area.count:SetAlpha(1 - f * .6)
      area.count:SetFont(NUM, 72 * (1.5 - f * .5), "OUTLINE")
      if step == 3 then area.count:SetTextColor(.3, 1, .55) else area.count:SetTextColor(1, 1, 1) end
      return
    end
    if AM.state ~= "run" then return end
    local dt = now - (AM.last or now)
    AM.last = now
    if now >= AM.ends then AM.Finish() return end
    -- a short shake of the screen on a miss
    if AM.shake and now < AM.shake then
      area:ClearAllPoints()
      local dx = (random() - .5) * 6
      area:SetPoint("TOPLEFT", ap, "TOPLEFT", dx, -88)
      area:SetPoint("BOTTOMRIGHT", ap, "BOTTOMRIGHT", dx, 0)
    elseif AM.shake then
      AM.shake = nil
      area:ClearAllPoints()
      area:SetPoint("TOPLEFT", ap, "TOPLEFT", 0, -88)
      area:SetPoint("BOTTOMRIGHT", ap, "BOTTOMRIGHT", 0, 0)
    end
    local m = MG.modes[S().aimmode]
    local pulse = .45 + .2 * math.sin(now * 6)
    for i = table.getn(AM.live), 1, -1 do
      local t = AM.live[i]
      local age = now - t.born
      local grow = min(1, age / .12)
      t.halo:SetAlpha(pulse)
      if t.life then
        -- reflex: shrinks to nothing over its life
        local f = 1 - age / t.life
        if f <= 0 then
          AM.Miss(t.x, t.y, "TOO SLOW")
          Retire(t)
          AM.gapUntil = now + .3
        else
          local s = max(4, t.base * f * grow)
          t:SetWidth(s) t:SetHeight(s)
          t.ring:SetWidth(s * 1.3) t.ring:SetHeight(s * 1.3)
          t.halo:SetWidth(s * 1.9) t.halo:SetHeight(s * 1.9)
        end
      elseif t.castTime then
        local f = age / t.castTime
        t.cast:SetValue(min(1, f))
        t.cast:SetStatusBarColor(1, .75 - min(.6, f * .6), .1, 1)
        if f >= 1 then
          AM.Miss(t.x, t.y, "CAST LANDED!")
          Retire(t)
          AM.Spawn()
        end
      elseif t.vx then
        -- tracking: moves, bounces off the edges, turns now and then
        local w, h = area:GetWidth() or 516, area:GetHeight() or 260
        local x, y = t.x + t.vx * dt, t.y + t.vy * dt
        local r = t.size / 2
        if x < r or x > w - r then t.vx = -t.vx x = max(r, min(w - r, x)) end
        if y < r or y > h - r then t.vy = -t.vy y = max(r, min(h - r, y)) end
        if random() < dt * .8 then
          local a = random() * 6.283
          local sp = 100 + random() * 90
          t.vx, t.vy = math.cos(a) * sp, math.sin(a) * sp
        end
        Place(t, x, y, t.size)
        AM.trackAll = AM.trackAll + dt
        if MouseIsOver(t) then
          AM.track = AM.track + dt
          AM.tickAcc = (AM.tickAcc or 0) + dt
          if AM.tickAcc >= .1 then
            AM.tickAcc = AM.tickAcc - .1
            AM.hits = AM.hits + 1
            AM.combo = AM.combo + 1
            if AM.combo > AM.bestCombo then AM.bestCombo = AM.combo end
            if CALLS[AM.combo] then Callout(CALLS[AM.combo]) end
            AM.score = AM.score + floor(10 * (1 + min(AM.combo, 50) * .02))
          end
          t.ring:SetVertexColor(.3, 1, .55, .8)
          t.halo:SetVertexColor(.3, 1, .55, .3)
        else
          if AM.combo > 0 then AM.combo = 0 end
          local ar, ag, ab = Accent()
          t.ring:SetVertexColor(ar, ag, ab, .55)
          t.halo:SetVertexColor(ar, ag, ab, .18)
        end
      elseif grow < 1 then
        local s = t.base * (.4 + .6 * grow)
        t:SetWidth(s) t:SetHeight(s)
      end
    end
    if m.key == "reflex" and not AM.live[1] and AM.gapUntil and now >= AM.gapUntil then
      AM.gapUntil = nil
      AM.Spawn()
    end
    AM.PaintHud()
  end)

  -- ---------------------------------------------------------------- scores and sharing

  -- realms (22 Nov 2026, user: "All scoreboards should show what realm the playername was on. NZ for N'zoth YS for
  -- Y'Shaarj, CT for C'thun"): a short tag per realm, sent with every score. Others: the first two letters.
  MG.REALMS = { nzoth = { "NZ", .72, .48, 1 }, yshaarj = { "YS", .35, .85, .55 }, cthun = { "CT", 1, .6, .25 } }
  function MG.RealmTag(name)
    local k = string.lower(string.gsub(tostring(name or ""), "[^%a]", ""))
    local d = MG.REALMS[k]
    if d then return d[1] end
    if string.len(k) >= 2 then return string.upper(string.sub(k, 1, 2)) end
    return "XX"
  end
  function MG.MyRealm()
    local ok, n = pcall(GetRealmName)
    return MG.RealmTag(ok and type(n) == "string" and n or "")
  end
  function MG.RealmColor(tag)
    for _, d in pairs(MG.REALMS) do if d[1] == tag then return d[2], d[3], d[4] end end
    return .62, .66, .74
  end
  function MG.RealmText(tag)
    local r, g, b = MG.RealmColor(tag)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, tag or "??")
  end

  -- every board: the three quiz runs, the six aim modes, the practice streak
  MG.BOARDS = {}
  for _, d in ipairs(QZ.DIFFS) do
    table.insert(MG.BOARDS, { key = d.board, group = "QUIZ", name = d.name, icon = d.icon, col = d.col, extra = "right", n = d.n,
      desc = d.n .. " questions, " .. d.secs .. " s each, points x" .. d.mult .. ". Faster answers score more." })
  end
  for _, m in ipairs(AM.MODES) do
    table.insert(MG.BOARDS, { key = m.key, group = "AIM TRAINER", name = m.name, icon = m.icon, extra = "acc", desc = m.tip })
  end
  table.insert(MG.BOARDS, { key = "quiz", group = "PRACTICE", name = "Quiz streak", icon = "INV_Misc_Book_09",
    desc = "Most right answers in a row in practice." })
  MG.BOARD = {}
  for _, b in ipairs(MG.BOARDS) do MG.BOARD[b.key] = b end

  -- your own best on a board: score, extra (right answers / accuracy)
  function MG.MyBest(key)
    local _, me = Store()
    if key == "quiz" then return me.quiz.best, nil end
    for _, d in ipairs(QZ.DIFFS) do
      if d.board == key then
        local r = me.quiz.runs[d.key]
        if r then return r.score, r.right end
        return
      end
    end
    local a = me.aim[key]
    if a then return a.score, a.acc end
  end
  -- a board's rows, best first: { name, realm, v, acc, you }. Entries kept before realms were (by name alone) were heard
  -- on your own realm.
  function MG.Rows(key)
    local s, _, myName = Store()
    local mine = MG.MyRealm()
    local rows = {}
    for id, e in pairs(s.board[key] or {}) do
      if type(e) == "table" and tonumber(e.v) then
        table.insert(rows, { name = e.n or id, realm = e.r or mine, v = tonumber(e.v), acc = e.acc })
      end
    end
    local v, acc = MG.MyBest(key)
    if v and v > 0 then table.insert(rows, { name = myName, realm = mine, v = v, acc = acc, you = true }) end
    table.sort(rows, function(a, b)
      if a.v ~= b.v then return a.v > b.v end
      return (a.name or "") < (b.name or "")
    end)
    return rows
  end
  function MG.Entry(key, name, realm)
    local s = Store()
    local b = s.board[key]
    if not b then return end
    return b[name .. "-" .. (realm or MG.MyRealm())] or b[name]
  end

  -- a scoreboard table: # / player / realm / score [/ right or accuracy]; `nrows` rows of 18 px. When you are below the
  -- rows shown, the last row is you with your real place.
  local MEDAL = { { 1, .82, .3 }, { .8, .84, .9 }, { .85, .55, .3 } }
  function MG.NewTable(parent, nrows, w, extra)
    local t = CreateFrame("Frame", nil, parent)
    t:SetWidth(w)
    t:SetHeight(18 + nrows * 18)
    local scoreR = extra and (w - 58) or (w - 8)
    local realmX = scoreR - 64 - 28
    t.cols = {}
    local function Head(label, x, right)
      local h = Pix(t, 7)
      if right then h:SetPoint("TOPRIGHT", t, "TOPLEFT", x, -5) else h:SetPoint("TOPLEFT", t, "TOPLEFT", x, -5) end
      h:SetText(label)
      return h
    end
    Head("#", 8)
    Head("PLAYER", 34)
    Head("REALM", realmX)
    Head("SCORE", scoreR, true)
    if extra then t.extraHead = Head("RIGHT", w - 8, true) end
    t.rule = Tex(t, "ARTWORK", 1, 1, 1, .1)
    t.rule:SetHeight(1)
    t.rule:SetPoint("TOPLEFT", t, "TOPLEFT", 0, -17)
    t.rule:SetPoint("TOPRIGHT", t, "TOPRIGHT", 0, -17)
    t.rows = {}
    for i = 1, nrows do
      local r = CreateFrame("Frame", nil, t)
      r:SetHeight(18)
      r:SetPoint("TOPLEFT", t, "TOPLEFT", 0, -18 - (i - 1) * 18)
      r:SetPoint("TOPRIGHT", t, "TOPRIGHT", 0, -18 - (i - 1) * 18)
      r.bg = Tex(r, "BACKGROUND", 1, 1, 1, math.mod(i, 2) == 0 and .03 or 0)
      r.bg:SetAllPoints(r)
      r.you = Tex(r, "BORDER", 1, 1, 1, .14)
      r.you:SetAllPoints(r)
      r.mark = Tex(r, "ARTWORK", 1, 1, 1, 1)
      r.mark:SetWidth(2)
      r.mark:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
      r.mark:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
      r.rank = Big(r, 15)
      r.rank:SetPoint("LEFT", r, "LEFT", 7, 0)
      r.name = Text(r, 11)
      r.name:SetPoint("LEFT", r, "LEFT", 34, 0)
      r.name:SetWidth(realmX - 40)
      r.name:SetJustifyH("LEFT")
      r.pill = Tex(r, "ARTWORK", 1, 1, 1, .2)
      r.pill:SetWidth(24)
      r.pill:SetHeight(13)
      r.pill:SetPoint("LEFT", r, "LEFT", realmX, 0)
      r.tag = Pix(r, 7, 1, 1, 1)
      r.tag:SetPoint("CENTER", r.pill, "CENTER", 0, 0)
      r.score = Big(r, 15)
      r.score:SetPoint("RIGHT", r, "LEFT", scoreR, 0)
      r.score:SetJustifyH("RIGHT")
      r.extra = Text(r, 10, nil, .6, .63, .68)
      r.extra:SetPoint("RIGHT", r, "RIGHT", -8, 0)
      r.extra:SetJustifyH("RIGHT")
      if not extra then r.extra:Hide() end
      t.rows[i] = r
    end
    t.empty = Text(t, 11, nil, .45, .48, .55)
    t.empty:SetPoint("TOP", t, "TOP", 0, -44)
    -- rows from MG.Rows, board from MG.BOARD (for the extra column)
    function t.Fill(rows, board)
      local ar, ag, ab = Accent()
      if t.extraHead then t.extraHead:SetText(board and board.extra == "acc" and "ACC" or "RIGHT") end
      local youAt
      for n, row in ipairs(rows) do if row.you then youAt = n break end end
      local shown = table.getn(t.rows)
      for i, r in ipairs(t.rows) do
        local n = i
        if i == shown and youAt and youAt > shown then n = youAt end
        local row = rows[n]
        if not row then r:Hide() else
          r:Show()
          local m = MEDAL[n]
          r.rank:SetText(n)
          if m then r.rank:SetTextColor(m[1], m[2], m[3]) else r.rank:SetTextColor(.55, .57, .62) end
          r.name:SetText(row.name)
          if row.you then r.name:SetTextColor(1, 1, 1) else r.name:SetTextColor(.86, .87, .9) end
          local cr, cg, cb = MG.RealmColor(row.realm)
          r.pill:SetVertexColor(cr, cg, cb, .22)
          r.tag:SetText(row.realm or "??")
          r.tag:SetTextColor(cr, cg, cb)
          r.score:SetText(row.v)
          if m then r.score:SetTextColor(m[1], m[2], m[3]) else r.score:SetTextColor(1, 1, 1) end
          local ex = ""
          if row.acc and board then
            if board.extra == "right" then ex = row.acc .. "/" .. (board.n or "?")
            elseif board.extra == "acc" and row.acc > 0 then ex = row.acc .. "%" end
          end
          r.extra:SetText(ex)
          if row.you then
            r.you:SetVertexColor(ar, ag, ab, .16) r.you:Show()
            r.mark:SetVertexColor(ar, ag, ab, 1) r.mark:Show()
          else
            r.you:Hide() r.mark:Hide()
          end
        end
      end
      if rows[1] then t.empty:SetText("") else t.empty:SetText("No scores yet - set the first one!") end
    end
    return t
  end

  -- the Scores tab: boards down the left, the picked one as a table on the right
  local bp = MG.pages.board
  bp.list = {}
  do
    local y, group = 0, nil
    for _, b in ipairs(MG.BOARDS) do
      if b.group ~= group then
        group = b.group
        local h = Pix(bp, 7, .5, .52, .58)
        h:SetPoint("TOPLEFT", bp, "TOPLEFT", 2, -y - (y > 0 and 6 or 0))
        h:SetText(group)
        y = y + (y > 0 and 6 or 0) + 13
      end
      local e = Button(bp, 150, 22, "")
      e:SetPoint("TOPLEFT", bp, "TOPLEFT", 0, -y)
      e.icon = e:CreateTexture(nil, "OVERLAY")
      e.icon:SetWidth(16) e.icon:SetHeight(16)
      e.icon:SetPoint("LEFT", e, "LEFT", 6, 0)
      e.icon:SetTexture(ICON .. b.icon)
      e.icon:SetTexCoord(.08, .92, .08, .92)
      e.text:ClearAllPoints()
      e.text:SetPoint("LEFT", e.icon, "RIGHT", 7, 0)
      e.text:SetFont(Font(), 11, "")
      e.text:SetText(b.name)
      e.bar = Tex(e, "OVERLAY")
      e.bar:SetWidth(2)
      e.bar:SetPoint("TOPLEFT", e, "TOPLEFT", 0, 0)
      e.bar:SetPoint("BOTTOMLEFT", e, "BOTTOMLEFT", 0, 0)
      e.key = b.key
      e:SetScript("OnClick", function() MG.boardSel = this.key MG.Board() Sound("hit") end)
      table.insert(bp.list, e)
      y = y + 24
    end
  end
  bp.right = CreateFrame("Frame", nil, bp)
  bp.right:SetPoint("TOPLEFT", bp, "TOPLEFT", 162, 0)
  bp.right:SetPoint("BOTTOMRIGHT", bp, "BOTTOMRIGHT", 0, 0)
  bp.right.bg = Tex(bp.right, "BACKGROUND", .065, .07, .085, 1)
  bp.right.bg:SetAllPoints(bp.right)
  bp.line = Tex(bp.right, "ARTWORK")
  bp.line:SetHeight(3)
  bp.line:SetPoint("TOPLEFT", bp.right, "TOPLEFT", 0, 0)
  bp.line:SetPoint("TOPRIGHT", bp.right, "TOPRIGHT", 0, 0)
  bp.icon = bp.right:CreateTexture(nil, "OVERLAY")
  bp.icon:SetWidth(30) bp.icon:SetHeight(30)
  bp.icon:SetPoint("TOPLEFT", bp.right, "TOPLEFT", 10, -11)
  bp.icon:SetTexCoord(.08, .92, .08, .92)
  bp.name = Big(bp.right, 26)
  bp.name:SetPoint("TOPLEFT", bp.icon, "TOPRIGHT", 9, 3)
  bp.desc = Text(bp.right, 10, nil, .6, .62, .68)
  bp.desc:SetPoint("TOPLEFT", bp.name, "BOTTOMLEFT", 0, -1)
  bp.desc:SetWidth(296)
  bp.desc:SetJustifyH("LEFT")
  bp.table = MG.NewTable(bp.right, 13, 334, true)
  bp.table:SetPoint("TOPLEFT", bp.right, "TOPLEFT", 10, -50)
  bp.foot = Pix(bp.right, 7, .45, .48, .55)
  bp.foot:SetPoint("BOTTOM", bp.right, "BOTTOM", 0, 7)
  function MG.Board()
    win.sub:SetText("leaderboards - guild, groups, battlegrounds and the realm")
    local sel = MG.BOARD[MG.boardSel or ""] and MG.boardSel or MG.BOARDS[1].key
    MG.boardSel = sel
    local b = MG.BOARD[sel]
    local ar, ag, ab = Accent()
    local cr, cg, cb = ar, ag, ab
    if b.col then cr, cg, cb = b.col[1], b.col[2], b.col[3] end
    for _, e in ipairs(bp.list) do
      local o = MG.BOARD[e.key]
      local r, g, bl = ar, ag, ab
      if o.col then r, g, bl = o.col[1], o.col[2], o.col[3] end
      if e.key == sel then
        e.locked = true
        e.Paint(r * .3, g * .3, bl * .3, 1)
        e.edge:SetVertexColor(r, g, bl, 1)
        e.bar:SetVertexColor(r, g, bl, 1)
        e.bar:Show()
      else
        e.locked = nil
        e.Paint(.1, .105, .12, 1)
        e.edge:SetVertexColor(.25, .26, .29, 1)
        e.bar:Hide()
      end
    end
    bp.line:SetVertexColor(cr, cg, cb, 1)
    bp.icon:SetTexture(ICON .. b.icon)
    bp.name:SetText(string.upper(b.name) .. (b.group == "QUIZ" and " QUIZ" or ""))
    bp.name:SetTextColor(cr + (1 - cr) * .25, cg + (1 - cg) * .25, cb + (1 - cb) * .25)
    bp.desc:SetText(b.desc or "")
    local rows = MG.Rows(sel)
    bp.table.Fill(rows, b)
    local n = table.getn(rows)
    bp.foot:SetText(n == 1 and "1 PLAYER ON THIS BOARD" or (n .. " PLAYERS ON THIS BOARD"))
  end
  -- a new best goes to guild / group; others' are kept (never "|" in an addon message). The realm tag rides last.
  function MG.Share(key, v, acc)
    if S().share ~= "1" or not SendAddonMessage then return end
    local msg = "B^" .. key .. "^" .. floor(v) .. "^" .. floor(acc or 0) .. "^" .. MG.MyRealm()
    for _, chan in ipairs(MG.Channels and MG.Channels() or { "GUILD" }) do pcall(SendAddonMessage, PREFIX, msg, chan) end
  end
  -- "B^mode^score^acc[^RT]" = the sender's own best; "R^mode^name^score^acc[^RT]" = a best they heard from someone else.
  -- No tag (pfUI Octo before 1.2.18): the sender's realm, i.e. ours.
  function MG.Receive(msg, from)
    if not from then return end
    local _, _, short = string.find(from, "^([^%-]+)")
    from = short or from
    local _, _, key, v, acc, realm = string.find(msg or "", "^B%^(%a+)%^(%d+)%^(%d+)%^?(%u*)$")
    if key then
      MG.Keep(key, from, v, acc, realm ~= "" and realm or nil)
    else
      local who
      _, _, key, who, v, acc, realm = string.find(msg or "", "^R%^(%a+)%^([^%^]+)%^(%d+)%^(%d+)%^?(%u*)$")
      if not key then return end
      MG.Keep(key, who, v, acc, realm ~= "" and realm or nil)
    end
    if win:IsShown() and MG.cur == "board" then MG.Board() end
  end

  -- ---------------------------------------------------------------- on flights

  -- the launcher while you fly (22 Nov 2026, user: the first one "looks rubbish make it look inviting and arcadish give
  -- it some artwork and wording"): an arcade marquee - a glowing OCTOARCADE sign between two Darkmoon tickets with a light
  -- sweeping across it, a blinking INSERT COIN line, and three game cards (icon with a pulsing halo, name, what is in
  -- it / your best). It slides in, can be dragged (its place is kept: S().lx / ly) and closes with the x or on landing.
  local L_W, L_H = 330, 116
  local launch = CreateFrame("Frame", "pfOctoArcadeLauncher", UIParent)
  MG.launcher = launch
  launch:SetWidth(L_W)
  launch:SetHeight(L_H)
  launch:SetFrameStrata("HIGH")
  launch:SetClampedToScreen(true)
  launch:SetMovable(true)
  launch:EnableMouse(true)
  launch:RegisterForDrag("LeftButton")
  launch:SetScript("OnDragStart", function() this:StartMoving() end)
  launch:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local x, y = this:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if x and ux then S().lx, S().ly = floor(x - ux + .5), floor(y - uy + .5) end
  end)
  launch:Hide()
  launch.bg = Tex(launch, "BACKGROUND", .03, .04, .07, .94)
  launch.bg:SetAllPoints(launch)
  launch.shade = Tex(launch, "BORDER", 0, 0, 0, 1)
  launch.shade:SetAllPoints(launch)
  if launch.shade.SetGradientAlpha then launch.shade:SetGradientAlpha("VERTICAL", 0, 0, 0, .5, 0, 0, 0, 0) end
  launch.edges = {}
  for i, pt in ipairs({ { "TOPLEFT", "TOPRIGHT", 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 1 }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
    local e = Tex(launch, "ARTWORK")
    if pt[3] then e:SetHeight(1) else e:SetWidth(1) end
    e:SetPoint(pt[1], launch, pt[1], 0, 0)
    e:SetPoint(pt[2], launch, pt[2], 0, 0)
    launch.edges[i] = e
  end
  launch.corners = {}
  for _, c in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
    local h = Tex(launch, "OVERLAY") h:SetWidth(14) h:SetHeight(2) h:SetPoint(c, launch, c, 0, 0)
    local v = Tex(launch, "OVERLAY") v:SetWidth(2) v:SetHeight(14) v:SetPoint(c, launch, c, 0, 0)
    table.insert(launch.corners, h) table.insert(launch.corners, v)
  end
  -- the marquee: a lit strip, the name, a ticket each side, a sweep of light
  local marquee = CreateFrame("Frame", nil, launch)
  marquee:SetPoint("TOPLEFT", launch, "TOPLEFT", 1, -1)
  marquee:SetPoint("TOPRIGHT", launch, "TOPRIGHT", -1, -1)
  marquee:SetHeight(30)
  marquee.glow = Tex(marquee, "BACKGROUND")
  marquee.glow:SetAllPoints(marquee)
  marquee.line = Tex(marquee, "ARTWORK")
  marquee.line:SetHeight(1)
  marquee.line:SetPoint("BOTTOMLEFT", marquee, "BOTTOMLEFT", 0, 0)
  marquee.line:SetPoint("BOTTOMRIGHT", marquee, "BOTTOMRIGHT", 0, 0)
  marquee.title = Big(marquee, 24)
  marquee.title:SetPoint("CENTER", marquee, "CENTER", 0, 0)
  marquee.title:SetText("OCTO ARCADE")
  for i, side in ipairs({ "LEFT", "RIGHT" }) do
    local t = marquee:CreateTexture(nil, "OVERLAY")
    t:SetWidth(20) t:SetHeight(20)
    t:SetTexture(ICON .. "INV_Misc_Ticket_Darkmoon_01")
    t:SetTexCoord(.08, .92, .08, .92)
    t:SetPoint(side == "LEFT" and "RIGHT" or "LEFT", marquee.title, side, side == "LEFT" and -10 or 10, 0)
    marquee["ticket" .. i] = t
  end
  -- little bulbs along the bottom of the sign
  marquee.bulbs = {}
  for i = 1, 20 do
    local b = Tex(marquee, "OVERLAY")
    b:SetWidth(3) b:SetHeight(3)
    b:SetPoint("BOTTOMLEFT", marquee, "BOTTOMLEFT", 8 + (i - 1) * 16.2, 3)
    marquee.bulbs[i] = b
  end
  -- (22 Nov 2026, user: the sweep "leaves the end of the frame ... make this glow abit better") a tapered beam: a soft
  -- wide bloom plus a bright core, each two halves fading in and out, clipped to the sign every frame (a cut half keeps
  -- the right fade by setting its end alphas from where it was cut)
  marquee.beams = {}
  for i = 1, 4 do
    local t = marquee:CreateTexture(nil, "OVERLAY")
    t:SetTexture(WHITE)
    t:SetBlendMode("ADD")
    t:SetPoint("TOP", marquee, "TOP", 0, -1)
    t:SetPoint("BOTTOM", marquee, "BOTTOM", 0, 1)
    t:Hide()
    marquee.beams[i] = t
  end
  -- { half width, peak alpha } for the bloom and the core
  marquee.BEAM = { { 46, .12 }, { 16, .32 } }
  launch.marquee = marquee
  launch.coin = Pix(launch, 8, 1, .82, .3)
  launch.coin:SetPoint("TOP", marquee, "BOTTOM", 0, -6)
  launch.coin:SetText("INSERT COIN  -  PICK A GAME FOR THE FLIGHT")

  -- the three cards
  launch.cards = {}
  local CARDS = {
    { key = "quiz", name = "QUIZ", icon = "INV_Misc_Book_09", tip = "Normal, Heroic and Mythic runs against the clock - faster answers score more." },
    { key = "aim", name = "AIM TRAINER", icon = "Ability_Marksmanship", tip = "Six modes from Gridshot to Kick! - how fast are your hands?" },
    { key = "board", name = "HIGH SCORES", icon = "INV_Misc_Note_06", tip = "Your bests, your guild's and the realm's." },
  }
  local CW, CH = 100, 60
  for i, d in ipairs(CARDS) do
    local c = CreateFrame("Button", nil, launch)
    c:SetWidth(CW) c:SetHeight(CH)
    c:SetPoint("TOPLEFT", launch, "TOPLEFT", 8 + (i - 1) * (CW + 7), -48)
    c.bg = Tex(c, "BACKGROUND", .07, .08, .11, 1)
    c.bg:SetAllPoints(c)
    c.edge = Tex(c, "BORDER", .22, .23, .27, 1)
    c.edge:SetPoint("TOPLEFT", c, "TOPLEFT", -1, 1)
    c.edge:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 1, -1)
    c.bg:SetDrawLayer("ARTWORK")
    c.halo = c:CreateTexture(nil, "ARTWORK")
    c.halo:SetTexture("Interface\\AddOns\\pfUI\\img\\octo\\disc")
    c.halo:SetBlendMode("ADD")
    c.halo:SetWidth(40) c.halo:SetHeight(40)
    c.halo:SetPoint("TOP", c, "TOP", 0, 2)
    c.icon = c:CreateTexture(nil, "OVERLAY")
    c.icon:SetWidth(24) c.icon:SetHeight(24)
    c.icon:SetPoint("CENTER", c.halo, "CENTER", 0, 0)
    c.icon:SetTexture(ICON .. d.icon)
    c.icon:SetTexCoord(.08, .92, .08, .92)
    c.name = Big(c, 14)
    c.name:SetPoint("TOP", c.icon, "BOTTOM", 0, -3)
    c.name:SetText(d.name)
    c.sub = Pix(c, 7)
    c.sub:SetPoint("TOP", c.name, "BOTTOM", 0, -2)
    c.key, c.tip, c.title = d.key, d.tip, d.name
    c:SetScript("OnClick", function()
      Sound("start")
      launch:Hide()
      MG.Show(this.key)
    end)
    c:SetScript("OnEnter", function()
      this.hover = true
      local ar, ag, ab = Accent()
      this.edge:SetVertexColor(ar, ag, ab, 1)
      this.bg:SetVertexColor(ar * .22, ag * .22, ab * .22, 1)
      GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
      GameTooltip:SetText(this.title, 1, 1, 1)
      GameTooltip:AddLine(this.tip, .8, .82, .86, 1)
      GameTooltip:AddLine("Click to play", .3, 1, .55)
      GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function()
      this.hover = nil
      this.edge:SetVertexColor(.22, .23, .27, 1)
      this.bg:SetVertexColor(.07, .08, .11, 1)
      GameTooltip:Hide()
    end)
    launch.cards[i] = c
  end
  -- not now
  local closeL = CreateFrame("Button", nil, launch)
  closeL:SetWidth(16) closeL:SetHeight(16)
  closeL:SetPoint("TOPRIGHT", launch, "TOPRIGHT", -5, -7)
  closeL.t = Pix(closeL, 10, .7, .72, .76)
  closeL.t:SetAllPoints(closeL)
  closeL.t:SetText("X")
  closeL:SetScript("OnClick", function() launch:Hide() end)
  closeL:SetScript("OnEnter", function()
    this.t:SetTextColor(1, .35, .35)
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Not now", 1, 1, 1)
    GameTooltip:AddLine("Comes back on your next flight. /arcade opens it any time.", .8, .82, .86, 1)
    GameTooltip:Show()
  end)
  closeL:SetScript("OnLeave", function() this.t:SetTextColor(.7, .72, .76) GameTooltip:Hide() end)

  -- what each card says under its name: the bank size, the modes and your best, your top score
  function MG.PaintLauncher()
    local ar, ag, ab = Accent()
    for _, e in ipairs(launch.edges) do e:SetVertexColor(ar, ag, ab, .55) end
    for _, c in ipairs(launch.corners) do c:SetVertexColor(ar, ag, ab, 1) end
    marquee.glow:SetVertexColor(ar, ag, ab, 1)
    if marquee.glow.SetGradientAlpha then marquee.glow:SetGradientAlpha("VERTICAL", ar, ag, ab, .05, ar, ag, ab, .35) end
    marquee.line:SetVertexColor(ar, ag, ab, .8)
    marquee.title:SetTextColor(ar + (1 - ar) * .55, ag + (1 - ag) * .55, ab + (1 - ab) * .55)
    for _, c in ipairs(launch.cards) do c.halo:SetVertexColor(ar, ag, ab, .3) end
    local _, me = Store()
    local bestAim, bestMode = 0, nil
    for key, r in pairs(me.aim) do if (r.score or 0) > bestAim then bestAim, bestMode = r.score, key end end
    launch.cards[1].sub:SetText((me.quiz.best or 0) > 0 and ("BEST STREAK " .. me.quiz.best) or (table.getn(DATA.quiz) .. " QUESTIONS"))
    launch.cards[2].sub:SetText(bestAim > 0 and ("BEST " .. bestAim) or (table.getn(AM.MODES) .. " MODES"))
    local s = Store()
    local n = 0
    for _, list in pairs(s.board) do for _ in pairs(list) do n = n + 1 end end
    launch.cards[3].sub:SetText(n > 0 and (n .. " SCORES") or "BE THE FIRST")
  end
  -- the beam at f (0 = left of the sign .. 1 = right of it, beyond 1 = resting); every part kept inside the sign
  function MG.PaintSweep(f)
    local w = marquee:GetWidth() or (L_W - 2)
    local beams = marquee.beams
    if f > 1 then
      for _, t in ipairs(beams) do t:Hide() end
      marquee.title:SetAlpha(1)
      return
    end
    local reach = marquee.BEAM[1][1]
    local cx = -reach + f * (w + 2 * reach)
    local n = 0
    for _, layer in ipairs(marquee.BEAM) do
      local h, peak = layer[1], layer[2]
      for side = 1, 2 do
        n = n + 1
        local t = beams[n]
        local x0, x1 = cx - h, cx
        local a0, a1 = 0, peak
        if side == 2 then x0, x1, a0, a1 = cx, cx + h, peak, 0 end
        local c0, c1 = max(0, x0), min(w, x1)
        if c1 - c0 < .5 then
          t:Hide()
        else
          local function At(c) return a0 + (a1 - a0) * (c - x0) / (x1 - x0) end
          t:ClearAllPoints()
          t:SetPoint("TOP", marquee, "TOP", 0, -1)
          t:SetPoint("BOTTOM", marquee, "BOTTOM", 0, 1)
          t:SetPoint("LEFT", marquee, "LEFT", c0, 0)
          t:SetWidth(c1 - c0)
          if t.SetGradientAlpha then t:SetGradientAlpha("HORIZONTAL", 1, .96, .86, At(c0), 1, .96, .86, At(c1)) end
          t:Show()
        end
      end
    end
    -- the letters catch the light as it passes them
    local k = max(0, 1 - math.abs(cx - w / 2) / 110)
    local ar, ag, ab = Accent()
    local base = .55 + .45 * k
    marquee.title:SetTextColor(ar + (1 - ar) * base, ag + (1 - ag) * base, ab + (1 - ab) * base)
    marquee.title:SetAlpha(1)
  end
  launch:SetScript("OnShow", function()
    MG.PaintLauncher()
    this:ClearAllPoints()
    local x, y = S().lx, S().ly
    this.home = { x or 0, y or (UIParent:GetHeight() / 2 - 130 - L_H / 2) }
    this.t0 = GetTime()
    this:SetAlpha(0)
    this:SetPoint("CENTER", UIParent, "CENTER", this.home[1], this.home[2] + 30)
  end)
  launch:SetScript("OnUpdate", function()
    local now = GetTime()
    -- slide in over .35 s
    if this.t0 then
      local a = min(1, (now - this.t0) / .35)
      local ease = 1 - (1 - a) * (1 - a)
      this:SetAlpha(ease)
      this:ClearAllPoints()
      this:SetPoint("CENTER", UIParent, "CENTER", this.home[1], this.home[2] + 30 * (1 - ease))
      if a >= 1 then this.t0 = nil end
    end
    -- the coin line blinks, the light sweeps the sign every 3 s, the bulbs chase
    launch.coin:SetAlpha(.4 + .6 * math.abs(math.sin(now * 2.6)))
    MG.PaintSweep(math.mod(now, 3) / 1.4)
    local lit = floor(now * 8)
    local ar, ag, ab = Accent()
    for i, b in ipairs(marquee.bulbs) do
      if math.mod(i + lit, 3) == 0 then b:SetVertexColor(1, .9, .5, 1) else b:SetVertexColor(ar, ag, ab, .35) end
    end
    -- the cards' halos breathe; a hovered card's icon grows
    local p = .22 + .14 * math.sin(now * 3)
    for _, c in ipairs(launch.cards) do
      c.halo:SetAlpha(c.hover and .9 or p / .3)
      local s = c.hover and 28 or 24
      c.icon:SetWidth(s) c.icon:SetHeight(s)
    end
  end)

  function MG.FlightStart()
    local how = S().onflight
    if how == "off" or not MG.On() then return end
    MG.openedForFlight = true
    if how == "pick" then launch:Show() else MG.Show(how) end
  end
  function MG.FlightEnd()
    launch:Hide()
    if not MG.openedForFlight or S().closeland ~= "1" then return end
    MG.openedForFlight = nil
    -- a running round finishes first
    if AM.state == "count" then AM.Finish(true) end
    if AM.state == "run" then MG.after = function() win:Hide() end return end
    if QZ.run and QZ.view == "run" and QZ.run.state ~= "done" then MG.after = function() win:Hide() end return end
    win:Hide()
  end
  local watch = CreateFrame("Frame")
  watch:SetScript("OnUpdate", function()
    if (this.next or 0) > GetTime() then return end
    this.next = GetTime() + .5
    local flying = UnitOnTaxi and UnitOnTaxi("player") and true or false
    if flying ~= (MG.flying or false) then
      MG.flying = flying
      if flying then MG.FlightStart() else MG.FlightEnd() end
    end
  end)
  -- ---------------------------------------------------------------- scores across players
  -- (22 Nov 2026, user: "Could we make the highscores shared over users?") Addon messages reach only guild, party,
  -- raid and battleground, so the board spreads player to player: at login and when a group forms we ask ("Q"); each
  -- player answers a moment later (1-5 s, so a guild does not answer at once, and once a minute per channel) with
  -- their own bests ("B^...") and the top 5 of each board they know ("R^mode^name^score^acc"). Others' scores are
  -- never passed on unasked. Sends go out one every .3 s.
  local outq, answered, askedAt = {}, {}, {}
  function MG.Queue(chan, msg) table.insert(outq, { chan, msg }) end
  function MG.Channels()
    local out = {}
    if IsInGuild and IsInGuild() then table.insert(out, "GUILD") end
    if GetNumRaidMembers() > 0 then table.insert(out, "RAID")
    elseif GetNumPartyMembers() > 0 then table.insert(out, "PARTY") end
    if GetBattlefieldStatus then
      for i = 1, (MAX_BATTLEFIELD_QUEUES or 3) do
        local ok, st = pcall(GetBattlefieldStatus, i)
        if ok and st == "active" then table.insert(out, "BATTLEGROUND") break end
      end
    end
    return out
  end
  function MG.Ask(chan)
    if S().share ~= "1" or not SendAddonMessage then return end
    if GetTime() - (askedAt[chan] or -100) < 60 then return end
    askedAt[chan] = GetTime()
    MG.Queue(chan, "Q")
  end
  -- what we tell a channel that asked: our bests, then the best others we know (each with its realm tag)
  function MG.Answer(chan)
    if S().share ~= "1" then return end
    if GetTime() - (answered[chan] or -100) < 60 then return end
    answered[chan] = GetTime()
    local s = Store()
    local tag = MG.MyRealm()
    for _, b in ipairs(MG.BOARDS) do
      local v, acc = MG.MyBest(b.key)
      if v and v > 0 then MG.Queue(chan, "B^" .. b.key .. "^" .. floor(v) .. "^" .. floor(acc or 0) .. "^" .. tag) end
    end
    for key in pairs(s.board) do
      if MG.BOARD[key] then
        local n = 0
        for _, r in ipairs(MG.Rows(key)) do
          if not r.you then
            n = n + 1
            if n > 5 then break end
            MG.Queue(chan, "R^" .. key .. "^" .. r.name .. "^" .. floor(r.v) .. "^" .. floor(r.acc or 0) .. "^" .. r.realm)
          end
        end
      end
    end
  end
  -- keeps a player's score when it is their best we know of; at most 50 players a board. Kept as "Name-RT" (the same
  -- name can be on two realms); realm nil = ours.
  function MG.Keep(key, name, v, acc, realm)
    if not key or not name or not MG.BOARD[key] then return end
    if not string.find(name, "^[%a\128-\255][%a\128-\255]+$") then return end
    if realm and not string.find(realm, "^%u%u%u?$") then return end
    local s, _, myName = Store()
    local mine = MG.MyRealm()
    realm = realm or mine
    if name == myName and realm == mine then return end
    v = tonumber(v)
    if not v then return end
    s.board[key] = s.board[key] or {}
    local board = s.board[key]
    local id = name .. "-" .. realm
    -- an entry from before realms were kept (by name alone) was heard on this realm
    local legacy = board[name]
    if realm == mine and legacy and not legacy.n then
      board[name] = nil
      if not board[id] then board[id] = { v = legacy.v, acc = legacy.acc, t = legacy.t, n = name, r = realm } end
    end
    local old = board[id]
    if old and v <= (tonumber(old.v) or 0) then return end
    board[id] = { v = v, acc = tonumber(acc), t = time(), n = name, r = realm }
    local n, low, lowName = 0, nil, nil
    for nm, e in pairs(board) do
      n = n + 1
      if not low or (tonumber(e.v) or 0) < low then low, lowName = tonumber(e.v) or 0, nm end
    end
    if n > 50 and lowName then board[lowName] = nil end
  end
  local ev = CreateFrame("Frame")
  local sendTick = CreateFrame("Frame")
  sendTick:SetScript("OnUpdate", function()
    if not outq[1] or (this.next or 0) > GetTime() then return end
    this.next = GetTime() + .3
    local e = table.remove(outq, 1)
    if SendAddonMessage then pcall(SendAddonMessage, PREFIX, e[2], e[1]) end
  end)
  local pending = {}
  local askFrame = CreateFrame("Frame")
  askFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    for chan, at in pairs(pending) do
      if now >= at then pending[chan] = nil MG.Answer(chan) end
    end
  end)
  MG.testFrames = { askFrame, sendTick }
  function MG.Asked(chan)
    if chan and not pending[chan] then pending[chan] = GetTime() + 1 + random() * 4 end
  end
  ev:RegisterEvent("CHAT_MSG_ADDON")
  ev:RegisterEvent("PLAYER_REGEN_DISABLED")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("PARTY_MEMBERS_CHANGED")
  ev:RegisterEvent("RAID_ROSTER_UPDATE")
  ev:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
      if arg1 == PREFIX and arg4 ~= UnitName("player") then
        if arg2 == "Q" then MG.Asked(arg3) else MG.Receive(arg2, arg4) end
      end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
      -- ask where we can hear others (once a minute per channel at most)
      for _, chan in ipairs(MG.Channels()) do MG.Ask(chan) end
    elseif event == "PLAYER_REGEN_DISABLED" then
      -- combat: the games go away
      if win:IsShown() then MG.Close() end
      launch:Hide()
    end
  end)

  -- ---------------------------------------------------------------- the realm channel
  -- (22 Nov 2026, user: "share scores over a chat channel people have with the pfui ... log into a realm and share the
  -- new scores ... sent only once when logged in and received lightweight") 1.12's SendAddonMessage cannot go to a chat
  -- channel, so pfUI joins a hidden custom channel (MG.CHANNEL) and says ONE line per login, ~20 s after entering the
  -- world: "OA1 mode:score:acc mode:score:acc ..." (only modes with a best; plain text, no |). Everyone on the realm in the
  -- channel reads it into their board; nobody answers, nothing else is ever sent there. The channel never shows: it is
  -- taken out of every chat window and its lines and join notices are dropped before the chat sees them.
  -- C.minigames.realm = "0" leaves the channel.
  MG.CHANNEL = "OctoArcade"
  if S().realm == nil then S().realm = "1" end
  local lowerChan = string.lower(MG.CHANNEL)
  function MG.IsOurChannel(a9, a4)
    local n = string.lower(tostring(a9 or "") .. " " .. tostring(a4 or ""))
    return string.find(n, lowerChan, 1, true) and true or nil
  end
  -- the one line: our bests. "@RT" = our realm tag (older pfUI Octo reads past it: it has no colon)
  function MG.RealmLine()
    local parts = {}
    for _, b in ipairs(MG.BOARDS) do
      local v, acc = MG.MyBest(b.key)
      if v and v > 0 then table.insert(parts, b.key .. ":" .. floor(v) .. ":" .. floor(acc or 0)) end
    end
    if not parts[1] then return end
    return "OA1 @" .. MG.MyRealm() .. " " .. table.concat(parts, " ")
  end
  -- someone's line: every mode:score:acc goes on the board
  function MG.ReadRealm(msg, from)
    if type(msg) ~= "string" or string.sub(msg, 1, 4) ~= "OA1 " or not from then return end
    local _, _, short = string.find(from, "^([^%-]+)")
    from = short or from
    local _, _, realm = string.find(msg, "^OA1 @(%u%u%u?) ")
    local n = 0
    for key, v, acc in string.gfind(msg, "(%a+):(%d+):(%d+)") do
      n = n + 1
      if n > 12 then break end
      MG.Keep(key, from, v, acc, realm)
    end
    if win:IsShown() and MG.cur == "board" then MG.Board() end
    return n
  end
  function MG.JoinRealm()
    if S().realm ~= "1" or S().share ~= "1" or not JoinChannelByName then return end
    local id = GetChannelName and GetChannelName(MG.CHANNEL)
    if not id or id == 0 then pcall(JoinChannelByName, MG.CHANNEL) end
    -- out of every chat window: it is only ever read by pfUI
    for i = 1, (NUM_CHAT_WINDOWS or 7) do
      local cf = _G["ChatFrame" .. i]
      if cf and ChatFrame_RemoveChannel then pcall(ChatFrame_RemoveChannel, cf, MG.CHANNEL) end
    end
  end
  function MG.LeaveRealm()
    if LeaveChannelByName and GetChannelName and (GetChannelName(MG.CHANNEL) or 0) > 0 then pcall(LeaveChannelByName, MG.CHANNEL) end
  end
  function MG.SayRealm()
    if MG.realmSaid or S().realm ~= "1" or S().share ~= "1" then return end
    local id = GetChannelName and GetChannelName(MG.CHANNEL)
    local line = MG.RealmLine()
    if not id or id == 0 or not line then return end
    MG.realmSaid = true
    pcall(SendChatMessage, line, "CHANNEL", nil, id)
  end
  -- the channel's lines and join / leave notices never reach a chat window
  local chatEvent = _G.ChatFrame_OnEvent
  if chatEvent then
    _G.ChatFrame_OnEvent = function(e)
      local ev2 = e or event
      if (ev2 == "CHAT_MSG_CHANNEL" or ev2 == "CHAT_MSG_CHANNEL_NOTICE" or ev2 == "CHAT_MSG_CHANNEL_JOIN"
          or ev2 == "CHAT_MSG_CHANNEL_LEAVE" or ev2 == "CHAT_MSG_CHANNEL_NOTICE_USER") and MG.IsOurChannel(arg9, arg4) then
        return
      end
      return chatEvent(e)
    end
  end
  local realm = CreateFrame("Frame")
  MG.realmFrame = realm
  realm:RegisterEvent("PLAYER_ENTERING_WORLD")
  realm:RegisterEvent("CHAT_MSG_CHANNEL")
  realm:SetScript("OnEvent", function()
    if event == "CHAT_MSG_CHANNEL" then
      if MG.IsOurChannel(arg9, arg4) and arg2 ~= UnitName("player") then MG.ReadRealm(arg1, arg2) end
    elseif event == "PLAYER_ENTERING_WORLD" and not this.joined then
      this.joined = true
      this.sayAt = GetTime() + 20
    end
  end)
  realm:SetScript("OnUpdate", function()
    if not this.sayAt or GetTime() < this.sayAt then return end
    if not this.joinedChan then
      -- join first, say a few seconds later (the channel needs a moment)
      this.joinedChan = true
      MG.JoinRealm()
      this.sayAt = GetTime() + 5
      return
    end
    this.sayAt = nil
    MG.SayRealm()
    this:SetScript("OnUpdate", nil)
  end)

  -- ---------------------------------------------------------------- commands

  _G.SLASH_PFARCADE1, _G.SLASH_PFARCADE2 = "/arcade", "/octoarcade"
  _G.SlashCmdList["PFARCADE"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "quiz" or msg == "aim" or msg == "board" or msg == "scores" then MG.Toggle(msg == "scores" and "board" or msg)
    else MG.Toggle() end
  end
  _G.SLASH_PFARCQUIZ1 = "/quiz"
  _G.SlashCmdList["PFARCQUIZ"] = function() MG.Toggle("quiz") end
  _G.SLASH_PFARCAIM1 = "/aim"
  _G.SlashCmdList["PFARCAIM"] = function() MG.Toggle("aim") end
  _G.BINDING_HEADER_PFARCADE = "pfUI Octo: OctoArcade"
  _G.BINDING_NAME_PFARCADEQUIZ = "Open the quiz"
  _G.BINDING_NAME_PFARCADEAIM = "Open the aim trainer"

  S()
  AM.state = "idle"
end)
