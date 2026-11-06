-- load pfUI environment
setfenv(1, pfUI:GetEnvironment())

function pfUI:UpdateConfig(group, subgroup, entry, value)
  -- create empty config if not existing
  if not pfUI_config then
    _G.pfUI_config = {}
  end

  -- check for missing config groups (Octo: and ones of the wrong type - a
  -- settings file from another pfUI can hold a string where a table goes,
  -- and every module indexing it then errors each frame: user's friend,
  -- 26 Oct 2026, "infinite scrolling of errors ... then it crashes")
  if type(pfUI_config[group]) ~= "table" then
    pfUI_config[group] = {}
  end

  -- update config
  if not subgroup and entry and value and (not pfUI_config[group][entry]
      or (type(value) == "table") ~= (type(pfUI_config[group][entry]) == "table")) then
    pfUI_config[group][entry] = value
  end

  -- check for missing config subgroups
  if subgroup and type(pfUI_config[group][subgroup]) ~= "table" then
    pfUI_config[group][subgroup] = {}
  end

  -- update config in subgroup
  if subgroup and entry and value and (not pfUI_config[group][subgroup][entry]
      or (type(value) == "table") ~= (type(pfUI_config[group][subgroup][entry]) == "table")) then
    pfUI_config[group][subgroup][entry] = value
  end
end

function pfUI:LoadConfig()
  --                MODULE        SUBGROUP       ENTRY               VALUE
  pfUI:UpdateConfig("global",     nil,           "language",         GetLocale())
  pfUI:UpdateConfig("global",     nil,           "profile",          "default")
  pfUI:UpdateConfig("global",     nil,           "pixelperfect",     "0")
  pfUI:UpdateConfig("global",     nil,           "uiscale",          "")
  pfUI:UpdateConfig("appearance", nil,           "charlook",         "1")
  pfUI:UpdateConfig("global",     nil,           "offscreen",        "0")

  pfUI:UpdateConfig("global",     nil,           "font_blizzard",    "0")
  pfUI:UpdateConfig("global",     nil,           "font_default",     "Interface\\AddOns\\pfUI\\fonts\\Myriad-Pro.ttf")
  pfUI:UpdateConfig("global",     nil,           "font_size",        "12")
  pfUI:UpdateConfig("global",     nil,           "font_unit",        "Interface\\AddOns\\pfUI\\fonts\\BigNoodleTitling.ttf")
  pfUI:UpdateConfig("global",     nil,           "font_unit_size",   "12")
  pfUI:UpdateConfig("global",     nil,           "font_unit_style",  "OUTLINE")
  pfUI:UpdateConfig("global",     nil,           "font_unit_name",   "Interface\\AddOns\\pfUI\\fonts\\Myriad-Pro.ttf")
  pfUI:UpdateConfig("global",     nil,           "font_combat",      "Interface\\AddOns\\pfUI\\fonts\\Continuum.ttf")

  pfUI:UpdateConfig("global",     nil,           "force_region",     "1")
  pfUI:UpdateConfig("global",     nil,           "errors",           "1")
  pfUI:UpdateConfig("global",     nil,           "errors_limit",     "1")
  pfUI:UpdateConfig("global",     nil,           "errors_hide",      "0")
  pfUI:UpdateConfig("global",     nil,           "hidebuff",         "0")
  pfUI:UpdateConfig("global",     nil,           "hidewbuff",        "0")
  pfUI:UpdateConfig("global",     nil,           "twentyfour",       "1")
  pfUI:UpdateConfig("global",     nil,           "servertime",       "0")
  pfUI:UpdateConfig("global",     nil,           "autosell",         "0")
  pfUI:UpdateConfig("global",     nil,           "autorepair",       "0")
  pfUI:UpdateConfig("global",     nil,           "libhealth",        "1")
  pfUI:UpdateConfig("global",     nil,           "libhealth_hit",    "4")
  pfUI:UpdateConfig("global",     nil,           "libhealth_dmg",    ".05")

  pfUI:UpdateConfig("gui",        nil,           "reloadmarker",     "0")
  pfUI:UpdateConfig("gui",        nil,           "showdisabled",     "0")

  pfUI:UpdateConfig("buffs",      nil,           "buffs",            "1")
  pfUI:UpdateConfig("buffs",      nil,           "debuffs",          "1")
  pfUI:UpdateConfig("buffs",      nil,           "weapons",          "1")
  pfUI:UpdateConfig("buffs",      nil,           "separateweapons",  "0")
  pfUI:UpdateConfig("buffs",      nil,           "size",             "24")
  pfUI:UpdateConfig("buffs",      nil,           "spacing",          "5")
  pfUI:UpdateConfig("buffs",      nil,           "wepbuffrowsize",   "2")
  pfUI:UpdateConfig("buffs",      nil,           "buffrowsize",      "16")
  pfUI:UpdateConfig("buffs",      nil,           "debuffrowsize",    "16")
  pfUI:UpdateConfig("buffs",      nil,           "textinside",       "0")
  pfUI:UpdateConfig("buffs",      nil,           "fontsize",         "-1")
  -- octo (28 Oct 2026; brues-code's fork): a sweep on your buffs, and the sweep's
  -- direction (needs ClassicAPI's cooldown frames) per kind of icon
  pfUI:UpdateConfig("buffs",      nil,           "hidetracking",     "0")
  pfUI:UpdateConfig("buffs",      nil,           "cooldown_anim",    "1")
  pfUI:UpdateConfig("buffs",      nil,           "cooldown_reverse", "1")
  pfUI:UpdateConfig("appearance", "bags",        "cooldown_reverse", "0")
  pfUI:UpdateConfig("bars",       nil,           "cooldown_reverse", "0")
  pfUI:UpdateConfig("totems",     nil,           "cooldown_reverse", "1")
  pfUI:UpdateConfig("nameplates", nil,           "debreverse",       "1")

  pfUI:UpdateConfig("buffbar",    "pbuff",       "enable",           "0")
  pfUI:UpdateConfig("buffbar",    "pbuff",       "use_unitfonts",    "0")
  pfUI:UpdateConfig("buffbar",    "pbuff",       "sort",             "asc")
  pfUI:UpdateConfig("buffbar",    "pbuff",       "color",            ".5,.5,.5,1")
  pfUI:UpdateConfig("buffbar",    "pbuff",       "bordercolor",      "0,0,0,0")
  pfUI:UpdateConfig("buffbar",    "pbuff",       "textcolor",        "1,1,1,1")
  pfUI:UpdateConfig("buffbar",    "pbuff",       "dtypebg",          "1")
  pfUI:UpdateConfig("buffbar",    "pbuff",       "dtypeborder",      "0")
  pfUI:UpdateConfig("buffbar",    "pbuff",       "dtypetext",        "0")
  pfUI:UpdateConfig("buffbar",    "pbuff",       "colorstacks",      "0")
  pfUI:UpdateConfig("buffbar",    "pbuff",       "width",            "-1")
  pfUI:UpdateConfig("buffbar",    "pbuff",       "height",           "20")
  pfUI:UpdateConfig("buffbar",    "pbuff",       "filter",           "blacklist")
  pfUI:UpdateConfig("buffbar",    "pbuff",       "threshold",        "120")
  pfUI:UpdateConfig("buffbar",    "pbuff",       "whitelist",        "")
  pfUI:UpdateConfig("buffbar",    "pbuff",       "blacklist",        "")

  pfUI:UpdateConfig("buffbar",    "pdebuff",     "enable",           "0")
  pfUI:UpdateConfig("buffbar",    "pdebuff",     "use_unitfonts",    "0")
  pfUI:UpdateConfig("buffbar",    "pdebuff",     "sort",             "asc")
  pfUI:UpdateConfig("buffbar",    "pdebuff",     "color",            ".8,.4,.4,1")
  pfUI:UpdateConfig("buffbar",    "pdebuff",     "bordercolor",      "0,0,0,0")
  pfUI:UpdateConfig("buffbar",    "pdebuff",     "textcolor",        "1,1,1,1")
  pfUI:UpdateConfig("buffbar",    "pdebuff",     "dtypebg",          "0")
  pfUI:UpdateConfig("buffbar",    "pdebuff",     "dtypeborder",      "1")
  pfUI:UpdateConfig("buffbar",    "pdebuff",     "dtypetext",        "0")
  pfUI:UpdateConfig("buffbar",    "pdebuff",     "colorstacks",      "0")
  pfUI:UpdateConfig("buffbar",    "pdebuff",     "width",            "-1")
  pfUI:UpdateConfig("buffbar",    "pdebuff",     "height",           "20")
  pfUI:UpdateConfig("buffbar",    "pdebuff",     "filter",           "blacklist")
  pfUI:UpdateConfig("buffbar",    "pdebuff",     "threshold",        "120")
  pfUI:UpdateConfig("buffbar",    "pdebuff",     "whitelist",        "")
  pfUI:UpdateConfig("buffbar",    "pdebuff",     "blacklist",        "")

  pfUI:UpdateConfig("buffbar",    "tdebuff",     "enable",           "0")
  pfUI:UpdateConfig("buffbar",    "tdebuff",     "use_unitfonts",    "0")
  pfUI:UpdateConfig("buffbar",    "tdebuff",     "sort",             "asc")
  pfUI:UpdateConfig("buffbar",    "tdebuff",     "color",            ".8,.4,.4,1")
  pfUI:UpdateConfig("buffbar",    "tdebuff",     "bordercolor",      "0,0,0,0")
  pfUI:UpdateConfig("buffbar",    "tdebuff",     "textcolor",        "1,1,1,1")
  pfUI:UpdateConfig("buffbar",    "tdebuff",     "dtypebg",          "0")
  pfUI:UpdateConfig("buffbar",    "tdebuff",     "dtypeborder",      "1")
  pfUI:UpdateConfig("buffbar",    "tdebuff",     "dtypetext",        "0")
  pfUI:UpdateConfig("buffbar",    "tdebuff",     "colorstacks",      "0")
  pfUI:UpdateConfig("buffbar",    "tdebuff",     "width",            "-1")
  pfUI:UpdateConfig("buffbar",    "tdebuff",     "height",           "20")
  pfUI:UpdateConfig("buffbar",    "tdebuff",     "selfdebuff",       "0")
  pfUI:UpdateConfig("buffbar",    "tdebuff",     "filter",           "blacklist")
  pfUI:UpdateConfig("buffbar",    "tdebuff",     "threshold",        "120")
  pfUI:UpdateConfig("buffbar",    "tdebuff",     "whitelist",        "")
  pfUI:UpdateConfig("buffbar",    "tdebuff",     "blacklist",        "")

  pfUI:UpdateConfig("appearance", "border",      "background",       "0,0,0,1")
  pfUI:UpdateConfig("appearance", "border",      "color",            "0.2,0.2,0.2,1")
  pfUI:UpdateConfig("appearance", "border",      "shadow",           "0")
  pfUI:UpdateConfig("appearance", "border",      "shadow_intensity", ".35")
  pfUI:UpdateConfig("appearance", "border",      "pixelperfect",     "1")
  pfUI:UpdateConfig("appearance", "border",      "force_blizz",      "0")
  pfUI:UpdateConfig("appearance", "border",      "hidpi",            "1")
  pfUI:UpdateConfig("appearance", "border",      "default",          "3")
  pfUI:UpdateConfig("appearance", "border",      "nameplates",       "-1")
  pfUI:UpdateConfig("appearance", "border",      "actionbars",       "-1")
  pfUI:UpdateConfig("appearance", "border",      "unitframes",       "-1")
  pfUI:UpdateConfig("appearance", "border",      "panels",           "-1")
  pfUI:UpdateConfig("appearance", "border",      "chat",             "-1")
  pfUI:UpdateConfig("appearance", "border",      "bags",             "-1")
  pfUI:UpdateConfig("meters",     nil,           "enable",           "1")
  pfUI:UpdateConfig("meters",     nil,           "hidden",           "0")
  pfUI:UpdateConfig("meters",     nil,           "togglebtn",        "1")

  pfUI:UpdateConfig("meters",     nil,           "windows",          "2")
  pfUI:UpdateConfig("meters",     nil,           "mode1",            "damage")
  pfUI:UpdateConfig("meters",     nil,           "mode2",            "threat")
  pfUI:UpdateConfig("meters",     nil,           "segment1",         "current")
  pfUI:UpdateConfig("meters",     nil,           "segment2",         "current")
  pfUI:UpdateConfig("meters",     nil,           "width",            "260")
  pfUI:UpdateConfig("meters",     nil,           "height",           "160")
  pfUI:UpdateConfig("meters",     nil,           "barheight",        "16")
  pfUI:UpdateConfig("meters",     nil,           "texture",          "Interface\\AddOns\\pfUI\\img\\bar_elvui")
  pfUI:UpdateConfig("meters",     nil,           "background",       "0.06,0.06,0.06,0.75")
  pfUI:UpdateConfig("meters",     nil,           "classcolor",       "1")
  pfUI:UpdateConfig("meters",     nil,           "showrank",         "1")
  pfUI:UpdateConfig("meters",     nil,           "showps",           "1")
  pfUI:UpdateConfig("meters",     nil,           "showpct",          "1")
  pfUI:UpdateConfig("meters",     nil,           "lock1",            "0")
  pfUI:UpdateConfig("meters",     nil,           "lock2",            "0")
  pfUI:UpdateConfig("meters",     nil,           "mergepets",        "1")
  pfUI:UpdateConfig("meters",     nil,           "trackall",         "0")
  pfUI:UpdateConfig("meters",     nil,           "history",          "10")
  pfUI:UpdateConfig("meters",     nil,           "resetask",         "1")
  pfUI:UpdateConfig("meters",     nil,           "threat",           "1")
  pfUI:UpdateConfig("meters",     nil,           "threatrate",       "0.2")
  pfUI:UpdateConfig("meters",     nil,           "refresh",          "0.1")
  pfUI:UpdateConfig("meters",     nil,           "threatwarn",       "90")
  pfUI:UpdateConfig("meters",     nil,           "threatsound",      "1")
  pfUI:UpdateConfig("meters",     nil,           "threatflash",      "1")
  pfUI:UpdateConfig("meters",     nil,           "asked",            "0")
  -- octo: threat label, cap and popups (moved from OctoBG 23 Oct 2026)
  pfUI:UpdateConfig("meters",     nil,           "threatref",        "pull")
  pfUI:UpdateConfig("meters",     nil,           "threatsoundkey",   "RaidWarning")
  pfUI:UpdateConfig("meters",     nil,           "threatpopup",      "THREAT - back off!")
  pfUI:UpdateConfig("meters",     nil,           "threataggro",      "1")
  pfUI:UpdateConfig("meters",     nil,           "tlabel",           "1")
  pfUI:UpdateConfig("meters",     nil,           "tlook",            "words")
  pfUI:UpdateConfig("meters",     nil,           "twhere",           "above")
  pfUI:UpdateConfig("meters",     nil,           "tx",               "0")
  pfUI:UpdateConfig("meters",     nil,           "ty",               "2")
  pfUI:UpdateConfig("meters",     nil,           "tsize",            "13")
  pfUI:UpdateConfig("meters",     nil,           "toutline",         "THICKOUTLINE")
  pfUI:UpdateConfig("meters",     nil,           "tnext",            "1")
  pfUI:UpdateConfig("meters",     nil,           "tnextname",        "1")
  pfUI:UpdateConfig("meters",     nil,           "tnear",            "80")
  pfUI:UpdateConfig("meters",     nil,           "tcolsafe",         "0.35,1,0.35,1")
  pfUI:UpdateConfig("meters",     nil,           "tcolnear",         "1,0.82,0.23,1")
  pfUI:UpdateConfig("meters",     nil,           "tcolover",         "1,0.29,0.23,1")
  pfUI:UpdateConfig("meters",     nil,           "tcolaggro",        "1,0.48,0.23,1")
  pfUI:UpdateConfig("meters",     nil,           "timported",        "0")
  -- octo: every meter window has its own settings (meters-window.lua; the
  -- old shared keys above are copied in once, "migrated")
  pfUI:UpdateConfig("meters",     nil,           "migrated",         "0")
  -- octo phase 2: how fights are kept and timed
  pfUI:UpdateConfig("meters",     nil,           "mergetrash",       "1")
  pfUI:UpdateConfig("meters",     nil,           "autocurrent",      "1")
  pfUI:UpdateConfig("meters",     nil,           "timemeasure",      "active")
  -- octo nameplates phase 4: animations and rules (plates-fx.lua)
  pfUI:UpdateConfig("plates",     nil,           "animcrit",         "pop")
  pfUI:UpdateConfig("plates",     nil,           "animtarget",       "pop")
  pfUI:UpdateConfig("plates",     nil,           "animsize",         "25")
  -- calm plates (not target / casting / moving) redraw this often; 60 = every frame
  pfUI:UpdateConfig("plates",     nil,           "calmfps",          "30")
  for i = 1, 6 do
    pfUI:UpdateConfig("plates", "rule" .. i, "on",     "0")
    pfUI:UpdateConfig("plates", "rule" .. i, "when",   "name")
    pfUI:UpdateConfig("plates", "rule" .. i, "value",  "")
    pfUI:UpdateConfig("plates", "rule" .. i, "effect", "color")
    pfUI:UpdateConfig("plates", "rule" .. i, "color",  "1,0.5,0,1")
    pfUI:UpdateConfig("plates", "rule" .. i, "size",   "130")
  end
  -- octo phase 4: numbers, trash, report / tooltip lines
  pfUI:UpdateConfig("meters",     nil,           "numformat",        "short")
  pfUI:UpdateConfig("meters",     nil,           "erasetrash",       "0")
  pfUI:UpdateConfig("meters",     nil,           "reportlines",      "10")
  pfUI:UpdateConfig("meters",     nil,           "tooltip",          "1")
  pfUI:UpdateConfig("meters",     nil,           "tooltiplines",     "8")
  pfUI:UpdateConfig("meters",     nil,           "clog",             "1")
  pfUI:UpdateConfig("meters",     nil,           "snap",             "1")
  pfUI:UpdateConfig("meters",     nil,           "recent",           "")
  -- custom displays: a spell's damage / healing / casts / damage taken, a buff's or debuff's uptime
  for i = 1, 5 do
    pfUI:UpdateConfig("meters", "custom" .. i, "name",  "")
    pfUI:UpdateConfig("meters", "custom" .. i, "kind",  "dmgspell")
    pfUI:UpdateConfig("meters", "custom" .. i, "spell", "")
  end
  for i = 1, 6 do
    pfUI:UpdateConfig("meters", "win" .. i, "status",      "0")
    pfUI:UpdateConfig("meters", "win" .. i, "statusleft",  "time")
    pfUI:UpdateConfig("meters", "win" .. i, "statusmid",   "mine")
    pfUI:UpdateConfig("meters", "win" .. i, "statusright", "clock")
  end
  local meterModes = { "damage", "threat", "heal", "taken", "interrupts", "deaths" }
  for i = 1, 6 do
    local w = "win" .. i
    pfUI:UpdateConfig("meters", w, "mode",        meterModes[i])
    pfUI:UpdateConfig("meters", w, "segment",     "current")
    pfUI:UpdateConfig("meters", w, "width",       "260")
    pfUI:UpdateConfig("meters", w, "height",      "160")
    pfUI:UpdateConfig("meters", w, "lock",        "0")
    pfUI:UpdateConfig("meters", w, "look",        "octo")
    -- window
    pfUI:UpdateConfig("meters", w, "bg",          "0.06,0.06,0.06,0.75")
    pfUI:UpdateConfig("meters", w, "border",      "pfui")
    pfUI:UpdateConfig("meters", w, "bordercolor", "0,0,0,1")
    pfUI:UpdateConfig("meters", w, "alpha",       "1")
    pfUI:UpdateConfig("meters", w, "oocalpha",    "1")
    pfUI:UpdateConfig("meters", w, "autohide",    "never")
    -- title bar
    pfUI:UpdateConfig("meters", w, "title",       "1")
    pfUI:UpdateConfig("meters", w, "titleheight", "18")
    pfUI:UpdateConfig("meters", w, "titlebg",     "0,0,0,0.45")
    pfUI:UpdateConfig("meters", w, "titleaccent", "1")
    pfUI:UpdateConfig("meters", w, "titlecolor",  "1,1,1,1")
    pfUI:UpdateConfig("meters", w, "titlesize",   "12")
    pfUI:UpdateConfig("meters", w, "showseg",     "1")
    pfUI:UpdateConfig("meters", w, "btnmenu",     "1")
    pfUI:UpdateConfig("meters", w, "btnreport",   "1")
    pfUI:UpdateConfig("meters", w, "btnreset",    "1")
    pfUI:UpdateConfig("meters", w, "btnlock",     "1")
    -- bars
    pfUI:UpdateConfig("meters", w, "barheight",   "16")
    pfUI:UpdateConfig("meters", w, "spacing",     "1")
    pfUI:UpdateConfig("meters", w, "texture",     "Interface\\AddOns\\pfUI\\img\\bar_elvui")
    pfUI:UpdateConfig("meters", w, "colorby",     "class")
    pfUI:UpdateConfig("meters", w, "barcolor",    "0.6,0.6,0.6,1")
    pfUI:UpdateConfig("meters", w, "baralpha",    "0.85")
    pfUI:UpdateConfig("meters", w, "barbg",       "1,1,1,0.05")
    pfUI:UpdateConfig("meters", w, "grow",        "down")
    pfUI:UpdateConfig("meters", w, "icons",       "class")
    pfUI:UpdateConfig("meters", w, "rank",        "1")
    -- texts
    pfUI:UpdateConfig("meters", w, "font",        "")
    pfUI:UpdateConfig("meters", w, "fontsize",    "11")
    pfUI:UpdateConfig("meters", w, "outline",     "OUTLINE")
    pfUI:UpdateConfig("meters", w, "shadow",      "0")
    pfUI:UpdateConfig("meters", w, "namecolor",   "white")
    pfUI:UpdateConfig("meters", w, "order",       "tps")
    pfUI:UpdateConfig("meters", w, "showps",      "1")
    pfUI:UpdateConfig("meters", w, "showpct",     "1")
    pfUI:UpdateConfig("meters", w, "brackets",    "1")
    -- 25 Oct 2026 (user: "more custom stuff ... font colour changes, icons"): colours of every text,
    -- icon size / side, bar border, your own bar marked, hover colour, title font
    pfUI:UpdateConfig("meters", w, "namecustom",  "1,1,1,1")
    pfUI:UpdateConfig("meters", w, "valuecolor",  "white")
    pfUI:UpdateConfig("meters", w, "valuecustom", "1,1,1,1")
    pfUI:UpdateConfig("meters", w, "subcolor",    "0.67,0.67,0.67,1")
    pfUI:UpdateConfig("meters", w, "rankcolor",   "0.67,0.67,0.67,1")
    pfUI:UpdateConfig("meters", w, "valuesize",   "0")
    pfUI:UpdateConfig("meters", w, "iconside",    "left")
    pfUI:UpdateConfig("meters", w, "iconsize",    "0")
    pfUI:UpdateConfig("meters", w, "barborder",   "0")
    pfUI:UpdateConfig("meters", w, "barbordercolor", "0,0,0,1")
    pfUI:UpdateConfig("meters", w, "selfmark",    "0")
    pfUI:UpdateConfig("meters", w, "selfcolor",   "1,0.82,0.2,1")
    pfUI:UpdateConfig("meters", w, "hovercolor",  "1,1,1,0.12")
    pfUI:UpdateConfig("meters", w, "titlefont",   "")
  end
  -- octo-blizzard.lua: "1" = that section uses Blizzard's own frames
  for _, k in pairs({ "unitframes", "castbar", "actionbars", "minimap", "buffs", "nameplates", "bags", "loot",
                      "combattext", "meters", "chat", "tooltip", "panels" }) do
    pfUI:UpdateConfig("blizz",    nil,           k,                  "0")
  end
  -- octo swing.lua: WeaponSwingTimer's own defaults (sizes, places, colours)
  for _, k in pairs({ { "player", "-200", ".1,.1,.9,1" }, { "target", "-230", ".8,.1,.1,1" }, { "ranged", "-260", nil }, { "cast", "-290", nil } }) do
    local bar = k[1]
    pfUI:UpdateConfig("swing",    bar,           "enabled",          "1")
    pfUI:UpdateConfig("swing",    bar,           "width",            "300")
    pfUI:UpdateConfig("swing",    bar,           "height",           "12")
    pfUI:UpdateConfig("swing",    bar,           "fontsize",         (bar == "ranged" or bar == "cast") and "12" or "10")
    pfUI:UpdateConfig("swing",    bar,           "x",                "0")
    pfUI:UpdateConfig("swing",    bar,           "y",                k[2])
    pfUI:UpdateConfig("swing",    bar,           "alpha",            "1")
    pfUI:UpdateConfig("swing",    bar,           "oocalpha",         (bar == "ranged" or bar == "cast") and "0" or ".25")
    pfUI:UpdateConfig("swing",    bar,           "fadeidle",         "0")
    pfUI:UpdateConfig("swing",    bar,           "fill",             "1")
    if k[3] then
      pfUI:UpdateConfig("swing",  bar,           "lefttext",         "1")
      pfUI:UpdateConfig("swing",  bar,           "righttext",        "1")
      pfUI:UpdateConfig("swing",  bar,           "maincolor",        k[3])
      pfUI:UpdateConfig("swing",  bar,           "offcolor",         k[3])
      pfUI:UpdateConfig("swing",  bar,           "textcolor",        "1,1,1,1")
    end
  end
  pfUI:UpdateConfig("swing",      "player",      "offhand",          "1")
  pfUI:UpdateConfig("swing",      "player",      "combined",         "0")
  pfUI:UpdateConfig("swing",      "ranged",      "text",             "1")
  pfUI:UpdateConfig("swing",      "ranged",      "onebar",           "0")
  pfUI:UpdateConfig("swing",      "ranged",      "cooldowncolor",    ".95,.95,.95,1")
  pfUI:UpdateConfig("swing",      "ranged",      "castcolor",        ".8,0,0,1")
  pfUI:UpdateConfig("swing",      "look",        "bar",              "classic")
  pfUI:UpdateConfig("swing",      "look",        "border",           "cdm")
  pfUI:UpdateConfig("swing",      "look",        "spark",            "1")
  pfUI:UpdateConfig("swing",      "look",        "backalpha",        ".5")
  pfUI:UpdateConfig("swing",      "warrior",     "queuecolor",       ".9,.6,.1,1")
  pfUI:UpdateConfig("swing",      "warrior",     "cleavecolor",      ".1,.8,.2,1")
  pfUI:UpdateConfig("swing",      "warrior",     "maulcolor",        ".67,.47,.47,1")
  pfUI:UpdateConfig("swing",      "cast",        "aimed",            "1")
  pfUI:UpdateConfig("swing",      "cast",        "multi",            "1")
  pfUI:UpdateConfig("swing",      "cast",        "text",             "1")
  pfUI:UpdateConfig("swing",      "cast",        "latency",          "0")
  pfUI:UpdateConfig("swing",      "cast",        "clip",             "1")
  pfUI:UpdateConfig("swing",      "cast",        "castcolor",        ".8,.64,0,1")
  pfUI:UpdateConfig("swing",      "cast",        "clipcolor",        "1,0,0,.7")
  pfUI:UpdateConfig("swing",      "cast",        "latencycolor",     "1,0,0,.75")
  pfUI:UpdateConfig("swing",      "warrior",     "slam",             "1")
  pfUI:UpdateConfig("swing",      "warrior",     "slamdelay",        ".1")
  pfUI:UpdateConfig("swing",      "warrior",     "slamcolor",        ".9,.1,0,1")
  pfUI:UpdateConfig("swing",      "warrior",     "slamgcd",          "1")
  pfUI:UpdateConfig("swing",      "warrior",     "gcdcolor",         "1,1,1,1")
  pfUI:UpdateConfig("swing",      "warrior",     "slamonehand",      "0")
  pfUI:UpdateConfig("swing",      "paladin",     "twist",            "0")
  pfUI:UpdateConfig("swing",      "paladin",     "gcd",              "0")
  pfUI:UpdateConfig("swing",      "paladin",     "twistcolor",       "1,.996,.722,1")
  pfUI:UpdateConfig("swing",      "paladin",     "gcdcolor",         "1,0,0,.8")
  pfUI:UpdateConfig("swing",      "paladin",     "offset",           "6")
  -- octo gear.lua / gear-sheet.lua (sets themselves: C.gear.sets, made by the module)
  pfUI:UpdateConfig("gear",       nil,           "button",           "1")
  pfUI:UpdateConfig("gear",       nil,           "size",             "36")
  pfUI:UpdateConfig("gear",       nil,           "showname",         "1")
  pfUI:UpdateConfig("gear",       nil,           "minimap",          "1")
  pfUI:UpdateConfig("gear",       nil,           "mmangle",          "200")
  pfUI:UpdateConfig("gear",       nil,           "tellwait",         "1")
  pfUI:UpdateConfig("gear",       nil,           "combatweapons",    "1")
  pfUI:UpdateConfig("gear",       nil,           "instant",          "1") -- octo: ClassicAPI one-pass swap
  pfUI:UpdateConfig("gear",       nil,           "keytoggle",        "0")
  pfUI:UpdateConfig("gear",       nil,           "allowempty",       "1")
  pfUI:UpdateConfig("gear",       nil,           "wrap",             "6")
  pfUI:UpdateConfig("gear",       nil,           "menuscale",        "1")
  pfUI:UpdateConfig("gear",       nil,           "sheet",            "1")
  pfUI:UpdateConfig("gear",       nil,           "sheetshift",       "0")
  pfUI:UpdateConfig("gear",       nil,           "sheetpanel",       "1")
  pfUI:UpdateConfig("gear",       nil,           "sheetside",        "right")
  pfUI:UpdateConfig("gear",       nil,           "trinketbar",       "0")
  pfUI:UpdateConfig("gear",       nil,           "trinketsize",      "36")
  pfUI:UpdateConfig("gear",       nil,           "trinketvertical",  "0")
  pfUI:UpdateConfig("gear",       nil,           "trinketmenu",      "1")
  pfUI:UpdateConfig("gear",       nil,           "trinketmenuclick", "0")
  pfUI:UpdateConfig("gear",       nil,           "trinketshift",     "0")
  pfUI:UpdateConfig("gear",       nil,           "cdnumbers",        "1")
  pfUI:UpdateConfig("gear",       nil,           "slotbar",          "1")
  pfUI:UpdateConfig("gear",       nil,           "slotlist",         "16,17,18")
  pfUI:UpdateConfig("gear",       nil,           "slotsize",         "36")
  pfUI:UpdateConfig("gear",       nil,           "slotspace",        "4")
  pfUI:UpdateConfig("gear",       nil,           "slotper",          "12")
  pfUI:UpdateConfig("gear",       nil,           "slotvertical",     "0")
  pfUI:UpdateConfig("gear",       nil,           "slotalpha",        "1")
  pfUI:UpdateConfig("gear",       nil,           "slotcombat",       "0")
  pfUI:UpdateConfig("gear",       nil,           "slotmenu",         "hover")
  pfUI:UpdateConfig("gear",       nil,           "slotshift",        "0")
  pfUI:UpdateConfig("gear",       nil,           "slotrightuse",     "0")
  pfUI:UpdateConfig("gear",       nil,           "slotside",         "auto")
  pfUI:UpdateConfig("gear",       nil,           "altslots",         "1")
  pfUI:UpdateConfig("gear",       nil,           "allowhidden",      "1")
  pfUI:UpdateConfig("gear",       nil,           "boundonly",        "0")
  pfUI:UpdateConfig("gear",       nil,           "cd90",             "0")
  pfUI:UpdateConfig("gear",       nil,           "notify",           "1")
  pfUI:UpdateConfig("gear",       nil,           "notify30",         "0")
  pfUI:UpdateConfig("gear",       nil,           "notifychat",       "0")
  pfUI:UpdateConfig("gear",       nil,           "waitdead",         "1")
  pfUI:UpdateConfig("gear",       nil,           "waitcast",         "1")
  pfUI:UpdateConfig("gear",       nil,           "autoswap",         "1")
  pfUI:UpdateConfig("gear",       nil,           "autotell",         "1")
  pfUI:UpdateConfig("gear",       nil,           "specwindow",       "1")
  pfUI:UpdateConfig("gear",       nil,           "spectell",         "1")
  pfUI:UpdateConfig("gear",       nil,           "specnotice",       "1")
  pfUI:UpdateConfig("gear",       nil,           "specconfirm",      "1")
  pfUI:UpdateConfig("gear",       nil,           "tooltips",         "1")
  pfUI:UpdateConfig("gear",       nil,           "sheettip",         "1")
  pfUI:UpdateConfig("gear",       nil,           "sheettipscale",    "0.85")
  pfUI:UpdateConfig("gear",       nil,           "tqtell",           "1")
  pfUI:UpdateConfig("mapstyle",   nil,           "shape",            "square")
  pfUI:UpdateConfig("mapstyle",   nil,           "border",           "pfui")
  pfUI:UpdateConfig("mapstyle",   nil,           "outlinecolor",     "0,0,0,1")
  pfUI:UpdateConfig("mapstyle",   nil,           "outlineaccent",    "0")
  for i = 1, 3 do
    pfUI:UpdateConfig("mapstyle", nil,           "art" .. i,         "none")
    pfUI:UpdateConfig("mapstyle", nil,           "art" .. i .. "size",  "140")
    pfUI:UpdateConfig("mapstyle", nil,           "art" .. i .. "color", "1,1,1,0.9")
    pfUI:UpdateConfig("mapstyle", nil,           "art" .. i .. "blend", "ADD")
    pfUI:UpdateConfig("mapstyle", nil,           "art" .. i .. "speed", "0")
    pfUI:UpdateConfig("mapstyle", nil,           "art" .. i .. "above", "1")
  end
  pfUI:UpdateConfig("mapstyle",   nil,           "tracking",         "show")
  pfUI:UpdateConfig("mapstyle",   nil,           "mail",             "show")
  pfUI:UpdateConfig("mapstyle",   nil,           "battlefield",      "show")
  pfUI:UpdateConfig("mapstyle",   nil,           "abutton",          "show")
  pfUI:UpdateConfig("mapstyle",   nil,           "clock",            "hover")
  pfUI:UpdateConfig("mapstyle",   nil,           "clocktime",        "local")
  pfUI:UpdateConfig("mapstyle",   nil,           "clockpos",         "bottom")
  pfUI:UpdateConfig("mapstyle",   nil,           "ping",             "1")
  pfUI:UpdateConfig("mapstyle",   nil,           "autozoom",         "0")
  pfUI:UpdateConfig("mapstyle",   nil,           "alpha",            "1")
  pfUI:UpdateConfig("mapstyle",   nil,           "combatalpha",      "1")
  -- each part's place on the map ("" = pfUI's own) and size in %
  pfUI:UpdateConfig("mapstyle",   nil,           "barwas",           "zone")
  for _, k in pairs({ "zone", "coords", "clock", "ping", "tracking", "mail", "battlefield", "pvp", "abutton", "bar" }) do
    pfUI:UpdateConfig("mapstyle", nil,           k .. "x",           "")
    pfUI:UpdateConfig("mapstyle", nil,           k .. "y",           "")
    pfUI:UpdateConfig("mapstyle", nil,           k .. "pt",          "")
    pfUI:UpdateConfig("mapstyle", nil,           k .. "scale",       "100")
  end
  pfUI:UpdateConfig("unlock",     nil,           "snap",             "1")
  pfUI:UpdateConfig("unlock",     nil,           "gridsize",         "128")
  pfUI:UpdateConfig("unlock",     nil,           "helpseen",         "0")
  pfUI:UpdateConfig("unlock",     "hidden",      nil,                nil) -- octo: frames hidden from layout mode
  pfUI:UpdateConfig("unlock",     nil,           "mirror",           "1") -- octo: mirrored guide lines
  pfUI:UpdateConfig("appearance", "accent",      "mode",             "class")
  pfUI:UpdateConfig("appearance", "accent",      "color",            "0.09,0.52,0.82,1")
  pfUI:UpdateConfig("appearance", "cd",          "lowcolor",         "1,.2,.2,1")
  pfUI:UpdateConfig("appearance", "cd",          "normalcolor",      "1,1,1,1")
  pfUI:UpdateConfig("appearance", "cd",          "minutecolor",      ".2,1,1,1")
  pfUI:UpdateConfig("appearance", "cd",          "hourcolor",        ".2,.5,1,1")
  pfUI:UpdateConfig("appearance", "cd",          "daycolor",         ".2,.2,1,1")
  pfUI:UpdateConfig("appearance", "cd",          "threshold",        "2")
  pfUI:UpdateConfig("appearance", "cd",          "font_size",        "12")
  pfUI:UpdateConfig("appearance", "cd",          "font_size_blizz",  "12")
  pfUI:UpdateConfig("appearance", "cd",          "font_size_foreign","12")
  pfUI:UpdateConfig("appearance", "cd",          "debuffs",          "1")
  pfUI:UpdateConfig("appearance", "cd",          "blizzard",         "1")
  pfUI:UpdateConfig("appearance", "cd",          "foreign",          "0")
  pfUI:UpdateConfig("appearance", "cd",          "milliseconds",     "1")
  pfUI:UpdateConfig("appearance", "cd",          "hideanim",         "0")
  pfUI:UpdateConfig("appearance", "cd",          "font",             "Interface\\AddOns\\pfUI\\fonts\\BigNoodleTitling.ttf")
  pfUI:UpdateConfig("appearance", "cd",          "dynamicsize",      "1")
  pfUI:UpdateConfig("appearance", "cd",          "format",           "pfui")
  pfUI:UpdateConfig("appearance", "cd",          "pos",              "CENTER")
  pfUI:UpdateConfig("appearance", "cd",          "lowgrow",          "0")
  pfUI:UpdateConfig("appearance", "cd",          "finish",           "none")
  pfUI:UpdateConfig("appearance", "cd",          "finishcolor",      "1,1,1,1")
  pfUI:UpdateConfig("appearance", "cd",          "finishmin",        "3")
  pfUI:UpdateConfig("appearance", "cd",          "finishsound",      "none")
  pfUI:UpdateConfig("appearance", "castbar",     "castbarcolor",     ".7,.7,.9,.8")
  pfUI:UpdateConfig("appearance", "castbar",     "channelcolor",     ".9,.9,.7,.8")
  pfUI:UpdateConfig("appearance", "castbar",     "nointcolor",       ".55,.55,.55,.8")
  pfUI:UpdateConfig("appearance", "castbar",     "texture",          "Interface\\AddOns\\pfUI\\img\\bar")
  pfUI:UpdateConfig("appearance", "infight",     "screen",           "0")
  pfUI:UpdateConfig("appearance", "infight",     "aggro",            "0")
  pfUI:UpdateConfig("appearance", "infight",     "health",           "1")
  pfUI:UpdateConfig("appearance", "infight",     "intensity",           "16")
  pfUI:UpdateConfig("appearance", "bags",        "unusable",         "1")
  pfUI:UpdateConfig("appearance", "bags",        "unusable_color",   ".9,.2,.2,1")
  pfUI:UpdateConfig("appearance", "bags",        "borderlimit",      "1")
  pfUI:UpdateConfig("appearance", "bags",        "borderonlygear",   "0")
  pfUI:UpdateConfig("appearance", "bags",        "fulltext",         "1")
  pfUI:UpdateConfig("appearance", "bags",        "movable",          "0")
  pfUI:UpdateConfig("appearance", "bags",        "abovechat",        "0")
  pfUI:UpdateConfig("appearance", "bags",        "hidechat",         "0")
  pfUI:UpdateConfig("appearance", "bags",        "icon_size",        "-1")
  pfUI:UpdateConfig("appearance", "bags",        "bagrowlength",     "10")
  pfUI:UpdateConfig("appearance", "bags",        "bankrowlength",    "10")
  -- range.lua: range to the target (6 Nov 2026)
  pfUI:UpdateConfig("range",      nil,           "enable",           "1")
  pfUI:UpdateConfig("range",      nil,           "showfor",          "all")
  pfUI:UpdateConfig("range",      nil,           "self",             "0")
  pfUI:UpdateConfig("range",      nil,           "trend",            "1")
  pfUI:UpdateConfig("range",      nil,           "scale",            "100")
  pfUI:UpdateConfig("range",      nil,           "fontsize",         "16")
  pfUI:UpdateConfig("range",      nil,           "decimals",         "1")
  pfUI:UpdateConfig("range",      nil,           "maxvel",           "15")
  pfUI:UpdateConfig("range",      nil,           "melee",            "5")
  pfUI:UpdateConfig("range",      nil,           "spell",            "30")
  pfUI:UpdateConfig("range",      nil,           "far",              "40")
  pfUI:UpdateConfig("range",      nil,           "c_near",           "0.30,1.00,0.30,1")
  pfUI:UpdateConfig("range",      nil,           "c_mid",            "1.00,0.90,0.20,1")
  pfUI:UpdateConfig("range",      nil,           "c_far",            "1.00,0.55,0.15,1")
  pfUI:UpdateConfig("range",      nil,           "c_out",            "1.00,0.25,0.25,1")
  pfUI:UpdateConfig("range",      nil,           "source",           "edge")
  pfUI:UpdateConfig("range",      nil,           "box",              "1")
  pfUI:UpdateConfig("range",      nil,           "unit",             "1")
  pfUI:UpdateConfig("range",      nil,           "font",             "")
  pfUI:UpdateConfig("range",      nil,           "outline",          "OUTLINE")
  pfUI:UpdateConfig("range",      nil,           "shadow",           "0")
  pfUI:UpdateConfig("range",      nil,           "colormode",        "range")
  pfUI:UpdateConfig("range",      nil,           "textcolor",        "1.00,1.00,1.00,1")
  -- art.lua: raid mark sets and elite crest styles (5 Nov 2026)
  pfUI:UpdateConfig("art",        nil,           "marks",            "pfui")
  pfUI:UpdateConfig("art",        nil,           "elite",            "classic")
  -- autoloot.lua: automatic area looting with ClassicAPI (4 Nov 2026)
  pfUI:UpdateConfig("autoloot",   nil,           "enable",           "0")
  pfUI:UpdateConfig("autoloot",   nil,           "death",            "1")
  pfUI:UpdateConfig("autoloot",   nil,           "stop",             "1")
  pfUI:UpdateConfig("autoloot",   nil,           "combat",           "1")
  pfUI:UpdateConfig("autoloot",   nil,           "closewin",         "1")
  pfUI:UpdateConfig("autoloot",   nil,           "deathdist",        "8")
  pfUI:UpdateConfig("autoloot",   nil,           "deathdelay",       "0.25")
  pfUI:UpdateConfig("autoloot",   nil,           "stopdelay",        "0.15")
  pfUI:UpdateConfig("autoloot",   nil,           "log",              "1")
  pfUI:UpdateConfig("autoloot",   nil,           "combine",          "0")
  pfUI:UpdateConfig("autoloot",   nil,           "chat",             "0")
  pfUI:UpdateConfig("autoloot",   nil,           "loginopen",        "0")
  pfUI:UpdateConfig("autoloot",   nil,           "loglock",          "0")
  pfUI:UpdateConfig("autoloot",   nil,           "logw",             "300")
  pfUI:UpdateConfig("autoloot",   nil,           "logh",             "220")
  -- bags-octo.lua: Bagnon-style bag and bank windows (25 Oct 2026)
  pfUI:UpdateConfig("bagsocto",   nil,           "enable",           "1")
  pfUI:UpdateConfig("bagsocto",   nil,           "columns",          "10")
  pfUI:UpdateConfig("bagsocto",   nil,           "bankcolumns",      "14")
  pfUI:UpdateConfig("bagsocto",   nil,           "size",             "32")
  pfUI:UpdateConfig("bagsocto",   nil,           "spacing",          "3")
  pfUI:UpdateConfig("bagsocto",   nil,           "scale",            "1")
  pfUI:UpdateConfig("bagsocto",   nil,           "bgalpha",          "0.92")
  pfUI:UpdateConfig("bagsocto",   nil,           "title",            "1")
  pfUI:UpdateConfig("bagsocto",   nil,           "search",           "1")
  pfUI:UpdateConfig("bagsocto",   nil,           "bagbar",           "1")
  pfUI:UpdateConfig("bagsocto",   nil,           "money",            "1")
  pfUI:UpdateConfig("bagsocto",   nil,           "free",             "1")
  pfUI:UpdateConfig("bagsocto",   nil,           "sortbtn",          "1")
  pfUI:UpdateConfig("bagsocto",   nil,           "bagbreak",         "0")
  pfUI:UpdateConfig("bagsocto",   nil,           "reverse",          "0")
  pfUI:UpdateConfig("bagsocto",   nil,           "locked",           "0")
  pfUI:UpdateConfig("bagsocto",   nil,           "hidden",           "")
  pfUI:UpdateConfig("bagsocto",   nil,           "wash",             "class")
  pfUI:UpdateConfig("bagsocto",   nil,           "washcolor",        "0.2,0.7,1,1")
  pfUI:UpdateConfig("bagsocto",   nil,           "bankwash",         "custom")
  pfUI:UpdateConfig("bagsocto",   nil,           "bankwashcolor",    "1,0.78,0.2,1")
  pfUI:UpdateConfig("bagsocto",   nil,           "bagsx",            "")
  pfUI:UpdateConfig("bagsocto",   nil,           "bagsy",            "")
  pfUI:UpdateConfig("bagsocto",   nil,           "bankx",            "")
  pfUI:UpdateConfig("bagsocto",   nil,           "banky",            "")
  pfUI:UpdateConfig("bagsocto",   nil,           "glownew",          "1")
  pfUI:UpdateConfig("bagsocto",   nil,           "newcolor",         "1,0.85,0.3,1")
  pfUI:UpdateConfig("bagsocto",   nil,           "newclear",         "1")
  pfUI:UpdateConfig("bagsocto",   nil,           "junk",             "1")
  pfUI:UpdateConfig("bagsocto",   nil,           "quest",            "1")
  pfUI:UpdateConfig("appearance", "minimap",     "size",             "140")
  pfUI:UpdateConfig("appearance", "minimap",     "arrowscale",       "1")
  pfUI:UpdateConfig("appearance", "minimap",     "zonetext",         "off")
  pfUI:UpdateConfig("appearance", "minimap",     "coordstext",       "mouseover")
  pfUI:UpdateConfig("appearance", "minimap",     "coordsloc",        "bottomleft")
  pfUI:UpdateConfig("appearance", "minimap",     "tracking_size",    "16")
  pfUI:UpdateConfig("appearance", "minimap",     "tracking_pulse",   "1")
  pfUI:UpdateConfig("appearance", "minimap",     "addon_buttons",    "0")
  pfUI:UpdateConfig("appearance", "worldmap",    "tooltipsize",      "0")
  pfUI:UpdateConfig("appearance", "worldmap",    "mapreveal",        "0")
  pfUI:UpdateConfig("appearance", "worldmap",    "mapreveal_color",  ".4,.4,.4,1")
  pfUI:UpdateConfig("appearance", "worldmap",    "mapexploration",   "0")
  pfUI:UpdateConfig("appearance", "worldmap",    "groupcircles",     "3")
  pfUI:UpdateConfig("appearance", "worldmap",    "colornames",       "1")

  pfUI:UpdateConfig("loot",       nil,           "autoresize",       "1")
  pfUI:UpdateConfig("loot",       nil,           "autopickup",       "1")
  pfUI:UpdateConfig("loot",       nil,           "mousecursor",      "1")
  pfUI:UpdateConfig("loot",       nil,           "advancedloot",     "1")
  pfUI:UpdateConfig("loot",       nil,           "rollannouncequal", "3")
  pfUI:UpdateConfig("loot",       nil,           "rollannounce",     "0")
  pfUI:UpdateConfig("loot",       nil,           "raritytimer",      "1")

  pfUI:UpdateConfig("unitframes", nil,           "disable",          "0")
  pfUI:UpdateConfig("unitframes", nil,           "pastel",           "1")
  pfUI:UpdateConfig("unitframes", nil,           "custom",           "0")
  pfUI:UpdateConfig("unitframes", nil,           "customfullhp",     "0")
  pfUI:UpdateConfig("unitframes", nil,           "customfade",       "0")
  pfUI:UpdateConfig("unitframes", nil,           "customcolor",      ".2,.2,.2,1")
  pfUI:UpdateConfig("unitframes", nil,           "custombg",         "0")
  pfUI:UpdateConfig("unitframes", nil,           "custombgcolor",    ".5,.2,.2,1")
  pfUI:UpdateConfig("unitframes", nil,           "custompbg",        "0")
  pfUI:UpdateConfig("unitframes", nil,           "custompbgcolor",   ".5,.2,.2,1")
  pfUI:UpdateConfig("unitframes", nil,           "manacolor",        ".5,.5,1,1")
  pfUI:UpdateConfig("unitframes", nil,           "energycolor",      "1,1,.5,1")
  pfUI:UpdateConfig("unitframes", nil,           "ragecolor",        "1,.5,.5,1")
  pfUI:UpdateConfig("unitframes", nil,           "focuscolor",       "1,1,.75,1")

  pfUI:UpdateConfig("unitframes", nil,           "animation_speed",  "5")
  pfUI:UpdateConfig("unitframes", nil,           "portraitalpha",    "0.1")
  pfUI:UpdateConfig("unitframes", nil,           "always2dportrait", "0")
  pfUI:UpdateConfig("unitframes", nil,           "portraittexture",  "1")
  pfUI:UpdateConfig("unitframes", nil,           "layout",           "default")
  pfUI:UpdateConfig("unitframes", nil,           "rangecheck",       "0")
  pfUI:UpdateConfig("unitframes", nil,           "losfade",          "1")
  pfUI:UpdateConfig("unitframes", nil,           "buffdetect",       "1")
  pfUI:UpdateConfig("unitframes", nil,           "druidmanabar",     "1")
  pfUI:UpdateConfig("unitframes", nil,           "druidmanaheight",  "2")
  pfUI:UpdateConfig("unitframes", nil,           "druidmanatext",    "0")
  pfUI:UpdateConfig("unitframes", nil,           "rangechecki",      "4")
  pfUI:UpdateConfig("unitframes", nil,           "combowidth",       "6")
  pfUI:UpdateConfig("unitframes", nil,           "comboheight",      "6")
  pfUI:UpdateConfig("unitframes", nil,           "abbrevnum",        "1")
  pfUI:UpdateConfig("unitframes", nil,           "abbrevname",       "1")

  pfUI:UpdateConfig("unitframes", nil,           "selfingroup",      "0")
  pfUI:UpdateConfig("unitframes", nil,           "selfinraid",       "0")
  pfUI:UpdateConfig("unitframes", nil,           "raidforgroup",     "0")
  pfUI:UpdateConfig("unitframes", nil,           "maxraid",          "40")

  pfUI:UpdateConfig("unitframes", nil,           "clickcast",        "target")
  pfUI:UpdateConfig("unitframes", nil,           "clickcast_shift",  "")
  pfUI:UpdateConfig("unitframes", nil,           "clickcast_alt",    "")
  pfUI:UpdateConfig("unitframes", nil,           "clickcast_ctrl",   "")

  pfUI:UpdateConfig("unitframes", nil,           "clickcast2",        "menu")
  pfUI:UpdateConfig("unitframes", nil,           "clickcast2_shift",  "")
  pfUI:UpdateConfig("unitframes", nil,           "clickcast2_alt",    "")
  pfUI:UpdateConfig("unitframes", nil,           "clickcast2_ctrl",   "")

  pfUI:UpdateConfig("unitframes", nil,           "clickcast3",        "")
  pfUI:UpdateConfig("unitframes", nil,           "clickcast3_shift",  "")
  pfUI:UpdateConfig("unitframes", nil,           "clickcast3_alt",    "")
  pfUI:UpdateConfig("unitframes", nil,           "clickcast3_ctrl",   "")

  pfUI:UpdateConfig("unitframes", nil,           "clickcast4",        "")
  pfUI:UpdateConfig("unitframes", nil,           "clickcast4_shift",  "")
  pfUI:UpdateConfig("unitframes", nil,           "clickcast4_alt",    "")
  pfUI:UpdateConfig("unitframes", nil,           "clickcast4_ctrl",   "")

  pfUI:UpdateConfig("unitframes", nil,           "clickcast5",        "")
  pfUI:UpdateConfig("unitframes", nil,           "clickcast5_shift",  "")
  pfUI:UpdateConfig("unitframes", nil,           "clickcast5_alt",    "")
  pfUI:UpdateConfig("unitframes", nil,           "clickcast5_ctrl",   "")

  pfUI:UpdateConfig("unitframes", "player",      "showPVPMinimap",   "0")
  pfUI:UpdateConfig("unitframes", "player",      "showRest",         "0")
  pfUI:UpdateConfig("unitframes", "player",      "energy",           "1")
  pfUI:UpdateConfig("unitframes", "player",      "manatick",         "0")

  pfUI:UpdateConfig("unitframes", "focus",       "width",            "120")
  pfUI:UpdateConfig("unitframes", "focus",       "height",           "34")
  pfUI:UpdateConfig("unitframes", "focus",       "pheight",          "4")
  pfUI:UpdateConfig("unitframes", "focus",       "buffsize",         "12")
  pfUI:UpdateConfig("unitframes", "focus",       "debuffsize",       "12")

  pfUI:UpdateConfig("unitframes", "focustarget", "visible",          "0")
  pfUI:UpdateConfig("unitframes", "focustarget", "width",            "80")
  pfUI:UpdateConfig("unitframes", "focustarget", "height",           "12")
  pfUI:UpdateConfig("unitframes", "focustarget", "pheight",          "-1")
  pfUI:UpdateConfig("unitframes", "focustarget", "buffs",            "off")
  pfUI:UpdateConfig("unitframes", "focustarget", "debuffs",          "off")
  pfUI:UpdateConfig("unitframes", "focustarget", "txthpleft",        "none")
  pfUI:UpdateConfig("unitframes", "focustarget", "txthpcenter",      "name")
  pfUI:UpdateConfig("unitframes", "focustarget", "txthpright",       "none")

  pfUI:UpdateConfig("unitframes", "group",       "portrait",         "off")
  pfUI:UpdateConfig("unitframes", "group",       "width",            "164")
  pfUI:UpdateConfig("unitframes", "group",       "height",           "32")
  pfUI:UpdateConfig("unitframes", "group",       "pheight",          "4")
  pfUI:UpdateConfig("unitframes", "group",       "buffs",            "BOTTOMLEFT")
  pfUI:UpdateConfig("unitframes", "group",       "buffsize",         "8")
  pfUI:UpdateConfig("unitframes", "group",       "debuffs",          "BOTTOMLEFT")
  pfUI:UpdateConfig("unitframes", "group",       "debuffsize",       "8")
  pfUI:UpdateConfig("unitframes", "group",       "debufflimit",      "8")
  pfUI:UpdateConfig("unitframes", "group",       "buff_indicator",   "1")
  pfUI:UpdateConfig("unitframes", "group",       "debuff_indicator", "2")
  pfUI:UpdateConfig("unitframes", "group",       "faderange",        "1")
  pfUI:UpdateConfig("unitframes", "group",       "glowcombat",       "0")
  pfUI:UpdateConfig("unitframes", "group",       "hide_in_raid",     "0")
  pfUI:UpdateConfig("unitframes", "group",       "txthpright",       "healthmiss")

  pfUI:UpdateConfig("unitframes", "grouptarget", "portrait",         "off")
  pfUI:UpdateConfig("unitframes", "grouptarget", "width",            "120")
  pfUI:UpdateConfig("unitframes", "grouptarget", "height",           "16")
  pfUI:UpdateConfig("unitframes", "grouptarget", "pheight",          "0")
  pfUI:UpdateConfig("unitframes", "grouptarget", "buffs",            "off")
  pfUI:UpdateConfig("unitframes", "grouptarget", "buffsize",         "16")
  pfUI:UpdateConfig("unitframes", "grouptarget", "debuffs",          "off")
  pfUI:UpdateConfig("unitframes", "grouptarget", "debuffsize",       "16")
  pfUI:UpdateConfig("unitframes", "grouptarget", "faderange",        "1")
  pfUI:UpdateConfig("unitframes", "grouptarget", "glowcombat",       "0")
  pfUI:UpdateConfig("unitframes", "grouptarget", "txthpright",       "healthperc")

  pfUI:UpdateConfig("unitframes", "grouppet",    "portrait",         "off")
  pfUI:UpdateConfig("unitframes", "grouppet",    "width",            "100")
  pfUI:UpdateConfig("unitframes", "grouppet",    "height",           "14")
  pfUI:UpdateConfig("unitframes", "grouppet",    "pheight",          "0")
  pfUI:UpdateConfig("unitframes", "grouppet",    "buffs",            "off")
  pfUI:UpdateConfig("unitframes", "grouppet",    "buffsize",         "16")
  pfUI:UpdateConfig("unitframes", "grouppet",    "debuffs",          "off")
  pfUI:UpdateConfig("unitframes", "grouppet",    "debuffsize",       "16")
  pfUI:UpdateConfig("unitframes", "grouppet",    "faderange",        "1")
  pfUI:UpdateConfig("unitframes", "grouppet",    "glowcombat",       "0")
  pfUI:UpdateConfig("unitframes", "grouppet",    "txthpright",       "healthperc")

  pfUI:UpdateConfig("unitframes", "raid",        "portrait",         "off")
  pfUI:UpdateConfig("unitframes", "raid",        "width",            "50")
  pfUI:UpdateConfig("unitframes", "raid",        "height",           "26")
  pfUI:UpdateConfig("unitframes", "raid",        "pheight",          "4")
  pfUI:UpdateConfig("unitframes", "raid",        "buffs",            "off")
  pfUI:UpdateConfig("unitframes", "raid",        "buffsize",         "16")
  pfUI:UpdateConfig("unitframes", "raid",        "debuffs",          "off")
  pfUI:UpdateConfig("unitframes", "raid",        "debuffsize",       "16")
  pfUI:UpdateConfig("unitframes", "raid",        "buff_indicator",   "1")
  pfUI:UpdateConfig("unitframes", "raid",        "debuff_indicator", "2")
  pfUI:UpdateConfig("unitframes", "raid",        "faderange",        "1")
  pfUI:UpdateConfig("unitframes", "raid",        "glowcombat",       "0")
  pfUI:UpdateConfig("unitframes", "raid",        "txthpleft",        "name")
  pfUI:UpdateConfig("unitframes", "raid",        "txthpright",       "healthmiss")
  pfUI:UpdateConfig("unitframes", "raid",        "overhealperc",     "10")
  pfUI:UpdateConfig("unitframes", "raid",        "raidlayout",       "8x5")
  pfUI:UpdateConfig("unitframes", "raid",        "raidpadding",      "3")
  pfUI:UpdateConfig("unitframes", "raid",        "raidfill",         "VERTICAL")
  pfUI:UpdateConfig("unitframes", "raid",        "raidgrouplabel",   "0")
  pfUI:UpdateConfig("unitframes", "raid",        "grouplabelxoff",   "0")
  pfUI:UpdateConfig("unitframes", "raid",        "grouplabelyoff",   "8")
  pfUI:UpdateConfig("unitframes", "raid",        "squareaggro",      "1")
  pfUI:UpdateConfig("unitframes", "raid",        "squaresize",       "6")

  pfUI:UpdateConfig("unitframes", "ttarget",     "width",            "100")
  pfUI:UpdateConfig("unitframes", "ttarget",     "height",           "17")
  pfUI:UpdateConfig("unitframes", "ttarget",     "pheight",          "3")
  pfUI:UpdateConfig("unitframes", "ttarget",     "buffs",            "off")
  pfUI:UpdateConfig("unitframes", "ttarget",     "buffsize",         "16")
  pfUI:UpdateConfig("unitframes", "ttarget",     "debuffs",          "off")
  pfUI:UpdateConfig("unitframes", "ttarget",     "debuffsize",       "16")
  pfUI:UpdateConfig("unitframes", "ttarget",     "txthpleft",        "none")
  pfUI:UpdateConfig("unitframes", "ttarget",     "txthpcenter",      "name")
  pfUI:UpdateConfig("unitframes", "ttarget",     "txthpright",       "none")
  pfUI:UpdateConfig("unitframes", "ttarget",     "overhealperc",     "10")

  pfUI:UpdateConfig("unitframes", "tttarget",    "visible",          "0")
  pfUI:UpdateConfig("unitframes", "tttarget",    "width",            "100")
  pfUI:UpdateConfig("unitframes", "tttarget",    "height",           "17")
  pfUI:UpdateConfig("unitframes", "tttarget",    "pheight",          "3")
  pfUI:UpdateConfig("unitframes", "tttarget",    "buffs",            "off")
  pfUI:UpdateConfig("unitframes", "tttarget",    "buffsize",         "16")
  pfUI:UpdateConfig("unitframes", "tttarget",    "debuffs",          "off")
  pfUI:UpdateConfig("unitframes", "tttarget",    "debuffsize",       "16")
  pfUI:UpdateConfig("unitframes", "tttarget",    "txthpleft",        "none")
  pfUI:UpdateConfig("unitframes", "tttarget",    "txthpcenter",      "name")
  pfUI:UpdateConfig("unitframes", "tttarget",    "txthpright",       "none")
  pfUI:UpdateConfig("unitframes", "tttarget",    "overhealperc",     "10")

  pfUI:UpdateConfig("unitframes", "pet",         "happinessicon",    "2")
  pfUI:UpdateConfig("unitframes", "pet",         "happinesssize",    "12")
  pfUI:UpdateConfig("unitframes", "pet",         "width",            "100")
  pfUI:UpdateConfig("unitframes", "pet",         "height",           "14")
  pfUI:UpdateConfig("unitframes", "pet",         "pheight",          "4")
  pfUI:UpdateConfig("unitframes", "pet",         "buffsize",         "12")
  pfUI:UpdateConfig("unitframes", "pet",         "debuffsize",       "12")
  pfUI:UpdateConfig("unitframes", "pet",         "txthpleft",        "none")
  pfUI:UpdateConfig("unitframes", "pet",         "txthpcenter",      "name")
  pfUI:UpdateConfig("unitframes", "pet",         "txthpright",       "none")

  pfUI:UpdateConfig("unitframes", "ptarget",     "visible",          "0")
  pfUI:UpdateConfig("unitframes", "ptarget",     "width",            "100")
  pfUI:UpdateConfig("unitframes", "ptarget",     "height",           "4")
  pfUI:UpdateConfig("unitframes", "ptarget",     "pheight",          "-1")
  pfUI:UpdateConfig("unitframes", "ptarget",     "buffs",            "off")
  pfUI:UpdateConfig("unitframes", "ptarget",     "buffsize",         "16")
  pfUI:UpdateConfig("unitframes", "ptarget",     "debuffs",          "off")
  pfUI:UpdateConfig("unitframes", "ptarget",     "debuffsize",       "16")
  pfUI:UpdateConfig("unitframes", "ptarget",     "txthpleft",        "none")
  pfUI:UpdateConfig("unitframes", "ptarget",     "txthpcenter",      "name")
  pfUI:UpdateConfig("unitframes", "ptarget",     "txthpright",       "none")
  pfUI:UpdateConfig("unitframes", "ptarget",     "overhealperc",     "10")

  local ufs = { "player", "target", "focus", "focustarget", "group", "grouptarget", "grouppet", "raid", "ttarget", "pet", "ptarget", "fallback", "tttarget" }
  for _, unit in pairs(ufs) do
    pfUI:UpdateConfig("unitframes", unit,      "visible",          "1")
    pfUI:UpdateConfig("unitframes", unit,      "showPVP",          "0")
    pfUI:UpdateConfig("unitframes", unit,      "pvpiconsize",      "16" )
    pfUI:UpdateConfig("unitframes", unit,      "pvpiconalign",     "CENTER")
    pfUI:UpdateConfig("unitframes", unit,      "pvpiconoffx",      "0")
    pfUI:UpdateConfig("unitframes", unit,      "pvpiconoffy",      "0")
    pfUI:UpdateConfig("unitframes", unit,      "raidicon",         "1")
    pfUI:UpdateConfig("unitframes", unit,      "raidiconalign",    "CENTER")
    pfUI:UpdateConfig("unitframes", unit,      "raidiconoffx",     "0")
    pfUI:UpdateConfig("unitframes", unit,      "raidiconoffy",     "20")
    pfUI:UpdateConfig("unitframes", unit,      "leadericon",       "1")
    pfUI:UpdateConfig("unitframes", unit,      "looticon",         "1")
    pfUI:UpdateConfig("unitframes", unit,      "raidiconsize",     "24")
    pfUI:UpdateConfig("unitframes", unit,      "portrait",         "bar")
    pfUI:UpdateConfig("unitframes", unit,      "bartexture",       "Interface\\AddOns\\pfUI\\img\\bar")
    pfUI:UpdateConfig("unitframes", unit,      "pbartexture",       "Interface\\AddOns\\pfUI\\img\\bar")
    pfUI:UpdateConfig("unitframes", unit,      "width",            "200")
    pfUI:UpdateConfig("unitframes", unit,      "height",           "46")
    pfUI:UpdateConfig("unitframes", unit,      "pheight",          "10")
    pfUI:UpdateConfig("unitframes", unit,      "pwidth",           "-1")
    pfUI:UpdateConfig("unitframes", unit,      "poffx",           "0")
    pfUI:UpdateConfig("unitframes", unit,      "poffy",           "0")
    pfUI:UpdateConfig("unitframes", unit,      "portraitheight",   "-1")
    pfUI:UpdateConfig("unitframes", unit,      "portraitwidth",    "-1")
    pfUI:UpdateConfig("unitframes", unit,      "panchor",          "TOP")
    pfUI:UpdateConfig("unitframes", unit,      "pspace",           "-3")
    pfUI:UpdateConfig("unitframes", unit,      "cooldown_text",    "1")
    pfUI:UpdateConfig("unitframes", unit,      "cooldown_anim",    "0")
    pfUI:UpdateConfig("unitframes", unit,      "cooldown_reverse", "1")
    pfUI:UpdateConfig("unitframes", unit,      "buffs",            "TOPLEFT")
    pfUI:UpdateConfig("unitframes", unit,      "buffsize",         "20")
    pfUI:UpdateConfig("unitframes", unit,      "bufflimit",        "32")
    pfUI:UpdateConfig("unitframes", unit,      "buffperrow",       "8")
    pfUI:UpdateConfig("unitframes", unit,      "debuffs",          "TOPLEFT")
    pfUI:UpdateConfig("unitframes", unit,      "debuffsize",       "20")
    pfUI:UpdateConfig("unitframes", unit,      "debufflimit",      "32")
    pfUI:UpdateConfig("unitframes", unit,      "debuffperrow",     "8")
    pfUI:UpdateConfig("unitframes", unit,      "selfdebuff",       "0")
    pfUI:UpdateConfig("unitframes", unit,      "invert_healthbar", "0")
    pfUI:UpdateConfig("unitframes", unit,      "verticalbar",      "0")
    pfUI:UpdateConfig("unitframes", unit,      "buff_indicator",   "0")
    pfUI:UpdateConfig("unitframes", unit,      "debuff_indicator", "0")
    pfUI:UpdateConfig("unitframes", unit,      "custom_indicator", "")

    pfUI:UpdateConfig("unitframes", unit,      "debuff_ind_pos",   "CENTER")
    pfUI:UpdateConfig("unitframes", unit,      "debuff_ind_size",  ".65")
    pfUI:UpdateConfig("unitframes", unit,      "debuff_ind_class", "1")

    pfUI:UpdateConfig("unitframes", unit,      "show_buffs",       "1")
    pfUI:UpdateConfig("unitframes", unit,      "show_hots",        "0")
    pfUI:UpdateConfig("unitframes", unit,      "all_hots",         "0")
    pfUI:UpdateConfig("unitframes", unit,      "show_procs",       "0")
    pfUI:UpdateConfig("unitframes", unit,      "show_totems",      "0")
    pfUI:UpdateConfig("unitframes", unit,      "all_procs",        "0")
    pfUI:UpdateConfig("unitframes", unit,      "indicator_time",   "1")
    pfUI:UpdateConfig("unitframes", unit,      "indicator_stacks", "1")
    pfUI:UpdateConfig("unitframes", unit,      "indicator_size",   "10")
    pfUI:UpdateConfig("unitframes", unit,      "indicator_spacing","1")
    pfUI:UpdateConfig("unitframes", unit,      "indicator_pos",    "TOPLEFT")

    pfUI:UpdateConfig("unitframes", unit,      "clickcast",        "0")
    pfUI:UpdateConfig("unitframes", unit,      "faderange",        "0")
    pfUI:UpdateConfig("unitframes", unit,      "alpha_visible",    "1")
    pfUI:UpdateConfig("unitframes", unit,      "alpha_outrange",   ".50")
    pfUI:UpdateConfig("unitframes", unit,      "alpha_offline",    ".25")
    pfUI:UpdateConfig("unitframes", unit,      "squareaggro",      "0")
    pfUI:UpdateConfig("unitframes", unit,      "squarecombat",     "0")
    pfUI:UpdateConfig("unitframes", unit,      "squaresize",       "8")
    pfUI:UpdateConfig("unitframes", unit,      "squarepos",        "TOPLEFT")

    pfUI:UpdateConfig("unitframes", unit,      "glowaggro",        "1")
    pfUI:UpdateConfig("unitframes", unit,      "glowcombat",       "1")
    pfUI:UpdateConfig("unitframes", unit,      "showtooltip",      "1")
    pfUI:UpdateConfig("unitframes", unit,      "healthcolor",      "1")
    pfUI:UpdateConfig("unitframes", unit,      "powercolor",       "1")
    pfUI:UpdateConfig("unitframes", unit,      "levelcolor",       "1")
    pfUI:UpdateConfig("unitframes", unit,      "classcolor",       "1")
    pfUI:UpdateConfig("unitframes", unit,      "txthpleft",        "unit")
    pfUI:UpdateConfig("unitframes", unit,      "txthpleftoffx",    "0")
    pfUI:UpdateConfig("unitframes", unit,      "txthpleftoffy",    "0")
    pfUI:UpdateConfig("unitframes", unit,      "txthpcenter",      "none")
    pfUI:UpdateConfig("unitframes", unit,      "txthpcenteroffx",    "0")
    pfUI:UpdateConfig("unitframes", unit,      "txthpcenteroffy",    "0")
    pfUI:UpdateConfig("unitframes", unit,      "txthpright",       "healthdyn")
    pfUI:UpdateConfig("unitframes", unit,      "txthprightoffx",    "0")
    pfUI:UpdateConfig("unitframes", unit,      "txthprightoffy",    "0")
    pfUI:UpdateConfig("unitframes", unit,      "txtpowerleft",     "none")
    pfUI:UpdateConfig("unitframes", unit,      "txtpowerleftoffx",    "0")
    pfUI:UpdateConfig("unitframes", unit,      "txtpowerleftoffy",    "0")
    pfUI:UpdateConfig("unitframes", unit,      "txtpowercenter",   "none")
    pfUI:UpdateConfig("unitframes", unit,      "txtpowercenteroffx",    "0")
    pfUI:UpdateConfig("unitframes", unit,      "txtpowercenteroffy",    "0")
    pfUI:UpdateConfig("unitframes", unit,      "txtpowerright",    "none")
    pfUI:UpdateConfig("unitframes", unit,      "txtpowerrightoffx",    "0")
    pfUI:UpdateConfig("unitframes", unit,      "txtpowerrightoffy",    "0")
    pfUI:UpdateConfig("unitframes", unit,      "hitindicator",     "0")
    pfUI:UpdateConfig("unitframes", unit,      "hitindicatorsize", "15")
    pfUI:UpdateConfig("unitframes", unit,      "hitindicatorfont", "Interface\\AddOns\\pfUI\\fonts\\Continuum.ttf")
    pfUI:UpdateConfig("unitframes", unit,      "defcolor",         "1")
    pfUI:UpdateConfig("unitframes", unit,      "custom",           "0")
    pfUI:UpdateConfig("unitframes", unit,      "customfullhp",     "0")
    pfUI:UpdateConfig("unitframes", unit,      "customfade",       "0")
    pfUI:UpdateConfig("unitframes", unit,      "customcolor",      ".2,.2,.2,1")
    pfUI:UpdateConfig("unitframes", unit,      "custombg",         "0")
    pfUI:UpdateConfig("unitframes", unit,      "custombgcolor",    ".5,.2,.2,1")
    pfUI:UpdateConfig("unitframes", unit,      "custompbg",        "0")
    pfUI:UpdateConfig("unitframes", unit,      "custompbgcolor",   ".5,.2,.2,1")
    pfUI:UpdateConfig("unitframes", unit,      "manacolor",        ".5,.5,1,1")
    pfUI:UpdateConfig("unitframes", unit,      "energycolor",      "1,1,.5,1")
    pfUI:UpdateConfig("unitframes", unit,      "ragecolor",        "1,.5,.5,1")
    pfUI:UpdateConfig("unitframes", unit,      "focuscolor",       "1,1,.75,1")
    pfUI:UpdateConfig("unitframes", unit,      "healcolor",        "0,1,0,0.6")
    pfUI:UpdateConfig("unitframes", unit,      "overhealperc",     "20")
    pfUI:UpdateConfig("unitframes", unit,      "customfont",       "0")
    pfUI:UpdateConfig("unitframes", unit,      "customfont_name",  "Interface\\AddOns\\pfUI\\fonts\\BigNoodleTitling.ttf")
    pfUI:UpdateConfig("unitframes", unit,      "customfont_size",  "12")
    pfUI:UpdateConfig("unitframes", unit,      "customfont_style", "OUTLINE")
    -- octo (unitframes-octo.lua): TPerl's ideas on pfUI's frames
    pfUI:UpdateConfig("unitframes", unit,      "o_skin",           "pfui")
    for _, k in pairs({ "o_buffx", "o_buffy", "o_debuffx", "o_debuffy" }) do
      pfUI:UpdateConfig("unitframes", unit,    k,                  "0")
    end
    -- each text's own colour: "" = its own colours, "class", "custom" (o_tcc_)
    for _, pos in pairs({ "hpleft", "hpcenter", "hpright", "powerleft", "powercenter", "powerright" }) do
      pfUI:UpdateConfig("unitframes", unit,    "o_tc_" .. pos,     "")
      pfUI:UpdateConfig("unitframes", unit,    "o_tcc_" .. pos,    "1,1,1,1")
    end
    pfUI:UpdateConfig("unitframes", unit,      "o_grad",           "none")
    pfUI:UpdateConfig("unitframes", unit,      "o_gradstart",      ".1,.1,.1,.8")
    pfUI:UpdateConfig("unitframes", unit,      "o_gradend",        ".3,.3,.3,.8")
    pfUI:UpdateConfig("unitframes", unit,      "o_fade",           "0")
    pfUI:UpdateConfig("unitframes", unit,      "o_fadetime",       ".6")
    pfUI:UpdateConfig("unitframes", unit,      "o_fadecolor",      "1,.9,.6,.7")
    pfUI:UpdateConfig("unitframes", unit,      "o_flash",          "0")
    pfUI:UpdateConfig("unitframes", unit,      "o_debuffhl",       "none")
    pfUI:UpdateConfig("unitframes", unit,      "o_curable",        "1")
    pfUI:UpdateConfig("unitframes", unit,      "o_selhl",          (unit == "group" or unit == "raid") and "1" or "0")
    pfUI:UpdateConfig("unitframes", unit,      "o_classicon",      "none")
    pfUI:UpdateConfig("unitframes", unit,      "o_classsize",      "14")
    pfUI:UpdateConfig("unitframes", unit,      "o_classport",      "0")
    pfUI:UpdateConfig("unitframes", unit,      "o_elite",          (unit == "target" or unit == "focus") and "graphic" or "none")
    pfUI:UpdateConfig("unitframes", unit,      "o_elitepos",       "TOPRIGHT")
    pfUI:UpdateConfig("unitframes", unit,      "o_status",         "1")
    pfUI:UpdateConfig("unitframes", unit,      "o_purge",          (unit == "target" or unit == "focus") and "1" or "0")
    -- (1 Nov 2026, user: "cast bars show on raid frames of our members")
    pfUI:UpdateConfig("unitframes", unit,      "o_cast",           (unit == "group" or unit == "raid") and "1" or "0")
  end
  pfUI:UpdateConfig("unitframes", "player",      "o_flashexpire",    "0")
  pfUI:UpdateConfig("unitframes", "pet",         "o_happysad",       "0")
  pfUI:UpdateConfig("unitframes", "pet",         "o_happyflash",     "0")
  pfUI:UpdateConfig("unitframes", nil,           "o_targetsound",    "0")

  pfUI:UpdateConfig("bars",       "bar1",        "pageable",         "1")
  pfUI:UpdateConfig("bars",       "bar2",        "pageable",         "1")

  pfUI:UpdateConfig("bars",       "bar1",        "enable",           "1")
  pfUI:UpdateConfig("bars",       "bar3",        "enable",           "1")
  pfUI:UpdateConfig("bars",       "bar4",        "enable",           "1")
  pfUI:UpdateConfig("bars",       "bar5",        "enable",           "1")
  pfUI:UpdateConfig("bars",       "bar6",        "enable",           "1")
  pfUI:UpdateConfig("bars",       "bar11",       "enable",           "1")
  pfUI:UpdateConfig("bars",       "bar12",       "enable",           "1")

  pfUI:UpdateConfig("bars",       "bar3",        "formfactor",       "6 x 2")
  pfUI:UpdateConfig("bars",       "bar5",        "formfactor",       "6 x 2")
  pfUI:UpdateConfig("bars",       "bar4",        "formfactor",       "1 x 12")
  pfUI:UpdateConfig("bars",       "bar11",       "formfactor",       "10 x 1")
  pfUI:UpdateConfig("bars",       "bar12",       "formfactor",       "10 x 1")

  pfUI:UpdateConfig("bars",       "bar11",       "icon_size",        "18")
  pfUI:UpdateConfig("bars",       "bar12",       "icon_size",        "18")

  for i=1,12 do
    pfUI:UpdateConfig("bars",     "bar"..i,      "enable",           "0")
    pfUI:UpdateConfig("bars",     "bar"..i,      "pageable",         "0")
    pfUI:UpdateConfig("bars",     "bar"..i,      "icon_size",        "20")
    pfUI:UpdateConfig("bars",     "bar"..i,      "spacing",          "1")
    pfUI:UpdateConfig("bars",     "bar"..i,      "formfactor",       "12 x 1")
    pfUI:UpdateConfig("bars",     "bar"..i,      "background",       "1")
    pfUI:UpdateConfig("bars",     "bar"..i,      "showempty",        "1")
    pfUI:UpdateConfig("bars",     "bar"..i,      "showmacro",        "1")
    pfUI:UpdateConfig("bars",     "bar"..i,      "showkeybind",      "1")
    pfUI:UpdateConfig("bars",     "bar"..i,      "showcount",        "1")
    pfUI:UpdateConfig("bars",     "bar"..i,      "autohide",         "0")
    pfUI:UpdateConfig("bars",     "bar"..i,      "hide_time",        "3")
    pfUI:UpdateConfig("bars",     "bar"..i,      "hide_combat",      "1")
    -- octo (actionbar-octo.lua): scale, opacity, fade-to, visibility rules
    pfUI:UpdateConfig("bars",     "bar"..i,      "scale",            "1")
    pfUI:UpdateConfig("bars",     "bar"..i,      "alpha",            "1")
    pfUI:UpdateConfig("bars",     "bar"..i,      "fadeto",           "0")
    pfUI:UpdateConfig("bars",     "bar"..i,      "vis_combat",       "any")
    pfUI:UpdateConfig("bars",     "bar"..i,      "vis_pet",          "any")
    pfUI:UpdateConfig("bars",     "bar"..i,      "vis_target",       "any")
    pfUI:UpdateConfig("bars",     "bar"..i,      "vis_stealth",      "any")
    if i ~= 11 and i ~= 12 then
      pfUI:UpdateConfig("bars",     "bar"..i,      "buttons",           "12")
    end
  end

  pfUI:UpdateConfig("bars",       nil,           "skin",             "pfui")
  pfUI:UpdateConfig("bars",       nil,           "zoom",             ".08")
  -- octo (actionbar-octo.lua): hover / press looks, proc glows, cooldown
  -- swipe, empty slot fill, equipped border
  pfUI:UpdateConfig("bars",       nil,           "hover_style",      "pfui")
  pfUI:UpdateConfig("bars",       nil,           "hover_color",      "1,1,1,.8")
  pfUI:UpdateConfig("bars",       nil,           "hover_color_class","0")
  pfUI:UpdateConfig("bars",       nil,           "hover_size",       "1")
  pfUI:UpdateConfig("bars",       nil,           "press_style",      "pfui")
  pfUI:UpdateConfig("bars",       nil,           "press_color",      "1,.82,0,.9")
  pfUI:UpdateConfig("bars",       nil,           "press_color_class","0")
  pfUI:UpdateConfig("bars",       nil,           "press_size",       "2")
  pfUI:UpdateConfig("bars",       nil,           "glow_style",       "ants")
  pfUI:UpdateConfig("bars",       nil,           "glow_color",       "1,.82,0,1")
  pfUI:UpdateConfig("bars",       nil,           "glow_color_class", "0")
  pfUI:UpdateConfig("bars",       nil,           "glow_lines",       "8")
  pfUI:UpdateConfig("bars",       nil,           "glow_thick",       "2")
  pfUI:UpdateConfig("bars",       nil,           "glow_speed",       "4")
  pfUI:UpdateConfig("bars",       nil,           "glow_reactive",    "1")
  pfUI:UpdateConfig("bars",       nil,           "glow_procs",       "1")
  pfUI:UpdateConfig("bars",       nil,           "glow_burst",       "1")
  pfUI:UpdateConfig("bars",       nil,           "cd_style",         "clock")
  pfUI:UpdateConfig("bars",       nil,           "cd_color",         "0,0,0,.65")
  pfUI:UpdateConfig("bars",       nil,           "cd_color_class",   "0")
  pfUI:UpdateConfig("bars",       nil,           "cd_edge",          "1")
  pfUI:UpdateConfig("bars",       nil,           "cd_edgecolor",     "1,.9,.5,1")
  pfUI:UpdateConfig("bars",       nil,           "cd_edgecolor_class","0")
  pfUI:UpdateConfig("bars",       nil,           "slot_style",       "pfui")
  pfUI:UpdateConfig("bars",       nil,           "slot_color",       ".1,.1,.1,.6")
  pfUI:UpdateConfig("bars",       nil,           "slot_color_class", "0")
  -- each skin part's colour / size ("" = the skin's own; actionbar-octo.lua AB.PARTS)
  for _, part in pairs({ "edge", "line2", "outer", "gloss", "shade", "frame" }) do
    pfUI:UpdateConfig("bars",     nil,           "skin_" .. part,    "")
    pfUI:UpdateConfig("bars",     nil,           "skin_" .. part .. "_class", "0")
  end
  pfUI:UpdateConfig("bars",       nil,           "skin_edgesize",    "")
  pfUI:UpdateConfig("bars",       nil,           "skin_outersize",   "")
  pfUI:UpdateConfig("bars",       nil,           "bar_bg",           "")
  pfUI:UpdateConfig("bars",       nil,           "eq_style",         "fill")
  pfUI:UpdateConfig("bars",       nil,           "eq_size",          "2")
  pfUI:UpdateConfig("bars",       nil,           "keydown",          "0")
  pfUI:UpdateConfig("bars",       nil,           "altself",          "0")
  pfUI:UpdateConfig("bars",       nil,           "rightself",        "0")
  pfUI:UpdateConfig("bars",       nil,           "animation",        "zoomfade")
  pfUI:UpdateConfig("bars",       nil,           "animmode",         "keypress")
  pfUI:UpdateConfig("bars",       nil,           "animalways",       "0")
  pfUI:UpdateConfig("bars",       nil,           "macroscan",        "1")
  pfUI:UpdateConfig("bars",       nil,           "reagents",         "1")
  pfUI:UpdateConfig("bars",       nil,           "hunterbar",        "0")
  pfUI:UpdateConfig("bars",       nil,           "pagemasteralt",    "0")
  pfUI:UpdateConfig("bars",       nil,           "pagemastershift",  "0")
  pfUI:UpdateConfig("bars",       nil,           "pagemasterctrl",   "0")
  pfUI:UpdateConfig("bars",       nil,           "druidstealth",     "0")
  pfUI:UpdateConfig("bars",       nil,           "showcastable",     "1")
  pfUI:UpdateConfig("bars",       nil,           "glowrange",        "1")
  pfUI:UpdateConfig("bars",       nil,           "rangecolor",       "1,0.1,0.1,1")
  pfUI:UpdateConfig("bars",       nil,           "showoom",          "1")
  pfUI:UpdateConfig("bars",       nil,           "oomcolor",         ".2,.2,1,1")
  pfUI:UpdateConfig("bars",       nil,           "showna",           "1")
  pfUI:UpdateConfig("bars",       nil,           "nacolor",          ".3,.3,.3,1")
  pfUI:UpdateConfig("bars",       nil,           "showequipped",     "1")
  pfUI:UpdateConfig("bars",       nil,           "eqcolor",          ".2,.8,.2,.2")
  pfUI:UpdateConfig("bars",       nil,           "shiftdrag",        "1")

  pfUI:UpdateConfig("bars",       nil,           "font",             "Interface\\AddOns\\pfUI\\fonts\\BigNoodleTitling.ttf")
  pfUI:UpdateConfig("bars",       nil,           "font_offset",      "0")
  pfUI:UpdateConfig("bars",       nil,           "macro_size",       "9")
  pfUI:UpdateConfig("bars",       nil,           "macro_color",      "1,1,1,1")
  pfUI:UpdateConfig("bars",       nil,           "count_size",       "11")
  pfUI:UpdateConfig("bars",       nil,           "count_color",      ".2,1,.8,1")
  pfUI:UpdateConfig("bars",       nil,           "bind_size",        "8")
  pfUI:UpdateConfig("bars",       nil,           "bind_color",       "1,1,0,1")
  pfUI:UpdateConfig("bars",       nil,           "cd_size",          "12")

  pfUI:UpdateConfig("bars",       "gryphons",    "texture",          "None")
  pfUI:UpdateConfig("bars",       "gryphons",    "color",            ".6,.6,.6,1")
  pfUI:UpdateConfig("bars",       "gryphons",    "size",             "64")
  pfUI:UpdateConfig("bars",       "gryphons",    "anchor_left",      "pfActionBarLeft")
  pfUI:UpdateConfig("bars",       "gryphons",    "anchor_right",     "pfActionBarRight")
  pfUI:UpdateConfig("bars",       "gryphons",    "offset_h",         "-48")
  pfUI:UpdateConfig("bars",       "gryphons",    "offset_v",         "-4")
  pfUI:UpdateConfig("bars",       "gryphons",    "sides",            "both")
  pfUI:UpdateConfig("bars",       "gryphons",    "mirror",           "0")

  pfUI:UpdateConfig("totems",     nil,           "direction",        "HORIZONTAL")
  pfUI:UpdateConfig("totems",     nil,           "iconsize",         "26")
  pfUI:UpdateConfig("totems",     nil,           "spacing",          "3")
  pfUI:UpdateConfig("totems",     nil,           "showbg",           "0")

  pfUI:UpdateConfig("panel",      nil,           "use_unitfonts",    "0")
  pfUI:UpdateConfig("panel",      nil,           "hide_leftchat",    "0")
  pfUI:UpdateConfig("panel",      nil,           "hide_rightchat",   "0")
  pfUI:UpdateConfig("panel",      nil,           "arrow",            "1")
  pfUI:UpdateConfig("panel",      nil,           "arrowwins",        "m1,m2")
  pfUI:UpdateConfig("panel",      nil,           "arrowmode",        "chat")
  pfUI:UpdateConfig("panel",      nil,           "arrowside",        "right")
  pfUI:UpdateConfig("meters",     nil,           "threatsolo",       "1")
  pfUI:UpdateConfig("panel",      nil,           "arrowopen",        "0")
  pfUI:UpdateConfig("panel",      nil,           "hide_minimap",     "0")
  pfUI:UpdateConfig("panel",      nil,           "hide_microbar",    "0")
  pfUI:UpdateConfig("panel",      nil,           "seconds",          "1")
  pfUI:UpdateConfig("panel",      "left",        "left",             "guild")
  pfUI:UpdateConfig("panel",      "left",        "center",           "durability")
  pfUI:UpdateConfig("panel",      "left",        "right",            "friends")
  pfUI:UpdateConfig("panel",      "right",       "left",             "fps")
  pfUI:UpdateConfig("panel",      "right",       "center",           "time")
  pfUI:UpdateConfig("panel",      "right",       "right",            "gold")
  pfUI:UpdateConfig("panel",      "left",        "pwidth",           "0")
  pfUI:UpdateConfig("panel",      "left",        "pheight",          "0")
  pfUI:UpdateConfig("panel",      "right",       "pwidth",           "0")
  pfUI:UpdateConfig("panel",      "right",       "pheight",          "0")
  pfUI:UpdateConfig("panel",      "other",       "minimap",          "zone")
  pfUI:UpdateConfig("panel",      "micro",       "enable",           "0")
  pfUI:UpdateConfig("panel",      nil,           "fpscolors",        "1")

  pfUI:UpdateConfig("panel",      "bag",         "ignorespecial",    "1")
  pfUI:UpdateConfig("panel",      "xp",          "xp_always",        "0")
  pfUI:UpdateConfig("panel",      "xp",          "xp_display",       "XPFLEX")
  pfUI:UpdateConfig("panel",      "xp",          "xp_timeout",       "5")
  pfUI:UpdateConfig("panel",      "xp",          "xp_width",         "5")
  pfUI:UpdateConfig("panel",      "xp",          "xp_height",        "5")
  pfUI:UpdateConfig("panel",      "xp",          "xp_mode",          "VERTICAL")
  pfUI:UpdateConfig("panel",      "xp",          "xp_anchor",        "pfChatLeft")
  pfUI:UpdateConfig("panel",      "xp",          "xp_position",      "RIGHT")
  pfUI:UpdateConfig("panel",      "xp",          "xp_text",          "0")
  pfUI:UpdateConfig("panel",      "xp",          "xp_text_off_y",    "0")
  pfUI:UpdateConfig("panel",      "xp",          "xp_text_mouse",    "0")
  pfUI:UpdateConfig("panel",      "xp",          "xp_color",         ".25,.25,1,1")
  pfUI:UpdateConfig("panel",      "xp",          "rest_color",       "1,.25,1,.5")
  pfUI:UpdateConfig("panel",      "xp",          "texture",          "Interface\\AddOns\\pfUI\\img\\bar")

  pfUI:UpdateConfig("panel",      "xp",          "rep_always",       "0")
  pfUI:UpdateConfig("panel",      "xp",          "rep_display",      "REP")
  pfUI:UpdateConfig("panel",      "xp",          "rep_timeout",      "5")
  pfUI:UpdateConfig("panel",      "xp",          "rep_width",        "5")
  pfUI:UpdateConfig("panel",      "xp",          "rep_height",       "5")
  pfUI:UpdateConfig("panel",      "xp",          "rep_mode",         "VERTICAL")
  pfUI:UpdateConfig("panel",      "xp",          "rep_anchor",       "pfChatRight")
  pfUI:UpdateConfig("panel",      "xp",          "rep_position",     "LEFT")
  pfUI:UpdateConfig("panel",      "xp",          "rep_text",         "0")
  pfUI:UpdateConfig("panel",      "xp",          "rep_text_off_y",   "0")
  pfUI:UpdateConfig("panel",      "xp",          "rep_text_mouse",   "0")
  pfUI:UpdateConfig("panel",      "xp",          "dont_overlap",     "0")

  pfUI:UpdateConfig("castbar",    "player",      "hide_blizz",       "1")
  pfUI:UpdateConfig("castbar",    "player",      "hide_pfui",        "0")
  pfUI:UpdateConfig("castbar",    "player",      "width",            "-1")
  pfUI:UpdateConfig("castbar",    "player",      "height",           "-1")
  pfUI:UpdateConfig("castbar",    "player",      "showicon",         "0")
  pfUI:UpdateConfig("castbar",    "player",      "showname",         "1")
  pfUI:UpdateConfig("castbar",    "player",      "showtimer",        "1")
  pfUI:UpdateConfig("castbar",    "player",      "txtleftoffx",      "0")
  pfUI:UpdateConfig("castbar",    "player",      "txtleftoffy",      "0")
  pfUI:UpdateConfig("castbar",    "player",      "showlag",          "0")
  pfUI:UpdateConfig("castbar",    "player",        "showpush",         "1")
  pfUI:UpdateConfig("castbar",    "player",      "showrank",         "0")
  pfUI:UpdateConfig("castbar",    "player",      "spellqueue",       "1") -- octo: nampower's queued spell
  pfUI:UpdateConfig("castbar",    "player",      "txtrightoffx",     "0")
  pfUI:UpdateConfig("castbar",    "player",      "txtrightoffy",     "0")
  pfUI:UpdateConfig("castbar",    "target",      "hide_pfui",        "0")
  pfUI:UpdateConfig("castbar",    "target",      "width",            "-1")
  pfUI:UpdateConfig("castbar",    "target",      "height",           "-1")
  pfUI:UpdateConfig("castbar",    "target",      "showicon",         "0")
  pfUI:UpdateConfig("castbar",    "target",      "showname",         "1")
  pfUI:UpdateConfig("castbar",    "target",      "showtimer",        "1")
  pfUI:UpdateConfig("castbar",    "target",      "txtleftoffx",      "0")
  pfUI:UpdateConfig("castbar",    "target",      "txtleftoffy",      "0")
  pfUI:UpdateConfig("castbar",    "target",      "showlag",          "0")
  pfUI:UpdateConfig("castbar",    "target",        "showpush",         "1")
  pfUI:UpdateConfig("castbar",    "target",      "showrank",         "0")
  pfUI:UpdateConfig("castbar",    "target",      "txtrightoffx",     "0")
  pfUI:UpdateConfig("castbar",    "target",      "txtrightoffy",     "0")
  pfUI:UpdateConfig("castbar",    "focus",       "hide_pfui",        "0")
  pfUI:UpdateConfig("castbar",    "focus",       "width",            "-1")
  pfUI:UpdateConfig("castbar",    "focus",       "height",           "-1")
  pfUI:UpdateConfig("castbar",    "focus",       "showicon",         "0")
  pfUI:UpdateConfig("castbar",    "focus",       "showname",         "1")
  pfUI:UpdateConfig("castbar",    "focus",       "showtimer",        "1")
  pfUI:UpdateConfig("castbar",    "focus",       "txtleftoffx",      "0")
  pfUI:UpdateConfig("castbar",    "focus",       "txtleftoffy",      "0")
  pfUI:UpdateConfig("castbar",    "focus",       "showlag",          "0")
  pfUI:UpdateConfig("castbar",    "focus",         "showpush",         "1")
  pfUI:UpdateConfig("castbar",    "focus",       "showrank",         "0")
  pfUI:UpdateConfig("castbar",    "focus",       "txtrightoffx",     "0")
  pfUI:UpdateConfig("castbar",    "focus",       "txtrightoffy",     "0")
  pfUI:UpdateConfig("castbar",    nil,           "use_unitfonts",    "0")

  pfUI:UpdateConfig("tooltip",    nil,           "position",         "chat")
  pfUI:UpdateConfig("tooltip",    nil,           "cursoralign",      "native")
  pfUI:UpdateConfig("tooltip",    nil,           "cursoroffset",     "20")
  pfUI:UpdateConfig("tooltip",    nil,           "extguild",         "1")
  pfUI:UpdateConfig("tooltip",    nil,           "itemid",           "0")
  pfUI:UpdateConfig("tooltip",    nil,           "auracaster",       "1")
  pfUI:UpdateConfig("tooltip",    nil,           "itemcount",        "1") -- octo: bags / bank / worn counts
  pfUI:UpdateConfig("tooltip",    nil,           "alpha",            "0.8")
  pfUI:UpdateConfig("tooltip",    nil,           "alwaysperc",       "0")
  pfUI:UpdateConfig("tooltip",    "compare",     "basestats",        "1")
  pfUI:UpdateConfig("tooltip",    "compare",     "showalways",       "0")
  pfUI:UpdateConfig("tooltip",    "vendor",      "showalways",       "0")
  pfUI:UpdateConfig("tooltip",    "questitem",   "showquest",        "1")
  pfUI:UpdateConfig("tooltip",    "questitem",   "showcount",        "0")
  pfUI:UpdateConfig("tooltip",    "statusbar",   "texture",          "Interface\\AddOns\\pfUI\\img\\bar")
  pfUI:UpdateConfig("tooltip",     nil,          "font_tooltip",     "Interface\\AddOns\\pfUI\\fonts\\Myriad-Pro.ttf")
  pfUI:UpdateConfig("tooltip",     nil,          "font_tooltip_size", "12")

  pfUI:UpdateConfig("chat",       "text",        "input_width",      "0")
  pfUI:UpdateConfig("chat",       "text",        "input_height",     "0")
  pfUI:UpdateConfig("chat",       "text",        "outline",          "1")
  pfUI:UpdateConfig("chat",       "text",        "history",          "1")
  pfUI:UpdateConfig("chat",       "text",        "mouseover",        "0")
  pfUI:UpdateConfig("chat",       "text",        "bracket",          "[]")
  pfUI:UpdateConfig("chat",       "text",        "time",             "0")
  pfUI:UpdateConfig("chat",       "text",        "timeformat",       "%H:%M:%S")
  pfUI:UpdateConfig("chat",       "text",        "timebracket",      "[]")
  pfUI:UpdateConfig("chat",       "text",        "timecolor",        ".8,.8,.8,1")
  pfUI:UpdateConfig("chat",       "text",        "tintunknown",      "1")
  pfUI:UpdateConfig("chat",       "text",        "unknowncolor",     ".7,.7,.7,1")
  pfUI:UpdateConfig("chat",       "text",        "channelnumonly",   "1")
  pfUI:UpdateConfig("chat",       "text",        "playerlinks",      "1")
  pfUI:UpdateConfig("chat",       "text",        "detecturl",        "1")
  pfUI:UpdateConfig("chat",       "text",        "classcolor",       "1")
  pfUI:UpdateConfig("chat",       "text",        "whosearchunknown", "0")
  pfUI:UpdateConfig("chat",       "left",        "width",            "380")
  pfUI:UpdateConfig("chat",       "left",        "height",           "180")
  pfUI:UpdateConfig("chat",       "right",       "enable",           "0")
  pfUI:UpdateConfig("chat",       "right",       "width",            "380")
  pfUI:UpdateConfig("chat",       "right",       "height",           "180")
  pfUI:UpdateConfig("chat",       "global",      "hidecombat",       "0")
  pfUI:UpdateConfig("chat",       "global",      "tabdock",          "0")
  pfUI:UpdateConfig("chat",       "global",      "tabmouse",         "0")
  pfUI:UpdateConfig("chat",       "global",      "chatflash",        "1")
  pfUI:UpdateConfig("chat",       "global",      "maxlines",         "128")
  pfUI:UpdateConfig("chat",       "global",      "frameshadow",      "1")
  pfUI:UpdateConfig("chat",       "global",      "custombg",         "0")
  pfUI:UpdateConfig("chat",       "global",      "background",       ".2,.2,.2,.5")
  pfUI:UpdateConfig("chat",       "global",      "border",           ".4,.4,.4,.5")
  pfUI:UpdateConfig("chat",       "global",      "whispermod",       "1")
  pfUI:UpdateConfig("chat",       "global",      "whisper",          "1,.7,1,1")
  pfUI:UpdateConfig("chat",       "global",      "sticky",           "1")
  pfUI:UpdateConfig("chat",       "global",      "fadeout",          "0")
  pfUI:UpdateConfig("chat",       "global",      "fadetime",         "300")
  pfUI:UpdateConfig("chat",       "global",      "scrollspeed",      "1")
  pfUI:UpdateConfig("chat",       "bubbles",     "borders",          "1")
  -- octo chat-plus.lua (Prat's ideas): tags "Trade=T, World=W"; words / hide comma lists
  pfUI:UpdateConfig("chat",       "plus",        "tags",             "")
  pfUI:UpdateConfig("chat",       "plus",        "levels",           "0")
  pfUI:UpdateConfig("chat",       "plus",        "mention",          "1")
  pfUI:UpdateConfig("chat",       "plus",        "mentioncolor",     "1,.82,0,1")
  pfUI:UpdateConfig("chat",       "plus",        "mentionsound",     "none")
  pfUI:UpdateConfig("chat",       "plus",        "mentionpopup",     "0")
  pfUI:UpdateConfig("chat",       "plus",        "words",            "")
  pfUI:UpdateConfig("chat",       "plus",        "wordcolor",        "1,.5,.1,1")
  for _, k in pairs({ "whisper", "guild", "officer", "party", "raid", "bg", "say", "channel" }) do
    pfUI:UpdateConfig("chat",     "plus",        "sound_" .. k,      "none")
  end
  pfUI:UpdateConfig("chat",       "plus",        "throttle",         "0")
  pfUI:UpdateConfig("chat",       "plus",        "hide",             "")
  pfUI:UpdateConfig("chat",       "plus",        "wheeljump",        "1")
  pfUI:UpdateConfig("chat",       "plus",        "altinvite",        "1")
  pfUI:UpdateConfig("chat",       "plus",        "autoinvite",       "0")
  pfUI:UpdateConfig("chat",       "plus",        "inviteword",       "inv")
  pfUI:UpdateConfig("chat",       "plus",        "findlines",        "300")
  -- octo chat-whispers.lua: mode window | tab | off; combat pop | wait | fold
  pfUI:UpdateConfig("chat",       "whisper",     "mode",             "window")
  pfUI:UpdateConfig("chat",       "whisper",     "alsochat",         "1")
  pfUI:UpdateConfig("chat",       "whisper",     "sound",            "none")
  pfUI:UpdateConfig("chat",       "whisper",     "combat",           "fold")
  pfUI:UpdateConfig("chat",       "whisper",     "width",            "320")
  pfUI:UpdateConfig("chat",       "whisper",     "height",           "200")
  pfUI:UpdateConfig("chat",       "whisper",     "fontsize",         "12")
  pfUI:UpdateConfig("chat",       "whisper",     "history",          "50")
  pfUI:UpdateConfig("chat",       "whisper",     "x",                "")
  pfUI:UpdateConfig("chat",       "whisper",     "y",                "")
  pfUI:UpdateConfig("chat",       "bubbles",     "alpha",            ".75")

  pfUI:UpdateConfig("nameplates", nil,           "showhostile",      "1")
  pfUI:UpdateConfig("nameplates", nil,           "showfriendly",     "0")
  pfUI:UpdateConfig("nameplates", nil,           "use_unitfonts",    "0")
  pfUI:UpdateConfig("nameplates", nil,           "legacy",           "0")
  pfUI:UpdateConfig("nameplates", nil,           "overlap",          "0")
  pfUI:UpdateConfig("nameplates", nil,           "verticalhealth",   "0")
  pfUI:UpdateConfig("nameplates", nil,           "vertical_offset",  "0")
  pfUI:UpdateConfig("nameplates", nil,           "showcastbar",      "1")
  pfUI:UpdateConfig("nameplates", nil,           "targetcastbar",    "0")
  pfUI:UpdateConfig("nameplates", nil,           "spellname",        "0")
  pfUI:UpdateConfig("nameplates", nil,           "showdebuffs",      "1")
  pfUI:UpdateConfig("nameplates", nil,           "selfdebuff",       "0")
  pfUI:UpdateConfig("nameplates", nil,           "guessdebuffs",     "1")
  pfUI:UpdateConfig("nameplates", nil,           "clickthrough",     "0")
  pfUI:UpdateConfig("nameplates", nil,           "rightclick",       "1")
  pfUI:UpdateConfig("nameplates", nil,           "clickthreshold",   "0.5")
  pfUI:UpdateConfig("nameplates", nil,           "enemyclassc",      "1")
  pfUI:UpdateConfig("nameplates", nil,           "friendclassc",     "1")
  pfUI:UpdateConfig("nameplates", nil,           "friendclassnamec", "0")
  pfUI:UpdateConfig("nameplates", nil,           "raidiconsize",     "16")
  pfUI:UpdateConfig("nameplates", nil,           "raidiconpos",      "CENTER")
  pfUI:UpdateConfig("nameplates", nil,           "raidiconoffx",     "0")
  pfUI:UpdateConfig("nameplates", nil,           "raidiconoffy",     "-5")
  pfUI:UpdateConfig("nameplates", nil,           "fullhealth",       "1")
  pfUI:UpdateConfig("nameplates", nil,           "target",           "1")
  pfUI:UpdateConfig("nameplates", nil,           "namefightcolor",   "1")
  pfUI:UpdateConfig("nameplates", nil,           "enemynpc",         "0")
  pfUI:UpdateConfig("nameplates", nil,           "enemyplayer",      "0")
  pfUI:UpdateConfig("nameplates", nil,           "neutralnpc",       "0")
  pfUI:UpdateConfig("nameplates", nil,           "friendlynpc",      "0")
  pfUI:UpdateConfig("nameplates", nil,           "friendlyplayer",   "0")
  pfUI:UpdateConfig("nameplates", nil,           "critters",         "1")
  pfUI:UpdateConfig("nameplates", nil,           "totems",           "1")
  pfUI:UpdateConfig("nameplates", nil,           "totemicons",       "0")
  pfUI:UpdateConfig("nameplates", nil,           "showguildname",    "0")

  pfUI:UpdateConfig("nameplates", nil,           "outcombatstate",   "1")
  pfUI:UpdateConfig("nameplates", nil,           "barcombatstate",   "1")

  pfUI:UpdateConfig("nameplates", nil,           "ccombatthreat",    "1")
  pfUI:UpdateConfig("nameplates", nil,           "ccombatofftank",   "1")
  pfUI:UpdateConfig("nameplates", nil,           "ccombatnothreat",  "1")
  pfUI:UpdateConfig("nameplates", nil,           "ccombatstun",      "1")
  pfUI:UpdateConfig("nameplates", nil,           "ccombatcasting",   "0")
  pfUI:UpdateConfig("nameplates", nil,           "combatthreat",     ".7,.2,.2,1")
  pfUI:UpdateConfig("nameplates", nil,           "combatofftank",    ".7,.4,.2,1")
  pfUI:UpdateConfig("nameplates", nil,           "combatnothreat",   ".7,.7,.2,1")
  pfUI:UpdateConfig("nameplates", nil,           "combatstun",       ".2,.7,.7,1")
  pfUI:UpdateConfig("nameplates", nil,           "combatcasting",    ".7,.2,.7,1")
  pfUI:UpdateConfig("nameplates", nil,           "combatofftanks",   "")

  pfUI:UpdateConfig("nameplates", nil,           "outfriendly",      "0")
  pfUI:UpdateConfig("nameplates", nil,           "outfriendlynpc",   "1")
  pfUI:UpdateConfig("nameplates", nil,           "outneutral",       "1")
  pfUI:UpdateConfig("nameplates", nil,           "outenemy",         "1")
  pfUI:UpdateConfig("nameplates", nil,           "targethighlight",  "0")
  pfUI:UpdateConfig("nameplates", nil,           "highlightcolor",   "1,1,1,1")

  pfUI:UpdateConfig("nameplates", nil,           "showhp",           "0")
  pfUI:UpdateConfig("nameplates", nil,           "hptextpos",        "RIGHT")
  pfUI:UpdateConfig("nameplates", nil,           "hptextformat",     "curmaxs")
  pfUI:UpdateConfig("nameplates", nil,           "vpos",             "-10")
  pfUI:UpdateConfig("nameplates", nil,           "width",            "120")
  pfUI:UpdateConfig("nameplates", nil,           "debuffsize",       "14")
  pfUI:UpdateConfig("nameplates", nil,           "debuffoffset",     "4")
  pfUI:UpdateConfig("nameplates", nil,           "heighthealth",     "8")
  pfUI:UpdateConfig("nameplates", nil,           "heightcast",       "8")
  pfUI:UpdateConfig("nameplates", nil,           "cpdisplay",        "0")
  pfUI:UpdateConfig("nameplates", nil,           "targetglow",       "1")
  pfUI:UpdateConfig("nameplates", nil,           "glowcolor",        "1,1,1,1")
  pfUI:UpdateConfig("nameplates", nil,           "targetzoom",       "0")
  pfUI:UpdateConfig("nameplates", nil,           "targetzoomval",    ".40")
  pfUI:UpdateConfig("nameplates", nil,           "notargalpha",      ".75")
  pfUI:UpdateConfig("nameplates", nil,           "healthtexture",    "Interface\\AddOns\\pfUI\\img\\bar")
  pfUI:UpdateConfig("nameplates", "name",        "fontstyle",        "OUTLINE")
  pfUI:UpdateConfig("nameplates", "health",      "offset",           "-3")
  pfUI:UpdateConfig("nameplates", "debuffs",     "filter",           "none")
  pfUI:UpdateConfig("nameplates", "debuffs",     "whitelist",        "")
  pfUI:UpdateConfig("nameplates", "debuffs",     "blacklist",        "")
  pfUI:UpdateConfig("nameplates", "debuffs",     "showstacks",       "0")
  pfUI:UpdateConfig("nameplates", "debuffs",     "position",         "BOTTOM")

  -- octo: Plater's ideas on the nameplates (modules/plates.lua)
  pfUI:UpdateConfig("global",     nil,           "screenshotmsg",    "0")
  pfUI:UpdateConfig("plates",     nil,           "enable",           "1")
  pfUI:UpdateConfig("plates",     nil,           "firstlook",        "0")
  pfUI:UpdateConfig("plates",     nil,           "bartexture",       "Interface\\AddOns\\pfUI\\img\\plates\\bar-soft")
  pfUI:UpdateConfig("plates",     nil,           "bgcolor",          ".06,.06,.06,.85")
  pfUI:UpdateConfig("plates",     nil,           "skin",             "pfui")
  pfUI:UpdateConfig("plates",     nil,           "font",             "")
  pfUI:UpdateConfig("plates",     nil,           "namesize",         "0")
  pfUI:UpdateConfig("plates",     nil,           "hpsize",           "0")
  pfUI:UpdateConfig("plates",     nil,           "size_enemynpc",    "100")
  pfUI:UpdateConfig("plates",     nil,           "size_enemyplayer", "100")
  pfUI:UpdateConfig("plates",     nil,           "size_friendlynpc", "80")
  pfUI:UpdateConfig("plates",     nil,           "size_friendlyplayer", "80")
  pfUI:UpdateConfig("plates",     nil,           "size_ooc",         "90")
  pfUI:UpdateConfig("plates",     nil,           "size_target",      "110")
  pfUI:UpdateConfig("plates",     nil,           "sizematch",        "0")
  pfUI:UpdateConfig("plates",     nil,           "threat",           "1")
  pfUI:UpdateConfig("plates",     nil,           "role",             "auto")
  pfUI:UpdateConfig("plates",     nil,           "pullat",           "90")
  pfUI:UpdateConfig("plates",     nil,           "aggroglow",        "1")
  pfUI:UpdateConfig("plates",     nil,           "safenormal",       "0")
  pfUI:UpdateConfig("plates",     nil,           "c_aggro",          ".93,.2,.2,1")
  pfUI:UpdateConfig("plates",     nil,           "c_pulling",        "1,.6,.1,1")
  pfUI:UpdateConfig("plates",     nil,           "c_safe",           ".55,.45,1,1")
  pfUI:UpdateConfig("plates",     nil,           "c_tankaggro",      ".25,.7,1,1")
  pfUI:UpdateConfig("plates",     nil,           "c_losing",         "1,.6,.1,1")
  pfUI:UpdateConfig("plates",     nil,           "c_offtank",        ".65,.4,1,1")
  pfUI:UpdateConfig("plates",     nil,           "c_lost",           ".93,.2,.2,1")
  pfUI:UpdateConfig("plates",     nil,           "indicator",        "arrows")
  pfUI:UpdateConfig("plates",     nil,           "targetaccent",     "1")
  pfUI:UpdateConfig("plates",     nil,           "targetcolor",      "1,1,1,1")
  pfUI:UpdateConfig("plates",     nil,           "mouseover",        "1")
  pfUI:UpdateConfig("plates",     nil,           "execute",          "auto")
  pfUI:UpdateConfig("plates",     nil,           "executepct",       "20")
  pfUI:UpdateConfig("plates",     nil,           "executecolor",     "1,.82,.2,1")
  pfUI:UpdateConfig("plates",     nil,           "executemark",      "1")
  pfUI:UpdateConfig("plates",     nil,           "castlayout",       "plater")
  pfUI:UpdateConfig("plates",     nil,           "castheight",       "12")
  pfUI:UpdateConfig("plates",     nil,           "c_cast",           "1,.72,.15,1")
  pfUI:UpdateConfig("plates",     nil,           "c_channel",        ".35,.8,.5,1")
  pfUI:UpdateConfig("plates",     nil,           "c_done",           ".3,1,.45,1")
  pfUI:UpdateConfig("plates",     nil,           "c_stopped",        ".93,.2,.2,1")
  pfUI:UpdateConfig("plates",     nil,           "spark",            "1")
  pfUI:UpdateConfig("plates",     nil,           "castend",          "1")
  pfUI:UpdateConfig("plates",     nil,           "kicker",           "1")
  pfUI:UpdateConfig("plates",     nil,           "range",            "1")
  pfUI:UpdateConfig("plates",     nil,           "rangeyards",       "40")
  pfUI:UpdateConfig("plates",     nil,           "rangealpha",       ".4")
  pfUI:UpdateConfig("plates",     nil,           "los",              "0")
  pfUI:UpdateConfig("plates",     nil,           "eliteicon",        "1")
  pfUI:UpdateConfig("plates",     nil,           "auras",            "1")
  pfUI:UpdateConfig("plates",     nil,           "debuffshow",       "mine_cc")
  pfUI:UpdateConfig("plates",     nil,           "buffshow",         "all")
  -- octo (29 Oct 2026; user: "SHOW ENEMY BUFFS ... all ENEMY NPC AND PLAYERS buffs"): on once for
  -- everyone - every enemy buff on nameplates and the hidden ones found for the target frame
  if pfUI_config.unitframes and pfUI_config.plates and pfUI_config.unitframes.octoenemybuffs ~= "1" then
    pfUI_config.unitframes.buffdetect = "1"
    pfUI_config.plates.buffshow = "all"
    pfUI_config.unitframes.octoenemybuffs = "1"
  end
  pfUI:UpdateConfig("plates",     nil,           "aurawidth",        "20")
  pfUI:UpdateConfig("plates",     nil,           "auraheight",       "16")
  pfUI:UpdateConfig("plates",     nil,           "auraperrow",       "6")
  pfUI:UpdateConfig("plates",     nil,           "aurarows",         "2")
  pfUI:UpdateConfig("plates",     nil,           "auragrow",         "center")
  pfUI:UpdateConfig("plates",     nil,           "auraoffset",       "2")
  pfUI:UpdateConfig("plates",     nil,           "auratimer",        "1")
  pfUI:UpdateConfig("plates",     nil,           "aurastacks",       "1")
  pfUI:UpdateConfig("plates",     nil,           "auraborder",       "1")
  pfUI:UpdateConfig("plates",     nil,           "specialon",        "1")
  pfUI:UpdateConfig("plates",     nil,           "specialsize",      "32")
  pfUI:UpdateConfig("plates",     nil,           "auraver",          "0")
  pfUI:UpdateConfig("plates",     nil,           "castbg",           ".22,.22,.22,.9")
  pfUI:UpdateConfig("plates",     nil,           "markelite",        "star")
  pfUI:UpdateConfig("plates",     nil,           "markrare",         "sparkle")
  pfUI:UpdateConfig("plates",     nil,           "markrareelite",    "crown")
  pfUI:UpdateConfig("plates",     nil,           "markboss",         "skull")
  pfUI:UpdateConfig("plates",     nil,           "elitecolor",       "1,.8,.25,1")
  pfUI:UpdateConfig("plates",     nil,           "rarecolor",        ".85,.9,1,1")
  pfUI:UpdateConfig("plates",     nil,           "bosscolor",        "1,.9,.9,1")
  pfUI:UpdateConfig("plates",     nil,           "markoffx",         "0")
  pfUI:UpdateConfig("plates",     nil,           "markoffy",         "0")
  pfUI:UpdateConfig("plates",     nil,           "questobjstyle",    "diamond")
  pfUI:UpdateConfig("plates",     nil,           "queststartstyle",  "bang")
  pfUI:UpdateConfig("plates",     nil,           "questendstyle",    "ask")
  pfUI:UpdateConfig("plates",     nil,           "questgivercolor",  "1,.82,0,1")
  pfUI:UpdateConfig("plates",     nil,           "questsize",        "0")
  pfUI:UpdateConfig("plates",     nil,           "questoffx",        "0")
  pfUI:UpdateConfig("plates",     nil,           "questoffy",        "0")
  pfUI:UpdateConfig("plates",     nil,           "ciconsize",        "0")
  pfUI:UpdateConfig("plates",     nil,           "ciconoffx",        "0")
  pfUI:UpdateConfig("plates",     nil,           "ciconoffy",        "0")
  pfUI:UpdateConfig("plates",     nil,           "nameoffx",         "0")
  pfUI:UpdateConfig("plates",     nil,           "nameoffy",         "0")
  pfUI:UpdateConfig("plates",     nil,           "leveloffx",        "0")
  pfUI:UpdateConfig("plates",     nil,           "leveloffy",        "0")
  pfUI:UpdateConfig("plates",     nil,           "hpoffx",           "0")
  pfUI:UpdateConfig("plates",     nil,           "hpoffy",           "0")
  pfUI:UpdateConfig("plates",     nil,           "targetsize",       "0")
  pfUI:UpdateConfig("plates",     nil,           "targetgap",        "0")
  pfUI:UpdateConfig("plates",     nil,           "previewgrid",      "1")
  pfUI:UpdateConfig("plates",     nil,           "nameshow",         "1")
  pfUI:UpdateConfig("plates",     nil,           "levelshow",        "1")
  pfUI:UpdateConfig("plates",     nil,           "marksize",         "0")
  pfUI:UpdateConfig("plates",     nil,           "casticon",         "1")
  pfUI:UpdateConfig("plates",     nil,           "casticonsize",     "0")
  pfUI:UpdateConfig("plates",     nil,           "casttimer",        "1")
  pfUI:UpdateConfig("plates",     nil,           "castname",         "1")
  pfUI:UpdateConfig("plates",     nil,           "casttextsize",     "0")
  pfUI:UpdateConfig("plates",     nil,           "castoffx",         "0")
  pfUI:UpdateConfig("plates",     nil,           "castoffy",         "0")
  pfUI:UpdateConfig("plates",     nil,           "auraoffx",         "0")
  pfUI:UpdateConfig("plates",     nil,           "specialoffx",      "0")
  pfUI:UpdateConfig("plates",     nil,           "specialoffy",      "0")
  pfUI:UpdateConfig("plates",     nil,           "cpoffx",           "0")
  pfUI:UpdateConfig("plates",     nil,           "cpoffy",           "0")
  pfUI:UpdateConfig("plates",     nil,           "auragap",          "2")
  pfUI:UpdateConfig("plates",     nil,           "auragaprow",       "2")
  pfUI:UpdateConfig("plates",     nil,           "specialgap",       "3")
  pfUI:UpdateConfig("plates",     nil,           "auratimersize",    "0")
  pfUI:UpdateConfig("plates",     nil,           "aurastacksize",    "0")
  pfUI:UpdateConfig("plates",     nil,           "cpstyle",          "orbs")
  pfUI:UpdateConfig("plates",     nil,           "cpsize",           "12")
  pfUI:UpdateConfig("plates",     nil,           "cpgap",            "3")
  pfUI:UpdateConfig("plates",     nil,           "cpplace",          "below")
  pfUI:UpdateConfig("plates",     nil,           "cpcolor",          "gradient")
  pfUI:UpdateConfig("plates",     nil,           "cpcustom",         "1,.8,.2,1")
  pfUI:UpdateConfig("plates",     nil,           "cpempty",          "1")
  pfUI:UpdateConfig("plates",     nil,           "cpglow",           "1")
  pfUI:UpdateConfig("plates",     nil,           "namecustom",       "0")
  pfUI:UpdateConfig("plates",     nil,           "namecolor",        "1,1,1,1")
  pfUI:UpdateConfig("plates",     nil,           "levelcustom",      "0")
  pfUI:UpdateConfig("plates",     nil,           "levelcolor",       "1,.82,.3,1")
  pfUI:UpdateConfig("plates",     nil,           "hptextcolor",      "1,1,1,1")
  pfUI:UpdateConfig("plates",     nil,           "casttextcolor",    "1,1,1,1")
  pfUI:UpdateConfig("plates",     nil,           "bordercustom",     "0")
  pfUI:UpdateConfig("plates",     nil,           "bordercolor",      "0,0,0,1")
  pfUI:UpdateConfig("plates",     nil,           "skincustom",       "0")
  pfUI:UpdateConfig("plates",     nil,           "skincolor",        "1,1,1,1")
  pfUI:UpdateConfig("plates",     nil,           "specialauras",     "Polymorph#Blind#Sap#Fear#Hammer of Justice#Kidney Shot#Psychic Scream#Intimidating Shout#Ice Block#Divine Shield#Blessing of Protection#Evasion")
  pfUI:UpdateConfig("plates",     nil,           "ghoston",          "0")
  pfUI:UpdateConfig("plates",     nil,           "ghostauras",       "")
  pfUI:UpdateConfig("plates",     nil,           "ghostalpha",       ".5")
  pfUI:UpdateConfig("plates",     nil,           "c_taking",         "1,.7,0,1")
  pfUI:UpdateConfig("plates",     nil,           "npclist",          "")
  pfUI:UpdateConfig("plates",     nil,           "castlist",         "")
  pfUI:UpdateConfig("plates",     nil,           "npcoverthreat",    "0")
  pfUI:UpdateConfig("plates",     nil,           "questmark",        "1")
  pfUI:UpdateConfig("plates",     nil,           "questbar",         "0")
  pfUI:UpdateConfig("plates",     nil,           "questcolor",       "1,.82,0,1")
  pfUI:UpdateConfig("plates",     nil,           "classicon_enemy",  "1")
  pfUI:UpdateConfig("plates",     nil,           "classicon_friend", "0")
  pfUI:UpdateConfig("plates",     nil,           "peticon",          "1")
  pfUI:UpdateConfig("plates",     nil,           "autofriend_city",  "keep")
  pfUI:UpdateConfig("plates",     nil,           "autofriend_instance", "keep")
  pfUI:UpdateConfig("plates",     nil,           "autofriend_world", "keep")
  pfUI:UpdateConfig("plates",     nil,           "autoenemy_combat", "keep")
  pfUI:UpdateConfig("plates",     nil,           "autoenemy_ooc",    "keep")

  pfUI:UpdateConfig("abuttons",   nil,           "enable",           "1")
  pfUI:UpdateConfig("abuttons",   nil,           "position",         "bottom")
  pfUI:UpdateConfig("abuttons",   nil,           "showdefault",      "0")
  pfUI:UpdateConfig("abuttons",   nil,           "rowsize",          "6")
  pfUI:UpdateConfig("abuttons",   nil,           "spacing",          "2")
  pfUI:UpdateConfig("abuttons",   nil,           "hideincombat",     "1")
  pfUI:UpdateConfig("abuttons",   nil,           "size",             "0")

  pfUI:UpdateConfig("screenshot", nil,           "interval",         "0")
  pfUI:UpdateConfig("screenshot", nil,           "levelup",          "0")
  pfUI:UpdateConfig("screenshot", nil,           "pvprank",          "0")
  pfUI:UpdateConfig("screenshot", nil,           "faction",          "0")
  pfUI:UpdateConfig("screenshot", nil,           "battleground",     "0")
  pfUI:UpdateConfig("screenshot", nil,           "hk",               "0")
  pfUI:UpdateConfig("screenshot", nil,           "loot",             "0")
  pfUI:UpdateConfig("screenshot", nil,           "hideui",           "0")
  pfUI:UpdateConfig("screenshot", nil,           "caption",          "0")
  pfUI:UpdateConfig("screenshot", nil,           "caption_font",     "Interface\\AddOns\\pfUI\\fonts\\BigNoodleTitling.ttf")
  pfUI:UpdateConfig("screenshot", nil,           "caption_size",     "22")

  pfUI:UpdateConfig("gm",         nil,           "disable",          "1")
  pfUI:UpdateConfig("gm",         nil,           "server",           "elysium")

  pfUI:UpdateConfig("questlog",   nil,           "showQuestLevels",  "0")
  pfUI:UpdateConfig("thirdparty", nil,           "chatbg",           "1")
  pfUI:UpdateConfig("thirdparty", nil,           "showmeter",        "0")
  pfUI:UpdateConfig("thirdparty", "pfmeter",     "dock",             "1")
  pfUI:UpdateConfig("thirdparty", "pfthreat",    "dock",             "1")
  pfUI:UpdateConfig("thirdparty", "dpsmate",     "skin",             "0")
  pfUI:UpdateConfig("thirdparty", "dpsmate",     "dock",             "0")
  pfUI:UpdateConfig("thirdparty", "shagudps",    "skin",             "0")
  pfUI:UpdateConfig("thirdparty", "shagudps",    "dock",             "0")
  pfUI:UpdateConfig("thirdparty", "swstats",     "skin",             "0")
  pfUI:UpdateConfig("thirdparty", "swstats",     "dock",             "0")
  pfUI:UpdateConfig("thirdparty", "ktm",         "skin",             "0")
  pfUI:UpdateConfig("thirdparty", "ktm",         "dock",             "0")
  pfUI:UpdateConfig("thirdparty", "twt",         "skin",             "0")
  pfUI:UpdateConfig("thirdparty", "twt",         "dock",             "0")
  pfUI:UpdateConfig("thirdparty", "wim",         "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "healcomm",    "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "sortbags",    "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "bag_sort",    "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "mrplow",      "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "bcs",         "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "crafty",      "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "clevermacro", "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "flightmap",   "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "sheepwatch",  "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "totemtimers", "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "theorycraft", "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "supermacro",  "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "atlasloot",   "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "myroleplay",  "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "druidmana",   "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "druidbar",    "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "ackis",       "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "bcepgp",      "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "noteit",      "enable",           "1")
  pfUI:UpdateConfig("thirdparty", "recount",     "skin",             "0")
  pfUI:UpdateConfig("thirdparty", "recount",     "dock",             "0")
  pfUI:UpdateConfig("thirdparty", "omen",        "skin",             "0")
  pfUI:UpdateConfig("thirdparty", "omen",        "dock",             "0")

  pfUI:UpdateConfig("position",   nil,           nil,                nil)
  pfUI:UpdateConfig("disabled",   nil,           nil,                nil)
end

function pfUI:MigrateConfig()
  -- migrating to new fonts (1.5 -> 1.6)
  if checkversion(1, 6, 0) then
    -- migrate font_default
    if pfUI_config.global.font_default == "arial" then
      pfUI_config.global.font_default = "Myriad-Pro"
    elseif pfUI_config.global.font_default == "homespun" then
      pfUI_config.global.font_default = "Homespun"
    elseif pfUI_config.global.font_default == "diediedie" then
      pfUI_config.global.font_default = "DieDieDie"
    end

    -- migrate font_square
    if pfUI_config.global.font_square == "arial" then
      pfUI_config.global.font_square = "Myriad-Pro"
    elseif pfUI_config.global.font_square == "homespun" then
      pfUI_config.global.font_square = "Homespun"
    elseif pfUI_config.global.font_square == "diediedie" then
      pfUI_config.global.font_square = "DieDieDie"
    end

    -- migrate font_combat
    if pfUI_config.global.font_combat == "arial" then
      pfUI_config.global.font_combat = "Myriad-Pro"
    elseif pfUI_config.global.font_combat == "homespun" then
      pfUI_config.global.font_combat = "Homespun"
    elseif pfUI_config.global.font_combat == "diediedie" then
      pfUI_config.global.font_combat = "DieDieDie"
    end
  end

  -- migrating to new loot config section (> 2.0.5)
  if checkversion(2, 0, 5) then
    if pfUI_config.appearance.loot and pfUI_config.appearance.loot.autoresize then
      pfUI_config.loot.autoresize = pfUI_config.appearance.loot.autoresize
      pfUI_config.appearance.loot.autoresize = nil
      pfUI_config.appearance.loot = nil
    end
  end

  -- migrating to new unitframes (> 2.5)
  if checkversion(2, 5, 0) then
    -- migrate clickcast settings
    if pfUI_config.unitframes.raid.clickcast_ctrl then
      pfUI_config.unitframes.clickcast = pfUI_config.unitframes.raid.clickcast
      pfUI_config.unitframes.clickcast_shift = pfUI_config.unitframes.raid.clickcast_shift
      pfUI_config.unitframes.clickcast_alt = pfUI_config.unitframes.raid.clickcast_alt
      pfUI_config.unitframes.clickcast_ctrl = pfUI_config.unitframes.raid.clickcast_ctrl

      pfUI_config.unitframes.raid.clickcast = "0"
      pfUI_config.unitframes.raid.clickcast_shift = nil
      pfUI_config.unitframes.raid.clickcast_alt = nil
      pfUI_config.unitframes.raid.clickcast_ctrl = nil
    end

    -- migrate buffsizes
    if pfUI_config.unitframes.buff_size then
      pfUI_config.unitframes.player.buffsize = pfUI_config.unitframes.buff_size
      pfUI_config.unitframes.target.buffsize = pfUI_config.unitframes.buff_size
      pfUI_config.unitframes.buff_size = nil
    end

    -- migrate debuffsizes
    if pfUI_config.unitframes.debuff_size then
      pfUI_config.unitframes.player.debuffsize = pfUI_config.unitframes.debuff_size
      pfUI_config.unitframes.target.debuffsize = pfUI_config.unitframes.debuff_size
      pfUI_config.unitframes.debuff_size = nil
    end
  end

  -- migrating to new fontnames (> 2.6)
  if checkversion(2, 6, 0) then
    -- migrate font_combat
    if pfUI_config.global.font_square then
      pfUI_config.global.font_unit = pfUI_config.global.font_square
      pfUI_config.global.font_square = nil
    end
  end


  -- migrating old to new font layout (> 3.0.0)
  if checkversion(3, 0, 0) then
    -- migrate font_default
    if not strfind(pfUI_config.global.font_default, "\\") then
      pfUI_config.global.font_default = "Interface\\AddOns\\pfUI\\fonts\\" .. pfUI_config.global.font_default .. ".ttf"
    end

    -- migrate font_unit
    if not strfind(pfUI_config.global.font_unit, "\\") then
      pfUI_config.global.font_unit = "Interface\\AddOns\\pfUI\\fonts\\" .. pfUI_config.global.font_unit .. ".ttf"
    end

    -- migrate font_combat
    if not strfind(pfUI_config.global.font_combat, "\\") then
      pfUI_config.global.font_combat = "Interface\\AddOns\\pfUI\\fonts\\" .. pfUI_config.global.font_combat .. ".ttf"
    end
  end

  -- migrating old to new unitframe texts (> 3.0.0)
  if checkversion(3, 0, 0) then
    local unitframes = { "player", "target", "focus", "group", "grouptarget", "grouppet", "raid", "ttarget", "pet", "ptarget", "fallback" }

    for _, unitframe in pairs(unitframes) do
      if pfUI_config.unitframes[unitframe].txtleft then
        pfUI_config.unitframes[unitframe].txthpleft = pfUI_config.unitframes[unitframe].txtleft
        pfUI_config.unitframes[unitframe].txtleft = nil
      end
      if pfUI_config.unitframes[unitframe].txtcenter then
        pfUI_config.unitframes[unitframe].txthpcenter = pfUI_config.unitframes[unitframe].txtcenter
        pfUI_config.unitframes[unitframe].txtcenter = nil
      end
      if pfUI_config.unitframes[unitframe].txtright then
        pfUI_config.unitframes[unitframe].txthpright = pfUI_config.unitframes[unitframe].txtright
        pfUI_config.unitframes[unitframe].txtright = nil
      end
    end
  end

  -- migrating animation_speed (> 3.1.2)
  if checkversion(3, 1, 2) then
    if tonumber(pfUI_config.unitframes.animation_speed) >= 13 then
      pfUI_config.unitframes.animation_speed = "13"
    elseif tonumber(pfUI_config.unitframes.animation_speed) >= 8 then
      pfUI_config.unitframes.animation_speed = "8"
    elseif tonumber(pfUI_config.unitframes.animation_speed) >= 5 then
      pfUI_config.unitframes.animation_speed = "5"
    elseif tonumber(pfUI_config.unitframes.animation_speed) >= 3 then
      pfUI_config.unitframes.animation_speed = "3"
    elseif tonumber(pfUI_config.unitframes.animation_speed) >= 2 then
      pfUI_config.unitframes.animation_speed = "2"
    elseif tonumber(pfUI_config.unitframes.animation_speed) >= 1 then
      pfUI_config.unitframes.animation_speed = "1"
    else
      pfUI_config.unitframes.animation_speed = "5"
    end
  end

  -- migrating rangecheck interval (> 3.2.2)
  if checkversion(3, 2, 2) then
    if tonumber(pfUI_config.unitframes.rangechecki) <= 1 then
      pfUI_config.unitframes.rangechecki = "2"
    end
  end

  -- migrating legacy buff/debuff naming (> 3.5.0)
  if checkversion(3, 5, 0) then
    local unitframes = { "player", "target", "focus", "group", "grouptarget", "grouppet", "raid", "ttarget", "pet", "ptarget", "fallback" }

    for _, unitframe in pairs(unitframes) do
      local entry = pfUI_config.unitframes[unitframe]
      if entry.buffs and entry.buffs == "hide" then entry.buffs = "off" end
      if entry.debuffs and entry.debuffs == "hide" then entry.debuffs = "off" end
    end
  end

  -- migrating glow settings (> 3.5.1)
  if checkversion(3, 5, 0) then
    local common = { "player", "target", "ttarget", "pet", "ptarget", "tttarget"}
    for _, unitframe in pairs(common) do
      if pfUI_config.appearance.infight.group == "1" then
        pfUI_config.unitframes[unitframe].glowcombat = "1"
        pfUI_config.unitframes[unitframe].glowaggro = "1"
      elseif pfUI_config.appearance.infight.group == "0" then
        pfUI_config.unitframes[unitframe].glowcombat = "0"
        pfUI_config.unitframes[unitframe].glowaggro = "0"
      end
    end

    if pfUI_config.appearance.infight.group == "1" then
      pfUI_config.unitframes["group"].glowcombat = "1"
      pfUI_config.unitframes["group"].glowaggro = "1"
    elseif pfUI_config.appearance.infight.group == "0" then
      pfUI_config.unitframes["group"].glowcombat = "0"
      pfUI_config.unitframes["group"].glowaggro = "0"
    end
  end

  -- migrating old buff settings (> 3.6.1)
  if checkversion(3, 6, 1) then
    pfUI_config.buffs.weapons =  pfUI_config.global.hidewbuff == "1" and "0" or "1"
    pfUI_config.buffs.buffs   =  pfUI_config.global.hidebuff  == "1" and "0" or "1"
    pfUI_config.buffs.debuffs =  pfUI_config.global.hidebuff  == "1" and "0" or "1"
  end

  -- migrating default debuffbar color settings (> 3.16)
  if checkversion(3, 16, 0) then

    if pfUI_config.buffbar.pdebuff.color == ".1,.1,.1,1" then
      pfUI_config.buffbar.pdebuff.color = ".8,.4,.4,1"
    end

    if pfUI_config.buffbar.tdebuff.color == ".1,.1,.1,1" then
      pfUI_config.buffbar.tdebuff.color   =  ".8,.4,.4,1"
    end
  end

  -- migrate buff/debuff position settings (> 3.19)
  if checkversion(3, 19, 0) then
    local unitframes = { "player", "target", "focus", "group", "grouptarget", "grouppet", "raid", "ttarget", "pet", "ptarget", "fallback" }

    for _, unitframe in pairs(unitframes) do
      local entry = pfUI_config.unitframes[unitframe]
      if entry.buffs and entry.buffs == "top" then entry.buffs = "TOPLEFT" end
      if entry.buffs and entry.buffs == "bottom" then entry.buffs = "BOTTOMLEFT" end
      if entry.debuffs and entry.debuffs == "top" then entry.debuffs = "TOPLEFT" end
      if entry.debuffs and entry.debuffs == "bottom" then entry.debuffs = "BOTTOMLEFT" end
    end
  end

  -- migrating actionbar settings (> 3.19)
  if checkversion(3, 19, 0) then

    local migratebars = {
      ["pfBarActionMain"] = "pfActionBarMain",
      ["pfBarBottomLeft"] = "pfActionBarTop",
      ["pfBarBottomRight"] = "pfActionBarLeft",
      ["pfBarTwoRight"] = "pfActionBarVertical",
      ["pfBarRight"] = "pfActionBarRight",
      ["pfBarShapeshift"] = "pfActionBarStances",
      ["pfBarPet"] = "pfActionBarPet",
    }

    -- migrate bar positions and scaling
    for oldname, newname in pairs(migratebars) do
      if pfUI_config.position[oldname] then
        pfUI_config.position[newname] = pfUI.api.CopyTable(pfUI_config.position[oldname])
        pfUI_config.position[oldname] = nil
      end
    end

    -- migrate global settings to bar specifics
    for i=1,12 do
      if pfUI_config.bars.icon_size then
        pfUI_config.bars["bar"..i].icon_size = pfUI_config.bars.icon_size
      end

      if pfUI_config.bars.background then
        pfUI_config.bars["bar"..i].background = pfUI_config.bars.background
      end

      if pfUI_config.bars.showmacro then
        pfUI_config.bars["bar"..i].showmacro = pfUI_config.bars.showmacro
      end

      if pfUI_config.bars.showkeybind then
        pfUI_config.bars["bar"..i].showkeybind = pfUI_config.bars.showkeybind
      end

      if pfUI_config.bars.hide_time then
        pfUI_config.bars["bar"..i].hide_time = pfUI_config.bars.hide_time
      end
    end

    pfUI_config.bars.icon_size = nil
    pfUI_config.bars.background = nil
    pfUI_config.bars.showmacro = nil
    pfUI_config.bars.showkeybind = nil
    pfUI_config.bars.hide_time = nil

    if pfUI_config.bars.hide_actionmain then
      pfUI_config.bars.bar1.autohide = pfUI_config.bars.hide_actionmain
      pfUI_config.bars.hide_actionmain = nil
    end

    if pfUI_config.bars.hide_bottomleft then
      pfUI_config.bars.bar6.autohide = pfUI_config.bars.hide_bottomleft
      pfUI_config.bars.hide_bottomleft = nil
    end

    if pfUI_config.bars.hide_bottomright then
      pfUI_config.bars.bar5.autohide = pfUI_config.bars.hide_bottomright
      pfUI_config.bars.hide_bottomright = nil
    end

    if pfUI_config.bars.hide_right then
      pfUI_config.bars.bar3.autohide = pfUI_config.bars.hide_right
      pfUI_config.bars.hide_right = nil
    end

    if pfUI_config.bars.hide_tworight then
      pfUI_config.bars.bar4.autohide = pfUI_config.bars.hide_tworight
      pfUI_config.bars.hide_tworight = nil
    end

    if pfUI_config.bars.hide_shapeshift then
      pfUI_config.bars.bar11.autohide = pfUI_config.bars.hide_shapeshift
      pfUI_config.bars.hide_shapeshift = nil
    end

    if pfUI_config.bars.hide_pet then
      pfUI_config.bars.bar12.autohide = pfUI_config.bars.hide_pet
      pfUI_config.bars.hide_pet = nil
    end

    if pfUI_config.bars.actionmain and pfUI_config.bars.actionmain.formfactor then
      pfUI_config.bars.bar1.formfactor = pfUI_config.bars.actionmain.formfactor
      pfUI_config.bars.actionmain.formfactor = nil
    end

    if pfUI_config.bars.bottomleft and pfUI_config.bars.bottomleft.formfactor then
      pfUI_config.bars.bar6.formfactor = pfUI_config.bars.bottomleft.formfactor
      pfUI_config.bars.bottomleft.formfactor = nil
    end

    if pfUI_config.bars.bottomright and pfUI_config.bars.bottomright.formfactor then
      pfUI_config.bars.bar5.formfactor = pfUI_config.bars.bottomright.formfactor
      pfUI_config.bars.bottomright.formfactor = nil
    end

    if pfUI_config.bars.right and pfUI_config.bars.right.formfactor then
      pfUI_config.bars.bar3.formfactor = pfUI_config.bars.right.formfactor
      pfUI_config.bars.right.formfactor = nil
    end

    if pfUI_config.bars.tworight and pfUI_config.bars.tworight.formfactor then
      pfUI_config.bars.bar4.formfactor = pfUI_config.bars.tworight.formfactor
      pfUI_config.bars.tworight.formfactor = nil
    end

    if pfUI_config.bars.shapeshift and pfUI_config.bars.shapeshift.formfactor then
      pfUI_config.bars.bar11.formfactor = pfUI_config.bars.shapeshift.formfactor
      pfUI_config.bars.shapeshift.formfactor = nil
    end

    if pfUI_config.bars.pet and pfUI_config.bars.pet.formfactor then
      pfUI_config.bars.bar12.formfactor = pfUI_config.bars.pet.formfactor
      pfUI_config.bars.pet.formfactor = nil
    end
  end

  -- migrate xp-showalways (> 4.0.2)
  if checkversion(4, 0, 2) and pfUI_config.panel.xp.showalways then
    pfUI_config.panel.xp.xp_always = pfUI_config.panel.xp.showalways
    pfUI_config.panel.xp.rep_always = pfUI_config.panel.xp.showalways
    pfUI_config.panel.xp.showalways = nil
  end

  -- migrate dispell indicators into seperate options (> 4.6.1)
  if checkversion(4, 6, 1) and pfUI_config.unitframes.debuffs_class then
    local unitframes = { "player", "target", "focus", "group", "grouptarget", "grouppet", "raid", "ttarget", "pet", "ptarget", "fallback", "tttarget" }
    for _, unitframe in pairs(unitframes) do
      pfUI_config.unitframes[unitframe].debuff_ind_class = pfUI_config.unitframes.debuffs_class
    end
    pfUI_config.unitframes.debuffs_class = nil
  end

  -- migrate buff indicators into seperate options (> 4.6.2)
  if checkversion(4, 6, 2) and pfUI_config.unitframes.show_hots then
    local unitframes = { "player", "target", "focus", "group", "grouptarget", "grouppet", "raid", "ttarget", "pet", "ptarget", "fallback", "tttarget" }
    local options = { "show_hots", "all_hots", "show_procs", "show_totems", "all_procs", "indicator_time", "indicator_stacks", "indicator_size" }

    for _, unitframe in pairs(unitframes) do
      for _, option in pairs(options) do
        pfUI_config.unitframes[unitframe][option] = pfUI_config.unitframes[option]
      end
    end

    for _, option in pairs(options) do
      pfUI_config.unitframes[option] = nil
    end
  end

  -- use same powerbar texture as for health (> 5.2.10)
  if checkversion(5, 2, 10) then
    local unitframes = { "player", "target", "focus", "group", "grouptarget", "grouppet", "raid", "ttarget", "pet", "ptarget", "fallback", "tttarget" }
    for _, unitframe in pairs(unitframes) do
      pfUI_config.unitframes[unitframe].pbartexture = pfUI_config.unitframes[unitframe].bartexture
    end
  end

  -- migrate minimap zone and coords changes
  if checkversion(5, 4, 11) then
    if pfUI_config.appearance.minimap.mouseoverzone and not pfUI_config.appearance.minimap.zonetext then
      pfUI_config.appearance.minimap.zonetext = (pfUI_config.appearance.minimap.mouseoverzone == "0") and "off" or "mouseover"
      pfUI_config.appearance.minimap.mouseoverzone = nil
    end
    if pfUI_config.appearance.minimap.coordsloc and not pfUI_config.appearance.minimap.coordstext then
      if pfUI_config.appearance.minimap.coordsloc == "off" then
        pfUI_config.appearance.minimap.coordsloc = "bottomleft"
        pfUI_config.appearance.minimap.coordstext = "off"
      else
        pfUI_config.appearance.minimap.coordstext = "mouseover"
      end
    end
  end

  -- migrate pagemaster to separate settings
  if checkversion(5, 4, 15) then
    if pfUI_config.bars.pagemaster == "1" then
      pfUI_config.bars.pagemaster = nil
      pfUI_config.bars.pagemasteralt = "1"
      pfUI_config.bars.pagemastershift = "1"
      pfUI_config.bars.pagemasterctrl = "1"
    end
  end

  -- migrate cooldown font from unit_font to separate setting
  if checkversion(5, 4, 18) then
    pfUI_config.appearance.cd.font = pfUI_config.global.font_unit
  end

  -- migrate combopoint size to separate settings
  if checkversion(5, 4, 18) then
    if pfUI_config.unitframes.combosize then
      pfUI_config.unitframes.combowidth = pfUI_config.unitframes.combosize
      pfUI_config.unitframes.comboheight = pfUI_config.unitframes.combosize
      pfUI_config.unitframes.combosize = nil
    end
  end


  pfUI_config.version = pfUI.version.string
end
