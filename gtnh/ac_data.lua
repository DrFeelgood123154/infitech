--[[	Data structure

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
]]
local autocraftData = {}

local NORMAL = 1
local IMPORTANT = 2
local UNIMPORTANT = 3

local function addItem(name,priority,amount,threshold,maxCraft)
	priority = priority or NORMAL
	amount = amount or ({[NORMAL]=500,[IMPORTANT]=1000,[UNIMPORTANT]=4000})[priority]
	threshold = threshold or math.floor(amount * ({[NORMAL]=0.25,[IMPORTANT]=0.5,[UNIMPORTANT]=0.25})[priority])
	maxCraft = maxCraft or ({[NORMAL]=amount*0.1,[UNIMPORTANT]=math.max(256,amount*0.05)})[priority]
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

addItem("drop of Excited Dimensionally Transcendent Exotic Catalyst", NORMAL, 1e9, nil, 1e7)

-- power stuff
--addItem("Wrapped Uranium Ingot", IMPORTANT, 500000)
--addItem("Wrapped Plutonium Ingot", IMPORTANT, 150000)
addItem("Atomic Separation Catalyst Dust", IMPORTANT, 5000)
addItem("Infinity Dust", IMPORTANT, 1000)
addItem("drop of Molten Atomic Separation Catalyst", IMPORTANT, 1e5)

-- ====== partially passive ======
-- ## DTPF ##
addItem("drop of Molten Infinity", IMPORTANT, 20e6)
addItem("drop of Molten Quantum", IMPORTANT, 20e6)
addItem("drop of Molten Neutronium", IMPORTANT, 20e6)

addItem("Cosmic Neutronium Rod", IMPORTANT, 1e4)
addItem("Tairitsu Rod", IMPORTANT, 1e4)
addItem("Transcendent Metal Rod", IMPORTANT, 1e4)
addItem("Botmium Plate", IMPORTANT, 1e4)
addItem("Arcanite Screw", IMPORTANT, 1e4)
addItem("Ender-Quantum Component", IMPORTANT, 1e4)

addItem("Biocells", NORMAL, 1e6)
addItem("TCetiE-Seaweed Extract", NORMAL, 1e6, nil, 10000)
-- ##elevator mining##
addItem("Neutronium Rod", NORMAL, 512)
addItem("Neutronium Drill Tip", NORMAL, 512)
-- ##radio hatches##
addItem("Enriched Naquadah Rod", NORMAL, 1e6)
addItem("Naquadah Rod", NORMAL, 1e6)
addItem("Naquadria Rod", NORMAL, 1e6)
addItem("Plutonium 241 Rod", NORMAL, 1e6)
-- ##seaweed broth##
addItem("Energium Dust", NORMAL, 1e6)
addItem("drop of Unknown Nutrient Agar", NORMAL, 1e7)
-- mytryl is mined
-- seaweed is passived
-- ##raw growth medium##
addItem("Mince Meat", NORMAL, 1e6)
addItem("Agar", NORMAL, 1e6)
-- ##raw bio catalyst##
-- note that this is the shittest tier recipe
addItem("Stemcells", NORMAL, 1e6)
addItem("Unknown Crystal Shard", NORMAL, 1e6)
addItem("Tritanium Dust", IMPORTANT, 1e6)
addItem("Tiny Pile of Infinity Catalyst Dust", NORMAL, 1e5)
-- ##xenoxene##
addItem("Antimony Trioxide Dust", NORMAL, 1e4)
-- osmium is passived
-- ##bastline?##
addItem("drop of Acetone", IMPORTANT, 1e8)


addItem("drop of Radon Plasma", NORMAL, 1e6)
addItem("drop of Blazing Pyrotheum", IMPORTANT, 1e6)
addItem("drop of Mutated Living Solder", NORMAL, 1e7)
addItem("drop of Tin Plasma", IMPORTANT, 1e7)
addItem("Naquadah Drill Tip", IMPORTANT, 1e4)
addItem("drop of Molten Duranium", NORMAL, 1e7)

-- circuit stuff
addItem("Indalloy 140 Cell", NORMAL, 2e4)
addItem("Wafer", NORMAL, 1000)
addItem("Phosphorus doped Wafer", NORMAL, 1000)
addItem("Naquadah doped Wafer", NORMAL, 1000)
addItem("Raw Crystal Chip", NORMAL, 100000) -- crystal shit
addItem("Crystal Processing Unit", NORMAL, 5000) -- crystal shit
addItem("Microprocessor", NORMAL, 50000) -- LV
addItem("Integrated Processor", NORMAL, 5000) -- MV
addItem("Nanoprocessor", NORMAL, 200000) -- HV
addItem("Quantumprocessor", NORMAL, 50000) -- EV
addItem("Crystalprocessor", NORMAL, 1e5).onlyOne = "CAL" -- IV
addItem("Crystalprocessor Assembly", NORMAL, 500000).onlyOne = "CAL" -- LuV
addItem("Ultimate Crystalcomputer", NORMAL, 100000).onlyOne = "CAL" -- ZPM
addItem("Crystalprocessor Mainframe", NORMAL, 10000).onlyOne = "CAL" -- UV
addItem("Wetware Mainframe", NORMAL, 5000) -- UHV
addItem("Bio Mainframe", NORMAL, 100) -- UEV

-- ebf stuff
addItem("HSS-S Ingot", NORMAL, 5e4)
addItem("Ruridit Ingot", NORMAL, 1e5)
addItem("Tungstensteel Ingot", NORMAL, 1e5)
addItem("Tungsten Ingot", NORMAL, 1e5)
addItem("Yttrium Barium Cuprate Ingot", NORMAL, 1e4)
addItem("Vanadium-Gallium Ingot", NORMAL, 3e5)
addItem("Europium Ingot", NORMAL, 1e3)
addItem("Iridium Ingot", NORMAL, 1e4)
addItem("Osmium Ingot", NORMAL, 1e4)
addItem("Naquadah Ingot", NORMAL, 1e4)
addItem("Raw Neutronium Dust", NORMAL, 1e6)

-- big amount ebf stuff
addItem("Aluminium Ingot", NORMAL, 1e6)
addItem("Steel Ingot", NORMAL, 1e6)
addItem("Silicon Solar Grade (Poly SI) Ingot", NORMAL, 1e5)
addItem("Stainless Steel Ingot", NORMAL, 1e5)
addItem("Titanium Ingot", NORMAL, 1e5)

-- ae stuff
addItem("ME Smart Cable - Fluix", NORMAL, 1000)
addItem("ME Dense Smart Cable - Fluix", NORMAL, 500)
addItem("Pattern Capacity Card", NORMAL, 64)
addItem("ME Storage Bus", NORMAL, 128)
addItem("ME Interface", NORMAL, 128)
addItem("ME Dual Interface", NORMAL, 128)
addItem("ME Export Bus", NORMAL, 128)
addItem("Acceleration Card", NORMAL, 64)
addItem("Capacity Card", NORMAL, 64)
addItem("Oredictionary Filter Card", NORMAL, 64)
addItem("Crafting Card", NORMAL, 64)
addItem("Fuzzy Card", NORMAL, 64)
addItem("Blank Pattern", IMPORTANT, 100)
addItem("Output Bus (ME)", NORMAL, 64)

-- gt stuff
addItem("Maintenance Hatch", NORMAL, 64)
addItem("Auto-Taping Maintenance Hatch", NORMAL, 256)
addItem("Muffler Hatch (LV)", NORMAL, 64)
addItem("Input Hatch (EV)", NORMAL, 64)
addItem("Output Hatch (EV)", NORMAL, 64)
addItem("Input Bus (HV)", NORMAL, 64)
addItem("IV Energy Hatch", NORMAL, 32)
addItem("LuV Energy Hatch", NORMAL, 16)
addItem("ZPM Energy Hatch", NORMAL, 16)
addItem("UV Energy Hatch", NORMAL, 16)
addItem("UHV Energy Hatch", NORMAL, 16)
addItem("UEV Energy Hatch", NORMAL, 16)
addItem("Super Bus (I) (EV)", NORMAL, 64)
addItem("Super Bus (O) (EV)", NORMAL, 64)
addItem("Super Bus (I) (UV)", NORMAL, 64)
addItem("Machine Controller Cover", NORMAL, 64)
addItem("Fluid Detector Cover", NORMAL, 64)
addItem("Redstone Receiver (Internal)", NORMAL, 256)
addItem("Multi-Use Casing", NORMAL, 4096, nil, 256)
addItem("Superconducting Coil Block", NORMAL, 2048)

-- big amount stuff
addItem("Reinforced Glass", NORMAL, 1e6)
addItem("1x Naquadah Cable", NORMAL, 1e4)
addItem("Eye of Ender", NORMAL, 5e4)
addItem("Lapotron Crystal", NORMAL, 5e5)
addItem("Block of Silicon Solar Grade (Poly SI)", NORMAL, 1e4)
addItem("ASoC", NORMAL, 2e5)
addItem("Advanced SMD Resistor", NORMAL, 5e3)
addItem("Advanced SMD Diode", NORMAL, 5e3)
addItem("Advanced SMD Transistor", NORMAL, 1e3)
addItem("Advanced SMD Capacitor", NORMAL, 1e3)
addItem("Optical SMD Resistor", NORMAL, 5e3)
addItem("Optical SMD Diode", NORMAL, 5e3)
addItem("Optical SMD Transistor", NORMAL, 1e3)
addItem("Optical SMD Capacitor", NORMAL, 1e3)
addItem("4x Niobium-Titanium Wire", NORMAL, 1e5)
addItem("Advanced Alloy", NORMAL, 1e5)
addItem("Block of Olivine", NORMAL, 1e4)
addItem("Small Coil", NORMAL, 1e6)
addItem("Random Access Memory Chip", NORMAL, 2e6)
addItem("NAND Memory Chip", NORMAL, 1e6)
addItem("NOR Memory Chip", NORMAL, 5e5)
addItem("Nanocomponent Central Processing Unit", NORMAL, 3e5)
addItem("HPIC Wafer", NORMAL, 1e5)

addItem("Advanced Circuit Board", UNIMPORTANT, 2e5)
addItem("Niobium-Titanium Ingot", UNIMPORTANT, 3e5)
addItem("Fiber-Reinforced Circuit Board", UNIMPORTANT, 5e5)
addItem("Multilayer Fiber-Reinforced Circuit Board", UNIMPORTANT, 3e5)
addItem("Elite Circuit Board", UNIMPORTANT, 2e5)
addItem("Reinforced Glass Tube", UNIMPORTANT, 5e5)

addItem("Conveyor Module (HV)", NORMAL, 64)
addItem("Conveyor Module (IV)", NORMAL, 64)
addItem("Conveyor Module (ZPM)", NORMAL, 64)
addItem("Conveyor Module (UV)", NORMAL, 64)

addItem("Electric Motor (LuV)", NORMAL, 5000)
addItem("Electric Motor (ZPM)", NORMAL, 1000)
addItem("Electric Motor (UV)", NORMAL, 100)
addItem("Electric Motor (UHV)", NORMAL, 100)

addItem("Electric Pump (IV)", NORMAL, 200)
addItem("Electric Pump (LuV)", NORMAL, 200)
addItem("Electric Pump (ZPM)", NORMAL, 200)
addItem("Electric Pump (UV)", NORMAL, 200)
addItem("Electric Pump (UHV)", NORMAL, 200)

addItem("Sensor (UHV)", NORMAL, 200)
addItem("Emitter (UHV)", NORMAL, 200)

addItem("1x Superconductor ZPM Wire", UNIMPORTANT, 5000)
addItem("1x Superconductor UV Wire", UNIMPORTANT, 5000)
addItem("1x Superconductor UHV Wire", UNIMPORTANT, 5000)
addItem("1x Superconductor UEV Wire", UNIMPORTANT, 500)

addItem("Iron Ingot", NORMAL, 5e5)
addItem("Electrum Ingot", NORMAL, 5e5)
addItem("Gold Ingot", NORMAL, 5e5)
addItem("Silver Ingot", NORMAL, 5e5)
addItem("Electrum Ingot", NORMAL, 5e5)

-- repair shit
addItem("BrainTech Aerospace Advanced Reinforced Duct Tape FAL-84", NORMAL, 10000)
addItem("Steel Screw", NORMAL, 10000)
addItem("Lubricant Cell", NORMAL, 10000)
addItem("drop of Lubricant", IMPORTANT, 1e8)

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

-- endgame shit
--addItem("Eternal Singularity", NORMAL, 1000, nil, 5)

return autocraftData
