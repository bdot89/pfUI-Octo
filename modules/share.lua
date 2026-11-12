pfUI:RegisterModule("share", "vanilla:tbc", function ()
  local function serialize(tbl, comp, name, ignored, spacing)
    local spacing = spacing or ""
    local match = nil
    local tname = ( spacing == "" and "" or "[\"" ) .. name .. ( spacing == "" and "" or "\"]" )
    local str = spacing .. tname .. " = {\n"

    for k, v in pairs(tbl) do
      if not ( ignored[k] and spacing == "" ) and ( not comp or not comp[k] or comp[k] ~= tbl[k] ) then
        if type(v) == "table" then
          local result = serialize(tbl[k], comp and comp[k], k, ignored, spacing .. "  ")
          if result then
            match = true
            str = str .. result
          end
        elseif type(v) == "string" then
          match = true
          str = str .. spacing .. "  [\""..k.."\"] = \"".. string.gsub(v, "\\", "\\\\") .."\",\n"
        elseif type(v) == "number" then
          match = true
          str = str .. spacing .. "  [\""..k.."\"] = ".. string.gsub(v, "\\", "\\\\") ..",\n"
        elseif type(v) == "boolean" then
          -- octo: the combat text keeps on / off settings as true / false
          match = true
          str = str .. spacing .. "  [\""..k.."\"] = ".. (v and "true" or "false") ..",\n"
        end
      end
    end

    str = str .. spacing .. "}" .. ( spacing == "" and "" or "," ) .. "\n"
    return match and str or nil
  end

  -- octo: reads the text serialize() writes WITHOUT running it. pfUI used
  -- loadstring() on whatever was pasted, so a shared string could run any
  -- code on the importer's client. Only these lines are accepted:
  --   pfUI_config = {          ["key"] = {          ["key"] = "text",
  --   ["key"] = 12.5,          },  or  }
  -- returns: the table, or nil and a message with the bad line number
  local function parse(text)
    if type(text) ~= "string" or string.len(text) > 2000000 then return nil, "no text" end
    local root, stack, depth, lineno = nil, {}, 0, 0
    local function unescape(s)
      return (string.gsub(s, "\\(.)", "%1"))
    end
    for line in string.gfind(text .. "\n", "([^\n]*)\n") do
      lineno = lineno + 1
      line = string.gsub(line, "^%s+", "")
      line = string.gsub(line, "%s+$", "")
      local _, key, value
      if line == "" then
        -- blank
      elseif not root then
        if line ~= "pfUI_config = {" then return nil, "line " .. lineno .. ": not a pfUI profile" end
        root = {}
        stack[1] = root
        depth = 1
      elseif depth == 0 then
        return nil, "line " .. lineno .. ": text after the end"
      elseif line == "}," or line == "}" then
        stack[depth] = nil
        depth = depth - 1
      else
        _, _, key = string.find(line, '^%["([^"]*)"%] = {$')
        if key then
          if depth >= 12 then return nil, "line " .. lineno .. ": nested too deep" end
          local t = {}
          stack[depth][key] = t
          depth = depth + 1
          stack[depth] = t
        else
          _, _, key, value = string.find(line, '^%["([^"]*)"%] = "(.*)",$')
          if key then
            stack[depth][key] = unescape(value)
          else
            _, _, key, value = string.find(line, '^%["([^"]*)"%] = (%-?[%d%.]+[eE]?[%-%+]?%d*),$')
            if key and tonumber(value) then
              stack[depth][key] = tonumber(value)
            else
              _, _, key, value = string.find(line, '^%["([^"]*)"%] = (%a+),$')
              if key and (value == "true" or value == "false") then
                stack[depth][key] = (value == "true")
              else
                return nil, "line " .. lineno .. ": not a setting"
              end
            end
          end
        end
      end
    end
    if not root then return nil, "empty" end
    if depth ~= 0 then return nil, "unfinished (missing })" end
    return root
  end

  -- counts the values in the imported config that differ from the current one,
  -- per top-level section: { {section, count}, ... } sorted by name
  local function preview(imported, current)
    local function count(a, b)
      local n = 0
      for k, v in pairs(a) do
        if type(v) == "table" then
          n = n + count(v, type(b) == "table" and b[k] or {})
        elseif type(b) ~= "table" or tostring(b[k]) ~= tostring(v) then
          n = n + 1
        end
      end
      return n
    end
    local list = {}
    for section, v in pairs(imported) do
      if type(v) == "table" then
        local n = count(v, current[section])
        if n > 0 then table.insert(list, { section, n }) end
      end
    end
    table.sort(list, function(a, b) return a[1] < b[1] end)
    return list
  end

  -- replaces the config with an imported one; a string exported with
  -- "Ignore Layout" carries no positions / disabled modules, so the
  -- importer keeps their own instead of falling back to the defaults
  local function import(imported)
    local keep = {}
    if not imported.position then keep.position = pfUI_config.position end
    if not imported.disabled then keep.disabled = pfUI_config.disabled end
    if not imported.sct then keep.sct = pfUI_config.sct end
    _G.pfUI_config = imported
    for k, v in pairs(keep) do pfUI_config[k] = v end
    pfUI:LoadConfig()
  end

  -- octo (12 Nov 2026, Wolfahrt on Discord: set up one character, then bring only some
  -- features to the others): pick which sections of an import or a saved profile are applied.

  -- the default config, without touching the real one for good
  -- (the real table goes back afterwards, not a copy - modules keep references to its parts)
  local function defaults()
    local original = pfUI_config
    _G.pfUI_config = {}
    pfUI:LoadConfig()
    local def = CopyTable(pfUI_config)
    _G.pfUI_config = original
    C = original
    pfUI.env.C = original
    return def
  end

  -- a copy of b with a laid over it (what a section looks like after LoadConfig fills defaults)
  local function overlay(a, b)
    local out = {}
    if type(b) == "table" then for k, v in pairs(b) do out[k] = type(v) == "table" and overlay(nil, v) or v end end
    if type(a) == "table" then
      for k, v in pairs(a) do
        if type(v) == "table" then out[k] = overlay(v, out[k]) else out[k] = v end
      end
    end
    return out
  end

  -- values that differ between two tables, both ways
  local function differ(a, b)
    local n = 0
    a = type(a) == "table" and a or {}
    b = type(b) == "table" and b or {}
    for k, v in pairs(a) do
      if type(v) == "table" or type(b[k]) == "table" then n = n + differ(v, b[k])
      elseif tostring(b[k]) ~= tostring(v) then n = n + 1 end
    end
    for k, v in pairs(b) do
      if a[k] == nil then n = n + (type(v) == "table" and differ(nil, v) or 1) end
    end
    return n
  end

  -- sections never offered: kept as they are unless the string carries them
  -- ("Ignore Layout" strings have no positions / disabled modules / combat text);
  -- the UI layouts are this character's screens and are never exported
  local function kept(imported, section)
    if section == "layouts" then return true end
    if (section == "position" or section == "disabled" or section == "sct") and imported[section] == nil then return true end
    return false
  end

  -- every section the import would change, as the result after defaults are filled in:
  -- { {section, count}, ... } sorted by name
  local function sections(imported, current, def)
    def = def or defaults()
    local seen, list = {}, {}
    local function check(section)
      if seen[section] then return end
      seen[section] = true
      if kept(imported, section) then return end
      if imported[section] ~= nil and type(imported[section]) ~= "table" then return end
      local after = overlay(imported[section], def[section])
      local n = differ(after, current[section])
      if n > 0 then table.insert(list, { section, n }) end
    end
    for s in pairs(imported) do check(s) end
    for s in pairs(def) do check(s) end
    table.sort(list, function(a, b) return a[1] < b[1] end)
    return list
  end

  -- applies only the picked sections ({ [section] = true }); the rest stays as it is
  local function importPicked(imported, picked)
    for section in pairs(picked) do
      if not kept(imported, section) then
        pfUI_config[section] = type(imported[section]) == "table" and CopyTable(imported[section]) or {}
      end
    end
    pfUI:LoadConfig()
  end

  -- friendlier names for the sections whose key says little
  local names = {
    position = "Frame positions", disabled = "Modules on / off", sct = "Combat text",
    abuttons = "Addon buttons", buffbar = "Buff bars", castbar = "Cast bars",
    plates = "Nameplates (Octo)", nameplates = "Nameplates", unitframes = "Unit frames",
    bars = "Action bars", tooltip = "Tooltip", questlog = "Quest log",
  }
  local function label(section)
    local n = names[section] or (string.upper(string.sub(section, 1, 1)) .. string.sub(section, 2))
    return T[n] or n
  end

  -- the tick list: every section that would change, all ticked; Apply hands the
  -- ticked ones to onApply (then the UI reloads)
  local pick
  local function Pick(title, imported, onApply)
    local list = sections(imported, pfUI_config)
    if not pick then
      pick = CreateFrame("Frame", "pfSharePick", UIParent)
      pick:SetWidth(360)
      pick:SetHeight(440)
      pick:SetPoint("CENTER", 0, 0)
      pick:SetFrameStrata("FULLSCREEN_DIALOG")
      pick:SetMovable(true)
      pick:EnableMouse(true)
      pick:RegisterForDrag("LeftButton")
      pick:SetScript("OnDragStart", function() this:StartMoving() end)
      pick:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
      CreateBackdrop(pick, nil, true, 0.9)
      CreateBackdropShadow(pick)
      table.insert(UISpecialFrames, "pfSharePick")

      pick.title = pick:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      pick.title:SetFont(pfUI.font_default, C.global.font_size + 2, "OUTLINE")
      pick.title:SetPoint("TOPLEFT", 10, -10)
      pick.title:SetPoint("TOPRIGHT", -10, -10)
      pick.title:SetJustifyH("LEFT")

      pick.info = pick:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      pick.info:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      pick.info:SetPoint("TOPLEFT", pick.title, "BOTTOMLEFT", 0, -6)
      pick.info:SetPoint("TOPRIGHT", pick.title, "BOTTOMRIGHT", 0, -6)
      pick.info:SetJustifyH("LEFT")
      pick.info:SetTextColor(.7, .7, .7)
      pick.info:SetText(T["Only the ticked features are applied; everything else stays as it is on this character."])

      pick.scroll = pfUI.api.CreateScrollFrame("pfSharePickScroll", pick)
      pick.scroll:SetPoint("TOPLEFT", 10, -60)
      pick.scroll:SetPoint("BOTTOMRIGHT", -10, 70)
      pick.scroll.bg = CreateFrame("Frame", nil, pick.scroll)
      pick.scroll.bg:SetFrameLevel(1)
      pick.scroll.bg:SetPoint("TOPLEFT", -5, 5)
      pick.scroll.bg:SetPoint("BOTTOMRIGHT", 5, -5)
      CreateBackdrop(pick.scroll.bg, nil, true)
      pick.list = CreateFrame("Frame", "pfSharePickList", pick.scroll)
      pick.list:SetWidth(330)
      pick.list:SetHeight(10)
      pick.scroll:SetScrollChild(pick.list)
      pick.rows = {}

      local function Button(name, text, width)
        local b = CreateFrame("Button", name, pick)
        SkinButton(b)
        b:SetWidth(width)
        b:SetHeight(22)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        b.text:SetAllPoints(b)
        b.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
        b.text:SetText(text)
        return b
      end
      pick.all = Button("pfSharePickAll", T["All"], 60)
      pick.all:SetPoint("BOTTOMLEFT", 10, 40)
      pick.none = Button("pfSharePickNone", T["None"], 60)
      pick.none:SetPoint("LEFT", pick.all, "RIGHT", 6, 0)
      pick.count = pick:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      pick.count:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      pick.count:SetPoint("LEFT", pick.none, "RIGHT", 10, 0)
      pick.apply = Button("pfSharePickApply", T["Apply"], 90)
      pick.apply:SetPoint("BOTTOMRIGHT", -10, 10)
      pick.cancel = Button("pfSharePickCancel", T["Cancel"], 90)
      pick.cancel:SetPoint("RIGHT", pick.apply, "LEFT", -6, 0)
      pick.cancel:SetScript("OnClick", function() pick:Hide() end)

      function pick.Update()
        local n = 0
        for i = 1, pick.shown do if pick.rows[i].check:GetChecked() then n = n + 1 end end
        pick.count:SetText(n .. " / " .. pick.shown .. " " .. T["ticked"])
        if n > 0 then pick.apply:Enable() pick.apply.text:SetTextColor(.5, 1, .5) else pick.apply:Disable() pick.apply.text:SetTextColor(.5, .5, .5) end
      end
      local function SetAll(on)
        for i = 1, pick.shown do pick.rows[i].check:SetChecked(on) end
        pick.Update()
      end
      pick.all:SetScript("OnClick", function() SetAll(true) end)
      pick.none:SetScript("OnClick", function() SetAll(false) end)
      pick.apply:SetScript("OnClick", function()
        local picked = {}
        for i = 1, pick.shown do
          local r = pick.rows[i]
          if r.check:GetChecked() then picked[r.section] = true end
        end
        pick:Hide()
        if pick.onApply then pick.onApply(picked) end
      end)
    end

    pick.title:SetText(title)
    pick.onApply = onApply
    pick.shown = table.getn(list)
    for i = 1, math.max(pick.shown, table.getn(pick.rows)) do
      local r = pick.rows[i]
      if not r and i <= pick.shown then
        r = CreateFrame("Button", nil, pick.list)
        r:SetHeight(18)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
        r:SetPoint("RIGHT", pick.list, "RIGHT", -12, 0)
        r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
        r.check:SetNormalTexture("")
        r.check:SetPushedTexture("")
        r.check:SetHighlightTexture("")
        CreateBackdrop(r.check, nil, true)
        r.check:SetWidth(14)
        r.check:SetHeight(14)
        r.check:SetPoint("LEFT", 4, 0)
        r.check:SetScript("OnClick", function() pick.Update() end)
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        r.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
        r.text:SetPoint("LEFT", r.check, "RIGHT", 8, 0)
        r.text:SetJustifyH("LEFT")
        r.changes = r:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        r.changes:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
        r.changes:SetPoint("RIGHT", -4, 0)
        r.changes:SetTextColor(.7, .7, .7)
        -- the whole row toggles the tick
        r:SetScript("OnClick", function() this.check:SetChecked(not this.check:GetChecked()) pick.Update() end)
        pick.rows[i] = r
      end
      if r then
        if i <= pick.shown then
          r.section = list[i][1]
          r.text:SetText(label(list[i][1]))
          r.changes:SetText(list[i][2] .. " " .. T["changes"])
          r.check:SetChecked(true)
          r:Show()
        else
          r.section = nil
          r:Hide()
        end
      end
    end
    pick.list:SetHeight(math.max(10, pick.shown * 20))
    pick.scroll:SetVerticalScroll(0)
    pick.Update()
    if pick.shown == 0 then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: " .. T["Nothing differs from your settings."])
      return
    end
    pick:Show()
    pick.scroll:UpdateScrollChildRect()
    pick.scroll:UpdateScrollState()
    return pick
  end

  local function compress(input)
    -- based on Rochet2's lzw compression
    if type(input) ~= "string" then
      return nil
    end
    local len = strlen(input)
    if len <= 1 then
      return "u"..input
    end

    local dict = {}
    for i = 0, 255 do
      local ic, iic = strchar(i), strchar(i, 0)
      dict[ic] = iic
    end
    local a, b = 0, 1

    local result = {"c"}
    local resultlen = 1
    local n = 2
    local word = ""
    for i = 1, len do
      local c = strsub(input, i, i)
      local wc = word..c
      if not dict[wc] then
        local write = dict[word]
        if not write then
          return nil
        end
        result[n] = write
        resultlen = resultlen + strlen(write)
        n = n+1
        if  len <= resultlen then
          return "u"..input
        end
        local str = wc
        if a >= 256 then
          a, b = 0, b+1
          if b >= 256 then
            dict = {}
            b = 1
          end
        end
        dict[str] = strchar(a,b)
        a = a+1
        word = c
      else
        word = wc
      end
    end
    result[n] = dict[word]
    resultlen = resultlen+strlen(result[n])
    n = n+1
    if  len <= resultlen then
      return "u"..input
    end
    return table.concat(result)
  end

  local function decompress(input)
    -- based on Rochet2's lzw compression
    if type(input) ~= "string" or strlen(input) < 1 then
      return nil
    end

    local control = strsub(input, 1, 1)
    if control == "u" then
      return strsub(input, 2)
    elseif control ~= "c" then
      return nil
    end
    input = strsub(input, 2)
    local len = strlen(input)

    if len < 2 then
      return nil
    end

    local dict = {}
    for i = 0, 255 do
      local ic, iic = strchar(i), strchar(i, 0)
      dict[iic] = ic
    end

    local a, b = 0, 1

    local result = {}
    local n = 1
    local last = strsub(input, 1, 2)
    result[n] = dict[last]
    n = n+1
    for i = 3, len, 2 do
      local code = strsub(input, i, i+1)
      local lastStr = dict[last]
      if not lastStr then
        return nil
      end
      local toAdd = dict[code]
      if toAdd then
        result[n] = toAdd
        n = n+1
        local str = lastStr..strsub(toAdd, 1, 1)
        if a >= 256 then
          a, b = 0, b+1
          if b >= 256 then
            dict = {}
            b = 1
          end
        end
        dict[strchar(a,b)] = str
        a = a+1
      else
        local str = lastStr..strsub(lastStr, 1, 1)
        result[n] = str
        n = n+1
        if a >= 256 then
          a, b = 0, b+1
          if b >= 256 then
            dict = {}
            b = 1
          end
        end
        dict[strchar(a,b)] = str
        a = a+1
      end
      last = code
    end
    return table.concat(result)
  end

  local function enc(to_encode)
    local index_table = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local bit_pattern = ''
    local encoded = ''
    local trailing = ''

    for i = 1, string.len(to_encode) do
      local remaining = tonumber(string.byte(string.sub(to_encode, i, i)))
      local bin_bits = ''
      for i = 7, 0, -1 do
        local current_power = math.pow(2, i)
        if remaining >= current_power then
          bin_bits = bin_bits .. '1'
          remaining = remaining - current_power
        else
          bin_bits = bin_bits .. '0'
        end
      end
      bit_pattern = bit_pattern .. bin_bits
    end

    if mod(string.len(bit_pattern), 3) == 2 then
      trailing = '=='
      bit_pattern = bit_pattern .. '0000000000000000'
    elseif mod(string.len(bit_pattern), 3) == 1 then
      trailing = '='
      bit_pattern = bit_pattern .. '00000000'
    end

    local count = 0
    for i = 1, string.len(bit_pattern), 6 do
      local byte = string.sub(bit_pattern, i, i+5)
      local offset = tonumber(tonumber(byte, 2))
      encoded = encoded .. string.sub(index_table, offset+1, offset+1)
      count = count + 1
      if count >= 92 then
        encoded = encoded .. "\n"
        count = 0
      end
    end

    -- octo: a line break right at the end made the padding cut one real
    -- character instead (exports of 92*n characters failed to import)
    encoded = string.gsub(encoded, "\n$", "")
    return string.sub(encoded, 1, -1 - string.len(trailing)) .. trailing
  end

  local function dec(to_decode)
    local index_table = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local padded = gsub(to_decode,"%s", "")
    local unpadded = gsub(padded,"=", "")
    local bit_pattern = ''
    local decoded = ''

    to_decode = gsub(to_decode,"\n", "")
    to_decode = gsub(to_decode," ", "")

    for i = 1, string.len(unpadded) do
      local char = string.sub(to_decode, i, i)
      -- octo: plain find; "(" or "[" in the box raised a pattern error
      local offset, _ = string.find(index_table, char, 1, true)
      if offset == nil then return nil end

      local remaining = tonumber(offset-1)
      local bin_bits = ''
      for i = 7, 0, -1 do
        local current_power = math.pow(2, i)
        if remaining >= current_power then
          bin_bits = bin_bits .. '1'
          remaining = remaining - current_power
        else
          bin_bits = bin_bits .. '0'
        end
      end

      bit_pattern = bit_pattern .. string.sub(bin_bits, 3)
    end

    for i = 1, string.len(bit_pattern), 8 do
      local byte = string.sub(bit_pattern, i, i+7)
      decoded = decoded .. strchar(tonumber(byte, 2))
    end

    local padding_length = string.len(padded)-string.len(unpadded)

    if (padding_length == 1 or padding_length == 2) then
      decoded = string.sub(decoded,1,-2)
    end

    return decoded
  end

  do -- Window
    local f = CreateFrame("Frame", "pfShare", UIParent)
    f:Hide()
    f:SetPoint("CENTER", 0, 0)
    f:SetWidth(580)
    f:SetHeight(420)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    f:SetFrameStrata("DIALOG")

    f:SetScript("OnShow", function()
      if pfUI.gui and pfUI.gui:IsShown() then
        f.hadGUI = true
        pfUI.gui:Hide()
      else
        f.hadGUI = nil
      end
    end)

    f:SetScript("OnHide", function()
      if f.hadGUI then
        pfUI.gui:Show()
      end
    end)

    CreateBackdrop(f, nil, true, 0.8)
    CreateBackdropShadow(f)
    table.insert(UISpecialFrames, "pfShare")

    -- the profile in the text box, pasted encoded or decoded: table or nil, error
    function f.GetImport()
      local text = f.scroll and f.scroll.text and f.scroll.text:GetText() or ""
      if string.gsub(text, "%s", "") == "" then return nil, "empty" end
      if not string.find(text, "pfUI_config") then
        local raw = dec(text)
        if not raw or raw == "" then return nil, "not encoded" end
        local good, out = pcall(decompress, raw)
        if not good or type(out) ~= "string" then return nil, "cannot decode" end
        text = out
      end
      return parse(text)
    end

    do -- Edit Box
      f.scroll = pfUI.api.CreateScrollFrame("pfShareScroll", f)
      f.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30)
      f.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 50)
      f.scroll:SetWidth(560)
      f.scroll:SetHeight(400)

      f.scroll.backdrop = CreateFrame("Frame", "pfShareScrollBackdrop", f.scroll)
      f.scroll.backdrop:SetFrameLevel(1)
      f.scroll.backdrop:SetPoint("TOPLEFT", f.scroll, "TOPLEFT", -5, 5)
      f.scroll.backdrop:SetPoint("BOTTOMRIGHT", f.scroll, "BOTTOMRIGHT", 5, -5)
      pfUI.api.CreateBackdrop(f.scroll.backdrop, nil, true)

      f.scroll.text = CreateFrame("EditBox", "pfShareEditBox", f.scroll)
      f.scroll.text.bg = f.scroll.text:CreateTexture(nil, "OVERLAY")
      f.scroll.text.bg:SetAllPoints(f.scroll.text)
      f.scroll.text.bg:SetTexture(1,1,1,.05)
      f.scroll.text:SetMultiLine(true)
      f.scroll.text:SetWidth(560)
      f.scroll.text:SetHeight(400)
      f.scroll.text:SetAllPoints(f.scroll)
      f.scroll.text:SetTextInsets(15,15,15,15)
      f.scroll.text:SetFont(pfUI.media["font:RobotoMono.ttf"], 9)
      f.scroll.text:SetAutoFocus(false)
      f.scroll.text:SetJustifyH("LEFT")
      f.scroll.text:SetScript("OnEscapePressed", function() this:ClearFocus() end)
      f.scroll.text:SetScript("OnTextChanged", function()
        this:GetParent():UpdateScrollChildRect()
        this:GetParent():UpdateScrollState()

        if not f.GetImport() then
          f.loadButton:Disable()
          f.loadButton.text:SetTextColor(1,.5,.5,1)
        else
          f.loadButton:Enable()
          f.loadButton.text:SetTextColor(.5,1,.5,1)
        end

        local trydec = dec(this:GetText())
        if string.gsub(this:GetText(), " ", "") == "" then
          f.readButton.text:SetText(T["N/A"])
          f.readButton:Disable()
        elseif not trydec or trydec == "" then
          f.readButton:Enable()
          f.readButton.text:SetText(T["Encode"])
          f.readButton.func = function()
            local compressed = enc(compress(f.scroll.text:GetText()))
            f.scroll.text:SetText(compressed)
          end
        else
          f.readButton:Enable()
          f.readButton.text:SetText(T["Decode"])
          f.readButton.func = function()
            local uncompressed = decompress(dec(f.scroll.text:GetText()))
            f.scroll.text:SetText(uncompressed)
          end
        end
      end)
      f.scroll:SetScrollChild(f.scroll.text)
    end

    do -- button: close
      f.closeButton = CreateFrame("Button", "pfShareClose", f)
      f.closeButton:SetPoint("TOPRIGHT", -5, -5)
      f.closeButton:SetHeight(12)
      f.closeButton:SetWidth(12)
      f.closeButton.texture = f.closeButton:CreateTexture("pfQuestionDialogCloseTex")
      f.closeButton.texture:SetTexture(pfUI.media["img:close"])
      f.closeButton.texture:ClearAllPoints()
      f.closeButton.texture:SetAllPoints(f.closeButton)
      f.closeButton.texture:SetVertexColor(1,.25,.25,1)
      pfUI.api.SkinButton(f.closeButton, 1, .5, .5)
      f.closeButton:SetScript("OnClick", function()
       this:GetParent():Hide()
      end)
    end

    do -- checkbox: ignore positions
      f.ignorePosition = CreateFrame("CheckButton", "pfShareIgnorePosition", f, "UICheckButtonTemplate")
      f.ignorePosition:SetNormalTexture("")
      f.ignorePosition:SetPushedTexture("")
      f.ignorePosition:SetHighlightTexture("")
      CreateBackdrop(f.ignorePosition, nil, true)
      f.ignorePosition:SetWidth(14)
      f.ignorePosition:SetHeight(14)
      f.ignorePosition:SetPoint("BOTTOMLEFT", 10, 10)

      f.ignorePositionCaption = f.ignorePosition:CreateFontString("Status", "LOW", "GameFontNormal")
      f.ignorePositionCaption:SetFont(pfUI.font_default, C.global.font_size + 2, "OUTLINE")
      f.ignorePositionCaption:SetPoint("LEFT", f.ignorePosition, "RIGHT", 5, 0)
      f.ignorePositionCaption:SetFontObject(GameFontWhite)
      f.ignorePositionCaption:SetJustifyH("LEFT")
      f.ignorePositionCaption:SetText(T["Ignore Layout"])
    end


    do -- button: load
      f.loadButton = CreateFrame("Button", "pfShareLoad", f)
      pfUI.api.SkinButton(f.loadButton)
      f.loadButton:SetPoint("BOTTOMRIGHT", -5, 5)
      f.loadButton:SetWidth(75)
      f.loadButton:SetHeight(25)
      f.loadButton.text = f.loadButton:CreateFontString("Caption", "LOW", "GameFontWhite")
      f.loadButton.text:SetAllPoints(f.loadButton)
      f.loadButton.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
      f.loadButton.text:SetText(T["Import"])
      f.loadButton:SetScript("OnClick", function()
        local imported, err = f.GetImport()
        if not imported then
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|rUI: " .. T["This is not a pfUI profile string"] .. " (" .. tostring(err) .. ")")
          return
        end

        -- octo (12 Nov 2026): a tick list of the sections that change; only the ticked ones
        -- are applied (an "Ignore Layout" string never touches the frame positions)
        local title = T["Import: pick the features to apply"]
        if not imported.position then title = title .. "\n|cffaaffaa" .. T["Your frame positions are kept."] .. "|r" end
        Pick(title, imported, function(picked)
          importPicked(imported, picked)
          ReloadUI()
        end)
      end)
    end

    do -- button: read
      f.readButton = CreateFrame("Button", "pfShareDecode", f)
      pfUI.api.SkinButton(f.readButton)
      f.readButton:SetPoint("RIGHT", f.loadButton, "LEFT", -10, 0)
      f.readButton:SetWidth(75)
      f.readButton:SetHeight(25)
      f.readButton.text = f.readButton:CreateFontString("Caption", "LOW", "GameFontWhite")
      f.readButton.text:SetAllPoints(f.readButton)
      f.readButton.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
      f.readButton.text:SetText(T["N/A"])
      f.readButton:SetScript("OnClick", function()
        this.func()
      end)
    end

    do -- button: export
      f.exportButton = CreateFrame("Button", "pfShareExport", f)
      pfUI.api.SkinButton(f.exportButton)
      f.exportButton:SetPoint("RIGHT", f.readButton, "LEFT", -10, 0)
      f.exportButton:SetWidth(75)
      f.exportButton:SetHeight(25)
      f.exportButton.text = f.exportButton:CreateFontString("Caption", "LOW", "GameFontWhite")
      f.exportButton.text:SetAllPoints(f.exportButton)
      f.exportButton.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
      f.exportButton.text:SetText(T["Export"])
      f.exportButton:SetScript("OnClick", function()
        -- generate a default config
        -- (octo: the real table goes back afterwards, not a copy - modules keep references to its parts)
        local original = pfUI_config
        local myconfig = CopyTable(pfUI_config)
        _G.pfUI_config = {}
        pfUI:LoadConfig()
        local defconfig = CopyTable(pfUI_config)

        -- restore config and references
        _G.pfUI_config = original
        C = original
        pfUI.env.C = original

        local ignored = {}
        ignored["position"] = f.ignorePosition:GetChecked()
        ignored["disabled"] = f.ignorePosition:GetChecked()
        -- octo (29 Oct 2026, "pressing profiles ... crashing the game"): the UI layouts keep a
        -- copy of every setting per layout (500 KB and more) - too big for the text box, and they
        -- are this character's screens, not a look to share
        ignored["layouts"] = true

        local compressed = enc(compress(serialize(myconfig, defconfig, "pfUI_config", ignored)))
        -- (a text box with megabytes in it takes the client down: such a string only goes to the clipboard)
        if string.len(compressed) > 120000 then
          f.scroll.text:SetText("")
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r profile: too big to show (" .. math.floor(string.len(compressed) / 1000) .. " KB).")
        else
          f.scroll.text:SetText(compressed)
        end
        f.scroll.text.value = compressed
        f.scroll:SetVerticalScroll(0)
        -- octo (ClassicAPI CopyToClipboard, 25 Oct 2026): straight onto the
        -- clipboard, no select-all and Ctrl+C in the box
        local LC = pfUI.api.libclient
        if LC and LC.Copy and LC.Copy(compressed) then
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r profile: copied to your clipboard - paste it anywhere with Ctrl+V.")
        end
      end)
    end

    -- for tests\run.lua and other modules
    pfUI.share = { serialize = serialize, parse = parse, preview = preview, import = import,
                   sections = sections, importPicked = importPicked, Pick = Pick, defaults = defaults,
                   compress = compress, decompress = decompress, enc = enc, dec = dec }

    _G.SLASH_PFEXPORT1, _G.SLASH_PFEXPORT2, _G.SLASH_PFEXPORT3 = "/export", "/import", "/share"
    function SlashCmdList.PFEXPORT(msg, editbox)
      f:Show()
    end
  end
end)
