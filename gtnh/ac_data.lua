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
		onlyOne = false, -- if true, only allow one of these at a time to be active

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
addItem("Wafer", NORMAL, 1000, nil, 128)
addItem("Phosphorus doped Wafer", NORMAL, 1000, nil, 128)
addItem("Naquadah doped Wafer", NORMAL, 100)
addItem("Raw Crystal Chip", NORMAL, 5000, 4000, 250) -- crystal shit
addItem("Crystal Processing Unit", NORMAL, 5000, 4000, 250) -- crystal shit
addItem("Microprocessor", NORMAL, 1000, nil, 128).onlyOne = "CAL" -- LV
addItem("Integrated Processor", NORMAL, 1000, nil, 128).onlyOne = "CAL" -- MV
addItem("Nanoprocessor", NORMAL, 1000, nil, 128).onlyOne = "CAL" -- HV
addItem("Quantumprocessor", NORMAL, 1000, nil, 128).onlyOne = "CAL" -- EV
addItem("Crystalprocessor", NORMAL, 1000, nil, 128).onlyOne = "CAL" -- IV
addItem("Crystalprocessor Assembly", NORMAL, 500, nil, 128).onlyOne = "CAL" -- LuV
addItem("Ultimate Crystalcomputer", NORMAL, 200, nil, 100).onlyOne = "CAL" -- ZPM
addItem("Crystalprocessor Mainframe", NORMAL, 50, nil, 10).onlyOne = "CAL" -- UV

-- ebf stuff
addItem("HSS-S Ingot", NORMAL, 5000).onlyOne = "EBF"
addItem("Ruridit Ingot", NORMAL, 10000).onlyOne = "EBF"
addItem("Tungstensteel Ingot", NORMAL, 10000).onlyOne = "EBF"
addItem("Tungsten Ingot", NORMAL, 10000).onlyOne = "EBF"
addItem("Yttrium Barium Cuprate Ingot", NORMAL, 1000).onlyOne = "EBF"
addItem("Vanadium-Gallium Ingot", NORMAL, 1000).onlyOne = "EBF"
addItem("Europium Ingot", NORMAL, 1000).onlyOne = "EBF"
addItem("Iridium Ingot", NORMAL, 1000).onlyOne = "EBF"
addItem("Osmium Ingot", NORMAL, 1000).onlyOne = "EBF"
addItem("Naquadah Ingot", NORMAL, 1000).onlyOne = "EBF"

-- big amount ebf stuff
addItem("Aluminium Ingot", NORMAL, 100000).onlyOne = "EBF"
addItem("Steel Ingot", NORMAL, 100000).onlyOne = "EBF"
addItem("Silicon Solar Grade (Poly SI) Ingot", NORMAL, 100000).onlyOne = "EBF"
addItem("Stainless Steel Ingot", NORMAL, 50000).onlyOne = "EBF"
addItem("Titanium Ingot", NORMAL, 50000).onlyOne = "EBF"
addItem("Iron Ingot", NORMAL, 100000).onlyOne = "EBF"

-- ae stuff
addItem("ME Smart Cable - Fluix", NORMAL, 1000, 500, 100)
addItem("ME Dense Smart Cable - Fluix", NORMAL, 200, 100, 32)
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
addItem("Blank Pattern", IMPORTANT, 100, 50, 100)
addItem("Output Bus (ME)", NORMAL, 64)

-- gt stuff
addItem("Conveyor Module (HV)", NORMAL, 64, 32, 16)
addItem("Conveyor Module (IV)", NORMAL, 64, 32, 16)
addItem("Electric Pump (IV)", NORMAL, 32, 16, 16)
addItem("Maintenance Hatch", NORMAL, 64)
addItem("Muffler Hatch (LV)", NORMAL, 64)
addItem("Input Hatch (EV)", NORMAL, 64)
addItem("Output Hatch (EV)", NORMAL, 64)
addItem("Input Bus (HV)", NORMAL, 64)
addItem("IV Energy Hatch", NORMAL, 32)
addItem("LuV Energy Hatch", NORMAL, 16)
addItem("Super Bus (I) (EV)", NORMAL, 64)
addItem("Super Bus (O) (EV)", NORMAL, 64)
addItem("Machine Controller Cover", NORMAL, 64)
addItem("Fluid Detector Cover", NORMAL, 64)

-- redstone shit
addItem("Redstone Receiver (Internal)", NORMAL, 64)
addItem("Redstone Receiver (External)", NORMAL, 64)
addItem("Redstone Transmitter (External)", NORMAL, 16)
addItem("Red Alloy Wire", NORMAL, 128)
addItem("Framed Red Alloy Wire", NORMAL, 128)
addItem("RS Latch", NORMAL, 32)
addItem("NOT Gate", NORMAL, 32)
addItem("AND Gate", NORMAL, 32)
addItem("Dense Redcrystal", NORMAL, 64)

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
