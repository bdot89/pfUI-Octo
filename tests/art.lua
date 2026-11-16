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

-- (16 Nov 2026) the game-icons.net crests: about a hundred, square, in groups, on nameplates too
local icons = pfUI.artIcons or {}
ok(table.getn(icons) >= 100, "game-icons crests: " .. table.getn(icons))
local _, w, h = A.Crest("gi-lorc-crowned-skull", "elite")
ok(w == 32 and h == 32 and string.find(A.Crest("gi-lorc-crowned-skull", "rare"), "elite\\gi\\lorc-crowned-skull-rare", 1, true), "an icon crest is square, per kind")
local _, w2 = A.Crest("wings", "elite")
ok(w2 == 46, "the drawn crests stay wide")
ok(table.getn(A.GROUPS) >= 8 and A.GROUPS[1] == "pfUI Octo", "crest groups (" .. table.concat(A.GROUPS, ", ") .. ")")
local plateOk = true
for _, ic in ipairs(icons) do if not exists(A.PlateArt("gi-" .. ic[1])) then plateOk = false end end
ok(plateOk, "every icon has its nameplate mark")
local P = pfUI.plates
if P and P.MarkArt then ok(P.MarkArt("gi-lorc-dragon-head") ~= nil and P.MarkArt("none") == nil, "nameplates offer the icon crests") end
ok(A.MarkSheet("emblems") and A.MarkSheet("fantasy"), "two game-icons raid mark sets")
S.elite = "gi-lorc-wyvern"
good, e = pcall(function() O:Page("art") O:Rebuild("art") end)
ok(good, "the Art page builds with an icon crest picked" .. (good and "" or (": " .. tostring(e))))
S.elite = "classic"

-- gryphon pictures brought by other add-ons (pfUI-CustomMedia) join the Gryphons page's list
do
  local GR = pfUI.gryphons
  ok(GR and GR.MergeTextures, "gryphons can take other add-ons' pictures")
  if GR then
    local n = table.getn(GR.art)
    GR.textures["Custom Phoenix"] = "Interface\\AddOns\\pfUI-CustomMedia\\gryphons\\phoenix"
    ok(GR.MergeTextures() == 1 and table.getn(GR.art) == n + 1 and GR.Art("Custom Phoenix") and GR.Art("Custom Phoenix").coords, "a new picture is added once")
    ok(GR.MergeTextures() == 0, "and not twice")
    GR.textures["Custom Phoenix"] = nil
    table.remove(GR.art, table.getn(GR.art))
  end
end
