pfUI:RegisterModule("gear-specs", "vanilla", function ()
  -- pfUI Octo :: talent specs at the Goblin Brainwashing Device (user, 25 Oct
  -- 2026: "implement this into our addon for brainwasher changing specs ...
  -- seamlessly work with our itemchanger ... match a set of gear to a spec ...
  -- the UI that comes up should resemble our UI").
  -- Idea from Brainwasher Pro (Fostercare5988, after Horyoshi); written fresh
  -- for pfUI: only the device's menu texts (read in play by its author,
  -- 21 Oct 2026) are taken from it.
  --   "Reset my talents. (1g0s0c)"
  --   "Activate 1st Specialization  (41/10/0)"
  --   "Save 1st Specialization."
  --   "Buy 4th Specialization tab for 200 gold."
  -- Talk to the device and this window takes the place of its menu: one row
  -- per talent slot with its name, icon and talent split, the gear set and UI
  -- layout that go with it, and whether it keeps its own spells on the bars.
  -- Once the new talents are in (no talent / spell events for 1.5 s) the set
  -- goes on (through GR's queue: armour after combat), the layout switches
  -- and the spec's spells go back on the bars. Away from the device the same
  -- window (/gear specs) manages the links; switching needs the device.
  -- Spec changes made some other way are noticed too: a talent split that
  -- matches one spec (and only one) puts its gear on.
  -- Uses ClassicAPI's C_GossipInfo when it is there (option ids and the
  -- server's own confirm flag); else the 1.12 GetGossipOptions /
  -- SelectGossipOption.
  -- C.gear.specs["<slot>"] = { name, icon, t1, t2, t3, set, layout, ownbars,
  --   bars = { [layout] = action bars } }; C.gear.specnow = the slot worn now.
  local GR = pfUI.gear
  if not GR then return end
  local GS = {}
  GR.specs = GS

  if type(C.gear.specs) ~= "table" then C.gear.specs = {} end
  local MAX = 8
  local ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
  local SETTLE, TIMEOUT = 1.5, 60

  local function Say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r specs: " .. msg) end
  local function Accent()
    if GetAccentColor then return GetAccentColor() end
    return .2, .7, 1
  end

  -- ---------------------------------------------------------------- specs

  function GS.Spec(slot) return C.gear.specs[tostring(slot)] end
  function GS.Ensure(slot)
    local k = tostring(slot)
    local s = C.gear.specs[k]
    if type(s) ~= "table" then
      s = { name = "Spec " .. k, icon = ICON, t1 = 0, t2 = 0, t3 = 0, set = "", layout = "", ownbars = "1" }
      C.gear.specs[k] = s
    end
    if type(s.bars) ~= "table" then s.bars = {} end
    return s
  end
  function GS.Name(slot)
    local s = GS.Spec(slot)
    return s and s.name or ("Spec " .. slot)
  end

  function GS.Split()
    local out = {}
    for i = 1, 3 do
      local _, _, n = GetTalentTabInfo(i)
      out[i] = tonumber(n) or 0
    end
    return out[1], out[2], out[3]
  end

  -- the spec worn now, when its spells are its own (layouts keep their bars there)
  function GS.BarSpec()
    local s = C.gear.specnow and GS.Spec(C.gear.specnow)
    if s and s.ownbars ~= "0" then
      if type(s.bars) ~= "table" then s.bars = {} end
      return s
    end
  end
  local function LayoutNow()
    local L = pfUI.layouts
    return L and L.Store and L.Store().current or "Normal"
  end

  -- the one saved spec with this split (nil when none or more than one)
  function GS.Match(t1, t2, t3)
    if t1 + t2 + t3 == 0 then return nil end
    local found
    for k, s in pairs(C.gear.specs) do
      if type(s) == "table" and s.t1 == t1 and s.t2 == t2 and s.t3 == t3 then
        if found then return nil end
        found = tonumber(k)
      end
    end
    return found
  end

  -- Brainwasher Pro's names and icons, once (they are the same slots)
  if C.gear.specimport ~= "1" and type(BrainwasherProDB) == "table" and type(BrainwasherProDB.specs) == "table" then
    for slot, b in pairs(BrainwasherProDB.specs) do
      if type(b) == "table" and tonumber(slot) and not GS.Spec(slot) then
        local s = GS.Ensure(slot)
        s.name, s.icon = b.name or s.name, b.icon or s.icon
        s.t1, s.t2, s.t3 = tonumber(b.t1) or 0, tonumber(b.t2) or 0, tonumber(b.t3) or 0
      end
    end
    C.gear.specimport = "1"
  end

  -- ---------------------------------------------------------------- the device's menu

  local menu, session = nil, 0

  -- the game's own list (always there); index = its place, for SelectGossipOption
  function GS.PlainOptions()
    local out = {}
    local t = { GetGossipOptions() }
    for i = 1, table.getn(t), 2 do
      table.insert(out, { text = t[i] or "", index = (i + 1) / 2 })
    end
    return out
  end
  -- ClassicAPI's list (option ids) when it reads as the device; else the game's
  function GS.Options()
    if C_GossipInfo and C_GossipInfo.GetOptions then
      local ok, list = pcall(C_GossipInfo.GetOptions)
      if ok and type(list) == "table" then
        local out = {}
        for i, o in ipairs(list) do
          if type(o) == "table" then
            table.insert(out, { text = o.name or o.text or o.title or "", id = o.gossipOptionID, index = i })
          end
        end
        if GS.Read(out) then return out end
      end
    end
    return GS.PlainOptions()
  end

  -- The device lists the points per tree in its own order, which need not be
  -- the game's (user, 26 Oct 2026: a Shadow priest's "33/18/0" read as 33
  -- Discipline, and no slot showed ACTIVE). Learnt by comparing a slot's split
  -- with the talents you have now: the one way round that makes them equal
  -- (C.gear.specorder, e.g. "3,2,1"); kept for later, also away from the device.
  GS.PERMS = { { 1, 2, 3 }, { 3, 2, 1 }, { 1, 3, 2 }, { 2, 1, 3 }, { 2, 3, 1 }, { 3, 1, 2 } }
  function GS.TreeOrder(m)
    local c = { GS.Split() }
    if m and c[1] + c[2] + c[3] > 0 then
      local found, count = nil, 0
      for _, perm in ipairs(GS.PERMS) do
        local fits
        for _, d in pairs(m.split) do
          if d[1] == c[perm[1]] and d[2] == c[perm[2]] and d[3] == c[perm[3]] then fits = true end
        end
        if fits then count = count + 1 found = found or perm end
      end
      -- (only one way round fits: learnt; more than one = these numbers cannot tell)
      if count == 1 then C.gear.specorder = table.concat(found, ",") end
    end
    local out = {}
    for n in string.gfind(C.gear.specorder or "", "%d") do table.insert(out, tonumber(n)) end
    if table.getn(out) == 3 then return out end
    return { 1, 2, 3 }
  end
  -- the device's splits in the game's tree order
  function GS.Normalize(m)
    local perm = GS.TreeOrder(m)
    for slot, d in pairs(m.split) do
      local t = {}
      for i = 1, 3 do t[perm[i]] = d[i] end
      m.split[slot] = t
    end
    return m
  end

  -- the menu as slots; nil for any other NPC
  function GS.Read(options)
    local m = { save = {}, activate = {}, split = {}, buy = {}, slots = 0 }
    local device
    for _, o in ipairs(options) do
      local text = o.text
      local _, _, save = string.find(text, "Save (%d+).. Specialization")
      local _, _, act = string.find(text, "Activate (%d+).. Specialization")
      local _, _, buy, price = string.find(text, "Buy (%d+).. Specialization.* (%d+) gold")
      local slot = tonumber(save or act or buy)
      if slot and slot >= 1 and slot <= MAX then
        device = true
        if slot > m.slots then m.slots = slot end
        if save then
          m.save[slot] = o
        elseif act then
          m.activate[slot] = o
          local _, _, a, b, c = string.find(text, "%((%d+)/(%d+)/(%d+)%)")
          if a then m.split[slot] = { tonumber(a), tonumber(b), tonumber(c) } end
        else
          m.buy[slot] = { option = o, price = tonumber(price) or 0 }
        end
      elseif string.find(text, "Reset my talents") then
        local _, _, g, s, c = string.find(text, "%((%d+)g(%d+)s(%d+)c%)")
        local price
        if g then
          local parts = {}
          if tonumber(g) > 0 then table.insert(parts, tonumber(g) .. "g") end
          if tonumber(s) > 0 then table.insert(parts, tonumber(s) .. "s") end
          if tonumber(c) > 0 then table.insert(parts, tonumber(c) .. "c") end
          if table.getn(parts) > 0 then price = table.concat(parts, " ") end
        end
        m.reset = { option = o, price = price }
      end
    end
    return device and GS.Normalize(m) or nil
  end

  -- the game's SelectGossipOption as it was before ours (below) wrapped it
  GS.rawSelect = _G.SelectGossipOption
  local function Choose(o, owner)
    if not (menu and owner == session and o) then return end
    if o.id and C_GossipInfo and C_GossipInfo.SelectOption then
      C_GossipInfo.SelectOption(o.id)
    else
      GS.rawSelect(o.index)
    end
    return true
  end

  function GS.Ask(text, yes) CreateQuestionDialog(text, yes) end
  -- every option asks first (user, 25 Oct 2026: Reset and Save went through
  -- without a word: the 1.12 client shows no box for the server's own confirm)
  local function Confirm(o, text, action)
    local owner = session
    if C.gear.specconfirm == "0" then action(owner) return end
    local open = _G["pfQuestionDialog"]
    if open and open:IsShown() then open:Hide() _G["pfQuestionDialog"] = nil end
    GS.Ask(text, function() action(owner) end)
  end

  -- the questions, with what each one does
  local function SplitWords(a, b, c)
    if a + b + c == 0 then return "no talents" end
    return a .. "/" .. b .. "/" .. c
  end
  function GS.Question(kind, slot, m)
    m = m or menu
    local name = slot and GS.Name(slot)
    if kind == "activate" then
      local s = GS.Spec(slot)
      local then_ = {}
      if s and s.set ~= "" then table.insert(then_, "wear " .. s.set) end
      if s and s.layout ~= "" then table.insert(then_, "switch to the " .. s.layout .. " layout") end
      if s and s.ownbars ~= "0" then table.insert(then_, "put its own spells on your bars") end
      return "|cff55ff77Activate " .. name .. "|r (" .. SplitWords(GS.SlotSplit(slot)) .. ")?\n\n"
        .. "The device swaps your talents for this spec's and gives you a debuff."
        .. (table.getn(then_) > 0 and ("\nThen pfUI will " .. table.concat(then_, ", ") .. ".") or "")
    elseif kind == "save" then
      local now = SplitWords(GS.Split())
      if m and m.activate[slot] then
        return "|cffffd100Save over " .. name .. "?|r\n\nYour talents now (" .. now .. ") go into slot " .. slot
          .. ".\n|cffff5555What " .. name .. " holds (" .. SplitWords(GS.SlotSplit(slot)) .. ") is lost - this cannot be undone.|r"
      end
      return "|cffffd100Save into empty slot " .. slot .. "?|r\n\nYour talents now (" .. now .. ") are kept there, "
        .. "so you can switch back to them later."
    elseif kind == "reset" then
      local price = m and m.reset and m.reset.price
      return "|cffff5555Reset all your talents" .. (price and (" for " .. price) or "") .. "?|r\n\n"
        .. "Every talent point comes back to spend again and the device gives you a debuff. Your saved specs stay saved."
        .. "\nSpend every point before you leave: the device's warning says unspent points make it reboot."
    elseif kind == "buy" then
      local price = m and m.buy[slot] and m.buy[slot].price or 0
      return "|cffffd100Buy talent slot " .. slot .. " for " .. price .. " gold?|r\n\nA new slot to save another spec in."
    end
  end

  -- the device's own menu asks too ("Show original", or this window off):
  -- the game's SelectGossipOption is wrapped while the device is the one talking
  function GS.KindAt(m, index)
    for slot, o in pairs(m.activate) do if o.index == index then return "activate", slot end end
    for slot, o in pairs(m.save) do if o.index == index then return "save", slot end end
    for slot, b in pairs(m.buy) do if b.option.index == index then return "buy", slot end end
    if m.reset and m.reset.option.index == index then return "reset" end
  end
  _G.SelectGossipOption = function(index, a, b)
    if C.gear.specconfirm == "0" or GS.passing then return GS.rawSelect(index, a, b) end
    local ok, m = pcall(function() return GS.Read(GS.PlainOptions()) end)
    local kind, slot
    if ok and m then kind, slot = GS.KindAt(m, index) end
    if not kind then return GS.rawSelect(index, a, b) end
    if kind == "activate" and GS.IsActive(slot) then Say(GS.Name(slot) .. " is already on.") return end
    local open = _G["pfQuestionDialog"]
    if open and open:IsShown() then open:Hide() _G["pfQuestionDialog"] = nil end
    GS.Ask(GS.Question(kind, slot, m), function()
      if kind == "activate" then GS.Leave() end
      GS.passing = true
      GS.rawSelect(index, a, b)
      GS.passing = nil
      if kind == "activate" then GS.Watch(slot) end
      if kind == "save" then GS.Saved(slot) end
      if kind == "reset" then C.gear.specnow = nil end
    end)
  end

  -- a slot's split: the device's, else what was saved
  function GS.SlotSplit(slot)
    local sp = menu and menu.split[slot]
    if sp then return sp[1], sp[2], sp[3] end
    local s = GS.Spec(slot)
    if s then return s.t1 or 0, s.t2 or 0, s.t3 or 0 end
    return 0, 0, 0
  end
  function GS.IsActive(slot)
    local a, b, c = GS.SlotSplit(slot)
    local x, y, z = GS.Split()
    if a + b + c == 0 then return false end
    if a == x and b == y and c == z then
      -- (two slots with one split: the one switched to last)
      local other = C.gear.specnow and tonumber(C.gear.specnow)
      if other and other ~= slot then
        local oa, ob, oc = GS.SlotSplit(other)
        if oa == a and ob == b and oc == c then return false end
      end
      return true
    end
    return false
  end

  -- ---------------------------------------------------------------- switching

  local watch = nil      -- { slot, before = { split }, at, deadline, changed }
  local later = nil      -- a slot whose layout / spells wait for combat to end

  -- the spec is in: its gear, its layout, its spells
  function GS.Apply(slot, why)
    local s = GS.Ensure(slot)
    C.gear.specnow = tostring(slot)
    s.t1, s.t2, s.t3 = GS.Split()
    local told = {}
    if s.set ~= "" and C.gear.sets[s.set] then
      if not GR.IsEquipped(s.set) then GR.Equip(s.set) end
      table.insert(told, "wearing " .. s.set)
    end
    if UnitAffectingCombat("player") then
      later = slot
      Say(s.name .. (table.getn(told) > 0 and (": " .. told[1]) or "") .. "; layout and spells go on when combat ends.")
      return
    end
    later = nil
    local L = pfUI.layouts
    if s.layout ~= "" and L and L.Switch and L.Store().current ~= s.layout then
      -- (the bars on now were kept for the spec left; the layout must not keep them for this one)
      L.holdBars = true
      L.Switch(s.layout, s.name)
      L.holdBars = nil
      table.insert(told, s.layout .. " layout")
    end
    if s.ownbars ~= "0" and L and L.WriteBars then
      local bars = s.bars and s.bars[LayoutNow()]
      if bars then
        L.WriteBars(bars)
        table.insert(told, "its spells")
      end
    end
    if C.gear.spectell ~= "0" then
      Say(s.name .. " is on" .. (why and (" (" .. why .. ")") or "") .. (table.getn(told) > 0 and (": " .. table.concat(told, ", ")) or "") .. ".")
    end
    GS.Paint()
  end

  -- the spec being left keeps what is on the bars now
  function GS.Leave()
    local s = GS.BarSpec()
    local L = pfUI.layouts
    if s and L and L.ReadBars then s.bars[LayoutNow()] = L.ReadBars() end
  end

  local function Watch(slot)
    local a, b, c = GS.Split()
    watch = { slot = slot, before = { a, b, c }, deadline = GetTime() + TIMEOUT }
  end
  GS.Watch = Watch

  -- the talents on now went into this slot
  function GS.Saved(slot)
    local s = GS.Ensure(slot)
    s.t1, s.t2, s.t3 = GS.Split()
    -- (the spec left keeps its bars; the slot saved is the one you are in now, with the bars on now)
    GS.Leave()
    C.gear.specnow = tostring(slot)
    GS.Leave()
    GS.Paint()
  end

  -- talents / spells changed: wait for them to settle
  function GS.OnTalents(points)
    if watch then
      if not (watch.changed or points) then
        local a, b, c = GS.Split()
        local t = watch.before
        local sa, sb, sc = GS.SlotSplit(watch.slot)
        -- (a swap to the same split only shows as spells changing)
        local same = sa == t[1] and sb == t[2] and sc == t[3]
        if a == t[1] and b == t[2] and c == t[3] and not same then return end
      end
      watch.changed = true
      watch.at = GetTime() + SETTLE
      return
    end
    -- changed some other way: a split that is one spec's
    if C.gear.specnotice == "0" then return end
    local a, b, c = GS.Split()
    if a + b + c == 0 then C.gear.specnow = nil return end
    local slot = GS.Match(a, b, c)
    if slot and tostring(slot) ~= C.gear.specnow then
      GS.pendingNotice = { slot = slot, at = GetTime() + SETTLE }
    end
  end

  function GS.Tick()
    local now = GetTime()
    if watch then
      if watch.changed and watch.at and now >= watch.at then
        local slot = watch.slot
        watch = nil
        GS.Apply(slot)
      elseif not watch.changed and now > watch.deadline then
        watch = nil
        Say("the talents did not change, so gear and bars were left as they are.")
      end
    end
    local n = GS.pendingNotice
    if n and now >= n.at then
      GS.pendingNotice = nil
      local a, b, c = GS.Split()
      -- (only noted: gear, layout and spells change only when you switch
      -- yourself - user, 31 Oct 2026: bars swapped to another spec's at random)
      if GS.Match(a, b, c) == n.slot then
        C.gear.specnow = tostring(n.slot)
        GS.Paint()
      end
    end
  end

  function GS.Activate(slot)
    if not menu then Say("talk to a Goblin Brainwashing Device to switch specs.") return end
    local buy = menu.buy[slot]
    if buy then
      Confirm(buy.option, GS.Question("buy", slot), function(owner) Choose(buy.option, owner) end)
      return
    end
    local o = menu.activate[slot]
    if not o then return end
    if GS.IsActive(slot) then Say(GS.Name(slot) .. " is already on.") return end
    Confirm(o, GS.Question("activate", slot), function(owner)
      GS.Leave()
      if Choose(o, owner) then Watch(slot) end
    end)
  end

  function GS.Save(slot)
    local o = menu and menu.save[slot]
    if not o then return end
    Confirm(o, GS.Question("save", slot), function(owner)
      if Choose(o, owner) then GS.Saved(slot) end
    end)
  end

  function GS.Reset()
    local r = menu and menu.reset
    if not r then return end
    Confirm(r.option, GS.Question("reset"), function(owner) if Choose(r.option, owner) then C.gear.specnow = nil end end)
  end

  function GS.AskRename(slot)
    local s = GS.Ensure(slot)
    local open = _G["pfQuestionDialog"]
    if open and open:IsShown() then open:Hide() _G["pfQuestionDialog"] = nil end
    CreateQuestionDialog("Name for talent slot " .. slot .. ":", function()
      local box = this:GetParent().input
      local v = box and string.gsub(box:GetText() or "", "^%s*(.-)%s*$", "%1")
      if v and v ~= "" then s.name = string.sub(v, 1, 24) GS.Paint() end
    end, false, true)
    local d = _G["pfQuestionDialog"]
    if d and d.input then d.input:SetText(s.name) d.input:SetScript("OnEditFocusGained", function() this:HighlightText() end) d.input:SetFocus() d.input:HighlightText() end
  end

  -- ---------------------------------------------------------------- the window

  -- (user, 25 Oct 2026: "more colour ... it looks very dull"; "it should be
  -- clear whats what") class colour across the top, each tree its own colour,
  -- green Activate, gold Save, red Reset, a line saying what each one does
  local OU = pfUI.octoui
  local W = OU and OU.W
  local P = W and W.C or { bg = { .067, .071, .078 }, panel = { .094, .098, .11 }, card = { .125, .13, .145 },
    line = { .23, .24, .27 }, text = { .92, .92, .93 }, dim = { .6, .61, .65 }, on = { .22, .72, .42 } }
  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local GREEN, GOLD, RED, GREY = { .25, .85, .4 }, { 1, .78, .2 }, { .95, .3, .3 }, { .55, .57, .62 }
  -- the three talent trees' colours
  GS.TREE = { { 1, .55, .2 }, { .35, .7, 1 }, { .55, .9, .35 } }
  local function ClassColor()
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return Accent()
  end
  local function Hex(r, g, b) return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255) end
  local function Flat(f, col, a)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(col[1], col[2], col[3], a or 1)
    f:SetBackdropBorderColor(P.line[1], P.line[2], P.line[3], 1)
  end
  local function Font(fs, size, col)
    if W then W.Font(fs, size, col[1], col[2], col[3]) else fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") fs:SetTextColor(col[1], col[2], col[3]) end
    return fs
  end
  -- a button tinted in a colour (dark fill, bright edge and words)
  local function Button(parent, text, w, col, h)
    local b
    if W then b = W.Button(parent, text, w, h or 22) else
      b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
      b:SetWidth(w) b:SetHeight(h or 22) b:SetText(text)
    end
    if col and b.SetBackdropColor then
      local function Paint()
        b:SetBackdropColor(col[1] * .3, col[2] * .3, col[3] * .3, 1)
        b:SetBackdropBorderColor(col[1] * .85, col[2] * .85, col[3] * .85, 1)
      end
      Paint()
      if b.label then b.label:SetTextColor(math.min(1, col[1] + .25), math.min(1, col[2] + .25), math.min(1, col[3] + .25)) end
      b:SetScript("OnMouseUp", Paint)
    end
    return b
  end
  local function Tip(frame, title, text)
    if W then W.Tip(frame, title, text) end
  end
  local function Grad(t, r, g, b, a1, a2, horiz)
    t:SetTexture(WHITE)
    -- (the colour goes in the gradient itself: a gradient in white over a
    -- vertex colour paints the corners white on the client)
    if t.SetGradientAlpha then
      t:SetVertexColor(1, 1, 1, 1)
      t:SetGradientAlpha(horiz and "HORIZONTAL" or "VERTICAL", r, g, b, a1, r, g, b, a2)
    else
      t:SetVertexColor(r, g, b, math.max(a1, a2))
    end
  end

  local WIDTH, ROWH, TOP = 720, 54, 112
  local f = CreateFrame("Frame", "pfGearSpecs", UIParent)
  GS.frame = f
  f:SetWidth(WIDTH)
  f:SetHeight(200)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  Flat(f, P.bg, .97)
  f:Hide()
  table.insert(UISpecialFrames, "pfGearSpecs")

  -- the top: class colour fading out, the device's picture, title
  local top = CreateFrame("Frame", nil, f)
  top:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
  top:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
  top:SetHeight(46)
  top:EnableMouse(true)
  top:RegisterForDrag("LeftButton")
  top:SetScript("OnDragStart", function() f:StartMoving() end)
  top:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
  local shade = top:CreateTexture(nil, "BACKGROUND")
  shade:SetAllPoints(top)
  local line = top:CreateTexture(nil, "ARTWORK")
  line:SetPoint("BOTTOMLEFT", top, "BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", 0, 0)
  line:SetHeight(2)
  local logo = top:CreateTexture(nil, "ARTWORK")
  logo:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowWordDominate")
  logo:SetTexCoord(.07, .93, .07, .93)
  logo:SetWidth(34) logo:SetHeight(34)
  logo:SetPoint("LEFT", top, "LEFT", 8, 0)
  local title = Font(top:CreateFontString(nil, "OVERLAY"), 16, { 1, 1, 1 })
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -1)
  title:SetText("Talent specs")
  local sub = Font(top:CreateFontString(nil, "OVERLAY"), 11, { .85, .86, .9 })
  sub:SetPoint("BOTTOMLEFT", logo, "BOTTOMRIGHT", 10, 1)
  f.sub = sub
  local close = Button(top, "x", 24, RED, 22)
  close:SetPoint("RIGHT", top, "RIGHT", -8, 0)
  -- (x ends the talk with the device; Escape and Show original bring its menu back)
  close:SetScript("OnClick", function() f:Hide() if menu then CloseGossip() end end)
  Tip(close, "Close", "Closes this window and ends the talk with the device.")
  function GS.PaintTop()
    local r, g, b = ClassColor()
    Grad(shade, r, g, b, .1, .55, true)
    line:SetTexture(WHITE)
    line:SetVertexColor(r, g, b, 1)
  end

  -- what each thing does, in colour
  local help = Font(f:CreateFontString(nil, "OVERLAY"), 11, P.text)
  help:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -54)
  help:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -54)
  help:SetJustifyH("LEFT")
  help:SetJustifyV("TOP")
  help:SetHeight(30)
  f.help = help

  -- column heads
  local heads = {}
  local COLS = { { "Spec  (click the picture or Activate to switch)", 12 }, { "Gear set", 262 }, { "UI layout", 404 }, { "Own spells", 494 } }
  for i, c in ipairs(COLS) do
    local h = Font(f:CreateFontString(nil, "OVERLAY"), 10, { Accent() })
    h:SetPoint("TOPLEFT", f, "TOPLEFT", c[2], -96)
    h:SetText(c[1])
    heads[i] = h
  end

  local function SetList()
    local out = { { key = "", label = "- no set -" } }
    for _, n in ipairs(GR.Sets()) do
      local set = C.gear.sets[n]
      table.insert(out, { key = n, label = n, icon = set and set.icon })
    end
    return out
  end
  local function LayoutList()
    local out = { { key = "", label = "- keep -" } }
    local L = pfUI.layouts
    for _, n in ipairs(L and L.NAMES or {}) do
      table.insert(out, { key = n, label = (L.Hex and L.Hex(n) or "") .. n .. "|r", icon = L.Icon and L.Icon(n) or (L.ICON and L.ICON[n]) })
    end
    return out
  end

  -- a split as text, each tree in its colour, the biggest bright
  function GS.SplitText(a, b, c)
    if a + b + c == 0 then return "|cff999999no talents saved|r" end
    local n = { a, b, c }
    local out = {}
    for i = 1, 3 do
      local t = GS.TREE[i]
      local k = n[i] > 0 and 1 or .45
      table.insert(out, Hex(t[1] * k, t[2] * k, t[3] * k) .. n[i] .. "|r")
    end
    -- (the main tree by name, so a split can not be read the wrong way round:
    -- user, 26 Oct 2026)
    local big, bi = -1, 1
    for i = 1, 3 do if n[i] > big then big, bi = n[i], i end end
    local tname = GetTalentTabInfo and GetTalentTabInfo(bi)
    local t = GS.TREE[bi]
    return table.concat(out, "|cff6a6d76 / |r") .. (tname and ("   " .. Hex(t[1], t[2], t[3]) .. tname .. "|r") or "")
  end
  -- your talents now and whether a slot holds them (user, 26 Oct 2026: both
  -- slots held one spec and the one in use was in none - say so plainly)
  function GS.NowText()
    local a, b, c = GS.Split()
    local where
    if menu then
      for slot in pairs(menu.activate) do
        if GS.IsActive(slot) then where = slot end
      end
    end
    local tail
    if a + b + c == 0 then
      tail = ""
    elseif where then
      tail = "   |cff55ff77in " .. GS.Name(where) .. "|r"
    else
      tail = "   |cffffd100in no slot - Save here keeps them|r"
    end
    return "Your talents now: " .. GS.SplitText(a, b, c) .. tail
  end

  -- the tree a split puts most points in (1-3), or nil
  local function MainTree(a, b, c)
    if a + b + c == 0 then return nil end
    if a >= b and a >= c then return 1 elseif b >= c then return 2 end
    return 3
  end

  local rows = {}
  local function Row(slot)
    if rows[slot] then return rows[slot] end
    local r = CreateFrame("Frame", nil, f)
    r.slot = slot
    r:SetWidth(WIDTH - 16)
    r:SetHeight(ROWH - 6)
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -TOP - (slot - 1) * ROWH)
    Flat(r, P.card, 1)
    r:EnableMouse(true)
    -- the main tree's colour: a stripe on the left, fading across the row
    r.stripe = r:CreateTexture(nil, "ARTWORK")
    r.stripe:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -1)
    r.stripe:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 1, 1)
    r.stripe:SetWidth(4)
    r.stripe:SetTexture(WHITE)
    r.wash = r:CreateTexture(nil, "BORDER")
    r.wash:SetPoint("TOPLEFT", r, "TOPLEFT", 5, -1)
    r.wash:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 5, 1)
    r.wash:SetWidth(300)

    local ib = CreateFrame("Button", nil, r)
    ib:SetWidth(38) ib:SetHeight(38)
    ib:SetPoint("LEFT", r, "LEFT", 10, 0)
    ib:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.icon = ib:CreateTexture(nil, "ARTWORK")
    r.icon:SetAllPoints(ib)
    r.icon:SetTexCoord(.07, .93, .07, .93)
    local hl = ib:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(ib)
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")
    ib:SetScript("OnClick", function()
      if arg1 == "RightButton" then GS.PickIcon(slot, this) else GS.Activate(slot) end
    end)
    ib:SetScript("OnEnter", function() GS.Tip(slot, this) end)
    ib:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.ib = ib

    r.name = Font(r:CreateFontString(nil, "OVERLAY"), 13, P.text)
    r.name:SetPoint("TOPLEFT", ib, "TOPRIGHT", 9, -3)
    r.name:SetWidth(150)
    r.name:SetJustifyH("LEFT")
    r.active = Font(r:CreateFontString(nil, "OVERLAY"), 10, GREEN)
    r.active:SetPoint("LEFT", r.name, "RIGHT", -150, 0)
    r.split = Font(r:CreateFontString(nil, "OVERLAY"), 12, P.dim)
    r.split:SetPoint("BOTTOMLEFT", ib, "BOTTOMRIGHT", 9, 3)
    r.split:SetWidth(190)
    r.split:SetJustifyH("LEFT")

    if W then
      local gear, gearPaint = W.MiniDrop(r, 132, SetList, function() return GS.Ensure(slot).set end,
        function(v) GS.Ensure(slot).set = v GS.Paint() end, 180)
      gear:SetPoint("LEFT", r, "LEFT", 254, 0)
      local lay, layPaint = W.MiniDrop(r, 92, LayoutList, function() return GS.Ensure(slot).layout end,
        function(v) GS.Ensure(slot).layout = v GS.Paint() end, 140)
      lay:SetPoint("LEFT", r, "LEFT", 396, 0)
      local own = W.CheckBox(r, 18)
      own:SetPoint("LEFT", r, "LEFT", 506, 0)
      own:SetScript("OnClick", function()
        GS.Ensure(slot).ownbars = this:GetChecked() and "1" or "0"
      end)
      Tip(own, "Its own spells", "This spec keeps what is on your action bars: leaving it remembers them, "
        .. "coming back puts them back (for each UI layout).")
      r.gearPaint, r.layPaint, r.own = gearPaint, layPaint, own
    end

    r.go = Button(r, "Activate", 66, GREEN)
    r.go:SetPoint("LEFT", r, "LEFT", 530, 0)
    r.go:SetScript("OnClick", function() GS.Activate(slot) end)
    Tip(r.go, "Activate", "Switch to this spec. Asks first; the device gives a debuff.")
    r.save = Button(r, "Save here", 58, GOLD)
    r.save:SetPoint("LEFT", r.go, "RIGHT", 4, 0)
    r.save:SetScript("OnClick", function() GS.Save(slot) end)
    Tip(r.save, "Save here", "Put the talents you have NOW into this slot. What the slot held is lost. Asks first.")
    r.edit = Button(r, "Name", 36, GREY)
    r.edit:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    r.edit:SetScript("OnClick", function() GS.AskRename(slot) end)
    Tip(r.edit, "Name", "Give this spec a name. Right-click its picture to change the picture.")
    rows[slot] = r
    return r
  end

  function GS.Tip(slot, owner)
    local s = GS.Spec(slot)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if menu and menu.buy[slot] then
      GameTooltip:AddLine("Buy talent slot " .. slot)
      GameTooltip:AddLine(menu.buy[slot].price .. " gold", 1, .82, 0)
      GameTooltip:Show()
      return
    end
    GameTooltip:AddLine(GS.Name(slot))
    local a, b, c = GS.SlotSplit(slot)
    local n = { a, b, c }
    if a + b + c > 0 then
      for i = 1, 3 do
        local t = GS.TREE[i]
        GameTooltip:AddDoubleLine(GetTalentTabInfo(i) or ("Tree " .. i), n[i], t[1], t[2], t[3], 1, 1, 1)
      end
    end
    if GS.IsActive(slot) then GameTooltip:AddLine("Active now", .3, 1, .4) end
    if s and s.set ~= "" then GameTooltip:AddLine("Gear: " .. s.set .. (C.gear.sets[s.set] and "" or " (set no longer there)"), .8, .8, .8) end
    if s and s.layout ~= "" then GameTooltip:AddLine("UI layout: " .. s.layout, .8, .8, .8) end
    if s and s.ownbars ~= "0" then
      GameTooltip:AddLine("Own spells: " .. ((s.bars and s.bars[LayoutNow()]) and "kept" or "kept once you leave it"), .8, .8, .8)
    end
    if menu then GameTooltip:AddLine("Click: activate it (asks first)", .4, 1, .5) else GameTooltip:AddLine("Switch at a Goblin Brainwashing Device", .6, .6, .6) end
    GameTooltip:AddLine("Right-click: pick a picture", .6, .8, 1)
    GameTooltip:Show()
  end

  function GS.PickIcon(slot, owner)
    local GO = pfUI.gearOcto
    if not (GO and GO.IconPicker) then return end
    local s = GS.Ensure(slot)
    local extra = {}
    for i = 1, 3 do
      local _, tex = GetTalentTabInfo(i)
      if tex then table.insert(extra, tex) end
    end
    local p = GO.IconPicker(owner, s.icon, extra, function(path) s.icon = path GS.Paint() end)
    if p then p:SetFrameStrata("FULLSCREEN_DIALOG") end
  end

  -- bottom buttons
  local reset = Button(f, "Reset talents", 170, RED)
  reset:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
  reset:SetScript("OnClick", function() GS.Reset() end)
  Tip(reset, "Reset talents", "Every talent point back to spend again, for the price shown. Asks first.")
  local original = Button(f, "Show original", 110, GREY)
  original:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
  original:SetScript("OnClick", function() f:Hide() end)
  Tip(original, "Show original", "Bring back the device's own menu (it asks before each choice too).")
  local opt = Button(f, "Options", 70)
  opt:SetPoint("RIGHT", original, "LEFT", -4, 0)
  opt:SetScript("OnClick", function() GS.OpenOptions() end)
  local layBtn = Button(f, "UI layouts", 84, { .7, .45, 1 })
  layBtn:SetPoint("RIGHT", opt, "LEFT", -4, 0)
  layBtn:SetScript("OnClick", function() local O = OU and OU.Options if O then O:Open("layouts") end end)
  Tip(layBtn, "UI layouts", "Make and arrange the layouts picked here (frames, bars and spells).")
  local gearBtn = Button(f, "Gear sets", 80, { .35, .7, 1 })
  gearBtn:SetPoint("RIGHT", layBtn, "LEFT", -4, 0)
  gearBtn:SetScript("OnClick", function() if pfUI.gearOcto and pfUI.gearOcto.Open then pfUI.gearOcto.Open() end end)
  Tip(gearBtn, "Gear sets", "Make or change the gear sets picked here.")
  f.reset, f.original = reset, original

  function GS.Paint()
    if not f:IsShown() then return end
    GS.PaintTop()
    local count
    if menu then
      count = menu.slots
      f.sub:SetText(GS.NowText())
      f.help:SetText("|cff55ff77Activate|r switches to a spec (the device gives a debuff).   |cffffd100Save here|r puts the "
        .. "talents you have now into that slot - what it held is lost.   |cffff5555Reset|r gives back every talent point"
        .. (menu.reset and menu.reset.price and (" for " .. menu.reset.price) or "") .. ".   Every choice asks first.")
    else
      count = 0
      for k in pairs(C.gear.specs) do if tonumber(k) and tonumber(k) > count then count = tonumber(k) end end
      f.sub:SetText("Away from the device")
      f.help:SetText("Pick the gear set, UI layout and spells that go with each spec. |cff55ff77Switching|r happens at a "
        .. "Goblin Brainwashing Device.")
    end
    for slot = 1, MAX do
      local r = rows[slot]
      if slot <= count then
        r = Row(slot)
        local s = GS.Spec(slot)
        local buy = menu and menu.buy[slot]
        local owned = not menu or menu.activate[slot] or menu.save[slot]
        if menu and menu.split[slot] and s then
          -- (the device's split is the truth)
          s.t1, s.t2, s.t3 = menu.split[slot][1], menu.split[slot][2], menu.split[slot][3]
        end
        local active = owned and not buy and GS.IsActive(slot)
        local links = not buy and owned
        local tree
        if buy then
          r.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
          r.name:SetText("|cffffd100Buy slot " .. slot .. "|r")
          r.split:SetText("|cffffd100" .. buy.price .. " gold|r")
          r.stripe:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
          Grad(r.wash, GOLD[1], GOLD[2], GOLD[3], .18, 0, true)
        elseif owned and (s or (menu and menu.activate[slot])) then
          s = GS.Ensure(slot)
          r.icon:SetTexture(s.icon or ICON)
          local cr, cg, cb = ClassColor()
          r.name:SetText(Hex(cr, cg, cb) .. s.name .. "|r")
          local a, b, c = GS.SlotSplit(slot)
          r.split:SetText(GS.SplitText(a, b, c))
          tree = MainTree(a, b, c)
          local t = tree and GS.TREE[tree] or GREY
          r.stripe:SetVertexColor(t[1], t[2], t[3], 1)
          Grad(r.wash, t[1], t[2], t[3], .16, 0, true)
        else
          r.icon:SetTexture(ICON)
          r.name:SetText("|cff8a8d96Empty talent slot " .. slot .. "|r")
          r.split:SetText("|cffffd100Save here|r keeps your talents in it")
          r.stripe:SetVertexColor(GREY[1], GREY[2], GREY[3], 1)
          Grad(r.wash, GREY[1], GREY[2], GREY[3], .08, 0, true)
          links = menu and menu.save[slot] and true
        end
        if active then
          r.active:SetText("|cff55ff77ACTIVE|r")
          r:SetBackdropBorderColor(GREEN[1], GREEN[2], GREEN[3], 1)
        else
          r.active:SetText("")
          r:SetBackdropBorderColor(P.line[1], P.line[2], P.line[3], 1)
        end
        -- (the name is pushed right of ACTIVE's width: the tag sits after the name)
        r.active:ClearAllPoints()
        r.active:SetPoint("LEFT", r.name, "LEFT", math.min(140, (r.name.GetStringWidth and r.name:GetStringWidth() or 0) + 8), 0)
        if r.gearPaint then
          r.gearPaint() r.layPaint()
          r.own:SetChecked(GS.Ensure(slot).ownbars ~= "0")
          if links then r.own:Show() else r.own:Hide() end
        end
        if menu and (buy or (menu.activate[slot] and not active)) then
          r.go:SetText(buy and "Buy" or "Activate")
          r.go:Show()
        else
          r.go:Hide()
        end
        if menu and menu.save[slot] then r.save:Show() else r.save:Hide() end
        if links then r.edit:Show() else r.edit:Hide() end
        r:Show()
      elseif r then
        r:Hide()
      end
    end
    if menu and menu.reset then
      reset:SetText(menu.reset.price and ("Reset talents - " .. menu.reset.price) or "Reset talents")
      reset:Show()
    else
      reset:Hide()
    end
    if menu then original:Show() else original:Hide() end
    if count == 0 then
      f.help:SetText("No talent specs yet: talk to a Goblin Brainwashing Device.")
    end
    f:SetHeight(TOP + math.max(count, 1) * ROWH + 38)
  end

  -- the device's own window stays open (closing it ends the talk) but is
  -- shrunk and see-through so its hidden buttons cannot be clicked
  local hidden
  local function HideGossip()
    if hidden or not GossipFrame then return end
    hidden = { a = GossipFrame:GetAlpha(), s = GossipFrame:GetScale() }
    GossipFrame:SetAlpha(0)
    GossipFrame:SetScale(.01)
  end
  local function RestoreGossip()
    if not hidden then return end
    GossipFrame:SetScale(hidden.s)
    GossipFrame:SetAlpha(hidden.a)
    hidden = nil
  end

  f:SetScript("OnShow", function() GS.Paint() end)
  f:SetScript("OnHide", function()
    menu = nil
    session = session + 1
    RestoreGossip()
    if W and W.CloseMenus then W.CloseMenus() end
  end)

  -- away from the device
  function GS.Open()
    menu = nil
    session = session + 1
    if f:IsShown() then GS.Paint() else f:Show() end
  end
  function GS.Toggle()
    if f:IsShown() then f:Hide() else GS.Open() end
  end

  function GS.OnGossip()
    if f:IsShown() then f:Hide() end
    if C.gear.specwindow == "0" then return end
    local m = GS.Read(GS.Options())
    if not m then return end
    -- (Brainwasher Pro, if still on, opens its own: this one takes its place)
    local bwp = _G["BrainwasherProFrame"]
    if bwp and bwp:IsShown() then bwp:Hide() end
    menu = m
    session = session + 1
    local new
    for slot in pairs(m.activate) do
      if not GS.Spec(slot) then new = true end
      GS.Ensure(slot)
    end
    if new and OU and OU.Options and OU.Options.Rebuild then OU.Options:Rebuild("gearspecs") end
    HideGossip()
    f:Show()
    GS.Paint()
  end

  -- ---------------------------------------------------------------- events

  local ev = CreateFrame("Frame")
  GS.events = ev
  for _, e in ipairs({ "GOSSIP_SHOW", "GOSSIP_CLOSED", "CHARACTER_POINTS_CHANGED", "SPELLS_CHANGED",
                       "PLAYER_REGEN_ENABLED" }) do
    ev:RegisterEvent(e)
  end
  ev:SetScript("OnEvent", function()
    if event == "GOSSIP_SHOW" then
      GS.OnGossip()
    elseif event == "GOSSIP_CLOSED" then
      if menu and f:IsShown() then f:Hide() end
    elseif event == "CHARACTER_POINTS_CHANGED" or event == "SPELLS_CHANGED" then
      GS.OnTalents(event == "CHARACTER_POINTS_CHANGED")
      GS.Paint()
    elseif event == "PLAYER_REGEN_ENABLED" then
      if later then GS.Apply(later) end
    end
  end)
  ev:SetScript("OnUpdate", function()
    this.t = (this.t or 0) + arg1
    if this.t < .2 then return end
    this.t = 0
    if watch or GS.pendingNotice then GS.Tick() end
  end)
  GR.listeners.specs = function() GS.Paint() end

  -- ---------------------------------------------------------------- options page

  local O = OU and OU.Options
  function GS.OpenOptions()
    if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection("gearspecs")
    elseif O then O:Open("gearspecs") end
  end

  local slash = SlashCmdList.PFGEAR
  SlashCmdList.PFGEAR = function(msg)
    if string.lower(msg or "") == "specs" then GS.Toggle() return end
    slash(msg)
  end
  _G.SLASH_PFSPECS1 = "/specs"
  -- /specs debug: what the device menu reads as (when the window does not come up)
  function GS.Debug()
    Say("ClassicAPI gossip: " .. ((C_GossipInfo and C_GossipInfo.GetOptions) and "yes" or "no") .. ", window " .. (C.gear.specwindow == "0" and "off" or "on"))
    for _, o in ipairs(GS.PlainOptions()) do Say("  " .. o.index .. ": " .. o.text) end
    if C_GossipInfo and C_GossipInfo.GetOptions then
      local ok, list = pcall(C_GossipInfo.GetOptions)
      Say("  ClassicAPI list: " .. (ok and type(list) == "table" and (table.getn(list) .. " options") or tostring(list)))
      if ok and type(list) == "table" and type(list[1]) == "table" then
        for k, v in pairs(list[1]) do Say("    " .. tostring(k) .. " = " .. tostring(v)) end
      end
    end
    Say("  reads as the device: " .. (GS.Read(GS.Options()) and "yes" or "no"))
  end
  _G.SlashCmdList.PFSPECS = function(msg)
    if string.lower(msg or "") == "debug" then GS.Debug() return end
    GS.Toggle()
  end

  if not W or not O or not O.AddPage then return end
  local function Build(p)
    W.Heading(p, "Talent specs", {
      on = { function() return C.gear.specwindow ~= "0" end, function(v) C.gear.specwindow = v and "1" or "0" end,
        "pfUI's window at the Goblin Brainwashing Device (off: the device's own menu)." },
      about = "Talk to a Goblin Brainwashing Device and this window takes the place of its menu: each talent slot "
        .. "with its name, picture and talents. Pick a gear set and a UI layout for each; when you switch, the set "
        .. "goes on (armour after combat), the layout changes and the spec's own spells go back on your bars. "
        .. "/gear specs or /specs opens it anywhere to change what goes with each spec." })
    W.Buttons(p, {
      { "Open the specs window", function() GS.Open() end, 160, "Change the names, pictures, gear sets and layouts of your specs." },
      { "Gear sets", function() if pfUI.gearOcto then pfUI.gearOcto.Open() end end, 100, "Make the gear sets to pick from." },
    })
    W.Card(p, "Switching", { tip = "What happens when a spec goes on." })
    W.Check(p, "Say what changed", "A line in chat: the spec, the set and layout that went on.",
      function() return C.gear.spectell ~= "0" end, function(v) C.gear.spectell = v and "1" or "0" end)
    W.Check(p, "Notice other spec changes", "Talents changed some other way (the device's own menu, another addon): "
      .. "when they match one of your specs, this window marks it as on. Gear and spells are left alone.",
      function() return C.gear.specnotice ~= "0" end, function(v) C.gear.specnotice = v and "1" or "0" end)
    W.Check(p, "Ask before every device choice", "Activate, Save, Reset and Buy each ask first, with what they do - in "
      .. "this window and in the device's own menu.",
      function() return C.gear.specconfirm ~= "0" end, function(v) C.gear.specconfirm = v and "1" or "0" end)
    if IsAddOnLoaded and IsAddOnLoaded("BrainwasherPro") then
      W.Card(p, "Brainwasher Pro", { tip = "The Brainwasher Pro addon is on too." })
      W.Note(p, "Brainwasher Pro is on: pfUI's window takes its place at the device, and its names and pictures were "
        .. "copied over. It can be turned off.")
      W.Buttons(p, { { "Turn Brainwasher Pro off (reload)", function()
        DisableAddOn("BrainwasherPro")
        ReloadUI()
      end, 220, "Turns the addon off and reloads the UI." } })
    end
    local slots = {}
    for k in pairs(C.gear.specs) do if tonumber(k) then table.insert(slots, tonumber(k)) end end
    table.sort(slots)
    for _, slot in ipairs(slots) do
      local n = slot
      local tr = MainTree(GS.SlotSplit(n))
      local tc = tr and GS.TREE[tr] or GREY
      W.Card(p, Hex(tc[1], tc[2], tc[3]) .. GS.Name(n) .. "|r", { tip = "Talent slot " .. n .. ": " .. GS.SplitText(GS.SlotSplit(n)) })
      W.Dropdown(p, "Gear set", "Put on when this spec goes on.", SetList,
        function() return GS.Ensure(n).set end, function(v) GS.Ensure(n).set = v GS.Paint() end)
      W.Dropdown(p, "UI layout", "Switched to when this spec goes on.", LayoutList,
        function() return GS.Ensure(n).layout end, function(v) GS.Ensure(n).layout = v GS.Paint() end)
      W.Check(p, "Its own spells", "This spec keeps what is on your action bars (for each UI layout).",
        function() return GS.Ensure(n).ownbars ~= "0" end, function(v) GS.Ensure(n).ownbars = v and "1" or "0" end)
    end
    if table.getn(slots) == 0 then
      W.Note(p, "Your specs show up here after you talk to a Goblin Brainwashing Device.")
    end
  end
  O:AddPage("Gear", "gearspecs", "Talent specs", Build)
end)
