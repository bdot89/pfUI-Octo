pfUI:RegisterModule("bulwark", "vanilla", function ()
  -- pfUI Octo :: Earthen Bulwark bar for tank shamans (18 Nov 2026; Lobo on Discord: "a display that
  -- shows you how much of it you got would be peak", about Call of Elements, which has none).
  -- OctoWoW's talent Elemental Weapons (16266 / 29079 / 29080), Rockbiter part: physical damage builds an
  -- earthen bulwark of 20% of the damage dealt (x3 with a shield), at most 20% of your maximum health; it
  -- absorbs 15% of incoming damage for 8 s or until used up. Spell.dbc (patch-O) has two buffs for it:
  --   58127 "Earthen Bulwark Durability", tooltip "Bulwark integrity is at $s1%."  = how full it is
  --   58128-58130 "Earthen Bulwark" (8 s), tooltip "Absorbs damage."                 = absorbing now
  -- The integrity % is read from the buff's tooltip (the server fills $s1); the amount shown is that share
  -- of the 20% health cap - an estimate, the server sends no amount.
  local BW = {}
  pfUI.bulwark = BW
  BW.DURA = "Earthen Bulwark Durability"
  BW.ABSORB = "Earthen Bulwark"
  BW.ICON = "Interface\\Icons\\Spell_Nature_RockBiter"
  BW.CAP = .2

  local function S() return C.bulwark end
  local function On(key) return S()[key] == "1" end
  local function Num(key, def) return tonumber(S()[key]) or def end
  local function Col(key, r, g, b, a)
    local s = S()[key]
    if type(s) == "string" and s ~= "" then
      local _, _, cr, cg, cb, ca = string.find(s, "^%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,?%s*([%d%.]*)")
      if cr then return tonumber(cr), tonumber(cg), tonumber(cb), tonumber(ca) or 1 end
    end
    return r, g, b, a or 1
  end
  BW.Col = Col

  local scanner
  local function Scanner()
    if not scanner and libtipscan and libtipscan.GetScanner then scanner = libtipscan:GetScanner("bulwark") end
    return scanner
  end
  BW.names = {}

  -- the integrity number in a tooltip's lines after the name ("Bulwark integrity is at 62%.")
  function BW.PctOf(lines)
    for _, t in ipairs(lines) do
      if type(t) == "string" then
        local _, _, n = string.find(t, "(%d+%.?%d*)%s*%%")
        if n then return tonumber(n) end
      end
    end
  end

  -- the integrity of one aura: Spell.dbc gives 58127 a base value of 1 per stack ("$s1%" = 1), so the server
  -- most likely keeps the % in the stack count; the tooltip number is used when it is more (19 Nov 2026, Lobo:
  -- the bar said 0% with the bulwark full - it was read from the buff list only and from the tooltip only)
  function BW.Integrity(tip, stacks)
    tip, stacks = tonumber(tip), tonumber(stacks)
    if stacks and stacks > 1 and (not tip or stacks > tip) then return stacks end
    return tip or stacks or 0
  end

  -- ClassicAPI: the aura by spell id (applications / points), nil without it
  function BW.ReadCAPI()
    local CU = _G.C_UnitAuras
    if not CU or not CU.GetPlayerAuraBySpellID then return nil end
    local ok, a = pcall(CU.GetPlayerAuraBySpellID, 58127)
    if not ok or type(a) ~= "table" then return nil end
    local pts = type(a.points) == "table" and tonumber(a.points[1]) or nil
    return BW.Integrity(pts, a.applications or a.count or a.charges), a.icon
  end

  -- { pct, absorbing, left, tex } from the player's buffs AND debuffs (the integrity aura may be either)
  function BW.Read()
    local out = { pct = nil, absorbing = false, left = 0 }
    if not GetPlayerBuff then return out end
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
      for i = 0, 31 do
        local bid = GetPlayerBuff(i, filter)
        if type(bid) ~= "number" or bid < 0 then break end
        local tex = GetPlayerBuffTexture and GetPlayerBuffTexture(bid)
        local key = bid .. ":" .. tostring(tex)
        local name = BW.names[key]
        local sc
        if name == nil then
          sc = Scanner()
          if sc and sc.SetPlayerBuff then sc:SetPlayerBuff(bid) name = sc:Line(1) end
          BW.names[key] = name or false
        end
        if name == BW.DURA then
          sc = sc or Scanner()
          local tip
          if sc and sc.SetPlayerBuff then
            sc:SetPlayerBuff(bid)
            tip = BW.PctOf({ sc:Line(2), sc:Line(3), sc:Line(4) })
          end
          local stacks = GetPlayerBuffApplications and GetPlayerBuffApplications(bid)
          out.pct = math.max(out.pct or 0, BW.Integrity(tip, stacks))
          out.tex = out.tex or tex
        elseif name == BW.ABSORB then
          out.absorbing = true
          local left = GetPlayerBuffTimeLeft and GetPlayerBuffTimeLeft(bid)
          out.left = type(left) == "number" and left > 0 and left or 0
          out.tex = tex or out.tex
        end
      end
    end
    local cp = BW.ReadCAPI()
    if cp and cp > (out.pct or 0) then out.pct = cp end
    if out.pct then out.pct = math.min(100, out.pct) end
    return out
  end

  -- a shield in the off hand triples what is built
  function BW.Shield()
    local link = GetInventoryItemLink and GetInventoryItemLink("player", 17)
    if not link then return false end
    local _, _, id = string.find(link, "item:(%d+)")
    if not id then return false end
    local _, _, _, _, _, sub, _, loc = _G.GetItemInfo(tonumber(id))
    return loc == "INVTYPE_SHIELD" or sub == "Shields" or sub == "Shield"
  end

  -- what the bar shows: { pct, amount, cap, absorbing, left, shield, tex }
  function BW.View()
    local r = BW.Read()
    local maxhp = UnitHealthMax and UnitHealthMax("player") or 0
    local cap = math.floor(maxhp * BW.CAP + .5)
    local pct = r.pct
    return { pct = pct, has = pct ~= nil or r.absorbing, amount = pct and math.floor(cap * pct / 100 + .5) or 0, cap = cap,
      absorbing = r.absorbing, left = r.left, shield = BW.Shield(), tex = r.tex }
  end

  -- a made-up bulwark filling and draining for the preview / layout mode
  function BW.Sample(now)
    local t = math.mod(now or GetTime(), 12)
    local pct = t < 6 and math.floor(t / 6 * 100) or math.floor((12 - t) / 6 * 100)
    local absorbing = t >= 6
    return { pct = pct, has = true, amount = math.floor(1000 * pct / 100), cap = 1000, absorbing = absorbing,
      left = absorbing and (8 - (t - 6)) or 0, shield = true, sample = true }
  end

  local function Comma(n)
    local s = tostring(math.floor(n or 0))
    local out = ""
    while string.len(s) > 3 do
      out = "," .. string.sub(s, -3) .. out
      s = string.sub(s, 1, -4)
    end
    return s .. out
  end
  BW.Comma = Comma

  function BW.Text(view)
    local mode = S().textmode or "both"
    local pct = (view.pct or 0) .. "%"
    local amt = "~" .. Comma(view.amount) .. " / " .. Comma(view.cap)
    if mode == "pct" then return pct end
    if mode == "amount" then return amt end
    return pct .. "   " .. amt
  end

  function BW.NewBar(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetWidth(180) f:SetHeight(14)
    if pfUI.api.CreateBackdrop then pfUI.api.CreateBackdrop(f, nil, true) end
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetAllPoints(f)
    f.bar:SetMinMaxValues(0, 100)
    f.bg = f.bar:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(f.bar)
    f.timer = CreateFrame("StatusBar", nil, f)
    f.timer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    f.timer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.timer:SetHeight(2)
    f.timer:SetMinMaxValues(0, 8)
    f.timer:SetFrameLevel(f.bar:GetFrameLevel() + 1)
    f.over = CreateFrame("Frame", nil, f)
    f.over:SetAllPoints(f)
    f.over:SetFrameLevel(f.bar:GetFrameLevel() + 2)
    f.text = f.over:CreateFontString(nil, "OVERLAY")
    f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.time = f.over:CreateFontString(nil, "OVERLAY")
    f.time:SetPoint("RIGHT", f, "RIGHT", -3, 0)
    f.tag = f.over:CreateFontString(nil, "OVERLAY")
    f.tag:SetPoint("LEFT", f, "LEFT", 3, 0)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetTexCoord(.08, .92, .08, .92)
    f.iconframe = CreateFrame("Frame", nil, f)
    if pfUI.api.CreateBackdrop then pfUI.api.CreateBackdrop(f.iconframe, nil, true) end
    f.icon:SetParent(f.iconframe)
    f.icon:SetAllPoints(f.iconframe)
    return f
  end

  function BW.Paint(f, view)
    -- (while stuck under the totem bars, their width; your own width setting stays yours)
    local w, h = (BW.attached and BW.attachW) or Num("width", 180), Num("height", 14)
    f:SetWidth(w) f:SetHeight(h)
    local tex = S().texture
    if not tex or tex == "" then tex = "Interface\\AddOns\\pfUI\\img\\bar_elvui" end
    local font = pfUI.font_unit or pfUI.font_default or STANDARD_TEXT_FONT
    local size = Num("textsize", 11)
    -- (25 Nov 2026, code review: three SetFont and three SetTexture calls ten times a second) the look only when a
    -- setting of it changed
    local look = tex .. "^" .. tostring(font) .. "^" .. size .. "^" .. tostring(S().bgcolor) .. "^" .. tostring(S().textcolor)
    if f.look ~= look then
      f.look = look
      f.bar:SetStatusBarTexture(tex)
      f.timer:SetStatusBarTexture(tex)
      f.bg:SetTexture(tex)
      local br, bg, bb, ba = Col("bgcolor", .1, .08, .05, .8)
      f.bg:SetVertexColor(br, bg, bb, ba)
      for _, fs in ipairs({ f.text, f.time, f.tag }) do fs:SetFont(font, size, "OUTLINE") end
      local tr, tg, tb = Col("textcolor", 1, 1, 1, 1)
      f.text:SetTextColor(tr, tg, tb)
      f.time:SetTextColor(tr, tg, tb)
    end
    local r, g, b, a
    if view.absorbing then r, g, b, a = Col("activecolor", 1, .82, .35, 1) else r, g, b, a = Col("color", .72, .52, .28, 1) end
    f.bar:SetStatusBarColor(r, g, b, a)
    f.bar:SetValue(math.max(0, math.min(100, view.pct or 0)))

    f.text:SetText(On("text") and BW.Text(view) or "")

    local showTimer = On("timer") and view.absorbing and (view.left or 0) > 0
    if showTimer then
      local cr, cg, cb, ca = Col("timercolor", 1, 1, 1, .9)
      f.timer:SetStatusBarColor(cr, cg, cb, ca)
      f.timer:SetValue(view.left)
      f.timer:Show()
      f.time:SetText(string.format("%.1f", view.left))
    else
      f.timer:Hide()
      f.time:SetText("")
    end
    if On("shieldtag") and view.shield then
      f.tag:SetText("x3")
      f.tag:SetTextColor(.55, .85, 1)
    else
      f.tag:SetText("")
    end

    if On("icon") then
      f.iconframe:ClearAllPoints()
      f.iconframe:SetPoint("RIGHT", f, "LEFT", -3, 0)
      f.iconframe:SetWidth(h) f.iconframe:SetHeight(h)
      f.icon:SetTexture(view.tex or BW.ICON)
      f.icon:SetDesaturated(not view.absorbing and (view.pct or 0) <= 0)
      f.iconframe:Show()
    else
      f.iconframe:Hide()
    end
  end

  -- shown on screen?
  function BW.Wanted(view)
    if not On("enable") or not BW.shaman then return false end
    local mode = S().show or "auto"
    if mode == "always" then return true end
    local fight = UnitAffectingCombat and UnitAffectingCombat("player")
    if mode == "combat" then return fight and true or false end
    return (fight or (view.has and (view.pct or 0) > 0) or view.absorbing) and true or false
  end

  local _, class = UnitClass("player")
  BW.shaman = class == "SHAMAN"

  local holder = CreateFrame("Frame", "pfBulwark", UIParent)
  holder:SetPoint("CENTER", UIParent, "CENTER", 0, -170)
  holder:SetWidth(180)
  holder:SetHeight(14)
  BW.holder = holder
  local bar = BW.NewBar(holder)
  bar:SetPoint("CENTER", holder, "CENTER", 0, 0)
  BW.bar = bar
  if UpdateMovable then UpdateMovable(holder) end

  function BW.Update(now)
    local layout = pfUI.unlock and pfUI.unlock.IsShown and pfUI.unlock:IsShown()
    local view = BW.View()
    local show = BW.Wanted(view)
    if not show and layout and On("enable") then view, show = BW.Sample(now), true end
    holder:SetWidth(Num("width", 180))
    holder:SetHeight(Num("height", 14))
    holder:SetAlpha(Num("alpha", 1))
    -- (19 Nov 2026) merged with OctoTotems: stuck under the totem bars, as wide as them
    local tot = _G.pfOctoTotems
    if On("attach") and tot and tot:IsShown() and C.octototems and C.octototems.layout ~= "apart" then
      local w = (tot:GetWidth() or 160) * (tot:GetScale() or 1)
      holder:ClearAllPoints()
      holder:SetPoint("TOP", tot, "BOTTOM", 0, -Num("attachgap", 5) / (tot:GetScale() or 1))
      holder:SetScale(1)
      -- (25 Nov 2026, code review: this wrote over your saved width every tick) kept apart
      BW.attachW = math.floor(w + .5)
      holder:SetWidth(w)
      BW.attached = true
    elseif BW.attached then
      BW.attached, BW.attachW = nil, nil
      holder:ClearAllPoints()
      holder:SetPoint("CENTER", UIParent, "CENTER", 0, -170)
      if UpdateMovable then UpdateMovable(holder) end
    end
    if not show then
      if bar:IsShown() then bar:Hide() end
      return view
    end
    BW.Paint(bar, view)
    if not bar:IsShown() then bar:Show() end
    return view
  end

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_AURAS_CHANGED")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:SetScript("OnEvent", function() BW.names = {} this.tick = 0 end)
  ev:SetScript("OnUpdate", function()
    if (this.tick or 0) > GetTime() then return end
    this.tick = GetTime() + .1
    if not BW.shaman and not (pfUI.unlock and pfUI.unlock.IsShown and pfUI.unlock:IsShown()) then
      if bar:IsShown() then bar:Hide() end
      this.tick = GetTime() + 2
      return
    end
    BW.Update(GetTime())
  end)

  _G.SLASH_PFBULWARK1 = "/bulwark"
  -- /bulwark debug: what the game says about every bulwark aura (to find where the integrity number is)
  function BW.Debug()
    local function Say(t) DEFAULT_CHAT_FRAME:AddMessage("|cffc8a050Bulwark:|r " .. t) end
    local found = 0
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
      for i = 0, 31 do
        local bid = GetPlayerBuff and GetPlayerBuff(i, filter)
        if type(bid) ~= "number" or bid < 0 then break end
        local sc = Scanner()
        if sc and sc.SetPlayerBuff then
          sc:SetPlayerBuff(bid)
          local name = sc:Line(1)
          if name and string.find(name, "Bulwark") then
            found = found + 1
            local stacks = GetPlayerBuffApplications and GetPlayerBuffApplications(bid)
            local left = GetPlayerBuffTimeLeft and GetPlayerBuffTimeLeft(bid)
            Say(string.format("%s (%s %d): stacks %s, %s s left, tooltip: %s | %s", name, filter, i, tostring(stacks),
              tostring(left and math.floor(left * 10) / 10), tostring(sc:Line(2)), tostring(sc:Line(3))))
          end
        end
      end
    end
    local CU = _G.C_UnitAuras
    if CU and CU.GetPlayerAuraBySpellID then
      local ok, a = pcall(CU.GetPlayerAuraBySpellID, 58127)
      if ok and type(a) == "table" then
        local pts = type(a.points) == "table" and table.concat(a.points, ",") or "none"
        Say("ClassicAPI 58127: applications " .. tostring(a.applications) .. ", points " .. pts)
      else Say("ClassicAPI 58127: no aura") end
    end
    if found == 0 then Say("no Earthen Bulwark aura on you right now.") end
    local v = BW.View()
    Say("bar reads " .. tostring(v.pct) .. "%")
  end

  _G.SlashCmdList.PFBULWARK = function(msg)
    if msg and string.find(string.lower(msg), "debug") then BW.Debug() return end
    local O = pfUI.octoui and pfUI.octoui.Options
    if O and O.Open then pfUI.gui:Show() O:Open("bulwark") end
  end
end)
