local _, ns = ...
local XM = ns.XM

local TICK = .25
local MOUNT_DELAY = .3     -- dismount blips (flight paths, zoning) shouldn't swap gear back and forth
local DRY_DELAY = 2        -- hopping out of water for a moment keeps the swim set on
local SETTLE = 1           -- equips are async; wait before judging the result

local function print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccXiao|cffffffffMount|r: " .. msg)
end

local function tooltipLines(data)
  local lines = {}
  for _, line in ipairs(data and data.lines or {}) do
    if type(line.leftText) == "string" then lines[#lines + 1] = line.leftText end
  end
  return lines
end

local function describe(link, data, equippedIn)
  local id, enchant = XM.ParseLink(link)
  local equipLoc = id and select(4, C_Item.GetItemInfoInstant(id))
  return {
    link = link, id = id, equippedIn = equippedIn,
    slots = XM.SlotsFor(equipLoc),
    score = XM.Score(tooltipLines(data), enchant),
  }
end

local function inventory()
  local items = {}
  for slot = 1, 19 do
    local link = GetInventoryItemLink("player", slot)
    if link then items[#items + 1] = describe(link, C_TooltipInfo.GetInventoryItem("player", slot), slot) end
  end
  for bag = 0, NUM_BAG_SLOTS do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local link = C_Container.GetContainerItemLink(bag, slot)
      if link then items[#items + 1] = describe(link, C_TooltipInfo.GetBagItem(bag, slot)) end
    end
  end
  return items
end

local function equip(link, slot)
  C_Item.EquipItemByName(link, slot)
end

-- Slots whose original item should go back, except slots the new set is about to fill. They
-- stay pending until the item is seen back in place: the game silently refuses gear swaps in
-- combat, and dismounting can race the combat flag.
local function restore(keep)
  for slot, link in pairs(XiaoMountDB.restore) do
    if not keep[slot] then
      XiaoMountDB.pending[slot] = link
      XiaoMountDB.restore[slot] = nil
    end
  end
end

local function equipPlan(plan)
  for slot, item in pairs(plan) do
    XiaoMountDB.restore[slot] = XiaoMountDB.restore[slot] or XiaoMountDB.pending[slot]
      or GetInventoryItemLink("player", slot)
    XiaoMountDB.pending[slot] = nil
    equip(item.link, slot)
  end
end

local function apply(context)
  local plan = context and XM.Plan(context, inventory()) or {}
  restore(plan)
  equipPlan(plan)
  XiaoMountDB.active = context
end

local MAX_TRIES = 5
local tries = {}
local function wornID(slot) return GetInventoryItemID("player", slot) end

-- Equips pending restores again; true when anything was (re)tried
local function settlePending()
  local due = XM.Unrestored(XiaoMountDB.pending, wornID, C_Item.GetItemCount)
  for slot, link in pairs(XiaoMountDB.pending) do
    tries[slot] = due[slot] and (tries[slot] or 0) + 1 or nil
    if not due[slot] or tries[slot] > MAX_TRIES then
      if due[slot] then print("couldn't put back " .. link) end
      XiaoMountDB.pending[slot], tries[slot] = nil, nil
    else
      equip(link, slot)
    end
  end
  return next(XiaoMountDB.pending) ~= nil
end

-- cast info can be secret; an unreadable cast counts as casting
local function casting()
  local cast, channel = UnitCastingInfo("player"), UnitChannelInfo("player")
  if issecretvalue(cast) or issecretvalue(channel) then return true end
  return cast ~= nil or channel ~= nil
end

local function blocked()
  return InCombatLockdown() or UnitAffectingCombat("player") or UnitIsDeadOrGhost("player") or casting()
    or GetCursorInfo() ~= nil
end

local function wanted()
  return XM.Context({
    mounted = IsMounted() and not UnitOnTaxi("player"),
    stealthed = IsStealthed(),
    stealthGear = XiaoMountDB.stealth,
    swimming = IsSwimming(),
  })
end

local seen, seenSince, settleUntil, verify = nil, 0, 0, false
local function tick()
  local now = GetTime()
  -- disabled counts as "nothing to dress for", so the gear goes back the same way
  local context = XiaoMountDB.enabled and wanted() or nil
  if context ~= seen then seen, seenSince = context, now end
  if now < settleUntil or blocked() then return end
  if context ~= XiaoMountDB.active then
    local delay = (XiaoMountDB.active == "swim" and not context) and DRY_DELAY or MOUNT_DELAY
    if now - seenSince < delay then return end
    apply(context)
    verify, settleUntil = true, now + SETTLE
    return
  end
  -- one re-plan after each swap catches set items the game refused to equip
  if verify and context then equipPlan(XM.Plan(context, inventory())) end
  verify = false
  if settlePending() then settleUntil = now + SETTLE end
end

local function report()
  local found = false
  for _, item in ipairs(inventory()) do
    local score = item.score
    if item.slots and (score.mount > 0 or score.swim > 0 or score.stealth > 0) then
      found = true
      print(string.format("%s  mount %s  swim %s  stealth %s%s", item.link, score.mount, score.swim,
        score.stealth, item.equippedIn and "  (worn)" or ""))
    end
  end
  if not found then print("no mount, swim or stealth items found in bags or worn") end
end

local commands = {
  on = function() XiaoMountDB.enabled = true; print("enabled") end,
  off = function() XiaoMountDB.enabled = false; print("disabled") end,
  scan = report,
  stealth = function()
    XiaoMountDB.stealth = not XiaoMountDB.stealth
    print("stealth gear " .. (XiaoMountDB.stealth and "on" or "off"))
  end,
}

SLASH_XIAOMOUNT1, SLASH_XIAOMOUNT2 = "/xiaomount", "/xm"
SlashCmdList.XIAOMOUNT = function(msg)
  local command = commands[strtrim(msg or ""):lower()]
  if command then return command() end
  print((XiaoMountDB.enabled and "enabled" or "disabled") .. ". /xm on | off | scan | stealth")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
  if name ~= "XiaoMount" then return end
  self:UnregisterEvent("ADDON_LOADED")
  XiaoMountDB = XiaoMountDB or {}
  if XiaoMountDB.enabled == nil then XiaoMountDB.enabled = true end
  if XiaoMountDB.stealth == nil then XiaoMountDB.stealth = true end
  XiaoMountDB.restore = XiaoMountDB.restore or {}
  XiaoMountDB.pending = XiaoMountDB.pending or {}
  C_Timer.NewTicker(TICK, tick)
end)
