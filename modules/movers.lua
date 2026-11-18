pfUI:RegisterModule("movers", "vanilla", function ()
  -- pfUI Octo :: Move anything (18 Nov 2026; Lo5t1ncyb3r on Discord asked for MoveAnything; user: "what would move
  -- anything bring that we dont have", then: build it here). Layout mode only moved frames pfUI made movable. This adds,
  -- on top of layout mode (snap, grid, sizes, locks, per-layout places stay as they are):
  --   * the game's own frames as boxes: quest tracker, quest timers, battleground score, raid warnings, error text,
  --     zone text, item link tooltip, follow text... (MV.BLIZZ). The game moves some of them by itself
  --     (UIParent_ManageFramePositions): a saved place is put back right after it does.
  --   * any other frame of any add-on: "Pick a frame" (layout mode's top bar, /moveany) - point at it and press Enter,
  --     or type its name. It becomes a layout-mode box like ours, saved in C.position.
  --   * game windows (character, spellbook, quest log, talents, trainers...): Shift + drag moves them, and they open
  --     there from then on (UpdateUIPanelPositions put back afterwards).
  --   * opacity per frame (C.movers.alpha[name]); size and hide are layout mode's own (wheel, size box, Hide).
  -- Settings > Move anything lists all of it. MoveAnything's idea, written fresh; nothing copied.
  local MV = {}
  pfUI.movers = MV

  local function S() return C.movers end
  local function On(k) return C.movers[k] == "1" end
  local function Tbl(k)
    if type(C.movers[k]) ~= "table" then C.movers[k] = {} end
    return C.movers[k]
  end
  local function Say(t) DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: " .. t) end

  -- the game's frames offered as boxes: { name, label }
  MV.BLIZZ = {
    { "QuestWatchFrame", "Quest Tracker" },
    { "QuestTimerFrame", "Quest Timers" },
    { "WorldStateAlwaysUpFrame", "Battleground Score" },
    { "RaidWarningFrame", "Raid Warnings" },
    { "UIErrorsFrame", "Error Text" },
    { "ZoneTextFrame", "Zone Name" },
    { "SubZoneTextFrame", "Subzone Name" },
    { "ItemRefTooltip", "Item Link Tooltip" },
    { "AutoFollowStatus", "Follow Text" },
    { "TicketStatusFrame", "GM Ticket" },
    { "BattlefieldMinimap", "Zone Map" },
    { "WorldStateCaptureBar1", "Capture Bar" },
  }
  -- (DurabilityFrame is left out: skin.lua pins it with SetPoint = no-op, so a box could not move it)
  -- the game windows moved with Shift + drag (the ones made later, by Blizzard_*UI add-ons, too)
  MV.WINDOWS = { "CharacterFrame", "SpellBookFrame", "QuestLogFrame", "FriendsFrame", "GossipFrame", "MerchantFrame",
    "QuestFrame", "TradeFrame", "TaxiFrame", "PetStableFrame", "DressUpFrame", "HelpFrame", "BankFrame", "GuildRegistrarFrame",
    "TabardFrame", "PetitionFrame", "ItemTextFrame", "LootFrame", "TalentFrame", "ClassTrainerFrame", "TradeSkillFrame",
    "CraftFrame", "InspectFrame", "MacroFrame", "KeyBindingFrame", "BattlefieldFrame", "WorldStateScoreFrame", "RaidFrame",
    "OptionsFrame", "SoundOptionsFrame", "UIOptionsFrame" }
  MV.LABEL = {}
  for _, b in ipairs(MV.BLIZZ) do MV.LABEL[b[1]] = b[2] end
  -- frames never offered: the screen itself, layout mode's own parts
  local NEVER = { UIParent = true, WorldFrame = true, pfUnlock = true, pfUnlockBar = true, pfUnlockMirror = true,
    pfMoversPick = true, pfUnlockHider = true, Minimap = true }

  -- ---------------------------------------------------------------- making a frame movable

  MV.mine = {}   -- name -> "blizz" | "picked": the frames this module put into layout mode
  function MV.Owns(name) return name and MV.mine[name] ~= nil end
  function MV.Label(name)
    if MV.LABEL[name] then return MV.LABEL[name] end
    local s = string.gsub(name or "?", "(%l)(%u)", "%1 %2")
    return (string.gsub(s, "(%a)(%d)", "%1 %2"))
  end
  -- a frame layout mode can work with: a real, named game frame that is not the screen or one of our own
  function MV.Usable(f)
    if type(f) ~= "table" or type(f.GetName) ~= "function" or type(f.GetObjectType) ~= "function" then return end
    local ok, name = pcall(f.GetName, f)
    if not ok or type(name) ~= "string" or name == "" or NEVER[name] or _G[name] ~= f then return end
    if string.find(name, "Drag$") and string.find(name, "^pf") then return end
    if not f.SetPoint or not f.GetPoint or not f.ClearAllPoints then return end
    return name
  end
  function MV.ApplyAlpha(name)
    local f = _G[name]
    local a = tonumber(Tbl("alpha")[name])
    if f and f.SetAlpha and a then f:SetAlpha(a) end
  end
  function MV.SetAlpha(name, a)
    a = tonumber(a)
    if a and a >= .99 then a = nil end
    Tbl("alpha")[name] = a and tostring(math.floor(a * 100 + .5) / 100) or nil
    local f = _G[name]
    if f and f.SetAlpha then f:SetAlpha(a or 1) end
  end
  -- (18 Nov 2026, user: "move anything toggle ... so the unlock mode doesn't get cluttered") the frames are always
  -- looked after - saved place, size and opacity put on at login and after the game moves them - but get a box in layout
  -- mode only while the switch (layout mode's top bar, C.movers.show) is on.
  function MV.Showing() return On("show") end
  local function Box(name, f)
    pfUI.movables[name] = f
    if pfUI.unlock and pfUI.unlock.AddBox then pfUI.unlock.AddBox(f) end
  end
  local function Unbox(name, f)
    if pfUI.movables[name] == f then pfUI.movables[name] = nil end
    if f and pfUI.unlock and pfUI.unlock.DropBox then pfUI.unlock.DropBox(f) end
  end
  function MV.SetShowing(on)
    C.movers.show = on and "1" or "0"
    for name in pairs(MV.mine) do
      local f = _G[name]
      if f then if on then Box(name, f) else Unbox(name, f) end end
    end
  end
  function MV.Make(f, kind)
    local name = MV.Usable(f)
    if not name then return end
    if pfUI.movables[name] and not MV.mine[name] then return name end   -- pfUI's own already
    MV.mine[name] = kind
    -- its first place noted once (Middle-click / Reset go back to it), the saved one put on
    if not f.octoMover then
      f.octoMover = true
      if pfUI_config.global.offscreen == "0" and f.SetClampedToScreen then f:SetClampedToScreen(true) end
      pcall(pfUI.api.LoadMovable, f, true)
    end
    MV.ApplyAlpha(name)
    if MV.Showing() then Box(name, f) end
    return name
  end
  function MV.Unmake(name)
    local f = _G[name]
    MV.mine[name] = nil
    Unbox(name, f)
    if C.position then C.position[name] = nil end
    Tbl("alpha")[name] = nil
    if f then
      if f.SetAlpha then f:SetAlpha(1) end
      if f.posdata then pcall(pfUI.api.LoadMovable, f) end
    end
  end

  -- the game's frames and picked frames looked after (again when an add-on loads: its frames exist now)
  function MV.Apply()
    for _, b in ipairs(MV.BLIZZ) do
      local f = _G[b[1]]
      if f and not MV.mine[b[1]] then MV.Make(f, "blizz") end
    end
    for name, v in pairs(Tbl("picked")) do
      if v == "1" and not MV.mine[name] and _G[name] then MV.Make(_G[name], "picked") end
    end
    MV.HookWindows()
  end

  -- the game puts some frames back by itself: a saved place goes on again right after
  function MV.Reapply()
    for name in pairs(MV.mine) do
      local f = _G[name]
      local p = C.position and C.position[name]
      if f and p and p.xpos and not (pfUI.unlock and pfUI.unlock:IsShown()) then
        pcall(pfUI.api.LoadMovable, f)
      end
    end
  end
  local function Wrap(gname, after)
    local orig = _G[gname]
    if type(orig) ~= "function" or MV["wrapped" .. gname] then return end
    MV["wrapped" .. gname] = orig
    _G[gname] = function(a, b, c, d, e)
      local r1, r2 = orig(a, b, c, d, e)
      after()
      return r1, r2
    end
  end
  MV.Wrap = Wrap
  Wrap("UIParent_ManageFramePositions", function() MV.Reapply() end)

  -- ---------------------------------------------------------------- game windows: Shift + drag

  function MV.PlaceWindow(f, name)
    local p = Tbl("win")[name]
    if not p or not On("windows") or pfUI.api.IsDragging(f) then return end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
  end
  function MV.ReplaceWindows()
    for _, name in ipairs(MV.WINDOWS) do
      local f = _G[name]
      if f and f.IsShown and f:IsShown() then MV.PlaceWindow(f, name) end
    end
  end
  function MV.HookWindows()
    for _, name in ipairs(MV.WINDOWS) do
      local f = _G[name]
      if f and not f.octoWinMover and f.RegisterForDrag and f.SetScript then
        f.octoWinMover = true
        local wname = name
        local oldStart, oldStop, oldShow = f:GetScript("OnDragStart"), f:GetScript("OnDragStop"), f:GetScript("OnShow")
        if f.EnableMouse then f:EnableMouse(true) end
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function()
          if On("windows") and IsShiftKeyDown() then
            this.octoMoving = true
            pfUI.api.DragStart(this)
          elseif oldStart then
            oldStart()
          end
        end)
        f:SetScript("OnDragStop", function()
          if this.octoMoving then
            this.octoMoving = nil
            pfUI.api.DragStop(this)
            Tbl("win")[wname] = { x = math.floor((this:GetLeft() or 0) + .5), y = math.floor((this:GetTop() or 0) + .5) }
          elseif oldStop then
            oldStop()
          end
        end)
        f:SetScript("OnShow", function()
          if oldShow then oldShow() end
          MV.PlaceWindow(this, wname)
        end)
      end
    end
  end
  Wrap("UpdateUIPanelPositions", function() MV.ReplaceWindows() end)
  function MV.ForgetWindow(name)
    Tbl("win")[name] = nil
    if _G[name] and _G[name]:IsShown() and UpdateUIPanelPositions then pcall(UpdateUIPanelPositions) end
  end

  -- ---------------------------------------------------------------- pick a frame

  -- the named frame under the mouse (its first named parent when the frame itself has no name)
  function MV.UnderMouse()
    local f = GetMouseFocus and GetMouseFocus()
    local steps = 0
    while f and steps < 12 do
      if MV.Usable(f) then return f end
      f = f.GetParent and f:GetParent()
      steps = steps + 1
    end
  end
  local pick
  local function PickFrame()
    if pick then return pick end
    pick = CreateFrame("Frame", "pfMoversPick", UIParent)
    pick:SetFrameStrata("TOOLTIP")
    pick:SetAllPoints(UIParent)
    pick:EnableMouse(false)
    pick:EnableKeyboard(true)
    pick.box = CreateFrame("Frame", nil, pick)
    pick.box:SetFrameStrata("TOOLTIP")
    pick.box:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    pick.box:SetBackdropBorderColor(1, .82, .3, 1)
    pick.text = pick:CreateFontString(nil, "OVERLAY")
    pick.text:SetFont(pfUI.font_default, 13, "OUTLINE")
    pick.text:SetPoint("TOP", UIParent, "TOP", 0, -60)
    pick.text:SetJustifyH("CENTER")
    pick:SetScript("OnUpdate", function()
      local f = this.parentOf or MV.UnderMouse()
      this.target = f
      local name = f and f:GetName()
      if f and f.GetLeft and f:GetLeft() then
        this.box:ClearAllPoints()
        this.box:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 2)
        this.box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
        this.box:Show()
      else
        this.box:Hide()
      end
      this.text:SetText("|cffffd24dPick a frame to move|r  -  point at it\n"
        .. (name and ("|cffffffff" .. name .. "|r" .. (pfUI.movables[name] and " |cff40d977(can be moved already)|r" or "")) or "|cff8a8f99nothing that can be moved here|r")
        .. "\n|cff8a8f99Enter|r pick   |cff8a8f99Up|r its parent   |cff8a8f99Down|r back to the mouse   |cff8a8f99Esc|r stop")
    end)
    pick:SetScript("OnKeyDown", function()
      local key = arg1
      if key == "ESCAPE" then
        this:Hide()
      elseif key == "ENTER" then
        local f = this.target
        this:Hide()
        if f then MV.PickName(f:GetName()) end
      elseif key == "UP" then
        local f = this.target and this.target.GetParent and this.target:GetParent()
        while f and not MV.Usable(f) do f = f.GetParent and f:GetParent() end
        if f then this.parentOf = f end
      elseif key == "DOWN" then
        this.parentOf = nil
      end
    end)
    pick:SetScript("OnHide", function() this.parentOf = nil this.target = nil end)
    pick:Hide()
    return pick
  end
  function MV.StartPick()
    if pfUI.unlock and pfUI.unlock:IsShown() then pfUI.unlock:Hide() end
    if pfUI.gui and pfUI.gui:IsShown() then pfUI.gui:Hide() end
    PickFrame():Show()
  end
  -- by name (the picker, /moveany <name>, the options' box): into layout mode, then layout mode opens on it
  function MV.PickName(name, quiet)
    local f = name and _G[name]
    if not f then
      if not quiet then Say("no frame called \"" .. tostring(name) .. "\" (names are case sensitive; /fstack-like: use Pick a frame).") end
      return
    end
    local real = MV.Usable(f)
    if not real then
      if not quiet then Say(tostring(name) .. " cannot be moved (not a frame, or the screen itself).") end
      return
    end
    if pfUI.movables[real] and not MV.mine[real] then
      if not quiet then Say(MV.Label(real) .. " can be moved in layout mode already.") end
    else
      Tbl("picked")[real] = "1"
      -- a picked frame should be seen straight away: the switch goes on
      if not MV.Showing() then MV.SetShowing(true) end
      MV.Make(f, "picked")
      if not quiet then Say(MV.Label(real) .. " can be moved now: it has a box in layout mode.") end
    end
    if not quiet and pfUI.unlock then pfUI.unlock:Show() end
    return real
  end
  function MV.Unpick(name)
    Tbl("picked")[name] = nil
    MV.Unmake(name)
  end

  -- ---------------------------------------------------------------- start

  local ev = CreateFrame("Frame", "pfMoversEvents")
  ev:RegisterEvent("ADDON_LOADED")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:SetScript("OnEvent", function()
    MV.Apply()
    if event == "PLAYER_ENTERING_WORLD" then MV.Reapply() end
  end)
  -- labels for the boxes (unlock.lua NiceLabel) and right-click = the Move anything page (unlock.lua GetConfigTable)
  if pfUI.unlockNice then for name, l in pairs(MV.LABEL) do pfUI.unlockNice[name] = l end end
  MV.Apply()

  _G.SLASH_PFMOVEANY1, _G.SLASH_PFMOVEANY2 = "/moveany", "/mva"
  _G.SlashCmdList["PFMOVEANY"] = function(msg)
    msg = string.gsub(msg or "", "^%s+", "")
    msg = string.gsub(msg, "%s+$", "")
    if msg == "" then MV.StartPick() else MV.PickName(msg) end
  end
end)
