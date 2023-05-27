local component = require("component")
local term = require("term")
local sides = require("sides")
local redstone = component.redstone

os.execute("resolution 60 15")

function formatInt(i)
	if i > 10^18 then return "battery goes brr" end
	return (tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", ""))
end
local function parseFromSensorInfo(str)
	local n = str:match(": ([%d,]+)EU"):gsub(",","")
	n = tonumber(n)
	if n < 0 then n = -n - 2 end -- fix tonumber bullshit
	return n
end

local max = 1e15
local side = sides.right
local side2 = sides.left

--redstone.setOutput(side,0)
local function doThing()
	local battery = component.gt_machine
	local data = battery.getSensorInformation()
	if not data then return end
	local gtPower = parseFromSensorInfo(data[2])
	local gtPowerMax = parseFromSensorInfo(data[3])
	--local gtPowerSupply = parseFromSensorInfo(data[5])
	--local gtPowerDrain = parseFromSensorInfo(data[6])

	term.clear()
	print(string.format("Power: %s / %s EU",formatInt(gtPower), formatInt(gtPowerMax)))

	local percent = math.max(0,math.min(gtPower / max,1))
	local redOut = math.floor(percent * 15)
	print(string.format("Fake max: %s\nPercent: %s%%\nRedstone: %s", max, math.floor(percent*100), redOut))
	redstone.setOutput(side,redOut)
	redstone.setOutput(side2,redOut)
end

while true do
	doThing()
	os.sleep(1)
end
