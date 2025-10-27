-- stairminer.lua
-- Advanced Turtle with Mining + Crafting:
-- 1) Mine staircase down to bedrock.
-- 2) On ascent: craft and place stairs when possible, torch every 10 steps,
--    dump to right chest ONLY items that can't be used to craft stairs.

-------------------------
-- CONFIG
-------------------------
local TORCH_INTERVAL     = 10    -- torch placement interval on ascent
local FUEL_LOW           = 200   -- refuel threshold
local KEEP_MIN_CHESTS    = 1     -- always keep at least this many chests reserved
-- Materials we consider valid for crafting stairs (vanilla-ish & common stones)
local STAIR_MATERIALS = {
  ["minecraft:cobblestone"]   = true,
  ["minecraft:stone"]         = true,
  ["minecraft:deepslate"]     = true,
  ["minecraft:granite"]       = true,
  ["minecraft:diorite"]       = true,
  ["minecraft:andesite"]      = true,
  ["minecraft:sandstone"]     = true,
  ["minecraft:red_sandstone"] = true,
  ["minecraft:blackstone"]    = true,
  ["minecraft:prismarine"]    = true,
}

-------------------------
-- UTILS: safety & helpers
-------------------------
local function hasCraftingAPI()
  return type(turtle.craft) == "function"
end

local function itemNameAt(slot)
  local d = turtle.getItemDetail(slot)
  return d and d.name or nil
end

local function selectFirst(name)
  for s=1,16 do
    if itemNameAt(s) == name then turtle.select(s); return true end
  end
  return false
end

local function selectAny(predicate)
  for s=1,16 do
    local d = turtle.getItemDetail(s)
    if d and predicate(d) then turtle.select(s); return true end
  end
  return false
end

local function hasEmptySlot()
  for s=1,16 do
    if turtle.getItemCount(s) == 0 then return true end
  end
  return false
end

local function countItem(name)
  local total = 0
  for s=1,16 do
    local d = turtle.getItemDetail(s)
    if d and d.name == name then total = total + d.count end
  end
  return total
end

local function isStairMaterialName(n) return STAIR_MATERIALS[n] == true end
local function isStairsName(n) return n and n:find("_stairs") ~= nil end

local function compactInventory()
  for i=1,16 do
    if turtle.getItemCount(i) > 0 then
      local di = turtle.getItemDetail(i)
      for j=i+1,16 do
        local dj = turtle.getItemDetail(j)
        if dj and di and dj.name == di.name then
          turtle.select(j); turtle.transferTo(i)
        end
      end
    end
  end
end

-------------------------
-- MOVEMENT / DIGGING (robust)
-------------------------
local function safeDig()
  while turtle.detect() do if not turtle.dig() then sleep(0.25) end end
end
local function safeDigUp()
  while turtle.detectUp() do if not turtle.digUp() then sleep(0.25) end end
end
local function safeDigDown()
  while turtle.detectDown() do if not turtle.digDown() then sleep(0.25) end end
end

local function safeForward()
  local tries=0
  while not turtle.forward() do
    if turtle.detect() then if not turtle.dig() then sleep(0.2) end
    else turtle.attack(); sleep(0.1) end
    tries=tries+1; if tries>25 then error("Stuck moving forward") end
  end
end

local function safeDown()
  local tries=0
  while not turtle.down() do
    if turtle.detectDown() then if not turtle.digDown() then sleep(0.2) end
    else turtle.attackDown(); sleep(0.1) end
    tries=tries+1; if tries>25 then error("Stuck moving down") end
  end
end

local function safeUp()
  local tries=0
  while not turtle.up() do
    if turtle.detectUp() then if not turtle.digUp() then sleep(0.2) end
    else turtle.attackUp(); sleep(0.1) end
    tries=tries+1; if tries>25 then error("Stuck moving up") end
  end
end

-------------------------
-- FUEL
-------------------------
local function refuelFromInventory()
  if selectFirst("minecraft:coal") or selectFirst("minecraft:charcoal") then
    return turtle.refuel()
  end
  if selectFirst("minecraft:coal_block") then return turtle.refuel(1) end
  -- soft fallback (wood) to avoid stalls
  if selectAny(function(d)
    local n=d.name; return n:find("planks") or n:find("log") or n:find("stem")
  end) then
    return turtle.refuel(1)
  end
  return false
end

local function ensureFuel()
  local f = turtle.getFuelLevel()
  if f == "unlimited" then return end
  if f < FUEL_LOW then refuelFromInventory() end
end

-------------------------
-- BEDROCK CHECK
-------------------------
local function atBedrock()
  local ok, data = turtle.inspectDown()
  return ok and data and data.name == "minecraft:bedrock"
end

-------------------------
-- DESCENT (staircase)
-------------------------
local steps = 0

local function digStepDownForward()
  safeDig()
  safeDigUp()
  safeDigDown()
  safeDown()
  safeDig()
  safeForward()
  steps = steps + 1
end

local function descendToBedrock()
  while true do
    ensureFuel()
    if atBedrock() then break end
    digStepDownForward()
  end
end

-------------------------
-- CHEST DUMP (ASCENT ONLY; drop ONLY non-stair materials)
-------------------------
local function dumpToRightChestIfFull()
  compactInventory()
  if hasEmptySlot() then return end

  turtle.turnRight()
  safeDig()
  local placed = false
  if selectAny(function(d) return d.name:find("chest") end) then
    placed = turtle.place()
  end
  if not placed then
    turtle.turnLeft()
    return
  end

  -- Keep: fuel, torches, at least KEEP_MIN_CHESTS chests, anything usable for stairs, and the stairs themselves
  local keep = {
    ["minecraft:torch"] = true,
    ["minecraft:coal"] = true,
    ["minecraft:charcoal"] = true,
    ["minecraft:coal_block"] = true,
  }
  if countItem("minecraft:chest") <= KEEP_MIN_CHESTS then keep["minecraft:chest"] = true end

  for s=1,16 do
    local d = turtle.getItemDetail(s)
    if d then
      local n = d.name
      local keepThis = keep[n] or isStairMaterialName(n) or isStairsName(n)
      if not keepThis then
        turtle.select(s); turtle.drop()
      end
    end
  end

  turtle.turnLeft()
end

-------------------------
-- TORCHES
-------------------------
local function placeTorchRightWall()
  if not selectFirst("minecraft:torch") then return end
  turtle.turnRight()
  if not turtle.place() then turtle.placeDown() end
  turtle.turnLeft()
end

-------------------------
-- STAIRS: craft & place (best-effort)
-------------------------
-- Crafting recipe: 6 of same material in slots 1,4,5,7,8,9
local stairPatternSlots = {1,4,5,7,8,9}

local function clearCraftGrid()
  for i=1,9 do
    local c = turtle.getItemCount(i)
    if c > 0 then
      local d = turtle.getItemDetail(i)
      -- first try to stack onto same items
      local moved = false
      for j=10,16 do
        local dj = turtle.getItemDetail(j)
        if dj and d and dj.name == d.name then
          turtle.select(i); turtle.transferTo(j)
          if turtle.getItemCount(i) == 0 then moved = true; break end
        end
      end
      if not moved then
        for j=10,16 do
          if turtle.getItemCount(j) == 0 then
            turtle.select(i); turtle.transferTo(j, c); break
          end
        end
      end
    end
  end
end

local function pullFromAny(matName, dst, need)
  local left = need
  for s=1,16 do
    if s ~= dst and left > 0 then
      local d = turtle.getItemDetail(s)
      if d and d.name == matName then
        turtle.select(s)
        local toMove = math.min(left, d.count)
        if turtle.transferTo(dst, toMove) then
          left = left - toMove
        end
      end
    end
  end
  return left <= 0
end

local function countTotal(matName)
  local total = 0
  for s=1,16 do
    local d = turtle.getItemDetail(s)
    if d and d.name == matName then total = total + d.count end
  end
  return total
end

local function craftOneBatchOfStairs()
  if not hasCraftingAPI() then return false end
  -- choose the material with the largest stack of eligible blocks
  local bestMat, bestCount = nil, 0
  for mat,_ in pairs(STAIR_MATERIALS) do
    local c = countTotal(mat)
    if c >= 6 and c > bestCount then bestMat, bestCount = mat, c end
  end
  if not bestMat then return false end

  clearCraftGrid()
  -- Place exactly 1 of the bestMat into each pattern slot (total 6)
  for _,slot in ipairs(stairPatternSlots) do
    -- ensure empty
    if turtle.getItemCount(slot) > 0 then
      for j=10,16 do
        if turtle.getItemCount(j) == 0 then turtle.select(slot); turtle.transferTo(j, turtle.getItemCount(slot)); break end
      end
    end
    if not pullFromAny(bestMat, slot, 1) then
      clearCraftGrid()
      return false
    end
  end

  -- Attempt craft (should yield 4 stairs)
  if turtle.craft(1) then
    return true
  else
    clearCraftGrid()
    return false
  end
end

local function ensureHaveStairs()
  -- If we already have any stairs, great.
  if selectAny(function(d) return isStairsName(d.name) end) then return true end
  -- Otherwise, try to craft one batch; if successful, select newly made stairs.
  if craftOneBatchOfStairs() then
    return selectAny(function(d) return isStairsName(d.name) end)
  end
  return false
end

local function placeStairBehindFacingDownSlope()
  turtle.turnLeft(); turtle.turnLeft()
  -- Try forward placement so stair faces the right way; fallback down
  if not turtle.place() then turtle.placeDown() end
  turtle.turnLeft(); turtle.turnLeft()
end

-------------------------
-- PATH FLOOR: ensure a block underfoot
-------------------------
local function ensureStepBelowWithBlock()
  local ok, _ = turtle.inspectDown()
  if ok then return end
  if selectAny(function(d) return isStairMaterialName(d.name) end) then
    turtle.placeDown()
  else
    -- as a last resort place any solid
    if selectAny(function(d)
      local n=d.name
      return n:find("stone") or n:find("cobblestone") or n:find("deepslate")
          or n:find("granite") or n:find("diorite") or n:find("andesite")
          or n:find("sandstone") or n:find("blackstone") or n:find("netherrack")
          or n:find("prismarine")
    end) then turtle.placeDown() end
  end
end

-------------------------
-- ASCENT
-------------------------
local function returnAndBuild()
  for i=steps,1,-1 do
    ensureFuel()

    -- If inventory is full, dump ONLY things that can’t be used for stairs
    dumpToRightChestIfFull()

    -- Keep walkable floor
    ensureStepBelowWithBlock()

    -- Torch interval on right wall
    if i % TORCH_INTERVAL == 0 then placeTorchRightWall() end

    -- Move back then up (reverse of descent step)
    if not turtle.back() then
      turtle.turnLeft(); turtle.turnLeft()
      safeDig()
      turtle.turnLeft(); turtle.turnLeft()
      turtle.back()
    end
    safeUp()

    -- Craft (if needed) and place 1 stair behind (best-effort; skip silently if not possible)
    if ensureHaveStairs() then
      placeStairBehindFacingDownSlope()
    end
  end
end

-------------------------
-- MAIN
-------------------------
local function main()
  print("StairMiner: starting descent...")
  safeDig(); safeDigUp()
  descendToBedrock()
  print("Reached bedrock (or as deep as allowed). Steps: "..tostring(steps))
  print("Ascending: crafting & placing stairs, chest-dumping non-stair items, torches every "..TORCH_INTERVAL.."...")
  returnAndBuild()
  print("Done. Back at the top.")
end

local ok, err = pcall(main)
if not ok then print("Error: "..tostring(err)) end

