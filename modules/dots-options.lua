pfUI:RegisterModule("dots-options", "vanilla", function ()
  -- pfUI Octo :: the DoT Tracker section (16 Nov 2026, modules/dots.lua). The user sent screenshots of
  -- Cursive-Raid's six tabs: "im sure we can do alot better but these should still be there". So the pages
  -- are Cursive's tabs - General, Raid, Class, Display, Filter, Profiles - with every one of its options,
  -- in our cards, plus a live preview drawn by the real row code (click a row for its settings).
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local D = pfUI.dots
  local SO = {}
  pfUI.dotsOcto = SO

  local function G() return C.dots end
  local function Up()
    if D then D.ApplyLayout() end
    if SO.Layout then SO.Layout() end
  end
  local function Chk(p, label, desc, key) return O.PfChk(p, label, desc, G, key, Up) end
  local function Sld(p, label, desc, min, max, step, key, fmt) return O.PfSld(p, label, desc, min, max, step, G, key, Up, fmt) end
  local function Drop(p, label, desc, options, key)
    return W.Dropdown(p, label, desc, options, function() return C.dots[key] end, function(v) C.dots[key] = v Up() end)
  end
  local function Px(v) return v .. " px" end
  local function Pct(v) return math.floor(v * 100 + .5) .. "%" end
  local function Sec(v) return v .. " s" end
  local function X(v) return string.format("%.2f", v) .. "x" end
  local ICON = "Interface\\Icons\\"

  local function Off(p)
    W.Heading(p, "DoT Tracker", { on = O.ModuleSwitch("dots", "DoT Tracker"), about = "The DoT Tracker is off. Switch it on "
      .. "here (it takes a reload), then its pages fill in." })
    W.Note(p, "The DoT Tracker is switched off. Click the switch above, close the options and reload.")
  end

  -- the borders, timer and stack colour words
  local BORDERS = { { key = "off", label = "Off" }, { key = "green", label = "Green" }, { key = "red", label = "Red" },
                    { key = "black", label = "Black" }, { key = "classcolor", label = "Class colour" } }
  local TEXTCOL = { { key = "none", label = "None (hidden)" }, { key = "white", label = "White" }, { key = "yellow", label = "Yellow" },
                    { key = "classcolor", label = "Class colour" } }
  local DECCOL = { { key = "none", label = "Same as the timer" }, { key = "white", label = "White" }, { key = "red", label = "Red" } }
  local SLOTS = { { key = "ownclass", label = "Own class debuffs" }, { key = "ownraid", label = "Own raid debuffs" },
                  { key = "otherclass", label = "Other class debuffs" }, { key = "otherraid", label = "Other raid debuffs" },
                  { key = "none", label = "Nothing" } }
  local SIDE = { { key = "none", label = "Nothing (all beside the bar)" }, { key = "ownclass", label = "Own class debuffs" },
                 { key = "ownraid", label = "Own raid debuffs" }, { key = "otherclass", label = "Other class debuffs" },
                 { key = "otherraid", label = "Other raid debuffs" } }
  local CLASSHEX = { WARRIOR = "c79c6e", ROGUE = "fff569", HUNTER = "abd473", MAGE = "69ccf0", WARLOCK = "9482c9",
                     PRIEST = "ffffff", DRUID = "ff7d0a", SHAMAN = "0070de", PALADIN = "f58cba", ITEM = "a0a0a0" }
  local CLASSNAME = { WARRIOR = "Warrior", ROGUE = "Rogue", HUNTER = "Hunter", MAGE = "Mage", WARLOCK = "Warlock",
                      PRIEST = "Priest", DRUID = "Druid", SHAMAN = "Shaman", PALADIN = "Paladin", ITEM = "Procs" }
  local function Tag(r) return r.name .. " |cff" .. (CLASSHEX[r.class] or "a0a0a0") .. "(" .. (CLASSNAME[r.class] or r.class) .. ")|r" end
  function SO.Open(key, card)
    if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection(key, card) else O:Open(key) end
  end

  -- ---------------------------------------------------------------- preview

  -- the real rows on made-up mobs (Ragnaros and friends); click a part = its settings
  local function Preview(p)
    W.Pin(p, "Preview", "Five made-up enemies drawn by the real tracker code with your settings: your DoTs, the raid's "
      .. "debuffs, a missing one in grey, a resist, a crowd-controlled mob (faded) and one out of range (stripes). Click a row "
      .. "for its look. Click this bar to fold it away.", function(pp)
      local box = (W.ZoomBox or W.Box)(pp, 190)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      local inner = CreateFrame("Frame", nil, holder)
      inner:SetWidth(10)
      inner:SetHeight(10)
      local rows = {}
      local units = D.FakeUnits(GetTime())
      for i = 1, table.getn(units) do
        local row = D.NewRow(inner)
        row.preview = true
        row.onPick = function() SO.Open("dotdisplay", "Sizes") end
        row.onEnter = function(r)
          GameTooltip:SetOwner(r, "ANCHOR_TOP")
          GameTooltip:AddLine("A tracked enemy")
          GameTooltip:AddLine("Click: sizes and looks", 1, 1, 1)
          GameTooltip:Show()
        end
        rows[i] = row
      end
      local function Layout()
        local gap = tonumber(C.dots.spacing) or 3
        local y, w = 0, 50
        for i, row in ipairs(rows) do
          D.LayoutRow(row)
          row:ClearAllPoints()
          row:SetPoint("TOPLEFT", inner, "TOPLEFT", 0, -y)
          y = y + row:GetHeight() + gap
          w = math.max(w, row:GetWidth())
        end
        inner:SetWidth(w)
        inner:SetHeight(math.max(10, y))
        local bw, bh = (box:GetWidth() or 600) - 30, (box:GetHeight() or 190) - 20
        local sc = math.min(1.6, bw / w, bh / math.max(10, y))
        inner:SetScale(sc)
        inner:ClearAllPoints()
        inner:SetPoint("CENTER", box, "CENTER", 0, 0)
      end
      SO.Layout = Layout
      Layout()
      holder:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + .1
        local t = GetTime()
        D.FakeTick(units, t)
        for i, row in ipairs(rows) do D.PaintRow(row, units[i], t) end
      end)
      W.Buttons(pp, {
        { "Test on my tracker (20 s)", function()
          if D.testUntil and GetTime() < D.testUntil then D.testUntil = 0 else D.Test(20) end
        end, nil, "The real tracker shows the made-up enemies for 20 seconds, so you can place it. Click again to stop.",
          on = function() return D.testUntil and GetTime() < D.testUntil end },
        { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, nil, "Drag the tracker where you want it." },
        { "Reset position", function() D.ResetPosition() end, nil, "Puts the tracker back on its first place (Cursive's Reset UI Frames)." },
      })
    end)
  end

  -- ---------------------------------------------------------------- General

  local function General(p)
    W.Heading(p, "DoT Tracker", { on = O.ModuleSwitch("dots", "DoT Tracker"), about = "One row for each enemy: its health, raid mark "
      .. "and every debuff on it - yours and the raid's - with real timers. Cursive Raid, built in and faster. With ClassicAPI the "
      .. "timers are the server's (talents and haste included); with SuperWoW alone they are counted from the casts it sees; "
      .. "without either it shows your target only. /dot cast <spell> spreads a DoT to the best enemy without it." })
    if not D then W.Note(p, "Switched off: click the switch above and reload.") return end
    Preview(p)

    W.Card(p, "Display", { icon = ICON .. "INV_Misc_Spyglass_02", tip = "What each row shows and how." })
    Chk(p, "Show health bar", "Off: no bar, only the name and the icons.", "healthbar")
    Chk(p, "Show unit name", nil, "name")
    Chk(p, "Show health %", nil, "hp")
    Chk(p, "Show raid icons", nil, "marks")
    Chk(p, "Invert bar layout", "The icons on the left of the bar, the raid mark on its right.", "invert")
    W.Check(p, "Reverse bars upwards", "New rows grow up from the bottom.", function() return C.dots.grow == "UP" end,
      function(v) C.dots.grow = v and "UP" or "DOWN" Up() end)
    Chk(p, "Always show current target", "Your target gets a row even when the filters would hide it.", "alwaystarget")
    Chk(p, "Target on top", "Your target's row is always the first.", "targettop")
    Chk(p, "Highlight target", "Your target's row has an edge in your accent colour.", "highlight")
    Chk(p, "CC / reflect transparency", "Crowd-controlled enemies (Polymorph, Banish, Sap...) and ones with a spell reflect fade, so you leave them alone.", "ccfade")
    Chk(p, "Out-of-range / line-of-sight stripes", "Stripes over enemies too far away or out of sight to cast at.", "stripes")
    Sld(p, "Stripes from", "How far away an enemy gets its stripes.", 5, 60, 1, "striperange", function(v) return v .. " yd" end)
    Chk(p, "Title", "\"DoT Tracker\" over the rows.", "title")
    Chk(p, "Backdrop", "A dark panel behind the rows.", "backdrop")
    Chk(p, "Click to target", "Click a row to target it (SuperWoW, no target swap needed to see it), right-click for the next raid mark.", "clicks")
    Drop(p, "When it shows", nil, { { key = "rows", label = "When there are enemies" }, { key = "combat", label = "Only in combat" },
      { key = "always", label = "Always" } }, "show")

    W.Card(p, "Debuff border", { icon = ICON .. "INV_Misc_Gem_Pearl_04", tip = "A coloured edge on each icon by whose it is." })
    Drop(p, "Own class debuffs", "Your own DoTs and debuffs.", BORDERS, "border_ownclass")
    Drop(p, "Own raid debuffs", "Raid debuffs you put up yourself (your Sunder, your Curse of the Elements...).", BORDERS, "border_ownraid")
    Drop(p, "Other class debuffs", "Other players' debuffs.", BORDERS, "border_otherclass")
    Drop(p, "Other raid debuffs", "Raid debuffs from other players.", BORDERS, "border_otherraid")
    Sld(p, "Border width", nil, 1, 3, 1, "bordersize", Px)
    Sld(p, "Border opacity", nil, 0, 1, .05, "borderalpha", Pct)

    W.Card(p, "Debuff order", { icon = ICON .. "INV_Misc_Note_01", tip = "Which group of icons comes first beside the bar. A group on the "
      .. "other side sits past the raid mark, away from the rest." })
    Drop(p, "Front", nil, SLOTS, "order1")
    Drop(p, "Middle", nil, SLOTS, "order2")
    Drop(p, "Rear", nil, SLOTS, "order3")
    Drop(p, "Last", nil, SLOTS, "order4")
    Drop(p, "Swap side (other side)", "One group on the far side of the bar.", SIDE, "otherside")
    Drop(p, "Your own icons", nil, { { key = "expire", label = "Expiring soonest first" }, { key = "applied", label = "In the order you put them on" } }, "mineorder")

    W.Card(p, "Debuff timer", { icon = ICON .. "INV_Misc_PocketWatch_01", tip = "The time left on each icon, and its stacks." })
    Chk(p, "Show timers", nil, "timers")
    Drop(p, "Duration timer colour", nil, TEXTCOL, "timercolor")
    Sld(p, "Tenths under", "Shows 2.4 instead of 3 in the last seconds (0 = never).", 0, 10, 1, "decimals", Sec)
    Sld(p, "Warning time", "Under this, the timer takes the colour below and the expiring sound plays.", 0, 10, 1, "warn", Sec)
    Drop(p, "Decimal duration colour", "The timer's colour in the warning time.", DECCOL, "decimalcolor")
    Drop(p, "Stack counter colour", nil, TEXTCOL, "stackcolor")

    W.Card(p, "Target armor", { icon = ICON .. "INV_Shield_06", tip = "Each enemy's armour, read live (SuperWoW), and how much the raid has taken off it." })
    Chk(p, "Show armour", nil, "armor")
    Chk(p, "Colour indicator", "Green, then yellow, then red as the armour drops.", "armorcolor")
    Drop(p, "Shows", nil, { { key = "live+total", label = "Live + total" }, { key = "live+removed", label = "Live + removed" },
      { key = "total+removed", label = "Total + removed" }, { key = "live", label = "Live" }, { key = "total", label = "Total" },
      { key = "removed", label = "Removed" } }, "armorshow")
    Drop(p, "Position", nil, { { key = "left", label = "Left" }, { key = "center", label = "Centre" }, { key = "right", label = "Right" } }, "armorpos")
    Drop(p, "Shield icon", nil, { { key = "off", label = "Off" }, { key = "left", label = "Left of the number" }, { key = "right", label = "Right of the number" } }, "armoricon")
    Sld(p, "Armour text size", nil, 6, 20, 1, "armorsize", Px)
    Sld(p, "Position offset", nil, -60, 60, 1, "armoroffset", Px)

    W.Card(p, "Sounds and alerts", { icon = ICON .. "INV_Misc_Bell_01" })
    Chk(p, "Resist / immune word", "RESIST, IMMUNE, MISS... over the row when your debuff fails.", "resist")
    Chk(p, "Resist sound", nil, "resistsound")
    Chk(p, "Expiring sound", "Once when one of your debuffs goes under the warning time.", "sound")

    W.Card(p, "Multi-DoT", { icon = ICON .. "Spell_Shadow_AbominationExplosion", tip = "Macros that put your DoT on the best enemy that "
      .. "lacks it - no target swap with SuperWoW. Your old Cursive macros (/cursive multicurse ...) work too while Cursive is off." })
    W.Note(p, "/dot cast Corruption  - the best enemy without your Corruption\n/dot cast Curse of Agony|lowhp|refresh=3,minhp=5000\n"
      .. "/dot target Immolate  - targets it instead\nOrder: marks (skull first), hp (biggest), lowhp. Options: refresh=seconds, minhp=N, range=yards, ooc, warn")
    local list = SO.MyDots()
    local btns = {}
    for i = 1, math.min(5, table.getn(list)) do
      local name = list[i]
      table.insert(btns, { "Make macro: " .. name, function() SO.MakeMacro(name) end, nil,
        "A macro \"" .. string.sub(name, 1, 16) .. "\" with /dot cast " .. name .. " in your macros." })
    end
    if table.getn(btns) > 0 then W.Buttons(p, btns) end
  end

  -- your class's debuffs that you know (spell book names in the data file)
  function SO.MyDots()
    local _, cls = UnitClass("player")
    local mine, out = {}, {}
    for _, v in pairs(D and D.DATA.spells or {}) do
      if v[3] == cls then mine[string.lower(v[1])] = v[1] end
    end
    local i = 1
    while true do
      local n = GetSpellName(i, BOOKTYPE_SPELL or "spell")
      if not n then break end
      local k = string.lower(n)
      if mine[k] then
        table.insert(out, mine[k])
        mine[k] = nil
      end
      i = i + 1
    end
    return out
  end
  function SO.MakeMacro(name)
    local body = "/dot cast " .. name
    local ok = pcall(CreateMacro, string.sub(name, 1, 16), 1, body, 1, 1)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffDoT Tracker|r: " .. (ok and ("macro made: " .. body) or "no room for another macro"))
  end

  -- ---------------------------------------------------------------- Raid

  local CATS = { { "armor", "Armor reduction", "Ability_Warrior_Sunder" }, { "spellvuln", "Spell vulnerability", "Spell_Shadow_ChillTouch" },
                 { "weaponproc", "Weapon procs", "INV_Sword_39" } }
  local function SetAll(test, on)
    for _, r in ipairs(D.DATA.raid) do if test(r) then D.SetWatched(r.key, on) end end
    Up()
    O:Refresh()
  end

  -- the raid order strip: watched raid debuffs as icons; click = earlier, right-click = later
  local function OrderStrip(p)
    local row = W.Row(p, 92, 0, 6)
    local btns = {}
    local function Paint()
      local keys = {}
      for _, k in ipairs(D.RaidOrder()) do if D.Watched(D.RAIDKEY[k]) then table.insert(keys, k) end end
      local per = math.max(1, math.floor((row:GetWidth() or 600) / 27))
      for i = 1, math.max(table.getn(keys), table.getn(btns)) do
        local b = btns[i]
        if not b and keys[i] then
          b = CreateFrame("Button", nil, row)
          b:SetWidth(24)
          b:SetHeight(24)
          b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
          b.tex = b:CreateTexture(nil, "ARTWORK")
          b.tex:SetAllPoints(b)
          b.tex:SetTexCoord(.08, .92, .08, .92)
          b:SetScript("OnClick", function()
            D.MoveRaid(this.key, arg1 == "RightButton" and 1 or -1)
            SO.PaintOrder()
            Up()
          end)
          b:SetScript("OnEnter", function()
            local r = D.RAIDKEY[this.key]
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:AddLine(r and Tag(r) or this.key)
            GameTooltip:AddLine("Click: earlier   Right-click: later", 1, 1, 1)
            GameTooltip:Show()
          end)
          b:SetScript("OnLeave", function() GameTooltip:Hide() end)
          btns[i] = b
        end
        if b and keys[i] then
          local r = D.RAIDKEY[keys[i]]
          b.key = keys[i]
          b.tex:SetTexture(D.SpellIcon(r.ids[1], r.key) or (ICON .. "INV_Misc_QuestionMark"))
          b:ClearAllPoints()
          b:SetPoint("TOPLEFT", row, "TOPLEFT", math.mod(i - 1, per) * 27, -math.floor((i - 1) / per) * 27)
          b:Show()
        elseif b then
          b:Hide()
        end
      end
    end
    SO.PaintOrder = Paint
    Paint()
    if p.items then table.insert(p.items, { Refresh = Paint }) end
  end

  local function Raid(p)
    W.Heading(p, "Raid debuffs", { about = "The debuffs the whole raid wants on a boss: armour, spell damage and weapon procs." })
    if not D then Off(p) return end
    W.Card(p, "Raid debuffs", { icon = ICON .. "Spell_Shadow_CurseOfAchimonde" })
    Chk(p, "Show the raid's debuffs", nil, "showraid")
    Chk(p, "Show your own debuffs", nil, "showmine")
    Chk(p, "Show other players' class debuffs", "Every other debuff on the enemy (Thunder Clap, Hamstring...).", "showother")
    Chk(p, "Show missing debuff icons", "Grey icons for the armour / spell debuffs ticked here that nobody has put up yet.", "missing")
    Chk(p, "Include own raid debuffs in order", "Your own raid debuffs sort into the raid order below instead of their own group.", "includeown")
    W.Card(p, "Change order", { icon = ICON .. "INV_Misc_Note_02", tip = "The order of the raid's debuffs on each row, first to last." })
    OrderStrip(p)
    W.Buttons(p, { { "Reset order", function() C.dots.raidorder = {} D.ReadHide() SO.PaintOrder() Up() end, nil, "The order of the list below." } })
    for _, c in ipairs(CATS) do
      W.Card(p, c[2], { icon = ICON .. c[3] })
      for _, r in ipairs(D.DATA.raid) do
        if r.cat == c[1] then
          local rr = r
          W.Check(p, Tag(rr), nil, function() return D.Watched(rr) end, function(v) D.SetWatched(rr.key, v) Up() if SO.PaintOrder then SO.PaintOrder() end end)
        end
      end
    end
    W.Buttons(p, {
      { "Enable all", function() SetAll(function(r) return r.cat == "armor" or r.cat == "spellvuln" or r.cat == "weaponproc" end, true) end },
      { "Disable all", function() SetAll(function(r) return r.cat == "armor" or r.cat == "spellvuln" or r.cat == "weaponproc" end, false) end },
    })
  end

  -- ---------------------------------------------------------------- Class

  local CLASSES = { "WARRIOR", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PRIEST", "DRUID", "SHAMAN", "PALADIN", "ITEM" }
  local CLASSICON = { WARRIOR = "INV_Sword_27", ROGUE = "INV_ThrowingKnife_04", HUNTER = "INV_Weapon_Bow_07", MAGE = "INV_Staff_13",
                      WARLOCK = "Spell_Nature_FaerieFire", PRIEST = "INV_Staff_30", DRUID = "Ability_Druid_Maul", SHAMAN = "Spell_Nature_BloodLust",
                      PALADIN = "INV_Hammer_01", ITEM = "INV_Sword_39" }
  local function Class(p)
    W.Heading(p, "Class debuffs", { about = "Every class's debuffs the tracker knows, by class: tick the ones you want to see on enemies "
      .. "(they show in the raid's group). Your own debuffs always show - by their caster, any class." })
    if not D then Off(p) return end
    local tabs = {}
    for _, cls in ipairs(CLASSES) do
      local any
      for _, r in ipairs(D.DATA.raid) do if r.class == cls then any = true end end
      if any then table.insert(tabs, { string.lower(cls), CLASSNAME[cls], CLASSICON[cls], { CLASSNAME[cls] } }) end
    end
    table.insert(tabs, { "never", "Never show", "Spell_Shadow_Teleport", { "Never show" } })
    O.CardTabs(p, tabs)
    for _, cls in ipairs(CLASSES) do
      local has
      for _, r in ipairs(D.DATA.raid) do if r.class == cls then has = true end end
      if has then
        W.Card(p, CLASSNAME[cls], { icon = ICON .. CLASSICON[cls] })
        for _, r in ipairs(D.DATA.raid) do
          if r.class == cls then
            local rr = r
            W.Check(p, rr.name, rr.cat, function() return D.Watched(rr) end, function(v) D.SetWatched(rr.key, v) Up() end)
          end
        end
        local c = cls
        W.Buttons(p, {
          { "Enable all", function() SetAll(function(r) return r.class == c end, true) end },
          { "Disable all", function() SetAll(function(r) return r.class == c end, false) end },
        })
      end
    end
    W.Card(p, "Never show", { icon = ICON .. "Spell_Shadow_Teleport", tip = "Debuffs never drawn, yours or anyone's." })
    W.Edit(p, "Names", "Debuff names, with commas between them: Mind Flay, Hamstring", function() return C.dots.hide end,
      function(v) C.dots.hide = v Up() end, 420)
    O.TabFilter(p)
  end

  -- ---------------------------------------------------------------- Display

  local function BarList()
    local out = { { key = "Interface\\AddOns\\pfUI\\img\\bar_elvui", label = "ElvUI", texture = "Interface\\AddOns\\pfUI\\img\\bar_elvui" },
                  { key = "Interface\\TargetingFrame\\UI-StatusBar", label = "Blizzard (Cursive)", texture = "Interface\\TargetingFrame\\UI-StatusBar" } }
    local list = pfUI.gui and pfUI.gui.dropdowns and pfUI.gui.dropdowns.uf_bartexture
    for _, e in ipairs(list or {}) do
      local _, _, k, l = string.find(e, "^(.-):(.*)$")
      if k then table.insert(out, { key = k, label = l, texture = k }) end
    end
    return out
  end
  local function Display(p)
    W.Heading(p, "Display", { about = "Sizes, spacing and text of the tracker." })
    if not D then Off(p) return end
    Preview(p)
    W.Card(p, "UI frame", { icon = ICON .. "INV_Misc_Spyglass_03" })
    Sld(p, "Scale", nil, .5, 2, .05, "scale", X)
    Sld(p, "Opacity", nil, 0, 1, .05, "alpha", Pct)
    Sld(p, "Font scale", "All the tracker's text at once.", .5, 2, .05, "fontscale", X)
    W.Dropdown(p, "Bar texture", nil, BarList(), function() return C.dots.texture end, function(v) C.dots.texture = v Up() end)
    Drop(p, "Bar colour", nil, { { key = "reaction", label = "Hostile red / neutral yellow (players: class)" }, { key = "custom", label = "My own colour" } }, "barcolor")
    W.Color(p, "Own bar colour", nil, function()
      local r, g, b, a = GetStringColor(C.dots.color or ".8,.2,.2,1")
      return tonumber(r) or .8, tonumber(g) or .2, tonumber(b) or .2, tonumber(a) or 1
    end, function(r, g, b, a) C.dots.color = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1) Up() end)

    W.Card(p, "Layout", { icon = ICON .. "INV_Misc_Note_03" })
    Sld(p, "Max debuffs", "Icons beside the bar per row.", 0, 18, 1, "icons")
    Sld(p, "Max targets", "Rows per column.", 1, 20, 1, "rows")
    Sld(p, "Columns", nil, 1, 5, 1, "cols")
    Sld(p, "Health bar spacing", "Between rows.", 0, 20, 1, "spacing", Px)
    Sld(p, "Debuff icon spacing", nil, 0, 10, 1, "iconspacing", Px)
    Drop(p, "Enemy order", nil, { { key = "marks", label = "Raid marks (skull first), then biggest" }, { key = "hp", label = "Most health first" },
      { key = "lowhp", label = "Lowest health % first" }, { key = "old", label = "First seen first" }, { key = "new", label = "Newest first" } }, "order")
    Sld(p, "Update speed", "How often the debuffs are read. Lower = fresher, higher = lighter.", .1, 1, .05, "rate", Sec)

    W.Card(p, "Sizes", { icon = ICON .. "INV_Misc_Ruler_01" })
    Sld(p, "Health bar width", nil, 40, 400, 1, "width", Px)
    Sld(p, "Health bar height", nil, 6, 50, 1, "rowh", Px)
    Sld(p, "Raid icon size", nil, 6, 50, 1, "marksize", Px)
    Sld(p, "Debuff icon size", nil, 8, 50, 1, "iconsize", Px)

    W.Card(p, "Text", { icon = ICON .. "INV_Misc_Book_09" })
    Sld(p, "HP text size", nil, 5, 24, 1, "fontsize", Px)
    Sld(p, "Name text size", nil, 5, 24, 1, "namesize", Px)
    Sld(p, "Name length", "Widest the name may be (0 = up to the health text).", 0, 300, 5, "namelen", Px)

    W.Card(p, "Timer position", { icon = ICON .. "INV_Misc_PocketWatch_02" })
    Sld(p, "Timer size", nil, 5, 24, 1, "timersize", Px)
    Sld(p, "Timer horizontal", nil, -20, 20, 1, "timerx", Px)
    Sld(p, "Timer vertical", nil, -20, 20, 1, "timery", Px)

    W.Card(p, "Stack counter", { icon = ICON .. "INV_Misc_Coin_02" })
    Sld(p, "Stack size", nil, 5, 24, 1, "stacksize", Px)
    Sld(p, "Stack horizontal", nil, -20, 20, 1, "stackx", Px)
    Sld(p, "Stack vertical", nil, -20, 20, 1, "stacky", Px)
  end

  -- ---------------------------------------------------------------- Filter

  local function Filter(p)
    W.Heading(p, "Filter", { about = "Which enemies get a row." })
    if not D then Off(p) return end
    W.Card(p, "Show only", { icon = ICON .. "INV_Misc_Spyglass_01" })
    Chk(p, "In combat", "Enemies in combat (your target always counts with \"Always show current target\").", "incombat")
    Chk(p, "Hostile", "Hostile ones only (no neutral mobs).", "hostile")
    Chk(p, "Target", "Only your target.", "onlytarget")
    Chk(p, "Attackable", nil, "attackable")
    Chk(p, "Player", "Only players.", "onlyplayers")
    Chk(p, "Not player", "Only NPCs.", "onlynpcs")
    Chk(p, "Within range", nil, "withinrange")
    Sld(p, "Range", "How far \"Within range\" reaches.", 10, 300, 5, "rangeyards", function(v) return v .. " yd" end)
    Chk(p, "Has raid mark", nil, "markedonly")
    Chk(p, "Has my debuff", "Only enemies with one of your debuffs (Cursive's \"Has curse\").", "mineonly")
    Chk(p, "Not ignored", "Leave out the names in the ignore list.", "ignored")
    Chk(p, "Use patterns", "Ignore list entries are Lua patterns (Cursive's \"Use regex\"): ^Flamewaker matches every Flamewaker.", "regex")

    W.Card(p, "Ignore list", { icon = ICON .. "Spell_Holy_SealOfSacrifice" })
    W.Live(p, function()
      local l = type(C.dots.ignore) == "table" and C.dots.ignore or {}
      if table.getn(l) == 0 then return "|cff888888Nobody ignored.|r" end
      return table.concat(l, ", ")
    end)
    local add = ""
    W.Edit(p, "Add name", "Type a name (or pattern), press Enter.", function() return "" end, function(v)
      add = v
      D.AddIgnore(v)
      O:Refresh()
    end, 300)
    W.Buttons(p, {
      { "Add target", function() if UnitExists("target") then D.AddIgnore(UnitName("target")) O:Refresh() end end, nil, "Your target's name." },
      { "Remove last", function()
        if type(C.dots.ignore) == "table" then table.remove(C.dots.ignore) end
        D.dirty = true
        O:Refresh()
      end },
      { "Clear", function() C.dots.ignore = {} D.dirty = true O:Refresh() end },
    })
  end

  -- ---------------------------------------------------------------- Profiles

  local function Profiles(p)
    W.Heading(p, "Profiles", { about = "Whole tracker setups saved by name for every character on this account, ready-made looks, "
      .. "and strings to share." })
    if not D then Off(p) return end
    local P = D.Profiles
    W.Card(p, "Ready-made", { icon = ICON .. "INV_Misc_Book_11", tip = "One click sets the tracker up for a job. Your sizes and places stay." })
    local tiles = {}
    for _, pr in ipairs(P.PRESETS) do
      local k = pr.key
      table.insert(tiles, { pr.label, pr.tip, nil, function() P.Preset(k) Up() O:Refresh() end, "pick" })
    end
    W.Tiles(p, { tiles[1], tiles[2], tiles[3], tiles[4] })
    W.Tiles(p, { tiles[5], tiles[6], tiles[7] })

    W.Card(p, "Profile management", { icon = ICON .. "INV_Misc_Note_04" })
    local names = {}
    for _, n in ipairs(P.Names()) do table.insert(names, { key = n, label = n }) end
    if table.getn(names) == 0 then table.insert(names, { key = "", label = "(no profile saved)" }) end
    W.Dropdown(p, "Select profile", nil, names, function() return C.dots.profile end, function(v) C.dots.profile = v end)
    local typed = ""
    W.Edit(p, "New name", "A name for Save as new (press Enter, then the button).", function() return typed end, function(v) typed = v end, 260)
    W.Buttons(p, {
      { "Load", function() P.Load(C.dots.profile) Up() O:Refresh() end },
      { "Save", function() if C.dots.profile ~= "" then P.Save(C.dots.profile) end end, nil, "Over the selected profile." },
      { "Delete", function() P.Delete(C.dots.profile) O:Rebuild("dotprofiles") end },
      { "Save as new", function() if typed ~= "" then P.Save(typed) O:Rebuild("dotprofiles") end end },
    })
    Chk(p, "Include frame position in profiles", nil, "profpos")

    W.Card(p, "Export / import", { icon = ICON .. "INV_Letter_15", tip = "Export writes every setting as text; copy it (Ctrl+C) and give it to a "
      .. "friend. Paste one in and Import. Nothing in the text is run: only setting lines are read." })
    local row = W.Row(p, 120, 0, 6)
    local sf = CreateFrame("ScrollFrame", "pfDotsExportScroll", row)
    sf:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -4)
    sf:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 4)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0, 0, 0, .5)
    local eb = CreateFrame("EditBox", "pfDotsExportBox", sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetWidth((row:GetWidth() or 600) - 12)
    eb:SetHeight(400)
    eb:SetFont(W.UIFont(), 11)
    eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    sf:SetScrollChild(eb)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function()
      local v = this:GetVerticalScroll() - (arg1 or 0) * 20
      this:SetVerticalScroll(math.max(0, math.min(v, this:GetVerticalScrollRange() or 0)))
    end)
    row:EnableMouse(true)
    row:SetScript("OnMouseDown", function() eb:SetFocus() end)
    SO.box = eb
    W.Buttons(p, {
      { "Export", function() eb:SetText(P.Export()) eb:HighlightText() eb:SetFocus() end },
      { "Import", function()
        local ok = P.Import(eb:GetText())
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffDoT Tracker|r: " .. (ok and "settings imported" or "that is not a DoT Tracker string"))
        Up()
        O:Refresh()
      end },
    })
  end

  O:AddPage("DoT Tracker", "dotgeneral", "General", General)
  O:AddPage("DoT Tracker", "dotraid", "Raid", Raid)
  O:AddPage("DoT Tracker", "dotclass", "Class", Class)
  O:AddPage("DoT Tracker", "dotdisplay", "Display", Display)
  O:AddPage("DoT Tracker", "dotfilter", "Filter", Filter)
  O:AddPage("DoT Tracker", "dotprofiles", "Profiles", Profiles)
end)
