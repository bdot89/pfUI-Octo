-- pfUI Octo: the mailbox (modules/mail.lua), run by tests\run.lua: sending with items never stalls, the name search
local ok = octo_ok
local M = pfUI.mail
ok(M and M.Send and M.SendStep and M.Names and M.People, "mail engine loaded (pfUI.mail)")
if not (M and M.SendStep and M.People) then return end

-- (16 Nov 2026, user: "when i right click the mailbox it does nothing") opening the mailbox shows our window
do
  local onEv = M.ev and M.ev:GetScript("OnEvent")
  ok(M.Active and M.Active(), "mail window active (no other mail add-on)")
  ok(pfUI.mail.ui and pfUI.mail.ui.frame or _G.pfMail, "mail window built (pfMail)")
  local okShow, err = pcall(function()
    _G.event = "MAIL_SHOW"
    onEv()
  end)
  ok(okShow, "MAIL_SHOW runs without an error: " .. tostring(err))
  ok(_G.pfMail and _G.pfMail:IsShown(), "MAIL_SHOW shows the window")
  local okSend, err2 = pcall(function() pfUI.mail.ui.Open("send") end)
  ok(okSend, "the Send tab opens without an error: " .. tostring(err2))
  _G.event = "MAIL_CLOSED"
  pcall(onEv)
end

-- script handlers the 1.12 client does not have (checked against WoW.exe): setting one errors in game, the
-- test mock takes anything (16 Nov 2026: OnArrowPressed stopped the mail window from being built)
do
  local NOT_112 = { "OnArrowPressed", "OnCursorChanged", "OnEnable", "OnDisable", "OnAttributeChanged" }
  local bad = {}
  local p = io.popen and io.popen('dir /b "' .. string.gsub(DIR, "/", "\\") .. '\\modules\\*.lua"')
  if p then
    for name in p:lines() do
      local fh = io.open(DIR .. "/modules/" .. name, "r")
      if fh then
        local src = fh:read("*a")
        fh:close()
        for _, s in ipairs(NOT_112) do
          if string.find(src, 'SetScript%(%s*"' .. s .. '"') then table.insert(bad, name .. ": " .. s) end
        end
      end
    end
    p:close()
    ok(table.getn(bad) == 0, "no module sets a script 1.12 lacks" .. (bad[1] and (": " .. table.concat(bad, ", ")) or ""))
  end
end

local keep = {}
for _, k in ipairs({ "GetTime", "GetContainerItemInfo", "GetContainerItemLink", "GetSendMailItem", "PickupContainerItem",
  "ClickSendMailItemButton", "ClearCursor", "SetSendMailCOD", "SetSendMailMoney", "GetSendMailPrice", "GetMoney", "SendMail",
  "ClearSendMail", "UnitName", "GetNumRaidMembers", "GetNumPartyMembers", "GetNumFriends", "GetFriendInfo", "IsInGuild",
  "GetNumGuildMembers", "GetGuildRosterInfo", "pfUI_playerDB", "CursorHasItem", "event", "arg1",
  "ERR_MAIL_TARGET_NOT_FOUND" }) do keep[k] = rawget(_G, k) end
local now = 100
_G.GetTime = function() return now end
_G.CursorHasItem = function() return false end
-- (Lobo, 16 Nov 2026) the item is attached, so the bag shows it locked: the mail must still go
local attached, sent, locked = nil, 0, false
_G.GetContainerItemInfo = function() return "tex", 1, locked end
_G.GetContainerItemLink = function() return "|cffffffff|Hitem:2589:0:0:0|h[Linen Cloth]|h|r" end
_G.GetSendMailItem = function() return attached end
_G.PickupContainerItem = function() end
_G.ClickSendMailItemButton = function() attached = "Linen Cloth" locked = true end
_G.ClearCursor = function() end
_G.SetSendMailCOD = function() end
_G.SetSendMailMoney = function() end
_G.GetSendMailPrice = function() return 30 end
_G.GetMoney = function() return 100000 end
_G.SendMail = function() sent = sent + 1 attached = nil end
_G.ClearSendMail = function() attached = nil end
M.open, M.sending = true, nil
M.Send("Bob", "", "", 0, 0, { { bag = 0, slot = 1, link = GetContainerItemLink(0, 1) } })
for _ = 1, 30 do
  now = now + .15
  M.SendStep()
end
ok(sent == 1, "an attached (locked) item is sent, not waited on for ever (sent " .. sent .. ")")
-- an item that never goes on the mail stops with a message within a few seconds
M.sending = nil
_G.ClickSendMailItemButton = function() end
attached, sent, locked = nil, 0, false
M.Send("Bob", "x", "", 0, 0, { { bag = 0, slot = 1, link = GetContainerItemLink(0, 1) } })
for _ = 1, 60 do
  now = now + .15
  M.SendStep()
end
ok(sent == 0 and M.sending == nil, "an item that will not attach stops the send with a message")

-- (17 Nov 2026, user: 16 items queued, only the first went) many items: every one goes, one mail each, even
-- when the client still shows the sent item on the mail for a moment after MAIL_SEND_SUCCESS
do
  local onEv = M.ev:GetScript("OnEvent")
  local LINEN = "|cffffffff|Hitem:2589:0:0:0|h[Linen Cloth]|h|r"
  local bag = { LINEN, LINEN, "|cffffffff|Hitem:2592:0:0:0|h[Wool Cloth]|h|r", LINEN }
  local cursor, onMail, staleUntil, mailed = nil, nil, 0, {}
  _G.GetContainerItemLink = function(b, s) return bag[s] end
  _G.GetContainerItemInfo = function(b, s) if bag[s] then return "tex", 20, onMail == s end end
  _G.PickupContainerItem = function(b, s) cursor = s end
  _G.CursorHasItem = function() return cursor ~= nil end
  _G.ClearCursor = function() cursor = nil end
  _G.GetSendMailItem = function()
    if onMail then return (string.gsub(bag[onMail], "^.-%[(.-)%].*$", "%1")) end
    if now < staleUntil then return "Linen Cloth" end
  end
  _G.ClickSendMailItemButton = function()
    if cursor then onMail, cursor = cursor, nil
    elseif onMail then cursor, onMail = onMail, nil
    elseif now < staleUntil then staleUntil = 0 end
  end
  _G.ClearSendMail = function() onMail = nil end
  local function success()
    local s = onMail
    onMail = nil
    if s then bag[s] = nil end
    _G.event = "MAIL_SEND_SUCCESS"
    onEv()
  end
  _G.SendMail = function()
    table.insert(mailed, onMail or 0)
    sent = sent + 1
    success()
    -- (the client still shows the sent item on the mail for a second)
    staleUntil = now + 1
  end
  local function run()
    for _ = 1, 300 do
      now = now + .15
      M.SendStep()
      if not M.sending then return end
    end
  end
  sent, M.sending = 0, nil
  local items = {}
  for s = 1, 4 do table.insert(items, { bag = 0, slot = s, link = bag[s] }) end
  M.Send("Bob", "", "", 0, 0, items)
  run()
  ok(sent == 4 and table.concat(mailed, ",") == "1,2,3,4" and M.sending == nil,
    "4 items: 4 mails, each with its own item (" .. table.concat(mailed, ",") .. ")")

  -- (17 Nov 2026) no pauses: right after a mail went, the next is attached and sent on the very next step
  bag = { LINEN, LINEN, LINEN }
  items = {}
  for s = 1, 3 do table.insert(items, { bag = 0, slot = s, link = bag[s] }) end
  staleUntil, mailed, sent = 0, {}, 0
  M.Send("Bob", "", "", 0, 0, items)
  for _ = 1, 3 do M.SendStep() end
  ok(sent == 3, "3 mails in 3 steps - one per server answer, no waiting (" .. sent .. ")")
  for _ = 1, 3 do M.SendStep() end
  M.sending = nil
  -- a mail the server refuses once (MAIL_FAILED) is tried again; the run goes on
  bag = { LINEN, LINEN, LINEN }
  items = {}
  for s = 1, 3 do table.insert(items, { bag = 0, slot = s, link = bag[s] }) end
  staleUntil, mailed, sent = 0, {}, 0
  local failedOnce
  _G.SendMail = function()
    if onMail == 2 and not failedOnce then
      failedOnce = true
      _G.event = "MAIL_FAILED"
      onEv()
      return
    end
    table.insert(mailed, onMail or 0)
    sent = sent + 1
    success()
  end
  M.Send("Bob", "", "", 0, 0, items)
  run()
  ok(failedOnce and sent == 3 and table.concat(mailed, ",") == "1,2,3" and M.sending == nil,
    "a mail refused once is tried again and the rest still go (" .. table.concat(mailed, ",") .. ")")

  -- a refused mail stops the run with a message; the sent item leaves the list, the rest stay
  bag = { LINEN, LINEN, LINEN }
  items = {}
  for s = 1, 3 do table.insert(items, { bag = 0, slot = s, link = bag[s] }) end
  staleUntil, mailed = 0, {}
  local n = 0
  _G.ERR_MAIL_TARGET_NOT_FOUND = "Cannot find player"
  _G.SendMail = function()
    n = n + 1
    table.insert(mailed, onMail or 0)
    if n == 1 then success() return end
    _G.event, _G.arg1 = "UI_ERROR_MESSAGE", ERR_MAIL_TARGET_NOT_FOUND
    onEv()
  end
  M.Send("Bob", "", "", 0, 0, items)
  run()
  ok(M.sending == nil and n == 2 and table.getn(items) == 2 and items[1].slot == 2,
    "a refused mail stops the run; the sent item leaves the list, the rest stay (" .. table.getn(items) .. " left)")

  -- the mailbox closing mid-run stops it
  _G.SendMail = function() end
  M.Send("Bob", "", "", 0, 0, { { bag = 0, slot = 2, link = bag[2] } })
  for _ = 1, 5 do now = now + .15 M.SendStep() end
  _G.event = "MAIL_CLOSED"
  onEv()
  ok(M.sending == nil and not M.open, "closing the mailbox stops a run")
  M.open = true
  -- (the finished run noted "Bob" as someone you mail: off again for the name tests below)
  local st = M.Store()
  st.names.Bob = nil
  if st.count then st.count.Bob = nil end
  M.people = nil
end

-- names: guild, friends, seen people; starts-with first, online first
_G.UnitName = function(u) if u == "player" then return "Me" end end
_G.GetNumRaidMembers = function() return 0 end
_G.GetNumPartyMembers = function() return 0 end
_G.GetNumFriends = function() return 1 end
_G.GetFriendInfo = function() return "Bobby", 60, "Mage", "Orgrimmar", false end
_G.IsInGuild = function() return true end
_G.GetNumGuildMembers = function() return 2 end
local g = { { "Bobo", "Warrior", true }, { "Abob", "Priest", true } }
_G.GetGuildRosterInfo = function(i) return g[i][1], "", 0, 60, g[i][2], "", "", "", g[i][3] end
_G.pfUI_playerDB = { Bobsled = { class = "ROGUE" } }
local list = M.Names("bob")
local names = {}
for _, e in ipairs(list) do table.insert(names, e.name) end
local s = table.concat(names, ",")
ok(names[1] == "Bobby" and names[2] == "Bobo" and string.find(s, "Bobby") and string.find(s, "Bobsled") and names[table.getn(names)] == "Abob",
  "names: friend, then guildie, friends and seen people, 'holds it' after 'starts with' (" .. s .. ")")
ok(list[2].class == "WARRIOR" and list[2].online and list[2].tag == "guild" and list[1].tag == "friend", "a name carries class, online and where it is from")
-- alts first, then people you mail (most often first); an empty box lists just those
local st = M.Store()
local oldNames, oldCount, oldAlts = st.names, st.count, st.alts
st.alts = { Bobalt = "PALADIN" }
st.names, st.count = { Bobmail = 1000, Bobrare = 900 }, { Bobmail = 9, Bobrare = 1 }
M.people = nil
list = M.Names("bob")
ok(list[1].name == "Bobalt" and list[1].tag == "alt" and list[2].name == "Bobmail" and list[3].name == "Bobrare",
  "typed: your alt first, then the people you mail most (" .. list[1].name .. ", " .. list[2].name .. ")")
list = M.Names("")
ok(table.getn(list) == 3 and list[1].name == "Bobalt", "an empty To box lists your alts and the people you mail")
st.names, st.count, st.alts = oldNames, oldCount, oldAlts

for k, v in pairs(keep) do _G[k] = v end
M.open, M.sending, M.people = nil, nil, nil

-- (17 Nov 2026) cash on delivery: one click pays, as the game's own COD box does (TakeInboxItem)
do
  local k2 = {}
  for _, k in ipairs({ "GetInboxHeaderInfo", "GetInboxItem", "GetInboxNumItems", "GetInboxText", "TakeInboxItem", "GetMoney" }) do k2[k] = rawget(_G, k) end
  local took, money = {}, 1000
  _G.GetInboxNumItems = function() return 1 end
  _G.GetInboxHeaderInfo = function(i) return "pack", "stat", "Shemp", "4x Dense Stone", 0, 6000, 2, 1, 1, nil, 1, 1 end
  _G.GetInboxItem = function() return "Dense Stone", "tex", 4, 1 end
  _G.GetInboxText = function() return "C.O.D. delivery" end
  _G.TakeInboxItem = function(i) table.insert(took, i) end
  _G.GetMoney = function() return money end
  local notes = {}
  local oldNote = M.onNote
  M.onNote = function(t) table.insert(notes, t) end
  ok(M.PayCOD and M.PayCOD(1) == false and table.getn(took) == 0 and string.find(notes[1] or "", "Not enough", 1, true), "COD: not enough money - nothing taken")
  money = 100000
  ok(M.PayCOD(1) == true and took[1] == 1, "COD: one click pays and takes the item")
  took = {}
  M.TakeOne(1)
  ok(took[1] == 1, "COD: right-click on the row pays too")
  M.onNote = oldNote
  M.job = nil
  for k, v in pairs(k2) do _G[k] = v end
end
