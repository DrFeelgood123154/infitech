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

function printColor(color, wat)
	gpu.setForeground(color)
	print(wat)
	gpu.setForeground(defaultColor)
end

-- general
local loopSleep = 1
local lastError = ""
local emitRedstoneAt = 0 -- frequency, do nothing if 0

--crafting
local maxCPUs = 4
local usedCPUs = 0
local waitBeforeCrafting = 30 -- seconds
local autocraftData = {}
local waitingToCraftMax = 3 -- limit array size
local waitingToCraft = {}
local currentlyCraftingMax = 3 -- limit array size
local currentlyCrafting = {}
local lastItemsRequestedSize = 5
local lastItemsRequested = {}

function LoadAutocraftData()
	package.loaded.autocraft = nil
	autocraftData = require("ac_data")
	local i = 0
	for k,v in pairs(autocraftData) do
		i = i+1
		v.currentlyCrafting = 0
		v.craftBegin = nil
		if(v.waitToCraft == nil) then v.waitToCraft = waitBeforeCrafting end
	end
	printColor(0x00FF00, "Loaded "..i.." autocraft items")
end
LoadAutocraftData()

function Autocrafting()
   lastError = ""
   currentlyCrafting = {}
   waitingToCraft = {}
   for item, data in pairs(autocraftData) do
      local filter = {}
      if(data.damage ~= 0) then filter["damage"] = data.damage end
      if(data.name ~= "-") then filter["name"] = data.name end
      if(data.label ~= "-") then filter["label"] = data.label end

      local toCraft = 0
      local craft = false
		if(data.condition == nil) then
			local aeitems = ae.getItemsInNetwork(filter)
			local stored = 0
			if(aeitems[1] ~= nil) then stored = aeitems[1].size end
			toCraft = data.keepStocked - stored
			craft = toCraft > data.threshold
		else
			if(data.condition.type == "moreThan") then
				local aeItems = ae.getItemsInNetwork(data.condition.filter)
				if(aeItems[1] ~= nil and aeItems[1].size > data.condition.quantity) then
					if(data.condition.materials ~= nil) then
						toCraft = math.floor((aeItems[1].size - data.condition.quantity)/data.condition.materials)
					else
						toCraft = 1
					end
					craft = true
				end
			end
		end
		-- request
		local waitDelta = 0 -- time left to ok craft
		if(craft) then
			if(data.craftBegin == nil) then data.craftBegin = computer.uptime() end
			waitDelta = data.craftBegin+data.waitToCraft - computer.uptime()
			if(data.wait == nil) then waitDelta = 0 end
			if(waitDelta > 0) then
				-- whatever
			elseif(data.redstoneFrequency == nil) then
				local craftable = ae.getCraftables(filter)
				if(#craftable > 0) then
					if(usedCPUs < maxCPUs and data.currentlyCrafting == 0) then
						data.craftStatus = craftable[1].request(toCraft)
						usedCPUs = usedCPUs + 1
						data.currentlyCrafting = toCraft
						if(not data.craftStatus.isCanceled()) then
							local last = lastItemsRequested[#lastItemsRequested]
							if(last ~= nil and last.what == item) then last.qt = last.qt + toCraft
							else table.insert(lastItemsRequested, {what=item,qt=toCraft})
							end
							if(#lastItemsRequested > lastItemsRequestedSize) then table.remove(lastItemsRequested, 1) end
						end
					end
				elseif(#craftable == 0) then
					lastError = "No crafting recipe available for "..item
					lastError = lastError .. sr.serialize(filter) .. "\n" .. sr.serialize(craftable)
				end
			elseif(data.redstoneFrequency ~= nil and emitRedstoneAt == 0) then
				emitRedstoneAt = data.redstoneFrequency
				data.currentlyCrafting = toCraft
			end
			-- add to queue
			if(data.currentlyCrafting == 0 and #waitingToCraft < waitingToCraftMax) then
				if(waitDelta > 0) then
					table.insert(waitingToCraft, toCraft.." "..item.."("..math.floor(waitDelta).."s)")
				else
					table.insert(waitingToCraft, toCraft.." "..item)
				end
			end
		end
		-- check craft status
		if(data.redstoneFrequency == nil) then
			if(data.craftStatus == nil) then
				data.currentlyCrafting = 0
			elseif(data.craftStatus.isDone() or data.craftStatus.isCanceled()) then
				if(not data.craftStatus.isCanceled()) then data.craftBegin = nil end
				data.currentlyCrafting = 0
				data.craftStatus = nil
				usedCPUs = usedCPUs - 1
			elseif(#currentlyCrafting < currentlyCraftingMax) then
				table.insert(currentlyCrafting, data.currentlyCrafting.." "..item)
			end
		else
			if(emitRedstoneAt == data.redstoneFrequency) then
				table.insert(currentlyCrafting, data.currentlyCrafting.." "..item)
				if(data.keepStocked ~= nil and stored ~= nil and stored >= data.keepStocked) then
					data.currentlyCrafting = 0
					emitRedstoneAt = 0
				end
			else
				data.currentlyCrafting = 0
			end
		end
	end -- loop?
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

	-- Last Crafts
	--[[
		printColor(0x00FF00, "Last crafts:")
		for i, wat in pairs(lastItemsRequested) do
		print(wat.qt.." "..wat.what)
		end
	]]--
	
	-- Currently Crafting
	if #currentlyCrafting > 0 then
		printColor(0x00FF00, "= Currently crafting:")

		local i = 0
		for k,v in pairs(currentlyCrafting) do
			print(v)
			i = i+1
			if(i>4) then break end
		end
	end

	-- Waiting to Craft
	if(#waitingToCraft > 0) then
		printColor(0x00FF00,"= Waiting to craft:")
		for k,v in pairs(waitingToCraft) do print(v) end
	end

	-- Crafting error
	--print("Redstone frequency: "..emitRedstoneAt)
	if(lastError ~= "") then
		printColor(0xFF0000,lastError)
	end

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
		((gtPowerSupplyAvg > 0) and math.floor(gtPowerDrainAvg/gtPowerSupplyAvg*100) or "-").."%"
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
		seconds = tonumber((gtPowerMax - gtPower) / powerDelta)
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

	print("Highest supply:\t"..formatInt(highestEnergyIncome).." \t"..timeToZero)
	print("Highest drain:\t"..formatInt(highestEnergyDrain).." ("..math.ceil(highestEnergyDrain/gtPowerVoltage).." A)")
end

while(true) do
	emitRedstoneAt = 0
	if(ae.getStoredPower() > 0) then
	Autocrafting()
	end

	if(emitRedstoneAt ~= 0) then
		redstone.setWirelessFrequency(emitRedstoneAt)
		redstone.setWirelessOutput(true)
	else
		redstone.setWirelessOutput(false)
	end
   Draw()
   os.sleep(loopSleep)
end
