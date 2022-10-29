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
		aeAmount = 0, -- amount of items in ae
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

local function addItem(name,priority,amount,threshold,maxCraft)
	priority = priority or NORMAL
	amount = amount or ({[NORMAL]=500,[IMPORTANT]=1000,[UNIMPORTANT]=4000})[priority]
	threshold = threshold or math.floor(amount * ({[NORMAL]=0.25,[IMPORTANT]=0.5,[UNIMPORTANT]=0.25})[priority])
	maxCraft = maxCraft or ({[NORMAL]=math.min(1024,amount*0.5),[UNIMPORTANT]=math.min(256,amount*0.25)})[priority]
	autocraftData[name] = {
		filter = {label=name},
		keepStocked = amount,
		threshold = threshold,
		important = priority == IMPORTANT,
		unimportant = priority == UNIMPORTANT,
		maxCraft = maxCraft
	}
	return autocraftData[name]
end

-- circuit stuff
addItem("Wafer", UNIMPORTANT, 1000)
addItem("Phosphorous doped Wafer", UNIMPORTANT, 1000)
addItem("Naquadah doped Wafer", UNIMPORTANT, 100)
addItem("Microprocessor", NORMAL, 1000)
addItem("Integrated Processor", NORMAL, 1000)
addItem("Nanoprocessor", NORMAL, 1000)
addItem("Quantumprocessor", NORMAL, 1000)
addItem("Mainframe", UNIMPORTANT, 100)
addItem("Nanoprocessor Mainframe", UNIMPORTANT, 10)
addItem("Quantumprocessor Mainframe", UNIMPORTANT, 10)

-- ebf stuff
addItem("HSS-S Ingot", UNIMPORTANT, 5000)
addItem("Ruridit Ingot", UNIMPORTANT, 10000)
addItem("Tungstensteel Ingot", UNIMPORTANT, 10000)
addItem("Tungsten Ingot", UNIMPORTANT, 2000)
addItem("Yttrium Barium Cuprate Ingot", UNIMPORTANT, 1000)
addItem("Vanadium Gallium Ingot", UNIMPORTANT, 1000)
addItem("Europium Ingot", UNIMPORTANT, 10000)
addItem("Iridium Ingot", UNIMPORTANT, 1000)
addItem("Osmium Ingot", UNIMPORTANT, 1000)
addItem("Silicon Solar Grade (Poly SI) Ingot", UNIMPORTANT, 10000)
addItem("Stainless Steel Ingot", UNIMPORTANT, 10000)
addItem("Europium Ingot", UNIMPORTANT, 10000)

-- ae stuff
addItem("ME Smart Cable", NORMAL, 1000, 500, 100)
addItem("ME Dense Smart Cable", NORMAL, 200, 100, 32)
addItem("Pattern Capacity Card", NORMAL, 64, 32, 16)
addItem("ME Storage Bus", NORMAL, 128, 64, 16)
addItem("ME Interface", NORMAL, 128, 64, 16)
addItem("ME Dual Interface", NORMAL, 128, 64, 16)
addItem("ME Export Bus", NORMAL, 128, 64, 16)
addItem("Acceleration Card", NORMAL, 64, 32, 16)
addItem("Capacity Card", NORMAL, 64, 32, 16)
addItem("Oredictionary Filter Card", NORMAL, 32, 16, 16)
addItem("Crafting Card", NORMAL, 64, 32, 16)
addItem("Fuzzy Card", NORMAL, 32, 16, 16)

-- gt stuff
addItem("Conveyor Module (HV)", NORMAL, 64, 32, 16)
addItem("Electric Pump (IV)", NORMAL, 32, 16, 16)

--[[
local function basicFilter(label, prefix)
	prefix = prefix or "01"
	return {label = "gt.metaitem." .. prefix .. "." .. label .. ".name"}
end
]]
local function stainlessCellFilter(fluid)
	return {label = "Large Stainless Steel Fluid Cell", fluid_label = fluid}
end

--[[
addGTItem("Stainless Oxygen Cell", IMPORTANT, 500).filter = stainlessCellFilter("Oxygen")
addGTItem("Stainless Hydrogen Cell", IMPORTANT, 500).filter = stainlessCellFilter("Hydrogen")
--addGTItem("Helium Plasma Cell", IMPORTANT, 500)
addGTItem("Niobium Plasma Cell", IMPORTANT, 10000, nil, 2560)

local CellSpam = {
	[200] = {
		"Ethanol", "Ether", "Heavy Fuel", "Light Fuel",
		"Radon", "Titaniumtetrachloride", "Benzene",
		"Propene", "Acetone", "Ethylene",  "Methane",
		"Steam", "Phenol", "Molten Silicone Rubber",
		"Distilled Water",
	},
	[500] = {
		"Helium", "Molten Polybenzimidazole", "Lubricant", "Refined Glue", 
		"Molten Rubber", "Molten Polyethylene", "Molten Epoxid", "Water", 
		"Oxygen", "Molten Polytetrafluoroethylene",
	},
	[1000] = {
		"Fluorine", "Iron III Chloride",
		"Sodium Persulfate", "Nitric Acid", "Nitrogen Dioxide",
		"Molten Soldering Alloy", "Mercury", 
	},
	[2000] = {
		"Nitrogen", "Ammonia", "Ammonium Chloride", "Hydrochloric Acid", 
		"Chlorine", "Hydrofluoric Acid",
	},
	[4000] = {
		"Sulfuric Acid", 
	}
}

for amount, cells in pairs( CellSpam ) do
	for _, name in pairs( cells ) do
		addGTItem(name .. " Cell", NORMAL, amount)
	end
end

addGTItem("Stainless Distilled Water Cell", NORMAL, 400).filter = stainlessCellFilter("Distilled Water")
addGTItem("Stainless Nitrogen Dioxide Cell", NORMAL, 100).filter = stainlessCellFilter("Nitrogen Dioxide")
addGTItem("Stainless Ammonia Cell", NORMAL, 100).filter = stainlessCellFilter("Ammonia")
addGTItem("Stainless Helium Cell", NORMAL, 64).filter = stainlessCellFilter("Helium")
addGTItem("Stainless Benzene Cell", NORMAL, 64).filter = stainlessCellFilter("Benzene")
addGTItem("Stainless Sulfuric Acid Cell", NORMAL, 64).filter = stainlessCellFilter("Sulfuric Acid")
addGTItem("Stainless Chlorine Cell", NORMAL, 100).filter = stainlessCellFilter("Chlorine")
addGTItem("Stainless Fluorine Cell", NORMAL, 100).filter = stainlessCellFilter("Fluorine")
addGTItem("Stainless Nitrogen Cell", NORMAL, 100).filter = stainlessCellFilter("Nitrogen")
addGTItem("Stainless Argon Cell", NORMAL, 100).filter = stainlessCellFilter("Argon")
addGTItem("Stainless Sodium Tungstate Cell", NORMAL, 100).filter = stainlessCellFilter("Sodium Tungstate")

addGTItem("Sodium Hydroxide Dust", NORMAL, 10000, nil, 2560)
addGTItem("Potassium Hydroxide Dust", NORMAL, 10000)
addGTItem("Quicklime Dust", NORMAL)
addGTItem("Enderpearl Dust", NORMAL)
addGTItem("Electric Pump (IV)", NORMAL, 10, 10)
addGTItem("Silicon Dioxide Dust", NORMAL, 100000)
addGTItem("Potassium Dichromate Dust", NORMAL, 64)
addGTItem("Aluminium Dust", NORMAL, 1000)
addGTItem("Sulfur Dust", NORMAL, 10000)
addGTItem("Bio Chaff", NORMAL, 10000)
addGTItem("Uranium 238 Rod", NORMAL, 128)
addGTItem("Furnace", NORMAL, 1024)
addGTItem("Blaze Powder", NORMAL, 2048)
addGTItem("Chiseled Stone Bricks", NORMAL, 10000)
addGTItem("Industrial TNT", NORMAL, 100000, nil, 2560)
addGTItem("Gelled Toluene", NORMAL, 100000, nil, 2560)

addGTItem("ME Interface", UNIMPORTANT, 256).filter = {label = "ME Interface", name = "appliedenergistics2:tile.BlockInterface"}
addGTItem("ME Export Bus", UNIMPORTANT, 64)
addGTItem("ME Storage Bus", UNIMPORTANT, 64)
addGTItem("ME Smart Cable - Fluix", UNIMPORTANT, 256)
addGTItem("ME Dense Smart Cable - Fluix", UNIMPORTANT, 64)
addGTItem("BrainTech Aerospace Advanced Reinforced Duct Tape FAL-84", UNIMPORTANT, 256)

addGTItem("Microprocessor", UNIMPORTANT, 512)
addGTItem("Integrated Processor", UNIMPORTANT, 512)
addGTItem("Nanoprocessor", UNIMPORTANT, 512)
addGTItem("Quantumprocessor", UNIMPORTANT, 1024)
addGTItem("Crystalprocessor", UNIMPORTANT, 2048)

local IngotSpam = {
	[1024] = {
		"Yttrium Barium Cuprate", "HSS-S", "Draconium"
	},
	[8192] = {
		"Aluminium", "Titanium", "Tungsten", "Tungstensteel", "Ruridit",
		"Stainless Steel", "Iridium", "Fluxed Electrum", 
	}
}

for amount, ingots in pairs( IngotSpam ) do
	for _, name in pairs( ingots ) do
		addGTItem(name .. " Ingot", UNIMPORTANT, amount)
	end
end
]]

return autocraftData
