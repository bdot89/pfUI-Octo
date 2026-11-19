pfUI:RegisterModule("share", "vanilla:tbc", function ()
  -- (16 Nov 2026) written into one table of lines and joined once: adding to one
  -- long string line after line copied it every time (the export froze the game)
  local function write(out, tbl, comp, name, ignored, spacing)
    local start = table.getn(out)
    local match = nil
    local tname = spacing == "" and name or (type(name) == "number" and ("[" .. name .. "]") or ("[\"" .. name .. "\"]"))
    table.insert(out, spacing .. tname .. " = {\n")
    for k, v in pairs(tbl) do
      if not ( ignored[k] and spacing == "" ) and ( not comp or not comp[k] or comp[k] ~= tbl[k] ) then
        -- (19 Nov 2026, Barbeque_Squirrel: "the import button isnt pressing at all") list entries keep a
        -- number key ([3]), so lists (totem sets, consumables, roll rules) come back as lists
        local kk = type(k) == "number" and ("[" .. k .. "]") or ("[\"" .. k .. "\"]")
        if type(v) == "table" then
          if write(out, tbl[k], comp and comp[k], k, ignored, spacing .. "  ") then match = true end
        elseif type(v) == "string" then
          match = true
          -- line breaks inside a value broke the string into lines the reader refused (Import stayed grey)
          local s = string.gsub(v, "\\", "\\\\")
          s = string.gsub(s, "\n", "\\n")
          s = string.gsub(s, "\r", "\\r")
          table.insert(out, spacing .. "  " .. kk .. " = \"" .. s .. "\",\n")
        elseif type(v) == "number" then
          -- not a number / endless (1.#INF) cannot be read back: left out
          if v == v and v < 1e300 and v > -1e300 then
            match = true
            table.insert(out, spacing .. "  " .. kk .. " = " .. tostring(v) .. ",\n")
          end
        elseif type(v) == "boolean" then
          -- octo: the combat text keeps on / off settings as true / false
          match = true
          table.insert(out, spacing .. "  " .. kk .. " = " .. (v and "true" or "false") .. ",\n")
        end
      end
    end
    if not match then
      for i = table.getn(out), start + 1, -1 do table.remove(out, i) end
      return nil
    end
    table.insert(out, spacing .. "}" .. ( spacing == "" and "" or "," ) .. "\n")
    return true
  end
  local function serialize(tbl, comp, name, ignored, spacing)
    local out = {}
    if not write(out, tbl, comp, name, ignored, spacing or "") then return nil end
    return table.concat(out)
  end

  -- octo: reads the text serialize() writes WITHOUT running it. pfUI used
  -- loadstring() on whatever was pasted, so a shared string could run any
  -- code on the importer's client. Only these lines are accepted:
  --   pfUI_config = {          ["key"] = {          ["key"] = "text",
  --   ["key"] = 12.5,          },  or  }
  -- returns: the table, or nil and a message with the bad line number
  local function parse(text)
    if type(text) ~= "string" or string.len(text) > 2000000 then return nil, "no text" end
    local root, stack, depth, lineno, skipped = nil, {}, 0, 0, 0
    local ESC = { n = "\n", r = "\r" }
    local function unescape(s)
      return (string.gsub(s, "\\(.)", function(c) return ESC[c] or c end))
    end
    -- ["key"] or [12] at the start of a line: key, the rest of the line
    local function keyOf(line)
      local _, _, k, rest = string.find(line, '^%["([^"]*)"%] = (.*)$')
      if k then return k, rest end
      _, _, k, rest = string.find(line, '^%[(%d+)%] = (.*)$')
      if k then return tonumber(k), rest end
    end
    for line in string.gfind(text .. "\n", "([^\n]*)\n") do
      lineno = lineno + 1
      line = string.gsub(line, "^%s+", "")
      line = string.gsub(line, "%s+$", "")
      local _, key, rest, value
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
        key, rest = keyOf(line)
        if key and rest == "{" then
          if depth >= 12 then return nil, "line " .. lineno .. ": nested too deep" end
          local t = {}
          stack[depth][key] = t
          depth = depth + 1
          stack[depth] = t
        elseif key then
          _, _, value = string.find(rest, '^"(.*)",$')
          if value then
            stack[depth][key] = unescape(value)
          elseif rest == "true," or rest == "false," then
            stack[depth][key] = (rest == "true,")
          else
            _, _, value = string.find(rest, '^(%-?[%d%.]+[eE]?[%-%+]?%d*),$')
            if value and tonumber(value) then
              stack[depth][key] = tonumber(value)
            else
              skipped = skipped + 1
            end
          end
        else
          -- (19 Nov 2026) one odd line (a value with a line break in an older string) is left out,
          -- the rest still imports - it used to refuse the whole string and keep Import grey
          skipped = skipped + 1
        end
      end
    end
    if not root then return nil, "empty" end
    if depth ~= 0 then return nil, "cut short" end
    return root, nil, skipped
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
  -- opts (export, 16 Nov 2026): list = the rows, info = the line under the title, apply = the button, empty = what to say when nothing is listed
  local function Pick(title, imported, onApply, opts)
    opts = opts or {}
    local list = opts.list or sections(imported, pfUI_config)
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
    pick.info:SetText(opts.info or T["Only the ticked features are applied; everything else stays as it is on this character."])
    pick.apply.text:SetText(opts.apply or T["Apply"])
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
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: " .. (opts.empty or T["Nothing differs from your settings."]))
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

  -- (16 Nov 2026, Wolfahrt on Discord: the game stops responding while exporting / importing)
  -- base64 by arithmetic, three bytes to four letters, built in a table. pfUI's version
  -- built a string of 0s and 1s one character at a time (each step copies the whole string),
  -- which took many seconds on a full profile. Same output: 92 letters a line, = padding.
  local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  local B64CHAR, B64VAL = {}, {}
  for i = 1, 64 do
    local c = string.sub(B64, i, i)
    B64CHAR[i - 1] = c
    B64VAL[c] = i - 1
  end
  local floor = math.floor

  local function enc(to_encode)
    local len = string.len(to_encode)
    local out, n, line = {}, 0, 0
    local function put(c)
      n = n + 1
      out[n] = c
      line = line + 1
      if line >= 92 then n = n + 1 out[n] = "\n" line = 0 end
    end
    for i = 1, len, 3 do
      -- (Lua 5.0's string.byte gives one byte a call)
      local a = string.byte(to_encode, i)
      local b = i + 1 <= len and string.byte(to_encode, i + 1) or nil
      local c = i + 2 <= len and string.byte(to_encode, i + 2) or nil
      local v = a * 65536 + (b or 0) * 256 + (c or 0)
      put(B64CHAR[floor(v / 262144)])
      put(B64CHAR[mod(floor(v / 4096), 64)])
      put(b and B64CHAR[mod(floor(v / 64), 64)] or "=")
      put(c and B64CHAR[mod(v, 64)] or "=")
    end
    -- octo: no line break right at the end (exports of 92*n letters failed to import)
    if out[n] == "\n" then out[n] = nil end
    return table.concat(out)
  end

  -- the other way (fast, see enc): nil when the text holds anything but base64
  local function dec(to_decode)
    local text = gsub(to_decode, "[%s=]", "")
    local len = string.len(text)
    local out, n = {}, 0
    for i = 1, len, 4 do
      local v, got = 0, 0
      for j = i, i + 3 do
        v = v * 64
        if j <= len then
          local d = B64VAL[string.sub(text, j, j)]
          if not d then return nil end
          v = v + d
          got = got + 1
        end
      end
      -- got letters carry floor(got * 6 / 8) whole bytes
      local a, b, c = floor(v / 65536), mod(floor(v / 256), 256), mod(v, 256)
      n = n + 1 out[n] = strchar(a)
      if got >= 3 then n = n + 1 out[n] = strchar(b) end
      if got >= 4 then n = n + 1 out[n] = strchar(c) end
    end
    return table.concat(out)
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
        -- (19 Nov 2026) Discord's ``` code blocks, quotes and |c colour codes copied along
        text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
        text = string.gsub(text, "|r", "")
        text = string.gsub(text, "[`\"']", "")
        text = string.gsub(text, "^%s*lua%s", "")
        local raw = dec(text)
        if not raw or raw == "" then return nil, "odd letters" end
        local good, out = pcall(decompress, raw)
        if not good or type(out) ~= "string" then return nil, "cut short" end
        text = out
      end
      return parse(text)
    end

    -- the line over the buttons: why Import cannot go yet, in words
    f.WHY = {
      ["empty"] = "Paste a profile string in the box (Ctrl+V).",
      ["odd letters"] = "This is not a pfUI profile string: it has letters a string never has. Copy it again.",
      ["cut short"] = "The string is cut short. Copy ALL of it (Discord cuts long messages: send it as a file).",
      ["no text"] = "This string is too long to read.",
    }
    function f.Why(err)
      if not err then return "" end
      local w = f.WHY[err]
      if w then return w end
      if string.find(err, "not a pfUI profile") then
        return "This is not a pfUI profile string (" .. err .. ")."
      end
      return "This string cannot be read (" .. err .. "). Copy it again."
    end
    function f.Check()
      local imported, err, skipped = f.GetImport()
      if not f.status then return imported end
      if imported then
        f.status:SetText("|cff88ff88" .. T["Ready: press Import."] .. "|r"
          .. ((skipped or 0) > 0 and ("  |cffaaaaaa(" .. skipped .. " odd lines left out)|r") or ""))
      else
        f.status:SetText("|cffff8888" .. f.Why(err) .. "|r")
      end
      return imported, err
    end

    do -- Edit Box
      f.scroll = pfUI.api.CreateScrollFrame("pfShareScroll", f)
      f.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30)
      f.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 56)
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

        -- (19 Nov 2026, "the import button isnt pressing at all") never a dead button: it stays
        -- clickable and the line above it says why a string cannot go in
        if f.Check() then
          f.loadButton.text:SetTextColor(.5,1,.5,1)
        else
          f.loadButton.text:SetTextColor(1,.5,.5,1)
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


    do -- status line: why Import cannot go yet
      f.status = f:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      f.status:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      f.status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 34)
      f.status:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 34)
      f.status:SetJustifyH("LEFT")
      f.status:SetText("")
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
        local imported, err = f.Check()
        if not imported then
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|rUI: " .. f.Why(err))
          if UIErrorsFrame then UIErrorsFrame:AddMessage(f.Why(err), 1, .4, .4) end
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

        local skip = {}
        skip["position"] = f.ignorePosition:GetChecked()
        skip["disabled"] = f.ignorePosition:GetChecked()
        -- octo (29 Oct 2026, "pressing profiles ... crashing the game"): the UI layouts keep a
        -- copy of every setting per layout (500 KB and more) - too big for the text box, and they
        -- are this character's screens, not a look to share
        skip["layouts"] = true

        -- (16 Nov 2026, Wolfahrt on Discord: "select the features we want to import when we choose
        -- the export feature") the same tick list as Import: every part you changed from the
        -- defaults, all ticked; only the ticked ones go into the string
        local list = {}
        for section, v in pairs(myconfig) do
          if not skip[section] and type(v) == "table" then
            local n = differ(v, defconfig[section])
            if n > 0 then table.insert(list, { section, n }) end
          end
        end
        table.sort(list, function(a, b) return label(a[1]) < label(b[1]) end)
        Pick(T["Export: pick the features to share"], nil, function(picked)
          local ignored = {}
          for section in pairs(myconfig) do
            if not picked[section] then ignored[section] = true end
          end
          f.DoExport(myconfig, defconfig, ignored)
        end, { list = list, apply = T["Export"],
               info = T["Only the ticked features go into the string. Fewer features = a shorter string."],
               empty = T["You have not changed anything from the defaults yet."] })
      end)
      -- the string itself, once the features are picked
      function f.DoExport(myconfig, defconfig, ignored)
        local text = serialize(myconfig, defconfig, "pfUI_config", ignored)
        if not text then
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r profile: " .. T["nothing to export."])
          return
        end
        local compressed = enc(compress(text))
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
      end
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
