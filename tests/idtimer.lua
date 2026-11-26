-- pfUI Octo: ID Timer (modules/idtimer.lua, the user's IDTimer add-on built in), run by tests\run.lua.
local ok = octo_ok
local IT = pfUI.idtimer
ok(IT and IT.Enable and IT.Disable and IT.Start, "ID Timer loaded (pfUI.idtimer)")
if not IT then return end

-- off as it comes: no engine, no window, one question at the first reset
pfUI_config.idtimer = pfUI_config.idtimer or {}
ok(not IT.On() and rawget(_G, "IDTimerFrame") == nil, "off as it comes: nothing made")
ok(StaticPopupDialogs["PFUI_IDTIMER_ASK"] ~= nil, "the first-reset question is there")

-- on: the engine and the window, data in pfUI's own save
IT.Enable()
local IDT = rawget(_G, "IDTimer")
ok(IDT and IDT.db and IDT.db == pfUI_cache.idtimer and rawget(_G, "IDTimerFrame"), "switched on: the engine and its window, data in pfUI_cache.idtimer")
if IDT and IDT.db then
  IDT.db.entries, IDT.db.resets = {}, {}
  -- (a minute ago: a reset in the very second of the entry counts as the same visit, as in the add-on)
  IDT.AddEntry("Scarlet Monastery", nil, time() - 60)
  ok(IDT.Count() == 1 and IDT.Free() == 4, "a lockout counts: 1 used, 4 free")
  local again = IDT.OnEnterInstance("Scarlet Monastery", true)
  ok(again == false and IDT.Count() == 1, "walking back into the same instance uses no new slot")
  IDT.MarkReset("Scarlet Monastery")
  local fresh = IDT.OnEnterInstance("Scarlet Monastery", true)
  ok(fresh == true and IDT.Count() == 2, "after a reset the next entry is a new slot")
  ok(IDT.FormatTime(3599) == "59:59" and IDT.FormatLong(90061) == "1d 1h", "its time formats")
  local okp, errp = pcall(function() IDT.Refresh() IDT.Tick() IDT.Toggle() IDT.Toggle() end)
  ok(okp, "its window paints: " .. tostring(errp))
  IDT.db.entries, IDT.db.resets = {}, {}
end
IT.Disable()
ok(not IT.On(), "switched off again")
