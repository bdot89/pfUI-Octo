pfUI:RegisterModule("octototems-options", "vanilla", function ()
  -- pfUI Octo :: the OctoTotems section (19 Nov 2026, modules/octototems.lua): Bars (live preview), Sets, Timers & alerts,
  -- Smart heals; the Earthen Bulwark page (bulwark-options.lua) sits in the same section.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local TT = pfUI.octototems
  if not W or not O or not O.AddPage or not TT then return end
  local TO = {}
  pfUI.octototemsOptions = TO
  local function G() return C.octototems end
  local function Chk(p, label, desc, key, after) return O.PfChk(p, label, desc, G, key, after) end
  local function Sld(p, label, desc, min, max, step, key, fmt) return O.PfSld(p, label, desc, min, max, step, G, key, nil, fmt) end
  local function Pct(v) return math.floor(v * 100 + .5) .. "%" end
  local function Sec(v) return v .. " s" end
  local function Yd(v) return v .. " yd" end
  local function Drop(p, label, desc, opts, key, after)
    return W.Dropdown(p, label, desc, opts, function() return G()[key] end, function(v) G()[key] = v if after then after(v) end end)
  end
  local function Color(p, label, desc, key, r, g, b)
    W.Color(p, label, desc, function() return TT.Col(key, r, g, b, 1) end,
      function(nr, ng, nb, na) G()[key] = nr .. "," .. ng .. "," .. nb .. "," .. (na or 1) end)
  end
  local function Heading(p, title, about)
    W.Heading(p, title, { on = O.ModuleSwitch("octototems", "OctoTotems"), about = about })
  end

  -- what the DLLs give, one line
  function TO.Status()
    local parts = {}
    local function Part(ok, yes, no) table.insert(parts, ok and ("|cff55ff55" .. yes .. "|r") or ("|cff888888" .. no .. "|r")) end
    Part(TT.ClassicTotems(), "ClassicAPI: real totem slots", "no ClassicAPI: timers from casts")
    Part(TT.Nampower(), "nampower: whole set on one press", "no nampower: one totem a press")
    Part(TT.HasPos(), "position: range from the drop point", "no position: range from totem buffs")
    local s = table.concat(parts, "   ")
    if not TT.shaman then s = "|cffffcc00Only shown on shamans.|r   " .. s end
    if TT.aside then s = "|cffff5555Call of Elements is loaded: OctoTotems stands aside.|r   " .. s end
    return s
  end

  -- the preview: the four bars from a made-up fight. Left-click a totem = in / out of the set being edited,
  -- right-click = hide it on the bar, hover = open the bar, Shift + wheel = size.
  local function Preview(p, note)
    W.Pin(p, "Your totem bars", "A made-up fight: timers run, one totem goes out of range, the advisor lights the poison totem. "
      .. "Left-click a totem: in / out of the set. Right-click: hide it on the bar. Shift + wheel: button size.", function(pp)
      local box = (W.ZoomBox or W.Box)(pp, 170)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      local stage = CreateFrame("Frame", nil, holder)
      stage:SetWidth(10) stage:SetHeight(10)
      stage.onPreview = function(b, button)
        if not b.totem then return end
        if button == "RightButton" then
          G().hide[b.totem] = not G().hide[b.totem] or nil
        else
          local set = TO.EditSet()
          TT.PutInSet(set, b.totem)
        end
        TO.Paint()
      end
      local hot = CreateFrame("Frame", nil, holder)
      hot:SetAllPoints(box)
      hot:EnableMouseWheel(true)
      hot:SetScript("OnMouseWheel", function()
        if IsShiftKeyDown() then
          G().size = tostring(math.max(20, math.min(64, (tonumber(G().size) or 36) + (arg1 or 0) * 2)))
          TO.Paint()
        elseif pfUI.plates and pfUI.plates.PassWheel then
          pfUI.plates.PassWheel(this)
        end
      end)
      local function Paint()
        local now = GetTime()
        TT.Preview(stage, now)
        local dir = G().dir_fire or "up"
        stage:ClearAllPoints()
        local scale = 1
        local room = (box:GetHeight() or 170) - 24
        local tall = 0
        for el = 1, 4 do
          local b = stage.pbars and stage.pbars[el]
          if b and b.shown then tall = math.max(tall, b.shown) end
        end
        local size, gap = tonumber(G().size) or 36, tonumber(G().spacing) or 3
        local need = tall * (size + gap)
        if need > room then scale = room / need end
        stage:SetScale(math.max(.4, scale))
        if dir == "down" then stage:SetPoint("TOP", box, "TOP", 0, -12 / stage:GetScale())
        else stage:SetPoint("BOTTOM", box, "BOTTOM", 0, 12 / stage:GetScale()) end
        holder:SetAlpha(G().enable == "1" and 1 or .4)
      end
      TO.Paint = Paint
      holder:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + .1
        Paint()
      end)
      Paint()
      if p.items then table.insert(p.items, { Refresh = Paint }) end
      W.Buttons(pp, {
        { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, nil, "Drag the totem bars where you want them." },
        { "Throw the set", function() TT.ThrowSet() end, nil, "Throws the active set now (as the key does)." },
      })
    end)
    W.Live(p, TO.Status)
    if note then W.Note(p, note) end
  end

  -- the set the Sets page edits (default: the active one)
  function TO.EditSet()
    local sets = TT.Sets()
    local i = TO.edit or tonumber(G().cur) or 1
    if not sets[i] then i = 1 end
    TO.edit = i
    return sets[i], i
  end

  local MODES = {
    { key = "flex", label = "Anchor, the rest on hover" },
    { key = "open", label = "All shown" },
    { key = "closed", label = "Anchor only" },
    { key = "hidden", label = "Hidden" },
  }
  local DIRS = { { key = "up", label = "Up" }, { key = "down", label = "Down" }, { key = "left", label = "Left" }, { key = "right", label = "Right" } }

  -- a row of an element's totems: left-click = one place earlier, right-click = hide / show
  local function OrderRow(p, el)
    local row = W.Row(p, 34, 0, 6)
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", row, "LEFT", 10, 0)
    label:SetWidth(60)
    label:SetJustifyH("LEFT")
    label:SetText(TT.EL[el].name)
    label:SetTextColor(TT.ElCol(el))
    row.btns = {}
    local function Paint()
      local list = TT.ElementTotems(el, true)
      for i, name in ipairs(list) do
        local b = row.btns[i]
        if not b then
          b = CreateFrame("Button", nil, row)
          b:SetWidth(28) b:SetHeight(28)
          b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
          b.tex = b:CreateTexture(nil, "ARTWORK")
          b.tex:SetAllPoints(b)
          b.tex:SetTexCoord(.08, .92, .08, .92)
          b.x = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          b.x:SetPoint("CENTER", b, "CENTER", 0, 0)
          b:SetScript("OnClick", function()
            local l = TT.ElementTotems(el, true)
            if arg1 == "RightButton" then
              G().hide[this.totem] = not G().hide[this.totem] or nil
            else
              for k = 2, table.getn(l) do
                if l[k] == this.totem then l[k], l[k - 1] = l[k - 1], l[k] break end
              end
              TT.SetOrder(el, l)
            end
            Paint()
          end)
          b:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:SetText(this.totem)
            GameTooltip:AddLine((TT.Known(this.totem) and "" or "Not learnt yet. ") .. "Left-click: one place earlier. Right-click: hide / show on the bar.", .8, .8, .8, 1)
            GameTooltip:Show()
          end)
          b:SetScript("OnLeave", function() GameTooltip:Hide() end)
          row.btns[i] = b
        end
        b.totem = name
        b:ClearAllPoints()
        b:SetPoint("LEFT", row, "LEFT", 74 + (i - 1) * 32, 0)
        b.tex:SetTexture(TT.Icon(name))
        local hidden = G().hide[name]
        b.tex:SetVertexColor(hidden and .3 or 1, hidden and .3 or 1, hidden and .3 or 1)
        b.tex:SetDesaturated(hidden and true or false)
        b.x:SetText(hidden and "|cffff4444x|r" or "")
        b:Show()
      end
      for i = table.getn(list) + 1, table.getn(row.btns) do row.btns[i]:Hide() end
    end
    Paint()
    if p.items then table.insert(p.items, { Refresh = Paint }) end
  end

  local function Bars(p)
    Heading(p, "OctoTotems", "Every totem you know on four bars, one per element, like action buttons with timers, cooldowns "
      .. "and range. Sets of four totems go down with one key (all at once with nampower), the advisor lights the cleansing "
      .. "or Tremor totem your group needs, and alerts tell you when a totem runs out, dies or is left behind. Your earthen "
      .. "bulwark (Rockbiter tanks) has its own page here. Call of Elements' features, written our own way.")
    Preview(p)

    W.Card(p, "Layout", { icon = "Interface\\Icons\\Spell_Nature_StoneSkinTotem", tip = "Where the bars are and how they open." })
    Drop(p, "Bars", "Together: one box in layout mode with the four bars side by side. Apart: each element its own box.", {
      { key = "together", label = "Together, side by side" }, { key = "apart", label = "Apart, each its own box" } }, "layout")
    Drop(p, "First button", "Which totem sits on the first button of each bar.", {
      { key = "active", label = "The totem that is down, else the set's" },
      { key = "set", label = "The active set's totem" },
      { key = "first", label = "The first in your order" } }, "anchor")
    Sld(p, "Always shown", "With \"the rest on hover\": how many buttons stay out without hovering.", 1, 8, 1, "static")
    Sld(p, "Close after", "Seconds a hovered bar stays open after the mouse leaves.", 0, 3, .1, "flexdelay", Sec)
    Chk(p, "Keep busy totems out", "Totems that are down, advised or cooling down stay on a closed bar.", "dock")
    Chk(p, "Hide out of combat", "Only while you fight or have a totem down.", "hideooc")
    Chk(p, "Totemic Recall button", "After the bars; it glows when every totem is out of range.", "recall")

    W.Card(p, "Each element", { icon = "Interface\\Icons\\Spell_Fire_SearingTotem", tip = "How each bar opens and which way." })
    for el = 1, 4 do
      local e = TT.EL[el]
      Drop(p, e.name .. ": shows", nil, MODES, "mode_" .. e.key)
      Drop(p, e.name .. ": opens", nil, DIRS, "dir_" .. e.key)
    end
    for el = 1, 4 do
      local e = TT.EL[el]
      Color(p, e.name .. " colour", "Its button edges, the active glow and the timer line.", "col_" .. e.key, e.col[1], e.col[2], e.col[3])
    end

    W.Card(p, "Order and hidden totems", { icon = "Interface\\Icons\\INV_Misc_Book_09", tip = "Left-click a totem: one place earlier. Right-click: hide / show." })
    for el = 1, 4 do OrderRow(p, el) end

    W.Card(p, "Buttons", { icon = "Interface\\Icons\\INV_Misc_Gem_Variety_01", tip = "Sizes, what each button shows." })
    Sld(p, "Button size", "Also Shift + wheel on the preview.", 20, 64, 1, "size", O.Px)
    Sld(p, "Space between", nil, 0, 12, 1, "spacing", O.Px)
    Sld(p, "Scale", nil, .5, 2, .05, "scale", Pct)
    Sld(p, "Opacity", nil, .1, 1, .05, "alpha", Pct)
    Sld(p, "Timer text size", nil, 8, 22, 1, "timersize", O.Px)
    Chk(p, "Timers", "Time left on a totem's button while it is down.", "timers")
    Chk(p, "Timer line", "A line along the bottom that empties as the totem runs out.", "timerbar")
    Chk(p, "Cooldown swipe", nil, "cooldown")
    Chk(p, "Red cooldown numbers", "Seconds until you can drop it again, once it is gone.", "cdtext")
    Chk(p, "Glow on the totem that is down", nil, "activeedge")
    Chk(p, "Edges in the element's colour", nil, "elementborder")
    Chk(p, "Gold dot on the set's totems", nil, "setmark")
    Chk(p, "Tooltips", nil, "tooltip")
    Drop(p, "Tooltip side", nil, { { key = "right", label = "Right" }, { key = "left", label = "Left" } }, "tipside")

    W.Card(p, "Clicks", { icon = "Interface\\Icons\\INV_Misc_Note_01", tip = "What clicking a totem does." })
    Drop(p, "Rank 1 with", "Hold this while clicking to drop rank 1 (cheap mana, same effect for Tremor, Grounding ...).", {
      { key = "alt", label = "Alt" }, { key = "shift", label = "Shift" }, { key = "ctrl", label = "Ctrl" }, { key = "none", label = "Never" } }, "rank1mod")
    Chk(p, "Ctrl-click puts it in the set", "Ctrl-click a totem: dropped and made the active set's totem for its element.", "ctrlset")
    W.Note(p, "Shift-drag a totem onto an action bar (Shift + Ctrl = rank 1). Right-click a bar: switch sets, throw, recall, these options. Commands: /totems (and /coe while Call of Elements is not loaded).")
  end

  local function Sets(p)
    Heading(p, "Totem sets", "Up to four totems, one per element, thrown in your order with one key. A press throws the next "
      .. "totem that is not down yet (or is out of range / about to run out); with nampower every missing one is queued on the "
      .. "same press. Enemy players switch to their class's set, and a set named exactly like your target is picked for it.")
    Preview(p)
    W.Live(p, function()
      local set, i = TT.Cur()
      local eset = TO.EditSet()
      return "Active set: |cffffffff" .. (set and set.name or "?") .. "|r" .. (TT.override and " |cffffcc00(picked by your target)|r" or "")
        .. "     Editing: |cffffd060" .. (eset and eset.name or "?") .. "|r"
    end)

    W.Card(p, "The set", { icon = "Interface\\Icons\\Spell_Nature_Windfury", tip = "Pick a set to edit; the preview's left-clicks change it too." })
    W.Dropdown(p, "Edit set", nil, function()
      local o = {}
      for i, s in ipairs(TT.Sets()) do table.insert(o, { key = tostring(i), label = s.name }) end
      return o
    end, function() local _, i = TO.EditSet() return tostring(i) end, function(v) TO.edit = tonumber(v) O:Refresh() end)
    W.Edit(p, "Name", "A set named exactly like a mob (\"Nefarian\") is picked when you target it.",
      function() local s = TO.EditSet() return s and s.name or "" end,
      function(v) local s = TO.EditSet() if s and v and v ~= "" then s.name = v end end, 220)
    W.Buttons(p, {
      { "Make active", function() local _, i = TO.EditSet() TT.UseSet(i) end, 110, "This set is thrown by the set key.", role = "go" },
      { "New set", function() TO.edit = TT.NewSet() O:Refresh() end, 100 },
      { "Delete", function() local _, i = TO.EditSet() if TT.DeleteSet(i) then TO.edit = 1 O:Refresh() end end, 90, "The last set cannot be deleted.", role = "off" },
    })
    for el = 1, 4 do
      local e = TT.EL[el]
      local elc = el
      W.Dropdown(p, e.name, nil, function()
        local o = { { key = "", label = "None" } }
        for _, n in ipairs(TT.ElementTotems(elc, true)) do table.insert(o, { key = n, label = n .. (TT.Known(n) and "" or " |cff888888(not learnt)|r") }) end
        return o
      end, function() local s = TO.EditSet() return s and s["t" .. elc] or "" end, function(v) local s = TO.EditSet() if s then s["t" .. elc] = v end end)
    end
    local ORD = {}
    for el = 1, 4 do table.insert(ORD, { key = tostring(el), label = TT.EL[el].name }) end
    local NTH = { "Thrown 1st", "Thrown 2nd", "Thrown 3rd", "Thrown 4th" }
    for k = 1, 4 do
      local kk = k
      W.Dropdown(p, NTH[k], "Swaps places with the element that had this turn.", ORD, function()
        local s = TO.EditSet()
        return tostring(TT.SetOrderList(s or {})[kk])
      end, function(v)
        local s = TO.EditSet()
        if not s then return end
        local l = TT.SetOrderList(s)
        local n = tonumber(v)
        for j = 1, 4 do if l[j] == n then l[j] = l[kk] end end
        l[kk] = n
        s.order = table.concat(l, ",")
      end)
    end

    W.Card(p, "Throwing", { icon = "Interface\\Icons\\Spell_Nature_Purge", tip = "How a press of the set key decides." })
    Chk(p, "Whole set on one press (nampower)", "Queues every missing totem at once with nampower's QueueSpellByName. Without nampower: one a press.", "queueall")
    Chk(p, "Drop again when out of range", "A totem left more than the range behind counts as missing.", "redrop")
    Sld(p, "Drop again below", "A totem with less time left than this counts as missing (0 = never).", 0, 30, 1, "refresh", Sec)
    Chk(p, "Say which set and when all are down", nil, "setnotice")
    if W.KeyBind then
      W.KeyBind(p, "Throw the set", nil, "PFTOTEMSET")
      W.KeyBind(p, "Throw the whole set again", "Every totem of the set, down or not.", "PFTOTEMSETFORCE")
      W.KeyBind(p, "Next set", nil, "PFTOTEMNEXTSET")
      W.KeyBind(p, "Previous set", nil, "PFTOTEMPRIORSET")
      W.KeyBind(p, "Totemic Recall", nil, "PFTOTEMRECALL")
    end
    W.Note(p, "Macros: /totems throwset [set], /totems forcethrowset, /totems nextset, /totems set <name>, /totems restartset.")

    W.Card(p, "PvP and targets", { icon = "Interface\\Icons\\INV_BannerPVP_02", tip = "Sets picked by who you target." })
    Chk(p, "Enemy players pick their class's set", "Back to your own set when you target something else.", "pvpauto")
    Chk(p, "A set named like the target is picked", nil, "namesets")
    local CN = { WARRIOR = "Warrior", ROGUE = "Rogue", MAGE = "Mage", WARLOCK = "Warlock", HUNTER = "Hunter", PRIEST = "Priest", DRUID = "Druid", PALADIN = "Paladin", SHAMAN = "Shaman" }
    for _, cl in ipairs(TT.CLASSES) do
      local c = cl
      W.Dropdown(p, CN[c], nil, function()
        local o = { { key = "", label = "Keep my set" } }
        for i, s in ipairs(TT.Sets()) do table.insert(o, { key = tostring(i), label = s.name }) end
        return o
      end, function() return G().pvp[c] or "" end, function(v) G().pvp[c] = v end)
    end
  end

  local function Alerts(p)
    Heading(p, "Timers and alerts", "Words in the middle of the screen (and a sound) when a totem is about to run out, has run "
      .. "out, was destroyed or is left out of range; reminders for your shield and weapon imbue; the advisor for what your "
      .. "group needs cleansed.")
    W.Live(p, TO.Status)

    W.Card(p, "Totem alerts", { icon = "Interface\\Icons\\INV_Misc_PocketWatch_01" })
    Chk(p, "Time running out", nil, "warn")
    Sld(p, "First warning", nil, 3, 30, 1, "warn1", Sec)
    Sld(p, "Second warning", "With a sound.", 1, 15, 1, "warn2", Sec)
    Chk(p, "It has run out", nil, "expired")
    Chk(p, "It was destroyed", "Gone before its time: killed, or replaced.", "destroyed")
    Chk(p, "Out of range", "You moved away from it.", "rangealert")
    Sld(p, "Totem range", "How far a totem reaches (most are 20 yd; Windfury and Grace of Air 20, Tremor 30).", 10, 40, 1, "range", Yd)
    Chk(p, "All out of range: recall?", "Every totem left behind: a reminder and the recall button glows.", "recallremind")

    W.Card(p, "How alerts show", { icon = "Interface\\Icons\\INV_Misc_Bell_01" })
    Chk(p, "Middle of the screen", nil, "alerttext")
    Chk(p, "In chat", nil, "alertchat")
    Chk(p, "Sound", nil, "alertsound")

    W.Card(p, "Shield and weapon", { icon = "Interface\\Icons\\Spell_Nature_LightningShield", tip = "Reminders while they are off." })
    Chk(p, "Shield reminder", nil, "remindshield")
    W.Dropdown(p, "Shield", nil, function()
      local o = { { key = "auto", label = "The first I know" } }
      for _, n in ipairs(TT.SHIELDS) do table.insert(o, { key = n, label = n }) end
      return o
    end, function() return G().shield end, function(v) G().shield = v end)
    Chk(p, "Weapon imbue reminder", nil, "remindimbue")
    W.Dropdown(p, "Imbue", nil, function()
      local o = { { key = "auto", label = "The first I know" } }
      for _, n in ipairs(TT.IMBUES) do table.insert(o, { key = n, label = n }) end
      return o
    end, function() return G().imbue end, function(v) G().imbue = v end)
    Chk(p, "Button to put it back", "A glowing button over the bars: click to cast the shield / imbue.", "remindbutton")
    Chk(p, "Also out of combat", nil, "remindooc")
    Sld(p, "Say it again after", nil, 5, 120, 5, "remindevery", Sec)
    Chk(p, "Reminder sound", nil, "remindsound")
    if W.KeyBind then W.KeyBind(p, "Put it back on", nil, "PFTOTEMSHIELD") end

    W.Card(p, "Totem advisor", { icon = "Interface\\Icons\\Spell_Nature_PoisonCleansingTotem", tip = "Poison, disease, fear / charm / sleep on your group." })
    Chk(p, "Advise totems", "Your group's poisons light Poison Cleansing, diseases Disease Cleansing, fear / charm / sleep Tremor (party only - in a raid only you are checked).", "advisor")
    if W.KeyBind then W.KeyBind(p, "Throw the advised totem", nil, "PFTOTEMADVISED") end
  end

  local function Heals(p)
    Heading(p, "Smart heals", "Two keys that heal the most hurt member of your group with the smallest rank that covers what "
      .. "they are missing. Battle heal prefers Lesser Healing Wave (fast); best heal prefers Healing Wave (more healing per "
      .. "mana). With SuperWoW it heals them without changing your target.")
    W.Live(p, function()
      local u, miss = TT.HealTarget()
      if not u then return "Nobody below the line right now." end
      local n, r = TT.PickHeal("battle", miss)
      return "Now: |cffffffff" .. (UnitName(u) or u) .. "|r missing |cffffffff" .. math.floor(miss) .. "|r -> " .. (n or "?") .. " " .. (r or "")
    end)
    W.Card(p, "Heals", { icon = "Interface\\Icons\\Spell_Nature_HealingWaveLesser" })
    Sld(p, "Only below", "Members above this much health are left alone.", 30, 100, 1, "healbelow", function(v) return v .. "%" end)
    Sld(p, "Cover", "The rank picked heals at least this share of what they are missing.", 50, 150, 5, "healcover", function(v) return v .. "%" end)
    if W.KeyBind then
      W.KeyBind(p, "Battle heal", nil, "PFTOTEMBATTLEHEAL")
      W.KeyBind(p, "Best heal", nil, "PFTOTEMBESTHEAL")
    end
    W.Note(p, "Macros: /totems battleheal, /totems bestheal.")
  end

  O:AddPage("OctoTotems", "totembars", "Bars", Bars)
  O:AddPage("OctoTotems", "totemsets", "Sets", Sets)
  O:AddPage("OctoTotems", "totemalerts", "Timers & alerts", Alerts)
  O:AddPage("OctoTotems", "totemheal", "Smart heals", Heals)
end)
