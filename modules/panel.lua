pfUI:RegisterModule("panel", "vanilla:tbc", function()
  -- initialize gold cache if not yet happened
  pfUI_cache["gold"] = pfUI_cache["gold"] or {}

  -- octo (25 Oct 2026, user: "There was one underneath before ... not sure where
  -- that has gone"): the bar under the map (zone name) had been set to "none" -
  -- put it back once; the Minimap page can still hide it
  if C.panel.other.minimap == "none" and (not C.mapstyle or C.mapstyle.barback ~= "1") then
    C.panel.other.minimap = (C.mapstyle and C.mapstyle.barwas and C.mapstyle.barwas ~= "none" and C.mapstyle.barwas) or "zone"
  end
  if C.mapstyle then C.mapstyle.barback = "1" end

  local font = C.panel.use_unitfonts == "1" and pfUI.font_unit or pfUI.font_default
  local font_size = C.panel.use_unitfonts == "1" and C.global.font_unit_size or C.global.font_size
  local rawborder, default_border = GetBorderSize("panels")

  do -- Widgets
    do -- Clock & Timer
      local widget = CreateFrame("Frame", "pfPanelWidgetClock",UIParent)
      widget.Tooltip = function()
        GameTooltip:ClearLines()
        GameTooltip_SetDefaultAnchor(GameTooltip, this)
        local h, m = GetGameTime()
        local noon = " AM"
        local servertime
        local time
        if C.global.twentyfour == "0" then
          if h == 0 then
            h = 12
          elseif h == 12 then
            noon = " PM"
          elseif h > 12 then
            h = h - 12
            noon = " PM"
          end
          time = date("%I:%M %p")
          servertime = string.format("%.2d:%.2d %s", h, m, noon)
        else
          time = date("%H:%M")
          servertime = string.format("%.2d:%.2d", h, m)
        end
        GameTooltip:AddLine("|cff555555" .. T["Time"])
        GameTooltip:AddDoubleLine(T["Localtime"],  "|cffffffff" .. time)
        GameTooltip:AddDoubleLine(T["Servertime"], "|cffffffff".. servertime)
        GameTooltip:AddLine(" ")
        if TimeManagerFrame then
          GameTooltip:AddDoubleLine(T["Left Click"], "|cffffffff" .. T["Show/Hide TimeManager"])
        else
          GameTooltip:AddDoubleLine(T["Left Click"], "|cffffffff" .. T["Show/Hide Timer"])
          GameTooltip:AddDoubleLine(T["Right Click"], "|cffffffff" .. T["Reset Timer"])
        end
        GameTooltip:Show()
      end
      widget.Click = function()
        this:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        if TimeManagerFrame then
          if TimeManagerClockButton.alarmFiring then
            TimeManager_TurnOffAlarm()
          end
          ToggleTimeManager()
          return
        end
        if arg1 == "LeftButton" then
          if widget.timerFrame:IsShown() then
            widget.timerFrame:Hide()
          else
            widget.timerFrame:Show()
          end
        elseif arg1 == "RightButton" then
          widget.timerFrame.Snapshot = GetTime()
        end
      end
      widget:SetScript("OnUpdate",function()
        if ( this.tick or 1) > GetTime() then return else this.tick = GetTime() + 1 end

        local h, m = GetGameTime()
        local noon = "AM"
        local time = ""
        local secondsenabled = C.panel.seconds == "1"
        if C.global.twentyfour == "0" then
          if C.global.servertime == "1" then
            if h == 0 then
              h = 12
            elseif h == 12 then
              noon = "PM"
            elseif h > 12 then
              h = h - 12
              noon = "PM"
            end
            time = string.format("%.2d:%.2d %s", h, m, noon)
          else
            if secondsenabled then
              time = date("%I:%M:%S %p")
            else
              time = date("%I:%M %p")
            end
          end
        else
          if C.global.servertime == "1" then
            time = string.format("%.2d:%.2d", h, m)
          else
            if secondsenabled then
              time = date("%H:%M:%S")
            else
              time = date("%H:%M")
            end
          end
        end
        pfUI.panel:OutputPanel("time", time, widget.Tooltip, widget.Click)
      end)

      widget.timerFrame = CreateFrame("Frame", "pfUITimer", UIParent)
      widget.timerFrame:Hide()
      widget.timerFrame:SetWidth(120)
      widget.timerFrame:SetHeight(35)
      widget.timerFrame:SetPoint("TOP", 0, -100)
      UpdateMovable(widget.timerFrame)

      widget.timerFrame.text = widget.timerFrame:CreateFontString("Status", "LOW", "GameFontNormal")
      widget.timerFrame.text:SetFontObject(GameFontWhite)
      widget.timerFrame.text:SetFont(font, font_size, "OUTLINE")
      widget.timerFrame.text:SetAllPoints(widget.timerFrame)
      widget.timerFrame:SetScript("OnUpdate", function()
          if not widget.timerFrame.Snapshot then widget.timerFrame.Snapshot = GetTime() end
          widget.timerFrame.curTime = SecondsToTime(floor(GetTime() - widget.timerFrame.Snapshot))
          if widget.timerFrame.curTime ~= "" then
            widget.timerFrame.text:SetText("|c33cccccc" .. widget.timerFrame.curTime)
          else
            widget.timerFrame.text:SetText("|cffff3333 --- " .. T["NEW TIMER"] .. " ---")
          end
        end)

      -- Combat Timer
      widget.combat = CreateFrame("Frame", "pfUICombatTimer", UIParent)
      widget.combat:RegisterEvent("PLAYER_ENTERING_WORLD")
      widget.combat:RegisterEvent("PLAYER_REGEN_ENABLED")
      widget.combat:RegisterEvent("PLAYER_REGEN_DISABLED")
      widget.combat:SetScript("OnEvent", function()
        if event == "PLAYER_REGEN_DISABLED" then
          if UnitAffectingCombat("player") and not this.combat then
            this.combat = GetTime()
          end

        elseif event == "PLAYER_REGEN_ENABLED" then
          if this.combat then
            this.lastcombat = GetTime() - this.combat
            this.combat = nil
            pfUI.panel:OutputPanel("combat", "|cffffffff" .. SecondsToTime(ceil(this.lastcombat)))
          end

        elseif event == "PLAYER_ENTERING_WORLD" then
          pfUI.panel:OutputPanel("combat", T["Combat"] .. ": " .. NOT_APPLICABLE)
        end
      end)
      widget.combat:SetScript("OnUpdate", function()
        if not this.tick then this.tick = GetTime() end
        if GetTime() <= this.tick + 1 then return else this.tick = GetTime() end
        if this.combat then
          pfUI.panel:OutputPanel("combat", "|cffffaaaa" .. SecondsToTime(ceil(GetTime() - this.combat)))
        end
      end)
    end

    do -- FPS & Lag
      local widget = CreateFrame("Frame", "pfPanelWidgetLag", UIParent)
      local lag, fps, laghex, fpshex, _
      widget.Tooltip = function()
        local active = 0
        GameTooltip:ClearLines()
        GameTooltip_SetDefaultAnchor(GameTooltip, this)
        GameTooltip:AddLine("|cff555555" .. T["Systeminfo"])
        for i=1, GetNumAddOns() do
          if IsAddOnLoaded(i) then
            active = active + 1
          end
        end

        local memkb, gckb = gcinfo()
        local memmb = memkb and memkb > 0 and round((memkb or 0)/1000, 2) .. " MB" or UNAVAILABLE
        local gcmb = gckb and gckb > 0 and round((gckb or 0)/1000, 2) .. " MB" or UNAVAILABLE

        local nin, nout, nping = GetNetStats()

        GameTooltip:AddDoubleLine(T["Active Addons"], "|cffffffff" .. active .. "|cff555555 / |cffffffff" .. GetNumAddOns())
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(T["Memory Usage"], "|cffffffff" .. memmb)
        GameTooltip:AddDoubleLine(T["Next Memory Cleanup"], "|cffffffff" .. gcmb)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(T["Network Down"], "|cffffffff" .. round(nin,1) .. "KB/s")
        GameTooltip:AddDoubleLine(T["Network Up"], "|cffffffff" .. round(nout,1) .. "KB/s")
        GameTooltip:AddDoubleLine(T["Network Latency"], "|cffffffff" .. nping .. "ms")
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(T["Graphic Renderer"], "|cffffffff" .. GetCVar("gxApi"))
        GameTooltip:AddDoubleLine(T["Screen Resolution"], "|cffffffff" .. GetCVar("gxResolution"))
        GameTooltip:AddDoubleLine(T["UI-Scale"], "|cffffffff" .. round(UIParent:GetEffectiveScale(),2))
        GameTooltip:Show()
      end
      widget.Click = function()
        if pfUI.addons and pfUI.addons:IsShown() then
          pfUI.addons:Hide()
        elseif pfUI.addons then
          pfUI.addons:Show()
        end
      end
      widget:SetScript("OnUpdate",function()
        if ( this.tick or 1) > GetTime() then return else this.tick = GetTime() + 1 end

        fps = floor(GetFramerate())
        _, _, lag = GetNetStats()

        if C.panel.fpscolors == "1" then
          _, _, _, fpshex = GetColorGradient(fps/60)
          _, _, _, laghex = GetColorGradient(60/lag)
          fps = fpshex .. fps .. "|r"
          lag = laghex .. lag .. "|r"
        end

        pfUI.panel:OutputPanel("fps", fps .. " " .. T["fps"] .. " & " .. lag .. " " .. T["ms"], widget.Tooltip, widget.Click)
      end)
    end

    do -- XP & Kills To Level
      local widget = CreateFrame("Frame", "pfPanelWidgetXP", UIParent)
      local curexp, difexp, maxexp, remexp, oldexp, remstring
      widget:RegisterEvent("PLAYER_ENTERING_WORLD")
      widget:RegisterEvent("PLAYER_XP_UPDATE")
      widget:SetScript("OnEvent", function()
        if UnitLevel("player") < _G.MAX_PLAYER_LEVEL then
          curexp = UnitXP("player")
          if oldexp ~= nil then
            difexp = curexp - oldexp
            maxexp = UnitXPMax("player")
            if difexp > 0 then
              remexp = floor((maxexp - curexp)/difexp)
              remstring = "|cff555555 [" .. remexp .. "]|r"
            else
              remstring = nil
            end
          end
          oldexp = curexp

          local a=UnitXP("player")
          local b=UnitXPMax("player")
          local xprested = tonumber(GetXPExhaustion())
          if remstring == nil then remstring = "" end
          if xprested ~= nil then
            pfUI.panel:OutputPanel("exp", T["Exp"] .. ": |cffaaaaff"..floor((a/b)*100).."%"..remstring)
          else
            pfUI.panel:OutputPanel("exp", T["Exp"] .. ": " .. floor((a/b)*100) .. "%" .. remstring)
          end
        else
          pfUI.panel:OutputPanel("exp", T["Exp"] .. ": " .. NOT_APPLICABLE)
        end
      end)
    end

    do -- Bagspace
      local widget = CreateFrame("Frame", "pfPanelWidgetBag", UIParent)
      widget:RegisterEvent("PLAYER_ENTERING_WORLD")
      widget:RegisterEvent("BAG_UPDATE")
      widget:SetScript("OnEvent", function()
        local maxslots = 0
        local usedslots = 0

        for bag = 0,4 do
          if C.panel.bag.ignorespecial ~= "1" or GetBagFamily(bag) == "BAG" then
            local bagsize = GetContainerNumSlots(bag)
            maxslots = maxslots + bagsize
            for j = 1,bagsize do
              local link = GetContainerItemLink(bag,j)
              if link then
                usedslots = usedslots + 1
              end
            end
          end
        end
        local freeslots = maxslots - usedslots
        pfUI.panel:OutputPanel("bagspace", freeslots .. " (" .. usedslots .. "/" .. maxslots .. ")", nil, OpenAllBags)
      end)
    end

    do -- Gold
      local widget = CreateFrame("Frame", "pfPanelWidgetGold", UIParent)
      widget:RegisterEvent("PLAYER_ENTERING_WORLD")
      widget:RegisterEvent("PLAYER_MONEY")
      widget.Click = function()
        if IsShiftKeyDown() then
          -- read current data
          local realm = GetRealmName()
          local unit  = UnitName("player")
          local money = GetMoney()

          -- reset gold value and hide tooltip
          pfUI_cache["gold"][realm] = { [unit] = money }
          GameTooltip:Hide()
        else
          OpenAllBags()
        end
      end
      widget.Tooltip = function()
        local gold = floor(GetMoney()/ 10000)
        local silver = floor(mod((GetMoney()/100),100))
        local copper = floor(mod(GetMoney(),100))

        local dmod = ""
        if pfUI.panel.diffMoney < 0 then
          dmod = "|cffff8888-"
        elseif pfUI.panel.diffMoney > 0 then
          dmod = "|cff88ff88+"
        end

        GameTooltip_SetDefaultAnchor(GameTooltip, this)
        GameTooltip:ClearLines()

        GameTooltip:AddLine("|cff555555" .. T["Money"])
        GameTooltip:AddDoubleLine(T["Login"] .. ":", CreateGoldString(pfUI.panel.initMoney))
        GameTooltip:AddDoubleLine(T["Now"] .. ":", CreateGoldString(GetMoney()))
        GameTooltip:AddDoubleLine("|cffffffff","")
        local totalgold = 0
        for name, gold in pairs(pfUI_cache["gold"][GetRealmName()]) do
          totalgold = totalgold + gold
          if name ~= UnitName("player") then
            GameTooltip:AddDoubleLine(name .. ":", CreateGoldString(gold))
          end
        end
        GameTooltip:AddDoubleLine("|cffffffff","")
        GameTooltip:AddDoubleLine(T["This Session"] .. ":", dmod .. CreateGoldString(math.abs(pfUI.panel.diffMoney)))
        GameTooltip:AddDoubleLine(T["Total Gold"] .. ":", CreateGoldString(totalgold))
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(T["Shift-Click to reset all money totals"], .5, .5, .5, 1)
        GameTooltip:Show()
      end
      widget:SetScript("OnEvent", function()
        local realm = GetRealmName()
        local unit  = UnitName("player")
        local money = GetMoney()
        local goldstr = CreateGoldString(GetMoney())

        pfUI.panel.initMoney = pfUI.panel.initMoney or money
        pfUI.panel.diffMoney = money - pfUI.panel.initMoney

        pfUI_cache["gold"][realm] = pfUI_cache["gold"][realm] or {}
        pfUI_cache["gold"][realm][unit] = money

        pfUI.panel:OutputPanel("gold", goldstr, widget.Tooltip, widget.Click)
      end)
    end

    do -- Friends
      local widget = CreateFrame("Frame", "pfPanelWidgetFriends", UIParent)
      widget:RegisterEvent("PLAYER_ENTERING_WORLD")
      widget:RegisterEvent("FRIENDLIST_UPDATE")
      widget.Tooltip = function()
        local init = nil
        local all = GetNumFriends()
        local playerzone  = GetRealZoneText()

        for friendIndex=1, all do
          local friend_name, friend_level, friend_class, friend_area, friend_connected = GetFriendInfo(friendIndex)
          if friend_connected and friend_class and friend_level then
            if not init then
              GameTooltip_SetDefaultAnchor(GameTooltip, this)
              GameTooltip:ClearLines()
              GameTooltip:AddLine("|cff555555" .. T["Friends Online"])
              init = true
            end
            local ccolor = RAID_CLASS_COLORS[L["class"][friend_class]] or { 1, 1, 1 }
            local lcolor = GetDifficultyColor(tonumber(friend_level)) or { 1, 1, 1 }
            local zcolor = friend_area == playerzone and "|cff33ffcc" or "|cffcccccc"
            GameTooltip:AddDoubleLine(rgbhex(ccolor) .. friend_name .. rgbhex(lcolor) .. " [" .. friend_level .. "]", zcolor .. friend_area)
          end
        end

        GameTooltip:Show()
      end
      widget.Click = function() ToggleFriendsFrame(1) end
      widget:SetScript("OnEvent", function()
        local online = 0
        local all = GetNumFriends()
        for friendIndex=1, all do
          local friend_name, friend_level, friend_class, friend_area, friend_connected = GetFriendInfo(friendIndex)
          if ( friend_connected ) then
            online = online + 1
          end
        end

        pfUI.panel:OutputPanel("friends", FRIENDS .. ": " .. online, widget.Tooltip, widget.Click)
      end)
    end

    do -- Guild
      local widget = CreateFrame("Frame", "pfPanelWidgetGuild", UIParent)
      widget:RegisterEvent("PLAYER_ENTERING_WORLD")
      widget:RegisterEvent("GUILD_ROSTER_UPDATE")
      widget:RegisterEvent("PLAYER_GUILD_UPDATE")
      widget.Tooltip = function()
        -- skip without guild
        if not GetGuildInfo("player") then return end

        local raidparty = {}
        for i=1,4 do -- detect people in group
          if UnitExists("party"..i) then
            raidparty[UnitName("party"..i)] = true
          end
        end
        for i=1,40 do -- detect people in raid
          if UnitExists("raid"..i) then
            raidparty[UnitName("raid"..i)] = true
          end
        end

        local all = GetNumGuildMembers()
        local playerzone = GetRealZoneText()
        local off = FauxScrollFrame_GetOffset(GuildListScrollFrame)
        local left, field, init

        for i=1, all do
          local name, _, _, level, class, zone, _, _, online = GetGuildRosterInfo(off + i)
          if online then
            if not init then
              GameTooltip_SetDefaultAnchor(GameTooltip, this)
              GameTooltip:ClearLines()
              GameTooltip:AddLine("|cff555555" .. T["Guild Online"])
              init = true
            end

            local ccolor = RAID_CLASS_COLORS[L["class"][class]] or { 1, 1, 1 }
            local lcolor = GetDifficultyColor(tonumber(level)) or { 1, 1, 1 }
            local level = "|cff555555" .. "[" .. rgbhex(lcolor) .. level .. "|cff555555]"
            local raid = raidparty[name] and "|cff555555[|cff33ffccG|cff555555]|r" or ""

            if not left then
              left =  level .. raid .. " " .. rgbhex(ccolor) .. name
            else
              field = rgbhex(ccolor) .. name .. " " .. raid .. level
              GameTooltip:AddDoubleLine(left, field)
              left = nil
            end
          end
        end

        if left then
          GameTooltip:AddDoubleLine(left, "")
        end

        GameTooltip:Show()
      end
      widget.Click = function() ToggleFriendsFrame(3) end
      widget:SetScript("OnEvent", function()
        if GetGuildInfo("player") then
          local count = 0
          for i = 1, GetNumGuildMembers() do
            local _, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
            if online then count = count + 1 end
          end

          pfUI.panel:OutputPanel("guild", GUILD .. ": " .. count, widget.Tooltip, widget.Click)
        else
          pfUI.panel:OutputPanel("guild", GUILD .. ": " .. NOT_APPLICABLE, widget.Tooltip, widget.Click)
        end
      end)

      widget:SetScript("OnUpdate",function()
        if ( this.tick or 60) > GetTime() then return else this.tick = GetTime() + 60 end
        if GetGuildInfo("player") then GuildRoster() end
      end)
    end

    do -- Durability / Repair
      local widget = CreateFrame("Frame", "pfPanelWidgetRepair", UIParent)
      widget:RegisterEvent("PLAYER_ENTERING_WORLD")
      widget:RegisterEvent("PLAYER_MONEY")
      widget:RegisterEvent("PLAYER_REGEN_ENABLED")
      widget:RegisterEvent("PLAYER_DEAD")
      widget:RegisterEvent("PLAYER_UNGHOST")
      widget:RegisterEvent("UNIT_INVENTORY_CHANGED")
      widget:RegisterEvent("UPDATE_INVENTORY_DURABILITY")

      widget.itemLines = {}
      widget.durability_slots = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }
      widget.totalRep = 0
      widget.scantip = libtipscan:GetScanner("panel")
      widget.duracapture = string.gsub(DURABILITY_TEMPLATE, "%%[^%s]+", "(.+)")
      widget.Click = function() ToggleCharacter("PaperDollFrame") end
      widget.Tooltip = function()
        if widget.totalRep > 0 then
          GameTooltip:ClearLines()
          GameTooltip_SetDefaultAnchor(GameTooltip, this)
          GameTooltip:SetText("|cff555555"..(string.gsub(REPAIR_COST,":","")).."|r")
          SetTooltipMoney(GameTooltip, widget.totalRep)
          for _,line in ipairs(widget.itemLines) do
            GameTooltip:AddDoubleLine(line[1],line[2])
          end
          GameTooltip:Show()
        end
      end
      widget:SetScript("OnEvent", function()
        if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end

        local repPercent = 100
        local lowestPercent = 100
        widget.totalRep = 0
        wipe(widget.itemLines)
        for _, id in pairs(widget.durability_slots) do
          local hasItem, _, repCost = widget.scantip:SetInventoryItem("player", id)
          if (hasItem) then
            widget.totalRep = widget.totalRep + repCost
            local line, lval, rval = widget.scantip:Find(widget.duracapture)
            if (lval and rval) then
              repPercent = math.floor(lval / rval * 100)
              if repPercent < 100 then
                local link = GetInventoryItemLink("player",id)
                local r,g,b,hex = GetColorGradient(repPercent/100)
                local cPercent = string.format("%s%s%%|r",hex,repPercent)
                widget.itemLines[table.getn(widget.itemLines)+1]={link, cPercent}
              end
            end
          end
          if repPercent < lowestPercent then
            lowestPercent = repPercent
          end
        end

        pfUI.panel:OutputPanel("durability", lowestPercent .. "% " .. ARMOR, widget.Tooltip, widget.Click)
      end)
    end

    do -- Zone
      local widget = CreateFrame("Frame", "pfPanelWidgetZone", UIParent)
      for _,event in pairs(EVENTS_MINIMAP_ZONE_UPDATE) do
        widget:RegisterEvent(event)
      end
      widget.Tooltip = function()
        local real = GetRealZoneText()
        local sub = GetSubZoneText()
        GameTooltip:ClearLines()
        GameTooltip_SetDefaultAnchor(GameTooltip, this)
        GameTooltip:AddLine("|cffffffff" .. real)
        GameTooltip:AddLine(sub)

        local posX, posY = GetPlayerMapPosition("player")
        if posX ~= 0 and posY ~= 0 then
          GameTooltip:AddLine("|cffaaaaaa" .. round(posX * 100, 1) .. ", " .. round(posY * 100, 1))
        end

        GameTooltip:Show()
      end
      widget.Click = function()
        if WorldMapFrame:IsShown() then
          WorldMapFrame:Hide()
        else
          WorldMapFrame:Show()
        end
      end
      widget:SetScript("OnEvent", function()
        pfUI.panel:OutputPanel("zone", GetMinimapZoneText(), widget.Tooltip, widget.Click)
      end)
    end

    do -- Ammo
      local widget = CreateFrame("Frame", "pfPanelWidgetAmmo", UIParent)
      widget:RegisterEvent("PLAYER_ENTERING_WORLD")
      widget:RegisterEvent("UNIT_INVENTORY_CHANGED")
      widget:RegisterEvent("BAG_UPDATE")
      widget.Tooltip = function()
        if GetInventoryItemQuality("player", 0) then
          local ammo = GetInventoryItemCount("player", 0)
          GameTooltip:ClearLines()
          GameTooltip_SetDefaultAnchor(GameTooltip, this)
          GameTooltip:SetInventoryItem("player", 0)
          GameTooltip:AddLine(T["Count"] .. ": " .. ammo, .3,1,.8)
          GameTooltip:Show()
        end
      end
      widget:SetScript("OnEvent", function()
        if not GetInventoryItemQuality("player", 0) then
          pfUI.panel:OutputPanel("ammo", AMMOSLOT .. ": -")
        else
          pfUI.panel:OutputPanel("ammo", AMMOSLOT .. ": " .. GetInventoryItemCount("player", 0), tooltip)
        end
      end)
    end

    do -- Soulshards
      local widget = CreateFrame("Frame", "pfPanelWidgetSoulshard", UIParent)
      widget:RegisterEvent("PLAYER_ENTERING_WORLD")
      widget:RegisterEvent("BAG_UPDATE")
      widget:SetScript("OnEvent", function()
        local _, class = UnitClass("player")
        if class == "WARLOCK" then
          local count = pfUI.api.GetItemCount(T["Soul Shard"])
          pfUI.panel:OutputPanel("soulshard", T["Soulshards"] .. ": " .. count)
        end
      end)
    end

    do -- Hearthstone bind location
      local widget = CreateFrame("Frame", "pfPanelBindLocation", UIParent)
      widget:RegisterEvent("PLAYER_ENTERING_WORLD")
      widget:RegisterEvent("CHAT_MSG_SYSTEM")
      widget:SetScript("OnEvent", function()
        pfUI.panel:OutputPanel("bindlocation", T["Hearthstone"] .. ": " .. (GetBindLocation() or T["Not Set"]))
      end)
    end

    do -- Flash Powder
      local widget = CreateFrame("Frame", "pfPanelFlashPowder", UIParent)
      widget:RegisterEvent("PLAYER_ENTERING_WORLD")
      widget:RegisterEvent("BAG_UPDATE")
      widget:SetScript("OnEvent", function()
        local _, class = UnitClass("player")
        if class == "ROGUE" then
          local count = pfUI.api.GetItemCount(T["Flash Powder"])
          pfUI.panel:OutputPanel("flashpowder", T["Flash Powder"] .. ": " .. count)
        end
      end)
    end

    do -- Thistle Tea
      local widget = CreateFrame("Frame", "pfPanelThistleTea", UIParent)
      widget:RegisterEvent("PLAYER_ENTERING_WORLD")
      widget:RegisterEvent("BAG_UPDATE")
      widget:SetScript("OnEvent", function()
        local _, class = UnitClass("player")
        if class == "ROGUE" then
          local count = pfUI.api.GetItemCount(T["Thistle Tea"])
          pfUI.panel:OutputPanel("thistletea", T["Thistle Tea"] .. ": " .. count)
        end
      end)
    end

    do -- Blinding Powder
      local widget = CreateFrame("Frame", "pfPanelBlindingPowder", UIParent)
      widget:RegisterEvent("PLAYER_ENTERING_WORLD")
      widget:RegisterEvent("BAG_UPDATE")
      widget:SetScript("OnEvent", function()
        local _, class = UnitClass("player")
        if class == "ROGUE" then
          local count = pfUI.api.GetItemCount(T["Blinding Powder"])
          pfUI.panel:OutputPanel("blindpowder", T["Blinding Powder"] .. ": " .. count)
        end
      end)
    end
  end

  pfUI.panel = {}
  pfUI.panel.modules = {}

  -- list of available panel fields
  pfUI.panel.options = { "time", "fps", "exp", "gold", "friends",
    "guild", "durability", "zone", "ammo", "bagspace" }

  local panels = {}
  function pfUI.panel:OutputPanel(entry, value, tooltip, func)
    -- return if not yet fully initialized
    if not pfUI.panel.minimap then return end

    -- initialize then panels if not yet done
    if not panels[1] then
      panels = {
        { pfUI.panel.left.left,    C.panel.left.left },
        { pfUI.panel.left.center,  C.panel.left.center },
        { pfUI.panel.left.right,   C.panel.left.right },
        { pfUI.panel.right.left,   C.panel.right.left },
        { pfUI.panel.right.center, C.panel.right.center },
        { pfUI.panel.right.right,  C.panel.right.right },
        { pfUI.panel.minimap,      C.panel.other.minimap },
      }
    end

    for i,p in pairs(panels) do
      local frame, config = p[1], p[2]
      if config == entry then
        frame.text:SetText(value)
        if not frame.initialized or frame.initialized ~= entry then
          if tooltip then
            frame:SetScript("OnEnter", tooltip)
            frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
          end

          if func then
            frame:SetScript("OnClick", func)
          end
          frame.initialized = entry
        end
      end
    end
  end

  local function CreatePanelButton(parent, width, location, tjustify)
    local frame = CreateFrame("Button", nil, parent)
    frame:SetFrameLevel(0)
    frame:ClearAllPoints()
    frame:SetWidth(width)
    frame:SetHeight(parent:GetHeight())
    frame:SetPoint(location, 0, 0)
    frame.text = frame:CreateFontString("Status", "LOW", "GameFontNormal")
    frame.text:ClearAllPoints()
    frame.text:SetAllPoints(frame)
    frame.text:SetPoint(location, 0, 0)
    frame.text:SetJustifyH(tjustify)
    frame.text:SetFont(font, font_size, "OUTLINE")
    frame.text:SetFontObject(GameFontWhite)
    return frame
  end

  local function CreatePanel(panelname, default_border)
    local frame = CreateFrame("Frame", panelname, UIParent)
    frame:SetFrameStrata("FULLSCREEN")
    frame:ClearAllPoints()
    frame:SetFrameStrata("DIALOG")
    frame:SetHeight(C.global.font_size*1.5)
    CreateBackdrop(frame, default_border, nil)
    CreateBackdropShadow(frame)
    return frame
  end

  local function CreatePanelHide(parent, leftright)
    parent.hide = CreateFrame("Button", nil, parent)
    parent.hide:SetFrameLevel(4)
    parent.hide:SetPoint(leftright, parent.backdrop, leftright, 0, 0)
    parent.hide:SetPoint("TOP", parent.backdrop, "TOP", 0, 0)
    parent.hide:SetPoint("BOTTOM", parent.backdrop, "BOTTOM", 0, 0)
    parent.hide:SetWidth(12)
    return parent.hide
  end

  local function CreatePanelHideTexture(parent, framename, leftright)
    SkinButton(parent)
    parent:SetBackdropColor(0,0,0,0)

    parent.texture = parent:CreateTexture(framename)
    local imgstring = "img:" .. leftright
    parent.texture:SetTexture(pfUI.media[imgstring])
    parent.texture:SetPoint("CENTER", 0, 0)
    parent.texture:SetWidth(8)
    parent.texture:SetHeight(8)
    parent.texture:SetVertexColor(.25,.25,.25,1)
    return parent.texture
  end

  -- left panel
  pfUI.panel.left = CreatePanel("pfPanelLeft", default_border)
  pfUI.panel.left.hide = CreatePanelHide(pfUI.panel.left, "LEFT", -5)
  pfUI.panel.left.hide.texture = CreatePanelHideTexture(pfUI.panel.left.hide, "pfPanelLeftHide", "left")

  if pfUI.chat then
    pfUI.panel.left:SetScale(pfUI.chat.left:GetScale())
    pfUI.panel.left:SetWidth(tonumber(C.chat.left.width) - 4)
    pfUI.panel.left:SetPoint("BOTTOM", pfUI.chat.left, "BOTTOM", 0, 2)
  else
    pfUI.panel.left:SetWidth(C.chat.left.width)
    pfUI.panel.left:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 5, 5)
  end

  UpdateMovable(pfUI.panel.left)

  pfUI.panel.left.hide:SetScript("OnClick", function()
    if pfUI.chat.left:IsShown() then pfUI.chat.left:Hide() else pfUI.chat.left:Show() end
  end)

  if not pfUI.chat then pfUI.panel.left.hide:Hide() end

  -- buttons for left panel
  local width = pfUI.panel.left:GetWidth() / 3 - 2
  width = C.panel.left.left == "none" and C.panel.left.right == "none" and pfUI.panel.left:GetWidth() - 2 or width
  width = C.panel.left.center == "none" and pfUI.panel.left:GetWidth() / 2 - 2 or width

  pfUI.panel.left.left = CreatePanelButton(pfUI.panel.left, width, "LEFT", "CENTER")
  pfUI.panel.left.center = CreatePanelButton(pfUI.panel.left, width, "CENTER", "CENTER")
  pfUI.panel.left.right = CreatePanelButton(pfUI.panel.left, width, "RIGHT", "CENTER")

  if C.panel.left.left == "none"
  and C.panel.left.center == "none"
  and C.panel.left.right == "none" then
    pfUI.panel.left:Hide()
  end

  -- right panel
  pfUI.panel.right = CreatePanel("pfPanelRight", default_border)
  pfUI.panel.right.hide = CreatePanelHide(pfUI.panel.right, "RIGHT", 5)
  pfUI.panel.right.hide.texture = CreatePanelHideTexture(pfUI.panel.right.hide, "pfPanelRightHide", "right")

  local ownPlace = C.position["pfPanelRight"] and C.position["pfPanelRight"].xpos
  if pfUI.chat and not ownPlace then
    -- octo (29 Oct 2026; user: the bar "should stay true to the box above it when i resize the box"):
    -- pinned to the window's left and right edges, so it always has the window's width. pfUI set a
    -- width once from the setting and it ran past the window after a resize. Moved or sized in Move
    -- frames (a saved place): it keeps that instead.
    pfUI.panel.right:SetScale(pfUI.chat.right:GetScale())
    pfUI.panel.right:ClearAllPoints()
    pfUI.panel.right:SetPoint("BOTTOMLEFT", pfUI.chat.right, "BOTTOMLEFT", 2, 2)
    pfUI.panel.right:SetPoint("BOTTOMRIGHT", pfUI.chat.right, "BOTTOMRIGHT", -2, 2)
    -- (a width too, for anything that reads it before the window is laid out)
    pfUI.panel.right:SetWidth(tonumber(C.chat.right.width) - 4)
  elseif pfUI.chat then
    pfUI.panel.right:SetScale(pfUI.chat.right:GetScale())
    pfUI.panel.right:SetWidth(tonumber(C.chat.right.width) - 4)
    pfUI.panel.right:SetPoint("BOTTOM", pfUI.chat.right, "BOTTOM", 0, 2)
  else
    pfUI.panel.right:SetWidth(C.chat.right.width)
    pfUI.panel.right:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -5, 5)
  end

  UpdateMovable(pfUI.panel.right)

  -- octo (29 Oct 2026, a player: a narrower bar "just as tall", never
  -- scaled): each panel's own width and height in C.panel.<side>.pwidth /
  -- pheight ("0" = as before: the chat's width, 1.5x the font). Layout mode's
  -- size box and wheel change these, not the scale (unlock.lua SetBoxSize).
  local function Default(side)
    local chat = pfUI.chat and pfUI.chat[side]
    return chat and (tonumber(C.chat[side].width) - 4) or tonumber(C.chat[side].width), C.global.font_size * 1.5
  end
  function pfUI.panel.Size(side)
    local p = pfUI.panel[side]
    local cfg = C.panel[side]
    if not p or not cfg then return end
    local dw, dh = Default(side)
    local w, h = tonumber(cfg.pwidth) or 0, tonumber(cfg.pheight) or 0
    if w <= 0 then w = dw end
    if h <= 0 then h = dh end
    -- never a scale of its own: the chat's, as pfUI does
    local chat = pfUI.chat and pfUI.chat[side]
    p:SetScale(chat and chat:GetScale() or 1)
    if C.position[p:GetName()] then C.position[p:GetName()].scale = nil end
    -- a width needs one anchor: the right bar pinned to both window edges
    -- keeps that only while it has no width of its own
    if (tonumber(cfg.pwidth) or 0) > 0 and p:GetNumPoints() > 1 and not (C.position[p:GetName()] and C.position[p:GetName()].xpos) then
      p:ClearAllPoints()
      if chat then p:SetPoint("BOTTOM", chat, "BOTTOM", 0, 2) end
    end
    p:SetWidth(w)
    p:SetHeight(h)
    -- the three texts share the width, each as tall as the bar
    local bw = w / 3 - 2
    if C.panel[side].left == "none" and C.panel[side].right == "none" then bw = w - 2 end
    if C.panel[side].center == "none" then bw = w / 2 - 2 end
    for _, k in ipairs({ "left", "center", "right" }) do
      if p[k] then p[k]:SetWidth(bw) p[k]:SetHeight(h) end
    end
  end
  function pfUI.panel:UpdateConfig()
    pfUI.panel.Size("left")
    pfUI.panel.Size("right")
  end

  -- octo: the arrow (24 Oct 2026 the user had it removed - "it just confuses";
  -- 25 Oct: back, on by default - "more people use it than not"). As pfUI's
  -- old one: it opens and shuts the right chat window. C.panel.arrowmode:
  --   chat    open: the right window shows with Loot & Spam (ChatFrame3) in it;
  --           shut: the window hides and Loot & Spam goes back to a tab in the
  --           left chat (C.chat.right.enable carries it over a reload)
  --   meters  open: the window shows with the meter windows picked
  --           (C.panel.arrowwins "m1,m2") docked side by side in it; shut: they
  --           go back to free windows, hidden (C.panel.arrowopen)
  -- Options: Chat > Panel arrow; in Move frames, right-click this bar.
  local arrow = pfUI.panel.right.hide
  local arrowShow = arrow.Show
  if C.panel.arrowon ~= "1" then C.panel.arrow = "1" C.panel.arrowon = "1" end
  -- (a lighter arrow: pfUI's .25 grey was hard to see on the dark bar)
  if arrow.texture then arrow.texture:SetVertexColor(.65, .65, .65, 1) end
  arrow.Show = function(self) if C.panel.arrow == "1" then arrowShow(self or arrow) end end

  local function Reshow(f) if f and f.Hide then f:Hide() f:Show() end end

  -- Loot & Spam into the right window, or back to the left chat as a tab
  local function LootRight(on)
    local cf, tab = _G["ChatFrame3"], _G["ChatFrame3Tab"]
    if not (pfUI.chat and pfUI.chat.right and cf) then return end
    if on then
      C.chat.right.enable = "1"
      pfUI.chat.right:Show()
      if cf.isDocked and FCF_UnDockFrame then FCF_UnDockFrame(cf) end
      if pfUI.chat.RefreshChat then pfUI.chat.RefreshChat() end
      -- (1.12: out of a hidden parent it stays unseen until shown again)
      Reshow(cf) Reshow(tab)
    else
      C.chat.right.enable = "0"
      -- (moved before the window hides, so it never sits in a hidden parent)
      cf:SetParent(UIParent)
      if tab then tab:SetParent(UIParent) end
      if FCF_DockFrame then FCF_DockFrame(cf) end
      if pfUI.chat.RefreshChat then pfUI.chat.RefreshChat() end
      if FCF_DockUpdate then FCF_DockUpdate() end
      pfUI.chat.right:Hide()
      Reshow(tab)
    end
  end

  -- at most this many meter windows share the panel (user, 28 Oct 2026: "3 max")
  pfUI.panel.ARROWMAX = 3
  function pfUI.panel.ArrowMeters()
    local out, M = {}, pfUI.meters
    for key in string.gfind(C.panel.arrowwins or "", "[^,]+") do
      local n = tonumber(string.sub(key, 2))
      if string.sub(key, 1, 1) == "m" and n and M and M.windows and M.windows[n]
        and table.getn(out) < pfUI.panel.ARROWMAX then table.insert(out, M.windows[n]) end
    end
    return out
  end

  -- which panel the docked meters sit in (1 Nov 2026, dennis: "lock into the left frame
  -- instead only the right"): C.panel.arrowside right | left; returns the chat window and its bar
  function pfUI.panel.DockHolder()
    if C.panel.arrowside == "left" and pfUI.chat and pfUI.chat.left then return pfUI.chat.left, pfUI.panel.left end
    return pfUI.chat and pfUI.chat.right, pfUI.panel.right
  end

  -- the picked meter windows side by side in the right (or left) window, or free again
  local function MetersIn(on)
    local chat, bar = pfUI.panel.DockHolder()
    local M = pfUI.meters
    local right = chat == (pfUI.chat and pfUI.chat.right)
    if not (chat and M) then return end
    local wins = pfUI.panel.ArrowMeters()
    if on then
      if right then chat:Show() end
      -- (28 Oct 2026, user: "resized naturally to FILL the right panel not leaving spaces") the
      -- docked windows split the panel evenly, edge to edge: one takes it all, two halves, three thirds
      -- (seen in game 28 Oct: a strip at the right stayed empty - the width was read before the
      -- chat had its real size. Now its measured edges, the last window pinned to its right edge,
      -- and placed again whenever the panel's width changes: pfUI.panel.arrowWatch)
      local l, r = chat:GetLeft(), chat:GetRight()
      local full = (l and r and r > l) and (r - l) or chat:GetWidth() or 400
      pfUI.panel.arrowWidth = full
      local bottom = bar and bar:GetHeight() or 0
      local x = 0
      local each = full / math.max(1, table.getn(wins))
      for i, win in ipairs(wins) do
        local last = i == table.getn(wins)
        -- (offsets count in the window's own scale, the split in the chat's: seen in game 28 Oct,
        -- the first two came out narrower and the last took the rest)
        local k = (chat:GetEffectiveScale() or 1) / math.max(.01, win:GetEffectiveScale() or 1)
        win:ClearAllPoints()
        win:SetPoint("TOPLEFT", chat, "TOPLEFT", x * k, 0)
        if last then
          win:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 0, bottom * k)
        else
          win:SetPoint("BOTTOMRIGHT", chat, "BOTTOMLEFT", (x + each) * k, bottom * k)
        end
        x = x + each
        win:SetFrameStrata(chat:GetFrameStrata())
        win:SetFrameLevel(chat:GetFrameLevel() + 5)
        if win.grip then win.grip:Hide() end
        win.arrowDocked = true
        win:Show()
        if win.Refresh then pcall(win.Refresh, win) end
        if M.Lift then M.Lift(win) end
      end
    else
      for _, win in ipairs(wins) do
        if win.arrowDocked then
          win.arrowDocked = nil
          -- (its own size and place again)
          local ok = M.SetDocked and pcall(M.SetDocked, win, false)
          if not ok then pcall(UpdateMovable, win) end
        end
        win:Hide()
      end
      if right and C.chat.right.enable ~= "1" then chat:Hide() end
    end
  end

  function pfUI.panel.ArrowIsOpen()
    if C.panel.arrowmode == "meters" then return C.panel.arrowopen == "1" end
    return C.chat.right.enable == "1"
  end
  function pfUI.panel.ArrowSet(open)
    if C.panel.arrowmode == "meters" then
      C.panel.arrowopen = open and "1" or "0"
      MetersIn(open)
    else
      LootRight(open)
    end
  end
  function pfUI.panel.ArrowToggle() pfUI.panel.ArrowSet(not pfUI.panel.ArrowIsOpen()) end
  -- meter window n docked in the arrow's window or not (Meters > Windows, "Where your windows go")
  function pfUI.panel.ArrowDocks(n)
    for k in string.gfind(C.panel.arrowwins or "", "[^,]+") do if k == "m" .. n then return true end end
    return false
  end
  -- where a window goes when it leaves the panel and has no spot of its own: just above where it
  -- sat in the panel, saved at once (user, 28 Oct 2026: "they should never move after you place them
  -- never reset position" - it used to jump to the middle of the screen)
  local function FloatSpot(win, n)
    if not win or not win.GetName or not win:GetName() then return end
    local name = win:GetName()
    if C.position[name] and C.position[name].xpos then return end
    local k = (win:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    local l, t = win:GetLeft(), win:GetTop()
    if not (win.arrowDocked and l and t) then
      -- (not on show: above the panel, side by side by number)
      local chat = pfUI.chat and pfUI.chat.right
      local cl, ct = chat and chat:GetLeft(), chat and chat:GetTop()
      if not (cl and ct) then return end
      local ck = (chat:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
      l, t, k = cl + math.mod(n - 1, 3) * 90, ct + 30, ck
    end
    local h = tonumber(pfUI.meters and pfUI.meters.S and pfUI.meters.S(win).height) or 160
    C.position[name] = { anchor = "BOTTOMLEFT", xpos = math.floor(l * k + .5), ypos = math.floor(t * k + 12 + .5) }
    -- (its own height above that spot stays on the screen)
    if C.position[name].ypos + h > (GetScreenHeight() or 768) then C.position[name].ypos = math.max(0, (GetScreenHeight() or 768) - h - 4) end
  end
  pfUI.panel.FloatSpot = FloatSpot

  -- window n in the panel (on) or floating (off); false when the panel is full
  function pfUI.panel.ArrowDock(n, on)
    if on and not pfUI.panel.ArrowDocks(n) and table.getn(pfUI.panel.ArrowMeters()) >= pfUI.panel.ARROWMAX then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r meters: the bottom panel holds " .. pfUI.panel.ARROWMAX
        .. " windows - set one of them to Floating first.")
      return false
    end
    local M = pfUI.meters
    local win = M and M.windows and M.windows[n]
    if not on then FloatSpot(win, n) end
    -- (docking: the panel holds meter windows from now on)
    if on and C.panel.arrowmode ~= "meters" and pfUI.panel.ArrowMode then pfUI.panel.ArrowMode("meters") end
    local open = C.panel.arrowmode == "meters" and pfUI.panel.ArrowIsOpen()
    if open then pfUI.panel.ArrowSet(false) end
    local out = {}
    for k in string.gfind(C.panel.arrowwins or "", "[^,]+") do if k ~= "m" .. n then table.insert(out, k) end end
    if on then table.insert(out, "m" .. n) end
    C.panel.arrowwins = table.concat(out, ",")
    if on and not open then C.panel.arrowopen = "1" open = true end
    if open then pfUI.panel.ArrowSet(true) end
    -- (the ones left in the panel split it again at once)
    if C.panel.arrowmode == "meters" and C.panel.arrowopen == "1" then MetersIn(true) end
    -- (a window set floating shows at once, at its spot)
    if not on and win and C.meters.hidden ~= "1" then win:Show() end
    return true
  end
  -- docked meter windows placed again (a width changed on the Meters page or in Move frames)
  function pfUI.panel.ArrowLayout()
    if C.panel.arrowmode == "meters" and C.panel.arrowopen == "1" then MetersIn(true) end
  end
  -- the docked windows follow the panel's width (login, chat resized, UI scale)
  pfUI.panel.arrowWatch = CreateFrame("Frame")
  pfUI.panel.arrowWatch:SetScript("OnUpdate", function()
    this.t = (this.t or 0) + arg1
    if this.t < .5 then return end
    this.t = 0
    local chat = pfUI.panel.DockHolder()
    if not chat or C.panel.arrowmode ~= "meters" or C.panel.arrowopen ~= "1" then return end
    local l, r = chat:GetLeft(), chat:GetRight()
    if l and r and math.abs((r - l) - (pfUI.panel.arrowWidth or 0)) > 1 then MetersIn(true) end
  end)
  -- the mode changed on the options page: shut the one before, open the new one
  function pfUI.panel.ArrowMode(mode)
    local was = pfUI.panel.ArrowIsOpen()
    if was then pfUI.panel.ArrowSet(false) end
    C.panel.arrowmode = mode
    if was then pfUI.panel.ArrowSet(true) end
  end
  -- the arrow's window as this layout has it (a UI layout switch puts each
  -- layout's own state back, after the frames are placed: user, 25 Oct 2026,
  -- meters docked in it "not remembered")
  function pfUI.panel.ArrowRefresh()
    if C.panel.arrowmode == "meters" then
      MetersIn(C.panel.arrowopen == "1")
    elseif pfUI.chat and pfUI.chat.right then
      -- (meters docked by a layout that used the arrow for them: free again)
      for _, win in ipairs(pfUI.panel.ArrowMeters()) do
        if win.arrowDocked then
          win.arrowDocked = nil
          local M = pfUI.meters
          local ok = M and M.SetDocked and pcall(M.SetDocked, win, false)
          if not ok then pcall(UpdateMovable, win) end
        end
      end
      LootRight(C.chat.right.enable == "1")
    end
  end
  function pfUI.panel.ArrowApply()
    if C.panel.arrow == "1" then arrowShow(arrow) else arrow:Hide() end
  end

  -- the arrow sits on the bar of the panel the meters dock in (1 Nov 2026,
  -- user: "make the arrow switch with it"): the right bar's right end, or the
  -- left bar's left end, pointing outwards
  function pfUI.panel.ArrowPlace()
    local left = C.panel.arrowside == "left" and pfUI.panel.left
    local bar = left and pfUI.panel.left or pfUI.panel.right
    if not bar then return end
    local edge = left and "LEFT" or "RIGHT"
    arrow:SetParent(bar)
    arrow:ClearAllPoints()
    arrow:SetPoint(edge, bar.backdrop or bar, edge, 0, 0)
    arrow:SetPoint("TOP", bar.backdrop or bar, "TOP", 0, 0)
    arrow:SetPoint("BOTTOM", bar.backdrop or bar, "BOTTOM", 0, 0)
    arrow:SetFrameLevel((bar:GetFrameLevel() or 1) + 3)
    if arrow.texture then arrow.texture:SetTexture(pfUI.media[left and "img:left" or "img:right"]) end
    -- (a frame moved out of a hidden parent stays unseen until it is shown again)
    if C.panel.arrow == "1" then arrow:Hide() arrowShow(arrow) end
  end
  pfUI.panel.ArrowPlace()

  arrow:SetScript("OnClick", function() pfUI.panel.ArrowToggle() end)
  arrow:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
    GameTooltip:AddLine(C.panel.arrowmode == "meters" and "Meters window" or "Loot & Spam window")
    GameTooltip:AddLine("Click: open / shut it", 1, 1, 1)
    GameTooltip:AddLine("Chat > Panel arrow: meters instead, or no arrow", .7, .7, .7)
    GameTooltip:Show()
  end)
  arrow:SetScript("OnLeave", function() GameTooltip:Hide() end)
  pfUI.panel.ArrowApply()
  -- meters docked when the game starts, if they were open (after the meters exist)
  if C.panel.arrowmode == "meters" and C.panel.arrowopen == "1" then
    local boot = CreateFrame("Frame")
    boot:RegisterEvent("PLAYER_ENTERING_WORLD")
    boot:SetScript("OnEvent", function() this:UnregisterAllEvents() MetersIn(true) end)
  end

  -- buttons for right panel
  local width = pfUI.panel.right:GetWidth() / 3 - 2
  width = C.panel.right.left == "none" and C.panel.right.right == "none" and pfUI.panel.right:GetWidth() - 2 or width
  width = C.panel.right.center == "none" and pfUI.panel.right:GetWidth() / 2 - 2 or width

  pfUI.panel.right.left = CreatePanelButton(pfUI.panel.right, width, "LEFT", "CENTER")
  pfUI.panel.right.center = CreatePanelButton(pfUI.panel.right, width, "CENTER", "CENTER")
  pfUI.panel.right.right = CreatePanelButton(pfUI.panel.right, width, "RIGHT", "CENTER")

  -- octo: its three parts follow its width when the window above is resized
  local function RightParts()
    local w = pfUI.panel.right:GetWidth() or 0
    if w <= 0 then return end
    local each = w / 3 - 2
    if C.panel.right.left == "none" and C.panel.right.right == "none" then each = w - 2
    elseif C.panel.right.center == "none" then each = w / 2 - 2 end
    for _, b in ipairs({ pfUI.panel.right.left, pfUI.panel.right.center, pfUI.panel.right.right }) do
      if b and b.SetWidth then b:SetWidth(each) end
    end
  end
  pfUI.panel.RightParts = RightParts
  pfUI.panel.right:SetScript("OnSizeChanged", RightParts)
  -- (each bar's own width / height, once both bars have their parts)
  pfUI.panel:UpdateConfig()

  if C.panel.right.left == "none"
  and C.panel.right.center == "none"
  and C.panel.right.right == "none" then
    pfUI.panel.right:Hide()
  end

  pfUI.panel.minimap = CreateFrame("Button", "pfPanelMinimap", UIParent)
  if pfUI.minimap then
    pfUI.panel.minimap:SetWidth(pfUI.minimap:GetWidth())
    pfUI.panel.minimap:SetPoint("TOPLEFT", pfUI.minimap, "BOTTOMLEFT", 0 , -default_border*3)
    pfUI.panel.minimap:SetPoint("TOPRIGHT", pfUI.minimap, "BOTTOMRIGHT", 0 , default_border*3)
  else
    pfUI.panel.minimap:SetWidth(200)
    pfUI.panel.minimap:SetPoint("TOP", UIParent, "TOP", 0, -5)
  end

  pfUI.panel.minimap:SetHeight(C.global.font_size*1.5)
  pfUI.panel.minimap:SetFrameStrata("MEDIUM")

  CreateBackdrop(pfUI.panel.minimap, default_border)
  CreateBackdropShadow(pfUI.panel.minimap)
  UpdateMovable(pfUI.panel.minimap)

  pfUI.panel.minimap.text = pfUI.panel.minimap:CreateFontString("MinimapZoneText", "LOW", "GameFontNormal")
  pfUI.panel.minimap.text:SetFont(font, font_size, "OUTLINE")
  pfUI.panel.minimap.text:SetAllPoints()
  pfUI.panel.minimap.text:SetFontObject(GameFontWhite)

  if C.panel.other.minimap == "none" then pfUI.panel.minimap:Hide() end

  -- MicroButtons
  if C.panel.micro.enable == "1" then
    pfUI.panel.microbutton = CreateFrame("Frame", "pfPanelMicroButton", UIParent)
    pfUI.panel.microbutton:SetPoint("TOP", pfUI.panel.minimap, "BOTTOM", 0,  -2*default_border)
    UpdateMovable(pfUI.panel.microbutton)
    pfUI.panel.microbutton:SetHeight(23)
    pfUI.panel.microbutton:SetWidth(145)
    pfUI.panel.microbutton:SetFrameStrata("MEDIUM")

    for i=1,table.getn(MICRO_BUTTONS) do
      local anchor = _G[MICRO_BUTTONS[i-1]] or pfUI.panel.microbutton
      local button = _G[MICRO_BUTTONS[i]]
      button:ClearAllPoints()
      button:SetParent(pfUI.panel.microbutton)
      if i == 1 then
        button:SetPoint("LEFT", pfUI.panel.microbutton, "LEFT", 1, 10)
      else
        button:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 1, 0)
      end

      button:SetScale(.6)
      button.frame = CreateFrame("Frame", "backdrop", button)
      button.frame:SetScale(1.4)
      button.frame:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -16)
      button.frame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
      CreateBackdrop(button.frame, default_border)
      button:Show()
    end
  end


  pfUI.panel.autohide = CreateFrame("Frame", nil, UIParent)
  pfUI.panel.autohide:RegisterEvent("PLAYER_ENTERING_WORLD")
  pfUI.panel.autohide:SetScript("OnEvent", function()
    if C.panel.hide_leftchat == "1" then
      EnableAutohide(pfUI.panel.left, 2)
    end
    if C.panel.hide_rightchat == "1" then
      EnableAutohide(pfUI.panel.right, 2)
    end
    if C.panel.hide_minimap == "1" then
      EnableAutohide(pfUI.panel.minimap, 2)
    end
    if C.panel.hide_microbar == "1" then
      EnableAutohide(pfUI.panel.microbutton, 2)
    end
  end)
end)
