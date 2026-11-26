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

-- Put back what each slot held before we swapped, except slots the new set is about to fill
local function restore(keep)
  for slot, link in pairs(XiaoMountDB.restore) do
    if not keep[slot] then
      if not C_Item.IsEquippedItem(link) then equip(link, slot) end
      XiaoMountDB.restore[slot] = nil
    end
  end
end

local function apply(context)
  local plan = context and XM.Plan(context, inventory()) or {}
  restore(plan)
  for slot, item in pairs(plan) do
    XiaoMountDB.restore[slot] = XiaoMountDB.restore[slot] or GetInventoryItemLink("player", slot)
    equip(item.link, slot)
  end
  XiaoMountDB.active = context
end

-- cast info can be secret; an unreadable cast counts as casting
local function casting()
  local cast, channel = UnitCastingInfo("player"), UnitChannelInfo("player")
  if issecretvalue(cast) or issecretvalue(channel) then return true end
  return cast ~= nil or channel ~= nil
end

local function blocked()
  return InCombatLockdown() or UnitIsDeadOrGhost("player") or casting() or GetCursorInfo() ~= nil
end

local function wanted()
  if IsMounted() and not UnitOnTaxi("player") then return "mount" end
  if IsSwimming() then return "swim" end
end

local seen, seenSince, settleUntil = nil, 0, 0
local function tick()
  if not XiaoMountDB.enabled then return end
  local now = GetTime()
  local context = wanted()
  if context ~= seen then seen, seenSince = context, now end
  if context == XiaoMountDB.active or now < settleUntil or blocked() then return end
  local delay = (XiaoMountDB.active == "swim" and not context) and DRY_DELAY or MOUNT_DELAY
  if now - seenSince < delay then return end
  apply(context)
  settleUntil = now + SETTLE
end

local function report()
  local found = false
  for _, item in ipairs(inventory()) do
    if item.slots and (item.score.mount > 0 or item.score.swim > 0) then
      found = true
      print(string.format("%s  mount %s  swim %s%s", item.link, item.score.mount, item.score.swim,
        item.equippedIn and "  (worn)" or ""))
    end
  end
  if not found then print("no mount or swim speed items found in bags or worn") end
end

local commands = {
  on = function() XiaoMountDB.enabled = true; print("enabled") end,
  off = function()
    XiaoMountDB.enabled = false
    if not blocked() then apply(nil) end
    print("disabled")
  end,
  scan = report,
}

SLASH_XIAOMOUNT1, SLASH_XIAOMOUNT2 = "/xiaomount", "/xm"
SlashCmdList.XIAOMOUNT = function(msg)
  local command = commands[strtrim(msg or ""):lower()]
  if command then return command() end
  print((XiaoMountDB.enabled and "enabled" or "disabled") .. ". /xm on | off | scan")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
  if name ~= "XiaoMount" then return end
  self:UnregisterEvent("ADDON_LOADED")
  XiaoMountDB = XiaoMountDB or {}
  if XiaoMountDB.enabled == nil then XiaoMountDB.enabled = true end
  XiaoMountDB.restore = XiaoMountDB.restore or {}
  C_Timer.NewTicker(TICK, tick)
end)
