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
    return s, s.me[me], me
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
    if MG.aim.state == "run" then MG.aim.Finish(true) end
    win:Hide()
  end
  function MG.Toggle(key)
    if win:IsShown() and (not key or key == MG.cur) then MG.Close() else MG.Show(key) end
  end

  -- ---------------------------------------------------------------- the quiz

  local QZ = MG.quiz
  QZ.CATS = { { "lore", "Lore & history" }, { "characters", "Characters" }, { "places", "Places" }, { "dungeons", "Dungeons" },
              { "raids", "Raids" }, { "classes", "Classes & races" }, { "professions", "Professions & mounts" },
              { "items", "Items & sets" }, { "pvp", "PvP" }, { "world", "Around the world" } }
  local qp = MG.pages.quiz
  qp.cat = Text(qp, 10, nil, .55, .57, .62)
  qp.cat:SetPoint("TOPLEFT", qp, "TOPLEFT", 2, -2)
  qp.timer = CreateFrame("StatusBar", nil, qp)
  qp.timer:SetPoint("TOPLEFT", qp, "TOPLEFT", 0, -16)
  qp.timer:SetPoint("TOPRIGHT", qp, "TOPRIGHT", 0, -16)
  qp.timer:SetHeight(3)
  qp.timer:SetStatusBarTexture(WHITE)
  qp.timer:SetMinMaxValues(0, 1)
  qp.q = Text(qp, 15)
  qp.q:SetPoint("TOPLEFT", qp, "TOPLEFT", 2, -26)
  qp.q:SetPoint("TOPRIGHT", qp, "TOPRIGHT", -2, -26)
  qp.q:SetJustifyH("LEFT")
  qp.answers = {}
  for i = 1, 4 do
    local b = Button(qp, 496, 32, "")
    b:SetPoint("TOPLEFT", qp, "TOPLEFT", 10, -82 - (i - 1) * 38)
    b:SetPoint("RIGHT", qp, "RIGHT", -10, 0)
    b.key = Text(b, 11, "OUTLINE", .6, .62, .66)
    b.key:SetPoint("LEFT", b, "LEFT", 10, 0)
    b.key:SetText(i)
    b.id = i
    b:SetScript("OnClick", function() QZ.Answer(this.id) end)
    qp.answers[i] = b
  end
  qp.fact = Text(qp, 12, nil, .85, .86, .9)
  qp.fact:SetPoint("TOPLEFT", qp, "TOPLEFT", 10, -238)
  qp.fact:SetPoint("TOPRIGHT", qp, "TOPRIGHT", -10, -238)
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
    qp.cat:SetText(string.upper(QZ.CatName(e.c)))
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
  function QZ.Open()
    win.sub:SetText("classic Azeroth, " .. table.getn(DATA.quiz) .. " questions")
    if not QZ.cur or QZ.done then QZ.Next() else QZ.PaintScore() end
  end
  qp:SetScript("OnUpdate", function()
    local now = GetTime()
    if QZ.deadline then
      local total = tonumber(S().quiztimer) or 15
      local left = QZ.deadline - now
      qp.timer:SetValue(max(0, left / total))
      local r = left < total * .3 and 1 or .2
      qp.timer:SetStatusBarColor(r, left < total * .3 and .35 or .7, left < total * .3 and .35 or 1)
      if left <= 0 then QZ.Answer(nil) end
    end
    if QZ.autoAt and now >= QZ.autoAt then QZ.autoAt = nil QZ.Next() end
  end)
  -- keys 1-4 answer while the quiz shows
  qp:EnableKeyboard(false)

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
  -- HUD
  ap.hud = {}
  local HUD = { "Time", "Score", "Accuracy", "Combo" }
  for i, label in ipairs(HUD) do
    local l = Text(ap, 10, nil, .55, .57, .62)
    l:SetPoint("TOPLEFT", ap, "TOPLEFT", 2 + (i - 1) * 128, -2)
    l:SetText(string.upper(label))
    local v = Text(ap, 17, "OUTLINE")
    v:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -2)
    ap.hud[i] = v
  end
  -- mode chips
  ap.chips = {}
  for i, m in ipairs(AM.MODES) do
    local b = Button(ap, 82, 20, m.name)
    b.text:SetFont(Font(), 10, "")
    b:SetPoint("TOPRIGHT", ap, "TOPRIGHT", -((table.getn(AM.MODES) - i) * 84), -2)
    b.key = m.key
    b:SetScript("OnClick", function()
      if AM.state == "run" then return end
      S().aimmode = this.key
      AM.Idle()
    end)
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
      GameTooltip:SetText(MG.modes[this.key].name, 1, 1, 1)
      GameTooltip:AddLine(MG.modes[this.key].tip, .8, .82, .86, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ap.chips[i] = b
  end
  -- the play area
  local area = CreateFrame("Button", nil, ap)
  ap.area = area
  area:SetPoint("TOPLEFT", ap, "TOPLEFT", 0, -44)
  area:SetPoint("BOTTOMRIGHT", ap, "BOTTOMRIGHT", 0, 0)
  area:RegisterForClicks("LeftButtonDown", "RightButtonDown")
  area.bg = Tex(area, "BACKGROUND", .08, .085, .095, 1)
  area.bg:SetAllPoints(area)
  area.grid = {}
  for i = 1, 3 do
    local h = Tex(area, "BORDER", 1, 1, 1, .025)
    h:SetHeight(1)
    h:SetPoint("LEFT", area, "LEFT", 0, 0)
    h:SetPoint("RIGHT", area, "RIGHT", 0, 0)
    h:SetPoint("TOP", area, "TOP", 0, -i * 70)
    local v = Tex(area, "BORDER", 1, 1, 1, .025)
    v:SetWidth(1)
    v:SetPoint("TOP", area, "TOP", 0, 0)
    v:SetPoint("BOTTOM", area, "BOTTOM", 0, 0)
    v:SetPoint("LEFT", area, "LEFT", i * 129, 0)
  end
  area.big = Text(area, 22, "OUTLINE")
  area.big:SetPoint("CENTER", area, "CENTER", 0, 26)
  area.small = Text(area, 12, nil, .78, .8, .84)
  area.small:SetPoint("TOP", area.big, "BOTTOM", 0, -8)
  area.small:SetWidth(440)
  area.best = Text(area, 12, nil, .35, .7, 1)
  area.best:SetPoint("TOP", area.small, "BOTTOM", 0, -6)
  area:SetScript("OnClick", function()
    if AM.state == "idle" or AM.state == "done" then
      if AM.state == "done" and GetTime() < (AM.lockUntil or 0) then return end
      AM.Start()
    elseif AM.state == "run" then
      AM.Miss()
    end
  end)
  -- results card
  local card = CreateFrame("Frame", nil, area)
  ap.card = card
  card:SetWidth(250)
  card:SetHeight(196)
  card:SetPoint("CENTER", area, "CENTER", 0, 0)
  card:SetFrameLevel(area:GetFrameLevel() + 20)
  card.bg = Tex(card, "BACKGROUND", .05, .055, .065, .97)
  card.bg:SetAllPoints(card)
  card.edge = Tex(card, "BORDER", .3, .31, .35, 1)
  card.edge:SetPoint("TOPLEFT", card, "TOPLEFT", -1, 1)
  card.edge:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 1, -1)
  card.bg:SetDrawLayer("ARTWORK")
  card.title = Text(card, 15, "OUTLINE")
  card.title:SetPoint("TOP", card, "TOP", 0, -10)
  card.rows = {}
  local ROWS = { "Hits", "Misses", "Accuracy", "Reaction", "Best combo", "Score", "Best" }
  for i, label in ipairs(ROWS) do
    local l = Text(card, 11, nil, .6, .62, .66)
    l:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -34 - (i - 1) * 16)
    l:SetText(label)
    local v = Text(card, 11)
    v:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -34 - (i - 1) * 16)
    v:SetJustifyH("RIGHT")
    card.rows[i] = v
  end
  card.again = Button(card, 108, 22, "Play again")
  card.again:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 12, 10)
  card.again:SetScript("OnClick", function() if GetTime() >= (AM.lockUntil or 0) then AM.Start() end end)
  card.next = Button(card, 108, 22, "Next mode")
  card.next:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -12, 10)
  card.next:SetScript("OnClick", function()
    local cur = S().aimmode
    for i, m in ipairs(AM.MODES) do
      if m.key == cur then
        local n = AM.MODES[math.mod(i, table.getn(AM.MODES)) + 1]
        S().aimmode = n.key
      end
    end
    AM.Idle()
  end)
  card:Hide()

  -- targets: a pool of buttons
  AM.pool, AM.live = {}, {}
  local function NewTarget()
    local t = CreateFrame("Button", nil, area)
    t:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    t:SetFrameLevel(area:GetFrameLevel() + 3)
    t.ring = t:CreateTexture(nil, "BACKGROUND")
    t.ring:SetTexture("Interface\\AddOns\\pfUI\\img\\octo\\disc")
    t.ring:SetPoint("CENTER", t, "CENTER", 0, 0)
    t.pic = t:CreateTexture(nil, "ARTWORK")
    t.pic:SetPoint("TOPLEFT", t, "TOPLEFT", 3, -3)
    t.pic:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -3, 3)
    t.cast = CreateFrame("StatusBar", nil, t)
    t.cast:SetPoint("TOPLEFT", t, "BOTTOMLEFT", -4, -3)
    t.cast:SetPoint("TOPRIGHT", t, "BOTTOMRIGHT", 4, -3)
    t.cast:SetHeight(5)
    t.cast:SetStatusBarTexture(WHITE)
    t.cast:SetStatusBarColor(1, .7, .1, 1)
    t.cast:SetMinMaxValues(0, 1)
    t.castbg = Tex(t.cast, "BACKGROUND", 0, 0, 0, .7)
    t.castbg:SetAllPoints(t.cast)
    t:SetScript("OnClick", function() AM.Hit(this) end)
    return t
  end
  -- floating "+120" / "-50" texts
  AM.pops = {}
  local function Pop(x, y, text, r, g, b)
    local p
    for _, e in ipairs(AM.pops) do if not e.on then p = e break end end
    if not p then
      p = Text(area, 13, "OUTLINE")
      table.insert(AM.pops, p)
    end
    p:ClearAllPoints()
    p:SetPoint("CENTER", area, "TOPLEFT", x, -y)
    p:SetText(text)
    p:SetTextColor(r, g, b)
    p.on, p.t0, p.x, p.y = true, GetTime(), x, y
    p:Show()
  end

  local function Faces()
    local f = AM.FACES[S().aimfaces] or AM.FACES.enemy
    local list = f()
    if not list[1] then list = AM.FACES.spells() end
    return list
  end
  -- a free spot in the area, not on another target
  local function Spot(size)
    local w, h = area:GetWidth() or 516, area:GetHeight() or 300
    local x, y
    for _ = 1, 12 do
      x = random(floor(size / 2) + 6, floor(w - size / 2 - 6))
      y = random(floor(size / 2) + 6, floor(h - size / 2 - 14))
      local free = true
      for _, o in ipairs(AM.live) do
        if (o.x - x) * (o.x - x) + (o.y - y) * (o.y - y) < (size + 8) * (size + 8) then free = false break end
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
    t.ring:SetVertexColor(ar, ag, ab, .45)
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
      end
    elseif m.key == "kick" and t.castTime then
      -- kicked early = more
      local f = (now - t.born) / t.castTime
      pts = floor(pts * (1.5 - f))
    end
    AM.score = AM.score + pts
    Pop(t.x, t.y - t.size / 2 - 6, "+" .. pts, .25, .85, .47)
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
    AM.combo = 0
    AM.score = max(0, AM.score - 50)
    if not x then
      local cx, cy = GetCursorPosition()
      local s = area:GetEffectiveScale()
      local left, top = area:GetLeft(), area:GetTop()
      if cx and left then x, y = cx / s - left, top - cy / s end
    end
    if x then Pop(x, y, why or "-50", 1, .35, .35) end
    Sound("miss")
    AM.PaintHud()
  end

  function AM.PaintHud()
    local left = AM.state == "run" and max(0, AM.ends - GetTime()) or (tonumber(S().aimtime) or 30)
    ap.hud[1]:SetText(string.format("%.1f", left))
    ap.hud[2]:SetText(AM.score or 0)
    local shots = (AM.hits or 0) + (AM.misses or 0)
    ap.hud[3]:SetText(shots > 0 and (floor(AM.hits / shots * 100 + .5) .. "%") or "--")
    ap.hud[4]:SetText("x" .. (AM.combo or 0))
  end
  local function Best(key)
    local _, me = Store()
    return me.aim[key]
  end
  function AM.Idle()
    AM.state = "idle"
    for i = table.getn(AM.live), 1, -1 do Retire(AM.live[i]) end
    card:Hide()
    local m = MG.modes[S().aimmode] or MG.modes.gridshot
    local ar, ag, ab = Accent()
    for _, b in ipairs(ap.chips) do
      if b.key == m.key then
        b.locked = true
        b.Paint(ar * .35, ag * .35, ab * .35, 1)
        b.edge:SetVertexColor(ar, ag, ab, 1)
      else
        b.locked = nil
        b.Paint(.1, .105, .12, 1)
        b.edge:SetVertexColor(.25, .26, .29, 1)
      end
    end
    win.sub:SetText(m.name)
    area.big:SetText("Click to start")
    area.small:SetText(m.tip .. "  " .. (tonumber(S().aimtime) or 30) .. " s rounds.")
    local b = Best(m.key)
    area.best:SetText(b and string.format("Your best: %d  (%d%% accuracy)", b.score or 0, b.acc or 0) or "No best yet")
    area.big:Show() area.small:Show() area.best:Show()
    AM.score, AM.hits, AM.misses, AM.combo = 0, 0, 0, 0
    AM.PaintHud()
  end
  function AM.Open()
    if AM.state ~= "run" and AM.state ~= "done" then AM.Idle() end
    local m = MG.modes[S().aimmode] or MG.modes.gridshot
    win.sub:SetText(m.name)
  end
  function AM.Start()
    local m = MG.modes[S().aimmode] or MG.modes.gridshot
    card:Hide()
    area.big:Hide() area.small:Hide() area.best:Hide()
    for i = table.getn(AM.live), 1, -1 do Retire(AM.live[i]) end
    AM.faces = Faces()
    AM.state = "run"
    AM.score, AM.hits, AM.misses, AM.combo, AM.bestCombo, AM.react = 0, 0, 0, 0, 0, 0
    AM.track, AM.trackAll = 0, 0
    AM.ends = GetTime() + (tonumber(S().aimtime) or 30)
    AM.gapUntil = nil
    for _ = 1, m.n do AM.Spawn() end
    Sound("start")
    AM.PaintHud()
  end
  function AM.Finish(quiet)
    AM.state = "done"
    AM.lockUntil = GetTime() + 1
    for i = table.getn(AM.live), 1, -1 do Retire(AM.live[i]) end
    if quiet then AM.Idle() return end
    local key = S().aimmode
    local shots = AM.hits + AM.misses
    local acc = shots > 0 and floor(AM.hits / shots * 100 + .5) or 0
    if key == "tracking" then acc = AM.trackAll > 0 and floor(AM.track / AM.trackAll * 100 + .5) or 0 end
    local react = AM.hits > 0 and floor(AM.react / AM.hits * 1000 + .5) or nil
    local _, me = Store()
    local old = me.aim[key]
    local isBest = not old or AM.score > (old.score or 0)
    if isBest and AM.score > 0 then
      me.aim[key] = { score = AM.score, acc = acc, t = time() }
      MG.Share(key, AM.score, acc)
      Sound("best")
    end
    card.title:SetText(isBest and AM.score > 0 and "|cffffd24dNew best!|r" or "Round over")
    local vals = { AM.hits, AM.misses, acc .. "%", react and (react .. " ms") or "--", "x" .. AM.bestCombo, AM.score,
                   me.aim[key] and me.aim[key].score or 0 }
    if key == "tracking" then vals[1], vals[2] = floor(AM.track * 10) / 10 .. " s on", floor((AM.trackAll - AM.track) * 10) / 10 .. " s off" end
    for i, v in ipairs(card.rows) do v:SetText(vals[i]) end
    card:Show()
    AM.PaintHud()
    if MG.after then local f = MG.after MG.after = nil f() end
  end

  -- every frame while a round runs
  ap:SetScript("OnUpdate", function()
    local now = GetTime()
    for _, p in ipairs(AM.pops) do
      if p.on then
        local a = (now - p.t0) / .6
        if a >= 1 then p.on = nil p:Hide()
        else
          p:SetAlpha(1 - a)
          p:ClearAllPoints()
          p:SetPoint("CENTER", area, "TOPLEFT", p.x, -(p.y - a * 18))
        end
      end
    end
    if AM.state ~= "run" then return end
    local dt = now - (AM.last or now)
    AM.last = now
    if now >= AM.ends then AM.Finish() return end
    local m = MG.modes[S().aimmode]
    for i = table.getn(AM.live), 1, -1 do
      local t = AM.live[i]
      local age = now - t.born
      -- grow in over .12 s
      local grow = min(1, age / .12)
      if t.life then
        -- reflex: shrinks to nothing over its life
        local f = 1 - age / t.life
        if f <= 0 then
          AM.Miss(t.x, t.y, "too slow")
          Retire(t)
          AM.gapUntil = now + .3
        else
          local s = max(4, t.base * f * grow)
          t:SetWidth(s) t:SetHeight(s)
          t.ring:SetWidth(s * 1.3) t.ring:SetHeight(s * 1.3)
        end
      elseif t.castTime then
        local f = age / t.castTime
        t.cast:SetValue(min(1, f))
        t.cast:SetStatusBarColor(1, .7 - min(.6, f * .6), .1, 1)
        if f >= 1 then
          AM.Miss(t.x, t.y, "cast landed!")
          Retire(t)
          AM.Spawn()
        end
      elseif t.vx then
        -- tracking: moves, bounces off the edges, turns now and then
        local w, h = area:GetWidth() or 516, area:GetHeight() or 300
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
            AM.score = AM.score + floor(10 * (1 + min(AM.combo, 50) * .02))
          end
          t.ring:SetVertexColor(.25, .85, .47, .7)
        else
          if AM.combo > 0 then AM.combo = 0 end
          local ar, ag, ab = Accent()
          t.ring:SetVertexColor(ar, ag, ab, .45)
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

  local bp = MG.pages.board
  bp.cols = {}
  function MG.Board()
    win.sub:SetText("bests from your guild, groups and battlegrounds - and the players they have met")
    local s, me, myName = Store()
    for _, c in ipairs(bp.cols) do c:Hide() end
    local list = { { key = "quiz", name = "Quiz streak", icon = "INV_Misc_Book_09" } }
    for _, m in ipairs(AM.MODES) do table.insert(list, { key = m.key, name = m.name, icon = m.icon }) end
    for i, d in ipairs(list) do
      local c = bp.cols[i]
      if not c then
        c = CreateFrame("Frame", nil, bp)
        c:SetWidth(126)
        c:SetHeight(158)
        c.bg = Tex(c, "BACKGROUND", 1, 1, 1, .03)
        c.bg:SetAllPoints(c)
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetWidth(16) c.icon:SetHeight(16)
        c.icon:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -6)
        c.icon:SetTexCoord(.08, .92, .08, .92)
        c.title = Text(c, 12, "OUTLINE")
        c.title:SetPoint("LEFT", c.icon, "RIGHT", 6, 0)
        c.lines = {}
        for n = 1, 8 do
          local l = Text(c, 10)
          l:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -26 - (n - 1) * 15)
          local r = Text(c, 10)
          r:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -26 - (n - 1) * 15)
          r:SetJustifyH("RIGHT")
          c.lines[n] = { l, r }
        end
        bp.cols[i] = c
      end
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", bp, "TOPLEFT", math.mod(i - 1, 4) * 129, -floor((i - 1) / 4) * 166)
      c.icon:SetTexture(ICON .. d.icon)
      c.title:SetText(d.name)
      -- everyone's best: the board plus your own
      local rows = {}
      for name, e in pairs(s.board[d.key] or {}) do table.insert(rows, { name = name, v = e.v, acc = e.acc }) end
      local mine = d.key == "quiz" and me.quiz.best or (me.aim[d.key] and me.aim[d.key].score)
      if mine and mine > 0 then
        local found
        for _, r in ipairs(rows) do if r.name == myName then r.v = max(r.v, mine) found = true end end
        if not found then table.insert(rows, { name = myName, v = mine, acc = me.aim[d.key] and me.aim[d.key].acc }) end
      end
      table.sort(rows, function(a, b) return a.v > b.v end)
      for n, ln in ipairs(c.lines) do
        local r = rows[n]
        if r then
          local you = r.name == myName
          ln[1]:SetText((you and "|cffffd24d" or "|cffdddddd") .. n .. ". " .. r.name .. "|r")
          ln[2]:SetText((you and "|cffffd24d" or "") .. r.v .. (r.acc and r.acc > 0 and ("  |cff8a8f99" .. r.acc .. "%|r") or "") .. (you and "|r" or ""))
          ln[1]:Show() ln[2]:Show()
        else
          ln[1]:SetText(n == 1 and "|cff666e7aNo scores yet|r" or "")
          ln[2]:SetText("")
        end
      end
      c:Show()
    end
  end
  -- a new best goes to guild / group; others' are kept (never "|" in an addon message)
  function MG.Share(key, v, acc)
    if S().share ~= "1" or not SendAddonMessage then return end
    local msg = "B^" .. key .. "^" .. floor(v) .. "^" .. floor(acc or 0)
    for _, chan in ipairs(MG.Channels and MG.Channels() or { "GUILD" }) do pcall(SendAddonMessage, PREFIX, msg, chan) end
  end
  -- "B^mode^score^acc" = the sender's own best; "R^mode^name^score^acc" = a best they heard from someone else
  function MG.Receive(msg, from)
    if not from then return end
    local _, _, short = string.find(from, "^([^%-]+)")
    from = short or from
    local _, _, key, v, acc = string.find(msg or "", "^B%^(%a+)%^(%d+)%^(%d+)$")
    if key then
      MG.Keep(key, from, v, acc)
    else
      local who
      _, _, key, who, v, acc = string.find(msg or "", "^R%^(%a+)%^([^%^]+)%^(%d+)%^(%d+)$")
      if not key then return end
      MG.Keep(key, who, v, acc)
    end
    if win:IsShown() and MG.cur == "board" then MG.Board() end
  end

  -- ---------------------------------------------------------------- on flights

  -- the launcher: three icons near the top of the screen while you fly
  local launch = CreateFrame("Frame", "pfOctoArcadeLauncher", UIParent)
  MG.launcher = launch
  launch:SetWidth(132)
  launch:SetHeight(36)
  launch:SetPoint("TOP", UIParent, "TOP", 0, -130)
  launch:SetFrameStrata("HIGH")
  launch:Hide()
  launch.bg = Tex(launch, "BACKGROUND", .05, .055, .065, .9)
  launch.bg:SetAllPoints(launch)
  launch.text = Text(launch, 10, nil, .6, .62, .66)
  launch.text:SetPoint("BOTTOM", launch, "TOP", 0, 3)
  launch.text:SetText("Something to play on the way?")
  local LB = { { "quiz", "INV_Misc_Book_09", "Quiz" }, { "aim", "Ability_Marksmanship", "Aim Trainer" }, { "board", "INV_Misc_Note_06", "Scores" } }
  for i, d in ipairs(LB) do
    local b = CreateFrame("Button", nil, launch)
    b:SetWidth(30) b:SetHeight(30)
    b:SetPoint("LEFT", launch, "LEFT", 6 + (i - 1) * 42, 0)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    b.icon:SetTexture(ICON .. d[2])
    b.icon:SetTexCoord(.08, .92, .08, .92)
    b.key, b.label = d[1], d[3]
    b:SetScript("OnClick", function() launch:Hide() MG.Show(this.key) end)
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
      GameTooltip:SetText(this.label, 1, 1, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  local closeL = CreateFrame("Button", nil, launch)
  closeL:SetWidth(14) closeL:SetHeight(14)
  closeL:SetPoint("TOPRIGHT", launch, "TOPRIGHT", -2, -2)
  closeL.t = Text(closeL, 10, "OUTLINE", .6, .62, .66)
  closeL.t:SetAllPoints(closeL)
  closeL.t:SetText("x")
  closeL:SetScript("OnClick", function() launch:Hide() end)

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
    if AM.state == "run" then MG.after = function() win:Hide() end return end
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
  -- what we tell a channel that asked: our bests, then the best others we know
  function MG.Answer(chan)
    if S().share ~= "1" then return end
    if GetTime() - (answered[chan] or -100) < 60 then return end
    answered[chan] = GetTime()
    local s, me, myName = Store()
    if (me.quiz.best or 0) > 0 then MG.Queue(chan, "B^quiz^" .. floor(me.quiz.best) .. "^0") end
    for key, r in pairs(me.aim) do
      if MG.modes[key] and (r.score or 0) > 0 then MG.Queue(chan, "B^" .. key .. "^" .. floor(r.score) .. "^" .. floor(r.acc or 0)) end
    end
    for key, list in pairs(s.board) do
      local rows = {}
      for name, e in pairs(list) do if name ~= myName then table.insert(rows, { name = name, v = e.v, acc = e.acc }) end end
      table.sort(rows, function(a, b) return a.v > b.v end)
      for i = 1, math.min(5, table.getn(rows)) do
        local r = rows[i]
        MG.Queue(chan, "R^" .. key .. "^" .. r.name .. "^" .. floor(r.v) .. "^" .. floor(r.acc or 0))
      end
    end
  end
  -- keeps a player's score when it is their best we know of; at most 50 names a board
  function MG.Keep(key, name, v, acc)
    if not key or not name or (key ~= "quiz" and not MG.modes[key]) then return end
    if not string.find(name, "^[%a\128-\255][%a\128-\255]+$") then return end
    local s, _, myName = Store()
    if name == myName then return end
    s.board[key] = s.board[key] or {}
    local board = s.board[key]
    local old = board[name]
    v = tonumber(v)
    if not v then return end
    if old and v <= old.v then return end
    board[name] = { v = v, acc = tonumber(acc), t = time() }
    local n, low, lowName = 0, nil, nil
    for nm, e in pairs(board) do
      n = n + 1
      if not low or e.v < low then low, lowName = e.v, nm end
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
