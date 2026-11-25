pfUI:RegisterModule("octorank-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the OctoRanks page (24 Nov 2026), opened from the big "OctoRanks" entry at the top of the sidebar
  -- (above Move Frames). Its own module, so the switch stays here while OctoRanks is off. Light on purpose: who runs it,
  -- three ways into the rankings window, your best time in every dungeon and where it stands, how it works, settings.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local function OR() return pfUI.octorank end
  local function Eng()
    local or_ = OR()
    if or_ then return or_.Engine() end
  end
  local function Fmt(secs)
    secs = math.floor((tonumber(secs) or 0) + .5)
    local h, m, s = math.floor(secs / 3600), math.floor(math.mod(secs, 3600) / 60), math.mod(secs, 60)
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
  end

  -- the line under the window's big title
  O.SUBTITLE = O.SUBTITLE or {}
  O.SUBTITLE["OctoRanks"] = "5-man runs timed and ranked by themselves, shared with the realm."

  -- every dungeon: your best, your place on the realm's board, the realm's fastest group (rows drawn in a box)
  local ROWH = 22
  local function BestRows()
    local kind, eng = Eng()
    local out = {}
    if not kind or not eng.Data or not eng.Data.DUNGEONS or not eng.Runs then return out end
    local R, B = eng.Runs, eng.Board
    local realm = B and B.Realm and B.Realm() or (GetRealmName() or "")
    for _, d in ipairs(eng.Data.DUNGEONS) do
      local okB, best = pcall(R.MyBest, R, d.key)
      local okL, list = pcall(R.Board, R, realm, d.key, "All")
      if not okB then best = nil end
      if not okL or type(list) ~= "table" then list = {} end
      local place
      if best and best.t then
        local okP, pl = pcall(R.Place, R, realm, d.key, best.t, "All")
        if okP then place = pl end
      end
      local top = list[1] and list[1][2]
      table.insert(out, { d = d, best = best, place = place, n = table.getn(list), top = top })
    end
    return out
  end

  local function Build(p)
    local kind, eng = Eng()
    W.Heading(p, "OctoRanks", { on = O.ModuleSwitch("octorank", "OctoRanks"),
      about = "Nothing to switch on. Every level-60 5-man run is timed by itself: from the first pull after you zone in to "
        .. "the last boss, with each boss's split and the deaths. When the last boss dies the run goes to every OctoRanks, "
        .. "OctoRank and WhoDidIt user on your realm over a hidden channel - nothing is said in chat - so the boards fill "
        .. "up across the realm.\n\nThe raid boards are every guild's kill and clear times from Chronicle's public logs.\n\n"
        .. "With WhoDidIt installed, WhoDidIt runs it and this copy stands aside: the same channel, and the times of both "
        .. "are copied into each other at every login, so nothing is lost when you turn either off." })

    -- who runs it now, and the channel
    W.Live(p, function()
      local k, e = Eng()
      if not k then
        if C.disabled and C.disabled.octorank == "1" then return "|cffff5555Switched off.|r Turn it on above, then reload." end
        return "|cffff5555Not running.|r A reload starts it."
      end
      local o = OR().Opts() or {}
      local who = (k == "wdi") and "|cffffd100WhoDidIt|r runs it (pfUI's copy stands aside - the times are copied both ways)"
        or (k == "addon") and "|cffffd100The OctoRank add-on|r runs it (the same save as pfUI's; you can switch the add-on off)"
        or "|cff55ff55Built in|r - pfUI Octo runs it"
      local online = ""
      if e.Board and e.Board.OnlineCount and o.shareBoard then
        local ok, n = pcall(e.Board.OnlineCount)
        if ok and n then online = "   |cffffffff" .. n .. "|r online on the realm channel" end
      end
      local share = o.no5man and "   |cffff9933your runs stay on your PC|r" or "   |cff55ff55your runs are shared|r"
      if not o.shareBoard then share = "   |cffff9933realm channel off|r" end
      return who .. online .. share
    end)

    W.Tiles(p, {
      { "5-man boards", "Every dungeon's fastest groups", "Interface\\Icons\\INV_Misc_PocketWatch_01", function() OR().Open("five") end, "open" },
      { "Raid rankings", "Every guild's kills and clears", "Interface\\Icons\\INV_Misc_Head_Dragon_01", function() OR().Open("raids") end, "open" },
      { "Chronicle logs", "Log raids to upload", "Interface\\Icons\\INV_Misc_Note_01", function() OR().Open("logs") end, "open" },
    })

    -- your best times
    W.Card(p, "Your best times", { icon = "Interface\\Icons\\INV_Misc_PocketWatch_02",
      tip = "Your fastest run in each dungeon (any group you were in), where it stands on your realm's board, and the realm's fastest group. Click a row for that dungeon's board." })
    local rows = BestRows()
    local n = math.max(1, table.getn(rows))
    local box = W.Box(p, 24 + n * ROWH + 6)
    local head = {}
    local COLS = { { "Dungeon", 10, 200 }, { "Your best", 214, 80 }, { "Your place", 298, 90 }, { "Realm's fastest", 392, 260 } }
    for i, c in ipairs(COLS) do
      local fs = W.Font(box:CreateFontString(nil, "OVERLAY"), 11, .86, .68, .38)
      fs:SetPoint("TOPLEFT", box, "TOPLEFT", c[2], -6)
      fs:SetWidth(c[3])
      fs:SetJustifyH("LEFT")
      fs:SetText(c[1])
      head[i] = fs
    end
    local line = W.Fill(box, { .86, .68, .38 }, .35, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -22)
    line:SetPoint("TOPRIGHT", box, "TOPRIGHT", -8, -22)
    local lines = {}
    local function Row(i)
      if lines[i] then return lines[i] end
      local b = CreateFrame("Button", nil, box)
      b:SetHeight(ROWH)
      b:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -24 - (i - 1) * ROWH)
      b:SetPoint("TOPRIGHT", box, "TOPRIGHT", -2, -24 - (i - 1) * ROWH)
      b.art = b:CreateTexture(nil, "BACKGROUND")
      b.art:SetAllPoints(b)
      b.zebra = W.Fill(b, { 1, 1, 1 }, math.mod(i, 2) == 0 and .03 or 0, "BORDER")
      b.zebra:SetAllPoints(b)
      local hl = W.Fill(b, { .86, .68, .38 }, .10, "HIGHLIGHT")
      hl:SetAllPoints(b)
      b.cells = {}
      for j, c in ipairs(COLS) do
        local fs = W.Font(b:CreateFontString(nil, "OVERLAY"), 12, 1, 1, 1)
        fs:SetPoint("LEFT", b, "LEFT", c[2] - 2, 0)
        fs:SetWidth(c[3])
        fs:SetJustifyH("LEFT")
        b.cells[j] = fs
      end
      b:SetScript("OnClick", function()
        local _, e = Eng()
        if e and e.UI and this.key then
          pcall(function() e.UI.rk.inst = this.key end)
        end
        OR().Open("five")
      end)
      lines[i] = b
      return b
    end
    local function Paint()
      local list = BestRows()
      local _, e = Eng()
      for i, r in ipairs(list) do
        local b = Row(i)
        b.key = r.d.key
        local art = e and e.UI and e.UI.ZoneArt and e.UI.ZoneArt(r.d.title)
        if art then
          b.art:SetTexture(art[1])
          b.art:SetTexCoord(art[3] or 0, art[4] or 1, art[5] or 0, art[6] or 1)
          b.art:SetAlpha(.22)
          b.art:Show()
        else
          b.art:Hide()
        end
        b.cells[1]:SetText(r.d.title)
        if r.best then
          b.cells[2]:SetText("|cffffffff" .. Fmt(r.best.t) .. "|r")
          b.cells[3]:SetText(r.place and ((r.place == 1 and "|cffffd100#1|r" or ("#" .. r.place)) .. " |cff888888of " .. r.n .. "|r") or "-")
        else
          b.cells[2]:SetText("|cff666666none yet|r")
          b.cells[3]:SetText("|cff666666-|r")
        end
        if r.top then
          b.cells[4]:SetText("|cffffd100" .. (r.top.g or "?") .. "|r  " .. Fmt(r.top.t))
        else
          b.cells[4]:SetText("|cff666666no runs yet|r")
        end
        b:Show()
      end
      for i = table.getn(list) + 1, table.getn(lines) do lines[i]:Hide() end
      if table.getn(list) == 0 then
        local b = Row(1)
        b.art:Hide()
        b.cells[1]:SetText("|cff888888" .. (Eng() and "No dungeons known." or "OctoRanks is off.") .. "|r")
        for j = 2, 4 do b.cells[j]:SetText("") end
        b:Show()
      end
    end
    Paint()
    if p.items then table.insert(p.items, { Refresh = Paint }) end

    -- (25 Nov 2026, user: "People can enable or disable a timer to see their run time live. Make a tidy timer")
    W.Card(p, "Run timer", { icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
      tip = "Your run time live while you are in a 5-man, the way the boards count it." })
    local box = W.Box(p, 150)
    do
      -- a still picture of it with a made-up Stratholme run (the live one: in a 5-man, and in layout mode)
      local sample = CreateFrame("Frame", nil, box)
      sample:SetWidth(250)
      sample:SetHeight(140)
      sample:SetPoint("CENTER", box, "CENTER", 0, 0)
      if CreateBackdrop then CreateBackdrop(sample, nil, nil, .85) end
      local function L(font, size, text, point, x, y, r, g, b)
        local fs = sample:CreateFontString(nil, "OVERLAY")
        fs:SetFont(font, size, "OUTLINE")
        fs:SetPoint(point, sample, point, x, y)
        fs:SetTextColor(r or 1, g or 1, b or 1)
        fs:SetText(text)
        return fs
      end
      local F, N = "Interface\\AddOns\\pfUI\\fonts\\FiraSansCondensed-SemiBold.ttf", "Interface\\AddOns\\pfUI\\fonts\\Expressway.ttf"
      L(F, 12, "Stratholme (Undead)", "TOPLEFT", 26, -7, 1, .82, .2)
      L(F, 12, "3/7", "TOPRIGHT", -8, -7)
      L(N, 26, "12:34", "TOPLEFT", 8, -24)
      L(F, 11, "|cff55ff559:00 ahead|r", "TOPLEFT", 92, -36)
      local bar = sample:CreateTexture(nil, "ARTWORK")
      bar:SetTexture(.3, .85, .4, 1)
      bar:SetHeight(5)
      bar:SetWidth(134)
      bar:SetPoint("TOPLEFT", sample, "TOPLEFT", 8, -58)
      local bg = sample:CreateTexture(nil, "BORDER")
      bg:SetTexture(1, 1, 1, .08)
      bg:SetHeight(5)
      bg:SetPoint("TOPLEFT", sample, "TOPLEFT", 8, -58)
      bg:SetPoint("TOPRIGHT", sample, "TOPRIGHT", -8, -58)
      L(F, 11, "your best |cffffffff21:54|r   realm #1 |cffffffff21:54|r", "TOPLEFT", 8, -67, .7, .72, .76)
      L(F, 11, "|cff55ff55+|r Magistrate Barthilas", "TOPLEFT", 10, -86, .86, .87, .9)
      L(F, 11, "|cff55ff55+|r Stonespine", "TOPLEFT", 10, -100, .86, .87, .9)
      L(F, 11, "|cff55ff55+|r Baroness Anastari", "TOPLEFT", 10, -114, .86, .87, .9)
      L(N, 11, "3:18", "TOPRIGHT", -10, -86, .86, .87, .9)
      L(N, 11, "6:42", "TOPRIGHT", -10, -100, .86, .87, .9)
      L(N, 11, "11:30", "TOPRIGHT", -10, -114, .86, .87, .9)
      local ic = sample:CreateTexture(nil, "ARTWORK")
      ic:SetTexture("Interface\\AddOns\\pfUI\\img\\octo\\icons\\rank")
      ic:SetVertexColor(1, .82, .2)
      ic:SetWidth(14) ic:SetHeight(14)
      ic:SetPoint("TOPLEFT", sample, "TOPLEFT", 7, -7)
      local top = sample:CreateTexture(nil, "ARTWORK")
      top:SetTexture("Interface\\Buttons\\WHITE8X8")
      top:SetHeight(2)
      top:SetPoint("TOPLEFT", sample, "TOPLEFT", 0, 0)
      top:SetPoint("TOPRIGHT", sample, "TOPRIGHT", 0, 0)
      top:SetGradientAlpha("HORIZONTAL", 1, .82, .2, .15, 1, .82, .2, .9)
    end
    local function TC() return C.octorank end
    O.PfChk(p, "Show the run timer", "Your run time live in a 5-man: bosses down, ahead / behind your best, the realm's fastest. Off: the time is still taken and shared, you just do not see it.", TC, "timer")
    O.PfChk(p, "Boss splits under it", "Each boss and the time it died, as you go.", TC, "splits")
    O.PfChk(p, "\"Starts at your first pull\" at the door", "Inside a 5-man at 60, before the first pull: the timer shows waiting, and a line at the top of the screen says the clock starts when you pull.", TC, "waiting")
    O.PfSld(p, "Size", "How big the timer is.", .6, 1.6, .05, TC, "scale", nil, function(v) return math.floor(v * 100 + .5) .. "%" end)
    W.Buttons(p, { { "Move it", function() if pfUI.unlock then pfUI.unlock:Show() end end, 120, "Layout mode: drag the run timer where you want it." } })

    -- settings: the engine's own switches (WhoDidIt's and OctoRank's have the same names)
    W.Card(p, "Sharing and the timer", { icon = "Interface\\Icons\\Spell_Holy_PrayerOfSpirit",
      tip = "What goes out, what comes in and what shows on your screen." })
    local function Opt(key, inverse)
      return function()
        local o = OR() and OR().Opts()
        if not o then return false end
        if inverse then return not o[key] end
        return o[key] and true or false
      end
    end
    W.Check(p, "Share my 5-man runs", "Your group's finished runs go to the realm's boards. Off: they stay on your PC, and nobody's add-on shares a run you are in.",
      Opt("no5man", true), function(v)
        local k, e = Eng()
        if e and e.Runs and e.Runs.Slash then pcall(e.Runs.Slash, e.Runs, v and "on" or "off") end
      end)
    W.Check(p, "Realm channel", "The hidden channel that brings everyone's runs and the raid times. Off: nothing comes in or goes out.",
      Opt("shareBoard"), function(v)
        local o = OR() and OR().Opts()
        local _, e = Eng()
        if not o or not e or not e.Board then return end
        o.shareBoard = v and true or false
        if v then pcall(e.Board.Join, e.Board) else pcall(e.Board.Leave, e.Board) end
      end)
    W.Check(p, "Raid times feed", "Newer raid times from the maintainer's feed on the channel, on top of the ones that come with updates.",
      Opt("noFeed", true), function(v)
        local o = OR() and OR().Opts()
        local _, e = Eng()
        if not o then return end
        o.noFeed = (not v) or nil
        if e and e.Board and e.Board.LoadChronicle then pcall(e.Board.LoadChronicle, e.Board) end
      end)
    if kind ~= "wdi" then
      W.Check(p, "Minimap button", "OctoRank's own button on the minimap (this page and /ranks open it too).",
        Opt("noMinimap", true), function(v)
          local o = OR() and OR().Opts()
          local _, e = Eng()
          if not o then return end
          o.noMinimap = (not v) or nil
          if e and e.UI and e.UI.UpdateMinimap then pcall(e.UI.UpdateMinimap) end
        end)
    end
    W.Buttons(p, {
      { "Name my group", function()
        local _, e = Eng()
        if e and e.Prompt and e.Runs then
          e:Prompt("Your group's name on the boards:", "", function(t) pcall(e.Runs.Slash, e.Runs, "name " .. (t or "")) end)
        end
      end, 140, "The name your group shows under on the boards, remembered for these players." },
    })

    W.Card(p, "How it works", { icon = "Interface\\Icons\\INV_Misc_Book_09", tip = "Where the times come from and where they go." })
    W.Note(p, "|cffffd100Automatic.|r Zone into a dungeon at level 60 and pull: the clock starts. It stops when the last boss dies. "
      .. "Deaths and boss splits are kept. A run that started mid-way or with too many players is not ranked.", nil, true)
    W.Note(p, "|cffffd100Shared.|r The finished run goes to everyone on your realm with OctoRanks, OctoRank or WhoDidIt - one network. "
      .. "Only someone who was in the group can share its run.", nil, true)
    W.Note(p, "|cffffd100Across realms.|r Every realm's 5-man boards (N'Zoth, Y'Shaarj) come with each pfUI Octo update, so "
      .. "\"All realms\" on the boards shows the other realm's groups too.", nil, true)
    W.Note(p, "|cffffd100A wrong time?|r Open the run on the board and withdraw it: it goes off the boards across the realm.", nil, true)
    W.Note(p, "|cffffd100Chronicle logs.|r Optional: asked when you enter a raid, nothing is logged until you say yes.", nil, true)
  end

  O:AddPage("OctoRanks", "orank", "OctoRanks", Build)
end)
