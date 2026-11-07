pfUI:RegisterModule("plates-fx", "vanilla:tbc", function ()
  -- pfUI Octo nameplates, phase 4 (docs/plates-spec.md): Plater's
  -- animations and scripts, made for 1.12 (Plater is All Rights Reserved:
  -- nothing of it is copied).
  --   Animations  your crits make the plate pop (grow and settle), bounce
  --               (a quick wobble) or flash white; a plate can pop as it
  --               becomes your target.
  --   Rules       Plater's scripts without code: up to six "when ... then
  --               ..." rules. When: the name has a word, it casts a spell,
  --               its health is below a %, it has a debuff, it is your
  --               target. Then: colour the bar, glow, bigger, smaller, hide.
  -- Settings: C.plates.anim* and C.plates.ruleN = { on, when, value,
  -- effect, color, size }. Options: Nameplates > Animations and rules.
  local P = pfUI.plates
  if not P then return end
  local Fx = {}
  P.Fx = Fx
  local S = C.plates

  local function Col(s)
    local r, g, b, a = GetStringColor(s or "1,1,1,1")
    return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
  end

  -- ---------------------------------------------------------------- animations

  Fx.ANIMS = { { "none", "None" }, { "pop", "Pop (grow and settle)" }, { "bounce", "Bounce (a quick wobble)" },
               { "flash", "Flash white" } }
  local DUR = { pop = .3, bounce = .45, flash = .35 }

  function Fx.Play(o, kind, now)
    if not kind or kind == "none" or not o then return end
    o.anim, o.animAt = kind, now or GetTime()
  end

  -- the size the animation gives the plate now (1 = its own)
  local function AnimScale(o, now)
    local kind = o.anim
    if not kind or kind == "flash" then return 1 end
    local t = (now - (o.animAt or 0)) / DUR[kind]
    if t >= 1 then o.anim = nil return 1 end
    local big = (tonumber(S.animsize) or 25) / 100
    if kind == "pop" then
      -- up fast, down slow
      if t < .3 then return 1 + big * t / .3 end
      return 1 + big * (1 - (t - .3) / .7)
    end
    -- bounce: a damped wobble
    return 1 + big * .6 * math.sin(t * math.pi * 3) * (1 - t)
  end

  -- a white flash over the health bar
  local function Flash(plate, o, now)
    if o.anim ~= "flash" then
      if o.fxflash then o.fxflash:Hide() end
      return
    end
    local t = (now - (o.animAt or 0)) / DUR.flash
    if t >= 1 then
      o.anim = nil
      if o.fxflash then o.fxflash:Hide() end
      return
    end
    if not o.fxflash then
      o.fxflash = plate.health:CreateTexture(nil, "OVERLAY")
      o.fxflash:SetTexture("Interface\\Buttons\\WHITE8X8")
      o.fxflash:SetBlendMode("ADD")
      -- (6 Nov 2026, GratisNinja: "the bar is full for half a second, then back to its fill": the white
      -- covered the whole bar, so a half empty bar looked full. Now only the filled part lights up.)
      local fill = plate.health.GetStatusBarTexture and plate.health:GetStatusBarTexture()
      o.fxflash:SetAllPoints(fill or plate.health)
    end
    o.fxflash:SetVertexColor(1, 1, 1, .7 * (1 - t))
    o.fxflash:Show()
  end

  -- ---------------------------------------------------------------- rules

  Fx.WHEN = { { "name", "Its name has" }, { "cast", "It casts" }, { "health", "Its health is below (%)" },
              { "debuff", "It has the debuff" }, { "target", "It is your target" } }
  Fx.THEN = { { "color", "Colour the health bar" }, { "glow", "Glow round it" }, { "bigger", "Make it bigger" },
              { "smaller", "Make it smaller" }, { "hide", "Hide it" } }
  Fx.RULES = 6

  -- does the plate have a debuff by that name (or icon)?
  local function HasDebuff(o, value)
    local unit = o.unit
    if not unit or value == "" then return false end
    local want = string.lower(value)
    local lc = pfUI.api and pfUI.api.libclient
    for i = 1, 16 do
      local tex = UnitDebuff(unit, i)
      if not tex then break end
      if string.find(string.lower(tex), want, 1, true) then return true end
      local name = lc and lc.Aura and lc.Aura(unit, i, true, tex)
      if name and string.lower(name) == want then return true end
    end
    return false
  end

  local function Matches(plate, o, r)
    local value = r.value or ""
    local when = r.when
    if when == "target" then return plate.istarget and true or false end
    if when == "name" then
      local name = plate.original and plate.original.name and plate.original.name:GetText() or ""
      return value ~= "" and string.find(string.lower(name), string.lower(value), 1, true) ~= nil
    end
    if when == "cast" then
      if not plate.castbar:IsShown() or value == "" then return false end
      local spell = o.castname or (plate.castbar.spell and plate.castbar.spell:GetText()) or ""
      return string.lower(spell) == string.lower(value)
    end
    if when == "health" then
      local h = plate.health
      local v = h:GetValue() or 0
      local _, mx = h:GetMinMaxValues()
      local pct = (mx and mx > 0) and v / mx * 100 or 100
      return pct < (tonumber(value) or 0)
    end
    if when == "debuff" then return HasDebuff(o, value) end
    return false
  end

  -- every rule that matches, five times a second: o.fx = { color, glow, scale, hide }
  local function Rules(plate, o, now)
    if (o.fxAt or 0) > now then return end
    o.fxAt = now + .2
    local fx
    for i = 1, Fx.RULES do
      local r = S["rule" .. i]
      if r and r.on == "1" and Matches(plate, o, r) then
        fx = fx or {}
        local e = r.effect
        if e == "color" or e == "glow" then fx[e] = r.color or "1,0.5,0,1"
        elseif e == "bigger" then fx.scale = (fx.scale or 1) * (tonumber(r.size) or 130) / 100
        elseif e == "smaller" then fx.scale = (fx.scale or 1) * 100 / (tonumber(r.size) or 130)
        elseif e == "hide" then fx.hide = true end
      end
    end
    o.fx = fx
  end
  Fx.Rules = Rules

  -- ---------------------------------------------------------------- plates.lua calls

  -- the size multiplier (animation x rules)
  function Fx.Scale(plate, o, now)
    local m = AnimScale(o, now)
    if o.fx and o.fx.scale then m = m * o.fx.scale end
    return m
  end

  function Fx.Tick(plate, o, now)
    Fx.seen[plate] = now
    -- (7 Nov 2026, GratisNinja, again: in a pop the bar was full and the wrong colour for the length of the
    -- animation, in the options preview too.) While a plate moves its bar is set again every frame - the
    -- value from the game's own bar, the colour it had just before - so nothing else can leave it full
    local hb = plate.health
    if o.anim and hb then
      local ob = plate.original and plate.original.healthbar
      if ob and ob.GetValue then
        local mn, mx = ob:GetMinMaxValues()
        local v = ob:GetValue()
        if v and mn and mx and mx > mn then
          local nudge = (mx - mn) * .002
          hb:SetMinMaxValues(mn, mx)
          hb:SetValue(v + nudge > mx and v - nudge or v + nudge)
          hb:SetValue(v)
        end
      end
      local c = o.lastColor
      if c and o.anim ~= "flash" then hb:SetStatusBarColor(c[1], c[2], c[3], c[4]) end
    elseif hb and hb.GetStatusBarColor then
      local r, g, b, a = hb:GetStatusBarColor()
      o.lastColor = { r or 1, g or 1, b or 1, a or 1 }
    end
    -- a plate that becomes your target pops
    local target = plate.istarget and true or false
    if target and not o.wasTarget then Fx.Play(o, S.animtarget, now) end
    o.wasTarget = target
    Flash(plate, o, now)
    Rules(plate, o, now)
    local fx = o.fx
    if fx then
      if fx.color then plate.health:SetStatusBarColor(Col(fx.color)) end
      if fx.glow and o.glow then
        local r, g, b = Col(fx.glow)
        o.glow:SetBackdropBorderColor(r, g, b, 1)
        o.glow:Show()
        o.fxglow = true
      end
      if fx.hide then plate:SetAlpha(0) end
    end
    -- the rule's glow goes when the rule does (the aggro glow is plates.lua's)
    if o.fxglow and not (fx and fx.glow) then
      o.fxglow = nil
      if o.glow then o.glow:Hide() end
    end
  end

  -- your crits: the plate of the one you crit animates. With the meters
  -- on, their reader parses the line (any language); else the English one.
  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "CHAT_MSG_COMBAT_SELF_HITS", "CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_COMBAT_PET_HITS",
                       "CHAT_MSG_SPELL_PET_DAMAGE" }) do
    ev:RegisterEvent(e)
  end
  local function CritTarget(event, msg)
    local M = pfUI.meters
    if M and M.Read then
      local r = M.Read(event, msg)
      if r and r.kind == "dmg" and r.crit then return r.tgt end
      return
    end
    local _, _, who = string.find(msg or "", "^Your .- crits (.-) for %d+")
    if not who then _, _, who = string.find(msg or "", "^You crit (.-) for %d+") end
    return who
  end
  Fx.CritTarget = CritTarget
  function Fx.OnCrit(name)
    if not name or S.animcrit == "none" then return end
    local now = GetTime()
    for _, plate in pairs(Fx.Plates()) do
      local o = plate.octo
      if o and plate.original and plate.original.name and plate.original.name:GetText() == name then
        Fx.Play(o, S.animcrit, now)
      end
    end
  end
  ev:SetScript("OnEvent", function()
    if S.enable ~= "1" or (S.animcrit or "none") == "none" then return end
    Fx.OnCrit(CritTarget(event, arg1))
  end)

  -- the plates on screen: the ones that ticked in the last second (pfUI
  -- keeps its own list private)
  Fx.seen = {}
  function Fx.Plates()
    local out, old = {}, GetTime() - 1
    for plate, t in pairs(Fx.seen) do
      if t >= old then table.insert(out, plate) else Fx.seen[plate] = nil end
    end
    return out
  end
end)
