local component = require("component")
local io = require("io")
local sr = require("serialization")
local text = require("text")
local term = require("term")
local computer = require("computer")
local sides = require("sides")
local redstone = component.redstone
local ae = component.me_interface
local gpu = component.gpu
local colors = require("colors")

local defaultColor = 0xFFFFFF
gpu.setForeground(defaultColor)

local function printColor(color, wat)
	gpu.setForeground(color)
	print(wat)
	gpu.setForeground(defaultColor)
end

-- general
local loopSleep = 0.5

--crafting
local cpustatus = {
	activeCPUsTotal = 0,
	activeCPUs = 0,
	activeUnimportantCPUs = 0,
	totalCPUs = 0,
	maxCPUs = 4 -- edit this if necessary
}
local waitBeforeCrafting = 30 -- seconds
local autocraftData = {}

local displayMax = 10
local waitingToCraft = {}
local currentlyCrafting = {}
local debugList = {}

local defaultEvents = {
	-- arguments to all these functions:
		-- data = the autocraftData[item] table itself
		-- ae = reference to ae object
		-- cpustatus = {
		--	activeCPUs = nr of ae crafting CPUs activated by the computer,
		--	activeCPUsTotal = nr of ae crafting CPUs currently active total,
		--	activeUnimportantCPUs = nr of ae crafting CPUs currently busy with unimportant recipes,
		--	totalCPUs = nr of total CPUs
		--	maxCPUs = max cpus allowed by config in main script
		-- }

	shouldCraft = function(data,ae,cpustatus)
		if data.aeitem.size < data.threshold or (data.maxCraftBound and data.aeitem.size < data.keepStocked) then
			if data.unimportant and cpustatus.activeCPUsTotal-cpustatus.activeUnimportantCPUs > 0 and cpustatus.totalCPUs-cpustatus.activeCPUsTotal < 10 then
				--table.insert(debugList,"Waiting to craft " .. data.name .. " because unimportant")
				return nil, "Unimportant"
			end

			if not data.important and cpustatus.activeCPUs >= cpustatus.maxCPUs then
				--table.insert(debugList,"Waiting to craft " .. data.name .. " because out of CPUs")
				return nil, "Not enough CPUs"
			end

			if data.startCraftingAt == nil then
				-- if startCraftingAt is nil, then set the end time
				data.startCraftingAt = computer.uptime() + data.waitToCraft
				return nil, "Waiting " .. data.waitToCraft .. "s"
			else
				--table.insert(debugList,"Waiting to craft " .. data.name .. " for "..math.max(0,math.floor((data.startCraftingAt-computer.uptime())*10+0.5)/10).." seconds")
				if data.startCraftingAt <= computer.uptime() then
					return true
				else
					local s = math.max(0,math.floor(data.startCraftingAt-computer.uptime()))
					return nil, "Waiting "..s.."s"
				end
			end
		else
			-- reset
			data.startCraftingAt = nil
			data.maxCraftBound = nil
			return false
		end
	end,
	start = function(data,ae,cpustatus)
		local amount = data.keepStocked - data.aeitem.size
		local new_amount = math.min(data.maxCraft,amount)

		if amount > new_amount then
			-- limited by maxCraft
			data.maxCraftBound = true
		end

		amount = new_amount

		--table.insert(debugList,"Amount to craft: "..amount)
		if amount <= 0 then return false end -- uh oh something went wrong
		data.amountToCraft = amount
		data.amountAtStart = data.aeitem.size

		local craftable = ae.getCraftables(data.filter)
		if craftable[1] ~= nil then
			--table.insert(debugList,"Craftable found")
			craftable = craftable[1]

			data.craftStatus = craftable.request(amount)
			if data.craftStatus.isCanceled() then
				return false, "Unable to craft"
			else
				return true
			end
		end

		return false, "Missing recipe"
	end,
	isFinished = function(data,ae,cpustatus)
		return data.craftStatus and (data.craftStatus.isDone() or data.craftStatus.isCanceled())
	end,
	finished = function(data,ae,cpustatus)
		if data.maxCraftBound and data.aeitem.size < data.keepStocked then
			-- Start quicker next time
			data.startCraftingAt = computer.uptime() + data.waitToCraft * 0.5
		else
			-- reset some values
			data.startCraftingAt = nil
			data.maxCraftBound = nil
		end

		data.craftStatus = nil
		data.amountToCraft = nil
		data.amountAtStart = nil
	end,
	displayStatus = function(data)
		local clr = {
			["Unable to craft"] = 0xFF0000,
			["Missing recipe"] = 0xFF0000,
			["default"] = 0xFFFFFF
		}
		local err = ""
		if data.error ~= nil then
			err = " (" .. data.error .. ")"
		end

		if err == "" and data.maxCraft < (data.amountToCraft or data.keepStocked) then
			err = " (max " .. data.maxCraft .. "x)"
		end

		-- Print status
		printColor(
			clr[data.error or "default"] or clr.default,
			string.format("%sx %s%s",
				math.max(0,(data.amountToCraft or data.keepStocked) - (data.aeitem.size-(data.amountAtStart or 0))),
				data.name,
				err
			)
		)
	end
}

local function LoadAutocraftData()
	package.loaded.ac_data = nil
	autocraftData = require("ac_data")

	local i = 0
	for name, data in pairs(autocraftData) do
		i = i + 1

		data.currentlyCrafting = false
		data.name = name
		data.threshold = data.threshold or math.floor(data.keepStocked*0.75)
		data.maxCraft = data.maxCraft or data.keepStocked

		-- Set default events
		if not data.events then 
			data.events = defaultEvents
		else
			for k,v in pairs(defaultEvents) do
				if not data.events[k] then data.events[k] = v end
			end
		end
		
		-- set default filter
		if not data.filter then
			data.filter = {
				label = name
			}
		end

		if not data.waitToCraft then data.waitToCraft = waitBeforeCrafting end
	end
	printColor(0x00FF00, "Loaded "..i.." autocraft items")
end
LoadAutocraftData()

local function Autocrafting()
	currentlyCrafting = {}
	waitingToCraft = {}
	debugList = {}

	local c = ae.getCpus()
	cpustatus.activeCPUsTotal = 0
	cpustatus.totalCPUs = c.n

	for i=1,c.n do
		if c[i].busy then 
			cpustatus.activeCPUsTotal = cpustatus.activeCPUsTotal + 1
		end
	end

	local function updateCPUStatus(data,dir)
		cpustatus.activeCPUs = cpustatus.activeCPUs + dir
		cpustatus.activeCPUsTotal = cpustatus.activeCPUsTotal + dir
		if data.unimportant then
			cpustatus.activeUnimportantCPUs = cpustatus.activeUnimportantCPUs + dir
		end
	end

	local function pushCurrentlyCrafting(data)
		table.insert(currentlyCrafting,data)
	end

	local function pushWaitingToCraft(data)
		if data.error == "Missing recipe" then
			table.insert(waitingToCraft,data) -- put it at the end of the list
		else
			table.insert(waitingToCraft,1,data)
		end
	end

	for name, data in pairs(autocraftData) do
		--table.insert(debugList,"checking: " .. item)
		local aeitem = ae.getItemsInNetwork(data.filter)
		if aeitem[1] ~= nil then
			aeitem = aeitem[1]
		else
			-- item not found, make some fake data and hope for the best
			aeitem = {
				size = 0, damage=0, 
				label=data.filter.label or name, 
				name=data.filter.name or name, 
				maxDamage = 0, maxSize = 64, 
				hasTag = false
			}
		end
			
		data.aeitem = aeitem
		--table.insert(debugList,"item name: " .. data.filter.label .. ", count: " .. aeitem.size)

		if not data.currentlyCrafting then
			local should, err = data.events.shouldCraft(data,ae,cpustatus)
			data.error = err
			if should == true then
				--table.insert(debugList,"Should start")
				local start, err = data.events.start(data,ae,cpustatus) 
				data.error = err
				if start then
					--table.insert(debugList,"Has started")
					data.currentlyCrafting = true

					updateCPUStatus(data,1)
					pushCurrentlyCrafting(data)
				else
					pushWaitingToCraft(data)
				end
			elseif should == nil then
				pushWaitingToCraft(data)
			end
		else
			if data.events.isFinished(data,ae,cpustatus) then
				--table.insert(debugList,"Finished")
				data.events.finished(data,ae,cpustatus)
				data.currentlyCrafting = false
				updateCPUStatus(data,-1)
			else
				pushCurrentlyCrafting(data)
			end
		end

	end
end

--gt
local batteryBuffers = {}
local highestEnergyIncome = 0
local highestEnergyDrain = 0
function GetBatteries()
	batteryBuffers = {}
	for id, what in component.list("battery") do
		table.insert(batteryBuffers, component.proxy(id))
	end
end
GetBatteries()
print("Found "..#batteryBuffers.." battery buffers")

function formatInt(i)
	if i > 10^18 then return "battery goes brr" end
	return (tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", ""))
end
function unformatInt(i)
	local temp = string.gsub(i,"[^%d]","")
	return tonumber(temp)
end

local gtPowerVoltage = 0
if(#batteryBuffers > 0) then gtPowerVoltage = batteryBuffers[1].getOutputVoltage() end

local turbinesOn = false
local warningBlink = false
local gtPowerDrainAvg = 0
local gtPowerSupplyAvg = 0
local function Draw()
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

	for i=1, #batteryBuffers do
		local bat = batteryBuffers[i]
		--local data = batteryBuffers[i].getSensorInformation()
		--local pwr = unformatInt(data[3])
		--local pwrMax = unformatInt(data[4])
		local pwr = bat.getEUStored()
		local pwrMax = bat.getEUMaxStored()
		for i=1,bat.getOutputAmperage() do
			pwr = pwr + bat.getBatteryCharge(i)
			pwrMax = pwrMax + bat.getMaxBatteryCharge(i)
		end

		local drain = bat.getEUOutputAverage() --bat.getAverageElectricOutput()
		local supply = bat.getEUInputAverage() --bat.getAverageElectricInput()

		gtPower = gtPower + pwr
		gtPowerMax = gtPowerMax + pwrMax
		gtPowerDrain = gtPowerDrain + drain
		gtPowerSupply = gtPowerSupply + supply
		gtPowerAmpMax = gtPowerAmpMax + bat.getOutputAmperage()

		if #batteryBuffers > 1 then
			local percent = math.floor(drain/supply*100+0.5)
			local clr = 0x00FF00
			if (drain == 0 and supply == 0) or 
				percent == math.huge or percent < 0 or percent > 10000 then
				percent = "-"
			else
				if percent >= 100 then clr = 0xFF0000
				elseif percent >= 75 then clr = 0xFFFF00 end
			end
			allbattery_info[i] = {
				clr,
				string.format("\t%s\t%s / %s\t\t(%s)",
					math.floor(pwr/pwrMax*100+0.5).."%",
					formatInt(drain), formatInt(supply),
					percent .. "%"
				)
			}
		end
	end

	if gtPowerDrainAvg == 0 then gtPowerDrainAvg = gtPowerDrain else
		gtPowerDrainAvg = gtPowerDrainAvg * 0.6 + gtPowerDrain * 0.4
	end

	if gtPowerSupplyAvg == 0 then gtPowerSupplyAvg = gtPowerSupply else
		gtPowerSupplyAvg = gtPowerSupplyAvg * 0.6 + gtPowerSupply * 0.4
	end

	if(gtPowerSupplyAvg > highestEnergyIncome) then highestEnergyIncome = gtPowerSupplyAvg end
	if(gtPowerDrainAvg > highestEnergyDrain) then highestEnergyDrain = gtPowerDrainAvg end
	gtPowerAmpUsed = math.ceil(gtPowerDrainAvg / gtPowerVoltage)

	if(powerDrain >= powerSupply) then powerColor = 0xFF0000
	elseif(powerDrain >= powerSupply*0.75) then powerColor = 0xFFFF00 end

	term.clear()

	-- CPU Status
	local clr = 0x00FF00
	if cpustatus.activeCPUs >= cpustatus.maxCPUs then clr = 0xFFFF00
	elseif cpustatus.activeCPUs > math.ceil(cpustatus.totalCPUs*0.8) then clr = 0xFF0000 end
	printColor(clr,string.format("=== CPUs: OC/Allowed: %s/%s - Active/Total: %s/%s",
		cpustatus.activeCPUs,cpustatus.maxCPUs,
		cpustatus.activeCPUsTotal,cpustatus.totalCPUs
	))

	-- debug
	--[[
		printColor(0x00FF00, "DEBUG:")
		for i, msg in pairs(debugList) do
			print(i..": "..msg)
		end
	--]]--
	
	local displaySlotsLeft = displayMax
	local function displayList(list)
		for k,v in pairs(list) do
			if displaySlotsLeft - ((#list-k)>0 and 1 or 0) <= 0 then
				if k < #list then
					print("+ " .. (#list - k) .. " others")
					displaySlotsLeft = displaySlotsLeft - 1
				end
				break
			end
			displaySlotsLeft = displaySlotsLeft - 1
			local s = v.events.displayStatus(v)
			if s then print(s) end
		end
	end

	-- Currently Crafting
	if #currentlyCrafting > 0 then
		printColor(0x00FF00, "= Currently crafting:")
		displayList(currentlyCrafting)
	end

	-- Waiting to Craft
	if #waitingToCraft > 0 then
		printColor(0x00FF00,"= Waiting to craft:")
		displayList(waitingToCraft)
	end

	-- Crafting error
	--print("Redstone frequency: "..emitRedstoneAt)

	-- AE Power
	--[[if(ae.getStoredPower() == 0) then
	gpu.setForeground(0xFF0000)
	print("!!! NO POWER IN AE !!!")
	gpu.setForeground(0xFFFFFF)
	end]]--

	printColor(powerColor,
		string.format("=== AE Power: %s (%s/%s) Idle: %s",
			math.floor(powerDrain/powerSupply*100).."%",
			math.floor(powerDrain),
			math.floor(powerSupply),
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

	printColor(color, string.format("= GT Power: %s\t%s / %s EU\t%s / %s Amps",
		math.floor(gtPower/gtPowerMax*100).."%",
		formatInt(gtPower),
		formatInt(gtPowerMax),
		gtPowerAmpUsed,
		gtPowerAmpMax
	))

	local percent = math.floor(gtPowerDrainAvg/gtPowerSupplyAvg*100+0.5)
	local color = 0x00FF00
	if (gtPowerDrainAvg == 0 and gtPowerSupplyAvg == 0) or 
		percent == math.huge or percent < 0 or percent > 10000 then
		percent = "-"
	else
		if percent >= 100 then color = 0xFF0000
		elseif percent >= 75 then color = 0xFFFF00 end
	end
	printColor(color, string.format("Total:\t\t%s / %s\t\t(%s)",
		formatInt(math.floor(gtPowerDrainAvg)),
		formatInt(math.floor(gtPowerSupplyAvg)),
		percent.."%"
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
	local powerDelta = ((gtPowerDrainAvg-gtPowerSupplyAvg)*20)

	if gtPowerDrainAvg > gtPowerSupplyAvg then
		seconds = tonumber(gtPower / powerDelta)
		timeToZero = "Zero: "
	elseif gtPowerDrainAvg < gtPowerSupplyAvg then
		seconds = tonumber((gtPowerMax - gtPower) / (-powerDelta))
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

	print(string.format("Highest drain/supply:\t%s/%s\t%s",
		formatInt(math.floor(highestEnergyDrain)).." ("..math.ceil(highestEnergyDrain/gtPowerVoltage).." A)",
		formatInt(math.floor(highestEnergyIncome)),
		timeToZero
	))

	-- control turbines
	if gtPower < 80*10^9 and not turbinesOn then
		turbinesOn = true
		redstone.setBundledOutput(sides.left,colors.red,255)
	elseif gtPower > 100*10^9 and turbinesOn then
		turbinesOn = false
		redstone.setBundledOutput(sides.left,colors.red,0)
	end

	print(turbinesOn and "Turbines on" or "Turbines off")
end

redstone.setBundledOutput(sides.left,colors.red,0) -- reset when starting
while(true) do
	if(ae.getStoredPower() > 0) then
		Autocrafting()
	end

	Draw()
	os.sleep(loopSleep)
end
