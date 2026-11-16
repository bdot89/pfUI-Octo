pfUI:RegisterModule("art", "vanilla:tbc", function ()
  -- pfUI Octo :: art sets (5 Nov 2026; user: "everything looks cheap, the elite marks ...
  -- raid marks look bad on targets and frames ... ART WORK ALL OVER"). Pictures drawn by
  -- tools\MakeMarkArt.ps1 (img\marks, img\elite); chosen on the Art page.
  --   C.art.marks  pfui (the stock sheet) | gloss | flat | neon | blizzard
  --   C.art.elite  classic | wings | star | shield | skull | crown
  -- A raid mark sheet has the game's 4 x 4 layout, so the one set of the pictures serves
  -- the unit frames, the nameplates and Blizzard's own frames: pfUI's sheet name is swapped
  -- before any frame is made, and the game's SetRaidTargetIconTexture puts the chosen sheet
  -- on a texture first, then the cell. Marks need a reload to change.
  local A = {}
  pfUI.art = A
  local DIR = "Interface\\AddOns\\pfUI\\img\\"
  A.MARKS = {
    { key = "pfui", label = "pfUI's own" },
    { key = "gloss", label = "Glossy 3D", tex = DIR .. "marks\\gloss" },
    { key = "flat", label = "Flat", tex = DIR .. "marks\\flat" },
    { key = "neon", label = "Neon", tex = DIR .. "marks\\neon" },
    { key = "blizzard", label = "The game's", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcons" },
    -- (16 Nov 2026) game-icons.net pictures in the marks' colours (tools\MakeIconArt.ps1)
    { key = "emblems", label = "Emblems (game-icons)", tex = DIR .. "marks\\emblems" },
    { key = "fantasy", label = "Fantasy (game-icons)", tex = DIR .. "marks\\fantasy" },
  }
  A.ELITE = {
    { key = "classic", label = "Classic", group = "pfUI Octo" },
    { key = "wings", label = "Winged gem", group = "pfUI Octo" },
    { key = "star", label = "Star", group = "pfUI Octo" },
    { key = "shield", label = "Shield", group = "pfUI Octo" },
    { key = "skull", label = "Skull", group = "pfUI Octo" },
    { key = "crown", label = "Crown", group = "pfUI Octo" },
  }
  -- (16 Nov 2026, user: "Download about 100 icons and put them in tidy the best rated ones that look good") the
  -- game-icons.net crests (modules\art-icons.lua, GENERATED): key "gi-<author>-<icon>", square, gold / silver / red
  A.ICONSQ = {}
  A.GROUPS = { "pfUI Octo" }
  local seen = { ["pfUI Octo"] = true }
  for _, ic in ipairs(pfUI.artIcons or {}) do
    local key = "gi-" .. ic[1]
    table.insert(A.ELITE, { key = key, label = ic[2], group = ic[3], file = ic[1] })
    A.ICONSQ[key] = ic[1]
    if not seen[ic[3]] then seen[ic[3]] = true table.insert(A.GROUPS, ic[3]) end
  end
  local function G() return C.art or {} end

  -- the picture sheet of the chosen mark set (nil = leave the stock one)
  function A.MarkSheet(key)
    key = key or G().marks
    for _, m in ipairs(A.MARKS) do
      if m.key == key then return m.tex end
    end
  end
  -- the crest picture for a style and kind ("elite", "rare", "boss"); nil = the classic art.
  -- Also its size on a unit frame: the drawn crests are twice as wide as tall, the icon crests square.
  function A.Crest(style, kind)
    style = style or G().elite
    if not style or style == "classic" then return nil end
    local sq = A.ICONSQ[style]
    if sq then return DIR .. "elite\\gi\\" .. sq .. "-" .. kind, 32, 32 end
    return DIR .. "elite\\" .. style .. "-" .. kind, 46, 23
  end
  -- the nameplate mark of an icon crest (chrome, tinted by the plate's elite / rare / boss colour)
  function A.PlateArt(key)
    local sq = A.ICONSQ[key]
    return sq and (DIR .. "plates\\gi\\" .. sq)
  end

  A.stock = pfUI.media["img:raidicons"]
  local sheet = A.MarkSheet()
  if sheet then
    pfUI.media["img:raidicons"] = sheet
    if type(_G.SetRaidTargetIconTexture) == "function" then
      local raw = _G.SetRaidTargetIconTexture
      _G.SetRaidTargetIconTexture = function(tex, index)
        local s = A.MarkSheet()
        if s and tex and tex.SetTexture then tex:SetTexture(s) end
        return raw(tex, index)
      end
    end
  end
end)
