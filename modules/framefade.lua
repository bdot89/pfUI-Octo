pfUI:RegisterModule("framefade", "vanilla:tbc", function ()
  -- pfUI Octo :: Frame fade (24 Nov 2026; Lo5t1ncyb3r on Discord: FrameFade by Grylls "for the immersion if someone
  -- wants it"). FrameFade (MIT, GryllsAddons; archive github.com/neimad-mp/FrameFade) hid the player and pet frames at
  -- once while you were full, idle, without a target and out of combat, and stopped pfUI's frame OnUpdate to do it.
  -- Rebuilt here, with more:
  --   * smooth fades (own times in and out) after a short wait, to any opacity, not only invisible
  --   * seven parts of the screen, each on or off: player and pet, action bars, buffs, minimap, chat, panels, meters
  --   * every "show again" reason its own switch: combat, target, health / mana under a mark, casting, pet, group,
  --     dungeons and battlegrounds, resting; chat comes back for new messages and while you type
  --   * hover a faded part to see it (or all of them), hold Alt / Ctrl / Shift to peek, fade on flight paths
  --   * pfUI's own opacity is kept: range fading, action bar fades and the rest multiply with it (SetAlpha is wrapped
  --     per frame and remembers what pfUI asked for), so nothing pfUI does is switched off
  -- Settings C.framefade; page Quality of Life > Frame Fade (framefade-options.lua).
  local FF = {}
  pfUI.framefade = FF

  local function S() return C.framefade end
  local function On(k) return S()[k] == "1" end
  local function N(k, d) return tonumber(S()[k]) or d end

  local BARS = { "Main", "Paging", "Right", "Vertical", "Left", "Top", "Stances", "Pet",
    "StanceBar1", "StanceBar2", "StanceBar3", "StanceBar4" }
  local function BarNames()
    local t = { "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight", "PetActionBarFrame", "ShapeshiftBarFrame" }
    for i = 1, table.getn(BARS) do table.insert(t, "pfActionBar" .. BARS[i]) end
    return t
  end
  local function ChatNames()
    local t = { "pfChatLeft", "pfChatRight" }
    for i = 1, 7 do
      table.insert(t, "ChatFrame" .. i)
      table.insert(t, "ChatFrame" .. i .. "Tab")
    end
    return t
  end
  local function MeterNames()
    local t = { "pfMeterToggle" }
    for i = 1, 6 do table.insert(t, "pfMeter" .. i) end
    return t
  end

  -- key, name on the options page, what it covers, frame names; hide = frames hidden (not faded) once fully gone:
  -- the minimap's ground does not follow its frame's opacity on this client
  FF.GROUPS = {
    { key = "player", label = "Player and pet", desc = "Your own unit frame and your pet's (pfUI's or the game's).",
      names = { "pfPlayer", "pfPet", "PlayerFrame", "PetFrame" } },
    { key = "bars", label = "Action bars", desc = "Every action bar, the stance bar and the pet bar.", names = BarNames() },
    { key = "buffs", label = "Buffs and debuffs", desc = "Your buffs, debuffs and weapon buffs at the top right.",
      names = { "pfBuffFrame", "pfDebuffFrame", "pfWepBuffFrame", "BuffFrame", "TemporaryEnchantFrame" } },
    { key = "minimap", label = "Minimap", desc = "The minimap with its border, buttons and clock. Fully faded, the map itself hides.",
      names = { "pfMinimap", "MinimapCluster", "pfMinimapButtons" }, hide = { "Minimap" } },
    { key = "chat", label = "Chat", desc = "The chat windows and their tabs. They come back for new messages and while you type.",
      names = ChatNames() },
    { key = "panels", label = "Panels and XP bar", desc = "pfUI's info panels, the micro menu panel, the XP and reputation bars.",
      names = { "pfPanelLeft", "pfPanelRight", "pfPanelMicroButton", "pfExperienceBar", "pfReputationBar" } },
    { key = "meters", label = "Meters", desc = "The damage / healing meter windows and their button.", names = MeterNames() },
  }

  FF.mul, FF.want = {}, {}

  -- ------------------------------------------------------------ frames

  -- the frames of each part that exist now; a frame inside another of the same part follows its parent's fade
  -- (faded twice it would go darker than asked)
  function FF.Resolve()
    local owner = {}
    for gi = 1, table.getn(FF.GROUPS) do
      local g = FF.GROUPS[gi]
      g.frames = {}
      for _, n in ipairs(g.names) do
        local f = _G[n]
        if type(f) == "table" and f.SetAlpha and not owner[f] then
          owner[f] = g
          table.insert(g.frames, f)
        end
      end
    end
    for gi = 1, table.getn(FF.GROUPS) do
      local g = FF.GROUPS[gi]
      for i = table.getn(g.frames), 1, -1 do
        local f = g.frames[i]
        local p, d = f.GetParent and f:GetParent(), 0
        while p and d < 12 do
          if owner[p] == g then table.remove(g.frames, i) break end
          p = p.GetParent and p:GetParent()
          d = d + 1
        end
      end
    end
  end

  -- A frame's own SetAlpha / GetAlpha are wrapped once it is first faded: what pfUI (or the game) asks for is kept as
  -- ffBase and shown times the fade; GetAlpha answers ffBase, so their checks ("is it already right?") still work.
  function FF.Hook(f)
    if f.ffWrap and f.SetAlpha == f.ffWrap then return end
    local get = f.ffRawGet or f.GetAlpha
    local set = f.SetAlpha
    f.ffRawGet, f.ffRawSet = get, set
    if f.ffBase == nil then f.ffBase = get(f) or 1 end
    f.ffWrap = function(self, a)
      self.ffBase = a
      local m = self.ffMul or 1
      if m >= 1 then set(self, a) else set(self, (a or 1) * m) end
    end
    f.SetAlpha = f.ffWrap
    f.ffGet = function(self) return self.ffBase or get(self) end
    f.GetAlpha = f.ffGet
  end

  function FF.Set(f, mul)
    if f.ffMul == nil and mul >= 1 then return end -- never touched: leave it alone
    FF.Hook(f)
    f.ffMul = mul
    f.ffRawSet(f, (f.ffBase or 1) * mul)
    -- a 3D portrait does not always follow its frame's opacity: hidden while fully gone, drawn again after
    local pm = f.portrait and f.portrait.model
    if pm and pm.Hide then
      if mul <= .01 then
        if pm:IsShown() then f.ffModel = true pm:Hide() end
      elseif f.ffModel then
        f.ffModel = nil
        if pfUI.uf and pfUI.uf.RefreshUnit then pcall(pfUI.uf.RefreshUnit, pfUI.uf, f, "portrait") end
        if not pm:IsShown() and f.config and f.config.portrait ~= "off" then pm:Show() end
      end
    end
  end

  function FF.Apply(g, mul)
    for _, f in ipairs(g.frames or {}) do FF.Set(f, mul) end
    for _, n in ipairs(g.hide or {}) do
      local f = _G[n]
      if type(f) == "table" and f.Hide then
        if mul <= .01 then
          if f:IsShown() and not f.ffHidden then f.ffHidden = true f:Hide() end
        elseif f.ffHidden then
          f.ffHidden = nil
          f:Show()
        end
      end
    end
  end

  function FF.Over(g)
    if not MouseIsOver then return nil end
    for _, f in ipairs(g.frames or {}) do
      if f.IsVisible and f:IsVisible() and MouseIsOver(f) then return true end
    end
  end

  -- ------------------------------------------------------------ when the screen is busy

  local function Pct(cur, max) if not max or max <= 0 then return 100 end return cur / max * 100 end

  -- every reason the faded parts should be shown now (empty = all quiet)
  function FF.Reasons()
    local r = {}
    local function Add(t) table.insert(r, t) end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then Add("you are dead") end
    if On("combat") and (FF.combat or (UnitAffectingCombat and UnitAffectingCombat("player"))) then Add("in combat") end
    if On("target") and UnitExists("target") then Add("you have a target") end
    if On("hurt") then
      local mark = N("hpbelow", 100)
      if Pct(UnitHealth("player"), UnitHealthMax("player")) < mark - .001 then
        Add(mark >= 100 and "health not full" or ("health under " .. mark .. "%"))
      end
    end
    if On("power") then
      local pt = UnitPowerType and UnitPowerType("player") or 0
      if pt == 1 then
        if (UnitMana("player") or 0) > 0 then Add("rage") end
      elseif pt == 0 or pt == 3 then
        local mark = N("powbelow", 100)
        if Pct(UnitMana("player"), UnitManaMax("player")) < mark - .001 then
          local what = pt == 3 and "energy" or "mana"
          Add(mark >= 100 and (what .. " not full") or (what .. " under " .. mark .. "%"))
        end
      end
    end
    if On("casting") and (FF.cast or FF.channel) then Add("casting") end
    if On("pet") and UnitExists("pet") then
      if Pct(UnitHealth("pet"), UnitHealthMax("pet")) < 100 then Add("pet hurt") end
      local h = GetPetHappiness and GetPetHappiness()
      if h and h < 2 then Add("pet unhappy") end
    end
    if On("group") and ((GetNumRaidMembers and GetNumRaidMembers() > 0) or (GetNumPartyMembers and GetNumPartyMembers() > 0)) then
      Add("in a group")
    end
    if On("instance") and pfUI.context and pfUI.context.Zone then
      local z = pfUI.context.Zone()
      if z and z ~= "world" then Add("in a " .. (z == "bg" and "battleground" or z)) end
    end
    if On("resting") and IsResting and IsResting() then Add("resting") end
    return r
  end

  local KEYS = { alt = "IsAltKeyDown", ctrl = "IsControlKeyDown", shift = "IsShiftKeyDown" }
  function FF.Peek()
    local fn = KEYS[S().modkey or ""]
    return fn and _G[fn] and _G[fn]() and true or nil
  end

  local function Chat(now)
    if (FF.chatUntil or 0) > now then return "new chat message" end
    local eb = _G.ChatFrameEditBox
    if eb and eb.IsVisible and eb:IsVisible() then return "typing" end
  end
  for _, g in ipairs(FF.GROUPS) do
    if g.key == "chat" then g.extra = Chat end
  end

  function FF.Evaluate(now)
    if now >= (FF.resolveAt or 0) then
      FF.resolveAt = now + 2
      FF.Resolve()
    end
    local enabled = On("enable") and not FF.aside
    local reasons = FF.Reasons()
    local taxi = On("taxi") and UnitOnTaxi and UnitOnTaxi("player")
    local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
    if taxi and not dead then reasons = {} end
    local busy = table.getn(reasons) > 0
    if busy then FF.quietAt = nil elseif not FF.quietAt then FF.quietAt = now end
    local wait = taxi and 0 or N("delay", 2)
    local forced = FF.tryUntil and FF.tryUntil > now
    local quietFor = FF.quietAt and (now - FF.quietAt) or 0
    -- (Try it works with the switch off too: a look before switching on)
    local fade = (forced and not FF.aside) or (enabled and not busy and quietFor >= wait)
    local layout = pfUI.unlock and pfUI.unlock.IsShown and pfUI.unlock:IsShown()
    local peek = FF.Peek()
    FF.reasons, FF.fading, FF.forced, FF.layout, FF.peeking = reasons, fade, forced, layout, peek
    FF.fadeIn = (enabled and not busy and not forced) and math.max(0, wait - quietFor) or nil

    local low = math.max(0, math.min(1, N("alpha", 0)))
    local anyHover
    for _, g in ipairs(FF.GROUPS) do
      g.hovered = (enabled or forced) and On("hover") and FF.Over(g) or nil
      if g.hovered then anyHover = true end
    end
    local all = anyHover and On("hoverall")
    for _, g in ipairs(FF.GROUPS) do
      local goal = 1
      if fade and not layout and not peek and S()["g_" .. g.key] == "1" and not g.hovered and not all
        and not (g.extra and g.extra(now)) then
        goal = low
      end
      FF.want[g.key] = goal
    end
  end

  function FF.Tick()
    local now = GetTime()
    local dt = now - (FF.last or now)
    FF.last = now
    if dt > .5 then dt = .5 end
    if now >= (FF.evalAt or 0) then
      FF.evalAt = now + .1
      FF.Evaluate(now)
    end
    for _, g in ipairs(FF.GROUPS) do
      local cur, goal = FF.mul[g.key] or 1, FF.want[g.key] or 1
      if cur ~= goal then
        local secs = goal > cur and N("fadein", .2) or N("fadeout", .8)
        local step = secs <= 0 and 1 or dt / secs
        if goal > cur then cur = math.min(goal, cur + step) else cur = math.max(goal, cur - step) end
        FF.mul[g.key] = cur
        FF.Apply(g, cur)
      end
    end
  end

  -- "Try it": faded now for n seconds, whatever is going on (the mouse and the peek key still show them)
  function FF.Try(n)
    FF.tryUntil = GetTime() + (n or 8)
    FF.evalAt = 0
  end
  -- everything back at once, and the wait starts again
  function FF.Wake()
    FF.tryUntil = nil
    FF.quietAt = GetTime()
    FF.evalAt = 0
  end
  -- every part shown and left alone (switching off)
  function FF.ShowAll()
    FF.tryUntil = nil
    for _, g in ipairs(FF.GROUPS) do
      FF.want[g.key] = 1
      FF.mul[g.key] = 1
      FF.Apply(g, 1)
    end
  end

  -- one line on what it is doing, for the options page and /framefade
  function FF.Status()
    if FF.aside then return "|cffffcc00The FrameFade add-on is loaded: it does this, so ours stands aside.|r" end
    if FF.layout then return "|cff66ccffLayout mode is open: everything shown.|r" end
    if FF.peeking then return "|cff66ccffPeeking: shown while the key is held.|r" end
    if FF.forced then
      return string.format("|cffcc99ffTrying it: faded for %d more seconds.|r", math.ceil((FF.tryUntil or 0) - GetTime()))
    end
    if not On("enable") then return "|cff999999Off: nothing fades.|r" end
    local r = FF.reasons or {}
    if table.getn(r) > 0 then return "|cff55ff55Shown:|r " .. table.concat(r, ", ") end
    if FF.fadeIn and FF.fadeIn > 0 then return string.format("|cffffcc00All quiet: fading in %.1f s|r", FF.fadeIn) end
    return "|cff999999Faded.|r Hover a part" .. (KEYS[S().modkey or ""] and (" or hold " .. string.upper(string.sub(S().modkey, 1, 1)) .. string.sub(S().modkey, 2)) or "") .. " to see it."
  end

  -- ------------------------------------------------------------ events

  local drv = CreateFrame("Frame", "pfFrameFade", UIParent)
  FF.frame = drv
  drv:RegisterEvent("PLAYER_ENTERING_WORLD")
  drv:RegisterEvent("PLAYER_REGEN_DISABLED")
  drv:RegisterEvent("PLAYER_REGEN_ENABLED")
  drv:RegisterEvent("SPELLCAST_START")
  drv:RegisterEvent("SPELLCAST_STOP")
  drv:RegisterEvent("SPELLCAST_FAILED")
  drv:RegisterEvent("SPELLCAST_INTERRUPTED")
  drv:RegisterEvent("SPELLCAST_CHANNEL_START")
  drv:RegisterEvent("SPELLCAST_CHANNEL_STOP")
  FF.CHAT = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_PARTY", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER" }
  for _, e in ipairs(FF.CHAT) do drv:RegisterEvent(e) end
  FF.chatEvent = {}
  for _, e in ipairs(FF.CHAT) do FF.chatEvent[e] = true end
  drv:SetScript("OnEvent", function()
    if event == "PLAYER_REGEN_DISABLED" then FF.combat = true
    elseif event == "PLAYER_REGEN_ENABLED" then FF.combat = nil
    elseif event == "SPELLCAST_START" then FF.cast = true
    elseif event == "SPELLCAST_STOP" or event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then FF.cast = nil
      if event ~= "SPELLCAST_STOP" then FF.channel = nil end
    elseif event == "SPELLCAST_CHANNEL_START" then FF.channel = true
    elseif event == "SPELLCAST_CHANNEL_STOP" then FF.channel = nil
    elseif FF.chatEvent[event] then FF.chatUntil = GetTime() + N("chatshow", 10)
    elseif event == "PLAYER_ENTERING_WORLD" then
      FF.aside = IsAddOnLoaded and IsAddOnLoaded("FrameFade") and true or nil
      FF.resolveAt = 0
    end
    FF.evalAt = 0
  end)
  drv:SetScript("OnUpdate", function() FF.Tick() end)

  -- the switch: on = from the next check, off = every part back at once
  function FF.Switched()
    if not On("enable") then FF.ShowAll() else FF.Wake() end
  end

  _G.SLASH_PFFRAMEFADE1, _G.SLASH_PFFRAMEFADE2 = "/framefade", "/ffade"
  if not _G.SlashCmdList then _G.SlashCmdList = {} end
  _G.SlashCmdList.PFFRAMEFADE = function(msg)
    msg = string.lower(msg or "")
    if msg == "on" or msg == "off" then
      S().enable = msg == "on" and "1" or "0"
      FF.Switched()
    elseif msg == "try" then
      if not On("enable") then S().enable = "1" end
      FF.Try(8)
    elseif msg == "" and pfUI.octoui and pfUI.octoui.Options and pfUI.gui then
      pfUI.gui:Show()
      pfUI.octoui.Options:Open("framefade")
      return
    end
    FF.Evaluate(GetTime())
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI Octo|r Frame fade: " .. FF.Status() .. "  (/framefade on | off | try)")
  end
end)
