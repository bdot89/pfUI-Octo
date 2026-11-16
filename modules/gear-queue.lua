pfUI:RegisterModule("gear-queue", "vanilla", function ()
  -- pfUI Octo :: gear sets - the trinket queue (24 Oct 2026; user: TrinketMenu
  -- 12.0.6 "automatically swapping trinkets 30 seconds before the CD is over
  -- ... can we implement this into our gear addon"). TrinketMenu states no
  -- licence, so it was read for its rules only and this is written fresh.
  --
  -- Each trinket slot (13 top, 14 bottom) has an order of trinkets and a
  -- "stop here" mark. With the slot's queue on, once a second:
  --   * a trinket with 30 s or less of cooldown counts as ready (putting one
  --     on starts a 30 s cooldown anyway)
  --   * the worn one on cooldown -> the first ready one above the mark goes on
  --   * the worn one ready -> it stays, unless one higher up marked Priority
  --     is ready
  --   * the worn one passive (no "Use:") -> a ready one higher up goes on
  --   * Delay n: a worn trinket stays n seconds after it was used (its buff)
  --   * Pause: while that trinket is worn, the queue waits
  -- Swaps go through GR's queue, so they wait for combat to end, and while
  -- dead or casting. Alt-click a trinket bar button: that slot's queue on /
  -- off. GR.SetQueue(slot, "ON" | "OFF" | "PAUSE" | "RESUME" | "SORT", ...).
  local GR = pfUI.gear
  if not GR then return end
  local Q = {}
  GR.tq = Q
  local READY = 30

  local function Say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r gear: " .. msg) end
  local function Base(id) return id and (string.gsub(id, ":.*$", "")) end

  if type(C.gear.tqueue) ~= "table" then C.gear.tqueue = {} end
  if type(C.gear.tflags) ~= "table" then C.gear.tflags = {} end
  function Q.Slot(inv)
    local k = tostring(inv)
    local q = C.gear.tqueue[k]
    if type(q) ~= "table" then q = { on = "0", order = { "stop" } } C.gear.tqueue[k] = q end
    if type(q.order) ~= "table" then q.order = { "stop" } end
    return q
  end
  function Q.Flags(base)
    local f = C.gear.tflags[base]
    if type(f) ~= "table" then f = { prio = "0", pause = "0", delay = "0" } C.gear.tflags[base] = f end
    return f
  end

  -- ---------------------------------------------------------------- the trinkets you have

  local function IsTrinket(link)
    local loc = GR.EquipLoc and GR.EquipLoc(link)
    return loc == "INVTYPE_TRINKET"
  end

  -- every trinket carried or worn: base id -> { base, id, name, tex, bag, slot | inv }
  function Q.Known()
    local out = {}
    for _, inv in ipairs({ 13, 14 }) do
      local id, link = GR.Worn(inv)
      if id then
        local _, _, nm = string.find(link, "%[(.-)%]")
        out[Base(id)] = { base = Base(id), id = id, name = nm or "?", tex = GR.InvTex(inv), inv = inv }
      end
    end
    for _, b in ipairs(GR.Bags()) do
      local base = Base(b.id)
      if not out[base] and IsTrinket(b.link) then
        local _, _, nm = string.find(b.link, "%[(.-)%]")
        out[base] = { base = base, id = b.id, link = b.link, name = nm or "?", tex = (GetContainerItemInfo(b.bag, b.slot)), bag = b.bag, slot = b.slot }
      end
    end
    return out
  end

  -- the slot's order with every known trinket in it (new ones after the mark)
  function Q.Order(inv)
    local q = Q.Slot(inv)
    local seen, known = {}, Q.Known()
    for _, k in ipairs(q.order) do seen[k] = true end
    for base in pairs(known) do
      if not seen[base] then table.insert(q.order, base) seen[base] = true end
    end
    if not seen.stop then table.insert(q.order, "stop") end
    return q.order, known
  end

  -- seconds of cooldown left (0 = ready), and whether it has a cooldown at all
  local function Left(t)
    local start, dur, on
    if not t then return 0 end
    if t.inv then start, dur, on = GetInventoryItemCooldown("player", t.inv)
    elseif t.bag then start, dur, on = GetContainerItemCooldown(t.bag, t.slot) end
    if start and dur and dur > 1.5 and on == 1 then return math.max(0, start + dur - GetTime()), start end
    return 0
  end
  Q.Left = Left

  -- does it have a "Use:" (else it is passive: it never goes on cooldown)
  local useCache = {}
  local scan
  function Q.HasUse(t)
    if not t then return false end
    if useCache[t.base] ~= nil then return useCache[t.base] end
    if not scan then scan = CreateFrame("GameTooltip", "pfGearQueueScan", nil, "GameTooltipTemplate") end
    scan:SetOwner(WorldFrame, "ANCHOR_NONE")
    scan:ClearLines()
    if t.inv then scan:SetInventoryItem("player", t.inv) elseif t.bag then scan:SetBagItem(t.bag, t.slot) end
    local use = false
    for l = 2, 15 do
      local fs = getglobal("pfGearQueueScanTextLeft" .. l)
      local s = fs and fs:GetText()
      if s and string.find(s, "^" .. (ITEM_SPELL_TRIGGER_ONUSE or "Use:")) then use = true break end
    end
    scan:Hide()
    useCache[t.base] = use
    return use
  end

  -- ---------------------------------------------------------------- the queue

  Q.state = {}   -- per slot: "on", "delay", "pause", "off"

  local function Ready(t) return t and Q.Left(t) <= READY end

  -- what should go in slot inv now: a known trinket, or nil
  function Q.Pick(inv)
    local q = Q.Slot(inv)
    if q.on ~= "1" then Q.state[inv] = "off" return nil end
    if q.paused then Q.state[inv] = "pause" return nil end
    local order, known = Q.Order(inv)
    local otherWorn = GR.Worn(inv == 13 and 14 or 13)
    local wornId = GR.Worn(inv)
    local worn = wornId and known[Base(wornId)]
    if worn and Q.Flags(worn.base).pause == "1" then Q.state[inv] = "pause" return nil end
    -- a delay: the worn trinket stays that long after it was used
    if worn then
      local d = tonumber(Q.Flags(worn.base).delay) or 0
      local left, start = Q.Left(worn)
      if d > 0 and start and GetTime() - start < d then Q.state[inv] = "delay" return nil end
    end
    Q.state[inv] = "on"
    -- the candidates above the mark, in order (not the one in the other slot)
    local list, rank = {}, nil
    for _, k in ipairs(order) do
      if k == "stop" then break end
      local t = known[k]
      if t and not (otherWorn and Base(otherWorn) == k) then
        table.insert(list, t)
        if worn and k == worn.base then rank = table.getn(list) end
      end
    end
    local usable = worn and Q.HasUse(worn)
    if worn and usable and Ready(worn) then
      -- ready to use: only a ready Priority trinket above it takes over
      for i = 1, (rank or 1) - 1 do
        local t = list[i]
        if Q.Flags(t.base).prio == "1" and Ready(t) then return t end
      end
      return nil
    end
    if worn and not usable then
      -- passive: a ready one higher up takes over
      for i = 1, (rank or (table.getn(list) + 1)) - 1 do
        if Ready(list[i]) then return list[i] end
      end
      return nil
    end
    -- on cooldown (or nothing worn): the first ready one
    for _, t in ipairs(list) do
      if (not worn or t.base ~= worn.base) and Ready(t) then return t end
    end
    return nil
  end

  function Q.Process()
    if GR.queue then return end                                  -- a set swap is running
    if UnitAffectingCombat("player") then return end             -- trinkets wait for combat anyway
    if GR.Blocked and GR.Blocked() then return end
    for _, inv in ipairs({ 13, 14 }) do
      local t = Q.Pick(inv)
      if t and GR.EquipItem then
        if C.gear.tqtell == "1" then Say((inv == 13 and "top" or "bottom") .. " trinket: " .. t.name .. ".") end
        GR.EquipItem(inv, { id = t.id, link = t.link, bag = t.bag, slot = t.slot, name = t.name, tex = t.tex })
        return                                                     -- one swap at a time
      end
    end
  end

  local tick = CreateFrame("Frame")
  tick:SetScript("OnUpdate", function()
    this.t = (this.t or 0) + arg1
    if this.t < 1 then return end
    this.t = 0
    local any
    for _, inv in ipairs({ 13, 14 }) do
      if Q.Slot(inv).on == "1" then any = true end
    end
    if any then Q.Process() end
    Q.Paint()
  end)

  -- ---------------------------------------------------------------- switching

  function GR.ToggleQueue(inv)
    local q = Q.Slot(inv)
    q.on = (q.on == "1") and "0" or "1"
    q.paused = nil
    Say((inv == 13 and "Top" or "Bottom") .. " trinket queue " .. (q.on == "1" and "on." or "off."))
    Q.Paint()
    GR.Changed()
  end

  -- for scripts and other addons, as TrinketMenu.SetQueue
  function GR.SetQueue(inv, what, a1, a2, a3, a4, a5, a6, a7, a8)
    inv = (inv == 0 or inv == 13) and 13 or 14
    local q = Q.Slot(inv)
    what = string.upper(what or "")
    if what == "ON" then q.on, q.paused = "1", nil
    elseif what == "OFF" then q.on, q.paused = "0", nil
    elseif what == "PAUSE" then q.paused = (q.on == "1") or nil
    elseif what == "RESUME" then q.paused = nil
    elseif what == "SORT" then
      local known = Q.Known()
      local byName = {}
      for base, t in pairs(known) do byName[t.name] = base end
      local order = {}
      for _, n in ipairs({ a1, a2, a3, a4, a5, a6, a7, a8 }) do
        if byName[n] then table.insert(order, byName[n]) end
      end
      table.insert(order, "stop")
      q.order = order
    end
    Q.Paint()
    GR.Changed()
  end

  -- the trinket bar: a small gear in the corner - gold = queue on, grey =
  -- holding (delay), red = paused (TrinketMenu's colours)
  local COLOR = { on = { 1, .82, 0 }, delay = { .6, .6, .6 }, pause = { 1, .2, .2 } }
  function Q.Paint()
    local bar = GR.trinkets
    if not bar or not bar.slots then return end
    for _, b in pairs(bar.slots) do
      -- (25 Oct 2026, user: "the setting or cog does nothing ... right clicking
      -- does nothing either"): the cog is a button - left-click = queue on /
      -- off, right-click = the quick menu; shown dim while the queue is off
      if not b.qbtn then
        local q = CreateFrame("Button", nil, b)
        q:SetWidth(14)
        q:SetHeight(14)
        q:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
        q:SetFrameLevel(b:GetFrameLevel() + 4)
        q:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.qmark = q:CreateTexture(nil, "OVERLAY")
        b.qmark:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
        b.qmark:SetTexCoord(.08, .92, .08, .92)
        b.qmark:SetAllPoints(q)
        q.inv = b.inv
        q:SetScript("OnClick", function()
          if arg1 == "RightButton" then GR.QueueMenu(this, this.inv) else GR.ToggleQueue(this.inv) end
        end)
        q:SetScript("OnEnter", function()
          GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
          local qq = Q.Slot(this.inv)
          GameTooltip:AddLine((this.inv == 13 and "Top" or "Bottom") .. " trinket queue: " .. (qq.on == "1" and "|cff55ff77on|r" or "|cffff5555off|r"))
          GameTooltip:AddLine("When the trinket you wear goes on cooldown, the next ready one in the queue goes on.", 1, 1, 1, 1)
          GameTooltip:AddLine("Left-click: queue on / off", .6, .8, 1)
          GameTooltip:AddLine("Right-click: pick the trinkets and their order", .6, .8, 1)
          GameTooltip:Show()
        end)
        q:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b.qbtn = q
      end
      local st = Q.Slot(b.inv).on == "1" and (Q.state[b.inv] or "on") or "off"
      local c = COLOR[st]
      if c then
        b.qmark:SetVertexColor(c[1], c[2], c[3])
        b.qmark:SetAlpha(1)
      else
        b.qmark:SetVertexColor(.6, .6, .6)
        b.qmark:SetAlpha(.45)
      end
      b.qbtn:Show()
    end
  end

  -- the quick menu: queue on / off, pause, the order (click = first), the
  -- trinkets not in it yet (click = add), and the full page
  function GR.QueueMenu(owner, inv)
    local W2 = pfUI.octoui and pfUI.octoui.W
    if not W2 or not W2.Menu then return end
    if GR.qmenu then GR.qmenu:Hide() end
    local q = Q.Slot(inv)
    local order, known = Q.Order(inv)
    local opts = { { label = (inv == 13 and "Top" or "Bottom") .. " trinket queue", group = true } }
    table.insert(opts, { key = "toggle", label = q.on == "1" and "|cff55ff77ON|r - click to turn off" or "|cffff5555OFF|r - click to turn on" })
    if q.on == "1" then table.insert(opts, { key = "pause", label = q.paused and "Resume" or "Pause" }) end
    local before, after = {}, {}
    local past
    for _, base in ipairs(order) do
      if base == "stop" then past = true
      elseif known[base] then table.insert(past and after or before, base) end
    end
    -- (25 Oct 2026, user: the menu stays open and a click moves a trinket
    -- from one list to the other)
    table.insert(opts, { label = "In the queue", group = true })
    table.insert(opts, { label = "|cff8a8d96click: take out   right-click: to the top|r" })
    if table.getn(before) == 0 then table.insert(opts, { label = "|cff888888(none yet)|r" }) end
    for i, base in ipairs(before) do
      local t = known[base]
      table.insert(opts, { key = "in:" .. base, label = i .. ". " .. t.name .. (Q.Flags(base).prio == "1" and " |cffffd100(priority)|r" or ""), icon = t.tex })
    end
    if table.getn(after) > 0 then
      table.insert(opts, { label = "Not in it", group = true })
      table.insert(opts, { label = "|cff8a8d96click: add   right-click: add at the top|r" })
      for _, base in ipairs(after) do
        local t = known[base]
        table.insert(opts, { key = "out:" .. base, label = t.name, icon = t.tex })
      end
    end
    table.insert(opts, { key = "page", label = "All queue settings..." })
    local function Move(base, pos)
      for i = table.getn(q.order), 1, -1 do if q.order[i] == base then table.remove(q.order, i) end end
      if pos == "first" then
        table.insert(q.order, 1, base)
      elseif pos == "out" then
        -- (after the red mark: known, but not used)
        table.insert(q.order, base)
      else
        local at = table.getn(q.order) + 1
        for i, k in ipairs(q.order) do if k == "stop" then at = i break end end
        table.insert(q.order, at, base)
      end
    end
    GR.qmenu = W2.Menu(owner, opts, 260, function(k)
      local right = arg1 == "RightButton"
      if k == "page" then
        if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection("gearqueue")
        elseif pfUI.octoui and pfUI.octoui.Options then pfUI.octoui.Options:Open("gearqueue") end
        return
      end
      if k == "toggle" then GR.ToggleQueue(inv)
      elseif k == "pause" then GR.SetQueue(inv, q.paused and "RESUME" or "PAUSE")
      else
        local _, _, what, base = string.find(k, "^(%a+):(.+)$")
        if base then
          if what == "in" then
            Move(base, right and "first" or "out")
          else
            Move(base, right and "first" or "end")
            -- (a trinket added means the queue is wanted)
            if q.on ~= "1" then q.on = "1" Say((inv == 13 and "Top" or "Bottom") .. " trinket queue on.") end
          end
          Q.Paint()
          GR.Changed()
        end
      end
      -- (it stays open: the same menu again, with the change in it)
      GR.QueueMenu(owner, inv)
    end, true)
    GR.qmenu:SetFrameStrata("TOOLTIP")
    GR.qmenu:Show()
  end

  -- ---------------------------------------------------------------- options page

  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local K = W.C

  local ROWS, RH = 9, 26

  -- one slot's list: a box of rows (scrolls with the wheel), each a trinket
  -- or the stop mark, with up / down, Priority, Pause and Delay
  local function SlotList(p, inv)
    local q = Q.Slot(inv)
    local box = W.Box(p, ROWS * RH + 12)
    box.top = 0
    box.rows = {}
    local function Move(i, d)
      local order = Q.Order(inv)
      local j = i + d
      if j < 1 or j > table.getn(order) then return end
      order[i], order[j] = order[j], order[i]
      box:Fill()
    end
    for r = 1, ROWS do
      local row = CreateFrame("Frame", nil, box)
      row:SetHeight(RH - 2)
      row:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6 - (r - 1) * RH)
      row:SetPoint("RIGHT", box, "RIGHT", -6, 0)
      row.bg = W.Fill(row, { 1, 1, 1 }, .03, "BACKGROUND")
      row.bg:SetAllPoints(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetWidth(20)
      row.icon:SetHeight(20)
      row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
      row.icon:SetTexCoord(.07, .93, .07, .93)
      row.text = W.Font(row:CreateFontString(nil, "OVERLAY"), 11, K.text[1], K.text[2], K.text[3])
      row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
      row.text:SetWidth(200)
      row.text:SetJustifyH("LEFT")
      row.cd = W.Font(row:CreateFontString(nil, "OVERLAY"), 10, K.dim[1], K.dim[2], K.dim[3])
      row.cd:SetPoint("LEFT", row.text, "RIGHT", 4, 0)
      row.cd:SetWidth(70)
      row.cd:SetJustifyH("LEFT")
      row.up = W.Button(row, "^", 22, 20)
      row.down = W.Button(row, "v", 22, 20)
      row.down:SetPoint("RIGHT", row, "RIGHT", -2, 0)
      row.up:SetPoint("RIGHT", row.down, "LEFT", -2, 0)
      row.up:SetScript("OnClick", function() Move(this:GetParent().index, -1) end)
      row.down:SetScript("OnClick", function() Move(this:GetParent().index, 1) end)
      row.delay = W.NumberBox and W.NumberBox(row, 40) or W.EditBox(row, 40)
      row.delay:SetPoint("RIGHT", row.up, "LEFT", -8, 0)
      row.delay.OnNumber = function(text)
        local n = W.ParseNumber and W.ParseNumber(text)
        local base = row.base
        if base then Q.Flags(base).delay = tostring(math.max(0, math.floor(n or 0))) end
        box:Fill()
      end
      row.delay.Restore = function() if row.base then row.delay:SetText(Q.Flags(row.base).delay .. "s") end end
      W.Tip(row.delay, "Delay", "Keep this trinket on this many seconds after you use it (its buff), before the queue swaps it.")
      row.pause = W.CheckBox(row, 14)
      row.pause:SetPoint("RIGHT", row.delay, "LEFT", -24, 0)
      row.pause:SetScript("OnClick", function() if row.base then Q.Flags(row.base).pause = this:GetChecked() and "1" or "0" end end)
      W.Tip(row.pause, "Pause", "While this trinket is worn the queue waits (a Carrot on a Stick you swap in yourself).")
      row.prio = W.CheckBox(row, 14)
      row.prio:SetPoint("RIGHT", row.pause, "LEFT", -24, 0)
      row.prio:SetScript("OnClick", function() if row.base then Q.Flags(row.base).prio = this:GetChecked() and "1" or "0" end end)
      W.Tip(row.prio, "Priority", "Swap this in as soon as it is ready, even while the worn trinket is ready to use.")
      row:EnableMouseWheel(true)
      row:SetScript("OnMouseWheel", function() box.top = math.max(0, box.top - arg1) box:Fill() end)
      box.rows[r] = row
    end
    -- column titles
    local head = W.Font(box:CreateFontString(nil, "OVERLAY"), 10, K.dim[1], K.dim[2], K.dim[3])
    head:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -58, 2)
    head:SetText("Priority     Pause     Delay")
    function box:Fill()
      local order, known = Q.Order(inv)
      local n = table.getn(order)
      self.top = math.max(0, math.min(self.top, n - ROWS))
      for r = 1, ROWS do
        local row = self.rows[r]
        local i = self.top + r
        local k = order[i]
        row.index = i
        if not k then
          row:Hide()
        elseif k == "stop" then
          row.base = nil
          row:Show()
          row.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
          row.text:SetText("|cffff5555-- stop the queue here --|r")
          row.cd:SetText("")
          row.prio:Hide() row.pause:Hide() row.delay:Hide()
        else
          local t = known[k]
          row.base = k
          row:Show()
          row.prio:Show() row.pause:Show() row.delay:Show()
          row.icon:SetTexture(t and t.tex or "Interface\\Icons\\INV_Misc_QuestionMark")
          row.text:SetText(t and t.name or ("|cff777777item " .. k .. " (not carried)|r"))
          local left = t and Left(t) or 0
          if not t then row.cd:SetText("")
          elseif not Q.HasUse(t) then row.cd:SetText("passive")
          elseif left > 0 then row.cd:SetText(math.ceil(left) .. "s")
          else row.cd:SetText("|cff55ff55ready|r") end
          local f = Q.Flags(k)
          row.prio:SetChecked(f.prio == "1" and 1 or nil)
          row.pause:SetChecked(f.pause == "1" and 1 or nil)
          if not row.delay.typing then row.delay:SetText(f.delay .. "s") end
        end
      end
    end
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", function() this.top = math.max(0, this.top - arg1) this:Fill() end)
    box:Fill()
    table.insert(p.items, { Refresh = function() box:Fill() end })
    return box
  end

  local function Build(p)
    W.Heading(p, "Trinket queue", { on = { function() return Q.Slot(13).on == "1" or Q.Slot(14).on == "1" end, function(v) Q.Slot(13).on = v and "1" or "0" Q.Slot(14).on = v and "1" or "0" Q.Paint() end, "Both trinket slots' queues on or off." }, about = "Each trinket slot can swap trinkets by itself (as TrinketMenu's auto queue): put "
      .. "your trinkets in order; when the one you wear goes on cooldown, the first one above the red mark that is "
      .. "ready goes on. A trinket with 30 seconds or less of cooldown counts as ready - putting one on starts a 30 "
      .. "second cooldown anyway. Swaps wait for combat to end. Alt-click a trinket on the trinket bar to switch its "
      .. "slot's queue on or off; a small gear on it shows the queue: gold on, grey holding (Delay), red paused." })
    W.Card(p, "Swapping")
    W.Check(p, "Say each swap in chat", nil, function() return C.gear.tqtell == "1" end,
      function(v) C.gear.tqtell = v and "1" or "0" end)
    for _, inv in ipairs({ 13, 14 }) do
      local slot = inv
      W.Card(p, inv == 13 and "Top trinket (slot 1)" or "Bottom trinket (slot 2)", {
        on = { function() return Q.Slot(slot).on == "1" end, function(v) Q.Slot(slot).on = v and "1" or "0" Q.Paint() end,
          "This slot's queue on or off (Alt-click its trinket on the trinket bar does the same)." },
        tip = "Top of the list = first choice. Use ^ and v to move trinkets and the red mark; the wheel scrolls." })
      SlotList(p, slot)
    end
  end
  O:AddPage("ItemRack", "gearqueue", "Trinket queue", Build)

  -- /gear queue [top|bottom] [on|off]
  local slash = SlashCmdList.PFGEAR
  SlashCmdList.PFGEAR = function(msg)
    local _, _, cmd, which, state = string.find(string.lower(msg or ""), "^%s*(%S*)%s*(%S*)%s*(%S*)")
    if cmd == "queue" then
      local inv = (which == "bottom" or which == "2") and 14 or 13
      if state == "on" or state == "off" then GR.SetQueue(inv, state) else GR.ToggleQueue(inv) end
      return
    end
    slash(msg)
  end
end)
