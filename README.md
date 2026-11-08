<p align="center"><img src="docs/banner.png" alt="pfUI Octo by Bdot89" width="100%"></p>

# 🐙 pfUI Octo for OctoWoW

**Your whole interface. One addon.** ✨

> [!CAUTION]
> ## 📁 THE FOLDER MUST BE CALLED `pfUI` - NOTHING ELSE!
> If your folder is called **`pfUI-Octo`**, **`pfUI-octo`**, **`pfUI-Octo-octo`** or **`pfUI-master`**, **DELETE the `-Octo` / `-octo` / `-master` part on the end** so it reads exactly **`pfUI`**.
> ✅ `Interface\AddOns\pfUI` &nbsp;&nbsp; ❌ `Interface\AddOns\pfUI-Octo-octo`
> With the wrong name the game won't load it (OctoLauncher says "Missing .toc file").

> ## 🔌 One-click DLL installer: always the newest versions!
> **It's in the ZIP.** After unzipping, double-click **`Install pfUI Octo DLLs.bat`** in the pfUI folder (game closed). Every time you run it, it fetches the **latest releases** of **ClassicAPI, SuperWoW, nampower and UnitXP_SP3** straight from their authors' GitHub, installs what's missing and updates what's out of date. 🚀
> Run it again any time to stay current. It backs up the old DLLs, adds them to `dlls.txt` for you, and never swaps a newer build you already have for an older one.

**pfUI Octo** is a free all-in-one interface for WoW 1.12 (OctoWoW), **version 1.0.0**, made by **Bdot89**: unit frames, action bars, nameplates, meters, threat, combat text, a swing timer, gear sets, a key map and whole UI layouts, all set up from **one options window** with a live preview on every page. 🎛️

> 🧩 **Built on [pfUI](https://github.com/shagu/pfUI) by Shagu:** pfQuest, Clickcast, your profiles and your settings all keep working.

**[⬇️ Download pfUI Octo (ZIP)](https://github.com/bdot89/pfUI-Octo/releases/latest/download/pfUI.zip)** · **[🌐 Web page with screenshots](https://bdot89.github.io/pfUI-Octo/)** · **[📜 What's new](https://github.com/bdot89/pfUI-Octo/releases)** · 💬 Discord: **benito9295**

## 🛠️ Install in 4 steps

1. **Close the game.** Addons and DLLs are only read when the game starts.
2. **Unzip into AddOns.** [Download pfUI.zip](https://github.com/bdot89/pfUI-Octo/releases/latest/download/pfUI.zip), right-click it, **Extract All**, and put the **pfUI** folder in `OctoWoW\Interface\AddOns`. Replace an old pfUI folder: your settings stay.
   > 🚀 **Or let OctoLauncher do it (and keep it updated):** in OctoLauncher open **Addons**, click **Add custom git addon** and paste `https://github.com/bdot89/pfUI` (that copy is named pfUI so the folder comes out right). **Check for updates** then updates it with one click.
   >
   > ❗ **Remove your old pfUI first** (in OctoLauncher's **Addons** list, or delete the `Interface\AddOns\pfUI` folder; your settings live in `WTF` and stay). OctoLauncher's own list has a different pfUI under the same name. It "updates" any pfUI folder that isn't a git copy of ours (an old pfUI, or pfUI Octo from the ZIP) to that one. So don't press **Update** on a ZIP install: remove it and add the link above instead.

   > ⚠️ The folder must be called exactly **pfUI**. Used GitHub's green **Code → Download ZIP** instead? That folder is called **pfUI-Octo-octo**: rename it to **pfUI** (else OctoLauncher says "Missing .toc file" and the game won't load it).
3. **Run the DLL installer** *(optional)*. In that pfUI folder, double-click **Install pfUI Octo DLLs.bat**. "Windows protected your PC": **More info**, then **Run anyway**.
4. **Play!** 🎮 Start the game from **OctoLauncher**. A short setup wizard picks your look and layout. `/pfui` opens the options, `/moveui` moves frames.

## 🌟 What you get

| | |
|---|---|
| 🗺️ **UI layouts** | Normal, Raid, PvP or your own, each with its own frames, meters, gear and spells; switches by itself by zone |
| 🧍 **Unit frames** | Player to raid, with fading health, combat flash, class icons, elite marks, dispel colours, buff timers |
| ⚔️ **Action bars** | 14 button looks, proc glows, cooldown swipes, hover and press effects, fading, end-cap art |
| 🎯 **Nameplates** | Plater-style: 8 looks, auras, cast bars, threat colours, quest marks, range fading, your own rules |
| 📊 **Meters & threat** | Up to 6 windows, full breakdowns of every spell, target and death; a pull warning on your target |
| 💥 **Combat text** | Five areas you place yourself, with looks, crits, sounds and alerts |
| ⏱️ **Swing timer** | Main hand, off hand and ranged, parry haste, queued attacks, Slam and Seal-twist marks |
| 🛡️ **Gear** | Instant set swaps, a trinket queue, slot buttons, automatic swaps, talent specs at the Brainwashing Device |
| ⌨️ **Key Map** | Your keyboard on screen: drag any spell, item or macro onto a key, pick the rank, see every layer |
| 🎒 **Bags, chat, minimap** | Instant sorting, new-item glows, chat with class colours, a SexyMap-style minimap, loot roll history |
| 🧭 **Layout mode** | Drag and snap frames, mirrored guide lines, match sizes, lock frames together, hide what you don't need |
| 🔁 **Octo or Blizzard** | A switch on every page: back to Blizzard's frames for that part at once, no reload |

## 📸 Screenshots

<img src="docs/keymap.jpg" alt="Key Map" width="100%">

**⌨️ Key Map:** your whole keyboard on screen with the mouse buttons and wheel. **Spell book** lists every spell you know (click one, pick its rank, click a key, or drag it onto a key), **Unbound** the spells on your bars with no key, **All bindings** the game's whole list. Shift / Ctrl / Alt show each layer.

| | | |
|---|---|---|
| <img src="docs/layouts.jpg" alt="UI layouts"><br>🗺️ **UI layouts**: one click to switch | <img src="docs/unitframes.jpg" alt="Unit frames"><br>🧍 **Unit frames**: click any part to change it | <img src="docs/actionbars.jpg" alt="Action bars"><br>⚔️ **Action bars**: 14 looks, every effect |
| <img src="docs/nameplates.jpg" alt="Nameplates"><br>🎯 **Nameplates**: four live sample plates | <img src="docs/meters.jpg" alt="Meters"><br>📊 **Meters**: a test fight to style them | <img src="docs/combattext.jpg" alt="Combat text"><br>💥 **Combat text**: drag the areas |
| <img src="docs/gear.jpg" alt="Gear sets"><br>🛡️ **Gear sets**: like the character window | <img src="docs/trinkets.jpg" alt="Trinket queue"><br>💍 **Trinket queue**: the next ready one goes on | <img src="docs/specs.jpg" alt="Talent specs"><br>🧠 **Talent specs**: gear, layout and spells per spec |
| <img src="docs/autoswap.jpg" alt="Automatic swaps"><br>🔄 **Automatic swaps**: mount, swim, battleground... | <img src="docs/swing.jpg" alt="Swing timer"><br>⏱️ **Swing timer**: with Slam and twist marks | <img src="docs/slots.jpg" alt="Slot buttons"><br>🎚️ **Slot buttons**: use or swap any slot |
| <img src="docs/chat.jpg" alt="Chat"><br>💬 **Chat**: timestamps and class colours | <img src="docs/minimap.jpg" alt="Minimap"><br>🧭 **Minimap**: shapes, art, a clock | <img src="docs/bags.jpg" alt="Bags"><br>🎒 **Bags**: one window, one-click sorting |

## ⚡ The DLLs: what they add

All optional: pfUI Octo works without them, and nobody loses a feature. The installer gets all four, or tick **nampower** and **unitXp** in OctoLauncher's mod list.

| DLL | What it adds |
|---|---|
| 🧬 **ClassicAPI** | Instant gear swaps and bag sorting, a real focus, "can't interrupt" cast bars, the combat log for meters, map reveal for OctoWoW's zones, item counts, loot history |
| 🦸 **SuperWoW** | Focus by GUID, `/pfcast` mouseover casting, enemy cast bars, real casts for the swing timer and meters |
| 🚀 **nampower** | Your queued spell on the cast bar, spell casts for combat text and meters |
| 📏 **UnitXP_SP3** | Exact distances and line of sight for range fading on plates and frames |

## ⌨️ Commands

| | |
|---|---|
| `/pfui` | the options window |
| `/moveui` | layout mode: move, size, snap, hide |
| `/layout [name]` | next UI layout, or the one you name |
| `/gear` | gear sets (`naked`, `queue`, `specs`) |
| `/keymap` | the Key Map |
| `/sct` | combat text pages |
| `/loothistory` | who rolled what (ClassicAPI) |
| `/export`, `/import` | share your whole setup |

---

Made with 💙 for the OctoWoW community by **Bdot89** · Discord: **benito9295**
Based on [pfUI](https://github.com/shagu/pfUI) by Shagu (MIT licence). Made for the OctoWoW 1.12.1 client. Not affiliated with Blizzard Entertainment.
