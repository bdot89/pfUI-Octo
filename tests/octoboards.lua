-- pfUI Octo: OctoBoards (modules/octoboards.lua, octoboards-window.lua), run by tests\run.lua
local ok = octo_ok
local LB = pfUI.boards
ok(LB and LB.Add and LB.Board and LB.Awards and LB.Show, "OctoBoards loaded (pfUI.boards)")
if not LB or not LB.Add then return end
pfUI_cache.boards = nil

-- counting from the game's own lines
local run = LB.events:GetScript("OnEvent")
local function Fire(e, a1)
  local ke, ka = rawget(_G, "event"), rawget(_G, "arg1")
  _G.event, _G.arg1 = e, a1
  run()
  _G.event, _G.arg1 = ke, ka
end
if SELFKILLOTHER then Fire("CHAT_MSG_COMBAT_HOSTILE_DEATH", string.format(SELFKILLOTHER, "Onyxian Whelp")) end
Fire("PLAYER_DEAD")
Fire("CHAT_MSG_MONEY", "You loot 2 Gold, 13 Silver, 5 Copper")
local m = LB.Me()
ok(m.all.dt == 1 and m.week.dt == 1, "a death counted, all time and this week")
ok(m.all.gl == 21305, "coins looted read as copper (" .. tostring(m.all.gl) .. ")")
if SELFKILLOTHER then ok(m.all.kl == 1 and m.all.kb == 1, "a kill and a killing blow from \"You have slain\"") end
LB.Add("bc", 500) LB.Add("bc", 300)
ok(m.all.bc == 500, "biggest crit keeps the highest")
ok(LB.Coins("You loot 45 Copper") == 45 and LB.Coins("") == 0, "coins: copper only, nothing")

-- the demo counts nothing
pfUI.demo = pfUI.demo or {}
local wasOn = pfUI.demo.on
pfUI.demo.on = true
Fire("PLAYER_DEAD")
ok(m.all.dt == 1, "nothing counted while the demo runs")
pfUI.demo.on = wasOn

-- sharing: what goes out, what comes in
local lines = LB.Lines()
ok(table.getn(lines) == 2 and string.find(lines[1], "^A%^") and string.find(lines[2], "^W%^") and not string.find(lines[1] .. lines[2], "|"),
  "two lines out, no | in them")
local t = LB.Unpack("dt=4,gl=900,kl=12", {})
ok(t.dt == 4 and t.gl == 900 and t.kl == 12, "packed numbers read back")
LB.Receive("A^MAGE^60^kl=40,dt=3,gl=50000", "GUILD", "Isolde")
LB.Receive("W^" .. LB.Week() .. "^kl=9,dt=2", "GUILD", "Isolde")
LB.Receive("A^WARRIOR^60^kl=7", "GUILD", "Brenna")
local o = LB.DB().others.Isolde
ok(o and o.class == "MAGE" and o.all.kl == 40 and o.week.kl == 9 and o.guild, "another player's numbers stored, from the guild")
local b = LB.Board("kl", "guild", "all")
ok(b[1].name == "Isolde" and b[1].rank == 1 and table.getn(b) == 3, "the guild board: best first, you and two others")
ok(LB.Rank("Brenna", "kl", "guild", "all") == 2, "a player's rank")
local wb = LB.Board("kl", "guild", "week")
ok(wb[1].name == "Isolde" and wb[1].value == 9, "this week's board reads the week's numbers")

-- tonight's awards from the meters' fights
local keepII, keepZ = rawget(_G, "IsInInstance"), rawget(_G, "GetRealZoneText")
_G.IsInInstance = function() return 1, "raid" end
_G.GetRealZoneText = function() return "Molten Core" end
local seg = { boss = "Ragnaros", actors = {
  Isolde = { class = "MAGE", damage = 90000, heal = 0, taken = 2000, interrupts = 1, dispels = 0, deaths = 0, spells = { Fireball = { name = "Fireball", cmax = 4800 } } },
  Brenna = { class = "WARRIOR", damage = 50000, heal = 0, taken = 80000, interrupts = 9, dispels = 0, deaths = 2, spells = {} },
  Mirelle = { class = "PRIEST", damage = 4000, heal = 120000, taken = 3000, interrupts = 0, dispels = 22, deaths = 0, spells = {} },
} }
LB.Fight(seg)
local n = LB.DB().night
ok(n and n.zone == "Molten Core" and n.bosses == 1 and n.p.Isolde.dm == 90000, "a raid fight goes into tonight")
local aw = {}
for _, a in ipairs(LB.Awards(n)) do aw[a.key] = a end
ok(aw.dm.who == "Isolde" and aw.hl.who == "Mirelle" and aw.it.who == "Brenna" and aw.dp.who == "Mirelle", "awards: damage, healing, kicks, cleanses")
ok(aw.dt.who == "Brenna" and aw.bc.who == "Isolde" and string.find(aw.bc.text, "Fireball"), "floor inspector and biggest crit (with its spell)")
ok(LB.Podium(n)[1].name == "Isolde", "the podium")
local dc = LB.DiscordText(n)
ok(string.find(dc, "Molten Core") and string.find(dc, ":first_place: Isolde"), "Discord text")
_G.IsInInstance, _G.GetRealZoneText = keepII, keepZ

-- words for numbers
ok(LB.Num(1420000, "big") == "1.42M" and LB.Num(12345, "big") == "12.3k" and LB.Num(4812) == "4,812", "big numbers")
ok(LB.Num(3890000, "money") == "389g" and LB.Num(7800, "time") == "2h 10m", "gold and time")

-- the window: every tab draws
local okA, errA = pcall(LB.Show, "awards")
ok(okA and pfOctoBoards and pfOctoBoards:IsShown(), "the window opens on Awards " .. tostring(errA or ""))
local okB, errB = pcall(LB.Show, "boards")
ok(okB, "Boards draws " .. tostring(errB or ""))
local okP, errP = pcall(LB.Show, "player", "Isolde")
ok(okP, "Player draws another player's card " .. tostring(errP or ""))
local okM, errM = pcall(LB.Show, "player")
ok(okM, "Player draws your own card " .. tostring(errM or ""))
ok(_G.SlashCmdList.PFBOARDS and _G.SLASH_PFBOARDS1 == "/boards", "/boards")
pfOctoBoards:Hide()

-- (26 Nov 2026) the Community tab: Chronicle's boards from tools\Sync-Chronicle.ps1
do
  local keep = rawget(pfUI, "boardsChronicle")
  ok(keep == nil or (type(keep.boards) == "table" and type(keep.realms) == "table"), "the generated Chronicle file reads as a table")
  pfUI.boardsChronicle = { updated = "26 Nov 2026 23:00", days = 7, raids = 2, players = 3, realms = { "N'Zoth", "Y'Shaarj" },
    boards = { realmwar = { all = { { "N'Zoth", "", "", "N'Zoth", 120, "40 raids" }, { "Y'Shaarj", "", "", "Y'Shaarj", 90, "30 raids" } } },
      topparse = { all = { { "Yanna", "PRIEST", "Sons of Mukla", "Y'Shaarj", 98.7, "23 boss kills" } }, ["Y'Shaarj"] = { { "Yanna", "PRIEST", "Sons of Mukla", "Y'Shaarj", 98.7, "23 boss kills" } } } } }
  local okC, errC = pcall(LB.Show, "community")
  ok(okC, "the Community tab draws " .. tostring(errC or ""))
  local UI = LB.ui
  UI.cboard, UI.cscope = "topparse", "Y'Shaarj"
  local okT, errT = pcall(UI.PaintCommunity)
  ok(okT and UI.frame.pages.community.rows[1]:IsShown(), "a realm's board shows its rows " .. tostring(errT or ""))
  ok(UI.CValue(98.7, "parse") == "98.7" and UI.CValue(195, "mins") == "3h 15m", "Chronicle values read right")
  for _, d in ipairs(UI.CBOARDS) do UI.cboard = d[1] local okB = pcall(UI.PaintCommunity) if not okB then ok(false, "board " .. d[1]) end end
  pfUI.boardsChronicle = keep
  pfOctoBoards:Hide()
end

-- (26 Nov 2026) nothing piles up: old players forgotten, at most LB.KEEP_MAX kept
do
  local d = LB.DB()
  local keep = d.others
  d.others = { Old = { t = time() - 90 * 86400, all = {} }, New = { t = time(), all = {} } }
  for i = 1, LB.KEEP_MAX + 20 do d.others["P" .. i] = { t = time() - i, all = {} } end
  LB.Prune()
  local n = 0
  for _ in pairs(d.others) do n = n + 1 end
  ok(d.others.Old == nil and d.others.New and n == LB.KEEP_MAX, "players unseen 60 days go, at most " .. LB.KEEP_MAX .. " kept (" .. n .. ")")
  d.others = keep
end

-- (27 Nov 2026) the Realm page (first tab) and the options shortcut
do
  local keep = rawget(pfUI, "boardsChronicle")
  pfUI.boardsChronicle = { updated = "27 Nov 2026 06:00", days = 7, raids = 563, players = 2830, realms = { "C'Thun", "N'Zoth", "Y'Shaarj" },
    boards = { realmwar = { all = { { "N'Zoth", "", "", "N'Zoth", 2680, "517 raids" }, { "Y'Shaarj", "", "", "Y'Shaarj", 271, "37 raids" }, { "C'Thun", "", "", "C'Thun", 49, "9 raids" } } },
      topdps = { all = { { "Dushegub", "WARLOCK", "Sons of Mukla", "Y'Shaarj", 2431, "on Ragnaros" }, { "Kael", "MAGE", "X", "N'Zoth", 2200, "on Garr" } } },
      tophps = { all = {} }, topparse = { all = { { "Shikiwa", "PALADIN", "Ost Ardent", "N'Zoth", 99.9, "14 boss kills" } } },
      guildweek = { all = { { "Oktagon", "", "", "N'Zoth", 120, "6 raids" } } }, speed = { all = { { "Molten Core", "", "Skull Emoji", "N'Zoth", 30.7, "33 players" } } } } }
  local okR, errR = pcall(LB.Show)
  ok(okR and LB.ui.tab == "realm" and LB.ui.frame.pages.realm:IsShown(), "OctoBoards opens on the Realm page " .. tostring(errR or ""))
  local p = LB.ui.frame.pages.realm
  ok(p.hero[1].name:GetText() == "Dushegub" and p.hero[2].name:GetText() == "Nobody yet", "top DPS card filled, an empty board says so")
  ok(LB.ui.CValue(30.7, "mins") == "30:42", "a clear time reads as minutes:seconds")
  LB.ui.cscope = "N'Zoth"
  local okS = pcall(LB.ui.PaintRealm)
  ok(okS, "a realm chip repaints the page")
  LB.ui.cscope = "all"
  pcall(LB.Show, "awards")
  local hidden = true
  for _, b in pairs(p.scopes) do if b:IsShown() then hidden = false end end
  ok(hidden, "the realm chips go away on the other tabs")
  local O = pfUI.octoui and pfUI.octoui.Options
  ok(not O or not O.logo or O.leaderboards, "Realm Leaderboards shortcut in the options sidebar")
  pfUI.boardsChronicle = keep
  pfOctoBoards:Hide()
end
