pfUI:RegisterModule("professions-missing", "vanilla", function ()
  -- pfUI Octo :: missing recipes in the profession windows (25 Nov 2026, Javelin on Discord: "adding missing recipes to
  -- profession windows? it exists in standalone addons, but some are not working well").
  -- A "Missing" button beside the search box swaps the recipe list for the recipes this character does not know yet:
  -- every recipe of the profession (modules\professions-data.lua, made from the client's own tables by
  -- tools\Make-RecipeData.ps1) less the ones seen in this character's window. Each with the skill it needs (or where it
  -- turns yellow, for recipes taught by an item) and where it comes from, read from pfQuest's database (built in):
  -- the recipe item ("Recipe: / Plans: / Pattern: / Formula: / Schematic: / Manual: / Design: <name>") sold by a vendor,
  -- dropped, found in an object, or nothing = taught by the trainer. Hover for the details, Shift-click = link.
  -- Known recipes are remembered per character (pfUI_cache.profknown): a recipe hidden by a filter the first time you
  -- open a window counts as missing until it has been seen once.
  local PO = pfUI.professionsOcto
  if not PO or not pfUI.recipeData then return end
  local PM = {}
  pfUI.professionsMissing = PM
  local function On() return C.charframe.prof ~= "0" and C.charframe.missing ~= "0" end
  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local ROWH, LEFTW = 16, 318

  -- the names in each window (index -> name, kind) and how many lines
  PO.KINDS.TradeSkill.name = function(i) local n, kind = GetTradeSkillInfo(i) return n, kind end
  PO.KINDS.TradeSkill.count = function() return GetNumTradeSkills and GetNumTradeSkills() or 0 end
  PO.KINDS.Craft.name = function(i) local n, _, kind = GetCraftInfo(i) return n, kind end
  PO.KINDS.Craft.count = function() return GetNumCrafts and GetNumCrafts() or 0 end

  -- ---------------------------------------------------------------- what is known
  local function Who() return (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "?") end
  function PM.Known(prof)
    pfUI_cache.profknown = pfUI_cache.profknown or {}
    local me = pfUI_cache.profknown[Who()]
    if not me then
      me = {}
      pfUI_cache.profknown[Who()] = me
    end
    me[prof] = me[prof] or {}
    return me[prof]
  end
  -- every recipe line the window shows now goes into the known list
  function PM.Learn(k)
    local prof = k.line()
    if not prof or prof == "" or not k.name then return end
    local known = PM.Known(prof)
    for i = 1, k.count() do
      local n, kind = k.name(i)
      if n and kind ~= "header" then known[n] = 1 end
    end
  end

  -- ---------------------------------------------------------------- the recipe list (read once per profession)
  local parsed = {}
  PM.ALIAS = { ["Smelting"] = "Mining" }
  function PM.All(prof)
    if not pfUI.recipeData[prof] and PM.ALIAS[prof] then prof = PM.ALIAS[prof] end
    if parsed[prof] then return parsed[prof] end
    -- (Mining's window is called Smelting)
    local raw = pfUI.recipeData[prof] or pfUI.recipeData[PM.ALIAS[prof] or ""]
    if not raw then return nil end
    local list = {}
    for line in string.gfind(raw, "[^\n]+") do
      local _, _, n, need, yellow, id, icon = string.find(line, "^(.-)%^(%d+)%^(%d+)%^(%d+)%^(.*)$")
      if n then table.insert(list, { name = n, need = tonumber(need), yellow = tonumber(yellow), spell = tonumber(id), icon = icon }) end
    end
    parsed[prof] = list
    return list
  end

  -- ---------------------------------------------------------------- where a recipe comes from (pfQuest)
  local PREFIX = { Recipe = 1, Plans = 1, Pattern = 1, Formula = 1, Schematic = 1, Manual = 1, Design = 1, Sketch = 1 }
  local byName
  function PM.ItemFor(name)
    local db = _G.pfDB
    if not db or not db.items then return nil end
    if not byName then
      byName = {}
      local names = db.items.loc or db.items.enUS or {}
      for id, n in pairs(names) do
        if type(n) == "string" then
          local _, _, pre, rest = string.find(n, "^(%a+): (.+)$")
          if pre and PREFIX[pre] and not byName[rest] then byName[rest] = id end
        end
      end
    end
    return byName[name]
  end
  local function UnitName2(id)
    local db = _G.pfDB
    local n = db and db.units and (db.units.loc or db.units.enUS or {})[id]
    local zone
    local u = db and db.units and db.units.data and db.units.data[id]
    if u and u.coords and u.coords[1] then
      local z = u.coords[1][3]
      zone = z and db.zones and (db.zones.loc or db.zones.enUS or {})[z]
    end
    return n or ("#" .. id), zone
  end
  -- { tag = "Trainer" | "Vendor" | "Drop" | "Object" | "Quest", item = id, lines = { "..." } }
  function PM.Source(name)
    local id = PM.ItemFor(name)
    if not id then return { tag = "Trainer", lines = { "Taught by a profession trainer." } } end
    local data = _G.pfDB.items.data and _G.pfDB.items.data[id] or {}
    local out = { item = id, lines = {} }
    if data.V then
      out.tag = "Vendor"
      local n = 0
      for npc in pairs(data.V) do
        n = n + 1
        if n <= 3 then
          local who, zone = UnitName2(npc)
          table.insert(out.lines, "Sold by " .. who .. (zone and (" (" .. zone .. ")") or ""))
        end
      end
      if n > 3 then table.insert(out.lines, "and " .. (n - 3) .. " more vendors") end
    end
    if data.U then
      out.tag = out.tag or "Drop"
      local best = {}
      for npc, chance in pairs(data.U) do table.insert(best, { npc, tonumber(chance) or 0 }) end
      table.sort(best, function(a, b) return a[2] > b[2] end)
      for i = 1, math.min(3, table.getn(best)) do
        local who, zone = UnitName2(best[i][1])
        table.insert(out.lines, "Drops from " .. who .. (zone and (" (" .. zone .. ")") or "") .. string.format(" - %.1f%%", best[i][2]))
      end
      if table.getn(best) > 3 then table.insert(out.lines, "and " .. (table.getn(best) - 3) .. " more") end
    end
    if data.O then
      out.tag = out.tag or "Object"
      table.insert(out.lines, "Found in chests or objects in the world")
    end
    if not out.tag then
      out.tag = "Quest"
      table.insert(out.lines, "A quest reward or an event: no vendor or drop known")
    end
    return out
  end
  PM.TAGCOL = { Trainer = "|cff55ff55", Vendor = "|cff66bbff", Drop = "|cffff9f40", Object = "|cffd0a0ff", Quest = "|cffffd24d" }

  -- the missing ones, easiest first, matching the search box
  function PM.Missing(prof, filter)
    local all = PM.All(prof)
    if not all then return nil end
    local known = PM.Known(prof)
    local out = {}
    filter = filter and filter ~= "" and string.lower(filter) or nil
    for _, r in ipairs(all) do
      if not known[r.name] and (not filter or string.find(string.lower(r.name), filter, 1, true)) then table.insert(out, r) end
    end
    table.sort(out, function(a, b)
      if a.yellow ~= b.yellow then return a.yellow < b.yellow end
      if a.need ~= b.need then return a.need < b.need end
      return a.name < b.name
    end)
    return out, table.getn(all)
  end

  -- ---------------------------------------------------------------- the panel over the recipe list
  local function Rows(k) return _G[k.displayed] or 22 end
  function PM.Build(k)
    local f = _G[k.frame]
    if not f or f.octoMissing then return f and f.octoMissing end
    -- the search box makes room for the button
    local search = _G[k.search]
    if search then search:SetWidth(LEFTW - 96) end
    local btn = CreateFrame("Button", nil, f)
    btn:SetWidth(82)
    btn:SetHeight(20)
    btn:SetPoint("TOPLEFT", f, "TOPLEFT", 14 + LEFTW - 90, -56)
    btn:SetFrameLevel(f:GetFrameLevel() + 6)
    if CreateBackdrop then CreateBackdrop(btn, nil, true) end
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn:SetScript("OnClick", function() PM.Toggle(k) end)
    btn:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText("Missing recipes", 1, .82, .2)
      GameTooltip:AddLine("Every recipe of this profession you do not know yet, easiest first, with where it comes from.", .9, .9, .9, 1)
      GameTooltip:AddLine("Click again for your own recipes.", .5, .7, 1, 1)
      GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -104)
    p:SetWidth(LEFTW - 14)
    p:SetHeight(Rows(k) * ROWH)
    p:SetFrameLevel(f:GetFrameLevel() + 5)
    p:EnableMouseWheel(true)
    p.offset = 0
    p:SetScript("OnMouseWheel", function()
      local n = table.getn(p.data or {})
      p.offset = math.max(0, math.min(math.max(0, n - Rows(k)), p.offset - (arg1 or 0) * 3))
      PM.Paint(k)
    end)
    p.rows = {}
    for i = 1, Rows(k) do
      local r = CreateFrame("Button", nil, p)
      r:SetHeight(ROWH)
      r:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -(i - 1) * ROWH)
      r:SetPoint("RIGHT", p, "RIGHT", 0, 0)
      local hl = r:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints(r)
      hl:SetTexture(1, .82, .2, .12)
      r.icon = r:CreateTexture(nil, "ARTWORK")
      r.icon:SetWidth(14)
      r.icon:SetHeight(14)
      r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
      r.icon:SetTexCoord(.08, .92, .08, .92)
      r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
      r.name:SetPoint("RIGHT", r, "RIGHT", -92, 0)
      r.name:SetJustifyH("LEFT")
      r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      r.right:SetPoint("RIGHT", r, "RIGHT", -2, 0)
      r.right:SetJustifyH("RIGHT")
      r:SetScript("OnEnter", function() PM.Tip(this) end)
      r:SetScript("OnLeave", function() GameTooltip:Hide() end)
      r:SetScript("OnClick", function()
        local d = this.d
        if not d then return end
        if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
          local src = PM.Source(d.name)
          local link
          if src.item and GetItemInfo then
            local _, l = GetItemInfo(src.item)
            if l and string.find(l, "|H") then link = l end
            if not link and l then link = "|cffffffff|H" .. l .. "|h[" .. (_G.pfDB.items.loc[src.item] or d.name) .. "]|h|r" end
          end
          ChatFrameEditBox:Insert(link or d.name)
        end
      end)
      p.rows[i] = r
    end
    p.head = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p.head:SetPoint("BOTTOMLEFT", p, "TOPLEFT", 0, 4)
    p:Hide()
    f.octoMissing = p
    p.btn = btn
    PM.PaintButton(k)
    return p
  end

  function PM.PaintButton(k)
    local f = _G[k.frame]
    local p = f and f.octoMissing
    if not p then return end
    if not On() or not PM.All(k.line() or "") then p.btn:Hide() p:Hide() return end
    p.btn:Show()
    local list = PM.Missing(k.line(), nil)
    local n = list and table.getn(list) or 0
    p.btn.text:SetText(p:IsShown() and "|cffffd24dMy recipes|r" or ("Missing |cffffd24d" .. n .. "|r"))
  end

  function PM.Toggle(k, on)
    local f = _G[k.frame]
    local p = f and (f.octoMissing or PM.Build(k))
    if not p then return end
    if on == nil then on = not p:IsShown() end
    local list = _G[k.list]
    if on then
      p.offset = 0
      p:Show()
      if list then list:Hide() end
      for i = 1, Rows(k) + 4 do local b = _G[k.row .. i] if b then b:Hide() end end
      local hl = _G[k.highlight]
      if hl then hl:Hide() end
      PM.Paint(k)
    else
      p:Hide()
      if list then list:Show() end
      local up = _G[k.update]
      if up then pcall(up) end
    end
    PM.PaintButton(k)
  end

  function PM.Paint(k)
    local f = _G[k.frame]
    local p = f and f.octoMissing
    if not p or not p:IsShown() then return end
    local prof = k.line() or ""
    local search = _G[k.search]
    local data, all = PM.Missing(prof, search and search.GetText and search:GetText() or nil)
    p.data = data or {}
    local n = table.getn(p.data)
    p.head:SetText(data and ("|cffffd24d" .. n .. "|r missing of " .. (all or 0) .. " " .. prof .. " recipes") or ("No recipe list for " .. prof))
    if p.offset > math.max(0, n - Rows(k)) then p.offset = math.max(0, n - Rows(k)) end
    for i = 1, Rows(k) do
      local r, d = p.rows[i], p.data[i + p.offset]
      r.d = d
      if d then
        r.icon:SetTexture("Interface\\Icons\\" .. ((d.icon and d.icon ~= "") and d.icon or string.gsub(PO.Icon(prof), "^Interface\\Icons\\", "")))
        r.name:SetText(d.name)
        r.name:SetTextColor(.78, .78, .8)
        local src = PM.Source(d.name)
        local lvl = d.need > 0 and ("|cffffffff" .. d.need .. "|r") or ("|cffffd24d~" .. d.yellow .. "|r")
        r.right:SetText((PM.TAGCOL[src.tag] or "") .. src.tag .. "|r  " .. lvl)
        r:Show()
      else
        r:Hide()
      end
    end
  end

  function PM.Tip(r)
    local d = r.d
    if not d then return end
    GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
    GameTooltip:SetText(d.name, 1, 1, 1)
    if d.need > 0 then
      GameTooltip:AddLine("Needs skill " .. d.need .. "   yellow at " .. d.yellow, 1, .82, .2)
    else
      GameTooltip:AddLine("Turns yellow at skill " .. d.yellow .. " (the skill it needs comes with its recipe)", 1, .82, .2, 1)
    end
    local src = PM.Source(d.name)
    for _, l in ipairs(src.lines) do GameTooltip:AddLine(l, .9, .9, .9, 1) end
    if src.item and _G.pfDB and _G.pfDB.items.loc then
      GameTooltip:AddLine("Recipe: " .. (_G.pfDB.items.loc[src.item] or "?"), .6, .6, .65)
    end
    GameTooltip:AddLine("Shift-click: into chat", .5, .7, 1)
    GameTooltip:Show()
  end

  -- every window draw: note what is known, keep the button / panel up to date
  for _, kk in pairs(PO.KINDS) do
    local k = kk
    local function Hook()
      local f = _G[k.frame]
      if not f or f.octoMissingHook then return end
      f.octoMissingHook = true
      if hooksecurefunc and _G[k.update] then
        hooksecurefunc(k.update, function()
          if not _G[k.frame].octoProf then return end
          local p = _G[k.frame].octoMissing or (On() and PM.Build(k))
          if p and p:IsShown() then
            -- (the client drew its rows again: keep them hidden under the panel)
            for i = 1, Rows(k) + 4 do local b = _G[k.row .. i] if b then b:Hide() end end
            PM.Paint(k)
          else
            PM.Learn(k)
          end
          PM.PaintButton(k)
        end)
      end
      local search = _G[k.search]
      if search and HookScript then
        HookScript(search, "OnTextChanged", function() PM.Paint(k) end)
      end
      if HookScript then HookScript(f, "OnHide", function() if f.octoMissing and f.octoMissing:IsShown() then PM.Toggle(k, false) end end) end
    end
    if HookAddonOrVariable then HookAddonOrVariable(k.addon, Hook) else Hook() end
  end
end)
