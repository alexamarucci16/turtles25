local logID = arg and arg[1]
local W = tonumber(arg and arg[2])
local H = tonumber(arg and arg[3])

if not logID then
    write("Enter log ID: ")
    logID = read()
end

if not W then
    write("Enter width: ")
    W = tonumber(read())
end

if not H then
    write("Enter height: ")
    H = tonumber(read())
end

local url = "https://cedar.fogcloud.org/api/logs/" .. logID


local function sendColor(color)
    http.post(url, "line=" .. color)
end

local function readColor()
    local ok, data = turtle.inspectDown()
    if ok then
        return data.name
    end
    return "air"
end

turtle.Forward()


for y = 1, H do
    for x = 1, W do
        local color = readColor()
        sendColor(color)
        print("Sent:", color)

        if x < W then
            if not safeForward() then return end
        end
    end

    -- move up to next row
    if y < H then
        -- return to left
        for i = 1, W - 1 do turtle.back() end
        turtle.up()
    end
end

print("Scan Finished!")

