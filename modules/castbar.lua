pfUI:RegisterModule("castbar", "vanilla:tbc", function ()
  local font = C.castbar.use_unitfonts == "1" and pfUI.font_unit or pfUI.font_default
  local font_size = C.castbar.use_unitfonts == "1" and C.global.font_unit_size or C.global.font_size
  local rawborder, default_border = GetBorderSize("unitframes")
  local cbtexture = pfUI.media[C.appearance.castbar.texture]

  local function CreateCastbar(name, parent, unitstr, unitname)
    local cb = CreateFrame("Frame", name, parent or UIParent)

    cb:SetHeight(C.global.font_size * 1.5)
    cb:SetFrameStrata("MEDIUM")
    cb:SetFrameLevel(8)

    cb.unitstr = unitstr
    cb.unitname = unitname

    -- icon
    cb.icon = CreateFrame("Frame", nil, cb)
    cb.icon:SetPoint("TOPLEFT", 0, 0)
    cb.icon:SetHeight(16)
    cb.icon:SetWidth(16)

    cb.icon.texture = cb.icon:CreateTexture(nil, "OVERLAY")
    cb.icon.texture:SetAllPoints()
    cb.icon.texture:SetTexCoord(.08, .92, .08, .92)
    CreateBackdrop(cb.icon, default_border)

    -- statusbar
    cb.bar = CreateFrame("StatusBar", nil, cb)
    cb.bar:SetStatusBarTexture(cbtexture)
    cb.bar:ClearAllPoints()
    cb.bar:SetAllPoints(cb)
    cb.bar:SetMinMaxValues(0, 100)
    cb.bar:SetValue(20)
    local r,g,b,a = strsplit(",", C.appearance.castbar.castbarcolor)
    cb.bar:SetStatusBarColor(r,g,b,a)
    CreateBackdrop(cb.bar, default_border)
    CreateBackdropShadow(cb.bar)

    -- text left
    cb.bar.left = cb.bar:CreateFontString("Status", "DIALOG", "GameFontNormal")
    cb.bar.left:ClearAllPoints()
    cb.bar.left:SetPoint("TOPLEFT", cb.bar, "TOPLEFT", 3 + C.castbar[unitstr].txtleftoffx, C.castbar[unitstr].txtleftoffy)
    cb.bar.left:SetPoint("BOTTOMRIGHT", cb.bar, "BOTTOMRIGHT", -3 + C.castbar[unitstr].txtleftoffx, C.castbar[unitstr].txtleftoffy)
    cb.bar.left:SetNonSpaceWrap(false)
    cb.bar.left:SetFontObject(GameFontWhite)
    cb.bar.left:SetTextColor(1,1,1,1)
    cb.bar.left:SetFont(font, font_size, "OUTLINE")
    cb.bar.left:SetJustifyH("left")

    -- text right
    cb.bar.right = cb.bar:CreateFontString("Status", "DIALOG", "GameFontNormal")
    cb.bar.right:ClearAllPoints()
    cb.bar.right:SetPoint("TOPLEFT", cb.bar, "TOPLEFT", 3 + C.castbar[unitstr].txtrightoffx, C.castbar[unitstr].txtrightoffy)
    cb.bar.right:SetPoint("BOTTOMRIGHT", cb.bar, "BOTTOMRIGHT", -3 + C.castbar[unitstr].txtrightoffx, C.castbar[unitstr].txtrightoffy)
    cb.bar.right:SetNonSpaceWrap(false)
    cb.bar.right:SetFontObject(GameFontWhite)
    cb.bar.right:SetTextColor(1,1,1,1)
    cb.bar.right:SetFont(font, font_size, "OUTLINE")
    cb.bar.right:SetJustifyH("right")

    cb.bar.lag = cb.bar:CreateTexture(nil, "OVERLAY")
    cb.bar.lag:SetPoint("TOPRIGHT", cb.bar, "TOPRIGHT", 0, 0)
    cb.bar.lag:SetPoint("BOTTOMRIGHT", cb.bar, "BOTTOMRIGHT", 0, 0)
    cb.bar.lag:SetTexture(1,.2,.2,.2)

    -- octo: the time a cast lost to pushback, a red stretch at the end of the bar
    cb.bar.push = cb.bar:CreateTexture(nil, "OVERLAY")
    cb.bar.push:SetPoint("TOPRIGHT", cb.bar, "TOPRIGHT", 0, 0)
    cb.bar.push:SetPoint("BOTTOMRIGHT", cb.bar, "BOTTOMRIGHT", 0, 0)
    cb.bar.push:SetTexture("Interface\\Buttons\\WHITE8X8")
    cb.bar.push:SetVertexColor(1, .15, .15, .55)
    cb.bar.push:Hide()

    cb:SetScript("OnUpdate", function()
      if this.drag and this.drag:IsShown() then
        this:SetAlpha(1)
        return
      end
      -- octo (17 Nov 2026, /pfperf: 6.6 ms a second over the three bars with nothing cast): a bar that is idle and
      -- faded out asks for a cast 30 times a second, not every frame; a cast event (OnEvent) wakes it at once
      if this.restUntil then
        if this.restUntil > GetTime() then return end
        this.restUntil = nil
      end

      if not UnitExists(this.unitstr) then
        this:SetAlpha(0)
      end

      if this.fadeout and this:GetAlpha() > 0 then
        if this:GetAlpha() == 0 then
          this.fadeout = nil
        end

        this:SetAlpha(this:GetAlpha()-0.05)
      end

      local channel = nil
      local query = this.unitstr ~= "" and this.unitstr or this.unitname
      if not query then return end

      -- transform all non player unitstrings to unit guids
      if superwow_active and this.unitstr and not UnitIsUnit(this.unitstr, 'player') then
        local _, guid = UnitExists(this.unitstr)
        query = guid or query
      end

      -- Octo: with ClassicAPI (libcast) two more returns: can't be interrupted, pushback in ms
      local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill, noint, delayMs = UnitCastingInfo(query)
      if not cast then
        -- scan for channel spells if no cast was found
        channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill, noint = UnitChannelInfo(query)
        cast = channel
      end
      -- (ClassicAPI's own figure wins: the delay events would count the same pushback a second time)
      if delayMs then this.capiDelay = true end
      if delayMs and delayMs > 0 then this.delay = delayMs / 1000 end

      -- octo (29 Oct 2026; user: pushback "available for both players ... a live count of the knockback on
      -- his target"): for anyone but you, the pushback is how far the cast's end moved since it began
      -- (ClassicAPI moves it on every hit; its own pushback figure is only for your casts). Channels lose
      -- time instead: their end comes nearer.
      if cast then
        if this.castStart ~= startTime then
          this.castStart, this.origEnd, this.otherDelay = startTime, endTime, nil
          this.capiDelay = delayMs and true or nil
          if this.unitstr ~= "player" then this.delay = 0 end
        end
        if not delayMs and this.origEnd and this.unitstr and this.unitstr ~= "player" and not UnitIsUnit(this.unitstr, "player") then
          local d = (channel and (this.origEnd - endTime) or (endTime - this.origEnd)) / 1000
          if d > .05 then this.delay, this.otherDelay = d, true end
        end
      else
        this.castStart, this.origEnd = nil, nil
      end

      if cast then
        local duration = endTime - startTime
        local max = duration / 1000
        local cur = GetTime() - startTime / 1000

        this:SetAlpha(1)

        local spellname = this.showname and cast and cast .. " " or ""
        local rank = this.showrank and nameSubtext and nameSubtext ~= "" and string.format("|cffaaffcc[%s]|r", nameSubtext) or ""

        if this.endTime ~= endTime or this.noint ~= noint then
          this.noint = noint
          local colour = noint and C.appearance.castbar.nointcolor or C.appearance.castbar[(channel and "channelcolor" or "castbarcolor")]
          this.bar:SetStatusBarColor(strsplit(",", colour))
          this.bar:SetMinMaxValues(0, duration / 1000)
          this.bar.left:SetText(spellname .. rank)
          this.fadeout = nil
          this.endTime = endTime

          -- set texture
          if texture and this.showicon then
            local size = this:GetHeight()
            this.icon:Show()
            this.icon:SetHeight(size)
            this.icon:SetWidth(size)
            this.icon.texture:SetTexture(texture)
            this.bar:SetPoint("TOPLEFT", this.icon, "TOPRIGHT", this.spacing, 0)
          else
            this.bar:SetPoint("TOPLEFT", this, 0, 0)
            this.icon:Hide()
          end

          if this.showlag then
            local _, _, lag = GetNetStats()
            local width = this:GetWidth() / (duration/1000) * (lag/1000)
            this.bar.lag:SetWidth(math.min(this:GetWidth(), width))
          else
            this.bar.lag:Hide()
          end
        end

        if channel then
          cur = max + startTime/1000 - GetTime()
        end

        cur = cur > max and max or cur
        cur = cur < 0 and 0 or cur

        this.bar:SetValue(cur)

        -- the pushback as a red stretch: the time it cost, to scale with the bar. A cast's end moved
        -- out, so its last part is the extra time (red at the right end); a channel's end came nearer,
        -- so the time it lost is shown where it would have run on to (red at the left end, where a
        -- channel bar runs out), as a share of the whole channel it was
        if this.showpush and this.delay and this.delay > 0 and max > 0 then
          local bw = this.bar:GetWidth() or 0
          if bw <= 0 then bw = this:GetWidth() or 0 end
          local share = channel and (this.delay / (max + this.delay)) or (this.delay / max)
          local w = bw * math.min(1, share)
          this.bar.push:ClearAllPoints()
          local side = channel and "LEFT" or "RIGHT"
          this.bar.push:SetPoint("TOP" .. side, this.bar, "TOP" .. side, 0, 0)
          this.bar.push:SetPoint("BOTTOM" .. side, this.bar, "BOTTOM" .. side, 0, 0)
          if w >= 1 then
            this.bar.push:SetWidth(w)
            this.bar.push:Show()
          else
            this.bar.push:Hide()
          end
        else
          this.bar.push:Hide()
        end

        -- the timer text only when its tenth of a second (or the delay) changes
        local tenth = math.floor(cur * 10)
        if this.showtimer and (tenth ~= this.lasttenth or this.delay ~= this.lastdelay) then
          this.lasttenth, this.lastdelay = tenth, this.delay
          if this.delay and this.delay > 0 then
            local delay = "|cffffaaaa" .. (channel and "-" or "+") .. round(this.delay,1) .. " |r "
            this.bar.right:SetText(delay .. string.format("%.1f",cur) .. " / " .. round(max,1))
          else
            this.bar.right:SetText(string.format("%.1f",cur) .. " / " .. round(max,1))
          end
        end

        this.fadeout = nil
      elseif this.endTime or not this.idle then
        -- the cast just ended: full bar fading out, set once (pfUI set it on
        -- every frame while nothing was cast). Your own cast stopped by an
        -- interrupt or a failure flashes red (from the ClassicAPI pfUI fork).
        this.endTime, this.idle, this.lasttenth = nil, true, nil
        this.bar:SetMinMaxValues(1,100)
        this.bar:SetValue(100)
        if this.failedAt and GetTime() - this.failedAt < .4 then
          this.bar:SetStatusBarColor(1, .15, .15, 1)
        end
        this.failedAt = nil
        this.fadeout = 1
        this.delay = 0
        this.bar.push:Hide()
      end
      if cast then
        this.idle = nil
      elseif this.idle and (this:GetAlpha() or 0) <= 0 then
        local trusted = this.unitstr and pfUI.castbar.evSeen and pfUI.castbar.evSeen[this.unitstr]
        this.restUntil = GetTime() + (trusted and 1 or 1 / 30)
      end
    end)

    -- your own cast interrupted or failed (vanilla events): the bar flashes red
    if pfUI.client <= 11200 then
      local fail = CreateFrame("Frame", nil, cb)
      fail:RegisterEvent("SPELLCAST_INTERRUPTED")
      fail:RegisterEvent("SPELLCAST_FAILED")
      fail:SetScript("OnEvent", function()
        local bar = this:GetParent()
        if bar.unitstr == "player" and bar.endTime then bar.failedAt = GetTime() end
      end)
    end

    -- register for spell delay
    local playerarg = nil
    cb:RegisterEvent(CASTBAR_EVENT_CAST_DELAY)
    cb:RegisterEvent(CASTBAR_EVENT_CHANNEL_DELAY)
    cb:RegisterEvent(CASTBAR_EVENT_CAST_START)
    cb:RegisterEvent(CASTBAR_EVENT_CHANNEL_START)
    cb:SetScript("OnEvent", function()
      this.restUntil = nil
      if this.unitstr and not UnitIsUnit(this.unitstr, "player") then return end
      playerarg = pfUI.client <= 11200 or arg1 == "player" and true or nil

      if event == CASTBAR_EVENT_CAST_DELAY and playerarg and this.capiDelay then
        -- (ClassicAPI already gives the pushback: not counted twice)
      elseif event == CASTBAR_EVENT_CAST_DELAY and playerarg then
        local isCast, nameSubtext, text, texture, startTime, endTime, isTradeSkill = UnitCastingInfo(this.unitstr or this.unitname)
        if not isCast then return end
        if not this.endTime then return end
        this.delay = this.delay + (endTime - this.endTime) / 1000
      elseif event == CASTBAR_EVENT_CHANNEL_DELAY and playerarg then
        local isChannel, _, _, _, startTime, endTime = UnitChannelInfo(this.unitstr or this.unitname)
        if not isChannel then return end
        this.delay = ( this.delay or 0 ) + this.bar:GetValue() - (endTime/1000 - GetTime())
      elseif playerarg then
        this.delay = 0
        this.bar.push:Hide()
      end
    end)

    cb:SetAlpha(0)
    return cb
  end

  pfUI.castbar = CreateFrame("Frame", "pfCastBar", UIParent)

  -- hide blizzard
  if C.castbar.player.hide_blizz == "1" then
    CastingBarFrame:SetScript("OnShow", function() CastingBarFrame:Hide() end)
    CastingBarFrame:UnregisterAllEvents()
    CastingBarFrame:Hide()
  end

  -- [[ pfPlayerCastbar ]] --
  if C.castbar.player.hide_pfui == "0" then
    pfUI.castbar.player = CreateCastbar("pfPlayerCastbar", UIParent, "player")
    pfUI.castbar.player.showicon = C.castbar.player.showicon == "1" and true or nil
    pfUI.castbar.player.showname = C.castbar.player.showname == "1" and true or nil
    pfUI.castbar.player.showtimer = C.castbar.player.showtimer == "1" and true or nil
    pfUI.castbar.player.showlag = C.castbar.player.showlag == "1" and true or nil
    pfUI.castbar.player.showpush = C.castbar.player.showpush ~= "0" and true or nil
    pfUI.castbar.player.showrank = C.castbar.player.showrank == "1" and true or nil
    pfUI.castbar.player.spacing = default_border * 2 + tonumber(C.unitframes.player.pspace) * GetPerfectPixel()

    if pfUI.uf.player then
      local anchor = pfUI.uf.player.portrait:GetHeight() > pfUI.uf.player:GetHeight() and pfUI.uf.player.power or pfUI.uf.player
      local width = C.castbar.player.width ~= "-1" and C.castbar.player.width or anchor:GetWidth()
      pfUI.castbar.player:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -pfUI.castbar.player.spacing)
      pfUI.castbar.player:SetWidth(width)
    else
      local width = C.castbar.player.width ~= "-1" and C.castbar.player.width or 200
      pfUI.castbar.player:SetPoint("CENTER", 0, -200)
      pfUI.castbar.player:SetWidth(width)
    end

    if C.castbar.player.height ~= "-1" then
      pfUI.castbar.player:SetHeight(C.castbar.player.height)
    end

    UpdateMovable(pfUI.castbar.player)

    -- octo: nampower's spell queue (SPELL_QUEUE_EVENT; idea from the ClassicAPI
    -- pfUI fork): the spell you queued shows at the bar's right end until it
    -- goes off. Nothing without nampower (the plain client cannot tell).
    if GetNampowerVersion and C.castbar.player.spellqueue == "1" then
      local cb = pfUI.castbar.player
      local q = CreateFrame("Frame", "pfSpellQueue", UIParent)
      q:SetFrameStrata("HIGH")
      q:SetPoint("LEFT", cb, "RIGHT", default_border * 3, 0)
      q.icon = q:CreateTexture(nil, "OVERLAY")
      q.icon:SetAllPoints(q)
      q.icon:SetTexCoord(.08, .92, .08, .92)
      CreateBackdrop(q)
      q:Hide()
      q:RegisterEvent("SPELL_QUEUE_EVENT")
      q:SetScript("OnEvent", function()
        -- arg1: 0 / 2 / 4 = queued (on swing / normal / off the GCD), 1 / 3 / 5 = it went
        local code, id = tonumber(arg1), tonumber(arg2)
        if code == 0 or code == 2 or code == 4 then
          local lc = pfUI.api.libclient
          local tex = lc and lc.SpellIcon and lc.SpellIcon(id)
          if not tex then return end
          local size = math.max(cb:GetHeight(), 14)
          this:SetWidth(size)
          this:SetHeight(size)
          this.icon:SetTexture(tex)
          this.till = GetTime() + 5
          this:Show()
        elseif code == 1 or code == 3 or code == 5 then
          this:Hide()
        end
      end)
      -- a queue that never reports going off is cleared after 5 s
      q:SetScript("OnUpdate", function()
        if (this.till or 0) < GetTime() then this:Hide() end
      end)
      pfUI.castbar.queue = q
    end
  end

  -- [[ pfTargetCastbar ]] --
  if C.castbar.target.hide_pfui == "0" then
    pfUI.castbar.target = CreateCastbar("pfTargetCastbar", UIParent, "target")
    pfUI.castbar.target.showicon = C.castbar.target.showicon == "1" and true or nil
    pfUI.castbar.target.showname = C.castbar.target.showname == "1" and true or nil
    pfUI.castbar.target.showtimer = C.castbar.target.showtimer == "1" and true or nil
    pfUI.castbar.target.showlag = C.castbar.target.showlag == "1" and true or nil
    pfUI.castbar.target.showpush = C.castbar.target.showpush ~= "0" and true or nil
    pfUI.castbar.target.showrank = C.castbar.target.showrank == "1" and true or nil
    pfUI.castbar.target.spacing = default_border * 2 + tonumber(C.unitframes.target.pspace) * GetPerfectPixel()

    if pfUI.uf.target then
      local anchor = pfUI.uf.target.portrait:GetHeight() > pfUI.uf.target:GetHeight() and pfUI.uf.target.power or pfUI.uf.target
      local width = C.castbar.target.width ~= "-1" and C.castbar.target.width or anchor:GetWidth()
      pfUI.castbar.target:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -pfUI.castbar.target.spacing)
      pfUI.castbar.target:SetWidth(width)
    else
      local width = C.castbar.target.width ~= "-1" and C.castbar.target.width or 200
      pfUI.castbar.target:SetPoint("CENTER", 0, -225)
      pfUI.castbar.target:SetWidth(width)
    end

    if C.castbar.target.height ~= "-1" then
      pfUI.castbar.target:SetHeight(C.castbar.target.height)
    end

    UpdateMovable(pfUI.castbar.target)
  end

  -- [[ pfFocusCastbar ]] --
  if C.castbar.focus.hide_pfui == "0" and pfUI.uf.focus then
    pfUI.castbar.focus = CreateCastbar("pfFocusCastbar", UIParent, "focus")
    pfUI.castbar.focus.showicon = C.castbar.focus.showicon == "1" and true or nil
    pfUI.castbar.focus.showname = C.castbar.focus.showname == "1" and true or nil
    pfUI.castbar.focus.showtimer = C.castbar.focus.showtimer == "1" and true or nil
    pfUI.castbar.focus.showlag = C.castbar.focus.showlag == "1" and true or nil
    pfUI.castbar.focus.showpush = C.castbar.focus.showpush ~= "0" and true or nil
    pfUI.castbar.focus.showrank = C.castbar.focus.showrank == "1" and true or nil
    pfUI.castbar.focus.spacing = default_border * 2 + tonumber(C.unitframes.focus.pspace) * GetPerfectPixel()

    -- reset unitstr for vanilla focus frame emulation
    if pfUI.client <= 11200 then
      pfUI.castbar.focus.unitstr = nil
    end

    local anchor = pfUI.uf.focus.portrait:GetHeight() > pfUI.uf.focus:GetHeight() and pfUI.uf.focus.power or pfUI.uf.focus
    local width = C.castbar.focus.width ~= "-1" and C.castbar.focus.width or anchor:GetWidth()
    pfUI.castbar.focus:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -pfUI.castbar.focus.spacing)
    pfUI.castbar.focus:SetWidth(width)

    if C.castbar.focus.height ~= "-1" then
      pfUI.castbar.focus:SetHeight(C.castbar.focus.height)
    end

    -- keep unit values in sync with focus unitframe
    HookScript(pfUI.castbar.focus, "OnUpdate", function()
      -- clear on empty focus frames
      if pfUI.uf.focus.unitname == nil and pfUI.uf.focus.label == nil then
        pfUI.castbar.focus.unitstr = nil
        pfUI.castbar.focus.unitname = nil
        return
      end

      -- skip on initial values
      if pfUI.uf.focus.unitname == "focus" then return end
      if pfUI.uf.focus.unitname == "" then return end

      -- try to obtain a unitstr
      pfUI.castbar.focus.unitstr = string.format("%s%s", (pfUI.uf.focus.label or ""), (pfUI.uf.focus.id or ""))
      pfUI.castbar.focus.unitstr = pfUI.castbar.focus.unitstr == "" and nil or pfUI.castbar.focus.unitstr

      if pfUI.castbar.focus.unitstr then
        -- read non-lowercase unitname when possible
        pfUI.castbar.focus.unitname = UnitName(pfUI.castbar.focus.unitstr) or pfUI.castbar.focus.unitname
      elseif strlower(pfUI.castbar.focus.unitname) ~= strlower(pfUI.uf.focus.unitname) then
        -- sync unitname with focus frame's lowercase value
        pfUI.castbar.focus.unitname = pfUI.uf.focus.unitname
      end
    end)

    UpdateMovable(pfUI.castbar.focus)
  end

  -- octo (17 Nov 2026): ClassicAPI's UNIT_SPELLCAST_* events (arg1 = the unit token; each token a caster has
  -- gets its own copy) wake the bar of that unit at once. Once one has come for a unit, that bar trusts them:
  -- idle and faded out it looks only once a second (a safety net) instead of 30 times. Until then: 30 times.
  pfUI.castbar.evSeen = pfUI.castbar.evSeen or {}
  local function Wake(unit)
    for _, key in ipairs({ "player", "target", "focus" }) do
      local cb = pfUI.castbar[key]
      if cb and cb.unitstr and cb.unitstr ~= "" and cb.unitstr == unit then cb.restUntil = nil end
    end
  end
  if libclient and libclient.On then
    for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_STOP",
        "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_UPDATE",
        "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }) do
      libclient.On(e, function(_, unit)
        if type(unit) ~= "string" then return end
        pfUI.castbar.evSeen[unit] = true
        Wake(unit)
      end)
    end
    libclient.On("PLAYER_TARGET_CHANGED", function() Wake("target") end)
    libclient.On("PLAYER_FOCUS_CHANGED", function() Wake("focus") end)
  end
end)
