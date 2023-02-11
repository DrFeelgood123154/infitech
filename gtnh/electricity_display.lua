
local displayMax = 14

local gtPowerVoltage = 0
local overrideVoltage = 0
local overrideAmperage = 0

local turbinesOn = false
local warningBlink = false
local gtPowerDrainAvg = nil
local gtPowerSupplyAvg = nil
local gtPowerIOAvg30sec = nil
local gtPowerIOAvg10min = nil
local gtPowerIOAvg1hour = nil

local batteryBuffers = {}
local highestEnergyIncome = 0
local highestEnergyDrain = 0
local crafter
local ae
local ret = {}

local function parseFromSensorInfo(str)
	local n = str:match("^[^%d]*([%d,]+)E?U?/?t?$"):gsub(",","")
	n = tonumber(n)
	if n < 0 then n = -n - 2 end -- fix tonumber bullshit
	return n
end

local function GetBatteries(component)
	local idx = 0
	local maxIdx = #batteryBuffers
	for id, what in component.list("battery") do
		idx = idx + 1
		batteryBuffers[idx] = component.proxy(id)
	end


	for id, what in component.list("gt_machine") do
		local proxy = component.proxy(id)
		if proxy.getEUOutputAverage and 
			proxy.getEUInputAverage and 
			proxy.getEUStored and 
			proxy.getEUMaxStored and
			proxy.getSensorInformation then
				idx = idx + 1
				batteryBuffers[idx] = proxy
		end
	end

	if idx < maxIdx then
		for i=idx, maxIdx do batteryBuffers[i] = nil end
	end

	if(#batteryBuffers > 0) then 
		if batteryBuffers[1].getBatteryCharge ~= nil then
			gtPowerVoltage = batteryBuffers[1].getOutputVoltage()
		else
			gtPowerVoltage = overrideVoltage
		end
	end
end

local function Init(_crafter, _ae, component, _overrideVoltage, _overrideAmperage)
	crafter = _crafter
	ae = _ae
	overrideVoltage = _overrideVoltage
	overrideAmperage = _overrideAmperage
	GetBatteries(component)
	print("Found "..#batteryBuffers.." battery buffers")
end


local function CalcAverage(updateRate, uptime)
	--local gtPowerDrain = batteryBuffers[1].getEUOutputAverage() --bat.getAverageElectricOutput()
	--local gtPowerSupply = batteryBuffers[1].getEUInputAverage() --bat.getAverageElectricInput()

	local data = batteryBuffers[1].getSensorInformation()
	if not data then return end
	local gtPowerSupply = parseFromSensorInfo(data[5])
	local gtPowerDrain = parseFromSensorInfo(data[6])

	local mult = math.max(updateRate,1/20)/5

	if gtPowerDrainAvg == nil then gtPowerDrainAvg = gtPowerDrain else
		gtPowerDrainAvg = gtPowerDrainAvg * (1-mult) + gtPowerDrain * (mult)
	end

	if gtPowerSupplyAvg == nil then gtPowerSupplyAvg = gtPowerSupply else
		gtPowerSupplyAvg = gtPowerSupplyAvg * (1-mult) + gtPowerSupply * (mult)
	end

	local diff  = gtPowerSupplyAvg - gtPowerDrainAvg
	if gtPowerIOAvg30sec == nil or uptime < 20 then gtPowerIOAvg30sec = diff else
		gtPowerIOAvg30sec = gtPowerIOAvg30sec * (1-mult/6) + diff * (mult/6)
	end
	if gtPowerIOAvg10min == nil or uptime < 20 then gtPowerIOAvg10min = diff else
		gtPowerIOAvg10min = gtPowerIOAvg10min * (1-mult/120) + diff * (mult/120)
	end
	if gtPowerIOAvg1hour == nil or uptime < 20 then gtPowerIOAvg1hour = diff else
		gtPowerIOAvg1hour = gtPowerIOAvg1hour * (1-mult/720) + diff * (mult/720)
	end
end

local function Draw(updateRate, uptime, cputime)
	local powerDrain = ae.getAvgPowerUsage()
	local powerSupply = ae.getAvgPowerInjection()
	local powerIdle = ae.getIdlePowerUsage()
	local powerColor = 0x00FF00
	local gtPowerMax = 0
	local gtPower = 0
	local gtPowerDrain = 0
	local gtPowerSupply = 0
	local gtPowerAmpMax = 0
	local gtPowerAmpUsed = 0
	local allbattery_info = {}

	if #batteryBuffers > 1 then
		for i=1, #batteryBuffers do
			local bat = batteryBuffers[i]
			--local data = batteryBuffers[i].getSensorInformation()
			--local pwr = unformatInt(data[3])
			--local pwrMax = unformatInt(data[4])
			local pwr = bat.getEUStored()
			local pwrMax = bat.getEUMaxStored()

			if bat.getBatteryCharge ~= nil then
				local amps = bat.getOutputAmperage()
				if amps and amps > 1 then
					for i=1,amps do
						pwr = pwr + bat.getBatteryCharge(i)
						pwrMax = pwrMax + bat.getMaxBatteryCharge(i)
					end
					gtPowerAmpMax = amps
				end
			else
				-- assume it's a gtnh multiblock with 64 amps out
				gtPowerAmpMax = overrideAmperage
			end

			local drain = bat.getEUOutputAverage() --bat.getAverageElectricOutput()
			local supply = bat.getEUInputAverage() --bat.getAverageElectricInput()

			gtPower = gtPower + pwr
			gtPowerMax = gtPowerMax + pwrMax
			gtPowerDrain = gtPowerDrain + drain
			gtPowerSupply = gtPowerSupply + supply


			local percent = math.floor(drain/supply*100+0.5)
			local color = 0x00FF00
			if percent == math.huge or percent > 10000 then
				percent = ">10000"
				color = 0xFF0000
			elseif percent <= 0 then
				percent = "0"
				color = 0x00FF00
			else
				if percent >= 100 then color = 0xFF0000
				elseif percent >= 75 then color = 0xFFFF00 end
			end
			allbattery_info[i] = {
				color,
				string.format("\t%s\t%s / %s\t\t(%s%%)",
					math.floor(pwr/pwrMax*100+0.5),
					formatInt(drain), formatInt(supply),
					percent
				)
			}
		end

		CalcAverage(updateRate, uptime)
	else
		--gtPower = batteryBuffers[1].getEUStored()
		--gtPowerMax = batteryBuffers[1].getEUMaxStored()
		--if gtPowerMax < -10^18 or gtPowerMax > 10^18 then
			local data = batteryBuffers[1].getSensorInformation()
			gtPower = parseFromSensorInfo(data[2]) -- + ((data[12]~=nil) and parseFromSensorInfo(data[12]) or 0)
			gtPowerMax = parseFromSensorInfo(data[3])
		--end
		gtPowerAmpMax = overrideAmperage
	end

	ret.gtPower = gtPower
	ret.gtPowerMax = gtPowerMax

	if(gtPowerSupplyAvg > highestEnergyIncome) then highestEnergyIncome = gtPowerSupplyAvg end
	if(gtPowerDrainAvg > highestEnergyDrain) then highestEnergyDrain = gtPowerDrainAvg end
	gtPowerAmpUsed = math.ceil(gtPowerDrainAvg / gtPowerVoltage)

	if(powerDrain >= powerSupply) then powerColor = 0xFF0000
	elseif(powerDrain >= powerSupply*0.75) then powerColor = 0xFFFF00 end

	clearTerminal()

	-- CPU Status
	local clr = 0x00FF00
	if crafter.cpustatus.activeCPUs >= crafter.cpustatus.maxCPUs then clr = 0xFFFF00
	elseif crafter.cpustatus.activeCPUs > math.ceil(crafter.cpustatus.totalCPUs*0.8) then clr = 0xFF0000 end
	printColor(clr,string.format("=== CPUs: OC/Allowed: %s/%s - Active/Total: %s/%s",
		crafter.cpustatus.activeCPUs,crafter.cpustatus.maxCPUs,
		crafter.cpustatus.activeCPUsTotal,crafter.cpustatus.totalCPUs
	))
	
	local slotsLeft = displayMax
	local function displayList(list, count, display)
		local idx = 0
		local ret = 0
		for k,v in pairs(list) do
			idx = idx + 1

			if display(k,v) then
				slotsLeft = slotsLeft - 1
				if slotsLeft <= 1 then
					local moreText = nil
					if count~=nil then
						if (count-idx)>1 then
							moreText = count-idx
						end
					else
						if next(list,k)~=nil and next(list,next(list,k))~=nil then
							moreText = "some"
						end
					end

					if moreText ~= nil then
						slotsLeft = slotsLeft - 1
						print("+ " .. moreText .. " others")
						return
					end
				end
			end
		end
	end

	if crafter.eAllRecipes.key then
		print(string.format("(%s/%s): %s, (%s/%s): %s",
			--[%s/%s] 
			--crafter.checkingAllItemsIdx,
			--crafter.checkingAllItemsTotal,
			crafter.eAllRecipes.idx,
			crafter.numberOfCraftData,
			string.sub(crafter.eAllRecipes.value.name,1,24),
			crafter.eCrafting.idx,
			crafter.cpustatus.activeCPUs,
			string.sub(crafter.eCrafting.value and crafter.eCrafting.value.name or "-",1,24)
		))
	end

	-- Currently Crafting
	if #crafter.currentlyCrafting > 0 then
		slotsLeft = slotsLeft - 1
		printColor(0x00FF00, "= Currently crafting:")
		displayList(crafter.currentlyCrafting, #crafter.currentlyCrafting, function(k,v) return v.events.displayStatus(v, cputime) end)
	end

	-- Waiting to Craft
	if #crafter.waitingToCraft > 0 and slotsLeft>2 then
		slotsLeft = slotsLeft - 1
		printColor(0x00FF00,"= Waiting to craft:")
		displayList(crafter.waitingToCraft, #crafter.waitingToCraft, function(k,v) return v.events.displayStatus(v, cputime) end)
	end

	-- Probably out of items
	if next(crafter.probablyOutOfItems) ~= nil then
		slotsLeft = slotsLeft - 2
		printColor(0xFF0000,"= Probably out of items:")
		local s,n = {}, 0
		for name, _ in pairs(crafter.probablyOutOfItems) do
			n = n + 1
			s[n] = name
		end
		s = table.concat(s,", ")
		local lines = math.ceil(#s/72)
		slotsLeft = slotsLeft - lines
		printColor(0xFFAA00, s)
	end

	-- Max restart amounts
	if next(crafter.maxRestartAmounts) ~= nil and slotsLeft>2 then
		slotsLeft = slotsLeft - 1
		printColor(0x00FF00,"= Max restart amounts:")
		displayList(crafter.maxRestartAmounts, nil, function(k,v) print(k .. ": " .. v .. "x") return true end)
	end

	-- Crafting error
	--print("Redstone frequency: "..emitRedstoneAt)

	printColor(powerColor,
		string.format("=== AE Power: %s (%s/%s) Idle: %s",
			math.floor(powerDrain/powerSupply*100).."%",
			formatInt(powerDrain),
			formatInt(powerSupply),
			math.floor(powerIdle)
		)
	)

	local color
	if(gtPower < gtPowerMax*0.10) then color = 0xFF0000
	elseif(gtPower < gtPowerMax*0.25) then color = 0xFFFF00
	else color = 0x00FF00 end

	-- GT Power

	-- make color blink if we use too many amps
	if gtPowerAmpUsed >= math.floor(gtPowerAmpMax*0.9) then
		warningBlink = not warningBlink
		if warningBlink then color = 0xFFFF00
		else color = 0xFF0000 end
	end
	printColor(color, string.format("= GT Power: %s\t%s / %s EU\t%s / %s A",
		math.floor(gtPower/gtPowerMax*100).."%",
		formatInt(gtPower),
		formatInt(gtPowerMax),
		gtPowerAmpUsed,
		gtPowerAmpMax
	))

	local percent = math.floor(gtPowerDrainAvg/gtPowerSupplyAvg*100+0.5)
	local color = 0x00FF00
	if percent == math.huge or percent > 10000 then
		percent = ">10000"
		color = 0xFF0000
	elseif percent <= 0 then
		percent = "0"
		color = 0x00FF00
	else
		if percent >= 100 then color = 0xFF0000
		elseif percent >= 75 then color = 0xFFFF00 end
	end
	printColor(color, string.format("Total -/+:\t%s / %s\t\t(%s%%)",
		formatInt(gtPowerDrainAvg),
		formatInt(gtPowerSupplyAvg),
		percent
	))

	-- all batteries
	if #allbattery_info > 1 then
		for i=1,#allbattery_info do 
			printColor(
				allbattery_info[i][1],
				(i==1 and "Buffers:" or "\t") .. allbattery_info[i][2]
			)
		end
	end

	-- Time to zero or full energy
	local timeToZero = "-"
	local seconds = 0
	--local powerDelta = gtPowerIOAvg30sec*20 --((gtPowerDrainAvg-gtPowerSupplyAvg)*20)
	local powerDelta = gtPowerIOAvg10min*20

	if powerDelta < 0 then
		seconds = tonumber(gtPower / math.abs(powerDelta))
		timeToZero = "Zero: "
	elseif powerDelta > 0 then
		seconds = tonumber((gtPowerMax - gtPower) / powerDelta)
		timeToZero = "Full: "
	end

	if seconds > 0 then
		if timeToZero == "Full: " and gtPowerMax > 10^18 then
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

	print(string.format("Highest -/+:\t%s / %s\t%s",
		formatInt(highestEnergyDrain).." ("..math.ceil(highestEnergyDrain/gtPowerVoltage).." A)",
		formatInt(highestEnergyIncome),
		timeToZero
	))
	printColor((uptime < 20 and 0x00FF00 or (uptime < 600 and 0x0000FF or 0xFFFFFF)),
		string.format(
			"Avg 10 min:\t%s\t1 hour:\t%s",
			formatInt(gtPowerIOAvg10min).." ("..math.ceil(gtPowerIOAvg10min/gtPowerVoltage).." A)",
			formatInt(gtPowerIOAvg1hour).." ("..math.ceil(gtPowerIOAvg1hour/gtPowerVoltage).." A)"
		)
	)

	-- control turbines
	--[[
	if gtPower < 80*10^9 and not turbinesOn then
		turbinesOn = true
		redstone.setBundledOutput(sides.left,colors.red,255)
	elseif gtPower > 100*10^9 and turbinesOn then
		turbinesOn = false
		redstone.setBundledOutput(sides.left,colors.red,0)
	end

	print(turbinesOn and "Turbines on" or "Turbines off")
	]]

	-- debug
	--[[
		printColor(0x00FF00, "DEBUG:")
		for i, msg in pairs(debugList) do
			print(i..": "..msg)
		end
		debugList = {}
	--]]--
end

ret = {
	Init = Init,
	CalcAverage = CalcAverage,
	Draw = Draw,
	batteryBuffers = batteryBuffers,
	gtPower = 0,
	gtPowerMax = 0
}
return ret