pfUI:RegisterModule("gui", "vanilla:tbc", function ()
  local Reload, U, CreateConfig, CreateTabFrame, CreateArea, CreateGUIEntry, EntryUpdate

  -- "searchDB" gets populated when CreateConfig is called. The table holds
  -- information about the title, its parent buttons and the frame itself:
  --   searchDB[tostring(frame)][-1] = frame
  --                             [0] = caption
  --                           [1-X] = parent buttons
  local searchDB = {}

  do -- Core Functions/Variables
    function Reload()
      CreateQuestionDialog(T["Some settings need to reload the UI to take effect.\nDo you want to reload now?"], function()
        pfUI.gui.settingChanged = nil
        ReloadUI()
      end)
    end

    U = setmetatable({}, { __index = function(tab,key)
      local ufunc
      if type(pfUI[key]) == "table" and pfUI[key].UpdateConfig then
        ufunc = function() return pfUI[key]:UpdateConfig() end
      elseif pfUI.uf and type(pfUI.uf[key]) == "table" and pfUI.uf[key].UpdateConfig then
        ufunc = function() return pfUI.uf[key]:UpdateConfig() end
      end
      if ufunc then
        rawset(tab,key,ufunc)
        return ufunc
      end
    end})

    function EntryUpdate()
      -- detect and skip during dropdowns
      local focus = GetMouseFocus()
      if focus and focus.parent and focus.parent.menu then
        if this.over then
          this.tex:Hide()
          this.over = nil
        end
        return
      end

      if MouseIsOver(this) and not this.over then
        this.tex:Show()
        this.over = true
      elseif not MouseIsOver(this) and this.over then
        this.tex:Hide()
        this.over = nil
      end
    end

    -- [ octo: ElvUI-style page layout ]
    -- Every page gets a title and every "header" opens a titled group box.
    -- While a page is built its settings are only collected; Finish() lays
    -- each group out like ElvUI: warnings, then an even two-column grid of
    -- tick boxes ([box] label - the label ticks too), colour swatches and
    -- buttons, then dropdowns and text fields with their label above, then
    -- lists. A spacer (CreateConfig(nil)) starts a new block in the group, so
    -- settings that belong together stay together. Cells are children of the
    -- page, the group box is a plain frame behind them.
    local PAGE_PAD, GROUP_PAD, GAP, TITLE_H = 12, 10, 6, 26
    local CELL = { checkbox = 24, color = 24, button = 24, dropdown = 42, text = 42, slider = 42, list = 42, warning = 50 }
    local ORDER = { warning = 1, checkbox = 2, color = 2, button = 2, dropdown = 3, text = 3, slider = 3, list = 4 }

    local function Flow(page)
      if page.flow then return page.flow end
      local width = 600
      if page.parent and page.parent:GetRight() and page.parent:GetLeft() then
        width = page.parent:GetRight() - page.parent:GetLeft() - 16 -- scrollbar
      end
      local fl = { top = PAGE_PAD, width = width, cols = 2 }
      page.flow = fl

      -- page title: "Category  >  Page" from the tree buttons
      local area = page.parent and page.parent.GetParent and page.parent:GetParent()
      local btn = area and area.button
      if btn and btn.text and btn.text:GetText() then
        local name = btn.text:GetText()
        if btn.isChild and btn.parent and btn.parent.text then
          name = "|cff888888" .. btn.parent.text:GetText() .. "  >|r  " .. name
        end
        page.title = page:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        page.title:SetFont(pfUI.font_default, C.global.font_size + 6, "OUTLINE")
        page.title:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_PAD, -PAGE_PAD)
        page.title:SetJustifyH("LEFT")
        page.title:SetText(name)
        fl.top = PAGE_PAD + C.global.font_size + 18
      end
      return fl
    end

    local function StartGroup(page, title)
      local fl = Flow(page)
      local g = CreateFrame("Frame", nil, page)
      g:SetFrameLevel(page:GetFrameLevel())
      g:SetWidth(fl.width - 2 * PAGE_PAD)
      g:SetHeight(TITLE_H)
      g:SetBackdrop(pfUI.backdrop_thin)
      g:SetBackdropColor(1, 1, 1, .03)
      g:SetBackdropBorderColor(.22, .22, .22, 1)
      g.blocks = { {} }

      if title then
        local ar, ag, ab = GetAccentColor()
        g.caption = g:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        g.caption:SetFont(pfUI.font_default, C.global.font_size + 1, "OUTLINE")
        g.caption:SetPoint("TOPLEFT", g, "TOPLEFT", GROUP_PAD, -7)
        g.caption:SetJustifyH("LEFT")
        g.caption:SetTextColor(ar, ag, ab, 1)
        g.caption:SetText(title)
      end

      fl.group = g
      page.groups = page.groups or {}
      table.insert(page.groups, g)
      return g
    end

    -- a spacer: the next settings start a new block in the group
    local function NewBlock(page)
      local fl = Flow(page)
      if not fl.group then return end
      local blocks = fl.group.blocks
      if table.getn(blocks[table.getn(blocks)]) > 0 then table.insert(blocks, {}) end
    end

    -- collects a cell (span columns, h high) for Finish()
    local function Place(page, frame, span, h)
      local fl = Flow(page)
      if not fl.group then StartGroup(page, nil) end
      local blocks = fl.group.blocks
      frame.span, frame.cellh = span, h
      frame.seq = (fl.seq or 0) + 1
      fl.seq = frame.seq
      table.insert(blocks[table.getn(blocks)], frame)
    end

    -- lays out every collected group once the page is built
    local function Finish(page)
      local fl = page.flow
      if not fl or not page.groups then return end
      local cols = fl.cols
      local inner = fl.width - 2 * PAGE_PAD - 2 * GROUP_PAD
      local colw = (inner - (cols - 1) * GAP) / cols
      local y = fl.top

      for _, g in ipairs(page.groups) do
        local gtop = y
        g:ClearAllPoints()
        g:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_PAD, -gtop)
        y = y + (g.caption and TITLE_H + 2 or GROUP_PAD)

        local first = true
        for _, block in ipairs(g.blocks) do
          if table.getn(block) > 0 then
            if not first then y = y + GAP * 2 end
            first = false

            -- same kinds together, in their original order
            table.sort(block, function(a, b)
              local oa, ob = ORDER[a.cellkind] or 2, ORDER[b.cellkind] or 2
              if oa ~= ob then return oa < ob end
              return a.seq < b.seq
            end)

            local x, rowh, lastorder = 0, 0, nil
            for _, frame in ipairs(block) do
              local span = frame.span > cols and cols or frame.span
              local order = ORDER[frame.cellkind] or 2
              -- a new kind or a full row starts a new line
              if x > 0 and (x + span > cols or order ~= lastorder) then
                y = y + rowh + GAP
                x, rowh = 0, 0
              end
              local cx = PAGE_PAD + GROUP_PAD + x * (colw + GAP)
              local cw = span * colw + (span - 1) * GAP
              frame:ClearAllPoints()
              frame:SetPoint("TOPLEFT", page, "TOPLEFT", cx, -y)
              frame:SetWidth(cw)
              frame:SetHeight(frame.cellh)
              frame.cell = { x = cx, y = y, w = cw, h = frame.cellh }
              x = x + span
              lastorder = order
              if frame.cellh > rowh then rowh = frame.cellh end
            end
            y = y + rowh
          end
        end

        y = y + GROUP_PAD
        g:SetHeight(y - gtop)
        g.cell = { x = PAGE_PAD, y = gtop, w = fl.width - 2 * PAGE_PAD }
        y = y + 12
      end
    end

    -- lays the widget out inside its cell and places the cell
    local function ArrangeCell(page, frame, widget)
      local kind = widget or "text"
      local h = CELL[kind] or 24
      local span = (kind == "list" or kind == "warning") and 99 or 1

      if kind == "checkbox" and frame.input then
        frame.input:ClearAllPoints()
        frame.input:SetPoint("LEFT", frame, "LEFT", 6, 0)
        frame.caption:ClearAllPoints()
        frame.caption:SetPoint("LEFT", frame.input, "RIGHT", 8, 0)
        frame.caption:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
        -- the label ticks the box too
        frame:EnableMouse(true)
        frame:SetScript("OnMouseUp", function()
          if this.input and this.input:IsEnabled() == 1 then this.input:Click() end
        end)
      elseif kind == "color" and frame.color then
        frame.color:ClearAllPoints()
        frame.color:SetPoint("LEFT", frame, "LEFT", 6, 0)
        frame.color:SetWidth(30)
        frame.color:SetHeight(14)
        frame.caption:ClearAllPoints()
        frame.caption:SetPoint("LEFT", frame.color, "RIGHT", 8, 0)
        frame.caption:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
      elseif kind == "button" and frame.button then
        frame.button:ClearAllPoints()
        frame.button:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -3)
        frame.button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 3)
      elseif kind == "slider" and frame.input then
        frame.caption:ClearAllPoints()
        frame.caption:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -3)
        frame.caption:SetPoint("RIGHT", frame.value, "LEFT", -6, 0)
        frame.caption:SetTextColor(.8, .8, .8, 1)
        frame.input:ClearAllPoints()
        frame.input:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -25)
        frame.input:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
        frame.input:SetHeight(8)
      elseif (kind == "dropdown" or kind == "text" or kind == "list") and frame.caption then
        frame.caption:ClearAllPoints()
        frame.caption:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -3)
        frame.caption:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
        frame.caption:SetTextColor(.8, .8, .8, 1)
        if frame.input then
          frame.input:ClearAllPoints()
          frame.input:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -19)
          if kind == "list" and frame.add then
            frame.del:ClearAllPoints()
            frame.del:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -20)
            frame.input:SetPoint("RIGHT", frame.add, "LEFT", -4, 0)
          else
            frame.input:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
          end
          frame.input:SetHeight(20)
          if kind == "text" then frame.input:SetJustifyH("LEFT") end
        end
      elseif kind == "warning" and frame.caption then
        frame.caption:ClearAllPoints()
        frame.caption:SetAllPoints(frame)
      end

      frame.cellkind = kind
      Place(page, frame, span, h)
    end

    function CreateConfig(ufunc, caption, category, config, widget, values, skip, named, type, expansion)
      local disabled = expansion and not strfind(expansion, pfUI.expansion)
      if disabled and pfUI_config.gui.showdisabled == "0" then return end

      -- kept for code that reads it; placement is done by Place()
      this.objectCount = (this.objectCount or -1) + 1

      -- spacer: start a new row
      if not caption then
        if not skip then NewBlock(this) end
        return
      end

      -- group header: a titled box the next settings go into
      if widget == "header" then
        return StartGroup(this, caption)
      end

      -- basic frame (placed at the end by ArrangeCell)
      local frame = CreateFrame("Frame", nil, this)
      frame:SetWidth(200)
      frame:SetHeight(22)

      -- populate search index
      if caption and this and this.GetParent and widget ~= "button" and widget ~= "header" then
        local id = tostring(frame)

        searchDB[id] = searchDB[id] or { }
        searchDB[id][0] = caption
        searchDB[id][-1] = frame

        -- scrollchild scrollframe  Area        Area        Btton
        -- this        .parent      :GetParent():GetParent().button
        -- this        .parent      :GetParent().button
        local scrollframe = this.parent
        while scrollframe.GetParent and scrollframe:GetParent() and scrollframe:GetParent().button do
          table.insert(searchDB[id], scrollframe:GetParent().button)
          scrollframe = scrollframe:GetParent()
        end
      end

      if not widget or (widget and widget ~= "button") then

        if widget ~= "header" then
          frame:SetScript("OnUpdate", EntryUpdate)
          frame.tex = frame:CreateTexture(nil, "BACKGROUND")
          frame.tex:SetTexture(1,1,1,.07)
          frame.tex:SetAllPoints()
          frame.tex:Hide()
        end

        if not ufunc and widget ~= "header" and C.gui.reloadmarker == "1" then
          caption = caption .. " [|cffffaaaa!|r]"
        end

        -- caption
        frame.caption = frame:CreateFontString("Status", "LOW", "GameFontWhite")
        frame.caption:SetFont(pfUI.font_default, C.global.font_size)
        frame.caption:SetPoint("LEFT", frame, "LEFT", 3, 1)
        frame.caption:SetJustifyH("LEFT")
        frame.caption:SetText(caption)
      end

      if disabled then
        if frame.caption then
          frame.caption:SetText(caption .. " |cffff5555[" .. T["Only"] .. " " .. string.gsub(expansion, ":", "&") .. "]")
        end

        frame:SetAlpha(.5)
        frame.caption:ClearAllPoints()
        frame.caption:SetPoint("LEFT", frame, "LEFT", 6, 0)
        frame.caption:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
        frame.cellkind = "checkbox"
        Place(this, frame, 99, 24)
        return
      end

      if category == "CVAR" then
        category = {}
        category[config] = tostring(GetCVar(config))
        ufunc = function()
          SetCVar(this:GetParent().config, this:GetParent().category[config])
        end
      end

      if category == "GVAR" then
        category = {}
        category[config] = tostring(_G[config] or 0)

        local U = ufunc

        ufunc = function()
          UIOptionsFrame_Load()
          _G[config] = this:GetChecked() and 1 or nil
          UIOptionsFrame_Save()
          if U then
            U()
          end
        end
      end

      if category == "UVAR" then
        category = {}
        category[config] = _G[config]

        local U = ufunc

        ufunc = function()
          _G[config] = this:GetChecked() and "1" or "0"
          if U then
            U()
          end
        end
      end

      frame.category = category
      frame.config = config

      if widget == "color" then
        -- color picker
        frame.color = CreateFrame("Button", nil, frame)
        frame.color:SetWidth(24)
        frame.color:SetHeight(12)
        CreateBackdrop(frame.color)
        frame.color:SetPoint("RIGHT" , -5, 1)
        frame.color.prev = frame.color.backdrop:CreateTexture(nil, "OVERLAY")
        frame.color.prev:SetAllPoints(frame.color)

        local cr, cg, cb, ca = strsplit(",", category[config])
        if not cr or not cg or not cb or not ca then
          cr, cg, cb, ca = 1, 1, 1, 1
        end
        frame.color.prev:SetTexture(cr,cg,cb,ca)

        frame.color:SetScript("OnClick", function()
          local cr, cg, cb, ca = strsplit(",", category[config])
          if not cr or not cg or not cb or not ca then
            cr, cg, cb, ca = 1, 1, 1, 1
          end
          local preview = this.prev

          function ColorPickerFrame.func()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = 1 - OpacitySliderFrame:GetValue()

            r = round(r, 3)
            g = round(g, 3)
            b = round(b, 3)
            a = round(a, 3)

            preview:SetTexture(r,g,b,a)

            if not this:GetParent():IsShown() then
              category[config] = r .. "," .. g .. "," .. b .. "," .. a
              if ufunc then ufunc() else pfUI.gui.settingChanged = true end
            end
          end

          function ColorPickerFrame.cancelFunc()
            preview:SetTexture(cr,cg,cb,ca)
          end

          ColorPickerFrame.opacityFunc = ColorPickerFrame.func
          ColorPickerFrame.element = this
          ColorPickerFrame.opacity = 1 - ca
          ColorPickerFrame.hasOpacity = 1
          ColorPickerFrame:SetColorRGB(cr,cg,cb)
          ColorPickerFrame:SetFrameStrata("DIALOG")
          ShowUIPanel(ColorPickerFrame)
        end)

        -- hide shadows on wrong stratas
        if frame.color.backdrop_shadow then
          frame.color.backdrop_shadow:Hide()
        end
      end

      if widget == "warning" then
        CreateBackdrop(frame, nil, true)
        frame:SetBackdropBorderColor(1,.5,.5)
        frame.caption:SetJustifyH("CENTER")
        frame.caption:SetJustifyV("CENTER")
      end

      -- use text widget (default)
      if not widget or widget == "text" then
        -- input field
        frame.input = CreateFrame("EditBox", nil, frame)
        frame.numtype = type or "number" -- octo: number fields also get a slider (octo-options.lua)
        CreateBackdrop(frame.input, nil, true)
        frame.input:SetTextInsets(5, 5, 5, 5)
        frame.input:SetTextColor(GetAccentColor())
        frame.input:SetJustifyH("RIGHT")

        frame.input:SetWidth(100)
        frame.input:SetHeight(18)
        frame.input:SetPoint("RIGHT" , -3, 0)
        frame.input:SetFontObject(GameFontNormal)
        frame.input:SetAutoFocus(false)
        frame.input:SetText(category[config])
        frame.input:SetScript("OnEscapePressed", function(self)
          this:ClearFocus()
        end)

        frame.input:SetScript("OnTextChanged", function(self)
          if ( type and type ~= "number" ) or tonumber(this:GetText()) then
            if this:GetText() ~= this:GetParent().category[this:GetParent().config] then
              this:GetParent().category[this:GetParent().config] = this:GetText()
              if ufunc then ufunc() else pfUI.gui.settingChanged = true end
            end
            this:SetTextColor(GetAccentColor())
          else
            this:SetTextColor(1,.3,.3,1)
          end
        end)

        -- hide shadows on wrong stratas
        if frame.input.backdrop_shadow then
          frame.input.backdrop_shadow:Hide()
        end
      end

      -- use button widget
      if widget == "button" then
        frame.button = CreateFrame("Button", "pfButton", frame, "UIPanelButtonTemplate")
        CreateBackdrop(frame.button, nil, true)
        SkinButton(frame.button)
        frame.button:SetWidth(100)
        frame.button:SetHeight(20)
        frame.button:SetPoint("TOPRIGHT", -5, -5)
        frame.button:SetText(caption)
        frame.button:SetTextColor(1,1,1,1)
        frame.button:SetScript("OnClick", values)

        -- hide shadows on wrong stratas
        if frame.button.backdrop_shadow then
          frame.button.backdrop_shadow:Hide()
        end
      end

      -- use checkbox widget
      if widget == "checkbox" then
        -- input field
        frame.input = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        frame.input:SetNormalTexture("")
        frame.input:SetPushedTexture("")
        frame.input:SetHighlightTexture("")
        CreateBackdrop(frame.input, nil, true)
        frame.input:SetWidth(14)
        frame.input:SetHeight(14)
        frame.input:SetPoint("RIGHT" , -5, 1)
        frame.input:SetScript("OnClick", function ()
          if this:GetChecked() then
            this:GetParent().category[this:GetParent().config] = "1"
          else
            this:GetParent().category[this:GetParent().config] = "0"
          end

          if ufunc then ufunc() else pfUI.gui.settingChanged = true end
        end)

        if category[config] == "1" then frame.input:SetChecked() end

        -- hide shadows on wrong stratas
        if frame.input.backdrop_shadow then
          frame.input.backdrop_shadow:Hide()
        end
      end

      -- use dropdown widget
      if widget == "dropdown" and values then
        frame.input = CreateDropDownButton(nil, frame)
        frame.input:SetBackdrop(nil)
        frame.input.menuframe:SetParent(pfUI.gui)

        frame.input:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        frame.input:SetWidth(180)
        frame.input:SetMenu(function()
          local menu = {}

          for i, k in pairs(_G.type(values) == "function" and values() or values) do
            local entry = {}
            -- get human readable
            local value, text = strsplit(":", k)
            text = text or value

            entry.text = text
            -- octo: fonts in their own letters, textures as a strip (ui-widgets.lua)
            if string.find(string.lower(value), "%.[to]tf$") then
              entry.font = value
            elseif string.find(value, "^Interface\\") then
              entry.texture = pfUI.media[value]
            end
            entry.func = function()
              if category[config] ~= value then
                category[config] = value
                if ufunc then ufunc() else pfUI.gui.settingChanged = true end
              end
            end

            if category[config] == value then
              frame.input.current = i
            end

            table.insert(menu, entry)
          end

          return menu
        end)

        frame.input:SetSelection(frame.input.current)
      end

      -- use slider widget (octo, ElvUI style): values = { min, max, step }
      if widget == "slider" and _G.type(values) == "table" then
        local lo, hi, step = values[1] or 0, values[2] or 100, values[3] or 1
        local function Fmt(v)
          if step >= 1 then return tostring(math.floor(v + .5)) end
          local s = string.format("%.2f", v)
          s = string.gsub(s, "0+$", "")
          return (string.gsub(s, "%.$", ""))
        end
        frame.input = CreateFrame("Slider", nil, frame)
        frame.input:SetOrientation("HORIZONTAL")
        frame.input:SetHeight(8)
        frame.input:SetMinMaxValues(lo, hi)
        frame.input:SetValueStep(step)
        frame.input:EnableMouseWheel(true)
        CreateBackdrop(frame.input, nil, true)
        frame.input:SetThumbTexture("Interface\\BUTTONS\\WHITE8X8")
        local thumb = frame.input:GetThumbTexture()
        thumb:SetWidth(8)
        thumb:SetHeight(14)
        thumb:SetVertexColor(GetAccentColor())
        frame.value = frame:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        frame.value:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
        frame.value:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -3)
        frame.value:SetTextColor(GetAccentColor())
        frame.input:SetValue(tonumber(category[config]) or lo)
        frame.value:SetText(Fmt(tonumber(category[config]) or lo))
        frame.input:SetScript("OnValueChanged", function()
          local v = math.floor(this:GetValue() / step + .5) * step
          if v < lo then v = lo elseif v > hi then v = hi end
          local p = this:GetParent()
          p.value:SetText(Fmt(v))
          if tostring(p.category[p.config]) ~= Fmt(v) then
            p.category[p.config] = Fmt(v)
            if ufunc then ufunc() else pfUI.gui.settingChanged = true end
          end
        end)
        frame.input:SetScript("OnMouseWheel", function()
          this:SetValue(this:GetValue() + arg1 * step)
        end)
      end

      -- use list widget
      if widget == "list" then
        frame.del = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        SkinButton(frame.del)
        frame.del:SetWidth(16)
        frame.del:SetHeight(16)
        frame.del:SetPoint("RIGHT", -4, 0)
        frame.del:GetFontString():SetPoint("CENTER", 1, 0)
        frame.del:SetText("-")
        frame.del:SetTextColor(1,.5,.5,1)
        frame.del:SetScript("OnClick", function()
          local sel = frame.input:GetSelection()
          local newconf = ""
          for id, val in pairs({strsplit("#", category[config])}) do
            if id ~= sel then newconf = newconf .. "#" .. val end
          end
          category[config] = newconf
          if ufunc then ufunc() else pfUI.gui.settingChanged = true end
          frame.input:UpdateMenu()
        end)

        frame.add = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        SkinButton(frame.add)
        frame.add:SetWidth(16)
        frame.add:SetHeight(16)
        frame.add:SetPoint("RIGHT", frame.del, "LEFT", -4, 0)
        frame.add:GetFontString():SetPoint("CENTER", 1, 0)
        frame.add:SetText("+")
        frame.add:SetTextColor(.5,1,.5,1)
        frame.add:SetScript("OnClick", function()
          CreateQuestionDialog(T["New entry:"], function()
            category[config] = category[config] .. "#" .. this:GetParent().input:GetText()
            if ufunc then ufunc() else pfUI.gui.settingChanged = true end
            frame.input:UpdateMenu()
          end, false, true)
        end)

        frame.input = CreateDropDownButton(nil, frame)
        frame.input:SetBackdrop(nil)
        frame.input.menuframe:SetParent(pfUI.gui)
        frame.input:SetPoint("RIGHT", frame.add, "LEFT", -2, 0)
        frame.input:SetWidth(140)
        frame.input:SetMenu(function()
          local menu = {}
          for i, val in pairs({strsplit("#", category[config])}) do
            table.insert(menu, { text = val })
          end
          return menu
        end)
      end

      -- a dropdown without values gets no input: lay it out as plain text
      if widget == "dropdown" and not frame.input then widget = "checkbox" end
      ArrangeCell(this, frame, widget)

      return frame
    end

    local TabFrameOnMouseDown = function()
      pfUI.gui.search:ClearFocus()
    end

    -- octo: ElvUI-style tree. One column: the categories, and under the open
    -- category its pages, indented (they used to open a second column next to
    -- the first, which took the room the settings need). Hover shade, accent
    -- edge + tint on the open page.
    local width, height = 170, 22

    -- stacks the categories and the open category's pages
    -- The tree scrolls with the mouse wheel (treeOffset) when it is taller
    -- than the window; rows outside the column are hidden. A category whose
    -- page is open folds and unfolds when clicked again (btn.folded).
    local treeOffset = 0
    local function RelayoutTree(reveal)
      local root = pfUI.gui.frames
      local room = (root.area:GetHeight() or 0) - 6
      if room < height then room = 2000 end -- not laid out yet

      -- every row and its y, top to bottom
      local rows, y = {}, 6
      local revealTop, revealBottom
      for _, btn in ipairs(root.order or {}) do
        table.insert(rows, { btn, y, height })
        if btn == reveal then revealTop = y end
        y = y + height
        local open = btn.area and btn.area:IsShown() and not btn.folded
        if btn.children then
          btn.arrow:SetText(open and "-" or "+")
          for _, child in ipairs(btn.children) do
            if open then
              table.insert(rows, { child, y, height - 2 })
              y = y + height - 2
            else
              child:Hide()
            end
          end
          if open then y = y + 4 end
          if btn == reveal then revealBottom = y end
        end
      end

      -- keep the offset in range; show a just-opened category with its pages
      local most = math.max(0, y - room)
      if revealBottom and revealBottom - treeOffset > room then treeOffset = revealBottom - room end
      if revealTop and revealTop - treeOffset < 6 then treeOffset = revealTop - 6 end
      if treeOffset > most then treeOffset = most end
      if treeOffset < 0 then treeOffset = 0 end

      for _, row in ipairs(rows) do
        local b, top, h = row[1], row[2] - treeOffset, row[3]
        if top < 0 or top + h > room + 6 then
          b:Hide()
        else
          b:ClearAllPoints()
          b:SetPoint("TOPLEFT", root.area, "TOPLEFT", 0, -top)
          b:SetWidth(width)
          b:SetHeight(h)
          b:Show()
        end
      end

      -- "more above / below" hints
      if root.area.more then
        if treeOffset > 0 then root.area.moreUp:Show() else root.area.moreUp:Hide() end
        if treeOffset < most then root.area.more:Show() else root.area.more:Hide() end
      end
    end
    pfUI.gui_RelayoutTree = RelayoutTree

    local function TreeScroll()
      treeOffset = treeOffset - arg1 * height * 2
      RelayoutTree()
    end
    pfUI.gui_TreeScroll = TreeScroll

    local TabFrameOnClick = function()
      -- a page: open its category first
      if this.isChild and not this.parent.area:IsShown() then
        this.parent:Click()
      end

      -- the open category again: fold / unfold its pages
      if not this.isChild and this.children and this.area:IsShown() then
        this.folded = not this.folded
        RelayoutTree(this)
        return
      end
      if not this.isChild then this.folded = nil end

      if not this.area:IsShown() then
        -- hide all others
        for id, name in pairs(this.parent) do
          if _G.type(name) == "table" and name.area and id ~= "parent" then
            name.area:Hide()
          end
        end
        this.area:Show()
      end
      RelayoutTree(not this.isChild and this or nil)
    end

    local TabFrameOnEnter = function()
      if not this.selected then this.bg:SetTexture(1,1,1,.06) end
    end

    local TabFrameOnLeave = function()
      if not this.selected then this.bg:SetTexture(0,0,0,0) end
    end

    function CreateTabFrame(parent, title)
      local root = pfUI.gui.frames
      local f = CreateFrame("Button", nil, root.area)
      f:SetWidth(width)
      f:SetHeight(height)
      f.parent = parent

      if parent ~= root then
        -- a page of a category: listed under it in the tree
        f.isChild = true
        parent.children = parent.children or {}
        table.insert(parent.children, f)
        f:Hide()
      else
        root.order = root.order or {}
        table.insert(root.order, f)
      end

      f:SetScript("OnMouseDown", TabFrameOnMouseDown)
      f:SetScript("OnClick", TabFrameOnClick)
      f:SetScript("OnEnter", TabFrameOnEnter)
      f:SetScript("OnLeave", TabFrameOnLeave)
      f:EnableMouseWheel(true)
      f:SetScript("OnMouseWheel", TreeScroll)

      -- background
      f.bg = f:CreateTexture(nil, "BACKGROUND")
      f.bg:SetAllPoints()

      -- accent edge of the open entry
      f.edge = f:CreateTexture(nil, "ARTWORK")
      f.edge:SetPoint("TOPLEFT", 0, -2)
      f.edge:SetPoint("BOTTOMLEFT", 0, 2)
      f.edge:SetWidth(2)
      f.edge:Hide()

      -- text
      f.text = f:CreateFontString(nil, "LOW", "GameFontWhite")
      f.text:SetFont(pfUI.font_default, f.isChild and C.global.font_size - 1 or C.global.font_size + 1, f.isChild and "" or "OUTLINE")
      f.text:SetPoint("TOPLEFT", f.isChild and 24 or 10, 0)
      f.text:SetPoint("BOTTOMRIGHT", -18, 0)
      f.text:SetJustifyH("LEFT")
      f.text:SetText(title)
      f.normal = f.isChild and { .8, .8, .8 } or { 1, 1, 1 }
      f.text:SetTextColor(f.normal[1], f.normal[2], f.normal[3], 1)

      -- +/- on categories that have pages
      if not f.isChild then
        f.arrow = f:CreateFontString(nil, "LOW", "GameFontWhite")
        f.arrow:SetFont(pfUI.font_default, C.global.font_size + 1, "OUTLINE")
        f.arrow:SetPoint("RIGHT", -8, 0)
        f.arrow:SetTextColor(.6, .6, .6, 1)
      end

      RelayoutTree()
      return f
    end

    function CreateArea(parent, title, func)
      -- create drawarea; a category's pages fill the whole category area
      local f = CreateFrame("Frame", nil, parent.area)
      f:SetPoint("TOPLEFT", parent.area, "TOPLEFT", parent == pfUI.gui.frames and width or 0, 0)
      f:SetPoint("BOTTOMRIGHT", parent.area, "BOTTOMRIGHT", 0, 0)

      if not parent.firstarea then
        parent.firstarea = true
      else
        f:Hide()
      end

      f.button = parent[title]

      if parent == pfUI.gui.frames then
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetTexture(1,1,1,.03)
        f.bg:SetAllPoints()
      end

      f:SetScript("OnShow", function()
        local ar, ag, ab = GetAccentColor()
        local b = this.button
        this.indexed = true
        b.selected = true
        b.text:SetTextColor(ar, ag, ab, 1)
        -- a category with pages only lights its name; its open page gets the bar
        if not b.children then
          b.bg:SetTexture(1,1,1,1)
          b.bg:SetGradientAlpha("HORIZONTAL", ar,ag,ab,.2,  ar,ag,ab,0)
          b.edge:SetTexture(ar, ag, ab, 1)
          b.edge:Show()
        end
      end)

      f:SetScript("OnHide", function()
        local b = this.button
        b.selected = nil
        b.text:SetTextColor(b.normal[1], b.normal[2], b.normal[3], 1)
        b.bg:SetTexture(0,0,0,0)
        b.edge:Hide()
      end)

      -- are we a frame with contents?
      if func then
        f.scroll = CreateScrollFrame(nil, f)
        SetAllPointsOffset(f.scroll, f, 2)
        f.scroll.content = CreateScrollChild(nil, f.scroll)
        f.scroll.content.parent = f.scroll
        f.scroll.content:SetScript("OnShow", function()
          if not this.setup then
            func()
            Finish(this)
            -- octo: the window's shell restyles the finished page
            if pfUI.gui.OnPageBuilt then pfUI.gui.OnPageBuilt(this) end
            this.setup = true
          end
        end)
      end

      return f
    end

    function CreateGUIEntry(parent, title, populate)
      -- create main menu if not yet exists
      if not pfUI.gui.frames[parent] then
        pfUI.gui.frames[parent] = CreateTabFrame(pfUI.gui.frames, parent)
        if title then
          pfUI.gui.frames[parent].area = CreateArea(pfUI.gui.frames, parent, nil)
        else
          -- populate area when no submenus are given
          pfUI.gui.frames[parent].area = CreateArea(pfUI.gui.frames, parent, populate)
          return
        end
      end

      -- create submenus when title was given
      if title and not pfUI.gui.frames[parent][title] then
        pfUI.gui.frames[parent][title] = CreateTabFrame(pfUI.gui.frames[parent], title)
        pfUI.gui.frames[parent][title].area = CreateArea(pfUI.gui.frames[parent], title, populate)
      end
    end
  end

  do -- GUI Frame
    -- main frame
    pfUI.gui = CreateFrame("Frame", "pfConfigGUI", UIParent)
    pfUI.gui:SetMovable(true)
    pfUI.gui:EnableMouse(true)
    pfUI.gui:RegisterForDrag("LeftButton")
    pfUI.gui:SetWidth(940)
    pfUI.gui:SetHeight(600)
    pfUI.gui:SetFrameStrata("DIALOG")
    pfUI.gui:SetPoint("CENTER", 0, 0)
    pfUI.gui:Hide()

    pfUI.gui:SetScript("OnShow",function()
      pfUI.gui.settingChanged = pfUI.gui.delaySettingChanged
      pfUI.gui.delaySettingChanged = nil

      -- the tree knows its height only once shown
      if pfUI.gui_RelayoutTree then pfUI.gui_RelayoutTree() end

      -- exit unlock mode
      -- (octo: not when a box was right-clicked: its options open beside the boxes)
      if pfUI.unlock and pfUI.unlock:IsShown() and not pfUI.gui.keepLayout then
        pfUI.unlock:Hide()
      end

      -- exit hoverbind mode
      if pfUI.hoverbind and pfUI.hoverbind:IsShown() then
        pfUI.hoverbind:Hide()
      end
    end)

    pfUI.gui:SetScript("OnHide",function()
      if ColorPickerFrame and ColorPickerFrame:IsShown() then
        ColorPickerFrame:Hide()
      end

      if pfUI.gui.settingChanged then
        pfUI.gui:Reload()
      end
      pfUI.gui:Hide()
    end)

    pfUI.gui:SetScript("OnDragStart",function()
      this:StartMoving()
    end)

    pfUI.gui:SetScript("OnDragStop",function()
      this:StopMovingOrSizing()
    end)

    CreateBackdrop(pfUI.gui, nil, true, .85)
    CreateBackdropShadow(pfUI.gui)
    table.insert(UISpecialFrames, "pfConfigGUI")

    -- make some locals available to thirdparty
    pfUI.gui.Reload = Reload
    pfUI.gui.CreateConfig = CreateConfig
    pfUI.gui.CreateGUIEntry = CreateGUIEntry
    pfUI.gui.UpdaterFunctions = U
    -- octo: the window's shell (octo-options.lua) searches these too
    pfUI.gui.searchDB = searchDB

    -- octo: re-reads every control of a built page from its setting (after a
    -- preset or a reset changed many at once). page = the page's content frame.
    function pfUI.gui.RefreshPage(page)
      if not page or not page.GetChildren then return end
      for _, c in ipairs({ page:GetChildren() }) do
        if c.category and c.config and c.cellkind then
          local v = c.category[c.config]
          if c.cellkind == "checkbox" and c.input then
            c.input:SetChecked(v == "1" and 1 or nil)
          elseif c.cellkind == "slider" and c.input then
            if tonumber(v) then c.input:SetValue(tonumber(v)) end
          elseif c.cellkind == "text" and c.input then
            c.input:SetText(v or "")
          elseif c.cellkind == "color" and c.color and c.color.prev and v then
            local r, g, b, a = strsplit(",", v)
            c.color.prev:SetTexture(r or 1, g or 1, b or 1, a or 1)
          elseif c.cellkind == "dropdown" and c.input and c.input.UpdateMenu then
            c.input.current = nil
            c.input:UpdateMenu()
            if c.input.current then c.input:SetSelection(c.input.current) end
          end
        end
      end
    end

    -- octo: settings kept as real Lua values (booleans, numbers - the
    -- combat text's) edited with the string widgets: true / false <-> "1" /
    -- "0", numbers <-> text, and the virtual key "rgb" <-> r, g, b fields.
    -- get() returns the table (looked up each time, so a reset table works);
    -- onchange(key) runs after every change.
    function pfUI.gui.Native(get, onchange)
      return setmetatable({}, {
        __index = function(_, k)
          local t = get()
          if k == "rgb" then return (t.r or 1) .. "," .. (t.g or 1) .. "," .. (t.b or 1) .. ",1" end
          local v = t[k]
          if _G.type(v) == "boolean" then return v and "1" or "0" end
          if v == nil then return nil end
          return tostring(v)
        end,
        __newindex = function(_, k, v)
          local t = get()
          if k == "rgb" then
            local _, _, r, g, b = string.find(v or "", "([%d%.]+),([%d%.]+),([%d%.]+)")
            t.r, t.g, t.b = tonumber(r) or t.r, tonumber(g) or t.g, tonumber(b) or t.b
          else
            local old = t[k]
            if _G.type(old) == "boolean" then t[k] = (v == "1")
            elseif _G.type(old) == "number" then t[k] = tonumber(v) or old
            else t[k] = v end
          end
          if onchange then onchange(k) end
        end,
      })
    end

    -- decorations
    pfUI.gui.title = pfUI.gui:CreateFontString("Status", "LOW", "GameFontNormal")
    pfUI.gui.title:SetFontObject(GameFontWhite)
    -- octo: ElvUI-style title bar - name and version left, search and the
    -- Move Frames / Keybinds / Install / Profiles buttons right
    local accent = rgbhex(GetAccentColor())
    pfUI.gui.title:SetPoint("TOPLEFT", pfUI.gui, "TOPLEFT", 10, -10)
    pfUI.gui.title:SetJustifyH("LEFT")
    pfUI.gui.title:SetFont(pfUI.font_default, 16, "OUTLINE")
    pfUI.gui.title:SetText(accent .. "pf|rUI " .. accent .. "Octo|r")

    pfUI.gui.version = pfUI.gui:CreateFontString("Status", "LOW", "GameFontNormal")
    pfUI.gui.version:SetFontObject(GameFontWhite)
    pfUI.gui.version:SetPoint("BOTTOMLEFT", pfUI.gui.title, "BOTTOMRIGHT", 6, 1)
    pfUI.gui.version:SetJustifyH("LEFT")
    pfUI.gui.version:SetFont(pfUI.font_default, 10)
    pfUI.gui.version:SetText("|cff777777" .. pfUI.version.octo .. "  (pfUI " .. pfUI.version.string .. ")|r")

    pfUI.gui.close = CreateFrame("Button", "pfQuestionDialogClose", pfUI.gui)
    pfUI.gui.close:SetPoint("TOPRIGHT", -10, -13)
    pfUI.api.CreateBackdrop(pfUI.gui.close)
    pfUI.gui.close:SetHeight(10)
    pfUI.gui.close:SetWidth(10)
    pfUI.gui.close.texture = pfUI.gui.close:CreateTexture("pfQuestionDialogCloseTex")
    pfUI.gui.close.texture:SetTexture(pfUI.media["img:close"])
    pfUI.gui.close.texture:ClearAllPoints()
    pfUI.gui.close.texture:SetAllPoints(pfUI.gui.close)
    pfUI.gui.close.texture:SetVertexColor(1,.25,.25,1)
    pfUI.gui.close:SetScript("OnEnter", function ()
      this.backdrop:SetBackdropBorderColor(1,.25,.25,1)
    end)

    pfUI.gui.close:SetScript("OnLeave", function ()
      pfUI.api.CreateBackdrop(this)
    end)

    pfUI.gui.close:SetScript("OnClick", function()
     this:GetParent():Hide()
    end)

    -- root layer
    pfUI.gui.frames = {}
    pfUI.gui.frames.area = CreateFrame("Frame", nil, pfUI.gui)
    pfUI.gui.frames.area:SetPoint("TOPLEFT", 7, -38)
    pfUI.gui.frames.area:SetPoint("BOTTOMRIGHT", -7, 7)
    CreateBackdrop(pfUI.gui.frames.area)

    -- tree column: a shade darker than the pages, with a divider
    pfUI.gui.frames.area.tree = pfUI.gui.frames.area:CreateTexture(nil, "BACKGROUND")
    pfUI.gui.frames.area.tree:SetPoint("TOPLEFT", 0, 0)
    pfUI.gui.frames.area.tree:SetPoint("BOTTOMLEFT", 0, 0)
    pfUI.gui.frames.area.tree:SetWidth(170)
    pfUI.gui.frames.area.tree:SetTexture(0, 0, 0, .35)
    pfUI.gui.frames.area.divider = pfUI.gui.frames.area:CreateTexture(nil, "BORDER")
    pfUI.gui.frames.area.divider:SetPoint("TOPLEFT", 170, 0)
    pfUI.gui.frames.area.divider:SetPoint("BOTTOMLEFT", 170, 0)
    pfUI.gui.frames.area.divider:SetWidth(1)
    pfUI.gui.frames.area.divider:SetTexture(.22, .22, .22, 1)

    -- the empty part of the tree column scrolls the tree too
    local wheel = CreateFrame("Frame", nil, pfUI.gui.frames.area)
    wheel:SetPoint("TOPLEFT", 0, 0)
    wheel:SetPoint("BOTTOMLEFT", 0, 0)
    wheel:SetWidth(170)
    wheel:SetFrameLevel(pfUI.gui.frames.area:GetFrameLevel())
    wheel:EnableMouseWheel(true)
    wheel:SetScript("OnMouseWheel", function() pfUI.gui_TreeScroll() end)
    pfUI.gui.frames.area.wheel = wheel

    -- "more above / below" marks at the column's edges
    local function More(point, text)
      local m = pfUI.gui.frames.area:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      m:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      m:SetPoint(point, pfUI.gui.frames.area, point == "TOP" and "TOPLEFT" or "BOTTOMLEFT", 85, point == "TOP" and -1 or 1)
      m:SetTextColor(.6, .6, .6, 1)
      m:SetText(text)
      m:Hide()
      return m
    end
    pfUI.gui.frames.area.moreUp = More("TOP", "^")
    pfUI.gui.frames.area.more = More("BOTTOM", "v")

    -- title bar buttons, right to left from the close button
    local function TopButton(text, width, anchor, tooltip, func)
      local b = CreateFrame("Button", nil, pfUI.gui)
      b:SetPoint("RIGHT", anchor, "LEFT", anchor == pfUI.gui.close and -12 or -6, 0)
      b:SetWidth(width)
      b:SetHeight(20)
      b:SetText(text)
      b:SetScript("OnClick", func)
      b:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
        GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      SkinButton(b)
      return b
    end

    -- share
    pfUI.gui.share = TopButton(T["Profiles"], 80, pfUI.gui.close, T["Export your settings as a text string, or import one (/export)"], function()
      if pfShare then
        pfShare:Show()
        pfShareExport:Click()
      end
    end)

    -- installer
    pfUI.gui.install = TopButton(T["Install"], 70, pfUI.gui.share, T["Run the installer again (/pfui install)"], function()
      if pfUI.firstrun then
        pfUI.gui:Hide()
        pfUI.firstrun:Restart()
      end
    end)

    -- hoverbind
    pfUI.gui.hoverbind = TopButton(T["Keybinds"], 80, pfUI.gui.install, T["Hover a button and press a key to bind it"], function()
      if pfUI.hoverbind then pfUI.hoverbind:Show() end
    end)

    -- unlock
    pfUI.gui.unlock = TopButton(T["Move Frames"], 100, pfUI.gui.hoverbind, T["Drag, snap and scale frames (/moveui)"], function()
      if pfUI.unlock then pfUI.unlock:Show() end
    end)

    -- searchbar
    local function SearchEntryClick()
      -- clear search focus
      pfUI.gui.search:ClearFocus()

      -- open submenus
      for i=table.getn(this.obj),1,-1 do
        this.obj[i]:Click()
      end

      -- highlight matched entry
      if not this.obj[-1].highlight then
        this.obj[-1].highlight = this.obj[-1]:CreateTexture(nil, "OVERLAY")
        this.obj[-1].highlight:SetAllPoints()
        local ar, ag, ab = GetAccentColor()
        this.obj[-1].highlight:SetTexture(ar, ag, ab, .2)
      end
      this.obj[-1].highlight:Show()
    end

    local function CreateSearchEntry(parent, i)
      local f = CreateFrame("Button", nil, parent)
      f:SetPoint("TOPLEFT", 5, -5 + (i-1)*-25)
      f:SetWidth(math.max(565, (parent:GetParent():GetWidth() or 0) - 20))
      f:SetHeight(20)
      f:SetScript("OnClick", SearchEntryClick)
      f:SetScript("OnUpdate", EntryUpdate)

      f.text = f:CreateFontString("Status", "LOW", "GameFontWhite")
      f.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
      f.text:SetAllPoints()
      f.text:SetJustifyH("LEFT")
      f.text:SetJustifyV("CENTER")
      f.text:SetTextColor(.5,.5,.5)

      f.tex = f:CreateTexture(nil, "BACKGROUND")
      f.tex:SetTexture(1,1,1,.05)
      f.tex:SetAllPoints()
      f.tex:Hide()

      return f
    end

    pfUI.gui.search = CreateFrame("EditBox", nil, pfUI.gui)
    pfUI.gui.search:SetPoint("RIGHT", pfUI.gui.unlock, "LEFT", -12, 0)
    pfUI.gui.search:SetWidth(200)
    pfUI.gui.search:SetHeight(20)
    pfUI.gui.search:SetAutoFocus(false)
    pfUI.gui.search:SetTextInsets(5, 5, 5, 5)
    pfUI.gui.search:SetTextColor(GetAccentColor())
    pfUI.gui.search:SetJustifyH("CENTER")
    pfUI.gui.search:SetFontObject(GameFontNormal)
    pfUI.gui.search:SetText(T["Search"] .. "...")
    CreateBackdrop(pfUI.gui.search, nil, true)

    pfUI.gui.search:SetScript("OnEscapePressed", function()
      this:ClearFocus()
      if this:GetText() == "" then
        this:SetText(T["Search"].."...")
      end
    end)

    pfUI.gui.search:SetScript("OnTextChanged", function()
      if this:GetText() == T["Search"].."..." then return end
      local defval = "["..T["Search"].."]"

      -- initialize search window
      CreateGUIEntry(defval, nil, function() end)
      pfUI.gui.frames[defval]:Click()

      local scroll = pfUI.gui.frames[defval].area.scroll.content
      local parent = pfUI.gui.frames[defval].area.scroll
      scroll.results = scroll.results or {}

      for i=1,table.getn(scroll.results) do
        scroll.results[i]:Hide()
        if scroll.results[i].obj and scroll.results[i].obj[-1].highlight then
          scroll.results[i].obj[-1].highlight:Hide()
        end
      end

      if strlen(this:GetText()) < 1 then return end

      local i = 1
      local search = strlower(this:GetText())
      for name, obj in pairs(searchDB) do
        local title = obj[0] and strlower(obj[0])
        if strfind(title, search) then
          -- build caption string
          local caption = ""
          for x=table.getn(obj),1,-1 do
            caption = caption .. rgbhex(GetAccentColor()) .. obj[x].text:GetText() .. "|r » "
          end
          caption = caption .. "|cffffffff" .. obj[0]

          -- build search entry button
          scroll.results[i] = scroll.results[i] or CreateSearchEntry(scroll, i)
          scroll.results[i].obj = obj
          scroll.results[i].text:SetText(caption)
          scroll.results[i]:Show()

          i = i + 1
        end
      end

      -- reload scroll frames
      scroll:Hide()
      scroll:SetHeight(i * 25 )
      scroll:Show()
      parent:SetScrollChild(scroll)
      QueueFunction(function()
        parent:SetVerticalScroll(0)
        parent:UpdateScrollState()
        parent:Scroll()
      end)
    end)

    pfUI.gui.search:SetScript("OnEditFocusGained", function(self)
      if this:GetText() == T["Search"] .. "..." then this:SetText("") end
      if this.indexed then return end
      -- Trigger "OnShow" for each subpage to initialize search index
      for name, frame in pairs(pfUI.gui.frames) do
        if type(frame) == "table" and frame.area and name ~= "parent" then
          frame.area:Show()

          for name, frame in pairs(pfUI.gui.frames[name]) do
            if type(frame) == "table" and frame.area and name ~= "parent" and not frame.area.indexed then
              frame.area:Show()
              frame.area:Hide()
            end
          end

          frame.area:Hide()
        end
      end
      this.indexed = true
    end)
  end

  do -- DropDown Menus
    -- [[ Static Dropdowns ]] --
    pfUI.gui.dropdowns = {
      ["languages"] = {
        -- "deDE:German",
        -- "enGB:British English",
        "enUS:English",
        "esES:Spanish",
        --"esMX:Spanish (Latin American)",
        "frFR:French",
        "koKR:Korean",
        "ruRU:Russian",
        "zhCN:Chinese (Simplified)",
        "zhTW:Chinese (Traditional)",
        -- http://wowprogramming.com/docs/api/GetLocale
      },
      ["fonts"] = {
        "Interface\\AddOns\\pfUI\\fonts\\BigNoodleTitling.ttf:BigNoodleTitling",
        "Interface\\AddOns\\pfUI\\fonts\\Continuum.ttf:Continuum",
        "Interface\\AddOns\\pfUI\\fonts\\DieDieDie.ttf:DieDieDie",
        "Interface\\AddOns\\pfUI\\fonts\\Expressway.ttf:Expressway",
        "Interface\\AddOns\\pfUI\\fonts\\Homespun.ttf:Homespun",
        "Interface\\AddOns\\pfUI\\fonts\\Hooge.ttf:Hooge",
        "Interface\\AddOns\\pfUI\\fonts\\Myriad-Pro.ttf:Myriad-Pro",
        "Interface\\AddOns\\pfUI\\fonts\\PT-Sans-Narrow-Bold.ttf:PT-Sans-Narrow-Bold",
        "Interface\\AddOns\\pfUI\\fonts\\PT-Sans-Narrow-Regular.ttf:PT-Sans-Narrow-Regular"
      },
      ["accent"] = {
        "class:" .. T["Class Color"],
        "custom:" .. T["Custom"],
      },
      ["border"] = {
        "-1:" .. T["Default"],
        "0:" .. T["None"],
        "1:1 " .. T["Pixel"],
        "2:2 " .. T["Pixel"],
        "3:3 " .. T["Pixel"],
        "4:4 " .. T["Pixel"],
        "5:5 " .. T["Pixel"],
      },
      ["fontstyle"] = {
        "NONE:" .. T["None"],
        "OUTLINE:" .. T["Outline"],
        "THICKOUTLINE:" .. T["Thick Outline"],
        "MONOCHROME:" .. T["Monochrome"],
      },
      ["spacing"] = {
        "0:0" .. T["None"],
        "1:1 " .. T["Pixel"],
        "2:2 " .. T["Pixel"],
        "3:3 " .. T["Pixel"],
        "4:4 " .. T["Pixel"],
        "5:5 " .. T["Pixel"],
        "6:6 " .. T["Pixel"],
        "7:7 " .. T["Pixel"],
        "8:8 " .. T["Pixel"],
        "9:9 " .. T["Pixel"],
      },
      ["maxraid"] = {
        "5:5",
        "10:10",
        "15:15",
        "20:20",
        "25:25",
        "30:30",
        "35:35",
        "40:40",
      },
      ["scaling"] = {
        "0:" .. T["Off"],
        "4:" .. T["Huge (PixelPerfect)"],
        "5:" .. T["Large"],
        "6:" .. T["Medium"],
        "7:" .. T["Small"],
        "8:" .. T["Tiny (PixelPerfect)"],
      },
      ["orientation"] = {
        "HORIZONTAL:" .. T["Horizontal"],
        "VERTICAL:" .. T["Vertical"],
      },
      ["uf_animationspeed"] = {
        "1:" .. T["Instant"],
        "2:" .. T["Very Fast"],
        "3:" .. T["Fast"],
        "5:" .. T["Medium"],
        "8:" .. T["Slow"],
        "13:" .. T["Very Slow"],
      },
      ["xpanchors"] = {
        "__NONONIL__:" .. T["No Anchor"],
        "pfChatLeft:" .. T["Left Chat Frame"],
        "pfChatRight:" .. T["Right Chat Frame"],
        "pfActionBarMain:" .. T["Main Actionbar"],
        "pfActionBarTop:" .. T["Top Actionbar"],
        "pfActionBarLeft:" .. T["Left Actionbar"],
        "pfActionBarRight:" .. T["Right Actionbar"],
        "pfActionBarVertical:" .. T["Vertical Actionbar"],
        "pfExperienceBar:" .. T["Experience Bar"],
        "pfReputationBar:" .. T["Reputation Bar"],
        "pfPlayer:" .. T["Player Unitframe"],
        "pfMinimap:" .. T["Minimap"],
        "pfPanelMinimap:" .. T["Minimap Panel"],
      },
      ["meter_modes"] = {
        "damage:" .. T["Damage Done"], "dps:" .. T["DPS"], "heal:" .. T["Healing Done"], "hps:" .. T["HPS"],
        "overheal:" .. T["Overhealing"], "taken:" .. T["Damage Taken"], "interrupts:" .. T["Interrupts"],
        "dispels:" .. T["Dispels"], "deaths:" .. T["Deaths"], "casts:" .. T["Casts"], "threat:" .. T["Threat"],
      },
      ["uf_bartexture"] = {
        "Interface\\AddOns\\pfUI\\img\\bar:pfUI",
        "Interface\\AddOns\\pfUI\\img\\bar_tukui:TukUI",
        "Interface\\AddOns\\pfUI\\img\\bar_elvui:ElvUI",
        "Interface\\AddOns\\pfUI\\img\\bar_gradient:Gradient",
        "Interface\\AddOns\\pfUI\\img\\bar_striped:Striped",
        "Interface\\TargetingFrame\\UI-StatusBar:Wow Status",
        "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar:Wow Skill"
      },
      ["uf_rangecheckinterval"] = {
        "1:" .. T["Very Fast"],
        "2:" .. T["Fast"],
        "4:" .. T["Medium"],
        "8:" .. T["Slow"],
        "16:" .. T["Very Slow"],
      },
      ["uf_raidlayout"] = {
        "1x40:" .. "1x40",
        "2x20:" .. "2x20",
        "4x10:" .. "4x10",
        "5x8:" ..  "5x8",
        "8x5:" ..  "8x5",
        "10x4:" .. "10x4",
        "20x2:" .. "20x2",
        "40x1:" .. "40x1",
      },
      ["uf_powerbar_position"] = {
        "TOPLEFT:" .. T["Left"],
        "TOP:" .. T["Center"],
        "TOPRIGHT:" .. T["Right"]
      },
      ["uf_portrait_position"] = {
        "bar:" .. T["Healthbar Embedded"],
        "left:" .. T["Left"],
        "right:" .. T["Right"],
        "off:" .. T["Disabled"]
      },
      ["uf_happiness"] = {
        "0:" .. T["Disabled"],
        "1:" .. T["Face"],
        "2:" .. T["Rank"]
      },
      ["uf_buff_position"] = {
        "TOPLEFT:" .. T["Top Left"],
        "TOPRIGHT:" .. T["Top Right"],
        "BOTTOMLEFT:" .. T["Bottom Left"],
        "BOTTOMRIGHT:" .. T["Bottom Right"],
        "off:" .. T["Disabled"]
      },
      ["uf_debuff_indicator"] = {
        "0:" .. T["Disabled"],
        "1:" .. T["Legacy"],
        "2:" .. T["Glow"],
        "3:" .. T["Square"],
        "4:" .. T["Icon"]
      },
      ["uf_debuff_indicator_size"] = {
        ".10:10%",
        ".25:25%",
        ".35:35%",
        ".50:50%",
        ".65:65%",
        ".75:75%",
        ".90:90%",
      },
      ["percent_small"] = {
        "0:0%",
        ".05:5%",
        ".10:10%",
        ".15:15%",
        ".20:20%",
        ".25:25%",
        ".30:30%",
        ".35:35%",
        ".40:40%",
        ".45:45%",
        ".50:50%",
        ".55:55%",
        ".60:60%",
        ".65:65%",
        ".70:70%",
        ".75:75%",
        ".80:80%",
        ".85:85%",
        ".90:90%",
        ".95:95%",
        "1:100%",
      },
      ["uf_overheal"] = {
        "0:0%",
        "10:10%",
        "20:20%",
        "30:30%",
        "40:40%",
        "50:50%",
        "60:60%",
        "70:70%",
        "80:80%",
        "90:90%",
        "100:100%",
      },
      ["uf_layout"] = {
        "default:" .. T["Default"],
        "tukui:TukUI"
      },
      ["uf_color"] = {
        "0:" .. T["Class"],
        "1:" .. T["Custom"],
        "2:" .. T["Health"],
      },
      ["uf_texts"] = {
        "none:" .. T["Disable"],
        "unit:" .. T["Unit String"],
        "unitrev:" .. T["Unit String (Reverse)"],
        "name:" .. T["Name"],
        "nameshort:" .. T["Name (Short)"],
        "level:" .. T["Level"],
        "class:" .. T["Class"],
        "namehealth:" .. T["Name | Health Missing"],
        "namehealthbreak:" .. T["Name (Linebreak) -Health Missing"],
        "shortnamehealth:" .. T["Name (Short) | Health Missing"],
        "healthdyn:" .. T["Health - Auto"],
        "health:" .. T["Health - Current"],
        "healthmax:" .. T["Health - Max"],
        "healthperc:" .. T["Health - Percentage"],
        "healthmiss:" .. T["Health - Missing"],
        "healthminmax:" .. T["Health - Min/Max"],
        "powerdyn:" .. T["Mana - Auto"],
        "power:" .. T["Mana - Current"],
        "powermax:" .. T["Mana - Max"],
        "powerperc:" .. T["Mana - Percentage"],
        "powermiss:" .. T["Mana - Missing"],
        "powerminmax:" .. T["Mana - Min/Max"],
      },
      ["hpformat"] = {
        "percent:" .. T["Percent"],
        "cur:" .. T["Current HP"],
        "curperc:" .. T["Current HP | Percent"],
        "curmax:" .. T["Current HP - Max HP"],
        "curmaxs:" .. T["Current HP / Max HP"],
        "curmaxperc:" .. T["Current HP - Max HP | Percent"],
        "curmaxpercs:" .. T["Current HP / Max HP | Percent"],
        "deficit:" .. T["Deficit"],
      },
      ["panel_values"] = {
        "none:" .. T["Disable"],
        "time:" .. T["Clock"],
        "fps:" .. T["FPS & Ping"],
        "exp:" .. T["XP Percentage"],
        "gold:" .. T["Gold"],
        "friends:" .. T["Friends Online"],
        "guild:" .. T["Guild Online"],
        "durability:" .. T["Item Durability"],
        "zone:" .. T["Zone Name"],
        "combat:" .. T["Combat Timer"],
        "ammo:" .. T["Ammo Counter"],
        "soulshard:" .. T["Soulshard Counter"],
        "bindlocation:" .. T["Hearth"],
        "thistletea:" .. T["Thistle Tea"],
        "flashpowder:" .. T["Flash Powder"],
        "blindpowder:" .. T["Blinding Powder"],
        "bagspace:" .. T["Bagspace"]
      },
      ["tooltip_position"] = {
        "bottom:" .. T["Bottom"],
        "chat:" .. T["Dodge"],
        "cursor:" .. T["Cursor"],
        "free:" .. T["Custom"]
      },
      ["tooltip_align"] = {
        "native:" .. T["Native"],
        "top:" .. T["Top"],
        "left:" .. T["Left"],
        "right:" .. T["Right"]
      },
      ["debuffposition"] = {
        "TOP:" .. T["Top"],
        "BOTTOM:" .. T["Bottom"],
      },
      ["gmserver_text"] = {
        "elysium:" .. T["Elysium Based Core"],
      },
      ["buffbarfilter"] = {
        "none:"      .. T["None"],
        "whitelist:" .. T["Whitelist"],
        "blacklist:" .. T["Blacklist"],
      },
      ["buffbarsort"] = {
        "asc:" .. T["Ascending"],
        "desc:" .. T["Descending"],
      },
      ["minimap_cords_position"] = {
        "topleft:" .. T["Top Left"],
        "topright:" .. T["Top Right"],
        "bottomleft:" .. T["Bottom Left"],
        "bottomright:" .. T["Bottom Right"],
      },
      ["minimap_cords_visibility"] = {
        "mouseover:" .. T["Mouseover"],
        "on:" .. T["Enable"],
        "off:" .. T["Disable"]
      },
      ["minimap_zone_visibility"] = {
        "mouseover:" .. T["Mouseover"],
        "on:" .. T["Enable"],
        "off:" .. T["Disable"]
      },
      ["positions"] = {
        "TOPLEFT:" .. T["Top Left"],
        "TOP:" .. T["Top"],
        "TOPRIGHT:" .. T["Top Right"],
        "LEFT:" .. T["Left"],
        "CENTER:" .. T["Center"],
        "RIGHT:" .. T["Right"],
        "BOTTOMLEFT:" .. T["Bottom Left"],
        "BOTTOM:" .. T["Bottom"],
        "BOTTOMRIGHT:" .. T["Bottom Right"],
      },
      ["actionbuttonanimations"] = {
        "none:" .. T["None"],
        "zoomfade:" .. T["Zoom & Fade"],
        "shrinkreturn:" .. T["Shrink & Return"],
        "elasticzoom:" .. T["Elastic Zoom"],
        "wobblezoom:" .. T["Wobble Zoom"],
      },
      ["animationmode"] = {
        "keypress:" .. T["On Key Press"],
        "statechange:" .. T["On State Change"]
      },
      ["actionbarbuttons"] = {
        "1","2","3","4","5","6","7","8","9","10","11","12"
      },
      ["addonbuttons_position"] = {
        "bottom:" .. T["Bottom"],
        "left:" .. T["Left"],
        "top:" .. T["Top"],
        "right:" .. T["Right"]
      },
      ["xp_display"] = {
        "XPFLEX:" .. T["Automatic"],
        "XP:" .. T["Experience"],
        "REP:" .. T["Tracked Reputation"],
        "FLEX:" .. T["Last Reputation"],
        "PETXP:" .. T["Pet Experience"],
        "DISABLED:" .. T["Disabled"],
      },
      ["xp_position"] = {
        "BOTTOM:" .. T["Bottom"],
        "LEFT:" .. T["Left"],
        "TOP:" .. T["Top"],
        "RIGHT:" .. T["Right"]
      },
      ["glowintensity"] = {
        "8:" .. T["Tiny"],
        "16:" .. T["Small"],
        "32:" .. T["Medium"],
        "64:" .. T["Large"],
        "128:" .. T["Huge"],
      },
      ["mapcircle"] = {
        "5:" .. T["Tiny"],
        "3:" .. T["Small"],
        "1:" .. T["Medium"],
        "-1:" .. T["Large"],
        "-3:" .. T["Huge"],
      },
      ["maptooltip"] = {
        ".10:10%",
        ".20:20%",
        ".30:30%",
        ".40:40%",
        ".50:50%",
        ".60:60%",
        ".70:70%",
        ".80:80%",
        ".90:90%",
        "1:100%",
        "0:" .. T["World Map Scale"],
      },
      ["textalign"] = {
        "LEFT:" .. T["Left"],
        "CENTER:" .. T["Center"],
        "RIGHT:" .. T["Right"],
      },
      ["gryphons"] = {
        "None:"..T["None"],
        "Gryphon:"..T["Gryphon"],
        "Lion:"..T["Lion"],
        "Dragon:Gold dragon",
        "Dragon2:Rising dragon",
        "Elite:Elite dragon",
        "Rare:Silver dragon",
      }
    }

    -- add locale dependent client fonts to the list
    if GetLocale() == "enUS" or GetLocale() == "frFR" or GetLocale() == "deDE" or GetLocale() == "ruRU" then
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\ARIALN.TTF:ARIALN")
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\FRIZQT__.TTF:FRIZQT")
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\MORPHEUS.TTF:MORPHEUS")
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\SKURRI.TTF:SKURRI")
    elseif GetLocale() == "koKR" then
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\2002.TTF:2002")
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\2002B.TTF:2002B")
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\ARIALN.TTF:ARIALN")
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\FRIZQT__.TTF:FRIZQT")
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\K_Damage.TTF:K_Damage")
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\K_Pagetext.TTF:K_Pagetext")
    elseif GetLocale() == "zhCN" then
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\ARIALN.TTF:ARIALN")
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\FRIZQT__.TTF:FRIZQT")
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\FZBWJW.TTF:FZBWJW")
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\FZJZJW.TTF:FZJZJW")
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\FZLBJW.TTF:FZLBJW")
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\FZXHJW.TTF:FZXHJW")
      table.insert(pfUI.gui.dropdowns.fonts, "Fonts\\FZXHLJW.TTF:FZXHLJW")
    end

    pfUI.gui.dropdowns.loot_rarity = {}
    for i=0, getn(_G.ITEM_QUALITY_COLORS)-2  do
      local entry = string.format("%d:%s", i, string.format("%s%s%s", _G.ITEM_QUALITY_COLORS[i].hex, _G[string.format("ITEM_QUALITY%d_DESC",i)], FONT_COLOR_CODE_CLOSE))
      table.insert(pfUI.gui.dropdowns.loot_rarity, entry)
    end

    pfUI.gui.dropdowns.screenshot_battle = {
      "0:".._G.NONE,
      "1:"..T["Won"],
      "2:"..T["Ended"],
    }
    pfUI.gui.dropdowns.screenshot_loot = {"0:".._G.NONE}
    for i=3, 5 do
      local entry = string.format("%d:%s", i, string.format("%s%s%s", _G.ITEM_QUALITY_COLORS[i].hex, _G[string.format("ITEM_QUALITY%d_DESC",i)], FONT_COLOR_CODE_CLOSE))
        table.insert(pfUI.gui.dropdowns.screenshot_loot, entry)
    end
  end

  do -- Generate Config UI
    CreateGUIEntry(T["About"], nil, function()
      -- read data
      local lang = T["Unknown"]
      for _, entry in pairs(pfUI.gui.dropdowns.languages) do
        local short, full = strsplit(":", entry)
        if short == C.global.language then
          lang = full
        end
      end

      -- octo (26 Oct 2026, user: "the main screen ... must say pfUI Octo in our
      -- new artwork ... the author Bdot89"): the logo from tools\MakeOctoLogo.ps1,
      -- who made it, two cards (this game / client mods) and the links.
      -- Colours: W.C's flat palette, blue = open, green = found.
      local page = this
      local function Text(parent, size, r, g, b)
        local t = parent:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        t:SetFont(pfUI.font_default, size or C.global.font_size, "OUTLINE")
        t:SetTextColor(r or 1, g or 1, b or 1)
        return t
      end

      local logo = page:CreateTexture(nil, "ARTWORK")
      logo:SetTexture("Interface\\AddOns\\pfUI\\img\\octo\\logo")
      logo:SetWidth(256)
      logo:SetHeight(128)
      logo:SetPoint("TOP", page, "TOP", 0, -6)

      local tag = Text(page, C.global.font_size + 1, .62, .68, .76)
      tag:SetPoint("TOP", logo, "BOTTOM", 0, -2)
      tag:SetText(T["your whole interface in one addon"])

      local by = Text(page, C.global.font_size + 5)
      by:SetPoint("TOP", tag, "BOTTOM", 0, -8)
      by:SetText(T["made by"] .. " |cff33b3ffBdot89|r  |cff666e7a-|r  " .. T["aka"] .. " |cff9a6bffUpsi|r")

      -- a card: dark panel with a title bar
      local function Card(title, x)
        local card = CreateFrame("Frame", nil, page)
        card:SetWidth(320)
        card:SetHeight(160)
        card:SetPoint("TOP", page, "TOP", x, -212)
        card:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8", edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1 })
        card:SetBackdropColor(.125, .13, .145, .95)
        card:SetBackdropBorderColor(.23, .24, .27, 1)
        local head = card:CreateTexture(nil, "ARTWORK")
        head:SetTexture(.165, .17, .19, 1)
        head:SetPoint("TOPLEFT", 1, -1)
        head:SetPoint("TOPRIGHT", -1, -1)
        head:SetHeight(22)
        local accent = card:CreateTexture(nil, "OVERLAY")
        accent:SetTexture(.2, .7, 1, 1)
        accent:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, 0)
        accent:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, 0)
        accent:SetHeight(1)
        local t = Text(card, C.global.font_size + 1)
        t:SetPoint("LEFT", head, "LEFT", 8, 0)
        t:SetText(title)
        card.rows = 0
        -- a row: label left (dim), value right
        function card:Row(label)
          self.rows = self.rows + 1
          local y = -30 - (self.rows - 1) * 21
          local l = Text(self, C.global.font_size, .6, .61, .65)
          l:SetPoint("TOPLEFT", 10, y)
          l:SetText(label)
          local v = Text(self, C.global.font_size)
          v:SetPoint("TOPRIGHT", -10, y)
          v:SetJustifyH("RIGHT")
          return v
        end
        return card
      end

      local game = Card(T["pfUI Octo and this game"], -165)
      local version = game:Row(T["Version"])
      local based = game:Row(T["Based on"])
      local screen = game:Row(T["Resolution"])
      local scale = game:Row(T["UI scale"])
      local client = game:Row(T["Game client"])
      local language = game:Row(T["Language"])

      local mods = Card(T["Client mods it uses"], 165)
      -- name, how to find it out (a version text, true, or nil), what it adds
      local MODS = {
        { "SuperWoW", function() return SUPERWOW_VERSION and tostring(SUPERWOW_VERSION) end, T["focus by GUID, mouseover casts, enemy casts"] },
        { "ClassicAPI", function()
            if not C_UnitAuras then return end
            local v = tonumber(CLASSIC_API_VERSION)
            if v then return string.format("%d.%d.%d", math.floor(v / 10000), math.floor(math.mod(v, 10000) / 100), math.mod(v, 100)) end
            return T["found"]
          end, T["instant gear and bags, combat log, focus"] },
        { "nampower", function()
            if not GetNampowerVersion then return end
            local a, b, c = GetNampowerVersion()
            return a and (a .. "." .. (b or 0) .. "." .. (c or 0)) or T["found"]
          end, T["queued spell, spell casts"] },
        { "UnitXP_SP3", function()
            if not _G.UnitXP then return end
            local ok = pcall(_G.UnitXP, "nop", "nop")
            return ok and T["found"] or nil
          end, T["exact range and line of sight"] },
      }
      local modrows = {}
      for i, m in ipairs(MODS) do
        local v = mods:Row(m[1])
        v.what = m[3]
        modrows[i] = v
      end
      local hint = Text(mods, C.global.font_size - 1, .6, .61, .65)
      hint:SetPoint("BOTTOMLEFT", 10, 8)
      hint:SetPoint("BOTTOMRIGHT", -10, 8)
      hint:SetJustifyH("LEFT")
      hint:SetText(T["Optional: everything works without them."])

      -- links: copied into a box to paste in your browser
      local function Link(text, url, x, blue)
        local b = CreateFrame("Button", nil, page)
        b:SetWidth(150)
        b:SetHeight(24)
        b:SetPoint("TOP", page, "TOP", x, -388)
        b:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8", edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1 })
        local r, g, bl = .55, .58, .62
        if blue then r, g, bl = .35, .7, 1 end
        b:SetBackdropColor(r * .2, g * .2, bl * .2, 1)
        b:SetBackdropBorderColor(r * .85, g * .85, bl * .85, 1)
        local t = Text(b, C.global.font_size)
        t:SetPoint("CENTER", 0, 0)
        t:SetTextColor(r + (1 - r) * .4, g + (1 - g) * .4, bl + (1 - bl) * .4)
        t:SetText(text)
        b:SetScript("OnEnter", function()
          this:SetBackdropColor(r * .4, g * .4, bl * .4, 1)
          GameTooltip:SetOwner(this, "ANCHOR_TOP")
          GameTooltip:SetText(text, 1, 1, 1)
          GameTooltip:AddLine(url, r, g, bl)
          GameTooltip:AddLine(T["Click: copy the link"], .6, .61, .65)
          GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function()
          this:SetBackdropColor(r * .2, g * .2, bl * .2, 1)
          GameTooltip:Hide()
        end)
        b:SetScript("OnClick", function() pfUI.chat.urlcopy.CopyText(url) end)
        return b
      end
      Link(T["Web page"], "https://bdot89.github.io/pfUI-Octo/", -160, true)
      Link("GitHub", "https://github.com/bdot89/pfUI-Octo", 0, true)
      Link(T["Original pfUI"], "https://github.com/shagu/pfUI", 160)

      local thanks = Text(page, C.global.font_size - 1, .5, .52, .56)
      thanks:SetPoint("TOP", page, "TOP", 0, -424)
      thanks:SetText(T["Thanks to Shagu for pfUI, and to everyone on OctoWoW who tries it out."])

      -- octo (29 Oct 2026): a newer pfUI Octo seen on another player
      -- (updatenotify.lua) gets a box with the link for the OctoWoW launcher
      local upd = CreateFrame("Frame", nil, page)
      upd:SetWidth(640)
      upd:SetHeight(84)
      upd:SetPoint("TOP", page, "TOP", 0, -446)
      upd:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8", edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1 })
      upd:SetBackdropColor(.16, .12, .04, 1)
      upd:SetBackdropBorderColor(1, .72, .2, 1)
      local updTitle = Text(upd, C.global.font_size + 3, 1, .8, .3)
      updTitle:SetPoint("TOPLEFT", 10, -8)
      local updText = Text(upd, C.global.font_size, .85, .86, .9)
      updText:SetPoint("TOPLEFT", 10, -28)
      updText:SetPoint("TOPRIGHT", -10, -28)
      updText:SetJustifyH("LEFT")
      updText:SetText(T["Copy this link and add it in the OctoWoW launcher: it then keeps pfUI Octo up to date for you."])
      local box = CreateFrame("EditBox", nil, upd)
      box:SetHeight(20)
      box:SetPoint("BOTTOMLEFT", 10, 8)
      box:SetPoint("BOTTOMRIGHT", -10, 8)
      box:SetAutoFocus(false)
      box:SetFontObject(GameFontWhite)
      box:SetFont(pfUI.font_default, C.global.font_size + 1, "OUTLINE")
      box:SetTextInsets(6, 6, 0, 0)
      box:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8", edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1 })
      box:SetBackdropColor(0, 0, 0, .6)
      box:SetBackdropBorderColor(.35, .7, 1, 1)
      local url = pfUI.octoUpdate and pfUI.octoUpdate.url or "https://github.com/bdot89/pfUI-Octo"
      box:SetText(url)
      -- always the link; click selects it all for Ctrl+C
      box:SetScript("OnTextChanged", function() if this:GetText() ~= url then this:SetText(url) this:HighlightText() end end)
      box:SetScript("OnEditFocusGained", function() this:HighlightText() end)
      box:SetScript("OnEscapePressed", function() this:ClearFocus() end)
      box:SetScript("OnEnterPressed", function() this:ClearFocus() end)
      upd:Hide()
      page.octoUpdateBox = upd

      -- the numbers that can change, once a second while the page shows
      local f = CreateFrame("Frame", nil, page)
      f:SetScript("OnUpdate", function()
        if ( this.tick or 0) > GetTime() then return else this.tick = GetTime() + 1 end
        -- the scroll child keeps the width it was made with: fill the panel so
        -- the centred logo, cards and links are not cut off at the left
        local holder = page.parent or page:GetParent()
        local w = holder and holder:GetWidth()
        if w and w > 200 and math.abs((page:GetWidth() or 0) - w) > 1 then page:SetWidth(w) end
        local newer = pfUI.octoUpdate and pfUI.octoUpdate.Newer()
        if newer then
          updTitle:SetText(string.format(T["pfUI Octo %s is out - you have %s"], newer, pfUI.version.octo))
          upd:Show()
        else
          upd:Hide()
        end
        version:SetText("|cff33b3ffv" .. pfUI.version.octo .. "|r" .. (newer and (" |cffffc840(" .. newer .. " " .. T["is out"] .. ")|r") or ""))
        based:SetText("pfUI " .. pfUI.version.string .. " " .. T["by"] .. " Shagu")
        screen:SetText(GetCVar("gxResolution"))
        scale:SetText(round(UIParent:GetEffectiveScale(), 2))
        client:SetText(GetBuildInfo() .. " (" .. GetLocale() .. ")")
        language:SetText(lang)
        for i, m in ipairs(MODS) do
          local ok, found = pcall(m[2])
          if ok and found then
            modrows[i]:SetText("|cff3fd977" .. found .. "|r")
          else
            modrows[i]:SetText("|cff666e7a" .. T["not found"] .. "|r")
          end
        end
      end)
    end)

    CreateGUIEntry(T["Settings"], T["General"], function()
      local header = CreateConfig(nil, T["Profile"], nil, nil, "header")
      header:GetParent().objectCount = header:GetParent().objectCount - 1
      header:SetHeight(20)

      CreateConfig(function() return end, T["Select profile"], C.global, "profile", "dropdown", function()
        local values = {}
        for name, config in pairs(pfUI_profiles) do table.insert(values, name) end
        table.sort(values)
        return values
      end, false, "Profile")

      -- load profile
      CreateConfig(nil, T["Load profile"], C.global, "profile", "button", function()
        if C.global.profile and pfUI_profiles[C.global.profile] then
          CreateQuestionDialog(T["Load profile"] .. " '" .. rgbhex(GetAccentColor()) .. C.global.profile .. "|r'?", function()
            local selp = C.global.profile
            local rchat = C.chat.right.enable

            -- load profile
            _G["pfUI_config"] = CopyTable(pfUI_profiles[C.global.profile])

            -- restore values
            pfUI:UpdateConfig("global", nil, "profile", selp)
            pfUI:UpdateConfig("chat", "right", "enable", rchat)

            -- add default values
            pfUI:LoadConfig()

            ReloadUI()
          end)
        end
      end)

      -- delete profile
      CreateConfig(nil, T["Delete profile"], C.global, "profile", "button", function()
        if C.global.profile and pfUI_profiles[C.global.profile] then
          CreateQuestionDialog(T["Delete profile"] .. " '" .. rgbhex(GetAccentColor()) .. C.global.profile .. "|r'?", function()
            pfUI_profiles[C.global.profile] = nil
            this:GetParent():Hide()
          end)
        end
      end, true)

      -- save profile
      CreateConfig(nil, T["Save profile"], C.global, "profile", "button", function()
        if C.global.profile and pfUI_profiles[C.global.profile] then
          CreateQuestionDialog(T["Save current settings to profile"] .. " '" .. rgbhex(GetAccentColor()) .. C.global.profile .. "|r'?", function()
            if pfUI_profiles[C.global.profile] then
              pfUI_profiles[C.global.profile] = CopyTable(C)
            end
            this:GetParent():Hide()
          end)
        end
      end, true)

      -- create profile
      CreateConfig(nil, T["Create Profile"], C.global, "profile", "button", function()
        CreateQuestionDialog(T["Please enter a name for the new profile.\nExisting profiles sharing the same name will be overwritten."],
        function()
          local profile = this:GetParent().input:GetText()
          local bad = string.gsub(profile,"([%w%s]+)","")
          if bad~="" then
            message("\"" .. bad .. "\" " .. T["is not allowed in profile name"])
          else
            profile = (string.gsub(profile,"^%s*(.-)%s*$", "%1"))
            if profile and profile ~= "" then
              pfUI_profiles[profile] = CopyTable(C)
              this:GetParent():Hide()
            end
          end
        end, false, true)
      end, true)

      -- add invisible font to disable combat messages
      local combatfonts = CopyTable(pfUI.gui.dropdowns.fonts)
      table.insert(combatfonts, "Interface\\AddOns\\pfUI\\fonts\\AdobeBlank.ttf:Invisible")

      CreateConfig(nil, T["Settings"], nil, nil, "header")
      CreateConfig(nil, T["Language"], C.global, "language", "dropdown", pfUI.gui.dropdowns.languages)
      CreateConfig(U["pixelperfect"], T["Enable UI-Scale"], C.global, "pixelperfect", "dropdown", pfUI.gui.dropdowns.scaling)
      CreateConfig(nil, T["Use Original Game Fonts"], C.global, "font_blizzard", "checkbox")
      -- octo: keep "Screen Captured" out of screenshots (modules/plates-lists.lua)
      CreateConfig(function() if pfUI.octoShot then pfUI.octoShot() end end, T["Show \"Screen Captured\" After A Screenshot"], C.global, "screenshotmsg", "checkbox")
      CreateConfig(nil, T["Enable Region Compatible Font"], C.global, "force_region", "checkbox")
      CreateConfig(nil, T["Standard Text Font"], C.global, "font_default", "dropdown", pfUI.gui.dropdowns.fonts)
      CreateConfig(nil, T["Standard Text Font Size"], C.global, "font_size")
      CreateConfig(nil, T["3D World Unit Font"], C.global, "font_unit_name", "dropdown", pfUI.gui.dropdowns.fonts)
      CreateConfig(nil, T["Scrolling Combat Text Font"], C.global, "font_combat", "dropdown", combatfonts)
      CreateConfig(nil, T["Enable Offscreen Frame Positions"], C.global, "offscreen", "checkbox")
      CreateConfig(nil, T["Display Addon Errors In Chat"], C.global, "errors", "checkbox")
      CreateConfig(nil, T["Use Single Line UIErrors Frame"], C.global, "errors_limit", "checkbox")
      CreateConfig(nil, T["Disable Errors in UIErrors Frame"], C.global, "errors_hide", "checkbox")
      CreateConfig(nil, T["Highlight Settings That Require Reload"], C.gui, "reloadmarker", "checkbox")
      CreateConfig(nil, T["Show Incompatible Config Entries"], C.gui, "showdisabled", "checkbox")
      CreateConfig(nil, T["Abbreviate Numbers (4200 -> 4.2k)"], C.unitframes, "abbrevnum", "checkbox")
      CreateConfig(nil, T["Abbreviate Unit Names"], C.unitframes, "abbrevname", "checkbox")
      CreateConfig(nil, T["Health Point Estimation"], nil, nil, "header")
      CreateConfig(nil, T["Estimate Enemy Health Points"], C.global, "libhealth", "checkbox")
      CreateConfig(nil, T["Threshold To Trust Health Estimation"], C.global, "libhealth_hit", "dropdown", pfUI.gui.dropdowns.uf_rangecheckinterval)
      CreateConfig(nil, T["Required Damage In Percent"], C.global, "libhealth_dmg", "dropdown", pfUI.gui.dropdowns.percent_small)

      -- Delete / Reset
      CreateConfig(nil, T["Delete / Reset"], nil, nil, "header")
      CreateConfig(nil, T["|cffff5555EVERYTHING"], C.global, "profile", "button", function()
        CreateQuestionDialog(T["Do you really want to reset |cffffaaaaEVERYTHING|r?\n\nThis will reset:\n - Current Configuration\n - Current Frame Positions\n - Firstrun Wizard\n - Addon Cache\n - Saved Profiles"],
          function()
            _G["pfUI_init"] = {}
            _G["pfUI_config"] = pfUI.octo.Profile()
            _G["pfUI_playerDB"] = {}
            _G["pfUI_profiles"] = {}
            _G["pfUI_cache"] = {}
            pfUI:LoadConfig()
            this:GetParent():Hide()
            pfUI.gui:Reload()
          end)
      end)

      CreateConfig(nil, T["Configuration"], C.global, "profile", "button", function()
        CreateQuestionDialog(T["Do you really want to reset your configuration?\nThis also includes frame positions"],
          function()
            _G["pfUI_config"] = pfUI.octo.Profile()
            _G["pfUI_init"] = {}
            pfUI:LoadConfig()
            this:GetParent():Hide()
            pfUI.gui:Reload()
          end)
      end, true)

      CreateConfig(nil, T["Cache"], C.global, "profile", "button", function()
        CreateQuestionDialog(T["Do you really want to reset the Cache?"],
          function()
            _G["pfUI_playerDB"] = {}
            _G["pfUI_cache"] = {}
            this:GetParent():Hide()
            pfUI.gui:Reload()
          end)
      end, true)

      CreateConfig(nil, T["Firstrun"], C.global, "profile", "button", function()
        _G["pfUI_init"] = {}
        pfUI.gui:Hide()
        pfUI.firstrun:NextStep()
      end, true)
    end)

    CreateGUIEntry(T["Settings"], T["Appearance"], function()
      CreateConfig(nil, T["Octo Look"], nil, nil, "header")
      CreateConfig(nil, T["Apply Octo Look (borders, colors, fonts, bar textures)"], C.global, "profile", "button", function()
        CreateQuestionDialog(T["Apply the Octo look?\n\nBorders, backgrounds, fonts and bar textures change.\nFrame sizes and positions stay as they are."],
          function()
            pfUI.octo.ApplyLook()
            ReloadUI()
          end)
      end)
      CreateConfig(nil, T["Accent Color"], C.appearance.accent, "mode", "dropdown", pfUI.gui.dropdowns.accent)
      CreateConfig(nil, T["Custom Accent Color"], C.appearance.accent, "color", "color")
      CreateConfig(nil, T["Colors"], nil, nil, "header")
      CreateConfig(nil, T["Background Color"], C.appearance.border, "background", "color")
      CreateConfig(nil, T["Border Color"], C.appearance.border, "color", "color")
      CreateConfig(U["mapreveal"], T["Map Reveal Color"], C.appearance.worldmap, "mapreveal_color", "color")
      CreateConfig(U["mapreveal"], T["Map Exploration Points"], C.appearance.worldmap, "mapexploration", "checkbox")
      CreateConfig(U["mapcolors"], T["Map Group/Raid Circle Size"], C.appearance.worldmap, "groupcircles", "dropdown", pfUI.gui.dropdowns.mapcircle)
      CreateConfig(U["mapcolors"], T["Colorize player name on WorldMap and BattlefieldMinimap"], C.appearance.worldmap, "colornames", "checkbox")
      CreateConfig(U["map"], T["Map Tooltip Scale"], C.appearance.worldmap, "tooltipsize", "dropdown", pfUI.gui.dropdowns.maptooltip)
      CreateConfig(nil) -- spacer
      CreateConfig(nil, T["Enable Frame Shadow"], C.appearance.border, "shadow", "checkbox")
      CreateConfig(nil, T["Frame Shadow Intensity"], C.appearance.border, "shadow_intensity", "dropdown", pfUI.gui.dropdowns.uf_debuff_indicator_size)
      CreateConfig(nil) -- spacer
      CreateConfig(nil, T["Force Blizzard Borders (|cffffaaaaExperimental|r)"], C.appearance.border, "force_blizz", "checkbox")
      CreateConfig(nil, T["Enable Pixel Perfect Borders"], C.appearance.border, "pixelperfect", "checkbox")
      CreateConfig(nil, T["Scale Border On HiDPI Displays"], C.appearance.border, "hidpi", "checkbox")
      CreateConfig(nil) -- spacer
      CreateConfig(nil, T["Global Border Size"], C.appearance.border, "default", "dropdown", pfUI.gui.dropdowns.border)
      CreateConfig(nil, T["Action Bar Border Size"], C.appearance.border, "actionbars", "dropdown", pfUI.gui.dropdowns.border)
      CreateConfig(nil, T["Unit Frame Border Size"], C.appearance.border, "unitframes", "dropdown", pfUI.gui.dropdowns.border)
      CreateConfig(nil, T["Panel Border Size"], C.appearance.border, "panels", "dropdown", pfUI.gui.dropdowns.border)
      CreateConfig(nil, T["Chat Border Size"], C.appearance.border, "chat", "dropdown", pfUI.gui.dropdowns.border)
      CreateConfig(nil, T["Bags Border Size"], C.appearance.border, "bags", "dropdown", pfUI.gui.dropdowns.border)
      CreateConfig(U["nameplates"], T["Nameplate Border Size"], C.appearance.border, "nameplates", "dropdown", pfUI.gui.dropdowns.border)
      CreateConfig(nil) -- spacer
      CreateConfig(U["infight"], T["Enable Combat Glow Effects On Screen Edges"], C.appearance.infight, "screen", "checkbox")
      CreateConfig(U["infight"], T["Enable Aggro Glow Effects On Screen Edges"], C.appearance.infight, "aggro", "checkbox")
      CreateConfig(U["infight"], T["Enable Low Health Glow Effects On Screen Edges"], C.appearance.infight, "health", "checkbox")
      CreateConfig(U["infight"], T["Screen Edge Glow Intensity"], C.appearance.infight, "intensity", "dropdown", pfUI.gui.dropdowns.glowintensity)
    end)

    CreateGUIEntry(T["Settings"], T["Cooldown"], function()
      CreateConfig(U["buff"], T["Show Milliseconds When Timer Runs Out"], C.appearance.cd, "milliseconds", "checkbox")
      CreateConfig(nil, T["Cooldown Color (Less than 3 Sec)"], C.appearance.cd, "lowcolor", "color")
      CreateConfig(nil, T["Cooldown Color (Seconds)"], C.appearance.cd, "normalcolor", "color")
      CreateConfig(nil, T["Cooldown Color (Minutes)"], C.appearance.cd, "minutecolor", "color")
      CreateConfig(nil, T["Cooldown Color (Hours)"], C.appearance.cd, "hourcolor", "color")
      CreateConfig(nil, T["Cooldown Color (Days)"], C.appearance.cd, "daycolor", "color")
      CreateConfig(nil, T["Use Dynamic Font Size"], C.appearance.cd, "dynamicsize", "checkbox")
      CreateConfig(nil, T["Cooldown Text Font"], C.appearance.cd, "font", "dropdown", pfUI.gui.dropdowns.fonts)
      CreateConfig(nil, T["Cooldown Text Font Size"], C.appearance.cd, "font_size")
      CreateConfig(nil, T["Cooldown Text Font Size (Blizzard Frames)"], C.appearance.cd, "font_size_blizz")
      CreateConfig(nil, T["Cooldown Text Font Size (Foreign Frames)"], C.appearance.cd, "font_size_foreign")
      CreateConfig(nil, T["Cooldown Text Time Threshold"], C.appearance.cd, "threshold")
      CreateConfig(nil, T["Display Debuff Durations"], C.appearance.cd, "debuffs", "checkbox")
      CreateConfig(nil, T["Enable Durations On Blizzard Frames"], C.appearance.cd, "blizzard", "checkbox")
      CreateConfig(nil, T["Enable Durations On Foreign Frames"], C.appearance.cd, "foreign", "checkbox")
      CreateConfig(nil, T["Hide Foreign Cooldown Animations"], C.appearance.cd, "hideanim", "checkbox")
    end)

    CreateGUIEntry(T["Settings"], T["Screenshot"], function()
      CreateConfig(nil, T["Timer In Minutes"], C.screenshot, "interval")
      CreateConfig(nil, T["Level Up"], C.screenshot, "levelup", "checkbox")
      CreateConfig(nil, T["PvP Rank"], C.screenshot, "pvprank", "checkbox")
      CreateConfig(nil, T["Reputation Level"], C.screenshot, "faction", "checkbox")
      CreateConfig(nil, T["Honorable Kill"], C.screenshot, "hk", "checkbox")
      CreateConfig(nil, T["Battleground Statistics"], C.screenshot, "battleground", "dropdown", pfUI.gui.dropdowns.screenshot_battle)
      CreateConfig(nil, T["Item Looted"], C.screenshot, "loot", "dropdown", pfUI.gui.dropdowns.screenshot_loot)
      CreateConfig(nil, T["Options"], nil, nil, "header")
      CreateConfig(nil, T["Show Description"], C.screenshot, "caption", "checkbox")
      CreateConfig(nil, T["Description Font"], C.screenshot, "caption_font", "dropdown", pfUI.gui.dropdowns.fonts)
      CreateConfig(nil, T["Description Font Size"], C.screenshot, "caption_size")
      CreateConfig(nil, T["Hide All UI Elements"], C.screenshot, "hideui", "checkbox")
    end)

    CreateGUIEntry(T["Settings"], T["GM-Mode"], function()
      CreateConfig(nil, T["Disable GM-Mode"], C.gm, "disable", "checkbox")
      CreateConfig(nil, T["Selected Core"], C.gm, "server", "dropdown", pfUI.gui.dropdowns.gmserver_text)
    end)

    CreateGUIEntry(T["Unit Frames"], T["General"], function()
      CreateConfig(nil, T["Disable pfUI Unit Frames"], C.unitframes, "disable", "checkbox")
      CreateConfig(nil, T["Healthbar Animation Speed"], C.unitframes, "animation_speed", "dropdown", pfUI.gui.dropdowns.uf_animationspeed)
      CreateConfig(nil, T["Portrait Alpha"], C.unitframes, "portraitalpha")
      CreateConfig(nil, T["Always Use 2D Portraits"], C.unitframes, "always2dportrait", "checkbox")
      CreateConfig(nil, T["Enable 2D Portraits As Fallback"], C.unitframes, "portraittexture", "checkbox")
      CreateConfig(nil, T["Unit Frame Layout"], C.unitframes, "layout", "dropdown", pfUI.gui.dropdowns.uf_layout)
      CreateConfig(nil, T["Combopoint Width"], C.unitframes, "combowidth")
      CreateConfig(nil, T["Combopoint Height"], C.unitframes, "comboheight")
      CreateConfig(nil, T["Show Resting"], C.unitframes.player, "showRest", "checkbox")
      CreateConfig(nil, T["Enable Energy Ticks"], C.unitframes.player, "energy", "checkbox")
      CreateConfig(nil, T["Enable Mana Ticks"], C.unitframes.player, "manatick", "checkbox")
      CreateConfig(nil, T["Detect Enemy Buffs"], C.unitframes, "buffdetect", "checkbox", nil, nil, nil, nil, "vanilla" )

      CreateConfig(U[c], T["Font Options"], nil, nil, "header")
      CreateConfig(nil, T["Unit Frame Text Font"], C.global, "font_unit", "dropdown", pfUI.gui.dropdowns.fonts)
      CreateConfig(nil, T["Unit Frame Text Size"], C.global, "font_unit_size")
      CreateConfig(nil, T["Unit Frame Text Style"], C.global, "font_unit_style", "dropdown", pfUI.gui.dropdowns.fontstyle)

      CreateConfig(U[c], T["Group Options"], nil, nil, "header")
      CreateConfig(nil, T["Enable 40y-Range Check"], C.unitframes, "rangecheck", "checkbox", nil, nil, nil, nil, "vanilla" )
      CreateConfig(nil, T["Range Check Interval"], C.unitframes, "rangechecki", "dropdown", pfUI.gui.dropdowns.uf_rangecheckinterval, nil, nil, nil, "vanilla")
      CreateConfig(nil, T["Use Raid Frames To Display Group Members"], C.unitframes, "raidforgroup", "checkbox")
      CreateConfig(nil, T["Always Show Self In Raid Frames"], C.unitframes, "selfinraid", "checkbox")
      CreateConfig(nil, T["Show Self In Group Frames"], C.unitframes, "selfingroup", "checkbox")
      CreateConfig(nil, T["Hide Group Frames While In Raid"], C.unitframes.group, "hide_in_raid", "checkbox")
      CreateConfig(nil, T["Max Amount Of Raid Frames"], C.unitframes, "maxraid", "dropdown", pfUI.gui.dropdowns.maxraid)

      CreateConfig(U[c], T["Colors"], nil, nil, "header")
      CreateConfig(nil, T["Enable Pastel Colors"], C.unitframes, "pastel", "checkbox")
      CreateConfig(nil, T["Health Bar Color"], C.unitframes, "custom", "dropdown", pfUI.gui.dropdowns.uf_color)
      CreateConfig(nil, T["Custom Health Bar Color"], C.unitframes, "customcolor", "color")
      CreateConfig(nil, T["Fade To Custom Color"], C.unitframes, "customfade", "checkbox")
      CreateConfig(nil, T["Use Custom Color On Full Health"], C.unitframes, "customfullhp", "checkbox")
      CreateConfig(nil, T["Enable Custom Color Health Bar Background"], C.unitframes, "custombg", "checkbox")
      CreateConfig(nil, T["Custom Health Bar Background Color"], C.unitframes, "custombgcolor", "color")
      CreateConfig(nil, T["Enable Custom Color Power Bar Background"], C.unitframes, "custompbg", "checkbox")
      CreateConfig(nil, T["Custom Power Bar Background Color"], C.unitframes, "custompbgcolor", "color")
      CreateConfig(nil, T["Mana Color"], C.unitframes, "manacolor", "color")
      CreateConfig(nil, T["Rage Color"], C.unitframes, "ragecolor", "color")
      CreateConfig(nil, T["Energy Color"], C.unitframes, "energycolor", "color")
      CreateConfig(nil, T["Focus Color"], C.unitframes, "focuscolor", "color")

      CreateConfig(nil, T["SuperWoW Settings"], nil, nil, "header")
      CreateConfig(nil, T["Show Druid Mana Bar"], C.unitframes, "druidmanabar", "checkbox", nil, nil, nil, nil, "vanilla" )
      CreateConfig(nil, T["Druid Mana Bar Height"], C.unitframes, "druidmanaheight", nil, nil, nil, nil, nil, "vanilla" )
      CreateConfig(nil, T["Druid Mana Bar Text"], C.unitframes, "druidmanatext", "checkbox", nil, nil, nil, nil, "vanilla" )
    end)

    -- Shared Unit- and Groupframes
    local unitframeSettings = {
      --      config,        text
      [1] = { "player",      T["Player"] },
      [2] = { "target",      T["Target"] },
      [3] = { "ttarget",     T["Target-Target"]},
      [4] = { "tttarget",    T["Target-Target-Target"]},
      [5] = { "pet",         T["Pet"] },
      [6] = { "ptarget",     T["Pet-Target"]},
      [7] = { "focus",       T["Focus"] },
      [8] = { "focustarget", T["Focus-Target"] },
      [9] = { "group",       T["Group"] },
      [10] = { "grouptarget", T["Group-Target"]},
      [11] = { "grouppet",   T["Group-Pet"] },
      [12] = { "raid",       T["Raid"] },
    }

    CreateGUIEntry(T["Unit Frames"], T["Click Casting"], function()
      for id, data in ipairs(unitframeSettings) do
        CreateConfig(U[data[1]], T["Enable"] .. " " .. data[2] .. " " .. T["Click Casting"], C.unitframes[data[1]], "clickcast", "checkbox")
      end

      CreateConfig(nil, T["Left Mouse Button"], nil, nil, "header")
      CreateConfig(nil, T["Click Action"], C.unitframes, "clickcast", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Shift-Click Action"], C.unitframes, "clickcast_shift", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Alt-Click Action"], C.unitframes, "clickcast_alt", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Ctrl-Click Action"], C.unitframes, "clickcast_ctrl", nil, nil, nil, nil, "STRING")

      CreateConfig(nil, T["Right Mouse Button"], nil, nil, "header")
      CreateConfig(nil, T["Click Action"], C.unitframes, "clickcast2", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Shift-Click Action"], C.unitframes, "clickcast2_shift", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Alt-Click Action"], C.unitframes, "clickcast2_alt", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Ctrl-Click Action"], C.unitframes, "clickcast2_ctrl", nil, nil, nil, nil, "STRING")

      CreateConfig(nil, T["Middle Mouse Button"], nil, nil, "header")
      CreateConfig(nil, T["Click Action"], C.unitframes, "clickcast3", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Shift-Click Action"], C.unitframes, "clickcast3_shift", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Alt-Click Action"], C.unitframes, "clickcast3_alt", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Ctrl-Click Action"], C.unitframes, "clickcast3_ctrl", nil, nil, nil, nil, "STRING")

      CreateConfig(nil, T["Mouse Button 4"], nil, nil, "header")
      CreateConfig(nil, T["Click Action"], C.unitframes, "clickcast4", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Shift-Click Action"], C.unitframes, "clickcast4_shift", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Alt-Click Action"], C.unitframes, "clickcast4_alt", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Ctrl-Click Action"], C.unitframes, "clickcast4_ctrl", nil, nil, nil, nil, "STRING")

      CreateConfig(nil, T["Mouse Button 5"], nil, nil, "header")
      CreateConfig(nil, T["Click Action"], C.unitframes, "clickcast5", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Shift-Click Action"], C.unitframes, "clickcast5_shift", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Alt-Click Action"], C.unitframes, "clickcast5_alt", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Ctrl-Click Action"], C.unitframes, "clickcast5_ctrl", nil, nil, nil, nil, "STRING")
    end)

    for id, data in ipairs(unitframeSettings) do
      local c = data[1]
      local t = data[2]

      CreateGUIEntry(T["Unit Frames"], t, function()
        -- link Update tables
        U.ttarget     = U["targettarget"]
        U.tttarget    = U["targettargettarget"]
        U.ptarget     = U["pettarget"]
        U.grouptarget = U["group"]
        U.grouppet    = U["group"]

        -- build config entries
        CreateConfig(U[c], T["Display Frame"] .. ": " .. t, C.unitframes[c], "visible", "checkbox")
        CreateConfig(U[c], T["Enable Mouseover Tooltip"], C.unitframes[c], "showtooltip", "checkbox")
        CreateConfig(U[c], T["Default Transparency"], C.unitframes[c], "alpha_visible", "dropdown", pfUI.gui.dropdowns.percent_small)
        CreateConfig(U[c], T["Out Of Range Transparency"], C.unitframes[c], "alpha_outrange", "dropdown", pfUI.gui.dropdowns.percent_small)
        CreateConfig(U[c], T["Offline Transparency"], C.unitframes[c], "alpha_offline", "dropdown", pfUI.gui.dropdowns.percent_small)
        CreateConfig(U[c], T["Enable Range Fading"], C.unitframes[c], "faderange", "checkbox")
        CreateConfig(U[c], T["Enable Aggro Glow"], C.unitframes[c], "glowaggro", "checkbox")
        CreateConfig(U[c], T["Enable Combat Glow"], C.unitframes[c], "glowcombat", "checkbox")
        CreateConfig(U[c], T["Portrait Position"], C.unitframes[c], "portrait", "dropdown", pfUI.gui.dropdowns.uf_portrait_position)
        CreateConfig(U[c], T["Portrait Width"], C.unitframes[c], "portraitwidth")
        CreateConfig(U[c], T["Portrait Height"], C.unitframes[c], "portraitheight")
        CreateConfig(U[c], T["Health Bar Texture"], C.unitframes[c], "bartexture", "dropdown", pfUI.gui.dropdowns.uf_bartexture)
        CreateConfig(U[c], T["Power Bar Texture"], C.unitframes[c], "pbartexture", "dropdown", pfUI.gui.dropdowns.uf_bartexture)
        CreateConfig(U[c], T["UnitFrame Spacing"], C.unitframes[c], "pspace")
        CreateConfig(U[c], T["Show PvP-Flag"], C.unitframes[c], "showPVP", "checkbox")
        CreateConfig(U[c], T["PVP Flag Size"], C.unitframes[c], "pvpiconsize")
        CreateConfig(U[c], T["PvP Flag Position"], C.unitframes[c], "pvpiconalign", "dropdown", pfUI.gui.dropdowns.positions)
        CreateConfig(U[c], T["PvP Flag X-Offset"], C.unitframes[c], "pvpiconoffx")
        CreateConfig(U[c], T["PvP Flag Y-Offset"], C.unitframes[c], "pvpiconoffy")
        CreateConfig(U[c], T["Show Loot Icon"], C.unitframes[c], "looticon", "checkbox")
        CreateConfig(U[c], T["Show Leader Icon"], C.unitframes[c], "leadericon", "checkbox")
        if c == "pet" then
          CreateConfig(U[c], T["Show Happiness Icon"], C.unitframes[c], "happinessicon", "dropdown", pfUI.gui.dropdowns.uf_happiness)
          CreateConfig(U[c], T["Happiness Icon Size"], C.unitframes[c], "happinesssize")
        end
        CreateConfig(U[c], T["Show Raid Mark"], C.unitframes[c], "raidicon", "checkbox")
        CreateConfig(U[c], T["Raid Mark Position"], C.unitframes[c], "raidiconalign", "dropdown", pfUI.gui.dropdowns.positions)
        CreateConfig(U[c], T["Raid Mark X-Offset"], C.unitframes[c], "raidiconoffx")
        CreateConfig(U[c], T["Raid Mark Y-Offset"], C.unitframes[c], "raidiconoffy")
        CreateConfig(U[c], T["Raid Mark Size"], C.unitframes[c], "raidiconsize")
        CreateConfig(U[c], T["Heal Color"], C.unitframes[c], "healcolor", "color")
        CreateConfig(U[c], T["Display Overheal"], C.unitframes[c], "overhealperc", "dropdown", pfUI.gui.dropdowns.uf_overheal)

        if c == "raid" then
          CreateConfig(U["raid"], T["Display Raid Group Label"], C.unitframes[c], "raidgrouplabel", "checkbox")
          CreateConfig(U["raid"], T["Group Label X-Offset"], C.unitframes[c], "grouplabelxoff")
          CreateConfig(U["raid"], T["Group Label Y-Offset"], C.unitframes[c], "grouplabelyoff")

          CreateConfig(U[c], T["Layout"], nil, nil, "header")
          CreateConfig(U["raid"], T["Raid Padding"], C.unitframes[c], "raidpadding")
          CreateConfig(U["raid"], T["Raid Layout"], C.unitframes[c], "raidlayout", "dropdown", pfUI.gui.dropdowns.uf_raidlayout)
          CreateConfig(U["raid"], T["Raid Fill Direction"], C.unitframes[c], "raidfill", "dropdown", pfUI.gui.dropdowns.orientation)
        end

        CreateConfig(U[c], T["Healthbar"], nil, nil, "header")
        CreateConfig(U[c], T["Health Bar Width"], C.unitframes[c], "width")
        CreateConfig(U[c], T["Health Bar Height"], C.unitframes[c], "height")
        CreateConfig(U[c], T["Left Text"], C.unitframes[c], "txthpleft", "dropdown", pfUI.gui.dropdowns.uf_texts)
        CreateConfig(U[c], T["Left Text X Offset"], C.unitframes[c], "txthpleftoffx")
        CreateConfig(U[c], T["Left Text Y Offset"], C.unitframes[c], "txthpleftoffy")
        CreateConfig(U[c], T["Center Text"], C.unitframes[c], "txthpcenter", "dropdown", pfUI.gui.dropdowns.uf_texts)
        CreateConfig(U[c], T["Center Text X Offset"], C.unitframes[c], "txthpcenteroffx")
        CreateConfig(U[c], T["Center Text Y Offset"], C.unitframes[c], "txthpcenteroffy")
        CreateConfig(U[c], T["Right Text"], C.unitframes[c], "txthpright", "dropdown", pfUI.gui.dropdowns.uf_texts)
        CreateConfig(U[c], T["Right Text X Offset"], C.unitframes[c], "txthprightoffx")
        CreateConfig(U[c], T["Right Text Y Offset"], C.unitframes[c], "txthprightoffy")
        CreateConfig(U[c], T["Invert Health Bar"], C.unitframes[c], "invert_healthbar", "checkbox")
        CreateConfig(U[c], T["Enable Vertical Health Bar"], C.unitframes[c], "verticalbar", "checkbox")

        CreateConfig(U[c], T["Powerbar"], nil, nil, "header")
        CreateConfig(U[c], T["Power Bar Height"], C.unitframes[c], "pheight")
        CreateConfig(U[c], T["Power Bar Width"], C.unitframes[c], "pwidth")
        CreateConfig(U[c], T["Power Bar X-Offset"], C.unitframes[c], "poffx")
        CreateConfig(U[c], T["Power Bar Y-Offset"], C.unitframes[c], "poffy")
        CreateConfig(U[c], T["Left Text"], C.unitframes[c], "txtpowerleft", "dropdown", pfUI.gui.dropdowns.uf_texts)
        CreateConfig(U[c], T["Left Text X Offset"], C.unitframes[c], "txtpowerleftoffx")
        CreateConfig(U[c], T["Left Text Y Offset"], C.unitframes[c], "txtpowerleftoffy")
        CreateConfig(U[c], T["Center Text"], C.unitframes[c], "txtpowercenter", "dropdown", pfUI.gui.dropdowns.uf_texts)
        CreateConfig(U[c], T["Center Text X Offset"], C.unitframes[c], "txtpowercenteroffx")
        CreateConfig(U[c], T["Center Text Y Offset"], C.unitframes[c], "txtpowercenteroffy")
        CreateConfig(U[c], T["Right Text"], C.unitframes[c], "txtpowerright", "dropdown", pfUI.gui.dropdowns.uf_texts)
        CreateConfig(U[c], T["Right Text X Offset"], C.unitframes[c], "txtpowerrightoffx")
        CreateConfig(U[c], T["Right Text Y Offset"], C.unitframes[c], "txtpowerrightoffy")
        CreateConfig(U[c], T["Power Bar Anchor"], C.unitframes[c], "panchor", "dropdown", pfUI.gui.dropdowns.uf_powerbar_position)

        CreateConfig(U[c], T["Combat Text"], nil, nil, "header")
        CreateConfig(U[c], T["Show Combat Text"], C.unitframes[c], "hitindicator", "checkbox")
        CreateConfig(U[c], T["Combat Text Font"], C.unitframes[c], "hitindicatorfont", "dropdown", pfUI.gui.dropdowns.fonts)
        CreateConfig(U[c], T["Combat Text Size"], C.unitframes[c], "hitindicatorsize")

        CreateConfig(U[c], T["Text Colors"], nil, nil, "header")
        CreateConfig(U[c], T["Automatic Health Text Color"], C.unitframes[c], "healthcolor", "checkbox")
        CreateConfig(U[c], T["Automatic Power Text Color"], C.unitframes[c], "powercolor", "checkbox")
        CreateConfig(U[c], T["Automatic Level Text Color"], C.unitframes[c], "levelcolor", "checkbox")
        CreateConfig(U[c], T["Automatic Class Text Color"], C.unitframes[c], "classcolor", "checkbox")

        CreateConfig(U[c], T["Timer"], nil, nil, "header")
        CreateConfig(U[c], T["Show Timer Text"], C.unitframes[c], "cooldown_text", "checkbox")
        CreateConfig(U[c], T["Show Timer Animation"], C.unitframes[c], "cooldown_anim", "checkbox")

        CreateConfig(U[c], T["Buffs"], nil, nil, "header")
        CreateConfig(U[c], T["Buff Position"], C.unitframes[c], "buffs", "dropdown", pfUI.gui.dropdowns.uf_buff_position)
        CreateConfig(U[c], T["Buff Size"], C.unitframes[c], "buffsize")
        CreateConfig(U[c], T["Buff Limit"], C.unitframes[c], "bufflimit")
        CreateConfig(U[c], T["Buffs Per Row"], C.unitframes[c], "buffperrow")

        CreateConfig(U[c], T["Debuffs"], nil, nil, "header")
        CreateConfig(U[c], T["Debuff Position"], C.unitframes[c], "debuffs", "dropdown", pfUI.gui.dropdowns.uf_buff_position)
        CreateConfig(U[c], T["Debuff Size"], C.unitframes[c], "debuffsize")
        CreateConfig(U[c], T["Debuff Limit"], C.unitframes[c], "debufflimit")
        CreateConfig(U[c], T["Debuffs Per Row"], C.unitframes[c], "debuffperrow")

        if c ~= "player" then
          CreateConfig(U[c], T["Only Show Own Debuffs (|cffffaaaaExperimental|r)"], C.unitframes[c], "selfdebuff", "checkbox")
        end

        CreateConfig(U[c], T["Combat/Aggro Indicators"], nil, nil, "header")
        CreateConfig(U[c], T["Display Aggro Indicator"], C.unitframes[c], "squareaggro", "checkbox")
        CreateConfig(U[c], T["Display Combat Indicator"], C.unitframes[c], "squarecombat", "checkbox")
        CreateConfig(U[c], T["Indicator Position"], C.unitframes[c], "squarepos", "dropdown", pfUI.gui.dropdowns.positions)
        CreateConfig(U[c], T["Indicator Size"], C.unitframes[c], "squaresize")

        CreateConfig(U[c], T["Buff/Debuff Indicators"], nil, nil, "header")
        CreateConfig(U[c], T["Enable Indicators"], C.unitframes[c], "buff_indicator", "checkbox")
        CreateConfig(U[c], T["Show Time Left"], C.unitframes[c], "indicator_time", "checkbox")
        CreateConfig(U[c], T["Show Stacks"], C.unitframes[c], "indicator_stacks", "checkbox")
        CreateConfig(U[c], T["Indicator Size"], C.unitframes[c], "indicator_size")
        CreateConfig(U[c], T["Indicator Spacing"], C.unitframes[c], "indicator_spacing", "dropdown", pfUI.gui.dropdowns.spacing)
        CreateConfig(U[c], T["Indicator Position"], C.unitframes[c], "indicator_pos", "dropdown", pfUI.gui.dropdowns.positions)
        CreateConfig(U[c], T["Show Custom Indicators"], C.unitframes[c], "custom_indicator", "list")
        CreateConfig(U[c], T["Show Buff Indicators"], C.unitframes[c], "show_buffs", "checkbox")
        CreateConfig(U[c], T["Show Hots Indicators"], C.unitframes[c], "show_hots", "checkbox")
        CreateConfig(U[c], T["Show Hots of all Classes"], C.unitframes[c], "all_hots", "checkbox")
        CreateConfig(U[c], T["Show Procs Indicators"], C.unitframes[c], "show_procs", "checkbox")
        CreateConfig(U[c], T["Show Procs of all Classes"], C.unitframes[c], "all_procs", "checkbox")
        CreateConfig(U[c], T["Show Totems Indicators"], C.unitframes[c], "show_totems", "checkbox")

        CreateConfig(U[c], T["Dispel Indicators"], nil, nil, "header")
        CreateConfig(U[c], T["Show Dispel Indicators"], C.unitframes[c], "debuff_indicator", "dropdown", pfUI.gui.dropdowns.uf_debuff_indicator)
        CreateConfig(U[c], T["Only Class Dispellable"], C.unitframes[c], "debuff_ind_class", "checkbox")
        CreateConfig(U[c], T["Indicator Position"], C.unitframes[c], "debuff_ind_pos", "dropdown", pfUI.gui.dropdowns.positions)
        CreateConfig(U[c], T["Indicator Size"], C.unitframes[c], "debuff_ind_size", "dropdown", pfUI.gui.dropdowns.uf_debuff_indicator_size)

        CreateConfig(U[c], T["Overwrite Fonts"], nil, nil, "header")
        CreateConfig(U[c], T["Use Custom Font Settings"], C.unitframes[c], "customfont", "checkbox")
        CreateConfig(U[c], T["Custom Font Name"], C.unitframes[c], "customfont_name", "dropdown", pfUI.gui.dropdowns.fonts)
        CreateConfig(U[c], T["Custom Font Size"], C.unitframes[c], "customfont_size")
        CreateConfig(U[c], T["Custom Font Style"], C.unitframes[c], "customfont_style", "dropdown", pfUI.gui.dropdowns.fontstyle)

        CreateConfig(U[c], T["Overwrite Colors"], nil, nil, "header")
        CreateConfig(U[c], T["Inherit Default Colors"], C.unitframes[c], "defcolor", "checkbox")
        CreateConfig(U[c], T["Health Bar Color"], C.unitframes[c], "custom", "dropdown", pfUI.gui.dropdowns.uf_color)
        CreateConfig(U[c], T["Custom Health Bar Color"], C.unitframes[c], "customcolor", "color")
        CreateConfig(U[c], T["Fade To Custom Color"], C.unitframes[c], "customfade", "checkbox")
        CreateConfig(U[c], T["Use Custom Color On Full Health"], C.unitframes[c], "customfullhp", "checkbox")
        CreateConfig(U[c], T["Custom Health Bar Background Color"], C.unitframes[c], "custombgcolor", "color")
        CreateConfig(U[c], T["Use Custom Color Health Bar Background"], C.unitframes[c], "custombg", "checkbox")
        CreateConfig(U[c], T["Custom Power Bar Background Color"], C.unitframes[c], "custompbgcolor", "color")
        CreateConfig(U[c], T["Use Custom Color Power Bar Background"], C.unitframes[c], "custompbg", "checkbox")
        CreateConfig(U[c], T["Mana Color"], C.unitframes[c], "manacolor", "color")
        CreateConfig(U[c], T["Rage Color"], C.unitframes[c], "ragecolor", "color")
        CreateConfig(U[c], T["Energy Color"], C.unitframes[c], "energycolor", "color")
        CreateConfig(U[c], T["Focus Color"], C.unitframes[c], "focuscolor", "color")
      end)
    end

    CreateGUIEntry(T["Bags & Bank"], nil, function()
      CreateConfig(nil, T["Disable Item Quality Color For \"Common\" Items"], C.appearance.bags, "borderlimit", "checkbox")
      CreateConfig(nil, T["Enable Item Quality Color For Equipment Only"], C.appearance.bags, "borderonlygear", "checkbox")
      CreateConfig(nil, T["Highlight Unusable Items"], C.appearance.bags, "unusable", "checkbox")
      CreateConfig(nil, T["Unusable Item Color"], C.appearance.bags, "unusable_color", "color")
      CreateConfig(nil, T["Enable Movable Bags"], C.appearance.bags, "movable", "checkbox")
      CreateConfig(nil, T["Anchor Bags Above Chat"], C.appearance.bags, "abovechat", "checkbox")
      CreateConfig(nil, T["Hide Chat When Bags Are Opened"], C.appearance.bags, "hidechat", "checkbox")
      CreateConfig(nil, T["Bagslots Per Row"], C.appearance.bags, "bagrowlength")
      CreateConfig(nil, T["Bankslots Per Row"], C.appearance.bags, "bankrowlength")
      CreateConfig(nil, T["Enable Full-Text Search"], C.appearance.bags, "fulltext")
      CreateConfig(nil, T["Item Slot Size"], C.appearance.bags, "icon_size")
      CreateConfig(nil, T["Auto Sell Grey Items"], C.global, "autosell", "checkbox")
      CreateConfig(nil, T["Auto Repair Items"], C.global, "autorepair", "checkbox")
    end)

    CreateGUIEntry(T["Loot"], nil, function()
      CreateConfig(nil, T["Enable Auto-Resize Loot Frame"], C.loot, "autoresize", "checkbox")
      CreateConfig(nil, T["Disable Loot Confirmation Dialog (Without Group)"], C.loot, "autopickup", "checkbox")
      CreateConfig(nil, T["Enable Loot Window On MouseCursor"], C.loot, "mousecursor", "checkbox")
      CreateConfig(nil, T["Enable Advanced Master Loot Menu"], C.loot, "advancedloot", "checkbox")
      CreateConfig(nil, T["Random Roll Announcement Rarity"], C.loot, "rollannouncequal", "dropdown", pfUI.gui.dropdowns.loot_rarity)
      CreateConfig(nil, T["Detailed Random Roll Announcement"], C.loot, "rollannounce", "checkbox")
      CreateConfig(nil, T["Use Item Rarity Color For Loot-Roll Timer"], C.loot, "raritytimer", "checkbox")
    end)

    CreateGUIEntry(T["Minimap"], T["Minimap"], function()
      CreateConfig(U["minimap"], T["Minimap Size (|cffffaaaaExperimental|r)"], C.appearance.minimap, "size")
      CreateConfig(U["minimap"], T["Minimap Player Arrow Scale"], C.appearance.minimap, "arrowscale")
      CreateConfig(nil, T["Zone Text On Minimap"], C.appearance.minimap, "zonetext", "dropdown", pfUI.gui.dropdowns.minimap_zone_visibility)
      CreateConfig(nil, T["Coordinates On Minimap"], C.appearance.minimap, "coordstext", "dropdown", pfUI.gui.dropdowns.minimap_cords_visibility)
      CreateConfig(nil, T["Coordinates Location"], C.appearance.minimap, "coordsloc", "dropdown", pfUI.gui.dropdowns.minimap_cords_position)
      CreateConfig(nil, T["Show PvP Icon"], C.unitframes.player, "showPVPMinimap", "checkbox")
      CreateConfig(nil, T["Show Inactive Tracking"], C.appearance.minimap, "tracking_pulse", "checkbox")
      CreateConfig(nil, T["Tracking Icon Size"], C.appearance.minimap, "tracking_size")
      CreateConfig(nil, T["Hide Addon Buttons On Combat"], C.appearance.minimap, "addon_buttons", "checkbox")
    end)

    CreateGUIEntry(T["Minimap"], T["Addon Buttons"], function()
      CreateConfig(nil,               T["Enable Addon Button Frame"], C.abuttons, "enable", "checkbox")
      CreateConfig(U["addonbuttons"], T["Addon Buttons Panel Position"], C.abuttons, "position", "dropdown", pfUI.gui.dropdowns.addonbuttons_position)
      CreateConfig(U["addonbuttons"], T["Show Addon Buttons On Login"], C.abuttons, "showdefault", "checkbox")
      CreateConfig(U["addonbuttons"], T["Number Of Buttons Per Row/Column"], C.abuttons, "rowsize")
      CreateConfig(U["addonbuttons"], T["Button Spacing"], C.abuttons, "spacing")
      CreateConfig(U["addonbuttons"], T["Hide When Entering Combat"], C.abuttons, "hideincombat", "checkbox")
    end)

    CreateGUIEntry(T["Buffs"], T["Buff/Debuff Icons"], function()
      CreateConfig(U["buff"], T["Enable Buff Display"], C.buffs, "buffs", "checkbox")
      CreateConfig(U["buff"], T["Enable Debuff Display"], C.buffs, "debuffs", "checkbox")
      CreateConfig(U["buff"], T["Enable Weapon Buff Display"], C.buffs, "weapons", "checkbox")
      CreateConfig(U["buff"], T["Seperate Weapon Buffs"], C.buffs, "separateweapons", "checkbox")
      CreateConfig(U["buff"], T["Buff Size"], C.buffs, "size")
      CreateConfig(U["buff"], T["Buff Spacing"], C.buffs, "spacing")
      CreateConfig(U["buff"], T["Number Of Weapon Buffs Per Row"], C.buffs, "wepbuffrowsize")
      CreateConfig(U["buff"], T["Number Of Buffs Per Row"], C.buffs, "buffrowsize")
      CreateConfig(U["buff"], T["Number Of Debuffs Per Row"], C.buffs, "debuffrowsize")
      CreateConfig(U["buff"], T["Show Duration Inside Buff"], C.buffs, "textinside", "checkbox")
      CreateConfig(U["buff"], T["Buff Font Size"], C.buffs, "fontsize")
    end)

    CreateGUIEntry(T["Buffs"], T["Totem Icons"], function()
      CreateConfig(U["totems"], T["Totem Direction"], C.totems, "direction", "dropdown", pfUI.gui.dropdowns.orientation)
      CreateConfig(U["totems"], T["Icon Size"], C.totems, "iconsize")
      CreateConfig(U["totems"], T["Spacing"], C.totems, "spacing", "dropdown", pfUI.gui.dropdowns.spacing)
      CreateConfig(U["totems"], T["Show Background"], C.totems, "showbg", "checkbox")
    end)

    CreateGUIEntry(T["Buffs"], T["Player Buff Bar"], function()
      CreateConfig(nil, T["Enable Bar"], C.buffbar.pbuff, "enable", "checkbox")
      CreateConfig(nil, T["Use Unit Fonts"], C.buffbar.pbuff, "use_unitfonts", "checkbox")
      CreateConfig(nil, T["Sort Order"], C.buffbar.pbuff, "sort", "dropdown", pfUI.gui.dropdowns.buffbarsort)
      CreateConfig(nil, T["Background Color"], C.buffbar.pbuff, "color", "color")
      CreateConfig(nil, T["Border Color"], C.buffbar.pbuff, "bordercolor", "color")
      CreateConfig(nil, T["Text Color"], C.buffbar.pbuff, "textcolor", "color")
      CreateConfig(nil, T["Automatic Background Color"], C.buffbar.pbuff, "dtypebg", "checkbox")
      CreateConfig(nil, T["Automatic Border Color"], C.buffbar.pbuff, "dtypeborder", "checkbox")
      CreateConfig(nil, T["Automatic Text Color"], C.buffbar.pbuff, "dtypetext", "checkbox")
      CreateConfig(nil, T["Color Buff Stacks"], C.buffbar.pbuff, "colorstacks", "checkbox")
      CreateConfig(nil, T["Buffbar Width"], C.buffbar.pbuff, "width")
      CreateConfig(nil, T["Buffbar Height"], C.buffbar.pbuff, "height")
      CreateConfig(nil, T["Filter Mode"], C.buffbar.pbuff, "filter", "dropdown", pfUI.gui.dropdowns.buffbarfilter)
      CreateConfig(nil, T["Time Threshold"], C.buffbar.pbuff, "threshold")
      CreateConfig(nil, T["Whitelist"], C.buffbar.pbuff, "whitelist", "list")
      CreateConfig(nil, T["Blacklist"], C.buffbar.pbuff, "blacklist", "list")
    end)

    CreateGUIEntry(T["Buffs"], T["Player Debuff Bar"], function()
      CreateConfig(nil, T["Enable Bar"], C.buffbar.pdebuff, "enable", "checkbox")
      CreateConfig(nil, T["Use Unit Fonts"], C.buffbar.pdebuff, "use_unitfonts", "checkbox")
      CreateConfig(nil, T["Sort Order"], C.buffbar.pdebuff, "sort", "dropdown", pfUI.gui.dropdowns.buffbarsort)
      CreateConfig(nil, T["Background Color"], C.buffbar.pdebuff, "color", "color")
      CreateConfig(nil, T["Border Color"], C.buffbar.pdebuff, "bordercolor", "color")
      CreateConfig(nil, T["Text Color"], C.buffbar.pdebuff, "textcolor", "color")
      CreateConfig(nil, T["Automatic Background Color"], C.buffbar.pdebuff, "dtypebg", "checkbox")
      CreateConfig(nil, T["Automatic Border Color"], C.buffbar.pdebuff, "dtypeborder", "checkbox")
      CreateConfig(nil, T["Automatic Text Color"], C.buffbar.pdebuff, "dtypetext", "checkbox")
      CreateConfig(nil, T["Color Debuff Stacks"], C.buffbar.pdebuff, "colorstacks", "checkbox")
      CreateConfig(nil, T["Buffbar Width"], C.buffbar.pdebuff, "width")
      CreateConfig(nil, T["Buffbar Height"], C.buffbar.pdebuff, "height")
      CreateConfig(nil, T["Filter Mode"], C.buffbar.pdebuff, "filter", "dropdown", pfUI.gui.dropdowns.buffbarfilter)
      CreateConfig(nil, T["Time Threshold"], C.buffbar.pdebuff, "threshold")
      CreateConfig(nil, T["Whitelist"], C.buffbar.pdebuff, "whitelist", "list")
      CreateConfig(nil, T["Blacklist"], C.buffbar.pdebuff, "blacklist", "list")
    end)

    CreateGUIEntry(T["Buffs"], T["Target Debuff Bar"], function()
      CreateConfig(nil, T["Enable Bar"], C.buffbar.tdebuff, "enable", "checkbox")
      CreateConfig(nil, T["Use Unit Fonts"], C.buffbar.tdebuff, "use_unitfonts", "checkbox")
      CreateConfig(nil, T["Sort Order"], C.buffbar.tdebuff, "sort", "dropdown", pfUI.gui.dropdowns.buffbarsort)
      CreateConfig(nil, T["Background Color"], C.buffbar.tdebuff, "color", "color")
      CreateConfig(nil, T["Border Color"], C.buffbar.tdebuff, "bordercolor", "color")
      CreateConfig(nil, T["Text Color"], C.buffbar.tdebuff, "textcolor", "color")
      CreateConfig(nil, T["Automatic Background Color"], C.buffbar.tdebuff, "dtypebg", "checkbox")
      CreateConfig(nil, T["Automatic Border Color"], C.buffbar.tdebuff, "dtypeborder", "checkbox")
      CreateConfig(nil, T["Automatic Text Color"], C.buffbar.tdebuff, "dtypetext", "checkbox")
      CreateConfig(nil, T["Color Debuff Stacks"], C.buffbar.tdebuff, "colorstacks", "checkbox")
      CreateConfig(nil, T["Buffbar Width"], C.buffbar.tdebuff, "width")
      CreateConfig(nil, T["Buffbar Height"], C.buffbar.tdebuff, "height")
      CreateConfig(nil, T["Only Show Own Debuffs (|cffffaaaaExperimental|r)"], C.buffbar.tdebuff, "selfdebuff", "checkbox")
      CreateConfig(nil, T["Filter Mode"], C.buffbar.tdebuff, "filter", "dropdown", pfUI.gui.dropdowns.buffbarfilter)
      CreateConfig(nil, T["Time Threshold"], C.buffbar.tdebuff, "threshold")
      CreateConfig(nil, T["Whitelist"], C.buffbar.tdebuff, "whitelist", "list")
      CreateConfig(nil, T["Blacklist"], C.buffbar.tdebuff, "blacklist", "list")
    end)

    CreateGUIEntry(T["Actionbar"], T["General"], function()
      CreateConfig(U["bars"], T["Trigger Actions On Key Down"], C.bars, "keydown", "checkbox")
      CreateConfig(U["bars"], T["Self Cast: Alt Key"], C.bars, "altself", "checkbox")
      CreateConfig(U["bars"], T["Self Cast: Right Click"], C.bars, "rightself", "checkbox")
      CreateConfig(U["bars"], T["Button Animation"], C.bars, "animation", "dropdown", pfUI.gui.dropdowns.actionbuttonanimations)
      CreateConfig(U["bars"], T["Button Animation Trigger"], C.bars, "animmode", "dropdown", pfUI.gui.dropdowns.animationmode)
      CreateConfig(U["bars"], T["Show Animation On Hidden Bars"], C.bars, "animalways", "checkbox")
      CreateConfig(U["bars"], T["Scan Macros For Spells"], C.bars, "macroscan", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(U["bars"], T["Show Reagent Count"], C.bars, "reagents", "checkbox")
      CreateConfig(U["bars"], T["Highlight Equipped Items"], C.bars, "showequipped", "checkbox")
      CreateConfig(U["bars"], T["Equipped Item Color"], C.bars, "eqcolor", "color")
      CreateConfig(U["bars"], T["Highlight Out Of Range Spells"], C.bars, "glowrange", "checkbox")
      CreateConfig(U["bars"], T["Out Of Range Color"], C.bars, "rangecolor", "color")
      CreateConfig(U["bars"], T["Highlight Out Of Mana Spells"], C.bars, "showoom", "checkbox")
      CreateConfig(U["bars"], T["Out Of Mana Color"], C.bars, "oomcolor", "color")
      CreateConfig(U["bars"], T["Highlight Not Usable Spells"], C.bars, "showna", "checkbox")
      CreateConfig(U["bars"], T["Not Usable Color"], C.bars, "nacolor", "color")
      CreateConfig(U["bars"], T["Lock Actionbars"], "UVAR", "LOCK_ACTIONBAR", "checkbox")
      CreateConfig(U["bars"], T["Always Allow Drag Via Shift Key"], C.bars, "shiftdrag", "checkbox")

      CreateConfig(nil, T["Font Options"], nil, nil, "header")
      CreateConfig(U["bars"], T["Font"], C.bars, "font", "dropdown", pfUI.gui.dropdowns.fonts)
      CreateConfig(U["bars"], T["Font Padding"], C.bars, "font_offset")
      CreateConfig(U["bars"], T["Macro Text Size"], C.bars, "macro_size")
      CreateConfig(U["bars"], T["Macro Text Color"], C.bars, "macro_color", "color")
      CreateConfig(U["bars"], T["Item Count Text Size"], C.bars, "count_size")
      CreateConfig(U["bars"], T["Item Count Text Color"], C.bars, "count_color", "color")
      CreateConfig(U["bars"], T["Keybind Text Size"], C.bars, "bind_size")
      CreateConfig(U["bars"], T["Keybind Text Color"], C.bars, "bind_color", "color")
      CreateConfig(nil, T["Cooldown Text Size"], C.bars, "cd_size")

      CreateConfig(nil, T["Auto Paging"], nil, nil, "header")
      CreateConfig(U["bars"], T["Switch Pages On Alt Key Press"], C.bars, "pagemasteralt", "checkbox")
      CreateConfig(U["bars"], T["Switch Pages On Shift Key Press"], C.bars, "pagemastershift", "checkbox")
      CreateConfig(U["bars"], T["Switch Pages On Ctrl Key Press"], C.bars, "pagemasterctrl", "checkbox")
      CreateConfig(U["bars"], T["Switch Pages On Druid Stealth"], C.bars, "druidstealth", "checkbox")
      CreateConfig(nil, T["Range Based Hunter Paging"], C.bars, "hunterbar", "checkbox", nil, nil, nil, nil, "vanilla")
    end)

    CreateGUIEntry(T["Actionbar"], T["Gryphons"], function()
      CreateConfig(U["gryphons"], T["Texture"], C.bars.gryphons, "texture", "dropdown", pfUI.gui.dropdowns.gryphons)
      CreateConfig(U["gryphons"], T["Color"], C.bars.gryphons, "color", "color")
      CreateConfig(U["gryphons"], T["Left Anchor"], C.bars.gryphons, "anchor_left", "dropdown", pfUI.gui.dropdowns.xpanchors)
      CreateConfig(U["gryphons"], T["Right Anchor"], C.bars.gryphons, "anchor_right", "dropdown", pfUI.gui.dropdowns.xpanchors)
      CreateConfig(U["gryphons"], T["Size"], C.bars.gryphons, "size")
      CreateConfig(U["gryphons"], T["Horizontal Offset"], C.bars.gryphons, "offset_h")
      CreateConfig(U["gryphons"], T["Vertical Offset"], C.bars.gryphons, "offset_v")
    end)

    -- Shared Actionbar Settings
    local barnames = {
      -- default
      {1, T["Main Actionbar"]},
      {6, T["Top Actionbar"]},
      {5, T["Left Actionbar"]},
      {3, T["Right Actionbar"]},
      {4, T["Vertical Actionbar"]},

      -- special
      {2, T["Paging Actionbar"]},
      {7, T["Stance Bar 1"]},
      {8, T["Stance Bar 2"]},
      {9, T["Stance Bar 3"]},
      {10, T["Stance Bar 4"]},

      -- class
      {11, T["Shapeshift Bar"]},
      {12, T["Pet Actionbar"]},
    }

    for _, data in pairs(barnames) do
      local id, caption = data[1], data[2]
      local formfactors = function()
        return BarLayoutOptions(tonumber(C.bars["bar"..id].buttons) or id < 11 and NUM_ACTIONBAR_BUTTONS or id > 11 and NUM_SHAPESHIFT_SLOTS or NUM_PET_ACTION_SLOTS)
      end

      CreateGUIEntry(T["Actionbar"], caption, function()
        CreateConfig(U["bars"], T["Enable"], C.bars["bar"..id], "enable", "checkbox")

        if id ~= 11 and id ~= 12 then
          CreateConfig(U["bars"], T["Buttons"], C.bars["bar"..id], "buttons", "dropdown", pfUI.gui.dropdowns.actionbarbuttons)
          if id ~= 1 then
            CreateConfig(U["bars"], T["Pageable"], C.bars["bar"..id], "pageable", "checkbox")
          end
        end

        if id == 12 then
          CreateConfig(U["bars"], T["Auto-Castable Action Indicator"], C.bars, "showcastable", "checkbox")
        end

        CreateConfig(U["bars"], T["Icon Size"], C.bars["bar"..id], "icon_size")
        CreateConfig(U["bars"], T["Spacing"], C.bars["bar"..id], "spacing", "dropdown", pfUI.gui.dropdowns.actionbarbuttons)
        CreateConfig(U["bars"], T["Layout"], C.bars["bar"..id], "formfactor", "dropdown", formfactors)
        CreateConfig(U["bars"], T["Bar Background"], C.bars["bar"..id], "background", "checkbox")
        CreateConfig(U["bars"], T["Show Hotkey Text"], C.bars["bar"..id], "showkeybind", "checkbox")

        if id ~= 11 and id ~= 12 then
          CreateConfig(U["bars"], T["Show Macro Text"], C.bars["bar"..id], "showmacro", "checkbox")
          CreateConfig(U["bars"], T["Show Item Count Text"], C.bars["bar"..id], "showcount", "checkbox")
        end

        if id ~= 11 then
          CreateConfig(U["bars"], T["Show Empty Buttons"], C.bars["bar"..id], "showempty", "checkbox")
        end

        CreateConfig(U["bars"], T["Enable Autohide"], C.bars["bar"..id], "autohide", "checkbox")
        CreateConfig(U["bars"], T["Autohide Timeout"], C.bars["bar"..id], "hide_time")
        CreateConfig(U["bars"], T["Show In Combat"], C.bars["bar"..id], "hide_combat", "checkbox")
      end)
    end

    CreateGUIEntry(T["Panel"], nil, function()
      CreateConfig(nil, T["Use Unit Fonts"], C.panel, "use_unitfonts", "checkbox")
      CreateConfig(nil, T["Left Panel: Left"], C.panel.left, "left", "dropdown", pfUI.gui.dropdowns.panel_values)
      CreateConfig(nil, T["Left Panel: Center"], C.panel.left, "center", "dropdown", pfUI.gui.dropdowns.panel_values)
      CreateConfig(nil, T["Left Panel: Right"], C.panel.left, "right", "dropdown", pfUI.gui.dropdowns.panel_values)
      CreateConfig(nil, T["Right Panel: Left"], C.panel.right, "left", "dropdown", pfUI.gui.dropdowns.panel_values)
      CreateConfig(nil, T["Right Panel: Center"], C.panel.right, "center", "dropdown", pfUI.gui.dropdowns.panel_values)
      CreateConfig(nil, T["Right Panel: Right"], C.panel.right, "right", "dropdown", pfUI.gui.dropdowns.panel_values)
      CreateConfig(U["panel"], T["Left Panel: Width (0 = as the chat)"], C.panel.left, "pwidth")
      CreateConfig(U["panel"], T["Left Panel: Height (0 = as before)"], C.panel.left, "pheight")
      CreateConfig(U["panel"], T["Right Panel: Width (0 = as the chat)"], C.panel.right, "pwidth")
      CreateConfig(U["panel"], T["Right Panel: Height (0 = as before)"], C.panel.right, "pheight")
      CreateConfig(nil, T["Other Panel: Minimap"], C.panel.other, "minimap", "dropdown", pfUI.gui.dropdowns.panel_values)
      CreateConfig(nil, T["Only Count Bagspace On Regular Bags"], C.panel.bag, "ignorespecial", "checkbox")
      CreateConfig(nil, T["Enable Micro Bar"], C.panel.micro, "enable", "checkbox")
      CreateConfig(nil, T["Enable 24h Clock"], C.global, "twentyfour", "checkbox")
      CreateConfig(nil, T["Enable Seconds"], C.panel, "seconds", "checkbox")
      CreateConfig(nil, T["Servertime"], C.global, "servertime", "checkbox")
      CreateConfig(U["panel"], T["Show FPS and Latency Colors"], C.panel, "fpscolors", "checkbox")

      CreateConfig(nil, T["Auto Hide"], nil, nil, "header")
      CreateConfig(nil, T["Enable Autohide For Left Chat Panel"], C.panel, "hide_leftchat", "checkbox")
      CreateConfig(nil, T["Enable Autohide For Right Chat Panel"], C.panel, "hide_rightchat", "checkbox")
      CreateConfig(nil, T["Enable Autohide For Minimap Panel"], C.panel, "hide_minimap", "checkbox")
      CreateConfig(nil, T["Enable Autohide For Microbar Panel"], C.panel, "hide_microbar", "checkbox")
    end)

    CreateGUIEntry(T["XP Bar"], T["Experience Bar"], function()
      CreateConfig(U["xpbar"], T["Always Show"], C.panel.xp, "xp_always", "checkbox")
      CreateConfig(U["xpbar"], T["Display Mode"], C.panel.xp, "xp_display", "dropdown", pfUI.gui.dropdowns.xp_display)
      CreateConfig(U["xpbar"], T["Hide Timeout"], C.panel.xp, "xp_timeout")
      CreateConfig(U["xpbar"], T["Width"], C.panel.xp, "xp_width")
      CreateConfig(U["xpbar"], T["Height"], C.panel.xp, "xp_height")
      CreateConfig(U["xpbar"], T["Orientation"], C.panel.xp, "xp_mode", "dropdown", pfUI.gui.dropdowns.orientation)
      CreateConfig(U["xpbar"], T["Frame Anchor"], C.panel.xp, "xp_anchor", "dropdown", pfUI.gui.dropdowns.xpanchors)
      CreateConfig(U["xpbar"], T["Aligned Position"], C.panel.xp, "xp_position", "dropdown", pfUI.gui.dropdowns.xp_position)
      CreateConfig(U["xpbar"], T["Don't overlap rested"], C.panel.xp, "dont_overlap", "checkbox")

      CreateConfig(nil, T["Text"], nil, nil, "header")
      CreateConfig(U["xpbar"], T["Show Text"], C.panel.xp, "xp_text", "checkbox")
      CreateConfig(U["xpbar"], T["Vertical Text Offset"], C.panel.xp, "xp_text_off_y")
      CreateConfig(U["xpbar"], T["Only Show On Mouse Over"], C.panel.xp, "xp_text_mouse", "checkbox")

      CreateConfig(nil, T["Colors"], nil, nil, "header")
      CreateConfig(U["xpbar"], T["Experience Color"], C.panel.xp, "xp_color", "color")
      CreateConfig(U["xpbar"], T["Rested Color"], C.panel.xp, "rest_color", "color")
      CreateConfig(U["xpbar"], T["Bar Texture"], C.panel.xp, "texture", "dropdown", pfUI.gui.dropdowns.uf_bartexture)
    end)

    CreateGUIEntry(T["XP Bar"], T["Reputation Bar"], function()
      CreateConfig(U["xpbar"], T["Always Show"], C.panel.xp, "rep_always", "checkbox")
      CreateConfig(U["xpbar"], T["Display Mode"], C.panel.xp, "rep_display", "dropdown", pfUI.gui.dropdowns.xp_display)
      CreateConfig(U["xpbar"], T["Hide Timeout"], C.panel.xp, "rep_timeout")
      CreateConfig(U["xpbar"], T["Width"], C.panel.xp, "rep_width")
      CreateConfig(U["xpbar"], T["Height"], C.panel.xp, "rep_height")
      CreateConfig(U["xpbar"], T["Orientation"], C.panel.xp, "rep_mode", "dropdown", pfUI.gui.dropdowns.orientation)
      CreateConfig(U["xpbar"], T["Frame Anchor"], C.panel.xp, "rep_anchor", "dropdown", pfUI.gui.dropdowns.xpanchors)
      CreateConfig(U["xpbar"], T["Aligned Position"], C.panel.xp, "rep_position", "dropdown", pfUI.gui.dropdowns.xp_position)

      CreateConfig(nil, T["Text"], nil, nil, "header")
      CreateConfig(U["xpbar"], T["Show Text"], C.panel.xp, "rep_text", "checkbox")
      CreateConfig(U["xpbar"], T["Vertical Text Offset"], C.panel.xp, "rep_text_off_y")
      CreateConfig(U["xpbar"], T["Only Show On Mouse Over"], C.panel.xp, "rep_text_mouse", "checkbox")
    end)

    CreateGUIEntry(T["Tooltip"], nil, function()
      -- octo (26 Oct 2026, user: a friend "can't find his tooltip anchor - it should be
      -- there always and easily found in the search"): its own group first, the word
      -- "anchor" in the name, and a button straight into layout mode at the anchor
      CreateConfig(nil, T["Tooltip Anchor"], nil, nil, "header")
      CreateConfig(nil, T["Tooltip Anchor (Where Tooltips Show)"], C.tooltip, "position", "dropdown", pfUI.gui.dropdowns.tooltip_position)
      CreateConfig(nil, T["Move Anchor"], C.tooltip, "position", "button", function()
        -- moving the anchor box only counts while the place is "Custom"
        C.tooltip.position = "free"
        if pfUI.gui then pfUI.gui:Hide() end
        if pfUI.unlock then pfUI.unlock:Show() end
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: " .. T["drag the |cff33ccffTooltip Anchor|r box to where tooltips should show, then click Done."])
      end)
      CreateConfig(nil, T["Text And Details"], nil, nil, "header")
      CreateConfig(nil, T["Tooltip Text Font"], C.tooltip, "font_tooltip", "dropdown", pfUI.gui.dropdowns.fonts)
      CreateConfig(nil, T["Tooltip Text Font Size"], C.tooltip, "font_tooltip_size")
      CreateConfig(nil, T["Cursor Tooltip Align"], C.tooltip, "cursoralign", "dropdown", pfUI.gui.dropdowns.tooltip_align)
      CreateConfig(nil, T["Cursor Tooltip Offset"], C.tooltip, "cursoroffset")
      CreateConfig(nil, T["Enable Extended Guild Information"], C.tooltip, "extguild", "checkbox")
      CreateConfig(nil, T["Always Show Health In Percent"], C.tooltip, "alwaysperc", "checkbox")
      CreateConfig(nil, T["Show Item IDs"], C.tooltip, "itemid", "checkbox")
      CreateConfig(nil, T["Show Who Cast A Buff Or Debuff (ClassicAPI)"], C.tooltip, "auracaster", "checkbox")
      CreateConfig(nil, T["Custom Transparency"], C.tooltip, "alpha")
      CreateConfig(nil, T["Status Bar Texture"], C.tooltip.statusbar, "texture", "dropdown", pfUI.gui.dropdowns.uf_bartexture)
      CreateConfig(nil, T["Compare Item Base Stats"], C.tooltip.compare, "basestats", "checkbox")
      CreateConfig(nil, T["Always Show Item Comparison"], C.tooltip.compare, "showalways", "checkbox")
      CreateConfig(nil, T["Always Show Extended Vendor Values"], C.tooltip.vendor, "showalways", "checkbox")
      CreateConfig(nil, T["Show How Many You Have (Bags, Bank, Worn)"], C.tooltip, "itemcount", "checkbox")
      CreateConfig(U["questitem"], T["Show Related Quest On Questitems"], C.tooltip.questitem, "showquest", "checkbox")
      CreateConfig(U["questitem"], T["Show Required Questitem Count"], C.tooltip.questitem, "showcount", "checkbox")
    end)

    CreateGUIEntry(T["Castbar"], nil, function()
      CreateConfig(nil, T["Use Unit Fonts"], C.castbar, "use_unitfonts", "checkbox")
      CreateConfig(nil, T["Casting Color"], C.appearance.castbar, "castbarcolor", "color")
      CreateConfig(nil, T["Channeling Color"], C.appearance.castbar, "channelcolor", "color")
      CreateConfig(nil, T["Castbar Texture"], C.appearance.castbar, "texture", "dropdown", pfUI.gui.dropdowns.uf_bartexture)
      CreateConfig(nil, T["Disable Blizzard Castbar"], C.castbar.player, "hide_blizz", "checkbox")

      CreateConfig(nil, T["Player Castbar"], nil, nil, "header")
      CreateConfig(nil, T["Disable Player Castbar"], C.castbar.player, "hide_pfui", "checkbox")
      CreateConfig(nil, T["Castbar Width"], C.castbar.player, "width")
      CreateConfig(nil, T["Castbar Height"], C.castbar.player, "height")
      CreateConfig(nil, T["Show Spell Icon"], C.castbar.player, "showicon", "checkbox")
      CreateConfig(nil, T["Show Spell Name"], C.castbar.player, "showname", "checkbox")
      CreateConfig(nil, T["Show Timer"], C.castbar.player, "showtimer", "checkbox")
      CreateConfig(nil, T["Left Text X Offset"], C.castbar.player, "txtleftoffx")
      CreateConfig(nil, T["Left Text Y Offset"], C.castbar.player, "txtleftoffy")
      CreateConfig(nil, T["Show Lag"], C.castbar.player, "showlag", "checkbox")
      CreateConfig(nil, T["Show Rank"], C.castbar.player, "showrank", "checkbox")
      CreateConfig(nil, T["Right Text X Offset"], C.castbar.player, "txtrightoffx")
      CreateConfig(nil, T["Right Text Y Offset"], C.castbar.player, "txtrightoffy")

      CreateConfig(nil, T["Target Castbar"], nil, nil, "header")
      CreateConfig(nil, T["Disable Target Castbar"], C.castbar.target, "hide_pfui", "checkbox")
      CreateConfig(nil, T["Castbar Width"], C.castbar.target, "width")
      CreateConfig(nil, T["Castbar Height"], C.castbar.target, "height")
      CreateConfig(nil, T["Show Spell Icon"], C.castbar.target, "showicon", "checkbox")
      CreateConfig(nil, T["Show Spell Name"], C.castbar.target, "showname", "checkbox")
      CreateConfig(nil, T["Show Timer"], C.castbar.target, "showtimer", "checkbox")
      CreateConfig(nil, T["Left Text X Offset"], C.castbar.target, "txtleftoffx")
      CreateConfig(nil, T["Left Text Y Offset"], C.castbar.target, "txtleftoffy")
      CreateConfig(nil, T["Show Lag"], C.castbar.target, "showlag", "checkbox")
      CreateConfig(nil, T["Show Rank"], C.castbar.target, "showrank", "checkbox")
      CreateConfig(nil, T["Right Text X Offset"], C.castbar.target, "txtrightoffx")
      CreateConfig(nil, T["Right Text Y Offset"], C.castbar.target, "txtrightoffy")

      CreateConfig(nil, T["Focus Castbar"], nil, nil, "header")
      CreateConfig(nil, T["Disable Focus Castbar"], C.castbar.focus, "hide_pfui", "checkbox")
      CreateConfig(nil, T["Castbar Width"], C.castbar.focus, "width")
      CreateConfig(nil, T["Castbar Height"], C.castbar.focus, "height")
      CreateConfig(nil, T["Show Spell Icon"], C.castbar.focus, "showicon", "checkbox")
      CreateConfig(nil, T["Show Spell Name"], C.castbar.focus, "showname", "checkbox")
      CreateConfig(nil, T["Show Timer"], C.castbar.focus, "showtimer", "checkbox")
      CreateConfig(nil, T["Left Text X Offset"], C.castbar.focus, "txtleftoffx")
      CreateConfig(nil, T["Left Text Y Offset"], C.castbar.focus, "txtleftoffy")
      CreateConfig(nil, T["Show Lag"], C.castbar.focus, "showlag", "checkbox")
      CreateConfig(nil, T["Show Rank"], C.castbar.focus, "showrank", "checkbox")
      CreateConfig(nil, T["Right Text X Offset"], C.castbar.focus, "txtrightoffx")
      CreateConfig(nil, T["Right Text Y Offset"], C.castbar.focus, "txtrightoffy")
    end)

    CreateGUIEntry(T["Chat"], nil, function()
      CreateConfig(nil, T["Enable \"Loot & Spam\" Chat Window"], C.chat.right, "enable", "checkbox")
      CreateConfig(nil, T["Inputbox Width"], C.chat.text, "input_width")
      CreateConfig(nil, T["Inputbox Height"], C.chat.text, "input_height")
      CreateConfig(nil, T["Enable Text Shadow"], C.chat.text, "outline", "checkbox")
      CreateConfig(nil, T["Enable Chat History"], C.chat.text, "history", "checkbox")
      CreateConfig(nil, T["Show Items On Mouseover"], C.chat.text, "mouseover", "checkbox")
      CreateConfig(nil, T["Chat Default Brackets"], C.chat.text, "bracket", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Enable Timestamps"], C.chat.text, "time", "checkbox")
      CreateConfig(nil, T["Timestamp Format"], C.chat.text, "timeformat", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Timestamp Brackets"], C.chat.text, "timebracket", nil, nil, nil, nil, "STRING")
      CreateConfig(nil, T["Timestamp Color"], C.chat.text, "timecolor", "color")
      CreateConfig(nil, T["Hide Channel Names"], C.chat.text, "channelnumonly", "checkbox")
      CreateConfig(nil, T["Generate Playerlinks"], C.chat.text, "playerlinks", "checkbox")
      CreateConfig(nil, T["Enable URL Detection"], C.chat.text, "detecturl", "checkbox")
      CreateConfig(nil, T["Enable Class Colors"], C.chat.text, "classcolor", "checkbox")
      CreateConfig(nil, T["Who Search Unknown Classes (|cffffaaaaExperimental|r)"], C.chat.text, "whosearchunknown", "checkbox")
      CreateConfig(nil, T["Colorize Unknown Classes"], C.chat.text, "tintunknown", "checkbox")
      CreateConfig(nil, T["Unknown Class Color"], C.chat.text, "unknowncolor", "color")
      CreateConfig(nil, T["Left Chat Width"], C.chat.left, "width")
      CreateConfig(nil, T["Left Chat Height"], C.chat.left, "height")
      CreateConfig(nil, T["Right Chat Width"], C.chat.right, "width")
      CreateConfig(nil, T["Right Chat Height"], C.chat.right, "height")
      CreateConfig(nil, T["Hide Combat Log"], C.chat.global, "combathide", "checkbox")
      CreateConfig(nil, T["Enable Chat Dock Background"], C.chat.global, "tabdock", "checkbox")
      CreateConfig(nil, T["Only Show Chat Dock On Mouseover"], C.chat.global, "tabmouse", "checkbox")
      CreateConfig(nil, T["Enable Chat Tab Flashing"], C.chat.global, "chatflash", "checkbox")
      CreateConfig(nil, T["Enable Frame Shadow"], C.chat.global, "frameshadow", "checkbox")
      CreateConfig(nil, T["Enable Custom Colors"], C.chat.global, "custombg", "checkbox")
      CreateConfig(nil, T["Chat Background Color"], C.chat.global, "background", "color")
      CreateConfig(nil, T["Chat Border Color"], C.chat.global, "border", "color")
      CreateConfig(nil, T["Enable Custom Incoming Whispers Layout"], C.chat.global, "whispermod", "checkbox")
      CreateConfig(nil, T["Incoming Whispers Color"], C.chat.global, "whisper", "color")
      CreateConfig(nil, T["Enable Sticky Chat"], C.chat.global, "sticky", "checkbox")
      CreateConfig(nil, T["Maximum Number Of Chat Lines"], C.chat.global, "maxlines")
      CreateConfig(nil, T["Enable Chat Fade"], C.chat.global, "fadeout", "checkbox")
      CreateConfig(nil, T["Seconds Before Chat Fade"], C.chat.global, "fadetime")
      CreateConfig(nil, T["Mousewheel Scroll Speed"], C.chat.global, "scrollspeed")
      CreateConfig(nil, T["Enable Chat Bubbles"], "CVAR", "chatBubbles", "checkbox")
      CreateConfig(nil, T["Enable Party Chat Bubbles"], "CVAR", "chatBubblesParty", "checkbox")
      CreateConfig(nil, T["Enable Chat Bubble Borders"], C.chat.bubbles, "borders", "checkbox")
      CreateConfig(nil, T["Chat Bubble Transparency"], C.chat.bubbles, "alpha")
    end)

    CreateGUIEntry(T["Nameplates"], nil, function()
      CreateConfig(U["nameplates"], T["Show On Hostile Units"], C.nameplates, "showhostile", "checkbox")
      CreateConfig(U["nameplates"], T["Show On Friendly Units"], C.nameplates, "showfriendly", "checkbox")
      CreateConfig(U["nameplates"], T["Vertical Offset (|cffffaaaaExperimental|r)"], C.nameplates, "vertical_offset", nil, nil, nil, nil, nil, "vanilla")
      CreateConfig(U["nameplates"], T["Inactive Nameplate Alpha"], C.nameplates, "notargalpha", "dropdown", pfUI.gui.dropdowns.percent_small)
      CreateConfig(U["nameplates"], T["Draw Glow Around Target Nameplate"], C.nameplates, "targetglow", "checkbox")
      CreateConfig(U["nameplates"], T["Glow Color Around Target Nameplate"], C.nameplates, "glowcolor", "color")
      CreateConfig(U["nameplates"], T["Red Name Text On Infight Units"], C.nameplates, "namefightcolor", "checkbox")
      CreateConfig(U["nameplates"], T["Zoom Target Nameplate"], C.nameplates, "targetzoom", "checkbox")
      CreateConfig(U["nameplates"], T["Target Nameplate Zoom Factor"], C.nameplates, "targetzoomval", "dropdown", pfUI.gui.dropdowns.percent_small)
      CreateConfig(U["nameplates"], T["Nameplate Width"], C.nameplates, "width")
      CreateConfig(U["nameplates"], T["Enable Class Colors On Enemies"], C.nameplates, "enemyclassc", "checkbox")
      CreateConfig(U["nameplates"], T["Enable Class Colors On Friends"], C.nameplates, "friendclassc", "checkbox")
      CreateConfig(U["nameplates"], T["Enable Class Colors On Friends Name"], C.nameplates, "friendclassnamec", "checkbox")
      CreateConfig(U["nameplates"], T["Enable Combo Point Display"], C.nameplates, "cpdisplay", "checkbox")
      CreateConfig(U["nameplates"], T["Enable Clickthrough"], C.nameplates, "clickthrough", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(U["nameplates"], T["Enable Overlap"], C.nameplates, "overlap", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(U["nameplates"], T["Enable Mouselook With Right Click"], C.nameplates, "rightclick", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(U["nameplates"], T["Right Click Auto Attack Threshold"], C.nameplates, "clickthreshold", nil, nil, nil, nil, nil, "vanilla")
      CreateConfig(U["nameplates"], T["Use Unit Fonts"], C.nameplates, "use_unitfonts", "checkbox")
      CreateConfig(U["nameplates"], T["Font Style"], C.nameplates.name, "fontstyle", "dropdown", pfUI.gui.dropdowns.fontstyle)
      CreateConfig(U["nameplates"], T["Replace Totems With Icons"], C.nameplates, "totemicons", "checkbox")
      CreateConfig(U["nameplates"], T["Show Guild Name"], C.nameplates, "showguildname", "checkbox")

      CreateConfig(nil, T["Raid Icon"], nil, nil, "header")
      CreateConfig(U["nameplates"], T["Raid Icon Position"], C.nameplates, "raidiconpos", "dropdown", pfUI.gui.dropdowns.positions)
      CreateConfig(U["nameplates"], T["Raid Icon X-Offset"], C.nameplates, "raidiconoffx")
      CreateConfig(U["nameplates"], T["Raid Icon Y-Offset"], C.nameplates, "raidiconoffy")
      CreateConfig(U["nameplates"], T["Raid Icon Size"], C.nameplates, "raidiconsize")

      CreateConfig(nil, T["Castbar"], nil, nil, "header")
      CreateConfig(U["nameplates"], T["Enable Castbars"], C.nameplates, "showcastbar", "checkbox")
      CreateConfig(U["nameplates"], T["Only Show Target Castbar"], C.nameplates, "targetcastbar", "checkbox")
      CreateConfig(U["nameplates"], T["Enable Spellname"], C.nameplates, "spellname", "checkbox")
      CreateConfig(U["nameplates"], T["Castbar Height"], C.nameplates, "heightcast")

      CreateConfig(nil, T["Debuffs"], nil, nil, "header")
      CreateConfig(U["nameplates"], T["Enable Debuffs"], C.nameplates, "showdebuffs", "checkbox")
      CreateConfig(U["nameplates"], T["Debuff Position"], C.nameplates.debuffs, "position", "dropdown", pfUI.gui.dropdowns.debuffposition)
      CreateConfig(U["nameplates"], T["Debuff Icon Offset"], C.nameplates, "debuffoffset")
      CreateConfig(U["nameplates"], T["Debuff Icon Size"], C.nameplates, "debuffsize")
      CreateConfig(U["nameplates"], T["Estimate Debuffs"], C.nameplates, "guessdebuffs", "checkbox")
      CreateConfig(U["nameplates"], T["Show Debuff Stacks"], C.nameplates.debuffs, "showstacks", "checkbox")
      CreateConfig(U["nameplates"], T["Only Show Own Debuffs (|cffffaaaaExperimental|r)"], C.nameplates, "selfdebuff", "checkbox")
      CreateConfig(U["nameplates"], T["Filter Mode"], C.nameplates.debuffs, "filter", "dropdown", pfUI.gui.dropdowns.buffbarfilter)
      CreateConfig(U["nameplates"], T["Blacklist"], C.nameplates.debuffs, "blacklist", "list")
      CreateConfig(U["nameplates"], T["Whitelist"], C.nameplates.debuffs, "whitelist", "list")

      CreateConfig(nil, T["Outlines"], nil, nil, "header")
      CreateConfig(U["nameplates"], T["Blue Border On Friendly Players"], C.nameplates, "outfriendly", "checkbox")
      CreateConfig(U["nameplates"], T["Green Border On Friendly NPCs"], C.nameplates, "outfriendlynpc", "checkbox")
      CreateConfig(U["nameplates"], T["Yellow Border On Neutral Units"], C.nameplates, "outneutral", "checkbox")
      CreateConfig(U["nameplates"], T["Red Border On Enemy Units"], C.nameplates, "outenemy", "checkbox")
      CreateConfig(U["nameplates"], T["Border Around Target Unit"], C.nameplates, "targethighlight", "checkbox")
      CreateConfig(U["nameplates"], T["Border Color Around Target Unit"], C.nameplates, "highlightcolor", "color")

      CreateConfig(nil, T["Healthbar"], nil, nil, "header")
      CreateConfig(U["nameplates"], T["Healthbar Vertical Offset"], C.nameplates.health, "offset")
      CreateConfig(U["nameplates"], T["Healthbar Height"], C.nameplates, "heighthealth")
      CreateConfig(U["nameplates"], T["Healthbar Texture"], C.nameplates, "healthtexture", "dropdown", pfUI.gui.dropdowns.uf_bartexture)
      CreateConfig(U["nameplates"], T["Show Health Points"], C.nameplates, "showhp", "checkbox")
      CreateConfig(U["nameplates"], T["Health Text Position"], C.nameplates, "hptextpos", "dropdown", pfUI.gui.dropdowns.textalign)
      CreateConfig(U["nameplates"], T["Health Text Format"], C.nameplates, "hptextformat", "dropdown", pfUI.gui.dropdowns.hpformat)
      CreateConfig(U["nameplates"], T["Hide Healthbar On Enemy NPCs"], C.nameplates, "enemynpc", "checkbox")
      CreateConfig(U["nameplates"], T["Hide Healthbar On Enemy Players"], C.nameplates, "enemyplayer", "checkbox")
      CreateConfig(U["nameplates"], T["Hide Healthbar On Neutral NPCs"], C.nameplates, "neutralnpc", "checkbox")
      CreateConfig(U["nameplates"], T["Hide Healthbar On Friendly NPCs"], C.nameplates, "friendlynpc", "checkbox")
      CreateConfig(U["nameplates"], T["Hide Healthbar On Friendly Players"], C.nameplates, "friendlyplayer", "checkbox")
      CreateConfig(U["nameplates"], T["Hide Healthbar On Critters"], C.nameplates, "critters", "checkbox")
      CreateConfig(U["nameplates"], T["Hide Healthbar On Totems"], C.nameplates, "totems", "checkbox")
      CreateConfig(U["nameplates"], T["Always Show On Units With Missing HP"], C.nameplates, "fullhealth", "checkbox")
      CreateConfig(U["nameplates"], T["Always Show On Target Units"], C.nameplates, "target", "checkbox")
      CreateConfig(U["nameplates"], T["Vertical Healthbar"], C.nameplates, "verticalhealth", "checkbox")

      CreateConfig(nil, T["SuperWoW Settings"], nil, nil, "header")
      CreateConfig(U["nameplates"], T["Overwrite Border Color With Combat State"], C.nameplates, "outcombatstate", "checkbox")
      CreateConfig(U["nameplates"], T["Overwrite Health Color With Combat State"], C.nameplates, "barcombatstate", "checkbox")
      CreateConfig(U["nameplates"], T["Overwrite If Unit Is Attacking You"], C.nameplates, "ccombatthreat", "checkbox")
      CreateConfig(U["nameplates"], T["Overwrite If Unit Is Attacking Off-Tank"], C.nameplates, "ccombatofftank", "checkbox")
      CreateConfig(U["nameplates"], T["Overwrite If Unit Is Attacking Others"], C.nameplates, "ccombatnothreat", "checkbox")
      CreateConfig(U["nameplates"], T["Overwrite If Unit Is Attacking No One"], C.nameplates, "ccombatstun", "checkbox")
      CreateConfig(U["nameplates"], T["Overwrite If Unit Is Casting"], C.nameplates, "ccombatcasting", "checkbox")
      CreateConfig(U["nameplates"], T["Unit Is Attacking You Color"], C.nameplates, "combatthreat", "color")
      CreateConfig(U["nameplates"], T["Unit Is Attacking Off-Tank Color"], C.nameplates, "combatofftank", "color")
      CreateConfig(U["nameplates"], T["Unit Is Attacking Others Color"], C.nameplates, "combatnothreat", "color")
      CreateConfig(U["nameplates"], T["Unit Is Attacking No One Color"], C.nameplates, "combatstun", "color")
      CreateConfig(U["nameplates"], T["Unit Is Casting Color"], C.nameplates, "combatcasting", "color")
      CreateConfig(U["nameplates"], T["Off-Tank Names"], C.nameplates, "combatofftanks", "list")
    end)

    -- octo: built-in damage / healing / threat meters (modules/meters*.lua)
    CreateGUIEntry(T["Meters"], T["General"], function()
      CreateConfig(nil, T["Meters"], nil, nil, "header")
      CreateConfig(nil, T["Enable Meters (damage, healing, interrupts, deaths, casts...)"], C.meters, "enable", "checkbox")
      CreateConfig(nil, T["Number Of Windows"], C.meters, "windows", "dropdown", { "1:1", "2:2" })
      CreateConfig(nil, T["Dock Meter Into Right Chat"], C.thirdparty.pfmeter, "dock", "checkbox")
      CreateConfig(nil, T["Dock Second Window Into Right Chat"], C.thirdparty.pfthreat, "dock", "checkbox")
      CreateConfig(nil, T["Show Meters Instead Of Chat At Login"], C.thirdparty, "showmeter", "checkbox")
      CreateConfig(nil, T["Ask To Reset When Entering An Instance"], C.meters, "resetask", "checkbox")
      CreateConfig(nil, T["Window 1 Shows"], C.meters, "mode1", "dropdown", pfUI.gui.dropdowns.meter_modes)
      CreateConfig(nil, T["Window 2 Shows"], C.meters, "mode2", "dropdown", pfUI.gui.dropdowns.meter_modes)

      CreateConfig(nil, T["Data"], nil, nil, "header")
      CreateConfig(nil, T["Merge Pets Into Their Owner"], C.meters, "mergepets", "checkbox")
      CreateConfig(nil, T["Track Everyone Nearby (Battlegrounds)"], C.meters, "trackall", "checkbox")
      CreateConfig(nil, T["Fights Kept"], C.meters, "history", "dropdown", { "5:5", "10:10", "20:20", "30:30" })

      CreateConfig(nil, T["Look"], nil, nil, "header")
      CreateConfig(nil, T["Class Colored Bars"], C.meters, "classcolor", "checkbox")
      CreateConfig(nil, T["Bar Texture"], C.meters, "texture", "dropdown", pfUI.gui.dropdowns.uf_bartexture)
      CreateConfig(nil, T["Bar Height"], C.meters, "barheight", "text", nil, nil, nil, "number")
      CreateConfig(nil, T["Background Color"], C.meters, "background", "color")
      CreateConfig(nil, T["Window Width (not docked)"], C.meters, "width", "text", nil, nil, nil, "number")
      CreateConfig(nil, T["Window Height (not docked)"], C.meters, "height", "text", nil, nil, nil, "number")
    end)

    CreateGUIEntry(T["Meters"], T["Threat"], function()
      CreateConfig(nil, T["Threat"], nil, nil, "header")
      CreateConfig(nil, T["Enable Threat Meter (asks the server, as TWThreat)"], C.meters, "threat", "checkbox")
      CreateConfig(nil, T["Warn Me At % Of The Pull Point"], C.meters, "threatwarn", "dropdown", { "70:70%", "80:80%", "90:90%", "95:95%" })
      CreateConfig(nil, T["Warning Sound"], C.meters, "threatsound", "checkbox")
      CreateConfig(nil, T["Warning Text On Screen"], C.meters, "threatflash", "checkbox")
    end)

    -- (29 Oct 2026: the page lists every integration again - hiding rows of
    -- addons not installed caused conflicts for players; HasAddon stays a helper)
    local function Has(a, b, c, d, e, f, g)
      for _, name in ipairs({ a, b, c, d, e, f, g }) do
        local ok, found, _, _, _, _, reason = pcall(GetAddOnInfo, name)
        if ok and found and reason ~= "MISSING" then return true end
      end
      return false
    end
    pfUI.gui.HasAddon = Has

    CreateGUIEntry(T["Thirdparty"], T["Integrations"], function()
      CreateConfig(nil, T["Show Meters By Default"], C.thirdparty, "showmeter", "checkbox")
      CreateConfig(nil, T["Use Chat Colors for Meters"], C.thirdparty, "chatbg", "checkbox")
      CreateConfig(nil, "ShaguDPS (" .. T["Skin"] .. ")", C.thirdparty.shagudps, "skin", "checkbox")
      CreateConfig(nil, "ShaguDPS (" .. T["Dock"] .. ")", C.thirdparty.shagudps, "dock", "checkbox")
      CreateConfig(nil, "DPSMate (" .. T["Skin"] .. ")", C.thirdparty.dpsmate, "skin", "checkbox")
      CreateConfig(nil, "DPSMate (" .. T["Dock"] .. ")", C.thirdparty.dpsmate, "dock", "checkbox")
      CreateConfig(nil, "Recount (" .. T["Skin"] .. ")", C.thirdparty.recount, "skin", "checkbox", nil, nil, nil, nil, "tbc")
      CreateConfig(nil, "Recount (" .. T["Dock"] .. ")", C.thirdparty.recount, "dock", "checkbox", nil, nil, nil, nil, "tbc")
      CreateConfig(nil, "Omen (" .. T["Skin"] .. ")", C.thirdparty.omen, "skin", "checkbox", nil, nil, nil, nil, "tbc")
      CreateConfig(nil, "Omen (" .. T["Dock"] .. ")", C.thirdparty.omen, "dock", "checkbox", nil, nil, nil, nil, "tbc")
      CreateConfig(nil, "SWStats (" .. T["Skin"] .. ")", C.thirdparty.swstats, "skin", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "SWStats (" .. T["Dock"] .. ")", C.thirdparty.swstats, "dock", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "KLH Threat Meter (" .. T["Skin"] .. ")", C.thirdparty.ktm, "skin", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "KLH Threat Meter (" .. T["Dock"] .. ")", C.thirdparty.ktm, "dock", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "TW Threatmeter (" .. T["Skin"] .. ")", C.thirdparty.twt, "skin", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "TW Threatmeter (" .. T["Dock"] .. ")", C.thirdparty.twt, "dock", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "WIM", C.thirdparty.wim, "enable", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "HealComm", C.thirdparty.healcomm, "enable", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "SortBags", C.thirdparty.sortbags, "enable", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "Bag_Sort", C.thirdparty.bag_sort, "enable", "checkbox", nil, nil, nil, nil, "tbc")
      CreateConfig(nil, "MrPlow", C.thirdparty.mrplow, "enable", "checkbox")
      CreateConfig(nil, "BetterCharacterStats", C.thirdparty.bcs, "enable", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "Crafty", C.thirdparty.crafty, "enable", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "CleverMacro", C.thirdparty.clevermacro, "enable", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "AckisRecipeList", C.thirdparty.ackis, "enable", "checkbox", nil, nil, nil, nil, "tbc")
      CreateConfig(nil, "SheepWatch", C.thirdparty.sheepwatch, "enable", "checkbox", nil, nil, nil, nil, "tbc")
      CreateConfig(nil, "TotemTimers", C.thirdparty.totemtimers, "enable", "checkbox", nil, nil, nil, nil, "tbc")
      CreateConfig(nil, "DruidBar", C.thirdparty.druidbar, "enable", "checkbox", nil, nil, nil, nil, "tbc")
      CreateConfig(nil, "BCEPGP", C.thirdparty.bcepgp, "enable", "checkbox", nil, nil, nil, nil, "tbc")
      CreateConfig(nil, "FlightMap", C.thirdparty.flightmap, "enable", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "TheoryCraft", C.thirdparty.theorycraft, "enable", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "SuperMacro", C.thirdparty.supermacro, "enable", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "AtlasLoot", C.thirdparty.atlasloot, "enable", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "MyRolePlay", C.thirdparty.myroleplay, "enable", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "DruidManaBar", C.thirdparty.druidmana, "enable", "checkbox", nil, nil, nil, nil, "vanilla")
      CreateConfig(nil, "NoteIt", C.thirdparty.noteit, "enable", "checkbox", nil, nil, nil, nil, "vanilla")
    end)

    CreateGUIEntry(T["Components"], T["Modules"], function()
      table.sort(pfUI.modules)
      for i,m in pairs(pfUI.modules) do
        if m ~= "gui" then
          -- create disabled entry if not existing and display
          pfUI:UpdateConfig("disabled", nil, m, "0")
          CreateConfig(nil, T["Disable Module"] .. " " .. m, C.disabled, m, "checkbox")
        end
      end
    end)

    CreateGUIEntry(T["Components"], T["Skins"], function()
      table.sort(pfUI.skins)
      for i,m in pairs(pfUI.skins) do
        -- create disabled entry if not existing and display
        pfUI:UpdateConfig("disabled", nil, "skin_" .. m, "0")
        CreateConfig(nil, T["Disable Skin"] .. " " .. m, C.disabled, "skin_" .. m, "checkbox")
      end
    end)
  end
end)
