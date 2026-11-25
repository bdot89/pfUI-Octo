-- pfUI Octo: the nameplates' longest name (modules/nameplates.lua ShortName, 25 Nov 2026, Wolfahrt: "a maximum number
-- of characters ... to not take too much space with long names")
local ok = octo_ok
local NP = pfUI.nameplates
ok(NP and NP.ShortName, "nameplate name shortener loaded")
if not (NP and NP.ShortName) then return end
local P = pfUI_config.plates
local keepMax, keepShort = P.namemax, P.nameshort

P.namemax = "0"
ok(NP.ShortName("Infinite Riftweaver") == "Infinite Riftweaver", "0: any length")
P.namemax, P.nameshort = "12", "dots"
ok(NP.ShortName("Infinite Riftweaver") == "Infinite Ri...", "cut with ... (" .. NP.ShortName("Infinite Riftweaver") .. ")")
ok(NP.ShortName("Hogger") == "Hogger", "a short name stays as it is")
P.nameshort = "words"
ok(NP.ShortName("Infinite Riftweaver") == "I. Riftweaver" or NP.ShortName("Infinite Riftweaver") == "I. Riftweav...",
  "first words as letters (" .. NP.ShortName("Infinite Riftweaver") .. ")")
P.namemax = "14"
ok(NP.ShortName("Infinite Riftweaver") == "I. Riftweaver", "the initial is enough: no cut (" .. NP.ShortName("Infinite Riftweaver") .. ")")
P.namemax = "6"
ok(NP.ShortName("Ältester Hüter") == "Ä. Hü...", "letters, not bytes: accents are one letter each (" .. NP.ShortName("Ältester Hüter") .. ")")
P.namemax, P.nameshort = keepMax, keepShort
