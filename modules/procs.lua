pfUI:RegisterModule("procs", "vanilla", function ()
  -- pfUI Octo :: OctoProcs (20 Nov 2026, user: "Lets build procdoc in make our own version but 100x better use dlls
  -- where needed make it the best version of procdoc ever easy to maintain and simple as it can possibly be").
  -- ProcDoc's idea - something big and pulsing round your character the moment a proc is up - in our own code and
  -- look (nothing of ProcDoc copied; its pictures are not ours). What it watches is ONE table, P.LIST; how it
  -- looks is one function, P.Draw. Three kinds:
  --   buff  - a buff on you (Clearcasting, Shadow Trance...): ClassicAPI's C_UnitAuras gives name, stacks and the
  --           real time left, no tooltip scans; without it, the buff's icon is matched (GetPlayerBuffTexture)
  --   spell - a reactive spell becomes usable (Overpower, Riposte, Execute...): ClassicAPI / Nampower's
  --           C_Spell.IsSpellUsable by name, so the spell need not be on a bar; else a bar slot's IsUsableAction
  --   ready - a cooldown comes back in a fight (Judgement, Hammer of Justice)
  -- Each alert: the spell's icon, a glow, a countdown and stacks, pulsing at its place round the anchor (Move frames
  -- moves it); a soft glow at the screen's edge and a sound if wanted. Settings C.procs; options: OctoProcs.
  local P = { active = {}, frames = {}, slots = {} }
  pfUI.procs = P
  local function S() return C.procs end
  local function On(k) return S()[k] == "1" end
  local I = "Interface\\Icons\\"
  local _, CLASS = UnitClass("player")

  -- where an alert goes round the anchor: x, y in units of "spread" (sides come as a mirrored pair)
  P.PLACES = {
    { key = "top", label = "Above", x = 0, y = 1 },
    { key = "top2", label = "Above, higher", x = 0, y = 1.8 },
    { key = "left", label = "Left", x = -1, y = 0 },
    { key = "right", label = "Right", x = 1, y = 0 },
    { key = "sides", label = "Both sides", x = 1, y = 0, pair = true },
    { key = "sides2", label = "Both sides, wider", x = 1.7, y = 0, pair = true },
    { key = "below", label = "Below", x = 0, y = -1 },
  }
  local PLACE = {}
  for _, p in ipairs(P.PLACES) do PLACE[p.key] = p end

  -- ---------------------------------------------------------------- what is watched (the only list to keep)
  -- name = the buff or spell, icon = its picture, place, col = glow colour, dur = seconds a reactive window lasts
  P.LIST = {
    WARLOCK = { { "buff", "Shadow Trance", "Spell_Shadow_Twilight", "sides", "0.7,0.3,1" } },
    MAGE = {
      { "buff", "Clearcasting", "Spell_Shadow_ManaBurn", "top", "0.5,0.7,1" },
      { "buff", "Netherwind Focus", "Spell_Shadow_Teleport", "sides2", "0.7,0.4,1" },
      { "buff", "Temporal Convergence", "Spell_Nature_StormReach", "sides2", "0.4,0.8,1" },
      { "buff", "Flash Freeze", "Spell_Fire_FrostResistanceTotem", "sides", "0.4,0.8,1" },
      { "buff", "Arcane Rupture", "Spell_Arcane_Blast", "sides", "0.8,0.5,1" },
      { "buff", "Hot Streak", "Spell_Fire_Firestarter", "top2", "1,0.5,0.1", stacks = 5 },
      { "spell", "Arcane Surge", "INV_Enchant_EssenceMysticalLarge", "top2", "0.8,0.5,1", dur = 4 },
    },
    DRUID = {
      { "buff", "Clearcasting", "Spell_Shadow_ManaBurn", "top", "0.5,0.7,1" },
      { "buff", "Nature's Grace", "Spell_Nature_NaturesBlessing", "sides", "0.4,1,0.4" },
      { "buff", "Tiger's Fury", "Ability_Mount_JungleTiger", "sides2", "1,0.7,0.2" },
      { "buff", "Astral Boon", "Spell_Arcane_StarFire", "top2", "0.6,0.6,1" },
      { "buff", "Natural Boon", "Spell_Nature_AbolishMagic", "top2", "0.4,1,0.5" },
      { "buff", "Arcane Eclipse", "Spell_Nature_WispSplode", "sides2", "0.7,0.5,1" },
      { "buff", "Nature Eclipse", "Spell_Nature_AbolishMagic", "sides2", "0.4,1,0.4" },
    },
    SHAMAN = {
      { "buff", "Clearcasting", "Spell_Shadow_ManaBurn", "top", "0.5,0.7,1" },
      { "buff", "Nature's Swiftness", "Spell_Nature_RavenForm", "sides", "0.4,1,0.4" },
      { "buff", "Stormstrike", "Ability_Shaman_StormStrike", "top2", "0.4,0.7,1" },
      { "buff", "Flurry", "Ability_GhoulFrenzy", "sides2", "1,0.6,0.2" },
    },
    HUNTER = {
      { "buff", "Quick Shots", "Ability_Warrior_InnerRage", "sides", "1,0.6,0.2" },
      { "spell", "Lacerate", "Spell_Lacerate_1c", "sides2", "1,0.3,0.3", dur = 4 },
      { "spell", "Baited Shot", "INV_Misc_Food_66", "top", "1,0.8,0.3", dur = 4 },
      { "spell", "Counterattack", "Ability_Warrior_Challange", "left", "1,0.5,0.2", dur = 5 },
    },
    WARRIOR = {
      { "buff", "Enrage", "Spell_Shadow_UnholyFrenzy", "sides", "1,0.2,0.2" },
      { "spell", "Overpower", "Ability_MeleeDamage", "top", "1,0.8,0.2", dur = 5 },
      { "spell", "Execute", "INV_Sword_48", "top2", "1,0.2,0.2" },
      { "spell", "Revenge", "Ability_Warrior_Revenge", "right", "1,0.6,0.2", dur = 5 },
      { "spell", "Counterattack", "Ability_Warrior_Riposte", "left", "1,0.5,0.2", dur = 5 },
    },
    PRIEST = {
      { "buff", "Resurgence", "Spell_Holy_MindVision", "sides", "1,0.9,0.5" },
      { "buff", "Enlightened", "Spell_Holy_PowerInfusion", "top", "1,0.9,0.4" },
      { "buff", "Searing Light", "Spell_Holy_SearingLightPriest", "sides2", "1,0.8,0.3" },
      { "buff", "Shadow Veil", "Spell_Shadow_GatherShadows", "sides", "0.7,0.3,1" },
      { "buff", "Spell Blasting", "Spell_Lightning_LightningBolt01", "top2", "0.5,0.7,1" },
    },
    PALADIN = {
      { "buff", "Daybreak", "Spell_Holy_AuraMastery", "top", "1,0.9,0.4" },
      { "spell", "Hammer of Wrath", "Ability_Thunderclap", "sides", "1,0.8,0.3" },
      { "ready", "Judgement", "Spell_Holy_RighteousFury", "right", "1,0.9,0.4" },
      { "ready", "Hammer of Justice", "Spell_Holy_SealOfMight", "left", "1,0.9,0.4" },
    },
    ROGUE = {
      { "buff", "Remorseless", "Ability_FiegnDead", "sides", "1,0.3,0.3" },
      { "buff", "Tricks of the Trade", "INV_Misc_Key_03", "top", "1,0.8,0.3" },
      { "spell", "Riposte", "Ability_Warrior_Challange", "sides", "1,0.6,0.2", dur = 5 },
      { "spell", "Surprise Attack", "Ability_Rogue_SurpriseAttack", "sides2", "1,0.8,0.3", dur = 5 },
    },
  }

  -- the procs in force for you: your class's (each can be switched off or moved) and your own
  function P.Mine()
    local out = {}
    for _, e in ipairs(P.LIST[CLASS] or {}) do
      local name = e[2]
      table.insert(out, { kind = e[1], name = name, icon = I .. e[3], place = S().place[name] or e[4], col = e[5],
        dur = e.dur, stacks = e.stacks, off = S().off[name] == "1" })
    end
    for _, c in ipairs(S().custom) do
      if c.name and c.name ~= "" then
        table.insert(out, { kind = c.kind or "buff", name = c.name, icon = c.icon or (I .. "INV_Misc_QuestionMark"),
          place = c.place or "top", col = c.col or "1,0.82,0.2", dur = tonumber(c.dur), custom = true, off = c.off == "1" })
      end
    end
    return out
  end

  -- ---------------------------------------------------------------- reading the game

  -- your buffs: name -> { left = seconds or nil, count, icon }
  local tipscan
  function P.Buffs()
    local out = {}
    local ua = C_UnitAuras and C_UnitAuras.UnitAura
    if ua then
      local now, good = GetTime(), true
      for i = 1, 40 do
        local ok, name, tex, count, _, _, expires = pcall(ua, "player", i, "HELPFUL")
        if not ok then good = false break end
        if not name then break end
        out[name] = { left = (type(expires) == "number" and expires > 0) and (expires - now) or nil, count = tonumber(count) or 0, icon = tex }
      end
      if good then return out end
      out = {}
    end
    -- no ClassicAPI: the buff's icon says which it is (the watched ones have their icon), else one tooltip line
    local byIcon = {}
    for _, p in ipairs(P.mine or {}) do if p.kind == "buff" then byIcon[string.lower(p.icon)] = p.name end end
    if not GetPlayerBuff then return out end
    for i = 0, 31 do
      local id = GetPlayerBuff(i, "HELPFUL")
      if type(id) ~= "number" or id < 0 then break end
      local tex = GetPlayerBuffTexture and GetPlayerBuffTexture(id)
      local name = tex and byIcon[string.lower(tex)]
      if not name and tex and P.watchCustom then
        tipscan = tipscan or (pfUI.api and pfUI.api.libtipscan and pfUI.api.libtipscan:GetScanner("octoprocs"))
        if tipscan and tipscan.SetPlayerBuff then tipscan:SetPlayerBuff(id) name = tipscan:Line(1) end
      end
      if name then
        local left = GetPlayerBuffTimeLeft and GetPlayerBuffTimeLeft(id)
        out[name] = { left = (left and left > 0) and left or nil, count = GetPlayerBuffApplications and GetPlayerBuffApplications(id) or 0, icon = tex }
      end
    end
    return out
  end

  -- the spell book: name -> index (its last rank), read when it changes
  P.book = {}
  function P.ReadBook()
    P.book = {}
    local i = 1
    while true do
      local name = GetSpellName(i, BOOKTYPE_SPELL or "spell")
      if not name then break end
      P.book[name] = i
      i = i + 1
    end
  end
  -- can it be cast now (reactive spells)
  function P.Usable(name)
    if not P.book[name] then return false end
    local cs = rawget(_G, "C_Spell")
    if type(cs) == "table" and type(cs.IsSpellUsable) == "function" then
      local ok, usable = pcall(cs.IsSpellUsable, name)
      if ok and usable ~= nil then return usable and P.Ready(name) end
    end
    -- without it: a bar slot with the spell's icon
    local tex = GetSpellTexture(P.book[name], BOOKTYPE_SPELL or "spell")
    for slot = 1, 120 do
      if HasAction(slot) and not GetActionText(slot) and GetActionTexture(slot) == tex then
        return IsUsableAction(slot) and P.Ready(name) or false
      end
    end
    return false
  end
  -- off cooldown (the global cooldown counts as ready)
  function P.Ready(name)
    local i = P.book[name]
    if not i then return false end
    local start, dur = GetSpellCooldown(i, BOOKTYPE_SPELL or "spell")
    return not start or start == 0 or (dur or 0) <= 1.5
  end

  -- ---------------------------------------------------------------- the look

  local anchor = CreateFrame("Frame", "pfOctoProcs", UIParent)
  anchor:SetWidth(64)
  anchor:SetHeight(64)
  anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  anchor:SetFrameStrata("HIGH")
  P.anchor = anchor
  if pfUI.api and pfUI.api.UpdateMovable then pcall(pfUI.api.UpdateMovable, anchor) end

  -- the screen's edge glows in the colour of the newest proc
  local edge = CreateFrame("Frame", nil, UIParent)
  edge:SetAllPoints(UIParent)
  edge:SetFrameStrata("BACKGROUND")
  edge.parts = {}
  for i, side in ipairs({ "LEFT", "RIGHT", "TOP", "BOTTOM" }) do
    local t = edge:CreateTexture(nil, "BACKGROUND")
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetBlendMode("ADD")
    if side == "LEFT" or side == "RIGHT" then
      t:SetPoint("TOP" .. side, edge, "TOP" .. side, 0, 0) t:SetPoint("BOTTOM" .. side, edge, "BOTTOM" .. side, 0, 0) t:SetWidth(90)
      if t.SetGradientAlpha then
        if side == "LEFT" then t:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 0) else t:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 0, 1, 1, 1, 1) end
      end
    else
      t:SetPoint(side .. "LEFT", edge, side .. "LEFT", 0, 0) t:SetPoint(side .. "RIGHT", edge, side .. "RIGHT", 0, 0) t:SetHeight(70)
      if t.SetGradientAlpha then
        if side == "TOP" then t:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, 1, 1, 1, 1) else t:SetGradientAlpha("VERTICAL", 1, 1, 1, 1, 1, 1, 1, 0) end
      end
    end
    edge.parts[i] = t
  end
  edge:Hide()
  P.edge = edge

  local function Col(s)
    local _, _, r, g, b = string.find(s or "", "([%d%.]+),([%d%.]+),([%d%.]+)")
    return tonumber(r) or 1, tonumber(g) or .82, tonumber(b) or .2
  end
  P.Col = Col

  -- one alert picture: icon, glow behind it, countdown, stacks
  local function Make()
    local f = CreateFrame("Frame", nil, anchor)
    f:SetFrameStrata("HIGH")
    f.glow = f:CreateTexture(nil, "BACKGROUND")
    f.glow:SetTexture(pfUI.media and pfUI.media["img:glow"] or "Interface\\AddOns\\pfUI\\img\\glow")
    f.glow:SetBlendMode("ADD")
    f.glow:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints(f)
    f.icon:SetTexCoord(.08, .92, .08, .92)
    f.edge = f:CreateTexture(nil, "OVERLAY")
    f.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.edge:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 2)
    f.edge:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
    f.edge:SetDrawLayer("BORDER")
    f.time = f:CreateFontString(nil, "OVERLAY")
    f.time:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.count = f:CreateFontString(nil, "OVERLAY")
    f.count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 3)
    f.name = f:CreateFontString(nil, "OVERLAY")
    f.name:SetPoint("TOP", f, "BOTTOM", 0, -3)
    f:Hide()
    return f
  end
  -- the pictures for a proc: one, or a mirrored pair
  local function Pics(p)
    local f = P.frames[p.name]
    if not f then
      f = { Make(), Make() }
      P.frames[p.name] = f
    end
    return f
  end

  -- an alert drawn at time t (pulse) with left seconds (or nil) and count stacks
  function P.Draw(p, a, t)
    local pics = Pics(p)
    local pl = PLACE[p.place] or PLACE.top
    local size = tonumber(S().size) or 56
    local spread = tonumber(S().spread) or 150
    local r, g, b = Col(p.col)
    local speed = tonumber(S().speed) or 2
    local wave = On("pulse") and (.5 + .5 * math.sin((t - a.since) * speed * 3)) or 1
    -- the first moment: a quick grow, then the steady pulse
    local born = math.min(1, (t - a.since) / .25)
    local scale = (1 + (1 - born) * .6) * (1 + .08 * wave)
    local font = pfUI.font_default
    for i = 1, 2 do
      local f = pics[i]
      if i == 2 and not pl.pair then
        f:Hide()
      else
        local sx = (i == 2) and -pl.x or pl.x
        f:ClearAllPoints()
        f:SetPoint("CENTER", anchor, "CENTER", sx * spread, pl.y * spread * .7)
        f:SetWidth(size * scale)
        f:SetHeight(size * scale)
        f.icon:SetTexture(p.icon)
        f.edge:SetVertexColor(r, g, b, 1)
        f.glow:SetVertexColor(r, g, b, 1)
        f.glow:SetWidth(size * scale * 2.2)
        f.glow:SetHeight(size * scale * 2.2)
        if On("glow") then f.glow:SetAlpha(.45 + .55 * wave) f.glow:Show() else f.glow:Hide() end
        f:SetAlpha((tonumber(S().alpha) or 1) * (.75 + .25 * wave) * born)
        f.time:SetFont(font, math.floor(size * .42), "OUTLINE")
        f.count:SetFont(font, math.floor(size * .3), "OUTLINE")
        f.name:SetFont(font, 12, "OUTLINE")
        local left = a.left
        if On("timer") and left then
          f.time:SetText(left < 3 and string.format("%.1f", left) or tostring(math.floor(left + .5)))
          if left < 3 then f.time:SetTextColor(1, .3, .3) else f.time:SetTextColor(1, 1, 1) end
          f.time:Show()
        else
          f.time:Hide()
        end
        f.count:SetText((a.count or 0) > 1 and tostring(a.count) or "")
        if On("names") and i == 1 then f.name:SetText(p.name) f.name:SetTextColor(r, g, b) f.name:Show() else f.name:Hide() end
        f:Show()
      end
    end
  end
  function P.Hide(name)
    local pics = P.frames[name]
    if pics then pics[1]:Hide() pics[2]:Hide() end
  end

  -- ---------------------------------------------------------------- what is up now

  local function Sound()
    local key = S().sound
    if not key or key == "" or key == "none" then return end
    local CT = pfUI.sctB and pfUI.sctB.SCT
    if CT and CT.PlaySound then CT.PlaySound(key) else PlaySound(key) end
  end

  -- one pass: which procs are up, with time left and stacks
  function P.Scan(t)
    t = t or GetTime()
    local buffs
    local up = {}
    local fight = UnitAffectingCombat("player")
    for _, p in ipairs(P.mine or {}) do
      if not p.off then
        if p.kind == "buff" then
          buffs = buffs or P.Buffs()
          local bf = buffs[p.name]
          if bf and (not p.stacks or (bf.count or 0) >= (tonumber(S().stacksfrom) or 1)) then
            up[p.name] = { left = bf.left, count = bf.count }
          end
        elseif p.kind == "spell" then
          if P.Usable(p.name) then up[p.name] = { count = 0 } end
        elseif p.kind == "ready" then
          if fight and P.Ready(p.name) and P.book[p.name] then up[p.name] = { count = 0 } end
        end
      end
    end
    return up
  end

  -- up = { name -> { left, count } }: alerts start, move on, end
  function P.Apply(up, t)
    local byName = {}
    for _, p in ipairs(P.mine or {}) do byName[p.name] = p end
    local newest
    for name, u in pairs(up) do
      local a = P.active[name]
      local p = byName[name] or (P.testing and P.testing[name])
      if p then
        if not a then
          a = { since = t }
          P.active[name] = a
          if not P.testing then Sound() end
        end
        -- when it ends: the buff's own time, or a reactive window's from when it opened
        if u.left then a.ends = t + u.left elseif p.dur then a.ends = a.since + p.dur else a.ends = nil end
        a.count = u.count
        if not newest or a.since > newest.since then newest = a newest.p = p end
      end
    end
    for name in pairs(P.active) do
      if not up[name] then
        P.active[name] = nil
        P.Hide(name)
      end
    end
    -- the edge glow
    if newest and On("edge") then
      local r, g, b = Col(newest.p.col)
      local wave = .5 + .5 * math.sin((t - newest.since) * (tonumber(S().speed) or 2) * 3)
      for _, e in ipairs(P.edge.parts) do e:SetVertexColor(r, g, b, (tonumber(S().edgealpha) or .35) * (.6 + .4 * wave)) end
      P.edge:Show()
    else
      P.edge:Hide()
    end
    return newest
  end

  -- scan = look at the game again (ten times a second); every frame only draws
  function P.Tick(t, scan)
    t = t or GetTime()
    if scan then P.Apply(P.testing and P.TestUp(t) or P.Scan(t), t) end
    for name, a in pairs(P.active) do
      local p = P.testing and P.testing[name]
      if not p then for _, q in ipairs(P.mine or {}) do if q.name == name then p = q end end end
      a.left = a.ends and (a.ends - t) or nil
      -- a reactive window that ran out (the spell may still be usable): gone until it opens again
      if p and a.left and a.left <= 0 then
        P.Hide(name)
      elseif p then
        P.Draw(p, a, t)
      end
    end
  end

  -- ---------------------------------------------------------------- a test: every proc of yours for 8 seconds

  function P.Test()
    P.Refresh()
    P.testing = {}
    for _, p in ipairs(P.mine) do if not p.off then P.testing[p.name] = p end end
    P.testStart = GetTime()
    P.active = {}
  end
  function P.TestUp(t)
    if t - P.testStart > 8 then P.StopTest() return {} end
    local up = {}
    for name, p in pairs(P.testing) do
      up[name] = { left = p.dur and nil or (8 - (t - P.testStart)), count = p.stacks or 0 }
    end
    return up
  end
  function P.StopTest()
    P.testing = nil
    for name in pairs(P.active) do P.Hide(name) end
    P.active = {}
    P.edge:Hide()
  end

  -- ---------------------------------------------------------------- running

  function P.Refresh()
    S().off = S().off or {}
    S().place = S().place or {}
    S().custom = S().custom or {}
    P.mine = P.Mine()
    P.watchCustom = false
    for _, p in ipairs(P.mine) do if p.custom and p.kind == "buff" then P.watchCustom = true end end
    for name in pairs(P.active) do P.Hide(name) end
    P.active = {}
  end

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB" }) do ev:RegisterEvent(e) end
  ev:SetScript("OnEvent", function()
    P.ReadBook()
    if not P.mine then P.Refresh() end
  end)
  -- ten looks a second (a handful of names for your class); drawing every frame only while something is up
  ev.t = 0
  ev:SetScript("OnUpdate", function()
    ev.t = ev.t + arg1
    local scan = ev.t >= .1
    if scan then ev.t = 0 end
    if scan or next(P.active) then P.Tick(GetTime(), scan) end
  end)

  _G.SLASH_OCTOPROCS1 = "/procs"
  _G.SLASH_OCTOPROCS2 = "/procdoc"
  _G.SlashCmdList.OCTOPROCS = function(msg)
    if msg == "test" then P.Test() return end
    if pfUI.octoui and pfUI.octoui.Options and pfUI.octoui.Options.Open then
      pfUI.octoui.Options:Open("procs")
    else
      P.Test()
    end
  end
end)
