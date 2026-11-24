pfUI:RegisterModule("framefade-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the Frame Fade page (24 Nov 2026, modules/framefade.lua), a tab under Quality of Life: the switch, a
  -- little screen whose parts fade with the real ones (click one = fade it or leave it), what fades, what brings it
  -- back, peeking, and the fade itself.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local FF = pfUI.framefade
  if not W or not O or not O.AddPage or not FF then return end
  local function G() return C.framefade end
  local function Chk(p, label, desc, key, after) return O.PfChk(p, label, desc, G, key, after or function() FF.evalAt = 0 end) end
  local function Sld(p, label, desc, min, max, step, key, fmt) return O.PfSld(p, label, desc, min, max, step, G, key, nil, fmt) end
  local function Pct(v) return math.floor(v * 100 + .5) .. "%" end
  local function Secs(v) return string.format("%.1f s", v) end
  local function Whole(v) return math.floor(v + .5) .. "%" end

  -- where each part sits on the little screen: x, y, width, height as shares of the box
  local SPOT = {
    player  = { .03, .07, .24, .17 },
    buffs   = { .56, .05, .26, .12 },
    minimap = { .85, .05, .12, .25 },
    chat    = { .03, .50, .30, .32 },
    meters  = { .70, .50, .27, .32 },
    bars    = { .35, .66, .30, .18 },
    panels  = { .00, .88, 1.0, .09 },
  }

  local function Build(p)
    W.Heading(p, "Frame fade", { on = O.KeySwitch(G, "enable", "Frame fade on or off. Off puts every part back at once.", FF.Switched),
      about = "For a clean screen while nothing is going on: the parts you pick fade away when you are at full health and "
        .. "mana, out of combat, not casting and have no target, and come back the moment any of that changes. Hover a "
        .. "faded part or hold a key to see it. pfUI's own fading (range, action bar fades) keeps working underneath. "
        .. "The idea comes from FrameFade by Grylls (MIT), which did this for the player and pet frames. /framefade" })

    W.Pin(p, "Your screen", "The parts of your screen as boxes, fading with the real ones. Click a box to fade that part or leave it alone.", function(pp)
      local box = W.Box(pp, 170)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      local spots = {}
      for gi = 1, table.getn(FF.GROUPS) do
        local g = FF.GROUPS[gi]
        local s = CreateFrame("Button", nil, holder)
        s.g = g
        s.fill = s:CreateTexture(nil, "BACKGROUND")
        s.fill:SetAllPoints(s)
        s.edge = {}
        for e = 1, 4 do s.edge[e] = s:CreateTexture(nil, "BORDER") end
        s.edge[1]:SetPoint("TOPLEFT", s, "TOPLEFT") s.edge[1]:SetPoint("TOPRIGHT", s, "TOPRIGHT") s.edge[1]:SetHeight(1)
        s.edge[2]:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT") s.edge[2]:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT") s.edge[2]:SetHeight(1)
        s.edge[3]:SetPoint("TOPLEFT", s, "TOPLEFT") s.edge[3]:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT") s.edge[3]:SetWidth(1)
        s.edge[4]:SetPoint("TOPRIGHT", s, "TOPRIGHT") s.edge[4]:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT") s.edge[4]:SetWidth(1)
        s.text = W.Font(s:CreateFontString(nil, "OVERLAY"), 10, 1, 1, 1)
        s.text:SetPoint("CENTER", s, "CENTER", 0, 0)
        s:SetScript("OnClick", function()
          local k = "g_" .. this.g.key
          G()[k] = G()[k] == "1" and "0" or "1"
          FF.evalAt = 0
          O:Refresh()
        end)
        s:SetScript("OnEnter", function()
          GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
          GameTooltip:AddLine(this.g.label)
          GameTooltip:AddLine(this.g.desc, 1, 1, 1, 1)
          GameTooltip:AddLine(G()["g_" .. this.g.key] == "1" and "Fades. Click: leave it alone." or "Left alone. Click: let it fade.", .6, .8, 1)
          GameTooltip:Show()
        end)
        s:SetScript("OnLeave", function() GameTooltip:Hide() end)
        spots[gi] = s
      end
      local status = W.Font(holder:CreateFontString(nil, "OVERLAY"), 11, 1, 1, 1)
      status:SetPoint("TOP", box, "TOP", 0, -6)
      status:SetWidth(380)

      local function Paint()
        local w, h = box:GetWidth() or 600, box:GetHeight() or 170
        local ar, ag, ab = .2, 1, .8
        if pfUI.api.GetAccentColor then ar, ag, ab = pfUI.api.GetAccentColor() end
        local on = G().enable == "1" or FF.forced
        for gi = 1, table.getn(spots) do
          local s = spots[gi]
          local k = s.g.key
          local sp = SPOT[k] or { 0, 0, .1, .1 }
          s:ClearAllPoints()
          s:SetPoint("TOPLEFT", box, "TOPLEFT", sp[1] * w + 2, -(sp[2] * h + 2))
          s:SetWidth(math.max(10, sp[3] * w - 4))
          s:SetHeight(math.max(10, sp[4] * h - 4))
          local fades = G()["g_" .. k] == "1"
          local m = FF.mul[k] or 1
          if fades then
            local seen = on and m or 1
            s.fill:SetTexture(ar, ag, ab, .12 + .38 * seen)
            for e = 1, 4 do s.edge[e]:SetTexture(ar, ag, ab, .35 + .65 * seen) end
            s.text:SetTextColor(1, 1, 1, .35 + .65 * seen)
            s.text:SetText(s.g.label .. (on and m < .99 and string.format("\n|cffaaaaaa%d%%|r", math.floor(m * 100 + .5)) or ""))
          else
            s.fill:SetTexture(.5, .5, .5, .08)
            for e = 1, 4 do s.edge[e]:SetTexture(.5, .5, .5, .3) end
            s.text:SetTextColor(.6, .6, .6, .8)
            s.text:SetText(s.g.label .. "\n|cff777777left alone|r")
          end
        end
        status:SetText(FF.Status())
      end
      holder:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + .05
        Paint()
      end)
      Paint()
      if p.items then table.insert(p.items, { Refresh = Paint }) end
      W.Buttons(pp, {
        { "Try it: fade now", function() FF.Try(8) end, 150, "Fades the picked parts for 8 seconds, whatever is going on (also with the switch off)." },
        { "Show everything", function() FF.Wake() end, 140, "Everything back now; the wait before fading starts again." },
      })
    end)

    W.Card(p, "What fades", { icon = "Interface\\Icons\\Spell_Nature_Invisibilty", tip = "The parts of your screen that fade. The rest is never touched." })
    for gi = 1, table.getn(FF.GROUPS) do
      local g = FF.GROUPS[gi]
      Chk(p, g.label, g.desc, "g_" .. g.key)
    end

    W.Card(p, "Shown again when", { icon = "Interface\\Icons\\Ability_Warrior_BattleShout", tip = "Any of these brings the faded parts back at once. Untick one to let them stay faded through it." })
    Chk(p, "In combat", nil, "combat")
    Chk(p, "You have a target", "Anything targeted: an enemy, a friend or yourself.", "target")
    Chk(p, "Health is low", "Your health is under the mark below.", "hurt")
    Sld(p, "Health mark", "100% = shown whenever your health is not full.", 10, 100, 5, "hpbelow", Whole)
    Chk(p, "Mana or energy is low", "Your mana or energy is under the mark below. Warriors: any rage.", "power")
    Sld(p, "Mana / energy mark", "100% = shown whenever it is not full.", 10, 100, 5, "powbelow", Whole)
    Chk(p, "Casting", "While you cast or channel a spell.", "casting")
    Chk(p, "Your pet needs you", "Your pet is hurt or unhappy.", "pet")
    Chk(p, "In a group", "Always shown while you are in a party or raid.", "group")
    Chk(p, "In a dungeon, raid or battleground", "Always shown inside instances, battlegrounds and arenas; fading only out in the world.", "instance")
    Chk(p, "Resting", "Shown in inns and cities.", "resting")

    W.Card(p, "Seeing them while faded", { icon = "Interface\\Icons\\INV_Misc_Spyglass_03", tip = "Ways to look at a faded part without bringing it back for good." })
    Chk(p, "Hover to show", "Moving the mouse over a faded part shows it while the mouse is there.", "hover")
    Chk(p, "Hovering one shows all", "Hovering any faded part shows every part.", "hoverall")
    W.Dropdown(p, "Hold a key to peek", "While this key is held everything is shown.",
      { { key = "none", label = "No key" }, { key = "alt", label = "Alt" }, { key = "ctrl", label = "Ctrl" }, { key = "shift", label = "Shift" } },
      function() return G().modkey end, function(v) G().modkey = v FF.evalAt = 0 end)
    Sld(p, "Chat after a message", "Seconds the chat stays shown after a new say, whisper, party, raid or guild message (0 = not at all). It also shows while you type.", 0, 60, 1, "chatshow", function(v) return math.floor(v + .5) .. " s" end)

    W.Card(p, "The fade", { icon = "Interface\\Icons\\Spell_Shadow_Twilight", tip = "How far, how fast and after how long." })
    Sld(p, "Faded to", "0% = gone completely; higher keeps a faint outline of each part.", 0, .9, .05, "alpha", Pct)
    Sld(p, "Wait before fading", "Seconds of calm before the parts start to fade.", 0, 15, .5, "delay", Secs)
    Sld(p, "Fade out time", "How long the fade away takes.", 0, 5, .1, "fadeout", Secs)
    Sld(p, "Fade in time", "How long coming back takes (0 = at once).", 0, 2, .05, "fadein", Secs)
    Chk(p, "Fade on flight paths", "On a flight path the parts fade at once, even at low health or mana.", "taxi")
  end

  O:AddPage("Frame Fade", "framefade", "Frame fade", Build)
end)
