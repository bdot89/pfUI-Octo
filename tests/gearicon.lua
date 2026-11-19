-- pfUI Octo: ItemRack set button picture follows what is worn (modules/gear.lua GR.UpdateButtons / GR.WornTex)
local ok = octo_ok
local GR = pfUI.gear
local btn = _G.pfGearButton
ok(GR and GR.UpdateButtons and GR.WornTex and btn, "gear button loaded")
if not (GR and btn and btn.icon) then return end
local keepCur, keepInv = GR.Current, GR.InvTex
local keepSets = pfUI_config.gear.sets
local SET, WORN = "Interface\\Icons\\INV_Misc_Book_09", "Interface\\Icons\\INV_Chest_Plate06x"
pfUI_config.gear.sets = { PvP = { icon = SET, slots = {} } }
GR.InvTex = function(inv) if inv == 5 then return WORN end end
GR.Current = function() return "PvP" end
GR.UpdateButtons()
ok(btn.icon:GetTexture() == SET, "a set worn exactly: its own picture")
GR.Current = function() return "PvP", true end
GR.UpdateButtons()
ok(btn.icon:GetTexture() == WORN, "a piece changed by hand: the picture of what is worn (" .. tostring(btn.icon:GetTexture()) .. ")")
GR.Current = function() return nil end
GR.UpdateButtons()
ok(btn.icon:GetTexture() == WORN, "no set: what is worn, not a grey default")
GR.Current, GR.InvTex = keepCur, keepInv
pfUI_config.gear.sets = keepSets
GR.UpdateButtons()
