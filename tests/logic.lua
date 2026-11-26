-- Offline tests for XiaoMount's rules. Run from the addon folder: lua5.1 tests/logic.lua
local root = arg[0]:match("^(.*)/tests/logic.lua$") or "."
local ns = {}
assert(loadfile(root .. "/Logic.lua"))("XiaoMount", ns)
local XM = ns.XM

local passed, failed = 0, 0
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1 else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a)) end end

local function item(id, slots, mount, swim, equippedIn)
  return { link = "item:" .. id, id = id, slots = slots, score = { mount = mount or 0, swim = swim or 0 }, equippedIn = equippedIn }
end

test("parses item and enchant ids from links", function()
  local id, enchant = XM.ParseLink("|cff1eff00|Hitem:11122:464:0:0|h[Carrot on a Stick]|h|r")
  eq(id, 11122); eq(enchant, 464)
  id, enchant = XM.ParseLink("|Hitem:274648::::::::42:::::|h")
  eq(id, 274648); eq(enchant, 0, "empty enchant")
  eq(XM.ParseLink(nil), nil)
end)

test("scores tooltip lines", function()
  eq(XM.Score({ "Carrot on a Stick", "Equip: Increases mount speed by 3%." }).mount, 3)
  eq(XM.Score({ "|cff1eff00Equip: Increases mount speed by 7% in Desert areas.|r" }).mount, .07, "zone-limited counts as fallback")
  eq(XM.Score({ "Equip: Increases swim speed by 15%." }).swim, 15)
  eq(XM.Score({ "Mount Speed +4%" }).mount, 4, "percent after the words")
  eq(XM.Score({ "Use: Increases mount speed by 10% for 1 min." }).mount, 0, "on-use effects skipped")
  eq(XM.Score({ "Equip: Allows underwater breathing." }).swim, 1, "breathing helm")
  eq(XM.Score({ "Mithril Spurs" }, 464).mount, 4, "enchant named instead of described")
  eq(XM.Score({ "Mount Speed +4%" }, 464).mount, 4, "enchant not counted twice")
end)

test("plans the best items into each slot group", function()
  local worn = item(1, XM.TRINKETS, 0, 0, 13)
  local carrot = item(11122, XM.TRINKETS, 3)
  local rose = item(274648, XM.TRINKETS, .07)
  local spurs = item(5, { 8 }, 4)
  local plan = XM.Plan("mount", { worn, item(2, XM.TRINKETS, 0, 0, 14), rose, carrot, spurs })
  eq(plan[13], carrot, "best trinket first")
  eq(plan[14], rose, "fallback fills the second trinket")
  eq(plan[8], spurs)
end)

test("keeps worn helpers in place and skips duplicates", function()
  local carrot = item(11122, XM.TRINKETS, 3, 0, 14)
  local plan = XM.Plan("mount", { carrot, item(11122, XM.TRINKETS, 3), item(9, XM.TRINKETS, 0, 0, 13) })
  eq(plan[14], nil, "already worn")
  eq(plan[13], nil, "second copy of a unique trinket not used")
end)

test("plans per context", function()
  local belt = item(7052, { 6 }, 0, 15)
  eq(next(XM.Plan("mount", { belt })), nil)
  eq(XM.Plan("swim", { belt })[6], belt)
end)

test("recognizes Outrider's Gloves as exclusive", function()
  local score = XM.Score({ "Outrider's Gloves", "Equip: Increases mount speed by 5%. Does not stack with other mount speed effects." })
  eq(score.exclusive, true); eq(score.mount, 5)
  score = XM.Score({ "Outrider's Gloves", "Hands" })
  eq(score.exclusive, true, "by name"); eq(score.mount, 5, "default bonus")
  eq(XM.Score({ "Equip: Increases mount speed by 3%." }).exclusive, nil)
end)

test("exclusive gloves win unless the stacking items add up to more", function()
  local outrider = item(30, { 10 }, 5)
  outrider.score.exclusive = true
  local carrot, spurs = item(11122, XM.TRINKETS, 3), item(5, { 8 }, 4)
  local plan = XM.Plan("mount", { outrider, carrot })
  eq(plan[10], outrider, "3% < 5%")
  eq(plan[13], nil, "nothing stacks with it")
  plan = XM.Plan("mount", { outrider, carrot, item(6, { 8 }, 2) })
  eq(plan[10], outrider, "a tie keeps the gloves")
  plan = XM.Plan("mount", { outrider, carrot, spurs })
  eq(plan[10], nil, "7% > 5%")
  eq(plan[13], carrot); eq(plan[8], spurs)
  outrider.equippedIn = 10
  eq(next(XM.Plan("mount", { outrider, carrot })), nil, "already worn")
end)

print(passed .. " passed, " .. failed .. " failed")
if failed > 0 then os.exit(1) end
