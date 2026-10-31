pfUI:RegisterModule("cooldown", "vanilla:tbc", function ()
  -- cache values
  local lowcolor    = {strsplit(",", C.appearance.cd.lowcolor)}
  local normalcolor = {strsplit(",", C.appearance.cd.normalcolor)}
  local minutecolor = {strsplit(",", C.appearance.cd.minutecolor)}
  local hourcolor   = {strsplit(",", C.appearance.cd.hourcolor)}
  local daycolor    = {strsplit(",", C.appearance.cd.daycolor)}

  -- octo (31 Oct 2026, user: "more countdown options ... cooldown effects when
  -- they are finished"): the number's format and spot, a grow in the last
  -- seconds, and an effect + sound on the button the moment it is ready.
  -- Settings C.appearance.cd: format, pos, lowgrow, finish, finishcolor,
  -- finishmin, finishsound. pfUI.cooldown.Finish(button) plays the effect.
  local CDX = {}
  pfUI.cooldown = CDX
  CDX.FORMATS = {
    { key = "pfui", label = "pfUI (5, 2m, 1h)" },
    { key = "clock", label = "Clock (1:25)" },
    { key = "whole", label = "Whole seconds (85)" },
    { key = "big", label = "Seconds, minutes as 2m" },
  }
  CDX.POINTS = {
    { key = "CENTER", label = "Middle" }, { key = "TOP", label = "Top" }, { key = "BOTTOM", label = "Bottom" },
    { key = "TOPLEFT", label = "Top left" }, { key = "TOPRIGHT", label = "Top right" },
    { key = "BOTTOMLEFT", label = "Bottom left" }, { key = "BOTTOMRIGHT", label = "Bottom right" },
  }
  CDX.EFFECTS = {
    { key = "none", label = "None" },
    { key = "flash", label = "Flash" },
    { key = "pulse", label = "Icon pulse" },
    { key = "glow", label = "Glow ring" },
    { key = "rune", label = "Rune burst" },
    { key = "text", label = "\"Ready\" text" },
    { key = "all", label = "Flash + pulse + ring" },
  }
  CDX.SOUNDS = {
    { key = "none", label = "None" },
    { key = "MapPing", label = "Ping" },
    { key = "igMainMenuOptionCheckBoxOn", label = "Click" },
    { key = "TellMessage", label = "Whisper chime" },
    { key = "RaidWarning", label = "Raid warning" },
    { key = "AuctionWindowOpen", label = "Bell" },
  }

  -- the number's text for this many seconds left
  function CDX.Text(remaining)
    local f = C.appearance.cd.format or "pfui"
    if f == "pfui" or remaining > 5940 or remaining <= 5 then
      -- (the last 5 seconds and hours keep pfUI's colours and tenths)
      if f == "whole" and remaining <= 5 and remaining > 0 then
        local r, g, b = pfUI.api.GetStringColor(C.appearance.cd.lowcolor)
        return pfUI.api.rgbhex(r, g, b) .. math.ceil(remaining)
      end
      return GetColoredTimeString(remaining)
    end
    local col = remaining >= 60 and C.appearance.cd.minutecolor or C.appearance.cd.normalcolor
    local r, g, b = pfUI.api.GetStringColor(col)
    local hex = pfUI.api.rgbhex(r, g, b)
    if f == "clock" and remaining >= 60 then
      local s = math.ceil(remaining)
      return hex .. math.floor(s / 60) .. ":" .. string.format("%02d", math.mod(s, 60))
    elseif f == "big" and remaining >= 60 then
      return hex .. math.ceil(remaining / 60) .. "m"
    end
    return hex .. math.ceil(remaining)
  end

  -- the number's size: bigger in the last seconds when lowgrow is on
  local function Grow(this, remaining)
    local want = (C.appearance.cd.lowgrow == "1" and remaining <= 5) and 1.35 or 1
    if this.grown ~= want then
      this.grown = want
      this.text:SetTextHeight(math.floor((this.fontsize or 12) * want + .5))
    end
  end

  local function Icon(b)
    if b.icon and b.icon.GetTexture then return b.icon end
    local n = b.GetName and b:GetName()
    return n and _G[n .. "Icon"]
  end

  local function FxUpdate()
    local t = (GetTime() - this.at) / .6
    if t >= 1 then this:Hide() return end
    local a = 1 - t
    if this.flash:IsShown() then this.flash:SetAlpha(a * .8) end
    if this.pulse:IsShown() then
      local s = 1 + t * .7
      this.pulse:SetWidth(this.w * s) this.pulse:SetHeight(this.h * s)
      this.pulse:SetAlpha(a)
    end
    if this.ring:IsShown() then
      local s = 1.6 + t * 1.2
      this.ring:SetWidth(this.w * s) this.ring:SetHeight(this.h * s)
      this.ring:SetAlpha(a)
    end
    if this.rune:IsShown() then
      local s = .8 + t * 1.6
      this.rune:SetWidth(this.w * s) this.rune:SetHeight(this.h * s)
      this.rune:SetAlpha(a)
      -- (ClassicAPI gives textures SetRotation: the rune turns as it grows)
      if this.rune.SetRotation then this.rune:SetRotation(t * 3) end
    end
    if this.word:IsShown() then
      this.word:SetTextHeight(math.floor(this.h * (.35 + t * .2)))
      this.word:SetAlpha(t < .5 and 1 or (1 - t) * 2)
    end
  end

  local lastSound = 0
  function CDX.Finish(b, kind)
    kind = kind or C.appearance.cd.finish or "none"
    if not b or kind == "none" then return end
    local fx = b.pfFinish
    if not fx then
      fx = CreateFrame("Frame", nil, b)
      fx:SetAllPoints(b)
      fx.flash = fx:CreateTexture(nil, "OVERLAY")
      fx.flash:SetTexture("Interface\\Buttons\\WHITE8X8")
      fx.flash:SetAllPoints(fx)
      fx.flash:SetBlendMode("ADD")
      fx.pulse = fx:CreateTexture(nil, "OVERLAY")
      fx.pulse:SetPoint("CENTER", fx, "CENTER", 0, 0)
      fx.pulse:SetBlendMode("ADD")
      fx.ring = fx:CreateTexture(nil, "OVERLAY")
      fx.ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
      fx.ring:SetPoint("CENTER", fx, "CENTER", 0, 0)
      fx.ring:SetBlendMode("ADD")
      fx.rune = fx:CreateTexture(nil, "OVERLAY")
      fx.rune:SetTexture("Spells\\AuraRune256")
      fx.rune:SetPoint("CENTER", fx, "CENTER", 0, 0)
      fx.rune:SetBlendMode("ADD")
      fx.word = fx:CreateFontString(nil, "OVERLAY")
      fx.word:SetFont(pfUI.media[C.appearance.cd.font] or STANDARD_TEXT_FONT, 12, "OUTLINE")
      fx.word:SetPoint("CENTER", fx, "CENTER", 0, 0)
      fx:SetScript("OnUpdate", FxUpdate)
      b.pfFinish = fx
    end
    fx:SetFrameLevel((b:GetFrameLevel() or 1) + 6)
    fx.w, fx.h = b:GetWidth() or 36, b:GetHeight() or 36
    local r, g, bl = pfUI.api.GetStringColor(C.appearance.cd.finishcolor or "1,1,1,1")
    local all = kind == "all"
    local function On(part, yes) if yes then part:Show() else part:Hide() end end
    On(fx.flash, all or kind == "flash")
    fx.flash:SetVertexColor(r, g, bl)
    local icon = Icon(b)
    On(fx.pulse, (all or kind == "pulse") and icon and icon:GetTexture())
    if fx.pulse:IsShown() then fx.pulse:SetTexture(icon:GetTexture()) fx.pulse:SetTexCoord(icon:GetTexCoord()) end
    On(fx.ring, all or kind == "glow")
    fx.ring:SetVertexColor(r, g, bl)
    On(fx.rune, kind == "rune")
    fx.rune:SetVertexColor(r, g, bl)
    On(fx.word, kind == "text")
    fx.word:SetText(T["Ready"])
    fx.word:SetTextColor(r, g, bl)
    fx.at = GetTime()
    fx:Show()
    local snd = C.appearance.cd.finishsound or "none"
    if snd ~= "none" and GetTime() - lastSound > .3 then
      lastSound = GetTime()
      PlaySound(snd)
    end
  end

  -- a cooldown ran out: the effect, unless it was a short one
  local function Done(this)
    if this.finished then return end
    this.finished = true
    if (this.duration or 0) < (tonumber(C.appearance.cd.finishmin) or 3) then return end
    if (C.appearance.cd.finish or "none") == "none" then return end
    local p = this:GetParent()
    if p and p:IsVisible() then CDX.Finish(p) end
  end

  local parent
  local function pfCooldownOnUpdate()
    -- only run every 0.1 seconds (one of these runs per visible cooldown text:
    -- the checks below used to run every frame, building a global name each time)
    if ( this.tick or .1) > GetTime() then return else this.tick = GetTime() + .1 end

    parent = this:GetParent()
    if not parent then this:Hide() return end

    -- avoid to set cooldowns on invalid frames (the cooldown is kept at creation)
    if this.cooldown and not this.cooldown:IsShown() then
      -- (the game hides its swipe as the cooldown ends, often before the text sees 0)
      if this.start and this.start <= GetTime() and this.duration - (GetTime() - this.start) < .5 then Done(this) end
      this:Hide()
      return
    end

    -- fix own alpha value (should be inherited, but somehow isn't always)
    if this:GetAlpha() ~= parent:GetAlpha() then
      this:SetAlpha(parent:GetAlpha())
    end

    if this.start < GetTime() then
      -- calculating remaining time as it should be
      local remaining = this.duration - (GetTime() - this.start)
      if remaining >= 0 then
        this.text:SetText(CDX.Text(remaining))
        Grow(this, remaining)
      else
        Done(this)
        this:Hide()
      end
    else
      -- I have absolutely no idea, but it works:
      -- https://github.com/Stanzilla/WoWUIBugs/issues/47
      local time = time()
      local startupTime = time - GetTime()
      -- just a simplification of: ((2^32) - (start * 1000)) / 1000
      local cdTime = (2 ^ 32) / 1000 - this.start
      local cdStartTime = startupTime - cdTime
      local cdEndTime = cdStartTime + this.duration
      local remaining = cdEndTime - time

      if remaining >= 0 then
        this.text:SetText(CDX.Text(remaining))
        Grow(this, remaining)
      else
        Done(this)
        this:Hide()
      end
    end
  end

  local height, size
  local function pfCreateCoolDown(cooldown, start, duration)
    cooldown.pfCooldownText = CreateFrame("Frame", "pfCooldownFrame", cooldown:GetParent())
    -- the frame its timer belongs to: _G[parent name .. "Cooldown"] as pfUI checked it
    local pname = cooldown:GetParent() and cooldown:GetParent():GetName()
    cooldown.pfCooldownText.cooldown = pname and _G[pname .. "Cooldown"]
    cooldown.pfCooldownText:SetAllPoints(cooldown)
    cooldown.pfCooldownText:SetFrameLevel(cooldown:GetParent():GetFrameLevel() + 2)
    cooldown.pfCooldownText.text = cooldown.pfCooldownText:CreateFontString("pfCooldownFrameText", "OVERLAY")

    if not cooldown.pfCooldownType then
      size = tonumber(C.appearance.cd.font_size_foreign)
    elseif cooldown.pfCooldownType == "BLIZZARD" then
      size = tonumber(C.appearance.cd.font_size_blizz)
    elseif cooldown.pfCooldownSize then
      size = tonumber(cooldown.pfCooldownSize)
    else
      size = tonumber(C.appearance.cd.font_size)
    end

    cooldown.pfCooldownText.size = size
    local pos = C.appearance.cd.pos or "CENTER"
    cooldown.pfCooldownText.text:SetPoint(pos, cooldown.pfCooldownText, pos, 0, 0)
    cooldown.pfCooldownText:SetScript("OnUpdate", pfCooldownOnUpdate)
  end

  -- the numbers' size: as set, or (dynamic) following the button's height - again
  -- whenever that height changes (octo: the button resized in layout mode or the
  -- options; idea from brues-code's pfUI fork)
  local function pfCooldownFont(cooldown)
    local size = cooldown.pfCooldownText.size or 12
    local h
    if C.appearance.cd.dynamicsize == "1" and cooldown.GetParent then
      h = cooldown:GetParent() and cooldown:GetParent():GetHeight() or cooldown:GetHeight() or 0
      size = math.max((h > 0 and h * .64 or 16), size)
    end
    cooldown.pfCooldownText.height = h
    cooldown.pfCooldownText.fontsize = size
    cooldown.pfCooldownText.grown = nil
    cooldown.pfCooldownText.text:SetFont(pfUI.media[C.appearance.cd.font], size, "OUTLINE")
  end

  -- hook
  local function SetCooldown(this, start, duration, enable)
    -- abort on unknown frames
    if C.appearance.cd.foreign == "0" and not this.pfCooldownType then
      return
    end

    -- add support for omnicc's disable flag
    if this.noCooldownCount then
      return
    end

    -- realign cooldown frames
    local parent = this.GetParent and this:GetParent()
    if parent and parent:GetWidth() / 36 > 0 then
      this:SetScale(parent:GetWidth() / 36)
      this:SetPoint("TOPLEFT", parent, "TOPLEFT", -1, 1)
      this:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 1, -1)
    end

    -- don't draw global cooldowns
    if this.pfCooldownType == "NOGCD" and duration < tonumber(C.appearance.cd.threshold) then
      start, duration = 0, 0
    end

    -- disable GCDs on non pfUI frames
    if not this.pfCooldownType and duration < tonumber(C.appearance.cd.threshold) then
      start, duration = 0, 0
    end

    -- the sweep's direction (octo, 28 Oct 2026; brues-code's fork): ClassicAPI's
    -- cooldown frames have SetReverse - the stock 1.12 swipe has not, so nothing happens there
    local rev = this.pfCooldownReverse or 0
    if this.SetReverse and this.octoReverse ~= rev then
      this:SetReverse(rev == 1)
      this.octoReverse = rev
    end

    -- hide animation
    if this.pfCooldownStyleAnimation == 0 then
      this:SetAlpha(0)
    elseif not this.pfCooldownStyleAnimation and C.appearance.cd.hideanim == "1" then
      this:SetAlpha(0)
    end

    -- print time as text on cooldown frames
    if ( not this.pfCooldownStyleText or this.pfCooldownStyleText == 1)
    and start > 0 and duration > 0 and (not enable or enable > 0) then
      if( not this.pfCooldownText ) then
        pfCreateCoolDown(this, start, duration)
        pfCooldownFont(this)
      elseif C.appearance.cd.dynamicsize == "1" then
        local p = this:GetParent()
        local h = p and p:GetHeight() or this:GetHeight() or 0
        if h ~= this.pfCooldownText.height then pfCooldownFont(this) end
      end

      this.pfCooldownText.start = start
      this.pfCooldownText.duration = duration
      this.pfCooldownText.finished = nil
      this.pfCooldownText:Show()
    elseif(this.pfCooldownText) then
      this.pfCooldownText:Hide()
    end
  end

  if pfUI.expansion == "vanilla" then
    -- vanilla does not have a cooldown frame type, so we hook the
    -- regular SetTimer function that each one is calling.
    hooksecurefunc("CooldownFrame_SetTimer", SetCooldown)
  else
    -- tbc and later expansion have a cooldown frametype, so we can
    -- hook directly into the frame creation and add our function there.
    local methods = getmetatable(CreateFrame('Cooldown', nil, nil, 'CooldownFrameTemplate')).__index
    hooksecurefunc(methods, 'SetCooldown', SetCooldown)
  end
end)
