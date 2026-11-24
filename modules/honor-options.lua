pfUI:RegisterModule("honor-options", "vanilla", function ()
  -- pfUI Octo :: the Honor page's options (23 Nov 2026, modules/honor.lua), a tab under Quality of Life.
  -- Its own module, so the switch stays here while the honor module is off.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local function G() return C.honor end
  local function HN() return pfUI.honor end
  local function Repaint()
    local hn = HN()
    if hn and hn.Look then hn.Look() end
    if hn and hn.Paint then hn.Paint() end
  end
  local function Chk(p, label, desc, key) return O.PfChk(p, label, desc, G, key, Repaint) end
  local function Sld(p, label, desc, min, max, step, key, fmt) return O.PfSld(p, label, desc, min, max, step, G, key, Repaint, fmt) end

  local function Build(p)
    W.Heading(p, "Honor", { on = O.ModuleSwitch("honor", "Honor"),
      about = "Your Honor tab (character window > PvP) in battle colours: rank and badge, your honor points, a big rank "
        .. "progress bar with today's gain lit, the honor still needed for the next rank (learnt from your own kills), the "
        .. "week's honor against the cap with the reset countdown, the game's numbers and your last days. Every honor gain, "
        .. "battleground win and loss and step of rank % is kept per character. HonorSpy's history is copied in once when it "
        .. "is loaded. /honor opens it." })

    W.Card(p, "The page", { tip = "How the Honor tab looks. The Arena tab and the server's own honor points are left as they are." })
    Chk(p, "Our Honor page", "Off: the game's own Honor tab (needs a reload).", "page")
    Chk(p, "Battle art", "The battleground scene behind it, worn and burnt at the edges. Off: plain and dark.", "art")
    Sld(p, "Scene darkness", "How dark the battle scene behind the numbers is.", .3, .95, .01, "artdark",
      function(v) return math.floor(v * 100 + .5) .. "%" end)
    W.Dropdown(p, "Bar colour", "The rank bar's colour. Faction: Horde red, Alliance blue.", {
        { key = "faction", label = "Faction" }, { key = "class", label = "Class colour" },
        { key = "accent", label = "Accent colour" }, { key = "custom", label = "Your own colour" },
      }, function() return G().barcolor or "faction" end, function(v) G().barcolor = v Repaint() end)
    W.Color(p, "Your own colour", "Used when the bar colour is \"Your own colour\".", function()
        local r, g, b, a = GetStringColor(G().barcustom or "0.7,0.1,0.08,1")
        return tonumber(r) or .7, tonumber(g) or .1, tonumber(b) or .08, tonumber(a) or 1
      end, function(r, g, b, a)
        G().barcustom = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
        Repaint()
      end)
    Chk(p, "Honor to the next rank", "Under the bar: about how much honor the next rank still takes, learnt from your own "
      .. "records at this rank (shows once 8 steps of rank % are seen).", "estimate")
    Sld(p, "Weekly cap", "The honor a week can hold (OctoWoW: 20 000).", 1000, 50000, 500, "cap",
      function(v) return pfUI.honor and pfUI.honor.Fmt(v) or tostring(v) end)
    W.Buttons(p, { { "Open my Honor tab", function() if ToggleCharacter then ToggleCharacter("HonorFrame") end end, 150,
      "The character window on its PvP tab (/honor)." } })

    -- (the character window in the same look: modules/charframe.lua)
    local function CG() return C.charframe end
    local function CPaint() if pfUI.charframe and pfUI.charframe.Paint then pfUI.charframe.Paint() end end
    W.Card(p, "Character window", { tip = "The whole character window in the same battle look: worn and burnt, your faction's "
      .. "crest behind your character, your name in gold with your rank badge, and a glow round your rare and better gear." })
    O.PfChk(p, "Battle look", "Off: pfUI's plain window (fully gone after a reload).", CG, "enable", CPaint)
    O.PfSld(p, "Window darkness", "How dark the window is under the grime.", .1, .9, .05, CG, "dark", CPaint,
      function(v) return math.floor(v * 100 + .5) .. "%" end)
    O.PfChk(p, "Faction crest behind you", nil, CG, "crest", CPaint)
    O.PfChk(p, "Rank badge by your name", nil, CG, "badge", CPaint)
    O.PfChk(p, "Glow round rare+ gear", "A soft glow in the item's quality colour round each worn item of rare or better.", CG, "glow", CPaint)
    O.PfChk(p, "Same look on the other windows", "Spellbook, talents, quest log and the profession windows get the worn finish too.",
      CG, "others", CPaint)
    O.PfChk(p, "New profession windows", "Trade skills and Enchanting laid out anew: search and filters above the list, "
      .. "categories as gold bars, the profession's picture behind the recipe. Off: pfUI's own skin (needs a reload).", CG, "prof")

    W.Card(p, "Your records", { tip = "Every honor gain, battleground result and step of rank %, per character." })
    W.Live(p, function()
      local hn = HN()
      if not hn or not hn.Store or not hn.ready then return "Records show here once you are in the game with the module on." end
      local s = hn.Store()
      local n = table.getn(s.log)
      local first = s.log[1]
      return n .. " records for " .. (UnitName("player") or "you") .. (first and (", since " .. date("%d %b %Y", first.t)) or "")
        .. (s.imported and ("   (HonorSpy copied " .. date("%d %b", s.imported) .. ")") or "")
    end)
    Sld(p, "Keep for", "Older records are dropped.", 14, 180, 1, "keepdays", function(v) return v .. " days" end)
    Chk(p, "Copy HonorSpy's history", "The first time TurtleHonorSpyEnhanced is loaded, its history comes over to this "
      .. "character (HonorSpy keeps one per realm and faction). Its own records are left as they are.", "import")
    W.Buttons(p, {
      { "Copy from HonorSpy now", function()
        local hn = HN()
        if not hn or not hn.Import then return end
        local n = hn.Import(true)
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r honor: " .. (n > 0 and ("copied " .. n .. " records from HonorSpy.")
          or "nothing new to copy (HonorSpy must be loaded)."))
        Repaint()
      end, 170, "Copies anything new from HonorSpy's history (it must be loaded)." },
    })
  end
  O:AddPage("Honor", "honor", "Honor", Build)
end)
