pfUI:RegisterModule("gear", "vanilla", function ()
  -- pfUI Octo :: gear sets (24 Oct 2026). User: ItemRack "like we have been
  -- adding the rest of the addons in". ItemRack Universal 4.56.1 has no
  -- licence (all rights reserved) and needs Classic Era's APIs, so this is
  -- written fresh for 1.12 from its feature list; none of its code or art used.
  -- Phase 1: sets (full or partial, exact item copies told apart by enchant
  -- and suffix), equip / unequip (= the gear worn before) / toggle, weapons
  -- at once in combat and the rest when combat ends, a set button and a
  -- minimap button with a menu of sets, ten key bindings, /gear.
  -- Settings C.gear.*; sets C.gear.sets[name] = { icon, key, slots = {
  -- ["s<inv>"] = { id = "item:enchant:suffix", name, tex } | "empty" } }.
  -- pfUI_config is per character, so the sets are too.
  local GR = { queue = nil }
  pfUI.gear = GR
  C.gear = C.gear or {}
  C.gear.sets = C.gear.sets or {}
  C.gear.before = C.gear.before or {}

  local function Say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r gear: " .. msg) end

  -- ---------------------------------------------------------------- slots

  GR.SLOTS = {
    { 1, "HeadSlot", "Head" }, { 2, "NeckSlot", "Neck" }, { 3, "ShoulderSlot", "Shoulders" },
    { 15, "BackSlot", "Back" }, { 5, "ChestSlot", "Chest" }, { 4, "ShirtSlot", "Shirt" },
    { 19, "TabardSlot", "Tabard" }, { 9, "WristSlot", "Wrists" }, { 10, "HandsSlot", "Hands" },
    { 6, "WaistSlot", "Waist" }, { 7, "LegsSlot", "Legs" }, { 8, "FeetSlot", "Feet" },
    { 11, "Finger0Slot", "Ring 1" }, { 12, "Finger1Slot", "Ring 2" }, { 13, "Trinket0Slot", "Trinket 1" },
    { 14, "Trinket1Slot", "Trinket 2" }, { 16, "MainHandSlot", "Main hand" }, { 17, "SecondaryHandSlot", "Off hand" },
    { 18, "RangedSlot", "Ranged" },
  }
  GR.NAME = {}
  for _, s in ipairs(GR.SLOTS) do GR.NAME[s[1]] = s[3] end
  -- weapons can be swapped in combat on 1.12; armour cannot
  GR.WEAPON = { [16] = true, [17] = true, [18] = true }
  -- which slots an item can go in (GetItemInfo's equip location)
  GR.FITS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
    INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 }, INVTYPE_TABARD = { 19 },
  }
  function GR.Key(inv) return "s" .. inv end

  -- an item's identity: "item:enchant:suffix" from its link (the same item
  -- with another enchant or suffix is another copy)
  function GR.IdOf(link)
    if not link then return nil end
    local _, _, id, ench, suffix = string.find(link, "item:(%d+):(%d*):(%d*)")
    if not id then return nil end
    return id .. ":" .. (ench ~= "" and ench or "0") .. ":" .. (suffix ~= "" and suffix or "0")
  end
  -- the whole identity, with the link's 4th number: two copies with one name,
  -- id, enchant and suffix can still differ there (user's friend, 25 Oct 2026:
  -- two "Jasper Link of Fire Resistance", +19 and +20 - picking one swapped in
  -- the other or did nothing). Sets and picks keep it as .full
  function GR.FullOf(link)
    if not link then return nil end
    local _, _, id, ench, suffix, uniq = string.find(link, "item:(%d+):(%-?%d*):(%-?%d*):?(%-?%d*)")
    if not id then return nil end
    local function N(v) return (v and v ~= "") and v or "0" end
    return id .. ":" .. N(ench) .. ":" .. N(suffix) .. ":" .. N(uniq)
  end
  local function Base(id) return id and (string.gsub(id, ":.*$", "")) end
  local function NameOf(link)
    if not link then return nil end
    local _, _, n = string.find(link, "%[(.-)%]")
    return n
  end

  -- A picture worth keeping. Seen in game 24 Oct: items the game had not
  -- loaded yet gave Interface\Icons\INV_Robe_02, a file this client does not
  -- have (checked against every MPQ's file list), so it drew blank.
  local BADTEX = { ["interface\\icons\\inv_robe_02"] = true }
  function GR.GoodTex(t)
    return type(t) == "string" and t ~= "" and not BADTEX[string.lower(t)]
  end

  -- The picture of what is worn in a slot. Seen in game 24 Oct: for this
  -- server's own items (the Prophecy set, 47xxx) GetInventoryItemTexture keeps
  -- giving the missing placeholder, while GetItemInfo has the real picture.
  -- Found 24 Oct: DmorphOcto's item morphs change the picture the game
  -- reports for a worn item (its main-hand morph made a staff show a sword;
  -- morphs into items the client lacks gave the placeholder). GetItemInfo
  -- reads the real item, so its picture comes first.
  function GR.InvTex(inv)
    local link = GetInventoryItemLink("player", inv)
    -- (an empty slot has no picture - with a morph on it the game still
    -- reports the morph's, seen 24 Oct with the staff put away)
    if not link then return nil end
    local _, _, base = string.find(link, "item:(%d+)")
    if base and _G.GetItemInfo then
      local _, _, _, _, _, _, _, _, tex = _G.GetItemInfo("item:" .. base)
      if GR.GoodTex(tex) then return tex end
    end
    local t = GetInventoryItemTexture("player", inv)
    if GR.GoodTex(t) then return t end
    return nil
  end

  -- a two-handed weapon in the main hand (the off hand cannot be used then)
  function GR.TwoHanded()
    local link = GetInventoryItemLink("player", 16)
    local _, _, base = string.find(link or "", "item:(%d+)")
    if not base or not _G.GetItemInfo then return false end
    local _, _, _, _, _, _, _, loc = _G.GetItemInfo("item:" .. base)
    return loc == "INVTYPE_2HWEAPON"
  end

  function GR.Worn(inv)
    local link = GetInventoryItemLink("player", inv)
    return GR.IdOf(link), link
  end

  -- every carried item: bag, slot, id, link
  function GR.Bags()
    local out = {}
    for bag = 0, 4 do
      for slot = 1, (GetContainerNumSlots(bag) or 0) do
        local link = GetContainerItemLink(bag, slot)
        if link then table.insert(out, { bag = bag, slot = slot, id = GR.IdOf(link), full = GR.FullOf(link), link = link }) end
      end
    end
    return out
  end

  -- what is worn now, as a set's slots (every slot, or the ones given)
  function GR.Snapshot(only)
    local slots = {}
    for _, s in ipairs(GR.SLOTS) do
      local inv = s[1]
      if not only or only[GR.Key(inv)] ~= nil then
        local id, link = GR.Worn(inv)
        if id then
          slots[GR.Key(inv)] = { id = id, full = GR.FullOf(link), guid = GR.LC().ItemGUID and GR.LC().ItemGUID(nil, inv), name = NameOf(link) or "", tex = GR.InvTex(inv) or "" }
        else
          slots[GR.Key(inv)] = "empty"
        end
      end
    end
    return slots
  end

  -- ---------------------------------------------------------------- sets

  function GR.Sets()
    local names = {}
    for name in pairs(C.gear.sets) do table.insert(names, name) end
    table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
    return names
  end

  -- a slot of a set worn right now
  -- is this very copy anywhere: worn or in the bags
  -- ClassicAPI item GUIDs (25 Oct 2026): the very copy, wherever it went
  function GR.LC() return pfUI.api.libclient or {} end
  -- (one look round per moment: set buttons ask for every slot of every set)
  local where, whereAt = {}, -1
  function GR.GUIDWhere(guid)
    local LC = GR.LC()
    if not guid or not LC.ItemGUID then return end
    local t = GetTime()
    if t ~= whereAt then
      whereAt, where = t, {}
      for _, s in ipairs(GR.SLOTS) do
        local g = LC.ItemGUID(nil, s[1])
        if g then where[g] = { inv = s[1] } end
      end
      for bag = 0, 4 do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
          local g = LC.ItemGUID(bag, slot)
          if g and not where[g] then where[g] = { bag = bag, slot = slot } end
        end
      end
    end
    local at = where[guid]
    if not at then return end
    if at.inv then return { inv = at.inv } end
    local link = GetContainerItemLink(at.bag, at.slot)
    return { bag = at.bag, slot = at.slot, id = GR.IdOf(link), link = link }
  end
  -- (a move made this moment must be seen by the next look)
  function GR.ForgetWhere() whereAt = -1 end
  function GR.HasCopy(full)
    for _, s in ipairs(GR.SLOTS) do
      local _, link = GR.Worn(s[1])
      if link and GR.FullOf(link) == full then return true end
    end
    for bag = 0, 4 do
      for slot = 1, (GetContainerNumSlots(bag) or 0) do
        local link = GetContainerItemLink(bag, slot)
        if link and GR.FullOf(link) == full then return true end
      end
    end
    return false
  end
  local function Done(inv, want)
    local id, link = GR.Worn(inv)
    if want == "empty" then return id == nil end
    if id == nil or id ~= want.id then return false end
    -- (ClassicAPI: the item's own GUID says it is the very copy)
    if want.guid and GR.LC().ItemGUID then
      if GR.LC().ItemGUID(nil, inv) == want.guid then return true end
      if GR.GUIDWhere(want.guid) then return false end
    end
    -- (the very copy, when the set or pick knows it and it is still about;
    -- gone - sold, banked - the same item will do)
    if not want.full or GR.FullOf(link) == want.full then return true end
    return not GR.HasCopy(want.full)
  end

  -- a trinket slot whose queue is on swaps by itself: a set does not count it
  -- (user, 25 Oct 2026: the set button said "No set" while wearing one)
  local function QueueSlot(inv)
    if inv ~= 13 and inv ~= 14 then return false end
    local q = C.gear.tqueue and C.gear.tqueue[tostring(inv)]
    return type(q) == "table" and q.on == "1"
  end
  -- worn: true; how many of its slots are right and how many it has
  function GR.Match(name)
    local set = C.gear.sets[name]
    if not set then return false, 0, 0 end
    local right, total = 0, 0
    for key, want in pairs(set.slots or {}) do
      local inv = tonumber(string.sub(key, 2))
      if inv and not QueueSlot(inv) then
        total = total + 1
        if Done(inv, want) then right = right + 1 end
      end
    end
    return total > 0 and right == total, right, total
  end
  function GR.IsEquipped(name)
    local worn = GR.Match(name)
    return worn and true or false
  end
  -- the set worn now: the last one put on if it still is, else any that is;
  -- else the closest one (three in four of its slots or more) - second return
  -- true then (a piece or two changed by hand)
  function GR.Current()
    if C.gear.current and GR.IsEquipped(C.gear.current) then return C.gear.current end
    local best, bestShare
    for _, name in ipairs(GR.Sets()) do
      local worn, right, total = GR.Match(name)
      if worn then return name end
      local share = total > 0 and right / total or 0
      if share >= .75 and (not bestShare or share > bestShare or (share == bestShare and name == C.gear.current)) then
        best, bestShare = name, share
      end
    end
    if best then return best, true end
  end

  function GR.Save(name, slots, icon)
    if not name or name == "" then return end
    local set = C.gear.sets[name] or {}
    set.slots = slots or set.slots or GR.Snapshot()
    if icon then set.icon = icon end
    if not set.icon or set.icon == "" or not GR.GoodTex(set.icon) then
      set.icon = nil
      for _, k in ipairs({ "s5", "s16", "s1", "s15", "s3" }) do
        local e = set.slots[k]
        if type(e) == "table" and GR.GoodTex(e.tex) then set.icon = e.tex break end
      end
      set.icon = set.icon or "Interface\\Icons\\INV_Chest_Plate06"
    end
    C.gear.sets[name] = set
    GR.Changed()
    return set
  end

  function GR.Delete(name)
    if C.gear.current == name then C.gear.current = nil end
    C.gear.sets[name] = nil
    GR.Changed()
  end

  function GR.Rename(old, new)
    if not old or not new or new == "" or old == new or not C.gear.sets[old] or C.gear.sets[new] then return end
    C.gear.sets[new] = C.gear.sets[old]
    C.gear.sets[old] = nil
    if C.gear.current == old then C.gear.current = new end
    GR.Changed()
    return true
  end

  -- something changed: buttons, binding names, the options page
  GR.listeners = {}
  function GR.Changed()
    for i = 1, 10 do _G["BINDING_NAME_PFGEAR" .. i] = "Gear set " .. i end
    for name, set in pairs(C.gear.sets) do
      local k = tonumber(set.key or "")
      if k then _G["BINDING_NAME_PFGEAR" .. k] = "Gear set " .. k .. ": " .. name end
    end
    for _, fn in pairs(GR.listeners) do pcall(fn) end
  end

  -- ---------------------------------------------------------------- swapping

  -- where an item is: worn in another slot, or in a bag (exact copy first,
  -- then the same item with another enchant). skip = worn slots to leave.
  function GR.Find(want, skip)
    if type(want) ~= "table" then return end
    -- (ClassicAPI) the copy by its own GUID
    if want.guid then
      local at = GR.GUIDWhere(want.guid)
      if at and not (at.inv and skip[at.inv]) then return at end
    end
    -- the copy that was clicked, if it is still where it was
    local from = want.from
    if from and from.bag and want.full then
      local link = GetContainerItemLink(from.bag, from.slot)
      if link and GR.FullOf(link) == want.full then return { bag = from.bag, slot = from.slot, id = GR.IdOf(link), link = link } end
    elseif from and from.inv and want.full and not skip[from.inv] then
      local _, link = GR.Worn(from.inv)
      if link and GR.FullOf(link) == want.full then return { inv = from.inv } end
    end
    local bags = GR.Bags()
    -- the very copy (4th number too), worn elsewhere or in a bag
    if want.full then
      for _, s in ipairs(GR.SLOTS) do
        local inv = s[1]
        if not skip[inv] then
          local _, link = GR.Worn(inv)
          if link and GR.FullOf(link) == want.full then return { inv = inv } end
        end
      end
      for _, b in ipairs(bags) do if b.full == want.full then return b end end
    end
    for _, s in ipairs(GR.SLOTS) do
      local inv = s[1]
      if not skip[inv] and GR.Worn(inv) == want.id then return { inv = inv } end
    end
    for _, b in ipairs(bags) do if b.id == want.id then return b end end
    for _, b in ipairs(bags) do if Base(b.id) == Base(want.id) then return b end end
  end

  -- (bag slots just filled - the game may still call them empty for a
  -- moment - and ones a special bag would not take are skipped; 24 Oct 2026,
  -- the Birthday suit takes many things off in a row)
  local taken, refused = {}, {}
  local function FreeBagSlot()
    local now = GetTime()
    for bag = 0, 4 do
      for slot = 1, (GetContainerNumSlots(bag) or 0) do
        local k = bag .. ":" .. slot
        if not GetContainerItemLink(bag, slot) and not refused[k] and not (taken[k] and now - taken[k] < 3) then
          return bag, slot
        end
      end
    end
  end
  GR.FreeBagSlot = FreeBagSlot
  local function FreeSlots()
    local n = 0
    for bag = 0, 4 do
      for slot = 1, (GetContainerNumSlots(bag) or 0) do
        if not GetContainerItemLink(bag, slot) then n = n + 1 end
      end
    end
    return n
  end
  GR.FreeSlots = FreeSlots

  local function Busy()
    if CursorHasItem and CursorHasItem() then return true end
    if SpellIsTargeting and SpellIsTargeting() then return true end
  end
  local function Locked(inv, from)
    if IsInventoryItemLocked and IsInventoryItemLocked(inv) then return true end
    if from and from.inv and IsInventoryItemLocked and IsInventoryItemLocked(from.inv) then return true end
    if from and from.bag then
      local _, _, locked = GetContainerItemInfo(from.bag, from.slot)
      if locked then return true end
    end
  end

  local function InCombat() return UnitAffectingCombat("player") end

  -- why gear cannot change right now (phase 3: swaps wait until it can):
  -- "dead", "casting", or nil. Combat is per slot (weapons may still go).
  local function Casting()
    local ok, a = pcall(UnitCastingInfo, "player")
    if ok and a then return true end
    ok, a = pcall(UnitChannelInfo, "player")
    return ok and a and true or nil
  end
  function GR.Blocked()
    if C.gear.waitdead ~= "0" and UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return "dead" end
    if C.gear.waitcast ~= "0" and Casting() then return "casting" end
    return nil
  end
  local WAIT_TEXT = { combat = "the rest goes on when combat ends", dead = "it goes on when you are alive again",
                      casting = "it goes on when your cast ends" }
  function GR.WaitText(q)
    q = q or GR.queue
    if not q or not q.waiting then return nil end
    return q.name .. ": " .. (WAIT_TEXT[q.waiting] or WAIT_TEXT.combat)
  end

  -- one move for a slot of the queue; true = something was done
  local function Step(inv, want, keep)
    if want == "empty" then
      local bag, slot = FreeBagSlot()
      if not bag then Say("no room in your bags to take off " .. GR.NAME[inv] .. ".") return "fail" end
      if IsInventoryItemLocked and IsInventoryItemLocked(inv) then return false end
      PickupInventoryItem(inv)
      PickupContainerItem(bag, slot)
      if CursorHasItem and CursorHasItem() then
        -- that bag would not take it (a quiver, a soul bag): back on, try another
        PickupInventoryItem(inv)
        refused[bag .. ":" .. slot] = true
        return false
      end
      taken[bag .. ":" .. slot] = GetTime()
      return true
    end
    local from = GR.Find(want, keep)
    if not from then return "missing" end
    if Locked(inv, from) then return false end
    if from.inv then
      PickupInventoryItem(from.inv)
      PickupInventoryItem(inv)
    else
      PickupContainerItem(from.bag, from.slot)
      -- (1.12 has no EquipCursorItem: a click on the slot with the item held
      -- puts it on, and the one worn goes to the bag slot it came from)
      PickupInventoryItem(inv)
    end
    -- (anything left on the cursor goes back where it came from)
    if CursorHasItem and CursorHasItem() then
      if from.bag then PickupContainerItem(from.bag, from.slot) else PickupInventoryItem(from.inv) end
    end
    return true
  end

  -- the queue: { name, slots, order = { inv... }, tries = {} }; one move per
  -- tick, each waiting for the item locks of the last one
  local runner = CreateFrame("Frame")
  runner:Hide()
  GR.runner = runner
  local function Finish(q)
    GR.queue = nil
    runner:Hide()
    if q.missing and q.missing ~= "" then Say("not found in your bags: " .. q.missing .. ".") end
    GR.Changed()
  end
  -- this slot has to wait for combat to end: armour always; weapons when they may not
  -- change in combat - for any swap (combatweapons) or only for automatic ones
  -- (autocombatweapons; 11 Nov 2026, Wolfahrt: a boss / not-a-boss weapon swap mid-fight
  -- costs a global cooldown)
  local function WaitsForCombat(q, inv)
    if not InCombat() then return false end
    if not GR.WEAPON[inv] or C.gear.combatweapons == "0" then return true end
    return (q.auto and C.gear.autocombatweapons == "0") and true or false
  end
  GR.WaitsForCombat = WaitsForCombat

  function GR.Tick()
    local q = GR.queue
    GR.ForgetWhere()
    if not q then runner:Hide() return end
    if Busy() then return end
    -- dead or casting: everything waits (the runner keeps looking)
    local blocked = GR.Blocked()
    if blocked then
      if q.waiting ~= blocked then
        q.waiting = blocked
        if C.gear.tellwait ~= "0" then Say(GR.WaitText(q) .. ".") end
        GR.Changed()
      end
      return
    end
    if q.waiting == "dead" or q.waiting == "casting" then
      q.waiting = nil
      q.told = nil
      GR.Changed()
    end
    local waiting, pending
    local now = GetTime()
    -- slots of this set to keep where they are (already right)
    local keep = {}
    for _, inv in ipairs(q.order) do
      if Done(inv, q.slots[GR.Key(inv)]) then keep[inv] = true end
    end
    -- ClassicAPI (the instant swap the ClassicAPI pfUI fork gets from its
    -- equipment sets): every slot that may change now goes in this one pass,
    -- cursor-free - C_Item.EquipItemByName with the exact copy's bag slot or
    -- worn slot (GR.Find: GUID, full link, id). Taking off, slots waiting for
    -- combat / death / a cast, and anything that did not take go through the
    -- one-a-tick queue below.
    if GR.Instant() then
      q.sent, q.itries = q.sent or {}, q.itries or {}
      local used = {}
      for _, inv in ipairs(q.order) do
        local want = q.slots[GR.Key(inv)]
        -- (three instant tries a slot, then the cursor queue has it)
        if not keep[inv] and not q.skip[inv] and type(want) == "table" and (q.sent[inv] or 0) <= now
          and (q.itries[inv] or 0) < 3
          and not WaitsForCombat(q, inv) then
          local from = GR.Find(want, keep)
          local k = from and (from.inv and ("i" .. from.inv) or (from.bag .. ":" .. from.slot))
          if from and not used[k] and not Locked(inv, from) then
            used[k] = true
            local loc = from.inv and { equipmentSlotIndex = from.inv } or { bagID = from.bag, slotIndex = from.slot }
            -- (1 s for the server to answer before this slot is looked at again)
            q.itries[inv] = (q.itries[inv] or 0) + 1
            if pcall(C_Item.EquipItemByName, loc, inv) then q.sent[inv] = now + 1 end
          end
        end
      end
    end
    for _, inv in ipairs(q.order) do
      local want = q.slots[GR.Key(inv)]
      if not keep[inv] and not q.skip[inv] and q.sent and (q.sent[inv] or 0) > now then
        -- sent by the instant pass, the server has not answered yet
        pending = true
      elseif not keep[inv] and not q.skip[inv] then
        if WaitsForCombat(q, inv) then
          waiting = true
        else
          q.tries[inv] = (q.tries[inv] or 0) + 1
          if q.tries[inv] > 40 then
            q.skip[inv] = true
          else
            local r = Step(inv, want, keep)
            if r == "missing" then
              q.skip[inv] = true
              q.missing = (q.missing and (q.missing .. ", ") or "") .. (type(want) == "table" and want.name or GR.NAME[inv])
            elseif r == "fail" then
              q.skip[inv] = true
            end
            -- (one move a tick: the next waits for this one's locks)
            if r == true or r == false then return end
          end
        end
      end
    end
    if waiting then
      if not q.told then
        q.told = true
        if C.gear.tellwait ~= "0" then Say(q.name .. ": the rest goes on when combat ends.") end
        GR.Changed()
      end
      q.waiting = "combat"
      return
    end
    if pending then return end
    Finish(q)
  end

  -- ClassicAPI's cursor-free equip is there (C.gear.instant "0" = always the queue)
  function GR.Instant()
    return C_UnitAuras and C_Item and C_Item.EquipItemByName and C.gear.instant ~= "0" and true or nil
  end
  runner:SetScript("OnUpdate", function()
    this.t = (this.t or 0) + arg1
    if this.t < .1 then return end
    this.t = 0
    GR.Tick()
  end)

  -- put on these slots (name for messages)
  function GR.Wear(name, slots)
    local order = {}
    for _, s in ipairs(GR.SLOTS) do
      if slots[GR.Key(s[1])] ~= nil then table.insert(order, s[1]) end
    end
    -- main hand before off hand (a two-hander), the rest by slot
    table.sort(order, function(a, b)
      local wa, wb = GR.WEAPON[a] and 0 or 1, GR.WEAPON[b] and 0 or 1
      if wa ~= wb then return wa < wb end
      return a < b
    end)
    refused = {}
    GR.queue = { name = name, slots = slots, order = order, tries = {}, skip = {}, auto = GR.autoSwap }
    runner:Show()
    GR.Tick()
  end

  function GR.Equip(name)
    local set = C.gear.sets[name]
    if not set then Say("no set called \"" .. tostring(name) .. "\".") return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") and C.gear.waitdead == "0" then Say("not while dead.") return end
    -- what is worn now in its slots, to put back with Unequip
    if C.gear.current ~= name then C.gear.before = GR.Snapshot(set.slots) end
    C.gear.current = name
    GR.Wear(name, set.slots)
  end

  -- take a set off: the gear worn before it went on
  function GR.Unequip(name)
    name = name or GR.Current() or C.gear.current
    local before = C.gear.before
    if not before or not next(before) then Say("nothing to go back to.") return end
    C.gear.current = nil
    C.gear.before = {}
    GR.Wear(name or "Unequip", before)
  end

  -- ---------------------------------------------------------------- birthday suit

  -- Everything worn goes into the bags (user, 24 Oct 2026: "birthday suit
  -- option that makes you naked putting all your gear in bags"). What was
  -- worn is kept as "before", so Take off (back to before) dresses you again.
  -- Armour waits for combat to end, as every swap.
  function GR.IsNaked()
    for _, s in ipairs(GR.SLOTS) do
      if GetInventoryItemLink("player", s[1]) then return false end
    end
    return true
  end
  function GR.Naked()
    local slots, n = {}, 0
    for _, s in ipairs(GR.SLOTS) do
      if GetInventoryItemLink("player", s[1]) then
        slots[GR.Key(s[1])] = "empty"
        n = n + 1
      end
    end
    if n == 0 then Say("nothing on to take off.") return end
    local free = FreeSlots()
    if free < n then Say("room in your bags for " .. free .. " of the " .. n .. " things you wear - the rest stays on.") end
    C.gear.before = GR.Snapshot()
    C.gear.current = nil
    GR.Wear("Birthday suit", slots)
  end
  -- the menu's entry: naked, or dressed again in what you had on
  function GR.ToggleNaked()
    if GR.IsNaked() and C.gear.before and next(C.gear.before) then GR.Unequip() else GR.Naked() end
  end

  -- "a" on and off, or between "a" and "b"
  function GR.Toggle(a, b)
    if GR.IsEquipped(a) then
      if b and C.gear.sets[b] then GR.Equip(b) else GR.Unequip(a) end
    else
      GR.Equip(a)
    end
  end

  -- a key binding (Bindings.xml PFGEAR1-10): the set given that key
  function GR.KeyPress(n)
    for name, set in pairs(C.gear.sets) do
      if tonumber(set.key or "") == n then
        if C.gear.keytoggle == "1" then GR.Toggle(name) else GR.Equip(name) end
        return
      end
    end
    Say("no set uses key " .. n .. " - pick one on the Gear page.")
  end

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:RegisterEvent("UNIT_INVENTORY_CHANGED")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  -- (ClassicAPI, 25 Oct 2026: one event per worn slot that changed, at once;
  -- a plain client never sends it)
  pcall(ev.RegisterEvent, ev, "PLAYER_EQUIPMENT_CHANGED")
  ev:SetScript("OnEvent", function()
    if event == "PLAYER_REGEN_ENABLED" and GR.queue then
      GR.queue.told = nil
      GR.queue.waiting = nil
      runner:Show()
      GR.Tick()
    elseif event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then
      return
    end
    GR.Changed()
  end)

  -- ---------------------------------------------------------------- keys for slot buttons

  -- Bindings.xml PFGEARSLOT1-19: use the item worn in that slot (user, 24
  -- Oct 2026: the slot buttons in the hover binding and the Key Map)
  function GR.UseSlot(inv)
    if GetInventoryItemLink("player", inv) then UseInventoryItem(inv) end
  end
  for _, s in ipairs(GR.SLOTS) do
    _G["BINDING_NAME_PFGEARSLOT" .. s[1]] = "Use worn: " .. s[3]
  end
  _G.BINDING_HEADER_PFGEARSLOT = "pfUI Octo: gear slot buttons"
  _G.BINDING_NAME_PFGEARNAKED = "Birthday suit (all gear into bags) / dress again"

  -- a gear button that works its slot: bindable by hovering it (pfUI's
  -- hover binding), its key shown small in the corner as on action buttons
  GR.bindables = {}
  function GR.Bindable(b, inv)
    b.pfBinding = "PFGEARSLOT" .. inv
    if not b.hotkey then
      b.hotkey = b:CreateFontString(nil, "OVERLAY")
      b.hotkey:SetFont(pfUI.font_default, 10, "OUTLINE")
      b.hotkey:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
      b.hotkey:SetJustifyH("RIGHT")
    end
    table.insert(GR.bindables, b)
    if pfUI.hoverbind and pfUI.hoverbind.AddButton then pfUI.hoverbind:AddButton(b) end
    GR.ShowKeys()
  end
  function GR.ShowKeys()
    for _, b in ipairs(GR.bindables) do
      local k = GetBindingKey(b.pfBinding)
      local t = k and GetBindingText and GetBindingText(k, "KEY_", 1) or k or ""
      t = string.gsub(t, "SHIFT%-", "s")
      t = string.gsub(t, "CTRL%-", "c")
      t = string.gsub(t, "ALT%-", "a")
      b.hotkey:SetText(t)
    end
  end
  local keyev = CreateFrame("Frame")
  keyev:RegisterEvent("UPDATE_BINDINGS")
  keyev:SetScript("OnEvent", function() GR.ShowKeys() end)

  -- macro names, as ItemRack's (only when no other addon has them)
  if not _G.EquipSet then _G.EquipSet = function(n) GR.Equip(n) end end
  if not _G.UnequipSet then _G.UnequipSet = function(n) GR.Unequip(n) end end
  if not _G.ToggleSet then _G.ToggleSet = function(a, b) GR.Toggle(a, b) end end
  if not _G.IsSetEquipped then _G.IsSetEquipped = function(n) return GR.IsEquipped(n) end end

  -- /gear
  _G.SLASH_PFGEAR1 = "/gear"
  _G.SlashCmdList.PFGEAR = function(msg)
    msg = msg or ""
    local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
    cmd = string.lower(cmd or "")
    if cmd == "equip" and rest ~= "" then GR.Equip(rest)
    elseif cmd == "unequip" then GR.Unequip(rest ~= "" and rest or nil)
    elseif cmd == "toggle" and rest ~= "" then
      local _, _, a, b = string.find(rest, "^(.-)%s*,%s*(.+)$")
      if a then GR.Toggle(a, b) else GR.Toggle(rest) end
    elseif cmd == "naked" then GR.ToggleNaked()
    elseif cmd == "list" then
      local names = GR.Sets()
      Say(table.getn(names) == 0 and "no sets yet." or table.concat(names, ", "))
    elseif cmd == "dump" then
      -- what a set holds, slot by slot, beside what is worn (for bug reports)
      local name = rest ~= "" and rest or C.gear.current or GR.Sets()[1]
      local set = name and C.gear.sets[name]
      if not set then Say("no set to show.") return end
      Say("\"" .. name .. "\" icon " .. tostring(set.icon))
      for _, s in ipairs(GR.SLOTS) do
        local e = set.slots[GR.Key(s[1])]
        local worn = GR.Worn(s[1])
        local what = e == nil and "-" or e == "empty" and "take off" or
          (tostring(e.id) .. " \"" .. tostring(e.name) .. "\" tex=" .. tostring(e.tex))
        DEFAULT_CHAT_FRAME:AddMessage("  " .. s[3] .. ": " .. what .. "  |cff999999worn " .. tostring(worn)
          .. " tex=" .. tostring(GetInventoryItemTexture("player", s[1])) .. "|r")
      end
    elseif cmd == "save" and rest ~= "" then
      GR.Save(rest, GR.Snapshot())
      Say("saved \"" .. rest .. "\" from what you wear.")
    elseif pfUI.gearOcto and pfUI.gearOcto.Open then
      pfUI.gearOcto.Open()
    else
      Say("/gear equip <set>, /gear unequip, /gear toggle <set>[, <set>], /gear save <set>, /gear list")
    end
  end

  _G.BINDING_HEADER_PFGEAR = "pfUI Octo: gear sets"

  -- ---------------------------------------------------------------- set button and menu

  local K = { bg = { .06, .06, .08, .95 }, line = { .2, .2, .24, 1 } }
  local function Accent()
    if GetAccentColor then return GetAccentColor() end
    return .2, .55, .9
  end
  local function Flat(f, a)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(K.bg[1], K.bg[2], K.bg[3], a or K.bg[4])
    f:SetBackdropBorderColor(K.line[1], K.line[2], K.line[3], 1)
  end

  -- the menu of sets (for the set button and the minimap button)
  local menu = CreateFrame("Frame", "pfGearMenu", UIParent)
  menu:SetFrameStrata("DIALOG")
  menu:EnableMouse(true)
  Flat(menu)
  menu:Hide()
  menu.rows = {}
  GR.menu = menu
  local function Row(i)
    local r = menu.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, menu)
    r:SetHeight(24)
    r:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * 26)
    r:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, -4 - (i - 1) * 26)
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetAllPoints(r)
    r.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetWidth(20)
    r.icon:SetHeight(20)
    r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
    r.icon:SetTexCoord(.07, .93, .07, .93)
    r.text = r:CreateFontString(nil, "OVERLAY")
    r.text:SetFont(pfUI.font_default, 12, "OUTLINE")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.text:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    r.text:SetJustifyH("LEFT")
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function()
      menu:Hide()
      if this.action then this.action() end
    end)
    r:SetScript("OnEnter", function() if not this.on then this.hl:SetVertexColor(1, 1, 1, .08) end end)
    r:SetScript("OnLeave", function() if not this.on then this.hl:SetVertexColor(0, 0, 0, 0) end end)
    menu.rows[i] = r
    return r
  end
  function GR.ShowMenu(owner)
    if menu:IsShown() and menu.owner == owner then menu:Hide() return end
    menu.owner = owner
    local ar, ag, ab = Accent()
    local cur = GR.Current()
    local list = {}
    for _, name in ipairs(GR.Sets()) do
      local n = name
      table.insert(list, { text = n, icon = C.gear.sets[n].icon, on = (n == cur), action = function() GR.Equip(n) end })
    end
    if cur or (C.gear.before and next(C.gear.before)) then
      table.insert(list, { text = "Take off (back to before)", icon = "Interface\\Icons\\Spell_ChargeNegative", action = function() GR.Unequip() end })
    end
    -- (naked: the entry dresses you again)
    if GR.IsNaked() and C.gear.before and next(C.gear.before) then
      table.insert(list, { text = "Dress again", icon = "Interface\\Icons\\INV_Chest_Cloth_01", action = function() GR.ToggleNaked() end })
    else
      table.insert(list, { text = "Birthday suit (all into bags)", icon = "Interface\\Icons\\Ability_Rogue_Disguise", action = function() GR.Naked() end })
    end
    table.insert(list, { text = "Gear options...", icon = "Interface\\Icons\\INV_Misc_Gear_01", action = function()
      if pfUI.gearOcto and pfUI.gearOcto.Open then pfUI.gearOcto.Open() end
    end })
    for i, e in ipairs(list) do
      local r = Row(i)
      r.icon:SetTexture(e.icon)
      r.text:SetText(e.text)
      r.action = e.action
      r.on = e.on
      if e.on then
        r.hl:SetVertexColor(ar, ag, ab, .35)
        r.text:SetTextColor(1, 1, 1)
      else
        r.hl:SetVertexColor(0, 0, 0, 0)
        r.text:SetTextColor(.85, .85, .85)
      end
      r:Show()
    end
    for i = table.getn(list) + 1, table.getn(menu.rows) do menu.rows[i]:Hide() end
    menu:SetWidth(220)
    menu:SetHeight(table.getn(list) * 26 + 6)
    menu:ClearAllPoints()
    -- open towards the middle of the screen
    local _, y = owner:GetCenter()
    if y and y > (GetScreenHeight() / 2) then
      menu:SetPoint("TOP", owner, "BOTTOM", 0, -4)
    else
      menu:SetPoint("BOTTOM", owner, "TOP", 0, 4)
    end
    menu:Show()
  end
  -- (a click anywhere else closes it)
  menu:SetScript("OnUpdate", function()
    if not MouseIsOver(this) and not (this.owner and MouseIsOver(this.owner)) then
      this.away = (this.away or 0) + arg1
      if this.away > 1.5 then this:Hide() end
    else
      this.away = 0
    end
  end)

  local function Clicks(b)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function()
      if arg1 == "RightButton" then
        if pfUI.gearOcto and pfUI.gearOcto.Open then pfUI.gearOcto.Open() end
      elseif IsShiftKeyDown() then
        GR.Unequip()
      else
        GR.ShowMenu(this)
      end
    end)
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_LEFT")
      GameTooltip:AddLine("Gear sets")
      local cur = GR.Current()
      GameTooltip:AddLine(cur and ("Wearing: " .. cur) or "Wearing: no saved set", 1, 1, 1)
      if GR.queue and GR.queue.waiting then GameTooltip:AddLine(GR.WaitText(), 1, .8, .2) end
      GameTooltip:AddLine("Click: your sets", .7, .7, .7)
      GameTooltip:AddLine("Shift + click: back to the gear worn before", .7, .7, .7)
      GameTooltip:AddLine("Right-click: gear options", .7, .7, .7)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  -- the set button: the set worn now, movable in layout mode
  local btn = CreateFrame("Button", "pfGearButton", UIParent)
  btn:SetFrameStrata("MEDIUM")
  btn:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -240, 180)
  Flat(btn, .9)
  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
  btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
  btn.icon:SetTexCoord(.07, .93, .07, .93)
  btn.label = btn:CreateFontString(nil, "OVERLAY")
  btn.label:SetFont(pfUI.font_default, 11, "OUTLINE")
  btn.label:SetPoint("TOP", btn, "BOTTOM", 0, -3)
  btn.wait = btn:CreateTexture(nil, "OVERLAY")
  btn.wait:SetTexture("Interface\\Buttons\\WHITE8X8")
  btn.wait:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 2)
  btn.wait:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
  btn.wait:SetHeight(3)
  btn.wait:SetVertexColor(1, .75, .1, 1)
  Clicks(btn)
  GR.button = btn

  -- the minimap button (pfUI's addon button bar takes it in like any other, 29 Oct 2026)
  local mm = CreateFrame("Button", "pfGearMinimapButton", Minimap)
  mm:SetWidth(26)
  mm:SetHeight(26)
  mm:SetFrameStrata("MEDIUM")
  mm:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
  mm.icon = mm:CreateTexture(nil, "ARTWORK")
  mm.icon:SetAllPoints(mm)
  mm.icon:SetTexture("Interface\\Icons\\INV_Chest_Plate06")
  mm.icon:SetTexCoord(.07, .93, .07, .93)
  mm:RegisterForDrag("LeftButton")
  mm:SetScript("OnDragStart", function() this.dragging = true end)
  mm:SetScript("OnDragStop", function() this.dragging = nil end)
  mm:SetScript("OnUpdate", function()
    if not this.dragging then return end
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local s = Minimap:GetEffectiveScale()
    C.gear.mmangle = tostring(math.floor(math.deg(math.atan2(cy / s - my, cx / s - mx))))
    GR.PlaceMinimap()
  end)
  Clicks(mm)
  GR.minimap = mm
  function GR.PlaceMinimap()
    -- (in the addon button bar: it places it there)
    if mm:GetParent() ~= Minimap then return end
    local a = math.rad(tonumber(C.gear.mmangle) or 200)
    local r = (Minimap:GetWidth() or 140) / 2 + 6
    mm:ClearAllPoints()
    mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
  end

  function GR.UpdateButtons()
    local size = tonumber(C.gear.size) or 36
    btn:SetWidth(size)
    btn:SetHeight(size)
    local cur, partly = GR.Current()
    local set = cur and C.gear.sets[cur]
    btn.icon:SetTexture(set and set.icon or "Interface\\Icons\\INV_Chest_Plate06")
    btn.icon:SetDesaturated(set == nil)
    btn.label:SetText(C.gear.showname ~= "0" and (cur and (partly and (cur .. " |cffaaaaaa(part)|r") or cur) or "No set") or "")
    local ar, ag, ab = Accent()
    if partly then ar, ag, ab = ar * .55, ag * .55, ab * .55 end
    if set then btn:SetBackdropBorderColor(ar, ag, ab, 1) else btn:SetBackdropBorderColor(K.line[1], K.line[2], K.line[3], 1) end
    if GR.queue and GR.queue.waiting then btn.wait:Show() else btn.wait:Hide() end
    if C.gear.button == "0" then btn:Hide() else btn:Show() end
    if C.gear.minimap == "0" then mm:Hide() else mm:Show() GR.PlaceMinimap() end
    if set then mm.icon:SetTexture(set.icon) end
  end
  GR.listeners.buttons = GR.UpdateButtons

  if UpdateMovable then UpdateMovable(btn) end
  GR.Changed()
end)
