pfUI:RegisterModule("octo-blizzard", "vanilla", function ()
  -- pfUI Octo :: one switch per section between pfUI Octo's version and
  -- Blizzard's own, live, no reload (user, 23 Oct 2026: "turning on will put
  -- on the addons version of this turning off will put it back to your
  -- blizzard setup ... one press toggle on and off no reloads").
  -- This module loads FIRST (top of init\modules.xml): it notes how
  -- Blizzard's frames and functions are set up before pfUI's modules hide
  -- or replace them. A section switched to Blizzard puts those back and
  -- re-runs each frame's own setup (its FrameXML OnLoad: the events it
  -- listens to, read from the client's patch-4 FrameXML); pfUI's frames go
  -- under a hidden parent. Switching back undoes that the way pfUI's
  -- modules do it. Settings: C.blizz[id] = "1" -> Blizzard's.
  -- Sections: unit frames, cast bar, raid frames, action bars, minimap,
  -- buffs, world map, nameplates, bags, loot, combat text, meters, chat,
  -- tooltip, panels.
  local BZ = { snap = {}, globals = {}, state = {} }
  pfUI.blizz = BZ
  C.blizz = C.blizz or {}

  local hider = CreateFrame("Frame", "pfOctoBlizzHider", UIParent)
  hider:Hide()
  BZ.hider = hider

  -- ---------------------------------------------------------------- snapshot (before pfUI)

  local function Snap(f, store)
    store = store or BZ.snap
    if not f or store[f] then return end
    -- (textures such as MinimapBorderTop have no GetScale on 1.12: in game that
    -- stopped this module before BZ.GROUPS, and every options page errored)
    local s = { parent = f.GetParent and f:GetParent(), scale = f.GetScale and f:GetScale(), alpha = f:GetAlpha(),
                shown = f:IsShown(), w = f:GetWidth(), h = f:GetHeight(), points = {} }
    for i = 1, (f.GetNumPoints and f:GetNumPoints() or 0) do s.points[i] = { f:GetPoint(i) } end
    if f.GetScript then
      for _, sc in ipairs({ "OnShow", "OnEvent", "OnMouseWheel" }) do
        local ok, fn = pcall(f.GetScript, f, sc)
        if ok then s[sc] = fn or false end
      end
    end
    store[f] = s
  end
  BZ.Snap = Snap

  local FRAMES = { "PlayerFrame", "TargetFrame", "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3",
    "PartyMemberFrame4", "CastingBarFrame", "BuffFrame", "TemporaryEnchantFrame", "ComboFrame", "MainMenuBar",
    "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight", "Minimap", "MiniMapMailFrame",
    "MiniMapBattlefieldFrame", "MiniMapTrackingFrame", "GameTimeFrame", "MinimapZoomIn", "MinimapZoomOut",
    "MinimapZoneTextButton", "MinimapBorderTop", "MiniMapWorldMapButton", "MinimapToggleButton", "LootFrame",
    "MiniMapMailBorder", "MiniMapBattlefieldBorder" }
  for _, n in ipairs(FRAMES) do Snap(_G[n]) end
  for _, n in ipairs(type(MICRO_BUTTONS) == "table" and MICRO_BUTTONS or {}) do Snap(_G[n]) end
  BZ.borderTex = MinimapBorder and MinimapBorder:GetTexture()
  BZ.mailTex = MiniMapMailIcon and MiniMapMailIcon:GetTexture()
  BZ.multi = { SHOW_MULTI_ACTIONBAR_1, SHOW_MULTI_ACTIONBAR_2, SHOW_MULTI_ACTIONBAR_3, SHOW_MULTI_ACTIONBAR_4 }

  -- functions pfUI replaces: Blizzard's now, pfUI's once every module ran
  local GLOBALS = { bags = { "OpenAllBags", "CloseAllBags", "ToggleBackpack", "ToggleBag" },
    loot = { "GroupLootDropDown_GiveLoot" } }
  -- chat: the strings pfUI shortens ("[G]" for guild...), its font sizes and
  -- link handler; the tooltip's anchor
  GLOBALS.chat = { "CHAT_FONT_HEIGHTS", "SetItemRef", "CHAT_CHANNEL_GET", "CHAT_GUILD_GET", "CHAT_OFFICER_GET",
    "CHAT_PARTY_GET", "CHAT_RAID_GET", "CHAT_RAID_LEADER_GET", "CHAT_RAID_WARNING_GET", "CHAT_BATTLEGROUND_GET",
    "CHAT_BATTLEGROUND_LEADER_GET", "CHAT_SAY_GET", "CHAT_YELL_GET", "CHAT_WHISPER_GET", "CHAT_WHISPER_INFORM_GET" }
  GLOBALS.tooltip = { "GameTooltip_SetDefaultAnchor" }
  for _, list in pairs(GLOBALS) do
    for _, n in ipairs(list) do BZ.globals[n] = { blizz = _G[n] } end
  end

  -- each chat window as the game made it: place, tab, background art,
  -- tab text, scroll buttons, and the edit box
  local function Tex(t) return t and t.GetTexture and t:GetTexture() end
  local function FontOf(fs)
    if not fs or not fs.GetFont then return end
    local font, size, flags = fs:GetFont()
    local r, g, b, a = 1, 1, 1, 1
    if fs.GetTextColor then r, g, b, a = fs:GetTextColor() end
    return { font, size, flags, r, g, b, a, h = fs:GetHeight(), jv = fs.GetJustifyV and fs:GetJustifyV() }
  end
  -- (in a pcall: a surprise here must not stop the module - 23 Oct 2026 a
  -- texture without GetScale did, and every options page errored)
  local snapOk, snapErr = pcall(function()
  BZ.chat = {}
  for i = 1, (tonumber(NUM_CHAT_WINDOWS) or 7) do
    local frame, tab = _G["ChatFrame" .. i], _G["ChatFrame" .. i .. "Tab"]
    if frame and tab then
      local c = { tex = {}, tabregions = {}, text = FontOf(_G["ChatFrame" .. i .. "TabText"]) }
      Snap(frame)
      Snap(tab)
      Snap(_G["ChatFrame" .. i .. "TabText"])
      for _, part in ipairs({ "TabLeft", "TabMiddle", "TabRight", "UpButton", "DownButton", "BottomButton" }) do
        Snap(_G["ChatFrame" .. i .. part])
      end
      for _, name in pairs(type(CHAT_FRAME_TEXTURES) == "table" and CHAT_FRAME_TEXTURES or {}) do
        local t = _G["ChatFrame" .. i .. name]
        if t then c.tex[name] = { tex = Tex(t), shown = t:IsShown() } end
      end
      for j, v in ipairs({ tab:GetRegions() }) do
        c.tabregions[j] = { tex = Tex(v), h = v.GetHeight and v:GetHeight() }
      end
      c.wheel = frame.IsMouseWheelEnabled and frame:IsMouseWheelEnabled()
      BZ.chat[i] = c
    end
  end
  if ChatFrameEditBox then
    Snap(ChatFrameEditBox)
    BZ.editRegions = {}
    for i, v in ipairs({ ChatFrameEditBox:GetRegions() }) do
      BZ.editRegions[i] = { shown = v:IsShown(), font = FontOf(v) }
    end
  end
  Snap(ChatFrameMenuButton)

  -- the tooltips' own backdrops and health bar
  BZ.tips = {}
  for _, n in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
    local t = _G[n]
    if t and t.GetBackdrop then
      local r, g, b, a = t:GetBackdropColor()
      local er, eg, eb, ea = t:GetBackdropBorderColor()
      BZ.tips[n] = { backdrop = t:GetBackdrop(), bg = { r, g, b, a }, edge = { er, eg, eb, ea } }
    end
  end
  if GameTooltipStatusBar then
    Snap(GameTooltipStatusBar)
    BZ.tipBarTex = GameTooltipStatusBar.GetStatusBarTexture and Tex(GameTooltipStatusBar:GetStatusBarTexture())
  end
  end)
  if not snapOk then
    BZ.chat = BZ.chat or {}
    BZ.tips = BZ.tips or {}
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: chat / tooltip switch could not note the game's setup: " .. tostring(snapErr))
  end

  -- ---------------------------------------------------------------- helpers

  -- run a FrameXML function with `this` set (the game's own global)
  local function Call(fn, frame, a1)
    if type(fn) ~= "function" then return end
    local old, olda = _G.this, _G.arg1
    _G.this, _G.arg1 = frame, a1
    pcall(fn, a1)
    _G.this, _G.arg1 = old, olda
  end

  -- a Blizzard frame as it was: parent, place, size, scale, scripts, Show
  local function Restore(f, show, store)
    if not f then return end
    local s = (store or BZ.snap)[f]
    f.Show = nil
    if s then
      if s.parent and f.SetParent then f:SetParent(s.parent) end
      if s.points[1] then
        f:ClearAllPoints()
        for _, p in ipairs(s.points) do
          if p[1] then f:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
        end
      end
      if f.SetScale then f:SetScale(s.scale or 1) end
      f:SetAlpha(s.alpha or 1)
      if s.OnShow ~= nil then f:SetScript("OnShow", s.OnShow or nil) end
    end
    -- (1.12: out of a hidden parent a frame stays unseen until hidden and
    -- shown again - the switch "did nothing", user 25 Oct 2026)
    if show == true or (show == nil and s and s.shown) then f:Hide() f:Show() end
  end
  BZ.Restore = Restore

  -- pfUI's way: hidden, deaf, and (killshow) unable to show itself
  local function Kill(f, killshow)
    if not f then return end
    if f.UnregisterAllEvents then f:UnregisterAllEvents() end
    f:Hide()
    if killshow then f.Show = function() return end end
  end
  BZ.Kill = Kill

  -- pfUI's frames out of sight (a hidden parent) and back
  local function Away(f)
    if not f or f.octoAway then return end
    f.octoAway = f:GetParent() or UIParent
    f:SetParent(hider)
  end
  local function Back(f)
    if not f or not f.octoAway then return end
    f:SetParent(f.octoAway)
    f.octoAway = nil
    -- (seen again only after a hide and show: see Restore)
    if f:IsShown() then f:Hide() f:Show() end
  end
  BZ.Away, BZ.Back = Away, Back
  -- (any frame moved out of a hidden parent: seen again)
  local function Reshow(f) if f and f.IsShown and f:IsShown() then f:Hide() f:Show() end end
  BZ.Reshow = Reshow

  local function Reg(f, events)
    if not f then return end
    for _, e in ipairs(events) do f:RegisterEvent(e) end
  end

  -- ---------------------------------------------------------------- sections

  local S = {}
  BZ.S = S

  -- unit frames: player (with its pet), target, party, combo points
  S.unitframes = {
    label = "Unit frames",
    blizz = function()
      for _, f in ipairs(pfUI.uf and pfUI.uf.frames or {}) do
        if not f.octoPreview then Away(f) end
      end
      if pfUI.combopoints then for _, c in pairs(pfUI.combopoints) do if type(c) == "table" and c.SetParent then Away(c) end end end
      -- (6 Nov 2026, Barbeque: the player frame came back without portrait or health bar. The game's
      -- XML runs UnitFrame_Initialize first - name / portrait / power events and the bars' health
      -- events - and then PlayerFrame_OnLoad; only the second used to be done here)
      local function Init(frame, unit, name, portrait, hb, ht, mb, mt)
        if type(UnitFrame_Initialize) ~= "function" or not frame then return end
        local old = _G.this
        _G.this = frame
        pcall(UnitFrame_Initialize, unit, _G[name], _G[portrait], _G[hb], _G[ht], _G[mb], _G[mt])
        _G.this = old
      end
      Restore(PlayerFrame, true)
      Init(PlayerFrame, "player", "PlayerName", "PlayerPortrait", "PlayerFrameHealthBar", "PlayerFrameHealthBarText",
        "PlayerFrameManaBar", "PlayerFrameManaBarText")
      Call(PlayerFrame_OnLoad, PlayerFrame)
      Restore(TargetFrame, false)
      Init(TargetFrame, "target", "TargetName", "TargetPortrait", "TargetFrameHealthBar", "TargetFrameHealthBarText",
        "TargetFrameManaBar", "TargetFrameManaBarText")
      Call(TargetFrame_OnLoad, TargetFrame)
      Call(TargetFrame_Update, TargetFrame)
      for i = 1, 4 do
        local f = _G["PartyMemberFrame" .. i]
        if f then
          Restore(f, false)
          Call(PartyMemberFrame_OnLoad, f)
          Call(PartyMemberFrame_UpdateMember, f)
        end
      end
      if ComboFrame then
        Restore(ComboFrame, false)
        Reg(ComboFrame, { "PLAYER_TARGET_CHANGED", "PLAYER_COMBO_POINTS" })
        if ComboFrame_Update then pcall(ComboFrame_Update) end
      end
    end,
    octo = function()
      Kill(PlayerFrame)
      Kill(TargetFrame)
      for i = 1, 4 do Kill(_G["PartyMemberFrame" .. i], true) end
      Kill(ComboFrame)
      for _, f in ipairs(pfUI.uf and pfUI.uf.frames or {}) do Back(f) end
      if pfUI.combopoints then for _, c in pairs(pfUI.combopoints) do if type(c) == "table" and c.SetParent then Back(c) end end end
      if pfUI.uf then
        for _, f in ipairs(pfUI.uf.frames or {}) do
          if f.UpdateConfig and not f.octoPreview then pcall(f.UpdateConfig, f) end
        end
      end
    end,
  }

  S.castbar = {
    label = "Cast bar",
    blizz = function()
      if pfUI.castbar then for _, k in ipairs({ "player", "target", "focus" }) do Away(pfUI.castbar[k]) end end
      Restore(CastingBarFrame, false)
      Call(CastingBarFrame_OnLoad, CastingBarFrame)
    end,
    octo = function()
      if CastingBarFrame then
        CastingBarFrame:SetScript("OnShow", function() CastingBarFrame:Hide() end)
        Kill(CastingBarFrame)
      end
      if pfUI.castbar then for _, k in ipairs({ "player", "target", "focus" }) do Back(pfUI.castbar[k]) end end
    end,
  }

  S.buffs = {
    label = "Buffs",
    blizz = function()
      if pfUI.buff then for _, k in ipairs({ "buffs", "debuffs", "wepbuffs" }) do Away(pfUI.buff[k]) end end
      Restore(BuffFrame, true)
      Call(BuffFrame_OnLoad, BuffFrame)
      Restore(TemporaryEnchantFrame, true)
    end,
    octo = function()
      Kill(BuffFrame)
      Kill(TemporaryEnchantFrame)
      if pfUI.buff then for _, k in ipairs({ "buffs", "debuffs", "wepbuffs" }) do Back(pfUI.buff[k]) end end
    end,
  }

  -- the main bar, the four extra bars and the micro buttons
  local function PfBars()
    local out = {}
    for _, n in ipairs({ "pfActionBar", "pfActionBarPageSwitch" }) do if _G[n] then table.insert(out, _G[n]) end end
    for _, n in ipairs({ "Main", "Top", "Left", "Right", "Vertical", "Paging", "Stances", "Pet",
                          "StanceBar1", "StanceBar2", "StanceBar3", "StanceBar4" }) do
      if _G["pfActionBar" .. n] then table.insert(out, _G["pfActionBar" .. n]) end
    end
    return out
  end
  S.actionbars = {
    label = "Action bars",
    blizz = function()
      for _, f in ipairs(PfBars()) do Away(f) end
      if pfUI.panel and pfUI.panel.microbutton then Away(pfUI.panel.microbutton) end
      Restore(MainMenuBar, true)
      for i, n in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft" }) do
        Restore(_G[n], false)
      end
      local m = BZ.multi
      SHOW_MULTI_ACTIONBAR_1, SHOW_MULTI_ACTIONBAR_2, SHOW_MULTI_ACTIONBAR_3, SHOW_MULTI_ACTIONBAR_4 = m[1], m[2], m[3], m[4]
      if SetActionBarToggles then SetActionBarToggles(m[1], m[2], m[3], m[4]) end
      if MultiActionBar_Update then pcall(MultiActionBar_Update) end
      for _, n in ipairs(MICRO_BUTTONS or {}) do
        local b = _G[n]
        if b then
          Restore(b, true)
          if b.frame then b.frame:Hide() end
        end
      end
      if UpdateMicroButtons then pcall(UpdateMicroButtons) end
    end,
    octo = function()
      Kill(MainMenuBar)
      for _, n in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight" }) do Kill(_G[n], true) end
      if SetActionBarToggles then SetActionBarToggles(0, 0, 0, 0) end
      SHOW_MULTI_ACTIONBAR_1, SHOW_MULTI_ACTIONBAR_2, SHOW_MULTI_ACTIONBAR_3, SHOW_MULTI_ACTIONBAR_4 = nil, nil, nil, nil
      for _, f in ipairs(PfBars()) do Back(f) end
      local mb = pfUI.panel and pfUI.panel.microbutton
      if mb then
        Back(mb)
        for i = 1, table.getn(MICRO_BUTTONS or {}) do
          local button = _G[MICRO_BUTTONS[i]]
          local anchor = _G[MICRO_BUTTONS[i - 1]] or mb
          if button then
            button:ClearAllPoints()
            button:SetParent(mb) Reshow(button)
            if i == 1 then button:SetPoint("LEFT", mb, "LEFT", 1, 10) else button:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 1, 0) end
            button:SetScale(.6)
            if button.frame then button.frame:Show() end
            button:Show()
          end
        end
      end
      if pfUI.bars and pfUI.bars.UpdateConfig then pcall(pfUI.bars.UpdateConfig, pfUI.bars) end
    end,
  }

  -- the minimap: back in Blizzard's cluster with its border, zoom, clock
  -- and buttons; the addon buttons go back round it
  S.minimap = {
    label = "Minimap",
    blizz = function()
      local m = pfUI.minimap
      if pfUI.addonbuttons and pfUI.addonbuttons.RestoreAll then pcall(pfUI.addonbuttons.RestoreAll, pfUI.addonbuttons) end
      Restore(Minimap, true)
      -- (never left inside pfUI's map, which is hidden next)
      if Minimap:GetParent() == m then
        Minimap:SetParent(MinimapCluster or UIParent) Reshow(Minimap)
        if not (BZ.snap[Minimap] and BZ.snap[Minimap].points[1]) then
          Minimap:ClearAllPoints()
          Minimap:SetPoint("CENTER", MinimapCluster or UIParent, "TOP", 9, -92)
        end
      end
      local s = BZ.snap[Minimap]
      if s and s.w and s.w > 0 then Minimap:SetWidth(s.w) Minimap:SetHeight(s.h) end
      Minimap:SetFrameLevel((MinimapCluster and MinimapCluster:GetFrameLevel() or 1) + 1)
      Minimap:SetMaskTexture("Textures\\MinimapMask")
      if s and s.OnMouseWheel ~= nil then Minimap:SetScript("OnMouseWheel", s.OnMouseWheel or nil) end
      if MinimapBorder then
        MinimapBorder:SetTexture(BZ.borderTex or "Interface\\Minimap\\UI-Minimap-Border")
        MinimapBorder:SetTexCoord(.25, 1, .125, .875)
      end
      for _, n in ipairs({ "MinimapBorderTop", "MinimapZoneTextButton", "MinimapZoomIn", "MinimapZoomOut", "GameTimeFrame",
                           "MiniMapWorldMapButton", "MinimapToggleButton", "MiniMapMailBorder", "MiniMapBattlefieldBorder" }) do
        Restore(_G[n], true)
      end
      Restore(MiniMapMailFrame, false)
      if MiniMapMailIcon and BZ.mailTex then MiniMapMailIcon:SetTexture(BZ.mailTex) end
      if MiniMapMailFrame then
        Reg(MiniMapMailFrame, { "UPDATE_PENDING_MAIL" })
        if HasNewMail and HasNewMail() then MiniMapMailFrame:Show() else MiniMapMailFrame:Hide() end
      end
      Restore(MiniMapBattlefieldFrame, false)
      if MiniMapTrackingFrame then
        Restore(MiniMapTrackingFrame, false)
        Reg(MiniMapTrackingFrame, { "PLAYER_AURAS_CHANGED" })
        if GetTrackingTexture and GetTrackingTexture() and MiniMapTrackingIcon then
          MiniMapTrackingIcon:SetTexture(GetTrackingTexture())
          MiniMapTrackingFrame:Show()
        end
      end
      if MinimapCluster then MinimapCluster:Show() end
      if Minimap_Update then pcall(Minimap_Update) end
      for _, f in ipairs({ m, pfUI.tracking, pfUI.panel and pfUI.panel.minimap, pfUI.addonbuttons }) do Away(f) end
    end,
    octo = function()
      local m = pfUI.minimap
      if not m then return end
      for _, f in ipairs({ m, pfUI.tracking, pfUI.panel and pfUI.panel.minimap, pfUI.addonbuttons }) do Back(f) end
      for _, n in ipairs({ "MinimapBorderTop", "MinimapZoneTextButton", "MinimapZoomIn", "MinimapZoomOut", "GameTimeFrame",
                           "MiniMapWorldMapButton", "MinimapToggleButton", "MiniMapMailBorder", "MiniMapBattlefieldBorder" }) do
        if _G[n] then _G[n]:Hide() end
      end
      if MiniMapTrackingFrame then Kill(MiniMapTrackingFrame) end
      if MinimapBorder then MinimapBorder:SetTexture(nil) end
      Minimap:SetParent(m) Reshow(Minimap)
      Minimap:ClearAllPoints()
      Minimap:SetPoint("CENTER", m, "CENTER", .5, -.5)
      Minimap:SetFrameLevel(1)
      Minimap:EnableMouseWheel(true)
      Minimap:SetScript("OnMouseWheel", function() if arg1 > 0 then Minimap_ZoomIn() else Minimap_ZoomOut() end end)
      if MiniMapMailFrame then
        MiniMapMailFrame:SetParent(MinimapBackdrop or Minimap) Reshow(MiniMapMailFrame)
        MiniMapMailFrame:ClearAllPoints()
        MiniMapMailFrame:SetPoint("TOPRIGHT", m, "TOPRIGHT", 0, 0)
        if MiniMapMailIcon then MiniMapMailIcon:SetTexture(pfUI.media["img:mail"]) end
      end
      if MiniMapBattlefieldFrame then
        MiniMapBattlefieldFrame:ClearAllPoints()
        MiniMapBattlefieldFrame:SetPoint("BOTTOMRIGHT", Minimap, 4, -4)
      end
      if m.UpdateConfig then pcall(m.UpdateConfig, m) end
      if pfUI.addonbuttons and pfUI.addonbuttons.ProcessButtons then pcall(pfUI.addonbuttons.ProcessButtons, pfUI.addonbuttons) end
    end,
  }

  -- nameplates: the game's own plate parts back, pfUI's drawing hidden
  -- (each plate's parts are noted before pfUI blanks them, see Wrap below)
  local function PlateParts(plate)
    local o = plate.octoBlizz
    if not o then return end
    for _, e in ipairs(o) do
      local obj = e.obj
      if e.kind == "Texture" then
        obj:SetTexture(e.tex)
        if e.tc then obj:SetTexCoord(e.tc[1], e.tc[2], e.tc[3], e.tc[4], e.tc[5], e.tc[6], e.tc[7], e.tc[8]) end
      elseif e.kind == "FontString" then
        if e.w then obj:SetWidth(e.w) end
      elseif e.kind == "StatusBar" then
        obj:SetStatusBarTexture(e.tex or "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
      end
    end
  end
  local function Blank(obj)
    local t = obj.GetObjectType and obj:GetObjectType()
    if t == "Texture" then obj:SetTexture("") obj:SetTexCoord(0, 0, 0, 0)
    elseif t == "FontString" then obj:SetWidth(.001)
    elseif t == "StatusBar" then obj:SetStatusBarTexture("") end
  end
  local function Plates()
    local out = {}
    for _, f in ipairs({ WorldFrame:GetChildren() }) do if f.nameplate and f.octoBlizz then table.insert(out, f) end end
    return out
  end
  S.nameplates = {
    label = "Nameplates",
    blizz = function()
      for _, plate in ipairs(Plates()) do
        PlateParts(plate)
        Away(plate.nameplate)
      end
    end,
    octo = function()
      for _, plate in ipairs(Plates()) do
        for _, e in ipairs(plate.octoBlizz) do if not e.keep then Blank(e.obj) end end
        Back(plate.nameplate)
      end
    end,
  }
  -- note a plate's parts before pfUI blanks them, and keep new plates in
  -- the look picked
  local function WrapPlates()
    local NP = pfUI.nameplates
    if not NP or NP.octoBlizzWrapped or not NP.OnCreate then return end
    NP.octoBlizzWrapped = true
    local create = NP.OnCreate
    NP.OnCreate = function(frame)
      local parent = frame or _G.this
      if parent and not parent.octoBlizz then
        local list = {}
        local bars = { parent:GetChildren() }
        for i = 1, 2 do
          local b = bars[i]
          if b and b.GetStatusBarTexture then
            local tx = b:GetStatusBarTexture()
            table.insert(list, { obj = b, kind = "StatusBar", tex = tx and tx.GetTexture and tx:GetTexture() })
          end
        end
        for i, r in ipairs({ parent:GetRegions() }) do
          local kind = r.GetObjectType and r:GetObjectType()
          local keep = NAMEPLATE_OBJECTORDER and NAMEPLATE_OBJECTORDER[i] == "raidicon"
          if kind == "Texture" then
            table.insert(list, { obj = r, kind = kind, tex = r:GetTexture(), tc = { r:GetTexCoord() }, keep = keep })
          elseif kind == "FontString" then
            table.insert(list, { obj = r, kind = kind, w = r:GetWidth() })
          end
        end
        parent.octoBlizz = list
      end
      local out = create(frame)
      if C.blizz.nameplates == "1" and parent then
        PlateParts(parent)
        if parent.nameplate then Away(parent.nameplate) end
      end
      return out
    end
  end
  BZ.WrapPlates = WrapPlates

  S.bags = {
    label = "Bags",
    blizz = function()
      if CloseAllBags then pcall(CloseAllBags) end
      for _, n in ipairs(GLOBALS.bags) do
        local g = BZ.globals[n]
        if g.blizz then _G[n] = g.blizz end
      end
      if pfUI.bag then Away(pfUI.bag.right) Away(pfUI.bag.left) end
    end,
    octo = function()
      for i = 1, (NUM_CONTAINER_FRAMES or 12) do
        local cf = _G["ContainerFrame" .. i]
        if cf and cf:IsShown() then cf:Hide() end
      end
      for _, n in ipairs(GLOBALS.bags) do
        local g = BZ.globals[n]
        if g.octo then _G[n] = g.octo end
      end
      if pfUI.bag then Back(pfUI.bag.right) Back(pfUI.bag.left) end
    end,
  }

  S.loot = {
    label = "Loot",
    blizz = function()
      if pfUI.loot then
        pfUI.loot.octoEvent = pfUI.loot.octoEvent or pfUI.loot:GetScript("OnEvent")
        pfUI.loot:SetScript("OnEvent", nil)
        pfUI.loot:Hide()
      end
      for _, n in ipairs(GLOBALS.loot) do
        local g = BZ.globals[n]
        if g.blizz then _G[n] = g.blizz end
      end
      Restore(LootFrame, false)
      Call(LootFrame_OnLoad, LootFrame)
    end,
    octo = function()
      if LootFrame then LootFrame:UnregisterAllEvents() LootFrame:Hide() end
      for _, n in ipairs(GLOBALS.loot) do
        local g = BZ.globals[n]
        if g.octo then _G[n] = g.octo end
      end
      if pfUI.loot and pfUI.loot.octoEvent then pfUI.loot:SetScript("OnEvent", pfUI.loot.octoEvent) end
    end,
  }

  S.combattext = {
    label = "Combat text",
    blizz = function()
      local CT = pfUI.sct and pfUI.sct.CT
      if CT and CT.SetEnabled then pcall(CT.SetEnabled, CT, false) end
    end,
    octo = function()
      local CT = pfUI.sct and pfUI.sct.CT
      if CT and CT.SetEnabled then pcall(CT.SetEnabled, CT, true) end
    end,
  }

  -- (the game has no meters: off hides the windows)
  S.meters = {
    label = "Meters",
    blizz = function()
      local M = pfUI.meters
      for _, w in ipairs(M and M.windows or {}) do Away(w) end
    end,
    octo = function()
      local M = pfUI.meters
      for _, w in ipairs(M and M.windows or {}) do Back(w) end
    end,
  }

  local function SetGlobals(list, which)
    for _, n in ipairs(list) do
      local g = BZ.globals[n]
      if g and (which == "blizz" or g.octo ~= nil) then _G[n] = g[which] end
    end
  end
  local function Font(fs, f)
    if not fs or not f or not f[1] then return end
    fs:SetFont(f[1], f[2], f[3] or "")
    if f[4] and fs.SetTextColor then fs:SetTextColor(f[4], f[5], f[6], f[7] or 1) end
    if f.h and f.h > 0 and fs.SetHeight then fs:SetHeight(f.h) end
    if f.jv and fs.SetJustifyV then fs:SetJustifyV(f.jv) end
  end
  BZ.osnap = {}

  -- chat: the windows back on the game's own frames, art and buttons; the
  -- game docks and fades them again. pfUI's RefreshChat stands down
  -- meanwhile (chat.lua).
  S.chat = {
    label = "Chat",
    blizz = function()
      if not pfUI.chat then return end
      -- First, whatever the snapshot holds: every window and the typing box
      -- back on UIParent where the game puts them (FloatingChatFrame.xml:
      -- ChatFrame1 BOTTOMLEFT 32, 95, 430 x 120; the edit box under it).
      -- 23 Oct 2026 in game they stayed inside pfUI's chat panels, which then
      -- went away: no chat and no way to type.
      for i = 1, (tonumber(NUM_CHAT_WINDOWS) or 7) do
        local frame, tab = _G["ChatFrame" .. i], _G["ChatFrame" .. i .. "Tab"]
        if frame then frame:SetParent(UIParent) Reshow(frame) end
        if tab then tab:SetParent(UIParent) Reshow(tab) end
      end
      if ChatFrame1 then
        local s = BZ.snap[ChatFrame1]
        if not (s and s.points[1]) or ChatFrame1:GetParent() ~= UIParent then
          ChatFrame1:ClearAllPoints()
          ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 95)
          ChatFrame1:SetWidth(430)
          ChatFrame1:SetHeight(120)
        end
        ChatFrame1:Show()
      end
      if ChatFrameEditBox and ChatFrame1 then
        ChatFrameEditBox:SetParent(UIParent) Reshow(ChatFrameEditBox)
        ChatFrameEditBox:ClearAllPoints()
        ChatFrameEditBox:SetPoint("TOPLEFT", ChatFrame1, "BOTTOMLEFT", -5, -2)
        ChatFrameEditBox:SetPoint("TOPRIGHT", ChatFrame1, "BOTTOMRIGHT", 5, -2)
      end
      for i, c in pairs(BZ.chat) do
        local frame, tab = _G["ChatFrame" .. i], _G["ChatFrame" .. i .. "Tab"]
        Restore(frame, frame:IsShown())
        Restore(tab, tab:IsShown())
        tab.SetAlpha = nil
        for name, t in pairs(c.tex) do
          local tex = _G["ChatFrame" .. i .. name]
          if tex then
            tex:SetTexture(name == "Background" and (tex.oldTexture or t.tex) or t.tex)
            if t.shown then tex:Show() end
          end
        end
        for j, v in ipairs({ tab:GetRegions() }) do
          local r = c.tabregions[j]
          if r then
            if r.tex and v.SetTexture then v:SetTexture(r.tex) end
            if r.h and r.h > 0 and v.SetHeight then v:SetHeight(r.h) end
          end
        end
        local text = _G["ChatFrame" .. i .. "TabText"]
        Restore(text, true)
        Font(text, c.text)
        for _, part in ipairs({ "TabLeft", "TabMiddle", "TabRight" }) do Restore(_G["ChatFrame" .. i .. part], true) end
        for _, part in ipairs({ "UpButton", "DownButton", "BottomButton" }) do Restore(_G["ChatFrame" .. i .. part], true) end
        local flash = _G["ChatFrame" .. i .. "TabFlash"]
        if flash then flash.Show = nil end
        local s = BZ.snap[frame]
        frame:SetScript("OnMouseWheel", s and s.OnMouseWheel or nil)
        frame:EnableMouseWheel(c.wheel and true or false)
        if frame.SetFading then frame:SetFading(true) end
        if frame.SetTimeVisible then frame:SetTimeVisible(120) end
      end
      if ChatFrameEditBox then
        Restore(ChatFrameEditBox, false)
        if ChatFrameEditBox:GetParent() ~= UIParent then ChatFrameEditBox:SetParent(UIParent) end
        if ChatFrameEditBox.backdrop then ChatFrameEditBox.backdrop:Hide() end
        for i, v in ipairs({ ChatFrameEditBox:GetRegions() }) do
          local r = BZ.editRegions and BZ.editRegions[i]
          if r then
            if r.shown then v:Show() end
            Font(v, r.font)
          end
        end
      end
      Restore(ChatFrameMenuButton, true)
      SetGlobals(GLOBALS.chat, "blizz")
      for _, f in ipairs({ pfUI.chat.left, pfUI.chat.right, pfUI.chat.editbox }) do Away(f) end
      if FCF_DockUpdate then pcall(FCF_DockUpdate) end
      -- chat and the typing box must be usable, or this is undone (BZ.Set)
      if ChatFrame1 and not ChatFrame1:IsVisible() then error("the chat window did not come back") end
      if ChatFrameEditBox and ChatFrameEditBox:GetParent() ~= UIParent then error("the typing box did not come back") end
    end,
    octo = function()
      if not pfUI.chat then return end
      for _, f in ipairs({ pfUI.chat.left, pfUI.chat.right, pfUI.chat.editbox }) do Back(f) end
      SetGlobals(GLOBALS.chat, "octo")
      for i in pairs(BZ.chat) do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        local o = BZ.chatOcto and BZ.chatOcto[i]
        if o then
          tab.SetAlpha = o.tabAlpha
          local flash = _G["ChatFrame" .. i .. "TabFlash"]
          if flash then flash.Show = o.flashShow end
        end
        for _, part in ipairs({ "UpButton", "DownButton", "BottomButton" }) do Kill(_G["ChatFrame" .. i .. part], true) end
      end
      if ChatFrameEditBox and pfUI.chat.editbox then
        ChatFrameEditBox:SetParent(pfUI.chat.editbox) Reshow(ChatFrameEditBox)
        ChatFrameEditBox:ClearAllPoints()
        ChatFrameEditBox:SetAllPoints(pfUI.chat.editbox)
        if ChatFrameEditBox.backdrop then ChatFrameEditBox.backdrop:Show() end
        for i, v in ipairs({ ChatFrameEditBox:GetRegions() }) do
          if i == 6 or i == 7 or i == 8 then v:Hide() end
          if v.SetFont then v:SetFont(pfUI.font_default, C.global.font_size + 1, "OUTLINE") end
        end
      end
      if pfUI.chat.RefreshChat then pcall(pfUI.chat.RefreshChat, pfUI.chat) end
      if FCF_DockUpdate then pcall(FCF_DockUpdate) end
    end,
  }

  -- tooltip: the game's backdrop, anchor and health bar
  local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }
  S.tooltip = {
    label = "Tooltip",
    blizz = function()
      for _, n in ipairs(TIPS) do
        local t, s = _G[n], BZ.tips[n]
        if t and s then
          if t.backdrop then t.backdrop:Hide() end
          if t.backdrop_shadow then t.backdrop_shadow:Hide() end
          t:SetBackdrop(s.backdrop)
          local bg = TOOLTIP_DEFAULT_BACKGROUND_COLOR
          local edge = TOOLTIP_DEFAULT_COLOR
          if bg then t:SetBackdropColor(bg.r, bg.g, bg.b) elseif s.bg[1] then t:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], s.bg[4]) end
          if edge then t:SetBackdropBorderColor(edge.r, edge.g, edge.b) elseif s.edge[1] then t:SetBackdropBorderColor(s.edge[1], s.edge[2], s.edge[3], s.edge[4]) end
        end
      end
      SetGlobals(GLOBALS.tooltip, "blizz")
      if GameTooltipStatusBar then
        Restore(GameTooltipStatusBar, nil)
        local s = BZ.snap[GameTooltipStatusBar]
        if s and s.h and s.h > 0 then GameTooltipStatusBar:SetHeight(s.h) end
        if BZ.tipBarTex then GameTooltipStatusBar:SetStatusBarTexture(BZ.tipBarTex) end
        if GameTooltipStatusBar.backdrop then GameTooltipStatusBar.backdrop:Hide() end
      end
      Away(pfUI.tooltip)
      Away(pfUI.tooltipStatusBar)
    end,
    octo = function()
      for _, n in ipairs(TIPS) do
        local t = _G[n]
        if t and t.backdrop then
          t:SetBackdrop(nil)
          t.backdrop:Show()
          if t.backdrop_shadow then t.backdrop_shadow:Show() end
        end
      end
      SetGlobals(GLOBALS.tooltip, "octo")
      if GameTooltipStatusBar then
        Restore(GameTooltipStatusBar, nil, BZ.osnap)
        local s = BZ.osnap[GameTooltipStatusBar]
        if s and s.h and s.h > 0 then GameTooltipStatusBar:SetHeight(s.h) end
        if BZ.tipBarOcto then GameTooltipStatusBar:SetStatusBarTexture(BZ.tipBarOcto) end
        if GameTooltipStatusBar.backdrop then GameTooltipStatusBar.backdrop:Show() end
      end
      Back(pfUI.tooltip)
      Back(pfUI.tooltipStatusBar)
    end,
  }

  -- panels: the info bars under the chats and the experience / reputation
  -- bars (the game has none of its own: off hides them)
  local function PanelFrames()
    local p = pfUI.panel or {}
    return { p.left, p.right, pfUI.xp, pfUI.rep }
  end
  S.panels = {
    label = "Panels",
    blizz = function() for _, f in ipairs(PanelFrames()) do Away(f) end end,
    octo = function() for _, f in ipairs(PanelFrames()) do Back(f) end end,
  }

  -- raid frames: the game has none on screen; its own are the Raid tab's
  -- pull-out groups (Blizzard_RaidUI, loaded so they can be dragged out)
  S.raid = {
    label = "Raid frames",
    blizz = function()
      Away(_G.pfRaidCluster)
      Away(_G.pfRaidUpdater)
      if LoadAddOn and not (IsAddOnLoaded and IsAddOnLoaded("Blizzard_RaidUI")) then pcall(LoadAddOn, "Blizzard_RaidUI") end
    end,
    octo = function()
      Back(_G.pfRaidCluster)
      Back(_G.pfRaidUpdater)
    end,
  }

  -- the world map: pfUI's map.lua moves, scales and skins it at the first
  -- PLAYER_ENTERING_WORLD; Blizzard's is full screen with its own art. Its
  -- parts as the game made them, noted now (before map.lua)
  local MAPBUTTONS = { "WorldMapZoomOutButton", "WorldMapFrameCloseButton" }
  local MAPDROPS = { "WorldMapContinentDropDown", "WorldMapZoneDropDown", "WorldMapZoneMinimapDropDown" }
  local BTEX = { "Normal", "Pushed", "Highlight", "Disabled" }
  local function RegionsOf(f)
    local out = {}
    for _, v in ipairs({ f:GetRegions() }) do
      if v.SetTexture then table.insert(out, { r = v, tex = Tex(v), shown = v:IsShown() }) end
    end
    return out
  end
  local function PutRegions(list)
    for _, v in ipairs(list or {}) do
      v.r:SetTexture(v.tex)
      if v.shown then v.r:Show() end
    end
  end
  local function ButtonTex(b)
    local t = {}
    for _, k in ipairs(BTEX) do
      local get = b["Get" .. k .. "Texture"]
      t[k] = get and Tex(get(b)) or false
    end
    t.font = b.GetFontString and FontOf(b:GetFontString())
    return t
  end
  local function PutButton(b, t)
    for _, k in ipairs(BTEX) do
      local set = b["Set" .. k .. "Texture"]
      if set then set(b, t[k] or "") end
    end
    local fs = b.GetFontString and b:GetFontString()
    if fs and t.font and t.font[1] then fs:SetFont(t.font[1], t.font[2], t.font[3]) end
    if b.backdrop then b.backdrop:Hide() end
    if b.texture then b.texture:Hide() end
    if b.icon then b.icon:Hide() end
  end
  local function Size(f)
    local s = f and BZ.snap[f]
    if s and s.w and s.w > 0 then f:SetWidth(s.w) f:SetHeight(s.h) end
  end
  BZ.map = {}
  pcall(function()
    local f = WorldMapFrame
    if not f or not f.GetRegions then return end
    local m = BZ.map
    Snap(f)
    m.regions = RegionsOf(f)
    m.toggle = ToggleWorldMap
    m.panel = UIPanelWindows and UIPanelWindows["WorldMapFrame"]
    m.blackout = BlackoutWorld and BlackoutWorld:IsShown()
    m.scripts = {}
    for _, sc in ipairs({ "OnDragStart", "OnDragStop" }) do m.scripts[sc] = f:GetScript(sc) end
    m.buttons = {}
    for _, n in ipairs(MAPBUTTONS) do
      if _G[n] then Snap(_G[n]) m.buttons[n] = ButtonTex(_G[n]) end
    end
    m.drops = {}
    for _, n in ipairs(MAPDROPS) do
      local d, btn = _G[n], _G[n .. "Button"]
      if d then
        Snap(d)
        if btn then Snap(btn) end
        m.drops[n] = { regions = RegionsOf(d), button = btn and ButtonTex(btn) }
      end
    end
  end)
  -- pfUI's map is in use (not with Cartographer / MetaMap, which pfUI leaves alone)
  local function MapOurs() return pfUI.map and BZ.map.regions and not rawget(_G, "Cartographer") and not rawget(_G, "METAMAP_TITLE") end
  local function ShownMap()
    local was = WorldMapFrame:IsShown()
    if was then HideUIPanel(WorldMapFrame) end
    return was
  end
  S.worldmap = {
    label = "World map",
    blizz = function()
      if not MapOurs() then return end
      local m, f = BZ.map, WorldMapFrame
      local was = ShownMap()
      -- pfUI's way, noted the first time (map.lua set it up after this module)
      if not m.octo then
        m.octo = { toggle = ToggleWorldMap, panel = UIPanelWindows and UIPanelWindows["WorldMapFrame"], scripts = {} }
        for _, sc in ipairs({ "OnShow", "OnMouseWheel", "OnDragStart", "OnDragStop" }) do m.octo.scripts[sc] = f:GetScript(sc) end
      end
      _G.ToggleWorldMap = m.toggle
      if UIPanelWindows then UIPanelWindows["WorldMapFrame"] = m.panel end
      Restore(f, false)
      Size(f)
      local s = BZ.snap[f]
      f:SetScript("OnMouseWheel", s and s.OnMouseWheel or nil)
      f:SetScript("OnDragStart", m.scripts.OnDragStart)
      f:SetScript("OnDragStop", m.scripts.OnDragStop)
      f:SetMovable(false)
      f:EnableKeyboard(true)
      PutRegions(m.regions)
      if f.backdrop then f.backdrop:Hide() end
      if f.backdrop_shadow then f.backdrop_shadow:Hide() end
      if m.blackout and BlackoutWorld then BlackoutWorld:Show() end
      for n, t in pairs(m.buttons) do
        local b = _G[n]
        Restore(b, nil)
        Size(b)
        PutButton(b, t)
      end
      for n, d in pairs(m.drops) do
        local dd, btn = _G[n], _G[n .. "Button"]
        Restore(dd, nil)
        PutRegions(d.regions)
        if dd.backdrop then dd.backdrop:Hide() end
        if btn and d.button then
          Restore(btn, nil)
          Size(btn)
          PutButton(btn, d.button)
        end
      end
      Away(_G.pfWorldMapButtonCoords)
      if was then ShowUIPanel(f) end
    end,
    octo = function()
      -- (never switched to Blizzard's this session: pfUI's is as map.lua left it)
      local m, f = BZ.map, WorldMapFrame
      if not MapOurs() or not m.octo then return end
      local was = ShownMap()
      _G.ToggleWorldMap = m.octo.toggle
      if UIPanelWindows then UIPanelWindows["WorldMapFrame"] = m.octo.panel end
      for sc, fn in pairs(m.octo.scripts) do f:SetScript(sc, fn) end
      f:SetMovable(true)
      f:EnableMouse(true)
      StripTextures(f)
      if f.backdrop then f.backdrop:Show() end
      if f.backdrop_shadow then f.backdrop_shadow:Show() end
      if BlackoutWorld then BlackoutWorld:Hide() end
      local pos = C.position["WorldMapFrame"] or {}
      f:SetScale(tonumber(pos.scale) or .7)
      f:SetAlpha(tonumber(pos.alpha) or 1)
      f:ClearAllPoints()
      f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
      if WorldMapButton then
        f:SetWidth(WorldMapButton:GetWidth() + 15)
        f:SetHeight(WorldMapButton:GetHeight() + 55)
      end
      if LoadMovable then LoadMovable(f) end
      for n in pairs(m.buttons) do
        local b = _G[n]
        for _, k in ipairs(BTEX) do b["Set" .. k .. "Texture"](b, "") end
        if b.backdrop then b.backdrop:Show() end
        if b.texture then b.texture:Show() end
        if b.SetFont then b:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE") end
      end
      local close = WorldMapFrameCloseButton
      if close then
        close:SetWidth(15)
        close:SetHeight(15)
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
      end
      for n in pairs(m.drops) do
        local dd, btn = _G[n], _G[n .. "Button"]
        StripTextures(dd)
        if dd.backdrop then dd.backdrop:Show() end
        if btn then
          for _, k in ipairs(BTEX) do btn["Set" .. k .. "Texture"](btn, nil) end
          if dd.backdrop then btn:ClearAllPoints() btn:SetAllPoints(dd.backdrop) end
          if btn.backdrop then btn.backdrop:Show() end
          if btn.icon then btn.icon:Show() end
        end
      end
      -- (map.lua moves the zone menu 8 px right)
      local zs = WorldMapZoneDropDown and BZ.snap[WorldMapZoneDropDown]
      local p = zs and zs.points[1]
      if p and p[1] then
        WorldMapZoneDropDown:ClearAllPoints()
        WorldMapZoneDropDown:SetPoint(p[1], p[2], p[3], (p[4] or 0) + 8, p[5] or 0)
      end
      Back(_G.pfWorldMapButtonCoords)
      if was then ShowUIPanel(f) end
    end,
  }

  -- which sections each topic of the options window has
  BZ.GROUPS = {
    ["Unit Frames"] = { "unitframes", "castbar", "raid" }, ["Action Bars"] = { "actionbars" }, ["Nameplates"] = { "nameplates" },
    ["Combat"] = { "combattext", "meters" }, ["Minimap & Buffs"] = { "minimap", "buffs", "worldmap" },
    ["Bags & Loot"] = { "bags", "loot" }, ["Chat & Panels"] = { "chat", "panels" }, ["Tooltip"] = { "tooltip" },
  }

  -- ---------------------------------------------------------------- Blizzard UI, movable
  -- (1 Nov 2026, user: "a hard switch that moves everything to blizzard unlocked to
  -- move and make how you want with all the pfUI functionability"). While a part is
  -- Blizzard's, its game frames are layout mode boxes like pfUI's own (positions in
  -- C.position, so per UI layout too), and the game's own placing of them
  -- (UIPARENT_MANAGED_FRAME_POSITIONS) leaves them alone.
  BZ.FRAMES = {
    unitframes = { "PlayerFrame", "TargetFrame", "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4" },
    castbar = { "CastingBarFrame" },
    actionbars = { "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
                   "PetActionBarFrame", "ShapeshiftBarFrame" },
    minimap = { "MinimapCluster" },
    buffs = { "BuffFrame", "TemporaryEnchantFrame" },
  }
  BZ.managed = {}
  function BZ.Movers(id, on)
    local list = BZ.FRAMES[id]
    if not list or not pfUI.api or not pfUI.api.UpdateMovable then return end
    local managed = _G.UIPARENT_MANAGED_FRAME_POSITIONS
    for _, name in ipairs(list) do
      local f = _G[name]
      if f then
        if on then
          if managed and managed[name] and BZ.managed[name] == nil then
            BZ.managed[name] = managed[name]
            managed[name] = nil
          end
          f:SetMovable(true)
          pcall(pfUI.api.UpdateMovable, f)
        else
          if managed and BZ.managed[name] then managed[name] = BZ.managed[name] BZ.managed[name] = nil end
          if pfUI.api.RemoveMovable then pfUI.api.RemoveMovable(f) end
        end
      end
    end
  end

  -- ---------------------------------------------------------------- switching

  function BZ.IsBlizz(id) return C.blizz[id] == "1" end

  -- id's look: "blizz" (Blizzard's) or "octo" (pfUI Octo's)
  function BZ.Set(id, which)
    local s = S[id]
    if not s then return end
    if InCombatLockdown and InCombatLockdown() then return end
    C.blizz[id] = (which == "blizz") and "1" or "0"
    local ok, err = pcall(s[which == "blizz" and "blizz" or "octo"])
    BZ.state[id] = which
    if ok then BZ.Movers(id, which == "blizz") end
    if not ok then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: " .. s.label .. ": " .. tostring(err))
      -- a switch to Blizzard's that went wrong is undone at once
      if which == "blizz" then
        C.blizz[id] = "0"
        pcall(s.octo)
        BZ.state[id] = "octo"
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: " .. s.label .. " stays pfUI Octo's.")
      end
    end
    return ok
  end
  function BZ.Toggle(id) return BZ.Set(id, BZ.IsBlizz(id) and "octo" or "blizz") end

  -- every section back to pfUI Octo's (Esc menu button, /octoundo)
  function BZ.AllOcto()
    for id in pairs(S) do
      if BZ.IsBlizz(id) or BZ.state[id] == "blizz" then BZ.Set(id, "octo") end
    end
    if BZ.confirm then BZ.confirm.id = nil BZ.confirm:Hide() end
  end
  -- every section Blizzard's (the Blizzard UI page's hard switch); the parts pfUI
  -- Octo adds on top (meters, combat text, gear...) stay
  BZ.ORDER = { "unitframes", "castbar", "raid", "actionbars", "minimap", "buffs", "worldmap", "nameplates",
               "bags", "loot", "chat", "tooltip", "panels" }
  function BZ.AllBlizz()
    for _, id in ipairs(BZ.ORDER) do
      if S[id] and not BZ.IsBlizz(id) then BZ.Set(id, "blizz") end
    end
  end
  function BZ.AllIsBlizz()
    for _, id in ipairs(BZ.ORDER) do if S[id] and not BZ.IsBlizz(id) then return false end end
    return true
  end

  -- Keep it or not: a switch to Blizzard's from the options window goes back
  -- by itself unless kept within 15 seconds (user, 23 Oct 2026: the panels
  -- switch took the chat away and there was no way back). Own frame on top
  -- of everything, never inside anything a switch hides.
  local confirm = CreateFrame("Frame", "pfOctoBlizzConfirm", UIParent)
  confirm:SetFrameStrata("FULLSCREEN_DIALOG")
  confirm:SetWidth(380)
  confirm:SetHeight(92)
  confirm:SetPoint("TOP", UIParent, "TOP", 0, -120)
  confirm:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  confirm:SetBackdropColor(.06, .06, .08, .96)
  confirm:SetBackdropBorderColor(.2, .55, .9, 1)
  confirm:EnableMouse(true)
  confirm:Hide()
  confirm.text = confirm:CreateFontString(nil, "OVERLAY", "GameFontWhite")
  confirm.text:SetPoint("TOP", confirm, "TOP", 0, -12)
  confirm.text:SetWidth(350)
  local function CButton(label, x, fn)
    local b = CreateFrame("Button", nil, confirm, "UIPanelButtonTemplate")
    b:SetWidth(150)
    b:SetHeight(24)
    b:SetPoint("BOTTOM", confirm, "BOTTOM", x, 12)
    b:SetText(label)
    b:SetScript("OnClick", fn)
    return b
  end
  confirm.keep = CButton("Keep Blizzard's", -80, function() confirm.id = nil confirm:Hide() end)
  confirm.undo = CButton("Go back now", 80, function()
    local id = confirm.id
    confirm.id = nil
    confirm:Hide()
    if id == "*" then BZ.AllOcto() elseif id then BZ.Set(id, "octo") end
    local O = pfUI.octoui and pfUI.octoui.Options
    if O and O.PaintSwap then O:PaintSwap() end
  end)
  confirm:SetScript("OnUpdate", function()
    if not this.id then this:Hide() return end
    local left = math.ceil((this.untilT or 0) - GetTime())
    local s = S[this.id] or (this.id == "*" and { label = "whole UI" })
    this.text:SetText("Blizzard's " .. string.lower(s and s.label or "") .. " is on.\nKeep it? Going back to pfUI Octo's in |cffffd100"
      .. math.max(0, left) .. "|r s.")
    if left <= 0 then
      local id = this.id
      this.id = nil
      this:Hide()
      if id == "*" then BZ.AllOcto() else BZ.Set(id, "octo") end
      local O = pfUI.octoui and pfUI.octoui.Options
      if O and O.PaintSwap then O:PaintSwap() end
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: not kept - " .. (s and s.label or id) .. " is pfUI Octo's again.")
    end
  end)
  BZ.confirm = confirm
  -- a switch from the options window: Blizzard's asks to be kept
  function BZ.Pick(id, which)
    local ok = BZ.Set(id, which)
    if which == "blizz" and ok and BZ.IsBlizz(id) then
      confirm.id = id
      confirm.untilT = GetTime() + 15
      confirm:Show()
    elseif confirm.id == id then
      confirm.id = nil
      confirm:Hide()
    end
    return ok
  end

  -- the hard switch: every part Blizzard's, asked to be kept like one part
  function BZ.PickAll(on)
    if not on then BZ.AllOcto() return end
    BZ.AllBlizz()
    confirm.id = "*"
    confirm.untilT = GetTime() + 15
    confirm:Show()
  end

  -- the way back that needs no chat: a button in the Esc menu, and /octoundo
  if GameMenuFrame then
    local esc = CreateFrame("Button", "GameMenuButtonOctoUndo", GameMenuFrame, "GameMenuButtonTemplate")
    esc:SetText("pfUI Octo: undo Blizzard")
    esc:SetPoint("TOP", GameMenuFrame, "BOTTOM", 0, -4)
    esc:SetScript("OnClick", function()
      HideUIPanel(GameMenuFrame)
      BZ.AllOcto()
    end)
    GameMenuFrame:SetScript("OnShow", (function(orig)
      return function()
        if orig then orig() end
        local any
        for id in pairs(S) do if BZ.IsBlizz(id) then any = true end end
        if any then esc:Show() else esc:Hide() end
      end
    end)(GameMenuFrame:GetScript("OnShow")))
    BZ.escButton = esc
  end
  _G.SLASH_OCTOUNDO1 = "/octoundo"
  _G.SlashCmdList.OCTOUNDO = function() BZ.AllOcto() end

  -- after every module ran: pfUI's functions noted, saved choices applied
  function BZ.Ready()
    if BZ.ready then return end
    BZ.ready = true
    for _, list in pairs(GLOBALS) do
      for _, n in ipairs(list) do BZ.globals[n].octo = _G[n] end
    end
    WrapPlates()
    -- pfUI's own setup of what it changed in place (chat tabs, the
    -- tooltip's health bar), to put back after Blizzard's
    BZ.chatOcto = {}
    for i in pairs(BZ.chat) do
      local tab, flash = _G["ChatFrame" .. i .. "Tab"], _G["ChatFrame" .. i .. "TabFlash"]
      BZ.chatOcto[i] = { tabAlpha = rawget(tab, "SetAlpha"), flashShow = flash and rawget(flash, "Show") }
    end
    if GameTooltipStatusBar then
      Snap(GameTooltipStatusBar, BZ.osnap)
      BZ.tipBarOcto = GameTooltipStatusBar.GetStatusBarTexture and Tex(GameTooltipStatusBar:GetStatusBarTexture())
    end
  end
  local boot = CreateFrame("Frame")
  boot:RegisterEvent("PLAYER_ENTERING_WORLD")
  boot:SetScript("OnEvent", function()
    BZ.Ready()
    -- (once the game and pfUI have set everything up for this screen)
    this.wait = GetTime() + .5
    this:SetScript("OnUpdate", function()
      if GetTime() < this.wait then return end
      this:SetScript("OnUpdate", nil)
      for id in pairs(S) do
        if BZ.IsBlizz(id) and BZ.state[id] ~= "blizz" then BZ.Set(id, "blizz") end
      end
    end)
  end)
end)
