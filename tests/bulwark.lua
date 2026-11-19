-- pfUI Octo: Earthen Bulwark bar (modules/bulwark.lua), run by tests\run.lua:
-- the integrity % from the durability buff's tooltip, the absorbing buff's timer, the amount from max health, shield x3.
local ok = octo_ok
local BW = pfUI.bulwark
ok(BW and BW.Read and BW.View and BW.Paint and BW.Sample, "bulwark bar loaded (pfUI.bulwark)")
if not BW then return end
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.bulwark, "OctoTotems > Earthen Bulwark registered")
local S = pfUI_config.bulwark
ok(S and S.enable == "1" and S.show == "auto" and S.textmode == "both", "defaults")

ok(BW.PctOf({ "Bulwark integrity is at 62%." }) == 62, "integrity read from the tooltip line")
ok(BW.PctOf({ nil, "Absorbs damage." }) == nil, "no number = nil")

local keep = {}
for _, k in ipairs({ "GetPlayerBuff", "GetPlayerBuffTexture", "GetPlayerBuffTimeLeft", "UnitHealthMax", "GetInventoryItemLink", "GetItemInfo" }) do keep[k] = rawget(_G, k) end
local LT = pfUI.api.libtipscan
local keepScanner = LT.GetScanner
local buffs = {
  { name = "Earthen Bulwark Durability", line = "Bulwark integrity is at 50%.", tex = "A" },
  { name = "Earthen Bulwark", line = "Absorbs damage.", tex = "B", left = 5.5 },
}
_G.GetPlayerBuff = function(i) if buffs[i + 1] then return i, 0 end return -1 end
_G.GetPlayerBuffTexture = function(bid) return buffs[bid + 1].tex end
_G.GetPlayerBuffTimeLeft = function(bid) return buffs[bid + 1].left or 0 end
_G.UnitHealthMax = function() return 5000 end
local fake = { cur = nil }
function fake:SetPlayerBuff(bid) self.cur = buffs[bid + 1] end
function fake:Line(n) if not self.cur then return nil end if n == 1 then return self.cur.name elseif n == 2 then return self.cur.line end end
LT.GetScanner = function() return fake end
_G.GetInventoryItemLink = function(u, slot) if slot == 17 then return "|cffffffff|Hitem:1201:0:0:0|h[Dull Heater Shield]|h|r" end end
_G.GetItemInfo = function() return "Dull Heater Shield", "item:1201", 1, 5, "Armor", "Shields", 1, "INVTYPE_SHIELD", "x" end
BW.names = {}

local v = BW.View()
ok(v.pct == 50 and v.cap == 1000 and v.amount == 500, "50% of 20% of 5000 health = 500 (got " .. tostring(v.pct) .. " / " .. tostring(v.amount) .. " / " .. tostring(v.cap) .. ")")
ok(v.absorbing and v.left == 5.5, "absorbing buff seen with its time left")
ok(v.shield, "a shield in the off hand")

buffs[1].line = "Bulwark integrity is at 80%."
v = BW.View()
ok(v.pct == 80, "a changed integrity is read again (tooltip not cached)")

BW.shaman = true
local f = BW.NewBar(UIParent)
BW.Paint(f, v)
ok(f.text:GetText() == "80%   ~800 / 1,000", "bar text (" .. tostring(f.text:GetText()) .. ")")
S.textmode = "pct" BW.Paint(f, v)
ok(f.text:GetText() == "80%", "percent only")
S.textmode = "both"
ok(BW.Wanted(v), "shown while it holds something")
buffs = {}
BW.names = {}
v = BW.View()
ok(not v.has and not BW.Wanted(v), "hidden with no bulwark out of combat")
S.show = "always"
ok(BW.Wanted(v), "Always shows it")
S.show = "auto"
BW.shaman = false
S.show = "always"
ok(not BW.Wanted(v), "never on other classes")
S.show = "auto"

for k, fn in pairs(keep) do _G[k] = fn end
LT.GetScanner = keepScanner
BW.names = {}
