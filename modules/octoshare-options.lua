pfUI:RegisterModule("octoshare-options", "vanilla", function ()
  -- pfUI Octo :: the Data sharing page (Quality of Life, 27 Nov 2026). One honest place that lists everything pfUI Octo
  -- shares with other players, lets you turn each off, and holds the OctoShare collector + new-feed switches. This page
  -- is the "make users aware" the feature was asked to have - nothing is hidden.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local function OS() return pfUI.octoshare end

  -- a feed's own on/off config, or nil when it has no single key (OctoBoards)
  local function Get(group, key) return group and key and C[group] and C[group][key] ~= "0" end
  local function Set(group, key, v) if group and key and C[group] then C[group][key] = v and "1" or "0" end end

  local function Build(p)
    W.Heading(p, "Data sharing", {
      about = "pfUI Octo shares small pieces of crowd data with other pfUI Octo players, so everyone's prices, timers and "
        .. "boards are better. It goes over the hidden addon channel to your guild and raid - short text only, a few times "
        .. "a minute at most, no personal data and nothing that affects your game. It is paced so it can never make the "
        .. "server throttle your chat, and it stops entirely while you are in combat.\n\nThis page lists everything that "
        .. "is shared and lets you turn any of it, or the lot, off. Nothing identifies you beyond your character name on "
        .. "public counts you already broadcast." })

    W.Live(p, function()
      local os = OS()
      if not os then return "|cff9a9ca3OctoShare not loaded.|r" end
      local on = {}
      for _, f in ipairs(os.FEEDS) do if f[3] and Get(f[3], f[4]) then table.insert(on, f[2]) end end
      local s = table.getn(on) > 0 and ("Sharing: |cffffffff" .. table.concat(on, ", ") .. "|r") or "|cff9a9ca3Sharing nothing.|r"
      if os.Collecting() then s = s .. "\n|cff55ff55Collector ON|r - this character is logging share traffic for export (" .. table.getn(os.DB().log) .. " kept)." end
      return s
    end)

    -- each existing feed and its own switch
    W.Card(p, "What is shared", { icon = "Interface\\Icons\\INV_Letter_15" })
    local function Feed(label, desc, group, key)
      if not key then
        W.Note(p, "|cffffffff" .. label .. "|r  -  " .. desc .. "  (guild / raid; off by leaving a raid or hiding the boards).", 0, false)
        return
      end
      W.Check(p, label, desc, function() return Get(group, key) end, function(v)
        Set(group, key, v)
        if pfUI.gui then pfUI.gui.settingChanged = true end
      end)
    end
    Feed("Auction prices", "The lowest buyout you see each day, so guildmates get a going rate. Never your own listings.", "auction", "share")
    Feed("Flight times", "How long a flight path took, to fill in the flight timer for others.", "flight", "share")
    Feed("Transport times", "When a boat, zeppelin or tram left, so the timers line up for everyone.", "transports", "share")
    Feed("Gathering nodes", "Herb and ore spots you pass, for the shared map nodes.", "gather", "share")
    Feed("World buffs", "Rend, Onyxia and Nefarian head drops as they happen, for the world-buff board.", "worldbuffs", "share")
    Feed("Leaderboards", "Your OctoBoards counts (kills, flights, gold...) to rank against guild and raid.", nil, nil)
    Feed("Battlegrounds & population", "Your BG queue waits and win/loss, and your current zone now and then - for "
      .. "queue-time, realm win-rate and 'where is everyone' boards. Nothing but the public count and your side.", "octoshare", "enable")

    -- how it is sent: the throttle-safe governor
    W.Card(p, "How it is sent", { icon = "Interface\\Icons\\Spell_Nature_WispSplode" })
    W.Note(p, "Every share message is paced onto one slow stream, so all the feeds together can never make the server "
      .. "throttle your chat. It stops completely while you are in combat and for a few seconds after, so it is never in "
      .. "the way of a pull or a raid fight. If the server ever warns about chat speed it goes silent and drops the "
      .. "backlog. You should never notice it.", 0, false)
    W.Slider(p, "Send spacing", "Seconds between messages. Higher is safer and slower; the default is already far under "
      .. "the server's limit. Lower it only if you know what you are doing.", 1, 6, .5,
      function() return tonumber(C.octoshare and C.octoshare.gap) or 2 end,
      function(v) if C.octoshare then C.octoshare.gap = tostring(v) end end, function(v) return v .. " s" end)
    W.Edit(p, "Master character", "For realm-wide reach: the collector character every pfUI Octo user quietly whispers "
      .. "(an invisible addon whisper, not a chat message). Leave empty for guild / raid only. Set it to your collector's "
      .. "name on all clients to gather the whole realm - but test first that it does not print a 'no such player' line "
      .. "when the master is offline. Needs a reload.",
      function() return C.octoshare and C.octoshare.master or "" end,
      function(v) if C.octoshare then C.octoshare.master = v or "" end end, 200)

    -- the collector + new feeds (for the person running the master database)
    W.Card(p, "Collector", { icon = "Interface\\Icons\\INV_Misc_Note_01",
      tip = "For the ONE character that gathers the realm's shared data into a database. Leave off unless that is you." })
    W.Check(p, "Collect on this character (master)", "Writes every share message this character hears into pfUI's saved "
      .. "data for export (tools\\Sync-OctoShare.ps1). It only keeps the same public data players already broadcast. "
      .. "Turn this on only on your own master character.",
      function() return OS() and OS().Collecting() end,
      function(v) if C.octoshare then C.octoshare.collect = v and "1" or "0" end end)
    W.Check(p, "Send new feeds", "Lets pfUI Octo broadcast extra records (battleground queues, population and more) once "
      .. "they are built. Off until then.",
      function() return OS() and OS().Enabled() end,
      function(v) if C.octoshare then C.octoshare.enable = v and "1" or "0" end end)
    W.Buttons(p, {
      { "Make this my master", function() if C.octoshare then C.octoshare.collect = "1" end if O.Refresh then pcall(O.Refresh, O) end end, 150,
        "Turns on collecting here. Run tools\\Sync-OctoShare.ps1 to pull it into the database.", role = "go" },
      { "Clear collected", function() if OS() then OS().Clear() end end, 130, "Empties this character's collector log.", role = "danger" },
      { "Status in chat", function() if _G.SlashCmdList and _G.SlashCmdList["OCTOSHARE"] then _G.SlashCmdList["OCTOSHARE"]("") end end, 120, "/octoshare", role = "open" },
    })
    W.Note(p, "Only one of your characters needs to be the master. Nothing personal is ever sent - just prices, timers, "
      .. "nodes, world buffs and public board counts.", 0, true)
  end

  O:AddPage("Quality of Life", "octoshare", "Data sharing", Build)
end)
