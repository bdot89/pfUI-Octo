pfUI:RegisterModule("raid", "vanilla:tbc", function ()
  -- do not go further on disabled UFs
  if C.unitframes.disable == "1" then return end

  pfUI.uf.raid = CreateFrame("Frame", "pfRaidUpdater", UIParent)

  local maxraid = tonumber(C.unitframes.maxraid)
  local rawborder, default_border = GetBorderSize("chat")
  local cluster = CreateFrame("Frame", "pfRaidCluster", UIParent)
  cluster:SetFrameLevel(20)
  cluster:SetWidth(120)
  cluster:SetHeight(10)
  cluster:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", default_border*2, C.chat.left.height + default_border*5)
  UpdateMovable(cluster)

  pfUI.uf.raid.tanksfirst = {
    ["PF_TANK_TOGGLE"] = { T["Toggle as Tank"], "toggleTank" }
  }

  -- no tank order for now, just "all tanks first"
  pfUI.uf.raid.tankrole = { }

  function pfUI.uf.raid:UpdateConfig()
    local rawborder, default_border = GetBorderSize("unitframes")
    maxraid = tonumber(C.unitframes.maxraid)

    for i=1,maxraid do
      pfUI.uf.raid[i] = pfUI.uf.raid[i] or pfUI.uf:CreateUnitFrame("Raid", i, C.unitframes.raid)
      pfUI.uf.raid[i]:SetParent(cluster)
      pfUI.uf.raid[i]:SetFrameLevel(5)

      pfUI.uf.raid[i]:UpdateConfig()
      pfUI.uf.raid[i]:UpdateFrameSize()
    end

    local i = 1
    local width = pfUI.uf.raid[1]:GetWidth()+2*default_border
    local height = pfUI.uf.raid[1]:GetHeight()+2*default_border
    local layout = pfUI.uf.raid[1].config.raidlayout
    local padding = tonumber(pfUI.uf.raid[1].config.raidpadding)*GetPerfectPixel()
    local fill = pfUI.uf.raid[1].config.raidfill
    local _, _, x, y = string.find(layout,"(.+)x(.+)")
    x, y = tonumber(x), tonumber(y)

    -- octo: the raid frames sit in a grid inside pfRaidCluster, which is the
    -- one box layout mode shows for them (user, 20 Oct 2026: "the raid frame
    -- is one big window not lots of multiple ones"). Frames moved one by one
    -- before go back into the grid.
    -- (25 Oct 2026) growth: o_growy UP (first row at the bottom, pfUI's way)
    -- or DOWN, o_growx RIGHT or LEFT (first column on the right)
    local cfg = pfUI.uf.raid[1].config
    local down, left = cfg.o_growy == "DOWN", cfg.o_growx == "LEFT"
    local corner = (down and "TOP" or "BOTTOM") .. (left and "RIGHT" or "LEFT")
    local sx, sy = left and -1 or 1, down and -1 or 1
    local function Put(f, r, g)
      f:ClearAllPoints()
      f:SetPoint(corner, cluster, corner, sx*(r-1)*(padding+width), sy*(g-1)*(padding+height))
      RemoveMovable(f)
    end
    if fill == "VERTICAL" then
      for r=1, x do for g=1, y do
        if pfUI.uf.raid[i] then Put(pfUI.uf.raid[i], r, g) end
        i = i + 1
      end end
    else
      for g=1, y do for r=1, x do
        if pfUI.uf.raid[i] then Put(pfUI.uf.raid[i], r, g) end
        i = i + 1
      end end
    end
    cluster:SetWidth(math.max(10, x * (padding + width) - padding))
    cluster:SetHeight(math.max(10, y * (padding + height) - padding))
  end

  pfUI.uf.raid:UpdateConfig()

  local function SetRaidIndex(frame, id)
    frame.id = id
    frame.label = "raid"
    frame:UpdateVisibility()
  end

  -- add units to the beginning of their groups
  function pfUI.uf.raid:AddUnitToGroup(index, group)
    for subindex = 1, 5 do
      local ids = subindex + 5*(group-1)
      if pfUI.uf.raid[ids] and pfUI.uf.raid[ids].id == 0 and pfUI.uf.raid[ids].config.visible == "1" then
        SetRaidIndex(pfUI.uf.raid[ids], index)
        return
      end
    end
  end

  pfUI.uf.raid:Hide()
  pfUI.uf.raid:RegisterEvent("RAID_ROSTER_UPDATE")
  pfUI.uf.raid:RegisterEvent("VARIABLES_LOADED")
  pfUI.uf.raid:SetScript("OnEvent", function() this:Show() end)
  pfUI.uf.raid:SetScript("OnUpdate", function()
    -- don't proceed without raid or during combat
    -- (octo, 22 Nov 2026: out of a raid it went to sleep only after a sort, so it asked UnitInRaid every frame from the
    -- first roster change on; roster events show it again)
    if not UnitInRaid("player") then this:Hide() return end
    if InCombatLockdown and InCombatLockdown() then return end

    -- clear all existing frames
    for i=1, maxraid do SetRaidIndex(pfUI.uf.raid[i], 0) end

    -- sort tanks into their groups
    for i=1, GetNumRaidMembers() do
      local name, _, subgroup  = GetRaidRosterInfo(i)
      if name and pfUI.uf.raid.tankrole[name] then
        pfUI.uf.raid:AddUnitToGroup(i, subgroup)
      end
    end

    -- sort players into roster
    for i=1, GetNumRaidMembers() do
      local name, _, subgroup  = GetRaidRosterInfo(i)
      if name and not pfUI.uf.raid.tankrole[name] then
        pfUI.uf.raid:AddUnitToGroup(i, subgroup)
      end
    end

    this:Hide()
  end)

  -- raid popup option to toggle tank role
  for _, menu in pairs({"RAID", "PARTY"}) do
    for label, data in pairs(pfUI.uf.raid.tanksfirst) do
      UnitPopupButtons[label] = { text = TEXT(data[1]), dist = 0 }
      table.insert(UnitPopupMenus[menu], 3, label)
    end
  end

  hooksecurefunc("UnitPopup_OnClick", function()
    local dropdownFrame = _G[UIDROPDOWNMENU_INIT_MENU]
    local button = this.value
    local unit = dropdownFrame.unit
    local name = dropdownFrame.name

    if button and pfUI.uf.raid.tanksfirst[button] and name then
      pfUI.uf.raid.tankrole[name] = not pfUI.uf.raid.tankrole[name]
      pfUI.uf.raid:Show()
    end
  end)
end)
