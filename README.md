## XiaoMount - WoW: Forever Edition

XiaoMount swaps in your best mount speed gear when you mount and your best swim speed gear when you swim, then puts your original gear back when you dismount or leave the water. No configuration needed.

The TurtleWoW version lives on the [`turtle`](https://github.com/Kmschr/XiaoMount/tree/turtle) branch. For Classic WoW see https://www.curseforge.com/wow/addons/xiaomount

## How it finds gear

WoW: Forever has its own items, so XiaoMount reads item tooltips instead of keeping a list of item IDs:

- **Mount speed**: "Increases mount speed by X%" on any armor, ring or trinket, plus the Mithril Spurs and Riding Skill glove enchants
- **Swim speed**: "Increases swim speed by X%", and water breathing items (helms)
- **Zone-limited bonuses** such as The Desert Rose ("... in Desert areas") are only used when nothing better is available
- **Outrider's Gloves** (5%, does not stack with other mount speed) are worn on their own unless your other mount speed items add up to more than 5%

It never swaps gear in combat, while dead, while casting or with an item on the cursor, and remembers your original gear across reloads.

## Commands

```
/xm        - status
/xm on     - enable auto-equipping
/xm off    - disable and put your original gear back
/xm scan   - list the mount and swim items XiaoMount found, with their scores
```

If `/xm scan` misses one of your items, open an issue with its tooltip text.

## Tests

The gear rules (`Logic.lua`) run offline:

```
lua5.1 tests/logic.lua
```

## Updates

- (2.0.0) WoW: Forever rewrite: tooltip-based gear detection, Forever swimming detection, Outrider's Gloves, `/xm on|off|scan`. TurtleWoW version moved to the `turtle` branch
