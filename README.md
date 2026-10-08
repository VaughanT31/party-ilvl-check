# Party iLvl Check

A World of Warcraft addon that shows your party's item levels, Mythic+ scores, buffs and gear checks the moment you zone into a dungeon.

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

**Test Mode** fills the window with a made-up group, so you can see how it looks outside a dungeon.

**Minimap button** opens the window. Drag it to move it around the minimap.

## Commands

| Command | What it does |
|---|---|
| `/ilvlcheck` | Open or close the window |

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
