pfUI:RegisterModule("escapefix", "vanilla", function ()
  -- pfUI Octo :: Escape always reaches the game menu (17 Nov 2026, user: "when i press escape to open the
  -- main menu sometimes it stops working for no reason").
  --
  -- The game keeps its big windows in slots on UIParent (left, center, right, doublewide, fullscreen).
  -- Escape runs CloseWindows, which counts a filled slot as "a window was closed" - even when the window
  -- in it was hidden with a plain Hide() and not HideUIPanel. HideUIPanel does nothing for a hidden window,
  -- so such a slot is never emptied and every Escape after it is spent on it: no game menu until another
  -- window takes that slot. Any add-on (or the game's own on-demand windows) can leave one behind.
  -- Before CloseWindows runs, a slot whose window is not shown is emptied.
  local E = {}
  pfUI.escapefix = E
  E.SLOTS = { "left", "center", "right", "doublewide", "fullscreen" }

  -- empties the slots of windows no longer shown; returns how many
  function E.ClearStale()
    local p = rawget(_G, "UIParent")
    if not p then return 0 end
    local n = 0
    for _, k in ipairs(E.SLOTS) do
      local f = p[k]
      if type(f) == "table" and f.IsShown and not f:IsShown() then
        p[k] = nil
        n = n + 1
      end
    end
    return n
  end

  local orig = rawget(_G, "CloseWindows")
  if type(orig) == "function" then
    _G.CloseWindows = function(a1, a2)
      E.ClearStale()
      return orig(a1, a2)
    end
  end

  -- (20 Nov 2026, Iso on Discord: "Interface\FrameXML\TargetFrame.lua:291: attempt to index global
  -- `Turtle_ChallengesCache' (a nil value)", over and over) The game's own target frame looks up a player's
  -- challenges in Turtle_ChallengesCache[realm][guid], a table its Turtle_General saved data fills. When that table is
  -- not there (that saved file missing or broken, or read before it loads) every target change errors. Before the
  -- game's challenge functions run, the table and this realm's part of it are made if missing (the game's own saved
  -- table, when it loads, simply takes their place).
  function E.ChallengesCache()
    if type(rawget(_G, "Turtle_ChallengesCache")) ~= "table" then _G.Turtle_ChallengesCache = {} end
    local realm = GetRealmName and GetRealmName() or "?"
    if type(Turtle_ChallengesCache[realm]) ~= "table" then Turtle_ChallengesCache[realm] = {} end
  end
  for _, fname in ipairs({ "TargetFrame_CheckChallenges", "TargetFrame_HandleChallenges", "TargetFrame_UpdateChallenges" }) do
    local fn = rawget(_G, fname)
    if type(fn) == "function" then
      _G[fname] = function(a1, a2, a3)
        E.ChallengesCache()
        return fn(a1, a2, a3)
      end
    end
  end
end)
