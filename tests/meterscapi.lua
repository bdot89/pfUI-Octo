-- pfUI Octo: ClassicAPI 1.22's damage meter as a source for the meter windows (modules/meters-capi.lua), run by
-- tests\run.lua. Stubs shaped like ClassicAPI's docs/API.md "DamageMeter".
local ok = octo_ok
local M = pfUI.meters
local CA = M and M.capi
ok(CA and CA.Rows and CA.Apply and M.OwnRows, "ClassicAPI meter source loaded (pfUI.meters.capi)")
if not CA then return end

local keep = {}
for _, k in ipairs({ "C_DamageMeter", "Enum", "GetCVar", "SetCVar", "DamageMeter", "DamageMeterSystemSetting", "SpellInfo" }) do
  keep[k] = rawget(_G, k)
end
local keepCfg = { pfUI_config.meters.capi, pfUI_config.meters.capiwindow }
local keepCur, keepHist, keepOverall = M.current, M.history, M.overall

-- without ClassicAPI: our own rows
_G.C_DamageMeter = nil
CA.Apply()
ok(not CA.On(), "no ClassicAPI: not in use")

local cvar = "0"
_G.GetCVar = function(n) if n == "damageMeterEnabled" then return cvar end end
_G.SetCVar = function(n, v) if n == "damageMeterEnabled" then cvar = v end end
_G.Enum = {
  DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5, Dispels = 6, DamageTaken = 7,
                      AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10 },
  DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 },
  DamageMeterVisibility = { Always = 0, InCombat = 1, Hidden = 2, InGroup = 3 },
}
local resets, asked = 0, {}
_G.C_DamageMeter = {
  IsDamageMeterAvailable = function() return true, "" end,
  GetCombatSessionFromType = function(s, t)
    table.insert(asked, { s, t })
    if t == 0 then
      return { totalAmount = 1500, maxAmount = 1000, durationSeconds = 10, combatSources = {
        { name = "Stabby", classFilename = "ROGUE", totalAmount = 1000, amountPerSecond = 100, sourceGUID = "0x1" },
        { name = "Pewpew", classFilename = "HUNTER", totalAmount = 500, amountPerSecond = 50, sourceGUID = "0x2" } } }
    end
    if t == 1 then
      return { combatSources = { { name = "Stabby", classFilename = "ROGUE", totalAmount = 1000, amountPerSecond = 100 } } }
    end
    return { combatSources = {} }
  end,
  GetCombatSessionSourceFromType = function(s, t, guid)
    return { combatSpells = { { spellID = 6603, totalAmount = 700, amountPerSecond = 70, overkillAmount = 0 } } }
  end,
  ResetAllCombatSessions = function() resets = resets + 1 end,
}
-- ClassicAPI's own window
local vis
_G.DamageMeterSystemSetting = { Visibility = "Visibility" }
_G.DamageMeter = {
  GetSettingValue = function(self, s) return vis end,
  OnSystemSettingChange = function(self, s, v) vis = v end,
  UpdateShownState = function() end,
}

pfUI_config.meters.capi, pfUI_config.meters.capiwindow = "1", "0"
CA.Apply()
ok(cvar == "1" and CA.On(), "switched on: ClassicAPI's counting turned on (cvar damageMeterEnabled)")
ok(vis == 2, "its own window set Hidden")
pfUI_config.meters.capiwindow = "1"
CA.ApplyWindow()
ok(vis == 0, "Show its own window: Always")

-- our segment, with different numbers: current / overall rows come from the DLL, earlier fights from ours
M.current = { name = "Test", actors = { Stabby = { class = "ROGUE", damage = 900, heal = 0 }, Pewpew = { class = "HUNTER", damage = 10, heal = 0 } },
              foes = {}, start = 0, time = 10 }
local rows = M.Rows("damage", "current")
ok(rows[1] and rows[1].name == "Stabby" and rows[1].value == 1000 and rows[1].capi and rows[1].actor == M.current.actors.Stabby,
  "current fight: ClassicAPI's damage, with our actor for the breakdown")
ok(rows[2] and rows[2].value == 500 and math.floor(rows[1].pct + .5) == 67, "shares from ClassicAPI's totals")
rows = M.Rows("dps", "current")
ok(rows[1] and rows[1].value == 100, "DPS: ClassicAPI's per second")
M.history = { M.current }
local mine = M.Rows("damage", "2")
ok(not (mine[1] and mine[1].capi), "an earlier fight: our own numbers")
rows = M.Rows("buffs", "current")
ok(not (rows[1] and rows[1].capi), "a display ClassicAPI does not count: ours")
local sp = CA.Spells("current", "damage", { sourceGUID = "0x1" })
ok(sp and sp[1] and sp[1].id == 6603 and sp[1].total == 700, "one source's spells from ClassicAPI")
local lines = CA.Check("current")
ok(lines[1] and string.find(lines[1], "^damage: ours"), "check line: " .. tostring(lines[1]))
-- our Reset clears the DLL's sessions too
M.Reset()
ok(resets == 1, "Reset clears ClassicAPI's sessions too")
-- switched off: ours again
pfUI_config.meters.capi = "0"
CA.Apply()
M.current = { name = "Test", actors = { Stabby = { class = "ROGUE", damage = 900, heal = 0 } }, foes = {}, start = 0, time = 10 }
rows = M.Rows("damage", "current")
ok(not (rows[1] and rows[1].capi), "option off: our own numbers")

for k, v in pairs(keep) do _G[k] = v end
pfUI_config.meters.capi, pfUI_config.meters.capiwindow = keepCfg[1], keepCfg[2]
M.current, M.history, M.overall = keepCur, keepHist, keepOverall
CA.Apply()
