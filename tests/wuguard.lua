-- pfUI Octo: the guard round WeirdUtils' tracking calls (modules/weirdutils-guard.lua), run by tests\run.lua.
local ok = octo_ok
local G = pfUI.wuguard
ok(G and G.Install, "weirdutils guard loaded")
if not G then return end
local saved = rawget(_G, "WeirdUtils")
local sent = {}
_G.WeirdUtils = { SetObjectTypeBlip = function(kind, tex, scale, inc, exc) table.insert(sent, kind .. ":" .. tostring(tex)) end }
G.Install()
local wu = _G.WeirdUtils
ok(wu.octoGuard, "installed on the DLL's table")
-- the menu's burst: every kind is sent again with each click
for click = 1, 3 do
  wu.SetObjectTypeBlip("banker", "icon", 1.5, nil, nil)
  wu.SetObjectTypeBlip("mailbox", nil, nil, nil, nil)
  wu.SetObjectTypeBlip("repair", "icon2", 1.5, nil, nil)
end
ok(table.getn(sent) == 0, "nothing goes to the DLL inside the clicking frame")
local function Run(n)
  for i = 1, n do
    Mock.now = Mock.now + .1
    Mock.Run(G.frame, "OnUpdate", .1)
  end
end
Run(6)
ok(table.getn(sent) == 3, "three kinds, once each, one at a time (" .. table.getn(sent) .. ")")
sent = {}
wu.SetObjectTypeBlip("banker", "icon", 1.5, nil, nil)
wu.SetObjectTypeBlip("mailbox", nil, nil, nil, nil)
Run(4)
ok(table.getn(sent) == 0, "the same answers again: nothing is sent")
wu.SetObjectTypeBlip("banker", nil, nil, nil, nil)
wu.SetObjectTypeBlip("banker", "icon", 1.5, nil, nil)
wu.SetObjectTypeBlip("banker", nil, nil, nil, nil)
Run(4)
ok(table.getn(sent) == 1 and sent[1] == "banker:nil", "quick off / on / off: one call, the last answer (" .. table.concat(sent, ",") .. ")")
_G.WeirdUtils = saved
