pfUI:RegisterModule("lootfilter", "vanilla", function ()
  -- pfUI Octo :: loot filter for Auto Loot (9 Nov 2026; Bread: "a filter
  -- system would be real handy for keeping bag space free of trash").
  -- A list of rules (libs/librules.lua), top to bottom, the first that matches
  -- decides: Take or Leave. Nothing matches: taken. Auto Loot asks it for
  -- every item of a scan (modules/autoloot.lua, AL.Decide), so what is left
  -- stays on the corpse - nothing is looted and thrown away.
  -- Settings: C.lootfilter.list = { { on, act = "keep" | "skip", name, rule, items = { itemID } } };
  -- a module of its own (switched off: Auto Loot takes everything).
  local R = pfUI.rules
  if not R then return end
  local LF = { stats = {}, skipped = 0 }
  pfUI.lootfilter = LF

  LF.DEFAULTS = {
    { on = "1", act = "keep", name = "Quest items", rule = 'Quest()' },
    { on = "1", act = "skip", name = "Grey items (vendor trash)", rule = 'Quality("poor")' },
    { on = "0", act = "skip", name = "White armour and weapons", rule = 'Quality("common") and (Type("Armor") or Type("Weapon"))' },
    { on = "0", act = "keep", name = "Cloth, ore, bars and herbs", rule = 'Name("Cloth", "Ore", "Bar") or Subtype("Herb") or Tooltip("Herbalism")' },
  }
  local function Copy(t)
    local out = {}
    for i = 1, table.getn(t) do
      local r = t[i]
      out[i] = { on = r.on, act = r.act, name = r.name, rule = r.rule, items = {} }
    end
    return out
  end
  function LF.List()
    C.lootfilter = C.lootfilter or {}
    if type(C.lootfilter.list) ~= "table" then C.lootfilter.list = Copy(LF.DEFAULTS) end
    return C.lootfilter.list
  end
  function LF.Reset() C.lootfilter = C.lootfilter or {} C.lootfilter.list = Copy(LF.DEFAULTS) end

  function LF.Active()
    local list = LF.List()
    for i = 1, table.getn(list) do if list[i].on == "1" then return true end end
    return false
  end

  -- an item of a scan ({ id, link, count, quality }) or anything R.Info reads
  -- -> keep, the rule that decided; dry: only asking (the Try it box)
  function LF.Keep(it, dry)
    local info = type(it) == "table" and R.Info(it.link or it.id, nil, nil, it.count) or R.Info(it)
    if type(it) == "table" and info.quality == nil then info.quality = it.quality end
    local list = LF.List()
    for i = 1, table.getn(list) do
      local r = list[i]
      if r.on == "1" then
        -- (9 Nov 2026) the rule's own items first (the item box), then its
        -- text, when it has one
        local hit = false
        if type(r.items) == "table" and info.id then
          for j = 1, table.getn(r.items) do if tonumber(r.items[j]) == info.id then hit = true break end end
        end
        if not hit and r.rule and r.rule ~= "" then
          local fn = R.Compile(r.rule)
          hit = fn and R.Match(fn, info) or false
        end
        if hit then
          local keep = r.act ~= "skip"
          if not keep and not dry then
            LF.skipped = LF.skipped + 1
            LF.stats[r.name or "?"] = (LF.stats[r.name or "?"] or 0) + 1
            LF.last = info.name
          end
          return keep, r.name
        end
      end
    end
    return true
  end

  function LF.Add()
    table.insert(LF.List(), { on = "1", act = "skip", name = "New rule", rule = "", items = {} })
  end
  function LF.Remove(i) table.remove(LF.List(), i) end
  function LF.Move(i, by)
    local list = LF.List()
    local j = i + by
    if j < 1 or j > table.getn(list) then return end
    list[i], list[j] = list[j], list[i]
  end
end)
