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

-- the layout mode bar: solid, the clicks strip part of it, moved by dragging, right-click = back to the top
if bar and bar.foot then
  ok(bar.keys:GetParent() == bar.foot and bar:IsMovable(), "clicks strip inside the bar; bar movable")
  _G.this = bar
  bar:GetScript("OnDragStart")()
  bar:GetScript("OnDragStop")()
  ok(pfUI_config.unlock.barx ~= nil and pfUI_config.unlock.bary ~= nil, "dragged: its place saved")
  _G.arg1 = "RightButton"
  bar:GetScript("OnMouseUp")()
  ok(pfUI_config.unlock.barx == nil and pfUI_config.unlock.bary == nil, "right-click: back to the top")
end

-- Show: All / pfUI / Game while Move anything is on
do
  local U = pfUI.unlock
  ok(bar and bar.view and table.getn(bar.view.buttons) == 3, "Show: All / pfUI / Game buttons on the bar")
  U:Show()
  MV.SetShowing(true)
  local qwf, player = _G.QuestWatchFrame, pfUI.movables.pfPlayer
  local function Seen(f) return f and f.drag and f.drag:IsShown() end
  pfUI_config.movers.view = "game"
  MV.ApplyView()
  ok(Seen(qwf) and (not player or not Seen(player)), "Game: only the game's frames have boxes")
  pfUI_config.movers.view = "pfui"
  MV.ApplyView()
  ok(not Seen(qwf) and (not player or Seen(player)), "pfUI: only pfUI's frames")
  pfUI_config.movers.view = "all"
  MV.ApplyView()
  ok(Seen(qwf) and (not player or Seen(player)), "All: both")
  pfUI_config.movers.view = "game"
  MV.SetShowing(false)
  ok(not player or Seen(player), "switch off: pfUI's boxes back whatever the view")
  pfUI_config.movers.view = "all"
  U:Hide()
end

-- self-fading game frames (zone text): no FadingFrame errors in layout mode, and their fade comes back afterwards
do
  local U = pfUI.unlock
  local z = CreateFrame("Frame", "OctoTestFadingFrame", UIParent)
  z.fadeInTime, z.holdTime, z.fadeOutTime = .5, 2, 1
  local function Fade() if this.startTime == nil then error("startTime nil") end end
  z:SetScript("OnUpdate", Fade)
  z:Hide()
  U:Show()
  U.AddBox(z)
  ok(z:GetScript("OnUpdate") == nil and z:IsShown(), "fading frame shown in layout mode with its fade put aside")
  U.DropBox(z)
  ok(z:GetScript("OnUpdate") == Fade and not z:IsShown(), "after: its fade back, hidden as it was")
  U:Hide()
end

-- (19 Nov 2026, Lo5t1ncyb3r: the picked quest log went back to the game's place after he had set it) a picked game
-- window keeps its saved place when the game lays its windows out and when it opens
do
  local qlog = CreateFrame("Frame", "OctoTestQuestLog", UIParent)
  qlog:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
  MV.PickName("OctoTestQuestLog", true)
  pfUI_config.position.OctoTestQuestLog = { xpos = 500, ypos = -300, anchor = "TOPLEFT" }
  local function Where()
    local a, b, c, x, y = qlog:GetPoint()
    if x == nil and type(b) == "number" then x, y = b, c end
    return a, x, y
  end
  if not MV.wrappedUpdateUIPanelPositions then
    _G.UpdateUIPanelPositions = function() end
    MV.Wrap("UpdateUIPanelPositions", function() MV.ReplaceWindows() MV.Reapply() end)
  end
  qlog:ClearAllPoints()
  qlog:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
  _G.UpdateUIPanelPositions()
  local a, x, y = Where()
  ok(a == "TOPLEFT" and x == 500 and y == -300, "the game laid its windows out: the saved place put back (" .. tostring(x) .. "," .. tostring(y) .. ")")
  qlog:Hide()
  qlog:ClearAllPoints()
  qlog:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
  _G.this = qlog
  qlog:GetScript("OnShow")()
  a, x, y = Where()
  ok(x == 500 and y == -300, "it opens: the saved place again")
  MV.Unpick("OctoTestQuestLog")
  MV.SetShowing(false)
end

-- (23 Nov 2026, Barbeque_Squirrel) ways into the options without the Game Menu skin, and the installer only at login
do
  ok(_G.GameMenuButtonPFUI ~= nil, "the Esc menu has the pfUI button (made by octo-options, not the skin)")
  local mm = _G.pfUIMinimapButton
  ok(mm ~= nil and pfUI.octoui.Options.ShowMinimap ~= nil, "pfUI Octo minimap button made")
  if mm then
    local CG = pfUI_config.global
    local was = CG.mmbutton
    CG.mmbutton = "0"
    pfUI.octoui.Options.ShowMinimap()
    ok(not mm:IsShown(), "minimap button switched off hides")
    CG.mmbutton = "1"
    pfUI.octoui.Options.ShowMinimap()
    ok(mm:IsShown(), "and switched on shows")
    CG.mmbutton = was
  end
  local fr = pfUI.firstrun
  if fr and fr.GetScript then
    local seen = 0
    local real, realInit = fr.NextStep, _G.pfUI_init
    fr.NextStep = function() seen = seen + 1 end
    _G.pfUI_init = {}
    _G.this = fr
    local h = fr:GetScript("OnEvent")
    if h then h() end
    ok(seen == 1, "a new character: the installer opens at the first loading screen (" .. seen .. ")")
    ok(fr.IsEventRegistered == nil or not fr:IsEventRegistered("PLAYER_ENTERING_WORLD"), "and stops listening after it")
    -- closed / skipped / finished: never by itself again, also with a step added later
    fr:Done()
    pfUI_init.somenewstep = nil
    table.insert(fr.steps, { name = "octotestnew", func = function() end })
    seen = 0
    fr:Start()
    ok(seen == 0 and pfUI_init.octotestnew == true, "done once: a later login does not open it, a new step is marked done")
    table.remove(fr.steps)
    -- a character that did steps before the flag existed counts as done
    _G.pfUI_init = { init = true }
    seen = 0
    fr:Start()
    ok(seen == 0 and pfUI_init.wizarddone, "an older character that started it before is not asked again")
    -- a profile pick reloads mid-way: it carries on
    _G.pfUI_init = { wizardv2 = true, init = true, profile = true }
    seen = 0
    fr:Start()
    ok(seen == 1, "mid-way through (profile reload): it carries on")
    fr.NextStep = real
    _G.pfUI_init = realInit
  end
end
