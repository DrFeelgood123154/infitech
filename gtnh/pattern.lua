local component = require("component")
local term = require("term")
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
		else
			io.write("Invalid, expected 'i' or 'o' " .. (allowboth and "or 'b'" or "") .. ", try again ")
		end
	end
end

while true do
	local slots = {Input=0, Output=0}

	io.write("Change only input or only output or both? [i/o/b] ")
	local ioboth = readio(true)

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

	print("DONE! Press enter to go again")
	io.read()
end

--[[
-- dr's version below

component = require("component")
me = component.me_interface
db = component.database

--0 for input, 1 for output
mode = 0;
io.write('Pattern side [in/out]: ')
strMode = io.read()

if(strMode == "in") then
	mode = 0
elseif(strMode == "out") then
	mode = 1
else
	io.write("Invalid pattern side")
	return
end

io.write('Number of item types: ')
nTypes = io.read("*n")

lastSlot = 0

for inp=1,nTypes do
	io.write('Number of items needed of type ', inp, ': ')
	nItems = io.read("*n")

	io.write('Item DB index: ')
	dbIndex = io.read("*n")

	cycles = nItems//64;
	lastStack = nItems%64;

	if(mode == 0) then
		for i=1,cycles do
			me.setInterfacePatternInput(1, db.address, dbIndex, 64, i+lastSlot)
		end

		me.setInterfacePatternInput(1, db.address, dbIndex, lastStack, cycles+lastSlot+1)
	else
		for i=1,cycles do
			me.setInterfacePatternOutput(1, db.address, dbIndex, 64, i+lastSlot)
		end

		me.setInterfacePatternOutput(1, db.address, dbIndex, lastStack, cycles+lastSlot+1)
	end
	if(lastStack ~= 0) then
		lastSlot = lastSlot + 1
	end
	lastSlot = lastSlot + cycles
end
]]
