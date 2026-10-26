# Party iLvl Check

A World of Warcraft addon that shows your party's item levels, Mythic+ scores, buffs and gear checks the moment you zone into a dungeon.

**New here?** The [wiki](wiki/Home.md) explains every feature step by step (also on the [website](https://ctrlshiftzed.com/wiki/party-ilvl-check/)). Questions it doesn't answer: ask on [Discord](https://discord.gg/wz7fw6jM9Z).

- **Game:** Retail, Midnight (12.x)
- **Interface:** `120100`
- **CurseForge:** [Party iLvl Check](https://www.curseforge.com/wow/addons/party-item-level-checker)

## What it does

**Pops up in dungeons.** Enter a 5-player instance and the window opens and inspects everyone in your group. It stays hidden once a Mythic+ keystone timer is running, so it never gets in the way of a key.

**One row per player** with:

- item level, and how far over or under your minimum it is
- Mythic+ score, in the game's own score colours
- spec and role
- a status while it works: *Scanning...*, *Offline* or *Out of range*

Players who were out of range are checked again automatically once they come close, no need to rescan by hand.

**Best run in this dungeon.** Each row shows that player's best key in the current dungeon (`+14 here`, green when timed, orange when over time, or `none here`). Outside a dungeon it uses the dungeon of your own keystone.

**Group utility bar.** Above the rows: interrupts, magic, curse, poison and disease dispels, battle res and Bloodlust for the whole group, green when covered, amber for a single interrupt, red when missing. Hover for who brings it. Based on class and spec (`ilvlcheck/Modules/Utility.lua`), so talents can change it.

**Keystones.** The right end of the group bar counts the group's keys; hover it for each player's key, highest first. Your own key comes from the game. Other players' keys come from LibKeystone when another addon (BigWigs and others) has loaded it; Party iLvl Check doesn't bundle it.

**Tier set and Post.** The gear icon's tooltip shows each player's tier set pieces. *Post* sends a short summary (item levels, best runs here, missing utility, keys) to party or instance chat, or prints it for you when you're alone or in Test Mode.

**Sharing (1.5).** Group members who also run Party iLvl Check send their own item level, spec and gear check, and share anyone they inspect, so the window fills in much faster, especially in raids. Shared data is only used for people in your group and never replaces your own inspects; nothing is sent during encounters or Mythic+.

**Raid mode.** In a raid group the window shows everyone as compact rows in a scrolling list. It doesn't open by itself in raids; use `/ilvlcheck` or the minimap button. `/ilvlcheck testraid` shows a made-up raid.

**Group finder applicants.** When you list a Mythic+ key, each applicant row shows their best run in your dungeon, and item levels under your Min iLvl turn orange.

**Buff strip.** Each row has a ring of icons, green when active and red when missing. Hover one to see which it is.

| Icon | Checks |
|---|---|
| Class buffs | Mark of the Wild, Battle Shout, Arcane Intellect, Power Word: Fortitude, Blessing of the Bronze, Skyfury |
| Well Fed | Any Midnight food or feast, including the reduced *Hearty* buff from someone else's feast |
| Flask | Midnight flasks |
| Weapon Oil | Oils and whetstones on your weapon. Only shown for you, because the game doesn't share other players' weapon enchants |
| Enchants & Gems | Missing enchants and empty sockets on everyone's gear. Hover it to see which slots |

**Minimum item level.** Type a number into *Min iLvl* and anyone under it gets flagged with a raid warning and a sound. The summary tiles at the top count who is ready, who is below your minimum and who is offline.

**Scan iLvl** prints each player's item level and score to chat as they are inspected.

**Test M+** and **Test Raid** fill the window with a made-up five-player group or a made-up raid, so you can see how it looks outside a dungeon. Only one can be on at a time; click the ticked one again to turn it off.

**Minimap button** opens the window. Drag it to move it around the minimap.

## Commands

| Command | What it does |
|---|---|
| `/ilvlcheck` | Open or close the window |
| `/ilvlcheck post` | Post the group summary to chat |
| `/ilvlcheck testraid` | Show a made-up raid in raid mode |
| `/ilvlcheck scale 0.8` | Window size, 0.5 to 2 (`scale reset` for normal); or drag the bottom-right corner |

## Install

- **CurseForge app:** search for *Party iLvl Check* and click Install.
- **Manual:** download the zip from CurseForge or the GitHub releases and drop the `ilvlcheck` folder into `World of Warcraft/_retail_/Interface/AddOns`. Restart the game or type `/reload`.

## Keeping the lists current

Class buffs are matched by spell ID, which doesn't change between patches. Food and flasks are matched by buff name, because those items change every expansion and season. The lists live in `ilvlcheck/Modules/Core.lua` (`ns.BUFF_DEFINITIONS`); update the `names` lists when new food or flasks come out.

## Building a release

```powershell
powershell -ExecutionPolicy Bypass -File package.ps1
```

This builds `.releases\ilvlcheck-v<version>.zip` from the version in `ilvlcheck.toc`, ready to upload to CurseForge.

## Bugs and ideas

Open an [issue](https://github.com/VaughanT31/party-ilvl-check/issues). For a bug, the addon version, what you did and any Lua error text (`/console scriptErrors 1`, or BugSack) helps a lot.

## License

[MIT](LICENSE)
