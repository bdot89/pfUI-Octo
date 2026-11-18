-- pfUI Octo: Move anything (modules/movers.lua, movers-options.lua, unlock.lua's bar switch), run by tests\run.lua
local ok = octo_ok
local MV = pfUI.movers
ok(MV and MV.Make and MV.SetShowing and MV.PickName and MV.Reapply, "Move anything loaded (pfUI.movers)")
if not MV then return end
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.stmovers, "Settings > Move anything registered")
ok(pfUI_config.movers.show == "0" and pfUI_config.movers.windows == "1", "defaults: game frames boxed only when switched on, Shift-drag windows on")

-- the game's frames are looked after but get no box while the switch is off (layout mode stays tidy)
local qw = _G.QuestWatchFrame
ok(MV.Owns("QuestWatchFrame"), "quest tracker looked after")
ok(not pfUI.movables.QuestWatchFrame, "switch off: no box for it")
MV.SetShowing(true)
ok(pfUI.movables.QuestWatchFrame == qw and pfUI_config.movers.show == "1", "switch on: it has a box")
MV.SetShowing(false)
ok(not pfUI.movables.QuestWatchFrame, "switch off again: box gone")

-- the bar's switch paints itself and flips the setting
local bar = pfUI.unlock and pfUI.unlock.bar
ok(bar and bar.moveany and bar.pick and bar.keys, "layout mode bar: Move anything switch, Pick a frame, the clicks line")
if bar and bar.moveany then
  _G.this = bar.moveany
  bar.moveany:GetScript("OnClick")()
  ok(pfUI_config.movers.show == "1" and string.find(bar.moveany.text:GetText() or "", "ON"), "bar switch: on")
  _G.this = bar.moveany
  bar.moveany:GetScript("OnClick")()
  ok(pfUI_config.movers.show == "0" and string.find(bar.moveany.text:GetText() or "", "OFF"), "bar switch: off")
end

-- a saved place goes back on after the game moves the frame itself (UIParent_ManageFramePositions)
pfUI_config.position.QuestWatchFrame = { xpos = 300, ypos = -200, anchor = "TOPLEFT" }
qw:ClearAllPoints()
qw:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -10)
if not MV.wrappedUIParent_ManageFramePositions then
  -- (the test client has no FrameXML function by that name: a stand-in, wrapped the way the module does)
  _G.UIParent_ManageFramePositions = function() end
  MV.Wrap("UIParent_ManageFramePositions", function() MV.Reapply() end)
end
if MV.wrappedUIParent_ManageFramePositions then
  _G.UIParent_ManageFramePositions()
  local a, b, c, x, y = qw:GetPoint()
  -- (SetPoint(anchor, x, y): the test client keeps the short form as it was given)
  if x == nil and type(b) == "number" then x, y = b, c end
  ok(a == "TOPLEFT" and x == 300 and y == -200, "the game moved it: our place put back (" .. tostring(a) .. " " .. tostring(x) .. "," .. tostring(y) .. ")")
else
  ok(false, "UIParent_ManageFramePositions wrapped")
end
pfUI_config.position.QuestWatchFrame = nil

-- opacity
MV.SetAlpha("QuestWatchFrame", .5)
ok(pfUI_config.movers.alpha.QuestWatchFrame == "0.5" and math.abs(qw:GetAlpha() - .5) < .01, "opacity 50% saved and shown")
MV.SetAlpha("QuestWatchFrame", 1)
ok(pfUI_config.movers.alpha.QuestWatchFrame == nil and qw:GetAlpha() == 1, "100% = nothing saved")

-- picking another add-on's frame by name: boxed (the switch goes on), saved; stop moving takes it away
local other = CreateFrame("Frame", "SomeAddonWindow", UIParent)
other:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
ok(MV.PickName("SomeAddonWindow", true) == "SomeAddonWindow" and pfUI.movables.SomeAddonWindow == other
  and pfUI_config.movers.picked.SomeAddonWindow == "1" and pfUI_config.movers.show == "1", "picked: a box, saved, switch on")
ok(not MV.PickName("UIParent", true) and not MV.PickName("noSuchFrameAnywhere", true), "the screen and missing names refused")
MV.Unpick("SomeAddonWindow")
ok(not pfUI.movables.SomeAddonWindow and not pfUI_config.movers.picked.SomeAddonWindow, "stop moving: gone")
MV.SetShowing(false)

-- right-click on such a box opens Settings > Move anything (unlock.lua GetConfigTable)
ok(MV.Owns("QuestWatchFrame") and not MV.Owns("Player"), "only its own frames send right-click to its page")
