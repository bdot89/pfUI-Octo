pfUI:RegisterModule("rinse-options", "vanilla", function ()
  -- pfUI Octo :: the OctoRinse section (17 Nov 2026, modules/rinse.lua). User: "Add this in the list with its own tab it
  -- should be top of the combat list with highlight the same as octodots", "the page ... can have its own clean layout",
  -- "all options where you want it enabled. what bosses you want to setup all with the dungeon lists same as in rinse
  -- make it CLEAN use art where we can". Pages: General (every UpsiRinse option + where it runs), Boss lists (a raid /
  -- dungeon list on the left, the boss's debuffs on the right under its loading-screen art), Everywhere (the lists that
  -- are not tied to a boss) and Players (cure-first and never-cure players).
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local R = pfUI.rinse
  local RO = {}
  pfUI.rinseOptions = RO
  local K = W.C
  local ICON = "Interface\\Icons\\"
  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local GLUE = "Interface\\Glues\\LoadingScreens\\"

  local function Chk(p, label, desc, key, after)
    return W.Check(p, label, desc, function() return C.rinse[key] == "1" end,
      function(v) C.rinse[key] = v and "1" or "0" if R then R.ApplyLayout() R.dirty = true end if after then after(v) end end)
  end
  local function Sld(p, label, desc, min, max, step, key, fmt)
    return W.Slider(p, label, desc, min, max, step, function() return tonumber(C.rinse[key]) or min end,
      function(v) C.rinse[key] = tostring(v) if R then R.ApplyLayout() end end, fmt)
  end
  local function Off(p)
    W.Note(p, "OctoRinse is switched off. Click the switch above, close the options and reload.")
  end
  local function Heading(p, title, about)
    W.Heading(p, title, { on = O.ModuleSwitch("rinse", "OctoRinse"), about = about })
  end
  function RO.Open(key) O:Open(key) end

  -- ---------------------------------------------------------------- art per zone

  RO.ZONEART = {
    ["Molten Core"] = { "Spell_Fire_LavaSpawn", "LoadScreenMoltenCore" },
    ["Blackwing Lair"] = { "INV_Misc_Head_Dragon_Black", "LoadScreenBlackwingLair" },
    ["Ahn'Qiraj Temple"] = { "INV_Qiraj_JewelEncased", "LoadScreenAhnQiraj40man" },
    ["Ruins of Ahn'Qiraj"] = { "INV_Misc_QirajiCrystal_05", "LoadScreenAhnQiraj20man" },
    ["Naxxramas"] = { "Spell_Shadow_RaiseDead", "LoadScreenNaxxramas" },
    ["Zul'Gurub"] = { "INV_Misc_Head_Troll_01", "LoadScreenZulGurub" },
    ["Onyxia's Lair"] = { "INV_Misc_Head_Dragon_01", "LoadScreenRaid" },
    ["Karazhan Crypt"] = { "INV_Misc_Bone_HumanSkull_01", "LoadScreenKarazhanCrypt" },
    ["Blackrock Spire"] = { "INV_Misc_Head_Orc_01", "LoadScreenBlackrockSpire" },
    ["Karazhan - Lower"] = { "INV_Misc_Key_11", "LoadScreenKarazhan" },
    ["Karazhan - Upper"] = { "INV_Misc_Orb_05", "LoadScreenKarazhanForty" },
    ["Emerald Sanctum"] = { "INV_Misc_Head_Dragon_Green", "LoadScreenEmeraldSanctum" },
    ["The Black Morass"] = { "Spell_Nature_TimeStop", "LoadScreenCavernsTime" },
    ["Timbermaw Hold"] = { "Ability_Hunter_Pet_Bear", "LoadScreenTimbermaw" },
    ["Dire Maul"] = { "INV_Misc_MonsterClaw_04", "LoadScreenDireMaul" },
    ["World Bosses"] = { "Spell_Shadow_DemonBreath", "LoadScreenEmeraldDream" },
    ["Unsorted"] = { "INV_Misc_Book_11", "LoadScreenDungeon" },
  }
  function RO.ZoneIcon(z) local a = RO.ZONEART[z] return ICON .. (a and a[1] or "INV_Misc_Bag_10") end
  function RO.ZoneArt(z) local a = RO.ZONEART[z] return GLUE .. (a and a[2] or "LoadScreenDungeon") end
  -- the browser's name for UpsiRinse's "Unsorted" zone: its ticks are the Everywhere lists
  function RO.ZoneLabel(z) return z == R.EVERYWHERE and "Everywhere" or z end

  -- ---------------------------------------------------------------- the lists (shipped + learned, UpsiRinse's merge)

  function RO.Zones()
    local out, has = {}, {}
    for _, z in ipairs(R.DATA.zones) do
      if z.zone ~= R.EVERYWHERE then table.insert(out, z.zone) has[z.zone] = true end
    end
    local extra = {}
    for z in pairs(R.Learned()) do if not has[z] and z ~= R.EVERYWHERE then table.insert(extra, z) end end
    table.sort(extra)
    for _, z in ipairs(extra) do table.insert(out, z) end
    table.insert(out, R.EVERYWHERE)
    return out
  end
  function RO.Bosses(zone)
    local out, has = {}, {}
    local z = R.FindZone(zone)
    for _, b in ipairs(z and z.bosses or {}) do table.insert(out, b.name) has[b.name] = true end
    local extra = {}
    for b in pairs(R.Learned()[zone] or {}) do if not has[b] then table.insert(extra, b) end end
    table.sort(extra)
    for _, b in ipairs(extra) do table.insert(out, b) end
    return out
  end
  -- { { name, school, note, learned, confirmed } }
  function RO.Spells(zone, boss)
    local out, idx = {}, {}
    local z = R.FindZone(zone)
    for _, b in ipairs(z and z.bosses or {}) do
      if b.name == boss then
        for _, s in ipairs(b.spells) do
          local e = { name = s[1], school = s[2], note = s[3] }
          table.insert(out, e)
          idx[s[1]] = e
        end
      end
    end
    local learned = R.Learned()[zone] and R.Learned()[zone][boss]
    for n, sc in pairs(learned or {}) do
      local e = idx[n]
      if e then
        if e.school == "Unknown" then e.school = sc e.confirmed = true end
      else
        e = { name = n, school = sc, learned = true }
        table.insert(out, e)
        idx[n] = e
      end
    end
    return out
  end
  local function Visible(school)
    if C.rinse.onlymine ~= "1" then return true end
    return school == "Unknown" or R.CanDispel(school)
  end
  function RO.Count(zone, boss)
    local n = 0
    for _, s in ipairs(RO.Spells(zone, boss)) do if Visible(s.school) then n = n + 1 end end
    return n
  end
  -- settings key of a boss (nil = the Everywhere lists)
  function RO.KeyOf(zone, boss) if zone == R.EVERYWHERE then return nil end return R.Key(zone, boss) end
  function RO.Get(key, name, what) if key then return R.BossGet(key, name, what) end return R.GlobalGet(name, what) end
  function RO.Set(key, name, what, v) if key then R.BossSet(key, name, what, v) else R.GlobalSet(name, what, v) end end

  -- ---------------------------------------------------------------- the boss browser

  local LEFT_W, LROW, RROW, BANNER = 236, 24, 30, 96
  RO.open = {}
  local function Fs(parent, size, r, g, b, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    W.Font(fs, size, r or K.text[1], g or K.text[2], b or K.text[3])
    if flags then fs:SetFont(W.UIFont(), size, flags) end
    fs:SetJustifyH("LEFT")
    return fs
  end
  local function Tex(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(WHITE)
    t:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    return t
  end

  -- the zone the player stands in, and its first boss (or the boss being fought)
  function RO.PickHere()
    local real = GetRealZoneText and GetRealZoneText() or ""
    for key in pairs(R.active or {}) do
      local _, _, zn, bn = string.find(key, "^(.-)%^(.+)$")
      if zn and not R.IsTrash(bn) then return zn, bn end
    end
    for _, z in ipairs(R.DATA.zones) do
      if table.getn(z.zones) > 0 and R.InZone(z, real) then return z.zone, z.bosses[1] and z.bosses[1].name end
    end
  end

  local function Browser(p)
    local row = W.Row(p, 600, 0, 4)
    local width = row:GetWidth() or 788
    local RW = width - LEFT_W - 12
    RO.browser = row

    -- left: raids, dungeons and their bosses
    local left = CreateFrame("Frame", nil, row)
    left:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    left:SetWidth(LEFT_W)
    left:SetHeight(600)
    W.Flat(left, K.field, .9, K.line)
    local lt = Fs(left, 10, K.label[1], K.label[2], K.label[3])
    lt:SetPoint("TOPLEFT", left, "TOPLEFT", 10, -9)
    lt:SetText("RAIDS & DUNGEONS")
    local here = CreateFrame("Button", nil, left)
    here:SetWidth(70)
    here:SetHeight(16)
    here:SetPoint("TOPRIGHT", left, "TOPRIGHT", -8, -6)
    here.t = Fs(here, 10, K.accent[1], K.accent[2], K.accent[3])
    here.t:SetPoint("RIGHT", here, "RIGHT", 0, 0)
    here.t:SetJustifyH("RIGHT")
    here.t:SetText("Where I am")
    W.Tip(here, "Where I am", "Opens the zone you are standing in, on the boss you are fighting.")
    here:SetScript("OnClick", function()
      local z, b = RO.PickHere()
      if z then RO.open[z] = true RO.zone, RO.boss, RO.roff = z, b, 0 RO.Paint() end
    end)
    local NL = math.floor((600 - 30) / LROW)
    RO.lrows = {}
    for i = 1, NL do
      local b = CreateFrame("Button", nil, left)
      b:SetHeight(LROW)
      b:SetPoint("TOPLEFT", left, "TOPLEFT", 4, -26 - (i - 1) * LROW)
      b:SetPoint("RIGHT", left, "RIGHT", -4, 0)
      b.sel = Tex(b, "BACKGROUND", K.accent[1], K.accent[2], K.accent[3], .22)
      b.sel:SetAllPoints(b)
      b.mark = Tex(b, "ARTWORK", K.accent[1], K.accent[2], K.accent[3], 1)
      b.mark:SetWidth(2)
      b.mark:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
      b.mark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
      b.hl = Tex(b, "HIGHLIGHT", 1, 1, 1, .05)
      b.hl:SetAllPoints(b)
      b.icon = b:CreateTexture(nil, "ARTWORK")
      b.icon:SetWidth(18)
      b.icon:SetHeight(18)
      b.icon:SetTexCoord(.08, .92, .08, .92)
      b.dot = Tex(b, "ARTWORK")
      b.dot:SetWidth(6)
      b.dot:SetHeight(6)
      b.text = Fs(b, 12)
      b.count = Fs(b, 10, K.dim[1], K.dim[2], K.dim[3])
      b.count:SetPoint("RIGHT", b, "RIGHT", -6, 0)
      b.count:SetJustifyH("RIGHT")
      b:EnableMouseWheel(true)
      b:SetScript("OnMouseWheel", function() RO.ScrollLeft(arg1) end)
      b:SetScript("OnClick", function()
        local e = this.entry
        if not e then return end
        if e.boss then
          RO.zone, RO.boss, RO.roff = e.zone, e.boss, 0
        else
          RO.open[e.zone] = not RO.open[e.zone] or nil
        end
        RO.Paint()
      end)
      RO.lrows[i] = b
    end
    left:EnableMouseWheel(true)
    left:SetScript("OnMouseWheel", function() RO.ScrollLeft(arg1) end)
    RO.loff = 0
    function RO.ScrollLeft(d)
      RO.loff = math.max(0, math.min((RO.lcount or 0) - NL, (RO.loff or 0) - d * 3))
      RO.PaintLeft()
    end

    -- right: banner, column heads, the boss's debuffs
    local right = CreateFrame("Frame", nil, row)
    right:SetPoint("TOPLEFT", row, "TOPLEFT", LEFT_W + 12, 0)
    right:SetWidth(RW)
    right:SetHeight(600)
    W.Flat(right, K.field, .9, K.line)
    RO.right = right
    local ban = CreateFrame("Frame", nil, right)
    ban:SetPoint("TOPLEFT", right, "TOPLEFT", 1, -1)
    ban:SetPoint("TOPRIGHT", right, "TOPRIGHT", -1, -1)
    ban:SetHeight(BANNER)
    ban.art = ban:CreateTexture(nil, "BACKGROUND")
    ban.art:SetAllPoints(ban)
    ban.art:SetTexCoord(0, 1, .3, .5)
    ban.shade = Tex(ban, "BORDER", 0, 0, 0, 1)
    ban.shade:SetAllPoints(ban)
    if ban.shade.SetGradientAlpha then ban.shade:SetGradientAlpha("HORIZONTAL", 0, 0, 0, .92, 0, 0, 0, .25) end
    ban.line = Tex(ban, "ARTWORK", K.accent[1], K.accent[2], K.accent[3], .8)
    ban.line:SetHeight(1)
    ban.line:SetPoint("BOTTOMLEFT", ban, "BOTTOMLEFT", 0, 0)
    ban.line:SetPoint("BOTTOMRIGHT", ban, "BOTTOMRIGHT", 0, 0)
    ban.iconbg = Tex(ban, "ARTWORK", 0, 0, 0, .8)
    ban.iconbg:SetWidth(50)
    ban.iconbg:SetHeight(50)
    ban.iconbg:SetPoint("LEFT", ban, "LEFT", 16, 0)
    ban.icon = ban:CreateTexture(nil, "OVERLAY")
    ban.icon:SetWidth(46)
    ban.icon:SetHeight(46)
    ban.icon:SetPoint("CENTER", ban.iconbg, "CENTER", 0, 0)
    ban.icon:SetTexCoord(.08, .92, .08, .92)
    ban.zone = Fs(ban, 11, K.dim[1], K.dim[2], K.dim[3])
    ban.zone:SetPoint("TOPLEFT", ban.iconbg, "TOPRIGHT", 14, 0)
    ban.title = Fs(ban, 22, 1, 1, 1, "OUTLINE")
    ban.title:SetPoint("LEFT", ban.iconbg, "RIGHT", 14, 2)
    ban.sub = Fs(ban, 11, .85, .86, .9)
    ban.sub:SetPoint("BOTTOMLEFT", ban.iconbg, "BOTTOMRIGHT", 14, 0)
    ban.sub:SetPoint("RIGHT", ban, "RIGHT", -14, 0)
    ban.live = Fs(ban, 11, .25, .85, .47, "OUTLINE")
    ban.live:SetPoint("TOPRIGHT", ban, "TOPRIGHT", -12, -10)
    ban.live:SetJustifyH("RIGHT")
    RO.banner = ban

    -- column heads
    local COLS = {
      { "b", "Skip school", { 1, .4, .4 }, "Ignore", "This debuff is never cured, and nothing else of its school on that player either, "
        .. "so you cannot strip it by accident (Seed of Corruption, Mutating Injection, Wyvern Sting)." },
      { "h", "Hide", { .85, .86, .9 }, "Hide", "Only this debuff is left alone. Others of its school still show." },
      { "p", "Cure first", { 1, .82, .3 }, "Priority", "Cured before anything else in the raid." },
    }
    RO.COLS = COLS
    local COLX = { -214, -150, -86 }
    local heads = CreateFrame("Frame", nil, right)
    heads:SetPoint("TOPLEFT", ban, "BOTTOMLEFT", 0, 0)
    heads:SetPoint("TOPRIGHT", ban, "BOTTOMRIGHT", 0, 0)
    heads:SetHeight(24)
    local hn = Fs(heads, 10, K.label[1], K.label[2], K.label[3])
    hn:SetPoint("LEFT", heads, "LEFT", 14, 0)
    hn:SetText("DEBUFF")
    for i, c in ipairs(COLS) do
      local h = CreateFrame("Button", nil, heads)
      h:SetWidth(62)
      h:SetHeight(20)
      h:SetPoint("CENTER", heads, "RIGHT", COLX[i], 0)
      local t = Fs(h, 10, c[3][1], c[3][2], c[3][3])
      t:SetAllPoints(h)
      t:SetJustifyH("CENTER")
      t:SetText(string.upper(c[2]))
      W.Tip(h, c[2], c[5])
    end
    local hc = CreateFrame("Button", nil, heads)
    hc:SetWidth(56)
    hc:SetHeight(20)
    hc:SetPoint("CENTER", heads, "RIGHT", -32, 0)
    local hct = Fs(hc, 10, K.label[1], K.label[2], K.label[3])
    hct:SetAllPoints(hc)
    hct:SetJustifyH("CENTER")
    hct:SetText("CLASSES")
    W.Tip(hc, "Classes", "Limit Cure first or Hide to some classes: cure Tranquilizing Poison first only on warriors, hide "
      .. "Ignite Mana on everyone without mana.")
    local hline = Tex(heads, "ARTWORK", K.line[1], K.line[2], K.line[3], 1)
    hline:SetHeight(1)
    hline:SetPoint("BOTTOMLEFT", heads, "BOTTOMLEFT", 8, 0)
    hline:SetPoint("BOTTOMRIGHT", heads, "BOTTOMRIGHT", -8, 0)

    local NR = math.floor((600 - BANNER - 24 - 40) / RROW)
    RO.rrows = {}
    for i = 1, NR do
      local r = CreateFrame("Frame", nil, right)
      r:SetHeight(RROW)
      r:SetPoint("TOPLEFT", heads, "BOTTOMLEFT", 6, -2 - (i - 1) * RROW)
      r:SetPoint("RIGHT", right, "RIGHT", -6, 0)
      r:EnableMouse(true)
      r:EnableMouseWheel(true)
      r:SetScript("OnMouseWheel", function() RO.ScrollRight(arg1) end)
      r.zebra = Tex(r, "BACKGROUND", 1, 1, 1, .025)
      r.zebra:SetAllPoints(r)
      r.edge = Tex(r, "ARTWORK")
      r.edge:SetWidth(2)
      r.edge:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -3)
      r.edge:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 3)
      r.iconbg = Tex(r, "ARTWORK")
      r.iconbg:SetWidth(24)
      r.iconbg:SetHeight(24)
      r.iconbg:SetPoint("LEFT", r, "LEFT", 8, 0)
      r.icon = r:CreateTexture(nil, "OVERLAY")
      r.icon:SetWidth(22)
      r.icon:SetHeight(22)
      r.icon:SetPoint("CENTER", r.iconbg, "CENTER", 0, 0)
      r.icon:SetTexCoord(.08, .92, .08, .92)
      r.name = Fs(r, 12)
      r.name:SetPoint("TOPLEFT", r.iconbg, "TOPRIGHT", 8, 1)
      r.name:SetPoint("RIGHT", r, "RIGHT", -250, 0)
      r.note = Fs(r, 10, K.dim[1], K.dim[2], K.dim[3])
      r.note:SetPoint("BOTTOMLEFT", r.iconbg, "BOTTOMRIGHT", 8, -1)
      r.note:SetPoint("RIGHT", r, "RIGHT", -250, 0)
      -- school heading parts
      r.hicon = r:CreateTexture(nil, "OVERLAY")
      r.hicon:SetWidth(16)
      r.hicon:SetHeight(16)
      r.hicon:SetPoint("LEFT", r, "LEFT", 8, -2)
      r.hicon:SetTexCoord(.08, .92, .08, .92)
      r.htext = Fs(r, 13)
      r.htext:SetPoint("LEFT", r.hicon, "RIGHT", 8, 0)
      r.hline = Tex(r, "ARTWORK")
      r.hline:SetHeight(1)
      r.hline:SetPoint("LEFT", r.htext, "RIGHT", 10, 0)
      r.hline:SetPoint("RIGHT", r, "RIGHT", -8, 0)
      -- the three switches + classes
      r.pills = {}
      for j, c in ipairs(COLS) do
        local pill = W.CheckPill(r)
        pill:SetPoint("CENTER", r, "RIGHT", COLX[j] + 6, 0)
        local what = c[1]
        pill:SetScript("OnClick", function()
          local row2 = this:GetParent()
          if not row2.spell then return end
          RO.Set(row2.key, row2.spell.name, what, this:GetChecked() and true or false)
          RO.Paint()
        end)
        W.Tip(pill, c[2], c[5])
        r.pills[j] = pill
      end
      r.cls = CreateFrame("Button", nil, r)
      r.cls:SetWidth(52)
      r.cls:SetHeight(20)
      r.cls:SetPoint("CENTER", r, "RIGHT", -26, 0)
      W.Flat(r.cls, K.btn, 1, K.line)
      r.cls.t = Fs(r.cls, 10)
      r.cls.t:SetAllPoints(r.cls)
      r.cls.t:SetJustifyH("CENTER")
      r.cls:SetScript("OnClick", function() RO.ClassMenu(this, this:GetParent()) end)
      r.cls:SetScript("OnEnter", function()
        local rr = this:GetParent()
        if not rr.spell then return end
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("Classes: " .. rr.spell.name, 1, 1, 1)
        GameTooltip:AddLine("Cure first only for: " .. RO.ScopeText(rr.key, rr.spell.name, "pc"), 1, .82, .3, 1)
        GameTooltip:AddLine("Hide only for: " .. RO.ScopeText(rr.key, rr.spell.name, "hc"), .85, .86, .9, 1)
        GameTooltip:AddLine("Click to change.", .6, .62, .66)
        GameTooltip:Show()
      end)
      r.cls:SetScript("OnLeave", function() GameTooltip:Hide() end)
      r:SetScript("OnEnter", function()
        local s = this.spell
        if not s then return end
        GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
        local c = R.COLOR[s.school] or R.COLOR.Unknown
        GameTooltip:SetText(s.name, c[1], c[2], c[3])
        if s.school == "Unknown" then
          GameTooltip:AddLine("School not confirmed yet: it fills in the first time OctoRinse sees it.", 1, 1, 1, 1)
        else
          GameTooltip:AddLine(s.school .. (R.CanDispel(s.school) and " - you can cure it" or " - your class cannot cure it"), 1, 1, 1)
        end
        if s.note then GameTooltip:AddLine(s.note, 1, .82, .3, 1) end
        if s.learned then GameTooltip:AddLine("Seen in game, not in the shipped list.", .6, .62, .66, 1)
        elseif s.confirmed then GameTooltip:AddLine("School confirmed in game.", .6, .62, .66, 1) end
        if this.key then
          GameTooltip:AddLine("These switches count only in this fight.", .25, .85, .47, 1)
        else
          GameTooltip:AddLine("These switches count everywhere, PvP included.", 1, .55, .3, 1)
        end
        GameTooltip:Show()
      end)
      r:SetScript("OnLeave", function() GameTooltip:Hide() end)
      RO.rrows[i] = r
    end
    right:EnableMouseWheel(true)
    right:SetScript("OnMouseWheel", function() RO.ScrollRight(arg1) end)
    RO.roff = 0
    function RO.ScrollRight(d)
      RO.roff = math.max(0, math.min((RO.rcount or 0) - NR, (RO.roff or 0) - d * 3))
      RO.PaintRight()
    end
    RO.empty = Fs(right, 12, K.dim[1], K.dim[2], K.dim[3])
    RO.empty:SetPoint("TOP", heads, "BOTTOM", 0, -40)
    RO.empty:SetWidth(RW - 60)
    RO.empty:SetJustifyH("CENTER")

    -- foot: only my schools, the legend
    local foot = CreateFrame("Frame", nil, right)
    foot:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 1, 1)
    foot:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -1, 1)
    foot:SetHeight(34)
    local fl = Tex(foot, "ARTWORK", K.line[1], K.line[2], K.line[3], 1)
    fl:SetHeight(1)
    fl:SetPoint("TOPLEFT", foot, "TOPLEFT", 8, 0)
    fl:SetPoint("TOPRIGHT", foot, "TOPRIGHT", -8, 0)
    local mine = W.CheckPill(foot)
    mine:SetPoint("LEFT", foot, "LEFT", 14, 0)
    mine:SetScript("OnClick", function()
      C.rinse.onlymine = this:GetChecked() and "1" or "0"
      RO.Paint()
    end)
    RO.mine = mine
    local ml = Fs(foot, 11)
    ml:SetPoint("LEFT", mine, "RIGHT", 8, 0)
    ml:SetText("Only schools I can cure")
    local legend = Fs(foot, 10, K.dim[1], K.dim[2], K.dim[3])
    legend:SetPoint("RIGHT", foot, "RIGHT", -12, 0)
    legend:SetJustifyH("RIGHT")
    legend:SetText("|cff40d977Green|r = on   *  = learned in game   Wheel to scroll")
    RO.Paint()
  end

  function RO.ScopeText(key, name, kind)
    local out = ""
    for _, c in ipairs(R.CLASSES) do
      if R.ScopeGet(key, name, kind, c) then
        out = out .. (out ~= "" and ", " or "") .. "|cff" .. R.CLASSHEX[c] .. R.CLASSNAME[c] .. "|r"
      end
    end
    return out ~= "" and out or "everyone"
  end
  local function ScopeCount(key, name, kind)
    local n = 0
    for _, c in ipairs(R.CLASSES) do if R.ScopeGet(key, name, kind, c) then n = n + 1 end end
    return n
  end
  function RO.ClassMenu(anchor, row)
    if not row.spell then return end
    local key, name = row.key, row.spell.name
    local opts = { { label = "Cure first only for", group = true } }
    for _, c in ipairs(R.CLASSES) do
      local on = R.ScopeGet(key, name, "pc", c)
      table.insert(opts, { key = "pc:" .. c, label = (on and "|cff40d977[x]|r " or "|cff666e7a[  ]|r ") .. "|cff" .. R.CLASSHEX[c] .. R.CLASSNAME[c] .. "|r" })
    end
    table.insert(opts, { key = "pc:clear", label = "|cffaaaaaaEveryone (clear)|r" })
    table.insert(opts, { label = "Hide only for", group = true })
    for _, c in ipairs(R.CLASSES) do
      local on = R.ScopeGet(key, name, "hc", c)
      table.insert(opts, { key = "hc:" .. c, label = (on and "|cff40d977[x]|r " or "|cff666e7a[  ]|r ") .. "|cff" .. R.CLASSHEX[c] .. R.CLASSNAME[c] .. "|r" })
    end
    local m = W.Menu(anchor, opts, 190, function(v)
      local _, _, kind, c = string.find(v, "^(%a+):(%a+)$")
      if not kind then return end
      if c == "clear" then R.ScopeClear(key, name, kind)
      else R.ScopeSet(key, name, kind, c, not R.ScopeGet(key, name, kind, c)) end
      RO.Paint()
    end)
    if m and m.Show then m:Show() end
  end

  function RO.PaintLeft()
    if not RO.lrows then return end
    local entries = {}
    for _, z in ipairs(RO.Zones()) do
      table.insert(entries, { zone = z })
      if RO.open[z] then
        for _, b in ipairs(RO.Bosses(z)) do table.insert(entries, { zone = z, boss = b }) end
      end
    end
    RO.lcount = table.getn(entries)
    local off = RO.loff or 0
    for i, b in ipairs(RO.lrows) do
      local e = entries[i + off]
      b.entry = e
      if e then
        b.icon:ClearAllPoints()
        b.dot:ClearAllPoints()
        b.text:ClearAllPoints()
        if e.boss then
          local key = RO.KeyOf(e.zone, e.boss)
          local n = RO.Count(e.zone, e.boss)
          local sel = RO.zone == e.zone and RO.boss == e.boss
          local live = key and R.active and R.active[key]
          b.icon:Hide()
          b.dot:Show()
          b.dot:SetPoint("LEFT", b, "LEFT", 26, 0)
          if live then b.dot:SetVertexColor(.25, .85, .47, 1)
          elseif sel then b.dot:SetVertexColor(K.accent[1], K.accent[2], K.accent[3], 1)
          else b.dot:SetVertexColor(.35, .36, .4, 1) end
          b.text:SetPoint("LEFT", b.dot, "RIGHT", 8, 0)
          b.text:SetPoint("RIGHT", b.count, "LEFT", -4, 0)
          b.text:SetFont(W.UIFont(), 11, "")
          b.text:SetText(e.boss)
          if n > 0 then b.text:SetTextColor(.92, .92, .93) else b.text:SetTextColor(.45, .46, .5) end
          b.count:SetText(n > 0 and n or "")
          if sel then b.sel:Show() b.mark:Show() else b.sel:Hide() b.mark:Hide() end
        else
          b.dot:Hide()
          b.icon:Show()
          b.icon:SetTexture(RO.ZoneIcon(e.zone))
          b.icon:SetPoint("LEFT", b, "LEFT", 6, 0)
          b.text:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
          b.text:SetPoint("RIGHT", b.count, "LEFT", -4, 0)
          b.text:SetFont(W.UIFont(), 12, "")
          b.text:SetText(RO.ZoneLabel(e.zone))
          if RO.zone == e.zone then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(.82, .83, .86) end
          b.count:SetText(RO.open[e.zone] and "-" or "+")
          b.sel:Hide()
          b.mark:Hide()
        end
        b:Show()
      else
        b:Hide()
      end
    end
  end

  function RO.PaintRight()
    if not RO.rrows then return end
    local zone, boss = RO.zone, RO.boss
    local ban = RO.banner
    local key = zone and boss and RO.KeyOf(zone, boss)
    local rows = {}
    if zone and boss then
      ban.art:SetTexture(RO.ZoneArt(zone))
      ban.icon:SetTexture(RO.ZoneIcon(zone))
      ban.zone:SetText(string.upper(RO.ZoneLabel(zone)))
      ban.title:SetText(boss)
      if not key then
        ban.sub:SetText("|cffff8c4dCounts everywhere|r - battlegrounds, arenas and the open world too.")
      elseif R.IsTrash(boss) then
        ban.sub:SetText("Counts in " .. zone .. " while none of its bosses is being fought.")
      else
        ban.sub:SetText("Counts only while you fight " .. boss .. " - nowhere else, never in PvP.")
      end
      ban.live:SetText(key and R.active and R.active[key] and "LIVE NOW" or "")
      local spells = RO.Spells(zone, boss)
      for _, sc in ipairs({ "Magic", "Curse", "Disease", "Poison", "Snare", "Unknown" }) do
        if Visible(sc) then
          local group = {}
          for _, s in ipairs(spells) do if s.school == sc then table.insert(group, s) end end
          if table.getn(group) > 0 then
            table.sort(group, function(a, b) return a.name < b.name end)
            table.insert(rows, { head = sc, n = table.getn(group) })
            for _, s in ipairs(group) do table.insert(rows, { spell = s }) end
          end
        end
      end
    else
      ban.art:SetTexture(GLUE .. "LoadScreenDungeon")
      ban.icon:SetTexture(ICON .. "INV_Misc_Book_09")
      ban.zone:SetText("BOSS LISTS")
      ban.title:SetText("Pick a boss")
      ban.sub:SetText("Open a raid or dungeon on the left, then pick a boss.")
      ban.live:SetText("")
    end
    RO.rcount = table.getn(rows)
    local off = RO.roff or 0
    local icons = R.Icons()
    local zebra = 0
    for i, r in ipairs(RO.rrows) do
      local e = rows[i + off]
      r.key = key
      r.spell = e and e.spell
      if e and e.head then
        local c = R.COLOR[e.head] or R.COLOR.Unknown
        r.hicon:SetTexture(R.SCHOOLICON[e.head])
        r.hicon:Show()
        r.htext:SetText("|cff" .. c[4] .. e.head .. "|r  |cff8a8f99" .. e.n .. "|r")
        r.htext:Show()
        r.hline:SetVertexColor(c[1], c[2], c[3], .35)
        r.hline:Show()
        r.zebra:Hide() r.edge:Hide() r.iconbg:Hide() r.icon:Hide() r.name:Hide() r.note:Hide() r.cls:Hide()
        for _, pl in ipairs(r.pills) do pl:Hide() end
        r:Show()
        zebra = 0
      elseif e then
        local s = e.spell
        local c = R.COLOR[s.school] or R.COLOR.Unknown
        r.hicon:Hide() r.htext:Hide() r.hline:Hide()
        zebra = zebra + 1
        if math.mod(zebra, 2) == 0 then r.zebra:Show() else r.zebra:Hide() end
        r.edge:SetVertexColor(c[1], c[2], c[3], 1)
        r.edge:Show()
        r.iconbg:SetVertexColor(c[1], c[2], c[3], .9)
        r.iconbg:Show()
        r.icon:SetTexture(icons[s.name] or R.SCHOOLICON[s.school] or R.SCHOOLICON.Unknown)
        r.icon:Show()
        r.name:SetText(s.name .. (s.learned and " |cff8a8f99*|r" or ""))
        r.name:Show()
        r.note:SetText(s.note or (s.learned and "Learned in game" or ""))
        r.note:Show()
        for j, c2 in ipairs(RO.COLS) do
          local pl = r.pills[j]
          pl:SetChecked(RO.Get(key, s.name, c2[1]))
          pl:Show()
        end
        local np, nh = ScopeCount(key, s.name, "pc"), ScopeCount(key, s.name, "hc")
        if np + nh > 0 then
          r.cls.t:SetText("|cffffd24d" .. (np + nh) .. " set|r")
        else
          r.cls.t:SetText("|cff8a8f99All|r")
        end
        r.cls:Show()
        r:Show()
      else
        r:Hide()
      end
    end
    if zone and boss and RO.rcount == 0 then
      RO.empty:SetText(C.rinse.onlymine == "1" and "Nothing here your class can cure.\nSwitch off \"Only schools I can cure\" below to see the rest."
        or "Nothing this boss puts on your raid can be cured.\nDebuffs seen in this fight are added here by themselves.")
      RO.empty:Show()
    else
      RO.empty:Hide()
    end
    if RO.mine then RO.mine:SetChecked(C.rinse.onlymine == "1") end
  end
  function RO.Paint()
    RO.PaintLeft()
    RO.PaintRight()
  end

  -- ---------------------------------------------------------------- pages

  local function General(p)
    Heading(p, "OctoRinse", "Strips debuffs off your group with one key: the most important first, the right spell, the "
      .. "right player, in range. UpsiRinse built into pfUI Octo, with its boss lists. Every UpsiRinse setting is here.")
    if not R then Off(p) return end
    W.Pin(p, "Your bar", "The bar with made-up debuffs. Test shows it on the screen for 20 seconds; Move frames lets you "
      .. "drag it.", function(pp)
      local status = W.Row(pp, 46, 0, 4)
      local t = Fs(status, 12)
      t:SetPoint("TOPLEFT", status, "TOPLEFT", 10, -4)
      t:SetPoint("RIGHT", status, "RIGHT", -10, 0)
      local t2 = Fs(status, 11, K.dim[1], K.dim[2], K.dim[3])
      t2:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
      t2:SetPoint("RIGHT", status, "RIGHT", -10, 0)
      local function Paint()
        local cures = ""
        for _, sc in ipairs(R.SCHOOLS) do
          if R.usable[sc] then
            cures = cures .. (cures ~= "" and "   " or "") .. "|cff" .. R.COLOR[sc][4] .. sc .. "|r " .. R.usable[sc]
          end
        end
        t:SetText(cures ~= "" and ("You cure:  " .. cures) or "|cffff8c4dYour class has no cure spell: the bar stays hidden.|r")
        local now
        for key in pairs(R.active or {}) do
          local _, _, bn = string.find(key, "%^(.+)$")
          if bn and (not now or R.IsTrash(now)) then now = bn end
        end
        local client = (_G.C_UnitAuras and "ClassicAPI auras" or SUPERWOW_VERSION and "SuperWoW auras" or "tooltip scan")
          .. (R.unitxp and ", UnitXP range" or (_G.C_UnitAuras or SUPERWOW_VERSION) and ", DLL range" or "")
          .. (SUPERWOW_VERSION and ", casts without a target swap" or "")
        t2:SetText((now and ("Boss lists on now: |cffffd24d" .. now .. "|r.  ") or "No boss list on now.  ") .. "Using " .. client .. ".")
      end
      Paint()
      status:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + 1
        Paint()
      end)
      W.Buttons(pp, {
        { "Test on my bar (20 s)", function() if R.testUntil and GetTime() < R.testUntil then R.testUntil = 0 else R.Test(20) end end, nil,
          "Shows the bar with made-up debuffs for 20 seconds. Click again to stop.",
          on = function() return R.testUntil and GetTime() < R.testUntil end },
        { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, nil, "Drag the bar where you want it." },
        { "Reset position", function() R.ResetPosition() end, nil, "Puts the bar back on its first place." },
        { "Boss lists", function() O:Open("rinsebosses") end, nil, "What to skip, hide or cure first, boss by boss." },
      })
    end)

    -- (20 Nov 2026, user: "our rinse is quite hard to see give it different layout options in the menu") a look in one
    -- click; the bar shows on the screen for 12 s so you see it at once
    W.Card(p, "Look", { icon = ICON .. "INV_Misc_Gem_Pearl_04", tip = "How the bar looks. Picking one shows the bar with made-up "
      .. "debuffs for 12 seconds. Everything under The bar still changes on top of it." })
    W.Live(p, function()
      local L = R.Look and R.Look()
      return "Now: |cffffffff" .. (L and L.label or "pfUI Octo") .. "|r   " .. (L and ("|cff888888" .. L.tip .. "|r") or "")
    end)
    local tiles = {}
    for _, l in ipairs(R.LOOKS or {}) do
      local look = l
      table.insert(tiles, { look.label, look.tip, ICON .. ({ octo = "Spell_Holy_DispelMagic", bars = "INV_Misc_Bandage_15",
        bright = "Spell_Holy_SearingLight", compact = "INV_Misc_Note_01", icons = "INV_Misc_Gem_Variety_01" })[look.key],
        function()
          C.rinse.look = look.key
          C.rinse.border = tostring(look.rim or 0)
          R.ApplyLayout()
          R.Test(12)
          O:Refresh()
        end, "pick" })
      if table.getn(tiles) == 3 then W.Tiles(p, tiles) tiles = {} end
    end
    if table.getn(tiles) > 0 then W.Tiles(p, tiles) end

    -- (17 Nov 2026, user: "this bar should be fully hidable until hover over fast to do in options") first card
    W.Card(p, "Title bar", { icon = ICON .. "INV_Misc_Spyglass_02", tip = "The strip with OctoRinse's name and the Boss lists / "
      .. "Players / Options pictures. With no debuffs up, it is all you see of the bar." })
    Chk(p, "Show the title bar", "Off: no title at all; reach its pages with /orinse bosses, quick, options.", "header")
    Chk(p, "Hidden until the mouse is over it", "The title is invisible and fades in while your mouse is on it (or the "
      .. "quick menu is open). Its buttons still work when it shows.", "headhover")

    W.Card(p, "Where it runs", { icon = ICON .. "INV_Misc_Map_01", tip = "The bar works only in the places switched on here." })
    Chk(p, "Raids", nil, "inraid")
    Chk(p, "Dungeons", nil, "indungeon")
    Chk(p, "Battlegrounds", nil, "inbg")
    Chk(p, "Arenas", nil, "inarena")
    Chk(p, "Open world", "Everywhere else: questing, world bosses, duels.", "inworld")

    W.Card(p, "Curing", { icon = ICON .. "Spell_Holy_DispelMagic" })
    Chk(p, "Show debuffs already under Abolish", "Off: a poison or disease on a player who has Abolish Poison / Disease "
      .. "running is left to it (UpsiRinse's Ignore Abolish).", "abolish")
    Chk(p, "Pets", "Cure pets too. Off: only a pet's Cure first debuffs show.", "pets", function() R.UpdatePrio() end)
    if R.class == "PRIEST" then
      Chk(p, "No diseases in Shadowform", "Shadowform cannot cast Abolish / Cure Disease.", "shadowform")
    end
    if R.class == "SHAMAN" then
      Chk(p, "Cleansing totems", "For your own group, drop Poison / Disease Cleansing Totem first: totems are off the global "
        .. "cooldown and keep curing by themselves. Not offered again for 5 s after a drop.", "totems")
    end

    W.Card(p, "Schools to show", { icon = ICON .. "Spell_Holy_Purify", tip = "Schools switched off are never shown. "
      .. "Schools your class cannot cure are always off." })
    for _, sc in ipairs(R.SCHOOLS) do
      local s = sc
      local can = R.CanDispel(s)
      W.Check(p, "|cff" .. R.COLOR[s][4] .. s .. "|r" .. (can and "" or " |cff666e7a(not your class)|r"),
        can and ("Show " .. s .. " debuffs.") or "Your class has no spell for it.",
        function() return can and R.Cfg("hide")[s] ~= "1" end,
        function(v)
          if not can then return end
          R.Cfg("hide")[s] = v and "0" or "1"
          R.UpdateSpells()
          R.dirty = true
        end)
    end

    W.Card(p, "The bar", { icon = ICON .. "INV_Misc_Spyglass_02" })
    Sld(p, "Debuffs shown", "How many rows the bar has.", 1, 20, 1, "buttons")
    Sld(p, "Width", nil, 140, 400, 2, "width", function(v) return v .. " px" end)
    Sld(p, "Row height", nil, 20, 48, 1, "rowh", function(v) return v .. " px" end)
    Sld(p, "Gap", nil, 0, 10, 1, "spacing", function(v) return v .. " px" end)
    Sld(p, "Text size", nil, 8, 18, 1, "fontsize")
    -- (the same size layout mode sets: never two scales fighting)
    W.Slider(p, "Scale", "The same size as dragging the wheel over the bar in layout mode.", .5, 2, .05,
      function() return tonumber(C.rinse.scale) or 1 end, function(v) R.SetScale(v) end,
      function(v) return string.format("%.2f", v) .. "x" end)
    Sld(p, "Opacity", nil, .1, 1, .05, "alpha", function(v) return math.floor(v * 100 + .5) .. "%" end)
    Chk(p, "Background", nil, "backdrop")
    Chk(p, "Grow upwards", "The title at the bottom, rows above it.", "flip")
    -- (20 Nov 2026) easier to see
    Sld(p, "Border", "A border in the debuff school's colour round each row (0 = none).", 0, 4, 1, "border",
      function(v) return v == 0 and "none" or (v .. " px") end)
    Sld(p, "Out of range", "How see-through a row is while its player is out of your cure's range.", .1, 1, .05, "oor",
      function(v) return math.floor(v * 100 + .5) .. "%" end)
    Chk(p, "Pulse the top row", "The next cure - the top row - softly pulses in its school's colour.", "pulse")

    -- (20 Nov 2026, a druid friend: talents that lengthen his cures' range were not counted)
    W.Card(p, "Range", { icon = ICON .. "Ability_Hunter_SniperShot", tip = "When a player counts as in range of your cure." })
    W.Live(p, function()
      if _G.C_Spell and _G.C_Spell.IsSpellInRange then
        return "|cff40d977ClassicAPI:|r the same range check as your action bar's range colour - talents and all."
      end
      local parts = {}
      for _, sc in ipairs(R.SCHOOLS or {}) do
        local sp = R.usable and R.usable[sc]
        if sp and R.Range then table.insert(parts, sp .. " " .. R.Range(sp) .. " yd") end
      end
      return "Without ClassicAPI: each cure's range from its spell: " .. (table.getn(parts) > 0 and table.concat(parts, ", ") or "none") .. "."
    end)
    Sld(p, "My cure range", "Yards, when the range read from your spell is wrong for you (a talent the tooltip does not "
      .. "show). 0 = read it from the spell. With ClassicAPI the action bar's own check wins.", 0, 50, 1, "range",
      function(v) return v == 0 and "from the spell" or (v .. " yd") end)

    W.Card(p, "Messages and sounds", { icon = ICON .. "INV_Misc_Note_01" })
    Chk(p, "Say what was cured", "A chat line for each cure (or when a queued cure goes off, with nampower).", "print")
    Chk(p, "In MikSBT", "The line goes to MikScrollingBattleText when it is loaded.", "msbt")
    Chk(p, "Sounds", "A bell when the first debuff shows, a buzz when the player is out of range.", "sound")

    W.Card(p, "Keys and commands", { icon = ICON .. "INV_Misc_Key_01" })
    W.KeyBind(p, "Cure the top debuff", "The key healers spam: cures the first debuff that can go.", "PFRINSE")
    W.KeyBind(p, "Open the boss lists", nil, "PFRINSEBOSSES")
    W.Note(p, "/orinse cures the top debuff (also /rinse and the Rinse() macro while UpsiRinse is not loaded). "
      .. "/orinse bosses, players, options, test, versions.")
    W.Buttons(p, {
      { "Version check", function() R.VersionCheck() end, nil, "Who in your group runs Rinse, UpsiRinse or OctoRinse." },
      { "Copy from UpsiRinse again", function()
        if not R.Import(true) then DEFAULT_CHAT_FRAME:AddMessage("|cff33b3ffOctoRinse|r: UpsiRinse is not loaded - switch it on for one login to copy from it.") end
        R.RebuildSkip() R.ApplyLayout() RO.Paint()
      end, nil, "Copies UpsiRinse's settings, lists and learned debuffs again (it must be loaded)." },
      { "Boss defaults again", function() R.Seed(true) RO.Paint() end, nil,
        "Puts UpsiRinse's shipped ticks back on their bosses (Wyvern Sting on Huhuran...). Your own ticks stay." },
    })
  end

  local function Bosses(p)
    Heading(p, "Boss lists", "Every raid and dungeon from UpsiRinse with each boss's curable debuffs. A switch here counts only "
      .. "in that fight: while the boss or its adds are in combat with you, or the debuff came from them. Trash counts in its "
      .. "zone while no boss is up. \"Everywhere\" holds the lists that count in every fight, PvP too.")
    if not R then Off(p) return end
    if not RO.zone then
      local z, b = RO.PickHere()
      if z then RO.zone, RO.boss, RO.open[z] = z, b, true end
    end
    Browser(p)
  end

  -- a list of names with remove buttons and an add box: get() = the table, kind "set" (name -> "1") or "class"
  local function NameList(p, title, icon, tip, tbl, onChange)
    W.Card(p, title, { icon = ICON .. icon, tip = tip })
    local holder = W.Row(p, 10, 0, 4)
    holder.rows = {}
    local function Rebuild()
      local names = {}
      for n, v in pairs(tbl()) do if v == "1" or v == true then table.insert(names, n) end end
      table.sort(names)
      for i, r in ipairs(holder.rows) do r:Hide() end
      for i, n in ipairs(names) do
        local r = holder.rows[i]
        if not r then
          r = CreateFrame("Frame", nil, holder)
          r:SetHeight(22)
          r.t = Fs(r, 12)
          r.t:SetPoint("LEFT", r, "LEFT", 10, 0)
          r.x = CreateFrame("Button", nil, r)
          r.x:SetWidth(18)
          r.x:SetHeight(18)
          r.x:SetPoint("RIGHT", r, "RIGHT", -8, 0)
          r.x.t = Fs(r.x, 12, 1, .4, .4)
          r.x.t:SetAllPoints(r.x)
          r.x.t:SetJustifyH("CENTER")
          r.x.t:SetText("x")
          r.z = Tex(r, "BACKGROUND", 1, 1, 1, .025)
          r.z:SetAllPoints(r)
          holder.rows[i] = r
        end
        local col = R.COLOR[n]
        r.t:SetText(col and ("|cff" .. col[4] .. n .. "|r |cff8a8f99(a whole school)|r") or n)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(i - 1) * 22)
        r:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
        if math.mod(i, 2) == 0 then r.z:Show() else r.z:Hide() end
        local name = n
        r.x:SetScript("OnClick", function()
          tbl()[name] = "0"
          if onChange then onChange() end
          Rebuild()
        end)
        W.Tip(r.x, "Remove", "Takes " .. n .. " off this list.")
        r:Show()
      end
      if table.getn(names) == 0 then
        holder.none = holder.none or Fs(holder, 11, K.dim[1], K.dim[2], K.dim[3])
        holder.none:SetPoint("TOPLEFT", holder, "TOPLEFT", 10, -4)
        holder.none:SetText("Empty.")
        holder.none:Show()
      elseif holder.none then
        holder.none:Hide()
      end
      holder:SetHeight(math.max(22, table.getn(names) * 22))
      if p.body then W.Measure(p) end
    end
    holder.Rebuild = Rebuild
    Rebuild()
    W.Edit(p, "Add a debuff", "The exact name, then Enter.", function() return "" end, function(v)
      if v and v ~= "" then
        tbl()[v] = "1"
        if onChange then onChange() end
        Rebuild()
      end
    end, 260)
    return holder
  end

  local function Everywhere(p)
    Heading(p, "Everywhere", "Lists that count in every fight - bosses, trash, battlegrounds, the open world. Use the Boss "
      .. "lists for anything that belongs to one fight. These were UpsiRinse's Blacklisted, Hidden and Class hidden lists.")
    if not R then Off(p) return end
    NameList(p, "Skip school", "Spell_Shadow_SacrificialShield", "Never cured, and nothing else of its school on that player either.",
      function() return R.Cfg("black") end, function() R.dirty = true end)
    NameList(p, "Hidden", "Spell_Shadow_Charm", "Only this debuff is left alone. A school name (Magic...) hides the whole school.",
      function() return R.Cfg("hide") end, function() R.UpdateSpells() R.dirty = true end)
    NameList(p, "Cure first", "Spell_Holy_SealOfSacrifice", "Cured before anything else, everywhere.",
      function() return R.Cfg("priority") end, function() R.dirty = true end)
    W.Card(p, "Hidden for one class", { icon = ICON .. "Ability_Druid_CatForm", tip = "Left alone on that class only "
      .. "(Ignite Mana on warriors and rogues)." })
    local tabs = {}
    for _, c in ipairs(R.CLASSES) do table.insert(tabs, { key = c, label = "|cff" .. R.CLASSHEX[c] .. R.CLASSNAME[c] .. "|r" }) end
    RO.hcClass = RO.hcClass or "WARRIOR"
    local list
    W.Dropdown(p, "Class", nil, tabs, function() return RO.hcClass end, function(v)
      RO.hcClass = v
      if list then list.Rebuild() end
    end)
    local hc = R.Cfg("hideclass")
    list = NameList(p, "Hidden on that class", "Spell_Shadow_GatherShadows", nil, function()
      hc[RO.hcClass] = hc[RO.hcClass] or {}
      return hc[RO.hcClass]
    end, function() R.dirty = true end)
  end

  -- players: cure first (in order) and never cure
  local function PlayerList(p, title, icon, tip, field)
    W.Card(p, title, { icon = ICON .. icon, tip = tip })
    local holder = W.Row(p, 22, 0, 4)
    holder.rows = {}
    local function Rebuild()
      local list = R.Cfg(field)
      for _, r in ipairs(holder.rows) do r:Hide() end
      for i, e in ipairs(list) do
        local r = holder.rows[i]
        if not r then
          r = CreateFrame("Frame", nil, holder)
          r:SetHeight(22)
          r.n = Fs(r, 11, K.dim[1], K.dim[2], K.dim[3])
          r.n:SetPoint("LEFT", r, "LEFT", 8, 0)
          r.n:SetWidth(22)
          r.t = Fs(r, 12)
          r.t:SetPoint("LEFT", r.n, "RIGHT", 4, 0)
          r.z = Tex(r, "BACKGROUND", 1, 1, 1, .025)
          r.z:SetAllPoints(r)
          r.btn = {}
          for j, s in ipairs({ "x", "v", "^" }) do
            local b = CreateFrame("Button", nil, r)
            b:SetWidth(20)
            b:SetHeight(18)
            if j == 1 then b:SetPoint("RIGHT", r, "RIGHT", -8, 0) else b:SetPoint("RIGHT", r.btn[j - 1], "LEFT", -4, 0) end
            W.Flat(b, K.btn, 1, K.line)
            b.t = Fs(b, 11, j == 1 and 1 or .85, j == 1 and .4 or .86, j == 1 and .4 or .9)
            b.t:SetAllPoints(b)
            b.t:SetJustifyH("CENTER")
            b.t:SetText(s)
            r.btn[j] = b
          end
          holder.rows[i] = r
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(i - 1) * 22)
        r:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
        r.n:SetText(i .. ".")
        r.t:SetText("|cff" .. (R.CLASSHEX[e.class] or "ffffff") .. (e.name or "?") .. "|r")
        if math.mod(i, 2) == 0 then r.z:Show() else r.z:Hide() end
        local idx = i
        r.btn[1]:SetScript("OnClick", function() table.remove(list, idx) R.RebuildSkip() R.UpdatePrio() Rebuild() end)
        r.btn[2]:SetScript("OnClick", function()
          if list[idx + 1] then list[idx], list[idx + 1] = list[idx + 1], list[idx] R.UpdatePrio() Rebuild() end
        end)
        r.btn[3]:SetScript("OnClick", function()
          if idx > 1 then list[idx], list[idx - 1] = list[idx - 1], list[idx] R.UpdatePrio() Rebuild() end
        end)
        r:Show()
      end
      if table.getn(list) == 0 then
        holder.none = holder.none or Fs(holder, 11, K.dim[1], K.dim[2], K.dim[3])
        holder.none:SetPoint("TOPLEFT", holder, "TOPLEFT", 10, -4)
        holder.none:SetText("Nobody yet.")
        holder.none:Show()
      elseif holder.none then
        holder.none:Hide()
      end
      holder:SetHeight(math.max(22, table.getn(list) * 22))
      if p.body then W.Measure(p) end
    end
    Rebuild()
    local function Add(name, class)
      if not name or name == "" then return end
      local list = R.Cfg(field)
      for _, e in ipairs(list) do if e.name == name then return end end
      if not class then
        local u = R.UnitOf(name)
        if u then local _, c = UnitClass(u) class = c end
      end
      table.insert(list, { name = name, class = class or "UNKNOWN" })
    end
    local function Done() R.RebuildSkip() R.UpdatePrio() Rebuild() end
    local function Roster(test)
      if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
          local n, _, g, _, _, c = GetRaidRosterInfo(i)
          if n and test(g, c) then Add(n, c) end
        end
      else
        for _, u in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
          if UnitExists(u) then
            local _, c = UnitClass(u)
            if test(1, c) then Add(UnitName(u), c) end
          end
        end
      end
      Done()
    end
    W.Edit(p, "Add a player", "The name, then Enter.", function() return "" end, function(v) Add(v) Done() end, 200)
    W.Buttons(p, {
      { "Add my target", function()
        if UnitExists("target") and UnitIsPlayer("target") and UnitIsFriend("player", "target") then
          local _, c = UnitClass("target")
          Add(UnitName("target"), c)
          Done()
        end
      end, nil, "Adds the friendly player you have targeted." },
      { "Add a group...", function()
        local opts = {}
        for g = 1, 8 do table.insert(opts, { key = g, label = "Group " .. g }) end
        local m = W.Menu(this, opts, 120, function(g) Roster(function(gg) return gg == g end) end)
        if m and m.Show then m:Show() end
      end, nil, "Everyone in one raid group (a party is group 1)." },
      { "Add a class...", function()
        local opts = {}
        for _, c in ipairs(R.CLASSES) do table.insert(opts, { key = c, label = "|cff" .. R.CLASSHEX[c] .. R.CLASSNAME[c] .. "|r" }) end
        local m = W.Menu(this, opts, 140, function(c) Roster(function(_, cc) return cc == c end) end)
        if m and m.Show then m:Show() end
      end, nil, "Everyone of one class in your group." },
      { "Clear", function()
        local list = R.Cfg(field)
        for i = table.getn(list), 1, -1 do table.remove(list, i) end
        Done()
      end, nil, "Empties this list.", role = "danger" },
    })
  end
  local function Players(p)
    Heading(p, "Players", "Who is cured first, in this order, and who is never cured. Everyone else is checked in a "
      .. "shuffled order, so the healers running OctoRinse do not all go for the same player.")
    if not R then Off(p) return end
    PlayerList(p, "Cure first", "Spell_Holy_PrayerOfHealing", "Checked first, top to bottom (tanks, other healers).", "prio")
    PlayerList(p, "Never cure", "Spell_Shadow_AntiShadow", "Left out of every scan (a mind-controlled player, someone who "
      .. "wants to keep a debuff).", "skip")
  end

  O:AddPage("OctoRinse", "rinsegeneral", "General", General)
  O:AddPage("OctoRinse", "rinsebosses", "Boss lists", Bosses)
  O:AddPage("OctoRinse", "rinseeverywhere", "Everywhere", Everywhere)
  O:AddPage("OctoRinse", "rinseplayers", "Players", Players)
end)
