# Reading the window

*What each player's row shows, the summary tiles and the minimum item level.*

### One row per player

- **Item level**, and how far over or under your minimum it is.
- **Mythic+ score**, in the game's own score colours.
- **Spec and role.**
- **Best run in this dungeon**, for example `+14 here`: green when timed, orange when over time, or `none here`. Outside a dungeon it uses your own keystone's dungeon, named at the top of the window.
- **A status while it works:** *Scanning...*, *Offline* or *Out of range*.

Players who were out of range are checked again by themselves once they come close. Inspects that fail (often because another addon inspected at the same moment) are tried again a few times, then every 20 seconds while the window is open.

### Minimum item level

Type a number into **Min iLvl**. Anyone under it is flagged with a raid warning and a sound.

### Summary tiles

The tiles at the top count who is **ready**, who is **below your minimum** and who is **offline**.

### Scan iLvl and Post

- **Scan iLvl** prints each player's item level and score to chat as they're inspected.
- **Post** sends a short summary to party or instance chat: item levels, best runs here, missing utility and keys. Alone or in Test Mode it's printed just for you. `/ilvlcheck post` does the same.

### Ran with before

Every Mythic+ key you finish is remembered on your own computer. A player you've run with shows it on their row, such as *2 timed, 1 over*. List a key and applicants you know show *ran 3x*, with the split and the last date in their tooltip.

- `/ilvlcheck runs` shows your latest runs and how many are kept
- `/ilvlcheck runs min 10` only remembers keys from +10 up
- `/ilvlcheck runs max 500` changes how many are kept (1000 to start with, oldest dropped first)
- `/ilvlcheck runs clear` forgets everything

---

Previous: [Getting started](Getting-started.md) | [Wiki home](Home.md) | Next: [Group utility and keys](Group-utility-and-keys.md)

Didn't find your answer? Ask in the [CtrlShiftZed Discord](https://discord.gg/wz7fw6jM9Z).
