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

local defaultColor = 0xFFFFFF
gpu.setForeground(defaultColor)

local function printColor(color, wat)
	gpu.setForeground(color)
	print(wat)
	gpu.setForeground(defaultColor)
end

-- general
local loopSleep = 1

--crafting
local maxCPUs = 4
local usedCPUs = 0
local activeUnimportantCPUs = 0
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
		-- }

	shouldCraft = function(data,ae,cpustatus)
		if data.aeitem.size < data.threshold then
			if data.unimportant and cpustatus.activeCPUsTotal-cpustatus.activeUnimportantCPUs > 0 then
				--table.insert(debugList,"Waiting to craft " .. data.name .. " because unimportant")
				return nil, "Unimportant"
			end

			if not data.important and cpustatus.activeCPUs > maxCPUs then
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
			return false
		end
	end,
	start = function(data,ae,cpustatus)
		local amount = data.keepStocked - data.aeitem.size
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
		-- reset some values
		data.startCraftingAt = nil
		data.craftStatus = nil
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

		-- Print status
		printColor(
			clr[data.error or "default"] or clr.default,
			string.format("%sx %s%s",
				math.max(0,(data.amountToCraft or data.keepStocked) - 
					(data.aeitem.size-(data.amountAtStart or 0))),
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
		data.threshold = data.threshold or data.keepStocked

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
	local cpustatus = {
		activeCPUsTotal = 0,
		activeCPUs = usedCPUs,
		activeUnimportantCPUs = activeUnimportantCPUs,
		CPUs = c.n
	}

	for i=1,c.n do
		if c[i].busy then 
			cpustatus.activeCPUsTotal = cpustatus.activeCPUsTotal + 1
		end
	end

	local function updateCPUStatus(data,dir)
		usedCPUs = usedCPUs + dir
		cpustatus.activeCPUs = usedCPUs
		if data.unimportant then
			activeUnimportantCPUs = activeUnimportantCPUs + dir
			cpustatus.activeUnimportantCPUs = activeUnimportantCPUs
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
  return tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end
function unformatInt(i)
	local temp = string.gsub(i,"[^%d]","")
	return tonumber(temp)
end

local gtPowerVoltage = 0
if(#batteryBuffers > 0) then gtPowerVoltage = batteryBuffers[1].getOutputVoltage() end

local gtPowerDrainAvg = 0
local gtPowerSupplyAvg = 0
function Draw()
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

	for i=1, #batteryBuffers do
		local data = batteryBuffers[i].getSensorInformation()
		gtPower = gtPower + unformatInt(data[3])
		gtPowerMax = gtPowerMax + unformatInt(data[4])
		gtPowerDrain = gtPowerDrain + batteryBuffers[i].getAverageElectricOutput()
		gtPowerSupply = gtPowerSupply + batteryBuffers[i].getAverageElectricInput()
		gtPowerAmpMax = gtPowerAmpMax + batteryBuffers[i].getOutputAmperage()
	end

	gtPowerDrainAvg = gtPowerDrainAvg * 0.8 + gtPowerDrain * 0.2
	gtPowerSupplyAvg = gtPowerSupplyAvg * 0.8 + gtPowerSupply * 0.2

	if(gtPowerSupplyAvg > highestEnergyIncome) then highestEnergyIncome = gtPowerSupplyAvg end
	if(gtPowerDrainAvg > highestEnergyDrain) then highestEnergyDrain = gtPowerDrainAvg end
	gtPowerAmpUsed = math.ceil(gtPowerDrainAvg / gtPowerVoltage)

	if(powerDrain >= powerSupply) then powerColor = 0xFF0000
	elseif(powerDrain >= powerSupply*0.75) then powerColor = 0xFFFF00 end

	term.clear()

	-- CPU Status
	if(usedCPUs == maxCPUs) then 
		gpu.setForeground(0xFF0000)
	else 
		gpu.setForeground(0x00FF00) 
	end
	print(usedCPUs.."/"..maxCPUs.." CPU")

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
	printColor(color, "=== GT power: "..math.floor(gtPower/gtPowerMax*100).."%")
	printColor(color, "Store:\t"..formatInt(gtPower).." EU / "..formatInt(gtPowerMax).." EU")
	if(gtPowerDrainAvg > gtPowerSupplyAvg) then color = 0xFF0000
	else color = 0x00FF00 end
	printColor(color, string.format("Out/In:\t%s / %s (%s)",
		formatInt(math.floor(gtPowerDrainAvg)),
		formatInt(math.floor(gtPowerSupplyAvg)),
		((math.floor(gtPowerSupplyAvg) > 0) and math.floor(gtPowerDrainAvg/gtPowerSupplyAvg*100) or "-").."%"
	))
	--amp
	if(gtPowerAmpUsed > gtPowerAmpMax*0.75) then color = 0xFFFF00
	else color = 0x00FF00 end

	printColor(color, string.format("Amps:\t%s / %s",
		gtPowerAmpUsed,
		gtPowerAmpMax
	))

	-- Time to zero or full energy
	local timeToZero = "-"
	local seconds = 0
	local powerDelta = ((gtPowerDrainAvg-gtPowerSupplyAvg)*20)

	if gtPowerDrainAvg > gtPowerSupplyAvg then
		seconds = tonumber(gtPower / powerDelta)
		timeToZero = "Time to zero energy: "
	elseif gtPowerDrainAvg < gtPowerSupplyAvg then
		seconds = tonumber((gtPowerMax - gtPower) / (-powerDelta))
		timeToZero = "Time to full energy: "
	end

	if seconds > 0 then
		local hours = math.floor(seconds/3600);
		local mins = math.floor(seconds/60 - (hours*60));
		local secs = math.floor(seconds - hours*3600 - mins *60);
		timeToZero = timeToZero .. string.format("%02.f:%02.f:%02.f", hours, mins, secs)
	else
		timeToZero = timeToZero .. "-"
	end

	print("Highest supply:\t"..formatInt(math.floor(highestEnergyIncome)).." \t"..timeToZero)
	print("Highest drain:\t"..formatInt(math.floor(highestEnergyDrain)).." ("..math.ceil(highestEnergyDrain/gtPowerVoltage).." A)")
end

while(true) do
	if(ae.getStoredPower() > 0) then
		Autocrafting()
	end

	Draw()
	os.sleep(loopSleep)
end
