## XiaoMount - WoW: Forever Edition

XiaoMount swaps in your best mount speed gear when you mount, your best swim speed gear when you swim and your best stealth gear when you stealth, then puts your original gear back afterwards. No configuration needed.

The TurtleWoW version lives on the [`turtle`](https://github.com/Kmschr/XiaoMount/tree/turtle) branch. For Classic WoW see https://www.curseforge.com/wow/addons/xiaomount

## How it finds gear

WoW: Forever has its own items, so XiaoMount reads item tooltips instead of keeping a list of item IDs:

- **Mount speed**: "Increases mount speed by X%" on any armor, ring or trinket, plus the Mithril Spurs and Riding Skill glove enchants
- **Swim speed**: "Increases swim speed by X%", and water breathing / longer breath items (helms, Gill's Gills)
- **Stealth**: "Increases your effective stealth level" (or "Stealth +X"), worn while stealthed (Rogue Stealth, Druid Prowl). Gear can't change in combat, so after opening from stealth you fight in it until combat ends; `/xm stealth` turns this off
- **Zone-limited bonuses** such as The Desert Rose ("... in Desert areas") are only used when nothing better is available
- **Outrider's Gloves** (5%, does not stack with other mount speed) are worn on their own unless your other mount speed items add up to more than 5%

The game doesn't allow armor swaps in combat, so gear changes wait until combat ends (also while dead, casting or holding an item on the cursor). Your original gear is remembered across reloads and put back as soon as it's allowed.

## Commands

```
/xm        - status
/xm on     - enable auto-equipping
/xm off    - disable and put your original gear back
/xm stealth - toggle stealth gear
/xm scan   - list the mount, swim and stealth items XiaoMount found, with their scores
```

If `/xm scan` misses one of your items, open an issue with its tooltip text.

## Tests

The gear rules (`Logic.lua`) run offline:

```
lua5.1 tests/logic.lua
```

Build the CurseForge zip (`dist/XiaoMount-<version>.zip`):

```
tools/package.sh
```

## Updates

- (2.1.1) Gill's Gills and other longer-breath items recognized
- (2.1.0) Stealth gear while stealthed, `/xm stealth` toggle
- (2.0.1) Gear reliably goes back after dismounting in combat (retried until it's back in place)
- (2.0.0) WoW: Forever rewrite: tooltip-based gear detection, Forever swimming detection, Outrider's Gloves, `/xm on|off|scan`. TurtleWoW version moved to the `turtle` branch
