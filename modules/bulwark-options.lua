pfUI:RegisterModule("bulwark-options", "vanilla", function ()
  -- pfUI Octo :: the Earthen Bulwark page (18 Nov 2026, modules/bulwark.lua), a tab under Unit Frames.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local BW = pfUI.bulwark
  if not W or not O or not O.AddPage or not BW then return end
  local function G() return C.bulwark end
  local function Chk(p, label, desc, key) return O.PfChk(p, label, desc, G, key) end
  local function Sld(p, label, desc, min, max, step, key, fmt) return O.PfSld(p, label, desc, min, max, step, G, key, nil, fmt) end
  local function Pct(v) return math.floor(v * 100 + .5) .. "%" end
  local function Color(p, label, desc, key, r, g, b, a)
    W.Color(p, label, desc, function() return BW.Col(key, r, g, b, a) end,
      function(nr, ng, nb, na) G()[key] = nr .. "," .. ng .. "," .. nb .. "," .. (na or 1) end)
  end

  local function Build(p)
    W.Heading(p, "Earthen Bulwark", { on = O.KeySwitch(G, "enable", "The bar for tank shamans, on or off."),
      about = "For shamans with Elemental Weapons and Rockbiter on the weapon: your physical damage builds an earthen "
        .. "bulwark (20% of the damage, three times as much with a shield), up to 20% of your maximum health. When you are "
        .. "hit it absorbs 15% of the damage for 8 seconds or until it is used up. The bar fills with how full it is (the "
        .. "server's own \"integrity\" number) and turns bright with a timer line while it is absorbing. The amount is "
        .. "worked out from your maximum health, so it is marked ~." })

    W.Pin(p, "Your bar", "A made-up bulwark filling up, then absorbing. Shift + wheel: wider / narrower.", function(pp)
      local box = (W.ZoomBox or W.Box)(pp, 80)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      local sample = BW.NewBar(holder)
      local hot = CreateFrame("Button", nil, holder)
      hot:SetAllPoints(box)
      hot:SetFrameLevel(holder:GetFrameLevel() + 8)
      hot:EnableMouseWheel(true)
      hot:SetScript("OnMouseWheel", function()
        if IsShiftKeyDown() then
          G().width = tostring(math.max(80, math.min(500, (tonumber(G().width) or 180) + (arg1 or 0) * 10)))
          O:Refresh()
        elseif pfUI.plates and pfUI.plates.PassWheel then
          pfUI.plates.PassWheel(this)
        end
      end)
      local function Paint()
        BW.Paint(sample, BW.Sample(GetTime()))
        sample:ClearAllPoints()
        sample:SetPoint("CENTER", box, "CENTER", G().icon == "1" and 10 or 0, 0)
        sample:SetAlpha(G().enable == "1" and (tonumber(G().alpha) or 1) or .35)
      end
      holder:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + .05
        Paint()
      end)
      Paint()
      if p.items then table.insert(p.items, { Refresh = Paint }) end
      W.Buttons(pp, { { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, nil, "Drag the bulwark bar where you want it." } })
    end)

    W.Live(p, function()
      if not BW.shaman then return "|cffffcc00Only shown on shamans.|r" end
      local v = BW.View()
      if not v.has then return "No bulwark right now: put Rockbiter on your weapon and hit something." end
      return "Now: |cffffffff" .. (v.pct or 0) .. "%|r of |cffffffff" .. BW.Comma(v.cap) .. "|r"
        .. (v.absorbing and ("   |cffffd060absorbing, " .. string.format("%.1f", v.left) .. " s left|r") or "")
        .. (v.shield and "   |cff88ccffshield: x3|r" or "")
    end)

    W.Card(p, "When it shows", { icon = "Interface\\Icons\\Spell_Nature_RockBiter", tip = "Only ever on shamans." })
    W.Dropdown(p, "Show", nil, {
      { key = "auto", label = "In combat or while it holds something" },
      { key = "combat", label = "Only in combat" },
      { key = "always", label = "Always" },
    }, function() return G().show end, function(v) G().show = v end)

    W.Card(p, "What it shows", { icon = "Interface\\Icons\\INV_Shield_04", tip = "The parts of the bar." })
    W.Dropdown(p, "Text", "The amount is how full it is times 20% of your maximum health.", {
      { key = "both", label = "62%   ~1,240 / 2,000" },
      { key = "pct", label = "62%" },
      { key = "amount", label = "~1,240 / 2,000" },
    }, function() return G().textmode end, function(v) G().textmode = v end)
    Chk(p, "Text on the bar", nil, "text")
    Chk(p, "Timer while absorbing", "A thin line along the bottom and the seconds left of the 8 s.", "timer")
    Chk(p, "\"x3\" while wearing a shield", "With a shield the bulwark builds three times as fast.", "shieldtag")
    Chk(p, "Picture", "The bulwark's icon left of the bar, grey while empty.", "icon")

    W.Card(p, "Look", { icon = "Interface\\Icons\\INV_Misc_Gem_Variety_01", tip = "Sizes and colours." })
    Sld(p, "Width", "Also Shift + wheel on the preview.", 80, 500, 5, "width", O.Px)
    Sld(p, "Height", nil, 6, 40, 1, "height", O.Px)
    Sld(p, "Text size", nil, 7, 20, 1, "textsize", O.Px)
    Sld(p, "Opacity", nil, .1, 1, .05, "alpha", Pct)
    Color(p, "Filling up", nil, "color", .72, .52, .28, 1)
    Color(p, "Absorbing", nil, "activecolor", 1, .82, .35, 1)
    Color(p, "Empty part", nil, "bgcolor", .1, .08, .05, .8)
    Color(p, "Timer line", nil, "timercolor", 1, 1, 1, .9)
    Color(p, "Text", nil, "textcolor", 1, 1, 1, 1)
    W.Note(p, "Command: /bulwark (this page). Right-click its box in layout mode also opens it.")
  end

  O:AddPage("Earthen Bulwark", "bulwark", "Earthen Bulwark", Build)
end)
