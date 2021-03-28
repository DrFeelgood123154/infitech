local component = require("component")
local term = require("term")
local sides = require("sides")
local redstone = component.redstone

local batteries = {}
for k,v in pairs(component.list("gt_batterybuffer")) do
	batteries[#batteries+1] = component.proxy(k)
end
function formatInt(i)
	if i > 10^18 then return "battery goes brr" end
	return (tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", ""))
end

local function getPower()
	local totalPower, totalPowerMax, totalOutput, totalInput = 0, 0, 0, 0
	for i=1,#batteries do
		local bat = batteries[i]
		local pwr = bat.getEUStored()
		local pwrMax = bat.getEUMaxStored()
		for i=1,bat.getOutputAmperage() do
			pwr = pwr + bat.getBatteryCharge(i)
			pwrMax = pwrMax + bat.getMaxBatteryCharge(i)
		end

		totalPower = totalPower + pwr
		totalPowerMax = totalPowerMax  + pwrMax

		totalInput = totalInput + bat.getEUInputAverage() 
		totalOutput = totalOutput + bat.getEUOutputAverage()
	end

	return totalPower, totalPowerMax, totalInput, totalOutput
end

local on = false
redstone.setOutput(sides.left,0)
local averageIn, averageOut = 0, 0
while true do
	local pwr, pwrMax, pwrAverageIn, pwrAverageOut = getPower()

	if averageIn == 0 then averageIn = pwrAverageIn else
		averageIn = averageIn * 0.7 + pwrAverageIn * 0.3
	end
	if averageOut == 0 then averageOut = pwrAverageOut else
		averageOut = averageOut * 0.7 + pwrAverageOut + 0.3
	end

	local percent = pwr / pwrMax
	if percent < 0.55 and not on then
		on = true
		redstone.setOutput(sides.left,15)
	elseif percent > 0.85 and on then
		on = false
		redstone.setOutput(sides.left,0)
	end

	-- Time to zero or full energy
	local timeToZero = "-"
	local seconds = 0
	local powerDelta = ((averageOut-averageIn)*20)

	if averageOut > averageIn then
		seconds = tonumber(pwr / powerDelta)
		timeToZero = "Zero: "
	elseif averageOut < averageIn then
		seconds = tonumber((pwrMax - pwr) / (-powerDelta))
		timeToZero = "Full: "
	end

	if seconds > 0 then
		if timeToZero == "Full: " and pwrMax > 10^18 then
			local hours = math.floor(seconds/3600)
			local years = math.floor(hours / 8765.81277)
			timeToZero = "Full: " .. formatInt(years) .. " years"
		else
			local hours = math.floor(seconds/3600);
			local mins = math.floor(seconds/60 - (hours*60));
			local secs = math.floor(seconds - hours*3600 - mins *60);
			timeToZero = timeToZero .. string.format("%02.f:%02.f:%02.f", hours, mins, secs)
		end
	else
		timeToZero = timeToZero .. "-"
	end

	term.clear()
	print(string.format("Power: %s / %s EU (%s)\nIn/Out: %s / %s\n%s\nTurbines: %s",
		formatInt(math.floor(pwr)),
		formatInt(math.floor(pwrMax)),
		math.floor(percent*100+0.5).."%",
		formatInt(math.floor(averageIn)),
		formatInt(math.floor(averageOut)),
		timeToZero,
		on and "On" or "Off"
	))

	os.sleep(0.5)
end
