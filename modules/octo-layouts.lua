pfUI:RegisterModule("octo-layouts", "vanilla", function ()
  -- pfUI Octo :: UI layouts (user, 24 Oct 2026: "setup different UIs for
  -- different things. RAID UI, NORMAL UI, PVPUI ... a toggle button on screen
  -- that you can quickly change between UIs, also could have it
  -- automatically change as you enter a BG ... make this optional").
  --
  -- A layout keeps where every frame is (pfUI's C.position: everything layout
  -- mode moves), whether the meters show, and a gear set to put on. What you
  -- arrange while in a layout is kept for it: switching away saves it first.
  -- A layout never used yet starts as a copy of the one you are in.
  -- The button on screen: click = next layout, right-click = pick one.
  -- Automatic: on entering a battleground, arena, raid or dungeon (and back
  -- in the open world) the layout picked for that place goes on.
  local L = {}
  pfUI.layouts = L
  L.NAMES = { "Normal", "Raid", "PvP" }
  -- frames that keep one place in all layouts: the gear set, meters and layout buttons
  L.FIXED = { "pfGearButton", "pfMeterToggle", "pfLayoutButton" }
  L.ICON = { Normal = "Interface\\Icons\\INV_Misc_Map_01", Raid = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
             PvP = "Interface\\Icons\\INV_BannerPVP_02" }

  local function Say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r layouts: " .. msg) end
  local function Copy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = Copy(v) end
    return o
  end

  local function Store()
    if type(C.layouts) ~= "table" then C.layouts = {} end
    local s = C.layouts
    if type(s.saved) ~= "table" then s.saved = {} end
    if type(s.byzone) ~= "table" then
      s.byzone = { world = "Normal", dungeon = "Normal", raid = "Raid", bg = "PvP", arena = "PvP" }
    end
    s.current = s.current or "Normal"
    if s.auto == nil then s.auto = "0" end
    if s.button == nil then s.button = "1" end
    -- (25 Oct 2026, user: "add option to add more profiles") the layouts in
    -- order, each with a picture and a colour; L.NAMES follows the list
    if type(s.list) ~= "table" or table.getn(s.list) == 0 then s.list = { "Normal", "Raid", "PvP" } end
    if type(s.icons) ~= "table" then s.icons = {} end
    if type(s.colors) ~= "table" then s.colors = {} end
    if L.NAMES ~= nil and L.synced ~= s.list then
      for i = table.getn(L.NAMES), 1, -1 do table.remove(L.NAMES, i) end
      for _, n in ipairs(s.list) do table.insert(L.NAMES, n) end
      L.synced = s.list
    end
    return s
  end
  L.Store = Store

  -- colours a layout can have (picked in turn for new ones)
  L.COLORS = { { .2, .7, 1 }, { 1, .55, .15 }, { .9, .25, .25 }, { .3, .85, .45 }, { .7, .45, 1 },
               { 1, .85, .2 }, { .2, .85, .85 }, { 1, .45, .75 } }
  L.DEFCOLOR = { Normal = 1, Raid = 2, PvP = 3 }
  function L.Color(name)
    local s = Store()
    local i = tonumber(s.colors[name] or "") or L.DEFCOLOR[name] or 1
    local c = L.COLORS[i] or L.COLORS[1]
    return c[1], c[2], c[3], i
  end
  function L.Hex(name)
    local r, g, b = L.Color(name)
    return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
  end
  function L.Icon(name)
    return Store().icons[name] or L.ICON[name] or "Interface\\Icons\\INV_Misc_Note_01"
  end
  local function Has(name)
    for _, n in ipairs(Store().list) do if n == name then return true end end
  end
  L.Has = Has

  -- talent specs that name this layout follow a rename / delete
  local function SpecsFollow(old, new)
    local specs = C.gear and C.gear.specs
    if type(specs) ~= "table" then return end
    for _, sp in pairs(specs) do
      if type(sp) == "table" then
        if sp.layout == old then sp.layout = new or "" end
        if type(sp.bars) == "table" and sp.bars[old] then
          if new then sp.bars[new] = sp.bars[old] end
          sp.bars[old] = nil
        end
      end
    end
  end

  -- a new layout, starting as a copy of the one you are in
  function L.New(name)
    local s = Store()
    name = string.gsub(name or "", "^%s*(.-)%s*$", "%1")
    if name == "" then return nil, "it needs a name" end
    if string.len(name) > 20 then name = string.sub(name, 1, 20) end
    if Has(name) then return nil, "there is already a layout called " .. name end
    if table.getn(s.list) >= 12 then return nil, "twelve layouts is the most" end
    L.SaveCurrent()
    s.saved[name] = Copy(s.saved[s.current])
    s.saved[name].gear = ""
    s.colors[name] = tostring(math.mod(table.getn(s.list), table.getn(L.COLORS)) + 1)
    table.insert(s.list, name)
    L.synced = nil
    Store()
    return name
  end

  function L.Rename(old, new)
    local s = Store()
    new = string.gsub(new or "", "^%s*(.-)%s*$", "%1")
    if new == "" or new == old or not Has(old) then return nil end
    if string.len(new) > 20 then new = string.sub(new, 1, 20) end
    if Has(new) then return nil, "there is already a layout called " .. new end
    for i, n in ipairs(s.list) do if n == old then s.list[i] = new end end
    s.saved[new], s.saved[old] = s.saved[old], nil
    s.icons[new], s.icons[old] = s.icons[old] or L.ICON[old], nil
    s.colors[new], s.colors[old] = s.colors[old] or (L.DEFCOLOR[old] and tostring(L.DEFCOLOR[old])), nil
    for z, n in pairs(s.byzone) do if n == old then s.byzone[z] = new end end
    if s.current == old then s.current = new end
    SpecsFollow(old, new)
    L.synced = nil
    Store()
    L.Paint()
    return new
  end

  function L.Delete(name)
    local s = Store()
    if not Has(name) then return nil end
    if table.getn(s.list) <= 1 then return nil, "the last layout stays" end
    if s.current == name then return nil, "switch to another layout first" end
    for i = table.getn(s.list), 1, -1 do if s.list[i] == name then table.remove(s.list, i) end end
    s.saved[name], s.icons[name], s.colors[name] = nil, nil, nil
    for z, n in pairs(s.byzone) do if n == name then s.byzone[z] = "" end end
    SpecsFollow(name, nil)
    L.synced = nil
    Store()
    return true
  end
  Store()

  -- ---------------------------------------------------------------- spells on the bars

  -- Each layout keeps what is on the 120 action slots (user, 24 Oct 2026:
  -- "it moves the frames but my spells dont move" - different spells per
  -- layout). A slot is { t = "spell" | "item" | "macro", name, rank }.
  -- ClassicAPI's GetActionInfo says which kind (its returns are taken as
  -- retail's - not verified on this client); without it: a macro has
  -- GetActionText, a name in the spellbook is a spell, the rest are items.
  -- The name and rank come from the button's tooltip.
  local scan
  local function TipName(slot)
    if pfUI.keymap and pfUI.keymap.ActionSpell then return pfUI.keymap.ActionSpell(slot) end
    if not scan then scan = CreateFrame("GameTooltip", "pfLayoutScan", nil, "GameTooltipTemplate") end
    scan:SetOwner(WorldFrame, "ANCHOR_NONE")
    scan:ClearLines()
    scan:SetAction(slot)
    local l, r = getglobal("pfLayoutScanTextLeft1"), getglobal("pfLayoutScanTextRight1")
    local name, rank = l and l:GetText(), r and r:IsShown() and r:GetText()
    scan:Hide()
    if rank == "" then rank = nil end
    return name, rank
  end

  -- the spellbook index of a spell (that rank, else the highest)
  local function SpellIndex(name, rank)
    local i, best = 1, nil
    while i <= 1024 do -- (bounded, 1 Nov 2026)
      local n, r = GetSpellName(i, BOOKTYPE_SPELL or "spell")
      if not n then break end
      if n == name then
        best = i
        if rank and r == rank then return i end
      end
      i = i + 1
    end
    return best
  end

  function L.ReadSlot(slot)
    if not HasAction(slot) then return nil end
    local kind, sid
    if GetActionInfo then
      local ok, k, id = pcall(GetActionInfo, slot)
      if ok and type(k) == "string" then kind = k end
      -- (ClassicAPI: a spell's own id - the exact rank comes back with it)
      if ok and k == "spell" then sid = tonumber(id) end
    end
    local macro = GetActionText and GetActionText(slot)
    if kind == "macro" or (not kind and macro) then return { t = "macro", name = macro } end
    local name, rank = TipName(slot)
    if not name then return nil end
    if kind == "item" then return { t = "item", name = name } end
    if kind == "spell" or SpellIndex(name) then return { t = "spell", name = name, rank = rank, sid = sid } end
    return { t = "item", name = name }
  end

  function L.ReadBars()
    local out = {}
    for slot = 1, 120 do
      local e = L.ReadSlot(slot)
      if e then out[tostring(slot)] = e end
    end
    return out
  end

  local function Same(a, b)
    if not a or not b then return a == b end
    return a.t == b.t and a.name == b.name and (a.t ~= "spell" or a.rank == b.rank)
  end

  -- what is carried or worn with that name: bag, slot | inv
  local function FindItem(name)
    for bag = 0, 4 do
      for s = 1, (GetContainerNumSlots(bag) or 0) do
        local link = GetContainerItemLink(bag, s)
        if link and string.find(link, "[" .. name .. "]", 1, true) then return bag, s end
      end
    end
    for inv = 1, 19 do
      local link = GetInventoryItemLink("player", inv)
      if link and string.find(link, "[" .. name .. "]", 1, true) then return nil, nil, inv end
    end
  end

  -- puts e on the slot (nil = empties it); false when it could not
  function L.PutSlot(slot, e)
    if Same(L.ReadSlot(slot), e) then return true end
    ClearCursor()
    if not e then
      PickupAction(slot)
      ClearCursor()
      return true
    end
    if e.t == "spell" then
      local i
      if e.sid and _G.FindSpellBookSlotByID then
        local ok, at, book = pcall(_G.FindSpellBookSlotByID, e.sid)
        if ok and tonumber(at) and (book == nil or book == "spell") then i = tonumber(at) end
      end
      i = i or SpellIndex(e.name, e.rank)
      if not i then return false end
      PickupSpell(i, BOOKTYPE_SPELL or "spell")
    elseif e.t == "macro" then
      local i = GetMacroIndexByName and GetMacroIndexByName(e.name)
      if not i or i == 0 then return false end
      PickupMacro(i)
    else
      local bag, s, inv = FindItem(e.name)
      if bag then PickupContainerItem(bag, s) elseif inv then PickupInventoryItem(inv) else return false end
    end
    PlaceAction(slot)
    -- (what was on the slot comes onto the cursor: let it go)
    ClearCursor()
    return true
  end

  function L.WriteBars(bars)
    if type(bars) ~= "table" then return end
    local missing = 0
    for slot = 1, 120 do
      if not L.PutSlot(slot, bars[tostring(slot)]) then missing = missing + 1 end
    end
    if missing > 0 then Say(missing .. " action button" .. (missing == 1 and "" or "s") .. " kept what they had - not found in your spellbook, macros or bags.") end
  end

  -- the talent spec on now when it keeps its own spells (gear-specs.lua)
  function L.BarSpec()
    local GS = pfUI.gear and pfUI.gear.specs
    return GS and GS.BarSpec and GS.BarSpec()
  end

  -- ---------------------------------------------------------------- every setting

  -- A layout keeps every setting (user, 25 Oct 2026: "every setting you have
  -- chosen should be saved inside that UI layout ... ANY MENU SELECTION
  -- ANYTHING"): a copy of pfUI_config, but not what belongs to the character
  -- in every layout - the layouts themselves, gear (sets, specs, queues),
  -- places (kept as .pos) and the version.
  L.SHARED = { layouts = true, position = true, gear = true, version = true }
  function L.CfgCopy()
    local out = {}
    for k, v in pairs(pfUI_config) do
      if not L.SHARED[k] then out[k] = Copy(v) end
    end
    return out
  end
  local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
  end
  L.Same = Same
  -- into the live settings in place: modules keep their own handles on parts
  -- of pfUI_config, so tables are filled, never swapped; a setting the saved
  -- copy does not have (newer than it) keeps its value
  local function Assign(dst, src)
    for k, v in pairs(src) do
      if type(v) == "table" then
        if type(dst[k]) ~= "table" then dst[k] = {} end
        Assign(dst[k], v)
      else
        dst[k] = v
      end
    end
  end
  -- what each part does to show new settings at once; a changed part without
  -- one takes a reload
  L.LIVE = {
    unitframes = function() if pfUI.ufOcto and pfUI.ufOcto.ApplyAll then pfUI.ufOcto.ApplyAll() end end,
    bars = function() if pfUI.bars and pfUI.bars.UpdateConfig then pfUI.bars:UpdateConfig() end end,
    meters = function()
      local M = pfUI.meters
      if M and M.RestyleAll then M.RestyleAll() end
    end,
    plates = function() if pfUI.plates and pfUI.plates.Refresh then pfUI.plates.Refresh() end end,
    castbar = function()
      local CB = pfUI.castbarOcto
      if CB and CB.Apply then for _, u in ipairs({ "player", "target", "focus" }) do pcall(CB.Apply, u) end end
    end,
    swing = function() if pfUI.swing and pfUI.swing.ApplyLayout then pfUI.swing.ApplyLayout() end end,
    mapstyle = function() if pfUI.minimap and pfUI.minimap.ApplyStyle then pfUI.minimap.ApplyStyle() end end,
    mapauto = function() end,
    bagsocto = function() if pfUI.bagsOcto and pfUI.bagsOcto.Refresh then pfUI.bagsOcto.Refresh() end end,
    abuttons = function() if pfUI.addonbuttons and pfUI.addonbuttons.UpdateConfig then pfUI.addonbuttons:UpdateConfig() end end,
    blizz = function()
      local BZ = pfUI.blizz
      if not (BZ and BZ.S) then return end
      for id in pairs(BZ.S) do
        local want = C.blizz[id] == "1"
        if (BZ.state[id] == "blizz") ~= want then BZ.Set(id, want and "blizz" or "octo") end
      end
    end,
    unlock = function() end, gui = function() end,
    -- (the arrow's window and Loot & Spam: put back after the frames are placed)
    chat = function() if pfUI.chat and pfUI.chat.RefreshChat then pfUI.chat.RefreshChat() end end,
    panel = function() end,
    -- (the user wants no reload questions, 26 Oct 2026: parts read at login take
    -- the new settings now and draw them fully at the next reload by themselves)
    buffs = function() if pfUI.buff and pfUI.buff.UpdateConfig then pfUI.buff:UpdateConfig() end end,
    buffbar = function() end, sct = function() end, global = function() end, tooltip = function() end,
    appearance = function()
      if pfUI.ufOcto and pfUI.ufOcto.ApplyAll then pcall(pfUI.ufOcto.ApplyAll) end
      if pfUI.bars and pfUI.bars.UpdateConfig then pcall(pfUI.bars.UpdateConfig, pfUI.bars) end
    end,
  }
  -- the saved settings in, each changed part shown; the parts that cannot
  -- change without a reload, by name
  function L.ApplyCfg(cfg)
    if type(cfg) ~= "table" then return {} end
    local changed, needs = {}, {}
    for k, v in pairs(cfg) do
      if not L.SHARED[k] and not Same(pfUI_config[k], v) then changed[k] = true end
    end
    -- (the bottom bars' own texts take a reload; the arrow's settings do not)
    if changed.panel and type(cfg.panel) == "table" and type(pfUI_config.panel) == "table" then
      for k, v in pairs(cfg.panel) do
        if not string.find(k, "^arrow") and not Same(pfUI_config.panel[k], v) then table.insert(needs, "bottom bars") break end
      end
    end
    for k, v in pairs(cfg) do
      if not L.SHARED[k] and changed[k] then
        if type(v) == "table" then
          if type(pfUI_config[k]) ~= "table" then pfUI_config[k] = {} end
          Assign(pfUI_config[k], v)
        else
          pfUI_config[k] = v
        end
      end
    end
    -- more or fewer meter windows: made or taken away now
    local M, want = pfUI.meters, cfg.meters and tonumber(cfg.meters.windows)
    if M and M.windows and want then
      for _ = 1, 6 do if table.getn(M.windows) < want and M.AddWindow then M.AddWindow() else break end end
      for _ = 1, 6 do if table.getn(M.windows) > want and M.RemoveWindow then M.RemoveWindow(table.getn(M.windows)) else break end end
    end
    for k in pairs(changed) do
      local fn = L.LIVE[k]
      if fn then pcall(fn) else table.insert(needs, k) end
    end
    return needs
  end

  -- what the layout you are in looks like now
  local function Snapshot()
    local M = pfUI.meters
    return { pos = Copy(C.position or {}), meters = (C.meters and C.meters.hidden == "1") and "0" or "1", bars = L.ReadBars(),
             cfg = L.CfgCopy(),
             gear = Store().saved[Store().current] and Store().saved[Store().current].gear or "" }
  end
  function L.SaveCurrent()
    local s = Store()
    local keep = s.saved[s.current] or {}
    local snap = Snapshot()
    keep.pos, keep.meters, keep.cfg = snap.pos, snap.meters, snap.cfg
    -- (a talent spec with its own spells keeps the bars, per layout; L.holdBars
    -- while a spec swap switches layout: the bars on now belong to the spec left)
    if not L.holdBars then
      local spec = L.BarSpec()
      if spec then spec.bars[s.current] = snap.bars else keep.bars = snap.bars end
    end
    keep.gear = keep.gear or ""
    s.saved[s.current] = keep
  end

  -- every frame layout mode knows goes where this layout has it
  local function Place()
    for name, frame in pairs(pfUI.movables or {}) do
      local f = frame or _G[name]
      if f then pcall(UpdateMovable, f) end
    end
    -- (meter windows and other frames that place themselves)
    if pfUI.meters and pfUI.meters.windows then
      for _, w in ipairs(pfUI.meters.windows) do
        if w.free and not (C.position and C.position[w:GetName()]) and pfUI.meters.ResetPosition then
          pfUI.meters.ResetPosition(w)
        end
      end
    end
  end

  function L.Switch(name, why)
    local s = Store()
    if not name or name == s.current then return end
    if UnitAffectingCombat("player") then
      -- (frames move fine in combat on 1.12, but a jump mid-fight helps nobody)
      L.pending = name
      Say(name .. " goes on when combat ends.")
      return
    end
    L.SaveCurrent()
    local target = s.saved[name]
    if not target then
      target = Snapshot()
      target.gear = ""
      s.saved[name] = target
    end
    -- the small on-screen buttons stay where they are in every layout, those
    -- made later too (user, 25 Oct 2026: "hard locked in place in whichever
    -- UI layout you use")
    local fixed = {}
    for _, n in ipairs(L.FIXED) do fixed[n] = C.position and C.position[n] end
    C.position = Copy(target.pos or {})
    for _, n in ipairs(L.FIXED) do C.position[n] = fixed[n] and Copy(fixed[n]) or nil end
    pfUI_config.position = C.position
    s.current = name
    -- every other setting of the layout (a layout saved before this has none:
    -- it takes the ones on now, and keeps them from here on)
    local needs = L.ApplyCfg(target.cfg)
    Place()
    -- (the arrow's window as this layout had it: meters docked in it or not)
    if pfUI.panel and pfUI.panel.ArrowRefresh then pcall(pfUI.panel.ArrowRefresh) end
    if pfUI.meters and pfUI.meters.ShowAll then pfUI.meters.ShowAll(target.meters ~= "0") end
    -- its own spells on the action bars (unless switched off for it)
    local spec = L.BarSpec()
    if spec then
      if spec.bars[name] and not L.holdBars then L.WriteBars(spec.bars[name]) end
    elseif target.bars and target.ownbars ~= "0" then
      L.WriteBars(target.bars)
    end
    if target.gear and target.gear ~= "" and pfUI.gear and C.gear.sets[target.gear] then pfUI.gear.Equip(target.gear) end
    L.Paint()
    Say(name .. (why and (" (" .. why .. ")") or "") .. ".")
    -- (parts that only draw their new settings fully after a reload: noted,
    -- never asked - the user wants no reload questions, 26 Oct 2026)
    L.needsReload = (needs and table.getn(needs) > 0) and table.concat(needs, ", ") or nil
  end

  function L.Next()
    local s = Store()
    local i = 1
    for n, nm in ipairs(L.NAMES) do if nm == s.current then i = n end end
    L.Switch(L.NAMES[math.mod(i, table.getn(L.NAMES)) + 1])
  end

  -- ---------------------------------------------------------------- the button

  local b = CreateFrame("Button", "pfLayoutButton", UIParent)
  b:SetWidth(30)
  b:SetHeight(30)
  b:SetFrameStrata("MEDIUM")
  b:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -300, 40)
  b:SetMovable(true)
  b:SetClampedToScreen(true)
  CreateBackdrop(b, nil, nil, .9)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexCoord(.08, .92, .08, .92)
  b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  b.label = b:CreateFontString(nil, "OVERLAY")
  b.label:SetFont(pfUI.font_default, 10, "OUTLINE")
  b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  L.button = b

  local menu
  local function Menu(owner)
    local W = pfUI.octoui and pfUI.octoui.W
    if not W then return end
    if menu then menu:Hide() end
    local opts = { { label = "UI layout", group = true } }
    for _, n in ipairs(L.NAMES) do
      table.insert(opts, { key = n, label = L.Hex(n) .. n .. "|r" .. (n == Store().current and "  |cff55ff77(on)|r" or ""), icon = L.Icon(n) })
    end
    table.insert(opts, { key = "_opt", label = "Layout options..." })
    menu = W.Menu(owner, opts, 170, function(k)
      if k == "_opt" then
        local O = pfUI.octoui.Options
        if O and O.Open then O:Open("layouts") end
      else
        L.Switch(k)
      end
    end)
    menu:SetFrameStrata("TOOLTIP")
    menu:Show()
  end

  b:SetScript("OnClick", function()
    if arg1 == "RightButton" then Menu(this) else L.Next() end
  end)
  b:SetScript("OnDragStart", function() if IsShiftKeyDown() then this:StartMoving() this.moving = true end end)
  b:SetScript("OnDragStop", function()
    if this.moving then this:StopMovingOrSizing() this.moving = nil SaveMovable(this) end
  end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:AddLine("UI layout: " .. Store().current)
    GameTooltip:AddLine("Click: next layout (" .. table.concat(L.NAMES, ", ") .. ")", 1, 1, 1)
    GameTooltip:AddLine("Right-click: pick one, or the options", 1, 1, 1)
    GameTooltip:AddLine("Shift + drag: move this button", .7, .7, .7)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  function L.Paint()
    local s = Store()
    b.icon:SetTexture(L.Icon(s.current))
    local r, g, bl = L.Color(s.current)
    b.label:SetText(s.current)
    b.label:SetTextColor(r, g, bl)
    if b.backdrop and b.backdrop.SetBackdropBorderColor then b.backdrop:SetBackdropBorderColor(r, g, bl, 1) end
    if s.button == "0" then b:Hide() else b:Show() end
  end
  if UpdateMovable then UpdateMovable(b) end
  L.Paint()

  -- ---------------------------------------------------------------- automatic

  if pfUI.context then
    pfUI.context.listeners.layouts = function(z, old)
      local s = Store()
      if s.auto ~= "1" then return end
      local want = s.byzone[z]
      if want and want ~= "" and want ~= s.current then L.Switch(want, pfUI.context.NAMES[z]) end
    end
  end
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:SetScript("OnEvent", function()
    if L.pending then
      local n = L.pending
      L.pending = nil
      L.Switch(n)
    end
  end)

  -- /layout [name]
  _G.SLASH_PFLAYOUT1 = "/layout"
  _G.SlashCmdList.PFLAYOUT = function(msg)
    msg = string.gsub(msg or "", "^%s*(.-)%s*$", "%1")
    for _, n in ipairs(L.NAMES) do
      if string.lower(n) == string.lower(msg) then L.Switch(n) return end
    end
    if msg == "" then L.Next() else Say("/layout " .. table.concat(L.NAMES, " | ")) end
  end

  -- ---------------------------------------------------------------- options page

  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end

  local ZONES = { { "world", "Open world" }, { "dungeon", "Dungeons" }, { "raid", "Raids" }, { "bg", "Battlegrounds" }, { "arena", "Arenas" } }
  local function LayoutList()
    local out = { { key = "", label = "- stay as it is -" } }
    for _, n in ipairs(L.NAMES) do table.insert(out, { key = n, label = L.Hex(n) .. n .. "|r", icon = L.Icon(n) }) end
    return out
  end
  local function SetList()
    local out = { { key = "", label = "- none -" } }
    if pfUI.gear then for _, n in ipairs(pfUI.gear.Sets()) do table.insert(out, { key = n, label = n }) end end
    return out
  end

  local function Rebuild() if O.Rebuild then O:Rebuild("layouts") end end
  local function Ask(text, fn, box, start)
    local open = _G["pfQuestionDialog"]
    if open and open:IsShown() then open:Hide() _G["pfQuestionDialog"] = nil end
    CreateQuestionDialog(text, function()
      local input = this:GetParent().input
      fn(input and input:GetText())
    end, false, box)
    local d = _G["pfQuestionDialog"]
    if box and d and d.input then d.input:SetText(start or "") d.input:SetScript("OnEditFocusGained", function() this:HighlightText() end) d.input:SetFocus() d.input:HighlightText() end
  end
  function L.AskNew()
    Ask("A new UI layout, starting as a copy of " .. Store().current .. ". Its name:", function(v)
      local name, err = L.New(v)
      if not name then Say(err or "no layout made.") return end
      Say(name .. " made: switch to it and arrange it.")
      Rebuild()
    end, true, "")
  end
  function L.AskRename(name)
    Ask("Rename the " .. name .. " layout to:", function(v)
      local new, err = L.Rename(name, v)
      if not new then if err then Say(err .. ".") end return end
      Rebuild()
    end, true, name)
  end
  function L.AskDelete(name)
    local ok, why = true, nil
    if Store().current == name then ok, why = false, "switch to another layout first" end
    if table.getn(Store().list) <= 1 then ok, why = false, "the last layout stays" end
    if not ok then Say(name .. ": " .. why .. ".") return end
    Ask("Delete the " .. name .. " layout?\n\nIts frame places, spells and settings are lost. "
      .. "Places and specs that used it keep the layout they are in.", function()
      L.Delete(name)
      Rebuild()
    end)
  end
  function L.PickIcon(name, owner)
    local GO = pfUI.gearOcto
    if not (GO and GO.IconPicker) then return end
    local extra = {}
    for _, n in ipairs(L.NAMES) do table.insert(extra, L.Icon(n)) end
    for _, t in pairs(L.ICON) do table.insert(extra, t) end
    local p = GO.IconPicker(owner, L.Icon(name), extra, function(path)
      Store().icons[name] = path
      L.Paint()
      if L.PaintTiles then L.PaintTiles() end
    end)
    if p then p:SetFrameStrata("FULLSCREEN_DIALOG") end
  end
  function L.NextColor(name)
    local _, _, _, i = L.Color(name)
    Store().colors[name] = tostring(math.mod(i, table.getn(L.COLORS)) + 1)
    L.Paint()
    if L.PaintTiles then L.PaintTiles() end
  end

  -- a soft wash of a colour, strongest at the bottom; the words stay white on
  -- the dark card (user, 25 Oct 2026: coloured text on its own colour was hard
  -- to read - SetVertexColor after SetGradientAlpha had filled the tile solid)
  function L.Wash(t, r, g, b)
    if t.SetGradientAlpha then
      t:SetVertexColor(1, 1, 1, 1)
      t:SetGradientAlpha("VERTICAL", r, g, b, .28, r, g, b, 0)
    else
      t:SetVertexColor(r, g, b, .14)
    end
  end
  -- the layouts as coloured tiles: click = switch, right-click = its menu
  local PER, TW, TH, GAP = 4, 183, 84, 8
  local function Tiles(p)
    local n = table.getn(L.NAMES) + 1
    local rows = math.ceil(n / PER)
    local box = W.Box(p, rows * (TH + GAP) + GAP)
    local tiles = {}
    local function Tile(i)
      if tiles[i] then return tiles[i] end
      local t = CreateFrame("Button", nil, box)
      t:SetWidth(TW)
      t:SetHeight(TH)
      t:SetPoint("TOPLEFT", box, "TOPLEFT", GAP + math.mod(i - 1, PER) * (TW + GAP), -GAP - math.floor((i - 1) / PER) * (TH + GAP))
      W.Flat(t, W.C.card, 1, W.C.line)
      W.Hover(t, .08)
      t.band = t:CreateTexture(nil, "ARTWORK")
      t.band:SetTexture("Interface\\Buttons\\WHITE8X8")
      t.band:SetPoint("TOPLEFT", t, "TOPLEFT", 1, -1)
      t.band:SetPoint("BOTTOMRIGHT", t, "TOPRIGHT", -1, -5)
      t.glow = t:CreateTexture(nil, "BORDER")
      t.glow:SetTexture("Interface\\Buttons\\WHITE8X8")
      t.glow:SetPoint("TOPLEFT", t, "TOPLEFT", 1, -5)
      t.glow:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -1, 1)
      t.icon = t:CreateTexture(nil, "OVERLAY")
      t.icon:SetWidth(40)
      t.icon:SetHeight(40)
      t.icon:SetTexCoord(.07, .93, .07, .93)
      t.icon:SetPoint("LEFT", t, "LEFT", 10, -2)
      t.name = W.Font(t:CreateFontString(nil, "OVERLAY"), 14, 1, 1, 1)
      t.name:SetShadowColor(0, 0, 0, 1)
      t.name:SetShadowOffset(1, -1)
      t.name:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 10, -2)
      t.name:SetWidth(TW - 70)
      t.name:SetJustifyH("LEFT")
      t.sub = W.Font(t:CreateFontString(nil, "OVERLAY"), 10, .82, .83, .87)
      t.sub:SetShadowColor(0, 0, 0, 1)
      t.sub:SetShadowOffset(1, -1)
      t.sub:SetPoint("TOPLEFT", t.name, "BOTTOMLEFT", 0, -4)
      t.sub:SetWidth(TW - 70)
      t.sub:SetJustifyH("LEFT")
      t.on = W.Font(t:CreateFontString(nil, "OVERLAY"), 10, 1, 1, 1)
      t.on:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -6, 5)
      t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      t:SetScript("OnClick", function()
        local nm = this.layout
        if not nm then L.AskNew() return end
        if arg1 == "RightButton" then
          local m = W.Menu(this, {
            { label = nm, group = true },
            { key = "switch", label = "Switch to it", icon = L.Icon(nm) },
            { key = "rename", label = "Rename..." },
            { key = "icon", label = "Picture..." },
            { key = "color", label = "Next colour" },
            { key = "delete", label = "|cffff5555Delete...|r" } }, 150, function(k)
              if k == "switch" then L.Switch(nm) if L.PaintTiles then L.PaintTiles() end
              elseif k == "rename" then L.AskRename(nm)
              elseif k == "icon" then L.PickIcon(nm, this)
              elseif k == "color" then L.NextColor(nm)
              elseif k == "delete" then L.AskDelete(nm) end
            end)
          m:SetFrameStrata("FULLSCREEN_DIALOG")
          m:Show()
          return
        end
        L.Switch(nm)
        L.PaintTiles()
      end)
      t:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        if this.layout then
          GameTooltip:AddLine(this.layout)
          GameTooltip:AddLine("Click: switch to it", 1, 1, 1)
          GameTooltip:AddLine("Right-click: rename, picture, colour, delete", 1, 1, 1)
        else
          GameTooltip:AddLine("New layout")
          GameTooltip:AddLine("Starts as a copy of the layout you are in: frames, spells, meters.", 1, 1, 1, 1)
        end
        GameTooltip:Show()
      end)
      t:SetScript("OnLeave", function() GameTooltip:Hide() end)
      tiles[i] = t
      return t
    end
    function L.PaintTiles()
      local s = Store()
      for i, nm in ipairs(L.NAMES) do
        local t = Tile(i)
        local r, g, b = L.Color(nm)
        t.layout = nm
        t.band:SetVertexColor(r, g, b, 1)
        L.Wash(t.glow, r, g, b)
        t.icon:SetTexture(L.Icon(nm))
        t.icon:SetVertexColor(1, 1, 1)
        t.name:SetText(nm)
        t.name:SetTextColor(1, 1, 1)
        local sv = s.saved[nm]
        local bits = {}
        if sv and sv.gear and sv.gear ~= "" then table.insert(bits, sv.gear) end
        if not sv or sv.ownbars ~= "0" then table.insert(bits, "own spells") end
        if sv and sv.meters == "0" then table.insert(bits, "no meters") end
        t.sub:SetText(table.concat(bits, " - "))
        if nm == s.current then
          t:SetBackdropBorderColor(r, g, b, 1)
          t.on:SetText("|cff55ff77ON NOW|r")
        else
          t:SetBackdropBorderColor(W.C.line[1], W.C.line[2], W.C.line[3], 1)
          t.on:SetText("")
        end
        t:Show()
      end
      local add = Tile(table.getn(L.NAMES) + 1)
      add.layout = nil
      add.band:SetVertexColor(.4, .42, .46, 1)
      L.Wash(add.glow, .4, .42, .46)
      add.icon:SetTexture("Interface\\Icons\\Spell_ChargePositive")
      add.name:SetText("+ New layout")
      add.name:SetTextColor(.85, .86, .9)
      add.sub:SetText("copy of the one you are in")
      add.on:SetText("")
      add:SetBackdropBorderColor(W.C.line[1], W.C.line[2], W.C.line[3], 1)
      if table.getn(L.NAMES) >= 12 then add:Hide() else add:Show() end
      for i = table.getn(L.NAMES) + 2, table.getn(tiles) do tiles[i]:Hide() end
    end
    L.PaintTiles()
  end

  local function Build(p)
    W.Heading(p, "UI layouts", {
      on = { function() return Store().button ~= "0" end, function(v) Store().button = v and "1" or "0" L.Paint() end,
        "The layout button on your screen." },
      about = "Layouts - Normal, Raid, PvP and any you make - each remember where every frame is (everything you move "
        .. "in Move frames), the spells on your action bars, whether the meters show, and a gear set. Switch with the "
        .. "button on your screen (click = next, right-click = pick), /layout, or a tile here. Whatever you arrange "
        .. "while in a layout is kept for it. A talent spec can pick a layout too (Gear > Talent specs): changing spec "
        .. "at the Brainwashing Device switches to it, with that spec's own spells in it." })
    W.Card(p, "Your layouts", { tip = "Click a tile to switch; right-click to rename, change its picture or colour, or delete it." })
    Tiles(p)
    W.Buttons(p, {
      { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, 120,
        "Arrange this layout: what you move is kept for the layout you are in." },
      { "Copy this layout to the others", function()
        L.SaveCurrent()
        local s = Store()
        for _, n in ipairs(L.NAMES) do
          if n ~= s.current then
            local gear = s.saved[n] and s.saved[n].gear or ""
            s.saved[n] = Copy(s.saved[s.current])
            s.saved[n].gear = gear
          end
        end
        Say("every layout now has the " .. s.current .. " layout's places.")
      end, 210, "Start the other layouts from this one." },
    })
    W.Card(p, "Automatic", { on = { function() return Store().auto == "1" end, function(v) Store().auto = v and "1" or "0" end,
      "Change the layout by itself when you enter these places." } })
    for _, z in ipairs(ZONES) do
      local zone = z[1]
      W.Dropdown(p, z[2], "The layout that goes on here.", LayoutList,
        function() return Store().byzone[zone] or "" end, function(v) Store().byzone[zone] = v end)
    end
    for _, n in ipairs(L.NAMES) do
      local nm = n
      W.Card(p, L.Hex(nm) .. nm .. "|r", { tip = "What else the " .. nm .. " layout changes." })
      W.Check(p, "Meters shown", nil, function()
        local t = Store().saved[nm]
        return not t or t.meters ~= "0"
      end, function(v)
        local t = Store().saved[nm] or Snapshot()
        t.meters = v and "1" or "0"
        Store().saved[nm] = t
        if L.PaintTiles then L.PaintTiles() end
      end)
      W.Check(p, "Its own spells", "This layout keeps its own spells, items and macros on the action bars: "
        .. "what you put there while in it comes back when you switch to it. (A talent spec with its own "
        .. "spells keeps them per layout instead.)", function()
        local t = Store().saved[nm]
        return not t or t.ownbars ~= "0"
      end, function(v)
        local t = Store().saved[nm] or Snapshot()
        t.ownbars = v and "1" or "0"
        Store().saved[nm] = t
        if L.PaintTiles then L.PaintTiles() end
      end)
      W.Dropdown(p, "Gear set", "Put on when this layout goes on.", SetList,
        function() local t = Store().saved[nm] return t and t.gear or "" end,
        function(v) local t = Store().saved[nm] or Snapshot() t.gear = v Store().saved[nm] = t if L.PaintTiles then L.PaintTiles() end end)
    end
  end

  O:AddPage("UI layouts", "layouts", "Layouts", Build)
end)
