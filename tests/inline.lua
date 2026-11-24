-- pfUI Octo: EllesmereUI-like rows (24 Nov 2026, octo-widgets W.More / W.AddColor), run by tests\run.lua.
-- A "..." on a row opens a one-column panel with its lesser settings; a colour can sit on its switch's line;
-- Find a setting still finds what is behind a "..."; pinned previews have no box or label bar.
local ok = octo_ok
local W = pfUI.octoui and pfUI.octoui.W
local O = pfUI.octoui and pfUI.octoui.Options
ok(W and W.More and W.AddColor, "W.More and W.AddColor exist")
if not (W and W.More and O and O.pages ~= nil) then return end

pfUI.gui:Show()
pcall(function() O:Select("o:npgeneral") end)
local p = O.pages.npgeneral
ok(p ~= nil, "nameplates Look page built")
if p then
  -- the Name card's size row carries a "..." with the two nudges
  local found
  for _, c in ipairs(p.cards) do
    if c.title == "Name" then
      local kids = { c.parent:GetChildren() }
      for _, r in ipairs(kids) do
        if r.more and r.label and r.label:GetText() == "Size" then found = r end
      end
    end
  end
  ok(found and found.more and found.more.pop, "Name > Size has a \"...\"")
  if found then
    local b = found.more
    ok(not b.pop:IsShown(), "its panel starts shut")
    _G.this = b
    b:GetScript("OnClick")()
    ok(b.pop:IsShown(), "a click opens it")
    local n = 0
    for _ in ipairs(b.q.items) do n = n + 1 end
    ok(n == 2, "it holds the two nudges (" .. n .. ")")
    _G.this = b
    b:GetScript("OnClick")()
    ok(not b.pop:IsShown(), "a second click shuts it")
  end
  -- Find a setting: what is behind a "..." belongs to its page
  local hit
  for _, e in ipairs(W.index) do
    if e.page == p and e.desc and string.find(e.desc, "behind the", 1, true) then hit = e end
  end
  ok(hit and hit.region, "Find a setting knows the settings behind a \"...\"")
  -- the pinned preview: no label bar, no panel; the box in it draws no frame
  ok(p.pin and p.pin.fold and p.pin.fold.t, "the preview strip has its quiet Hide preview word")
end
pfUI.gui:Hide()
