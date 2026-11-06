pfUI:RegisterModule("unlock", "vanilla:tbc", function ()
  local rawborder, default_border = GetBorderSize()

  -- grouped frames
  local clusters = {
    -- Name            Shift  Ctrl
    { "pfCombo",          5       },
    -- (octo: the raid frames are one box, pfRaidCluster)
    { "pfGroup",          4       },
    { "pfLootRollFrame",  4       },
  }

  local anchors = {
    "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT", "LEFT", "CENTER"
  }


  local spanframe = CreateFrame("Frame", "pfUnlockSelector", UIParent)
  spanframe:Hide()

  -- frame labels and their config section relation
  local frame_configs = {
    -- unitframes
    -- (octo: the Unit Frames section's Frames page, on the frame's tab)
    ["Player"]             = { "ufframes", "player" },
    ["Target"]             = { "ufframes", "target" },
    ["TargetTarget"]       = { "ufframes", "ttarget" },
    ["TargetTargetTarget"] = { "ufframes", "tttarget" },
    ["Pet"]                = { "ufframes", "pet" },
    ["PetTarget"]          = { "ufframes", "ptarget" },
    ["Focus"]              = { "ufframes", "focus" },
    ["FocusTarget"]        = { "ufframes", "focustarget" },

    -- octo: more boxes with a page of their own
    ["Totems"]             = { "bfbuffs", "totems" },
    ["TooltipAnchor"]      = { T["Tooltip"], nil },
    ["Group%dTarget"]      = { "ufframes", "grouptarget" },
    ["GroupPet%d"]         = { "ufframes", "grouppet" },

    -- combopoints
    ["Combo%d"]       = { "ufframes", nil },

    -- groupframes
    -- (octo: the third field = the card that opens, here the raid layout)
    ["Raid%d"]        = { "ufframes", "raid", "Raid layout" },
    ["Raid%d%d"]      = { "ufframes", "raid", "Raid layout" },
    ["RaidCluster"]   = { "ufframes", "raid", "Raid layout" },

    -- octo: meters and combat text (an Octo page key opens that page)
    ["Meter%d"]       = { "mtwindows", nil },
    ["TargetRange"]   = { "ufrange", nil },
    ["CombatText%a+"] = { "ctareas", nil },
    ["Group%d"]       = { "ufframes", "group" },
    ["Party%dTarget"] = { "ufframes", "grouptarget" },
    ["PartyPet%d"]    = { "ufframes", "grouppet" },

    -- chat
    ["ChatLeft"]      = { T["Chat"], nil },
    ["ChatRight"]     = { T["Chat"], nil },
    ["ChatInputBox"]  = { T["Chat"], nil },

    -- loot
    ["LootRollFrame%d"] = { T["Loot"], nil },

    -- panel
    ["PanelLeft"]        = { T["Panel"], T["General"] },
    -- (octo, 29 Oct 2026: its width and height are on the Panel page, like the
    -- left one; the arrow stays on Chat > Panel arrow)
    ["PanelRight"]       = { T["Panel"], T["General"] },
    ["PanelMinimap"]     = { T["Panel"], T["General"] },
    ["PanelMicroButton"] = { T["Panel"], T["General"] },

    -- actionbar
    -- (octo, 26 Oct 2026: right-click opens the Bars page on that bar's own tab; C.bars.barN)
    ["ActionBarMain"]        = { "abbars", 1 },
    ["ActionBarPaging"]      = { "abbars", 2 },
    ["ActionBarRight"]       = { "abbars", 3 },
    ["ActionBarVertical"]    = { "abbars", 4 },
    ["ActionBarLeft"]        = { "abbars", 5 },
    ["ActionBarTop"]         = { "abbars", 6 },
    ["ActionBarStanceBar1"]  = { "abbars", 7 },
    ["ActionBarStanceBar2"]  = { "abbars", 8 },
    ["ActionBarStanceBar3"]  = { "abbars", 9 },
    ["ActionBarStanceBar4"]  = { "abbars", 10 },
    ["ActionBarStances"]     = { "abbars", 11 },
    ["ActionBarPet"]         = { "abbars", 12 },

    -- castbar
    ["TargetCastbar"]  = { "ufcastbar", "target" },
    ["PlayerCastbar"]  = { "ufcastbar", "player" },
    ["FocusCastbar"]   = { "ufcastbar", "focus" },

    -- minimap
    ["Minimap"]        = { "mmmap" },
    ["UITracking"]     = { "mmparts" },

    -- buffs
    ["BuffFrame"]      = { "bfbuffs" },
    ["DebuffFrame"]    = { "bfbuffs" },

    -- buffbars
    ["PlayerBuffBar"]   = { "bfbuffs", "pbuff" },
    ["PlayerDebuffBar"] = { "bfbuffs", "pdebuff" },
    ["TargetDebuffBar"] = { "bfbuffs", "tdebuff" },
  }

  local function GetFrames(base)
    -- Return frames based on Ctrl and Shift state
    -- 'this'   [frame]       the base frame (octo: or base, from the nudge box)
    -- return   [list]        all frames that should be selected

    local frame = base or this.frame
    local frames = { frame }

    if IsShiftKeyDown() or IsControlKeyDown() then
      -- search and add clustered frames
      for id, cluster in pairs(clusters) do
        local len = strlen(cluster[1])
        if strsub(frame:GetName(),0,len) == cluster[1] then
          if IsShiftKeyDown() and cluster[2] then
            for i = 1, cluster[2] do
              if _G[cluster[1] .. i] ~= frame then
                table.insert(frames, _G[cluster[1] .. i])
              end
            end
          elseif IsControlKeyDown() and cluster[3] then
            local id = tonumber(strsub(frame:GetName(),len+1,len+2))

            local b = 1
            for i = cluster[3]+1, cluster[2], cluster[3] do
              b = ( id >= i ) and i or b
            end

            for i = b, b + cluster[3] - 1 do
              if _G[cluster[1] .. i] ~= frame then
                table.insert(frames, _G[cluster[1] .. i])
              end
            end
          end
        end
      end
    end

    return frames
  end

  -- octo: ElvUI-style boxes (user, 20 Oct 2026: "how the UI boxes are
  -- clearer"): see-through dark fill, a blue edge and a blue label; white
  -- edge under the mouse, bright when picked, gold for the Alt-click size
  -- source. d.backdrop comes from CreateBackdrop.
  local PAINT = {
    normal = { .02, .04, .06, .55,  .2, .7, 1, .9,     .55, .82, 1 },
    hover  = { .05, .12, .18, .75,  1, 1, 1, 1,        1, 1, 1 },
    picked = { .08, .22, .32, .75,  .35, .8, 1, 1,     1, 1, 1 },
    source = { .22, .17, .02, .7,   1, .82, 0, 1,      1, .9, .4 },
    off    = { .2, .03, .03, .65,   .9, .2, .2, 1,     1, .55, .55 },
  }

  -- octo (25 Oct 2026, user: "a disable option here for quick removal"):
  -- Hide in the nudge box takes a frame away, over reloads too
  -- (C.unlock.hidden[name] = "1"). It sits under a hidden parent, so whatever
  -- shows it stays unseen; while layout mode is open it is back (its box red,
  -- the button "Show"), so it can always be put back without typing anything.
  local hider = CreateFrame("Frame", "pfUnlockHider", UIParent)
  hider:Hide()
  local function IsHiddenFrame(f)
    local n = f and f.GetName and f:GetName()
    return n and C.unlock.hidden and C.unlock.hidden[n] == "1" and true or nil
  end
  local function HideAway(f)
    if not f or f.octoHidden or not f.SetParent then return end
    f.octoHidden = f:GetParent() or UIParent
    f:SetParent(hider)
  end
  local function HideBack(f)
    if not f or not f.octoHidden then return end
    f:SetParent(f.octoHidden)
    f.octoHidden = nil
    -- (1.12: a frame out of a hidden parent is seen again only after hide + show)
    if f:IsShown() then f:Hide() f:Show() end
  end
  local function ApplyHidden()
    for name, v in pairs(C.unlock.hidden or {}) do
      local f = (pfUI.movables and pfUI.movables[name]) or _G[name]
      if v == "1" and f and not (pfUI.unlock and pfUI.unlock:IsShown()) then HideAway(f) end
    end
  end
  pfUI.unlockHidden = { IsHidden = IsHiddenFrame, Away = HideAway, Back = HideBack, Apply = ApplyHidden }
  -- at login, and again a little later for frames made after the first
  local hidewatch = CreateFrame("Frame")
  hidewatch:RegisterEvent("PLAYER_ENTERING_WORLD")
  hidewatch:SetScript("OnEvent", function() ApplyHidden() this.again = GetTime() + 2 this:Show() end)
  hidewatch:SetScript("OnUpdate", function()
    if (this.again or 0) > GetTime() then return end
    this:Hide()
    ApplyHidden()
  end)

  local matchFrom   -- the box Alt-clicked first: its size goes to the next one
  local NiceLabel   -- (below)
  local function Paint(d, mode)
    if not d then return end
    if not d.backdrop then CreateBackdrop(d, nil, nil, .8) end
    if d == matchFrom and mode ~= "hover" then mode = "source" end
    local off = IsHiddenFrame(d.frame)
    if mode == "normal" and off then mode = "off" end
    -- a hidden frame's box says so (tall boxes keep their one-letter-a-line label)
    if d.text and d.label and d.off ~= off then
      d.off = off
      local label = NiceLabel(d.label)
      if d:GetHeight() > (2 * d:GetWidth()) then label = strvertical(label)
      elseif off then label = label .. "\n|cffff8080" .. T["(hidden)"] .. "|r" end
      d.text:SetText(label)
    end
    local p = PAINT[mode] or PAINT.normal
    d.backdrop:SetBackdropColor(p[1], p[2], p[3], p[4])
    d.backdrop:SetBackdropBorderColor(p[5], p[6], p[7], p[8])
    if d.text then d.text:SetTextColor(p[9], p[10], p[11], 1) end
  end

  -- "pfPlayerCastbar" -> "Player Castbar", "pfRaidCluster" -> "Raid Frames"
  local NICE = { RaidCluster = "Raid Frames", Meter1 = "Meter 1", Meter2 = "Meter 2", UITracking = "Tracking",
                 ChatInputBox = "Chat Input", CombatTextIncoming = "Combat Text: Incoming",
                 CombatTextOutgoing = "Combat Text: Outgoing", CombatTextHealing = "Combat Text: Healing",
                 CombatTextNotes = "Combat Text: Notes", CombatTextExtra = "Combat Text: Extra" }
  function NiceLabel(label)
    if NICE[label] then return NICE[label] end
    local s = string.gsub(label, "(%l)(%u)", "%1 %2")
    s = string.gsub(s, "(%a)(%d)", "%1 %2")
    s = string.gsub(s, "(%d)(%a)", "%1 %2")
    return s
  end

  local ShowSize -- (below: the box's size readout)

  local function SaveScale(frame, scale)
    frame:SetScale(scale)

    if not C.position[frame:GetName()] then
      C.position[frame:GetName()] = {}
    end
    C.position[frame:GetName()]["scale"] = scale
    -- octo: a frame whose module keeps its own size setting (action bars)
    -- takes the new size there too, so its next refresh keeps it
    if frame.OnScale then frame:OnScale(scale) end

    if frame.drag then ShowSize(frame.drag) end
  end

  local function SavePosition(frame)
    SaveMovable(frame)
    UpdateMovable(frame)
  end

  -- [ grid ]
  -- Square cells, GetScreenWidth() / unlock.gridsize wide, counted out from
  -- the screen centre so the two accent-coloured centre lines are exact.
  -- One grid frame per size, kept for when the size is picked again.
  local function GridStep()
    return GetScreenWidth() / (tonumber(C.unlock.gridsize) or 128)
  end

  local function DrawGrid()
    local cells = tonumber(C.unlock.gridsize) or 128
    pfUI.unlock.grids = pfUI.unlock.grids or {}
    for size, grid in pairs(pfUI.unlock.grids) do grid:Hide() end
    if pfUI.unlock.grids[cells] then
      pfUI.unlock.grids[cells]:Show()
      return pfUI.unlock.grids[cells]
    end

    local grid = CreateFrame("Frame", "pfUnlockGrid" .. cells, pfUI.unlock)
    grid:SetAllPoints(pfUI.unlock)
    pfUI.unlock.grids[cells] = grid

    local size = 1
    local width, height = GetScreenWidth(), GetScreenHeight()
    local step = width / cells
    local cx, cy = width / 2, height / 2
    local ar, ag, ab = GetAccentColor()

    local function Line(center, vertical, pos)
      local line = grid:CreateTexture(nil, center and "BORDER" or "BACKGROUND")
      if center then
        line:SetTexture(ar, ag, ab, .8)
      else
        line:SetTexture(0, 0, 0, .5)
      end
      if vertical then
        line:SetPoint("TOPLEFT", grid, "TOPLEFT", pos - size/2, 0)
        line:SetPoint("BOTTOMRIGHT", grid, "BOTTOMLEFT", pos + size/2, 0)
      else
        line:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 0, pos + size/2)
        line:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", 0, pos - size/2)
      end
    end

    Line(true, true, cx)
    Line(true, false, cy)
    for i = 1, ceil(cx / step) do
      Line(false, true, cx - i*step)
      Line(false, true, cx + i*step)
    end
    for i = 1, ceil(cy / step) do
      Line(false, false, cy - i*step)
      Line(false, false, cy + i*step)
    end

    return grid
  end

  -- [ snapping ]
  -- While a frame is dragged the outer edges of its box (frame + border) and
  -- its centre are compared with the outer edges and centres of every other
  -- mover, the screen edges and centre, then the grid lines; within SNAP
  -- pixels the nearest one pulls the frame onto it (ElvUI's sticky frames)
  -- and an accent guide line shows it. Alt or the top bar's "Snap" box turns
  -- it off. All in UIParent units.
  local SNAP = 10

  local function UIScale(frame)
    return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
  end

  -- outer left, right, centre-x, bottom, top, centre-y in UIParent units:
  -- the boxes draw their border outside the frame, so snapping the outer
  -- edges makes two boxes sit flush instead of overlapping by the border
  local function Edges(frame)
    local l, r, b, t = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop()
    if not l or not r or not b or not t then return end
    local s = UIScale(frame)
    local bd = (default_border or 0) * s
    l, r, b, t = l*s - bd, r*s + bd, b*s - bd, t*s + bd
    return l, r, (l+r)/2, b, t, (b+t)/2
  end

  local function InSelection(frame)
    for _, f in pairs(pfUI.unlock.selection) do
      if f == frame then return true end
    end
  end

  -- [ locks ]
  -- octo (user, 25 Oct 2026: "I have undocked my mana bar ... it wont lock
  -- back ... you should be able to lock the plate to another as it was or ...
  -- lock other plates to group them"). A frame locked to another is saved
  -- on that frame's corner (C.position attach / relpoint, api.lua) and moves
  -- with it. A frame's home: what its default place hangs on (pfDruidMana
  -- on pfPlayer), its posdata from UpdateMovable.
  local function LockedTo(f)
    local pos = C.position[f:GetName() or ""]
    return pos and pos.attach and _G[pos.attach]
  end
  local function HomeOf(f)
    local p = f.posdata and f.posdata.pos and f.posdata.pos[1]
    local rel = p and p[2]
    if type(rel) == "string" then rel = _G[rel] end
    if type(rel) == "table" and rel ~= UIParent and rel ~= f and rel.GetName and rel:GetName() then return rel end
  end
  -- what f moves with: its lock, or its home while on its default place
  local function Holder(f)
    if C.position[f:GetName() or ""] then return LockedTo(f) end
    return HomeOf(f)
  end
  -- is f (through its holders) moved by one of these / by target
  local function HeldBy(f, test)
    local t, n = Holder(f), 0
    while t and n < 20 do
      if test(t) then return true end
      t, n = Holder(t), n + 1
    end
  end

  -- best move (delta) of one of the values in mine onto a target line;
  -- frame and screen lines win over grid lines (ElvUI's sticky frames)
  local function Nearest(mine, targets, gridpos, best, bestline)

    for _, v in pairs(mine) do
      for _, t in pairs(targets) do
        if abs(t - v) < abs(best) then best, bestline = t - v, t end
      end
    end
    if bestline or not gridpos then return best, bestline end
    for _, v in pairs(mine) do
      local t = gridpos(v)
      if abs(t - v) < abs(best) then best, bestline = t - v, t end
    end
    return best, bestline
  end

  -- [ mirror lines ]
  -- octo (user, 26 Oct 2026: "our own lines ... mirrored on both X and Y ...
  -- if you move one the other moves in line with the opposite bar ... make
  -- these lines snappable"). Two orange pairs: a vertical pair the same way
  -- either side of the screen's middle, a horizontal pair the same way above
  -- and below it. Frames snap to them; drag a tab at a line's end to move the
  -- pair (it snaps to box edges too), right-click a tab to put it back.
  -- C.unlock.mirror on / off, mirrorx / mirrory = distance from the middle.
  local function MirrorOn() return C.unlock.mirror == "1" end
  local function MirrorDist(axis)
    local v = tonumber(axis == "x" and C.unlock.mirrorx or C.unlock.mirrory)
    if v then return v end
    return (axis == "x" and GetScreenWidth() or GetScreenHeight()) / 4
  end
  -- the four lines: { left x, right x }, { bottom y, top y } (UIParent units)
  local function MirrorLines()
    local w, h = GetScreenWidth(), GetScreenHeight()
    local dx, dy = MirrorDist("x"), MirrorDist("y")
    return { w/2 - dx, w/2 + dx }, { h/2 - dy, h/2 + dy }
  end

  -- snap for a box with these outer edges: dx, dy (UIParent units) and the
  -- guide lines, or nil when snapping is off. keepx / keepy = the lines it
  -- snapped to last: kept while still in reach, so the guide does not jump
  -- between lines a pixel apart while dragging
  local function SnapBox(frame, l, r, b, t, keepx, keepy)
    if C.unlock.snap ~= "1" or IsAltKeyDown() then return end
    local cx, cy = (l+r)/2, (b+t)/2

    local width, height = GetScreenWidth(), GetScreenHeight()
    local xs, ys = { 0, width, width/2 }, { 0, height, height/2 }
    if MirrorOn() then
      local mx, my = MirrorLines()
      table.insert(xs, mx[1]) table.insert(xs, mx[2])
      table.insert(ys, my[1]) table.insert(ys, my[2])
    end
    for name, other in pairs(pfUI.movables) do
      other = other or _G[name]
      -- (frames that move with the selection are no lines to snap to)
      if other and other ~= frame and other:IsShown() and not InSelection(other) and not HeldBy(other, InSelection) then
        local ol, or_, ocx, ob, ot, ocy = Edges(other)
        if ol then
          table.insert(xs, ol) table.insert(xs, or_) table.insert(xs, ocx)
          table.insert(ys, ob) table.insert(ys, ot) table.insert(ys, ocy)
        end
      end
    end

    local step = GridStep()
    local gridx = function(v) return width/2 + floor((v - width/2) / step + .5) * step end
    local gridy = function(v) return height/2 + floor((v - height/2) / step + .5) * step end

    local dx, xline = Nearest({ l, r, cx }, xs, gridx, SNAP + 1)
    local dy, yline = Nearest({ b, t, cy }, ys, gridy, SNAP + 1)
    if abs(dx) > SNAP then dx, xline = 0, nil end
    if abs(dy) > SNAP then dy, yline = 0, nil end
    -- stay on the last line while it is in reach (a few pixels more than the
    -- snap), unless another line is right on an edge
    if keepx and keepx ~= xline and abs(dx) > 1 then
      local kd = Nearest({ l, r, cx }, { keepx }, nil, SNAP + 5)
      if abs(kd) <= SNAP + 4 then dx, xline = kd, keepx end
    end
    if keepy and keepy ~= yline and abs(dy) > 1 then
      local kd = Nearest({ b, t, cy }, { keepy }, nil, SNAP + 5)
      if abs(kd) <= SNAP + 4 then dy, yline = kd, keepy end
    end
    return dx, dy, xline, yline
  end

  -- the snap of a frame where it is now
  local function GetSnap(frame)
    local l, r, _, b, t = Edges(frame)
    if not l then return end
    return SnapBox(frame, l, r, b, t)
  end

  local function ShowGuides(xline, yline)
    local g = pfUI.unlock.guides
    if not g then
      g = {}
      g.x = pfUI.unlock:CreateTexture(nil, "OVERLAY")
      g.y = pfUI.unlock:CreateTexture(nil, "OVERLAY")
      pfUI.unlock.guides = g
    end
    local ar, ag, ab = GetAccentColor()
    g.x:SetTexture(ar, ag, ab, 1)
    g.y:SetTexture(ar, ag, ab, 1)
    if xline then
      g.x:ClearAllPoints()
      g.x:SetPoint("TOPLEFT", pfUI.unlock, "TOPLEFT", xline - 1, 0)
      g.x:SetPoint("BOTTOMRIGHT", pfUI.unlock, "BOTTOMLEFT", xline + 1, 0)
      g.x:Show()
    else
      g.x:Hide()
    end
    if yline then
      g.y:ClearAllPoints()
      g.y:SetPoint("TOPLEFT", pfUI.unlock, "BOTTOMLEFT", 0, yline + 1)
      g.y:SetPoint("BOTTOMRIGHT", pfUI.unlock, "BOTTOMRIGHT", 0, yline - 1)
      g.y:Show()
    else
      g.y:Hide()
    end
  end

  -- [ dragging ]
  -- The selection is moved by hand from the cursor instead of the client's
  -- StartMoving, so the snap can pull it while dragging, and the saved
  -- position is worked out from these numbers: the client may report a
  -- moved frame's edges only on the next screen update.
  local drag = {}

  local function Cursor()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
  end

  local function PlaceBoxes(dx, dy)
    for _, box in ipairs(drag.boxes) do
      box.frame:ClearAllPoints()
      box.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (box.il + dx) / box.s, (box.ib + dy) / box.s)
    end
  end

  local function DragOnUpdate()
    local cx, cy = Cursor()
    local dx, dy = cx - drag.cx, cy - drag.cy
    local lead = drag.boxes[1]
    local sx, sy, xline, yline = SnapBox(lead.frame, lead.l + dx, lead.r + dx, lead.b + dy, lead.t + dy, drag.xline, drag.yline)
    if sx then dx, dy = dx + sx, dy + sy end
    drag.xline, drag.yline = xline, yline
    ShowGuides(xline, yline)
    if dx == drag.dx and dy == drag.dy then return end
    drag.dx, drag.dy = dx, dy
    PlaceBoxes(dx, dy)
  end

  -- the saved anchor follows the screen third the selection ends up in
  local function AnchorFor(l, r, b, t)
    local width, height = GetScreenWidth(), GetScreenHeight()
    local mx, my = (l + r) / 2, (b + t) / 2
    local h = mx < width/3 and "LEFT" or mx > width*2/3 and "RIGHT" or ""
    local v = my > height*2/3 and "TOP" or my < height/3 and "BOTTOM" or ""
    if v .. h == "" then return "CENTER" end
    return v .. h
  end

  -- offsets of a box (inner edges, UIParent units) for that anchor, in frame units
  local function AnchorOffsets(anchor, l, r, b, t, s)
    local width, height = GetScreenWidth(), GetScreenHeight()
    local x, y
    if strfind(anchor, "LEFT") then x = l elseif strfind(anchor, "RIGHT") then x = r - width else x = (l + r)/2 - width/2 end
    if strfind(anchor, "TOP") then y = t - height elseif strfind(anchor, "BOTTOM") then y = b else y = (b + t)/2 - height/2 end
    return x / s, y / s
  end

  -- [ sizes ]
  -- octo (user, 25 Oct 2026: "when resizing ... they jump in size between
  -- its not smooth ... hard to match sizes to other bars"). The wheel changed
  -- the scale by 0.1 a notch (a 500 px bar jumped 50 px) and the saved place,
  -- kept in the frame's own units, moved with the scale. Now a notch is 2%
  -- (Shift 10%, Ctrl 0.5%), the point the frame is saved at stays put
  -- (KeepPlaces), the box shows its size while it changes, and the raid
  -- frames get a real width and height (raid.lua lays the grid out again)
  -- instead of a scale that left uneven gaps between them.
  local SZ = { MIN = .3, MAX = 3 }
  function SZ.Step(shift, ctrl)
    if shift then return .1 elseif ctrl then return .005 end
    return .02
  end
  function SZ.Next(cur, dir, step)
    local v = (tonumber(cur) or 1) + (dir or 0) * (step or .02)
    if v < SZ.MIN then v = SZ.MIN elseif v > SZ.MAX then v = SZ.MAX end
    return floor(v * 1000 + .5) / 1000
  end
  -- a frame's anchor point on screen (UIParent units) from its offsets
  -- (frame units at scale s), and back
  function SZ.Point(anchor, x, y, s, w, h)
    local px, py = x * s, y * s
    if strfind(anchor, "RIGHT") then px = w + px elseif not strfind(anchor, "LEFT") then px = w / 2 + px end
    if strfind(anchor, "TOP") then py = h + py elseif not strfind(anchor, "BOTTOM") then py = h / 2 + py end
    return px, py
  end
  function SZ.Offsets(anchor, px, py, s, w, h)
    if strfind(anchor, "RIGHT") then px = px - w elseif not strfind(anchor, "LEFT") then px = px - w / 2 end
    if strfind(anchor, "TOP") then py = py - h elseif not strfind(anchor, "BOTTOM") then py = py - h / 2 end
    return px / s, py / s
  end
  -- raid.lua: cluster width = cols * (frame + 2 borders + gap) - gap
  function SZ.RaidFrameWidth(clusterw, cols, gap, border)
    return (clusterw + gap) / cols - gap - 2 * border
  end
  -- a raid frame one step wider or narrower; the height follows (ratio =
  -- height / width when the sizing started, so the shape does not drift)
  function SZ.RaidStep(w, ratio, dir, step)
    local nw = w + dir * step
    if nw < 20 then nw = 20 elseif nw > 400 then nw = 400 end
    local nh = floor(nw * ratio + .5)
    if nh < 4 then nh = 4 elseif nh > 100 then nh = 100 end
    return nw, nh
  end
  -- columns and rows of the raid grid ("5x8")
  function SZ.RaidGrid(layout)
    local _, _, x, y = string.find(layout or "", "(%d+)x(%d+)")
    return tonumber(x) or 5, tonumber(y) or 8
  end

  local function ScreenSize(f)
    local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return (f:GetWidth() or 0) * s, (f:GetHeight() or 0) * s, s
  end

  -- where a frame is saved, on screen: from its saved offsets, never from its
  -- edges (the client reports those a screen update late). The point from
  -- the last resize is reused while the saved numbers are the ones it left,
  -- so pfUI's whole-number rounding does not creep in notch after notch.
  -- Frames on their default place (often tied to another frame) have none.
  local function FixedPoint(f)
    local pos = C.position[f:GetName() or ""]
    if not pos or not pos.xpos or not pos.ypos then return end
    -- (a frame locked to another stays on that one's corner)
    if pos.attach or pos.parent and pos.parent ~= "UIParent" or f:GetParent() ~= UIParent then return end
    local fix = f.unlockFix
    if fix and fix.anchor == pos.anchor and fix.xpos == pos.xpos and fix.ypos == pos.ypos then
      return fix.anchor, fix.px, fix.py
    end
    local a = pos.anchor or "TOPLEFT"
    local px, py = SZ.Point(a, tonumber(pos.xpos) or 0, tonumber(pos.ypos) or 0, UIScale(f), GetScreenWidth(), GetScreenHeight())
    return a, px, py
  end

  -- fn() changes the size of these frames; each stays on the point it is
  -- saved at (the anchor of its screen third: a bar at the bottom grows up)
  local function KeepPlaces(frames, fn)
    local keep = {}
    for _, f in pairs(frames) do
      local a, px, py = FixedPoint(f)
      if a then table.insert(keep, { f, a, px, py }) end
    end
    fn()
    local w, h = GetScreenWidth(), GetScreenHeight()
    for _, k in ipairs(keep) do
      local f, a, px, py = k[1], k[2], k[3], k[4]
      local x, y = SZ.Offsets(a, px, py, UIScale(f), w, h)
      f:ClearAllPoints()
      f:SetPoint(a, UIParent, a, x, y)
      SaveMovable(f)
      local pos = C.position[f:GetName()]
      f.unlockFix = { anchor = pos.anchor, xpos = pos.xpos, ypos = pos.ypos, px = px, py = py }
      UpdateMovable(f)
      if f.OnMove then f:OnMove() end
    end
  end

  local function BarIndex(f)
    local AB = pfUI.barsOcto
    return AB and AB.BarIndex and AB.BarIndex(f)
  end

  -- the readout: on the box while it changes or the mouse is on it, and in
  -- the nudge box
  local function SizeOnly(f)
    local w, h = ScreenSize(f)
    local txt = floor(w + .5) .. " x " .. floor(h + .5)
    if f == _G.pfRaidCluster then
      local cfg = C.unitframes.raid
      local cols, rows = SZ.RaidGrid(cfg.raidlayout)
      return txt .. "\n" .. T["each"] .. " " .. (cfg.width or "?") .. " x " .. (cfg.height or "?") .. ", " .. cols .. " x " .. rows
    end
    local pct = floor(f:GetScale() * 100 + .5) .. "%"
    local i = BarIndex(f)
    if i then
      local px = (tonumber(C.bars["bar" .. i].icon_size) or 0) * f:GetScale()
      return txt .. "\n" .. pct .. ", " .. T["buttons"] .. " " .. (floor(px * 10 + .5) / 10) .. " px"
    end
    return txt .. "\n" .. pct
  end
  -- (and what it is locked to)
  local function SizeText(f)
    local to = Holder(f)
    if not to then return SizeOnly(f) end
    return SizeOnly(f) .. "\n|cff88ccff" .. T["on"] .. " " .. NiceLabel(to.drag and to.drag.label or to:GetName() or "?") .. "|r"
  end

  -- the one line under the numbers: button size, raid grid, what it is on
  local function SizeInfo(f)
    local info = {}
    if f == _G.pfRaidCluster then
      local cfg = C.unitframes.raid
      local cols, rows = SZ.RaidGrid(cfg.raidlayout)
      table.insert(info, T["each"] .. " " .. (cfg.width or "?") .. " x " .. (cfg.height or "?") .. ", " .. cols .. " x " .. rows)
    end
    local i = BarIndex(f)
    if i then
      local px = (tonumber(C.bars["bar" .. i].icon_size) or 0) * f:GetScale()
      table.insert(info, T["buttons"] .. " " .. (floor(px * 10 + .5) / 10) .. " px")
    end
    local to = Holder(f)
    if to then table.insert(info, "|cff88ccff" .. T["on"] .. " " .. NiceLabel(to.drag and to.drag.label or to:GetName() or "?") .. "|r") end
    return table.concat(info, "  ")
  end

  local Resize, SetBoxSize -- (below)

  local function SizeOnUpdate()
    local sb = this.sizebox
    -- (kept while the mouse is on it or a number is being typed)
    -- (the gap between the box and its editor counts as the editor: user, 26 Oct
    -- 2026, "it disappears when i leave the frame" on the way to the editor)
    if sb and sb:IsShown() and (sb.editing or MouseIsOver(sb, 10, -10, -4, 4)) then this.sizeUntil = GetTime() + .4 return end
    if this.sizeUntil and GetTime() < this.sizeUntil then return end
    if this.hover then return end
    this.sizeUntil = nil
    if sb then sb:Hide() end
    this:SetScript("OnUpdate", nil)
  end

  -- octo (user, 25 Oct 2026: "you should be [able to] edit here for quick
  -- resizing ... make it clear small and easy"): the tag under the box is a
  -- small editor - width x height and the scale in %, typed (Enter) or
  -- turned with the mouse wheel over the number (Shift: 10 a notch), and
  -- - / + for one notch of the box's own wheel.
  local function NumBox(sb, width, apply, step)
    local e = CreateFrame("EditBox", nil, sb)
    e:SetWidth(width)
    e:SetHeight(16)
    e:SetAutoFocus(false)
    e:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
    e:SetJustifyH("CENTER")
    e:SetTextColor(1, .82, 0)
    e:SetTextInsets(2, 2, 0, 0)
    CreateBackdrop(e, nil, true)
    e:SetBackdropColor(0, 0, 0, .85)
    e.apply, e.step = apply, step
    e:SetScript("OnEditFocusGained", function() this:GetParent().editing = this this:HighlightText() end)
    e:SetScript("OnEditFocusLost", function()
      if this:GetParent().editing == this then this:GetParent().editing = nil end
    end)
    e:SetScript("OnEscapePressed", function() this:ClearFocus() ShowSize(this:GetParent().d) end)
    e:SetScript("OnEnterPressed", function()
      local v = tonumber((string.gsub(this:GetText() or "", "[^%d%.]", "")))
      this:ClearFocus()
      if v then this.apply(v) end
      ShowSize(this:GetParent().d)
    end)
    e:EnableMouseWheel(true)
    e:SetScript("OnMouseWheel", function()
      local v = tonumber((string.gsub(this:GetText() or "", "[^%d%.]", "")))
      if not v then return end
      this:ClearFocus()
      this.apply(v + (arg1 or 0) * this.step * (IsShiftKeyDown() and 10 or 1))
      ShowSize(this:GetParent().d)
    end)
    -- (a tooltip on the numbers: what they do)
    e:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
      GameTooltip:SetText(this.tipTitle or "", 1, 1, 1)
      GameTooltip:AddLine(T["Type a number and press Enter, or turn the mouse wheel over it (Shift: 10 at a time)."], .8, .8, .8, 1)
      GameTooltip:Show()
    end)
    e:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return e
  end

  local function SmallButton(sb, text, run)
    local b = CreateFrame("Button", nil, sb)
    b:SetWidth(16)
    b:SetHeight(16)
    CreateBackdrop(b, nil, true)
    b:SetBackdropColor(.05, .05, .05, .9)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(pfUI.font_default, C.global.font_size + 1, "OUTLINE")
    b.text:SetPoint("CENTER", 0, 1)
    b.text:SetText(text)
    b.text:SetTextColor(1, .82, 0)
    b:SetScript("OnEnter", function() this:SetBackdropBorderColor(1, .82, 0, 1) end)
    b:SetScript("OnLeave", function() this:SetBackdropBorderColor(GetStringColor(C.appearance.border.color)) end)
    b:SetScript("OnClick", run)
    return b
  end

  local function SizeEditor(d)
    local sb = CreateFrame("Frame", nil, d)
    sb.d = d
    sb:SetFrameLevel(d:GetFrameLevel() + 4)
    sb:SetWidth(150)
    sb:SetHeight(44)
    sb:EnableMouse(true)
    CreateBackdrop(sb, nil, true, .92)
    local function Font(fs, r, g, b)
      fs:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      fs:SetTextColor(r, g, b)
      return fs
    end
    -- width x height
    sb.wbox = NumBox(sb, 44, function(v) SetBoxSize(d.frame, v, nil) end, 1)
    sb.wbox.tipTitle = T["Width"]
    sb.wbox:SetPoint("TOPRIGHT", sb, "TOP", -8, -5)
    sb.xmark = Font(sb:CreateFontString(nil, "OVERLAY"), .6, .6, .6)
    sb.xmark:SetPoint("LEFT", sb.wbox, "RIGHT", 3, 0)
    sb.xmark:SetText("x")
    sb.hbox = NumBox(sb, 44, function(v) SetBoxSize(d.frame, nil, v) end, 1)
    sb.hbox.tipTitle = T["Height"]
    sb.hbox:SetPoint("TOPLEFT", sb, "TOP", 8, -5)
    -- - [ % ] +
    sb.pbox = NumBox(sb, 44, function(v) SetBoxSize(d.frame, nil, nil, v / 100) end, 1)
    sb.pbox.tipTitle = T["Scale in %"]
    sb.pbox:SetPoint("TOP", sb, "TOP", 0, -24)
    sb.minus = SmallButton(sb, "-", function() Resize(d, -1) end)
    sb.minus:SetPoint("RIGHT", sb.pbox, "LEFT", -6, 0)
    sb.plus = SmallButton(sb, "+", function() Resize(d, 1) end)
    sb.plus:SetPoint("LEFT", sb.pbox, "RIGHT", 6, 0)
    sb.info = Font(sb:CreateFontString(nil, "OVERLAY"), .8, .8, .8)
    sb.info:SetPoint("TOP", sb, "TOP", 0, -45)
    return sb
  end

  -- the editor under the box (over it near the bottom of the screen): the
  -- box's own label stays as it is
  ShowSize = function(d, hold)
    if not d or not d.frame then return end
    if not d.sizebox then d.sizebox = SizeEditor(d) end
    local sb = d.sizebox
    -- (the same size on screen however the frame is scaled)
    local s = UIScale(d)
    if s > 0 then sb:SetScale(1 / s) end
    local w, h = ScreenSize(d.frame)
    if sb.editing ~= sb.wbox then sb.wbox:SetText(floor(w + .5)) end
    if sb.editing ~= sb.hbox then sb.hbox:SetText(floor(h + .5)) end
    if sb.editing ~= sb.pbox then sb.pbox:SetText(floor(d.frame:GetScale() * 100 + .5) .. "%") end
    -- (the info panels have no scale: - / + change their width)
    if d.frame == _G.pfPanelLeft or d.frame == _G.pfPanelRight then sb.pbox:Hide() else sb.pbox:Show() end
    local info = SizeInfo(d.frame)
    sb.info:SetText(info)
    sb:SetWidth(math.max(150, (sb.info:GetStringWidth() or 0) + 16))
    sb:SetHeight(info ~= "" and 60 or 44)
    sb:ClearAllPoints()
    local bottom = d:GetBottom()
    if bottom and bottom * UIScale(d) < 60 then
      sb:SetPoint("BOTTOM", d, "TOP", 0, 4)
    else
      sb:SetPoint("TOP", d, "BOTTOM", 0, -4)
    end
    sb:Show()
    d.sizeUntil = GetTime() + (hold or 1.5)
    -- (not while it is dragged: the drag runs on this OnUpdate)
    if not (drag.boxes and drag.boxes[1]) then d:SetScript("OnUpdate", SizeOnUpdate) end
    if pfUI.unlock.dock and pfUI.unlock.dock.parent == d and pfUI.unlock.dock.size then
      pfUI.unlock.dock.size:SetText(SizeText(d.frame))
    end
  end

  -- the raid frames: a pixel wider or narrower a notch (Shift: 5), the
  -- height in step, every frame laid out again by raid.lua
  local function ResizeRaid(d, dir, step)
    local cluster, raid = d.frame, pfUI.uf and pfUI.uf.raid
    if not raid or not raid.UpdateConfig then return end
    local cfg = C.unitframes.raid
    local w, h = tonumber(cfg.width) or 50, tonumber(cfg.height) or 20
    -- a scale left from before: becomes the frames' real size
    local sc = cluster:GetScale()
    if math.abs(sc - 1) > .001 then w, h = floor(w * sc + .5), floor(h * sc + .5) end
    if not (d.raidShape and d.raidShape.w == w and d.raidShape.h == h) then
      d.raidShape = { ratio = h / math.max(1, w) }
    end
    local nw, nh = SZ.RaidStep(w, d.raidShape.ratio, dir, step)
    d.raidShape.w, d.raidShape.h = nw, nh
    KeepPlaces({ cluster }, function()
      if math.abs(sc - 1) > .001 then
        cluster:SetScale(1)
        if C.position[cluster:GetName()] then C.position[cluster:GetName()].scale = nil end
      end
      cfg.width, cfg.height = tostring(nw), tostring(nh)
      raid:UpdateConfig()
      -- (the options' preview of the raid frames too)
      local UF = pfUI.ufOcto
      if UF and UF.mini and UF.mini.Reconfigure then UF.mini.Reconfigure("raid") end
    end)
    ShowSize(d)
  end

  -- one notch of the wheel (dir 1 / -1) or of the nudge box's - / +
  Resize = function(d, dir)
    if d.frame == _G.pfRaidCluster then
      ResizeRaid(d, dir, IsShiftKeyDown() and 5 or 1)
      return
    end
    local frame = d.frame
    -- (the info panels: 10 px wider / narrower a notch, Shift 1 px; never a scale)
    if frame == _G.pfPanelLeft or frame == _G.pfPanelRight then
      local w, _, s = ScreenSize(frame)
      SetBoxSize(frame, w + dir * (IsShiftKeyDown() and 1 or 10) * s, nil)
      ShowSize(d)
      return
    end
    local scale = SZ.Next(frame:GetScale(), dir, SZ.Step(IsShiftKeyDown(), IsControlKeyDown()))
    pfUI.unlock.selection = GetFrames(frame)
    KeepPlaces(pfUI.unlock.selection, function()
      for _, f in pairs(pfUI.unlock.selection) do SaveScale(f, scale) end
    end)
    -- repaint hackfix for panels
    if pfUI.panel and pfUI.chat and pfUI.panel.left and pfUI.chat.left and pfUI.panel.right and pfUI.chat.right then
      pfUI.panel.left:SetScale(pfUI.chat.left:GetScale())
      pfUI.panel.right:SetScale(pfUI.chat.right:GetScale())
    end
    if frame.OnMove then frame:OnMove() end
    ShowSize(d)
  end

  local function GetConfigTable(dlabel)
    local cat, conf, card = nil, nil, nil
    for label, config in pairs(frame_configs) do
      if string.gsub(dlabel, label, "") == "" then
        cat, conf, card = config[1], config[2], config[3]
      end
    end

    return cat, conf, card
  end

  local function OpenConfigDialog(category, view, card)
    -- octo: the OctoBG-style window opens the page itself
    local O = pfUI.octoui and pfUI.octoui.Options
    if O and O.Open and O.frame then
      pfUI.gui.keepLayout = true
      O:Open(category, view)
      -- (a card of that page: opened, scrolled to and flashed)
      if card and pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection(category, card) end
      pfUI.gui.keepLayout = nil
      return
    end

    pfUI.gui:Show()

    if not pfUI.gui.frames[category] then return end
    pfUI.gui.frames[category]:Click()

    if not view or not pfUI.gui.frames[category][view] then return end
    pfUI.gui.frames[category][view]:Click()
  end

  local function UpdateDockValues()
    if not pfUI.unlock.dock:IsShown() then return end

    local dock = pfUI.unlock.dock
    local drag = dock.parent
    local frame = drag.frame

    -- update dock position
    SetAutoPoint(dock, drag, default_border*2+2)

    -- update dock entries
    dock.title:SetText(drag.label)
    if pfUI_config["position"] and pfUI_config["position"][drag.fname] and pfUI_config["position"][drag.fname]["xpos"] then
      dock.xcoord:SetText(pfUI_config["position"][drag.fname]["xpos"])
      dock.ycoord:SetText(pfUI_config["position"][drag.fname]["ypos"])
      local anchor = pfUI_config["position"][drag.fname]["anchor"] or "TOPLEFT"

      for id, k in pairs(anchors) do
        -- get human readable
        local value, text = strsplit(":", k)
        text = text or value

        if value == anchor then
          UIDropDownMenu_SetSelectedID(pfUI.unlock.dock.anchor, id, 0)
          UIDropDownMenu_SetText(text, pfUI.unlock.dock.anchor)
        end
      end

      dock.reset:SetText(T["Reset"])

      dock.up:Enable()
      dock.down:Enable()
      dock.left:Enable()
      dock.right:Enable()

      dock.up.texture:SetVertexColor(1,.8,0)
      dock.down.texture:SetVertexColor(1,.8,0)
      dock.left.texture:SetVertexColor(1,.8,0)
      dock.right.texture:SetVertexColor(1,.8,0)
    else
      dock.reset:SetText(T["Unlock"])
      dock.xcoord:SetText(T["N/A"])
      dock.ycoord:SetText(T["N/A"])

      dock.up:Disable()
      dock.down:Disable()
      dock.left:Disable()
      dock.right:Disable()

      dock.up.texture:SetVertexColor(.4,.4,.4)
      dock.down.texture:SetVertexColor(.4,.4,.4)
      dock.left.texture:SetVertexColor(.4,.4,.4)
      dock.right.texture:SetVertexColor(.4,.4,.4)
    end

    -- octo: the size readout
    if dock.size then dock.size:SetText(SizeText(frame)) end

    if dock.PaintHide then dock.PaintHide() end

    -- update config button
    local cat, conf = GetConfigTable(drag.label)
    if cat then
      dock.config:Enable()
    else
      dock.config:Disable()
    end
  end

  local function SetDockToFrame(frame)
    if pfUI.unlock.dock.parent then
      -- reset previous border color
      Paint(pfUI.unlock.dock.parent, "normal")
    end

    -- add the new frame
    pfUI.unlock.dock.parent = frame

    if frame then
      Paint(pfUI.unlock.dock.parent, "picked")
      pfUI.unlock.dock:Show()
      UpdateDockValues()
    else
      pfUI.unlock.dock:Hide()
    end
  end

  local function DraggerOnMouseWheel()
    Resize(this, (arg1 or 0) > 0 and 1 or -1)
    QueueFunction(UpdateDockValues)
  end

  local function DraggerOnDragStart()
    local frame = this.frame
    if this.sizebox then this.sizebox:Hide() end
    if _G.pfUnlockMatchMenu then _G.pfUnlockMatchMenu:Hide() end

    pfUI.unlock.selection = GetFrames()

    -- remember every selected box where it is now (dragged frame first)
    drag.boxes = {}
    drag.xline, drag.yline = nil, nil
    local function Add(f)
      local l, r, _, b, t = Edges(f)
      if not l then return end
      local s = UIScale(f)
      local il, ir, ib, it = f:GetLeft() * s, f:GetRight() * s, f:GetBottom() * s, f:GetTop() * s
      -- saved positions are relative to UIParent (as pfUI did on drop)
      if f:GetParent() ~= UIParent then
        f:SetParent(UIParent)
        s = UIScale(f)
      end
      table.insert(drag.boxes, { frame = f, s = s, l = l, r = r, b = b, t = t, il = il, ir = ir, ib = ib, it = it })
      Paint(f.drag, "picked")
    end
    Add(frame)
    for _, f in pairs(pfUI.unlock.selection) do
      if f ~= frame then Add(f) end
    end
    if not drag.boxes[1] then return end

    drag.cx, drag.cy = Cursor()
    drag.dx, drag.dy = 0, 0
    PlaceBoxes(0, 0)
    this:SetScript("OnUpdate", DragOnUpdate)

    if frame.OnMove then frame:OnMove() end
  end

  local function DraggerOnDragStop()
    local frame = this.frame

    this:SetScript("OnUpdate", nil)
    ShowGuides(nil, nil)
    if not drag.boxes or not drag.boxes[1] then return end

    -- where the selection ended up (inner edges, UIParent units)
    local dx, dy = drag.dx or 0, drag.dy or 0
    local left, right, bottom, top
    for _, box in ipairs(drag.boxes) do
      local l, r, b, t = box.il + dx, box.ir + dx, box.ib + dy, box.it + dy
      left = left and min(left, l) or l
      right = right and max(right, r) or r
      bottom = bottom and min(bottom, b) or b
      top = top and max(top, t) or t
    end
    local anchor = AnchorFor(left, right, bottom, top)

    -- save all frame positions
    for _, box in ipairs(drag.boxes) do
      local f = box.frame
      local x, y = AnchorOffsets(anchor, box.il + dx, box.ir + dx, box.ib + dy, box.it + dy, box.s)
      Paint(f.drag, "normal")
      f:ClearAllPoints()
      -- octo: a locked frame stays locked, on its new spot on that frame
      -- (its holder's left / bottom: where it was dropped too if it moved)
      local to = LockedTo(f)
      local tl, tb
      if to then
        for _, tbox in ipairs(drag.boxes) do
          if tbox.frame == to then tl, tb = tbox.il + dx, tbox.ib + dy end
        end
        if not tl and to:GetLeft() then tl, tb = to:GetLeft() * UIScale(to), to:GetBottom() * UIScale(to) end
      end
      if tl then
        f:SetPoint("BOTTOMLEFT", to, "BOTTOMLEFT", (box.il + dx - tl) / box.s, (box.ib + dy - tb) / box.s)
      else
        f:SetPoint(anchor, UIParent, anchor, x, y)
      end
      SavePosition(f)
      if f.OnMove then f:OnMove() end
    end
    drag.boxes = nil
    this.justDragged = true

    Paint(this, "hover")
    UpdateDockValues()
  end

  -- octo: Alt-click two boxes - the second gets the first one's size (user,
  -- 20 Oct 2026). Frames whose size is a setting get the setting (it stays
  -- after a reload): unit frames and castbars (width; height too between two
  -- of the same kind), the meter windows. Anything else is scaled to the
  -- same width.
  local SIZES = {
    pfPlayer = { "unitframes", "player" }, pfTarget = { "unitframes", "target" },
    pfTargetTarget = { "unitframes", "ttarget" }, pfTargetTargetTarget = { "unitframes", "tttarget" },
    pfPet = { "unitframes", "pet" }, pfPetTarget = { "unitframes", "ptarget" }, pfFocus = { "unitframes", "focus" },
    pfPlayerCastbar = { "castbar", "player" }, pfTargetCastbar = { "castbar", "target" }, pfFocusCastbar = { "castbar", "focus" },
  }

  local function Say(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: " .. msg)
  end

  -- what a box is, for Match: boxes of the same kind are offered first
  local function KindOf(f)
    local name = f:GetName() or ""
    if BarIndex(f) then return "bar" end
    if SIZES[name] then return SIZES[name][1] end
    if string.find(name, "^pfMeter%d$") then return "meter" end
    if f == _G.pfRaidCluster then return "raid" end
    return "other"
  end

  local function MatchSize(from, to)
    local fw, fh = ScreenSize(from)
    local _, _, ts = ScreenSize(to)
    if fw <= 0 or ts <= 0 then return end
    local w, h = round(fw / ts), round(fh / ts)
    local fk, tk = SIZES[from:GetName()], SIZES[to:GetName()]
    local _, _, meter = string.find(to:GetName() or "", "^pfMeter(%d)$")
    -- octo (25 Oct 2026): two action bars - the same button size, gap and
    -- scale (pfUI.barsOcto.CopySize), so bars with the same buttons line up
    local fi, ti = BarIndex(from), BarIndex(to)
    if fi and ti then
      KeepPlaces({ to }, function()
        pfUI.barsOcto.CopySize(fi, ti)
        pfUI.bars:UpdateConfig()
      end)
      if to.drag then ShowSize(to.drag) end
      Say(NiceLabel(to.drag.label) .. " " .. T["now matches"] .. " " .. NiceLabel(from.drag.label)
        .. " (" .. T["buttons"] .. " " .. C.bars["bar" .. ti].icon_size .. " px, " .. floor(to:GetScale() * 100 + .5) .. "%)")
      return
    end
    -- the raid frames: as wide as the other box, by their own width (the
    -- grid, rows and columns stay)
    if to == _G.pfRaidCluster and pfUI.uf and pfUI.uf.raid and pfUI.uf.raid[1] then
      local cfg = C.unitframes.raid
      local cols = SZ.RaidGrid(cfg.raidlayout)
      local gap = (tonumber(cfg.raidpadding) or 0) * GetPerfectPixel()
      local _, border = GetBorderSize("unitframes")
      local extra = (pfUI.uf.raid[1]:GetWidth() or 0) - (tonumber(cfg.width) or 0)
      local nw = floor(SZ.RaidFrameWidth(fw, cols, gap, border) - extra + .5)
      if nw < 20 then nw = 20 elseif nw > 400 then nw = 400 end
      KeepPlaces({ to }, function()
        to:SetScale(1)
        if C.position[to:GetName()] then C.position[to:GetName()].scale = nil end
        cfg.width = tostring(nw)
        pfUI.uf.raid:UpdateConfig()
      end)
      if to.drag then ShowSize(to.drag) end
      Say(NiceLabel(to.drag.label) .. " " .. T["now matches"] .. " " .. NiceLabel(from.drag.label) .. " (" .. T["each"] .. " " .. nw .. " px)")
      return
    end
    -- octo (1 Nov 2026, user: "match the player frame on my target frame ...
    -- piece for piece and snap the power bar back onto frame and cast bar"):
    -- two unit frames = the bars copied (Copy from... > Size: width, heights,
    -- power bar place, textures - not the portrait; user, 1 Nov: texts, buffs
    -- and names stay each frame's own), and its cast bar matched and put under it
    -- where the other frame's cast bar sits under that one
    local UO = pfUI.ufOcto
    if fk and tk and fk[1] == "unitframes" and tk[1] == "unitframes" and UO and UO.Copy then
      -- (its scale too: a target frame sized in layout mode stayed bigger than
      -- the player's after a match, user's screenshot 1 Nov 2026)
      KeepPlaces({ to }, function()
        UO.Copy(fk[2], tk[2], "size", "^portrait")
        if math.abs((to:GetScale() or 1) - (from:GetScale() or 1)) > .001 then SaveScale(to, from:GetScale()) end
      end)
      local fcb = _G["pf" .. (from:GetName() == "pfPlayer" and "Player" or from:GetName() == "pfTarget" and "Target"
        or from:GetName() == "pfFocus" and "Focus" or "") .. "Castbar"]
      local tcb = _G["pf" .. (to:GetName() == "pfPlayer" and "Player" or to:GetName() == "pfTarget" and "Target"
        or to:GetName() == "pfFocus" and "Focus" or "") .. "Castbar"]
      local CB = pfUI.castbarOcto
      if fcb and tcb and fcb ~= tcb then
        if CB and CB.Copy then CB.Copy(SIZES[fcb:GetName()][2], SIZES[tcb:GetName()][2]) end
        local fs, ts2 = UIScale(from), UIScale(to)
        local cs, tcs = UIScale(fcb), UIScale(tcb)
        if from:GetLeft() and fcb:GetLeft() and to:GetLeft() then
          local dx = fcb:GetLeft() * cs - from:GetLeft() * fs
          local dy = fcb:GetTop() * cs - from:GetTop() * fs
          tcb:ClearAllPoints()
          tcb:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (to:GetLeft() * ts2 + dx) / tcs, (to:GetTop() * ts2 + dy) / tcs)
          SavePosition(tcb)
          if tcb.drag then ShowSize(tcb.drag) end
        end
      end
      SavePosition(to)
      if to.OnMove then to:OnMove() end
      if to.drag then ShowSize(to.drag) end
      Say(NiceLabel(to.drag and to.drag.label or to:GetName()) .. " " .. T["now matches"] .. " "
        .. NiceLabel(from.drag and from.drag.label or from:GetName()) .. " - its bars, power bar and cast bar")
      return
    end
    if tk then
      local cfg = C[tk[1]][tk[2]]
      cfg.width = tostring(w)
      to:SetWidth(w)
      if fk and fk[1] == tk[1] then
        -- the same kind: the bars' heights too
        local src = C[fk[1]][fk[2]]
        cfg.height = src.height
        if src.pheight then cfg.pheight = src.pheight end
        if tk[1] == "castbar" and tonumber(cfg.height) and tonumber(cfg.height) > 0 then to:SetHeight(tonumber(cfg.height)) end
      end
      if to.UpdateFrameSize then to:UpdateFrameSize() end
    elseif meter then
      -- (each window's own settings since the meters' phase 1: C.meters.winN)
      local mc = C.meters["win" .. meter] or C.meters
      mc.width, mc.height = tostring(w), tostring(h)
      to:SetWidth(w)
      to:SetHeight(h)
      if to.OnMove then to:OnMove() end
    else
      local tw = (to:GetWidth() or 0) * to:GetScale()
      if tw <= 0 then return end
      KeepPlaces({ to }, function() SaveScale(to, round(to:GetScale() * (w * to:GetScale()) / tw, 3)) end)
    end
    SavePosition(to)
    if to.OnMove then to:OnMove() end
    if to.drag then ShowSize(to.drag) end
    Say(NiceLabel(to.drag.label) .. " " .. T["now matches"] .. " "
      .. NiceLabel(from.drag.label) .. " (" .. w .. (tk and fk and fk[1] == tk[1] and "" or (" x " .. h)) .. ")")
  end

  -- a box to a typed size (UIParent px; nil = leave it) or scale. Frames
  -- whose size is a setting get the setting: unit frames and cast bars
  -- (their own width / height, the portrait kept), the meter windows, the
  -- raid frames (each frame's size from the whole raid's, the grid kept).
  -- Anything else is scaled: to the width, else the height, else scale.
  SetBoxSize = function(f, w, h, scale)
    local cw, ch, s = ScreenSize(f)
    if cw <= 0 or ch <= 0 or s <= 0 then return end
    local name = f:GetName() or ""
    local tk = SIZES[name]
    local _, _, meter = string.find(name, "^pfMeter(%d)$")
    local raid = pfUI.uf and pfUI.uf.raid
    -- octo (29 Oct 2026, a player: "narrower but just as tall", never scaled):
    -- the info panels take a width and a height of their own; no scale (the
    -- % box is hidden for them, - / + change the width)
    local side = (name == "pfPanelLeft" and "left") or (name == "pfPanelRight" and "right")
    if side and pfUI.panel and pfUI.panel.Size then
      local cfg = C.panel[side]
      if scale then return end
      KeepPlaces({ f }, function()
        if w then cfg.pwidth = tostring(math.max(40, floor(w / s + .5))) end
        if h then cfg.pheight = tostring(math.max(8, floor(h / s + .5))) end
        pfUI.panel.Size(side)
      end)
    elseif scale then
      scale = math.max(SZ.MIN, math.min(SZ.MAX, scale))
      KeepPlaces({ f }, function() SaveScale(f, floor(scale * 1000 + .5) / 1000) end)
    elseif f == _G.pfRaidCluster and raid and raid[1] and raid.UpdateConfig then
      local cfg = C.unitframes.raid
      local cols, rows = SZ.RaidGrid(cfg.raidlayout)
      local gap = (tonumber(cfg.raidpadding) or 0) * GetPerfectPixel()
      local _, border = GetBorderSize("unitframes")
      KeepPlaces({ f }, function()
        if math.abs(f:GetScale() - 1) > .001 then
          f:SetScale(1)
          if C.position[name] then C.position[name].scale = nil end
        end
        if w then
          local extra = (raid[1]:GetWidth() or 0) - (tonumber(cfg.width) or 0)
          cfg.width = tostring(math.max(20, math.min(400, floor(SZ.RaidFrameWidth(w, cols, gap, border) - extra + .5))))
        end
        if h then
          local extra = (raid[1]:GetHeight() or 0) - (tonumber(cfg.height) or 0)
          cfg.height = tostring(math.max(4, math.min(100, floor(SZ.RaidFrameWidth(h, rows, gap, border) - extra + .5))))
        end
        raid:UpdateConfig()
      end)
    elseif tk then
      local cfg = C[tk[1]][tk[2]]
      KeepPlaces({ f }, function()
        if w then
          local own = tonumber(cfg.width) or 0
          local extra = own > 0 and ((f:GetWidth() or 0) - own) or 0
          cfg.width = tostring(math.max(10, floor(w / s - extra + .5)))
        end
        if h then
          local own = tonumber(cfg.height) or 0
          local extra = own > 0 and ((f:GetHeight() or 0) - own) or 0
          cfg.height = tostring(math.max(2, floor(h / s - extra + .5)))
        end
        if tk[1] == "castbar" then
          if w then f:SetWidth(tonumber(cfg.width)) end
          if h then f:SetHeight(tonumber(cfg.height)) end
          if pfUI.castbarOcto and pfUI.castbarOcto.Apply then pfUI.castbarOcto.Apply(tk[2]) end
        elseif pfUI.ufOcto and pfUI.ufOcto.Apply then
          pfUI.ufOcto.Apply(tk[2])
        elseif f.UpdateFrameSize then
          f:UpdateFrameSize()
        end
      end)
    elseif meter then
      local mc = C.meters["win" .. meter] or C.meters
      if w then mc.width = tostring(floor(w / s + .5)) f:SetWidth(tonumber(mc.width)) end
      if h then mc.height = tostring(floor(h / s + .5)) f:SetHeight(tonumber(mc.height)) end
      if f.arrowDocked and pfUI.panel and pfUI.panel.ArrowLayout then
        -- (docked in the panel arrow's window: its width is its share of it; never save the docked place)
        pfUI.panel.ArrowLayout()
      else
        SavePosition(f)
        if f.OnMove then f:OnMove() end
      end
    else
      local k = w and (w / cw) or h and (h / ch) or 1
      local ns = math.max(SZ.MIN, math.min(SZ.MAX, f:GetScale() * k))
      KeepPlaces({ f }, function() SaveScale(f, floor(ns * 1000 + .5) / 1000) end)
    end
    if f.drag then ShowSize(f.drag) end
    UpdateDockValues()
  end

  -- [ match menu ]
  -- octo (user, 25 Oct 2026: "There should be match size buttons"): the
  -- nudge box's Match button lists the boxes this one can take the size of,
  -- the same kind first (action bars: the other bars, and "every bar like
  -- this one"). Closes on a click outside it.
  -- (made before pfUI.unlock: on UIParent, hidden with layout mode)
  local menu = CreateFrame("Frame", "pfUnlockMatchMenu", UIParent)
  local catch = CreateFrame("Button", nil, UIParent)
  catch:SetFrameStrata("FULLSCREEN_DIALOG")
  catch:SetFrameLevel(1)
  catch:SetAllPoints(WorldFrame)
  catch:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  catch:SetScript("OnClick", function() menu:Hide() end)
  catch:Hide()
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetFrameLevel(20)
  menu:SetWidth(220)
  menu:SetClampedToScreen(true)
  menu:EnableMouse(true)
  menu:Hide()
  CreateBackdrop(menu, nil, nil, .95)
  menu:SetScript("OnShow", function() catch:Show() end)
  menu:SetScript("OnHide", function() catch:Hide() end)
  menu.title = menu:CreateFontString(nil, "OVERLAY")
  menu.title:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  menu.title:SetPoint("TOPLEFT", 8, -7)
  menu.title:SetPoint("TOPRIGHT", -8, -7)
  menu.title:SetJustifyH("LEFT")
  menu.title:SetTextColor(.7, .75, .8)
  menu.rows = {}

  -- colour roles (as the options window: purple = pick one, gold = copy /
  -- match, blue = opens more, green = go, red = off; grey = back)
  local ROLE = { pick = { .68, .45, 1 }, save = { 1, .78, .2 }, open = { .35, .7, 1 }, go = { .25, .85, .4 },
                 off = { .95, .3, .3 }, back = { .55, .58, .62 } }
  local function MenuRow(n)
    local b = menu.rows[n]
    if b then return b end
    b = CreateFrame("Button", nil, menu)
    b:SetHeight(20)
    b:SetPoint("TOPLEFT", 6, -22 - (n - 1) * 22)
    b:SetPoint("TOPRIGHT", -6, -22 - (n - 1) * 22)
    CreateBackdrop(b, nil, true)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
    b.text:SetShadowOffset(1, -1)
    b.text:SetPoint("LEFT", 8, 0)
    b.text:SetPoint("RIGHT", -8, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetTextColor(1, 1, 1)
    b.Paint = function(hover)
      local c = ROLE[b.role] or ROLE.pick
      local k = hover and .45 or .22
      b:SetBackdropColor(c[1] * k, c[2] * k, c[3] * k, .95)
      b:SetBackdropBorderColor(c[1] * .8, c[2] * .8, c[3] * .8, 1)
    end
    b:SetScript("OnEnter", function() this.Paint(true) end)
    b:SetScript("OnLeave", function() this.Paint(false) end)
    b:SetScript("OnClick", function()
      -- (a row that opens a list keeps the menu up)
      if not this.keep then menu:Hide() end
      if this.run then this.run() end
      UpdateDockValues()
    end)
    menu.rows[n] = b
    return b
  end

  -- the words of a box's name ("Combat Text: Incoming" -> combat, text, incoming)
  local function Words(label)
    local out = {}
    for w in string.gfind(string.lower(label or ""), "%a+") do
      if string.len(w) > 2 then out[w] = true end
    end
    return out
  end

  -- how alike two boxes are, for the Match list (user, 26 Oct 2026: "the
  -- closest match to what you would match the size to ... combat text incoming
  -- with combat text outgoing"): words they share in their names (Combat
  -- Text, Castbar, Target...), the same kind, then a like shape and size
  local function Likeness(a, b)
    local score = 0
    local wa, wb = Words(a.drag and a.drag.label), Words(b.drag and b.drag.label)
    for w in pairs(wa) do if wb[w] then score = score + 3 end end
    local ka = KindOf(a)
    if ka ~= "other" and ka == KindOf(b) then score = score + 4 end
    local aw, ah = ScreenSize(a)
    local bw, bh = ScreenSize(b)
    if aw > 0 and ah > 0 and bw > 0 and bh > 0 then
      local ra, rb = aw / ah, bw / bh
      score = score + 2 * math.min(ra, rb) / math.max(ra, rb)
      score = score + math.min(aw * ah, bw * bh) / math.max(aw * ah, bw * bh)
    end
    return score
  end

  -- the boxes d can take the size of: { label, frame }, the closest first
  -- (bars only match bars)
  local function MatchChoices(d)
    local kind = KindOf(d.frame)
    local out = {}
    for name, f in pairs(pfUI.movables) do
      f = f or _G[name]
      if f and f ~= d.frame and f.drag and f:IsShown() and (f:GetWidth() or 0) > 0
        and (kind ~= "bar" or KindOf(f) == "bar") then
        local label = NiceLabel(f.drag.label)
        table.insert(out, { label, f, Likeness(d.frame, f) })
      end
    end
    table.sort(out, function(a, b)
      if a[3] ~= b[3] then return a[3] > b[3] end
      return a[1] < b[1]
    end)
    return out
  end

  -- [ locking ] (see "locks" above)
  -- f stays where it is, now saved on target's bottom left corner
  local function LockTo(f, target)
    local l, b, tl, tb = f:GetLeft(), f:GetBottom(), target:GetLeft(), target:GetBottom()
    if not l or not tl then return end
    local s, ts = UIScale(f), UIScale(target)
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", (l * s - tl * ts) / s, (b * s - tb * ts) / s)
    SavePosition(f)
    if f.OnMove then f:OnMove() end
    Say(NiceLabel(f.drag and f.drag.label or f:GetName()) .. " " .. T["is locked to"] .. " "
      .. NiceLabel(target.drag and target.drag.label or target:GetName()) .. " " .. T["and moves with it."])
  end
  -- free again, where it is now
  local function Unlock(f)
    local l, r, b, t = f:GetLeft(), f:GetRight(), f:GetBottom(), f:GetTop()
    if not l then return end
    local s = UIScale(f)
    l, r, b, t = l * s, r * s, b * s, t * s
    local a = AnchorFor(l, r, b, t)
    local x, y = AnchorOffsets(a, l, r, b, t, s)
    f:ClearAllPoints()
    f:SetPoint(a, UIParent, a, x, y)
    SavePosition(f)
    if f.OnMove then f:OnMove() end
  end
  -- back on its default place, on the frame it hung on (as middle-click)
  local function LockBack(f)
    C.position[f:GetName()] = nil
    f:ClearAllPoints()
    UpdateMovable(f)
    if f.OnMove then f:OnMove() end
  end

  -- boxes f could lock to (here = boxes that could lock to f), nearest first
  local function LockChoices(f, here)
    local fl, fr, fcx, fb, ft, fcy = Edges(f)
    local out = {}
    for name, o in pairs(pfUI.movables) do
      o = o or _G[name]
      if o and o ~= f and o.drag and o:IsShown() then
        local holder, held = f, o
        if here then holder, held = o, f end
        -- (no loops: the one that holds may not move with the one locked)
        if not HeldBy(holder, function(t) return t == held end) and LockedTo(held) ~= holder then
          local _, _, ocx, _, _, ocy = Edges(o)
          local dist = (fcx and ocx) and ((ocx - fcx) * (ocx - fcx) + (ocy - fcy) * (ocy - fcy)) or 1e9
          table.insert(out, { NiceLabel(o.drag.label), o, dist })
        end
      end
    end
    table.sort(out, function(a, b) return a[3] < b[3] end)
    while table.getn(out) > 14 do table.remove(out) end
    return out
  end

  local function OpenMatchMenu(d, anchor, page)
    local f = d.frame
    local n = 0
    local function Add(text, role, run, keep)
      n = n + 1
      local b = MenuRow(n)
      b.text:SetText(text)
      b.role, b.run, b.keep = role, run, keep
      b.Paint(false)
      b:Show()
    end
    local function Go(to) return function() OpenMatchMenu(d, anchor, to) end end
    local name = NiceLabel(d.label)
    if page == "match" or page == "matchall" then
      menu.title:SetText(T["Give"] .. " " .. name .. " " .. T["the size of"] .. ":")
      -- the closest ones (a list that fits the screen), the rest one click away
      local choices = MatchChoices(d)
      local most = page == "match" and 10 or table.getn(choices)
      for i, e in ipairs(choices) do
        local src = e[2]
        if i <= most then Add(e[1], "pick", function() MatchSize(src, f) end) end
      end
      if table.getn(choices) > most then
        Add(T["All boxes"] .. " (" .. table.getn(choices) .. ")  >", "open", Go("matchall"), true)
      end
    elseif page == "lockto" or page == "lockhere" then
      menu.title:SetText(page == "lockto" and (T["Lock"] .. " " .. name .. " " .. T["to (moves with it)"] .. ":")
        or (T["Lock to"] .. " " .. name .. ":"))
      for _, e in ipairs(LockChoices(f, page == "lockhere")) do
        local o = e[2]
        if page == "lockto" then
          Add(e[1], "pick", function() LockTo(f, o) end)
        else
          Add(e[1], "pick", function() LockTo(o, f) end)
        end
      end
    else
      -- the first page: what can be done
      menu.title:SetText(name)
      Add(T["Match the size of"] .. "  >", "open", Go("match"), true)
      local bi = BarIndex(f)
      if bi then
        Add(T["Every other bar like this one"], "save", function()
          local frames = {}
          for i = 1, 10 do if i ~= bi and pfUI.bars[i] then table.insert(frames, pfUI.bars[i]) end end
          local count = 0
          KeepPlaces(frames, function()
            count = pfUI.barsOcto.MatchAll(bi)
            pfUI.bars:UpdateConfig()
          end)
          Say(count .. " " .. T["bars now match"] .. " " .. name)
        end)
      end
      Add(T["Lock to another box"] .. "  >", "open", Go("lockto"), true)
      Add(T["Lock other boxes to this one"] .. "  >", "open", Go("lockhere"), true)
      local home = HomeOf(f)
      if home and C.position[f:GetName()] then
        Add(T["Lock back on"] .. " " .. NiceLabel(home.drag and home.drag.label or home:GetName()), "go", function() LockBack(f) end)
      end
      local to = LockedTo(f)
      if to then
        Add(T["Unlock from"] .. " " .. NiceLabel(to.drag and to.drag.label or to:GetName()) .. " " .. T["(stays here)"], "off", function() Unlock(f) end)
      end
    end
    if page then
      if n == 0 then Add(T["Nothing here"], "back", nil, true) end
      Add("<  " .. T["Back"], "back", Go(nil), true)
    end
    for i = n + 1, table.getn(menu.rows) do menu.rows[i]:Hide() end
    menu:SetHeight(28 + n * 22)
    menu:ClearAllPoints()
    SetAutoPoint(menu, anchor or d, 4)
    menu:Show()
  end

  local function DraggerOnClick()
    -- the mouse-up that ends a drag is not a click
    if arg1 == "LeftButton" and this.justDragged then this.justDragged = nil return end
    if IsAltKeyDown() and arg1 == "LeftButton" then
      -- first box: the size to copy; second box: gets it
      if not matchFrom or matchFrom == this then
        local was = matchFrom
        matchFrom = (was ~= this) and this or nil
        Paint(this, "hover")
        if matchFrom then
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r: " .. T["Alt-click the box that should get the size of"] .. " " .. NiceLabel(this.label))
        end
      else
        local from = matchFrom
        matchFrom = nil
        Paint(from, "normal")
        MatchSize(from.frame, this.frame)
        UpdateDockValues()
      end
      return
    elseif arg1 == "LeftButton" then
      -- ElvUI: left-click = the nudge box (arrows, X / Y, anchor)
      if pfUI.unlock.dock.parent == this and pfUI.unlock.dock:IsShown() then
        SetDockToFrame(nil)
      else
        SetDockToFrame(this)
      end
      return
    elseif arg1 == "RightButton" then
      -- ElvUI: right-click = this frame's options
      local cat, conf, card = GetConfigTable(this.label)
      if cat then
        OpenConfigDialog(cat, conf, card)
      else
        SetDockToFrame(this)
      end
      return
    elseif arg1 == "MiddleButton" then
      -- reset positions of dragger and all connected frames
      pfUI.unlock.selection = GetFrames()
      for id, frame in pairs(pfUI.unlock.selection) do
        pfUI_config["position"][frame:GetName()] = nil
        UpdateMovable(frame)

        if frame.OnMove then frame:OnMove() end
      end
      UpdateDockValues()
    end
  end

  -- (octo: the size shows while the mouse is on a box)
  local function DraggerOnEnter()
    if pfUI.unlock.dock.parent ~= this then
      Paint(this, "hover")
    end
    this.hover = true
    if not (drag.boxes and drag.boxes[1]) then ShowSize(this, 0) end
  end

  local function DraggerOnLeave()
    if pfUI.unlock.dock.parent ~= this then
      Paint(this, "normal")
    end
    this.hover = nil
    -- (a moment to reach the size editor under the box)
    if this.sizebox and this.sizebox:IsShown() then this.sizeUntil = math.max(this.sizeUntil or 0, GetTime() + .5) end
  end

  local function CreateDragger(f)
    local fname = f:GetName()
    local label = string.sub(fname, 1, 2) == "pf" and strsub(fname,3) or fname

    local d = CreateFrame("Button", fname .. "Drag", f)
    d:RegisterForClicks("LeftButtonUp", "MiddleButtonUp", "RightButtonUp")
    d:RegisterForDrag("LeftButton")
    d:SetAllPoints(f)
    d:SetAlpha(1)
    d:EnableMouseWheel(1)

    d:SetFrameLevel(128)

    d.text = d:CreateFontString("Status", "LOW", "GameFontNormal")
    d.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
    d.text:ClearAllPoints()
    d.text:SetAllPoints(d)
    d.text:SetPoint("CENTER", 0, 0)
    d.text:SetFontObject(GameFontWhite)

    d.frame = f
    d.fname = fname
    d.label = label

    label = NiceLabel(label)
    if d:GetHeight() > (2 * d:GetWidth()) then
      label = strvertical(label)
    end

    d.text:SetText(label)
    d.text:SetFont(pfUI.font_default, C.global.font_size + 1, "OUTLINE")

    d:SetScript("OnMouseWheel", DraggerOnMouseWheel)
    d:SetScript("OnDragStart", DraggerOnDragStart)
    d:SetScript("OnDragStop", DraggerOnDragStop)
    d:SetScript("OnClick", DraggerOnClick)
    d:SetScript("OnMouseDown", function() this.justDragged = nil end)
    d:SetScript("OnEnter", DraggerOnEnter)
    d:SetScript("OnLeave", DraggerOnLeave)

    CreateBackdrop(d, nil, nil, .8)
    Paint(d, "normal")
    return d
  end

  table.insert(UISpecialFrames, "pfUnlock")
  pfUI.unlock = CreateFrame("Button", "pfUnlock", UIParent)
  pfUI.unlock.selection = {}
  pfUI.unlock:Hide()
  pfUI.unlock:SetAllPoints(WorldFrame)
  pfUI.unlock:SetFrameStrata("BACKGROUND")
  pfUI.unlock:SetScript("OnClick", function()
    this:Hide()
  end)

  -- a saved spot as one string, to see whether it changed
  local function PosSig(p)
    if type(p) ~= "table" then return "" end
    return tostring(p.xpos) .. "|" .. tostring(p.ypos) .. "|" .. tostring(p.anchor) .. "|" .. tostring(p.scale) .. "|"
      .. tostring(p.attach) .. "|" .. tostring(p.relpoint) .. "|" .. tostring(p.parent)
  end

  pfUI.unlock:SetScript("OnShow", function()
    if this.skip then this.skip = nil return end
    if InCombatLockdown and InCombatLockdown() then
      DEFAULT_CHAT_FRAME:AddMessage(ERR_NOT_IN_COMBAT, 1, .2, .2)
      this.skip = true
      this:Hide()
      return
    end

    -- (1 Nov 2026, a player: crash #132 at 0x0070211C while moving the gear button -
    -- the client crashes, no Lua error, when a method runs on something that is not
    -- a real frame. Layout mode reads every movable while dragging (snap lines):
    -- anything in the list that is not a live game frame - a copied table, a frame
    -- of another name - is dropped from it before any of that runs.)
    for name, f in pairs(pfUI.movables) do
      local real = type(f) == "table" and type(f.GetName) == "function"
      local ok, nm = false, nil
      if real then ok, nm = pcall(f.GetName, f) end
      if not real or not ok or nm ~= name or _G[name] ~= f then pfUI.movables[name] = nil end
    end

    this.grid = DrawGrid()
    this.bar:Update()
    -- (where every frame is saved now: on leaving, only the ones moved here
    -- are placed again - user, 26 Oct 2026: Escape after Move Frames moved
    -- the meters "THEY SHOULD BE NEVER MOVED UNLESS I MOVE THEM")
    this.before = {}
    for name in pairs(pfUI.movables) do this.before[name] = PosSig(C.position[name]) end

    for name, frame in pairs(pfUI.movables) do
      local frame = frame or _G[name]

      -- (hidden ones are back while the boxes are up, marked red)
      HideBack(frame)
      if not frame:IsShown() then frame.hideLater = true end
      frame.drag = frame.drag or CreateDragger(frame)
      frame:SetMovable(true)
      frame.drag:Show()
      frame:Show()
    end

    -- go back to the options window on exit only when it was opened from there
    this.fromGUI = pfUI.gui:IsShown()

    if C.unlock.helpseen ~= "1" then
      this.bar:ShowHelp()
      C.unlock.helpseen = "1"
    end
    pfUI.gui:Hide()
  end)

  pfUI.unlock:SetScript("OnHide", function()
    if this.skip then this.skip = nil return end
    if InCombatLockdown and InCombatLockdown() then
      this.skip = true
      this:Show()
      return
    end

    for name, frame in pairs(pfUI.movables) do
      local frame = frame or _G[name]

      if frame.hideLater == true then frame:Hide() end
      frame:StopMovingOrSizing()
      frame:SetMovable(false)
      if frame.drag then frame.drag:Hide() end
      if not this.before or this.before[name] ~= PosSig(C.position[name]) then UpdateMovable(frame) end
    end

    SetDockToFrame(nil)
    ShowGuides(nil, nil)
    menu:Hide()
    pfUI.unlock:Hide()
    ApplyHidden()
    if this.fromGUI then pfUI.gui:Show() end
  end)

  -- [ top bar ]
  -- ElvUI's layout-mode bar: snap on/off, grid size, help, reset all, done.
  local GRIDSIZES = { 32, 64, 128, 256 }

  local bar = CreateFrame("Frame", "pfUnlockBar", pfUI.unlock)
  bar:SetFrameStrata("FULLSCREEN_DIALOG")
  bar:SetPoint("TOP", pfUI.unlock, "TOP", 0, -20)
  bar:SetWidth(520)
  bar:SetHeight(28)
  bar:EnableMouse(true) -- clicks on the bar do not leave layout mode
  CreateBackdrop(bar)
  pfUI.unlock.bar = bar

  bar.title = bar:CreateFontString(nil, "OVERLAY")
  bar.title:SetFont(pfUI.font_default, C.global.font_size + 2, "OUTLINE")
  bar.title:SetPoint("LEFT", 8, 0)
  bar.title:SetText(T["Layout Mode"])

  local function BarButton(text, width, func)
    local b = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    b:SetWidth(width)
    b:SetHeight(18)
    b:SetText(text)
    b:SetScript("OnClick", func)
    SkinButton(b)
    return b
  end

  -- snap
  bar.snap = CreateFrame("CheckButton", "pfUnlockBarSnap", bar, "UICheckButtonTemplate")
  bar.snap:SetWidth(14)
  bar.snap:SetHeight(14)
  bar.snap:SetPoint("LEFT", 118, 0)
  SkinCheckbox(bar.snap, 14)
  bar.snap:SetScript("OnClick", function()
    C.unlock.snap = this:GetChecked() and "1" or "0"
  end)
  bar.snaptext = bar:CreateFontString(nil, "OVERLAY")
  bar.snaptext:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  bar.snaptext:SetPoint("LEFT", bar.snap, "RIGHT", 4, 0)
  bar.snaptext:SetText(T["Snap"])

  -- grid size = cells across the screen: "-" fewer, bigger squares
  local function SetGrid(dir)
    local cur = tonumber(C.unlock.gridsize) or 128
    local idx = 3
    for i, v in ipairs(GRIDSIZES) do if v == cur then idx = i end end
    idx = idx + dir
    if idx < 1 then idx = 1 elseif idx > table.getn(GRIDSIZES) then idx = table.getn(GRIDSIZES) end
    C.unlock.gridsize = tostring(GRIDSIZES[idx])
    pfUI.unlock.grid = DrawGrid()
    bar:Update()
  end
  bar.gridless = BarButton("-", 18, function() SetGrid(-1) end)
  bar.gridless:SetPoint("LEFT", 185, 0)
  bar.gridtext = bar:CreateFontString(nil, "OVERLAY")
  bar.gridtext:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  bar.gridtext:SetPoint("LEFT", bar.gridless, "RIGHT", 4, 0)
  bar.gridtext:SetWidth(60)
  bar.gridmore = BarButton("+", 18, function() SetGrid(1) end)
  bar.gridmore:SetPoint("LEFT", bar.gridtext, "RIGHT", 4, 0)

  function bar:ShowHelp()
    local a = rgbhex(GetAccentColor())
    -- octo: ElvUI's clicks (left = nudge box, right = the frame's options)
    -- and Alt-click to give one box another one's size
    local function L(key, text) return a .. key .. "|r " .. text .. "\n" end
    local txt = T["Layout mode: move, size and reset frames."] .. "\n\n"
      .. L(T["[Drag]"], T["move the frame - it snaps to other frames and the grid"])
      .. L(T["[Left-click]"], T["nudge box: arrows, X / Y, anchor, size, Match"])
      .. L(T["[Right-click]"], T["open this frame's options"])
      .. L(T["[Match / Lock] in the nudge box"], T["take another box's size, or lock boxes together (they move as one)"])
      .. L(T["[Alt-click] two boxes"], T["the second gets the first one's size"])
      .. L(T["[Middle-click]"], T["back to its default place"])
      .. L(T["[Mouse wheel]"], T["size, 2% a notch (raid frames: 1 px)"])
      .. L(T["[Shift] / [Ctrl] + wheel"], T["10% / 0.5% a notch (raid frames: 5 px)"])
      .. "\n"
      .. L(T["[Shift]"], T["select all frames of the same kind"])
      .. L(T["[Ctrl]"], T["select all frames of the same group"])
      .. L(T["[Alt] while dragging"], T["no snapping"])
      .. L(T["[Orange tabs]"], T["drag the mirror lines: a pair moves the same way either side of the middle, frames snap to them"])
      .. L(T["[Shift] on the arrows"], T["move 10 pixels"])
      .. "\n"
      .. L(T["[Esc]"], T["or a click on an empty spot: done"])
    CreateInfoBox(txt, 15, pfUI.unlock, 250)
  end
  bar.help = BarButton("?", 18, function() bar:ShowHelp() end)
  bar.help:SetPoint("LEFT", bar.gridmore, "RIGHT", 14, 0)

  bar.done = BarButton(T["Done"], 70, function() pfUI.unlock:Hide() end)
  bar.done:SetPoint("RIGHT", -6, 0)

  bar.reset = BarButton(T["Reset All"], 80, function()
    CreateQuestionDialog(T["Move every frame back to its default place?"], function()
      for name, frame in pairs(pfUI.movables) do
        frame = frame or _G[name]
        pfUI_config["position"][frame:GetName()] = nil
        frame:ClearAllPoints()
        UpdateMovable(frame)
        if frame.OnMove then frame:OnMove() end
      end
      SetDockToFrame(nil)
    end)
  end)
  bar.reset:SetPoint("RIGHT", bar.done, "LEFT", -6, 0)

  -- [ mirror lines: drawing and dragging ] (see "mirror lines" above)
  local MCOL = { 1, .5, .1 }
  local mirror = CreateFrame("Frame", "pfUnlockMirror", pfUI.unlock)
  mirror:SetAllPoints(pfUI.unlock)
  mirror:SetFrameStrata("FULLSCREEN")
  mirror:EnableMouse(false)
  mirror.lines, mirror.tabs = {}, {}
  pfUI.unlock.mirror = mirror

  -- every box edge's distance from the middle on that axis: a dragged
  -- line snaps onto one, so a pair can be set to a frame's edge
  local function MirrorSnap(axis, d)
    if C.unlock.snap ~= "1" or IsAltKeyDown() then return d end
    local mid = axis == "x" and GetScreenWidth() / 2 or GetScreenHeight() / 2
    local best, bestd = SNAP + 1, d
    for name, f in pairs(pfUI.movables) do
      f = f or _G[name]
      if f and f:IsShown() then
        local l, r, cx, b, t, cy = Edges(f)
        if l then
          local list = axis == "x" and { l, r, cx } or { b, t, cy }
          for _, e in ipairs(list) do
            local ed = abs(e - mid)
            if abs(ed - d) < best then best, bestd = abs(ed - d), ed end
          end
        end
      end
    end
    return bestd
  end

  function mirror:Place()
    local on = MirrorOn()
    for _, l in pairs(self.lines) do if on then l:Show() else l:Hide() end end
    for _, t in pairs(self.tabs) do if on then t:Show() else t:Hide() end end
    if not on then return end
    local mx, my = MirrorLines()
    local w, h = GetScreenWidth(), GetScreenHeight()
    for i = 1, 2 do
      local v, hz = self.lines["x" .. i], self.lines["y" .. i]
      v:ClearAllPoints()
      v:SetPoint("TOPLEFT", self, "TOPLEFT", mx[i] - 1, 0)
      v:SetPoint("BOTTOMRIGHT", self, "BOTTOMLEFT", mx[i] + 1, 0)
      hz:ClearAllPoints()
      hz:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, my[i] + 1)
      hz:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, my[i] - 1)
      -- tabs: at the bottom of the vertical lines, the left end of the
      -- horizontal ones (clear of the top bar and the nudge box)
      local tv, th = self.tabs["x" .. i], self.tabs["y" .. i]
      tv:ClearAllPoints()
      tv:SetPoint("BOTTOM", self, "BOTTOMLEFT", mx[i], 40)
      th:ClearAllPoints()
      th:SetPoint("LEFT", self, "BOTTOMLEFT", 40, my[i])
    end
    self.readx:SetText(floor(MirrorDist("x") + .5) .. " px")
    self.ready:SetText(floor(MirrorDist("y") + .5) .. " px")
  end

  local function MirrorTab(key, axis)
    local t = CreateFrame("Button", nil, mirror)
    t:SetFrameStrata("FULLSCREEN")
    t:SetFrameLevel(mirror:GetFrameLevel() + 5)
    if axis == "x" then t:SetWidth(14) t:SetHeight(26) else t:SetWidth(26) t:SetHeight(14) end
    t:EnableMouse(true)
    t:RegisterForClicks("RightButtonUp")
    t.bg = t:CreateTexture(nil, "ARTWORK")
    t.bg:SetAllPoints()
    t.bg:SetTexture(MCOL[1], MCOL[2], MCOL[3], .85)
    t.grip = t:CreateTexture(nil, "OVERLAY")
    t.grip:SetTexture(0, 0, 0, .6)
    if axis == "x" then
      t.grip:SetWidth(2) t.grip:SetHeight(14)
    else
      t.grip:SetWidth(14) t.grip:SetHeight(2)
    end
    t.grip:SetPoint("CENTER", 0, 0)
    t:SetScript("OnMouseDown", function()
      if arg1 == "LeftButton" then this.dragging = true end
    end)
    t:SetScript("OnMouseUp", function() this.dragging = nil end)
    t:SetScript("OnClick", function()
      -- right-click: back to a quarter of the screen
      if axis == "x" then C.unlock.mirrorx = nil else C.unlock.mirrory = nil end
      mirror:Place()
    end)
    t:SetScript("OnUpdate", function()
      if not this.dragging then return end
      local x, y = Cursor()
      local mid = axis == "x" and GetScreenWidth() / 2 or GetScreenHeight() / 2
      local d = MirrorSnap(axis, abs((axis == "x" and x or y) - mid))
      d = floor(d * 10 + .5) / 10
      if axis == "x" then C.unlock.mirrorx = tostring(d) else C.unlock.mirrory = tostring(d) end
      mirror:Place()
    end)
    t:SetScript("OnEnter", function()
      this.bg:SetTexture(1, .75, .35, 1)
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText(T["Mirror lines"], MCOL[1], MCOL[2], MCOL[3])
      GameTooltip:AddLine(T["Drag: both lines move, the same way either side of the middle (they snap to box edges)."], 1, 1, 1, 1)
      GameTooltip:AddLine(T["Frames snap to them. Right-click: back to a quarter of the screen."], .8, .8, .8, 1)
      GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function()
      this.bg:SetTexture(MCOL[1], MCOL[2], MCOL[3], .85)
      GameTooltip:Hide()
    end)
    mirror.tabs[key] = t
  end

  for i = 1, 2 do
    for _, axis in ipairs({ "x", "y" }) do
      local l = mirror:CreateTexture(nil, "OVERLAY")
      l:SetTexture(MCOL[1], MCOL[2], MCOL[3], .75)
      mirror.lines[axis .. i] = l
      MirrorTab(axis .. i, axis)
    end
  end
  -- the distance, by the right-hand vertical tab and the top horizontal one
  mirror.readx = mirror:CreateFontString(nil, "OVERLAY")
  mirror.readx:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  mirror.readx:SetTextColor(MCOL[1], MCOL[2], MCOL[3])
  mirror.readx:SetPoint("LEFT", mirror.tabs.x2, "RIGHT", 4, 0)
  mirror.ready = mirror:CreateFontString(nil, "OVERLAY")
  mirror.ready:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  mirror.ready:SetTextColor(MCOL[1], MCOL[2], MCOL[3])
  mirror.ready:SetPoint("BOTTOM", mirror.tabs.y2, "TOP", 0, 4)
  pfUI.unlock.MirrorLines = MirrorLines

  -- the bar's switch for them
  bar.mirror = CreateFrame("CheckButton", "pfUnlockBarMirror", bar, "UICheckButtonTemplate")
  bar.mirror:SetWidth(14)
  bar.mirror:SetHeight(14)
  bar.mirror:SetPoint("LEFT", bar.help, "RIGHT", 14, 0)
  SkinCheckbox(bar.mirror, 14)
  bar.mirror:SetScript("OnClick", function()
    C.unlock.mirror = this:GetChecked() and "1" or "0"
    mirror:Place()
  end)
  bar.mirrortext = bar:CreateFontString(nil, "OVERLAY")
  bar.mirrortext:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  bar.mirrortext:SetPoint("LEFT", bar.mirror, "RIGHT", 4, 0)
  bar.mirrortext:SetText(T["Mirror lines"])
  bar.mirrortext:SetTextColor(MCOL[1], MCOL[2], MCOL[3])
  bar:SetWidth(620)

  function bar:Update()
    local ar, ag, ab = GetAccentColor()
    bar.title:SetTextColor(ar, ag, ab, 1)
    bar.snap:SetChecked(C.unlock.snap == "1")
    bar.mirror:SetChecked(C.unlock.mirror == "1")
    mirror:Place()
    bar.gridtext:SetText(T["Grid"] .. " " .. (C.unlock.gridsize or "128"))
  end

  -- for tests\run.lua
  pfUI.unlock.GetSnap = GetSnap
  -- the size maths, Match and keeping a frame's place (tests; the Bars page)
  pfUI.unlock.size = SZ
  pfUI.unlock.MatchSize = MatchSize
  pfUI.unlock.KeepPlaces = KeepPlaces
  pfUI.unlock.Resize = Resize
  pfUI.unlock.MatchChoices = MatchChoices
  pfUI.unlock.Likeness = Likeness
  pfUI.unlock.OpenMatchMenu = OpenMatchMenu
  pfUI.unlock.LockTo, pfUI.unlock.Unlock, pfUI.unlock.LockBack = LockTo, Unlock, LockBack
  pfUI.unlock.LockChoices, pfUI.unlock.Holder = LockChoices, Holder
  pfUI.unlock.SetBoxSize = SetBoxSize

  -- /moveui (ElvUI's command), /pfmove
  _G.SLASH_PFMOVEUI1, _G.SLASH_PFMOVEUI2 = "/moveui", "/pfmove"
  _G.SlashCmdList.PFMOVEUI = function()
    if pfUI.unlock:IsShown() then pfUI.unlock:Hide() else pfUI.unlock:Show() end
  end

  -- dock frame
  pfUI.unlock.dock = CreateFrame("Button", "pfUnlockDock", pfUI.unlock)
  pfUI.unlock.dock:SetWidth(150)
  pfUI.unlock.dock:SetHeight(160)
  pfUI.unlock.dock:SetFrameStrata("FULLSCREEN_DIALOG")
  pfUI.unlock.dock:Hide()
  CreateBackdrop(pfUI.unlock.dock)

  -- title
  pfUI.unlock.dock.title = pfUI.unlock.dock:CreateFontString("Status", "DIALOG", "GameFontNormal")
  pfUI.unlock.dock.title:SetTextColor(1,1,1,1)
  pfUI.unlock.dock.title:SetFont(pfUI.font_default, C.global.font_size + 2, "OUTLINE")
  pfUI.unlock.dock.title:SetJustifyH("left")
  pfUI.unlock.dock.title:SetPoint("TOP", 0, -5)

  -- anchor
  pfUI.unlock.dock.anchor = CreateFrame("Frame", "pfUIUnlockAnchorDropDownMenu", pfUI.unlock.dock, "UIDropDownMenuTemplate")
  pfUI.unlock.dock.anchor:ClearAllPoints()
  pfUI.unlock.dock.anchor:SetPoint("TOP", 0, -25)

  UIDropDownMenu_SetWidth(120, pfUI.unlock.dock.anchor)
  UIDropDownMenu_SetButtonWidth(120, pfUI.unlock.dock.anchor)
  UIDropDownMenu_JustifyText("RIGHT", pfUI.unlock.dock.anchor)
  UIDropDownMenu_Initialize(pfUI.unlock.dock.anchor, function()
    local info = {}
    for id, k in pairs(anchors) do
      -- get human readable
      local value, text = strsplit(":", k)
      local id = id
      text = text or value

      info.text = text
      info.checked = false
      info.func = function()
        UIDropDownMenu_SetSelectedID(pfUI.unlock.dock.anchor, id, 0)
        UIDropDownMenu_SetText(text, pfUI.unlock.dock.anchor)

        local frame = pfUI.unlock.dock.parent.frame
        local anchor, x, y = ConvertFrameAnchor(frame, text)
        frame:ClearAllPoints()
        frame:SetPoint(anchor, UIParent, anchor, x, y)

        SavePosition(frame)
        UpdateDockValues()
      end

      UIDropDownMenu_AddButton(info)
    end
  end)

  SkinDropDown(pfUI.unlock.dock.anchor)

  -- x coordinates
  pfUI.unlock.dock.xcoordcap = pfUI.unlock.dock:CreateFontString("Status", "DIALOG", "GameFontNormal")
  pfUI.unlock.dock.xcoordcap:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  pfUI.unlock.dock.xcoordcap:SetJustifyH("LEFT")
  pfUI.unlock.dock.xcoordcap:SetPoint("TOPLEFT", 5, -63)
  pfUI.unlock.dock.xcoordcap:SetText("X:")
  pfUI.unlock.dock.xcoord = CreateFrame("EditBox", nil, pfUI.unlock.dock)
  pfUI.unlock.dock.xcoord:SetTextInsets(5, 5, 5, 5)
  pfUI.unlock.dock.xcoord:SetJustifyH("CENTER")
  pfUI.unlock.dock.xcoord:SetWidth(45)
  pfUI.unlock.dock.xcoord:SetHeight(18)
  pfUI.unlock.dock.xcoord:SetPoint("TOPLEFT", pfUI.unlock.dock, "TOPLEFT", 20, -60)
  pfUI.unlock.dock.xcoord:SetFontObject(GameFontNormal)
  pfUI.unlock.dock.xcoord:SetAutoFocus(false)

  pfUI.unlock.dock.xcoord:SetScript("OnEnterPressed", function(self)
    local newXPos = tonumber(this:GetText())
    if newXPos then
      local frame = pfUI.unlock.dock.parent.frame
      local anchor, rel, relpoint, xpos, ypos = frame:GetPoint()
      frame:ClearAllPoints()
      frame:SetPoint(anchor, rel or UIParent, relpoint or anchor, newXPos, ypos)
      SavePosition(frame)
    else
      UpdateDockValues()
    end
    this:ClearFocus()
  end)

  pfUI.unlock.dock.xcoord:SetScript("OnTextChanged", function(self)
    if tonumber(this:GetText()) then
      this:SetTextColor(1,1,1,1)
    else
      this:SetTextColor(1,.3,.3,1)
    end
  end)

  CreateBackdrop(pfUI.unlock.dock.xcoord, nil, true)

  -- y coordinates
  pfUI.unlock.dock.ycoordcap = pfUI.unlock.dock:CreateFontString("Status", "DIALOG", "GameFontNormal")
  pfUI.unlock.dock.ycoordcap:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  pfUI.unlock.dock.ycoordcap:SetText("Y:")
  pfUI.unlock.dock.ycoordcap:SetJustifyH("LEFT")
  pfUI.unlock.dock.ycoordcap:SetPoint("TOPLEFT", 75, -63)
  pfUI.unlock.dock.ycoord = CreateFrame("EditBox", nil, pfUI.unlock.dock)
  pfUI.unlock.dock.ycoord:SetTextInsets(5, 5, 5, 5)
  pfUI.unlock.dock.ycoord:SetJustifyH("CENTER")
  pfUI.unlock.dock.ycoord:SetWidth(45)
  pfUI.unlock.dock.ycoord:SetHeight(18)
  pfUI.unlock.dock.ycoord:SetPoint("TOPLEFT", pfUI.unlock.dock, "TOPLEFT", 90, -60)
  pfUI.unlock.dock.ycoord:SetFontObject(GameFontNormal)
  pfUI.unlock.dock.ycoord:SetAutoFocus(false)

  pfUI.unlock.dock.ycoord:SetScript("OnEnterPressed", function(self)
    local newYPos = tonumber(this:GetText())
    if newYPos then
      local frame = pfUI.unlock.dock.parent.frame
      local anchor, rel, relpoint, xpos, ypos = frame:GetPoint()
      frame:ClearAllPoints()
      frame:SetPoint(anchor, rel or UIParent, relpoint or anchor, xpos, newYPos)
      SavePosition(frame)
    else
      UpdateDockValues()
    end
    this:ClearFocus()
  end)

  pfUI.unlock.dock.ycoord:SetScript("OnTextChanged", function(self)
    if tonumber(this:GetText()) then
      this:SetTextColor(1,1,1,1)
    else
      this:SetTextColor(1,.3,.3,1)
    end
  end)

  CreateBackdrop(pfUI.unlock.dock.ycoord, nil, true)

  -- reset button
  pfUI.unlock.dock.reset = CreateFrame("Button", "pfDragDockReset", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.reset:SetHeight(18)
  pfUI.unlock.dock.reset:SetPoint("TOPLEFT", 5, -85)
  pfUI.unlock.dock.reset:SetPoint("TOPRIGHT", -5, -85)
  pfUI.unlock.dock.reset:SetScript("OnClick", function()
    local frame = pfUI.unlock.dock.parent.frame

    if this:GetText() == T["Reset"] then
      pfUI_config["position"][frame:GetName()] = nil
      frame:ClearAllPoints()
      UpdateMovable(frame)
    else
      frame:StartMoving()
      frame:StopMovingOrSizing()
      SavePosition(frame)
    end

    if frame.OnMove then frame:OnMove() end

    QueueFunction(SetDockToFrame, pfUI.unlock.dock.parent)
  end)
  SkinButton(pfUI.unlock.dock.reset)

  -- move left
  pfUI.unlock.dock.left = CreateFrame("Button", "pfDragDockPosUp", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.left:SetHeight(18)
  pfUI.unlock.dock.left:SetWidth(18)
  pfUI.unlock.dock.left:SetPoint("TOP", -50, -110)
  pfUI.unlock.dock.left.texture = pfUI.unlock.dock.left:CreateTexture("arrow")
  pfUI.unlock.dock.left.texture:SetTexture(pfUI.media["img:left"])
  pfUI.unlock.dock.left.texture:ClearAllPoints()
  pfUI.unlock.dock.left.texture:SetPoint("TOPLEFT", pfUI.unlock.dock.left, "TOPLEFT", 4, -2)
  pfUI.unlock.dock.left.texture:SetPoint("BOTTOMRIGHT", pfUI.unlock.dock.left, "BOTTOMRIGHT", -4, 2)
  pfUI.unlock.dock.left:SetScript("OnClick", function()
    local frame = pfUI.unlock.dock.parent.frame
    local anchor, rel, relpoint, xpos, ypos = frame:GetPoint()
    frame:ClearAllPoints()
    frame:SetPoint(anchor or "TOPLEFT", rel or UIParent, relpoint or anchor or "TOPLEFT", xpos - (IsShiftKeyDown() and 10 or 1), ypos)
    SavePosition(frame)
    UpdateDockValues()
  end)
  SkinButton(pfUI.unlock.dock.left)

  -- move right
  pfUI.unlock.dock.right = CreateFrame("Button", "pfDragDockPosUp", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.right:SetHeight(18)
  pfUI.unlock.dock.right:SetWidth(18)
  pfUI.unlock.dock.right:SetPoint("TOP", -25, -110)
  pfUI.unlock.dock.right.texture = pfUI.unlock.dock.right:CreateTexture("arrow")
  pfUI.unlock.dock.right.texture:SetTexture(pfUI.media["img:right"])
  pfUI.unlock.dock.right.texture:ClearAllPoints()
  pfUI.unlock.dock.right.texture:SetPoint("TOPLEFT", pfUI.unlock.dock.right, "TOPLEFT", 4, -2)
  pfUI.unlock.dock.right.texture:SetPoint("BOTTOMRIGHT", pfUI.unlock.dock.right, "BOTTOMRIGHT", -4, 2)
  pfUI.unlock.dock.right:SetScript("OnClick", function()
    local frame = pfUI.unlock.dock.parent.frame
    local anchor, rel, relpoint, xpos, ypos = frame:GetPoint()
    frame:ClearAllPoints()
    frame:SetPoint(anchor or "TOPLEFT", rel or UIParent, relpoint or anchor or "TOPLEFT", xpos + (IsShiftKeyDown() and 10 or 1), ypos)
    SavePosition(frame)
    UpdateDockValues()
  end)
  SkinButton(pfUI.unlock.dock.right)

  -- move up
  pfUI.unlock.dock.up = CreateFrame("Button", "pfDragDockPosUp", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.up:SetHeight(18)
  pfUI.unlock.dock.up:SetWidth(18)
  pfUI.unlock.dock.up:SetPoint("TOP", 25, -110)
  pfUI.unlock.dock.up.texture = pfUI.unlock.dock.up:CreateTexture("arrow")
  pfUI.unlock.dock.up.texture:SetTexture(pfUI.media["img:up"])
  pfUI.unlock.dock.up.texture:ClearAllPoints()
  pfUI.unlock.dock.up.texture:SetPoint("TOPLEFT", pfUI.unlock.dock.up, "TOPLEFT", 4, -2)
  pfUI.unlock.dock.up.texture:SetPoint("BOTTOMRIGHT", pfUI.unlock.dock.up, "BOTTOMRIGHT", -4, 2)
  pfUI.unlock.dock.up:SetScript("OnClick", function()
    local frame = pfUI.unlock.dock.parent.frame
    local anchor, rel, relpoint, xpos, ypos = frame:GetPoint()
    frame:ClearAllPoints()
    frame:SetPoint(anchor or "TOPLEFT", rel or UIParent, relpoint or anchor or "TOPLEFT", xpos, ypos + (IsShiftKeyDown() and 10 or 1))
    SavePosition(frame)
    UpdateDockValues()
  end)
  SkinButton(pfUI.unlock.dock.up)

  -- move down
  pfUI.unlock.dock.down = CreateFrame("Button", "pfDragDockPosUp", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.down:SetHeight(18)
  pfUI.unlock.dock.down:SetWidth(18)
  pfUI.unlock.dock.down:SetPoint("TOP", 50, -110)
  pfUI.unlock.dock.down.texture = pfUI.unlock.dock.down:CreateTexture("arrow")
  pfUI.unlock.dock.down.texture:SetTexture(pfUI.media["img:down"])
  pfUI.unlock.dock.down.texture:ClearAllPoints()
  pfUI.unlock.dock.down.texture:SetPoint("TOPLEFT", pfUI.unlock.dock.down, "TOPLEFT", 4, -2)
  pfUI.unlock.dock.down.texture:SetPoint("BOTTOMRIGHT", pfUI.unlock.dock.down, "BOTTOMRIGHT", -4, 2)
  pfUI.unlock.dock.down:SetScript("OnClick", function()
    local frame = pfUI.unlock.dock.parent.frame
    local anchor, rel, relpoint, xpos, ypos = frame:GetPoint()
    frame:ClearAllPoints()
    frame:SetPoint(anchor or "TOPLEFT", rel or UIParent, relpoint or anchor or "TOPLEFT", xpos, ypos - (IsShiftKeyDown() and 10 or 1))
    SavePosition(frame)
    UpdateDockValues()
  end)
  SkinButton(pfUI.unlock.dock.down)

  -- octo (25 Oct 2026): the size - readout, smaller / bigger by one notch
  -- of the wheel (Shift / Ctrl as on the wheel), and Match
  local dock = pfUI.unlock.dock
  dock:SetHeight(228)
  dock.size = dock:CreateFontString(nil, "DIALOG")
  dock.size:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
  dock.size:SetTextColor(1, .82, 0)
  dock.size:SetPoint("TOPLEFT", 5, -134)
  dock.size:SetPoint("TOPRIGHT", -5, -134)
  dock.size:SetHeight(42)
  dock.size:SetJustifyH("CENTER")
  local function DockButton(text, tip, run)
    local b = CreateFrame("Button", nil, dock, "UIPanelButtonTemplate")
    b:SetHeight(20)
    b:SetText(text)
    SkinButton(b)
    b:SetScript("OnClick", run)
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText(text, 1, 1, 1)
      GameTooltip:AddLine(tip, .8, .8, .8, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end
  local SIZETIP = T["Shift: 10% (raid frames 5 px). Ctrl: 0.5%."]
  dock.smaller = DockButton("-", T["Smaller by one notch of the wheel."] .. "\n" .. SIZETIP, function()
    if dock.parent then Resize(dock.parent, -1) UpdateDockValues() end
  end)
  dock.smaller:SetWidth(22)
  dock.smaller:SetPoint("TOPLEFT", 5, -180)
  dock.bigger = DockButton("+", T["Bigger by one notch of the wheel."] .. "\n" .. SIZETIP, function()
    if dock.parent then Resize(dock.parent, 1) UpdateDockValues() end
  end)
  dock.bigger:SetWidth(22)
  dock.bigger:SetPoint("LEFT", dock.smaller, "RIGHT", 4, 0)
  dock.match = DockButton(T["Match / Lock..."], T["Match: give this box the size of another one (action bars take the other "
    .. "bar's button size, spacing and scale). Lock: fix it to another box so it moves with that one, lock others to it to "
    .. "move them as a group, or lock it back where it was (a mana bar back on the Player frame)."], function()
    if dock.parent then OpenMatchMenu(dock.parent, this) end
  end)
  dock.match:SetPoint("LEFT", dock.bigger, "RIGHT", 4, 0)
  dock.match:SetPoint("RIGHT", dock, "RIGHT", -5, 0)
  -- (gold: it copies a size, as Match on the options pages)
  dock.match:SetBackdropColor(.25, .2, .05, 1)
  dock.match:SetBackdropBorderColor(.85, .66, .17, 1)
  local mt = dock.match:GetFontString()
  if mt then mt:SetTextColor(1, .85, .4) end

  -- open config
  pfUI.unlock.dock.config = CreateFrame("Button", "pfDragDockConfigOpen", pfUI.unlock.dock, "UIPanelButtonTemplate")
  pfUI.unlock.dock.config:SetHeight(18)
  pfUI.unlock.dock.config:SetPoint("BOTTOMLEFT", 5, 5)
  pfUI.unlock.dock.config:SetPoint("BOTTOMRIGHT", dock, "BOTTOM", -2, 5)
  pfUI.unlock.dock.config:SetText(T["Configure"])
  pfUI.unlock.dock.config:SetScript("OnClick", function()
    local cat, conf = GetConfigTable(pfUI.unlock.dock.parent.label)
    if cat then OpenConfigDialog(cat, conf) end
  end)
  SkinButton(pfUI.unlock.dock.config)

  -- octo: Hide / Show this frame (red off, green on - W.ROLE's colours)
  dock.hide = DockButton(T["Hide"], T["Hide this frame, over reloads too. While layout mode is open it stays here, "
    .. "its box red, so you can bring it back with Show."], function()
    local f = dock.parent and dock.parent.frame
    local n = f and f:GetName()
    if not n then return end
    C.unlock.hidden = C.unlock.hidden or {}
    if C.unlock.hidden[n] == "1" then C.unlock.hidden[n] = nil else C.unlock.hidden[n] = "1" end
    UpdateDockValues()
  end)
  dock.hide:SetHeight(18)
  dock.hide:SetPoint("BOTTOMLEFT", dock, "BOTTOM", 2, 5)
  dock.hide:SetPoint("BOTTOMRIGHT", -5, 5)
  function dock.PaintHide()
    local off = dock.parent and IsHiddenFrame(dock.parent.frame)
    dock.hide:SetText(off and T["Show"] or T["Hide"])
    local fs = dock.hide:GetFontString()
    if off then
      dock.hide:SetBackdropColor(.05, .2, .07, 1)
      dock.hide:SetBackdropBorderColor(.3, .85, .4, 1)
      if fs then fs:SetTextColor(.5, 1, .55) end
    else
      dock.hide:SetBackdropColor(.22, .04, .04, 1)
      dock.hide:SetBackdropBorderColor(.9, .25, .25, 1)
      if fs then fs:SetTextColor(1, .55, .55) end
    end
    if dock.parent then Paint(dock.parent, "picked") end
  end
end)
