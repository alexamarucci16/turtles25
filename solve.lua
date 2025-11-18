-- MAZE SOLVER USING DEPTH-FIRST SEARCH + BACKTRACKING
-- Requires no map; turtle learns maze while exploring

local visited = {}   -- visited[x][y] = true
local dir = 0        -- 0=N, 1=E, 2=S, 3=W
local x, y = 0, 0    -- turtle position in virtual grid

-- direction helpers
local function left()  dir = (dir + 3) % 4; turtle.turnLeft() end
local function right() dir = (dir + 1) % 4; turtle.turnRight() end
local function back()  dir = (dir + 2) % 4; turtle.turnRight(); turtle.turnRight() end

local function forward()
    if turtle.forward() then
        if dir == 0 then y = y + 1
        elseif dir == 1 then x = x + 1
        elseif dir == 2 then y = y - 1
        elseif dir == 3 then x = x - 1 end
        return true
    end
    return false
end

local function markVisited()
    visited[x] = visited[x] or {}
    visited[x][y] = true
end

local function isVisited(nx, ny)
    return visited[nx] and visited[nx][ny]
end

--------------------------------------------------------------------

local function victory()
    print("We finished the maze!")
    turtle.up()
    for _ = 1, 4 do turtle.turnRight() end
end

local function lookForGoal()
    local ok, data = turtle.inspectDown()
    return ok and data.name:find("yellow")
end

--------------------------------------------------------------------

-- attempt to move in relative direction
local function tryMove(rel)
    -- 0=forward, 1=right, 2=back, 3=left
    if rel == 1 then right()
    elseif rel == 2 then back()
    elseif rel == 3 then left() end

    local moved = forward()

    -- restore orientation after test if failed
    if not moved then
        if rel == 1 then left()
        elseif rel == 2 then back()
        elseif rel == 3 then right() end
    end

    return moved
end

--------------------------------------------------------------------

-- DEPTH-FIRST SEARCH
local function dfs()
    markVisited()

    if lookForGoal() then
        victory()
        return true
    end

    -- Explore in order: left → forward → right → back
    local relDirs = {3,0,1,2}
    for _, rel in ipairs(relDirs) do
        -- compute hypothetical move target
        local nx, ny = x, y
        local d = (dir + rel) % 4
        if d == 0 then ny = ny + 1
        elseif d == 1 then nx = nx + 1
        elseif d == 2 then ny = ny - 1
        elseif d == 3 then nx = nx - 1 end

        if not isVisited(nx, ny) and tryMove(rel) then
            if dfs() then return true end

            -- backtrack
            back()
        end
    end

    return false
end

--------------------------------------------------------------------

turtle.refuel(10)
dfs()
print("No goal found.")
