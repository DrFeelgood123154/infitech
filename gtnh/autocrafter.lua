
local cpustatus = {
	activeCPUsTotal = 0,
	activeCPUs = 0,
	activeUnimportantCPUs = 0,
	totalCPUs = 0,
	maxCPUs = 16 -- edit this if necessary
}
local waitBeforeCrafting = 0 -- seconds
local autocraftData = {}

local waitingToCraft = {}
local waitingToCraftLookup = {}
local currentlyCrafting = {}
local currentlyCraftingLookup = {}
local maxRestartAmounts = {}
local probablyOutOfItems = {}
local eAllRecipes
local eCrafting
local eAllItems
local computer
local ae
local ret
local craftTime = 1

local defaultAutocraftItem = {
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
	events = {
		shouldCraft = function(data,ae,cpustatus)
			if data.aeAmount < data.threshold or (data.maxCraftBound and data.aeAmount < data.keepStocked) then
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
			local amount = data.keepStocked - data.aeAmount
			
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
			data.amountAtStart = data.aeAmount
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
			if data.maxCraftBound and data.aeAmount < data.keepStocked then
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

			if data.restartAmount > 0 and computer.uptime()-data.startedAt > ret.numberOfCraftData * craftTime * 3 then
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
					math.floor(math.max(0,(data.amountToCraft or data.keepStocked) - (data.aeAmount-(data.amountAtStart or 0)))),
					data.name,
					err
				)
			)

			return true
		end,
	},
	aeAmount = 0,
	threshold = 32,
	keepStocked = 64,
	name = "-default-",
	maxCraft = 64,
	waitToCraft = nil,
	currentlyCrafting = false,
}

local function LoadAutocraftData()
	package.loaded.ac_data = nil
	autocraftData = require("ac_data")

	ret.numberOfCraftData = 0
	for name, data in pairs(autocraftData) do
		--for k,v in pairs(defaultAutocraftItem) do
		--	if data[k] == nil then data[k] = v end
		--end
		ret.numberOfCraftData = ret.numberOfCraftData + 1

		data.currentlyCrafting = false
		data.name = name
		data.threshold = data.threshold or math.floor(data.keepStocked*0.75)
		data.maxCraft = data.maxCraft or data.keepStocked

		-- set default filter
		if not data.filter then
			data.filter = {
				label = name
			}
		end

		if not data.waitToCraft then data.waitToCraft = waitBeforeCrafting end
		setmetatable(data, {__index=defaultAutocraftItem})
		--autocraftData[string.format("%s;%s",data.filter.label,data.filter.fluid_label or "")] = data
		--print("loaded " .. data.name)
		--os.sleep(1)
	end

	printColor(0x00FF00, "Loaded "..ret.numberOfCraftData.." autocraft items")
end

local function enumerator(tbl)
	local enumer = {
		next = function(self, infl)
			self.idx = self.idx + 1
			self.key, self.value = next(tbl, self.key)
			if not self.key and not infl then
				self:reset()
			end
			return self.value
		end,
		reset = function(self)
			self.key = nil
			self.idx = 0
			return self:next(true)
		end,
		idx = 0
	}
	return enumer
end

local function Init(_ae, _computer, _craftTime)
	ae = _ae
	computer = _computer
	craftTime = _craftTime
	LoadAutocraftData()
	eAllRecipes = enumerator(autocraftData)
	eCrafting = enumerator(currentlyCrafting)
	--eAllItems = ae.allItems()

	ret.eAllRecipes = eAllRecipes
	ret.eCrafting = eCrafting
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

local function checkIfAdd(data)
	if not data then return end
	if not data.filter or (not data.filter.label and not data.filter.fluid_label) then 
		error("ITEM WITH NO FILTER: " .. data.name)
		return
	end

	local aeitem = ae.getItemsInNetwork(data.filter)
	if aeitem[1] ~= nil then
		data.aeAmount = math.floor(aeitem[1].size)
	else
		data.aeAmount = 0
	end

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
	if not data then return false end
	data.finishedAtTheSameTime = nil
	if data.currentlyCrafting and data.events.isFinished(data,ae,cpustatus) then
		data.events.finished(data,ae,cpustatus)
		data.currentlyCrafting = false
		removeFromBoth(data)
		data.finishedAtTheSameTime = true
		return true
	end
end

local function Autocrafting()
	local cpus = ae.getCpus()
	cpustatus.activeCPUsTotal = 0
	cpustatus.totalCPUs = cpus.n
	for i=1,cpus.n do
		if cpus[i].busy then 
			cpustatus.activeCPUsTotal = cpustatus.activeCPUsTotal + 1
		end
	end

	--[[
	local amount = 1
	local item
	repeat
		ret.checkingAllItemsIdx = ret.checkingAllItemsIdx + 1
		item = eAllItems()

		if item == nil then
			ret.checkingAllItemsTotal = ret.checkingAllItemsIdx
			ret.checkingAllItemsIdx = 1
			eAllItems = ae.allItems()
			item = eAllItems()
			if item == nil then break end
		end

		local key = string.format("%s;%s",item.label,item.fluid_label or "")
		if autocraftData[key] then
			autocraftData[key].aeAmount = item.size
		end

		amount = amount - 1
	until amount <= 0
	]]

	if checkIfComplete(eCrafting:next()) then
		checkIfAdd(eCrafting.value)
	else
		checkIfAdd(eAllRecipes:next())
	end
end

ret = {
	Init = Init,
	Autocrafting = Autocrafting,
	currentlyCrafting = currentlyCrafting,
	maxRestartAmounts = maxRestartAmounts,
	probablyOutOfItems = probablyOutOfItems,
	waitingToCraft = waitingToCraft,
	numberOfCraftData = 0,
	cpustatus = cpustatus,
	checkingAllItemsIdx = 0,
	checkingAllItemsTotal = 0
}
return ret