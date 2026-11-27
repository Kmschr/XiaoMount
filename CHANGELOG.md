# Changelog

## 2.1.1

- Longer underwater breath items (Gill's Gills: "Underwater Breath lasts 50% longer") count as breathing gear

## 2.1.0

- Stealth gear ("Increases your effective stealth level") is worn while stealthed (Stealth, Prowl); `/xm stealth` toggles it
- `/xm scan` shows stealth scores

## 2.0.1

- Gear goes back after dismounting in combat: restores are retried until the original item is seen back in its slot, instead of assumed done (the game silently refuses gear swaps in combat)
- Mount/swim items the game refused to equip are retried once after each swap
- `/xm off` puts gear back through the same retry path, also when typed in combat

## 2.0.0

- Ported to WoW: Forever (1.60.1+). The TurtleWoW version lives on the `turtle` branch
- Gear is found from item tooltips (mount speed, swim speed, water breathing) instead of item IDs, so Forever's own items work
- Mithril Spurs and Riding Skill glove enchants still count
- Zone-limited bonuses (The Desert Rose, "in Desert areas") are only used when nothing better is available
- Outrider's Gloves (5%, does not stack) are worn alone unless your other mount speed items add up to more than 5%
- Swim gear goes on as soon as you swim (surface too) and comes off 2s after leaving the water
- Chest slot swaps fixed (used the shirt slot before)
- Commands: `/xm on`, `/xm off` (also restores your gear), `/xm scan`
