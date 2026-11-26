pfUI:RegisterModule("addonbuttons", "vanilla:tbc", function ()
  if not pfUI.minimap then return end
  if C.abuttons.enable == "0" then return end

  local rawborder, default_border = GetBorderSize("panels")

  pfUI_cache["abuttons"] = pfUI_cache["abuttons"] or {}
  pfUI_cache["abuttons"]["add"] = pfUI_cache["abuttons"]["add"] or {}
  pfUI_cache["abuttons"]["del"] = pfUI_cache["abuttons"]["del"] or {}

  local ignored_icons = {
    "Note",
    "JQuest",
    "Naut_",
    "MinimapIcon",
    "GatherMatePin",
    "WestPointer",
    "Chinchilla_",
    "SmartMinimapZoom",
    "QuestieNote",
    "smm",
    "pfMiniMapPin",
    "MiniMapBattlefieldFrame",
    "pfMinimapButton",
    "GatherNote",
    "MiniNotePOI",
    "FWGMinimapPOI",
    "RecipeRadarMinimapIcon",
    "MiniMapTracking",
    "CartographerNotesPOI"
  }

  pfUI.addonbuttons = CreateFrame("Frame", "pfMinimapButtons", UIParent)
  pfUI.addonbuttons:SetFrameStrata("HIGH")
  CreateBackdrop(pfUI.addonbuttons)
  CreateBackdropShadow(pfUI.addonbuttons)

  pfUI.addonbuttons.minimapbutton = CreateFrame("Button", "pfMinimapButton", pfUI.minimap or UIParent)
  pfUI.addonbuttons.minimapbutton:SetFrameLevel(24)
  pfUI.addonbuttons.minimapbutton:SetWidth(12)
  pfUI.addonbuttons.minimapbutton:SetHeight(12)

  pfUI.addonbuttons.minimapbutton:SetScript("OnClick", function()
    if pfUI.addonbuttons:IsShown() then
      pfUI.addonbuttons:Hide()
    else
      pfUI.addonbuttons:Show()
    end
  end)

  pfUI.addonbuttons.buttons = {}
  pfUI.addonbuttons.overrides = {}
  pfUI.addonbuttons.last_updated = 0
  pfUI.addonbuttons.rows = 1
  pfUI.addonbuttons.max_button_size = 40

  -- octo (25 Oct 2026, user: "the resizer hardly changes the buttons"): a
  -- size of its own in px (0 = fit the map's width, as pfUI did)
  local function Fixed() return tonumber(C.abuttons.size or "") or 0 end

  local function GetButtonSize()
    if Fixed() > 0 then return Fixed() end
    if C.abuttons.position == "bottom" or C.abuttons.position == "top" then
      return (pfUI.minimap:GetWidth() - (tonumber(C.abuttons.spacing) * (tonumber(C.abuttons.rowsize) + 1))) / tonumber(C.abuttons.rowsize)
    else
      return (pfUI.minimap:GetHeight() - (tonumber(C.abuttons.spacing) * (tonumber(C.abuttons.rowsize) + 1))) / tonumber(C.abuttons.rowsize)
    end
  end

  local function GetNumButtons()
    local total_buttons = 0
    for i, v in ipairs(pfUI.addonbuttons.buttons) do
      total_buttons = total_buttons + 1
    end
    return total_buttons
  end

  local function GetStringSize()
    return (GetButtonSize() + tonumber(C.abuttons.spacing))
  end

  local function TableMatch(table, needle)
    for i,v in ipairs(table) do
      if (strlower(v) == strlower(needle)) then
        return i
      end
    end
    return false
  end

  local function TablePartialMatch(table, needle)
    for i,v in ipairs(table) do
      local pos_start, pos_end = strfind(strlower(needle), strlower(v))
      if pos_start == 1 then
        return i
      end
    end
    return false
  end

  local function IsButtonValid(frame)
    -- ignore invalid and invisible frames
    if not frame:GetName() then return false end
    if not frame:IsVisible() then return false end

    -- ignore frames with invalid sizes
    if frame:GetHeight() > pfUI.addonbuttons.max_button_size then return false end
    if frame:GetWidth() > pfUI.addonbuttons.max_button_size then return false end

    -- ignore other frame types
    if not frame:IsFrameType("Button") and not frame:IsFrameType("Frame") then return false end

    -- ignore manually selected frames
    if TablePartialMatch(ignored_icons, frame:GetName()) then return false end
    -- (26 Nov 2026) a button of pfUI's own that asks to stay on the map's edge (OctoLoot's, by its setting)
    if frame.pfNoCollect then return false end

    -- check button/frame script handlers
    if frame:IsFrameType("Button") then
      if frame:GetScript("OnClick") or frame:GetScript("OnMouseDown") or frame:GetScript("OnMouseUp") then
        return true
      end
    elseif frame:IsFrameType("Frame") and (strfind(strlower(frame:GetName()), "icon") or strfind(strlower(frame:GetName()), "button")) then
      if frame:GetScript("OnMouseDown") or frame:GetScript("OnMouseUp") then
        return true
      end
    end

    -- ignore everything else
    return false
  end

  local function FindButtons(frame)
    for i, frame_child in ipairs({frame:GetChildren()}) do
      -- check first level children
      if IsButtonValid(frame_child) and not TableMatch(pfUI.addonbuttons.buttons, frame_child:GetName()) then
        table.insert(pfUI.addonbuttons.buttons, frame_child:GetName())
      else
        if frame_child:GetNumChildren() > 0 then
          for j, child_child in ipairs({frame_child:GetChildren()}) do
            if IsButtonValid(child_child) and not TableMatch(pfUI.addonbuttons.buttons, child_child:GetName()) then
              table.insert(pfUI.addonbuttons.buttons, child_child:GetName())
            end
          end
        end
      end
    end
  end

  local function GetScale()
    local sum_size, buttons_count, calculated_scale
    sum_size = 0
    buttons_count = GetNumButtons()
    for i, button_name in ipairs(pfUI.addonbuttons.buttons) do
      if _G[button_name] ~= nil then
        sum_size = sum_size + _G[button_name]:GetHeight()
      end
    end
    calculated_scale = GetButtonSize() / (sum_size / buttons_count)
    if Fixed() > 0 then return calculated_scale end
    return calculated_scale > 1 and 1 or calculated_scale
  end

  -- (23 Oct 2026: a scan for buttons only anchored to the map, made on
  -- UIParent / MinimapCluster, crashed the client at login when it walked
  -- UIParent; the user found the button by hand, so it is gone - such a
  -- button is added with /abp add)
  local function ScanForButtons()
    FindButtons(Minimap)
    FindButtons(MinimapBackdrop)
  end

  -- the panel's long side: the map's, or as long as a row of fixed-size buttons
  local function Long(side)
    if Fixed() > 0 then return tonumber(C.abuttons.rowsize) * GetStringSize() + tonumber(C.abuttons.spacing) end
    return side
  end

  -- what the panel hangs under: the bar under the map when it is in its own
  -- place there (it used to cover the first row and take its clicks)
  local function Below()
    local bar = pfUI.panel and pfUI.panel.minimap
    local S = C.mapstyle
    if bar and bar:IsShown() and not (S and tonumber(S.barx or "")) then return bar end
    return pfUI.minimap
  end

  local function SetupMainFrame()
    pfUI.addonbuttons:ClearAllPoints()
    pfUI.addonbuttons:SetScale(pfUI.minimap:GetScale())

    pfUI.addonbuttons.minimapbutton:ClearAllPoints()
    if C.abuttons.position == "bottom" then
      pfUI.addonbuttons:SetWidth(Long(pfUI.minimap:GetWidth()))
      pfUI.addonbuttons:SetHeight(ceil((GetNumButtons() > 0 and GetNumButtons() or 1) / tonumber(C.abuttons.rowsize)) * GetStringSize() + tonumber(C.abuttons.spacing))
      pfUI.addonbuttons:SetPoint("TOP", Below(), "BOTTOM", 0 , -default_border * 3)
      SkinArrowButton(pfUI.addonbuttons.minimapbutton, "down")
      pfUI.addonbuttons.minimapbutton:SetPoint("BOTTOM", pfUI.minimap, "BOTTOM", 0, 4)
    elseif C.abuttons.position == "left" then
      pfUI.addonbuttons:SetWidth(ceil((GetNumButtons() > 0 and GetNumButtons() or 1) / tonumber(C.abuttons.rowsize)) * GetStringSize() + tonumber(C.abuttons.spacing))
      pfUI.addonbuttons:SetHeight(Long(pfUI.minimap:GetHeight()))
      pfUI.addonbuttons:SetPoint("TOPRIGHT", pfUI.minimap, "TOPLEFT", -default_border * 3, 0)
      SkinArrowButton(pfUI.addonbuttons.minimapbutton, "left")
      pfUI.addonbuttons.minimapbutton:SetPoint("LEFT", pfUI.minimap, "LEFT", 4, 0)
    elseif C.abuttons.position == "top" then
      pfUI.addonbuttons:SetWidth(Long(pfUI.minimap:GetWidth()))
      pfUI.addonbuttons:SetHeight(ceil((GetNumButtons() > 0 and GetNumButtons() or 1) / tonumber(C.abuttons.rowsize)) * GetStringSize() + tonumber(C.abuttons.spacing))
      pfUI.addonbuttons:SetPoint("BOTTOM", pfUI.minimap, "TOP", 0 , default_border * 3)
      SkinArrowButton(pfUI.addonbuttons.minimapbutton, "up")
      pfUI.addonbuttons.minimapbutton:SetPoint("TOP", pfUI.minimap, "TOP", 0, -4)
    elseif C.abuttons.position == "right" then
      pfUI.addonbuttons:SetWidth(ceil((GetNumButtons() > 0 and GetNumButtons() or 1) / tonumber(C.abuttons.rowsize)) * GetStringSize() + tonumber(C.abuttons.spacing))
      pfUI.addonbuttons:SetHeight(Long(pfUI.minimap:GetHeight()))
      pfUI.addonbuttons:SetPoint("TOPLEFT", pfUI.minimap, "TOPRIGHT", default_border * 3, 0)
      SkinArrowButton(pfUI.addonbuttons.minimapbutton, "right")
      pfUI.addonbuttons.minimapbutton:SetPoint("RIGHT", pfUI.minimap, "RIGHT", -4, 0)
    end
  end

  local function UpdatePanel()
    ScanForButtons()
    for i, button_name in ipairs(pfUI_cache["abuttons"]["add"]) do
      if not TableMatch(pfUI.addonbuttons.buttons, button_name) then
        if _G[button_name] ~= nil then
          table.insert(pfUI.addonbuttons.buttons, button_name)
        end
      end
    end
    for i, button_name in ipairs(pfUI_cache["abuttons"]["del"]) do
      if TableMatch(pfUI.addonbuttons.buttons, button_name) then
        table.remove(pfUI.addonbuttons.buttons, TableMatch(pfUI.addonbuttons.buttons, button_name))
      end
    end
    for i, button_name in ipairs(pfUI.addonbuttons.buttons) do
      if _G[button_name] == nil then
        table.remove(pfUI.addonbuttons.buttons, TableMatch(pfUI.addonbuttons.buttons, button_name))
      end
    end
    SetupMainFrame()
  end

  local parent
  local function GetTopFrame(frame)
    parent = frame:GetParent()
    if not parent or not parent.GetParent or parent == Minimap or parent == MinimapBackdrop or parent == UIParent then
      return frame
    else
      return GetTopFrame(parent)
    end
  end

  local function BackupButton(frame)
    if not frame then return end
    if frame.backup == nil then
      frame.backup = {}
      frame.backup.top_frame_name = GetTopFrame(frame):GetName()
      frame.backup.parent_name = GetTopFrame(frame):GetParent():GetName()
      -- (octo: the parent itself - a name is not taken by every client's SetParent)
      frame.backup.parent = GetTopFrame(frame):GetParent()
      frame.backup.is_clamped_to_screen = frame:IsClampedToScreen()
      frame.backup.is_movable = frame:IsMovable()
      frame.backup.point = {frame:GetPoint()}
      frame.backup.size = {frame:GetHeight(), frame:GetWidth()}
      frame.backup.scale = frame:GetScale()
      if frame:HasScript("OnDragStart") then
        frame.backup.on_drag_start = frame:GetScript("OnDragStart")
      end
      if frame:HasScript("OnDragStop") then
        frame.backup.on_drag_stop = frame:GetScript("OnDragStop")
      end
      if frame:HasScript("OnUpdate") then
        frame.backup.on_update = frame:GetScript("OnUpdate")
      end
      -- TODO: find a way to avoid such hardcoding
      if frame:GetName() == "MetaMapButton" then
        frame.backup.MetaMapButton_UpdatePosition = MetaMapButton_UpdatePosition
        pfUI.addonbuttons.overrides.MetaMapButton_UpdatePosition = function () return end
      end
    end
  end

  local function RestoreButton(frame)
    if frame.backup ~= nil then
      local top = _G[frame.backup.top_frame_name or ""] or frame
      local parent = frame.backup.parent or _G[frame.backup.parent_name or ""] or Minimap
      top:SetParent(parent)
      frame:SetClampedToScreen(frame.backup.is_clamped_to_screen)
      frame:SetMovable(frame.backup.is_movable)
      frame:SetScale(frame.backup.scale)
      frame:SetHeight(frame.backup.size[1])
      frame:SetWidth(frame.backup.size[2])
      frame:ClearAllPoints()
      frame:SetPoint(frame.backup.point[1], frame.backup.point[2], frame.backup.point[3], frame.backup.point[4], frame.backup.point[5])
      if frame.backup.on_drag_start ~= nil then
        frame:SetScript("OnDragStart", frame.backup.on_drag_start)
      end
      if frame.backup.on_drag_stop ~= nil then
        frame:SetScript("OnDragStop", frame.backup.on_drag_stop)
      end
      if frame.backup.on_update ~= nil then
        frame:SetScript("OnUpdate", frame.backup.on_update)
      end
      if frame.backup.MetaMapButton_UpdatePosition ~= nil then
        pfUI.addonbuttons.overrides.MetaMapButton_UpdatePosition = frame.backup.MetaMapButton_UpdatePosition
      end
    end
  end

  local function MoveButton(index, frame)
    if not frame then return end
    local top_frame, row_index, offsetX, offsetY, final_scale
    top_frame = GetTopFrame(frame)
    final_scale = GetScale()
    -- (octo: a button with a size of its own)
    local own = pfUI.addonbuttons.GetSize and pfUI.addonbuttons:GetSize(frame:GetName() or "") or 0
    if own > 0 then
      local h = (frame.backup and frame.backup.size and frame.backup.size[1]) or frame:GetHeight()
      if h and h > 0 then final_scale = own / h end
    end
    row_index = floor((index-1)/tonumber(C.abuttons.rowsize))
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(false)
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
    frame:SetScript("OnUpdate", nil)
    frame:SetClampedToScreen(true)
    frame:SetMovable(false)
    frame:ClearAllPoints()

    if top_frame ~= pfUI.addonbuttons then
      top_frame:SetScale(final_scale)
      top_frame:ClearAllPoints()
      top_frame:SetParent(pfUI.addonbuttons)
    end

    if C.abuttons.position == "bottom" or C.abuttons.position == "top" then
      offsetX = ((index - row_index * tonumber(C.abuttons.rowsize)) * (tonumber(C.abuttons.spacing))) + (((index - row_index * tonumber(C.abuttons.rowsize)) - 1) * GetButtonSize()) + (GetButtonSize() / 2)
      offsetY = -(((row_index + 1) * tonumber(C.abuttons.spacing)) + (row_index * GetButtonSize()) + (GetButtonSize() / 2))
      frame:SetPoint("CENTER", pfUI.addonbuttons, "TOPLEFT", offsetX/final_scale, offsetY/final_scale)
      if top_frame ~= pfUI.addonbuttons then
        top_frame:SetPoint("CENTER", pfUI.addonbuttons, "TOPLEFT", offsetX/final_scale, offsetY/final_scale)
      end
    else
      offsetX = -(((row_index + 1) * tonumber(C.abuttons.spacing)) + (row_index * GetButtonSize()) + (GetButtonSize() / 2))
      offsetY = -(((index - row_index * tonumber(C.abuttons.rowsize)) * (tonumber(C.abuttons.spacing))) + (((index - row_index * tonumber(C.abuttons.rowsize)) - 1) * GetButtonSize()) + (GetButtonSize() / 2))
      frame:SetPoint("CENTER", pfUI.addonbuttons, "TOPRIGHT", offsetX/final_scale, offsetY/final_scale)
      if top_frame ~= pfUI.addonbuttons then
        top_frame:SetPoint("CENTER", pfUI.addonbuttons, "TOPRIGHT", offsetX/final_scale, offsetY/final_scale)
      end
    end
  end

  local function ManualAddOrRemove(msg)
    local _, _, action, arg = string.find(msg, "%s?(%w+)%s?(.*)")

    local button
    if arg and arg ~= "" then
      button = _G[arg]
    else
      button = GetMouseFocus()
    end

    if action == "" or (action ~= "reset" and action ~= "add" and action ~= "del") then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|rUI Addon Button Panel:")
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/abp add|r - " .. T["Add button to the frame"])
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/abp del|r - " .. T["Remove button from the frame"])
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/abp reset|r - " .. T["Reset all manually added or ignored buttons"])
      return
    end

    if action == "reset" then
      for i, button_name in ipairs(pfUI_cache["abuttons"]["add"]) do
        if _G[button_name] ~= nil then
          if TableMatch(pfUI.addonbuttons.buttons, button_name) then
            table.remove(pfUI.addonbuttons.buttons, TableMatch(pfUI.addonbuttons.buttons, button_name))
          end
          RestoreButton(_G[button_name])
        end
      end
      pfUI_cache["abuttons"]["add"] = {}
      pfUI_cache["abuttons"]["del"] = {}
      pfUI.addonbuttons:ProcessButtons()
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|rUI ABP|r: " .. T["Lists of added and deleted buttons are cleared"])
      return
    else
      if IsButtonValid(button) then
        if action == "add" then
          if TableMatch(pfUI_cache["abuttons"]["del"], button:GetName()) then
            table.remove(pfUI_cache["abuttons"]["del"], TableMatch(pfUI_cache["abuttons"]["del"], button:GetName()))
          end
          if not TableMatch(pfUI.addonbuttons.buttons, button:GetName()) and not TableMatch(pfUI_cache["abuttons"]["add"], button:GetName()) then
            table.insert(pfUI_cache["abuttons"]["add"], button:GetName())
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|rUI ABP|r: " .. T["Added button"] .. ": " .. button:GetName())
          else
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|rUI ABP|r: " .. T["Button already exists in pfMinimapButtons frame"])
            return
          end
        elseif action == "del" then
          if TableMatch(pfUI_cache["abuttons"]["add"], button:GetName()) then
            table.remove(pfUI_cache["abuttons"]["add"], TableMatch(pfUI_cache["abuttons"]["add"], button:GetName()))
          end
          if TableMatch(pfUI.addonbuttons.buttons, button:GetName()) then
            table.remove(pfUI.addonbuttons.buttons, TableMatch(pfUI.addonbuttons.buttons, button:GetName()))
          else
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|rUI ABP|r: " .. T["Button not found in pfMinimapButtons frame"])
            return
          end
          if not TableMatch(pfUI_cache["abuttons"]["del"], button:GetName()) then
            table.insert(pfUI_cache["abuttons"]["del"], button:GetName())
            RestoreButton(button)
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|rUI ABP|r: " .. T["Removed button"] .. ": " .. button:GetName())
          end
        end
        pfUI.addonbuttons:ProcessButtons()
        return
      else
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|rUI ABP|r: " .. T["Not a valid button!"])
        return
      end
    end
  end

  -- octo (23 Oct 2026): each addon button's place, set from the Minimap
  -- options: "panel" (gathered), "map" (left on the minimap) or "hide"
  pfUI_cache["abuttons"]["hide"] = pfUI_cache["abuttons"]["hide"] or {}
  function pfUI.addonbuttons:GetPlace(name)
    if pfUI_cache["abuttons"]["hide"][name] then return "hide" end
    if TableMatch(pfUI_cache["abuttons"]["del"], name) then return "map" end
    return "panel"
  end

  function pfUI.addonbuttons:SetPlace(name, where)
    local add, del, hide = pfUI_cache["abuttons"]["add"], pfUI_cache["abuttons"]["del"], pfUI_cache["abuttons"]["hide"]
    local f = _G[name]
    local function Drop(t) local i = TableMatch(t, name) if i then table.remove(t, i) end end
    if where == "panel" then
      Drop(del)
      hide[name] = nil
      if not TableMatch(add, name) then table.insert(add, name) end
      if f then f:SetAlpha(1) if f.EnableMouse then f:EnableMouse(true) end end
    else
      Drop(add)
      if not TableMatch(del, name) then table.insert(del, name) end
      local i = TableMatch(self.buttons, name)
      if i then
        table.remove(self.buttons, i)
        -- (octo, 25 Oct 2026: an error here left the button half moved until a
        -- reload - "it should be instant"; the map place below sets it anyway)
        if f and where == "hide" then pcall(RestoreButton, f) end
      end
      hide[name] = (where == "hide") or nil
      if f then
        f:SetAlpha(where == "hide" and 0 or 1)
        if f.EnableMouse then f:EnableMouse(where ~= "hide") end
      end
    end
    self:ProcessButtons()
  end

  -- octo (25 Oct 2026, user: "they are not showing actually they should show
  -- on the top and be sizeable individually"): a button set to "On map" went
  -- back to its addon's own spot round Blizzard's old map, out of sight. They
  -- now sit in rows along the top of the map, each its own size; a size of
  -- its own counts in the panel too. pfUI_cache.abuttons.size[name] = px.
  pfUI_cache["abuttons"]["size"] = pfUI_cache["abuttons"]["size"] or {}
  function pfUI.addonbuttons:GetSize(name)
    return tonumber(pfUI_cache["abuttons"]["size"][name] or "") or 0
  end
  function pfUI.addonbuttons:SetSize(name, px)
    px = tonumber(px) or 0
    pfUI_cache["abuttons"]["size"][name] = px > 0 and px or nil
    self:ProcessButtons()
  end

  local function OnMap(frame, cx, cy, scale)
    -- (the button itself goes on the map: carrying its holder failed when the
    -- holder was hidden or was Blizzard's map cluster - user, 25 Oct 2026,
    -- MinimapShopFrame "not showing")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(false)
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
    frame:SetScript("OnUpdate", nil)
    frame:ClearAllPoints()
    local moved = frame:GetParent() ~= Minimap
    frame:SetParent(Minimap)
    frame:SetScale(scale)
    frame:SetPoint("CENTER", Minimap, "TOPLEFT", cx / scale, cy / scale)
    if frame.SetFrameLevel then frame:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 5) end
    -- (1.12: a frame moved out of a hidden parent - the shut panel - stays
    -- unseen though it and every parent say shown, until it is hidden and
    -- shown again; seen 25 Oct 2026: "on the map (not showing)" with every
    -- parent shown, fine after a reload)
    if moved or not frame:IsVisible() then
      frame:Hide()
      frame:Show()
    end
  end

  -- why a button does not show: its parents, each shown or not (for chat)
  function pfUI.addonbuttons:Chain(name)
    local f, out = _G[name], {}
    for _ = 1, 8 do
      if not f or not f.GetParent then break end
      table.insert(out, (f.GetName and f:GetName() or "?") .. (f:IsShown() and "" or " (hidden)") .. ((f.GetAlpha and f:GetAlpha() == 0) and " (alpha 0)" or ""))
      f = f:GetParent()
    end
    return table.concat(out, " < ")
  end

  function pfUI.addonbuttons:PlaceOnMap()
    local width = Minimap:GetWidth() or 140
    local base = tonumber(C.abuttons.size or "") or 0
    if base <= 0 then base = 20 end
    local x, y, rowh, gap = 3, -3, 0, 2
    for _, name in ipairs(pfUI_cache["abuttons"]["del"]) do
      local f = _G[name]
      if type(f) == "table" and f.GetParent and f.SetPoint and f.GetHeight and not pfUI_cache["abuttons"]["hide"][name] then
        BackupButton(f)
        local h = (f.backup and f.backup.size and f.backup.size[1]) or f:GetHeight()
        if not h or h <= 0 then h = 20 end
        local px = self:GetSize(name)
        if px <= 0 then px = base end
        if x + px > width - 3 and x > 3 then
          x, y, rowh = 3, y - rowh - gap, 0
        end
        pcall(OnMap, f, x + px / 2, y - px / 2, px / h)
        x = x + px + gap
        if px > rowh then rowh = px end
      end
    end
  end

  -- every addon button found: gathered ones and those left on the map
  function pfUI.addonbuttons:List()
    self:ProcessButtons()
    local out, seen = {}, {}
    for _, list in ipairs({ self.buttons, pfUI_cache["abuttons"]["del"] }) do
      for _, name in ipairs(list) do
        if _G[name] and not seen[name] then
          seen[name] = true
          table.insert(out, name)
        end
      end
    end
    table.sort(out)
    return out
  end

  -- Buttons an addon makes after login were only gathered once the panel
  -- was opened (user, 23 Oct 2026: "why is this button still there"): look
  -- again now and then while the panel is shut, and keep hidden ones hidden.
  local watch = CreateFrame("Frame", nil, UIParent)
  libclient.Every(watch, 3, function()
    this.count = (this.count or 0) + 1
    if not pfUI.addonbuttons:IsShown() and math.mod(this.count, 3) == 1 then
      pfUI.addonbuttons:ProcessButtons()
    end
    for name in pairs(pfUI_cache["abuttons"]["hide"]) do
      local f = _G[name]
      if f and f:GetAlpha() > 0 then
        f:SetAlpha(0)
        if f.EnableMouse then f:EnableMouse(false) end
      end
    end
  end)

  -- octo: Blizzard's minimap in use (octo-blizzard.lua): every button back
  -- round the map, and nothing gathered until pfUI's map is back
  function pfUI.addonbuttons:RestoreAll()
    for _, name in ipairs(self.buttons) do
      if _G[name] then RestoreButton(_G[name]) end
    end
    self.buttons = {}
    self:Hide()
  end

  function pfUI.addonbuttons:ProcessButtons()
    if pfUI.blizz and pfUI.blizz.IsBlizz and pfUI.blizz.IsBlizz("minimap") then return end
    UpdatePanel()

    local i = 1
    for _, button_name in ipairs(pfUI.addonbuttons.buttons) do
      if _G[button_name] and _G[button_name]:IsVisible() then
        BackupButton(_G[button_name])
        MoveButton(i, _G[button_name])
        i = i + 1
      end
    end
    pfUI.addonbuttons:PlaceOnMap()
  end

  function pfUI.addonbuttons:UpdateConfig()
    pfUI.addonbuttons:ProcessButtons()
  end

  pfUI.addonbuttons:SetScript("OnShow", function()
    pfUI.addonbuttons:ProcessButtons()
  end)

  pfUI.addonbuttons:SetScript("OnUpdate", function()
    -- check if the panel should be shown by default
    if not this.initialized then
      if C.abuttons.showdefault == "1" and GetNumButtons() > 0 then
        pfUI.addonbuttons:Show()
      else
        pfUI.addonbuttons:Hide()
      end

      -- update all buttons
      pfUI.addonbuttons:ProcessButtons()
      this.initialized = true
    end

    -- throttle updates to once per 5 seconds
    if ( this.tick or 1) > GetTime() then return else this.tick = GetTime() + 5 end

    -- reload/rescan minimap buttons
    pfUI.addonbuttons:ProcessButtons()

    -- re-apply addon button workarounds
    for k, v in pairs(pfUI.addonbuttons.overrides) do
      _G[k] = v
    end
  end)

  pfUI.addonbuttons:RegisterEvent("PLAYER_REGEN_DISABLED")
  pfUI.addonbuttons:SetScript("OnEvent", function()
    if C.abuttons.hideincombat == "1" and pfUI.addonbuttons:IsShown() then
      pfUI.addonbuttons:Hide()
    end
  end)

  pfUI.addonbuttons:UpdateConfig()

  _G.SLASH_PFABP1, _G.SLASH_PFABP2 = "/abp", "/pfabp"
  _G.SlashCmdList.PFABP = ManualAddOrRemove
end)
