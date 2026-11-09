pfUI:RegisterModule("lootfilter-options", "vanilla", function ()
  -- pfUI Octo :: the Loot Filter page (9 Nov 2026, modules/lootfilter.lua),
  -- under Quality of Life: the module switch, what it left this session,
  -- the rules top to bottom, and a box to try them on an item.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local R = pfUI.rules

  local ACTS = { { key = "keep", label = "Take it" }, { key = "skip", label = "Leave it" } }
  local tryItem = ""

  local function Build(p)
    local LF = pfUI.lootfilter
    W.Heading(p, "Loot filter", { on = O.ModuleSwitch("lootfilter", "Loot filter"),
      about = "Auto Loot asks these rules about every item on the corpses around you. Top to bottom, the first rule that "
        .. "matches decides: take it or leave it on the corpse. An item no rule matches is taken. Nothing is looted and "
        .. "then thrown away. In a group, items at or over the loot threshold are always left for the master looter or the roll." })
    if not LF then
      W.Note(p, "The loot filter is switched off. Switch it on above and reload; until then Auto Loot takes everything (in a group, everything under the loot threshold).", nil, true)
      return
    end

    W.Live(p, function()
      local line = (LF.Active() and "|cff55ff55On|r" or "|cffffcc00No rule is switched on|r") .. "   left on corpses this session: " .. LF.skipped
      if LF.last then line = line .. "   last: " .. LF.last end
      if not (pfUI.autoloot and pfUI.autoloot.Available and pfUI.autoloot.Available()) then
        line = line .. "   |cffff5555(Auto Loot needs ClassicAPI)|r"
      end
      return line
    end)

    local list = LF.List()
    for i = 1, table.getn(list) do
      local idx = i
      local function r() return LF.List()[idx] end
      W.Card(p, idx .. ".  " .. (list[idx].name or "Rule"), { tip = "Rules are checked from the top; the first that matches decides." })
      W.Check(p, "Use this rule", nil, function() return r() and r().on == "1" end, function(v) if r() then r().on = v and "1" or "0" end end)
      W.Dropdown(p, "When it matches", nil, ACTS, function() return r() and r().act end, function(v) if r() then r().act = v end end)
      W.Edit(p, "Name", nil, function() return r() and r().name end, function(v) if r() then r().name = v O:Rebuild("lootfilter") end end, 260)
      W.Edit(p, "Rule", "For example: Quality(\"poor\") and not Name(\"Hide\")", function() return r() and r().rule end,
        function(v) if r() then r().rule = v end end, 460)
      W.Live(p, function()
        local rule = r() and r().rule
        local fn, err = R.Compile(rule)
        if not fn then return "|cffff5555This rule has a mistake:|r " .. tostring(err) end
        return "|cff55ff55Rule reads fine|r"
      end)
      W.Buttons(p, {
        { "Move up", function() LF.Move(idx, -1) O:Rebuild("lootfilter") end, 90, "Checked one place earlier." },
        { "Move down", function() LF.Move(idx, 1) O:Rebuild("lootfilter") end, 90, "Checked one place later." },
        { "Delete", function() LF.Remove(idx) O:Rebuild("lootfilter") end, 80, "Remove this rule." },
      })
    end

    W.Card(p, "More rules", { tip = "Add a rule, or go back to the four this started with." })
    W.Buttons(p, {
      { "Add a rule", function() LF.Add() O:Rebuild("lootfilter") end, 110, "A new rule at the bottom." },
      { "Back to the defaults", function() LF.Reset() O:Rebuild("lootfilter") end, 150, "Throws your rules away and puts the starting four back." },
    })
    W.Note(p, "Checks: Name, NameIs, ID, Type, Subtype, Equip, Quality(\"poor\"...\"legendary\" or 0-6), MinQuality, MaxQuality, "
      .. "Level(min, max), Tooltip, BoE(), BoP(), Soulbound(), Quest(), Stackable(), Count(n), Value(min, max). "
      .. "Join them with and / or / not and brackets. Text matches anywhere in any case; several words = any of them.")

    W.Card(p, "Try it", { tip = "See what the filter would do with an item." })
    W.Edit(p, "Item", "An item ID (2589) or a link (Shift-click an item while typing here). The game must have seen the item.",
      function() return tryItem end, function(v) tryItem = v or "" end, 260)
    W.Live(p, function()
      if tryItem == "" then return "Type an item ID or link above and press Enter." end
      local info = R.Info(tryItem)
      if not info.name then return "|cffffcc00The game does not know this item yet|r (see it once: a link, a bag, the auction house)." end
      local keep, name = LF.Keep(info, true)
      return info.name .. ":  " .. (keep and "|cff55ff55taken|r" or "|cffff5555left on the corpse|r")
        .. (name and ("  (rule: " .. name .. ")") or "  (no rule matched)")
    end)
  end

  O:AddPage("Loot Filter", "lootfilter", "Loot Filter", Build)
end)
