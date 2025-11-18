local function victory()
    print("We finished the maze!")
    turtle.up()
    for _ = 1, 4 do
        turtle.turnRight()
    end
end

local function look()
    local ok, data = turtle.inspectDown()

    if ok and data.name:find("yellow") then
        victory()
        return true
    end
    return false
end

-- Helpers
local function frontBlocked()
    return turtle.detect()
end

local function leftBlocked()
    turtle.turnLeft()
    local blocked = turtle.detect()
    turtle.turnRight()
    return blocked
end

local function rightBlocked()
    turtle.turnRight()
    local blocked = turtle.detect()
    turtle.turnLeft()
    return blocked
end


turtle.refuel(10)

while true do
    if look() then return end

    -- LEFT-HAND RULE:
    if not leftBlocked() then
        turtle.turnLeft()
        turtle.forward()
    elseif not frontBlocked() then
        turtle.forward()
    elseif not rightBlocked() then
        turtle.turnRight()
        turtle.forward()
    else
        -- Dead end -> turn around
        turtle.turnRight()
        turtle.turnRight()
    end
end
