pfUI:RegisterModule("addoncompat", function ()
  -- save addon decissions across logins
  pfUI_init.addons = pfUI_init.addons or {}

  -- used as a dummy for an always matching dependency
  local always = function()
    return true
  end

  -- The first entry of the conflict tables contain a function
  -- that is used as a dependency checker. For example, to make sure
  -- we don't deactivate snowfall when actionbars aren't in use.
  -- The second entry is a function that runs specific code. This
  -- can be used to enable a specific option when the addon gets disabled.

  local hardconflict = {
    ["ClassicSnowFall"] = {
      function() return pfUI.bars end, -- dependency
      function() pfUI_config.bars.keydown = "1" end, -- option
    },
  }

  local softconflict = {
    ["MinimapButtonFrame"] = { always, function() pfUI_config.abuttons.enable = "1" end },
    ["MBB"] = { always, function() pfUI_config.abuttons.enable = "1" end },
    ["SellValue"] = { always },
    ["EquipCompare"] = { always },
    ["EQCompare"] = { always },
    ["OmniCC"] = { always },
    ["ShaguBoP"] = { always },
    ["ShaguCombat"] = { always },
    ["ShaguCopy"] = { always },
    ["ShaguError"] = { always },
    ["ShaguMount"] = { always },
    ["ShaguPlates"] = { always },
    ["ShaguTooltips"] = { always },
    ["ShaguValue"] = { always },
    ["ShaguTweaks"] = { always },
    ["ColorGuildFrame-1.0"] = { always },
    ["ColorSocialFrame"] = { always },
    ["DebuffTimers"] = { always },
    ["EquipColor"] = { always },
    ["FocusFrame"] = { always },
    ["GrayAutoSell"] = { always },
    ["QuickBind"] = { always },
    ["SmallerRollFrames"] = { always },
    ["EzDismount"] = { always },
    ["AddOnOrganizer"] = { always },
    ["Prat"] = { always },
  }

  -- pfUI Octo (11 Nov 2026, user: "an alert if people have anything enabled outside our addon that is already
  -- inbuilt into our addon"). Key = the add-on's name made plain (Plain: lower case, letters and digits only,
  -- a download's "-master" / "-main" dropped), so "pfQuest-master" and "pfquest" are the same add-on.
  -- [3] = what of ours does the same, for the question. Only asked while that part of pfUI Octo is in use.
  local function has(path)
    return function()
      local t = pfUI
      for part in string.gfind(path, "[^%.]+") do
        if type(t) ~= "table" then return false end
        t = t[part]
      end
      return t ~= nil
    end
  end
  local octoconflict = {
    ["pfquest"] = { always, nil, "Questing (pfQuest is built in; pfUI's copy stays off while this one is on)" },
    ["shagudps"] = { has("meters"), nil, "Meters (damage, healing and more)" },
    ["twthreat"] = { has("meters"), nil, "Threat meter and threat label" },
    ["sct"] = { has("sct"), nil, "Combat Text" },
    ["sctd"] = { has("sct"), nil, "Combat Text (your damage on enemies)" },
    ["bagnon"] = { has("bagsOcto"), nil, "Bags (one window for all bags)" },
    ["bagshui"] = { has("bagCats"), nil, "Bag categories" },
    ["itemrack"] = { has("gear"), nil, "Gear sets" },
    ["outfitter"] = { has("gear"), nil, "Gear sets" },
    ["closetgnome"] = { has("gear"), nil, "Gear sets" },
    ["trinketmenu"] = { has("gear"), nil, "Gear: trinket bar and trinket queue" },
    ["weaponswingtimer"] = { has("swing"), nil, "Swing Timer" },
    ["spswingtimer"] = { has("swing"), nil, "Swing Timer" },
    ["brainwasherpro"] = { has("gear.specs"), nil, "Gear: talent specs at the Brainwashing Device" },
    ["bettercharacterstats"] = { always, nil, "Character stats in the character window" },
    ["evenbettercharacterstats"] = { always, nil, "Character stats in the character window" },
    ["pfuicustommedia"] = { always, nil, "Bar textures, fonts and gryphon pictures (pfUI-CustomMedia is built in)" },
  }

  local function Plain(name)
    local n = string.lower(name or "")
    n = string.gsub(n, "[^%w]", "")
    n = string.gsub(n, "master$", "")
    n = string.gsub(n, "main$", "")
    return n
  end

  local require_reload
  local queue_soft = {}
  local queue_hard = {}
  local reason = {}

  -- scan through all addons
  -- (pfUI Octo: run when the queue starts, so every module has started and the [1] checks can see it)
  local function Scan(again)
    for i=1, GetNumAddOns() do
      local name, title, notes, enabled = GetAddOnInfo(i)
      local octo = name and octoconflict[Plain(name)]
      if again and octo then pfUI_init.addons[name] = nil end
      if enabled and not pfUI_init.addons[name] then
        if hardconflict[name] and hardconflict[name][1]() then
          queue_hard[name] = i
        end

        if softconflict[name] and softconflict[name][1]() then
          queue_soft[name] = i
        elseif octo and octo[1]() then
          queue_soft[name] = i
          reason[name] = octo
        end
      end
    end
  end

  local function RunQueue()
    -- run through hardlist
    local name, id = next(queue_hard)
    if name and id then
      -- disable addon
      DisableAddOn(id)

      -- trigger action if availabe
      if hardconflict[name][2] then
        hardconflict[name][2]()
      end

      -- ask for reload
      CreateQuestionDialog(
        string.format(T["The addon \"|cff33ffcc%s|r\" doesn't work with pfUI and has been disabled."], name) .. "\n"
        .. T["Do you want to reload the UI now?"],
        {T["Yes"], function()
          ReloadUI()
        end},
        {T["No"], function()
          queue_hard[name] = nil
        end},
        nil, RunQueue)
      return
    end

    -- run through softlist
    local name, id = next(queue_soft)
    if name and id then
      local octo = reason[name]
      local text
      if octo then
        text = string.format(T["\"|cff33ffcc%s|r\" is already built into pfUI Octo:"], name) .. "\n|cffffd100"
          .. T[octo[3]] .. "|r\n\n" .. T["Running both can show things twice or make them fight."] .. "\n"
          .. T["Do you want to disable the addon?"]
      else
        text = string.format(T["Every feature that \"|cff33ffcc%s|r\" offers is already built into pfUI."], name) .. "\n"
          .. T["Do you want to disable the addon?"]
      end
      CreateQuestionDialog(text,
        {T["Yes"], function()
          queue_soft[name] = nil

          -- trigger action if availabe
          local entry = softconflict[name] or octo
          if entry and entry[2] then
            entry[2]()
          end

          DisableAddOn(id)
          require_reload = true
        end},
        {T["No"], function()
          queue_soft[name] = nil

          -- cache value to not ask again
          pfUI_init.addons[name] = true
        end},
        nil, RunQueue)
      return
    end

    -- in case of changes, ask for reload
    if require_reload then
      require_reload = nil
      CreateQuestionDialog(
        T["The addon selection has changed."] .. "\n"
        .. T["Do you want to reload the UI now?"],
        {T["Yes"], function()
          ReloadUI()
        end},
        {T["No"], function() end},
        nil)
    end
  end

  -- pfUI Octo: the list, and asking again about the ones answered "No" before (Quality of Life page)
  pfUI.addoncompat = {
    Plain = Plain,
    octo = octoconflict,
    -- the switched-on add-ons that pfUI Octo already does: { { name, what }, ... }
    Doubled = function()
      local found = {}
      for i=1, GetNumAddOns() do
        local name, _, _, enabled = GetAddOnInfo(i)
        local octo = name and octoconflict[Plain(name)]
        if enabled and octo and octo[1]() then table.insert(found, { name, octo[3] }) end
      end
      return found
    end,
    Check = function()
      Scan(true)
      if next(queue_soft) or next(queue_hard) then RunQueue() return true end
      return false
    end,
  }

  -- run the addonconflict queue when firstrun is ready
  local delay = CreateFrame("Frame")
  delay:SetScript("OnUpdate", function()
    -- throttle to to one query per .1 second
    if ( this.tick or 1) > GetTime() then return else this.tick = GetTime() + .1 end

    -- make sure the firstrun dialog has finished
    if pfUI.firstrun and pfUI.firstrun.steps then
      for _, step in pairs(pfUI.firstrun.steps) do
        if not pfUI_init[step.name] then return end
      end
    end

    Scan()
    RunQueue()
    this:SetScript("OnUpdate", nil)
  end)
end)
