
local function victory()
    print("We finished the maze!")
    turtle.up()
    for _ = 1,4 do
        turtle.turnRight()
    end    
end

local function look()
    local ok, data = turtle.inspectDown()
    
    if ok and data.name:find("green") then
        print("At start")
    end
    
    if ok and data.name:find("yellow") then
      victory()
      return true
    end  
    
    return false
end

turtle.refuel(10)
if turtle.getFuelLevel() < 10 then
    print("Insert fuel in slot 1")
    return
end

while true do
    local done = look()
    if done then
        return
    end

    -- Idea:
    -- While we dect a block
    -- forward, turn right.
    turtle.turnRight()
    while turtle.detect() do 
    	turtle.turnLeft()
    end 
    turtle.turnLeft()
    while turtle.detect() do
    	turtle.turnRight()
    end
    
    turtle.turnLeft()
    turtle.forward()
    turtle.turnRight()
    turtle.forward()
    turtle.turnLeft()
    turtle.forward()
    turtle.turnRight()
    turtle.forward()
end
