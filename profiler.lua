-- pfUI Octo :: /pfprof, how much time each part of pfUI takes (9 Nov 2026; user: "make it
-- run as fast and smooth as possible"). Measure first, then fix what really costs.
--
-- The game's own debugprofilestop() reads the CPU clock (milliseconds with a sub-microsecond
-- fraction, stock since 1.7). While the profiler is on (pfUI_cache.profile, set by /pfprof on
-- and a reload), every OnUpdate and OnEvent script pfUI gives a frame is timed, grouped by the
-- file and line that set it (OnEvent also by event); gcinfo() gives a rough count of the
-- memory each one makes (garbage = the hitches when the game cleans up).
--
-- Off (the normal case) it costs nothing after login: while pfUI's own files load, CreateFrame
-- notes the frames they make (pfUI's libraries make theirs then, before saved variables are
-- read); at pfUI's ADDON_LOADED the game's CreateFrame is put back and the list dropped.
pfUI.prof = { rows = {}, load = {}, done = {} }
local P = pfUI.prof
P.make = CreateFrame

local function Where()
  if type(debugstack) ~= "function" then return nil end
  local ok, s = pcall(debugstack)
  if not ok or type(s) ~= "string" then return nil end
  for file, line in string.gfind(s, "AddOns\\pfUI\\([^:\n]+):(%d+)") do
    if file ~= "profiler.lua" then return file .. ":" .. line end
  end
  return nil
end

-- the game's CreateFrame with exactly the arguments given (as pfquest\guard.lua)
local function Make(a1, a2, a3, a4)
  if a4 then return P.make(a1, a2, a3, a4) elseif a3 then return P.make(a1, a2, a3)
  elseif a2 then return P.make(a1, a2) end
  return P.make(a1)
end

-- while pfUI's files load: note each frame and where it was made
CreateFrame = function(a1, a2, a3, a4)
  local f = Make(a1, a2, a3, a4)
  if P.load then table.insert(P.load, { f, Where() }) end
  return f
end

local clock = debugprofilestop
local gc = gcinfo

local function Row(where, script)
  local key = (where or "?") .. " " .. script
  local r = P.rows[key]
  if not r then
    r = { where = where or "?", script = script, n = 0, ms = 0, max = 0, kb = 0, ev = {} }
    P.rows[key] = r
  end
  return r
end

-- (1.12 scripts read this / event / arg1..; a direct call may pass values, so they go on)
local function Wrap(fn, r)
  return function(a1, a2, a3, a4, a5, a6, a7, a8, a9)
    local g, t = gc(), clock()
    fn(a1, a2, a3, a4, a5, a6, a7, a8, a9)
    local d = clock() - t
    r.n, r.ms = r.n + 1, r.ms + d
    if d > r.max then r.max = d end
    local k = gc() - g
    if k > 0 then r.kb = r.kb + k end
    if r.script == "OnEvent" then
      local ev = _G.event or "?"
      local e = r.ev[ev]
      if not e then e = { n = 0, ms = 0 } r.ev[ev] = e end
      e.n, e.ms = e.n + 1, e.ms + d
    end
  end
end

local TIMED = { OnUpdate = true, OnEvent = true }

-- the frame's SetScript / GetScript become ours: scripts are timed, GetScript still hands
-- back the function that was given (pfUI compares and chains them)
function P.Instrument(f, where)
  if not f or P.done[f] or type(f.SetScript) ~= "function" then return end
  P.done[f] = true
  local set, get = f.SetScript, f.GetScript
  local given = {}
  f.SetScript = function(self, name, fn)
    if TIMED[name] and type(fn) == "function" then
      given[name] = fn
      return set(self, name, Wrap(fn, Row(Where() or where, name)))
    end
    given[name] = nil
    return set(self, name, fn)
  end
  f.GetScript = function(self, name)
    return given[name] or get(self, name)
  end
  -- scripts it already has (named after where the frame was made)
  for name in pairs(TIMED) do
    local fn = get(f, name)
    if fn then
      given[name] = fn
      set(f, name, Wrap(fn, Row(where, name)))
    end
  end
end

-- pfUI's ADDON_LOADED, before the modules start (pfUI.lua)
function P.Init()
  local list = P.load
  P.load = nil
  clock, gc = debugprofilestop, gcinfo
  if not (pfUI_cache and pfUI_cache.profile and type(clock) == "function" and type(gc) == "function") then
    CreateFrame = P.make
    P.on = nil
    return
  end
  P.on = true
  for i = 1, table.getn(list or {}) do P.Instrument(list[i][1], list[i][2]) end
  -- frames made later by pfUI's code (modules, nameplates, previews) are timed too
  CreateFrame = function(a1, a2, a3, a4)
    local f = Make(a1, a2, a3, a4)
    local where = Where()
    if where then P.Instrument(f, where) end
    return f
  end
  P.Reset()
  local fps = P.make("Frame")
  fps:SetScript("OnUpdate", function() P.frames = (P.frames or 0) + 1 end)
  local hello = P.make("Frame")
  hello:RegisterEvent("PLAYER_ENTERING_WORLD")
  hello:SetScript("OnEvent", function()
    this:UnregisterAllEvents()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: the profiler is |cffffcc00on|r and measuring. "
      .. "|cffffffff/pfprof|r = the report, |cffffffff/pfprof off|r = stop (reload).")
  end)
end

function P.Reset()
  for _, r in pairs(P.rows) do r.n, r.ms, r.max, r.kb, r.ev = 0, 0, 0, 0, {} end
  P.start, P.frames = clock and clock() or 0, 0
end

local function Fmt(v, d) return string.format("%." .. (d or 1) .. "f", v) end

-- the report as lines: totals, then the costliest scripts
function P.Lines(max)
  local out = {}
  if not P.on then
    table.insert(out, "The profiler is off. /pfprof on (reloads) starts it.")
    return out
  end
  local secs = math.max(.001, (clock() - P.start) / 1000)
  local list, total, kb, byfile = {}, 0, 0, {}
  for _, r in pairs(P.rows) do
    if r.n > 0 then
      table.insert(list, r)
      total, kb = total + r.ms, kb + r.kb
      local file = string.gsub(r.where, ":%d+$", "")
      byfile[file] = (byfile[file] or 0) + r.ms
    end
  end
  table.sort(list, function(a, b) return a.ms > b.ms end)
  local fps = (P.frames or 0) / secs
  local frameMs = fps > 0 and 1000 / fps or 0
  table.insert(out, "pfUI profile over " .. Fmt(secs, 0) .. " s at " .. Fmt(fps, 0) .. " fps: pfUI scripts used "
    .. Fmt(total / secs, 2) .. " ms a second (" .. Fmt(frameMs > 0 and total / (P.frames or 1) or 0, 3)
    .. " ms a frame of " .. Fmt(frameMs, 1) .. "), made ~" .. Fmt(kb / secs, 1) .. " KB a second")
  local files = {}
  for file, ms in pairs(byfile) do table.insert(files, { file, ms }) end
  table.sort(files, function(a, b) return a[2] > b[2] end)
  local top = {}
  for i = 1, math.min(6, table.getn(files)) do
    table.insert(top, files[i][1] .. " " .. Fmt(files[i][2] / secs, 2))
  end
  table.insert(out, "By file (ms/s): " .. table.concat(top, ", "))
  table.insert(out, "ms/s | calls/s | worst ms | KB/s | where")
  for i = 1, math.min(max or 15, table.getn(list)) do
    local r = list[i]
    local line = Fmt(r.ms / secs, 2) .. " | " .. Fmt(r.n / secs, 0) .. " | " .. Fmt(r.max, 2) .. " | "
      .. Fmt(r.kb / secs, 1) .. " | " .. r.where .. " " .. r.script
    if r.script == "OnEvent" then
      local evs = {}
      for name, e in pairs(r.ev) do table.insert(evs, { name, e }) end
      table.sort(evs, function(a, b) return a[2].ms > b[2].ms end)
      local names = {}
      for j = 1, math.min(3, table.getn(evs)) do
        table.insert(names, evs[j][1] .. " " .. Fmt(evs[j][2].ms / secs, 2) .. "/" .. Fmt(evs[j][2].n / secs, 0))
      end
      if names[1] then line = line .. " (" .. table.concat(names, ", ") .. ")" end
    end
    table.insert(out, line)
  end
  return out
end

-- a box with the whole report, selected, to copy (Ctrl+C) and paste to whoever fixes it
function P.Show()
  local text = table.concat(P.Lines(40), "\n")
  local b = P.box
  if not b then
    b = P.make("Frame", "pfProfilerBox", UIParent)
    b:SetWidth(640) b:SetHeight(360)
    b:SetPoint("CENTER", 0, 60)
    b:SetFrameStrata("DIALOG")
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    b:SetBackdropColor(.05, .05, .06, .95)
    b:SetBackdropBorderColor(.2, .6, 1, 1)
    b:EnableMouse(true)
    b:SetMovable(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function() this:StartMoving() end)
    b:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    local title = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("pfUI profiler - Ctrl+C copies, /pfprof reset starts again")
    local close = CreateFrame("Button", nil, b, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    local sf = CreateFrame("ScrollFrame", "pfProfilerScroll", b, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 10, -28)
    sf:SetPoint("BOTTOMRIGHT", -30, 10)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(GameFontHighlightSmall)
    eb:SetWidth(590)
    eb:SetScript("OnEscapePressed", function() b:Hide() end)
    sf:SetScrollChild(eb)
    b.edit = eb
    tinsert(UISpecialFrames, "pfProfilerBox")
    P.box = b
  end
  b.edit:SetText(text)
  b:Show()
  b.edit:SetFocus()
  b.edit:HighlightText()
end

_G.SLASH_PFPROF1 = "/pfprof"
_G.SlashCmdList["PFPROF"] = function(msg)
  msg = string.lower(msg or "")
  local say = function(s) DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: " .. s) end
  if msg == "on" then
    pfUI_cache.profile = true
    say("profiler on - reloading. Play as normal for a few minutes (a raid or battleground is best), then /pfprof.")
    ReloadUI()
  elseif msg == "off" then
    pfUI_cache.profile = nil
    say("profiler off - reloading.")
    ReloadUI()
  elseif msg == "reset" then
    P.Reset()
    say("profiler counts cleared.")
  elseif msg == "chat" then
    local lines = P.Lines(10)
    for i = 1, table.getn(lines) do DEFAULT_CHAT_FRAME:AddMessage(lines[i]) end
  else
    P.Show()
  end
end
