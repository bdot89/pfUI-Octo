pfUI:RegisterModule("meters-breakdown", "vanilla", function ()
  -- pfUI Octo :: the breakdown window (meters phase 3, Details!' "player
  -- details" as the model - Details! is All Rights Reserved, nothing of it is
  -- copied). Clicking any bar of a meter window opens it. 23 Oct 2026 (user:
  -- "extra frames ... should carry the same UI look and store vast info from
  -- the meters every bit of info should be in there easy to manage and linked
  -- with easy click through menus") it shows everything the meter keeps, in
  -- the window's own look, and every name in it is a link:
  --   a player   Summary, Spells, Targets, Taken, Casts, Auras, Utility,
  --              Deaths, Chart, Compare. Spells / Targets / Chart / Compare
  --              switch between damage, healing and friendly fire.
  --   an enemy   Summary, Hit by, Spells on it, It hit, Its spells
  --   a spell    (damage taken by spell) who it hit, who cast it
  -- Clicking a player, enemy or spell anywhere opens it; Back goes back; the
  -- name in the header lists everyone in the fight, Enemies every enemy.
  local M = pfUI.meters
  if not M or not M.ShowDetails or not M.MODES then return end

  local floor, max, min = math.floor, math.max, math.min
  local Num = M.Num
  local Clock = M.Clock or function(t) t = max(0, floor(t or 0)) return string.format("%d:%02d", floor(t / 60), math.mod(t, 60)) end
  local MODE = {}
  for _, m in ipairs(M.MODES) do MODE[m.key] = m end
  local function Pct(part, all) return (all and all > 0) and string.format("%.1f%%", part / all * 100) or "-" end
  local function Avg(total, n) return n > 0 and Num(total / n) or "-" end
  local HEALMODES = { heal = true, hps = true, overheal = true, htaken = true }
  local LINK = "|cff7fbfff"

  local B = { tab = "spells", stack = {} }
  M.breakdown = B

  -- ---------------------------------------------------------------- the frame
  -- 25 Oct 2026 (user: "looks bad ... a lot more professional and easier to
  -- select what category ... some icons ... link all the bars up ... hover
  -- links and descriptions"): a header, a rail on the left (the views, each
  -- with a picture, then what is shown), a strip of figures that open their
  -- tab, the list of bars and the detail panel. Every part has a tooltip.

  local W, H = 940, 560
  local RAIL, HEAD, X0 = 176, 48, 186
  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local f = CreateFrame("Frame", "pfMeterBreakdown", UIParent)
  f:SetWidth(W)
  f:SetHeight(H)
  f:SetPoint("CENTER", 0, 40)
  f:SetFrameStrata("FULLSCREEN_DIALOG") -- above the options window (DIALOG), 25 Oct 2026
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() pfUI.api.DragStart(this) end)
  f:SetScript("OnDragStop", function() pfUI.api.DragStop(this) end)
  f:Hide()
  CreateBackdrop(f, nil, true, .94)
  CreateBackdropShadow(f)
  table.insert(UISpecialFrames, "pfMeterBreakdown")
  B.frame = f

  local texts = {}
  local function Text(parent, size, justify)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    t:SetFont(pfUI.font_default, size or C.global.font_size, "OUTLINE")
    t:SetJustifyH(justify or "LEFT")
    t.base = size or C.global.font_size
    table.insert(texts, t)
    return t
  end
  local function Strip(s) return gsub(gsub(tostring(s or ""), "|c%x%x%x%x%x%x%x%x", ""), "|r", "") end

  -- the dark bands: header and rail
  f.headbg = f:CreateTexture(nil, "BACKGROUND")
  f.headbg:SetTexture(WHITE)
  f.headbg:SetVertexColor(0, 0, 0, .35)
  f.headbg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
  f.headbg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
  f.headbg:SetHeight(HEAD - 1)
  f.railbg = f:CreateTexture(nil, "BACKGROUND")
  f.railbg:SetTexture(WHITE)
  f.railbg:SetVertexColor(0, 0, 0, .22)
  f.railbg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -HEAD)
  f.railbg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
  f.railbg:SetWidth(RAIL)
  f.rule = f:CreateTexture(nil, "ARTWORK")
  f.rule:SetTexture(WHITE)
  f.rule:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -HEAD)
  f.rule:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -HEAD)
  f.rule:SetHeight(2)
  f.rail = f:CreateTexture(nil, "ARTWORK")
  f.rail:SetTexture(WHITE)
  f.rail:SetVertexColor(1, 1, 1, .08)
  f.rail:SetPoint("TOPLEFT", f, "TOPLEFT", RAIL + 1, -HEAD)
  f.rail:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", RAIL + 1, 1)
  f.rail:SetWidth(1)

  f.icon = f:CreateTexture(nil, "OVERLAY")
  f.icon:SetWidth(30)
  f.icon:SetHeight(30)
  f.icon:SetPoint("TOPLEFT", 12, -9)

  -- a tooltip: the first line is the title, the rest explains
  local function Tip(owner, tip, anchor)
    if not tip or tip == "" then return end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    local _, _, head, rest = string.find(tip, "^(.-)\n(.*)$")
    if head then
      GameTooltip:AddLine(head, 1, 1, 1)
      GameTooltip:AddLine(rest, .7, .85, 1, 1)
    else
      GameTooltip:AddLine(tip, 1, 1, 1)
    end
    GameTooltip:Show()
  end
  B.Tip = Tip

  -- a small text button
  local function Button(parent, label, width, func, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(width)
    b:SetHeight(20)
    CreateBackdrop(b, nil, true, .8)
    b.text = Text(b, C.global.font_size, "CENTER")
    b.text:SetAllPoints(b)
    b.text:SetText(label)
    b:SetScript("OnClick", func)
    b:SetScript("OnEnter", function()
      local r, g, bb = GetAccentColor()
      if this.backdrop then this.backdrop:SetBackdropBorderColor(r, g, bb, 1) end
      Tip(this, this.tip, "ANCHOR_BOTTOM")
    end)
    b:SetScript("OnLeave", function()
      if this.backdrop then
        if this.lit then
          local r, g, bb = GetAccentColor()
          this.backdrop:SetBackdropBorderColor(r, g, bb, 1)
        else
          this.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        end
      end
      if this.PaintRole and not this.lit then this.PaintRole() end
      GameTooltip:Hide()
    end)
    b.tip = tip
    return b
  end
  B.Button = Button

  -- the header: the name opens a list of everyone in the fight
  f.who = Button(f, "", 200, function() B.PeopleMenu(this) end,
    "Everyone in this fight\nClick to pick another player: the same view opens for them.")
  f.who:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
  f.name = f.who.text
  f.name:ClearAllPoints()
  f.name:SetPoint("LEFT", f.who, "LEFT", 6, 0)
  f.who.text.base = C.global.font_size + 4
  f.name:SetFont(pfUI.font_default, C.global.font_size + 4, "OUTLINE")
  f.who:SetHeight(24)
  f.sub = Text(f, C.global.font_size)
  f.sub:SetPoint("LEFT", f.who, "RIGHT", 12, 0)
  f.sub:SetTextColor(.65, .65, .65)

  f.close = Button(f, "X", 22, function() f:Hide() end, "Close\nEscape closes it too.")
  f.close:SetPoint("TOPRIGHT", -10, -14)
  f.report = Button(f, "Report", 64, function() B.ReportMenu(this) end,
    "Report\nSend what this view shows (the top lines) to say, party, raid, guild, officers or a whisper.")
  f.report:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
  f.next = Button(f, ">", 24, function() B.Step(1) end, "Next\nThe next bar of the meter window, in the same view.")
  f.next:SetPoint("RIGHT", f.report, "LEFT", -10, 0)
  f.prev = Button(f, "<", 24, function() B.Step(-1) end, "Previous\nThe bar above this one in the meter window.")
  f.prev:SetPoint("RIGHT", f.next, "LEFT", -2, 0)
  f.foes = Button(f, "Enemies", 70, function() B.FoeMenu(this) end,
    "Enemies\nEvery enemy in this fight: what hit it, what it hit, its spells.")
  f.foes:SetPoint("RIGHT", f.prev, "LEFT", -10, 0)
  f.back = Button(f, "< Back", 60, function() B.Back() end, "Back\nTo what was open before you followed a link.")
  f.back:SetPoint("RIGHT", f.foes, "LEFT", -4, 0)
  -- (25 Oct 2026, test mode for everything) a tour: every view of what is open, one every two seconds
  f.tour = Button(f, "Tour", 48, function() B.Tour() end,
    "Tour the views\nSteps through every view of what is open, one every two seconds, so you can see them all. Click again to stop.")
  f.tour:SetPoint("RIGHT", f.back, "LEFT", -4, 0)
  function B.Tour(on)
    if on == nil then on = not B.touring end
    B.touring = on and true or nil
    B.tourIndex = 0
    f.tour.lit = B.touring
    if f.tour.backdrop then
      if B.touring then
        local r, g, b = GetAccentColor()
        f.tour.backdrop:SetBackdropBorderColor(r, g, b, 1)
      else
        f.tour.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
      end
    end
    f.nextTour = 0
  end
  f:SetScript("OnUpdate", function()
    if not B.touring then return end
    if (this.nextTour or 0) > GetTime() then return end
    this.nextTour = GetTime() + 2
    local set = (B.foe and B.FOETABS) or (B.bspell and B.SPELLTABS) or B.TABS
    local i = (B.tourIndex or 0) + 1
    if i > table.getn(set) then i = 1 end
    B.tourIndex = i
    B.tab, B.offset, B.lineOffset = set[i][1], 0, 0
    B.Draw()
  end)
  f:SetScript("OnHide", function() B.touring = nil f.tour.lit = nil end)
  -- one colour language (25 Oct 2026): blue opens something, green runs, red closes
  do
    local OW = pfUI.octoui and pfUI.octoui.W
    if OW and OW.Tint then
      OW.Tint(f.close, "danger")
      OW.Tint(f.tour, "go")
      for _, b in ipairs({ f.report, f.next, f.prev, f.foes, f.back }) do OW.Tint(b, "open") end
    end
  end

  -- ------------------------------------------------------------ the rail

  -- views: one picture and one sentence each (for the tooltip)
  B.TABS = { { "summary", "Summary" }, { "spells", "Spells" }, { "targets", "Targets" }, { "taken", "Taken" },
             { "casts", "Casts" }, { "auras", "Auras" }, { "utility", "Utility" }, { "deaths", "Deaths" },
             { "chart", "Chart" }, { "compare", "Compare" } }
  B.FOETABS = { { "fsummary", "Summary" }, { "fhitby", "Hit by" }, { "ftaken", "Spells on it" }, { "fhit", "It hit" },
                { "fspells", "Its spells" } }
  B.SPELLTABS = { { "ssummary", "Who it hit" }, { "sfrom", "Who cast it" } }
  local ICON = "Interface\\Icons\\"
  B.TABINFO = {
    summary = { "INV_Misc_Note_01", "Everything about them at a glance. Click a line to jump to its view." },
    spells = { "Spell_Fire_FlameBolt", "Every spell and attack with its total. Click one for hits, crits, misses, averages and targets." },
    targets = { "Ability_Marksmanship", "Who they hit (or healed). Click one for the spells used on it." },
    taken = { "Ability_Warrior_DefensiveStance", "What hit them: the attacks, who made them, what they avoided, who healed them." },
    casts = { "INV_Misc_Book_09", "Every cast, with cooldowns used and resurrections." },
    auras = { "Spell_Holy_WordFortitude", "Buffs on them and their debuffs on enemies, with uptime." },
    utility = { "Ability_Kick", "Interrupts, dispels, kills, resurrects, mana and rage gained." },
    deaths = { "INV_Misc_Bone_HumanSkull_01", "Each death with the last hits and heals before it." },
    chart = { "Spell_Nature_Lightning", "Damage or healing per second through the fight." },
    compare = { "Ability_DualWield", "Spell by spell against another player." },
    fsummary = { "INV_Misc_Note_01", "The enemy at a glance." },
    fhitby = { "Ability_Marksmanship", "Who hit it, and how much." },
    ftaken = { "Spell_Fire_FlameBolt", "The spells that hit it." },
    fhit = { "Ability_Warrior_DefensiveStance", "Who it hit." },
    fspells = { "Spell_Shadow_ShadowWordPain", "What it cast." },
    ssummary = { "Ability_Marksmanship", "Who this spell hit." },
    sfrom = { "Spell_Shadow_ShadowWordPain", "Who cast this spell." },
  }

  -- what is shown: every display of the windows, by group; the group in use is lit
  B.GROUPS = {}
  local seenGroup = {}
  for _, m in ipairs(M.MODES) do
    if m.group and not seenGroup[m.group] and m.key ~= "threat" then
      seenGroup[m.group] = true
      table.insert(B.GROUPS, m.group)
    end
  end
  B.GROUPINFO = {
    Damage = { "Ability_MeleeDamage", "Damage done and taken, per second, friendly fire, enemies, frags." },
    Healing = { "Spell_Holy_Heal", "Healing, overhealing and healing taken." },
    Resources = { "Spell_Nature_Regeneration", "Mana, rage and energy gained." },
    Misc = { "Spell_Holy_DispelMagic", "Interrupts, dispels, deaths, resurrects, cooldowns, buff and debuff uptime." },
    Custom = { "INV_Misc_Gear_01", "Your own displays (set them in the meter options)." },
  }

  -- a rail row: a picture, a word, a bar down the left edge when it is the one in use
  local function RailButton(parent, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(h)
    b:SetWidth(RAIL - 14)
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints(b)
    b.sel:SetTexture(WHITE)
    b.sel:Hide()
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(b)
    b.hl:SetTexture(WHITE)
    b.hl:SetVertexColor(1, 1, 1, .07)
    b.bar = b:CreateTexture(nil, "OVERLAY")
    b.bar:SetTexture(WHITE)
    b.bar:SetWidth(3)
    b.bar:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.bar:Hide()
    b.ico = b:CreateTexture(nil, "ARTWORK")
    b.ico:SetWidth(h - 6)
    b.ico:SetHeight(h - 6)
    b.ico:SetPoint("LEFT", b, "LEFT", 8, 0)
    b.ico:SetTexCoord(.08, .92, .08, .92)
    b.text = Text(b, C.global.font_size, "LEFT")
    b.text:SetPoint("LEFT", b.ico, "RIGHT", 7, 0)
    b.text:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    b:SetScript("OnEnter", function() Tip(this, this.tip, "ANCHOR_RIGHT") end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end
  -- lit or not: the accent on the bar, the word and a faint wash
  local function Lit(b, on)
    b.lit = on
    if on then
      local ar, ag, ab = GetAccentColor()
      b.sel:SetVertexColor(ar, ag, ab, .2)
      b.sel:Show()
      b.bar:SetVertexColor(ar, ag, ab, 1)
      b.bar:Show()
      b.text:SetTextColor(ar * .5 + .5, ag * .5 + .5, ab * .5 + .5)
    else
      b.sel:Hide()
      b.bar:Hide()
      b.text:SetTextColor(.85, .85, .85)
    end
  end

  f.viewlabel = Text(f, C.global.font_size - 1)
  f.viewlabel:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -(HEAD + 10))
  f.viewlabel:SetText("VIEW")
  f.viewlabel:SetTextColor(.5, .5, .5)
  f.tabs = {}
  for i = 1, 10 do
    local b = RailButton(f, 24)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -(HEAD + 26 + (i - 1) * 25))
    b:SetScript("OnClick", function()
      B.tab = this.key
      B.offset = 0
      B.Draw()
    end)
    f.tabs[i] = b
  end

  f.showing = Text(f, C.global.font_size - 1)
  f.showing:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -(HEAD + 290))
  f.showing:SetText("SHOWING")
  f.showing:SetTextColor(.5, .5, .5)
  f.groups = {}
  for i, g in ipairs(B.GROUPS) do
    local group = g
    local b = RailButton(f, 24)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -(HEAD + 306 + (i - 1) * 25))
    b:SetScript("OnClick", function() B.ModeMenu(this, group) end)
    b.group = group
    local info = B.GROUPINFO[group]
    b.ico:SetTexture(ICON .. (info and info[1] or "INV_Misc_Gear_01"))
    b.tip = group .. " displays\n" .. (info and info[2] or "") .. "\nClick to pick one: the breakdown follows the display."
    f.groups[i] = b
  end
  function B.ModeMenu(anchor, group)
    local items = { { group, head = true } }
    for _, m in ipairs(M.MODES) do
      if m.group == group and m.key ~= "threat" and (not m.shown or m.shown()) then
        local key = m.key
        table.insert(items, { m.name, function() B.SetMode(key) end, checked = key == B.mode })
      end
    end
    M.ShowMenu(anchor, items)
  end
  -- a new display: players keep the one open (or the top one); enemy and
  -- spell displays open their top row
  function B.SetMode(key)
    local mode = MODE[key]
    if not mode then return end
    B.mode, B.kind = key, nil
    B.offset, B.lineOffset, B.spell, B.target, B.death = 0, 0, nil, nil, nil
    local rows = M.Rows(key, B.segment)
    if mode.rows then
      local r = rows[1]
      if r and r.foe then B.actor, B.foe, B.bspell, B.tab = nil, r.name, nil, key == "enemydone" and "fhit" or "fsummary"
      elseif r and r.byspell then B.actor, B.foe, B.bspell, B.tab = nil, nil, r.name, "ssummary" end
    else
      if not B.actor and rows[1] and rows[1].actor then B.actor = rows[1].actor end
      B.foe, B.bspell = nil, nil
      B.tab = B.FIRSTTAB and B.FIRSTTAB[key] or "spells"
    end
    B.Draw()
  end
  local function PaintGroups()
    local cur = MODE[B.mode]
    for _, b in ipairs(f.groups) do
      local on = cur and cur.group == b.group
      Lit(b, on and true or false)
      b.text:SetText(on and (cur.name .. "  v") or (b.group .. "  v"))
    end
  end
  B.PaintGroups = PaintGroups

  -- ------------------------------------------------------------ the figures

  -- five tiles over the list (a player): damage, healing, taken, active, deaths; a click opens that view
  f.tiles = {}
  local TILEW = floor((W - X0 - 12 - 4 * 6) / 5)
  for i = 1, 5 do
    local t = CreateFrame("Button", nil, f)
    t:SetWidth(TILEW)
    t:SetHeight(42)
    t:SetPoint("TOPLEFT", f, "TOPLEFT", X0 + (i - 1) * (TILEW + 6), -(HEAD + 10))
    t.bg = t:CreateTexture(nil, "BACKGROUND")
    t.bg:SetAllPoints(t)
    t.bg:SetTexture(WHITE)
    t.bg:SetVertexColor(1, 1, 1, .06)
    t.hl = t:CreateTexture(nil, "HIGHLIGHT")
    t.hl:SetAllPoints(t)
    t.hl:SetTexture(WHITE)
    t.hl:SetVertexColor(1, 1, 1, .08)
    t.line = t:CreateTexture(nil, "OVERLAY")
    t.line:SetTexture(WHITE)
    t.line:SetHeight(2)
    t.line:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 0, 0)
    t.line:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 0, 0)
    t.label = Text(t, C.global.font_size - 1)
    t.label:SetPoint("TOPLEFT", t, "TOPLEFT", 8, -5)
    t.label:SetTextColor(.6, .6, .6)
    t.value = Text(t, C.global.font_size + 3)
    t.value:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 8, 5)
    t.sub = Text(t, C.global.font_size - 1, "RIGHT")
    t.sub:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -8, 6)
    t.sub:SetTextColor(.6, .6, .6)
    t:SetScript("OnClick", function() if this.go then this.go() end end)
    t:SetScript("OnEnter", function() Tip(this, this.tip, "ANCHOR_BOTTOM") end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.tiles[i] = t
  end

  -- damage / healing / friendly fire, as one strip of three over the tabs that use it
  B.KINDS = { { "damage", "Damage", "Ability_MeleeDamage", "Damage they did." },
              { "heal", "Healing", "Spell_Holy_Heal", "Healing they did." },
              { "ff", "Friendly fire", "Spell_Fire_Fire", "Damage they did to their own group." } }
  f.kinds = {}
  for i, k in ipairs(B.KINDS) do
    local key = k[1]
    local b = RailButton(f, 22)
    b:SetWidth(122)
    b.key = key
    b.ico:SetTexture(ICON .. k[3])
    b.text:SetText(k[2])
    b.tip = k[2] .. "\n" .. k[4] .. "\nSwitches the list below."
    b:SetScript("OnClick", function() B.kind = this.key B.spell = nil B.offset = 0 B.Draw() end)
    f.kinds[i] = b
  end
  local KINDTABS = { spells = true, targets = true, chart = true, compare = true }

  -- ------------------------------------------------------------ the body

  local ROWH, LINEH = 22, 18
  local LIST_W = 420
  f.list = CreateFrame("Frame", nil, f)
  f.list:SetWidth(LIST_W)
  f.list:EnableMouseWheel(true)
  f.list:SetScript("OnMouseWheel", function()
    B.offset = max(0, (B.offset or 0) - (arg1 or 0) * 3)
    B.Draw()
  end)
  f.panel = CreateFrame("Frame", nil, f)
  CreateBackdrop(f.panel, nil, true, .5)
  f.panel:EnableMouseWheel(true)
  f.panel:SetScript("OnMouseWheel", function()
    B.lineOffset = max(0, (B.lineOffset or 0) - (arg1 or 0) * 3)
    B.Draw()
  end)
  f.rows, f.lines = {}, {}
  B.maxrows, B.maxlines = 18, 24

  -- where the body starts: under the figures and the kind strip when they show
  local function LayoutBody(tiles, kinds)
    local top = HEAD + 10
    for _, t in ipairs(f.tiles) do if tiles then t:Show() else t:Hide() end end
    if tiles then top = top + 50 end
    for i, k in ipairs(f.kinds) do
      if kinds then
        k:ClearAllPoints()
        k:SetPoint("TOPLEFT", f, "TOPLEFT", X0 + (i - 1) * 124, -top)
        k:Show()
      else
        k:Hide()
      end
    end
    if kinds then top = top + 28 end
    f.list:ClearAllPoints()
    f.list:SetPoint("TOPLEFT", f, "TOPLEFT", X0, -top)
    f.list:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", X0, 12)
    f.list:SetWidth(LIST_W)
    f.panel:ClearAllPoints()
    f.panel:SetPoint("TOPLEFT", f.list, "TOPRIGHT", 10, 0)
    f.panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    f.chart:ClearAllPoints()
    f.chart:SetPoint("TOPLEFT", f, "TOPLEFT", X0, -top)
    f.chart:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    B.maxrows = max(3, floor((H - top - 12) / (ROWH + 2)))
    B.maxlines = max(3, floor((H - top - 12 - 8) / LINEH))
    B.chartW, B.chartH = W - X0 - 12 - 16, H - top - 12 - 40
  end

  -- a picture for a spell by its name: from your spell book, a few fixed ones
  local spellTex
  local FIXED = {}
  FIXED[T["Melee"] or "Melee"] = ICON .. "Ability_MeleeDamage"
  FIXED["Auto Shot"] = ICON .. "Ability_Whirlwind"
  FIXED["Shoot"] = ICON .. "Ability_ShootWand"
  local function SpellIcon(name)
    name = Strip(name)
    if name == "" then return end
    -- ClassicAPI: the spell id the combat log gave -> its own picture (any spell, not only yours)
    local id = M.spellIds and M.spellIds[name]
    local CS = _G.C_Spell
    if id and CS and CS.GetSpellTexture then
      local good, tex = pcall(CS.GetSpellTexture, id)
      if good and tex and tex ~= "" then return tex end
    end
    if not spellTex then
      spellTex = {}
      if GetSpellName and GetSpellTexture then
        for i = 1, 600 do
          local n = GetSpellName(i, "spell")
          if not n then break end
          spellTex[n] = GetSpellTexture(i, "spell") or spellTex[n]
        end
      end
    end
    return spellTex[name] or FIXED[name]
  end
  B.SpellIcon = SpellIcon
  local spellWatch = CreateFrame("Frame")
  spellWatch:RegisterEvent("SPELLS_CHANGED")
  spellWatch:SetScript("OnEvent", function() spellTex = nil end)

  local function Row(i)
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, f.list)
    r:SetHeight(ROWH)
    r:SetPoint("TOPLEFT", f.list, "TOPLEFT", 0, -(i - 1) * (ROWH + 2))
    r:SetPoint("RIGHT", f.list, "RIGHT", 0, 0)
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetAllPoints(r)
    r.bar:SetMinMaxValues(0, 1)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints(r)
    r.bg:SetTexture(1, 1, 1, .05)
    r.sel = r:CreateTexture(nil, "OVERLAY")
    r.sel:SetAllPoints(r)
    r.sel:SetTexture(1, 1, 1, .12)
    r.sel:Hide()
    r.mark = r:CreateTexture(nil, "OVERLAY")
    r.mark:SetTexture(WHITE)
    r.mark:SetWidth(3)
    r.mark:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    r.mark:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
    r.mark:Hide()
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints(r)
    r.hl:SetTexture(1, 1, 1, .1)
    r.ico = r.bar:CreateTexture(nil, "OVERLAY")
    r.ico:SetWidth(ROWH - 4)
    r.ico:SetHeight(ROWH - 4)
    r.ico:SetPoint("LEFT", r, "LEFT", 4, 0)
    r.ico:SetTexCoord(.08, .92, .08, .92)
    r.left = Text(r.bar, C.global.font_size)
    r.right = Text(r.bar, C.global.font_size, "RIGHT")
    r.right:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    r.left:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
    r:SetScript("OnClick", function() if this.onclick then this.onclick() end end)
    r:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(Strip(this.title), 1, 1, 1)
      if this.sub and this.sub ~= "" then GameTooltip:AddLine(Strip(this.sub), .8, .8, .8) end
      if this.tip then GameTooltip:AddLine(this.tip, .5, .75, 1, 1) end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.rows[i] = r
    return r
  end

  -- a line on the right panel: label and value; a line with `go` is a link
  local function Line(i)
    local l = f.lines[i]
    if l then return l end
    l = {}
    local y = -6 - (i - 1) * LINEH
    l.zebra = f.panel:CreateTexture(nil, "BACKGROUND")
    l.zebra:SetTexture(WHITE)
    l.zebra:SetVertexColor(1, 1, 1, .035)
    l.zebra:SetPoint("TOPLEFT", f.panel, "TOPLEFT", 2, y + 2)
    l.zebra:SetPoint("TOPRIGHT", f.panel, "TOPRIGHT", -2, y + 2)
    l.zebra:SetHeight(LINEH)
    l.rule = f.panel:CreateTexture(nil, "ARTWORK")
    l.rule:SetTexture(WHITE)
    l.rule:SetHeight(1)
    l.rule:SetPoint("TOPLEFT", f.panel, "TOPLEFT", 6, y - LINEH + 3)
    l.rule:SetPoint("TOPRIGHT", f.panel, "TOPRIGHT", -6, y - LINEH + 3)
    l.btn = CreateFrame("Button", nil, f.panel)
    l.btn:SetHeight(LINEH)
    l.btn:SetPoint("TOPLEFT", f.panel, "TOPLEFT", 2, y + 2)
    l.btn:SetPoint("RIGHT", f.panel, "RIGHT", -2, 0)
    l.btn.hl = l.btn:CreateTexture(nil, "HIGHLIGHT")
    l.btn.hl:SetAllPoints(l.btn)
    l.btn.hl:SetTexture(1, 1, 1, .1)
    l.btn:SetScript("OnClick", function() if this.go then this.go() end end)
    l.btn:SetScript("OnEnter", function()
      if this.tip then
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:AddLine(Strip(this.title), 1, 1, 1)
        GameTooltip:AddLine(this.tip, .7, .85, 1, 1)
        GameTooltip:Show()
      end
    end)
    l.btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    l.label = Text(f.panel, C.global.font_size)
    l.label:SetPoint("TOPLEFT", f.panel, "TOPLEFT", 8, y)
    l.value = Text(f.panel, C.global.font_size, "RIGHT")
    l.value:SetPoint("TOPRIGHT", f.panel, "TOPRIGHT", -8, y)
    l.arrow = Text(f.panel, C.global.font_size, "RIGHT")
    l.arrow:SetPoint("TOPRIGHT", f.panel, "TOPRIGHT", -8, y)
    l.arrow:SetText(">")
    l.arrow:SetTextColor(.5, .75, 1)
    f.lines[i] = l
    return l
  end

  -- ---------------------------------------------------------------- filling

  local texture = "Interface\\AddOns\\pfUI\\img\\bar_elvui"
  local cr, cg, cb = .6, .6, .6

  -- list: { { name, value, text, onclick, selected, color, tip, class, icon, spell } }
  -- a picture is the class (a player of the fight), the skull (an enemy), the spell's own
  -- (`spell = true` or a name that is a spell of yours) or none
  local function FillList(list, maxv)
    local seg = B.seg
    local max_rows = B.maxrows or 18
    local off = B.offset or 0
    if off > max(0, table.getn(list) - max_rows) then off = max(0, table.getn(list) - max_rows) B.offset = off end
    local ar, ag, ab = GetAccentColor()
    for i = 1, max(max_rows, table.getn(f.rows)) do
      local e = i <= max_rows and list[i + off]
      local r = Row(i)
      if e then
        r.bar:SetStatusBarTexture(texture)
        local c = e.color
        r.bar:SetStatusBarColor(c and c[1] or cr, c and c[2] or cg, c and c[3] or cb, .8)
        r.bar:SetValue((maxv and maxv > 0 and e.value) and e.value / maxv or 0)
        -- the picture
        local plain = Strip(e.name)
        local tex, coords
        if e.icon then tex = e.icon
        else
          local actor = seg and seg.actors and (seg.actors[plain] or (e.class and { class = e.class }))
          local cls = e.class or (actor and actor.class)
          local cc = cls and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[cls]
          if cc then tex, coords = pfUI.media["img:classicons"], cc
          elseif seg and seg.foes and seg.foes[plain] then tex = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
          elseif e.spell then tex = SpellIcon(plain) or (ICON .. "INV_Misc_QuestionMark")
          end
        end
        if tex then
          r.ico:SetTexture(tex)
          if coords then r.ico:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
          else r.ico:SetTexCoord(.08, .92, .08, .92) end
          r.ico:Show()
        else
          r.ico:Hide()
        end
        r.left:ClearAllPoints()
        r.left:SetPoint("LEFT", r, "LEFT", tex and (ROWH + 3) or 7, 0)
        r.left:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
        r.left:SetText((e.link and LINK or "") .. e.name .. (e.link and "|r" or ""))
        r.right:SetText(e.text or "")
        r.onclick = e.onclick
        r.title, r.sub = e.name, e.text
        r.tip = e.tip or (e.onclick and (e.link and ("Click: open " .. plain) or "Click: its details on the right")) or nil
        if e.selected then
          r.sel:Show()
          r.mark:SetVertexColor(ar, ag, ab, 1)
          r.mark:Show()
        else
          r.sel:Hide()
          r.mark:Hide()
        end
        r:Show()
      else
        r:Hide()
      end
    end
    B.listShown = list
  end

  -- lines: { { label, value, head, go, tip } }
  local function FillLines(lines)
    local ar, ag, ab = GetAccentColor()
    local max_lines = B.maxlines or 24
    local off = B.lineOffset or 0
    if off > max(0, table.getn(lines) - max_lines) then off = max(0, table.getn(lines) - max_lines) B.lineOffset = off end
    for i = 1, max(max_lines, table.getn(f.lines)) do
      local e = i <= max_lines and lines[i + off]
      local l = Line(i)
      if e then
        l.label:SetText(e[1] or "")
        l.value:SetText(e[2] or "")
        l.value:ClearAllPoints()
        l.value:SetPoint("TOPRIGHT", f.panel, "TOPRIGHT", e.go and -20 or -8, -6 - (i - 1) * LINEH)
        if e.head then
          l.label:SetTextColor(ar, ag, ab)
          l.rule:SetVertexColor(ar, ag, ab, .45)
          l.rule:Show()
        else
          l.rule:Hide()
          if e.go then l.label:SetTextColor(.5, .75, 1) else l.label:SetTextColor(.85, .85, .85) end
        end
        if not e.head and math.mod(i, 2) == 0 then l.zebra:Show() else l.zebra:Hide() end
        l.label:Show()
        l.value:Show()
        if e.go then l.arrow:Show() else l.arrow:Hide() end
        l.btn.go = e.go
        l.btn.title = e[1]
        l.btn.tip = e.tip or (e.go and ("Click: open " .. Strip(e[1]))) or nil
        if e.go or e.tip then l.btn:Show() else l.btn:Hide() end
      else
        l.label:Hide()
        l.value:Hide()
        l.arrow:Hide()
        l.rule:Hide()
        l.zebra:Hide()
        l.btn:Hide()
      end
    end
    B.linesShown = lines
  end

  local function Sorted(tbl, field)
    local out = {}
    for name, v in pairs(tbl or {}) do
      local x = field and v[field] or v
      if type(x) == "number" then table.insert(out, { name = name, v = x, data = v }) end
    end
    table.sort(out, function(x, y) return x.v > y.v end)
    return out
  end

  -- ---------------------------------------------------------------- links

  local function Seg() return B.seg end
  -- a name as a link: a player of the fight, an enemy, or nothing
  local function Link(name)
    local seg = Seg()
    if not seg or not name then return end
    if seg.actors and seg.actors[name] then return function() B.Open({ actor = seg.actors[name] }) end end
    if seg.foes and seg.foes[name] then return function() B.Open({ foe = name }) end end
  end
  B.Link = Link
  local function Named(name)
    if Link(name) then return LINK .. name .. "|r" end
    return name
  end
  -- "Spell - Source": the source part
  local function SourceOf(label)
    local _, _, spell, who = string.find(label or "", "^(.-) %- (.+)$")
    return spell or label, who
  end

  -- ---------------------------------------------------------------- player tabs

  -- the spells of an actor: list, total, heal?
  local function SpellsOf(a, mode)
    if mode == "taken" then return a.tspells, a.taken end
    if mode == "ff" then return a.ffspells or {}, a.ff or 0 end
    if mode == "heal" or HEALMODES[mode] then return a.hspells, a.heal, true end
    return a.spells, a.damage
  end
  local function TargetsOf(a, mode)
    if mode == "taken" then return a.sources, a.taken, "Damaged by" end
    if mode == "htaken" then return a.hsources or {}, a.htaken or 0, "Healed by" end
    if mode == "ff" then return a.fftargets or {}, a.ff or 0, "Hit" end
    if mode == "heal" or HEALMODES[mode] then return a.htargets, a.heal, "Healed" end
    return a.targets, a.damage, "Targets"
  end
  B.SpellsOf, B.TargetsOf = SpellsOf, TargetsOf
  local function Kind() return B.kind or "damage" end

  -- one spell in detail (right panel)
  local function SpellLines(name, s, total, heal)
    local lines = { { name, "", head = true } }
    local n = s.hits + s.ticks
    table.insert(lines, { heal and "Healed" or "Damage", Num(s.total) .. "  (" .. Pct(s.total, total) .. ")" })
    if B.active and B.active > 0 then table.insert(lines, { heal and "HPS" or "DPS", Num(s.total / B.active) }) end
    if s.hits > 0 then
      local crits = s.crits or 0
      local ctotal = s.ctotal or 0
      local normal = s.hits - crits
      -- (ticks apart: they are not hits)
      local ntotal = s.total - ctotal - (s.ttotal or 0)
      table.insert(lines, { "Hits", s.hits })
      table.insert(lines, { "  Normal", normal .. "   avg " .. Avg(max(0, ntotal), normal) })
      table.insert(lines, { "  Critical", crits .. "  (" .. Pct(crits, s.hits) .. ")   avg " .. Avg(ctotal, crits) })
      if s.cmax then table.insert(lines, { "  Biggest crit", Num(s.cmax) }) end
      table.insert(lines, { "  Smallest / biggest", (s.min and Num(s.min) or "-") .. " / " .. Num(s.max) })
    end
    if s.ticks > 0 then table.insert(lines, { "Ticks", s.ticks .. "   avg " .. Avg(s.ttotal or s.total, s.ticks) }) end
    if heal then
      table.insert(lines, { "Overhealing", Num(s.over or 0) .. "  (" .. Pct(s.over or 0, s.total + (s.over or 0)) .. ")" })
    elseif s.misses > 0 then
      table.insert(lines, { "Missed", s.misses .. "  (" .. Pct(s.misses, n + s.misses) .. ")" })
      for how, count in pairs(s.how or {}) do
        if how ~= "glancing" and how ~= "crushing" then table.insert(lines, { "  " .. how, count }) end
      end
    end
    if s.how and s.how.glancing then table.insert(lines, { "Glancing", s.how.glancing }) end
    if s.how and s.how.crushing then table.insert(lines, { "Crushing", s.how.crushing }) end
    if s.targets then
      table.insert(lines, { " ", "" })
      table.insert(lines, { "Targets", "", head = true })
      local list = Sorted(s.targets)
      for i = 1, min(8, table.getn(list)) do
        table.insert(lines, { list[i].name, Num(list[i].v) .. "  (" .. Pct(list[i].v, s.total) .. ")", go = Link(list[i].name) })
      end
    end
    return lines
  end
  B.SpellLines = SpellLines

  local function Summary(a, seg)
    local fight = seg and M.Duration(seg) or 1
    local act = max(1, a.active or 0)
    local function Go(tab, kind) return function() B.kind = kind or B.kind B.tab = tab B.offset = 0 B.Draw() end end
    local lines = { { "Damage and healing", "", head = true },
      { "Damage done", Num(a.damage) .. "   (" .. Num(a.damage / act) .. " dps)", go = Go("spells", "damage"),
        tip = "All damage they did, and per second of their active time. Click: the spells." },
      { "Healing done", Num(a.heal) .. "   (" .. Num(a.heal / act) .. " hps)", go = Go("spells", "heal"),
        tip = "Healing that actually healed something. Click: the spells." },
      { "Overhealing", Num(a.overheal) .. "  (" .. Pct(a.overheal, a.heal + a.overheal) .. ")", go = Go("spells", "heal"),
        tip = "Healing that was more than the target was missing. A little is normal; a lot means heals went to waste." },
      { "Damage taken", Num(a.taken), go = Go("taken"), tip = "All damage that hit them. Click: what it was and who made it." },
      { "Healing taken", Num(a.htaken or 0), go = Go("taken"), tip = "Healing others did on them. Click: who healed them." },
      { "Friendly fire", Num(a.ff or 0), go = Go("spells", "ff"), tip = "Damage they did to their own group (it is not counted as damage done)." },
      { "Time", "", head = true },
      { "Fight", Clock(fight) },
      { "Active", Clock(act) .. "  (" .. Pct(min(act, fight), fight) .. ")", go = Go("chart"),
        tip = "How long they were attacking, healing or casting (gaps over a few seconds do not count). Click: the chart." },
      { "Utility", "", head = true },
      { "Interrupts / dispels", (a.interrupts or 0) .. " / " .. (a.dispels or 0), go = Go("utility"),
        tip = "Spells they stopped, and effects they removed. Click: each one, with what it was." },
      { "Cooldowns used", a.cds or 0, go = Go("casts"), tip = "Big cooldowns they pressed. Click: when." },
      { "Resurrects", a.ress or 0, go = Go("casts"), tip = "Players they brought back. Click: who and when." },
      { "Kills / deaths", (a.frags or 0) .. " / " .. (a.deaths or 0), go = Go((a.deaths or 0) > 0 and "deaths" or "utility"),
        tip = "Kills they landed the last blow on, and times they died. Click: the death log." },
      { "Casts", a.ncasts or 0, go = Go("casts"), tip = "Every spell they cast. Click: the list." },
      { "Buff / debuff uptime", Clock(a.buffsum or 0) .. " / " .. Clock(a.debuffsum or 0), go = Go("auras"),
        tip = "How long buffs were on them, and how long their debuffs were on enemies. Click: each aura." },
    }
    -- resources gained
    for pow, v in pairs(a.power or {}) do table.insert(lines, { pow .. " gained", Num(v), go = Go("utility") }) end
    FillLines(lines)
    -- the left: top spells of the window's kind
    local spells, total = SpellsOf(a, Kind())
    local list = {}
    for _, e in ipairs(Sorted(spells, "total")) do
      local name = e.name
      table.insert(list, { name = name, spell = true, value = e.v, text = Num(e.v) .. "  " .. Pct(e.v, total),
        onclick = function() B.spell = name B.tab = "spells" B.Draw() end })
    end
    FillList(list, list[1] and list[1].value)
  end

  local function Spells(a)
    local spells, total, heal = SpellsOf(a, Kind())
    local sorted = Sorted(spells, "total")
    if not B.spell or not spells[B.spell] then B.spell = sorted[1] and sorted[1].name end
    local list = {}
    for _, e in ipairs(sorted) do
      local name = e.name
      local s = e.data
      table.insert(list, { name = name, spell = true, value = e.v,
        text = Num(e.v) .. "  " .. Pct(e.v, total) .. "  |cff888888" .. (s.hits + s.ticks) .. "x|r",
        selected = name == B.spell, onclick = function() B.spell = name B.lineOffset = 0 B.Draw() end })
    end
    FillList(list, sorted[1] and sorted[1].v)
    if B.spell and spells[B.spell] then FillLines(SpellLines(B.spell, spells[B.spell], total, heal)) else FillLines({ { "Nothing here in this fight.", "" } }) end
  end

  local function Targets(a)
    local tbl, total, title = TargetsOf(a, Kind())
    local spells = SpellsOf(a, Kind())
    local sorted = Sorted(tbl)
    if not B.target or not tbl[B.target] then B.target = sorted[1] and sorted[1].name end
    local list = {}
    for _, e in ipairs(sorted) do
      local name = e.name
      table.insert(list, { name = name, link = Link(name) and true, value = e.v, text = Num(e.v) .. "  " .. Pct(e.v, total),
        selected = name == B.target, onclick = function() B.target = name B.lineOffset = 0 B.Draw() end })
    end
    FillList(list, list[1] and list[1].value)
    local lines = { { title, "", head = true }, { "Total", Num(total) }, { "How many", table.getn(list) } }
    local t = B.target
    if t then
      table.insert(lines, { " ", "" })
      table.insert(lines, { t, "", head = true })
      local go = Link(t)
      if go then table.insert(lines, { "Open " .. t, "", go = go }) end
      -- which of this player's spells went there
      local by = {}
      for sname, s in pairs(spells or {}) do
        if s.targets and s.targets[t] then by[sname] = s.targets[t] end
      end
      for _, e in ipairs(Sorted(by)) do table.insert(lines, { "  " .. e.name, Num(e.v) }) end
      -- everyone else on that enemy
      local foe = B.seg and B.seg.foes and B.seg.foes[t]
      if foe and foe.from then
        table.insert(lines, { "Everyone on " .. t, "", head = true })
        for _, e in ipairs(Sorted(foe.from)) do
          table.insert(lines, { e.name, Num(e.v) .. "  (" .. Pct(e.v, foe.taken) .. ")", go = Link(e.name) })
        end
      end
    end
    FillLines(lines)
  end

  local function Taken(a)
    local sorted = Sorted(a.tspells, "total")
    if not B.spell or not a.tspells[B.spell] then B.spell = sorted[1] and sorted[1].name end
    local list = {}
    for _, e in ipairs(sorted) do
      local name = e.name
      local spell, who = SourceOf(name)
      table.insert(list, { icon = SpellIcon(spell), spell = true, name = spell .. "  |cff888888" .. (who or "") .. "|r", value = e.v,
        text = Num(e.v) .. "  " .. Pct(e.v, a.taken) .. "  |cff888888" .. e.data.hits .. "x|r", color = { .7, .25, .25 },
        selected = name == B.spell, onclick = function() B.spell = name B.lineOffset = 0 B.Draw() end })
    end
    FillList(list, sorted[1] and sorted[1].v)
    local lines = {}
    if B.spell and a.tspells[B.spell] then
      local s = a.tspells[B.spell]
      local spell, who = SourceOf(B.spell)
      table.insert(lines, { spell, "", head = true })
      table.insert(lines, { "From", who and Named(who) or "?", go = Link(who) })
      table.insert(lines, { "Damage", Num(s.total) .. "  (" .. Pct(s.total, a.taken) .. ")" })
      table.insert(lines, { "Hits / biggest", s.hits .. " / " .. Num(s.max) })
      table.insert(lines, { " ", "" })
    end
    table.insert(lines, { "Damaged by", Num(a.taken), head = true })
    for _, e in ipairs(Sorted(a.sources)) do
      table.insert(lines, { e.name, Num(e.v) .. "  (" .. Pct(e.v, a.taken) .. ")", go = Link(e.name) })
    end
    if next(a.avoid or {}) then
      table.insert(lines, { "Avoided", "", head = true })
      for how, n in pairs(a.avoid) do table.insert(lines, { "  " .. how, n }) end
    end
    if (a.htaken or 0) > 0 then
      table.insert(lines, { "Healed by", Num(a.htaken), head = true })
      for _, e in ipairs(Sorted(a.hsources)) do
        table.insert(lines, { e.name, Num(e.v) .. "  (" .. Pct(e.v, a.htaken) .. ")", go = Link(e.name) })
      end
    end
    FillLines(lines)
  end

  local function Casts(a)
    local sorted = Sorted(a.casts)
    local list = {}
    for _, e in ipairs(sorted) do
      local name = e.name
      -- a spell with numbers opens its detail
      local kind = (a.spells and a.spells[name] and "damage") or (a.hspells and a.hspells[name] and "heal")
      table.insert(list, { name = name, spell = true, value = e.v, text = e.v .. "  " .. Pct(e.v, a.ncasts or 0),
        tip = kind and "Click: its numbers" or nil,
        onclick = kind and function() B.kind = kind B.spell = name B.tab = "spells" B.Draw() end or nil })
    end
    FillList(list, sorted[1] and sorted[1].v)
    local start = B.seg and B.seg.start or 0
    local lines = { { "Casts", (a.ncasts or 0) .. "  (" .. table.getn(sorted) .. " spells)", head = true } }
    table.insert(lines, { "Cooldowns used", a.cds or 0, head = true })
    for _, c in ipairs(a.cdlist or {}) do
      table.insert(lines, { Clock(c.t - start) .. "  " .. c.spell, c.target and Named(c.target) or "", go = Link(c.target) })
    end
    table.insert(lines, { "Resurrects", a.ress or 0, head = true })
    for _, c in ipairs(a.resslist or {}) do
      table.insert(lines, { Clock(c.t - start) .. "  " .. c.spell, c.target and Named(c.target) or "", go = Link(c.target) })
    end
    FillLines(lines)
  end

  local function Auras(a, seg)
    local fight = seg and M.Duration(seg) or 1
    local list = {}
    for _, e in ipairs(Sorted(a.buffs)) do
      table.insert(list, { name = e.name, value = e.v, text = Clock(e.v) .. "  " .. Pct(min(e.v, fight), fight), color = { .3, .7, .35 } })
    end
    for _, e in ipairs(Sorted(a.debuffs)) do
      table.insert(list, { name = e.name .. "  |cff888888(on enemies)|r", value = e.v, text = Clock(e.v) .. "  " .. Pct(min(e.v, fight), fight),
        color = { .6, .3, .7 } })
    end
    FillList(list, fight)
    FillLines({ { "Uptime", "", head = true },
      { "Buffs on " .. a.name, Clock(a.buffsum or 0) },
      { "Debuffs from " .. a.name, Clock(a.debuffsum or 0) },
      { "Fight", Clock(fight) },
      { " ", "" },
      { "Green: buffs on them, purple: their debuffs on enemies. Bars are % of the fight.", "" } })
  end

  local function Utility(a, seg)
    local start = seg and seg.start or 0
    local list = {}
    for _, e in ipairs(a.ilist or {}) do
      local tgt = e.target
      table.insert(list, { name = Clock(e.t - start) .. "  Interrupted " .. (e.spell or "?") .. " on " .. Named(tgt or "?"), value = 1,
        text = e.with and ("with " .. e.with) or "", color = { .9, .6, .2 }, onclick = Link(tgt) })
    end
    for _, e in ipairs(a.dlist or {}) do
      local tgt = e.target
      table.insert(list, { name = Clock(e.t - start) .. "  Removed " .. (e.aura or "?") .. " from " .. Named(tgt or "?"), value = 1,
        text = e.with and ("with " .. e.with) or "", color = { .3, .6, .9 }, onclick = Link(tgt) })
    end
    for _, e in ipairs(a.fraglist or {}) do
      local tgt = e.target
      table.insert(list, { name = Clock(e.t - start) .. "  Killed " .. Named(tgt or "?"), value = 1, text = "",
        color = { .7, .2, .2 }, onclick = Link(tgt) })
    end
    for _, e in ipairs(a.resslist or {}) do
      local tgt = e.target
      table.insert(list, { name = Clock(e.t - start) .. "  Resurrected " .. Named(tgt or "?"), value = 1, text = e.spell or "",
        color = { .3, .8, .4 }, onclick = Link(tgt) })
    end
    if table.getn(list) == 0 then table.insert(list, { name = "No interrupts, dispels, kills or resurrects in this fight.", value = 0 }) end
    FillList(list, 1)
    local lines = { { "Interrupts / dispels / kills", (a.interrupts or 0) .. " / " .. (a.dispels or 0) .. " / " .. (a.frags or 0), head = true } }
    for pow, v in pairs(a.power or {}) do
      table.insert(lines, { pow .. " gained", Num(v), head = true })
      for _, e in ipairs(Sorted(a.psources and a.psources[pow])) do table.insert(lines, { "  " .. e.name, Num(e.v) }) end
    end
    if (a.ff or 0) > 0 then
      table.insert(lines, { "Friendly fire", Num(a.ff), head = true })
      for _, e in ipairs(Sorted(a.fftargets)) do table.insert(lines, { e.name, Num(e.v), go = Link(e.name) }) end
    end
    FillLines(lines)
  end

  -- the other players of this fight, for Compare
  local function Others(seg, a)
    local out = {}
    for name, o in pairs(seg and seg.actors or {}) do
      if o ~= a then table.insert(out, o) end
    end
    table.sort(out, function(x, y) return (x.damage + x.heal) > (y.damage + y.heal) end)
    return out
  end

  local function Compare(a, seg)
    local others = Others(seg, a)
    -- the same class first, else the biggest
    if not B.other or not seg.actors[B.other] or B.other == a.name then
      B.other = nil
      for _, o in ipairs(others) do if o.class == a.class then B.other = o.name break end end
      if not B.other and others[1] then B.other = others[1].name end
    end
    local o = B.other and seg.actors[B.other]
    if not o then
      FillList({}, 1)
      FillLines({ { "Nobody else in this fight to compare with.", "" } })
      return
    end
    local mine, mtotal = SpellsOf(a, Kind())
    local theirs, ttotal = SpellsOf(o, Kind())
    local names = {}
    for n in pairs(mine) do names[n] = true end
    for n in pairs(theirs) do names[n] = true end
    local list, top = {}, 1
    for n in pairs(names) do
      local x = mine[n] and mine[n].total or 0
      local y = theirs[n] and theirs[n].total or 0
      top = max(top, x, y)
      local gap = y > 0 and string.format("%+.0f%%", (x - y) / y * 100) or "new"
      local color = x >= y and "|cff66ff66" or "|cffff6666"
      table.insert(list, { name = n, spell = true, value = x, sort = max(x, y),
        text = Num(x) .. "  |cff888888vs|r " .. Num(y) .. "  " .. color .. gap .. "|r" })
    end
    table.sort(list, function(p, q) return p.sort > q.sort end)
    FillList(list, top)
    local lines = { { a.name .. "  vs  " .. o.name, "", head = true },
      { "Total", Num(mtotal) .. "  /  " .. Num(ttotal) },
      { "Per second", Num(mtotal / max(1, a.active or 0)) .. "  /  " .. Num(ttotal / max(1, o.active or 0)) },
      { "Active", Clock(a.active or 0) .. "  /  " .. Clock(o.active or 0) },
      { "Open " .. o.name, "", go = Link(o.name) },
      { " ", "" }, { "Compare with", "", head = true } }
    FillLines(lines)
    -- a list of the others to pick from, under the lines
    B.compareChoices = others
  end

  -- Chart: the player's damage (or healing) per second through the fight,
  -- as columns, with the group's in grey behind (Details' charts)
  f.chart = CreateFrame("Frame", nil, f)
  f.chart:SetPoint("TOPLEFT", f, "TOPLEFT", X0, -(HEAD + 10))
  f.chart:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
  CreateBackdrop(f.chart, nil, true, .5)
  f.chart.cols, f.chart.back = {}, {}
  f.chart.top = Text(f.chart, C.global.font_size - 1)
  f.chart.top:SetPoint("TOPLEFT", f.chart, "TOPLEFT", 6, -4)
  f.chart.right = Text(f.chart, C.global.font_size - 1, "RIGHT")
  f.chart.right:SetPoint("TOPRIGHT", f.chart, "TOPRIGHT", -6, -4)
  f.chart.bottom = Text(f.chart, C.global.font_size - 1)
  f.chart.bottom:SetPoint("BOTTOMLEFT", f.chart, "BOTTOMLEFT", 6, 4)
  f.chart.endtime = Text(f.chart, C.global.font_size - 1, "RIGHT")
  f.chart.endtime:SetPoint("BOTTOMRIGHT", f.chart, "BOTTOMRIGHT", -6, 4)
  f.chart:Hide()


  local function Column(list, i, parent)
    local c = list[i]
    if c then return c end
    c = parent:CreateTexture(nil, "ARTWORK")
    c:SetTexture("Interface\\Buttons\\WHITE8X8")
    list[i] = c
    return c
  end

  local function Chart(a, seg)
    local CHART_W, CHART_H = B.chartW or 700, B.chartH or 300
    local heal = Kind() == "heal"
    local mine = M.Curve and M.Curve(seg, a.name, heal) or {}
    local all = M.Curve and M.Curve(seg, nil, heal) or {}
    local n = table.getn(mine)
    local ch = f.chart
    for _, c in pairs(ch.cols) do c:Hide() end
    for _, c in pairs(ch.back) do c:Hide() end
    if n < 2 then
      ch.top:SetText("No chart for this fight yet (it is drawn from the fight's samples, one a second).")
      ch.right:SetText("")
      ch.bottom:SetText("")
      ch.endtime:SetText("")
      B.chartPoints = 0
      return
    end
    -- at most one column per 2 pixels: samples are bunched together
    local cols = min(n, floor(CHART_W / 2))
    local per = n / cols
    local top, peak, sum = 1, 0, 0
    local vm, va = {}, {}
    for i = 1, cols do
      local from, to = floor((i - 1) * per) + 1, max(floor((i - 1) * per) + 1, floor(i * per))
      local m, g = 0, 0
      for j = from, to do m, g = m + (mine[j] or 0), g + (all[j] or 0) end
      m, g = m / (to - from + 1), g / (to - from + 1)
      vm[i], va[i] = m, g
      top = max(top, m, g)
      peak = max(peak, m)
      sum = sum + m
    end
    local w = CHART_W / cols
    local r, g, b = cr, cg, cb
    for i = 1, cols do
      local bk = Column(ch.back, i, ch)
      bk:ClearAllPoints()
      bk:SetPoint("BOTTOMLEFT", ch, "BOTTOMLEFT", 8 + (i - 1) * w, 20)
      bk:SetWidth(max(1, w - 1))
      bk:SetHeight(max(1, va[i] / top * CHART_H))
      bk:SetVertexColor(1, 1, 1, .12)
      bk:Show()
      local col = Column(ch.cols, i, ch)
      col:ClearAllPoints()
      col:SetPoint("BOTTOMLEFT", ch, "BOTTOMLEFT", 8 + (i - 1) * w, 20)
      col:SetWidth(max(1, w - 1))
      col:SetHeight(max(1, vm[i] / top * CHART_H))
      col:SetVertexColor(r, g, b, .9)
      col:Show()
    end
    local what = heal and "healing" or "damage"
    ch.top:SetText(a.name .. ": " .. what .. " per second  (grey: the whole group)")
    ch.right:SetText("peak " .. Num(peak) .. "   average " .. Num(sum / cols) .. "   scale " .. Num(top))
    ch.bottom:SetText("0:00")
    ch.endtime:SetText(Clock(seg.timeline[n].t))
    B.chartPoints = cols
  end
  B.Chart = Chart

  local function Deaths(a, seg)
    local start = seg and seg.start or 0
    local deaths = a.deathlogs or {}
    if table.getn(deaths) == 0 then
      FillList({}, 1)
      FillLines({ { "No deaths in this fight.", "" } })
      return
    end
    B.death = min(B.death or 1, table.getn(deaths))
    local list = {}
    for i, d in ipairs(deaths) do
      local idx = i
      table.insert(list, { name = string.format("Death %d at %s", i, Clock(d.t - start)), value = 1,
        text = d.killer and ("by " .. Named(d.killer)) or "", color = { .6, .15, .15 },
        selected = i == B.death, onclick = function() B.death = idx B.Draw() end })
    end
    FillList(list, 1)
    -- the last hits and heals, newest last, with health
    local d = deaths[B.death]
    local lines = { { "Before death " .. B.death, "health", head = true } }
    if d.killer and Link(d.killer) then table.insert(lines, { "Killed by " .. d.killer, "", go = Link(d.killer) }) end
    for _, e in ipairs(d.log or {}) do
      local sign = e.kind == "heal" and "|cff66ff66+" or "|cffff6666-"
      local hp = (e.hp and e.hpmax and e.hpmax > 0) and floor(e.hp / e.hpmax * 100) .. "%" or ""
      table.insert(lines, { string.format("%4.1fs ", e.t - d.t) .. sign .. Num(e.amount) .. (e.crit and "*" or "") .. "|r " ..
        (e.spell or "") .. " |cff888888" .. (e.who or "") .. "|r", hp, go = Link(e.who) })
    end
    FillLines(lines)
  end

  -- ---------------------------------------------------------------- enemy and spell views

  local function FoeDraw(name, seg)
    local foe = seg and seg.foes and seg.foes[name]
    if not foe then
      FillList({}, 1)
      FillLines({ { name .. " is not in this fight.", "" } })
      return
    end
    local tab = B.tab
    local list, lines = {}, {}
    if tab == "fhitby" or tab == "fsummary" then
      for _, e in ipairs(Sorted(foe.from)) do
        local who = e.name
        local a = seg.actors[who]
        local c = a and a.class and RAID_CLASS_COLORS[a.class]
        table.insert(list, { name = who, link = Link(who) and true, value = e.v, text = Num(e.v) .. "  " .. Pct(e.v, foe.taken),
          color = c and { c.r, c.g, c.b }, onclick = Link(who) })
      end
    elseif tab == "fhit" then
      for _, e in ipairs(Sorted(foe.to)) do
        local who = e.name
        table.insert(list, { name = who, link = Link(who) and true, value = e.v, text = Num(e.v) .. "  " .. Pct(e.v, foe.done), onclick = Link(who),
          color = { .7, .25, .25 } })
      end
    elseif tab == "ftaken" then
      for _, e in ipairs(Sorted(foe.tspells, "total")) do
        local spell, who = SourceOf(e.name)
        table.insert(list, { icon = SpellIcon(spell), spell = true, name = spell .. "  |cff888888" .. (who or "") .. "|r", value = e.v,
          text = Num(e.v) .. "  " .. Pct(e.v, foe.taken), onclick = Link(who) })
      end
    else
      local sorted = Sorted(foe.dspells, "total")
      if not B.spell or not foe.dspells[B.spell] then B.spell = sorted[1] and sorted[1].name end
      for _, e in ipairs(sorted) do
        local sname = e.name
        table.insert(list, { name = sname, spell = true, value = e.v, text = Num(e.v) .. "  " .. Pct(e.v, foe.done), color = { .7, .25, .25 },
          selected = sname == B.spell, onclick = function() B.spell = sname B.Draw() end })
      end
      if B.spell and foe.dspells[B.spell] then
        local s = foe.dspells[B.spell]
        lines = { { B.spell, "", head = true }, { "Damage", Num(s.total) .. "  (" .. Pct(s.total, foe.done) .. ")" },
          { "Hits / biggest", s.hits .. " / " .. Num(s.max or 0) } }
        local b = seg.byspell and seg.byspell[B.spell]
        if b then
          table.insert(lines, { "Who it hit", "", head = true })
          for _, e in ipairs(Sorted(b.targets)) do table.insert(lines, { e.name, Num(e.v), go = Link(e.name) }) end
        end
      end
    end
    FillList(list, list[1] and list[1].value)
    if table.getn(lines) == 0 then
      lines = { { name, "", head = true },
        { "Damage taken", Num(foe.taken), go = function() B.tab = "fhitby" B.Draw() end },
        { "Damage done", Num(foe.done), go = function() B.tab = "fhit" B.Draw() end },
        { "Fight", Clock(M.Duration(seg)) } }
      if seg.boss == name then table.insert(lines, { "The boss of this fight", "" }) end
      table.insert(lines, { "Most damage on it", "", head = true })
      for i, e in ipairs(Sorted(foe.from)) do
        if i > 5 then break end
        table.insert(lines, { e.name, Num(e.v), go = Link(e.name) })
      end
      table.insert(lines, { "It hit most", "", head = true })
      for i, e in ipairs(Sorted(foe.to)) do
        if i > 5 then break end
        table.insert(lines, { e.name, Num(e.v), go = Link(e.name) })
      end
    end
    FillLines(lines)
  end

  local function SpellDraw(name, seg)
    local b = seg and seg.byspell and seg.byspell[name]
    if not b then
      FillList({}, 1)
      FillLines({ { name .. " did not hit anyone in this fight.", "" } })
      return
    end
    local list = {}
    local tbl = B.tab == "sfrom" and b.from or b.targets
    for _, e in ipairs(Sorted(tbl)) do
      local who = e.name
      table.insert(list, { name = who, link = Link(who) and true, value = e.v, text = Num(e.v) .. "  " .. Pct(e.v, b.total), onclick = Link(who),
        color = { .7, .25, .25 } })
    end
    FillList(list, list[1] and list[1].value)
    local lines = { { name, "", head = true }, { "Damage on your group", Num(b.total) }, { "Hits / biggest", b.hits .. " / " .. Num(b.max) },
      { "Cast by", "", head = true } }
    for _, e in ipairs(Sorted(b.from)) do table.insert(lines, { e.name, Num(e.v), go = Link(e.name) }) end
    FillLines(lines)
  end

  -- ---------------------------------------------------------------- open / draw

  -- the window's look on the breakdown: bar texture, font, background, border
  local function Look()
    local s = B.win and M.S and M.S(B.win)
    if not s then return end
    texture = (s.texture and s.texture ~= "") and s.texture or texture
    local font = (s.font and s.font ~= "") and s.font or pfUI.font_default
    local outline = s.outline == "NONE" and "" or (s.outline or "OUTLINE")
    local size = tonumber(s.fontsize) or C.global.font_size
    for _, t in ipairs(texts) do t:SetFont(font, max(8, t.base + (size - C.global.font_size)), outline) end
    if f.backdrop and M.Col then
      f.backdrop:SetBackdropColor(M.Col(s.bg, "0,0,0,0.85"))
      f.backdrop:SetBackdropBorderColor(M.Col(s.bordercolor, "0,0,0,1"))
    end
  end
  B.Look = Look

  -- the rail's views, each with its picture and a sentence for the tooltip
  local function Tabs(set)
    for i, b in ipairs(f.tabs) do
      local t = set[i]
      if t then
        b.key = t[1]
        b.text:SetText(t[2])
        local info = B.TABINFO[t[1]]
        b.ico:SetTexture(ICON .. (info and info[1] or "INV_Misc_QuestionMark"))
        b.tip = t[2] .. "\n" .. (info and info[2] or "")
        Lit(b, b.key == B.tab)
        b:Show()
      else
        b:Hide()
      end
    end
  end

  -- the figures over the list (a player): each one opens the view it comes from
  local function Tiles(a, seg)
    local fight = seg and M.Duration(seg) or 1
    local act = max(1, a.active or 0)
    local function Go(tab, kind) return function() B.kind = kind or B.kind B.tab = tab B.offset = 0 B.spell = nil B.Draw() end end
    local defs = {
      { "DAMAGE", Num(a.damage), Num(a.damage / act) .. " dps", "spells", "damage", "Damage done\nTotal and per second. Click for the spells." },
      { "HEALING", Num(a.heal), Num(a.heal / act) .. " hps", "spells", "heal", "Healing done\nTotal and per second. Click for the spells." },
      { "TAKEN", Num(a.taken), Num(a.htaken or 0) .. " healed", "taken", nil, "Damage taken\nAnd what healed them. Click for what hit them." },
      { "ACTIVE", Clock(act), Pct(min(act, fight), fight), "chart", nil, "Active time\nHow long they were doing something, and the share of the fight. Click for the chart." },
      { "DEATHS", tostring(a.deaths or 0), (a.frags or 0) .. " kills", (a.deaths or 0) > 0 and "deaths" or "utility", nil,
        "Deaths and kills\nClick for the death log (or the utility view when there is none)." },
    }
    local ar, ag, ab = GetAccentColor()
    for i, d in ipairs(defs) do
      local t = f.tiles[i]
      t.label:SetText(d[1])
      t.value:SetText(d[2])
      t.sub:SetText(d[3])
      t.tip = d[6]
      t.go = Go(d[4], d[5])
      local on = (d[4] == B.tab) and (not d[5] or d[5] == Kind())
      if on then t.line:SetVertexColor(ar, ag, ab, 1) t.line:Show() else t.line:Hide() end
    end
  end

  function B.Draw()
    local seg = M.Segment(B.segment)
    B.seg = seg
    Look()
    PaintGroups()
    local mode = MODE[B.mode] or MODE.damage
    local segname = gsub(M.SegmentName and M.SegmentName(B.segment) or "", "|c%x%x%x%x%x%x%x%x", "")
    segname = gsub(segname, "|r", "")
    if B.stack and table.getn(B.stack) > 0 then f.back:Show() else f.back:Hide() end
    f.icon:Hide()
    cr, cg, cb = .6, .6, .6
    local ar, ag, ab = GetAccentColor()
    f.rule:SetVertexColor(ar, ag, ab, .8)

    -- an enemy, or a spell that hit the group
    if B.foe or B.bspell then
      local set = B.foe and B.FOETABS or B.SPELLTABS
      local ok = false
      for _, t in ipairs(set) do if t[1] == B.tab then ok = true end end
      if not ok then B.tab = set[1][1] end
      Tabs(set)
      LayoutBody(false, false)
      f.name:SetText(B.foe or B.bspell)
      f.name:SetTextColor(1, .45, .45)
      f.who:SetWidth(max(80, (f.name:GetStringWidth() or 60) + 14))
      f.sub:SetText((B.foe and "enemy" or "spell on your group") .. "  -  " .. segname)
      local tex = B.foe and "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" or SpellIcon(B.bspell)
      if tex then
        f.icon:SetTexture(tex)
        f.icon:SetTexCoord(B.foe and 0 or .08, B.foe and 1 or .92, B.foe and 0 or .08, B.foe and 1 or .92)
        f.icon:Show()
      end
      f.chart:Hide()
      f.list:Show()
      f.panel:Show()
      if B.foe then FoeDraw(B.foe, seg) else SpellDraw(B.bspell, seg) end
      f:Show()
      return
    end

    local a = B.actor
    if not a then return end
    -- the actor of this segment (the test fight, a newer fight)
    if seg and seg.actors and seg.actors[a.name] then a = seg.actors[a.name] B.actor = a end
    if not B.kind then B.kind = HEALMODES[B.mode] and "heal" or (B.mode == "ff" and "ff" or "damage") end
    B.active = max(1, a.active or 0)
    local ok = false
    for _, t in ipairs(B.TABS) do if t[1] == B.tab then ok = true end end
    if not ok then B.tab = "spells" end
    Tabs(B.TABS)
    -- header
    local coords = a.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[a.class]
    if coords then
      f.icon:SetTexture(pfUI.media["img:classicons"])
      f.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
      f.icon:Show()
    end
    local c = a.class and RAID_CLASS_COLORS[a.class]
    f.name:SetText(a.name)
    if c then f.name:SetTextColor(c.r, c.g, c.b) cr, cg, cb = c.r, c.g, c.b else f.name:SetTextColor(1, 1, 1) end
    f.who:SetWidth(max(80, (f.name:GetStringWidth() or 60) + 14))
    f.sub:SetText(mode.name .. "  -  " .. segname)
    -- damage / healing / friendly fire switch on the tabs that use it
    local kinds = KINDTABS[B.tab]
    for _, k in ipairs(f.kinds) do Lit(k, k.key == Kind()) end
    LayoutBody(true, kinds)
    Tiles(a, seg)
    -- the chart takes the whole body
    if B.tab == "chart" then
      f.list:Hide()
      f.panel:Hide()
      f.chart:Show()
    else
      f.chart:Hide()
      f.list:Show()
      f.panel:Show()
    end
    if B.tab == "summary" then Summary(a, seg)
    elseif B.tab == "chart" then Chart(a, seg)
    elseif B.tab == "targets" then Targets(a)
    elseif B.tab == "taken" then Taken(a)
    elseif B.tab == "casts" then Casts(a)
    elseif B.tab == "auras" then Auras(a, seg)
    elseif B.tab == "utility" then Utility(a, seg)
    elseif B.tab == "compare" then Compare(a, seg)
    elseif B.tab == "deaths" then Deaths(a, seg)
    else Spells(a) end
    f:Show()
  end

  -- what is open now, for Back
  local function Current() return { actor = B.actor, foe = B.foe, bspell = B.bspell, tab = B.tab, kind = B.kind } end
  local function Show(v)
    B.actor, B.foe, B.bspell = v.actor, v.foe, v.bspell
    B.tab = v.tab or (v.foe and "fsummary") or (v.bspell and "ssummary") or B.tab
    if v.kind then B.kind = v.kind end
    B.offset, B.lineOffset, B.spell, B.target, B.death = 0, 0, nil, nil, nil
    B.Draw()
  end
  -- open a player, an enemy or a spell from a link (Back returns)
  function B.Open(v)
    table.insert(B.stack, Current())
    if table.getn(B.stack) > 30 then table.remove(B.stack, 1) end
    if v.actor and not v.tab then v.tab = (B.tab and not B.foe and not B.bspell) and B.tab or "summary" end
    Show(v)
  end
  function B.Back()
    local v = table.remove(B.stack)
    if v then Show(v) end
  end

  -- the tab that fits what the window shows
  local FIRSTTAB = { deaths = "deaths", taken = "taken", htaken = "taken", interrupts = "utility", dispels = "utility",
    frags = "utility", ress = "casts", cooldowns = "casts", buffs = "auras", debuffs = "auras", mana = "utility",
    rage = "utility", energy = "utility" }
  B.FIRSTTAB = FIRSTTAB

  -- a click on a bar opens it
  local ShowSimple = M.ShowDetails
  M.ShowDetails = function(win, row)
    if not row then return end
    B.win, B.row = win, row
    B.mode = win.mode
    B.segment = win.segment
    B.stack = {}
    B.kind = nil
    B.offset, B.lineOffset, B.spell, B.target, B.death = 0, 0, nil, nil, nil
    if row.actor then
      B.actor, B.foe, B.bspell = row.actor, nil, nil
      -- (the last player tab stays, unless the window says otherwise)
      local keep
      for _, t in ipairs(B.TABS) do if t[1] == B.tab and t[1] ~= "deaths" then keep = B.tab end end
      B.tab = FIRSTTAB[win.mode] or keep or "spells"
    elseif row.foe then
      B.actor, B.foe, B.bspell = nil, row.name, nil
      B.tab = win.mode == "enemydone" and "fhit" or "fsummary"
    elseif row.byspell then
      B.actor, B.foe, B.bspell = nil, nil, row.name
      B.tab = "ssummary"
    else
      return ShowSimple(win, row)
    end
    B.Draw()
  end

  -- < >: the next row of the window's list
  function B.Step(dir)
    if not B.win then return end
    local rows = M.Rows(B.mode, B.segment)
    for i, r in ipairs(rows) do
      local same = (B.actor and r.actor and r.actor.name == B.actor.name) or (B.foe and r.foe and r.name == B.foe)
        or (B.bspell and r.byspell and r.name == B.bspell)
      if same then
        local n = rows[i + dir]
        if n then
          if n.actor then B.actor, B.foe, B.bspell = n.actor, nil, nil
          elseif n.foe then B.actor, B.foe, B.bspell = nil, n.name, nil
          elseif n.byspell then B.actor, B.foe, B.bspell = nil, nil, n.name end
          B.offset, B.lineOffset, B.spell, B.target = 0, 0, nil, nil
          B.Draw()
        end
        return
      end
    end
  end

  -- everyone in the fight / every enemy, as menus
  function B.PeopleMenu(anchor)
    local seg = B.seg
    if not seg or not M.ShowMenu then return end
    local items = { { "Players in this fight", head = true } }
    local list = {}
    for name, a in pairs(seg.actors or {}) do table.insert(list, a) end
    table.sort(list, function(x, y) return (x.damage + x.heal) > (y.damage + y.heal) end)
    for _, a in ipairs(list) do
      local actor = a
      local c = a.class and RAID_CLASS_COLORS[a.class]
      local label = c and string.format("|cff%02x%02x%02x%s|r", floor(c.r * 255), floor(c.g * 255), floor(c.b * 255), a.name) or a.name
      table.insert(items, { label .. "  |cff888888" .. Num(a.damage) .. " / " .. Num(a.heal) .. "|r",
        function() B.Open({ actor = actor }) end, checked = B.actor and B.actor.name == a.name })
    end
    M.ShowMenu(anchor, items)
  end
  function B.FoeMenu(anchor)
    local seg = B.seg
    if not seg or not M.ShowMenu then return end
    local items = { { "Enemies in this fight", head = true } }
    for _, e in ipairs(Sorted(seg.foes, "taken")) do
      local name = e.name
      table.insert(items, { name .. "  |cff888888" .. Num(e.v) .. "|r", function() B.Open({ foe = name }) end, checked = B.foe == name })
    end
    if table.getn(items) == 1 then table.insert(items, { "No enemies in this fight", head = true }) end
    M.ShowMenu(anchor, items)
  end

  -- Compare: pick the other player
  f.pick = Button(f.panel, "Pick player...", 120, function()
    local items = { { "Compare with", head = true } }
    for _, o in ipairs(B.compareChoices or {}) do
      local name = o.name
      table.insert(items, { name, function() B.other = name B.Draw() end, checked = name == B.other })
    end
    M.ShowMenu(this, items)
  end)
  f.pick:SetPoint("BOTTOMLEFT", f.panel, "BOTTOMLEFT", 8, 8)
  f.pick:Hide()
  local draw = B.Draw
  B.Draw = function()
    draw()
    if B.actor and not B.foe and not B.bspell and B.tab == "compare" and B.compareChoices and table.getn(B.compareChoices) > 0 then
      f.pick:Show()
    else
      f.pick:Hide()
    end
  end

  -- ---------------------------------------------------------------- report

  -- what the open tab shows, as chat lines (top 10)
  -- (21 Nov 2026, Wolfahrt: Lua error reporting a death log) bracketed: gsub's count came along as a second value
  -- and table.insert(out, text, count) read the text as a position. Any other | left would make the client refuse
  -- the chat line, so those go too.
  local function Plain(s)
    local t = gsub(gsub(tostring(s or ""), "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
    return (gsub(t, "|", ""))
  end
  function B.ReportLines()
    local title = B.actor and B.actor.name or B.foe or B.bspell
    if not title then return {} end
    local mode = MODE[B.mode] or MODE.damage
    local out = { "pfUI Octo - " .. title .. " - " .. mode.name .. " (" .. B.tab .. ")" }
    if B.tab == "summary" or B.tab == "deaths" or B.tab == "fsummary" then
      for _, l in ipairs(B.linesShown or {}) do
        if not l.head and l[1] and l[1] ~= " " then
          table.insert(out, Plain(l[1] .. "  " .. tostring(l[2] or "")))
        end
        if table.getn(out) > 12 then break end
      end
    else
      for i, e in ipairs(B.listShown or {}) do
        if i > (tonumber(C.meters.reportlines) or 10) then break end
        table.insert(out, i .. ". " .. Plain(e.name) .. "  " .. Plain(e.text))
      end
    end
    return out
  end

  function B.Report(channel, whisper)
    for _, line in ipairs(B.ReportLines()) do SendChatMessage(line, channel, nil, whisper) end
  end

  function B.ReportMenu(anchor)
    local items = { { "Report this tab", head = true },
      { "Say", function() B.Report("SAY") end },
      { "Party", function() B.Report("PARTY") end },
      { "Raid", function() B.Report("RAID") end },
      { "Guild", function() B.Report("GUILD") end },
      { "Officer", function() B.Report("OFFICER") end } }
    -- (ClassicAPI) the same text on the Windows clipboard, to paste into Discord or a forum
    if M.CanCopy and M.CanCopy() then
      table.insert(items, { "Copy to the clipboard", function()
        local lc = pfUI.api and pfUI.api.libclient
        if lc and lc.Copy and lc.Copy(table.concat(B.ReportLines(), "\n"), true) then
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: the report is on your clipboard - paste it with Ctrl+V.")
        end
      end })
    end
    if UnitIsPlayer("target") and UnitIsFriend("player", "target") then
      local name = UnitName("target")
      table.insert(items, { "Whisper " .. name, function() B.Report("WHISPER", name) end })
    end
    M.ShowMenu(anchor, items)
  end
end)
