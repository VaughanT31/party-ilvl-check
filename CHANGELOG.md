# Changelog

## 1.5.0

- **Faster with friends:** when others in your group also run Party iLvl Check, they send you their own item level, spec, tier pieces and enchant and gem check straight away, so they don't need inspecting at all. Anyone one of you inspects is shared with the rest, so in a raid the group splits the inspecting instead of everyone inspecting all twenty. Hover a player's gear icon to see where their data came from.
- Shared data is only used for people in your group, nobody can send data for someone else, and your own inspect results are never replaced. Nothing is sent during boss encounters or Mythic+ runs.
- **See who has it:** a small Party iLvl Check icon follows the names of everyone in your group who has the addon (and yours), and the top of the window says how many of you have it.
- The window is a little wider, so the item level on the right has room. Name, score and spec no longer run under the buff icons; the best run in this dungeon now sits on the spec line.
- **Well Fed fixed:** food buffs now count whatever they're called, including *Hearty Well Fed* and plain *Well Fed*.
- **Test M+ and Test Raid:** Test Mode is now two buttons that work like radio buttons. *Test M+* shows a made-up five-player group and *Test Raid* a made-up raid in raid mode. Click the ticked one again to leave test mode.
- **Resizable window:** drag the grip in the bottom-right corner to make the window smaller or bigger (50% to 200%), or type `/ilvlcheck scale 0.8`. `/ilvlcheck scale reset` brings back the normal size. The size is remembered.

## 1.4.1

- **Scans don't get stuck in raids:** people standing right next to you could stay on "Scanning..." or "Not inspectable". A roster change (someone joining, zoning or being moved) started the whole scan again, so the people at the end of the list were never reached. Now people already scanned keep their result and only the rest are scanned.
- **Failed inspects are tried again:** when the game doesn't answer (often because another addon inspected someone at the same time) or their gear hasn't loaded yet, Party iLvl Check tries again a moment later, up to 3 times, and then every 20 seconds while the window is open.
- Scanning no longer empties Blizzard's inspect window when you have it open.

## 1.4.0

- **Their best run in this dungeon:** each row shows the player's best key in the dungeon you're in, green when timed, orange when over time, or "none here". Outside a dungeon it uses your own keystone's dungeon, named at the top of the window.
- **Group utility bar:** interrupts, magic, curse, poison and disease dispels, battle res and Bloodlust for the whole group at a glance. Hover an icon for who brings it.
- **Everyone's keys:** the group bar counts the keystones in your group; hover for each player's key. Your own always shows; other players' show when an addon that shares keys (like BigWigs) is installed.
- **Tier set count** in the gear icon's tooltip.
- **Post button:** a short summary of the group check to party or instance chat (`/ilvlcheck post` works too).
- **Raid mode:** in a raid group the window lists everyone as compact rows in a scrolling list, with item level, spec, the buff and gear icons and the group utility bar. Open it with `/ilvlcheck` or the minimap button; it doesn't pop up by itself in raids. `/ilvlcheck testraid` shows a made-up raid.
- **Group finder applicants:** when you list a Mythic+ key, each applicant's row shows their best run in your dungeon, and their item level turns orange when it's under your Min iLvl.

## 1.3.0

- **Enchant and gem check:** a new icon in each player's strip flags missing enchants and empty sockets. Hover it to see which slots.
- **Out of range players are checked again** automatically once they come close.
- **Weapon oil check** for your own weapon. Other players' weapon oils aren't shared by the game, so their slot stays blank.

## 1.2.0

- Raid buff, food and flask checks per player.
- *Hearty* (the reduced buff from someone else's feast) counts as Well Fed.
- Minimum item level with raid warning alerts, summary tiles, Scan iLvl chat output, Test Mode and a minimap button.
