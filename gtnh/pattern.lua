local component = require("component")
local term = require("term")
local os = require("os")
local me = component.me_interface
local db = component.database

local DBSIZE = 25 -- tier 2 database
-- local DBSIZE = 81 -- tier 3 database

local function readio(allowboth)
	while true do
		local iostr = io.read()
		if iostr == "i" or iostr == "in" then
			return "Input"
		elseif iostr == "o" or iostr == "out" then
			return "Output"
		elseif allowboth and (iostr == "b" or iostr == "both") then
			return "both"
		elseif allowboth and (iostr == "m" or iostr == "multiply") then
			return "multiply"
		elseif allowboth and (iostr == "r" or iostr == "read") then
			return "read"
		else
			io.write("Invalid, expected 'i' or 'o' " .. (allowboth and "or 'b'" or "") .. ", try again ")
		end
	end
end

while true do
	local slots = {Input=0, Output=0}
	local interfaceSlot = 0

	io.write("[r]ead pattern into db, change [i]nput, [o]utput, [b]oth, or [m]ultiply? ")
	local ioboth = readio(true)

	if ioboth == "multiply" or ioboth == "read" then
		-------------------------------------------------------------------
		-- multiply recipe

		local dbidx = 0
		local recipe = {
			Input = {},
			Output = {},
			Original = {Input={},Output={}}
		}

		local function checkItemExists() -- check if item stored at max index already exists
			local hash = db.computeHash(DBSIZE)
			for i=1,DBSIZE-1 do
				if db.computeHash(i) == hash then
					return i
				end
			end
			dbidx = dbidx + 1
			if dbidx == DBSIZE then print("") print("TOO MANY ITEM TYPES, switch to a bigger database. Script aborted") os.exit() end
			db.copy(DBSIZE, dbidx)
			return dbidx
		end

		local function clearDB()
			for i=1, DBSIZE do db.clear(i) end
		end

		local function storePattern(pattern, patternKey, funcName)
			for i=1,pattern[patternKey].n do
				if pattern[patternKey][i] and pattern[patternKey][i].count ~= nil then
					local amount = pattern[patternKey][i].count
					me["storeInterfacePattern" .. funcName](interfaceSlot, i, db.address, DBSIZE)
					local itemidx = checkItemExists()
					io.write(string.format("Loading item into db, %s, i: %s, amount: %s, itemidx: %s\n", funcName, i, amount, itemidx))
					recipe[funcName][itemidx] = (recipe[funcName][itemidx] or 0) + amount
					recipe.Original[funcName][itemidx] = (recipe.Original[funcName][itemidx] or 0) + amount
				end
			end
		end

		local function multiply(funcName, mult)
			local totalNumberOfSlots = 0
			local smallestAmount
			local smallestIdx
			for itemidx,amount in pairs(recipe[funcName]) do
				recipe.Original[funcName][itemidx] = amount

				if funcName == "Input" and (not smallestIdx or smallestAmount < amount) then
					smallestIdx = itemidx
					smallestAmount = amount
				end

				recipe[funcName][itemidx] = amount * mult
				totalNumberOfSlots = totalNumberOfSlots + math.ceil(recipe[funcName][itemidx]/64)
			end

			return totalNumberOfSlots, smallestIdx, smallestAmount
		end

		local function resetFields()
			dbidx = 0
			recipe.Input = {}
			recipe.Output = {}
			recipe.Original.Input = {}
			recipe.Original.Output = {}
			slots.Inputs = 0
			slots.Outputs = 0
		end

		local function readPattern()
			io.write("--- Loading pattern #1\n")
			local pattern = me.getInterfacePattern(interfaceSlot)
			if not pattern then return false end
			io.write("Loading all items into database...\n")
			storePattern(pattern, "inputs", "Input")
			storePattern(pattern, "outputs", "Output")
			io.write("All items loaded\n")
			return true
		end

		if ioboth == "read" then
			resetFields()
			clearDB()
			interfaceSlot = 1
			readPattern()
			db.clear(DBSIZE)
		else

			-- ask for super bus size
			io.write("How many slots does your input bus have? ")
			local busSize
			repeat
				busSize = tonumber(io.read())
				if busSize == nil then io.write("Not a valid number, try again ") end
			until busSize ~= nil

			-- ask for mult
			io.write("Multiply recipe by how much? ")
			local mult
			repeat
				mult = tonumber(io.read())
				if mult == nil then io.write("Not a valid number, try again ") end
			until mult ~= nil

			-- store pattern to db
			while true do
				-- reset fields
				resetFields()
				clearDB()

				interfaceSlot = interfaceSlot + 1
				if not readPattern() then break end

				-- multiply amounts
				local numSlotsI, smallestIdx, smallestAmount = multiply("Input", mult)
				local numSlotsO = multiply("Output", mult)

				if numSlotsI > 512 then
					print("Multiplier is too high, would result in more than 255 (input) slots used, try again. Aborting.")
				elseif numSlotsO > 512 then
					print("Multiplier is too high, would result in more than 255 (output) slots used, try again. Aborting.")
				else
					-- write outputs to pattern
					io.write("Clearing outputs...\n")
					for i=pattern.outputs.n,1,-1 do
						me.clearInterfacePatternOutput(interfaceSlot, i)
					end
					io.write("Writing outputs...\n")
					for itemidx, amount in pairs(recipe.Output) do
						local maxAmount = amount
						repeat
							local currentAmount = math.min(amount, 64)
							amount = amount - currentAmount

							slots.Output = slots.Output + 1
							io.write(string.format("Writing %s items to output slot %s (Total progress: %s/%s)",
								currentAmount, slots.Output, maxAmount-amount, maxAmount))
							me.setInterfacePatternOutput(interfaceSlot, db.address, itemidx, currentAmount, slots.Output)
							if amount > 0 then term.clearLine() else io.write("\n") end
						until amount <= 0
					end

					io.write("Done writing outputs\n")

					-- calculate input ratios
					-- we want to write in groups such that the ratio of input items is preserved
					-- and so that it fills the maximum amount of slots in the input bus each time
					local ratios = {}
					local totalNumberOfItemsToWrite = 0
					local numSlotsOriginal = 0
					local ratioSum = 0
					for itemidx, amount in pairs(recipe.Original.Input) do
						ratios[itemidx] = amount / smallestAmount
						ratioSum = ratioSum + amount / smallestAmount
						numSlotsOriginal = numSlotsOriginal + math.ceil(amount/64)
						totalNumberOfItemsToWrite = totalNumberOfItemsToWrite + recipe.Input[itemidx]
					end

					local busRatio = math.floor(busSize / ratioSum)
					local maxTotal = totalNumberOfItemsToWrite

					io.write("Clearing inputs...\n")
					for i=pattern.inputs.n,1,-1 do
						me.clearInterfacePatternInput(interfaceSlot, i)
					end
					io.write("Writing inputs...\n")
					repeat
						for itemidx, maxAmount in pairs(recipe.Input) do
							local amount = math.min(maxAmount, ratios[itemidx] * busRatio * 64)
							local currentMaxAmount = amount
							maxAmount = maxAmount - amount

							repeat
								local currentAmount = math.min(amount, 64)
								amount = amount - currentAmount
								totalNumberOfItemsToWrite = totalNumberOfItemsToWrite - currentAmount

								slots.Input = slots.Input + 1
								io.write(string.format("Writing %s items to input slot %s (Total progress: %s/%s - %s%%)",
									currentAmount, slots.Input, currentMaxAmount-amount, currentMaxAmount, 
									math.floor(0.5+(maxTotal-totalNumberOfItemsToWrite)/maxTotal*100)))
								me.setInterfacePatternInput(interfaceSlot, db.address, itemidx, currentAmount, slots.Input)
								if amount > 0 then term.clearLine() else io.write("\n") end
							until amount <= 0

							if maxAmount <= 0 then
								recipe.Input[itemidx] = nil
							else
								recipe.Input[itemidx] = maxAmount
							end
						end
					until totalNumberOfItemsToWrite<=0
				end
			end

			clearDB()
		end
	else
		-------------------------------------------------------------------
		-- encode recipe

		for i=1,DBSIZE do
			local dbitem = db.get(i)
			if dbitem == nil then break end

			print("\nItem: " .. (dbitem.fluid_label and (dbitem.fluid_label .. " Cell") or dbitem.label))
			local funcName

			if ioboth == "both" then
				io.write("Is this item an input or output? [i/o] ")
				funcName = readio(false)
			else
				funcName = ioboth
			end

			io.write("How many of this item? [e to exit] ")
			local amount
			repeat
				local temp = io.read()
				if temp == "e" then break end
				amount = tonumber(temp)
				if amount == nil then io.write("Not a valid number, try again ") end
			until amount ~= nil

			if not amount then break end

			local maxAmount = amount
			repeat
				local currentAmount = math.min(amount,64)
				amount = amount - currentAmount

				slots[funcName] = slots[funcName] + 1
				io.write(string.format("Writing %s (%s/%s) items to %s slot %s",
					currentAmount, maxAmount-amount, maxAmount,
					string.lower(funcName), slots[funcName]))

				me["setInterfacePattern"..funcName](1, db.address, i, currentAmount, slots[funcName])
				if amount > 0 then term.clearLine() else io.write("\n") end
			until (amount == 0)
		end
	end

	print("DONE! Press enter to go again")
	io.read()
end
