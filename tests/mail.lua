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
  "GetNumGuildMembers", "GetGuildRosterInfo", "pfUI_playerDB" }) do keep[k] = rawget(_G, k) end
local now = 100
_G.GetTime = function() return now end
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
