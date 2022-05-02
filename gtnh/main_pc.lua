local component = require("component")
local io = require("io")
local sr = require("serialization")
local text = require("text")
local term = require("term")
local computer = require("computer")
local sides = require("sides")
--local redstone = component.redstone
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
local sleepTime = 0.5
local drawTime = 0.5
local craftTime = 1
local startTime = computer.uptime()

--crafting
local cpustatus = {
	activeCPUsTotal = 0,
	activeCPUs = 0,
	activeUnimportantCPUs = 0,
	totalCPUs = 0,
	maxCPUs = 16 -- edit this if necessary
}
local waitBeforeCrafting = 0 -- seconds
local autocraftData = {}

local displayMax = 14
local waitingToCraft = {}
local waitingToCraftLookup = {}
local currentlyCrafting = {}
local currentlyCraftingLookup = {}
local maxRestartAmounts = {}
local debugList = {}
local currentlyCheckingName
local currentlyCheckingIdx = 0
local numberOfCraftData = 0
local probablyOutOfItems = {}

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

			if data.startCraftingAt == nil and data.waitToCraft > 0 then
				-- if startCraftingAt is nil, then set the end time
				data.startCraftingAt = computer.uptime() + data.waitToCraft
				return nil, "Waiting " .. data.waitToCraft .. "s"
			else
				--table.insert(debugList,"Waiting to craft " .. data.name .. " for "..math.max(0,math.floor((data.startCraftingAt-computer.uptime())*10+0.5)/10).." seconds")
				if not data.startCraftingAt or data.startCraftingAt <= computer.uptime() then
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
		
		if data.finishedAtTheSameTime and data.restartAmount > 0 then
			-- if it's restarting immediately, skip maxcraft checking and double the amount
			new_amount = new_amount * data.restartAmount
			maxRestartAmounts[data.name] = math.max(maxRestartAmounts[data.name] or 0,data.restartAmount)
		else
			data.restartAmount = 0
			if amount > new_amount then
				-- limited by maxCraft
				data.maxCraftBound = true
			end
		end

		amount = new_amount

		--table.insert(debugList,"Amount to craft: "..amount)
		if amount <= 0 then return false end -- uh oh something went wrong
		data.amountToCraft = amount
		data.amountAtStart = data.aeitem.size
		data.startedAt = computer.uptime()

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

		if data.restartAmount > 0 and computer.uptime()-data.startedAt > numberOfCraftData * craftTime * 3 then
			data.restartAmount = 0
			probablyOutOfItems[data.name] = true
		else
			data.restartAmount = (data.restartAmount or 0) + 2
			probablyOutOfItems[data.name] = nil
		end
	end,
	displayStatus = function(data)
		local clr = {
			["Unable to craft"] = 0xFF0000,
			["Missing recipe"] = 0xFF0000,
			["default"] = 0xFFFFFF,
			["restarted"] = 0xFF9900
		}
		local err = ""
		if data.error ~= nil then
			err = " (" .. data.error .. ")"
		end

		if (data.error == nil or data.error == "restarted") and data.restartAmount ~= nil and data.restartAmount > 0 then
			err = " (+" .. data.restartAmount .. "x)"
			data.error = "restarted"
		elseif data.error == nil and data.maxCraft < (data.amountToCraft or data.keepStocked) then
			err = " (max " .. data.maxCraft .. "x)"
		end

		-- Print status
		printColor(
			clr[data.error or "default"] or clr.default,
			string.format("%sx %s%s",
				math.floor(math.max(0,(data.amountToCraft or data.keepStocked) - (data.aeitem.size-(data.amountAtStart or 0)))),
				data.name,
				err
			)
		)

		return true
	end
}

local function LoadAutocraftData()
	package.loaded.ac_data = nil
	autocraftData = require("ac_data")

	numberOfCraftData = 0
	for name, data in pairs(autocraftData) do
		numberOfCraftData = numberOfCraftData + 1

		data.currentlyCrafting = false
		data.name = name
		data.threshold = data.threshold or math.floor(data.keepStocked*0.75)
		data.maxCraft = data.maxCraft or data.keepStocked
		data.aeitem = {size=0}

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
	printColor(0x00FF00, "Loaded "..numberOfCraftData.." autocraft items")
end
LoadAutocraftData()

local function enumerator(tbl)
	local enumer = {
		next = function(self)
			self.idx = self.idx + 1
			self.key, self.value = next(tbl, self.key)
			if not self.key or not self.value then
				self:reset()
			end
			return self.value
		end,
		reset = function(self)
			self.key = nil
			self.idx = 0
			return self:next()
		end,
		idx = 0
	}
	return enumer
end

local function updateCPUStatus(data,dir)
	cpustatus.activeCPUs = cpustatus.activeCPUs + dir
	cpustatus.activeCPUsTotal = cpustatus.activeCPUsTotal + dir
	if data.unimportant then
		cpustatus.activeUnimportantCPUs = cpustatus.activeUnimportantCPUs + dir
	end
end

local function pushCurrentlyCrafting(data)
	if currentlyCraftingLookup[data.name] then return end
	data.currentlyCrafting = true
	updateCPUStatus(data,1)
	table.insert(currentlyCrafting,data)
	currentlyCraftingLookup[data.name] = true
end

local function pushWaitingToCraft(data)
	if waitingToCraftLookup[data.name] then return end

	if data.error == "Missing recipe" then
		table.insert(waitingToCraft,data) -- put it at the end of the list
	else
		table.insert(waitingToCraft,1,data)
	end

	waitingToCraftLookup[data.name] = true
end

function removeFromCurrentlyCrafting(data)
	currentlyCraftingLookup[data.name] = nil
	for i=1,#currentlyCrafting do
		if currentlyCrafting[i] == data then
			updateCPUStatus(data,-1)
			table.remove(currentlyCrafting,i)
			break
		end
	end
end
function removeFromWaitingToCraft(data)
	waitingToCraftLookup[data.name] = nil
	for i=1,#waitingToCraft do
		if waitingToCraft[i] == data then
			table.remove(waitingToCraft,i)
			break
		end
	end
end
local function removeFromBoth(data)
	removeFromWaitingToCraft(data)
	removeFromCurrentlyCrafting(data)
end

local eAllRecipes = enumerator(autocraftData)
local eCrafting = enumerator(currentlyCrafting)
local function Autocrafting()
	local cpus = ae.getCpus()
	cpustatus.activeCPUsTotal = 0
	cpustatus.totalCPUs = cpus.n
	for i=1,cpus.n do
		if cpus[i].busy then 
			cpustatus.activeCPUsTotal = cpustatus.activeCPUsTotal + 1
		end
	end

	local function checkIfAdd(data)
		local aeitem = ae.getItemsInNetwork(data.filter)
		if aeitem[1] ~= nil then
			aeitem = aeitem[1]
		else
			-- item not found, make some fake data and hope for the best
			aeitem = {
				size=0, damage=0, 
				label=data.filter.label or name, 
				name=data.filter.name or name, 
				maxDamage = 0, maxSize = 64, 
				hasTag = false
			}
		end
			
		data.aeitem = aeitem

		if not data.currentlyCrafting then
			local should, err = data.events.shouldCraft(data,ae,cpustatus)
			data.error = err
			if should == true then
				--table.insert(debugList,"Should start")
				local start, err = data.events.start(data,ae,cpustatus) 
				data.error = err
				if start then
					--table.insert(debugList,"Has started")
					pushCurrentlyCrafting(data)
					removeFromWaitingToCraft(data)
				else
					pushWaitingToCraft(data)
				end
			elseif should == nil then
				pushWaitingToCraft(data)
			else
				removeFromBoth(data)
			end
		end
	end
	local function checkIfComplete(data)
		data.finishedAtTheSameTime = nil
		if data.currentlyCrafting and data.events.isFinished(data,ae,cpustatus) then
			--table.insert(debugList,"Finished")
			data.events.finished(data,ae,cpustatus)
			data.currentlyCrafting = false
			removeFromBoth(data)
			data.finishedAtTheSameTime = true
			return true
		end
	end

	if checkIfComplete(eCrafting:next()) then
		checkIfAdd(eCrafting.value)
	elseif checkIfComplete(eAllRecipes:next()) then
		checkIfAdd(eAllRecipes.value)
	end
end

--local function cpuInit()

	--[[
	local function getLbl(item)
		if item.fluid_label then
			return item.fluid_label .. " fluid"
		else
			return item.label
		end
	end

	print("Checking recipes currenly crafting")
	local items = {}
	for i=1,cpus.n do
		if cpus[i].busy and cpus[i].cpu then
			local item = cpus[i].cpu.finalOutput()
			if item then
				items[#items+1] = {item,cpus[i]}
			end
		end
	end

	-- get currently crafting
	local idx=0
	for k,v in pairs(autocraftData) do
		idx=idx+1
		local isCraftingThisItem = true
		local itemIdx = 0

		for k2, itemcpu in pairs(items) do
			local item, cpu = itemcpu[1], itemcpu[2]
			for filterKey, filterValue in pairs(v.filter) do
				if item[filterKey] ~= filterValue then
					isCraftingThisItem = false
					break
				end
			end
			if isCraftingThisItem then
				items[k2] = nil
				break
			end
		end
		if isCraftingThisItem then
			pushCurrentlyCrafting(v)
			v.amountToCraft = v.keepStocked
			v.amountAtStart = 0
			v.startedAt = computer.uptime()
			v.craftingStatus = {isDone = function() return not cpu.isBusy() end}
			v.craftingStatus.isCanceled = v.craftingStatus.isDone
			if not next(items) then break end
		end
	end
	items = nil
	]]
--end
--cpuInit()

--gt
local batteryBuffers = {}
local highestEnergyIncome = 0
local highestEnergyDrain = 0
function GetBatteries()
	batteryBuffers = {}
	for id, what in component.list("battery") do
		table.insert(batteryBuffers, component.proxy(id))
	end
	for id, what in component.list("gt_machine") do
		local proxy = component.proxy(id)
		if proxy.getEUOutputAverage and 
			proxy.getEUInputAverage and 
			proxy.getEUStored and 
			proxy.getEUMaxStored then
				table.insert(batteryBuffers, proxy)
		end
	end
end
GetBatteries()
print("Found "..#batteryBuffers.." battery buffers")

-- HARDCODED VALUES IN CASE OF GT_MACHINE MULTIBLOCK
local hardCodedVoltage = 32768
local hardCodedAmperage = 64

function formatInt(i)
	if i > 10^18 then return "battery goes brr" end
	local neg = i<0
	i = math.floor(math.abs(i))
	return (neg and "-" or "") .. (tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", ""))
end
function unformatInt(i)
	local temp = string.gsub(i,"[^%d]","")
	return tonumber(temp)
end

local gtPowerVoltage = 0
if(#batteryBuffers > 0) then 
	if batteryBuffers[1].getBatteryCharge ~= nil then
		gtPowerVoltage = batteryBuffers[1].getOutputVoltage()
	else
		gtPowerVoltage = hardCodedVoltage
	end
end

local turbinesOn = false
local warningBlink = false
local gtPowerDrainAvg = nil
local gtPowerSupplyAvg = nil
local gtPowerIOAvg30sec = nil
local gtPowerIOAvg10min = nil
local gtPowerIOAvg1hour = nil
local function Draw()
	local uptime = computer.uptime()-startTime
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
				gtPowerAmpMax = hardCodedAmperage
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

		local sleepMult = 0.1 / sleepTime

		if gtPowerDrainAvg == nil then gtPowerDrainAvg = gtPowerDrain else
			gtPowerDrainAvg = gtPowerDrainAvg * (1-sleepMult) + gtPowerDrain * sleepMult
		end

		if gtPowerSupplyAvg == nil then gtPowerSupplyAvg = gtPowerSupply else
			gtPowerSupplyAvg = gtPowerSupplyAvg * (1-sleepMult) + gtPowerSupply * sleepMult
		end

		local diff  = gtPowerSupplyAvg - gtPowerDrainAvg

		if gtPowerIOAvg30sec == nil or uptime < 20 then gtPowerIOAvg30sec = diff else
			gtPowerIOAvg30sec = gtPowerIOAvg30sec * (1-1/(30*sleepMult)) + diff * (1/(30*sleepMult))
		end
		if gtPowerIOAvg10min == nil or uptime < 20 then gtPowerIOAvg10min = diff else
			gtPowerIOAvg10min = gtPowerIOAvg10min * (1-1/(600*sleepMult)) + diff * (1/(600*sleepMult))
		end
		if gtPowerIOAvg1hour == nil or uptime < 20 then gtPowerIOAvg1hour = diff else
			gtPowerIOAvg1hour = gtPowerIOAvg1hour * (1-1/(3600*sleepMult)) + diff * (1/(3600*sleepMult))
		end
	else
		gtPower = batteryBuffers[1].getEUStored()
		gtPowerMax = batteryBuffers[1].getEUMaxStored()
		gtPowerAmpMax = hardCodedAmperage
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
		return
	end

	if eAllRecipes.key then
		print(string.format("(%s/%s): %s, (%s/%s): %s",
			eAllRecipes.idx,
			numberOfCraftData,
			string.sub(eAllRecipes.key,1,24),
			eCrafting.idx,
			cpustatus.activeCPUs,
			string.sub(eCrafting.value and eCrafting.value.name or "-",1,24)
		))
	end

	-- Currently Crafting
	if #currentlyCrafting > 0 then
		slotsLeft = slotsLeft - 1
		printColor(0x00FF00, "= Currently crafting:")
		displayList(currentlyCrafting, #currentlyCrafting, function(k,v) return v.events.displayStatus(v) end)
	end


	-- Max restart amounts
	if next(maxRestartAmounts) ~= nil then
		slotsLeft = slotsLeft - 1
		printColor(0x00FF00,"= Max restart amounts:")
		displayList(maxRestartAmounts, nil, function(k,v) print(k .. ": " .. v .. "x") return true end)
	end

	if next(probablyOutOfItems) ~= nil then
		slotsLeft = slotsLeft - 2
		printColor(0xFF0000,"= Probably out of items:")
		local s,n = {}, 0
		for name, _ in pairs(probablyOutOfItems) do
			n = n + 1
			s[n] = name
		end
		printColor(0xFFAA00, table.concat(s,", "))
	end

	-- Waiting to Craft
	if #waitingToCraft > 0 then
		slotsLeft = slotsLeft - 1
		printColor(0x00FF00,"= Waiting to craft:")
		displayList(waitingToCraft, #waitingToCraft, function(k,v) return v.events.displayStatus(v) end)
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

	printColor(color, string.format("= GT Power: %s\t%s / %s EU\t%s / %s Amps",
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
	local powerDelta = gtPowerIOAvg30sec*20 --((gtPowerDrainAvg-gtPowerSupplyAvg)*20)

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

--redstone.setBundledOutput(sides.left,colors.red,0) -- reset when starting
if #batteryBuffers < 2 then sleepTime = 0 end

local nextDraw = computer.uptime() + drawTime
local nextCraft = computer.uptime() + craftTime
while(true) do
	local t = computer.uptime()

	if sleepTime == 0 then
		local gtPowerDrain = batteryBuffers[1].getEUOutputAverage() --bat.getAverageElectricOutput()
		local gtPowerSupply = batteryBuffers[1].getEUInputAverage() --bat.getAverageElectricInput()

		local seconds = 5
		local mult = 1/(20*seconds)

		if gtPowerDrainAvg == nil then gtPowerDrainAvg = gtPowerDrain else
			gtPowerDrainAvg = gtPowerDrainAvg * (1-mult) + gtPowerDrain * mult
		end

		if gtPowerSupplyAvg == nil then gtPowerSupplyAvg = gtPowerSupply else
			gtPowerSupplyAvg = gtPowerSupplyAvg * (1-mult) + gtPowerSupply * mult
		end

		local diff  = gtPowerSupplyAvg - gtPowerDrainAvg
		if gtPowerIOAvg30sec == nil or t - startTime < 20 then gtPowerIOAvg30sec = diff else
			gtPowerIOAvg30sec = gtPowerIOAvg30sec * (1-1/(30*20*seconds)) + diff * (1/(30*20*seconds))
		end
		if gtPowerIOAvg10min == nil or t - startTime < 20 then gtPowerIOAvg10min = diff else
			gtPowerIOAvg10min = gtPowerIOAvg10min * (1-1/(600*20*seconds)) + diff * (1/(600*20*seconds))
		end
		if gtPowerIOAvg1hour == nil or t - startTime < 20 then gtPowerIOAvg1hour = diff else
			gtPowerIOAvg1hour = gtPowerIOAvg1hour * (1-1/(3600*20*seconds)) + diff * (1/(3600*20*seconds))
		end
	end

	if t > nextDraw then
		nextDraw = t + drawTime
		Draw()
	end

	if t > nextCraft then
		nextCraft = t + craftTime
		Autocrafting()
	end
	os.sleep(sleepTime)
end
