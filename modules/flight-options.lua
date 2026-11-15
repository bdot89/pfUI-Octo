pfUI:RegisterModule("flight-options", "vanilla", function ()
  -- pfUI Octo :: the Flight timer page (15 Nov 2026, modules/flight.lua), a tab under
  -- Quality of Life: the switch, the bar as it looks (a made-up flight running), what it
  -- shows, its look and the flight times it has learnt.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local FL = pfUI.flight
  if not W or not O or not O.AddPage or not FL then return end
  local function G() return C.flight end
  local function Chk(p, label, desc, key) return O.PfChk(p, label, desc, G, key) end
  local function Sld(p, label, desc, min, max, step, key, fmt) return O.PfSld(p, label, desc, min, max, step, G, key, nil, fmt) end
  local function Pct(v) return math.floor(v * 100 + .5) .. "%" end
  local function Color(p, label, desc, key, r, g, b)
    W.Color(p, label, desc, function() return FL.Col(key, r, g, b, 1) end,
      function(nr, ng, nb, na) G()[key] = nr .. "," .. ng .. "," .. nb .. "," .. (na or 1) end)
  end

  local function Build(p)
    W.Heading(p, "Flight timer", { on = O.KeySwitch(G, "enable", "The bar while you are on a flight path, on or off."),
      about = "While you fly, a line from where you took off to where you land: a tick for every flight point on the way, "
        .. "a marker for where you are and the time left. With ClassicAPI the route and its length are read from the game's "
        .. "own flight paths, so the time is right on the first flight and the marker follows where you really are. Without "
        .. "it, a route's time is a guess until you have flown it once. Every flight is timed and remembered." })

    W.Pin(p, "Your bar", "A made-up flight from Orgrimmar to Ratchet running in a loop. Shift + wheel: longer / shorter line.", function(pp)
      local box = (W.ZoomBox or W.Box)(pp, 96)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      local sample = FL.NewBar(holder)
      local hot = CreateFrame("Button", nil, holder)
      hot:SetAllPoints(box)
      hot:SetFrameLevel(holder:GetFrameLevel() + 6)
      hot:EnableMouseWheel(true)
      hot:SetScript("OnMouseWheel", function()
        if IsShiftKeyDown() then
          G().width = tostring(math.max(200, math.min(900, (tonumber(G().width) or 420) + (arg1 or 0) * 20)))
          O:Refresh()
        elseif pfUI.plates and pfUI.plates.PassWheel then
          pfUI.plates.PassWheel(this)
        end
      end)
      local function Paint()
        FL.Paint(sample, FL.Sample(GetTime()))
        local room = (box:GetWidth() or 600) - 30
        sample:SetScale(math.min(1, room / math.max(1, sample:GetWidth())))
        sample:ClearAllPoints()
        sample:SetPoint("CENTER", box, "CENTER", 0, 0)
        sample:SetAlpha(G().enable == "1" and (tonumber(G().alpha) or 1) or .35)
      end
      holder:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + .05
        Paint()
      end)
      Paint()
      if p.items then table.insert(p.items, { Refresh = Paint }) end
      W.Buttons(pp, { { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, nil, "Drag the flight bar where you want it." } })
    end)

    W.Live(p, function()
      local n = FL.Count()
      local src = FL.HasPaths() and "|cff55ff55ClassicAPI's flight paths: exact from the first flight.|r"
        or "|cffffcc00No ClassicAPI flight paths: a route is a guess until flown once.|r"
      local now = FL.now and ("   In flight: " .. (FL.now.plan.names[1] or "?") .. " > " .. (FL.now.plan.names[table.getn(FL.now.plan.names)] or "?")) or ""
      return src .. "   Flights timed: |cffffffff" .. n .. "|r" .. ((FL.got or 0) > 0 and ("   from others: |cffffffff" .. FL.got .. "|r") or "") .. now
    end)

    W.Card(p, "What it shows", { icon = "Interface\\Icons\\INV_Misc_Map_01", tip = "The parts of the bar." })
    Chk(p, "Time left", "Left of the line. A \"~\" in front = a guess (the route has not been flown yet and the client gave no path).", "showtime")
    Chk(p, "The stops on the way", "A tick and the name of every flight point you pass.", "stops")
    Chk(p, "\"You\" over the marker", nil, "you")
    Chk(p, "A flyer on the marker", nil, "flyer")
    Chk(p, "Short names", "\"Crossroads\" instead of \"Crossroads, The Barrens\".", "short")
    Chk(p, "The picture at the end", nil, "picture")
    Chk(p, "Dark panel behind", "A soft dark panel behind the whole bar, for bright places.", "panel")
    Chk(p, "Flight times on the flight map", "Hovering a flight point on the flight master's map shows how long the flight takes and how many stops it has.", "tooltip")
    Chk(p, "Share flight times", "The times you fly go to your guild and group, and theirs come to you for routes you have not flown.", "share")

    W.Card(p, "Look", { icon = "Interface\\Icons\\INV_Misc_Gem_Variety_01", tip = "Sizes and colours." })
    Sld(p, "Line length", "Also Shift + wheel on the preview.", 200, 900, 10, "width", O.Px)
    Sld(p, "Line thickness", nil, 1, 6, 1, "thick", O.Px)
    Sld(p, "Text size", nil, 8, 20, 1, "textsize", O.Px)
    Sld(p, "Flyer size", nil, 8, 32, 1, "flyersize", O.Px)
    Sld(p, "Picture size", nil, 16, 64, 1, "picsize", O.Px)
    Sld(p, "Opacity", nil, .1, 1, .05, "alpha", Pct)
    Color(p, "Line", nil, "linecolor", 1, 1, 1)
    Color(p, "Flown part, flyer and passed stops", nil, "donecolor", .35, .8, 1)
    Color(p, "Ends and stops ahead", nil, "endcolor", .86, .6, .42)
    Color(p, "Text", nil, "textcolor", 1, 1, 1)
    W.Edit(p, "Own picture", "Empty = a feather. Else a texture path, for example Interface\\Icons\\Ability_Mount_Gryphon_01.",
      function() return G().pictex or "" end, function(v) G().pictex = v or "" end, 300)

    W.Card(p, "Flight times", { icon = "Interface\\Icons\\INV_Misc_PocketWatch_01", tip = "Kept for all your characters." })
    W.Buttons(p, {
      { "Forget all times", function()
        if FL.sureAt and GetTime() < FL.sureAt then
          FL.sureAt = nil
          pfUI_cache.flighttimes, pfUI_cache.flightrate, pfUI_cache.flightcut = {}, nil, nil
        else
          FL.sureAt = GetTime() + 3
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r flight timer: click Forget all times again within 3 s.")
        end
      end, 150, "Click twice: every timed flight is dropped and timed again as you fly.", role = "off" },
    })
    W.Note(p, "Landing early at a stop on the way is not possible on this client: the game has no way to ask the server for it. "
      .. "To stop at a flight point, pick it as your destination. Command: /flight (this page).")
  end

  O:AddPage("Flight Timer", "flight", "Flight timer", Build)
end)
