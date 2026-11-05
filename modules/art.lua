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
  }
  A.ELITE = {
    { key = "classic", label = "Classic" },
    { key = "wings", label = "Winged gem" },
    { key = "star", label = "Star" },
    { key = "shield", label = "Shield" },
    { key = "skull", label = "Skull" },
    { key = "crown", label = "Crown" },
  }
  local function G() return C.art or {} end

  -- the picture sheet of the chosen mark set (nil = leave the stock one)
  function A.MarkSheet(key)
    key = key or G().marks
    for _, m in ipairs(A.MARKS) do
      if m.key == key then return m.tex end
    end
  end
  -- the crest picture for a style and kind ("elite", "rare", "boss"); nil = the classic art
  function A.Crest(style, kind)
    style = style or G().elite
    if not style or style == "classic" then return nil end
    return DIR .. "elite\\" .. style .. "-" .. kind
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
