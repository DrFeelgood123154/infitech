--[[

	Data structure

	autocraftData[ name of item ] = {
		filter = { -- filter used by AE to find the item. If unspecified, uses the name of the item from the key of autocraftData in place of filter.label
			name = "string",
			damage = 0,
			label = "string"
		},

		-- fixed values (cannot be changed, overwritten by computer)
		name = "-", -- will always contain the same value as the key of the table
		aeitem = nil, -- reference to aeitem object
		error = "string", -- error message set by one of the events or other. should be displayed in displayStatus

		-- options
		keepStocked = 1000, -- keep this many in storage,
		threshold = 100, -- will only begin crafting once number of items drops below this number. If unspecified, defaults to equal math.floor(keepStocked*0.75)
		maxCraft = nil, -- max amount of items to craft in one go (before waiting waitToCraft*0.5 amount of time to check again). default is equal to keepStocked
		redstoneFrequency = nil, -- Emit this redstone signal to craft instead of crafting from ae. useful for powered spawners
		waitToCraft = nil, -- wait this many seconds before starting to craft, default 30
		important = false, -- if true, will always craft, ignoring the number of CPUs in use
		unimportant = false, -- if true, will only craft if nothing else is being crafted (except other unimportant crafts),
							 -- or if the number of available CPUs is greater 10

		events = {  -- optional table of events
					-- keep in mind overriding these functions will make your code 
					-- ignore some or all of the settings above (see default events in main file)


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

			shouldCraft = function(data,ae,cpustatus),
				-- if specified, is used to check whether or not crafting should begin instead of checking keepStocked/threshold/whatever
				-- return: true = yes
				--		   false = no
				--		   nil = waiting for waitToCraft or something

				-- return 2: Optional string error message
			
			start = function(data,ae),
				-- if specified, is called when crafting begins instead of telling ae to start the craft
				-- return true = start successful
				--		  false = start unsuccessfull, probably waiting for resources
			
				-- return 2: Optional string error message

			isFinished = function(data,ae),
				-- if specified, is called to check if crafting is considered "finished" instead of comparing stocked item counts
				-- return true to tell it to stop crafting

			finished = function(data,ae),
				-- if specified, is called when the crafting is finished
				-- no return value, crafting is always considered finished

			displayStatus = function(data),
				-- called every time the item is displayed on screen
				-- return: string to print (OR return nothing and instead print it yourself)
		}
	}

]]--

local autocraftData = {}

local NORMAL = 1
local IMPORTANT = 2
local UNIMPORTANT = 3

local function addGTItem(name,filter,priority,amount,threshold,maxCraft)
	filter = filter or {label=name}
	priority = priority or NORMAL
	amount = amount or ({[NORMAL]=500,[IMPORTANT]=1000,[UNIMPORTANT]=4000})[priority]
	threshold = threshold or math.floor(amount * ({[NORMAL]=0.25,[IMPORTANT]=0.5,[UNIMPORTANT]=0.25})[priority])
	maxCraft = maxCraft or ({[UNIMPORTANT]=256})[priority]
	autocraftData[name] = {
		filter = filter,
		keepStocked = amount,
		threshold = threshold,
		important = priority == IMPORTANT,
		unimportant = priority == UNIMPORTANT,
		maxCraft = maxCraft
	}
	return autocraftData[name]
end

--[[
local function basicFilter(label, prefix)
	prefix = prefix or "01"
	return {label = "gt.metaitem." .. prefix .. "." .. label .. ".name"}
end
]]
local function stainlessCellFilter(fluid)
	return {label = "Large Stainless Steel Fluid Cell", fluid_name = string.lower(fluid)}
end

addGTItem("Stainless Oxygen Cell", stainlessCellFilter("Oxygen"), IMPORTANT, 200)
addGTItem("Stainless Hydrogen Cell", stainlessCellFilter("Hydrogen"), IMPORTANT, 200)

local NormalPriorityCellSpam = {
	"Ethanol", "Ether", "Heavy Fuel", "Iron III Chloride", "Light Fuel", "P-507",
	"Radon", "Refined Glue", "Sodium Persulfate", "Steam", "Nitrogen Dioxide",
	"Molten Polyethylene", "Molten Silicone Rubber", "Molten Soldering Alloy",
	"Sulfuric Acid", "Nitric Acid", "Ammonium Chloride", "Molten Rubber",
	"Molten Epoxid", "Helium", "Ammonia", "Titaniumtetrachloride",
	"Propene", "Phenol", "Acetone", "Ethylene", "Mercury", "Water",
	"Methane", "Molten Polytetrafluoroethylene", "Hydrofluoric Acid",
	"Fluorine", "Hydrochloric Acid", "Chlorine", "Oxygen"
}

for i=1, #NormalPriorityCellSpam do
	addGTItem(NormalPriorityCellSpam[i] .. " Cell", nil, NORMAL, 64)
end

addGTItem("Sodium Hydroxide Dust", nil, NORMAL, 64)
addGTItem("Quicklime Dust", nil, NORMAL, 64)

return autocraftData
