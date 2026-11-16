pfUI:RegisterModule("mail-options", "vanilla", function ()
  -- pfUI Octo :: the Mail section (16 Nov 2026, modules/mail.lua + mail-window.lua). Its own module so
  -- the section - and its on / off switch - stays when the mailbox is switched off.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local function G() return C.mail end

  local function Build(p)
    local m = pfUI.mail
    W.Heading(p, "Mailbox", { on = O.ModuleSwitch("mail", "The mailbox"),
      about = "pfUI Octo's own mail window, in place of the game's at a mailbox: every mail in one list, Collect all that never "
        .. "gets stuck (a mail it cannot take is left and the rest still come), and sending many items at once. Off = the game's "
        .. "own window (or another mail add-on), and nothing of this is loaded." })
    if not m then
      W.Note(p, "The mailbox is off. Use the switch at the top right to turn it back on (takes a reload).")
      return
    end
    W.Live(p, function()
      local other = m.Other()
      if other then return "|cffffcc00" .. other .. " is also switched on: it keeps the mail window and ours stands aside.|r" end
      return "|cff55ff55On: it opens when you click a mailbox.|r"
    end)
    if m.Other() then
      W.Buttons(p, { { "Switch " .. m.Other() .. " off", function()
        if DisableAddOn then DisableAddOn(m.Other()) end
        pfUI.gui.settingChanged = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r mail: the other add-on is switched off from the next reload.")
      end, 190, "Turns the other mail add-on off (from the next reload) so pfUI Octo's opens. Its folder and saved data stay.", role = "off" } })
    end

    W.Card(p, "Collecting", { icon = "Interface\\Icons\\INV_Misc_Coin_01", tip = "What Collect all does." })
    O.PfChk(p, "Collect as soon as the mailbox opens", "Takes everything (or what the Inbox's choice says) without a click.", G, "autocollect")
    O.PfChk(p, "Throw away emptied letters", "Off: letters stay in the inbox after their gold and items are taken.", G, "delete")
    O.PfChk(p, "Keep letters players wrote in", "A letter from a player with text in it stays, even when emptied.", G, "keeptext")
    O.PfSld(p, "Keep bag slots free", "Collecting stops taking items when only this many bag slots are left (gold still comes).", 0, 10, 1, G, "reserve")
    O.PfSld(p, "Wait for each mail", "How long a mail may take before it is left and the next one goes. Raise it on a slow connection.", 1, 6, .5, G, "wait", nil, function(v) return v .. " s" end)
    O.PfChk(p, "Say what was collected in chat", nil, G, "report")

    W.Card(p, "Sending", { icon = "Interface\\Icons\\INV_Letter_15", tip = "The Send tab." })
    O.PfChk(p, "Right-click bag items to attach them", "While the mailbox is open, a right-click in your bags puts the item on the Send tab.", G, "bagclick")
    W.Buttons(p, { { "Forget names", function()
      m.Store().names = {}
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r mail: the names you sent to are forgotten.")
    end, 130, "The To box stops suggesting the names you sent mail to (guild and friends still come).", role = "off" } })

    W.Card(p, "Window", { icon = "Interface\\Icons\\INV_Misc_Note_01", tip = "Drag its title bar to move it; the place is kept." })
    O.PfSld(p, "Size", nil, .6, 1.4, .05, G, "scale", nil, function(v) return math.floor(v * 100 + .5) .. "%" end)
    W.Note(p, "In the window: click a mail to read it, right-click to take everything out of it, Shift + click links its item. "
      .. "\"Game window\" in the title bar swaps to the game's own mail window for this visit.")
  end

  O:AddPage("Mail", "mail", "Mailbox", Build)
end)
