-- OctoShare death + crit feeds (28 Nov 2026): the combat-log patterns on real 1.12 English lines, and that only a new
-- best crit is sent. Standalone (its own tiny host), run by tests\run.ps1 after run.lua.
local sent, fails, checks = {}, 0, 0
local function ok(cond, what)
  checks = checks + 1
  if not cond then fails = fails + 1 print("FAIL " .. what) end
end

-- a minimal pfUI module host
pfUI = { octoshare = { Emit = function(kind, payload) table.insert(sent, kind .. "^" .. payload) end,
                       Enabled = function() return true end } }
pfUI_cache = { octoshare = {} }
local frame = { RegisterEvent = function() end, SetScript = function() end }
CreateFrame = function() return frame end
GetTime = function() return 100 end
GetRealZoneText = function() return "Durotar" end
UnitLevel = function() return 41 end
UnitFactionGroup = function() return "Horde" end
function pfUI:RegisterModule(name, kind, fn) fn() end
dofile("modules/octoshare-feeds.lua")
local F = pfUI.octoshare.feeds

-- deaths: the last thing that hurt you
F.Hurt("Kolkar Bloodcharger hits you for 87.")
F.Died()
ok(sent[1] == "death^Durotar^41^Kolkar Bloodcharger", "melee killer: " .. tostring(sent[1]))
F.Hurt("Defias Pillager's Fireball hits you for 210 Fire damage.")
F.Died()
ok(sent[2] == "death^Durotar^41^Defias Pillager", "spell killer: " .. tostring(sent[2]))
F.Hurt("You suffer 30 Shadow damage from Grimtotem Shaman's Shadow Word: Pain.")
F.Died()
ok(sent[3] == "death^Durotar^41^Grimtotem Shaman", "dot killer: " .. tostring(sent[3]))
F.Died()
ok(sent[4] == "death^Durotar^41^", "no killer after it was used: " .. tostring(sent[4]))

-- crits: only a new best goes out
sent = {}
F.Crit("Your Fireball crits Kobold Miner for 2500 Fire damage.", false)
F.Crit("Your Frostbolt crits Kobold Miner for 2100 Frost damage.", false)
F.Crit("You crit Kobold Miner for 2900.", false)
F.Crit("Your Flash Heal critically heals Mosshoof for 1500.", true)
F.Crit("Your Flash Heal heals Mosshoof for 900.", true)
ok(sent[1] == "crit^2500^Fireball^dmg", "first crit: " .. tostring(sent[1]))
ok(sent[2] == "crit^2900^Melee^dmg", "melee best: " .. tostring(sent[2]))
ok(sent[3] == "crit^1500^Flash Heal^heal", "crit heal: " .. tostring(sent[3]))
ok(table.getn(sent) == 3, "only new bests sent (" .. table.getn(sent) .. ")")
ok(pfUI_cache.octoshare.rec.dmg == 2900, "best kept in the cache")

print(checks .. " checks, " .. fails .. " failed")
if fails > 0 then os.exit(1) end
