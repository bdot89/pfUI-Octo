-- pfUI Octo: layout mode sizes (25 Oct 2026, user: "when resizing ... they jump in size ...
-- There should be match size buttons ... when ... making your raid frame bigger it messes up
-- the way the raid is laid out"), run by tests\run.lua. The wheel's notch, frames keeping
-- their place while they change size, Match between action bars, the raid grid sized by its
-- frames, and the Unit Frames page's sections.
local ok = octo_ok
local U = pfUI.unlock
local SZ = U and U.size
ok(SZ and U.KeepPlaces and U.MatchSize and U.Resize, "layout mode's size helpers (pfUI.unlock.size)")
if not SZ then return end
local C = pfUI_config
local function near(a, b, e) return a and b and math.abs(a - b) < (e or .001) end

-- ---------------------------------------------------------------- the notch
ok(SZ.Step() == .02 and SZ.Step(true) == .1 and SZ.Step(nil, true) == .005, "a notch: 2%, Shift 10%, Ctrl 0.5%")
ok(SZ.Next(1, 1, .02) == 1.02 and SZ.Next(1.02, -1, .02) == 1, "one notch up and back")
local v = 1
for i = 1, 25 do v = SZ.Next(v, 1, .02) end
for i = 1, 25 do v = SZ.Next(v, -1, .02) end
ok(v == 1, "25 notches up and 25 down end where they started (" .. v .. ")")
ok(SZ.Next(.31, -1, .1) == SZ.MIN and SZ.Next(2.95, 1, .1) == SZ.MAX, "the scale stays between 30% and 300%")

-- anchor point <-> offsets, every anchor, at a scale
local W, H = 1920, 1080
local all = true
for _, a in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
  local px, py = SZ.Point(a, 37, -12, .8, W, H)
  local x, y = SZ.Offsets(a, px, py, .8, W, H)
  if not near(x, 37) or not near(y, -12) then all = false end
end
ok(all, "a frame's point on screen and its saved offsets turn into each other for every anchor")
local bx, by = SZ.Point("BOTTOM", 0, 50, 1.5, W, H)
ok(bx == 960 and by == 75, "BOTTOM 0 / 50 at 150% sits 75 px up the middle")

-- ---------------------------------------------------------------- keeping the place
do
  local f = CreateFrame("Frame", "pfTestSized", UIParent)
  f:SetWidth(400)
  f:SetHeight(40)
  f.GetEffectiveScale = function(self) return self:GetScale() end
  C.position.pfTestSized = { anchor = "BOTTOM", xpos = 0, ypos = 60 }
  f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 60)
  local was = { SZ.Point("BOTTOM", 0, 60, 1, W, H) }
  -- ten notches bigger, one at a time: the bottom middle never moves
  local moved = 0
  for i = 1, 10 do
    U.KeepPlaces({ f }, function() f:SetScale(SZ.Next(f:GetScale(), 1, .02)) end)
    local pos = C.position.pfTestSized
    local qx, qy = SZ.Point(pos.anchor, tonumber(pos.xpos), tonumber(pos.ypos), f:GetScale(), W, H)
    moved = math.max(moved, math.abs(qx - was[1]), math.abs(qy - was[2]))
  end
  ok(near(f:GetScale(), 1.2) and moved < 1.3, "a bar at the bottom grows up from where it is (moved " .. moved .. " px at most)")
  ok(f.unlockFix and f.unlockFix.px == was[1] and f.unlockFix.py == was[2], "the exact point is kept between notches, not pfUI's rounded one")
  -- a frame on its default place is left there
  local g = CreateFrame("Frame", "pfTestDefault", UIParent)
  g:SetPoint("CENTER", UIParent, "CENTER", 5, 5)
  C.position.pfTestDefault = nil
  U.KeepPlaces({ g }, function() g:SetScale(1.1) end)
  ok(C.position.pfTestDefault == nil, "a frame on its default place stays on it (not saved)")
  C.position.pfTestSized = nil
end

-- ---------------------------------------------------------------- action bars
local AB = pfUI.barsOcto
local main, top = pfUI.bars and pfUI.bars[1], pfUI.bars and pfUI.bars[6]
ok(AB and AB.CopySize and AB.MatchAll and AB.BarIndex, "pfUI.barsOcto.CopySize / MatchAll / BarIndex")
if AB and main and top then
  ok(AB.BarIndex(main) == 1 and AB.BarIndex(top) == 6 and not AB.BarIndex(UIParent), "BarIndex finds a bar's number")
  local b1, b6 = C.bars.bar1, C.bars.bar6
  local keep = { b1.icon_size, b1.spacing, b1.scale, b6.icon_size, b6.spacing, b6.scale }
  b6.icon_size, b6.spacing, b6.scale = "30", "4", "1.2"
  b1.icon_size, b1.spacing, b1.scale = "20", "1", "1"
  for k in pairs(pfUI.movables) do if type(k) ~= "string" then pfUI.movables[k] = nil end end
  U:Show()
  U.MatchSize(top, main)
  ok(b1.icon_size == "30" and b1.spacing == "4" and b1.scale == "1.2", "Match: the main bar takes the top bar's button size, spacing and scale")
  ok(near(main:GetScale(), 1.2), "and is drawn at that scale (" .. main:GetScale() .. ")")
  -- the match menu: other bars, then "every other bar"
  local list = U.MatchChoices(main.drag)
  local onlyBars = table.getn(list) > 0
  for _, e in ipairs(list) do if not AB.BarIndex(e[2]) then onlyBars = false end end
  ok(onlyBars, "a bar's Match menu lists only other bars (" .. table.getn(list) .. ")")
  -- first page: what can be done; Match opens the list of bars
  U.OpenMatchMenu(main.drag)
  local menu = _G.pfUnlockMatchMenu
  local words = {}
  for _, r in ipairs(menu.rows) do if r:IsShown() then table.insert(words, r.text:GetText()) end end
  local said = table.concat(words, " | ")
  ok(string.find(said, "Match the size of") and string.find(said, "Lock to another box") and string.find(said, "Lock other boxes"),
    "the menu: match, lock to, lock others here (" .. said .. ")")
  Mock.Run(menu.rows[1], "OnClick", "LeftButton")
  ok(menu:IsShown() and menu.rows[1].role == "pick", "Match opens the bars to pick from, the menu stays up")
  U.OpenMatchMenu(main.drag)
  ok(menu.rows[2].role == "save" and string.find(menu.rows[2].text:GetText(), "Every other bar"), "then 'every other bar like this one' (gold)")
  U.OpenMatchMenu(main.drag, nil, "match")
  local first = menu.rows[1]
  local last
  for _, r in ipairs(menu.rows) do if r:IsShown() then last = r end end
  ok(first and first.role == "pick" and last.role == "back", "the bars to pick from are purple (pick one), Back at the end")
  if first then
    Mock.Run(first, "OnClick", "LeftButton")
    ok(not menu:IsShown(), "picking one closes the menu")
  end
  -- every enabled bar like the main one
  b1.icon_size, b1.spacing, b1.scale = "26", "2", "0.9"
  local n = AB.MatchAll(1)
  local same = true
  for i = 2, 10 do
    local d = C.bars["bar" .. i]
    if d.enable == "1" and (d.icon_size ~= "26" or d.spacing ~= "2" or d.scale ~= "0.9") then same = false end
  end
  ok(n > 0 and same, "Match all bars: every bar that is on takes the main bar's size (" .. n .. " bars)")
  -- the wheel over a bar: one 2% notch, and the readout under the box
  local s0 = main:GetScale()
  _G.this, _G.arg1 = main.drag, 1
  main.drag:GetScript("OnMouseWheel")()
  ok(near(main:GetScale(), s0 + .02), "one notch of the wheel = 2% (" .. s0 .. " -> " .. main:GetScale() .. ")")
  local sb = main.drag.sizebox
  ok(sb and sb:IsShown() and string.find(sb.info:GetText(), "buttons") and tonumber(sb.wbox:GetText()), "the size shows under the box while it changes")
  -- the tag is an editor: type the % and press Enter
  if sb then
    sb.pbox:SetText("110%")
    _G.this = sb.pbox
    Mock.Run(sb.pbox, "OnEnterPressed")
    ok(near(main:GetScale(), 1.1) and sb.pbox:GetText() == "110%", "typing 110% in the tag scales the bar (" .. main:GetScale() .. ")")
    -- the wheel over the % turns it a point
    _G.this = sb.pbox
    Mock.Run(sb.pbox, "OnMouseWheel", 1)
    ok(near(main:GetScale(), 1.11), "the wheel over the % adds one (" .. main:GetScale() .. ")")
    -- - / + = a notch of the box's wheel
    local s1 = main:GetScale()
    _G.this = sb.minus
    Mock.Run(sb.minus, "OnClick", "LeftButton")
    ok(near(main:GetScale(), s1 - .02), "- in the tag = one notch smaller")
    -- a width typed: a bar is scaled to it (the mock's frames report scale 1
    -- on screen, so the shown width is the frame's own)
    local s2, w0 = main:GetScale(), main:GetWidth()
    sb.wbox:SetText(tostring(w0 * 1.2))
    _G.this = sb.wbox
    Mock.Run(sb.wbox, "OnEnterPressed")
    ok(near(main:GetScale(), s2 * 1.2, .002), "typing a width scales the bar to it (" .. s2 .. " -> " .. main:GetScale() .. ")")
  end
  s0 = main:GetScale() - .02  -- (so s0 - .08 = 10% under where it is)
  Mock.shift = true
  _G.this, _G.arg1 = main.drag, -1
  main.drag:GetScript("OnMouseWheel")()
  Mock.shift = nil
  ok(near(main:GetScale(), s0 - .08), "Shift: 10% a notch (" .. main:GetScale() .. ")")
  U:Hide()
  b1.icon_size, b1.spacing, b1.scale, b6.icon_size, b6.spacing, b6.scale = keep[1], keep[2], keep[3], keep[4], keep[5], keep[6]
  for i = 2, 10 do C.bars["bar" .. i].scale = "1" end
  if C.position.pfActionBarMain then C.position.pfActionBarMain.scale = nil end
  pfUI.bars:UpdateConfig()
end

-- ---------------------------------------------------------------- locks
-- (user, 25 Oct 2026: the druid mana bar dragged off the player frame "wont lock back")
do
  local real = pfUI.movables
  local A = CreateFrame("Frame", "pfTestLockA", UIParent)
  local B = CreateFrame("Frame", "pfTestLockB", UIParent)
  local D = CreateFrame("Frame", "pfTestMana", UIParent)
  for _, f in ipairs({ A, B, D }) do f:SetWidth(100) f:SetHeight(20) end
  B:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  A:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
  -- a bar docked under B by default, as pfDruidMana under pfPlayer
  D:SetPoint("TOPLEFT", B, "BOTTOMLEFT", 0, -2)
  pfUI.movables = { pfTestLockA = A, pfTestLockB = B, pfTestMana = D }
  C.position.pfTestLockA, C.position.pfTestLockB, C.position.pfTestMana = nil, nil, nil
  for _, f in ipairs({ A, B, D }) do pfUI.api.UpdateMovable(f, true) end
  U:Show()
  ok(U.Holder(D) == B, "a docked bar moves with the frame it hangs on")
  -- dragged off (saved on the screen), then locked back
  D:ClearAllPoints()
  D:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
  pfUI.api.SaveMovable(D)
  ok(C.position.pfTestMana and not C.position.pfTestMana.attach and U.Holder(D) == nil, "dragged off: free")
  U.OpenMatchMenu(D.drag)
  local back
  for _, r in ipairs(_G.pfUnlockMatchMenu.rows) do
    if r:IsShown() and string.find(r.text:GetText() or "", "Lock back on") then back = r end
  end
  ok(back and back.role == "go", "the menu offers 'Lock back on' its frame (green)")
  if back then Mock.Run(back, "OnClick", "LeftButton") end
  local _, rel = D:GetPoint()
  ok(C.position.pfTestMana == nil and rel == B, "locked back on its frame, as it was")
  -- lock A to B: saved on B, loaded on B
  U.LockTo(A, B)
  local pa = C.position.pfTestLockA
  ok(pa and pa.attach == "pfTestLockB" and pa.relpoint == "BOTTOMLEFT", "Lock to: saved on the other box (" .. tostring(pa and pa.attach) .. ")")
  A:ClearAllPoints()
  pfUI.api.LoadMovable(A)
  _, rel = A:GetPoint()
  ok(rel == B, "and loaded on it after a reload")
  ok(U.Holder(A) == B, "it moves with B")
  -- no loops: B cannot lock to A now
  local loops
  for _, e in ipairs(U.LockChoices(B)) do if e[2] == A then loops = true end end
  ok(not loops, "B is not offered to lock to A (that would be a loop)")
  -- a nudge keeps the lock (the arrows set a point on the same frame)
  local an, r2, rp, x0, y0 = A:GetPoint()
  A:ClearAllPoints()
  A:SetPoint(an, r2, rp, x0 + 1, y0)
  pfUI.api.SaveMovable(A)
  ok(C.position.pfTestLockA.attach == "pfTestLockB", "nudging keeps it locked")
  -- unlock: free, where it is
  U.Unlock(A)
  ok(C.position.pfTestLockA and not C.position.pfTestLockA.attach and U.Holder(A) == nil, "Unlock: free again")
  -- lock others to this one (a group)
  U.OpenMatchMenu(B.drag, nil, "lockhere")
  local row
  for _, r in ipairs(_G.pfUnlockMatchMenu.rows) do if r:IsShown() and r.text:GetText() == "Test Lock A" then row = r end end
  if row then Mock.Run(row, "OnClick", "LeftButton") end
  ok(C.position.pfTestLockA.attach == "pfTestLockB", "Lock other boxes to this one: A joins B's group")
  U:Hide()
  C.position.pfTestLockA, C.position.pfTestLockB, C.position.pfTestMana = nil, nil, nil
  pfUI.movables = real
end

-- a typed size on a frame whose size is a setting: the setting changes
do
  local pf, set = _G.pfPlayer, U.SetBoxSize
  ok(set, "pfUI.unlock.SetBoxSize")
  if pf and set and C.unitframes.player then
    local keep = { C.unitframes.player.width, C.unitframes.player.height }
    set(pf, (pf:GetWidth() or 0) + 20, nil)
    ok(tonumber(C.unitframes.player.width) == tonumber(keep[1]) + 20, "a typed width on the player frame is its Width setting ("
      .. tostring(keep[1]) .. " -> " .. tostring(C.unitframes.player.width) .. ")")
    C.unitframes.player.width, C.unitframes.player.height = keep[1], keep[2]
    if pfUI.ufOcto then pfUI.ufOcto.Apply("player") end
  end
end

-- ---------------------------------------------------------------- the raid grid
-- raid.lua: cluster = cols * (frame + 2 borders + gap) - gap
ok(SZ.RaidFrameWidth(5 * (60 + 4 + 2) - 2, 5, 2, 2) == 60, "a raid frame's width from the whole raid's width")
local w1, h1 = SZ.RaidStep(60, .5, 1, 1)
local w2, h2 = SZ.RaidStep(w1, .5, 1, 1)
ok(w1 == 61 and h1 == 31 and w2 == 62 and h2 == 31, "a notch: a pixel wider, the height keeps the shape")
local cols, rows = SZ.RaidGrid("5x8")
ok(cols == 5 and rows == 8, "columns and rows from the layout")
local raid, cluster = pfUI.uf and pfUI.uf.raid, _G.pfRaidCluster
if raid and raid[1] and cluster and raid.UpdateConfig then
  local rc = C.unitframes.raid
  local keep = { rc.width, rc.height, rc.o_growy, rc.o_growx, rc.raidlayout }
  rc.width, rc.height, rc.raidlayout = "60", "30", "5x8"
  raid:UpdateConfig()
  local _, border = pfUI.api.GetBorderSize("unitframes")
  local gap = (tonumber(rc.raidpadding) or 0) * pfUI.api.GetPerfectPixel()
  local function GridW() return 5 * (raid[1]:GetWidth() + 2 * border + gap) - gap end
  cluster:SetScale(1.3)  -- a scale left from before
  for k in pairs(pfUI.movables) do if type(k) ~= "string" then pfUI.movables[k] = nil end end
  U:Show()
  _G.this, _G.arg1 = cluster.drag, 1
  if cluster.drag then cluster.drag:GetScript("OnMouseWheel")() end
  ok(rc.width == "79" and rc.height == "40", "the raid wheel turns the old scale into real sizes, then a pixel (" .. rc.width .. " x " .. rc.height .. ")")
  ok(cluster:GetScale() == 1, "and the raid box is not scaled any more")
  ok(near(cluster:GetWidth(), GridW()), "the box is the grid's size again (" .. cluster:GetWidth() .. " / " .. GridW() .. ")")
  local p1 = { raid[1]:GetPoint() }
  local p2 = { raid[2]:GetPoint() }
  -- (raidfill VERTICAL by default: the second frame is above the first)
  ok(p1[1] == "BOTTOMLEFT" and p2[5] and (p2[4] > p1[4] or p2[5] > p1[5]), "frames still in the grid")
  -- Match: the raid as wide as another box, by its frames' width
  local wide = CreateFrame("Frame", "pfTestWide", UIParent)
  wide:SetWidth(5 * (70 + 2 * border + gap) - gap)
  wide:SetHeight(20)
  wide.drag = { label = "TestWide" }
  U.MatchSize(wide, cluster)
  ok(rc.width == "70" and near(cluster:GetWidth(), wide:GetWidth(), .6), "Match: the raid as wide as another box, the grid kept (" .. rc.width .. ")")
  U:Hide()
  -- growth
  rc.o_growy, rc.o_growx = "DOWN", "LEFT"
  raid:UpdateConfig()
  local q = { raid[1]:GetPoint() }
  local q2 = { raid[2]:GetPoint() }
  ok(q[1] == "TOPRIGHT" and q2[5] and q2[5] < 0, "rows can grow down and columns left")
  rc.raidfill = "HORIZONTAL"
  raid:UpdateConfig()
  q2 = { raid[2]:GetPoint() }
  ok(q2[4] and q2[4] < 0, "a row at a time: the second frame to the left")
  rc.raidfill = "VERTICAL"
  rc.width, rc.height, rc.o_growy, rc.o_growx, rc.raidlayout = keep[1], keep[2], keep[3], keep[4], keep[5]
  if C.position.pfRaidCluster then C.position.pfRaidCluster = nil end
  raid:UpdateConfig()
else
  ok(true, "(the raid frames do not start in the mock)")
end

-- ---------------------------------------------------------------- zooming previews
-- (user, 25 Oct 2026: "make all preview windows able to be zoomed in and out on and dragged")
do
  local W = pfUI.octoui and pfUI.octoui.W
  ok(W and W.ZoomBox, "W.ZoomBox: a preview box you can zoom into")
  if W and W.ZoomBox then
    local pg = W.Page(UIParent)
    local stage = W.ZoomBox(pg, 120)
    local V = stage.view
    ok(V and V.z == 1 and stage.outer and stage:GetParent():GetParent() ~= stage.outer and stage:GetWidth() == stage.outer:GetWidth(),
      "the stage is as big as the box, inside its clip")
    Mock.cx, Mock.cy = 0, 0
    V.Zoom(1)
    ok(math.abs(V.z - 1.2) < .001 and math.abs(stage:GetScale() - 1.2) < .001, "the wheel zooms in (" .. V.z .. ")")
    V.Zoom(1) V.Zoom(1)
    ok(string.find(V.fit.text:GetText(), "Fit"), "while zoomed: the zoom and Fit in the corner")
    for i = 1, 30 do V.Zoom(1) end
    ok(V.z == W.ZOOM_MAX, "no further than " .. W.ZOOM_MAX .. "x")
    for i = 1, 30 do V.Zoom(-1) end
    ok(V.z == 1 and V.x == 0 and V.y == 0, "out to the whole picture, centred again")
    -- a part that hands on the plain wheel (as the previews' parts do) zooms
    local part = CreateFrame("Button", nil, stage)
    _G.arg1 = 1
    pfUI.plates.PassWheel(part)
    ok(V.z > 1, "a part's plain wheel reaches the zoom (PassWheel)")
    _G.arg1 = 1
    pfUI.plates.PassWheel(stage)
    ok(V.z > 1.3, "the stage's own wheel too")
    -- dragging empty space moves the view
    Mock.cx, Mock.cy = 0, 0
    _G.this = V.pan
    Mock.Run(V.pan, "OnMouseDown", "LeftButton")
    Mock.cx, Mock.cy = 30, -10
    Mock.Run(V.pan, "OnUpdate", .02)
    Mock.Run(V.pan, "OnMouseUp", "LeftButton")
    ok(V.x ~= 0 or V.y ~= 0, "dragging empty space moves the view (" .. V.x .. ", " .. V.y .. ")")
    Mock.Run(V.pan, "OnDoubleClick", "LeftButton")
    ok(V.z == 1 and V.x == 0, "a double-click fits it again")
    Mock.cx, Mock.cy = nil, nil
  end
end

-- ---------------------------------------------------------------- copying a frame's settings
-- (user, 25 Oct 2026: "Player and Target bars for example you can easily copy ALL the settings")
do
  local UF = pfUI.ufOcto
  if UF and UF.Copy then
    ok(UF.PartOf("width") == "size" and UF.PartOf("txthpleft") == "text" and UF.PartOf("buffsize") == "auras"
      and UF.PartOf("raidiconsize") == "icons" and UF.PartOf("o_skin") == "look" and UF.PartOf("manacolor") == "look"
      and UF.PartOf("customfont_size") == "text" and UF.PartOf("debuff_indicator") == "auras",
      "every setting goes to its part (size, text, buffs, icons, look)")
    ok(UF.PartOf("visible") == nil and UF.PartOf("clickcast_shift") == nil and UF.PartOf("raidlayout") == nil,
      "whether it shows, click casting and the raid grid are never copied")
    local pl, tg = C.unitframes.player, C.unitframes.target
    local keep = { pl.width, pl.txthpleft, pl.visible, tg.width, tg.txthpleft, tg.visible }
    pl.width, pl.txthpleft, pl.visible = "222", "name", "1"
    tg.width, tg.txthpleft, tg.visible = "150", "health", "0"
    local n = UF.Copy("player", "target", "size")
    ok(n > 0 and tg.width == "222" and tg.txthpleft == "health", "Copy size and bars: only that part (" .. n .. ")")
    UF.Undo()
    ok(tg.width == "150" and not UF.lastCopy, "Undo puts it back")
    UF.Copy("player", "target", "all")
    ok(tg.width == "222" and tg.txthpleft == "name" and tg.visible == "0", "Copy everything: all of it but whether it shows")
    UF.Undo()
    ok(tg.width == "150" and tg.txthpleft == "health", "and Undo puts all of it back")
    -- the menu: frames to copy from, then what
    UF.cur = "target"
    local m = UF.CopyMenu(UF.copyButton or UIParent)
    ok(m and m:IsShown(), "Copy from... opens a list of frames")
    pl.width, pl.txthpleft, pl.visible, tg.width, tg.txthpleft, tg.visible = keep[1], keep[2], keep[3], keep[4], keep[5], keep[6]
    UF.cur = "player"
    UF.Apply("target")
  else
    ok(false, "pfUI.ufOcto.Copy")
  end
  local CB = pfUI.castbarOcto
  if CB and CB.Copy then
    local pc, tc = C.castbar.player, C.castbar.target
    local keep = { pc.height, pc.hide_pfui, tc.height, tc.hide_pfui }
    pc.height, pc.hide_pfui, tc.height, tc.hide_pfui = "24", "0", "12", "1"
    CB.Copy("player", "target")
    ok(tc.height == "24" and tc.hide_pfui == "1", "cast bars: copy another's settings, not whether it is on")
    CB.Undo()
    ok(tc.height == "12", "cast bars: undo")
    pc.height, pc.hide_pfui, tc.height, tc.hide_pfui = keep[1], keep[2], keep[3], keep[4]
  else
    ok(false, "pfUI.castbarOcto.Copy")
  end
end

-- ---------------------------------------------------------------- unit frames sections
local UF = pfUI.ufOcto
local O = pfUI.octoui and pfUI.octoui.Options
if UF and O and UF.SECTIONS then
  pfUI.gui:Show()
  O:Select("o:ufframes")
  local p = O.pages.ufframes
  local lost, pics = {}, {}
  for _, c in ipairs(p.cards) do
    if not UF.SECTION_OF[c.title] then table.insert(lost, c.title) end
    if not UF.CARDICON[c.title] and c.title ~= "Try it on the preview" then table.insert(pics, c.title) end
  end
  ok(table.getn(lost) == 0, "every Unit Frames card is in a section (" .. table.concat(lost, ", ") .. ")")
  ok(table.getn(pics) == 0, "every Unit Frames card has a picture (" .. table.concat(pics, ", ") .. ")")
  local most = 0
  for _, s in ipairs(UF.SECTIONS) do most = math.max(most, table.getn(s[4])) end
  ok(table.getn(UF.SECTIONS) == 7 and most <= 4, "seven sections of at most four cards (was one list of " .. table.getn(p.cards) .. ")")
  local function Shown(title)
    for _, c in ipairs(p.cards) do if c.title == title then return c.card:IsShown() end end
  end
  UF.SetSection("size")
  ok(Shown("Health bar") and not Shown("Raid layout") and not Shown("Buffs"), "Size and bars shows only its cards")
  ok(p.last and p.last:IsShown(), "the page ends at the last card shown (its height)")
  UF.SetSection("raid")
  ok(Shown("Raid layout") and not Shown("Health bar") and UF.cur == "raid", "Raid layout: its own section, on the raid frames' preview")
  ok(UF.secTabs and UF.secTabs[6].picked and not UF.secTabs[1].picked, "the section tab is lit (purple)")
  -- a click on the preview's health bar goes to its section
  pfUI.plates.OpenSection("ufframes", "Health bar")
  ok(UF.sec == "size" and Shown("Health bar"), "a card of another section opens that section")
  -- layout mode's right-click on the raid box: the Raid layout card
  O.tabs.ufframes("raid")
  O:Select("o:ufframes")
  ok(UF.sec == "raid" and Shown("Raid layout"), "the raid box's options open on the raid layout")
  UF.cur = "player"
  UF.SetSection("size")
else
  ok(false, "unit frames sections (pfUI.ufOcto.SECTIONS)")
end

-- ---------------------------------------------------------------- bar shape follows its buttons
-- (user, 26 Oct 2026: "when i choose 9 buttons the right option should change to 1x9")
do
  local N = pfUI.api.BarLayoutNearest
  ok(N, "action bar shape helper (pfUI.api.BarLayoutNearest)")
  if N then
    ok(N(9, "1 x 12") == "1 x 9", "1 x 12 with 9 buttons becomes 1 x 9")
    ok(N(9, "12 x 1") == "9 x 1", "12 x 1 with 9 buttons becomes 9 x 1")
    ok(N(9, "6 x 2") == "3 x 3", "6 x 2 with 9 buttons becomes 3 x 3")
    ok(N(8, "6 x 2") == "4 x 2", "6 x 2 with 8 buttons becomes 4 x 2")
    ok(N(12, "1 x 9") == "1 x 12", "and back to 1 x 12")
    -- a bar saved as 9 buttons in "1 x 12" is drawn as one column of 9, not one row
    local bar = C.bars.bar3
    local ob, of = bar.buttons, bar.formfactor
    bar.buttons, bar.formfactor = "9", "1 x 12"
    pfUI.bars:UpdateConfig()
    local f = pfUI.bars[3]
    ok(f and f._size and f._size[2] > f._size[1], "9 buttons saved as 1 x 12 draw as a column (" .. tostring(f and f._size and f._size[1]) .. " x " .. tostring(f and f._size and f._size[2]) .. ")")
    bar.buttons, bar.formfactor = ob, of
    pfUI.bars:UpdateConfig()
  end
  -- (user, 26 Oct 2026: "making a frame wider ... nothing happens") docked meter windows share the
  -- panel by their own widths
  local PN, M = pfUI.panel, pfUI.meters
  -- (chat does not start in the mock: a stand-in right chat window)
  local hadChat = pfUI.chat
  if not (pfUI.chat and pfUI.chat.right) then
    pfUI.chat = pfUI.chat or {}
    pfUI.chat.right = CreateFrame("Frame", nil, UIParent)
    pfUI.chat.right:SetWidth(400)
    pfUI.chat.right:SetHeight(180)
  end
  if PN and PN.ArrowDock and M and M.windows and M.windows[2] and pfUI.chat and pfUI.chat.right then
    local om, oo, ow = C.panel.arrowmode, C.panel.arrowopen, C.panel.arrowwins
    local w1, w2 = C.meters.win1.width, C.meters.win2.width
    C.panel.arrowmode, C.panel.arrowopen, C.panel.arrowwins = "meters", "1", ""
    PN.ArrowDock(1, true)
    PN.ArrowDock(2, true)
    ok(PN.ArrowDocks(1) and PN.ArrowDocks(2) and C.panel.arrowwins == "m1,m2", "both windows docked (" .. C.panel.arrowwins .. ")")
    -- (user, 28 Oct 2026: they FILL the panel, no gaps; their own widths do not matter in it)
    C.meters.win1.width, C.meters.win2.width = "300", "100"
    PN.ArrowLayout()
    local a, b = M.windows[1], M.windows[2]
    local pa, pb = a.points and a.points[2], b.points and b.points[1]
    local function X(pt) return pt and pt[4] end
    local full = PN.arrowWidth or pfUI.chat.right:GetWidth() or 0
    ok(a.arrowDocked and pa and pb and X(pa) and X(pb) and math.abs(X(pa) - X(pb)) < .01 and math.abs(X(pa) - full / 2) < .5,
      "two docked windows split the panel evenly, edge to edge (" .. tostring(X(pa)) .. " of " .. full .. ")")
    local pz = b.points and b.points[2]
    ok(pz and pz[1] == "BOTTOMRIGHT" and pz[3] == "BOTTOMRIGHT" and X(pz) == 0, "the last one is pinned to the panel's right edge")
    -- three at most
    if M.windows[4] then
      PN.ArrowDock(3, true)
      ok(PN.ArrowDock(4, true) == false and not PN.ArrowDocks(4), "a fourth window is refused (three at most)")
      PN.ArrowDock(3, false)
    end
    -- set floating: a spot of its own, saved, so it never jumps to the middle
    local name = b:GetName()
    local was = C.position[name]
    C.position[name] = nil
    PN.ArrowDock(2, false)
    ok(not PN.ArrowDocks(2) and C.position[name] and C.position[name].xpos, "a window set floating keeps a saved spot of its own")
    local saved = C.position[name] and C.position[name].xpos
    PN.ArrowDock(2, true)
    PN.ArrowDock(2, false)
    ok(C.position[name] and C.position[name].xpos == saved, "and that spot stays when it goes in and out again")
    C.position[name] = was
    -- (user, 1 Nov 2026: "the arrow has stopped moving the back panel on and off") a click on the
    -- arrow shuts the docked meters AND the dark window behind them, and opens both again
    local rc = C.chat.right.enable
    C.chat.right.enable = "0"
    C.panel.arrowside = "right"
    PN.ArrowSet(true)
    local arrow = PN.right and PN.right.hide
    local click = arrow and arrow:GetScript("OnClick")
    ok(click and pfUI.chat.right:IsShown() and C.panel.arrowopen == "1", "arrow: meters docked, the window behind them shows")
    if click then _G.this = arrow click() end
    ok(C.panel.arrowopen == "0" and not pfUI.chat.right:IsShown() and not M.windows[1]:IsShown(), "arrow click: meters and the window behind them shut")
    if click then _G.this = arrow click() end
    ok(C.panel.arrowopen == "1" and pfUI.chat.right:IsShown() and M.windows[1]:IsShown(), "arrow click again: both back")
    -- (seen in game 1 Nov 2026: TWThreat, docked by pfUI's third-party glue, took the arrow's click)
    local TP = pfUI.thirdparty and pfUI.thirdparty.meters
    if TP and TP.RegisterMeter and arrow then
      C.thirdparty.octotest = { dock = "1" }
      local hid
      TP:RegisterMeter("threat", { "octotest", "OctoTest", nil, nil, nil, nil, function() hid = true end })
      ok(arrow:GetScript("OnClick") == click and not TP.threat and not hid, "a docking meter addon leaves the Octo arrow's click alone")
      C.thirdparty.octotest = nil
    end
    C.chat.right.enable = rc
    C.panel.arrowopen = "0"
    PN.ArrowSet(false)
    C.panel.arrowmode, C.panel.arrowopen, C.panel.arrowwins = om, oo, ow
    C.meters.win1.width, C.meters.win2.width = w1, w2
  else
    ok(false, "panel arrow docking helpers")
  end
  pfUI.chat = hadChat
  -- (user, 26 Oct 2026) right-click a bar in layout mode: the Bars page on that bar's tab
  local O = pfUI.octoui and pfUI.octoui.Options
  local AB = pfUI.barsOcto
  if O and AB and AB.TAB then
    O:Open("abbars", 6)
    ok(AB.TAB.cur == 6 and O.current == "o:abbars", "the Top bar's box opens the Bars page on Top bar")
    O:Open("abbars", 1)
  end
end

-- (1 Nov 2026) Match: Target to Player = every setting, the power bar's place too
do
  local p, t = _G.pfPlayer, _G.pfTarget
  local made = not p
  if made then
    p = CreateFrame("Frame", "pfPlayer", UIParent)
    p:SetWidth(200) p:SetHeight(50) p:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
  end
  local cu = pfUI_config.unitframes
  if p and t and pfUI.ufOcto and cu.player and cu.target then
    local keep = {}
    for k, v in pairs(cu.target) do keep[k] = v end
    cu.player.width, cu.player.poffy, cu.player.txthpleftoffx = "222", "0", "4"
    t:SetScale(1.4)
    cu.target.width, cu.target.poffy, cu.target.txthpleftoffx = "150", "-40", "0"
    local good, err = pcall(U.MatchSize, p, t)
    ok(good, "Match a unit frame to another runs: " .. tostring(err))
    ok(cu.target.width == "222" and cu.target.poffy == "0" and cu.target.txthpleftoffx == "0",
      "the target took the player's size and power bar place, and kept its own texts")
    ok(math.abs(t:GetScale() - p:GetScale()) < .001, "and its scale")
    t:SetScale(1)
    for k in pairs(cu.target) do cu.target[k] = nil end
    for k, v in pairs(keep) do cu.target[k] = v end
    if made then _G.pfPlayer = nil end
  end
end
