-- octo (26 Nov 2026, Wolfahrt: "my loading screen is now taking a looong time before connecting ... I suppose this comes
-- from PFUI"): a load clock with the client's own precise timer (debugprofilestop, in WoW.exe). Marks along the way
-- (pfUI's first file, pfQuest's database and clean-ups, all files read, modules, skins, in the world) and each module's
-- start; /pfload prints where the time went (kept in pfUI_cache.loadprof for the next session too).
PFUI_LOADCLOCK = { marks = {}, mods = {} }
function pfUI_LoadMark(name)
  if not debugprofilestop then return end
  table.insert(PFUI_LOADCLOCK.marks, { name, debugprofilestop() })
end
pfUI_LoadMark("pfUI's first file")

SLASH_RELOAD1 = '/rl'
function SlashCmdList.RELOAD(msg, editbox)
  ReloadUI()
end

SLASH_PFUI1 = '/pfui'
function SlashCmdList.PFUI(msg, editbox)
  -- octo: "/pfui install" reruns the installer, "/pfui move" is /moveui
  local cmd = string.lower(msg or "")
  if cmd == "install" and pfUI.firstrun then
    pfUI.gui:Hide()
    pfUI.firstrun:Restart()
    return
  elseif (cmd == "move" or cmd == "moveui" or cmd == "unlock") and pfUI.unlock then
    if pfUI.unlock:IsShown() then pfUI.unlock:Hide() else pfUI.unlock:Show() end
    return
  elseif (cmd == "export" or cmd == "import" or cmd == "share") and pfShare then
    pfShare:Show()
    return
  end

  if pfUI.gui:IsShown() then
    pfUI.gui:Hide()
  else
    pfUI.gui:Show()
  end
end

SLASH_GM1, SLASH_GM2 = '/gm', '/support'
function SlashCmdList.GM(msg, editbox)
  ToggleHelpFrame(1)
end

pfUI = CreateFrame("Frame", nil, UIParent)
pfUI:RegisterEvent("ADDON_LOADED")
pfUI:RegisterEvent("PLAYER_ENTERING_WORLD")

-- the load clock's report: the steps between marks, then the slowest module starts
function pfUI.LoadReport()
  local lc = PFUI_LOADCLOCK
  local out = {}
  local m = lc.marks
  for i = 2, table.getn(m) do table.insert(out, { m[i][1], m[i][2] - m[i - 1][2] }) end
  local mods = {}
  for name, ms in pairs(lc.mods) do table.insert(mods, { name, ms }) end
  table.sort(mods, function(a, b) return a[2] > b[2] end)
  local total = table.getn(m) > 1 and (m[table.getn(m)][2] - m[1][2]) or 0
  return out, mods, total
end
function pfUI.LoadReportSave()
  if not pfUI_cache then return end
  local steps, mods, total = pfUI.LoadReport()
  local top = {}
  for i = 1, math.min(15, table.getn(mods)) do top[i] = mods[i] end
  pfUI_cache.loadprof = { steps = steps, mods = top, total = total, when = date and date("%d %b %H:%M") or "" }
end
SLASH_PFLOAD1 = '/pfload'
function SlashCmdList.PFLOAD()
  local steps, mods, total = pfUI.LoadReport()
  if table.getn(steps) == 0 and pfUI_cache and pfUI_cache.loadprof then
    local lp = pfUI_cache.loadprof
    steps, mods, total = lp.steps or {}, lp.mods or {}, lp.total or 0
  end
  local p = function(s) DEFAULT_CHAT_FRAME:AddMessage(s) end
  p(string.format("|cff33ffccpfUI Octo|r load time: |cffffffff%.1f s|r from pfUI's first file to the world", total / 1000))
  for _, s in ipairs(steps) do p(string.format("   %6.0f ms  up to: %s", s[2], s[1])) end
  p("|cff33ffccslowest module starts:|r")
  for i = 1, math.min(12, table.getn(mods)) do p(string.format("   %6.0f ms  %s", mods[i][2], mods[i][1])) end
end

-- setup bootvar
pfUI.bootup = true

-- initialize saved variables
pfUI_playerDB = {}
pfUI_config = {}
pfUI_init = {}
pfUI_profiles = {}
pfUI_addon_profiles = {}
pfUI_cache = {}

-- localization
pfUI_locale = {}
pfUI_translation = {}

-- initialize default variables
pfUI.cache = {}
pfUI.module = {}
pfUI.modules = {}
pfUI.skin = {}
pfUI.skins = {}
pfUI.environment = {}
pfUI.movables = {}
pfUI.version = {}
pfUI.hooks = {}
pfUI.env = {}

-- detect current addon path
local tocs = { "", "-master", "-tbc", "-wotlk" }
for _, name in pairs(tocs) do
  local current = string.format("pfUI%s", name)
  local _, title = GetAddOnInfo(current)
  if title then
    pfUI.name = current
    pfUI.path = "Interface\\AddOns\\" .. current
    break
  end
end

-- handle/convert media dir paths
pfUI.media = setmetatable({}, { __index = function(tab,key)
  local value = tostring(key)
  if strfind(value, "img:") then
    value = string.gsub(value, "img:", pfUI.path .. "\\img\\")
  elseif strfind(value, "font:") then
    value = string.gsub(value, "font:", pfUI.path .. "\\fonts\\")
  else
    value = string.gsub(value, "Interface\\AddOns\\pfUI\\", pfUI.path .. "\\")
  end
  rawset(tab,key,value)
  return value
end})

-- cache client version
local _, _, _, client = GetBuildInfo()
client = client or 11200

-- detect client expansion
if client >= 20000 and client <= 20400 then
  pfUI.expansion = "tbc"
  pfUI.client = client
elseif client >= 30000 and client <= 30300 then
  pfUI.expansion = "wotlk"
  pfUI.client = client
else
  pfUI.expansion = "vanilla"
  pfUI.client = client
end

-- setup pfUI namespace
setmetatable(pfUI.env, {__index = getfenv(0)})

function pfUI:UpdateColors()
  if pfUI.expansion == "vanilla" then
    -- update table to get unknown colors and blue shamans for vanilla
    RAID_CLASS_COLORS = {
      ["WARRIOR"] = { r = 0.78, g = 0.61, b = 0.43, colorStr = "ffc79c6e" },
      ["MAGE"]    = { r = 0.41, g = 0.8,  b = 0.94, colorStr = "ff69ccf0" },
      ["ROGUE"]   = { r = 1,    g = 0.96, b = 0.41, colorStr = "fffff569" },
      ["DRUID"]   = { r = 1,    g = 0.49, b = 0.04, colorStr = "ffff7d0a" },
      ["HUNTER"]  = { r = 0.67, g = 0.83, b = 0.45, colorStr = "ffabd473" },
      ["SHAMAN"]  = { r = 0.14, g = 0.35, b = 1.0,  colorStr = "ff0070de" },
      ["PRIEST"]  = { r = 1,    g = 1,    b = 1,    colorStr = "ffffffff" },
      ["WARLOCK"] = { r = 0.58, g = 0.51, b = 0.79, colorStr = "ff9482c9" },
      ["PALADIN"] = { r = 0.96, g = 0.55, b = 0.73, colorStr = "fff58cba" },
    }

    RAID_CLASS_COLORS = setmetatable(RAID_CLASS_COLORS, { __index = function(tab,key)
      return { r = 0.6,  g = 0.6,  b = 0.6,  colorStr = "ff999999" }
    end})
  end
end

function pfUI:UpdateFonts()
  -- abort when config is not ready yet
  if not pfUI_config or not pfUI_config.global then return end

  -- load font configuration
  local default, tooltip, unit, unit_name, combat
  if pfUI_config.global.force_region == "1" and GetLocale() == "zhCN" and pfUI.expansion == "vanilla" then
    -- force locale compatible fonts (zhCN 1.12)
    default = "Fonts\\FZXHLJW.TTF"
    tooltip = "Fonts\\FZXHLJW.TTF"
    combat = "Fonts\\FZXHLJW.TTF"
    unit = "Fonts\\FZXHLJW.TTF"
    unit_name = "Fonts\\FZXHLJW.TTF"
  elseif pfUI_config.global.force_region == "1" and GetLocale() == "zhCN" and pfUI.expansion == "tbc" then
    -- force locale compatible fonts (zhCN 2.4.3)
    default = "Fonts\\ZYHei.ttf"
    tooltip = "Fonts\\ZYHei.ttf"
    combat = "Fonts\\ZYKai_C.ttf"
    unit = "Fonts\\ZYKai_T.ttf"
    unit_name = "Fonts\\ZYHei.ttf"
  elseif pfUI_config.global.force_region == "1" and GetLocale() == "zhTW" and pfUI.expansion == "vanilla" then
    -- force locale compatible fonts (zhTW 1.12)
    default = "Fonts\\FZXHLJW.ttf"
    tooltip = "Fonts\\FZXHLJW.ttf"
    combat = "Fonts\\FZXHLJW.ttf"
    unit = "Fonts\\FZXHLJW.ttf"
    unit_name = "Fonts\\FZXHLJW.ttf"
  elseif pfUI_config.global.force_region == "1" and GetLocale() == "zhTW" and pfUI.expansion == "tbc" then
    -- force locale compatible fonts (zhTW 2.4.3)
    default = "Fonts\\bHEI01B.ttf"
    tooltip = "Fonts\\bHEI01B.ttf"
    combat = "Fonts\\bHEI01B.ttf"
    unit = "Fonts\\bHEI01B.ttf"
    unit_name = "Fonts\\bHEI01B.ttf"
  elseif pfUI_config.global.force_region == "1" and GetLocale() == "koKR" then
    -- force locale compatible fonts (koKR)
    default = "Fonts\\2002.TTF"
    tooltip = "Fonts\\2002.TTF"
    combat = "Fonts\\2002.TTF"
    unit = "Fonts\\2002.TTF"
    unit_name = "Fonts\\2002.TTF"
  else
    -- use default entries
    default = pfUI.media[pfUI_config.global.font_default]
    tooltip = pfUI.media[pfUI_config.tooltip.font_tooltip]
    combat = pfUI.media[pfUI_config.global.font_combat]
    unit = pfUI.media[pfUI_config.global.font_unit]
    unit_name = pfUI.media[pfUI_config.global.font_unit_name]
  end

  -- write setting shortcuts
  pfUI.font_default = default
  pfUI.font_combat = combat
  pfUI.font_unit = unit
  pfUI.font_unit_name = unit_name

  -- skip setting fonts, keep blizzard defaults
  if pfUI_config.global.font_blizzard == "1" then
    return
  end

  -- set game constants
  STANDARD_TEXT_FONT = default
  DAMAGE_TEXT_FONT   = combat
  NAMEPLATE_FONT     = default
  UNIT_NAME_FONT     = unit_name

  -- set dropdown font to default size
  UIDROPDOWNMENU_DEFAULT_TEXT_HEIGHT = 11

  -- change default game font objects
  SystemFont:SetFont(default, 15)
  GameFontNormal:SetFont(default, 12)
  GameFontBlack:SetFont(default, 12)
  GameFontNormalSmall:SetFont(default, 11)
  GameFontNormalLarge:SetFont(default, 16)
  GameFontNormalHuge:SetFont(default, 20)
  NumberFontNormal:SetFont(default, 14, "OUTLINE")
  NumberFontNormalSmall:SetFont(default, 14, "OUTLINE")
  NumberFontNormalLarge:SetFont(default, 16, "OUTLINE")
  NumberFontNormalHuge:SetFont(default, 30, "OUTLINE")
  QuestTitleFont:SetFont(default, 18)
  QuestFont:SetFont(default, 13)
  QuestFontHighlight:SetFont(default, 14)
  ItemTextFontNormal:SetFont(default, 15)
  MailTextFontNormal:SetFont(default, 15)
  SubSpellFont:SetFont(default, 12)
  DialogButtonNormalText:SetFont(default, 16)
  ZoneTextFont:SetFont(default, 34, "OUTLINE")
  SubZoneTextFont:SetFont(default, 24, "OUTLINE")
  GameTooltipText:SetFont(tooltip, pfUI_config.tooltip.font_tooltip_size)
  GameTooltipTextSmall:SetFont(tooltip, pfUI_config.tooltip.font_tooltip_size)
  GameTooltipHeaderText:SetFont(tooltip, pfUI_config.tooltip.font_tooltip_size + 1)
  WorldMapTextFont:SetFont(default, 102, "THICK")
  InvoiceTextFontNormal:SetFont(default, 12)
  InvoiceTextFontSmall:SetFont(default, 12)
  CombatTextFont:SetFont(combat, 25)
  ChatFontNormal:SetFont(default, 13, pfUI_config.chat.text.outline == "1" and "OUTLINE")

  if TextStatusBarTextSmall then -- does not exist in koKR
    TextStatusBarTextSmall:SetFont(default, 12, "NORMAL")
  end
end

local translations
function pfUI:GetEnvironment()
  -- load api into environment
  for m, func in pairs(pfUI.api or {}) do
    pfUI.env[m] = func
  end

  if pfUI_config and pfUI_config.global and pfUI_config.global.language and not translations then
    local lang = pfUI_config and pfUI_config.global and pfUI_config.global.language and pfUI_translation[pfUI_config.global.language] and pfUI_config.global.language or GetLocale()
    pfUI.env.T = setmetatable(pfUI_translation[lang] or {}, { __index = function(tab,key)
      local value = tostring(key)
      rawset(tab,key,value)
      return value
    end})
    translations = true
  end

  pfUI.env._G = getfenv(0)
  pfUI.env.C = pfUI_config
  pfUI.env.L = (pfUI_locale[GetLocale()] or pfUI_locale["enUS"])

  return pfUI.env
end

function pfUI:RegisterModule(name, a2, a3)
  if pfUI.module[name] then return end
  local hasv = type(a2) == "string"
  local func, version = hasv and a3 or a2, hasv and a2 or "vanilla:tbc:wotlk"

  -- check for client compatibility
  if not strfind(version, pfUI.expansion) then return end

  pfUI.module[name] = func
  table.insert(pfUI.modules, name)
  if not pfUI.bootup then
    pfUI:LoadModule(name)
  end
end

function pfUI:RegisterSkin(name, a2, a3)
  if pfUI.skin[name] then return end
  local hasv = type(a2) == "string"
  local func, version = hasv and a3 or a2, hasv and a2 or "vanilla:tbc:wotlk"

  -- check for client compatibility
  if not strfind(version, pfUI.expansion) then return end

  pfUI.skin[name] = func
  table.insert(pfUI.skins, name)
  if not pfUI.bootup then
    pfUI:LoadSkin(name)
  end
end

-- octo: a module or skin that errors while starting is reported in chat and
-- the others still start (one error used to stop every module after it)
local function Start(kind, name, fn)
  setfenv(fn, pfUI:GetEnvironment())
  -- (16 Nov 2026) the module starting, for the profiler's labels (modules\perf.lua)
  pfUI.loading = name
  local t0 = debugprofilestop and debugprofilestop()
  local ok, err = pcall(fn)
  if t0 then PFUI_LOADCLOCK.mods[kind .. " " .. tostring(name)] = (PFUI_LOADCLOCK.mods[kind .. " " .. tostring(name)] or 0) + debugprofilestop() - t0 end
  pfUI.loading = nil
  if not ok then
    local handler = geterrorhandler and geterrorhandler()
    local msg = "pfUI " .. kind .. " '" .. tostring(name) .. "' did not start: " .. tostring(err)
    if handler then handler(msg) else DEFAULT_CHAT_FRAME:AddMessage("|cffcc3333ERROR: |cffff5555" .. msg) end
  end
end

-- the options modules that start at login all the same (see the module loop below)
pfUI.DEFER_KEEP = {
  ["octo-options"] = true,        -- the options window itself
  ["castbar-options"] = true,     -- pfUI.castbarOcto: UI layouts and layout mode call it
  ["gear-options"] = true,        -- pfUI.gearOcto: gear, specs, layouts, cooldowns
  ["unitframes-options"] = true,  -- pfUI.ufOcto, pfUI.font_unit: layouts, layout mode, every frame's font
  ["sct-options"] = true,         -- /sct
  ["actionbar-options"] = true, ["buffs-options"] = true, ["minimap-options"] = true, -- set defaults at load
  ["plates-options"] = true,      -- pfUI.plates.OpenSection (the sidebar's Profiles entry and others)
  ["dots-options"] = true,        -- a named frame other code finds
}
-- start the options modules that waited (the first time the options window opens); true when any started
function pfUI.StartDeferred()
  local list = pfUI.deferred
  if not list or table.getn(list) == 0 then return false end
  pfUI.deferred = nil
  for _, m in ipairs(list) do pfUI:LoadModule(m) end
  return true
end

function pfUI:LoadModule(m)
  Start("module", m, pfUI.module[m])
end

function pfUI:LoadSkin(s)
  Start("skin", s, pfUI.skin[s])
end

pfUI:SetScript("OnEvent", function()
  -- enforce color updates on each event
  pfUI:UpdateColors()

  -- make sure to initialize and set our fonts
  -- each time an addon got loaded but only
  -- when the config is already accessible
  if not pfUI.bootup then
    pfUI:UpdateFonts()
  end

  if event == "PLAYER_ENTERING_WORLD" then
    pfUI:UnregisterEvent("PLAYER_ENTERING_WORLD")
    pfUI_LoadMark("in the world")
    if pfUI.LoadReportSave then pfUI.LoadReportSave() end
    return
  end
  if arg1 == pfUI.name then
    pfUI_LoadMark("every file read (pfUI and pfQuest)")
    -- read pfUI version from .toc file
    local major, minor, fix = pfUI.api.strsplit(".", tostring(GetAddOnMetadata(pfUI.name, "Version")))
    pfUI.version.major = tonumber(major) or 1
    pfUI.version.minor = tonumber(minor) or 2
    pfUI.version.fix   = tonumber(fix)   or 0
    pfUI.version.string = pfUI.version.major .. "." .. pfUI.version.minor .. "." .. pfUI.version.fix

    -- octo edition version: kept apart from "Version" (the upstream base), which
    -- updatenotify broadcasts to other pfUI users
    pfUI.version.octo = GetAddOnMetadata(pfUI.name, "X-Octo-Version") or "0"

    -- octo (6 Nov 2026, "attempt to index global 'pfUI_init' (a nil value)" in firstrun / updatenotify): a
    -- saved variable that came back empty (a damaged saved variables file) is made again, never nil
    pfUI_init = pfUI_init or {}
    pfUI_config = pfUI_config or {}
    pfUI_cache = pfUI_cache or {}
    pfUI_profiles = pfUI_profiles or {}
    pfUI_playerDB = pfUI_playerDB or {}
    pfUI_addon_profiles = pfUI_addon_profiles or {}

    -- octo: /pfprof (profiler.lua) times pfUI's scripts while it is on
    if pfUI.prof then pfUI.prof.Init() end

    -- use the "Octo" profile (env/octo.lua) on a fresh install
    if pfUI.api.isempty(pfUI_init) and pfUI.api.isempty(pfUI_config) then
      pfUI_config = pfUI.octo.Profile()
    end

    pfUI:LoadConfig()
    pfUI:MigrateConfig()
    pfUI:UpdateFonts()

    -- load modules
    -- (26 Nov 2026, user: "1 and 2 do it amazingly" - Wolfahrt's /pfload: 1.2 s of module starts) an options page's module
    -- only registers its pages: it starts the first time the options window opens (pfUI.StartDeferred), not at login.
    -- Kept at login: the options shell and the pages whose code other modules call at run time or that set defaults.
    pfUI.deferred = {}
    for _, m in pairs(this.modules) do
      if not ( pfUI_config["disabled"] and pfUI_config["disabled"][m]  == "1" ) then
        if string.find(m, "%-options$") and not pfUI.DEFER_KEEP[m] and not pfUI.nodefer then
          table.insert(pfUI.deferred, m)
        else
          pfUI:LoadModule(m)
        end
      end
    end

    pfUI_LoadMark("modules started")
    -- load skins
    for _, s in pairs(this.skins) do
      if not ( pfUI_config["disabled"] and pfUI_config["disabled"]["skin_" .. s]  == "1" ) then
        pfUI:LoadSkin(s)
      end
    end
    pfUI_LoadMark("skins started")

    pfUI.bootup = nil
  end
end)

pfUI.backdrop = {
  bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = false, tileSize = 0,
  edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1,
  insets = {left = -1, right = -1, top = -1, bottom = -1},
}
pfUI.backdrop_no_top = pfUI.backdrop

pfUI.backdrop_thin = {
  bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = false, tileSize = 0,
  edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1,
  insets = {left = 0, right = 0, top = 0, bottom = 0},
}

pfUI.backdrop_hover = {
  edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 24,
  insets = {left = -1, right = -1, top = -1, bottom = -1},
}

pfUI.backdrop_shadow = {
  edgeFile = pfUI.media["img:glow2"], edgeSize = 8,
  insets = {left = 0, right = 0, top = 0, bottom = 0},
}

pfUI.backdrop_blizz_bg = {
  bgFile =  "Interface\\BUTTONS\\WHITE8X8", tile = true, tileSize = 8,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

pfUI.backdrop_blizz_border = {
  edgeFile = pfUI.media["img:border_blizz"], edgeSize = 6,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

pfUI.backdrop_blizz_full = {
  bgFile =  "Interface\\BUTTONS\\WHITE8X8", tile = true, tileSize = 8,
  edgeFile = pfUI.media["img:border_blizz"], edgeSize = 6,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

message = function(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffcccc33INFO: |cffffff55" .. ( msg or "nil" ))
end
print = print or message

error = function(msg)
  if PF_DEBUG_MODE then message(debugstack()) end
  if string.find(msg, "AddOns\\pfUI") then
    DEFAULT_CHAT_FRAME:AddMessage("|cffcc3333ERROR: |cffff5555".. (msg or "nil" ))
  elseif not pfUI_config or (pfUI_config.global and pfUI_config.global.errors == "1") then
    DEFAULT_CHAT_FRAME:AddMessage("|cffcc3333ERROR: |cffff5555".. (msg or "nil" ))
  end
end
seterrorhandler(error)

function pfUI.SetupCVars()
  ClearTutorials()
  TutorialFrame_HideAllAlerts()

  ConsoleExec("CameraDistanceMaxFactor 5")

  SetCVar("autoSelfCast", "1")
  SetCVar("profanityFilter", "0")

  MultiActionBar_ShowAllGrids()
  ALWAYS_SHOW_MULTIBARS = "1"

  SHOW_BUFF_DURATIONS = "1"
  QUEST_FADING_DISABLE = "1"
  NAMEPLATES_ON = "1"
  SIMPLE_CHAT = "0"

  SHOW_COMBAT_TEXT = "1"
  COMBAT_TEXT_SHOW_LOW_HEALTH_MANA = "1"
  COMBAT_TEXT_SHOW_AURAS = "1"
  COMBAT_TEXT_SHOW_AURA_FADE = "1"
  COMBAT_TEXT_SHOW_COMBAT_STATE = "1"
  COMBAT_TEXT_SHOW_DODGE_PARRY_MISS = "1"
  COMBAT_TEXT_SHOW_RESISTANCES = "1"
  COMBAT_TEXT_SHOW_REPUTATION = "1"
  COMBAT_TEXT_SHOW_REACTIVES = "1"
  COMBAT_TEXT_SHOW_FRIENDLY_NAMES = "1"
  COMBAT_TEXT_SHOW_COMBO_POINTS = "1"
  COMBAT_TEXT_SHOW_MANA = "1"
  COMBAT_TEXT_FLOAT_MODE = "1"
  COMBAT_TEXT_SHOW_HONOR_GAINED = "1"
  UIParentLoadAddOn("Blizzard_CombatText")
end
