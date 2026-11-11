pfUI:RegisterModule("consumes-options", "vanilla", function ()
  -- pfUI Octo :: the Consumables section (11 Nov 2026, modules/consumes.lua).
  -- Its own module so the section - and its on / off switch - stays when the
  -- tracker is switched off. Tracker: the bar as it looks now, the lists (one
  -- per place / spec / UI layout), the items on the picked one, adding items
  -- (from the list of consumables, the bags, a drop box, a name). Bar and
  -- alerts: when it warns, how, and the look of the bar.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local CP = { sel = 1 }
  pfUI.consumesOptions = CP

  local function CS() return pfUI.consumes end
  local function G() return C.consumes end
  local function Again() O:Rebuild("consumes") end
  local function Up() if CS() then CS().Changed() end end
  local function Accent()
    if GetAccentColor then return GetAccentColor() end
    return .2, .55, .9
  end
  local function Off(p, title)
    W.Heading(p, title, { on = O.ModuleSwitch("consumes", "Consumables"),
      about = "The consumables tracker is switched off. Switch it on and close the options to reload; your lists come back." })
    W.Note(p, "The tracker is off. Use the switch at the top right to turn it back on (takes a reload).")
  end
  function CP.List()
    local lists = CS().Lists()
    if CP.sel > table.getn(lists) then CP.sel = table.getn(lists) end
    if CP.sel < 1 then CP.sel = 1 end
    return lists[CP.sel], lists
  end

  -- ---------------------------------------------------------------- preview

  function CP.Status()
    local cs = CS()
    local l, i = cs.Active()
    local zone = cs.Zone()
    local where = (pfUI.context and pfUI.context.NAMES and pfUI.context.NAMES[zone]) or zone
    if G().track == "0" then return "|cffff6060Tracking is off (Bar and alerts).|r" end
    if not l then return "|cffaaaaaaYou are in: " .. where .. ". No list applies here, so nothing is watched (the preview shows the picked list).|r" end
    local miss, low = 0, 0
    for _, r in ipairs(cs.rows) do
      if r.state == "missing" then miss = miss + 1 elseif r.state == "low" then low = low + 1 end
    end
    local s = "Watching |cffffd24d" .. (l.name or "?") .. "|r (" .. where .. "): "
    if miss + low == 0 then return s .. "|cff40e060everything is up.|r" end
    return s .. (miss > 0 and ("|cffff6060" .. miss .. " missing|r ") or "") .. (low > 0 and ("|cffffcc33" .. low .. " running out|r") or "")
  end

  local function Preview(p)
    W.Pin(p, "Your bar", "The bar as it is now (or samples of the picked list when it does not apply here): red = "
      .. "missing, gold = running out, the number = how many are in your bags. Click an icon there to use it. "
      .. "Shift + wheel over it: bigger / smaller icons.", function(pp)
      local box = (W.ZoomBox or W.Box)(pp, 112)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      local status = holder:CreateFontString(nil, "OVERLAY")
      status:SetFont(W.UIFont(), 11, "OUTLINE")
      status:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -9)
      status:SetPoint("RIGHT", box, "RIGHT", -12, 0)
      status:SetJustifyH("LEFT")
      local legend = holder:CreateFontString(nil, "OVERLAY")
      legend:SetFont(W.UIFont(), 10, "")
      legend:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 12, 8)
      legend:SetTextColor(.6, .6, .62)
      legend:SetText("|cffff6060red|r missing   |cffffcc33gold|r running out   grey edge = up   red number = none in your bags")
      local sample = CreateFrame("Frame", nil, holder)
      local buttons = {}
      local function Make() return CS().NewButton(sample, true) end
      local hot = CreateFrame("Button", nil, holder)
      hot:SetAllPoints(sample)
      hot:SetFrameLevel(sample:GetFrameLevel() + 6)
      hot:EnableMouseWheel(true)
      hot:SetScript("OnMouseWheel", function()
        if IsShiftKeyDown() then
          G().size = tostring(math.max(20, math.min(64, (tonumber(G().size) or 34) + (arg1 or 0) * 2)))
          Up()
          O:Refresh()
        elseif pfUI.plates and pfUI.plates.PassWheel then
          pfUI.plates.PassWheel(this)
        end
      end)
      W.Tip(hot, "Your consumables bar", "Shift + mouse wheel: bigger / smaller icons.")
      local function Rows()
        local cs = CS()
        local l = CP.List()
        if cs.Active() == l and table.getn(cs.rows) > 0 then return cs.Shown(cs.rows) end
        -- the picked list as samples
        local out, states = {}, { "missing", "low", "ok" }
        for i, e in ipairs(l.items or {}) do
          if e.on ~= "0" then
            local st = states[math.mod(i - 1, 3) + 1]
            table.insert(out, { e = e, state = st, left = (st == "low") and 150 or 1800, count = cs.Count(e.item) })
          end
        end
        if table.getn(out) == 0 then return cs.Samples() end
        return out
      end
      local function Paint()
        status:SetText(CP.Status())
        local n = CS().Layout(sample, buttons, Rows(), Make)
        local room = (box:GetWidth() or 600) - 24
        local scale = math.min(1, room / math.max(1, sample:GetWidth()), 60 / math.max(1, sample:GetHeight()))
        sample:SetScale(scale)
        sample:ClearAllPoints()
        sample:SetPoint("CENTER", box, "CENTER", 0, 0)
        sample:SetAlpha(G().bar == "1" and (tonumber(G().alpha) or 1) or .35)
        if n == 0 then sample:Hide() else sample:Show() end
      end
      CP.PaintPreview = Paint
      holder:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + .5
        Paint()
      end)
      Paint()
      if p.items then table.insert(p.items, { Refresh = Paint }) end
      W.Buttons(pp, {
        { "Check now", function() Up() CS().Chat((CS().lastAlert and ("last alert: " .. CS().lastAlert)) or "checked.") end, nil,
          "Looks at your buffs and bags again and says what is missing (also /consumes check)." },
        { "Use the next missing", function() CS().UseNext() end, nil, "Uses the first missing consumable from your bags (the same as its key)." },
        { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, nil, "Drag the consumables bar where you want it." },
      })
    end)
  end

  -- ---------------------------------------------------------------- menus

  -- every consumable of the catalogue, by kind, with how many you have
  function CP.CatalogMenu()
    local cs = CS()
    local out = {}
    for _, c in ipairs(cs.CATS) do
      for _, e in ipairs(cs.CATALOG[c[1]] or {}) do
        local n = cs.Count(e[1])
        local _, tex = cs.ItemInfo(e[1])
        table.insert(out, { key = e[1], label = c[2] .. ": " .. e[2] .. (n > 0 and ("  |cff40e060(" .. n .. ")|r") or ""),
          icon = tex or ("Interface\\Icons\\" .. e[4]),
          tip = (e[3] == "*") and "A weapon enchant: any oil, stone or poison on that hand counts." or ("Looks for the buff \"" .. e[3] .. "\".") })
      end
    end
    return out
  end
  -- the items in your bags that have a "Use:" line (and are not on the list yet)
  function CP.BagMenu(list)
    local cs = CS()
    local out, seen = {}, {}
    for bag = 0, 4 do
      local n = GetContainerNumSlots and tonumber(GetContainerNumSlots(bag)) or 0
      for slot = 1, n do
        local id = cs.IdOf(GetContainerItemLink(bag, slot))
        if id and not seen[id] and not cs.Has(list, id) then
          seen[id] = true
          if cs.BYID[id] or cs.UseText(bag, slot) then
            local name, tex = cs.ItemInfo(id)
            table.insert(out, { key = id, label = (name or ("item " .. id)) .. "  |cff888888(" .. cs.Count(id) .. ")|r", icon = tex })
          end
        end
      end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
  end
  local function Added(e, why)
    if e then CS().Chat(e.name .. " is on the list" .. (e.kind == "weapon" and (e.hand == "17" and " (off hand)." or " (main hand).") or ".")) Again()
    elseif why then CS().Chat(why) end
  end

  -- ---------------------------------------------------------------- Tracker page

  local function Build(p)
    local cs = CS()
    if not cs then Off(p, "Consumables") return end
    W.Heading(p, "Consumables", { on = O.ModuleSwitch("consumes", "Consumables"),
      about = "Pick the flasks, elixirs, food, oils and scrolls you want up, and the bar shows each one: red when it "
      .. "is missing, gold with a timer when it runs out soon. A warning on screen (and a sound) says what is missing "
      .. "as you enter a raid. Click an icon - or press its key - to use it from your bags. Lists are per character; "
      .. "each list has the places (raid, dungeon, battleground...) it is for, and can be tied to a talent spec or a UI layout." })
    Preview(p)
    local list, lists = CP.List()

    -- lists
    W.Card(p, "Lists", { icon = "Interface\\Icons\\INV_Misc_Note_01",
      tip = "One list per kind of night out. The first list (in this order) that fits where you are is the one watched." })
    local row = W.Row(p, 24, 0, 4)
    local x = 0
    for ii, l in ipairs(lists) do
      local i = ii
      local b = W.Button(row, (l.name or "?") .. "  (" .. table.getn(l.items or {}) .. ")", 130, 22)
      local tw = b.label and b.label.GetStringWidth and b.label:GetStringWidth()
      if tw and tw + 20 > 130 then b:SetWidth(math.floor(tw + 20)) end
      b:SetPoint("LEFT", row, "LEFT", x, 0)
      x = x + (b:GetWidth() or 130) + 6
      W.Pick(b, i == CP.sel)
      b:SetScript("OnClick", function() CP.sel = i Again() end)
      W.Tip(b, l.name, "Click to edit this list.")
    end
    W.Buttons(p, {
      { "New list", function()
        local n = table.getn(lists) + 1
        local l = cs.NewList("List " .. n)
        table.insert(lists, l)
        CP.sel = n
        Up() Again()
      end, nil, "An empty list (raid and dungeon ticked)." },
      { "Copy this list", function()
        local l = cs.NewList((list.name or "List") .. " copy")
        for _, z in ipairs(cs.ZONES) do l[z] = list[z] end
        for _, e in ipairs(list.items or {}) do
          local c = {}
          for k, v in pairs(e) do c[k] = v end
          table.insert(l.items, c)
        end
        table.insert(lists, l)
        CP.sel = table.getn(lists)
        Up() Again()
      end, nil, "A copy of this list with the same items, to change for another place or spec." },
      { "Move up", function()
        if CP.sel > 1 then
          lists[CP.sel], lists[CP.sel - 1] = lists[CP.sel - 1], lists[CP.sel]
          CP.sel = CP.sel - 1
          Up() Again()
        end
      end, nil, "Earlier lists win when two fit the same place." },
      { "Delete this list", function()
        CreateQuestionDialog("Delete the list \"" .. (list.name or "?") .. "\" and its items?", function()
          table.remove(lists, CP.sel)
          CP.sel = 1
          Up() Again()
        end)
      end, nil, "Asks first. The last list is never empty-handed: a new Raid list takes its place." },
    })
    W.Edit(p, "Name", "The list's name.", function() return list.name end, function(v)
      if v and v ~= "" then list.name = v Up() Again() end
    end)

    -- when
    W.Card(p, "When this list is on", { icon = "Interface\\Icons\\INV_Misc_Map_01",
      tip = "Where you are (as UI layouts and the minimap see it), and optionally your talent spec and UI layout." })
    local ZN = { raid = "In a raid", dungeon = "In a dungeon", bg = "In a battleground", arena = "In an arena", world = "In the open world" }
    for _, z in ipairs(cs.ZONES) do
      local zone = z
      W.Check(p, ZN[zone], nil, function() return list[zone] == "1" end, function(v) list[zone] = v and "1" or "0" Up() end)
    end
    local specs = { { key = "", label = "Any spec" } }
    if C.gear and type(C.gear.specs) == "table" then
      local slots = {}
      for k in pairs(C.gear.specs) do table.insert(slots, k) end
      table.sort(slots)
      for _, k in ipairs(slots) do
        local s = C.gear.specs[k]
        table.insert(specs, { key = tostring(k), label = (type(s) == "table" and s.name) or ("Spec " .. k) })
      end
    end
    W.Dropdown(p, "Only for talent spec", "Your specs from the Goblin Brainwashing Device (Gear > Talent specs).", specs,
      function() return list.spec or "" end, function(v) list.spec = v Up() end)
    local lays = { { key = "", label = "Any UI layout" } }
    for _, n in ipairs((pfUI.layouts and pfUI.layouts.NAMES) or {}) do table.insert(lays, { key = n, label = n }) end
    W.Dropdown(p, "Only in UI layout", "Your UI layouts (Normal, Raid, PvP...).", lays,
      function() return list.layout or "" end, function(v) list.layout = v Up() end)

    -- items
    W.Card(p, "Items on " .. (list.name or "this list"), { icon = "Interface\\Icons\\INV_Potion_62",
      tip = "Each row: the item, the buff it is tracked by, how many you have. The switch takes it off the bar without removing it." })
    local items = list.items or {}
    if table.getn(items) == 0 then
      W.Note(p, "Nothing on this list yet: add items in the next card.")
    end
    for ii, e in ipairs(items) do
      local i, it = ii, e
      local r = W.Row(p, 26, 0, 2)
      local ic = CreateFrame("Button", nil, r)
      ic:SetWidth(22)
      ic:SetHeight(22)
      ic:SetPoint("LEFT", r, "LEFT", 2, 0)
      local tex = ic:CreateTexture(nil, "ARTWORK")
      tex:SetAllPoints(ic)
      tex:SetTexCoord(.07, .93, .07, .93)
      local _, t = cs.ItemInfo(it.item)
      tex:SetTexture(t or "Interface\\Icons\\INV_Misc_QuestionMark")
      ic:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        if GameTooltip.SetHyperlink then GameTooltip:SetHyperlink("item:" .. it.item .. ":0:0:0") end
        GameTooltip:Show()
      end)
      ic:SetScript("OnLeave", function() GameTooltip:Hide() end)
      local name = r:CreateFontString(nil, "OVERLAY")
      name:SetFont(W.UIFont(), 12, "")
      name:SetPoint("LEFT", ic, "RIGHT", 8, 0)
      name:SetWidth(230)
      name:SetJustifyH("LEFT")
      name:SetText((it.on == "0" and "|cff777777" or "") .. (it.name or "?"))
      local what = r:CreateFontString(nil, "OVERLAY")
      what:SetFont(W.UIFont(), 11, "")
      what:SetPoint("LEFT", name, "RIGHT", 6, 0)
      what:SetWidth(210)
      what:SetJustifyH("LEFT")
      local n = cs.Count(it.item)
      what:SetText((it.kind == "weapon" and "|cff9a9aa0weapon enchant|r" or ("|cff9a9aa0buff:|r " .. (it.buff or it.name or "?") .. (it.learned and " |cff6fb3ff(learned)|r" or "")))
        .. "   " .. (n > 0 and ("|cff40e060" .. n .. " in bags|r") or "|cffff6060none in bags|r"))
      local del = W.Button(r, "X", 24, 20)
      del:SetPoint("RIGHT", r, "RIGHT", -4, 0)
      if W.Tint then W.Tint(del, "danger") end
      del:SetScript("OnClick", function() table.remove(items, i) Up() Again() end)
      W.Tip(del, "Remove", "Takes " .. (it.name or "it") .. " off this list.")
      local sw = W.Switch(r, function() return it.on ~= "0" end, function(v) it.on = v and "1" or "0" Up() Again() end,
        "On the bar and warned about (off: kept on the list, not watched).")
      sw:SetPoint("RIGHT", del, "LEFT", -8, 0)
      if sw.Refresh then sw.Refresh() end
      local up = W.Button(r, "Up", 36, 20)
      up:SetPoint("RIGHT", sw, "LEFT", -8, 0)
      up:SetScript("OnClick", function()
        if i > 1 then items[i], items[i - 1] = items[i - 1], items[i] Up() Again() end
      end)
      W.Tip(up, "Up", "Earlier on the bar, and used first by the key.")
      if it.kind == "weapon" then
        local hand = W.Button(r, it.hand == "17" and "Off hand" or "Main hand", 76, 20)
        hand:SetPoint("RIGHT", up, "LEFT", -6, 0)
        if W.Tint then W.Tint(hand, "pick") end
        hand:SetScript("OnClick", function() it.hand = (it.hand == "17") and "16" or "17" Up() Again() end)
        W.Tip(hand, "Which hand", "Click to switch. Clicking the icon on the bar puts it on this hand.")
      elseif it.learned or not cs.BYID[it.item] then
        local fix = W.Button(r, "Buff...", 60, 20)
        fix:SetPoint("RIGHT", up, "LEFT", -6, 0)
        if W.Tint then W.Tint(fix, "pick") end
        fix:SetScript("OnClick", function()
          local opts = {}
          local buffs = cs.ReadBuffs()
          for k in pairs(buffs) do
            if k ~= "ids" then table.insert(opts, { key = cs.Proper(k) or k, label = cs.Proper(k) or k }) end
          end
          table.sort(opts, function(a, b) return a.label < b.label end)
          table.insert(opts, 1, { key = "", label = "|cffaaaaaaThe item's own name|r" })
          local m = W.Menu(this, opts, 220, function(v)
            it.buff = (v ~= "") and v or it.name
            it.learned = nil
            Up() Again()
          end)
          if m and m.Show then m:Show() end
        end)
        W.Tip(fix, "Which buff", "Pick the buff this item gives from the ones on you now. Normally it is learned by itself the first time you use the item.")
      end
    end

    -- add
    W.Card(p, "Add items", { icon = "Interface\\Icons\\INV_Misc_Bag_10",
      tip = "From the list of OctoWoW consumables, from your bags, by dropping an item, or by its name or ID." })
    local addRow = W.Row(p, 26, 0, 4)
    local function Btn(text, w, tip, fn, role)
      local b = W.Button(addRow, text, w, 22)
      if W.Tint then W.Tint(b, role) end
      b:SetScript("OnClick", fn)
      W.Tip(b, text, tip)
      return b
    end
    local pick = Btn("Pick from the list...", 170, "Flasks, elixirs, Zanza, Blasted Lands, juju, food, drinks, scrolls, "
      .. "protection potions, oils, stones and poisons. The number = how many you have.", function()
      W.LongMenu(this, CP.CatalogMenu(), 330, function(id) Added(cs.Add(list, id)) end):Show()
    end, "pick")
    pick:SetPoint("LEFT", addRow, "LEFT", 0, 0)
    local bags = Btn("From your bags...", 150, "The items in your bags that can be used.", function()
      local opts = CP.BagMenu(list)
      if table.getn(opts) == 0 then CS().Chat("nothing usable in your bags that is not on the list.") return end
      local m = W.Menu(this, opts, 260, function(id) Added(cs.Add(list, id)) end)
      if m and m.Show then m:Show() end
    end, "pick")
    bags:SetPoint("LEFT", pick, "RIGHT", 6, 0)
    local drop = Btn("Drop an item here", 170, "Pick an item up from your bags, then click here (or let go of it here).", function()
      Added(cs.AddFromCursor(list))
    end, "go")
    drop:SetPoint("LEFT", bags, "RIGHT", 6, 0)
    drop:SetScript("OnReceiveDrag", function() Added(cs.AddFromCursor(list)) end)
    W.Edit(p, "By name or ID", "Part of the item's name (your bags first, then the list of consumables, then every item) or its ID.",
      function() return "" end, function(v) if v and v ~= "" then Added(cs.Add(list, v)) end end)
  end

  -- ---------------------------------------------------------------- Bar and alerts page

  local function Pct(v) return math.floor(v * 100 + .5) .. "%" end
  local function Min(v) return (v == 0) and "off" or (v .. " min") end
  local function BuildBar(p)
    if not CS() then Off(p, "Bar and alerts") return end
    W.Heading(p, "Bar and alerts", { on = O.KeySwitch(G, "track", "Watching your consumables on or off (the lists stay).", Up),
      about = "When the tracker warns you and how, the look of the bar, and the key that puts the next missing one on." })

    W.Card(p, "Warnings", { icon = "Interface\\Icons\\Spell_Holy_BorrowedTime",
      tip = "Each missing or running-out item is said once; again when it changes, or every few minutes if you want." })
    O.PfSld(p, "Running out under", "A buff with less time left than this is \"running out\" (gold, with a timer).", 1, 30, 1, G, "warn", Up, Min)
    O.PfSld(p, "Oils and stones under", "The same for weapon enchants.", 1, 30, 1, G, "warnweapon", Up, Min)
    O.PfChk(p, "Text on screen", "A line in the middle of the screen: \"Missing: ...\".", G, "text", Up)
    O.PfChk(p, "Also in chat", nil, G, "chat", Up)
    W.Dropdown(p, "Sound", nil, { { key = "raidwarning", label = "Raid warning" }, { key = "ping", label = "Map ping" }, { key = "none", label = "None" } },
      function() return G().sound end, function(v)
        G().sound = v
        if v == "raidwarning" then PlaySound("RaidWarning") elseif v == "ping" then PlaySoundFile("Sound\\Interface\\MapPing.wav") end
      end)
    O.PfChk(p, "Quiet in combat", "No warnings while you fight: they come when combat ends.", G, "quiet", Up)
    O.PfSld(p, "Say it again every", "Repeat the warning while something is still missing; off = once.", 0, 30, 1, G, "again", Up, Min)
    O.PfChk(p, "Learn the buff an item gives", "After you use an item of the list, the new buff that shows up is the one it is tracked by "
      .. "(for items that are not in the list of consumables, or whose buff is named differently on this server).", G, "learn", Up)
    O.PfChk(p, "Read buffs with ClassicAPI", "Faster, no tooltip reading. Without ClassicAPI the buffs are read from their tooltips either way.", G, "classicapi", Up)

    W.Card(p, "The bar", { icon = "Interface\\Icons\\INV_Misc_Gear_01" })
    O.PfChk(p, "Show the bar", nil, G, "bar", Up)
    W.Dropdown(p, "Show on it", nil, { { key = "all", label = "Everything on the list" }, { key = "problems", label = "Only missing and running out" } },
      function() return G().show end, function(v) G().show = v Up() end)
    O.PfSld(p, "Icon size", "Or Shift + wheel over the preview.", 20, 64, 1, G, "size", Up, O.Px)
    O.PfSld(p, "Spacing", nil, 0, 20, 1, G, "spacing", Up, O.Px)
    O.PfSld(p, "Icons per row", nil, 1, 20, 1, G, "per", Up)
    O.PfChk(p, "Up and down", "Off: side by side.", G, "vertical", Up)
    O.PfSld(p, "Opacity", nil, .1, 1, .05, G, "alpha", Up, Pct)
    O.PfChk(p, "Timers on every icon", "Off: only on the ones running out.", G, "timers", Up)
    O.PfChk(p, "How many in your bags", "Off: only a red 0 when you have none.", G, "counts", Up)
    O.PfChk(p, "Missing ones pulse", nil, G, "pulse", Up)
    O.PfChk(p, "Hide the bar in combat", nil, G, "hidecombat", Up)
    W.Buttons(p, { { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, nil, "Drag the consumables bar where you want it." } })

    W.Card(p, "Putting them on again", { icon = "Interface\\Icons\\INV_Potion_93",
      tip = "Click an icon on the bar, or press this key: the first missing one (then the one running out soonest) is used from your bags." })
    if W.KeyBind then W.KeyBind(p, "Use the next missing", "Uses the first missing consumable from your bags; food only out of combat; an oil goes on its hand.", "PFCONSUMENEXT") end
    W.Note(p, "There is no fully automatic option on purpose: using items with no key press or click is what bots do, and "
      .. "the server's rules forbid it. A key press is one tap, and safe. Items are never used while a vendor, the bank, "
      .. "a trade, the mail or the auction house is open (they would be sold or moved instead).")
  end

  O:AddPage("Consumables", "consumes", "Tracker", Build)
  O:AddPage("Consumables", "consumesbar", "Bar and alerts", BuildBar)
end)
