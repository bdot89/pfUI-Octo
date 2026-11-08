# pfUI Octo

Fork of shagu/pfUI 5.5.4 on the `octo` branch (upstream stays on `master`), for the OctoWoW
1.12.1 build 5875 client. Goal: one all-in-one UI with ElvUI-style looks, layout mode, install
wizard, profile strings and options window, plus built-in meters (damage, healing, threat and more,
Details!/Recount depth) and combat text moved over from OctoBG. Roadmap and decisions:
see "Roadmap" below.

## Rules
- The folder, the `pfUI` table and the saved variables keep their names: pfQuest, Clickcast,
  EFocus, Bagforlife, Atlas, HoryUI and OctoBG all hook pfUI by name.
- `## Version` in pfUI.toc stays the upstream base (5.5.4). updatenotify broadcasts it to other
  pfUI users, and a higher number would make everyone's pfUI say "new version at shagu.org". The
  Octo version is `## X-Octo-Version`, read into `pfUI.version.octo` (pfUI.lua) and shown in the
  options title and the About page.
- Lua 5.0: no `#`, `%`, `...` as an expression, string.gfind not gmatch, table.getn. Write Lua with
  Edit/Write, never a shell heredoc (apostrophes and backslashes get mangled).
- Lua 5.0 (the game): a function given to string.gsub that returns nil REMOVES the match (5.1 /
  LuaJIT, the test host, keeps it). Every branch must return the text it wants (chat-plus.lua).
- Lua 5.0 (the game) shares a for loop's counter between functions made inside the loop; the test
  host (LuaJIT) gives each its own, so tests pass and the game breaks. Copy it first:
  `for tt = 1, n do local t = tt ... function() use(t) end end` (23 Oct 2026: the meter test fight
  only ever recorded Melee in game).
- Never assign a client global like `this`, `event` or `arg1` from pfUI code: modules run in
  pfUI's environment, so `this = f` creates a pfUI-only `this` that hides the real one from every
  pfUI script afterwards. Use `_G.this` (22 Oct 2026: broke every pfUI script and blanked the
  options page).
- Never walk every UIParent child calling GetPoint (or other methods) on them: 23 Oct 2026 the
  addon button scan did that at login and the client crashed with #132 ACCESS_VIOLATION in the Lua
  core on every login (Errors\*Crash.txt; Logs\nampower_debug.log times show which reload broke).
  Check name / type first, and only on a small known parent.
- Modules are `pfUI:RegisterModule(name, "vanilla:tbc", fn)` listed in init/modules.xml; they run
  in pfUI's environment (`C` = config, `T` = translations, pfUI.api functions as globals).
  Defaults go in api/config.lua (`pfUI:UpdateConfig(group, sub, key, default)`), options in
  modules/gui.lua (`CreateConfig`, `CreateGUIEntry`).
- Previews must be bright and sharp (user, 8 Nov 2026, angry after the third dark one). They draw in
  FULLSCREEN, often on frame levels 1-4 (pfUI's plates / cast bars): NEVER put a fill, panel or texture
  on a frame that lies above them (W.ZoomBox's clip / canvas, a pin's child frame). A box's dark fill is
  its own backdrop in the window's layer (DIALOG). tests\run.lua checks every zoom box after building
  every page.

## Testing
- `powershell -ExecutionPolicy Bypass -File tests\run.ps1`: loads every file in the toc (following
  the init\*.xml includes) on DmorphOcto's LuaHost (LuaJIT, Lua 5.0 shims), fires ADDON_LOADED and
  starts every module and skin one by one. Unknown CamelCase globals become stand-in widgets, ALL_CAPS
  constants become strings or small counts (tests\run.lua). 61 of 71 modules start offline; the
  rest need client parts the mock lacks (Blizzard child regions). Then it builds every options
  page (all 52 must build). Octo modules go in
  `MUST_LOAD` and fail the run if they error. `PFUI_TEST_VERBOSE=1` lists module and page errors.
- Unknown widget fields return a no-op function only when named like a method (Set*, Get*, Is*...,
  `IsMethodName` in mock.lua): pfUI stores data under CamelCase keys (gui.frames["General"]).
- `..\OctoBG\tools\LuaCheck.ps1 -Files @(<full paths>) -Globals` on every changed Lua file.
- tests\mock.lua is a copy of OctoBG's, changed so pfUI can run: absent 1.12 methods look up as nil
  (pfUI tests `if not frame.HookScript`), GetNumPoints / GetPoint / SetGradientAlpha exist (pfUI
  uses them on 1.12, so OctoBG's mock is wrong to refuse them), font sizes may be numeric strings.

## Client DLLs (SuperWoW, ClassicAPI, nampower)
User rule (22 Oct 2026): use SuperWoW and ClassicAPI wherever they give better data, in every
module, always with the plain-API path as a guarded fallback - nobody without them may lose a
feature. ClassicAPI's call list = "Usage:" strings in `C:\Games\OctoWoW\ClassicAPI.dll`; its docs
are brues-code/ClassicAPI docs/API.md (download it, ~800 KB). `libs\libclient.lua`
(`pfUI.api.libclient`, loaded before libcast) wraps them: GUID, Aura (C_UnitAuras.UnitAura,
texture-checked because Turtle-style servers park extra debuffs in buff slots), Cast
(C_Spell.UnitCastingInfo / UnitChannelInfo), Distance (UnitDistanceSquared, SuperWoW
UnitPosition, UnitXP "distanceBetween"), InRange, Stealthed, PlayerAura. ClassicAPI globals are
read as `_G.X` and only when `C_UnitAuras` exists: pfUI.api.UnitInRange shadows ClassicAPI's
UnitInRange inside pfUI's environment, and the test mock turns unknown CamelCase globals into
stand-ins. C_* names are only called with real unit tokens or GUIDs (they raise on names).
What uses it (22 Oct, NOT seen in game):
- superwow.lua: `superwow_active` is set at load when SUPERWOW_VERSION >= 1.5 (pfUI set it only at
  the first UNIT_CASTEVENT, so GUID plates / click casting without a target swap / position range
  started late).
- libcast: UnitCastingInfo / UnitChannelInfo ask ClassicAPI first (any token or GUID, player
  pushback, cleared at once on kicks), then SuperWoW / combat log data; two extra returns
  notInterruptible, delayMs. Cast bars (castbar.lua) colour can't-interrupt casts
  (`appearance.castbar.nointcolor`, Cast bars page "Can't be interrupted") and show ClassicAPI's
  pushback. Nameplates, plates.lua, afkcam get the better data through libcast.
- libdebuff:UnitDebuff: name, real timer (talents, combo points) and caster from ClassicAPI when
  it saw the cast (no tooltip scan then); pfUI's duration table stays the fallback.
- librange:UnitInSpellRange: ClassicAPI UnitInRange (reach-aware 40 yd), else distance < 45 from
  libclient, for every class (it used to need a healer's 40 yd spell on the bars); the
  target-swap scan stays the fallback.
- libtotem: GetTotemInfo reads ClassicAPI's totem tracker (early death / recall, custom totems).
- unitframes-octo.lua UO.Auras: timers on other units' buffs (1.12 has none) and a blue frame on
  enemy Magic buffs (`o_purge`, on for target / focus; Frames > Buffs card).
- tooltip.lua: "Cast by <name>" on unit buff / debuff tooltips (`tooltip.auracaster`), spell id
  with Show Item IDs.
- actionbar-octo.lua: stealth visibility from IsStealthed, Shadow Trance by spell id 17941
  (AB.PROC_IDS) next to the icon list.
- Already before: plates (GUIDs, C_UnitAuras end times, C_NamePlate), sct (nampower events),
  keymap (GetCursorInfo, SetBindingSpell / Item / Macro), superwow.lua (focus by GUID,
  /pfcast mouseover, druid mana).
Tests: tests\clientapi.lua (run by run.lua): fallbacks without ClassicAPI, then doc-shaped stubs.
Not done (ideas): ClassicAPI-only click casting via C_Spell.CastAtUnit (it skips the
CastSpellByName hooks libpredict needs for heal prediction); focus frame on ClassicAPI's own
`focus` token when SuperWoW is missing; notInterruptible colour on nameplate cast bars;
C_LossOfControl / school lockout on action buttons; C_NewItems glow in bags.

## Verified vs unverified
- Unverified: `GetAddOnMetadata(name, "X-Octo-Version")` on this client (falls back to "0").
- Unverified (22 Oct 2026): every ClassicAPI call in libclient (shapes from its API.md), the
  SUPERWOW_VERSION string format, Shadow Trance's buff id 17941, UnitXP "distanceBetween".

## Roadmap (approved 19 Oct 2026)
0. Foundation: branch, toc, this file, tests. DONE.
1. Look and feel. DONE 19 Oct (not seen in game): env/octo.lua - `pfUI.octo.look` (1px black
   borders, 0.06 backdrops, PT Sans Narrow Bold text, Expressway numbers/unit/cooldown/combat,
   img\bar_elvui on unit frames, castbar, nameplates, tooltip, xp bar), `pfUI_profiles["Octo"]` =
   Slim + look (fresh installs and both resets use it; first-run wizard has an Octo button),
   `pfUI.octo.ApplyLook()` = button "Apply Octo Look" at the top of Settings > Appearance (changes
   only look keys, never sizes/positions). Accent colour: `appearance.accent.mode` class|custom +
   `.color`, `pfUI.api.GetAccentColor()` used by SetHighlight / SkinButton / rotate / dropdown
   highlight in api/ui-widgets.lua. Still teal (pfUI's |cff33ffcc / .2,1,.8): options window tree,
   scrollbar thumbs - phase 4 moves those to the accent.
2. Layout mode. DONE 19 Oct (not seen in game), modules/unlock.lua. pfUI already had drag, grid,
   middle-click reset and a right-click box (anchor, X/Y, arrows, Configure). Added: snapping while
   dragging (`SnapBox`: other movers' outer edges (frame + border, so boxes sit flush) and
   centres and the screen edges/centre first, grid lines second, 10 px, accent guide lines, Alt
   or the Snap box = off). Seen in game 19 Oct: the first version (snap on release after the
   client's StartMoving) did not snap - the client reports a moved frame's edges late. Now the
   drag is done by hand: DragOnUpdate moves the selection from the cursor and pulls it onto the
   snap live; the drop saves from those numbers (AnchorFor = screen third, AnchorOffsets) and
   never reads edges back. Reparents to UIParent at drag start, as pfUI did on drop. Grid drawn from the centre
   with exact accent centre lines, top bar (Snap, grid -/+ 32/64/128/256 cells, ?, Reset All,
   Done), Shift on the arrows = 10 px, `/moveui` and `/pfmove`, options window only reopens when
   layout mode was started from it, help box only on first use (`unlock.helpseen`). Config group
   `unlock`: snap, gridsize, helpseen.
3. Installer + profile strings. DONE 19 Oct (not seen in game).
   modules/firstrun.lua rewritten as one ElvUI-style window (step list left, Previous / Next /
   Skip, close X = ask again next login). Steps: init, profile (Octo recommended + stock profiles,
   UI scale; picking one sets pfUI_init.profile before the reload so it does not ask again),
   layout (Tank/DPS vs Healer: `pfUI.firstrun.SetRaidLayout` moves `pfRaidCluster` to bottom centre,
   width from raidlayout columns), cvars, chat_right, chat_position, chat_channels, finalize.
   AddStep(name, func, title) keeps the old two-argument form. `/pfui install` =
   `pfUI.firstrun:Restart()`; `/pfui move`, `/pfui export` also work. Meter / combat text steps
   come with phases 5 and 6.
   modules/share.lua (/export, /import, /share - pfUI's own) fixed: import no longer runs the
   pasted text with loadstring (`parse` reads only `["k"] = "v",` / number / `{` / `}` lines),
   Import shows a per-section change preview, strings without positions/disabled keep the
   importer's own (pfUI used to reset them), Import accepts the encoded string directly. Two
   upstream bugs: enc() cut a real character when the text ended on a 92-char line break, dec()
   used a pattern find (errors on "(" or "["). `pfUI.share` exposes serialize/parse/preview/import.
4. Options window, ElvUI layout. modules/gui.lua. Window 940x600; title bar: accent "pfUI Octo" +
   version, search, Move Frames / Keybinds (hoverbind) / Install / Profiles (share).
   First version (one control per row, zebra) seen in game 19 Oct: the user called it "messy"
   and asked to copy ElvUI. Second version (not seen in game yet):
   - Tree: ONE column 170 wide (`RelayoutTree`); a category's pages are its `children`, listed
     indented under it only while it is open (+/- marker); they used to open a second column.
     Page areas fill the category area (no inner column). Clicking a page opens its category.
   - Pages: title "Category > Page"; every "header" is a titled group box; CreateConfig only
     collects cells (`Place`), `Finish(page)` (called after the page's populate func) lays each
     group out: warnings, then tick boxes / colour swatches / buttons in a 2-column grid, then
     dropdowns / text fields (label above), then lists; same kinds keep their order; a spacer
     CreateConfig(nil) starts a new block. Tick box labels are clickable. Cells record
     `frame.cell` {x,y,w,h} and `frame.cellkind`.
   - Tests check no cells overlap and all sit inside their page and group. PFUI_PREVIEW_DIR=<dir>
     makes tests\run.lua write options-preview.html (a drawing of every page from those numbers;
     serve it over http to view it in the browser pane, which will not screenshot file://).
   Every teal in gui.lua / api/ui-widgets.lua uses GetAccentColor (About logo left teal).
5. Meters, Details!/Recount depth (the user asked "they should tell you everything, all
   interrupts, all casts"): damage / healing / overhealing / absorbs, damage taken, per-spell and
   per-target breakdowns with hits, crits, misses, max/min/avg, interrupts (who kicked what), dispels
   and purges, crowd control and CC breaks, deaths with a log of the last hits and heals, every cast
   per player, buff/debuff uptime, activity time, segments (current / overall / per fight / boss),
   reports to chat. Threat from the server protocol (TWThreat's `TWT_UDTSv4`, unverified on this
   server) with pull-aggro line and tank view. Sources: nampower events (casts, GUIDs, interrupts)
   where present, combat-log strings as fallback. Credit ShaguDPS for the parser; TWThreat code is
   not copied (no licence).
   RELEASE 1 DONE 19 Oct (not seen in game): combat-log strings only (no nampower yet, so no
   in-game probes were needed). modules/meters.lua: SPECS = GlobalStrings template name + kind
   (dmg heal miss interrupt cast start dispel death) + capture roles; templates sorted by fixed
   text length (longest first - "Your %s hits %s..." before "%s hits %s..."), anchored ^$,
   trailers (absorbed/resisted/blocked/vulnerability/glancing/crushing) stripped first. Event name
   picks the kinds tried (KindsFor). Segments: pfUI.meters.current / history (C.meters.history) /
   overall; a fight starts on the first tracked action while the group is in combat, ends 1 s after
   the group leaves combat, named after the enemy that took most damage. Effective heal = min(amount,
   missing HP of the target's unit). Interrupt "with" = the kicker's last spell within 1.5 s.
   Dispels = "X's Y is removed." credited to the last dispel-spell cast on X within 2 s (English
   dispel names via T[]). Casts = cast/perform lines + "begins to cast" + direct hits without a start.
   Deaths keep the last 15 hits/heals (15 s) with HP %. modules/meters-threat.lua: server protocol,
   warn at C.meters.threatwarn % of the pull point (110 melee / 130 range). modules/meters-window.lua:
   2 windows docked in the right chat via pfUI.thirdparty.meters:RegisterMeter (C.thirdparty.pfmeter /
   pfthreat .dock); first load sets C.thirdparty.showmeter = "1" once (C.meters.shown). Options:
   Meters > General / Threat. Offers to DisableAddOn ShaguDPS + TWThreat once (C.meters.asked).
   tests/globalstrings.lua = the client's combat templates (patch-5) for the offline tests.
   Not yet: nampower events, CC / buff uptime, saved fights across reload, multiple-window snapping.
6. Combat text. DONE 19 Oct (not seen in game). OctoBG's SCT.lua / SCTEvents.lua copied as
   modules/sct-engine.lua / sct-events.lua (headers, frame names and the area movers changed, the
   rest as in OctoBG - fix bugs in both or note it), running on modules/sct-core.lua = a stand-in
   for OctoBG's core (`pfUI.sctB`: B:On / B:Fire / B:Every / B:Print, B.db.sct, U.GuidOf, U.Panel,
   SpyData.Font). modules/sct.lua (module "sct"): settings `pfUI_config.sct` in REAL Lua values
   (booleans, numbers), copied once from OctoBGDB.sct (`fromOctoBG`), defaults filled; fires
   OBG_LOADED at load, OBG_INIT at PLAYER_LOGIN, OBG_ZONE on zone change; B.test while /moveui is
   open (sample text per area); `/pfui sct test|on|off`; options "Combat Text" > General, Scroll
   Areas, Nameplates, Crits & Sounds, Messages: Combat, Messages: Alerts, Text & Filters, built
   with `pfUI.gui.Native(get, onchange)` (true/false <-> "1"/"0", numbers, virtual key "rgb") and
   the new "slider" widget (values = { min, max, step }). Areas are pfUI movers
   pfCombatTextIncoming / Outgoing / Healing / Notes / Extra; a drop's x / y come from
   C.position (anchor + offsets), then C.position is cleared (x / y are the truth).
   Media: img\sct (burst.tga, Spy's four wavs, sounds\custom for the user's own).
   Profile strings now carry booleans (share.lua serialize / parse); strings without "sct" keep
   the importer's combat text. Same day, user: "totally moved over out of OBG" - OctoBG's SCT
   files and menu are deleted (OctoBG 2.2.0, not git): OctoBG\modules\SCTLink.lua forwards its
   alerts to pfUI.sct.CT:Notify and keeps the threat label's plate lookup and sounds; its threat
   page is Setup > Threat label. OctoBG's 94 combat text tests moved here as tests\sct.lua
   (events / clock go only to pfSCTCore + pfCombatTextContainer: Fire / Tick in that file);
   tests\globalstrings.lua also has the reward templates (honor, rep, skill, loot, money, extra
   attacks). /sctdisplay is pfUI's now (when SCT itself is not loaded).
7. Map styles (SexyMap). DONE 19 Oct (not seen in game), modules/minimap-style.lua on pfUI's
   minimap, settings C.mapstyle, options Minimap > Map Style / Buttons & Extras. Shapes: square
   (pfUI's img\minimap), round (the game's textures\MinimapMask), and img\minimap\mask-*.tga +
   outline-*.tga made by tools\MakeMinimapMasks.ps1 (rounded, rounder, squircle, octagon, diamond,
   corner-tl/tr/bl/br; white inside, clear outside, 4x4 samples). Border: pfUI frame (square only)
   / shape outline (colour or accent) / none. Three art layers from the game's spell textures
   (names checked against every MPQ's (listfile): AuraRune256/_A-D, Holy/Ice/Fire/Nature/InnerFire
   runes, DemonRune6/7, rings, glows...), size %, colour, ADD/BLEND, above (frame above Minimap) or
   below (level 0 child of the map), spin via 8-value SetTexCoord. Buttons tracking / mail /
   battlefield / addon-button toggle / clock: show | hover (fade while the mouse is over the map)
   | hide (alpha 0 + no mouse). Clock (local/server, 24 h per C.global.twentyfour), ping name
   (MINIMAP_PING arg1), auto zoom-out, opacity in / out of combat, 10 presets
   (`pfUI.minimap.ApplyPreset`). `pfUI.gui.RefreshPage(page)` re-reads a built page's controls.
   Not verified in game: the spell textures' look as minimap art, SetMaskTexture with a 32-bit
   TGA mask, MINIMAP_PING args, art layer stacking under pfUI's backdrop.
8. The user will add more addons "like this" into pfUI Octo.
   22 Oct 2026, action bars (Bartender4 as the model; Bartender4 is All Rights Reserved - the
   user's Bartender4-4.18.3.1.zip was read for its option list only, nothing copied):
   modules/actionbar-octo.lua (`pfUI.barsOcto`) hooks pfUI.bars.UpdateConfig and adds per bar
   scale / alpha / fadeto / vis_combat / vis_pet / vis_target / vis_stealth (C.bars.barN), button
   skins + icon zoom (C.bars.skin / zoom) and 6 looks. api.lua EnableAutohide fades to
   frame.fadeTo and back to frame.octoAlpha. modules/actionbar-options.lua: section "Action Bars"
   (General, Bars with a tab per bar, Buttons and text, Paging, Gryphons), pfUI's Actionbar
   category hidden; pinned preview = real bars on a mini screen (click = its tab, Shift + wheel =
   button size) + a sample button. Not seen in game. tests stub GetNumShapeshiftForms (the
   actionbar module now starts in the mock).
   22 Oct, effects (EllesmereUI's feature list as the model; its licence reserves all rights and
   much of its art is other artists', so nothing copied). Same day the user asked for every
   button option on ONE page: "Buttons" (abbuttons) has cards Button / Hover and press (incl.
   press animation) / Cooldown (swipe + number + colours) / Proc glow / Highlights / Letters /
   Equipped items; the sample's parts open their card, the button itself opens what it is showing
   now; Test buttons replay one effect on the sample (M.Play) or on the real bars (AB.Test). In
   actionbar-octo.lua: hover / press looks (AB.STYLES, AB.Layer / AB.Paint; hover rides on pfUI's
   f.highlight, press on OnMouseDown/Up + keystate in OnClick, 3 s safety), proc glows (AB.GLOWS
   ants / pulse / shine / border + start burst; AB.REACTIVE icons while IsUsableAction, AB.PROCS
   buff icon -> spell icon; 5 Hz watcher), cooldown swipe (AB.CDSTYLES; hooks
   CooldownFrame_SetTimer via cd.octoButton; non-clock styles set cd.pfCooldownStyleAnimation = 0),
   empty slot fill (AB.SLOTS, on f.backdrop), equipped quality border (AB.Quality = scanning
   tooltip's name colour). Art from tools\MakePlateArt.ps1 -> img\bars. The preview's sample
   plays a 13 s loop of all of them; the note under it opens what it shows. Not seen in game;
   unverified: Model SetAlpha(0) hiding the clock, keystate on key presses, tooltip quality colour.
   25 Oct, looks rebuilt (NOT seen in game). User's screenshot: Neon was a thick grey-white box round every
   button, empty ones too - pfUI's glow texture 6 px wide in the accent colour (class colour: a priest's is
   white), on a frame parented to the button (pfUI hides only an empty slot's backdrop). Now AB.SKINS are
   parts (edge {size, off, "bevel"}, line2, outer {size, off, glow|glow2}, gloss, shade, frame =
   UI-Quickslot2) drawn by AB.Draw(f, key, own) on frames under f.backdrop (gloss / shade / frame are BORDER
   textures on f, shown / hidden by the backdrop's OnShow / OnHide). Each part's colour C.bars.skin_<part>
   ("" = the skin's own, "accent" allowed) + _class, sizes skin_edgesize / skin_outersize, bar backdrop
   colour bar_bg; AB.ClearColors on every look / border pick. 14 looks (AB.PRESETS, 5th field = the idea):
   ideas from Masque's Apathy (thin square lines) / Entropy (the same in metal colours) / Dream / Zoomed,
   ElvUI pixel borders and shadows, the game's frame (Bartender / Dominos default) - nothing copied. Slot
   style "game" = UI-Quickslot (crop .14-.86 guessed). Options: General = Looks as picture tiles (7 a row,
   picked one purple and in your colours), Look colours card (12 colours, unused ones dimmed), Behaviour;
   every card's small controls via Grid(p, cols, items) in even columns; tabs purple (pick-one). Preview:
   each bar's buttons are copies at real size scaled by the view (MiniButton) drawn with AB.Draw, empty
   slots only where the bar shows them, the bar's backdrop only where it has one, outline only on hover /
   the open tab. Tests: W.ColorMade(label, get) registers grid colours for the "every colour has a picker"
   check.
9. OctoBG's look for the whole options window (20 Oct, not seen in game). User (ElvUI screenshots +
   OctoBG's options): "copy Octo BGS style of UI and update PFUI into being my own addon", and
   "PLEASE GET SCROLLING COMBAT TEXT OPTION PANEL IT WAS IN OCTO BG" (the CreateConfig pages
   were not what they knew). Also: tree categories did not visibly fold/unfold for them.
   - modules/octo-widgets.lua (plain file, `pfUI.octoui.W`) = OctoBG's core\Widgets.lua: pages of
     folding cards, switches, sliders, dropdowns, Find index. Wider (body 700, card 668, half 326).
     Folded cards + Background in `pfUI_cache.octoui` (per account, not in profile strings).
     Fonts/textures copied from OctoBG into pfUI\fonts and img\octo (Roboto, Fira, Share, ...).
   - modules/octo-options.lua (module, right after gui) turns `pfUI.gui` itself into OctoBG's
     shell (so every pfUI.gui:Show / Hide / Reload keeps working): title row, quick bar (Move
     Frames, Keybinds, Install, Profiles, Background, Find a setting), topic list 196 wide (Octo
     sections first, then one folding section per pfUI category; one open at a time; wheel
     scrolls), page panel. pfUI's category areas are re-anchored onto the page panel, the old
     tree buttons reparented to a hidden frame (gui.lua still drives them; O:ShowLegacy shows
     areas directly, never via Click). Keys: "o:<page>" (Octo) / "l:<Category>[/<Page>]".
     `O:AddPage(group, key, label, build)`, `O:Open(key | category, page)`. Find searches W.index
     and gui.lua's searchDB (now `pfUI.gui.searchDB`). gui.lua calls `pfUI.gui.OnPageBuilt(page)`
     after Finish: O.SkinPage restyles pfUI's pages (cards, blue tick boxes, disc sliders with fill).
   - modules/sct-options.lua = OctoBG's SCTOptions.lua pages (ctgeneral, ctareas, ctplates,
     ctcrits, ctevents, ctfilters) almost verbatim; threat page stays in OctoBG. /sct opens them.
     The CreateConfig "Combat Text" category is gone from sct.lua.
   - Layout mode (unlock.lua): ElvUI boxes (`Paint`: see-through fill, blue edge + label; gold =
     Alt-click source), labels in words (`NiceLabel`). Clicks as ElvUI: left = nudge box, right =
     the frame's options (OpenConfigDialog -> O:Open; frame_configs gained RaidCluster, Meter%d,
     CombatText%a+ -> "ctareas"), middle = reset. Alt-click two boxes: `MatchSize` (unit frame /
     castbar width settings, height too between the same kind; meters width/height; else scale).
     `this.justDragged` (set on drop, cleared on mouse down) keeps the drop from counting as a click.
   - Raid frames: only pfRaidCluster is a mover, sized to the whole grid (raid.lua); individual
     pfRaidN movers are removed (old per-frame positions no longer apply). Healer layout centres
     the cluster with xpos 0. Not verified: a cluster saved with a TOP anchor shifts the grid down
     by its new height once.
   - Sizes in layout mode (25 Oct 2026, NOT seen in game; user: resizing "jump[s] in size ... not
     smooth", wants "match size buttons", raid "messes up" when made bigger, raid options hard to
     find, Unit Frames page "a bit of a mess"). unlock.lua `SZ` (= pfUI.unlock.size): a wheel notch
     is 2% (Shift 10%, Ctrl 0.5%; was 0.1 with round(..., 1)); `KeepPlaces(frames, fn)` keeps each
     frame on the screen point it is saved at (from C.position offsets via SZ.Point / SZ.Offsets,
     never from edges; f.unlockFix keeps the exact point between notches so pfUI's whole-number
     xpos does not creep). Frames on their default place are left there. Size readout = a gold
     tag under the box (d.sizebox, scale 1 / UIScale) on hover and while sizing, and in the nudge
     box, which gained - / + and "Match size..." (pfUnlockMatchMenu: same-kind boxes, purple;
     action bars only list bars, plus gold "Every other bar like this one"; closes on an outside
     click via a full-screen catcher). MatchSize: two bars = pfUI.barsOcto.CopySize (icon_size,
     spacing, scale; also C.position scale) + MatchAll; raid = width per frame from the other box
     (SZ.RaidFrameWidth). Raid wheel (ResizeRaid): C.unitframes.raid width +1 px (Shift 5), height
     keeps the shape, raid:UpdateConfig re-grids; an old cluster scale is folded into the sizes and
     reset to 1 (non-integer scale left uneven gaps - the likely "messed up" raid). raid.lua:
     o_growy UP|DOWN, o_growx RIGHT|LEFT (nil = pfUI's up / right). frame_configs 3rd field = the
     card OpenConfigDialog opens (RaidCluster -> "Raid layout"). Bars page: "Match all bars to this
     one". Unit Frames > Frames (item 11): UF.SECTIONS = 7 section tabs under the preview (Size and
     bars, Text, Buffs, Icons, Look, Raid layout, All frames; purple, game icons) show only that
     section's cards (UF.Filter re-chains shown cards, p.last = last shown; UF.SetSection opens
     them; pfUI.plates.OpenSection is wrapped to switch section first); preview box 170 -> 136,
     Test buttons moved to a "Try it on the preview" card (Look); every card has a picture
     (UF.CARDICON); "All frames: portraits" merged into basics; Raid layout card: live summary,
     columns x rows, fill, growth, frame width / height / power height, gap, labels, Move button;
     the Raid frame tab opens on it. Preview raid grid follows columns and growth.
     Tests: tests\layout-size.lua.
   - Locks (25 Oct 2026, NOT seen in game; user: druid mana bar dragged off the Player frame "wont
     lock back", wants to lock boxes to others and group them, in the Match menu). api.lua:
     C.position[name].attach / relpoint = saved on another movable's point (SaveMovable sets it when
     GetPoint's relative frame is a movable other than the parent; LoadMovable anchors to it, retried
     5 times via QueueFunction if that frame is made later). unlock.lua: LockedTo / HomeOf (posdata's
     relative frame = where its default place hangs, pfDruidMana -> pfPlayer) / Holder / HeldBy;
     LockTo (BOTTOMLEFT on BOTTOMLEFT, stays where it is), Unlock, LockBack (= middle-click reset).
     Nudge-box button "Match / Lock...": first page Match the size of > / Every other bar (bars) /
     Lock to another box > / Lock other boxes to this one > / Lock back on <home> (green, when moved
     off it) / Unlock from X (red); lists nearest first, no loops, Back row. Dropping a locked frame
     keeps it locked at the new offset; boxes that move with the dragged one are not snap lines;
     arrows / X / Y keep the relative frame (they used to re-anchor to the parent); KeepPlaces skips
     locked frames. The size tag says "on <frame>".
   - Zooming previews and copying a frame (25 Oct 2026, NOT seen in game; user: "all preview windows
     able to be zoomed in and out on and dragged ... if you scroll outside of anything you can edit
     it will zoom", and copy ALL settings Player <-> Target). octo-options.lua W.ZoomBox(p, h) = W.Box
     + ScrollFrame (FULLSCREEN, clips) + canvas + stage (returned, box-sized; stage.view = { z, x, y,
     Zoom, Fit, pan, fit }). Wheel zooms 1-5x towards the mouse, drag empty space pans (a Button
     behind the stage), double-click / corner "Fit" resets; parts pushed outside the box get
     EnableMouse(false) (octoNoMouse) since the clip does not stop the mouse. Stage and canvas have
     OnMouseWheel, so every PassWheel(part) reaches the zoom. Used by the previews of action bars
     (+ gryphons), bags, buffs, cast bars, chat, gear bar, meters (+ threat), minimap, nameplates,
     combat text, swing (`(W.ZoomBox or W.Box)`). Unit frame preview: plain wheel zooms (was Alt).
     Copy: unitframes-options UF.COPYPARTS (all / size / text / auras / icons / look by key
     patterns, UF.PartOf; never visible, click casting, raid grid), UF.Copy(from, to, part) keeps
     the old values for UF.Undo; gold "Copy from..." at the end of the section tabs (section "Size and
     bars" is now "Size") = W.Menu of frames, then of parts, and Undo. Cast bars page: CB.Copy /
     CB.Undo / CB.CopyMenu (all but hide_*).
   - Size tag = editor (25 Oct 2026, NOT seen in game; user: "you should be [able to] edit here for
     quick resizing ... clear small and easy"). unlock.lua SizeEditor(d): width x height and % as
     small gold EditBoxes (Enter applies, Esc puts back, wheel over one = +-1, Shift 10), - / + =
     one notch (Resize); a grey line under them (button size, raid grid, "on <frame>"). Stays up
     while the mouse is on it or a number is being typed. Field names wbox / hbox / pbox (the test
     mock keeps sizes in .w / .h). SetBoxSize(f, w, h, scale): unit frames / cast bars set their
     width / height settings (portrait part kept), meters C.meters.winN, raid per-frame sizes from
     the whole raid (grid kept), anything else scaled to the width / height; MatchSize's meter
     branch now writes C.meters.winN too (it wrote the old pre-phase-1 keys).
   - Tests: tests\mock.lua keeps its own bookkeeping in `_parent` / `_kids` (pfUI uses .parent and
     .children on frames) and has a real SetParent.
   - Seen in game 20 Oct ("looking better"). Then: right-click on a box only closed layout mode
     and showed the window (frame_configs pointed at a "Group Frames" category upstream pfUI no
     longer has; gui OnShow also ended layout mode). Now `O:FindLegacy(cat, page)` matches names
     loosely (case, colour codes, punctuation; a page found in any category; a category's first
     page) and `pfUI.gui.keepLayout` keeps the boxes up while the page opens. User also: "use
     actual picture and logos of spells", "get rid of so much text", "sliders ... and numbers
     for accuracy": section icons (`O.ICONS`, every name checked in the MPQ listfile, scratchpad
     icons.txt), card / heading explanations moved into tooltips (W.Card text, W.Heading text ->
     "How it works"), `W.NumberBox` on every Octo slider (typed "40%" -> 0.4 for 0-1 values) and
     on pfUI's sliders, `O.NumberSlider` adds a slider beside every pfUI number field
     (`frame.numtype`, range guessed from the key name / value, typing past the end widens it).
   - Key Map (modules/keymap.lua, `pfUI.keymap`, /keymap /km; quick bar Keybinds = menu: original
     hover binding or Key Map). User's model: a retail "KeyMap" addon screenshot. A keyboard (UK /
     US / QWERTZ / AZERTY rows, F-keys, mouse 3-5 and wheel), layers base / SHIFT- / CTRL- / ALT-
     (click a modifier or layer button to lock, hold one to peek). Keys show the action button's
     icon (binding ACTIONBUTTONn / MULTIACTIONBARmBUTTONn -> slot as actionbar.lua: bar 1 = 0,
     MULTI1 = 60, MULTI2 = 48, MULTI3 = 24, MULTI4 = 36), or "SPELL x" / "MACRO x" bindings' icons,
     or the binding's name. Drop: action key -> PlaceAction(slot); else ClassicAPI GetCursorInfo +
     SetBindingSpell / Item / Macro (found as "Usage:" strings in ClassicAPI.dll - returns assumed
     retail-like, NOT verified); else a free action slot + SetBinding. Left-click pick up / move /
     swap, right-click unbind, Unbound abilities = bar slots with an action and no key. Layout and
     panel choice in pfUI_cache.octoui.keymap. Not verified in game at all.
   - Seen in game 20 Oct: Key Map works (icons on keys, Alt layer, unbound list). Slider fill
     did not follow the knob on stretched sliders (width from GetWidth); now `W.FillToThumb`
     anchors the fill's right edge to the thumb texture (all Octo, pfUI-page and number sliders).
   - Key Bindings (modules/keybinds.lua, `pfUI.keybinds`, /keybinds /kb; third entry of the
     Keybinds menu, "All bindings" on the Key Map). User asked for Blizzard's key binding list
     in our look, folding categories, a right-hand panel explaining things, pictures everywhere.
     GetNumBindings / GetBinding (HEADER_x rows start categories, name BINDING_HEADER_x; BLANK
     joins the previous one; headers from patch-4 Bindings.xml: MOVEMENT CHAT ACTIONBAR
     MULTIACTIONBAR TARGETING INTERFACE MISC CAMERA RAID_TARGET ITUNES_REMOTE), category icons +
     one-line explanations, action button rows show their spell (pfUI.keymap.Describe), raid mark
     rows the mark (UI-RaidTargetingIcons quarters). Key boxes: click then press (modifiers,
     BUTTON3-5, wheel); right-click clears; saved at once. Character specific = SaveBindings(2) /
     LoadBindings(1); Reset = LoadBindings(0). Fold state in pfUI_cache.octoui.kbFold.
     Seen in game 20 Oct: BLANK2 / BLANK3 headers showed as categories (now any HEADER_BLANK*
     joins the one before); categories now start folded (kbFold[id] == false = open).
   - Key Map side panel (user: "move the All bindings next to Unbound abilities ... make them
     both drag drops"): two tabs with icons (Unbound INV_Misc_Key_01 / All bindings
     INV_Misc_Book_09), the All tab = pfUI.keybinds.Read() categories folded in a scroll list
     (open state keymap.open). Our own drag (not the game cursor): a picture follows the mouse,
     on release `KM.KeyUnderMouse` (MouseIsOver over the key cells) -> `KM.Give` = SetBinding.
     Click a list item then a key works too (KM.ability / KM.command). The toolbar's All
     bindings button went; "Unbound" is now "Lists" (show / hide the panel). Not verified in game.
   - Not verified in game: the whole window, Roboto in it, disc slider thumbs on pfUI's pages,
     menus of pfUI dropdowns (parented to pfUI.gui) over the new panels, OnSizeChanged on sliders.
10. Plater-style nameplates (user 20 Oct: "our own version of this name plate addon ... with all
   features and art work"). Spec and phases: docs\plates-spec.md. Plater is All Rights Reserved:
   no code or texture of it is copied; the user's Plater v661 zip was read for setting names only.
   PHASE 1 DONE 21 Oct (not seen in game): modules/plates.lua wraps pfUI.nameplates (OnConfigChange
   / OnDataChanged / OnUpdate / UpdateConfig; nameplates.lua untouched), parts in `plate.octo`.
   Settings C.plates. Art: tools\MakePlateArt.ps1 -> img\plates (bars, arrow, chevron, corner,
   underglow, spark, star, skull, tick). modules/plates-options.lua = Octo section "Nameplates"
   (7 pages, all of pfUI's nameplate settings too); `O.replaced[name]` hides pfUI's own category
   from the topic list and Find. Plater look applied once at first load. Next: phase 2 auras.
   Seen in game 21 Oct, then: looks switched plates off (pfUI's UpdateConfig re-applies
   showhostile; the V key does not change it) - P.Refresh now skips SetGameVariables, only the
   Show tick boxes call it (P.ApplyShow). 8 looks (Plater, Slim, ElvUI, Big and bold, Neon,
   Classic, PvP, pfUI) incl. border skins (C.plates.skin: pfui shadow thick accent neon gold),
   the matching one lit (P.CurrentLook). Preview card (OctoBG's "Icons on nameplates" box) on
   most pages: P.AttachPreview runs pfUI's real OnCreate on 4 fake game plates (`game.preview`
   overrides state / target / combat / mark; own OnUpdate, levels raised above the box);
   "Test on real nameplates" = P.Test(60): pretend threat states + casts on every plate.
   SuperWoW check = P.SuperWoW() (SUPERWOW_VERSION): pfUI's superwow_active is only set at the
   first cast event. Mock: frame level kept in `_level` (pfUI plates have a .level text).
   Seen in game 21 Oct: preview and looks work. PHASE 2 auras DONE 21 Oct (not seen in game):
   modules/plates-auras.lua, see docs\plates-spec.md section 4; options page "Auras" (was
   Debuffs). Mock gained UnitBuff / UnitDebuff (Mock.units[guid].buffs / .debuffs) and
   Get/SetStatusBarColor; run.lua stubs GetDifficultyColor. Note: the map style test leaves a
   global UnitName that only knows party1 - later tests must answer GUIDs themselves.
   Seen in game 21 Oct: auras work. PHASE 3 DONE 21 Oct (not seen in game): modules/plates-lists.lua
   (NPC / cast colours and names, quest marks from pfQuest or the quest log, class / pet icons,
   auto toggles, tank "taking"), pages "Colours and names" and "Quests, icons and auto" (9 pages
   now). Spec section 5. tests\globalstrings.lua gained QUEST_MONSTERS_KILLED. Next: phase 4.
   22 Oct: combat text preview, modules/sct-preview.lua (`CT.Mini(box, onPick)`): a scaled copy of
   the screen, each area box at its x / y, a mock enemy plate, sample texts moved by CT.MOVE with the
   area's anim / dir / size / crit style / time / speed. Area boxes: click = its tab on Scroll areas
   (sct-options `AREA.cur`), drag = moves the real area (CT:PlaceArea), Shift + wheel = text size,
   right-click = default place. On Basics, Scroll areas, Nameplates, Crits.
   22 Oct: combat text pages regrouped: General (looks: CT.LOOKS / ApplyLook / CurrentLook, lit
   button; preview; look of all text with new db.scale / fade / maxLive in sct-engine; where your
   damage goes; game numbers), Scroll areas, Nameplates, Crits, Messages and sounds (grid, then
   warnings and sounds), Text and filters.
   tests\mock.lua: SetVertexColor / SetTextColor take numeric strings (as the client does).
11. Unit frames section (22 Oct 2026, not seen in game). User: "this menu needs updating also and
   making smaller into managable order ... a nice clean preview box ... tabs that you select which
   unit frame ... all parts must be clickable ... taking you to their specific menus".
   modules/unitframes-options.lua (`pfUI.ufOcto`): 3 pages instead of pfUI's 14 - General (shared:
   text, portraits, colours, class extras, party / raid), Frames (12 tabs in the pinned preview,
   UF.cur; cards Frame / Health bar / Health text / Power bar / Power text / Portrait / Buffs /
   Debuffs / Icons / Glow and indicators / Buff and dispel markers / Colours / Raid layout),
   Click casting. pfUI's Unit Frames category is hidden (O.replaced); custom_indicator list is not
   on the new pages. Preview = pfUI's REAL frames: pfUI.uf:CreateUnitFrame("OctoPrev"..key, i,
   C.unitframes[key]) (an unknown unit, so no events), reparented into the box, label set to
   "player" (or target / pet when they exist), UF.Tame: no click / tooltip / OnUpdate, every
   part restrata'd FULLSCREEN (pfUI puts frames on MEDIUM, glow / portrait on BACKGROUND).
   Refreshed every 0.5 s (RefreshUnit in pcall) with sample buffs / debuffs / skull / icons /
   glow so every part can be clicked; text spots are as wide as the words; the stage zooms and
   centres to fit the box. Party = 4 frames, raid = 10 (5 x 2). Hot spots: click = UF.GO card
   (via pfUI.plates.OpenSection), Shift + wheel = UF.SIZE. Layout mode right-click now gives
   unlock's frame_configs Octo keys ("ufframes", tab); `O.tabs[key](page)` in O:Open picks the
   tab. Mock: ManaBarColor / UnitReactionColor (run.lua), Get/SetFrameStrata with inheritance.
   Not verified in game: the preview frames' look, RefreshUnit on a frame whose label was
   changed by hand, libpredict walking pfUI.uf.frames (the previews are in it).
   Same day, TPerl's features (user's "TPerl 1.2.45 Retail v4.zip"; TPerl is GPL-3, pfUI MIT:
   only its option list was read, no code or art used): modules/unitframes-octo.lua
   (`pfUI.ufExtras`) wraps pfUI.uf.UpdateConfig (and every existing frame's copy) and
   pfUI.uf.RefreshUnit. Per frame C.unitframes[unit].o_*: border skin (UO.SKINS), shade behind
   the bars (gradient), fading bar (ghost texture behind the fill), combat flash (UNIT_COMBAT),
   target highlight, debuff highlight (DebuffTypeColor, UO.CURES), class icon / class picture
   portrait (img:classicons + CLASS_ICON_TCOORDS), elite / rare / boss crest or word, AFK /
   offline / dead / ghost / feigning marks; player buffs flash < 30 s; pet happiness only when
   unhappy / flashing; C.unitframes.o_targetsound. 12 more bar textures appended to
   pfUI.gui.dropdowns.uf_bartexture (every texture menu). Art: MakePlateArt.ps1 -> img\bars
   (bar-smooth/bevel/steel/cloud/diagonal/pill/minimal, uf-elite, uf-rare, uf-afk, uf-offline).
   Options: Frames cards "Border and background", "Class and status" + additions; preview
   Test buttons (hit / heal flash, debuff colour, dead, offline). Not on 1.12 or skipped: role
   icons, ready check, summons, absorbs, own-caster auras, stealable glow, talents, sorting.
   Unverified: UnitIsAFK / UnitIsFeignDeath on this client (guarded), UNIT_COMBAT args.
   Cast bars page (22 Oct): modules/castbar-options.lua (`pfUI.castbarOcto`), key "ufcastbar" under
   Unit Frames, replaces pfUI's Castbar page. Tabs Player / Target / Focus (CB.cur); pinned
   preview = a sample cast bar built like castbar.lua's, looping 4 spells (cast fills, channel
   empties, fades out), name / rank / timer / icon / lag per settings; spots: bar (size, Shift +
   wheel height), fill (colours + texture), name, timer, icon, lag. CB.Apply sets show* flags,
   size, texture and text points on pfUI's real cast bars live; on/off, fonts, hide_blizz need a
   reload (settingChanged). The Unit Frames preview shows a cast bar under player / target / focus
   that opens this page on its tab; layout mode's cast bar boxes do too (O.tabs.ufcastbar).
   Then (user: general options under the preview, test the font, textures / shades showed
   nothing): the General page is gone - its cards are on Frames as "All frames: ..." (text first,
   right under the preview; basics, portraits, colours, class extras, party and raid at the end).
   Font / size / outline apply live (UF.FontNow sets pfUI.font_unit, then every frame's
   UpdateConfig). The preview sets its bars to part health (85% / 45% every 3 s) and 60% power, so
   texture, the empty part's colour, the shade and the fading bar show; the fading bar reads the
   bar's own value (bar.val / max) instead of UnitHealth.
   Mouse in the unit frame preview (user: frames too small, "zoom and drag ... an alt scroll",
   "nothing is movable"): Alt + wheel zooms (M.Zoom, .35 - 4x), dragging empty space (M.pan, a
   button under the spots) or a part without a place of its own moves the view, double-click /
   "Fit view" in the corner fits again (M.FitView; also on tab change). While the view is set by
   hand (M.manual) auto-fit stops and a frame whose parts leave the box hides (alpha 0, spots
   hidden). Draggable parts: UF.DRAG (raid mark, PvP flag, power bar, the six texts: x / y offset
   keys with pfUI's pixel factors - left / right texts move 2 px per unit, right one inwards; power
   y in perfect pixels); dragging updates the preview (M.Reconfigure, .04 s) and the real frame on
   release; right-click puts back. Cast bars page: drag name / timer (CB.DRAG), right-click back.
   A two-line help strip under each preview lists every control.
   Text sizes (8 Nov 2026, NOT seen in game; Bread on Discord: health text size also changed the power text):
   pfUI.uf.TextSize(config, pos, base) = txt<pos>size, else txthpsize / txtpowersize, else the frame's font size
   ("0" / "" = not set, defaults "0"). Frames > Text: "Text colours and font" has Health / Power text size, the Texts
   card a Size per text; Shift + wheel on a text in the preview (UF.SIZE[pos], 4th field = its size now).
12. Meters, Details!-style (22 Oct 2026; user's Details zip is All Rights Reserved - option and
   display names read only, no code or art). Rule from the user: use SuperWoW / ClassicAPI wherever
   they help, in every module. Phases: 1 windows + looks + options preview (DONE, not seen in
   game), 2 the extra data (friendly fire, enemy damage, damage taken by spell, healing taken,
   frags, resources, resurrects, cooldowns, buff / debuff uptime, time measure, trash / boss
   segments; SuperWoW casts / GUIDs where better), 3 Details-style breakdown window + compare.
   Phase 1: per-window settings C.meters.win1..win6 (old shared keys copied once, C.meters.migrated),
   C.meters.windows = count (1-6), M.AddWindow / M.RemoveWindow (later windows move up, positions
   too), only windows 1 / 2 dock (KeyOf). meters-window.lua: M.S(win), M.LOOKS / ApplyLook /
   CurrentLook (octo, minimal, elvui, glass, classic, neon), ApplyStyle (background, border incl.
   glow, title bar height / colours / size, fight text, buttons), Refresh draws bars from the
   window's settings (height, spacing, texture, class / one colour, opacity, background, grow up,
   class icons, rank, font / size / outline / shadow, name colour, value order M.ORDERS via
   M.RightText), M.CombatLook (opacity in / out of combat, hide in / out of combat).
   CreateWindow(id, pv) makes the options' preview window (FULLSCREEN, sample fight M.SampleRows,
   clicks -> M.PreviewClick, grip sets the size). modules/meters-options.lua (`pfUI.metersOcto`):
   pages mtwindows (tabs Window 1-6, + New window, preview, looks, cards Shows / Window / Title bar /
   Bars / Texts / Remove), mtdata, mtthreat; pfUI's Meters category hidden. O:Open(name) of a
   replaced category opens its section's first Octo page.
   Phase 2 (23 Oct, NOT seen in game). meters.lua reads more log lines: POWERGAIN* ("power":
   credited to who gains it, by spell (caster)), AURAADDED* / AURAAPPLICATIONADDED* /
   AURAREMOVED* ("aura"); CHAT_MSG_SPELL_AURA_GONE_PARTY + PERIODIC_CREATURE_BUFFS added. Actor
   fields: ff / ffspells / fftargets (a hit between two of your group is friendly fire, NOT damage
   done - kinds PLAYER / PET both sides), htaken / hsources, frags / fraglist (killer named by the
   log, else the last of your group to hit it within 10 s), power[pow] / psources[pow][from],
   ress / resslist (RESS spells), cds / cdlist (COOLDOWNS, from casts or the cooldown's buff on the
   one who has it, once per 3 s), buffs / debuffs / buffsum / debuffsum (uptime seconds: buffs on
   your group for the one who has them; debuffs on enemies for the last of your group seen using
   that spell within 30 s - 1.12's log does not name the caster). Segment fields: foes (taken / done
   / from / to / tspells / dspells), byspell (what hit your group), boss (M.IsBoss: worldboss or
   skull level on a unit we can see), trash. M.EndFight closes open auras for that fight, names it
   after the boss, and with C.meters.mergetrash merges trash fights in a row (M.Merge: numbers
   summed, max / min kept, lists joined; "Trash (n)"). M.onStart -> windows showing an older fight
   go back to current (C.meters.autocurrent). C.meters.timemeasure active | effective (window's
   ActiveTime). SuperWoW UNIT_CASTEVENT (CAST / CHANNEL) -> M.CastEvent: casts with targets, names
   via UnitName(GUID), SpellInfo(id); a cast seen by the log and the event within 1 s counts once.
   meters-window.lua MODES now have group (Damage / Healing / Resources / Misc, the title menu shows
   them as heads), value | rows(seg) (enemytaken, enemydone, byspell), list / plain (tooltip),
   text (uptime as m:ss); new: ff, enemytaken, enemydone, byspell, frags, htaken, mana, rage,
   energy, ress, cooldowns, buffs, debuffs. Breakdowns for each. Boss fights red with a skull in
   the fight menu. Data page: Fights card (merge trash, switch to new fight, per second over).
   tests\globalstrings.lua gained the power / aura templates and MANA / RAGE / ENERGY.
   Unverified in game: UNIT_CASTEVENT arg order, SpellInfo, aura fade lines for other players
   (range), boss check, the "gains X from Y" templates' source roles.
   Phase 3 (23 Oct, NOT seen in game): modules/meters-breakdown.lua (`pfUI.meters.breakdown`, frame
   pfMeterBreakdown, 720 x 470, DIALOG) replaces M.ShowDetails for player rows (enemy / spell rows
   keep the old pfMeterDetails). Header: class icon, name in class colour, display - fight, < >
   (B.Step: next / previous player of the window's rows), Report (B.ReportLines: the open tab, top
   10, to say / party / raid / guild / officer / whisper target). Tabs: Summary (all stats + top
   spells), Spells (bars; click = detail: hits, normal / critical count and average, biggest crit,
   min / max, ticks, misses by kind, glancing / crushing, overhealing, targets), Targets, Compare
   (another player - same class first - each spell side by side with the gap %; "Pick player..."),
   Deaths (each death; its last hits / heals with health %). Wheel scrolls the list. meters.lua
   spells gained ctotal / cmax / cmin (crits), ttotal (ticks) and targets per spell; M.Merge keeps
   cmax / cmin as max / min. meters-window exports M.SegmentName, M.Clock.
   Phase 4 (23 Oct, NOT seen in game), Details' window extras: status bar per window (S.status,
   statusleft / statusmid / statusright from M.SLOTS: time, mine (your value + rank), segment,
   clock, fps, ping; 1 s ticker; bars leave it room), M.TestBars(30) (every window shows
   M.SampleRows until M.testUntil; button under Looks), right-click the title = recent displays
   (C.meters.recent, M.Recent / M.SetMode), M.Snap on drop (C.meters.snap: flush side by side with
   tops lined up, or stacked with left edges lined up), C.meters.numformat short | comma | full
   (Num), erasetrash (trash fights dropped from the list, overall keeps them), reportlines,
   tooltip / tooltiplines. Options: Windows > Status bar card (preview's status bar clicks to it),
   Data > Numbers, reports and tooltips card.
   23 Oct, more (NOT seen in game): breakdown "Chart" tab (M.Sample once a second into
   seg.timeline, M.Curve = per second smoothed over 5 s; columns in class colour, the group in
   grey behind; merged trash keeps the first fight's timeline), five custom displays
   (C.meters.custom1..5 name / kind / spell; MODES custom1..5 in group "Custom", shown once a
   spell is set; M.CustomValue; Data > Custom displays card), share a window's look
   (M.ExportLook / M.ImportLook "OCTOMETER1:key=value|...", known keys only, not mode / segment /
   lock; Windows > Share this look card). Nameplates phase 4: see docs/plates-spec.md section 6.
   Unit frame preview: UF.PLACES (buffs / debuffs corner, portrait left / right / bar, class icon,
   elite badge) dragged by where the mouse is over the frame (UF.Over), right-click = UF.Default.
   Threat moved from OctoBG (23 Oct; user: "bring the threat section over here and add to it ...
   remove anything to do with threat tracking from OBG"): meters-threat.lua now also has OctoBG's
   label (TH.NewLabel / Paint / Draw on your target's pfUI Octo plate via pfUI.plates.Fx.Plates -
   istarget, else the movable pfThreatBox), cap (TH.Judge: C.meters.threatwarn % of the pull point or
   of the 1st / 2nd / 3rd other player, threatref; yellow from tnear %), popups (pfThreatAlert +
   C.meters.threatsoundkey from combat text's sound list, once per crossing and on aggro), the next
   player's name with aggro, own colours (tcolsafe / near / over / aggro), /pfthreat [70 [pull|1|2|3]].
   TH.ImportOctoBG copies OctoBGDB.threat once (timported). Page mtthreat: preview (mock plate + the
   label cycling safe / near / past / aggro, clicks to Label), status, sample / test popup / open a
   threat window, cards Threat meter, Your cap, Label, Colours, Popups.
   Meter test mode (23 Oct, NOT seen in game; user: "a full test mode ... click on test bars ... the
   extra frames ... every bit of info ... linked with easy click through menus"): modules/meters-test.lua
   records a made-up 2 min Onyxia fight through M.Record on a fake clock (_G.GetTime swapped inside a
   pcall, real overall / history / current / recent / onStart put aside and restored, roster in M.who
   with checked = 1e12), every aura it opens is closed again (the aura tracker `open` is shared).
   M.TestMode(on) / /pfmetertest; while on, M.Segment returns M.testSeg for every key; a real fight
   (M.onStart) turns it off. meters.lua Record: r.over = overheal when the target is not a unit.
   meters-breakdown.lua rewritten: 900 x 500 in the window's look (B.Look: texture, font, bg, border),
   player tabs Summary / Spells / Targets / Taken / Casts / Auras / Utility / Deaths / Chart / Compare
   with a damage / healing / friendly fire switch (B.kind), enemy view (B.foe: Summary, Hit by, Spells
   on it, It hit, Its spells) and spell view (B.bspell) for enemy / spell rows; every name is a link
   (B.Link -> B.Open, Back stack), Summary lines jump to their tab, header name = menu of everyone,
   Enemies = menu of every enemy. Windows page: "Test mode" card (switch, status, Open a breakdown).
   25 Oct 2026 (NOT seen in game; user: breakdown "looks bad ... a lot more professional and easier to select what
   category", icons, linked bars, hover descriptions; the Windows page "a mess ... more custom stuff ... font colour
   changes icons"): meters-breakdown.lua chrome rebuilt, data functions untouched (BD.TABS / KINDS / GROUPS /
   listShown / linesShown keep their shape). 940 x 560: header (picture, name menu, Back / Enemies / < > / Report / X
   with tooltips), a rail on the left (VIEW: the tabs, each with a game icon and a sentence, B.TABINFO; SHOWING:
   the five display groups, B.GROUPINFO, lit one shows the display's name), five figure tiles over the list for a
   player (Damage, Healing, Taken, Active, Deaths: click = that view), the Damage / Healing / Friendly fire strip,
   rows with a picture (class for players, skull for enemies, spell icon via B.SpellIcon = the player's spell book
   by name + a few fixed ones, question mark when unknown), left accent mark on the selected row, row tooltips
   (name, figures, "Click: ..."), panel lines with zebra, accent rules under headings, ">" on links, tooltips
   (`tip` on a line) - Summary lines now explain themselves. LayoutBody(tiles, kinds) sets where the list starts
   and B.maxrows / maxlines / chartW / chartH. Meter windows: new per-window settings (api/config.lua) namecustom,
   valuecolor / valuecustom, subcolor (the grey of the small numbers), rankcolor, valuesize, iconside, iconsize,
   barborder / barbordercolor, selfmark (0 | border | tint) / selfcolor, hovercolor, titlefont (Bar() has hov / rim,
   Refresh applies them; M.Hex). Bar tooltip starts with the display and value. Options > Meters > Windows
   re-ordered into cards with game icons (W.Card o.icon): Start with a look, What it shows, The window, Title bar,
   Bars, Pictures, Words, Colours of the words, Status bar, Share this look, Where they are, Try it without a fight,
   Remove; every setting has a description; MO.GO renamed (Words, The window, What it shows); preview box 250 high.
   25 Oct 2026, test row on the preview (Test fight, Open breakdown, Tour the views, Threat label, Status bar; the
   breakdown is FULLSCREEN_DIALOG so it sits over the options window; its Tour button steps through every view).
   25 Oct 2026, ClassicAPI's combat log (NOT seen in game; user: use the updated ClassicAPI wherever it helps):
   modules/meters-clog.lua listens to COMBAT_LOG_EVENT_UNFILTERED, reads CombatLogGetCurrentEventInfo() (1.12
   handlers only get arg1-arg9) and feeds M.Record the same records the text parser makes (M.ClogHandle, tested
   with synthetic events in tests\run.lua). The first event sets M.clog and the CHAT_MSG parsing and SuperWoW
   UNIT_CASTEVENT casts stop (meters.lua OnEvent); C.meters.clog = "0" or no ClassicAPI = the text lines as before.
   Filter: affiliation bits (mine / party / raid) or pet / guardian type on either side, else only "everyone nearby"
   (trackall); an enemy's UNIT_DIED only if the group hit it. Gains over the text lines: exact crit / glancing /
   crushing flags, interrupted spell AND the interrupting spell (r.with), SPELL_DISPEL names the dispeller and the
   aura, SPELL_AURA_APPLIED names who cast a debuff (M.AuraUp by) so debuff uptime is real, PARTY_KILL names the
   killer (frags), casts from SPELL_CAST_START / SUCCESS (hits carry r.nocast so they do not count a cast again),
   spell ids (M.spellIds: name -> id) so the breakdown's rows show C.Spell.GetSpellTexture pictures for any spell.
   Not in the events: overheal (always 0 - effective healing still from UnitHealth), SPELL_RESURRECT target.
   Report > Copy to the clipboard (window + breakdown) and Copy this look use libclient.Copy. Data page: card
   "Combat log source" (switch + status line). Unverified: that the events fire for party / raid members and
   their pets, that pets carry the pet / group flags, PARTY_KILL arriving before UNIT_DIED.
13. pfUI Octo or Blizzard, per section, live (23 Oct 2026, NOT seen in game; user: "EVERY PAGE / ADDON
   Should be easily toggled on or off at the top ... turning off will put it back to your blizzard
   setup ... no reloads"). modules/octo-blizzard.lua (`pfUI.blizz`) is FIRST in init\modules.xml: it
   snapshots Blizzard's frames (parent, points, size, scale, alpha, shown, OnShow / OnEvent /
   OnMouseWheel), MinimapBorder / mail icon textures, SHOW_MULTI_ACTIONBAR_1-4, and the bag / loot
   functions pfUI replaces (pfUI's versions noted at the first PLAYER_ENTERING_WORLD, BZ.Ready).
   BZ.Set(id, "blizz" | "octo"), C.blizz[id] = "1" for Blizzard's (re-applied 0.5 s after entering
   the world). Blizzard's way back: Restore (snapshot, f.Show = nil) + the frame's FrameXML OnLoad
   (PlayerFrame_OnLoad, TargetFrame_OnLoad, PartyMemberFrame_OnLoad, CastingBarFrame_OnLoad,
   BuffFrame_OnLoad, LootFrame_OnLoad; ComboFrame / MiniMapMailFrame / MiniMapTrackingFrame events
   re-registered by hand - read from patch-4 FrameXML, extracted with OctoBG\tools\MpqRead.ps1);
   pfUI's frames go under the hidden pfOctoBlizzHider (Away / Back). pfUI's way back = what its
   modules do at load (Kill = UnregisterAllEvents + Hide [+ Show no-op]). Sections: unitframes,
   castbar, actionbars (+ micro buttons), minimap (addon buttons back round the map:
   addonbuttons:RestoreAll; ProcessButtons does nothing meanwhile), buffs, nameplates (each plate's
   parts noted in a wrap of pfUI.nameplates.OnCreate before pfUI blanks them), bags, loot,
   combattext (CT:SetEnabled), meters (windows hidden). BZ.GROUPS maps topic list sections to them;
   octo-options shows a strip over the page (O.swap, O:LayoutSwap on Select: content moves to -110)
   with "pfUI Octo" / "Blizzard" per section, the one in use lit. 24 Oct (NOT seen in game): raid
   (pfRaidCluster / pfRaidUpdater away, Blizzard_RaidUI loaded for the Raid tab's pull-outs) and
   worldmap (BZ.map: WorldMapFrame regions, ToggleWorldMap, UIPanelWindows entry, BlackoutWorld, the
   zoom / close buttons' and zone menus' textures noted at load; pfUI's scripts noted at the first
   switch, m.octo; does nothing under Cartographer / MetaMap). The strip has 3 slots now.
   Same day: chat (BZ.chat per window: frame / tab / tab text / tab art / scroll buttons snapped,
   CHAT_FRAME_TEXTURES paths, tab regions, edit box regions and fonts; CHAT_*_GET strings,
   CHAT_FONT_HEIGHTS, SetItemRef swapped; pfUI's tab SetAlpha and TabFlash.Show noted at BZ.Ready
   (BZ.chatOcto) and put back; chat.lua RefreshChat returns early while Blizzard's chat is on),
   tooltip (backdrops, TOOLTIP_DEFAULT_* colours, GameTooltip_SetDefaultAnchor, GameTooltipStatusBar
   from BZ.snap / BZ.osnap = pfUI's own state noted at BZ.Ready; pfUI.tooltip and its status text
   away), panels (pfPanelLeft / Right, XP / rep bars away). The chat / tooltip snapshot is in a pcall.
   Chat does not start in the mock: the chat switch is only checked there when it does.
14. Swing Timer (24 Oct 2026, NOT seen in game; user: WeaponSwingTimer 2.8.6 "in its own category ... identical").
   WeaponSwingTimer is GPL-3 (CurseForge lists GPLv3; the user's 2.8.6 is a fork): user chose "built into pfUI
   Octo", written fresh - its defaults, colours and option list matched, no code or art used. Its 2.8.6 needs
   Classic Era APIs (CLEU, C_Timer, UnitGUID, BackdropTemplate) and cannot run on 1.12 anyway.
   modules/swing.lua (`pfUI.swing`): bars pfSwingPlayer / pfSwingTarget / pfSwingRanged (movers), ST.NewBar /
   Layout / Paint (the options preview runs the same code on its own clock), looks ST.BARS (game UI-StatusBar,
   WHITE8X8, imgarsar-minimal, swing-cdm) and ST.BORDERS (game UI-CastingBar-Border, gold-tinted, our
   swing-frame / swing-back / swing-diamond from tools\MakePlateArt.ps1, 1 px, none), spark = game cast bar spark.
   Swings: SuperWoW UNIT_CASTEVENT MAINHAND / OFFHAND / CAST 75 + 5019 (shots) / next-swing spell ids; else the
   combat log (CHAT_MSG_COMBAT_SELF_* = a swing, hand nearest its end; target by name prefix). Parry haste via
   VSPARRYOTHERSELF / VSPARRYSELFOTHER. Queued attacks: action slots with the HS / Cleave / Maul / Raptor icons
   and IsCurrentAction. Ranged: reload (speed - .5) then aim (.5), moving (map position) restarts the aim.
   Settings C.swing.player / target / ranged / look / warrior. modules/swing-options.lua: section "Swing Timer"
   (after Action Bars), page stbars, preview + Test on my bars (ST.Test).
   Extras (24 Oct, NOT seen in game): pfSwingCast (C.swing.cast) for Aimed Shot / Multi-Shot from SPELLCAST_START
   (ST.CASTS by name, DELAYED adds, STOP / FAILED / INTERRUPTED clear) with a latency part (GetNetStats 3rd return);
   Multi-Shot clip zone on the reload (C.swing.cast.clip); marks via ST.Mark on textures made in Part(): warrior
   Slam window + GCD spark (C.swing.warrior slam*, only for WARRIOR who knows Slam, ST.ScanSpells; two-hander unless
   slamonehand), paladin twist .4 s / GCD 1.5 s lines (C.swing.paladin). The preview state has preview = true so
   every mark shows there for any class.
15. 24 Oct 2026 (NOT seen in game). Colours: tests\run.lua wraps W.Color right after load and, near the end,
   sets every colour string in pfUI_config to an odd value in turn: some Octo picker (or a colour box on a pfUI
   page whose category is not replaced) must show it. PICKED there covers pickers that follow a choice on the
   page (unit frame text UF.text, minimap art MO.layer); meters.background is the old pre-window key. Swing
   mark colours became settings (warrior.gcdcolor, paladin.twistcolor / gcdcolor, cast.latencycolor).
   End art (gryphons.lua): pfUI.gryphons.art = Gryphon, Lion + the client's gold dragons (DialogFrame
   UI-DialogBox-Gold-Dragon / -Dragon2) and the elite / rare target frame dragons (cropped, coords); size =
   height, width from the crop's shape; C.bars.gryphons.sides (both / left / right), mirror. Gryphons page:
   preview of a bar with both ends + one button per picture. Retail art (DF gryphon / wyvern) would need
   the CASC file ids (no name lookup in ~/tools/wowport yet).
   Buffs section: modules/buffs-options.lua (`pfUI.buffsOcto`), page bfbuffs replaces pfUI's Buffs category
   (all its settings: icons, weapon buffs, buff bars with tabs BO.bar pbuff / pdebuff / tdebuff, totems).
   Preview: sample icons with buff.lua's spacing formulas, a sample buff bar in the tab's colours, totems;
   click = card, Shift + wheel = icon size. Buff bars need a reload (button lit once changed). Layout mode
   boxes for buffs / buff bars / totems open it (unlock.lua frame_configs, O.tabs.bfbuffs).
16. Gear sets (24 Oct 2026, phase 1 of 3, NOT seen in game; user: ItemRack-universal-4.56.1 "like we have been
   adding the rest"). ItemRack has no licence (all rights reserved) and needs Classic Era APIs: read for its
   feature list only, written fresh. modules/gear.lua (`pfUI.gear` = GR): sets in C.gear.sets[name] = { icon,
   key, slots = { s<inv> = { id = "item:enchant:suffix", name, tex } | "empty" } } (pfUI_config is per character);
   GR.Equip / Unequip (C.gear.before = what those slots wore) / Toggle / IsEquipped / Current; a queue (GR.Wear,
   GR.Tick every .1 s, one pick-up per tick waiting on item locks, 40 tries a slot) - weapons in combat
   (C.gear.combatweapons), the rest after PLAYER_REGEN_ENABLED; exact copy first, then the same item id.
   Set button pfGearButton (movable), minimap button pfGearMinimapButton (kept out of addonbuttons), menu
   pfGearMenu, Bindings.xml PFGEAR1-10 -> GR.KeyPress(n) (BINDING_NAME_PFGEARn named after its set), /gear,
   EquipSet / UnequipSet / ToggleSet / IsSetEquipped globals when free. gear-sheet.lua: GR.Flyout (item menu,
   pfGearFlyout), GR.ItemsFor(inv) via _G.GetItemInfo (pfUI's compat GetItemInfo is TBC-ordered and drops the
   equip location), character window slot hover menus + pfGearSheet panel (sets list, New from worn, Options),
   trinket bar pfGearTrinkets (use on click, cooldown swipe + numbers, menu: left = slot 13, right = 14).
   gear-options.lua (`pfUI.gearOcto`): section "Gear" (topic after Swing Timer), page gearsets: set tiles,
   19 slots in 3 rows (click = item menu into the set, right-click = leave out, Shift = take off), cards This
   set / Buttons / Swapping / Character window / Trinket bar. Next: phase 2 quick-access slot buttons,
   phase 3 events + auto queue.
   Phase 2 (24 Oct, NOT seen in game): modules/gear-slots.lua - bar pfGearSlots (movable, shown in layout mode)
   of the slots in C.gear.slotlist ("16,17,18", order kept; GR.ToggleSlot, Alt-click a character window slot
   replaces its OnClick while Alt is held), GR.NewSlotButton / GR.LayoutSlots (also the options sample),
   click = UseInventoryItem, menu C.gear.slotmenu hover | right | off, GR.MenuSide (auto = towards the middle).
   gear-sheet.lua gained GR.PaintCooldown (swipe, numbers, cd90, ready / 30 s notices via UIErrorsFrame +
   chat, also used by the trinket bar), hidden items C.gear.hidden[baseid] (Alt-click in a menu, Alt held shows
   them dimmed; not in the Gear page's own lists), only-soulbound filter (pfGearScan tooltip, ITEM_SOULBOUND).
   Options page gearslots "Slot buttons". The colour test's IsColor now needs every number 0..1.
   Next: phase 3 events + auto queue.
   Seen in game 24 Oct: the user found the first Gear sets page confusing ("look at how Outfitter and Item Rack do
   their UIs") and swapping from the character window did nothing - 1.12 has no EquipCursorItem (only
   AutoEquipCursorItem); a bag item goes on with PickupContainerItem + PickupInventoryItem(slot) (the worn one goes
   to that bag slot). The test stub sets EquipCursorItem = nil. The Gear sets page is now an ItemRack-style editor
   (GO.LEFT / RIGHT / BOTTOM slots as on the character sheet with a tick each, saved sets listed left, a
   DressUpModel wearing the set between them, name box, Wear / Take off / Save / Delete). GR.MenuItems(inv) = the
   item worn in the slot's pair (GR.PAIR) + carried items, for every item menu. Not seen in game yet.
   Blank slots (24 Oct, found from the saved file, not a screenshot): Set 1 held
   tex = "Interface\\Icons\\INV_Robe_02" for 8 slots - the picture the game gave for items it had not loaded
   yet; the file is in no MPQ, so it drew blank. GR.GoodTex refuses it; GO.TexOf looks the picture up by the
   item's base id (worn in the slot or its pair, bags, GetItemInfo) before the saved one, and the set icon /
   icon picker use it too. The saved file (WTF\...\SavedVariables\pfUI.lua, written on /reload) is the
   quickest way to see a set's data. Confirmed in game 24 Oct: slots filled, the character (model on
   UIParent, lined up each frame) sits between the slot columns.
   Slot buttons bindable (24 Oct, user: "add into our hover macro / keymap"): Bindings.xml PFGEARSLOT1-19 ->
   GR.UseSlot(inv); GR.Bindable(b, inv) on slot bar + trinket bar buttons (b.pfBinding, key text in the corner,
   GR.ShowKeys on UPDATE_BINDINGS). hoverbind.lua: `pfUI.hoverbind:AddButton(button)` - any button carrying
   pfBinding gets an overlay (the action bar overlays share MakeOverlay). Key Map: KM.Describe shows the worn
   item for PFGEARSLOTn; KM.Unbound lists visible unbound slot buttons ({ cmd, inv } entries).
   Phase 3 (24 Oct, NOT seen in game): queue - GR.Blocked() "dead" (C.gear.waitdead; Equip no longer refuses
   while dead) / "casting" (C.gear.waitcast, UnitCastingInfo / UnitChannelInfo) hold the whole queue; q.waiting
   = "combat" | "dead" | "casting", GR.WaitText for chat and the set button tooltip. modules/gear-events.lua
   (GR.events = GE): events in priority order - mount (ClassicAPI / SuperWoW IsMounted, else a buff whose
   tooltip says "Increases speed"), taxi, swim (only with IsSwimming), stealth (IsStealthed, else Stealth /
   Prowl form), this character's stances / forms ("form:<name>"), bg (GetBattlefieldStatus active), raid /
   dungeon (IsInInstance + its type, else raid group), rest, combat. C.gear.events[key] = { on, set, back }.
   GE.Check every .5 s + events: first happening event with a set wins -> GR.Equip; the gear it replaced
   (snapshot of the set's slots, widened per event set) is put back with GR.Wear when no event is on.
   C.gear.autoswap (master), autotell. Page gearevents "Automatic swaps". /gear events lists what is happening.
   Seen in game 24 Oct: the mount event swaps (and puts back); hover binding gear buttons works (after the
   env "this" fix: never assign `this` in pfUI code - use _G.this); InvTex pictures and the Slot buttons
   preview confirmed. Not tried yet: the other events, waiting while dead / casting.
   Worn pictures (24 Oct): the blank / wrong pictures were DmorphOcto's item morphs (DmorphOctoDB.items per
   slot) - a morph changes what GetInventoryItemTexture reports (main hand 905852 = a sword for Anathema,
   morph ids unknown to the client = Interface\Icons\INV_Robe_02). Proven from WDB\itemcache.wdb (18609 ->
   display 31346) + ItemDisplayInfo.dbc (patch-Z/patch-5: INV_Staff_12). GR.InvTex now asks GetItemInfo
   (real item) first; the character window's slot icons use it (hooksecurefunc PaperDollItemSlotButton_Update).
   GR.TwoHanded (INVTYPE_2HWEAPON): the slot bar leaves an empty off hand out under a two-hander.
   GR.InvTex returns nil for an empty slot (a morph still reports its picture there); the slot bar watches
   the worn links itself every .25 s (UNIT_INVENTORY_CHANGED did not reach it when a staff went to the bag).
   Rename (24 Oct): Rename button beside New set + right-click a saved set -> GO.AskRename (pfUI question box
   with an edit box; any open question box is closed first or CreateQuestionDialog just closes it).
   Trinket queue (24 Oct, seen working in game with Rename; user: TrinketMenu 12.0.6 in Downloads - no licence, rules only):
   modules/gear-queue.lua (GR.tq = Q). C.gear.tqueue["13"/"14"] = { on, order = { base ids..., "stop" },
   paused }, C.gear.tflags[base] = { prio, pause, delay } (shared by both slots). Q.Pick: <= 30 s cooldown
   = ready; worn on cooldown -> first ready above the mark; worn ready -> stays unless a ready Priority one
   above; worn passive (no "Use:" in its tooltip, Q.HasUse) -> a ready one higher up; Delay n holds it n s
   after its cooldown started; Pause holds the queue. Q.Process each second out of combat, not while a set
   swap runs / GR.Blocked, one GR.EquipItem at a time. Trinket bar: Alt-click = GR.ToggleQueue, gear mark
   gold / grey / red. GR.SetQueue(0|1|13|14, ON|OFF|PAUSE|RESUME|SORT, names...). /gear queue [top|bottom]
   [on|off]. Page gearqueue "Trinket queue": per slot a 9-row list (^ v, Priority, Pause, Delay box, the
   red stop mark). Left out: TrinketMenu's "hold while its buff is on" (no item -> buff link on 1.12) and
   sort profiles.
   Birthday suit (24 Oct, works in game): GR.Naked (every worn slot "empty", C.gear.before = snapshot,
   so Unequip dresses again), GR.ToggleNaked (menu entry Birthday suit / Dress again, /gear naked, binding
   PFGEARNAKED). Taking off: FreeBagSlot skips slots filled in the last 3 s (taken) and ones a special bag
   refused (item left on the cursor -> put back on, refused reset per GR.Wear).
   Meters padlock (24 Oct, works in game): win.lockbtn (UI-ChatFrame-LockIcon), M.ToggleLock / M.PaintLock,
   S(win).lock; per-window btnlock.
   Docking removed (24 Oct, user hated the chat-panel toggle: "it just confuses and makes a mess"): CanDock()
   is false, pfmeter / pfthreat .dock and thirdparty.showmeter forced "0", the right chat is shown, dock menu
   entry and options gone; panel.lua hides pfUI.panel.right.hide for good (its Show is a no-op). Reset
   positions (Meters page card "Where they are", window menu, /pfmeterreset): M.ResetPosition clears
   C.position and floats the window at M.HomeX/HomeY (three to a row); Float with no saved spot calls
   UpdateMovable(win, true) so pfUI's remembered default (posdata) is that spot - layout mode used to put a
   reset window back at its first, off-screen spot.
   Meters button (24 Oct, works in game; black panel gone): pfMeterToggle (movable, Shift+drag, layout mode; Ability_Marksmanship icon, grey
   when hidden): M.ToggleAll / ShowAll, C.meters.hidden kept over reloads, right-click = options,
   C.meters.togglebtn. The empty right chat was switched off once (C.meters.rightchatoff, pfUI.chat.
   SetupRightChat(false), ChatFrame3 Loot & Spam docked into the left chat).
17. Switches, map hiding, UI layouts (24 Oct 2026, NOT seen in game). User: "things like this should be
   simply able to be toggled on and off", the map hiding by itself in battlegrounds / raids with everything
   on it, and "RAID UI, NORMAL UI, PVPUI" with an on-screen button and optional automatic switching.
   - Page switches: O.ModuleSwitch(mod, what) (C.disabled[mod], pfUI.gui.settingChanged -> reload offered
     on close), O.KeySwitch(group, key, tip, after). On: Action bars, Gryphons, Buffs, Cast bars, Chat,
     Whispers, Gear sets, Slot buttons (live), Trinket queue (live), Meter windows (live show / hide),
     Threat (C.meters.threat), Minimap, Swing Timer, Unit frames (C.unitframes.disable). O.STANDIN: a page
     that needs its module (actionbar, swing, minimap, meters, gear) gets a stand-in page with the switch
     while that module is off (O:AddStandIns at first open).
   - modules/octo-context.lua: pfUI.context.Zone() bg | arena | raid | dungeon | world (battlefield status,
     IsInInstance + kind, else raid group), listeners on change (+ 2 s poll). C.mapauto[zone] = "1": the
     minimap frame hides, parts outside it (minimap-style PARTS, addon buttons) go alpha 0 + no mouse, put
     back with map.ApplyStyle; card "Hide by itself" on the Minimap page.
   - modules/octo-layouts.lua: pfUI.layouts, C.layouts { current, auto, button, byzone[zone], saved[name] =
     { pos = copy of C.position, meters, gear } }. Switch saves the current layout first, swaps C.position,
     UpdateMovable for every movable, meters ShowAll, optional gear set; waits for combat to end. Button
     pfLayoutButton (click = next, right-click = menu, Shift+drag), /layout [name]. Section "UI layouts"
     second in O.NAV.
   - Own spells per layout (24 Oct, user: "it moves the frames but my spells dont move"): saved[name].bars =
     L.ReadBars() (120 slots, { t = spell | item | macro, name, rank }; kind from ClassicAPI GetActionInfo when
     present - unverified - else GetActionText = macro, spellbook name = spell, else item; name / rank from the
     button tooltip via pfUI.keymap.ActionSpell). Switch writes them back (L.PutSlot: PickupSpell by name +
     rank / PickupMacro / bag or worn item, PlaceAction, ClearCursor; empty = PickupAction + ClearCursor;
     slots already right are left alone; not found -> kept, counted in chat). Per layout "its own spells"
     (ownbars, on by default).
18. Talent specs at the Goblin Brainwashing Device (25 Oct 2026, NOT seen in game). User: Brainwasher Pro
   (Fostercare5988, after Horyoshi; no licence stated) "implement this into our addon ... seamlessly work with
   our itemchanger ... match a set of gear to a spec ... resemble our UI". Written fresh; only the device's
   menu texts (read in play by its author) are taken: "Activate 1st Specialization  (31/20/0)", "Save 1st
   Specialization.", "Buy 4th Specialization tab for 200 gold.", "Reset my talents. (1g0s0c)".
   modules/gear-specs.lua (GR.specs = GS): GOSSIP_SHOW -> GS.Read(GS.Options()) (ClassicAPI C_GossipInfo
   GetOptions / SelectOption + flags when there - unverified; else GetGossipOptions pairs /
   SelectGossipOption(index)); window pfGearSpecs in the Octo palette (W.C): a row per slot - icon (click =
   activate / buy, right-click = GO.IconPicker), name + ACTIVE, split, gear set and UI layout W.MiniDrops,
   own-spells box, Name / Save; Reset talents, Gear sets, Options, Show original. GossipFrame is shrunk
   (alpha 0, scale .01) while it shows, as Brainwasher Pro did; x = CloseGossip, Escape = device menu back.
   Brainwasher Pro's frame is hidden if that addon is on too; its names / icons / splits copied once
   (C.gear.specimport). C.gear.specs["<slot>"] = { name, icon, t1-3, set, layout, ownbars, bars[layout] },
   C.gear.specnow. Switch: GS.Leave (the spec left keeps L.ReadBars() for the layout on now), option picked,
   then CHARACTER_POINTS_CHANGED / SPELLS_CHANGED settle 1.5 s (60 s timeout) -> GS.Apply: GR.Equip(set),
   L.Switch(layout) with L.holdBars, L.WriteBars(spec bars); layout / spells wait for combat. Layouts:
   while a spec with own spells is on, L.SaveCurrent / Switch keep bars in that spec (L.BarSpec) instead of
   the layout. Talents changed some other way that match exactly one spec apply it too (C.gear.specnotice).
   /gear specs, /specs = the window away from the device (links only). Page gearspecs "Talent specs".
   Seen in game 25 Oct: the device's own menu showed (most likely the new file needed a client restart - a
   /reload does not find new files) and the user reset / saved over a spec with no warning. Now: every choice
   asks first with what it does (GS.Question: activate / save "what it holds is lost" / reset with price /
   buy), never trusting the server's confirm flag (1.12 shows no box for it); the game's SelectGossipOption is
   wrapped (GS.rawSelect = the original) so the device's own menu asks too (C.gear.specconfirm). GS.Options
   uses ClassicAPI's list only when it reads as the device, else GetGossipOptions; /specs debug prints both.
   Window recoloured (user: "very dull"): class colour gradient top, a help line, each row striped and washed
   in its main tree's colour (GS.TREE), split numbers per tree colour, green Activate / gold Save here / red
   Reset buttons. UI layouts: your own (L.New / Rename / Delete, up to 12; C.layouts.list / icons / colors,
   L.NAMES follows the list; specs' layout and bars follow renames), layouts page = coloured tiles (click =
   switch, right-click = rename / picture / colour / delete, + New layout), a card per layout in its colour.
   O:Rebuild(key) builds an Octo page again (new layout / new spec).
19. One colour language (25 Oct 2026, NOT seen in game; user after the specs window: "keep it a rule Red for off
   green for on ... purple for multi choice ... keep it all the same ... highly prof", "more artwork"). In
   octo-options.lua (top), on top of octo-widgets so every Octo page follows: W.ROLE go/on green, danger/off red,
   pick purple, save gold, open blue; W.Tint(b, role) (b.PaintRole, kept on mouse up); W.RoleOf(words) via
   W.ROLEWORDS; W.Buttons rows tinted by d.role or their words (lit "on" buttons light green, W.Lit wrapped);
   W.Toggle off = red pill, W.Switch "OFF" red; W.CheckBox ticked = green; W.DropBox (every dropdown) purple edge
   and arrow; W.Card o.icon (false = none) else W.CardArt(title) from W.CARDART keywords (names checked in the
   client's listfile; W.Card's o.icon support came with the meter session's 25 Oct widget change). Spec
   window: rename boxes now select the old name (SetFocus + OnEditFocusGained HighlightText - typing used to
   append: "Spec 1Shadow PvE"; same fix in gear set and layout rename), buy row one line, help line wraps.
20. ClassicAPI update (25 Oct 2026, NOT seen in game; user: "I HAVE UPDATED CLASSIC API USE THIS WHEREEVER WE CAN").
   ClassicAPI.dll of 25 Oct 07:53: 364 "Usage:" strings; docs = brues-code/ClassicAPI docs/API.md (scratchpad
   capidocs). libclient gained ItemGUID(bag, slot | nil, inv) (C_Item.GetItemGUID {bagID, slotIndex} /
   {equipmentSlotIndex}), IsBound (C_Item.IsBound), LineOfSight (UnitInLineOfSight: true / false / nil), Copy
   (CopyToClipboard), SwingEvents (C_SwingTimer + C_EventUtils.IsEventValid "PLAYER_SWING"). Used by:
   - gear: picks / Snapshot keep .guid; Done / Find use the GUID first (GR.GUIDWhere, one bag look per GetTime,
     GR.ForgetWhere each Tick), then .full, then id; a GUID no longer anywhere is ignored. GR.Bound asks
     C_Item.IsBound before the tooltip scan. PLAYER_EQUIPMENT_CHANGED -> GR.Changed (instant slot bar).
   - swing: PLAYER_SWING (arg1 = seconds to the next swing, arg2 = 0 main / 1 off / 2 ranged) sets the bar's
     start so it ends then (a parried swing shortens it); s.cw / s.cwr make SuperWoW's MAINHAND / OFFHAND /
     shot casts and the log stand aside. PLAYER_SWING_RANGE_UPDATE (kind, inRange, checksRange) and
     C_SwingTimer.IsTargetWithinSwingRange on target change -> s.outMelee / outRanged dim the bars (x .4).
   - librange: in range but UnitInLineOfSight false = out of range (C.unitframes.losfade, Frames page box).
   - layouts: GetActionInfo's spell id kept (sid); PutSlot finds it with FindSpellBookSlotByID (player book).
   - share.lua: Export copies the string to the clipboard.
   Left for later / other sessions: COMBAT_LOG_EVENT_UNFILTERED + CombatLogGetCurrentEventInfo for the meters
   (meter session told), LOSS_OF_CONTROL_* / C_LossOfControl.GetSchoolLockout on action buttons,
   NAME_PLATE_UNIT_ADDED for plates, GetInventoryItemsForSlot for item menus, texture:SetRotation for map art,
   UNIT_SPELLCAST_* for cast bars, C_EquipmentSet (Blizzard-style sets saved in a file).
21. The ClassicAPI author's pfUI fork compared (25 Oct 2026, NOT seen in game). User's zip "pfUI-master (2)\pfui.zip"
   = brues-code/pfUI "6.0.0", ClassicAPI + nampower REQUIRED (API_Check.lua gate; ClassicAPI redirects a read of
   pfUI.toc to pfUI_ClassicAPI.toc / pfUI_Turtle.toc when those exist - never add files with those names here).
   Diffed against master (5.5.4); it rewrites most files for ClassicAPI only, so ideas were taken, not code.
   Brought over (each with the plain path kept):
   - unit frames: ClassicAPI frame:RegisterUnitEvent per frame (pfUI.uf.RegisterUnitEvents, re-pointed in
     UpdateVisibility; frames following a name keep plain events); health / power events refresh "base" only
     (pfUI rescanned every aura and the portrait on each tick; coming into / out of sight still does "all");
     heal prediction checked 20x a second (.predictAt, reset after a refresh); frames go quiet on PLAYER_LOGOUT
     (the fork's crash #132 guard).
   - nameplates: P.Calm - plates that are not the target, casting, moused over or animating (o.busy from P.Tick)
     redraw C.plates.calmfps (30) times a second, 60 = every frame (General > Smoothness card). Aura timer loop
     without a table per frame.
   - action bars: usable / cooldown / state passes skip hidden buttons (stale -> full update when they show,
     checked every .05 s). cooldown.lua: throttle first, cooldown frame kept (was a global name lookup per frame).
   - cast bars: idle bar set once (was every frame), timer text only when its tenth changes, red flash when your
     cast is interrupted / fails (SPELLCAST_INTERRUPTED / FAILED), nampower's queued spell icon right of the player
     bar (SPELL_QUEUE_EVENT, C.castbar.player.spellqueue, Cast bars page; libclient.SpellIcon).
   - focus: ClassicAPI's real focus unit - frames follow PLAYER_FOCUS_CHANGED (label "focus" / "focustarget"),
     /focus and /clearfocus call FocusUnit / ClearFocus (both /focus commands now agree); SuperWoW GUID focus and
     the name focus stay without it.
   - map reveal: C_Map.GetMapOverlays tiles (OctoWoW's own zones too) before pfUI's measured table; fixed the
     hover highlight (tiles were cached under the tooltip text) and stale tile caches.
   - sell greys: C_MerchantFrame.SellAllJunkItems (one call, paced in the client), loop as fallback.
   - tooltip: item counts bags / bank / worn (C.tooltip.itemcount; ClassicAPI counts the bank while shut, else
     bags + worn and the bank while open); health text only redrawn on change.
   - friend notes (socialmod.lua: "Note" in a friend's menu, shown on hover; ClassicAPI notes, else
     pfUI_cache.friendnotes); loot roll history window /loothistory /lh (loot.lua, C_LootHistory; at the top of
     the loot module so it runs in the mock); libunitscan reads NAME_PLATE_UNIT_ADDED units.
   - api.lua: GetItemLinkByName cached + 2 misses max + ids to 61000 (custom items), GetColorGradient NaN guard,
     LoadMovable point saved against the frame itself, autohide mouse check 20x a second.
   - also sped up (not from the fork): chat tab hover (FCF_DockUpdate ran every frame while hovering chat),
     minimap-style hover check, XP bar mouse check, libpredict housekeeping twice a second.
   Left out: the ClassicAPI-only gate, Turtle / stock table split and locale rewrite, its EquipmentManager and
   swing timer (Gear and swing.lua do more), libbagsort / C_NewItems / C_Container sort (bags session told, notes
   folder), event-driven plate rewrite (NAME_PLATE_CREATED instead of the WorldFrame count - that check is already
   cheap), raid frames at 10 fps (would delay health bars), libthrottle FPS menus (one Smoothness slider instead),
   libpredict heal guesses from ClassicAPI casts of non-HealComm healers, castbar tradeskill merge, mark tracker
   (markN tokens), macro icon picker, UnitXP behind indicator, BG score mover, Innervate call-out, reactive
   indicator (actionbar-octo has proc glows), /disenchantall, C_EncodingUtil profile strings (would change the
   string format), extra bar grid shapes (action bar session). Tests: tests\clientapi.lua (unit frame events,
   SpellIcon, loot history).
   Then (25 Oct; the user's friend: brues' pfUI was better only at "instant gear swap" and "instant bag sorting"):
   - gear.lua GR.Tick: with ClassicAPI (GR.Instant, C.gear.instant) every slot that may change goes in one
     cursor-free pass, C_Item.EquipItemByName({bagID, slotIndex} | {equipmentSlotIndex}, inv) on the copy GR.Find
     picks (GUID / full / id); q.sent waits 1 s for the server, 3 tries a slot, then the cursor queue. Taking off
     and combat / dead / casting waits stay on the queue. (brues' fork uses C_EquipmentSet.UseEquipmentSet with
     sets saved in ClassicAPI; ours stay ours.)
   - libs\libbagsort.lua (new file, full restart): pfUI.api.libbagsort:Sort("bags" | "bank"), :IsSorting(),
     .onDone. ClassicAPI: C_Container.SortBags / SortBankBags (the client sorts, special bags respected). Plain:
     Step() tops up stacks (SplitContainerItem), then swaps the first wrong slot (hearthstone, gear by slot,
     type / subtype / name, greys from the end), one move per .05 s after locks clear, 30 s / 500 moves cap;
     normal bags only. Sort button via pfUI.thirdparty.RegisterBagSort when no sort addon took it. The bags
     session's window calls the same Sort.
22. Bagnon-style bags (25 Oct 2026, NOT seen in game; user: "we need a addon building in like Bagnon", Bagnon 12.1.7
   zip - All Rights Reserved, so feature list only, written fresh, no art). Picked by the user: the core window only
   (not item glow, other characters / tooltip counts, auto open). modules/bags-octo.lua (`pfUI.bagsOcto` = BO) wraps
   pfUI.bag:CreateBags / UpdateSlot / ReanchorAdditions (bags.lua untouched: its slots, cooldowns, locks, search
   and small buttons stay) and lays both windows out again: BO.Metrics(which, sizes) = the measures (title bar,
   search, bag bar, grid, footer) used by the real windows and the options preview; BO.Places(order, sizes, cols,
   hidden, brk, rev) = slot grid. Title bar = class / accent / own colour wash (SetGradientAlpha only), name,
   pfUI's buttons re-chained into it (close, bag bar arrow, libbagsort's sort, keys, open, pick lock,
   disenchant); drag title or body to move (C.bagsocto bagsx/bagsy = bottom-right, bankx/banky = top-left, in
   UIParent units), right-click title = options. Bag bar: a button per bag (keyring last; bank -1, 5-10): click =
   show / hide its slots (C.bagsocto.hidden "2,5"; keyring = pfUI.bag.showKeyring), item on cursor = put in bag,
   drag = PickupBagFromSlot, red edge = hidden / not bought (click at the banker buys the next). Footer: free / all
   (ClassicAPI C_Container.GetContainerNumFreeSlots for bags 0-4, else counted) and money; refreshed on
   BAG_UPDATE_DELAYED when C_EventUtils says it is valid, else BAG_UPDATE throttled .1 s. Off = needs a reload.
   modules/bags-options.lua: page "Bags" (bagsocto, section "Bags" first under "Bags & Loot"): switch, pinned
   preview (your items, or samples; click its bags), Open / Sort / Reset positions, cards Window, What it shows,
   Slot order, Which bags, Title bar colour. Tests: tests\bags.lua. New files: needs a full client restart.
   Item marks (26 Oct 2026, NOT seen in game; user: "quest / junk / unusable marks and a new-item glow with ClassicAPI
   C_NewItems"): BO.Marks(bag, slot) -> BO.Mark paints parts made once per slot (BO.MarkParts: top frame, ADD glow
   UI-ActionButton-Border pulsing via BO.Pulse on the watch frame, coin top-left for grey, quest ? / starts-quest !
   top-right (pfUI's own "?" text cleared), red tint from ClassicAPI C_PlayerInfo.CanUseItem when present - pfUI's
   unusable.lua tooltip scan stays the fallback, its switch C.appearance.bags.unusable). New: C_NewItems.IsNewItem /
   RemoveNewItem (mouse over, wrapped slot OnEnter) / ClearAll (bag window closes, C.bagsocto.newclear),
   BAG_NEW_ITEMS_UPDATED; without ClassicAPI BO.ScanNew: an item id owned now (bags 0-4 + worn + bank as last seen
   open) that was not owned at the last look, ignored for 4 s after login. Starts-quest = libtipscan Find
   ITEM_STARTS_QUEST, cached per item string. Card "Item marks"; the preview's samples show each mark.
21. UI layouts keep EVERY setting (25 Oct 2026, NOT seen in game; user: "every setting you have chosen should be saved
   inside that UI layout ... ANY MENU SELECTION ANYTHING", after meters did not follow a layout). octo-layouts.lua:
   saved[name].cfg = L.CfgCopy() (pfUI_config minus L.SHARED: layouts, position (kept as .pos), gear, version);
   L.Switch -> L.ApplyCfg(target.cfg): changed top-level parts are filled into the live pfUI_config IN PLACE (modules
   hold handles on sub-tables; keys missing from an older copy keep their value), then L.LIVE[part]() shows them
   (unitframes UF.ApplyAll, bars UpdateConfig, meters RestyleAll, plates Refresh, castbar CB.Apply, swing ApplyLayout,
   mapstyle ApplyStyle, bagsocto Refresh, abuttons, blizz BZ.Set per C.blizz); a changed part with no live apply (or
   a different meter window count) -> "Reload now?" question, never an automatic reload. A layout saved before this
   has no cfg and takes the settings on now. L.FIXED buttons (gear set, meters, layout) keep one place in all layouts.
23. brues-code's pfUI fork, second look (28 Oct 2026; user's "pfUI-master (3).zip" vs the (2) copy of roadmap 21;
   the fork keeps Shagu's MIT licence). Taken: nine CreateTexture(layer) calls fixed, api/unitframes.lua AuraClock
   (talent-lengthened auras: time left > duration put the start in the future -> 2^32 text), cooldown sweeps on
   player buffs (buff.lua: buff.cd + buff.overlay for the texts; length = time left when first seen or renewed,
   C.buffs.cooldown_anim), sweep direction per kind (cd.pfCooldownReverse; cooldown.lua calls SetReverse only when
   the frame has it = ClassicAPI's cooldown frames; C.buffs / bars / totems / appearance.bags .cooldown_reverse,
   C.unitframes[unit].cooldown_reverse, C.nameplates.debreverse), cooldown numbers resize when their button's
   height changes (pfCooldownFont). Stable skin left alone (its `button` is a fresh local per loop pass).
   Heal prediction (user: "MUST SHOW ALL HEALS IN ALL FRAMES"): libpredict read ClassicAPI's UNIT_SPELLCAST_SENT
   arg4 (spell id) as the target's name on 1.12 - own heals went to a "player" called 10917; now arg2 (unit token).
   New block at the end of libs\libpredict.lua: other players' heal casts from ClassicAPI (UNIT_SPELLCAST_* of every
   unit, deduped by cast GUID, UnitSpellTargetName, C_Spell.UnitCastingInfo) or SuperWoW UNIT_CASTEVENT; sizes from
   that healer's last heal (combat log SPELL_HEAL / chat HEALED*OTHER* lines, crits / 1.5), anyone's, else the
   spell's "for X to Y" text (C_Spell.GetSpellDescription or the own spell book's tooltip, libpredict:Guess, also
   for the first own cast). Incoming bar sized from hp.bar's real width. Not seen in game.
24. Calmer options pages, ideas from EllesmereUI (8 Nov 2026, NOT seen in game; user sent its options window: "I
   really like the clean look ... make ours less overwhelming and organised better"; a Discord player called ours
   "overwhelming" but likes the previews). EllesmereUI's licence reserves rights: ideas only, no code or art.
   Plan in the shared notes (ellesmere-borrow-plan.md): B = shared widgets (done), A = shell (sidebar groups with
   power icons, page tabs, footer Reload / Close, flags into one dropdown) - waits for the user's word.
   octo-widgets.lua: W.Card = small grey capitals label (W.Caps keeps |c / |r codes), 8 px fold arrow, 14 px icon,
   a thin line to the right (stops before the card's switch), the rows on one soft panel under it (c.panel, hidden
   while folded); no head bar. W.Pin the same (its "stays here" note moved into the tooltip). Rows (SettingRow,
   ROW = 28): label left, control right, a faint line under each, the label area lights and shows the tooltip
   (RowHit). W.Check = W.CheckPill (a CheckButton drawn as a pill, green / red-grey; SetChecked repaints) on the
   right, the whole label toggles; W.Slider = slider + boxed number on the label's line (one line, was two);
   W.Dropdown box right (130-190 wide); W.Color swatch right, the label picks. A label too long for half a row
   takes the whole row. octo-options.lua W.Tiles(p, { { title, hint, icon, fn, role } }) = action tiles (role
   wash); Settings > Scale, profiles and look starts with Move frames / Key Map / Run setup again tiles.
   Skipped: folding W.Note text into an "i" (only 14 notes in all the pages). pfUI's own CreateConfig pages
   (O.SkinPage) are unchanged.
   Shell (A, same day, NOT seen in game; user: "Yes, build A now"). octo-options.lua: NAV_W 210; the quick bar and
   the eight top flags are gone. Sidebar (full height): "pfUI Octo" + version (O:BuildSideTop), big entries Move
   Frames / Keybinds (menu) / Profiles / Install, then from NAV_TOP the sections under small capitals headings
   (O.NAVGROUPS, in O.NAV's order: General, Interface, Combat & Items, More; grp.headFrame). Sections no longer
   unfold: a click opens the page last seen there (grp.lastKey) or the first; the open one = wash + accent edge.
   Power dot right of a section (O:PowerFor, made lazily in LayoutNav): BZ.GROUPS sections = green while any part
   is pfUI Octo's, click flips the whole section to the game's frames and back (no reload); Gear = its module via
   O.ModuleSwitch (reload). The topic buttons (grp.buttons, O.nav[key]) are now text tabs in O.tabRow
   (O:LayoutTabs wraps to more lines; picked = white + accent underline), Find (O.quickFind) right of them. The
   window's f.title / f.version = the section's name (22 px) and its line (O.SUBTITLE). Footer (O:BuildFooter,
   O.quick): Reload UI (gold while g.settingChanged), Background slider, language button (flag + name, menu ->
   O.SetLanguage), Close. Content sits between tabs (+ the Octo / Blizzard strip) and footer (LayoutSwap).
   Seen in game 8 Nov; user: the sidebar scrolled ("ALL SHOULD SHOW ALWAYS", scaled to the window), our own
   features belong in the sidebar not in tabs, tabs "don't stand out", pinned cast bar preview dark. Now: Combat
   split into Combat Text / Meters / Swing Timer sections and Auto Loot out of Bags & Loot (O.NAV; BZ.GROUPS
   gained "Combat Text" / "Meters"); LayoutNav sizes rows to the sidebar's height (15-26 px, headings 20 or 15,
   test at 560 px); tabs are 30 px buttons (lit panel, 14 px words; open = accent fill + edge + 3 px line); card
   and pin panels are textures on the card itself (W.Panel) - as a child frame the pin's panel lay over the
   preview at .85 and darkened it.
   W.LongMenu (8 Nov; user: after scrolling a click "just picks any"): a row click took focus from the filter
   box, box.OnFocus ran Filter, which reset the scroll to the top before OnClick - the row then held another
   option. Filter now only rebuilds when the text changed (Filter(true) on show); test in run.lua.
   Sidebar again (8 Nov, user screenshot: 15 px rows, list still scrolled, half the column empty): in game
   navFrame:GetHeight() reported far less than its anchored height. LayoutNav now uses the window's height - 24
   (we set it) and lets rows grow to 32 px so the list fills the column; tests at 740 and 600 with a wrong 120.
   EllesmereUI look, second pass (8 Nov, NOT seen in game; user via the top session: "how open it is, colour
   matching how the header and side columns work together ... selected with an underline ... CENTERED ... IN
   LINE"). Window, header, sidebar and footer = one tone (K.panel; nav / footer backdrops clear, ApplyAlpha), the
   page = darker well (K.bg); thin accent lines (.45) down the sidebar's edge and under the tabs. Title 28 px +
   12 px grey line, TAB_TOP 74; top right: Window Scale slider + % (applies on mouse up, follows ApplyScale) and
   a 26 px X. Tabs = plain 15 px words, grey; open = white + 3 px accent underline on the accent line (they were
   lit buttons an hour before; the user then pointed at the underline). Sidebar: 24 px name + "your whole
   interface", version at its foot, accent capitals headings, sections indented 14. Rows 32 px; every slider 120
   (+ number box) and every dropdown 180 wide, right edges -4, so controls share one column; labels over 172 px
   take the whole row. Footer: Reload UI 120 left, Close 120 right, Background + language centred.
