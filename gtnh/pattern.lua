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