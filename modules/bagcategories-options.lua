pfUI:RegisterModule("bagcategories-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the bag categories page (9 Nov 2026, modules/bagcategories.lua).
  -- Its own module so the page - and its on / off switch - stays when the
  -- categories module is switched off. The list in order (click a name to
  -- edit it), then the picked one: name, rule with a live check, "Try it"
  -- on an item, and the items always put in it.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local R = pfUI.rules
  if not W or not O or not O.AddPage or not R then return end
  local BP = { sel = 1, try = "" }
  pfUI.bagCatsOptions = BP

  local function BC() return pfUI.bagCats end
  local function Again() O:Rebuild("bagcats") end

  BP.HELP = "Checks (words match anywhere in the text, any case; several words = any of them): Name(...), NameIs(...) "
    .. "the whole name, ID(...), Type(...), Subtype(...), Equip(...) (no words: anything you can wear), Quality(...) "
    .. "poor / common / uncommon / rare / epic / legendary, MinQuality(q), MaxQuality(q), Level(min, max), Tooltip(...) "
    .. "any tooltip line, BoE(), BoP(), Soulbound(), Quest(), Stackable(), Count(min), Value(min, max) in copper. "
    .. "Join them with and / or / not and brackets, e.g.  Type(\"Trade Goods\") and Name(\"Ore\", \"Bar\") and not Quest()"

  -- what the "Try it" box says about the item typed in it
  function BP.TryText(rule)
    local cats = BC()
    if not BP.try or BP.try == "" then return "Type an item ID or part of a name from your bags." end
    local item = cats and cats.Find(BP.try)
    if not item then return "|cffff6060Nothing called that in your bags or bank.|r" end
    local info = R.Info(item)
    if not info.name then return "|cffffcc33The client does not know that item yet - see it once (a link, the bank) and try again.|r" end
    local hit, err = R.Test(rule or "", info)
    local s
    if err then
      s = "|cffff6060" .. info.name .. ": " .. tostring(err) .. "|r"
    elseif hit then
      s = "|cff40e060" .. info.name .. " matches this rule.|r"
    else
      s = "|cffaaaaaa" .. info.name .. " does not match this rule.|r"
    end
    local goes = cats and cats.Where(info)
    if goes then s = s .. "  In your bags it goes to |cffffd24d" .. goes .. "|r." end
    return s
  end

  -- the assigned item IDs as names
  function BP.ItemsText(c)
    local out = {}
    for id in string.gfind(c.items or "", "(%d+)") do
      local i = R.ItemInfo(tonumber(id))
      table.insert(out, (i and i.name or ("item " .. id)))
    end
    if table.getn(out) == 0 then return "No items assigned: only the rule picks what goes here." end
    return "Always here: " .. table.concat(out, ", ") .. "."
  end

  function BP.Rule(text)
    local fn, err = R.Compile(text or "")
    if fn then return "|cff40e060The rule reads fine.|r" end
    return "|cffff6060" .. tostring(err) .. "|r"
  end

  local function Build(p)
    W.Heading(p, "Bag categories", { on = O.ModuleSwitch("bagcategories", "Bag categories"),
      about = "Your bag and bank windows sorted into labelled groups - Quest Items, BoE, Gear, Food, Metal & Stone and "
      .. "the rest - side by side where they fit (Bagshui's idea, written fresh). Each category has a rule made of "
      .. "simple checks; an item goes to the first category in the list that it matches, or to one that names it, "
      .. "and anything left goes to Other. The loot filter uses the same rules." })
    local cats = BC()
    if not cats then
      W.Note(p, "Bag categories are off, so the bags show one plain grid. Use the switch at the top right and close the "
        .. "options to reload.")
      return
    end
    if C.bagsocto.enable ~= "1" then
      W.Note(p, "These groups show in the Octo bag windows: switch those on in the Bags tab first.", 0, true)
    end
    local list = cats.List()
    if BP.sel > table.getn(list) then BP.sel = table.getn(list) end

    W.Card(p, "Categories", { icon = "Interface\\Icons\\INV_Misc_Bag_10",
      tip = "In order: an item goes to the first one it matches. Click a name to edit it." })
    for i, c in ipairs(list) do
      local idx, cat = i, c
      local row = W.Row(p, 22, 0, 2)
      local wide = row:GetWidth() - 3 * 50 - 80
      local b = W.Button(row, idx .. ".  " .. (cat.name or "?"), wide, 20)
      b:SetPoint("LEFT", row, "LEFT", 0, 0)
      if b.label then
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", b, "LEFT", 8, 0)
        b.label:SetJustifyH("LEFT")
      end
      W.Pick(b, idx == BP.sel)
      if cat.on == "0" then b.label:SetTextColor(.5, .5, .55) end
      b:SetScript("OnClick", function() BP.sel = idx Again() end)
      W.Tip(b, cat.name, cat.rule)
      local up = W.Button(row, "Up", 46, 20)
      up:SetPoint("LEFT", b, "RIGHT", 6, 0)
      up:SetScript("OnClick", function()
        if idx > 1 then
          list[idx], list[idx - 1] = list[idx - 1], list[idx]
          BP.sel = idx - 1
          cats.Changed() Again()
        end
      end)
      local down = W.Button(row, "Down", 46, 20)
      down:SetPoint("LEFT", up, "RIGHT", 4, 0)
      down:SetScript("OnClick", function()
        if idx < table.getn(list) then
          list[idx], list[idx + 1] = list[idx + 1], list[idx]
          BP.sel = idx + 1
          cats.Changed() Again()
        end
      end)
      local sw = W.Switch(row, function() return cat.on ~= "0" end, function(v)
        cat.on = v and "1" or "0"
        cats.Changed() Again()
      end, "Use this category (off: its items go to the next one they match).")
      sw:SetPoint("RIGHT", row, "RIGHT", -4, 0)
      if sw.Refresh then sw.Refresh() end
    end
    W.Note(p, "After these: Other (anything no category takes), then Empty (free slots).")
    W.Buttons(p, {
      { "New category", function()
        table.insert(list, { name = "New category", rule = "Name(\"\")", items = "", on = "1" })
        BP.sel = table.getn(list)
        cats.Changed() Again()
      end, nil, "Adds a category at the end of the list." },
      { "Back to the defaults", function()
        CreateQuestionDialog("Put every category back as it came? Your own ones go.", function()
          cats.Reset() BP.sel = 1 Again()
        end)
      end, nil, "The list as it came, close to Bread's: Quest Items, BoE, Gear, Food ... Junk." },
    })

    local c = list[BP.sel]
    if c then
      W.Card(p, "Edit: " .. (c.name or "?"), { icon = "Interface\\Icons\\INV_Misc_Note_01",
        tip = "The picked category's name, rule and assigned items." })
      W.Edit(p, "Name", "Shown over its group in the bags.", function() return c.name end, function(v)
        if v and v ~= "" then c.name = v cats.Changed() Again() end
      end)

      W.Note(p, "Rule", 0, true)
      local box = W.Row(p, 70, 0, 4)
      local eb = W.EditBox(box, box:GetWidth() - 4)
      eb:SetMultiLine(true)
      eb:SetHeight(66)
      eb:SetTextInsets(6, 6, 4, 4)
      eb:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
      eb:SetText(c.rule or "")
      local state = W.Note(p, BP.Rule(c.rule))
      local tryOut
      eb:SetScript("OnTextChanged", function()
        state:SetText(BP.Rule(this:GetText()))
        if tryOut then tryOut:SetText(BP.TryText(this:GetText())) end
      end)
      W.Buttons(p, {
        { "Save rule", function()
          c.rule = eb:GetText()
          cats.Changed()
        end, nil, "Uses the rule in your bags now." },
        { "Undo", function() eb:SetText(c.rule or "") end, nil, "Back to the saved rule." },
      })

      W.Edit(p, "Try it on an item", "An item ID, or part of the name of something in your bags or bank.", function() return BP.try end, function(v)
        BP.try = v or ""
        if tryOut then tryOut:SetText(BP.TryText(eb:GetText())) end
      end, 260)
      tryOut = W.Note(p, BP.TryText(c.rule), 0, true)

      W.Edit(p, "Assigned items", "Item IDs, comma between them: these always go to this category, whatever "
        .. "the rules say.", function() return c.items or "" end, function(v)
        c.items = v or ""
        cats.Changed() Again()
      end, 260)
      W.Note(p, BP.ItemsText(c))
      W.Buttons(p, {
        { "Assign the Try it item", function()
          local id = R.IdOf(cats.Find(BP.try))
          if not id then return end
          local t = cats.Ids(c.items)
          if not t[id] then c.items = ((c.items or "") ~= "" and (c.items .. ",") or "") .. id end
          cats.Changed() Again()
        end, nil, "Adds the item in the Try it box to this category's items." },
        { "Remove this category", function()
          CreateQuestionDialog("Remove the category \"" .. (c.name or "?") .. "\"?", function()
            table.remove(list, BP.sel)
            BP.sel = math.max(1, BP.sel - 1)
            cats.Changed() Again()
          end)
        end, nil, "Its items go to the next category they match." },
      })
    end

    W.Card(p, "Look", { icon = "Interface\\Icons\\INV_Misc_Spyglass_02", tip = "How the groups show in the bags." })
    O.PfChk(p, "Group names", "Each group's name in small gold letters over its slots.", function() return C.bagcategories end,
      "labels", function() cats.Changed() end)

    W.Card(p, "How rules work", { icon = "Interface\\Icons\\INV_Scroll_03", tip = "The checks a rule can use." })
    W.Note(p, BP.HELP, 0, true)
  end

  O:AddPage("Bags", "bagcats", "Categories", Build)
end)
