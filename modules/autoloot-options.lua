pfUI:RegisterModule("autoloot-options", "vanilla", function ()
  -- pfUI Octo :: the Auto Loot page (4 Nov 2026, modules/autoloot.lua): its own
  -- topic in the list, every setting on one page, a live status line.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  local AL = pfUI.autoloot
  if not W or not O or not O.AddPage or not AL then return end
  local function G() return C.autoloot end
  local function Sec(v) return string.format("%.2f s", v) end
  local function Yd(v) return v .. " yd" end
  local function Px(v) return v .. " px" end
  local function Chk(p, label, desc, key, after) return O.PfChk(p, label, desc, G, key, after) end
  local function Sld(p, label, desc, min, max, step, key, fmt, after) return O.PfSld(p, label, desc, min, max, step, G, key, after, fmt) end
  local function Redraw() if AL.RefreshLog then AL.RefreshLog() end end

  local function Build(p)
    W.Heading(p, "Auto Loot", { on = O.KeySwitch(G, "enable", "Loots every corpse around you by itself, on or off."),
      about = "Loots the corpses near you by itself when a mob dies, when you stop moving and when a fight ends - "
        .. "no clicking. It waits while you move, cast, hold a loot window open or a scan is still running. "
        .. "Needs the ClassicAPI DLL (Install pfUI Octo DLLs.bat)." })

    W.Live(p, function()
      local s = AL.state
      local line
      if not AL.Available() then
        line = "|cffff5555Needs ClassicAPI:|r its loot function was not found. Close the game, run |cffffd100Install pfUI Octo DLLs.bat|r, start again."
      elseif s.conflict then
        line = "|cffff5555The AutoAreaLoot addon is on too|r, so this stands aside. Switch one of them off."
      else
        local why = AL.Blocked()
        line = why == "off" and "|cffff5555Off|r" or (why and ("|cffffcc00Waiting:|r " .. why) or "|cff55ff55Ready|r")
        line = line .. "   passes this session: " .. (s.runs or 0) .. "   items: " .. s.count .. "   " .. AL.Money(s.money)
      end
      return line
    end)

    W.Card(p, "When to loot", { icon = "Interface\\Icons\\INV_Misc_Bag_08", tip = "Each reason is its own switch. A request that has to wait (moving, casting) is kept and done as soon as it can." })
    Chk(p, "A mob dies near you", "Loots right after a kill. Only mobs inside loot range count.", "death")
    Chk(p, "You stop moving", "Loots whatever is around you each time you come to a stop.", "stop")
    Chk(p, "During combat", "Off: waits until the fight is over, then does one pass.", "combat")
    Chk(p, "Hide the loot window", "The game's own loot window flashes up for each corpse; this closes it. Off: a window that opens is left for you.", "closewin")

    W.Card(p, "Timing", { icon = "Interface\\Icons\\INV_Misc_PocketWatch_01", tip = "The defaults suit most people." })
    Sld(p, "Kill range", "A death further away than this is ignored.", 3, 20, 1, "deathdist", Yd)
    Sld(p, "After a kill", "How long to wait after a death before looting (the corpse needs a moment).", 0, 1, .05, "deathdelay", Sec)
    Sld(p, "After stopping", "You must stand still this long before it loots; moving again cancels it.", .05, 1, .05, "stopdelay", Sec)

    W.Card(p, "Loot log", { icon = "Interface\\Icons\\INV_Misc_Note_01", tip = "What it picked up: items from your loot messages and the money you gained." })
    Chk(p, "Keep a log", nil, "log")
    Chk(p, "Combine matching items", "One row per item with its total. Off: every loot with its time, newest first.", "combine", Redraw)
    Chk(p, "Chat summary", "One line in chat after each pass: how many items and how much money.", "chat")
    Chk(p, "Open the log at login", nil, "loginopen")
    Chk(p, "Lock the log window", "It stays where it is (Move Frames still moves it).", "loglock")
    Sld(p, "Window width", nil, 240, 600, 10, "logw", Px, Redraw)
    Sld(p, "Window height", "Shows as many rows as fit.", 120, 600, 10, "logh", Px, Redraw)
    W.Buttons(p, {
      { "Open the log", function() AL.ShowLog(true) end, 130, "Show the loot log window." },
      { "Clear the log", function() AL.Clear() end, 130, "Forget everything in the log." },
      { "Add sample rows", function() AL.Sample() AL.ShowLog(true) end, 140, "Fill the log with a few made-up rows to see how it looks." },
    })
    W.Note(p, "Commands: /autoloot (this page), /autoloot on, /autoloot off, /autoloot log, /autoloot status")
  end

  O:AddPage("Auto Loot", "autoloot", "Auto Loot", Build)
end)
