pfUI:RegisterSkin("Character", "vanilla:tbc", function ()
  local rawborder, border = GetBorderSize()
  local bpad = rawborder > 1 and border - GetPerfectPixel() or GetPerfectPixel()

  -- Compatibility
  if PlayerTitleDropDown then -- tbc, wotlk
    -- Character Tab
    SkinDropDown(PlayerTitleDropDown)
    PlayerTitleDropDown:SetPoint("TOP", CharacterLevelText, "BOTTOM", 0, -2)
    PlayerTitleDropDownText:SetPoint("LEFT", PlayerTitleDropDown.backdrop, "LEFT", 6, 2)
    SkinDropDown(PlayerStatFrameLeftDropDown)
    SkinDropDown(PlayerStatFrameRightDropDown)

    -- Honor Tab
    StripTextures(PVPFrame)
  else -- vanilla
    -- Honor Tab
    StripTextures(HonorFrame)

    HonorFrameProgressBar:SetStatusBarTexture(pfUI.media["img:bar"])
    CreateBackdrop(HonorFrameProgressBar)
    HonorFrameProgressBar:SetHeight(24)
  end

  local magicResTextureCords = {
    {0.21875, 0.78125, 0.25, 0.3203125},
    {0.21875, 0.78125, 0.0234375, 0.09375},
    {0.21875, 0.78125, 0.13671875, 0.20703125},
    {0.21875, 0.78125, 0.36328125, 0.43359375},
    {0.21875, 0.78125, 0.4765625, 0.546875}
  }

  CreateBackdrop(CharacterFrame, nil, nil, .75)
  CreateBackdropShadow(CharacterFrame)

  CharacterFrame.backdrop:SetPoint("TOPLEFT", 10, -10)
  CharacterFrame.backdrop:SetPoint("BOTTOMRIGHT", -30, 72)
  CharacterFrame:SetHitRectInsets(10,30,10,72)
  EnableMovable("CharacterFrame", nil, CHARACTERFRAME_SUBFRAMES)

  SkinCloseButton(CharacterFrameCloseButton, CharacterFrame.backdrop, -6, -6)

  CharacterFrame:DisableDrawLayer("ARTWORK")

  CharacterNameText:ClearAllPoints()
  CharacterNameText:SetPoint("TOP", CharacterFrame.backdrop, "TOP", 0, -10)

  CharacterFrameTab1:ClearAllPoints()
  CharacterFrameTab1:SetPoint("TOPLEFT", CharacterFrame.backdrop, "BOTTOMLEFT", bpad, -(border + (border == 1 and 1 or 2)))
  for i = 1, 5 do
    local tab = _G["CharacterFrameTab"..i]
    local lastTab = _G["CharacterFrameTab"..(i-1)]
    if lastTab and lastTab:IsShown() then
      tab:ClearAllPoints()
      tab:SetPoint("LEFT", lastTab, "RIGHT", border*2 + 1, 0)
    end
    SkinTab(tab)
  end

  do -- Character Tab
    local slots = {
      "HeadSlot",
      "NeckSlot",
      "ShoulderSlot",
      "BackSlot",
      "ChestSlot",
      "ShirtSlot",
      "TabardSlot",
      "WristSlot",
      "HandsSlot",
      "WaistSlot",
      "LegsSlot",
      "FeetSlot",
      "Finger0Slot",
      "Finger1Slot",
      "Trinket0Slot",
      "Trinket1Slot",
      "MainHandSlot",
      "SecondaryHandSlot",
      "RangedSlot",
      "AmmoSlot"
    }

    local function RefreshPetPosition()
      CharacterFrameTab3:ClearAllPoints()
      CharacterFrameTab3:SetPoint("LEFT", HasPetUI() and CharacterFrameTab2 or CharacterFrameTab1, "RIGHT", border*2 + 1, 0)
    end

    local function RefreshCharacterSlot(slot)
      local slotId = slot:GetID()
      local link = GetInventoryItemLink("player", slotId)
      if slot and slot.backdrop then
        if link then
          local isBroken = GetInventoryItemBroken("player", slotId)
          local quality = GetInventoryItemQuality("player", slotId)
          if isBroken then
            slot.backdrop:SetBackdropBorderColor(0.9, 0, 0, 1)
          elseif quality and quality > 0 then
            local r, g, b = GetItemQualityColor(quality)
            slot.backdrop:SetBackdropBorderColor(r, g, b, 1)
          else
            slot.backdrop:SetBackdropBorderColor(pfUI.cache.er, pfUI.cache.eg, pfUI.cache.eb, pfUI.cache.ea)
          end
        else
          slot.backdrop:SetBackdropBorderColor(pfUI.cache.er, pfUI.cache.eg, pfUI.cache.eb, pfUI.cache.ea)
        end

        if ShaguScore and link then
          local _, _, itemID = string.find(GetInventoryItemLink("player", slotId), "item:(%d+):%d+:%d+:%d+")
          local itemLevel = ShaguScore.Database[tonumber(itemID)] or 0
          local _, _, quality, _, _, _, _, _, itemSlot, _ = GetItemInfo(itemID)
          local score = ShaguScore:Calculate(itemSlot, quality, itemLevel)
          if score and score > 0 and quality and quality > 0 then
            local r,g,b = GetItemQualityColor(quality)
            slot.scoreText:SetText(score)
            slot.scoreText:SetTextColor(r, g, b, 1)
          else
            slot.scoreText:SetText("")
            slot.scoreText:SetTextColor(1, 1, 1, 1)
          end
        else
          slot.scoreText:SetText("")
          slot.scoreText:SetTextColor(1, 1, 1, 1)
        end
      end
    end
    local function RefreshCharacterSlots()
      for _, slotName in pairs(slots) do
        local slot = _G["Character"..slotName]
        RefreshCharacterSlot(slot)
      end
    end

    HookScript(CharacterFrame, "OnShow", function()
      RefreshCharacterSlots()
      RefreshPetPosition()

      if not this.hooked then
        hooksecurefunc("PaperDollItemSlotButton_Update", function()
          -- update only character slots!
          if string.find(this:GetName(), "^Character.-Slot$") then
            RefreshCharacterSlot(this)
          end
        end)
        hooksecurefunc("PetTab_Update", RefreshPetPosition)
        this.hooked = true
      end
    end)

    StripTextures(PaperDollFrame)
    StripTextures(CharacterAttributesFrame)
    StripTextures(CharacterResistanceFrame)

    EnableClickRotate(CharacterModelFrame)
    CharacterModelFrameRotateLeftButton:Hide()
    CharacterModelFrameRotateRightButton:Hide()

    for i,c in pairs(magicResTextureCords) do
      local magicResFrame = _G["MagicResFrame"..i]
      magicResFrame:SetWidth(26)
      magicResFrame:SetHeight(26)
      CreateBackdrop(magicResFrame)
      SetAllPointsOffset(magicResFrame.backdrop, magicResFrame, 2)
      local icon = GetNoNameObject(magicResFrame, "Texture", "BACKGROUND", "ResistanceIcons")
      SetAllPointsOffset(icon, magicResFrame, 3)
      icon:SetTexCoord(c[1], c[2], c[3], c[4])
    end

    for _, slotName in pairs(slots) do
      local frame = _G["Character"..slotName]
      StripTextures(frame)
      CreateBackdrop(frame)
      SetAllPointsOffset(frame.backdrop, frame, 0)

      HandleIcon(frame.backdrop, _G["Character"..slotName.."IconTexture"])

      if not frame.scoreText then
        frame.scoreText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.scoreText:SetFont(pfUI.font_default, 12, "OUTLINE")
        frame.scoreText:SetPoint("TOPRIGHT", 0, 0)
      end
    end
  end

  do -- Pet Tab
    StripTextures(PetPaperDollFrame)

    PetNameText:ClearAllPoints()
    PetNameText:SetPoint("TOP", CharacterFrame.backdrop, "TOP", 0, -10)

    EnableClickRotate(PetModelFrame)
    PetModelFrameRotateLeftButton:Hide()
    PetModelFrameRotateRightButton:Hide()

    PetPaperDollCloseButton:Hide()

    StripTextures(PetAttributesFrame)
    StripTextures(PetPaperDollFrameExpBar)
    CreateBackdrop(PetPaperDollFrameExpBar, nil, true)
    PetPaperDollFrameExpBar:SetStatusBarTexture(pfUI.media["img:bar"])
    PetPaperDollFrameExpBar:ClearAllPoints()
    PetPaperDollFrameExpBar:SetPoint("BOTTOM", PetModelFrame, "BOTTOM", 0, -120)

    PetTrainingPointLabel:ClearAllPoints()
    PetTrainingPointLabel:SetPoint("TOPLEFT", PetArmorFrame, "BOTTOMLEFT", 0, -16)

    PetTrainingPointText:ClearAllPoints()
    PetTrainingPointText:SetPoint("TOPRIGHT", PetArmorFrame, "BOTTOMRIGHT", 0, -16)

    PetPaperDollPetInfo:ClearAllPoints()
    PetPaperDollPetInfo:SetPoint("TOPLEFT", PetModelFrame, "TOPLEFT")
    PetPaperDollPetInfo:SetFrameLevel(255)

    PetResistanceFrame:ClearAllPoints()
    PetResistanceFrame:SetPoint("TOPRIGHT", PetModelFrame, "TOPRIGHT")

    for i,c in pairs(magicResTextureCords) do
      local magicResFrame = _G["PetMagicResFrame"..i]
      magicResFrame:SetWidth(26)
      magicResFrame:SetHeight(26)
      CreateBackdrop(magicResFrame)
      SetAllPointsOffset(magicResFrame.backdrop, magicResFrame, 2)
      local icon = GetNoNameObject(magicResFrame, "Texture", "BACKGROUND", "ResistanceIcons")
      SetAllPointsOffset(icon, magicResFrame, 3)
      icon:SetTexCoord(c[1], c[2], c[3], c[4])
    end
  end

  do -- Reputation Tab
    StripTextures(ReputationFrame)

    for i = 1, NUM_FACTIONS_DISPLAYED do
      local bar = _G["ReputationBar" .. i]
      StripTextures(bar)
      CreateBackdrop(bar)
      bar:SetStatusBarTexture(pfUI.media["img:bar"])

      local war = _G["ReputationBar"..i.."AtWarCheck"]
      StripTextures(war)
      war:SetWidth(13)
      war:SetHeight(13)
      war:ClearAllPoints()
      war:SetPoint("LEFT", bar.backdrop, "RIGHT", 6, 0)
      war.icon = war:CreateTexture(nil, "OVERLAY")
      war.icon:SetPoint("LEFT", -3, -8)
      war.icon:SetTexture("Interface\\Buttons\\UI-CheckBox-SwordCheck")

      SkinCollapseButton(_G["ReputationHeader"..i])
    end

    StripTextures(ReputationListScrollFrame)
    SkinScrollbar(ReputationListScrollFrameScrollBar)

    StripTextures(ReputationDetailFrame)
    CreateBackdrop(ReputationDetailFrame, nil, nil, .75)
    SkinCloseButton(ReputationDetailCloseButton, ReputationDetailFrame.backdrop, -6, -6)

    ReputationDetailFrame:ClearAllPoints()
    ReputationDetailFrame:SetPoint("TOPLEFT", CharacterFrame.backdrop, "TOPRIGHT", 2*border, 0)

    SkinCheckbox(ReputationDetailAtWarCheckBox)
    SkinCheckbox(ReputationDetailInactiveCheckBox)
    SkinCheckbox(ReputationDetailMainScreenCheckBox)
  end

  do -- Skills Tab
    StripTextures(SkillFrame)

    SkillFrameExpandButtonFrame:DisableDrawLayer("BACKGROUND")

    SkillFrameCancelButton:Hide()

    StripTextures(SkillFrameCollapseAllButton)
    SkinCollapseButton(SkillFrameCollapseAllButton, true)
    SkillFrameCollapseAllButton:ClearAllPoints()
    SkillFrameCollapseAllButton:SetPoint("BOTTOMLEFT", SkillTypeLabel1, "TOPLEFT", 2, 2)

    for i = 1, SKILLS_TO_DISPLAY do
      local header = _G["SkillTypeLabel"..i]
      StripTextures(header)
      SkinCollapseButton(header)

      StripTextures(_G["SkillRankFrame"..i.."Border"])

      local frame = _G["SkillRankFrame" .. i]
      local lastframe = _G["SkillRankFrame" .. i-1]
      StripTextures(frame)
      CreateBackdrop(frame)

      if lastframe then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", lastframe, "BOTTOMLEFT", 0, -6)
      end
      frame:SetStatusBarTexture(pfUI.media["img:bar"])
      frame:SetHeight(12)
    end

    StripTextures(SkillListScrollFrame)
    SkinScrollbar(SkillListScrollFrameScrollBar)

    StripTextures(SkillDetailScrollFrame)
    SkillDetailScrollFrameScrollBar:Hide()
    SkillDetailScrollChildFrame:Hide()

    SkillDetailCostText:SetParent(SkillDetailScrollFrame)
    SkillDetailDescriptionText:SetParent(SkillDetailScrollFrame)

    StripTextures(SkillDetailStatusBar)
    CreateBackdrop(SkillDetailStatusBar)
    SkillDetailStatusBar:SetStatusBarTexture(pfUI.media["img:bar"])
    SkillDetailStatusBar:SetParent(SkillDetailScrollFrame)

    StripTextures(SkillDetailStatusBarUnlearnButton)
    SkillDetailStatusBarUnlearnButton:SetWidth(20)
    SkillDetailStatusBarUnlearnButton:SetHeight(20)
    SkillDetailStatusBarUnlearnButton:SetHitRectInsets(0,0,0,0)
    SkillDetailStatusBarUnlearnButton:ClearAllPoints()
    SkillDetailStatusBarUnlearnButton:SetPoint("LEFT", SkillDetailStatusBar, "RIGHT", 6, 0)
    SkillDetailStatusBarUnlearnButton:SetPushedTexture(nil)
    SkillDetailStatusBarUnlearnButton:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
  end

  -- octo (31 Oct 2026, user: "give it a new look that is professional add some
  -- art ... even better character stats also and the gear planner should all
  -- look together as one ... make the character stats button more obvious").
  -- One look for the character window, EvenBetterCharacterStats' enchant
  -- panel and the Gear sets panel: a class-coloured title strip with an
  -- accent line under it, your race's scenery faded behind the model, and the
  -- enchant panel's button as a labelled square beside the weapon slots.
  -- Textures only, made once: nothing runs per frame.
  local cr, cg, cb = 1, .82, 0
  local _, class = UnitClass("player")
  if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
    local c = RAID_CLASS_COLORS[class]
    cr, cg, cb = c.r, c.g, c.b
  end
  local ar, ag, ab = cr, cg, cb
  if GetAccentColor then ar, ag, ab = GetAccentColor() end

  local function Head(f, height)
    local bg = f and (f.backdrop or f)
    if not bg or bg.octoHead then return end
    height = height or 24
    local strip = bg:CreateTexture(nil, "BORDER")
    strip:SetTexture("Interface\\Buttons\\WHITE8X8")
    strip:SetPoint("TOPLEFT", bg, "TOPLEFT", 2, -2)
    strip:SetPoint("TOPRIGHT", bg, "TOPRIGHT", -2, -2)
    strip:SetHeight(height)
    strip:SetGradientAlpha("VERTICAL", cr, cg, cb, .04, cr, cg, cb, .32)
    local line = bg:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT", 0, 0)
    line:SetHeight(1)
    line:SetVertexColor(ar, ag, ab, .9)
    bg.octoHead = strip
    if bg.SetBackdropBorderColor then bg:SetBackdropBorderColor(ar * .5, ag * .5, ab * .5, 1) end
  end
  pfUI.charLook = { Head = Head }

  Head(CharacterFrame, 42)

  -- the race's own scenery (the game's dressing room art) behind the model
  if CharacterModelFrame and not CharacterModelFrame.octoArt then
    local _, race = UnitRace("player")
    race = race or "Human"
    local base = "Interface\\DressUpFrame\\DressUpBackground-" .. race
    local w, h = CharacterModelFrame:GetWidth() or 230, CharacterModelFrame:GetHeight() or 320
    local parts = {
      { 1, 0, 0, 256 / 318, 256 / 383 },            -- top left 256 x 256
      { 2, 256 / 318, 0, 62 / 318, 256 / 383 },     -- top right 62 x 256
      { 3, 0, 256 / 383, 256 / 318, 127 / 383 },    -- bottom left 256 x 128
      { 4, 256 / 318, 256 / 383, 62 / 318, 127 / 383 },
    }
    CharacterModelFrame.octoArt = {}
    for _, pt in ipairs(parts) do
      local t = PaperDollFrame:CreateTexture(nil, "BACKGROUND")
      t:SetTexture(base .. pt[1])
      t:SetPoint("TOPLEFT", CharacterModelFrame, "TOPLEFT", pt[2] * w, -pt[3] * h)
      t:SetWidth(pt[4] * w)
      t:SetHeight(pt[5] * h)
      t:SetAlpha(.45)
      table.insert(CharacterModelFrame.octoArt, t)
    end
    -- a soft dark edge so the art fades into the window
    local shade = PaperDollFrame:CreateTexture(nil, "BORDER")
    shade:SetTexture("Interface\\Buttons\\WHITE8X8")
    shade:SetAllPoints(CharacterModelFrame)
    shade:SetGradientAlpha("VERTICAL", 0, 0, 0, .75, 0, 0, 0, 0)
  end

  -- EvenBetterCharacterStats' enchant panel and our Gear sets panel: the same strip
  local function Side()
    local ench = _G.BCSEnchantFrame
    if ench then Head(ench, 22) end
    if _G.pfGearSheet then Head(_G.pfGearSheet, 22) end
    local tg = _G.BCSEnchantFrameToggleButton
    if tg and not tg.octoSquare then
      tg.octoSquare = true
      local slot = _G.CharacterMainHandSlot
      local size = slot and slot:GetHeight() or 37
      tg:SetWidth(size)
      tg:SetHeight(size)
      tg:ClearAllPoints()
      if slot then tg:SetPoint("RIGHT", slot, "LEFT", -10, 0) end
      local word = tg:CreateFontString(nil, "OVERLAY")
      word:SetFont(pfUI.font_default, 9, "OUTLINE")
      word:SetPoint("TOP", tg, "BOTTOM", 0, -2)
      word:SetText("Enchants")
      word:SetTextColor(ar, ag, ab)
    end
    -- (its border comes when the enchant panel first opens: tint it each time)
    if tg and tg.backdrop then tg.backdrop:SetBackdropBorderColor(ar, ag, ab, 1) end
  end
  Side()
  if PaperDollFrame then HookScript(PaperDollFrame, "OnShow", Side) end
  if _G.BCSEnchantFrame then HookScript(_G.BCSEnchantFrame, "OnShow", Side) end
end)
