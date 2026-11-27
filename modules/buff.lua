pfUI:RegisterModule("buff", "vanilla:tbc", function ()
  -- Hide Blizz
  BuffFrame:Hide()
  BuffFrame:UnregisterAllEvents()
  TemporaryEnchantFrame:Hide()
  TemporaryEnchantFrame:UnregisterAllEvents()

  local br, bg, bb, ba = GetStringColor(pfUI_config.appearance.border.color)

  local function RefreshBuffButton(buff)
    if buff.btype == "HELPFUL" then
      if C.buffs.separateweapons == "1" then
        buff.id = buff.gid - (buff.weapon ~= nill and buff.gid or 0)
      else
        buff.id = buff.gid - pfUI.buff.wepbuffs.count
      end
    else
      buff.id = buff.gid
    end
    -- (octo: a tracking ability's buff can be left out - pfUI.api.PlayerBuffIndex)
    -- (octo, 27 Nov 2026: consolidated buffs - long buffs go into one box, as in
    -- WotLK. The box takes the first buff place; the rest come from mainList.)
    local slot
    if buff.cons then
      slot = pfUI.buff.consList[buff.gid] or 33
    elseif buff.btype == "HELPFUL" and buff.id > 0 and pfUI.buff.consOn then
      if buff.id == 1 then
        buff.bid = -1
        buff.mode = nil
        buff:Hide()
        return
      end
      slot = pfUI.buff.mainList[buff.id - 1] or 33
    else
      slot = pfUI.api.PlayerBuffIndex(buff.id, buff.btype)
    end
    buff.bid = GetPlayerBuff(PLAYER_BUFF_START_ID + slot, buff.btype)

    if not buff.backdrop then
      CreateBackdrop(buff)
      CreateBackdropShadow(buff)
    end

    --detect weapon buffs
    if buff.btype == "HELPFUL" and not buff.cons and ((C.buffs.separateweapons == "0" and buff.gid <= pfUI.buff.wepbuffs.count) or (pfUI.buff.wepbuffs.count > 0 and buff.weapon ~= nil)) then
        local mh, mhtime, mhcharge, oh, ohtime, ohcharge = GetWeaponEnchantInfo()
        if pfUI.buff.wepbuffs.count == 2 then
          if buff.gid == 1 then
            buff.mode = "MAINHAND"
          else
            buff.mode = "OFFHAND"
          end
        else
          if C.buffs.separateweapons == "0" then
            buff.mode = mh and "MAINHAND" or oh and "OFFHAND"
          else
            if buff.gid == 1 then
              buff.mode = mh and "MAINHAND" or oh and "OFFHAND"
            else
              buff:Hide()
              return
            end
          end
        end

      -- Set Weapon Texture and Border
      if buff.mode == "MAINHAND" then
        buff.texture:SetTexture(GetInventoryItemTexture("player", 16))
        buff.backdrop:SetBackdropBorderColor(GetItemQualityColor(GetInventoryItemQuality("player", 16) or 1))
      elseif buff.mode == "OFFHAND" then
        buff.texture:SetTexture(GetInventoryItemTexture("player", 17))
        buff.backdrop:SetBackdropBorderColor(GetItemQualityColor(GetInventoryItemQuality("player", 17) or 1))
      end
    elseif GetPlayerBuffTexture(buff.bid) and (( buff.btype == "HARMFUL" and C.buffs.debuffs == "1" ) or ( buff.btype == "HELPFUL" and C.buffs.buffs == "1" )) then
      -- Set Buff Texture and Border
      buff.mode = buff.btype
      buff.texture:SetTexture(GetPlayerBuffTexture(buff.bid))

      if buff.btype == "HARMFUL" then
        local dtype = GetPlayerBuffDispelType(buff.bid)
        if dtype == "Magic" then
          buff.backdrop:SetBackdropBorderColor(0,1,1,1)
        elseif dtype == "Poison" then
          buff.backdrop:SetBackdropBorderColor(0,1,0,1)
        elseif dtype == "Curse" then
          buff.backdrop:SetBackdropBorderColor(1,0,1,1)
        elseif dtype == "Disease" then
          buff.backdrop:SetBackdropBorderColor(1,1,0,1)
        else
          buff.backdrop:SetBackdropBorderColor(1,0,0,1)
        end
      else
        buff.backdrop:SetBackdropBorderColor(br,bg,bb,ba)
      end
    else
      buff:Hide()
      return
    end

    buff:Show()
  end

  local function CreateBuffButton(i, btype, weapon, cons)
    local buttonName, buttonParent
    if cons then
      buttonName = "pfConsBuffFrameBuff" .. i
      buttonParent = pfUI.buff.cons
    elseif btype == "HELPFUL" then
      if weapon == 1 then
        buttonName = "pfWepBuffFrame" .. i
        buttonParent = pfUI.buff.wepbuffs
      else
        buttonName = "pfBuffFrameBuff" .. i
        buttonParent = pfUI.buff.buffs
      end
    else
      buttonName = "pfDebuffFrameBuff" .. i
      buttonParent = pfUI.buff.debuffs
    end
    local buff = CreateFrame("Button", buttonName, buttonParent)
    buff.texture = buff:CreateTexture("BuffIcon" .. i, "BACKGROUND")
    buff.texture:SetTexCoord(.07,.93,.07,.93)
    buff.texture:SetAllPoints(buff)

    -- octo (28 Oct 2026; brues-code's fork): a cooldown sweep over the icon as the
    -- buff runs out. The texts sit on a frame above it (a child frame draws over
    -- every region of its parent, so they would dim under the dark wedge)
    buff.cd = CreateFrame(COOLDOWN_FRAME_TYPE or "Model", buttonName .. "Cooldown", buff, "CooldownFrameTemplate")
    buff.cd:SetFrameLevel(buff:GetFrameLevel() + 1)
    buff.cd.pfCooldownType = "ALL"
    buff.cd.pfCooldownStyleText = 0
    buff.overlay = CreateFrame("Frame", nil, buff)
    buff.overlay:SetAllPoints(buff)
    buff.overlay:SetFrameLevel(buff:GetFrameLevel() + 2)

    buff.timer = buff.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buff.timer:SetTextColor(1,1,1,1)
    buff.timer:SetJustifyH("CENTER")
    buff.timer:SetJustifyV("CENTER")

    buff.stacks = buff.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buff.stacks:SetTextColor(1,1,1,1)
    buff.stacks:SetJustifyH("RIGHT")
    buff.stacks:SetJustifyV("BOTTOM")
    buff.stacks:SetAllPoints(buff)

    buff:RegisterForClicks("RightButtonUp")

    buff.weapon = weapon
    buff.btype = btype
    buff.gid = i
    buff.cons = cons

    buff:SetScript("OnUpdate", function()
      if not this.next then this.next = GetTime() + .1 end
      if this.next > GetTime() then return end
      this.next = GetTime() + .1

      local timeleft = 0
      local stacks = 0

      if this.mode == this.btype then
        timeleft = GetPlayerBuffTimeLeft(this.bid, this.btype)
        stacks = GetPlayerBuffApplications(this.bid, this.btype)
      elseif this.mode == "MAINHAND" then
        local _, mhtime, mhcharge = GetWeaponEnchantInfo()
        timeleft = mhtime/1000
        stacks = mhcharge
      elseif this.mode == "OFFHAND" then
        local _, _, _, _, ohtime, ohcharge = GetWeaponEnchantInfo()
        timeleft = ohtime/1000
        stacks = ohcharge
      end

      -- (octo, 22 Nov 2026: the texts only when they change - this runs 10 times a second for every buff)
      pfUI.api.SetTimeText(this.timer, timeleft > 0 and timeleft or nil)
      if this.lastStacks ~= stacks then
        this.lastStacks = stacks
        this.stacks:SetText(stacks > 1 and stacks or "")
      end

      -- the sweep: 1.12 gives a buff's time left but not its full length, so the
      -- length is the time left when it was first seen (or renewed: more time left
      -- than a moment ago). A buff that was on at login starts part way.
      if C.buffs.cooldown_anim == "1" and timeleft > 0 then
        local id = this.mode .. ":" .. tostring(this.mode == this.btype and GetPlayerBuffTexture(this.bid) or "")
        if this.cdId ~= id or not this.cdLen or timeleft > (this.cdLeft or 0) + .5 then
          this.cdId, this.cdLen = id, timeleft
        end
        this.cdLeft = timeleft
        local start = GetTime() + timeleft - this.cdLen
        if not this.cdStart or math.abs(start - this.cdStart) > .3 then
          this.cd.pfCooldownReverse = tonumber(C.buffs.cooldown_reverse) or 0
          CooldownFrame_SetTimer(this.cd, start, this.cdLen, 1)
          this.cdStart = start
        end
      elseif this.cdStart then
        CooldownFrame_SetTimer(this.cd, 0, 0, 0)
        this.cdStart, this.cdId = nil, nil
      end
    end)

    buff:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
      if this.mode == this.btype then
        GameTooltip:SetPlayerBuff(this.bid)

        if IsShiftKeyDown() then
          local texture = GetPlayerBuffTexture(this.bid)

          local playerlist = ""
          local first = true

          if UnitInRaid("player") then
            for i=1,40 do
              local unitstr = "raid" .. i
              if not UnitHasBuff(unitstr, texture) and UnitName(unitstr) then
                playerlist = playerlist .. ( not first and ", " or "") .. GetUnitColor(unitstr) .. UnitName(unitstr) .. "|r"
                first = nil
              end
            end
          else
            if not UnitHasBuff("player", texture) then
              playerlist = playerlist .. ( not first and ", " or "") .. GetUnitColor("player") .. UnitName("player") .. "|r"
              first = nil
            end

            for i=1,4 do
              local unitstr = "party" .. i
              if not UnitHasBuff(unitstr, texture) and UnitName(unitstr) then
                playerlist = playerlist .. ( not first and ", " or "") .. GetUnitColor(unitstr) .. UnitName(unitstr) .. "|r"
                first = nil
              end
            end
          end

          if strlen(playerlist) > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(T["Unbuffed"] .. ":", .3, 1, .8)
            GameTooltip:AddLine(playerlist,1,1,1,1)
            GameTooltip:Show()
          end
        end
      elseif this.mode == "MAINHAND" then
        GameTooltip:SetInventoryItem("player", 16)
      elseif this.mode == "OFFHAND" then
        GameTooltip:SetInventoryItem("player", 17)
      end
    end)

    buff:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    buff:SetScript("OnClick", function()
      if CancelItemTempEnchantment and this.mode and this.mode == "MAINHAND" then
        CancelItemTempEnchantment(1)
      elseif CancelItemTempEnchantment and this.mode and this.mode == "OFFHAND" then
        CancelItemTempEnchantment(2)
      else
        CancelPlayerBuff(this.bid)
      end
    end)

    RefreshBuffButton(buff)

    return buff
  end

  local function GetNumBuffs()
    local mh, mhtime, mhcharge, oh, ohtime, ohcharge = GetWeaponEnchantInfo()
    local offset = (mh and 1 or 0) + (oh and 1 or 0)

    for i=1,32 do
      local bid, untilCancelled = GetPlayerBuff(PLAYER_BUFF_START_ID+i, "HELPFUL")
      if bid < 0 then
        return i - 1 + offset
      end
    end
    return 0 + offset
  end

  pfUI.buff = CreateFrame("Frame", "pfGlobalBuffFrame", UIParent)
  pfUI.buff.mainList, pfUI.buff.consList, pfUI.buff.consSig = {}, {}, ""

  -- (octo, 27 Nov 2026; Andayko: "consolidation buffs ... as in VCB") which buff
  -- slots go into the box: more time left than the set minutes, or (optional)
  -- buffs that never run out (auras, tracking). Returns a string that changes
  -- whenever the split does, so the once-a-second check knows when to redraw.
  local function BuildLists()
    local main, cons = {}, {}
    local sig = ""
    if C.buffs.consolidate == "1" and C.buffs.buffs == "1" then
      local lim = (tonumber(C.buffs.consmin) or 10) * 60
      for n = 1, 32 do
        local k = pfUI.api.PlayerBuffIndex(n, "HELPFUL")
        if k > 32 then break end
        local bid = GetPlayerBuff(PLAYER_BUFF_START_ID + k, "HELPFUL")
        if not bid or bid < 0 then break end
        local tl = GetPlayerBuffTimeLeft(bid) or 0
        if tl > lim or (tl <= 0 and C.buffs.consnotimer == "1") then
          table.insert(cons, k)
          sig = sig .. "c" .. k
        else
          table.insert(main, k)
          sig = sig .. "m" .. k
        end
      end
    end
    pfUI.buff.mainList, pfUI.buff.consList = main, cons
    pfUI.buff.consOn = table.getn(cons) > 0
    return sig
  end

  pfUI.buff:RegisterEvent("PLAYER_AURAS_CHANGED")
  pfUI.buff:RegisterEvent("UNIT_INVENTORY_CHANGED")
  pfUI.buff:RegisterEvent("UNIT_MODEL_CHANGED")
  pfUI.buff:SetScript("OnEvent", function()
    if C.buffs.weapons == "1" then
      local mh, mhtime, mhcharge, oh, ohtime, ohcharge = GetWeaponEnchantInfo()
      pfUI.buff.wepbuffs.count = (mh and 1 or 0) + (oh and 1 or 0)
    else
      pfUI.buff.wepbuffs.count = 0
    end

    pfUI.buff.consSig = BuildLists()

    for i=1,32 do
      RefreshBuffButton(pfUI.buff.buffs.buttons[i])
    end

    for i=1,16 do
      RefreshBuffButton(pfUI.buff.debuffs.buttons[i])
    end

    if C.buffs.separateweapons == "1" then
      for i=1,2 do
        RefreshBuffButton(pfUI.buff.wepbuffs.buttons[i])
      end
    end

    pfUI.buff:UpdateCons()
  end)

  -- a buff runs down past the box's minutes without an event: look once a second
  pfUI.buff:SetScript("OnUpdate", function()
    if C.buffs.consolidate ~= "1" then return end
    if (this.nextCons or 0) > GetTime() then return end
    this.nextCons = GetTime() + 1
    local old = pfUI.buff.consSig
    if BuildLists() ~= old then
      pfUI.buff:GetScript("OnEvent")()
    end
  end)

  -- Weapon Buffs
  pfUI.buff.wepbuffs = CreateFrame("Frame", "pfWepBuffFrame", UIParent)
  pfUI.buff.wepbuffs.count = 0
  pfUI.buff.wepbuffs.buttons = {}
  for i=1,2 do
    pfUI.buff.wepbuffs.buttons[i] = CreateBuffButton(i, "HELPFUL", 1)
  end

  -- Buff Frame
  pfUI.buff.buffs = CreateFrame("Frame", "pfBuffFrame", UIParent)
  pfUI.buff.buffs.buttons = {}
  for i=1,32 do
    pfUI.buff.buffs.buttons[i] = CreateBuffButton(i, "HELPFUL")
  end

  -- Debuffs
  pfUI.buff.debuffs = CreateFrame("Frame", "pfDebuffFrame", UIParent)
  pfUI.buff.debuffs.buttons = {}
  for i=1,16 do
    pfUI.buff.debuffs.buttons[i] = CreateBuffButton(i, "HARMFUL")
  end

  -- Consolidated buffs: one icon in the buff row; hover it (or click to keep it
  -- open) for a box with the long buffs. Right-click a buff there to cancel it.
  local function MouseOver(f)
    if not f or not f:IsVisible() or not f:GetLeft() then return nil end
    local x, y = GetCursorPosition()
    local s = f:GetEffectiveScale()
    x, y = x / s, y / s
    return x >= f:GetLeft() and x <= f:GetRight() and y >= f:GetBottom() and y <= f:GetTop()
  end

  pfUI.buff.consbtn = CreateFrame("Button", "pfConsBuffButton", pfUI.buff.buffs)
  local cb = pfUI.buff.consbtn
  cb:SetFrameLevel(pfUI.buff.buffs:GetFrameLevel() + 4)
  cb.texture = cb:CreateTexture(nil, "BACKGROUND")
  cb.texture:SetTexCoord(.07, .93, .07, .93)
  cb.texture:SetAllPoints(cb)
  cb.count = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  cb.count:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", -1, 2)
  cb.count:SetTextColor(1, .82, 0, 1)
  CreateBackdrop(cb)
  CreateBackdropShadow(cb)
  cb:RegisterForClicks("LeftButtonUp")
  cb:Hide()
  cb:SetScript("OnEnter", function()
    pfUI.buff.cons:Show()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
    GameTooltip:AddLine(T["Consolidated buffs"] or "Consolidated buffs")
    GameTooltip:AddLine(T["Click: keep the box open"] or "Click: keep the box open", 1, 1, 1)
    GameTooltip:Show()
  end)
  cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  cb:SetScript("OnClick", function()
    local box = pfUI.buff.cons
    box.pinned = not box.pinned
    if box.pinned then box:Show() end
  end)

  pfUI.buff.cons = CreateFrame("Frame", "pfConsBuffFrame", UIParent)
  local box = pfUI.buff.cons
  box:SetFrameStrata("DIALOG")
  box:SetClampedToScreen(true)
  box:Hide()
  CreateBackdrop(box)
  CreateBackdropShadow(box)
  box:SetScript("OnUpdate", function()
    if this.pinned then this.away = nil return end
    if MouseOver(this) or MouseOver(pfUI.buff.consbtn) then
      this.away = nil
    else
      this.away = this.away or (GetTime() + .4)
      if GetTime() > this.away then this.away = nil this:Hide() end
    end
  end)
  box.buttons = {}
  for i=1,32 do
    box.buttons[i] = CreateBuffButton(i, "HELPFUL", nil, true)
  end

  function pfUI.buff:UpdateCons()
    local cb, box = pfUI.buff.consbtn, pfUI.buff.cons
    local n = table.getn(pfUI.buff.consList)
    for i=1,32 do RefreshBuffButton(box.buttons[i]) end
    if not pfUI.buff.consOn then
      cb:Hide()
      box:Hide()
      box.pinned = nil
      return
    end
    -- the box's place = the first buff place (after weapon buffs in the row)
    local first = 1
    if C.buffs.separateweapons ~= "1" then first = pfUI.buff.wepbuffs.count + 1 end
    local anchor = pfUI.buff.buffs.buttons[first]
    cb:ClearAllPoints()
    cb:SetAllPoints(anchor)
    local bid = GetPlayerBuff(PLAYER_BUFF_START_ID + pfUI.buff.consList[1], "HELPFUL")
    cb.texture:SetTexture(GetPlayerBuffTexture(bid))
    cb.count:SetText(n)
    cb.backdrop:SetBackdropBorderColor(1, .82, 0, 1)
    cb:Show()

    -- the box: a grid of the buffs, growing the same way as the buff row
    local size = tonumber(C.buffs.size)
    local sp = tonumber(C.buffs.spacing)
    local fontsize = C.buffs.fontsize == "-1" and C.global.font_size or C.buffs.fontsize
    local rowh = (C.buffs.textinside == "1" and 0 or (fontsize * 1.5)) + size + 2 * sp
    local cell = size + 2 * sp
    local perRow = math.min(n, math.max(1, tonumber(C.buffs.consrowsize) or 8))
    local rows = math.ceil(n / perRow)
    local right = C.buffs.buffgrow == "right"
    local up = C.buffs.rowgrow == "up"
    box:SetWidth(perRow * cell + 2 * sp)
    box:SetHeight(rows * rowh + 2 * sp)
    box:SetScale(pfUI.buff.buffs:GetEffectiveScale() / UIParent:GetEffectiveScale())
    box:ClearAllPoints()
    local h = right and "LEFT" or "RIGHT"
    if up then
      box:SetPoint("BOTTOM" .. h, cb, "TOP" .. h, 0, 8)
    else
      box:SetPoint("TOP" .. h, cb, "BOTTOM" .. h, 0, C.buffs.textinside == "1" and -8 or -(fontsize * 1.5 + 8))
    end
    for i=1,32 do
      local b = box.buttons[i]
      local row = floor((i - 1) / perRow)
      local col = i - 1 - row * perRow
      b:ClearAllPoints()
      b:SetPoint("TOP" .. h, box, "TOP" .. h, (right and 1 or -1) * (col * cell + 2 * sp), -(row * rowh + 2 * sp))
    end
  end

  -- config loading
  function pfUI.buff:UpdateConfigBuffButton(buff)
    local fontsize = C.buffs.fontsize == "-1" and C.global.font_size or C.buffs.fontsize
    -- (octo, 27 Nov 2026; Andayko, "as in VCB") each row grows left (pfUI's way)
    -- or right, and rows stack down or up: buffs.buffgrow / debuffgrow / wepgrow,
    -- buffs.rowgrow. The frames keep their size and place, so movers stay put.
    local perRow, relFrame, grow
    if buff.btype == "HELPFUL" then
      if buff.weapon == 1 and C.buffs.separateweapons == "1" then
        perRow, relFrame, grow = tonumber(C.buffs.wepbuffrowsize), pfUI.buff.wepbuffs, C.buffs.wepgrow
      else
        perRow, relFrame, grow = tonumber(C.buffs.buffrowsize), pfUI.buff.buffs, C.buffs.buffgrow
      end
    else
      perRow, relFrame, grow = tonumber(C.buffs.debuffrowsize), pfUI.buff.debuffs, C.buffs.debuffgrow
    end

    buff:SetWidth(tonumber(C.buffs.size))
    buff:SetHeight(tonumber(C.buffs.size))

    if not buff.cons then
      local textrow = C.buffs.textinside == "1" and 0 or (fontsize*1.5)
      local cell = tonumber(C.buffs.size)+2*tonumber(C.buffs.spacing)
      local rowh = textrow + cell
      local rowcount = floor((buff.gid-1) / perRow)
      local col = buff.gid-1-rowcount*perRow
      local right = grow == "right"
      local up = C.buffs.rowgrow == "up"
      local point = (up and "BOTTOM" or "TOP") .. (right and "LEFT" or "RIGHT")
      local offsetX = (right and 1 or -1) * col * cell
      local offsetY = up and (rowcount * rowh + textrow) or -(rowcount * rowh)
      buff:ClearAllPoints()
      buff:SetPoint(point, relFrame, point, offsetX, offsetY)
    end

    buff.timer:SetFont(pfUI.font_default, fontsize, "OUTLINE")
    buff.stacks:SetFont(pfUI.font_default, fontsize+1, "OUTLINE")

    buff.timer:SetHeight(fontsize * 1.3)

    buff.timer:ClearAllPoints()
    if C.buffs.textinside == "1" then
      buff.timer:SetAllPoints(buff)
    else
      buff.timer:SetPoint("TOP", buff, "BOTTOM", 0, -3)
    end
  end

  function pfUI.buff:UpdateConfig()
    local fontsize = C.buffs.fontsize == "-1" and C.global.font_size or C.buffs.fontsize

    pfUI.buff.buffs:SetWidth(tonumber(C.buffs.buffrowsize) * (tonumber(C.buffs.size)+2*tonumber(C.buffs.spacing)))
    pfUI.buff.buffs:SetHeight(ceil(32/tonumber(C.buffs.buffrowsize)) * ((C.buffs.textinside == "1" and 0 or (fontsize*1.5))+tonumber(C.buffs.size)+2*tonumber(C.buffs.spacing)))
    pfUI.buff.buffs:SetPoint("TOPRIGHT", pfUI.minimap or UIParent, "TOPLEFT", -4*tonumber(C.buffs.spacing), 0)
    UpdateMovable(pfUI.buff.buffs)

    pfUI.buff.debuffs:SetWidth(tonumber(C.buffs.debuffrowsize) * (tonumber(C.buffs.size)+2*tonumber(C.buffs.spacing)))
    pfUI.buff.debuffs:SetHeight(ceil(16/tonumber(C.buffs.debuffrowsize)) * ((C.buffs.textinside == "1" and 0 or (fontsize*1.5))+tonumber(C.buffs.size)+2*tonumber(C.buffs.spacing)))
    pfUI.buff.debuffs:SetPoint("TOPRIGHT", pfUI.buff.buffs, "BOTTOMRIGHT", 0, 0)
    UpdateMovable(pfUI.buff.debuffs)

    if C.buffs.separateweapons == "1" then
      pfUI.buff.wepbuffs:ClearAllPoints()
      pfUI.buff.wepbuffs:SetWidth(tonumber(C.buffs.wepbuffrowsize) * (tonumber(C.buffs.size)+2*tonumber(C.buffs.spacing)))
      pfUI.buff.wepbuffs:SetHeight(ceil(2/tonumber(C.buffs.wepbuffrowsize)) * ((C.buffs.textinside == "1" and 0 or (fontsize*1.5))+tonumber(C.buffs.size)+2*tonumber(C.buffs.spacing)))
      pfUI.buff.wepbuffs:SetPoint("TOPRIGHT", pfUI.buff.debuffs, "BOTTOMRIGHT", 0, 0)
      pfUI.buff.wepbuffs:Show()
      UpdateMovable(pfUI.buff.wepbuffs)
    else
      pfUI.buff.wepbuffs:Hide()
      RemoveMovable(pfUI.buff.wepbuffs)
    end

    for i=1,32 do
      pfUI.buff:UpdateConfigBuffButton(pfUI.buff.buffs.buttons[i])
    end

    for i=1,16 do
      pfUI.buff:UpdateConfigBuffButton(pfUI.buff.debuffs.buttons[i])
    end

    for i=1,2 do
      pfUI.buff:UpdateConfigBuffButton(pfUI.buff.wepbuffs.buttons[i])
    end

    for i=1,32 do
      pfUI.buff:UpdateConfigBuffButton(pfUI.buff.cons.buttons[i])
    end
    pfUI.buff.consbtn.count:SetFont(pfUI.font_default, fontsize+1, "OUTLINE")

    pfUI.buff:GetScript("OnEvent")()
  end

  pfUI.buff:UpdateConfig()
end)
