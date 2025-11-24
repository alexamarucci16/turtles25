url = "https://cedar.fogcloud.org/api/logs/6845"

ok, data = turtle.inspectDown()
if ok then
  turtle.forward()
  print(data.name) 
end

turtle.forward() 

function scan_one_block()
   ok, data = turtle.detectDown()
   one_line = "line="..data.name
   http.post(url, data)
   turtle.forward()
   return ok 
end 

local scanning = true 

while scanning do 
	scanning = scan_one_block()
	turtle.moveForward()
end


