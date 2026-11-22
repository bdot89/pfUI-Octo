-- pfUI Octo: the Group Finder skin (skins/blizzard/lft.lua, 22 Nov 2026, Lobo: the group finder and its ready
-- check "seem to be the default blizzard ui"). The frames come from the client's FrameXML\LFT; here they are made
-- by hand with the names of patch-4's LFT.xml, then the skin runs on them.
local ok = octo_ok
local fn = pfUI.skin and pfUI.skin["Group Finder"]
ok(fn, "Group Finder skin registered")
if not fn then return end

local names = { "LFTFrame", "LFTFrameTab1", "LFTFrameTab2", "LFTFrameMainButton", "LFTFrameScrollFrameScrollBar",
  "LFTRoleCheckFrame", "LFTRoleCheckFrameConfirmButton", "LFTRoleCheckFrameDeclineButton", "LFTRoleCheckFrameTimer",
  "LFTGroupReadyFrame", "LFTGroupReadyFrameConfirmButton", "LFTGroupReadyFrameDeclineButton", "LFTGroupReadyFrameTimer",
  "LFTGroupReadyStatusFrame", "LFTGroupReadyStatusFrameCloseButton", "LFTNewGroupFrame", "LFTNewGroupOkButton" }
local keep = {}
for _, n in ipairs(names) do keep[n] = rawget(_G, n) end

local lft = CreateFrame("Frame", "LFTFrame", UIParent)
_G.LFTFrame = lft
for _, n in ipairs(names) do
  if n ~= "LFTFrame" then
    local kind = string.find(n, "Timer$") and "StatusBar" or (string.find(n, "Frame$") and "Frame" or "Button")
    _G[n] = CreateFrame(kind, n, string.find(n, "^LFTFrame") and lft or UIParent)
  end
end
local good, err = pcall(fn)
ok(good, "the Group Finder skin runs: " .. tostring(err))
ok(LFTFrame.backdrop, "the Group Finder window gets pfUI's panel")
ok(LFTFrameTab1.backdrop and LFTFrameTab2.backdrop, "its Group Browser / Dungeon Finder tabs are pfUI's")
ok(LFTRoleCheckFrameTimer.backdrop and LFTGroupReadyFrameTimer.backdrop, "the countdown bars are pfUI's")
for _, n in ipairs(names) do _G[n] = keep[n] end
