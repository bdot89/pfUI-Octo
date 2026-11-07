pfUI:RegisterModule("gryphons", "vanilla:tbc", function ()
  pfUI.gryphons = {
    frames = {
      left = CreateFrame("Frame"),
      right = CreateFrame("Frame"),
    }
  }

  pfUI.gryphons.textures = {
    ["None"] = nil,
    ["Gryphon"] = "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf",
    ["Lion"] = "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Human",
  }

  -- octo (24 Oct 2026): more of the client's own art for the bar ends (every
  -- path checked in the MPQ listfiles). coords = the part of the texture that
  -- is the picture; each one looks right as stored, so the left end shows it
  -- as it is and the right end mirrored (C.bars.gryphons.mirror swaps that)
  pfUI.gryphons.art = {
    { key = "Gryphon", label = "Gryphon", tex = "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf" },
    { key = "Lion", label = "Lion", tex = "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Human" },
    { key = "Dragon", label = "Gold dragon", tex = "Interface\\DialogFrame\\UI-DialogBox-Gold-Dragon" },
    { key = "Dragon2", label = "Rising dragon", tex = "Interface\\DialogFrame\\UI-DialogBox-Gold-Dragon2", coords = { 0, .87, 0, .78 } },
    { key = "Elite", label = "Elite dragon", tex = "Interface\\TargetingFrame\\UI-TargetingFrame-Elite", coords = { .56, 1, 0, .85 } },
    { key = "Rare", label = "Silver dragon", tex = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare", coords = { .56, 1, 0, .85 } },
  }
  for _, a in ipairs(pfUI.gryphons.art) do
    pfUI.gryphons.textures[a.key] = a.tex
    a.coords = a.coords or { 0, 1, 0, 1 }
  end
  function pfUI.gryphons.Art(key)
    for _, a in ipairs(pfUI.gryphons.art) do if a.key == key then return a end end
  end

  -- (7 Nov 2026, Mr_Rosh: support for pfUI-CustomMedia, github.com/mr-rosh/pfUI-CustomMedia, MIT) Add-ons that
  -- bring their own gryphon pictures put them in pfUI.gryphons.textures (name -> path) as pfUI's own page
  -- expects; the picture list of this page is made from pfUI.gryphons.art, so they are added to it as they
  -- come: at login, when everything has loaded. (Its bar textures and fonts go into pfUI.gui.dropdowns lists,
  -- which every Octo texture / font menu reads when it opens.)
  function pfUI.gryphons.MergeTextures()
    local have = {}
    for _, a in ipairs(pfUI.gryphons.art) do have[a.key] = true end
    local added = 0
    for name, path in pairs(pfUI.gryphons.textures) do
      if type(name) == "string" and type(path) == "string" and not have[name] then
        table.insert(pfUI.gryphons.art, { key = name, label = name, tex = path, coords = { 0, 1, 0, 1 } })
        added = added + 1
      end
    end
    return added
  end
  local gm = CreateFrame("Frame")
  gm:RegisterEvent("PLAYER_LOGIN")
  gm:SetScript("OnEvent", function()
    pfUI.gryphons.MergeTextures()
    if pfUI.gryphons.UpdateConfig then pfUI.gryphons.UpdateConfig() end
  end)

  pfUI.gryphons.UpdateConfig = function()
    local set = C.bars.gryphons
    local art = pfUI.gryphons.Art(set.texture)
    for position, frame in pairs(pfUI.gryphons.frames) do
      local anchor = _G[set["anchor_"..position]]
      local texture = art and art.tex
      local r, g, b, a = GetStringColor(set.color)
      local size = tonumber(set.size) or 50
      local offset_h = tonumber(set.offset_h) or 0
      local offset_v = tonumber(set.offset_v) or 0
      local relative = "BOTTOM"..string.upper(position)
      local c = art and art.coords or { 0, 1, 0, 1 }
      -- the picture's own shape (crops are not square)
      local aspect = math.max(.2, (c[2] - c[1]) / math.max(.01, c[4] - c[3]))
      local sides = set.sides or "both"

      frame:SetParent(anchor)
      frame:SetWidth(size * aspect)
      frame:SetHeight(size)
      frame:ClearAllPoints()
      frame:SetPoint(relative, anchor, relative, (position == "right" and -1 or 1) * offset_h, offset_v)
      frame:SetFrameLevel(128)

      frame.texture = frame.texture or frame:CreateTexture(nil, "OVERLAY")
      frame.texture:SetTexture(texture)
      frame.texture:SetVertexColor(r, g, b, a)
      frame.texture:SetAllPoints()

      local mirror = position == "right"
      if set.mirror == "1" then mirror = not mirror end
      if mirror then
        frame.texture:SetTexCoord(c[2], c[1], c[3], c[4])
      else
        frame.texture:SetTexCoord(c[1], c[2], c[3], c[4])
      end

      if texture and anchor and (sides == "both" or sides == position) then
        frame:Show()
      else
        frame:Hide()
      end
    end
  end

  pfUI.gryphons.UpdateConfig()
end)
