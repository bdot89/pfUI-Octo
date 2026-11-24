pfUI:RegisterModule("professions-octo", "vanilla", function ()
  -- pfUI Octo :: the profession windows (24 Nov 2026; user with the Forever client's profession window: "background art
  -- work in all that resemble the page ... the enchanting page"; Wolfahrt: on Enchanting a "Search" box sat on the
  -- recipe list). OctoWoW's client adds a search box and two filter ticks (have materials / skill-ups) to both windows
  -- (TradeSkillSearchBox, CraftFrameSearchBox, *MatsCheckButton, *SkillCheckButton); pfUI's skin only knew TBC's
  -- names, made the list longer and left them where the client put them - over the list.
  -- On the game's own windows (everything the server does keeps working), after pfUI's skin:
  --   top        the skill bar across the window
  --   left       search, the two filter ticks under it, then the recipes: categories as gold bars, the picked one lit
  --   right      the recipe: its picture large, what it makes and needs, and a large faint picture of the profession
  --              behind it; Create all / how many / Create along the bottom
  --   all over   the worn finish of the character window (charframe.lua)
  -- C.charframe.prof = "0" leaves pfUI's own skin.
  local PO = {}
  pfUI.professionsOcto = PO
  local function On() return C.charframe.prof ~= "0" end
  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local GOLD = { 1, .82, .25 }

  -- the profession's own picture (from its name; the server's own professions fall back to a book)
  PO.ICONS = {
    ["Alchemy"] = "Trade_Alchemy", ["Blacksmithing"] = "Trade_BlackSmithing", ["Enchanting"] = "Trade_Engraving",
    ["Engineering"] = "Trade_Engineering", ["Leatherworking"] = "INV_Misc_ArmorKit_17", ["Tailoring"] = "Trade_Tailoring",
    ["Cooking"] = "INV_Misc_Food_15", ["First Aid"] = "Spell_Holy_SealOfSacrifice", ["Mining"] = "Trade_Mining",
    ["Smelting"] = "Trade_Mining", ["Jewelcrafting"] = "INV_Misc_Gem_01", ["Fishing"] = "Trade_Fishing",
    ["Poisons"] = "Trade_BrewPoison", ["Beast Training"] = "Ability_Hunter_BeastCall", ["Survival"] = "Trade_Survival",
  }
  function PO.Icon(name)
    return "Interface\\Icons\\" .. (PO.ICONS[name or ""] or "INV_Misc_Book_09")
  end

  -- the two windows: their names and the client calls that differ
  PO.KINDS = {
    TradeSkill = { frame = "TradeSkillFrame", addon = "Blizzard_TradeSkillUI", row = "TradeSkillSkill", list = "TradeSkillListScrollFrame",
      detail = "TradeSkillDetailScrollFrame", rank = "TradeSkillRankFrame", search = "TradeSkillSearchBox",
      mats = "TradeSkillMatsCheckButton", skill = "TradeSkillSkillCheckButton", displayed = "TRADE_SKILLS_DISPLAYED",
      highlight = "TradeSkillHighlight", update = "TradeSkillFrame_Update", create = "TradeSkillCreateButton",
      createall = "TradeSkillCreateAllButton", cancel = "TradeSkillCancelButton", collapse = "TradeSkillCollapseAllButton",
      subclass = "TradeSkillSubClassDropDown", invslot = "TradeSkillInvSlotDropDown",
      info = function(i) local _, kind = GetTradeSkillInfo(i) return kind end,
      line = function() return GetTradeSkillLine() end },
    Craft = { frame = "CraftFrame", addon = "Blizzard_CraftUI", row = "Craft", list = "CraftListScrollFrame",
      detail = "CraftDetailScrollFrame", rank = "CraftRankFrame", search = "CraftFrameSearchBox",
      mats = "CraftFrameMatsCheckButton", skill = "CraftFrameSkillCheckButton", displayed = "CRAFTS_DISPLAYED",
      highlight = "CraftHighlight", update = "CraftFrame_Update", create = "CraftCreateButton",
      cancel = "CraftCancelButton", collapse = "CraftCollapseAllButton",
      info = function(i) local _, _, kind = GetCraftInfo(i) return kind end,
      line = function() return GetCraftDisplaySkillLine and GetCraftDisplaySkillLine() end },
  }

  local W0, H0 = 720, 490      -- the window
  local LEFTW = 318            -- the recipe list column
  local ROWH = 16

  local function Place(f, point, rel, relPoint, x, y)
    if not f then return end
    f:ClearAllPoints()
    f:SetPoint(point, rel, relPoint, x, y)
  end

  -- once per window, the first time it shows (pfUI's skin has run by then)
  function PO.Setup(k)
    local f = _G[k.frame]
    if not f or f.octoProf or not On() then return end
    f.octoProf = true
    f:SetWidth(W0)
    f:SetHeight(H0)
    local art = CreateFrame("Frame", nil, f)
    art:SetAllPoints(f)
    art:SetFrameLevel(math.max(0, f:GetFrameLevel()))
    f.octoArt = art
    -- the profession's picture, large and faint, behind the recipe
    art.mark = art:CreateTexture(nil, "BACKGROUND")
    art.mark:SetWidth(230)
    art.mark:SetHeight(230)
    art.mark:SetPoint("CENTER", f, "TOPLEFT", LEFTW + 24 + (W0 - LEFTW - 36) / 2, -270)
    art.mark:SetTexCoord(.08, .92, .08, .92)
    art.mark:SetVertexColor(.75, .7, .6, .09)
    -- panels: a darker well under the list and under the recipe, each with a bronze top line
    local function Well(x, y, w, h)
      local t = art:CreateTexture(nil, "BACKGROUND")
      t:SetTexture(WHITE)
      t:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
      t:SetWidth(w)
      t:SetHeight(h)
      t:SetGradientAlpha("VERTICAL", 0, 0, 0, .45, .06, .05, .04, .45)
      local line = art:CreateTexture(nil, "BORDER")
      line:SetTexture(WHITE)
      line:SetPoint("BOTTOMLEFT", t, "TOPLEFT", 0, 0)
      line:SetPoint("BOTTOMRIGHT", t, "TOPRIGHT", 0, 0)
      line:SetHeight(1)
      line:SetGradientAlpha("HORIZONTAL", .86, .68, .38, .6, .86, .68, .38, .1)
      return t
    end
    art.left = Well(10, -84, LEFTW, H0 - 84 - 12)
    art.right = Well(LEFTW + 22, -84, W0 - LEFTW - 34, H0 - 84 - 46)

    -- the skill bar across the top
    local rank = _G[k.rank]
    if rank then
      rank:ClearAllPoints()
      rank:SetPoint("TOPLEFT", f, "TOPLEFT", 140, -30)
      rank:SetPoint("TOPRIGHT", f, "TOPRIGHT", -140, -30)
      rank:SetHeight(18)
      if rank.SetStatusBarTexture then rank:SetStatusBarTexture(pfUI.media["img:honor\\bar"]) end
    end

    -- search and the two ticks (the client's own; they did sit on the list)
    local search = _G[k.search]
    if search then
      search:ClearAllPoints()
      search:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -56)
      search:SetWidth(LEFTW - 8)
      search:SetHeight(20)
      if search:GetFrameLevel() < f:GetFrameLevel() + 3 then search:SetFrameLevel(f:GetFrameLevel() + 3) end
    end
    local mats, skill = _G[k.mats], _G[k.skill]
    if mats then
      mats:ClearAllPoints()
      mats:SetPoint("TOPLEFT", f, "TOPLEFT", LEFTW + 22, -54)
      mats:SetScale(.85)
    end
    if skill and mats then
      skill:ClearAllPoints()
      skill:SetPoint("LEFT", mats, "RIGHT", 110, 0)
      skill:SetScale(1)
    end
    -- the old filter menus (trade skills): at the right end of the top row
    local sub, inv = k.subclass and _G[k.subclass], k.invslot and _G[k.invslot]
    if inv then Place(inv, "TOPRIGHT", f, "TOPRIGHT", 8, -50) end
    if sub and inv then Place(sub, "RIGHT", inv, "LEFT", 26, 0) end

    -- the recipe list, filling its well
    local list = _G[k.list]
    local rows = math.floor((H0 - 84 - 12 - 8) / ROWH)
    _G[k.displayed] = rows
    if list then
      list:ClearAllPoints()
      list:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -88)
      list:SetWidth(LEFTW - 30)
      list:SetHeight(rows * ROWH)
      if list.backdrop then list.backdrop:SetAlpha(0) end
    end
    local first = _G[k.row .. 1]
    if first and list then Place(first, "TOPLEFT", list, "TOPLEFT", 0, 0) end
    for i = 2, rows + 4 do
      local b = _G[k.row .. i]
      if not b and i <= rows then b = CreateFrame("Button", k.row .. i, f, k.row .. "ButtonTemplate") end
      if b then
        if i <= rows then Place(b, "TOPLEFT", _G[k.row .. (i - 1)], "BOTTOMLEFT", 0, 0) else b:Hide() end
      end
    end
    local collapse = _G[k.collapse]
    if collapse and list then Place(collapse, "BOTTOMLEFT", list, "TOPLEFT", -4, 2) collapse:Hide() end

    -- the recipe on the right
    local detail = _G[k.detail]
    if detail then
      detail:ClearAllPoints()
      detail:SetPoint("TOPLEFT", f, "TOPLEFT", LEFTW + 28, -90)
      detail:SetWidth(W0 - LEFTW - 70)
      detail:SetHeight(H0 - 90 - 54)
      if detail.backdrop then detail.backdrop:SetAlpha(0) end
    end
    -- the buttons along the bottom right
    local cancel, create, createall = _G[k.cancel], _G[k.create], k.createall and _G[k.createall]
    if cancel then Place(cancel, "BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14) end
    if create and cancel then Place(create, "RIGHT", cancel, "LEFT", -6, 0) end
    if createall then Place(createall, "BOTTOMLEFT", f, "BOTTOMLEFT", LEFTW + 26, 14) end

    -- the picked recipe's light: a gold bar fading to the right
    local hl = _G[k.highlight]
    if hl and hl.SetTexture then
      hl:SetTexture(WHITE)
      hl:SetGradientAlpha("HORIZONTAL", GOLD[1], GOLD[2], GOLD[3], .35, GOLD[1], GOLD[2], GOLD[3], 0)
    end
    -- categories as gold bars, every time the list is drawn
    if hooksecurefunc and _G[k.update] then
      hooksecurefunc(k.update, function() PO.Paint(k) end)
    end
    PO.Paint(k)
  end

  -- each shown row: a category = a gold bar with its name in gold, a recipe = plain
  function PO.Paint(k)
    local f = _G[k.frame]
    if not f or not f.octoProf then return end
    local name = k.line()
    if f.octoArt then f.octoArt.mark:SetTexture(PO.Icon(name)) end
    for i = 1, (_G[k.displayed] or 0) do
      local b = _G[k.row .. i]
      if b then
        if not b.octoBar then
          b.octoBar = b:CreateTexture(nil, "BACKGROUND")
          b.octoBar:SetTexture(WHITE)
          b.octoBar:SetPoint("TOPLEFT", b, "TOPLEFT", -2, -1)
          b.octoBar:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 1)
          b.octoBar:SetGradientAlpha("HORIZONTAL", .55, .36, .08, .55, .25, .16, .04, .15)
          b.octoLine = b:CreateTexture(nil, "BORDER")
          b.octoLine:SetTexture(WHITE)
          b.octoLine:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", -2, 0)
          b.octoLine:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
          b.octoLine:SetHeight(1)
          b.octoLine:SetGradientAlpha("HORIZONTAL", GOLD[1], GOLD[2], GOLD[3], .7, GOLD[1], GOLD[2], GOLD[3], 0)
        end
        local idx = b:GetID()
        local kind = b:IsShown() and idx and idx > 0 and k.info(idx)
        if kind == "header" then
          b.octoBar:Show()
          b.octoLine:Show()
          local fs = b.GetFontString and b:GetFontString()
          if fs then fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end
        else
          b.octoBar:Hide()
          b.octoLine:Hide()
        end
      end
    end
  end

  for _, k in pairs(PO.KINDS) do
    local kind = k
    local function Hook()
      local f = _G[kind.frame]
      if not f or f.octoHook or not HookScript then return end
      f.octoHook = true
      HookScript(f, "OnShow", function() PO.Setup(kind) PO.Paint(kind) end)
    end
    if HookAddonOrVariable then HookAddonOrVariable(kind.addon, Hook) else Hook() end
  end
end)
