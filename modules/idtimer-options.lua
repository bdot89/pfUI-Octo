pfUI:RegisterModule("idtimer-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the ID Timer tab in Quality of Life (26 Nov 2026): the switch, IDTimer's own settings (IDTimerDB, the
  -- same ones as /idt announce / sound / autoshow / ids / minimap / lock / scale), and its buttons.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local function IT() return pfUI.idtimer end
  local function IDT() return _G.IDTimer end
  local function DB() return _G.IDTimer and _G.IDTimer.db end

  local function Build(p)
    W.Heading(p, "ID Timer", { on = { function() return IT() and IT().On() end, function(v)
        if not IT() then return end
        if v then IT().Enable() else IT().Disable() end
        if O.Rebuild and O.current then pcall(O.Rebuild, O, (string.gsub(O.current or "", "^o:", ""))) end
      end },
      about = "The server lets you into 5 different instances an hour (per account). ID Timer counts them: each instance you "
        .. "entered with a countdown to when its slot frees, walking back into the same one costs nothing, a reset makes "
        .. "the next entry a new slot - and your saved raid IDs with their reset timers.\n\nOff as it comes: the first "
        .. "time you reset an instance it asks once. /idt opens it (and /idt help lists its commands)." })
    W.Live(p, function()
      local it = IT()
      if it and it.Other() then return "|cffffcc00The separate idtimer add-on is on|r - pfUI's copy stands aside." end
      if not (it and it.On()) then return "|cff9a9ca3Off.|r Switch it on above." end
      local idt = IDT()
      if not (idt and idt.db) then return "|cff55ff55On|r" end
      local used = idt.Count()
      local nf = idt.NextFree()
      return string.format("|cff55ff55On|r  -  |cffffffff%d / %d|r instances this hour%s", used, idt.MAX_PER_HOUR,
        nf and ("  -  next slot in |cffffffff" .. idt.FormatTime(nf) .. "|r") or "")
    end)
    local on = IT() and IT().On() and DB()
    if not on then return end
    W.Buttons(p, {
      { "Show the window", function() if IDT() then IDT().Toggle() end end, 130, "The ID Timer window (/idt).", role = "open" },
      { "Tell my party", function() if IDT() then IDT().Report("PARTY") end end, 120, "Your timers in party chat.", role = "go" },
      { "Clear the list", function()
          local db = DB()
          if db then db.entries, db.resets = {}, {} end
          if IDT() then IDT().Refresh() end
        end, 110, "Takes every lockout off the list (it can't know about one someone else reset).", role = "danger" },
    })
    W.Card(p, "Settings", { icon = "Interface\\Icons\\INV_Misc_PocketWatch_01" })
    local function Flag(label, desc, key, after)
      W.Check(p, label, desc, function() return DB() and DB()[key] and true or false end, function(v)
        if DB() then DB()[key] = v and true or false end
        if after then after() end
        if IDT() and IDT().Refresh then IDT().Refresh() end
      end)
    end
    Flag("Chat messages", "A line in chat when you use a slot, when one frees, and when you reach the cap.", "announce")
    Flag("Warning sounds", "A sound when one slot is left, at the cap, and when a slot frees.", "sound")
    Flag("Open it when I go in", "The window shows each time you enter an instance that uses a slot.", "autoshow")
    Flag("Saved raid IDs", "Your saved raids and 5-mans with their reset timers under the hourly list.", "showsaved")
    Flag("Minimap button", "The watch with used/5 on the minimap (pfUI's minimap button menu takes it).", "minimap",
      function() if IDT() and IDT().UpdateMinimap then IDT().UpdateMinimap() end end)
    Flag("Lock the window", "No dragging (and no hint line at its foot).", "locked")
    W.Slider(p, "Window size", "The ID Timer window's scale.", .5, 2, .05,
      function() return DB() and DB().scale or 1 end,
      function(v)
        if DB() then DB().scale = v end
        if IDT() and IDT().ApplyScale then IDT().ApplyScale() end
      end, function(v) return math.floor(v * 100 + .5) .. "%" end)
    W.Note(p, "Right-click a lockout in the window to take it off; /idt add puts one on by hand (when someone else "
      .. "reset it, or you joined another group's copy).", 0, true)
  end

  O:AddPage("Quality of Life", "idtimer", "ID Timer", Build)
end)
