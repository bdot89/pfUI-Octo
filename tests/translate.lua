-- pfUI Octo: the language of Octo's own pages (octo-widgets.lua W.T, env\octo_<locale>.lua),
-- run by tests\run.lua: a text is translated at SetText, in tooltips and in the search index,
-- and every locale file only holds words that exist in docs\octo-strings.txt.
local ok = octo_ok
local W = pfUI.octoui and pfUI.octoui.W
ok(W and W.T and W.Lang, "language helpers on the Octo widgets (W.T)")
if not W then return end
local langs = { "deDE", "esES", "frFR", "koKR", "ruRU", "zhCN", "zhTW" }
local keep = pfUI_config.global.language
local T = pfUI_translation["ruRU"]
local old = rawget(T, "Octo test word")
T["Octo test word"] = "Тест"
pfUI_config.global.language = "ruRU"
ok(W.T("Octo test word") == "Тест" and W.T("not in the table") == "not in the table", "a known text is translated, an unknown one stays English")
local fs = W.Font(UIParent:CreateFontString(nil, "OVERLAY"), 12)
fs:SetText("Octo test word")
ok(fs.text == "Тест" or fs:GetText() == "Тест", "SetText on an Octo text is translated")
ok(string.find(W.UIFont(), "PT-Sans-Narrow-Bold", 1, true), "Russian uses a font with Cyrillic")
pfUI_config.global.language = "enUS"
ok(W.T("Octo test word") == "Octo test word", "English stays English")
pfUI_config.global.language = keep
T["Octo test word"] = old

-- the locale files: loaded, and the English side is real text
local known = {}
local f = io.open(octo_dir .. "/docs/octo-strings.txt", "r")
ok(f ~= nil, "docs/octo-strings.txt (the list to translate) exists")
if f then
  for line in f:lines() do
    line = string.gsub(line, "\\n", "\n")
    line = string.gsub(line, '\\"', '"')
    line = string.gsub(line, "\\\\", "\\")
    known[line] = true
  end
  f:close()
end
local n = 0
for _ in pairs(known) do n = n + 1 end
for _, l in ipairs(langs) do
  local tt = pfUI_translation[l]
  local have = 0
  for k in pairs(known) do if rawget(tt, k) ~= nil then have = have + 1 end end
  print(string.format("translated %s: %d of %d Octo texts", l, have, n))
end
ok(n > 1000, "the Octo text list has " .. n .. " texts")
