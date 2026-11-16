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
    -- (16 Nov 2026, user: more crests, "really good and a big selection ... easy to put onto elites / rares") the
    -- big gold / silver / red preview of the picked crest, then every crest in a grid by group: click one to use it
    W.Card(p, "Elite crests", { icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
      tip = "The badge on a unit frame for elite (gold), rare (silver) and boss (red) targets. Turn the badge on under Unit Frames > Border and background / Class and status." })
    local cbox = W.Box(p, 64)
    local crests = {}
    for i, kind in ipairs({ "elite", "rare", "boss" }) do
      local t = cbox:CreateTexture(nil, "ARTWORK")
      t:SetPoint("LEFT", cbox, "LEFT", 16 + (i - 1) * 104, 0)
      t.kind = kind
      crests[i] = t
    end
    local word = W.Font(cbox:CreateFontString(nil, "OVERLAY"), 12, 1, 1, 1)
    word:SetPoint("LEFT", cbox, "LEFT", 340, 6)
    local sub = W.Font(cbox:CreateFontString(nil, "OVERLAY"), 10, W.C.dim[1], W.C.dim[2], W.C.dim[3])
    sub:SetPoint("TOPLEFT", word, "BOTTOMLEFT", 0, -3)
    sub:SetText("Gold: elite   Silver: rare   Red: boss")
    local function Entry(key)
      for _, e in ipairs(A.ELITE) do if e.key == key then return e end end
    end
    local function PaintCrests()
      for _, t in ipairs(crests) do
        local tex, w, h = A.Crest(G().elite, t.kind)
        if tex then
          t:SetTexture(tex)
          t:SetVertexColor(1, 1, 1)
          t:SetTexCoord(0, 1, 0, 1)
          t:SetWidth((w or 46) * 2 > 92 and 92 or (w or 46) * 2) t:SetHeight((h or 23) * 2 > 56 and 56 or (h or 23) * 2)
          if w == h then t:SetWidth(56) t:SetHeight(56) end
        else
          t:SetTexture("Interface\\AddOns\\pfUI\\img\\bars\\" .. (t.kind == "rare" and "uf-rare" or "uf-elite"))
          t:SetWidth(92) t:SetHeight(46)
          if t.kind == "boss" then t:SetVertexColor(1, .35, .3)
          elseif t.kind == "rare" then t:SetVertexColor(.8, .85, .95)
          else t:SetVertexColor(1, .82, .3) end
        end
      end
      local e = Entry(G().elite) or A.ELITE[1]
      word:SetText(e.label .. "  |cff888888" .. (e.group or "") .. "|r")
    end

    -- the grid: a heading per group, then its crests, 36 px a cell
    local CELL, grid = 36, W.Box(p, 200)
    local sel = CreateFrame("Frame", nil, grid)
    sel:SetWidth(CELL) sel:SetHeight(CELL)
    W.Flat(sel, W.C.accent, .22, W.C.accent)
    sel:SetFrameLevel(grid:GetFrameLevel() + 1)
    local cells = {}
    local function Lay()
      local width = (grid:GetWidth() or 600) - 16
      local per = math.max(4, math.floor(width / CELL))
      local y = -8
      for _, grp in ipairs(A.GROUPS) do
        local head = grid.heads and grid.heads[grp]
        if not head then
          grid.heads = grid.heads or {}
          head = W.Font(grid:CreateFontString(nil, "OVERLAY"), 10, W.C.dim[1], W.C.dim[2], W.C.dim[3])
          head:SetText(string.upper(grp))
          grid.heads[grp] = head
        end
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", grid, "TOPLEFT", 10, y)
        y = y - 14
        local n = 0
        for _, e in ipairs(A.ELITE) do
          if (e.group or "pfUI Octo") == grp then
            local b = cells[e.key]
            if not b then
              b = CreateFrame("Button", nil, grid)
              b:SetWidth(CELL) b:SetHeight(CELL)
              b:SetFrameLevel(grid:GetFrameLevel() + 2)
              b.key = e.key
              local t = b:CreateTexture(nil, "ARTWORK")
              t:SetPoint("CENTER", b, "CENTER", 0, 0)
              local tex, w, h = A.Crest(e.key, "elite")
              if tex then
                t:SetTexture(tex)
                if w == h then t:SetWidth(30) t:SetHeight(30) else t:SetWidth(32) t:SetHeight(16) end
              else
                t:SetTexture("Interface\\AddOns\\pfUI\\img\\bars\\uf-elite")
                t:SetVertexColor(1, .82, .3)
                t:SetWidth(32) t:SetHeight(16)
              end
              local hl = b:CreateTexture(nil, "HIGHLIGHT")
              hl:SetTexture("Interface\\BUTTONS\\WHITE8X8")
              hl:SetVertexColor(1, 1, 1, .1)
              hl:SetAllPoints(b)
              W.Tip(b, e.label, (e.group or "") .. "\nClick to use it on elite, rare and boss frames.")
              b:SetScript("OnClick", function()
                G().elite = this.key
                PaintCrests()
                sel:ClearAllPoints() sel:SetAllPoints(this)
                local UF = pfUI.ufOcto
                if UF and UF.ApplyAll then UF.ApplyAll() end
              end)
              cells[e.key] = b
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", grid, "TOPLEFT", 8 + math.mod(n, per) * CELL, y - math.floor(n / per) * CELL)
            if e.key == G().elite then sel:ClearAllPoints() sel:SetAllPoints(b) end
            n = n + 1
          end
        end
        y = y - math.ceil(n / per) * CELL - 6
      end
      grid:SetHeight(-y + 4)
    end
    Lay()
    grid:SetScript("OnSizeChanged", function() Lay() end)
    PaintCrests()
    O.PfSld(p, "Crest size", "On the unit frames.", .6, 2, .05, G, "elitesize", function()
      local UF = pfUI.ufOcto
      if UF and UF.ApplyAll then UF.ApplyAll() end
    end, function(v) return math.floor(v * 100 + .5) .. "%" end)
    W.Note(p, "Nameplates can use any of these too: Nameplates > Elite, rare and boss marks. Crest and mark icons from game-icons.net "
      .. "(CC BY 3.0) by Lorc, Delapouite, Skoll, sbed, Faithtoken, DarkZaitzev, Caro Asercion and Carl Olsen, lit as metal for pfUI Octo.")
  end

  O:AddPage("Art", "art", "Art", Build)
end)
