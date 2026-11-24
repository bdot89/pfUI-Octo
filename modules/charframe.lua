pfUI:RegisterModule("charframe", "vanilla", function ()
  -- pfUI Octo :: the character window in battle colours (23 Nov 2026; user: "make this page and the character frame up to
  -- date with what we are doing", then "make it look amazing like PvP ... battle and worn"). Goes with the Honor page
  -- (honor.lua) and uses its art (img\honor, tools\MakeHonorArt.ps1):
  --   window     grime, scratches, burnt edges and a bronze line on pfUI's own window backdrop - under every tab's content
  --   model      a dark vignette and your faction's crest behind your character
  --   header     your name in battle gold with your PvP rank badge beside it
  --   gear       a soft glow in the item's quality colour round every worn item of rare or better
  --   stats      worn panels under the stat columns (BetterCharacterStats) instead of the game's grey boxes
  -- Settings C.charframe (options: Quality of Life > Honor, "Character window"). Off = pfUI's plain skin (reload).
  local CF = {}
  pfUI.charframe = CF
  local function G() return C.charframe end
  local ART = "img:honor\\"
  local BRONZE = { .86, .68, .38 }
  local SLOTS = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot",
    "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
    "MainHandSlot", "SecondaryHandSlot", "RangedSlot", "AmmoSlot" }
  CF.SLOTS = SLOTS

  local function Tex(parent, layer, path, r, g, b, a)
    local t = parent:CreateTexture(nil, layer)
    if path then t:SetTexture(path) end
    if r then t:SetVertexColor(r, g, b, a or 1) end
    return t
  end

  -- the worn window: textures on pfUI's backdrop frame (it lies under every tab's frames)
  function CF.Dress()
    local cf = _G.CharacterFrame
    local bd = cf and cf.backdrop
    if not bd or CF.worn then return CF.worn end
    local w = {}
    CF.worn = w
    w.shade = Tex(bd, "BORDER", "Interface\\Buttons\\WHITE8X8", .03, .02, .015, .55)
    w.shade:SetAllPoints(bd)
    w.grime = Tex(bd, "ARTWORK", pfUI.media[ART .. "grime"], 1, 1, 1, .85)
    w.grime:SetAllPoints(bd)
    w.scratch = Tex(bd, "ARTWORK", pfUI.media[ART .. "scratch"], 1, 1, 1, .18)
    w.scratch:SetAllPoints(bd)
    w.scratch:SetBlendMode("ADD")
    w.burn = Tex(bd, "OVERLAY", pfUI.media[ART .. "burn"], 1, 1, 1, .9)
    w.burn:SetAllPoints(bd)
    -- a bronze line just inside the edge
    w.lines = {}
    local function Line(a1, a2, horizontal)
      local t = Tex(bd, "OVERLAY", "Interface\\Buttons\\WHITE8X8", BRONZE[1], BRONZE[2], BRONZE[3], .3)
      t:SetPoint(a1, bd, a1, (string.find(a1, "LEFT") and 3) or -3, (string.find(a1, "TOP") and -3) or 3)
      t:SetPoint(a2, bd, a2, (string.find(a2, "LEFT") and 3) or -3, (string.find(a2, "TOP") and -3) or 3)
      if horizontal then t:SetHeight(1) else t:SetWidth(1) end
      table.insert(w.lines, t)
    end
    Line("TOPLEFT", "TOPRIGHT", true)
    Line("BOTTOMLEFT", "BOTTOMRIGHT", true)
    Line("TOPLEFT", "BOTTOMLEFT", false)
    Line("TOPRIGHT", "BOTTOMRIGHT", false)

    -- behind the model: a dark round shade and the faction crest (on PaperDollFrame, under the model)
    local pd, model = _G.PaperDollFrame, _G.CharacterModelFrame
    if pd and model then
      w.vignette = Tex(pd, "BACKGROUND", pfUI.media[ART .. "spark"], 0, 0, 0, .75)
      w.vignette:SetPoint("CENTER", model, "CENTER", 0, -10)
      w.vignette:SetWidth(300)
      w.vignette:SetHeight(300)
      w.crest = Tex(pd, "BORDER", nil)
      w.crest:SetPoint("CENTER", model, "CENTER", 0, 6)
      w.crest:SetWidth(200)
      w.crest:SetHeight(200)
      w.crest:SetBlendMode("ADD")
      w.floor = Tex(pd, "ARTWORK", pfUI.media[ART .. "spark"], 0, 0, 0, .9)
      w.floor:SetPoint("CENTER", model, "BOTTOM", 0, 18)
      w.floor:SetWidth(170)
      w.floor:SetHeight(34)
    end

    -- the rank badge beside the name
    if _G.CharacterNameText then
      w.badge = Tex(cf, "OVERLAY", nil)
      w.badge:SetWidth(18)
      w.badge:SetHeight(18)
      w.badge:SetPoint("RIGHT", _G.CharacterNameText, "LEFT", -4, 0)
    end

    -- worn panels under the stat columns
    local bcs = _G.BCSFrame
    if bcs then
      w.stats = {}
      for i, side in ipairs({ "Left", "Right" }) do
        local top = _G["PlayerStat" .. side .. "Top"]
        local p = Tex(bcs, "BACKGROUND", pfUI.media[ART .. "bar"], .16, .13, .11, .9)
        p:SetPoint("TOPLEFT", bcs, "TOPLEFT", (i - 1) * 115 + 1, 0)
        p:SetWidth(113)
        p:SetHeight(84)
        local g = Tex(bcs, "ARTWORK", pfUI.media[ART .. "grime"], 1, 1, 1, .6)
        g:SetAllPoints(p)
        local edge = Tex(bcs, "OVERLAY", "Interface\\Buttons\\WHITE8X8", BRONZE[1], BRONZE[2], BRONZE[3], .35)
        edge:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
        edge:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
        edge:SetHeight(1)
        table.insert(w.stats, p) table.insert(w.stats, g) table.insert(w.stats, edge)
        w.statTop = w.statTop or {}
        if top then table.insert(w.statTop, top) end
      end
    end

    -- a glow round every worn item of rare or better
    w.glow = {}
    for _, name in ipairs(SLOTS) do
      local slot = _G["Character" .. name]
      if slot then
        local host = slot.backdrop or slot
        local t = Tex(host, "BACKGROUND", pfUI.media[ART .. "spark"])
        t:SetPoint("CENTER", slot, "CENTER", 0, 0)
        t:SetWidth((slot:GetWidth() or 37) * 1.9)
        t:SetHeight((slot:GetHeight() or 37) * 1.9)
        t:SetBlendMode("ADD")
        t:Hide()
        w.glow[name] = t
      end
    end
    return w
  end

  -- the game's grey stat boxes under BetterCharacterStats' columns
  local STATBOXES = { "PlayerStatLeftTop", "PlayerStatLeftMiddle", "PlayerStatLeftBottom", "PlayerStatRightTop",
    "PlayerStatRightMiddle", "PlayerStatRightBottom" }

  function CF.Paint()
    local w = CF.worn
    if not w then return end
    local on = G().enable ~= "0"
    local function Vis(t, v) if t then if v then t:Show() else t:Hide() end end end
    Vis(w.shade, on) Vis(w.grime, on) Vis(w.scratch, on) Vis(w.burn, on)
    for _, t in ipairs(w.lines) do Vis(t, on) end
    w.shade:SetVertexColor(.03, .02, .015, tonumber(G().dark) or .55)
    -- model backdrop
    local faction = UnitFactionGroup("player") or "Horde"
    local cr, cg, cb = .78, .12, .08
    if faction == "Alliance" then cr, cg, cb = .16, .4, .9 end
    Vis(w.vignette, on) Vis(w.floor, on)
    if w.crest then
      w.crest:SetTexture("Interface\\PvPRankBadges\\PvPRank" .. faction)
      w.crest:SetVertexColor(cr, cg, cb, .22)
      Vis(w.crest, on and G().crest ~= "0")
    end
    -- name in battle gold, rank badge beside it
    local name = _G.CharacterNameText
    if name and on then
      name:SetFont(pfUI.font_default, 15, "OUTLINE")
      name:SetTextColor(1, .82, .45)
    end
    if w.badge then
      local rank = UnitPVPRank and UnitPVPRank("player") or 0
      local _, num = nil, 0
      if GetPVPRankInfo then _, num = GetPVPRankInfo(rank) end
      num = tonumber(num) or 0
      if on and G().badge ~= "0" and num > 0 then
        w.badge:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", num))
        w.badge:Show()
      else
        w.badge:Hide()
      end
    end
    -- stat panels
    if w.stats then
      for _, t in ipairs(w.stats) do Vis(t, on) end
      for _, n in ipairs(STATBOXES) do
        local t = _G[n]
        if t then t:SetAlpha(on and 0 or 1) end
      end
    end
    CF.Glows()
  end

  -- quality glows on the worn items
  function CF.Glows()
    local w = CF.worn
    if not w then return end
    local on = G().enable ~= "0" and G().glow ~= "0"
    for _, name in ipairs(SLOTS) do
      local t = w.glow[name]
      local slot = _G["Character" .. name]
      if t and slot then
        local q = on and GetInventoryItemQuality and GetInventoryItemQuality("player", slot:GetID()) or nil
        if q and q >= 3 and GetItemQualityColor then
          local r, g, b = GetItemQualityColor(q)
          t:SetVertexColor(r, g, b, q >= 4 and .7 or .5)
          t:Show()
        else
          t:Hide()
        end
      end
    end
  end

  -- built the first time the window opens (after pfUI's skin made its backdrop), painted on every open
  local cf = _G.CharacterFrame
  if cf and HookScript then
    HookScript(cf, "OnShow", function()
      if G().enable == "0" and not CF.worn then return end
      CF.Dress()
      CF.Paint()
    end)
  end
  -- ---------------------------------------------------------------- the other windows

  -- (24 Nov 2026, user: "make sure this styling is on all character windows") the same worn finish - grime, scratches,
  -- burnt edges, a bronze line - on any window pfUI has skinned (its backdrop frame lies under the window's own parts).
  -- C.charframe.others = "0" leaves them plain.
  function CF.DressFrame(f)
    local bd = f and f.backdrop
    if not bd then return nil end
    if f.pfWorn then return f.pfWorn end
    local w = { lines = {} }
    f.pfWorn = w
    w.shade = Tex(bd, "BORDER", "Interface\\Buttons\\WHITE8X8", .03, .02, .015, .5)
    w.shade:SetAllPoints(bd)
    w.grime = Tex(bd, "ARTWORK", pfUI.media[ART .. "grime"], 1, 1, 1, .8)
    w.grime:SetAllPoints(bd)
    w.scratch = Tex(bd, "ARTWORK", pfUI.media[ART .. "scratch"], 1, 1, 1, .16)
    w.scratch:SetAllPoints(bd)
    w.scratch:SetBlendMode("ADD")
    w.burn = Tex(bd, "OVERLAY", pfUI.media[ART .. "burn"], 1, 1, 1, .85)
    w.burn:SetAllPoints(bd)
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
      { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
      local t = Tex(bd, "OVERLAY", "Interface\\Buttons\\WHITE8X8", BRONZE[1], BRONZE[2], BRONZE[3], .3)
      t:SetPoint(e[1], bd, e[1], (string.find(e[1], "LEFT") and 3) or -3, (string.find(e[1], "TOP") and -3) or 3)
      t:SetPoint(e[2], bd, e[2], (string.find(e[2], "LEFT") and 3) or -3, (string.find(e[2], "TOP") and -3) or 3)
      if e[3] then t:SetHeight(1) else t:SetWidth(1) end
      table.insert(w.lines, t)
    end
    return w
  end
  function CF.PaintFrame(f)
    local w = f and f.pfWorn
    if not w then return end
    local on = G().enable ~= "0" and G().others ~= "0"
    for _, t in ipairs({ w.shade, w.grime, w.scratch, w.burn }) do if on then t:Show() else t:Hide() end end
    for _, t in ipairs(w.lines) do if on then t:Show() else t:Hide() end end
    w.shade:SetVertexColor(.03, .02, .015, tonumber(G().dark) or .55)
  end
  -- the windows: name, and the add-on that brings it (nil = always there)
  CF.OTHERS = { { "SpellBookFrame" }, { "QuestLogFrame" }, { "TalentFrame", "Blizzard_TalentUI" },
    { "TradeSkillFrame", "Blizzard_TradeSkillUI" }, { "CraftFrame", "Blizzard_CraftUI" } }
  local function Watch(name)
    local f = _G[name]
    if not f or f.pfWornHook or not HookScript then return end
    f.pfWornHook = true
    HookScript(f, "OnShow", function()
      if G().enable == "0" or G().others == "0" then if this.pfWorn then CF.PaintFrame(this) end return end
      CF.DressFrame(this)
      CF.PaintFrame(this)
    end)
  end
  for _, e in ipairs(CF.OTHERS) do
    local name = e[1]
    if e[2] and HookAddonOrVariable then HookAddonOrVariable(e[2], function() Watch(name) end) else Watch(name) end
  end

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("UNIT_INVENTORY_CHANGED")
  ev:RegisterEvent("PLAYER_PVP_RANK_CHANGED")
  ev:SetScript("OnEvent", function()
    if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
    if cf and cf:IsVisible() and CF.worn then CF.Paint() end
  end)
end)
