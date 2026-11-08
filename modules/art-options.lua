pfUI:RegisterModule("art-options", "vanilla", function ()
  -- pfUI Octo :: the Art page (5 Nov 2026, modules/art.lua): raid mark sets and elite
  -- crest styles, each with a picture of what you get. Marks take a reload; the crests
  -- show on the next refresh of a frame.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local A = pfUI.art
  if not W or not O or not O.AddPage or not A then return end
  local function G() return C.art end
  local MARK_CELLS = { 1, 2, 3, 4, 5, 6, 7, 8 }

  local function Build(p)
    W.Heading(p, "Art", { about = "Pictures for the raid marks and the elite / rare / boss crests on unit frames. "
      .. "Every set is drawn for pfUI Octo." })

    -- ------------------------------------------------------------ custom media
    local CM = pfUI.custommedia
    if CM then
      local L = CM.list
      W.Card(p, "Custom media", { icon = "Interface\\Icons\\INV_Misc_Gem_Variety_02",
        tip = "pfUI-CustomMedia by Mr_Rosh (MIT) is built in. Every texture, font and gryphon menu in pfUI Octo has these: long menus scroll and have a box to type a filter." })
      W.Note(p, table.getn(L.bars) .. " bar textures, " .. table.getn(L.fonts) .. " fonts, " .. table.getn(L.gryphons) .. " gryphon pictures and "
        .. table.getn(L.backgrounds) .. " button backgrounds - pfUI-CustomMedia by Mr_Rosh. They are in every bar texture menu (unit frames, "
        .. "cast bars, nameplates, meters, swing timer, XP bar), every font menu, and the Gryphons page.")
      W.Card(p, "Button backgrounds", { icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_02",
        tip = "A picture behind every action button, or every bag slot." })
      local function Back(label, texKey, colKey)
        local opts = { { key = "none", label = "None" } }
        for _, b in ipairs(CM.BACK) do table.insert(opts, { key = b.key, label = b.label, texture = b.texture }) end
        W.Dropdown(p, label, nil, opts, function() return C.custommedia[texKey] end, function(v) C.custommedia[texKey] = v CM.Apply() end)
        W.Color(p, label .. " colour", "The picture's colour and see-through-ness.", function()
          local r, g, b, a = GetStringColor(C.custommedia[colKey] or "1,1,1,.5")
          return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
        end, function(r, g, b, a)
          C.custommedia[colKey] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
          CM.Apply()
        end)
      end
      Back("Action buttons", "actionbar_texture", "actionbar_color")
      Back("Bag slots", "bags_texture", "bags_color")
    end

    -- ---------------------------------------------------------------- raid marks
    W.Card(p, "Raid marks", { icon = "Interface\\Icons\\INV_Misc_Gem_Variety_01",
      tip = "The eight marks (star, circle, diamond, triangle, moon, square, cross, skull) on unit frames, nameplates and the game's own frames." })
    local box = W.Box(p, 56)
    local marks = {}
    for i, cell in ipairs(MARK_CELLS) do
      local t = box:CreateTexture(nil, "ARTWORK")
      t:SetWidth(40)
      t:SetHeight(40)
      t:SetPoint("LEFT", box, "LEFT", 12 + (i - 1) * 54, 0)
      marks[i] = t
    end
    local function PaintMarks()
      local sheet = A.MarkSheet() or pfUI.media["img:raidicons"] or "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
      -- the stock choice shows pfUI's own sheet as it was before a set replaced it
      if G().marks == "pfui" then sheet = A.stock or sheet end
      for i, t in ipairs(marks) do
        t:SetTexture(sheet)
        local col, row = math.mod(i - 1, 4), math.floor((i - 1) / 4)
        t:SetTexCoord(col * .25, col * .25 + .25, row * .25, row * .25 + .25)
      end
    end
    W.Dropdown(p, "Set", "Glossy 3D: bevelled gems with a highlight. Flat: clean solid shapes. Neon: glowing outlines. "
      .. "pfUI's own: the sheet pfUI ships. The game's: the usual marks.",
      A.MARKS, function() return G().marks end, function(v)
        G().marks = v
        if pfUI.gui then pfUI.gui.settingChanged = true end
        PaintMarks()
      end)
    W.Note(p, "A new set shows after a reload (close the options window to be asked).")
    PaintMarks()

    -- ---------------------------------------------------------------- elite crests
    W.Card(p, "Elite crests", { icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
      tip = "The badge on a unit frame for elite (gold), rare (silver) and boss (red) targets. Turn the badge on under Unit Frames > Border and background / Class and status." })
    local cbox = W.Box(p, 56)
    local crests = {}
    for i, kind in ipairs({ "elite", "rare", "boss" }) do
      local t = cbox:CreateTexture(nil, "ARTWORK")
      t:SetWidth(92)
      t:SetHeight(46)
      t:SetPoint("LEFT", cbox, "LEFT", 12 + (i - 1) * 104, 0)
      t.kind = kind
      crests[i] = t
    end
    local function PaintCrests()
      for _, t in ipairs(crests) do
        local tex = A.Crest(G().elite, t.kind)
        if tex then
          t:SetTexture(tex)
          t:SetVertexColor(1, 1, 1)
          t:SetTexCoord(0, 1, 0, 1)
        else
          t:SetTexture("Interface\\AddOns\\pfUI\\img\\bars\\" .. (t.kind == "rare" and "uf-rare" or "uf-elite"))
          if t.kind == "boss" then t:SetVertexColor(1, .35, .3)
          elseif t.kind == "rare" then t:SetVertexColor(.8, .85, .95)
          else t:SetVertexColor(1, .82, .3) end
        end
      end
    end
    W.Dropdown(p, "Style", "Classic is the flat badge. The others are bevelled metal: gold for elite, silver for rare, red for bosses.",
      A.ELITE, function() return G().elite end, function(v)
        G().elite = v
        PaintCrests()
        local UF = pfUI.ufOcto
        if UF and UF.ApplyAll then UF.ApplyAll() end
      end)
    PaintCrests()
  end

  O:AddPage("Art", "art", "Art", Build)
end)
