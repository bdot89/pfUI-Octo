-- pfUI Octo: art sets (modules/art.lua, art-options.lua), run by tests\run.lua:
-- the picture names for marks and crests, the defaults, and the Art page.
local ok = octo_ok
local A = pfUI.art
ok(A and A.MarkSheet and A.Crest, "art loaded (pfUI.art)")
if not A then return end
local S = pfUI_config.art
ok(S and S.marks == "pfui" and S.elite == "classic", "art defaults: stock marks, classic crest")
ok(A.MarkSheet("pfui") == nil, "the stock set leaves pfUI's sheet alone")
ok(string.find(A.MarkSheet("gloss") or "", "marks\\gloss", 1, true), "glossy marks sheet")
ok(A.MarkSheet("blizzard") == "Interface\\TargetingFrame\\UI-RaidTargetingIcons", "the game's own marks")
ok(A.Crest("classic", "elite") == nil, "classic crest = the old art")
ok(string.find(A.Crest("wings", "boss") or "", "elite\\wings-boss", 1, true), "a crest style picture name")
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.art, "options page Art registered")
local good, e = pcall(function() O:Page("art") end)
ok(good, "the Art page builds" .. (good and "" or (": " .. tostring(e))))
-- the files the sets name exist
local function exists(path)
  local rel = string.gsub(string.gsub(path, "Interface\\AddOns\\pfUI\\", ""), "\\", "/")
  local f = io.open(octo_dir .. "/" .. rel .. ".tga", "rb")
  if f then f:close() end
  return f ~= nil
end
for _, m in ipairs(A.MARKS) do
  if m.tex and string.find(m.tex, "AddOns", 1, true) then ok(exists(m.tex), "picture exists: " .. m.key) end
end
for _, s in ipairs(A.ELITE) do
  if s.key ~= "classic" then
    for _, k in ipairs({ "elite", "rare", "boss" }) do
      local p = A.Crest(s.key, k)
      ok(exists(p), "crest exists: " .. s.key .. " " .. k)
    end
  end
end
