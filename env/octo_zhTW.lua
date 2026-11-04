-- pfUI Octo: zhTW text of Octo's own pages (modules/octo-*.lua, gear, meters, swing, ...).
-- Keys are the English texts exactly as pfUI Octo draws them (tests\run.lua with
-- PFUI_DUMP_STRINGS=<file> lists them); merged into pfUI's table, an entry pfUI
-- already has is kept. Words in |cffxxxxxx colour codes| and %d / %s stay as they are.
local T = pfUI_translation["zhTW"]
local words = {
}
for k, v in pairs(words) do if rawget(T, k) == nil then T[k] = v end end
