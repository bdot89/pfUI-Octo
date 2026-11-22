pfUI:RegisterSkin("Group Finder", "vanilla", function ()
  -- pfUI Octo (22 Nov 2026, Lobo: "some screens that do not take the pfui screen look. like looking for group stuff
  -- all seem to be the default blizzard ui"). OctoWoW's own group finder (Turtle-style "LFT", in the client's
  -- FrameXML\LFT, patch-4 / patch-5): the Group Finder window (Group Browser / Dungeon Finder tabs, the new group
  -- form), the role check, the "your group is ready" pop-up and the ready check status window with the five role
  -- circles. Frame names read from patch-4's LFT.xml. The dungeon pictures and role pictures stay; the wooden
  -- dialog boxes, the parchment frame and the gold bar borders become pfUI's dark panels, buttons and bars.
  if not LFTFrame then return end
  local rawborder, border = GetBorderSize()
  local bpad = rawborder > 1 and border - GetPerfectPixel() or GetPerfectPixel()

  -- hide a frame's own pictures except the ones named in keep (their full names)
  local function StripExcept(frame, keep)
    if not frame then return end
    for _, r in ipairs({ frame:GetRegions() }) do
      if r.SetTexture and not (r.GetName and r:GetName() and keep[r:GetName()]) then r:SetTexture(nil) end
    end
  end

  -- the countdown bars: pfUI's bar, the game's gold border away
  local function SkinTimer(bar)
    if not bar then return end
    for _, r in ipairs({ bar:GetRegions() }) do
      local tex = r.GetTexture and r:GetTexture()
      if type(tex) == "string" and string.find(string.lower(tex), "barborder") then r:SetTexture(nil) end
    end
    bar:SetStatusBarTexture(pfUI.media["img:bar"])
    bar:SetStatusBarColor(1, .8, .2, 1)
    CreateBackdrop(bar)
  end

  -- a dialog box (the game's wooden border and background) as a pfUI panel
  local function Panel(frame)
    if not frame then return end
    CreateBackdrop(frame, nil, true, .85)
    CreateBackdropShadow(frame)
  end

  local function Btn(b) if b then SkinButton(b) end end
  -- a part the server may build differently: tried on its own, so one odd part never stops the rest
  local function Try(fn, a, b, c, d) if a then pcall(fn, a, b, c, d) end end

  -- ---------------------------------------------------------------- the Group Finder window
  StripTextures(LFTFrame)
  CreateBackdrop(LFTFrame, nil, nil, .75)
  CreateBackdropShadow(LFTFrame)
  LFTFrame.backdrop:SetPoint("TOPLEFT", 10, -10)
  LFTFrame.backdrop:SetPoint("BOTTOMRIGHT", -30, 72)
  LFTFrame:SetHitRectInsets(10, 30, 10, 72)
  EnableMovable("LFTFrame")

  local close = GetNoNameObject(LFTFrame, "Button", nil, "UI-Panel-MinimizeButton-Up")
  if close then SkinCloseButton(close, LFTFrame.backdrop, -6, -6) end

  Try(SkinScrollbar, LFTFrameScrollFrameScrollBar)
  Try(SkinDropDown, LFTFrameDropDown)
  Btn(LFTFrameMainButton)
  Btn(LFTFrameNewGroupButton)
  Btn(LFTFrameSendMessageButton)
  if LFTFrameSearch then
    StripTextures(LFTFrameSearch)
    CreateBackdrop(LFTFrameSearch, nil, true)
  end

  -- the tabs under the window, as pfUI's
  if LFTFrameTab1 then
    LFTFrameTab1:ClearAllPoints()
    LFTFrameTab1:SetPoint("TOPLEFT", LFTFrame.backdrop, "BOTTOMLEFT", bpad, -(border + (border == 1 and 1 or 2)))
    for i = 1, 2 do
      local tab = _G["LFTFrameTab" .. i]
      local last = _G["LFTFrameTab" .. (i - 1)]
      if tab then
        if last then
          tab:ClearAllPoints()
          tab:SetPoint("LEFT", last, "RIGHT", border * 2 + 1, 0)
        end
        SkinTab(tab)
      end
    end
  end

  -- the new group form
  if LFTNewGroupFrame then
    StripTextures(LFTNewGroupFrame)
    CreateBackdrop(LFTNewGroupFrame, nil, nil, .9)
    CreateBackdropShadow(LFTNewGroupFrame)
    for _, name in ipairs({ "LFTNewGroupTitleBackground", "LFTNewGroupDescriptionBackground" }) do
      local f = _G[name]
      if f then
        StripTextures(f)
        CreateBackdrop(f, nil, true)
      end
    end
    Try(SkinScrollbar, LFTNewGroupDescriptionScrollBar)
    Try(SkinCheckbox, LFTNewGroupUseRolesButton)
    for i = 1, 3 do
      local e = _G["LFTNewGroupRole" .. i .. "EditBox"]
      if e then
        StripTextures(e)
        CreateBackdrop(e, nil, true)
      end
    end
    Try(SkinDropDown, LFTNewGroupFramePresetDropDown)
    for _, name in ipairs({ "LFTNewGroupFrameSavePresetButton", "LFTNewGroupOkButton", "LFTNewGroupCancelButton",
      "LFTNewGroupFrameDeleteButton", "LFTNewGroupFrameRoleCheckButton" }) do
      Btn(_G[name])
    end
  end

  -- ---------------------------------------------------------------- role check
  if LFTRoleCheckFrame then
    Panel(LFTRoleCheckFrame)
    Btn(LFTRoleCheckFrameConfirmButton)
    Btn(LFTRoleCheckFrameDeclineButton)
    SkinTimer(LFTRoleCheckFrameTimer)
  end

  -- ---------------------------------------------------------------- your group is ready (enter the dungeon)
  if LFTGroupReadyFrame then
    -- keep the dungeon's picture and your role's; the wooden art round them goes
    StripExcept(LFTGroupReadyFrame, { LFTGroupReadyFrameBackground = true, LFTGroupReadyFrameRoleTexture = true })
    Panel(LFTGroupReadyFrame)
    Btn(LFTGroupReadyFrameConfirmButton)
    Btn(LFTGroupReadyFrameDeclineButton)
    SkinTimer(LFTGroupReadyFrameTimer)
  end

  -- ---------------------------------------------------------------- ready check (who has accepted)
  if LFTGroupReadyStatusFrame then
    Panel(LFTGroupReadyStatusFrame)
    if LFTGroupReadyStatusFrameCloseButton then
      SkinCloseButton(LFTGroupReadyStatusFrameCloseButton, LFTGroupReadyStatusFrame, -6, -6)
    end
    SkinTimer(LFTGroupReadyStatusFrameTimer)
  end
end)
