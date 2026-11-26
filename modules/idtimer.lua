pfUI:RegisterModule("idtimer", "vanilla:tbc", function ()
  -- pfUI Octo :: ID Timer (26 Nov 2026). The user's own IDTimer add-on (bdot1, idtimer.zip, v1.0.0) built in: "add this in
  -- as optional loads the first time resetting give them easy to see tab to enable it works exactly the same just give it
  -- our layout". Its engine (core.lua) is here unchanged but for how it starts; its window and minimap button (ui.lua) are
  -- drawn in the Octo look. Its data lives in pfUI_cache.idtimer (account-wide, as IDTimerDB);
  -- while the separate idtimer add-on is loaded this copy stands aside.
  --   off (as it comes): nothing runs but one CHAT_MSG_SYSTEM listener - the first "<instance> has been reset." asks once
  --   whether to switch it on (C.idtimer.asked); yes starts it at once, no reload. Switch: Quality of Life > ID Timer.
  C.idtimer = C.idtimer or {}
  local IT = {}
  pfUI.idtimer = IT

  function IT.Other()
    return IsAddOnLoaded("idtimer") or IsAddOnLoaded("IDTimer")
  end
  function IT.On() return C.idtimer.on == "1" end

  local started
  function IT.Start()
    if started or IT.Other() then return end
    started = true
    IT.Engine()
  end
  function IT.Enable()
    C.idtimer.on = "1"
    C.idtimer.asked = "1"
    IT.Start()
    if _G.IDTimer and _G.IDTimer.Show then _G.IDTimer.Show() end
  end
  -- off again: its frames go away (the engine stays loaded until the next reload, doing nothing visible)
  function IT.Disable()
    C.idtimer.on = "0"
    if _G.IDTimerFrame then _G.IDTimerFrame:Hide() end
    if _G.IDTimerMinimapButton then _G.IDTimerMinimapButton:Hide() end
    if _G.IDTimer then _G.IDTimer:UnregisterAllEvents() _G.IDTimer:SetScript("OnUpdate", nil) end
    started = "off"
  end

  -- ---------------------------------------------------------------- off: ask once, at the first instance reset
  StaticPopupDialogs["PFUI_IDTIMER_ASK"] = {
    text = "You just reset an instance.\n\nThe server lets you into 5 different instances an hour. pfUI Octo's |cff33ff99ID|r Timer can count them for you, with a countdown to each free slot (and your saved raid IDs).\n\nSwitch it on?",
    button1 = YES, button2 = NO, timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnAccept = function() IT.Enable() end,
    OnCancel = function()
      C.idtimer.asked = "1"
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: ID Timer stays off. Switch it on any time: Quality of Life > ID Timer, or type /idt.")
    end,
  }
  local RESET_ASK = INSTANCE_RESET_SUCCESS and ("^" .. string.gsub(string.gsub(INSTANCE_RESET_SUCCESS,
    "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"), "%%s", "(.+)")) or "^(.+) has been reset"
  local ask = CreateFrame("Frame")
  ask:RegisterEvent("CHAT_MSG_SYSTEM")
  ask:SetScript("OnEvent", function()
    if IT.On() or C.idtimer.asked == "1" or IT.Other() or not arg1 then return end
    if string.find(arg1, RESET_ASK) then StaticPopup_Show("PFUI_IDTIMER_ASK") end
  end)
  -- /idt before it is on: switches it on (typing the command is asking for it)
  if not IT.Other() then
    _G.SLASH_IDTIMER1 = "/idt"
    _G.SLASH_IDTIMER2 = "/idtimer"
    _G.SlashCmdList["IDTIMER"] = function() IT.Enable() end
  end

  -- ---------------------------------------------------------------- the engine (IDTimer's core.lua) and its window
  function IT.Engine()

--[[---------------------------------------------------------------------
  IDTimer - instance ID / hourly lockout tracker
  Client: WoW 1.12 (Turtle WoW 1.18.x) - Lua 5.0, no '#' and no '%' operator.

  Tracks the rolling "5 instances per hour" account-wide limit and the
  saved instance IDs (raids / saved 5-mans) of every character you play.
-----------------------------------------------------------------------]]

_G.IDTimer = CreateFrame("Frame", "IDTimerCore")
local IDT = _G.IDTimer

IDT.VERSION      = "1.0.0"
IDT.MAX_PER_HOUR = 5
IDT.WINDOW       = 3600      -- rolling window, seconds

local floor = math.floor
local getn  = table.getn
local tinsert, tremove, tsort = table.insert, table.remove, table.sort

----------------------------------------------------------------------
-- defaults / saved variables
----------------------------------------------------------------------

local defaults = {
  entries     = {},   -- { { zone, char, t, re } }  oldest first
  resets      = {},   -- [zone] = time() of last observed manual reset
  savedByChar = {},   -- ["Name - Realm"] = { { name, id, expires }, ... }

  announce    = true,
  sound       = true,
  autoshow    = true,
  showsaved   = true,
  locked      = false,
  scale       = 1.0,
  shown       = true,
  minimap     = true,
  mmangle     = 205,
  pos         = { "CENTER", "CENTER", 220, 60 },
}

local function CopyDefaults(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      CopyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------

function IDT.Print(msg, r, g, b)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ID|cffffffffTimer|r  " .. msg, r, g, b)
end

-- mm:ss / h:mm:ss  (Lua 5.0 has no '%' operator)
function IDT.FormatTime(s)
  if not s or s < 0 then s = 0 end
  s = floor(s)
  local h = floor(s / 3600)
  local m = floor((s - h * 3600) / 60)
  local sec = s - h * 3600 - m * 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, sec) end
  return string.format("%d:%02d", m, sec)
end

-- 4d 3h / 3h 12m / 41m
function IDT.FormatLong(s)
  if not s or s < 0 then s = 0 end
  s = floor(s)
  local d = floor(s / 86400)
  local h = floor((s - d * 86400) / 3600)
  local m = floor((s - d * 86400 - h * 3600) / 60)
  if d > 0 then return d .. "d " .. h .. "h" end
  if h > 0 then return h .. "h " .. m .. "m" end
  return m .. "m"
end

-- red while the slot is stuck, green once it is about to free up
function IDT.TimeColor(remaining)
  if remaining <= 300 then return 0.20, 1.00, 0.20 end
  if remaining <= 900 then return 1.00, 0.82, 0.00 end
  return 1.00, 0.35, 0.30
end

function IDT.CharKey()
  local realm = GetRealmName and GetRealmName() or "Turtle WoW"
  return (UnitName("player") or "?") .. " - " .. (realm or "?")
end

-- turn a global format string ("%s has been reset.") into a lua pattern
local function ToPattern(fmt, fallback)
  if type(fmt) ~= "string" then return fallback end
  local p = string.gsub(fmt, "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
  p = string.gsub(p, "%%s", "(.+)")
  p = string.gsub(p, "%%d", "(%%d+)")
  return "^" .. p
end

local RESET_PATTERN = ToPattern(INSTANCE_RESET_SUCCESS, "^(.+) has been reset")

----------------------------------------------------------------------
-- instance state
----------------------------------------------------------------------

local function InstanceState()
  local zone = GetRealZoneText()
  if not zone or zone == "" then zone = GetZoneText() end
  local inside, itype
  if IsInInstance then inside, itype = IsInInstance() end
  itype = itype or "none"
  -- battlegrounds do not consume the hourly limit
  if itype == "pvp" or itype == "arena" then inside = nil end
  return (inside and true or false), itype, zone
end
IDT.InstanceState = InstanceState

----------------------------------------------------------------------
-- lockout book keeping
----------------------------------------------------------------------

local function SortEntries()
  tsort(IDT.db.entries, function(a, b) return (a.t or 0) < (b.t or 0) end)
end

-- drop entries older than the window, announce the freed slots
function IDT.Purge(silent)
  if not IDT.db then return 0 end
  local now, kept, freed = time(), {}, 0
  local n = getn(IDT.db.entries)
  for i = 1, n do
    local e = IDT.db.entries[i]
    if e and e.t and (now - e.t) < IDT.WINDOW then
      tinsert(kept, e)
    else
      freed = freed + 1
      if not silent and IDT.db.announce and e then
        IDT.Print("|cffffd200" .. (e.zone or "?") .. "|r expired - slot free.", 0.4, 1, 0.4)
      end
    end
  end
  IDT.db.entries = kept
  if freed > 0 and not silent then
    if IDT.db.announce then
      IDT.Print(IDT.Free() .. " of " .. IDT.MAX_PER_HOUR .. " slots available.", 0.4, 1, 0.4)
    end
    if IDT.db.sound then PlaySound("TellMessage") end
    IDT.Refresh()
  end
  return freed
end

function IDT.Count()
  if not IDT.db then return 0 end
  return getn(IDT.db.entries)
end

function IDT.Free()
  local f = IDT.MAX_PER_HOUR - IDT.Count()
  if f < 0 then f = 0 end
  return f
end

-- seconds until the oldest entry drops off (nil when nothing is tracked)
function IDT.NextFree()
  local e = IDT.db.entries[1]
  if not e then return nil end
  local left = IDT.WINDOW - (time() - e.t)
  if left < 0 then left = 0 end
  return left
end

-- newest live entry for a zone
function IDT.FindZone(zone)
  local best, bestIdx
  for i = 1, getn(IDT.db.entries) do
    local e = IDT.db.entries[i]
    if e.zone == zone and (not best or e.t > best.t) then best, bestIdx = e, i end
  end
  return best, bestIdx
end

function IDT.AddEntry(zone, char, stamp)
  local e = { zone = zone, char = char or IDT.CharKey(), t = stamp or time(), re = 0 }
  tinsert(IDT.db.entries, e)
  SortEntries()
  IDT.db.resets[zone] = nil
  IDT.Refresh()
  return e
end

function IDT.RemoveEntry(idx)
  local e = IDT.db.entries[idx]
  if not e then return nil end
  tremove(IDT.db.entries, idx)
  IDT.Refresh()
  return e
end

function IDT.MarkReset(zone)
  if not IDT.db then return end
  IDT.db.resets[zone] = time()
  if IDT.FindZone(zone) and IDT.db.announce then
    IDT.Print("|cffffd200" .. zone .. "|r was reset - walking back in costs a new slot.")
  end
end

----------------------------------------------------------------------
-- entering an instance
--
-- The server counts *unique instance IDs* entered in the last hour, so
-- walking back into the instance you are already inside (corpse run,
-- vendor trip, /reload, relog) costs nothing - unless it was reset.
----------------------------------------------------------------------

function IDT.OnEnterInstance(zone, quiet)
  IDT.Purge(true)

  local live = IDT.FindZone(zone)
  local resetAt = IDT.db.resets[zone]
  if live and (not resetAt or resetAt <= live.t) then
    live.re = (live.re or 0) + 1
    IDT.Refresh()
    if not quiet and IDT.db.announce then
      local left = IDT.WINDOW - (time() - live.t)
      IDT.Print("back in |cffffd200" .. zone .. "|r - same ID, no new slot used (frees in "
        .. IDT.FormatTime(left) .. ").")
      IDT.Print("|cff888888was it a fresh instance? type /idt add|r")
    end
    return false
  end

  IDT.AddEntry(zone)
  local used, nextFree = IDT.Count(), IDT.NextFree()

  if IDT.db.announce then
    local line = "|cffffd200" .. zone .. "|r  -  " .. used .. "/" .. IDT.MAX_PER_HOUR .. " used this hour"
    if nextFree then line = line .. ", next slot in " .. IDT.FormatTime(nextFree) end
    if used >= IDT.MAX_PER_HOUR then
      IDT.Print(line .. ".", 1, 0.3, 0.3)
      IDT.Print("|cffff2020hourly cap reached|r - no new instance for " .. IDT.FormatTime(nextFree or 0) .. ".", 1, 0.3, 0.3)
      if IDT.db.sound then PlaySound("RaidWarning") end
    elseif used == IDT.MAX_PER_HOUR - 1 then
      IDT.Print(line .. ".", 1, 0.82, 0)
      IDT.Print("only |cffffd2001|r slot left this hour.", 1, 0.82, 0)
      if IDT.db.sound then PlaySound("igQuestFailed") end
    else
      IDT.Print(line .. ".")
    end
  end

  if IDT.db.autoshow then IDT.Show() end
  return true
end

function IDT.CheckZone()
  if not IDT.db then return end
  local inside, itype, zone = InstanceState()

  if inside and zone and zone ~= "" then
    -- db.inside survives /reload and relog, so neither is mistaken for
    -- walking back through the portal
    local cur = IDT.db.inside
    if cur and cur.zone == zone and (time() - (cur.seen or 0)) < 300 then
      cur.seen = time()          -- same stay, nothing to do
    else
      IDT.db.inside = { zone = zone, seen = time(), itype = itype }
      IDT.OnEnterInstance(zone)
    end
  else
    IDT.db.inside = nil
  end
  IDT.Refresh()
end

-- run IDT.CheckZone() in <delay> seconds (zone text lags behind the event)
function IDT.ScheduleCheck(delay)
  IDT.checkAt = GetTime() + (delay or 1.5)
end

----------------------------------------------------------------------
-- saved instance IDs (raids and saved 5-mans)
----------------------------------------------------------------------

function IDT.UpdateSaved()
  if not IDT.db or not GetNumSavedInstances then return end
  local key, list, now = IDT.CharKey(), {}, time()
  for i = 1, GetNumSavedInstances() do
    local name, id, reset = GetSavedInstanceInfo(i)
    if name and reset and reset > 0 then
      tinsert(list, { name = name, id = id, expires = now + reset })
    end
  end
  IDT.db.savedByChar[key] = list
  IDT.Refresh()
end

-- saved IDs of this character, expired ones dropped
function IDT.GetSaved()
  local out, now = {}, time()
  local list = IDT.db.savedByChar[IDT.CharKey()]
  if not list then return out end
  for i = 1, getn(list) do
    local s = list[i]
    if s.expires and s.expires > now then tinsert(out, s) end
  end
  tsort(out, function(a, b) return a.expires < b.expires end)
  return out
end

----------------------------------------------------------------------
-- chat output
----------------------------------------------------------------------

function IDT.Report(channel)
  IDT.Purge(true)
  local used, lines = IDT.Count(), {}
  local head = "Instances: " .. used .. "/" .. IDT.MAX_PER_HOUR .. " used this hour"
  local nf = IDT.NextFree()
  if nf then head = head .. " (next free in " .. IDT.FormatTime(nf) .. ")" end
  tinsert(lines, head)
  for i = 1, used do
    local e = IDT.db.entries[i]
    tinsert(lines, i .. ". " .. e.zone .. " - " .. IDT.FormatTime(IDT.WINDOW - (time() - e.t)))
  end
  if used == 0 then tinsert(lines, "no instance IDs on the clock.") end

  if channel then
    for i = 1, getn(lines) do SendChatMessage(lines[i], channel) end
  else
    for i = 1, getn(lines) do IDT.Print(lines[i]) end
  end
end

----------------------------------------------------------------------
-- events
----------------------------------------------------------------------

-- (pfUI: started from pfUI's module, after the saved variables are read - so no ADDON_LOADED wait)
local function Init()
  -- (pfUI: its own table in pfUI_cache, account-wide as IDTimerDB is - two add-ons saving one global would overwrite each
  -- other's file at login)
  pfUI_cache.idtimer = pfUI_cache.idtimer or {}
  CopyDefaults(pfUI_cache.idtimer, defaults)
  IDT.db = pfUI_cache.idtimer
  IDT.Purge(true)
  IDT.BuildUI()
  IDT.ScheduleCheck(2.0)
  if RequestRaidInfo then RequestRaidInfo() end
end

IDT:RegisterEvent("PLAYER_ENTERING_WORLD")
IDT:RegisterEvent("ZONE_CHANGED_NEW_AREA")
IDT:RegisterEvent("CHAT_MSG_SYSTEM")
IDT:RegisterEvent("UPDATE_INSTANCE_INFO")

IDT:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" then
    IDT.ScheduleCheck(2.0)
    if RequestRaidInfo then RequestRaidInfo() end

  elseif event == "ZONE_CHANGED_NEW_AREA" then
    IDT.ScheduleCheck(1.0)

  elseif event == "UPDATE_INSTANCE_INFO" then
    IDT.UpdateSaved()

  elseif event == "CHAT_MSG_SYSTEM" and arg1 then
    local _, _, zone = string.find(arg1, RESET_PATTERN)
    if zone then IDT.MarkReset(zone) end
    if string.find(string.lower(arg1), "too many instances") then
      IDT.Purge(true)
      local nf = IDT.NextFree()
      IDT.Print("|cffff2020entry refused by the server|r - " .. IDT.Count() .. "/" .. IDT.MAX_PER_HOUR
        .. " used, next slot in " .. IDT.FormatTime(nf or 0) .. ".", 1, 0.3, 0.3)
      if IDT.db.sound then PlaySound("RaidWarning") end
      IDT.Show()
    end
  end
end)

-- one ticker drives the delayed zone check, the purge and the UI clock
local fast, slow = 0, 0
IDT:SetScript("OnUpdate", function()
  if IDT.checkAt and GetTime() >= IDT.checkAt then
    IDT.checkAt = nil
    IDT.CheckZone()
  end
  if not IDT.db then return end

  fast = fast + arg1
  if fast < 0.2 then return end
  fast = 0
  IDT.Tick()

  slow = slow + 0.2
  if slow >= 1 then
    slow = 0
    IDT.Purge()
    if IDT.db.inside then IDT.db.inside.seen = time() end
  end
end)

----------------------------------------------------------------------
-- slash commands
----------------------------------------------------------------------

local function Help()
  local c = {
    "|cffffd200/idt|r  toggle the window",
    "|cffffd200/idt list|r  print lockouts to chat",
    "|cffffd200/idt add [zone]|r  add a lockout by hand (current zone if omitted)",
    "|cffffd200/idt del <n>|r  remove lockout number n",
    "|cffffd200/idt clear|r  wipe all tracked lockouts",
    "|cffffd200/idt report [party/raid/guild/say]|r  post your timers",
    "|cffffd200/idt saved|r  saved raid IDs of all your characters",
    "|cffffd200/idt ids|r  show/hide the saved ID section",
    "|cffffd200/idt lock|r  lock or unlock the window",
    "|cffffd200/idt scale <0.5-2>|r  window scale",
    "|cffffd200/idt announce|r  chat messages on/off",
    "|cffffd200/idt sound|r  warning sounds on/off",
    "|cffffd200/idt autoshow|r  auto-open on entry on/off",
    "|cffffd200/idt minimap|r  minimap button on/off",
    "|cffffd200/idt reset|r  reset window position and scale",
  }
  IDT.Print("commands:")
  for i = 1, getn(c) do IDT.Print("  " .. c[i]) end
end

_G.SLASH_IDTIMER1 = "/idt"
_G.SLASH_IDTIMER2 = "/idtimer"
_G.SlashCmdList["IDTIMER"] = function(msg)
  msg = msg or ""
  local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
  cmd = string.lower(cmd or "")
  rest = rest or ""

  if cmd == "" then
    IDT.Toggle()

  elseif cmd == "list" then
    IDT.Report()

  elseif cmd == "add" then
    local zone = rest
    if zone == "" then
      local _, _, z = InstanceState()
      zone = z
    end
    if not zone or zone == "" then
      IDT.Print("could not read a zone name - try |cffffd200/idt add Scarlet Monastery|r.")
    elseif IDT.Count() >= IDT.MAX_PER_HOUR then
      IDT.Print("already tracking " .. IDT.MAX_PER_HOUR .. " lockouts - remove one first.", 1, 0.3, 0.3)
    else
      IDT.AddEntry(zone)
      IDT.Print("added |cffffd200" .. zone .. "|r  (" .. IDT.Count() .. "/" .. IDT.MAX_PER_HOUR .. ").")
      IDT.Show()
    end

  elseif cmd == "del" or cmd == "rem" or cmd == "remove" then
    local n = tonumber(rest)
    local e = n and IDT.RemoveEntry(n)
    if e then
      IDT.Print("removed |cffffd200" .. e.zone .. "|r  (" .. IDT.Count() .. "/" .. IDT.MAX_PER_HOUR .. ").")
    else
      IDT.Print("usage: |cffffd200/idt del <number>|r  - see /idt list")
    end

  elseif cmd == "clear" then
    IDT.db.entries = {}
    IDT.db.resets = {}
    IDT.Refresh()
    IDT.Print("all lockouts cleared.")

  elseif cmd == "report" then
    local ch = "PARTY"
    if rest ~= "" then ch = string.upper(rest) end
    IDT.Report(ch)

  elseif cmd == "saved" then
    if RequestRaidInfo then RequestRaidInfo() end
    IDT.UpdateSaved()
    local any, now = false, time()
    for key, list in pairs(IDT.db.savedByChar) do
      local shown = false
      for i = 1, getn(list) do
        local s = list[i]
        if s.expires > now then
          if not shown then IDT.Print("|cff33ff99" .. key .. "|r"); shown = true; any = true end
          IDT.Print("   " .. s.name .. " |cff888888(id " .. (s.id or "?") .. ")|r - resets in "
            .. IDT.FormatLong(s.expires - now))
        end
      end
    end
    if not any then IDT.Print("no saved instance IDs on any character.") end

  elseif cmd == "ids" then
    IDT.db.showsaved = not IDT.db.showsaved
    IDT.Refresh()
    IDT.Print("saved ID section " .. (IDT.db.showsaved and "shown." or "hidden."))

  elseif cmd == "lock" then
    IDT.db.locked = not IDT.db.locked
    IDT.Print("window " .. (IDT.db.locked and "locked." or "unlocked."))

  elseif cmd == "scale" then
    local s = tonumber(rest)
    if s and s >= 0.5 and s <= 2 then
      IDT.db.scale = s
      IDT.ApplyScale()
      IDT.Print("scale set to " .. s .. ".")
    else
      IDT.Print("usage: |cffffd200/idt scale 1.0|r  (0.5 - 2.0)")
    end

  elseif cmd == "announce" then
    IDT.db.announce = not IDT.db.announce
    IDT.Print("chat messages " .. (IDT.db.announce and "on." or "off."))

  elseif cmd == "sound" then
    IDT.db.sound = not IDT.db.sound
    IDT.Print("warning sounds " .. (IDT.db.sound and "on." or "off."))

  elseif cmd == "autoshow" then
    IDT.db.autoshow = not IDT.db.autoshow
    IDT.Print("auto-open on entry " .. (IDT.db.autoshow and "on." or "off."))

  elseif cmd == "minimap" then
    IDT.db.minimap = not IDT.db.minimap
    IDT.UpdateMinimap()
    IDT.Print("minimap button " .. (IDT.db.minimap and "shown." or "hidden."))

  elseif cmd == "reset" then
    IDT.db.pos = { "CENTER", "CENTER", 220, 60 }
    IDT.db.scale = 1.0
    IDT.ApplyScale()
    IDT.RestorePosition()
    IDT.Print("window position and scale reset.")

  else
    Help()
  end
end

IT.UI(IDT)
Init()
  end

  -- ---------------------------------------------------------------- the window (IDTimer's ui.lua in the Octo look)
  function IT.UI(IDT)
    local getn = table.getn
    local W = pfUI.octoui and pfUI.octoui.W
    local P = W and W.C or { bg = { .067, .071, .078 }, line = { .23, .24, .27 }, text = { .92, .92, .93 }, dim = { .6, .61, .65 } }
    local WHITE = "Interface\\Buttons\\WHITE8X8"
    local FONTS = "Interface\\AddOns\\pfUI\\fonts\\"
    local WIDTH, ROW_H, PAD = 246, 18, 10
    local BAR_TEX = (pfUI.media and pfUI.media["img:bar"]) or "Interface\\TargetingFrame\\UI-StatusBar"
    local ICON = "Interface\\Icons\\INV_Misc_PocketWatch_01"
    local frame, rows, savedRows, mmButton

    local function Font(fs, size, face)
      fs:SetFont(face or (W and W.UIFont and W.UIFont()) or STANDARD_TEXT_FONT, size or 11, "")
      fs:SetShadowOffset(1, -1)
      fs:SetShadowColor(0, 0, 0, .9)
      return fs
    end
    -- the Octo panel: flat near-black, a 1-pixel edge
    local function Backdrop(f)
      f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 } })
      f:SetBackdropColor(P.bg[1], P.bg[2], P.bg[3], .94)
      f:SetBackdropBorderColor(0, 0, 0, 1)
    end
    local function Label(parent, kind, justify)
      local fs = parent:CreateFontString(nil, "OVERLAY")
      local size = (kind == "big") and 13 or 11
      Font(fs, size, (kind == "big" or kind == "num") and (kind == "num" and FONTS .. "Expressway.ttf" or FONTS .. "FiraSansCondensed-SemiBold.ttf") or nil)
      if kind == "dim" then fs:SetTextColor(P.dim[1], P.dim[2], P.dim[3]) else fs:SetTextColor(P.text[1], P.text[2], P.text[3]) end
      fs:SetJustifyH(justify or "LEFT")
      return fs
    end
    local function Divider(parent)
      local t = parent:CreateTexture(nil, "ARTWORK")
      t:SetTexture(WHITE)
      t:SetHeight(1)
      t:SetVertexColor(P.line[1], P.line[2], P.line[3], 1)
      return t
    end

    -- lockout rows
    local function RowTooltip()
      local e = this.entry
      if not e then return end
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(e.zone, 1, 0.82, 0)
      local left = IDT.WINDOW - (time() - e.t)
      GameTooltip:AddLine("Slot frees in " .. IDT.FormatTime(left), 1, 1, 1)
      GameTooltip:AddLine("Entered " .. date("%H:%M:%S", e.t) .. " on " .. (e.char or "?"), 0.7, 0.7, 0.7)
      if e.re and e.re > 0 then
        GameTooltip:AddLine("Walked back in " .. e.re .. "x on the same ID", 0.7, 0.7, 0.7)
      end
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Right-click to remove this lockout", 0.4, 1, 0.4)
      GameTooltip:Show()
    end
    local function RowClick()
      if arg1 == "RightButton" and this.index then
        local e = IDT.RemoveEntry(this.index)
        if e then
          IDT.Print("removed |cffffd200" .. e.zone .. "|r  (" .. IDT.Count() .. "/" .. IDT.MAX_PER_HOUR .. ").")
        end
        GameTooltip:Hide()
      end
    end
    local function CreateRow(parent, index)
      local row = CreateFrame("Button", nil, parent)
      row:SetWidth(WIDTH - PAD * 2)
      row:SetHeight(ROW_H)
      row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      row.bar = CreateFrame("StatusBar", nil, row)
      row.bar:SetAllPoints(row)
      row.bar:SetStatusBarTexture(BAR_TEX)
      row.bar:SetMinMaxValues(0, 1)
      row.bar:SetValue(1)
      row.bar:SetAlpha(0.35)
      row.bg = row.bar:CreateTexture(nil, "BACKGROUND")
      row.bg:SetAllPoints(row)
      row.bg:SetTexture(WHITE)
      row.bg:SetVertexColor(1, 1, 1, 0.04)
      row.num = Label(row, "dim", "LEFT")
      row.num:SetPoint("LEFT", row, "LEFT", 3, 0)
      row.num:SetWidth(14)
      row.name = Label(row, nil, "LEFT")
      row.name:SetPoint("LEFT", row, "LEFT", 18, 0)
      row.name:SetWidth(WIDTH - PAD * 2 - 72)
      row.time = Label(row, "num", "RIGHT")
      row.time:SetPoint("RIGHT", row, "RIGHT", -4, 0)
      row:SetScript("OnEnter", RowTooltip)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
      row:SetScript("OnClick", RowClick)
      row.index = index
      return row
    end
    local function CreateSavedRow(parent)
      local row = CreateFrame("Frame", nil, parent)
      row:SetWidth(WIDTH - PAD * 2)
      row:SetHeight(ROW_H - 2)
      row.name = Label(row, nil, "LEFT")
      row.name:SetPoint("LEFT", row, "LEFT", 18, 0)
      row.name:SetWidth(WIDTH - PAD * 2 - 80)
      row.time = Label(row, "num", "RIGHT")
      row.time:SetPoint("RIGHT", row, "RIGHT", -4, 0)
      return row
    end

    function IDT.BuildUI()
      if frame then IDT.Refresh() return end
      frame = CreateFrame("Frame", "IDTimerFrame", UIParent)
      frame:SetWidth(WIDTH)
      frame:SetHeight(120)
      frame:SetFrameStrata("MEDIUM")
      frame:SetToplevel(true)
      frame:SetMovable(true)
      frame:EnableMouse(true)
      frame:RegisterForDrag("LeftButton")
      if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
      Backdrop(frame)
      -- the gold line along the top, as OctoRanks' timer
      frame.topline = frame:CreateTexture(nil, "ARTWORK")
      frame.topline:SetTexture(WHITE)
      frame.topline:SetHeight(2)
      frame.topline:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
      frame.topline:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
      frame.topline:SetGradientAlpha("HORIZONTAL", .2, 1, .6, .2, .2, 1, .6, .9)

      frame:SetScript("OnDragStart", function()
        if not IDT.db.locked then this:StartMoving() end
      end)
      frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local point, _, relPoint, x, y = this:GetPoint()
        IDT.db.pos = { point, relPoint, x, y }
      end)

      frame.icon = frame:CreateTexture(nil, "ARTWORK")
      frame.icon:SetTexture(ICON)
      frame.icon:SetTexCoord(.07, .93, .07, .93)
      frame.icon:SetWidth(14) frame.icon:SetHeight(14)
      frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD + 1)
      frame.title = Label(frame, "big", "LEFT")
      frame.title:SetPoint("LEFT", frame.icon, "RIGHT", 6, 0)
      frame.title:SetText("|cff33ff99ID|r Timer")

      frame.count = Label(frame, "big", "RIGHT")
      frame.count:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -PAD + 1)

      frame.close = CreateFrame("Button", nil, frame)
      frame.close:SetWidth(16) frame.close:SetHeight(16)
      frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
      frame.close.text = Label(frame.close, "dim", "CENTER")
      frame.close.text:SetPoint("CENTER", frame.close, "CENTER", 0, 1)
      frame.close.text:SetText("x")
      frame.close:SetScript("OnEnter", function() this.text:SetTextColor(1, .4, .4) end)
      frame.close:SetScript("OnLeave", function() this.text:SetTextColor(P.dim[1], P.dim[2], P.dim[3]) end)
      frame.close:SetScript("OnClick", function() IDT.Hide() end)

      frame.status = Label(frame, "dim", "LEFT")
      frame.status:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -27)
      frame.status:SetWidth(WIDTH - PAD * 2)

      frame.line = Divider(frame)
      frame.line:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -40)
      frame.line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -40)

      rows = {}
      for i = 1, IDT.MAX_PER_HOUR do
        rows[i] = CreateRow(frame, i)
        if i == 1 then
          rows[i]:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -44)
        else
          rows[i]:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -1)
        end
        rows[i]:Hide()
      end

      frame.empty = Label(frame, "dim", "CENTER")
      frame.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -48)
      frame.empty:SetWidth(WIDTH - PAD * 2)
      frame.empty:SetText("no instance IDs on the clock")

      frame.savedLine = Divider(frame)
      frame.savedHeader = Label(frame, "big", "LEFT")
      frame.savedHeader:SetText("|cffffd200Saved IDs|r")

      savedRows = {}
      for i = 1, 12 do
        savedRows[i] = CreateSavedRow(frame)
        savedRows[i]:Hide()
      end

      frame.hint = Label(frame, "dim", "CENTER")
      frame.hint:SetWidth(WIDTH - PAD * 2)

      IDT.BuildMinimap()
      IDT.ApplyScale()
      IDT.RestorePosition()
      IDT.uiReady = true

      if IDT.db.shown then frame:Show() else frame:Hide() end
      IDT.Refresh()
    end

    function IDT.ApplyScale()
      if frame then frame:SetScale(IDT.db.scale or 1) end
    end
    function IDT.RestorePosition()
      if not frame then return end
      local p = IDT.db.pos
      frame:ClearAllPoints()
      frame:SetPoint(p[1] or "CENTER", UIParent, p[2] or "CENTER", p[3] or 0, p[4] or 0)
    end
    function IDT.Show()
      if not frame then return end
      IDT.db.shown = true
      frame:Show()
      IDT.Refresh()
    end
    function IDT.Hide()
      if not frame then return end
      IDT.db.shown = false
      frame:Hide()
    end
    function IDT.Toggle()
      if not frame then return end
      if frame:IsShown() then IDT.Hide() else IDT.Show() end
    end

    function IDT.Refresh()
      if not IDT.uiReady or not frame then return end
      local used = IDT.Count()
      local y = 44
      for i = 1, IDT.MAX_PER_HOUR do
        local e = IDT.db.entries[i]
        local row = rows[i]
        if e then
          row.entry = e
          row.index = i
          row.num:SetText(i .. ".")
          row.name:SetText(e.zone)
          row:ClearAllPoints()
          row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
          row:Show()
          y = y + ROW_H + 1
        else
          row.entry = nil
          row:Hide()
        end
      end
      if used == 0 then
        frame.empty:Show()
        frame.empty:ClearAllPoints()
        frame.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -48)
        y = y + 18
      else
        frame.empty:Hide()
      end
      local saved = IDT.GetSaved()
      local nSaved = getn(saved)
      if IDT.db.showsaved and nSaved > 0 then
        y = y + 4
        frame.savedLine:ClearAllPoints()
        frame.savedLine:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
        frame.savedLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -y)
        frame.savedLine:Show()
        y = y + 4
        frame.savedHeader:ClearAllPoints()
        frame.savedHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
        frame.savedHeader:Show()
        y = y + 16
        for i = 1, getn(savedRows) do
          local s = saved[i]
          local row = savedRows[i]
          if s then
            row.saved = s
            row.name:SetText(s.name)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
            row:Show()
            y = y + ROW_H - 2
          else
            row.saved = nil
            row:Hide()
          end
        end
      else
        frame.savedLine:Hide()
        frame.savedHeader:Hide()
        for i = 1, getn(savedRows) do savedRows[i]:Hide() end
      end
      if IDT.db.locked then
        frame.hint:Hide()
      else
        y = y + 2
        frame.hint:ClearAllPoints()
        frame.hint:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
        frame.hint:SetText("drag to move  -  right-click a row to remove")
        frame.hint:Show()
        y = y + 12
      end
      frame:SetHeight(y + PAD)
      IDT.Tick()
    end

    function IDT.Tick()
      if not IDT.uiReady or not frame then return end
      IDT.UpdateMinimapText()
      if not frame:IsShown() then return end
      local now = time()
      local used = IDT.Count()
      local free = IDT.Free()
      local cr, cg, cb = 0.2, 1, 0.2
      if free == 0 then cr, cg, cb = 1, 0.2, 0.2
      elseif free == 1 then cr, cg, cb = 1, 0.82, 0 end
      frame.count:SetText(used .. " / " .. IDT.MAX_PER_HOUR)
      frame.count:SetTextColor(cr, cg, cb)
      local nf = IDT.NextFree()
      if used == 0 then
        frame.status:SetText("|cff40ff40all " .. IDT.MAX_PER_HOUR .. " slots open|r")
      elseif free == 0 then
        frame.status:SetText("|cffff4040capped|r - next slot in |cffffffff" .. IDT.FormatTime(nf) .. "|r")
      else
        frame.status:SetText(free .. " free  -  next slot in |cffffffff" .. IDT.FormatTime(nf) .. "|r")
      end
      for i = 1, IDT.MAX_PER_HOUR do
        local row = rows[i]
        if row.entry then
          local left = IDT.WINDOW - (now - row.entry.t)
          if left < 0 then left = 0 end
          local r, g, b = IDT.TimeColor(left)
          row.time:SetText(IDT.FormatTime(left))
          row.time:SetTextColor(r, g, b)
          row.bar:SetValue(left / IDT.WINDOW)
          row.bar:SetStatusBarColor(r, g, b)
          if IDT.db.inside and IDT.db.inside.zone == row.entry.zone then
            row.name:SetTextColor(1, 1, 1)
          else
            row.name:SetTextColor(0.9, 0.85, 0.6)
          end
        end
      end
      for i = 1, getn(savedRows) do
        local row = savedRows[i]
        if row.saved and row:IsShown() then
          row.time:SetText(IDT.FormatLong(row.saved.expires - now))
          row.time:SetTextColor(0.6, 0.8, 1)
        end
      end
    end

    -- minimap button: the Octo badge with the watch and used/5 (pfUI's minimap button menu takes it like any add-on's)
    local function MinimapPosition()
      local angle = math.rad(IDT.db.mmangle or 205)
      local r = (Minimap:GetWidth() or 140) / 2 + 4
      mmButton:ClearAllPoints()
      mmButton:SetPoint("CENTER", Minimap, "CENTER", r * math.cos(angle), r * math.sin(angle))
    end
    local function MinimapDrag()
      if not this.dragging then return end
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      cx, cy = cx / s, cy / s
      IDT.db.mmangle = math.deg(math.atan2(cy - my, cx - mx))
      MinimapPosition()
    end
    local function MinimapTooltip()
      GameTooltip:SetOwner(this, "ANCHOR_LEFT")
      GameTooltip:AddLine("|cff33ff99ID|r Timer")
      local used = IDT.Count()
      GameTooltip:AddDoubleLine("Instances this hour", used .. " / " .. IDT.MAX_PER_HOUR, 1, 1, 1, 1, 0.82, 0)
      local nf = IDT.NextFree()
      if nf then GameTooltip:AddDoubleLine("Next slot", IDT.FormatTime(nf), 1, 1, 1, IDT.TimeColor(nf)) end
      for i = 1, used do
        local e = IDT.db.entries[i]
        local left = IDT.WINDOW - (time() - e.t)
        GameTooltip:AddDoubleLine(e.zone, IDT.FormatTime(left), 0.9, 0.85, 0.6, IDT.TimeColor(left))
      end
      local saved = IDT.GetSaved()
      if getn(saved) > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Saved IDs", 1, 0.82, 0)
        for i = 1, getn(saved) do
          GameTooltip:AddDoubleLine(saved[i].name, IDT.FormatLong(saved[i].expires - time()), 1, 1, 1, 0.6, 0.8, 1)
        end
      end
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Left-click: show / hide window", 0.4, 1, 0.4)
      GameTooltip:AddLine("Right-click: lock / unlock window", 0.4, 1, 0.4)
      GameTooltip:AddLine("Drag: move this button", 0.4, 1, 0.4)
      GameTooltip:Show()
    end
    function IDT.BuildMinimap()
      if mmButton then return end
      local BADGE = "Interface\\AddOns\\pfUI\\img\\transports\\"
      mmButton = CreateFrame("Button", "IDTimerMinimapButton", Minimap)
      mmButton:SetWidth(30) mmButton:SetHeight(30)
      mmButton:SetFrameStrata("MEDIUM")
      mmButton:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
      mmButton:SetMovable(true)
      mmButton:EnableMouse(true)
      mmButton:RegisterForDrag("LeftButton")
      mmButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      local bg = mmButton:CreateTexture(nil, "BACKGROUND")
      bg:SetTexture(BADGE .. "badge") bg:SetAllPoints(mmButton) bg:SetVertexColor(.06, .06, .07, .95)
      local icon = mmButton:CreateTexture(nil, "BORDER")
      icon:SetTexture(ICON)
      icon:SetTexCoord(.12, .88, .12, .88)
      icon:SetPoint("TOPLEFT", mmButton, "TOPLEFT", 5, -5)
      icon:SetPoint("BOTTOMRIGHT", mmButton, "BOTTOMRIGHT", -5, 5)
      icon:SetAlpha(.55)
      local ring = mmButton:CreateTexture(nil, "ARTWORK")
      ring:SetTexture(BADGE .. "ring") ring:SetAllPoints(mmButton) ring:SetVertexColor(.2, 1, .6, 1)
      mmButton.text = mmButton:CreateFontString(nil, "OVERLAY")
      Font(mmButton.text, 10, FONTS .. "Expressway.ttf")
      mmButton.text:SetPoint("CENTER", mmButton, "CENTER", 0, 0)
      mmButton:SetScript("OnEnter", MinimapTooltip)
      mmButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
      mmButton:SetScript("OnUpdate", MinimapDrag)
      mmButton:SetScript("OnDragStart", function() this.dragging = true end)
      mmButton:SetScript("OnDragStop", function() this.dragging = nil end)
      mmButton:SetScript("OnClick", function()
        if arg1 == "RightButton" then
          IDT.db.locked = not IDT.db.locked
          IDT.Print("window " .. (IDT.db.locked and "locked." or "unlocked."))
          IDT.Refresh()
        else
          IDT.Toggle()
        end
      end)
      MinimapPosition()
      IDT.UpdateMinimap()
    end
    function IDT.UpdateMinimap()
      if not mmButton then return end
      if IDT.db.minimap then mmButton:Show() else mmButton:Hide() end
      MinimapPosition()
    end
    function IDT.UpdateMinimapText()
      if not mmButton or not mmButton:IsShown() then return end
      local used, free = IDT.Count(), IDT.Free()
      local r, g, b = 0.2, 1, 0.2
      if free == 0 then r, g, b = 1, 0.2, 0.2
      elseif free == 1 then r, g, b = 1, 0.82, 0 end
      mmButton.text:SetText(used .. "/" .. IDT.MAX_PER_HOUR)
      mmButton.text:SetTextColor(r, g, b)
    end
  end

  if IT.On() then IT.Start() end
end)
