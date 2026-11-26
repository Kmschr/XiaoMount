local _, ns = ...

-- Pure rules: which items help in which context and what to put in each slot. No game calls,
-- so tests/xiaomount.lua can run it offline.
local XM = {}
ns.XM = XM

XM.TRINKETS = { 13, 14 }
XM.RINGS = { 11, 12 }

local SLOTS_BY_LOC = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
  INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
  INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
  INVTYPE_FINGER = XM.RINGS, INVTYPE_TRINKET = XM.TRINKETS, INVTYPE_CLOAK = { 15 },
}

function XM.SlotsFor(equipLoc)
  return SLOTS_BY_LOC[equipLoc]
end

-- Permanent enchants whose tooltip line names the enchant instead of its effect
XM.ENCHANT_MOUNT = {
  [464] = 4, -- Mithril Spurs
  [930] = 2, -- Enchant Gloves - Riding Skill
}

-- Zone-limited bonuses ("... in Desert areas") only win when nothing unconditional is around
local CONDITIONAL_WEIGHT = .01

-- Mount speed that replaces every other mount speed bonus instead of adding to it, by name with
-- its bonus in case the tooltip words it some other way
XM.EXCLUSIVE_NAMES = { ["outrider's gloves"] = 5 }

function XM.ParseLink(link)
  if type(link) ~= "string" then return end
  local id, enchant = link:match("item:(%d+):(%d*)")
  return tonumber(id), tonumber(enchant) or 0
end

local function percent(line, what)
  return tonumber(line:match(what .. "[^%d%%]-(%d+)%%")) or tonumber(line:match("(%d+)%%%s*" .. what))
end

-- Mount/swim scores from an item's tooltip lines: percent bonus, plus 1 swim point for water
-- breathing so a breathing helm still gets equipped.
function XM.Score(lines, enchantID)
  local score, named = { mount = 0, swim = 0 }, nil
  for i, text in ipairs(lines or {}) do
    local line = text:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if i == 1 then named = XM.EXCLUSIVE_NAMES[line] end
    if named or (line:find("mount speed") and line:find("not stack")) then score.exclusive = true end
    if not line:find("^use:") then
      local weight = (line:find(" in [%a%s']+ areas") or line:find(" while in ")) and CONDITIONAL_WEIGHT or 1
      local mount = percent(line, "mount speed")
      local swim = percent(line, "swim%a* speed")
      if mount then score.mount = score.mount + mount * weight end
      if swim then score.swim = score.swim + swim * weight end
      if line:find("water breathing") or line:find("underwater breathing") or line:find("breathe underwater") then
        score.swim = score.swim + 1
      end
    end
  end
  score.mount = math.max(score.mount, XM.ENCHANT_MOUNT[enchantID or 0] or 0, named or 0)
  return score
end

-- Best items per slot group among `items`, and the total score they add up to
local function planGroups(context, items)
  local groups = {}
  for _, item in ipairs(items) do
    if item.slots and (item.score[context] or 0) > 0 then
      local group = groups[item.slots] or {}
      groups[item.slots] = group
      group[#group + 1] = item
    end
  end

  local plan, total = {}, 0
  for slots, group in pairs(groups) do
    table.sort(group, function(a, b)
      local sa, sb = a.score[context], b.score[context]
      if sa ~= sb then return sa > sb end
      return (a.equippedIn and 1 or 0) > (b.equippedIn and 1 or 0)
    end)
    local chosen, seen = {}, {}
    for _, item in ipairs(group) do
      if #chosen == #slots then break end
      if not seen[item.id] then
        seen[item.id] = true
        chosen[#chosen + 1] = item
        total = total + item.score[context]
      end
    end
    -- chosen items already worn stay put; the rest fill the other slots of the group
    local free, worn = {}, {}
    for _, item in ipairs(chosen) do
      if item.equippedIn then worn[item.equippedIn] = true end
    end
    for _, slot in ipairs(slots) do
      if not worn[slot] then free[#free + 1] = slot end
    end
    for _, item in ipairs(chosen) do
      if not item.equippedIn then plan[table.remove(free, 1)] = item end
    end
  end
  return plan, total
end

-- Which item each slot should hold for `context` ("mount" or "swim").
-- items: { { link, id, slots = {...}, score = {...}, equippedIn = slot? }, ... } covering bags
-- and what's worn. Returns { [slot] = item } only for slots whose item should change.
-- An exclusive mount item (Outrider's Gloves) is worn alone when the stacking items together
-- give no more than it does.
function XM.Plan(context, items)
  local stacking, best = {}, nil
  for _, item in ipairs(items) do
    if context == "mount" and item.score.exclusive then
      if item.slots and (not best or item.score.mount > best.score.mount
          or (item.score.mount == best.score.mount and item.equippedIn)) then
        best = item
      end
    else
      stacking[#stacking + 1] = item
    end
  end
  local plan, total = planGroups(context, stacking)
  if not best or best.score.mount <= 0 or best.score.mount < total then return plan end
  if best.equippedIn then return {} end
  return { [best.slots[1]] = best }
end
