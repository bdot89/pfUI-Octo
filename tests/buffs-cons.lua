-- pfUI Octo: tracking buff filter + consolidated buffs + grow direction (modules/buff.lua,
-- pfUI.api.PlayerBuffIndex; 27 Nov 2026), run by tests\run.lua.
local ok = octo_ok
local keep = {}
for _, k in ipairs({ "GetPlayerBuff", "GetPlayerBuffTexture", "GetPlayerBuffTimeLeft", "GetTrackingTexture",
  "PLAYER_BUFF_START_ID", "GetWeaponEnchantInfo" }) do keep[k] = rawget(_G, k) end

local DRAGON = "Interface\\Icons\\INV_Misc_Head_Dragon_01"
-- slot k (1-based) = { texture, time left }
local buffs = {}
_G.PLAYER_BUFF_START_ID = -1
_G.GetPlayerBuff = function(i) if buffs[i + 1] then return i, 0 end return -1 end
_G.GetPlayerBuffTexture = function(i) return buffs[i + 1] and buffs[i + 1][1] end
_G.GetPlayerBuffTimeLeft = function(i) return buffs[i + 1] and buffs[i + 1][2] or 0 end
_G.GetTrackingTexture = function() return DRAGON end
_G.GetWeaponEnchantInfo = function() return nil end

local B = pfUI_config.buffs
local old = {}
for _, k in ipairs({ "hidetracking", "consolidate", "consmin", "consnotimer", "buffs", "buffgrow", "rowgrow" }) do old[k] = B[k] end

-- (Javelin: Track Dragonkin hid the Onyxia / Nefarian buff, same icon)
B.hidetracking = "1"
buffs = { { "Interface\\Icons\\Spell_Holy_WordFortitude", 1500 }, { DRAGON, 7000 }, { DRAGON, 0 }, { "Interface\\Icons\\Spell_Nature_Regeneration", 600 } }
local PBI = pfUI.api.PlayerBuffIndex
ok(PBI(1, "HELPFUL") == 1 and PBI(2, "HELPFUL") == 2 and PBI(3, "HELPFUL") == 4,
  "tracking hidden: the dragon head buff with a timer stays, the timeless tracking one goes")
buffs = { { DRAGON, 7000 }, { "Interface\\Icons\\Spell_Holy_WordFortitude", 1500 } }
ok(PBI(1, "HELPFUL") == 1 and PBI(2, "HELPFUL") == 2, "Onyxia buff alone, tracking something else: both shown")

-- consolidation: long buffs into the box
if pfUI.buff and pfUI.buff.GetScript and pfUI.buff:GetScript("OnEvent") then
  B.hidetracking = "0"
  B.buffs = "1"
  B.consolidate = "1"
  B.consmin = "10"
  B.consnotimer = "1"
  buffs = { { "a", 1800 }, { "b", 30 }, { "c", 0 }, { "d", 300 } }
  local okr, err = pcall(pfUI.buff:GetScript("OnEvent"))
  ok(okr, "buff refresh runs with consolidation: " .. tostring(err))
  local m, c = pfUI.buff.mainList, pfUI.buff.consList
  ok(table.getn(c) == 2 and c[1] == 1 and c[2] == 3 and table.getn(m) == 2 and m[1] == 2 and m[2] == 4,
    "30 min and timeless buffs go into the box, short ones stay in the row")
  ok(pfUI.buff.consOn and pfUI.buff.buffs.buttons[1].bid == -1 and pfUI.buff.buffs.buttons[2].bid == 1,
    "the box takes the first place, the row shows the short buffs after it")
  B.consolidate = "0"
  pcall(pfUI.buff:GetScript("OnEvent"))
  ok(not pfUI.buff.consOn and pfUI.buff.buffs.buttons[1].bid == 0, "off: every buff back in the row")

  -- grow direction: rows to the right, stacked up
  B.buffgrow, B.rowgrow = "right", "up"
  local okc, errc = pcall(pfUI.buff.UpdateConfig, pfUI.buff)
  ok(okc, "buff layout with right / up: " .. tostring(errc))
  local b2 = pfUI.buff.buffs.buttons[2]
  local pt = b2.GetPoint and b2:GetPoint(1)
  ok(pt == nil or pt == "BOTTOMLEFT", "right / up buffs hang on the frame's bottom left (" .. tostring(pt) .. ")")
end

for k, v in pairs(old) do B[k] = v end
for k, v in pairs(keep) do _G[k] = v end
if pfUI.buff and pfUI.buff.UpdateConfig then pcall(pfUI.buff.UpdateConfig, pfUI.buff) end
