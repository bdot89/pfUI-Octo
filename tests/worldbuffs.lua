-- pfUI Octo: world buff drops (modules/worldbuffs.lua) and the world map's zoom (modules/map.lua), run by tests\run.lua.
-- (21 Nov 2026, Bread: "when world buffs are going to go off and what buff it is"; Lo5t1ncyb3r: Magnify built in)
local ok = octo_ok
local WB = pfUI.worldbuffs
ok(WB and WB.Match and WB.Coming and WB.Paint, "world buffs loaded (pfUI.worldbuffs)")
if WB then
  local S = pfUI_config.worldbuffs
  ok(S and S.enable == "1" and S.share == "1", "defaults (C.worldbuffs)")
  ok(getglobal("pfWorldBuffs") and rawget(_G, "SLASH_PFWORLDBUFFS1") == "/wb", "the bar's frame and /wb")
  -- which yell is which drop
  local d = WB.Match("Overlord Runthak", "Citizens of the Horde, behold the head of the black dragon Onyxia!")
  ok(d and d.key == "ony_h", "Overlord Runthak's yell: Onyxia's head in Orgrimmar")
  ok((WB.Match("Thrall", "The false Warchief, Rend Blackhand, has fallen!") or {}).key == "rend", "Thrall about Rend: Warchief's Blessing")
  ok(WB.Match("Thrall", "Lok'tar!") == nil, "Thrall saying anything else: nothing")
  ok(WB.Match("Some Guard", "Onyxia!") == nil, "someone else's yell: nothing")

  local keep = { send = rawget(_G, "SendAddonMessage"), guild = rawget(_G, "IsInGuild"), buff = rawget(_G, "UnitBuff"),
    gt = rawget(_G, "GetTime"), un = rawget(_G, "UnitName") }
  local sent = {}
  _G.SendAddonMessage = function(p, m, c) table.insert(sent, { p, m, c }) end
  _G.IsInGuild = function() return 1 end
  local now = 1000
  _G.GetTime = function() return now end
  WB.pending = {}
  pfUI_cache.wbdelay = nil
  -- the yell in Orgrimmar starts the countdown and is passed on to the guild
  _G.event, _G.arg1, _G.arg2 = "CHAT_MSG_MONSTER_YELL", "Citizens of the Horde, behold the head of Onyxia!", "Overlord Runthak"
  _G.this = WB.events
  Mock.Run(WB.events, "OnEvent")
  local p = WB.pending.ony_h
  ok(p and math.abs(p.at - (1000 + 14)) < .01, "the yell: Onyxia's buff in 14 s (the estimate)")
  ok(sent[1] and sent[1][1] == "pfWB" and sent[1][2] == "D^ony_h^14" and sent[1][3] == "GUILD", "passed on to the guild (" .. tostring(sent[1] and sent[1][2]) .. ")")
  WB.Paint(now + 4)
  local r = WB.rows[1]
  ok(r and r:IsShown() and string.find(r.text.text or "", "Rallying Cry", 1, true) and r.time.text == "10 s", "the bar: the buff, where, and 10 s left")
  -- the same drop passed on by someone else does not start a second bar
  WB.Receive("D^ony_h^12", "Bob")
  local n = 0
  for _ in pairs(WB.pending) do n = n + 1 end
  ok(n == 1, "the same drop heard twice: one bar")
  -- a guildmate's drop elsewhere
  local sentBefore = table.getn(sent)
  WB.Receive("D^rend^5", "Bob")
  ok(WB.pending.rend and WB.pending.rend.from == "Bob" and math.abs(WB.pending.rend.at - 1005) < .01, "Bob's Rend drop: Warchief's Blessing in 5 s")
  ok(table.getn(sent) == sentBefore, "a drop passed on to us is not passed on again")
  WB.Receive("D^nonsense^5", "Bob")
  ok(WB.pending.nonsense == nil, "an unknown drop is ignored")
  -- the buff lands 12 s after the yell: that is learnt
  _G.UnitBuff = function(u, i) if i == 1 then return "Interface\\Icons\\inv_misc_head_dragon_01" end end
  WB.Landed(1012)
  ok(pfUI_cache.wbdelay and pfUI_cache.wbdelay.ony_h == "12", "the buff landed 12 s after the yell: learnt (" .. tostring(pfUI_cache.wbdelay and pfUI_cache.wbdelay.ony_h) .. ")")
  local secs, learnt = WB.Delay(WB.Def("ony_h"))
  ok(secs == 12 and learnt, "next time: 12 s")
  -- gone 15 s after it landed
  WB.Paint(1012 + 16)
  ok(WB.pending.ony_h == nil and WB.pending.rend == nil, "the bars go 15 s after their buff")
  pfUI_config.worldbuffs.enable = "0"
  WB.Coming(WB.Def("zg"), 30)
  ok(WB.pending.zg == nil, "switched off: nothing")
  pfUI_config.worldbuffs.enable = "1"
  _G.SendAddonMessage, _G.IsInGuild, _G.UnitBuff, _G.GetTime = keep.send, keep.guild, keep.buff, keep.gt
  WB.pending, pfUI_cache.wbdelay = {}, nil
end

-- the world map's zoom
local Z = pfUI.map and pfUI.map.zoom
ok(Z and Z.SetZoom and Z.Reset, "world map zoom loaded (pfUI.map.zoom)")
if Z then
  ok(pfUI_config.appearance.worldmap.zoom == "1", "on by default")
  -- (the mock says every add-on is loaded - Magnify too: here it is not)
  local keepLoaded = rawget(_G, "IsAddOnLoaded")
  _G.IsAddOnLoaded = function(n) return nil end
  -- (an earlier test leaves a Cartographer table behind: no Cartographer here)
  local keepCarto = rawget(_G, "Cartographer")
  _G.Cartographer = nil
  if not Z.scroll then pcall(Z.Setup) end
  _G.IsAddOnLoaded = function(n) return n == "Magnify" and 1 or nil end
  ok(not Z.Wanted(), "Magnify loaded: ours stands aside")
  _G.IsAddOnLoaded = function(n) return nil end
  ok(Z.scroll and (rawget(_G, "WorldMapScrollFrame") == Z.scroll or Z.scroll:GetName() == "WorldMapScrollFrame"),
    "the map picture in WorldMapScrollFrame (the name pfQuest's buttons look for)")
  if Z.scroll then
    Z.scroll:SetWidth(1002)
    Z.scroll:SetHeight(668)
    WorldMapDetailFrame:SetWidth(1002)
    WorldMapDetailFrame:SetHeight(668)
    Z.Reset()
    Z.SetZoom(2, 501, 334)
    ok(Z.zoom == 2 and math.abs(Z.h - 250.5) < .01 and math.abs(Z.v - 167) < .01, "2x at the middle: the middle stays in the middle (" .. tostring(Z.h) .. ", " .. tostring(Z.v) .. ")")
    -- (21 Nov 2026, user: zooming "moves where i picked") the picture hangs by its top left at (-h, v): its own units
    local pt = WorldMapDetailFrame.points and WorldMapDetailFrame.points[1]
    ok(pt and pt[2] == Z.canvas and math.abs(pt[4] + 250.5) < .01 and math.abs(pt[5] - 167) < .01,
      "the picture hangs at (-h, v) in the canvas (" .. tostring(pt and pt[4]) .. ", " .. tostring(pt and pt[5]) .. ")")
    -- the map point under the cursor stays under it, notch after notch
    local fx, fy = 300, 200
    local function Under() return Z.h + fx / Z.zoom, Z.v + fy / Z.zoom end
    local ux, uy = Under()
    for _ = 1, 3 do Z.SetZoom(Z.zoom * 1.25, fx, fy) end
    local ux2, uy2 = Under()
    ok(math.abs(ux - ux2) < .01 and math.abs(uy - uy2) < .01, "three notches in: the point under the cursor has not moved")
    Z.SetZoom(Z.zoom / 1.25, fx, fy)
    local ux3, uy3 = Under()
    ok(math.abs(ux - ux3) < .01 and math.abs(uy - uy3) < .01, "and one out: still under the cursor")
    Z.Reset()
    Z.SetZoom(2, 501, 334)
    Z.SetZoom(2 * 1.25, 0, 0)
    ok(math.abs(Z.h - 250.5) < .01, "zooming at the top left corner keeps that corner")
    Z.SetZoom(99, 501, 334)
    ok(Z.zoom == Z.MAX, "no further than " .. Z.MAX .. "x")
    Z.Scroll(100000, -50)
    local mh = Z.Range(Z.zoom)
    ok(math.abs(Z.h - mh) < .01 and Z.v == 0, "the view never leaves the map")
    Z.Reset()
    ok(Z.zoom == 1 and Z.h == 0 and Z.v == 0, "back to the whole map")
    -- (23 Nov 2026, mechanism: the ping on opening the map landed in the wrong place after zooming) the ping hangs on
    -- the player marker, which is right at every zoom
    if Z.FixPing then
      local keepPing, keepMe = rawget(_G, "WorldMapPing"), rawget(_G, "WorldMapPlayer")
      local ping, me = CreateFrame("Frame"), CreateFrame("Frame")
      ping:Show()
      _G.WorldMapPing, _G.WorldMapPlayer = ping, me
      Z.SetZoom(3, 501, 334)
      Z.FixPing()
      local pp = ping.points and ping.points[1]
      ok(pp and pp[1] == "CENTER" and pp[2] == me and pp[4] == -7 and pp[5] == -9, "zoomed in: the ping sits on your marker")
      -- (24 Nov 2026, Simpson) pinned on you at 1x too (the old fix ran only with zoom), and it can be switched off
      Z.Reset()
      ping:ClearAllPoints()
      ping:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, 50)
      ping:Show()
      Z.PingCheck()
      pp = ping.points and ping.points[1]
      ok(pp and pp[1] == "CENTER" and pp[2] == me, "not zoomed: the ping sits on your marker too")
      pfUI_config.appearance.worldmap.ping = "0"
      Z.PingCheck()
      ok(not ping:IsShown(), "ping switched off: hidden")
      pfUI_config.appearance.worldmap.ping = "1"
      _G.WorldMapPing, _G.WorldMapPlayer = keepPing, keepMe
      Z.Reset()
    end
    -- (24 Nov 2026, Simpson: pfQuest's "Current Zone Only" stopped working) every map menu above the map's click layer
    if Z.RaiseMenus then
      local keepDD, keepDDB = rawget(_G, "pfQuestMapDropdown"), rawget(_G, "pfQuestMapDropdownButton")
      local dd = CreateFrame("Frame", nil, UIParent)
      local ddb = CreateFrame("Button", nil, dd)
      dd:SetFrameLevel(2)
      _G.pfQuestMapDropdown, _G.pfQuestMapDropdownButton = dd, ddb
      WorldMapButton:SetFrameLevel(30)
      Z.RaiseMenus()
      ok(dd:GetFrameLevel() > 30 and ddb:GetFrameLevel() > dd:GetFrameLevel(), "pfQuest's quest menu and its arrow sit above the map")
      _G.pfQuestMapDropdown, _G.pfQuestMapDropdownButton = keepDD, keepDDB
    end
  end
  pfUI_config.appearance.worldmap.zoom = "0"
  ok(not Z.Wanted(), "switched off: not set up")
  pfUI_config.appearance.worldmap.zoom = "1"
  _G.IsAddOnLoaded = keepLoaded
  _G.Cartographer = keepCarto
end
