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
		threshold = 100, -- will only begin crafting once number of items drops below this number. If unspecified, defaults to equal keepStocked
		redstoneFrequency = nil, -- Emit this redstone signal to craft instead of crafting from ae. useful for powered spawners
		waitToCraft = nil, -- wait this many seconds before starting to craft, default 30
		important = false, -- if true, will always craft, ignoring the number of CPUs in use
		unimportant = false, -- if true, will only craft if nothing else is being crafted (except other unimportant crafts)

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

autocraftData["Stick"] = {
	keepStocked=1000,
	threshold=900,
	unimportant = true
}
autocraftData["Jungle Wood Planks"] = {
	keepStocked = 10000,
	threshold = 8000,
	unimportant = true
}
autocraftData["Bone Meal"] = {
	keepStocked = 5000,
	threshold = 1000
}
autocraftData["Paper"] = {
	keepStocked = 100,
	unimportant = true
}

autocraftData["Tiny Titanium Dust"] = {
	filter = {
		name = "gregtech:gt.metaitem.01",
		damage = 28,
	},
	keepStocked=100,
}
autocraftData["Powderbarrel"] = {
	filter = {
		label="gt.blockreinforced.5.name",
	},
	keepStocked=1024,
	threshold=512
}
autocraftData["Duct tape"] = {
	filter = {
		label="gt.metaitem.01.32764.name",
	},
	keepStocked = 128,
	threshold = 64,
	unimportant = true
}
autocraftData["Magnesium Dust"] = {
	filter = {
		label="gt.metaitem.01.2018.name",
	},
	keepStocked = 10000,
	threshold = 9000
}
autocraftData["Tin Ingot"] = {
	filter = {
		label="gt.metaitem.01.11057.name",
	},
	keepStocked = 10000,
	threshold = 9000
}

-- IC2
autocraftData["Empty Cell"] = {
	filter = {
		name="IC2:itemCellEmpty",
	},
	keepStocked = 1000,
	threshold = 500
}
-- AE
autocraftData["Blank Pattern"] = {
	filter = {
		label="Blank Pattern",
	},
	keepStocked = 64,
	unimportant = true
}
autocraftData["Quartz Fiber"] = {
	filter = {
		label="Quartz Fiber",
	},
	keepStocked = 64,
	unimportant = true
}
autocraftData["ME Glass Cable - Fluix"] = {
	filter = {
		label = "ME Glass Cable - Fluix",
	},
	keepStocked = 128,
	unimportant = true
}
autocraftData["Charged Certus Quartz"] = {
	filter = {
		label="Charged Certus Quartz Crystal",
	},
	keepStocked = 1000,
	threshold = 500,
	unimportant = true
}
autocraftData["Pure Certus Quartz"] = {
	filter = {
		label="Pure Certus Quartz Crystal",
	},
	keepStocked = 1000,
	threshold = 500,
	unimportant = true
}
autocraftData["Pure Fluix Crystal"] = {
	filter = {
		label="Pure Fluix Crystal",
	},
	keepStocked = 1000,
	threshold = 500,
	unimportant = true
}

--[[
-- these are export bussed with crafting cards for now
autocraftData["Silicon Ingot"] = {
	filter = {
		label="gt.metaitem.01.11020.name",
	},
	keepStocked = 1000,
	threshold = 200,
	important = true
}
autocraftData["Lutetium Ingot"] = {
	filter = {
		label="gt.metaitem.01.11078.name",
	},
	keepStocked = 100,
	important = true
}
autocraftData["Enriched Naquadah Ingot"] = {
	filter = {
		label="gt.metaitem.01.11326.name",
	},
	keepStocked = 1000,
	threshold = 900,
	important = true
}
--other ingots
autocraftData["Magnesium Ingot"] = {
	filter = {
		label="gt.metaitem.01.11018.name",
	},
	keepStocked = 1000,
	threshold = 800,
	important = true
}
autocraftData["Chrome Ingot"] = {
	filter = {
		label = "gt.metaitem.01.11030.name",
	},
	keepStocked = 100,
	threshold = 50,
	important = true
}
]]

--[[
-- unused
autocraftData["Palladium Ingot"] = {
	filter = {
		label="gt.metaitem.01.11052.name",
	},
	keepStocked=1000,
	threshold=800
}
]]

--[[ spawners
-- NOTE: THESE DO NOT WORK WITH THE NEW AUTOCRAFTER CODE YET
-- they need their own event hooks to output a redstone frequency
-- which we can create later when we need it
autocraftData["Leather"] = {
	label="Leather",
	keepStocked=5000,
	threshold=100,
	redstoneFrequency=4987
}
autocraftData["Raw Beef"] = {
	label="Raw Beef",
	keepStocked=5000,
	threshold=100,
	redstoneFrequency=4987
}
autocraftData["Ender Pearl"] = {
	label="Ender Pearl",
	keepStocked=2000,
	threshold=0,
	redstoneFrequency=4988
}
autocraftData["Feather"] = {
	label="Feather",
	keepStocked=200,
	threshold=0,
	redstoneFrequency=4985
}
autocraftData["Blaze Rod"] = {
	label="Blaze Rod",
	keepStocked=2000,
	threshold=0,
	redstoneFrequency=4986
}
autocraftData["Ink Sac"] = {
	label="Ink Sac",
	keepStocked=5000,
	threshold=2500,
	redstoneFrequency=4984
}
autocraftData["Bone"] = {
	label="Bone",
	keepStocked=5000,
	threshold=2500,
	redstoneFrequency=4999
}
--]]
--[[autocraftData["Gunpowder"] = {
	label="Gunpowder",
	keepStocked=50000,
	threshold=2500,
	redstoneFrequency=4999
}]]--

return autocraftData
