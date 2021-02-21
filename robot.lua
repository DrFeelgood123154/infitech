local component = require("component")
local io = require("io")
local sr = require("serialization")
local text = require("text")
local term = require("term")
local sides = require("sides")
local event = require("event")
local robot = component.robot
local inv = component.inventory_controller
local nav = component.navigation

local DRONE = "Forestry:beeDroneGE"
local PRINCESS = "Forestry:beePrincessGE"
local QUEEN = "Forestry:beeQueenGE"
local APIARY = "gendustry:IndustrialApiary"

function TurnTo(dir)
	while(nav.getFacing() ~= dir) do
		robot.turn(true)
	end
end

function GetEmptySlot()
	for i=1, robot.inventorySize() do
		if(inv.getStackInInternalSlot(i) == nil) then return i end
	end
	return -1
end

function FindItem(what)
	for i=1, robot.inventorySize() do
		local item = inv.getStackInInternalSlot(i)
		if(item ~= nil and item.name == what) then
			return i
		end
	end
	return -1
end
function FindItemByLabel(what)
	for i=1, robot.inventorySize() do
		local item = inv.getStackInInternalSlot(i)
		if(item ~= nil and item.label == what) then
			return i
		end
	end
	return -1
end
local cableLabelPart = "gt.blockmachines.cable"
function FindCable()
	for i=1, robot.inventorySize() do
		local item = inv.getStackInInternalSlot(i)
		if(item ~= nil and string.find(item.label, cableLabelPart)) then
			return i
		end
	end
	return -1
end

function Equipped()
	local slot = GetEmptySlot()
	robot.select(slot)
	inv.equip()
	local what = inv.getStackInInternalSlot(slot).label
	inv.equip()
	return what
end

function Equip(what)
	local slot = FindSlot(what)
	if(slot ~= -1) then inv.equip(slot) end
end
function EquipLabel(what)
	local slot = FindSlotLabel(what)
	if(slot ~= -1) then inv.equip(slot) end
end

function TurnRight()
	robot.turn(true)
end
function TurnLeft()
	robot.turn(false)
end

-- pull items from chest
print("Getting items")
TurnRight()
local chestSize = inv.getInventorySize(sides.front)
if chestSize == nil then
	print("No chest found (place to the right)")
	return
end
for i=1, chestSize do
	inv.suckFromSlot(sides.front, i)
end
TurnLeft()

--remember to place it in the center, it will move one block to the left and start placing to it's right
local apiariesPlaced = 0
print("Starting")

robot.move(sides.left)
robot.move(sides.front)
local currentInvSlot;
local upper = false
while(true) do
	print("Placing apiary "..apiariesPlaced+1)
	currentInvSlot = FindItem(APIARY);
	if(currentInvSlot == -1) then break end
	robot.select(currentInvSlot)
	TurnRight()
	robot.place(sides.front, true)

	currentInvSlot = FindItem(QUEEN)
	if(currentInvSlot ~= -1) then
		inv.dropIntoSlot(sides.front, 1, 1)
	else
		currentInvSlot = FindItem(DRONE)
		if(currentInvSlot == -1) then break end
		inv.dropIntoSlot(sides.front, 2, 1)

		currentInvSlot = FindItem(PRINCESS)
		if(currentInvSlot == -1) then break end
		inv.dropIntoSlot(sides.front, 1, 1)
	end

	currentInvSlot = FindItemByLabel("Automation Upgrade")
	if(currentInvSlot == -1) then break end
	inv.dropIntoSlot(sides.front, 3, 1)

	currentInvSlot = FindItemByLabel("Genetic Stabilizer Upgrade")
	if(currentInvSlot == -1) then break end
	inv.dropIntoSlot(sides.front, 4, 1)

	if(not upper) then
		robot.down()
		currentInvSlot = FindCable()
		robot.select(currentInvSlot)
		robot.place(sides.front, true)
		robot.up()
		robot.up()
		currentInvSlot = FindItem("Transfer Pipe")
		robot.select(currentInvSlot)
		robot.place(sides.front, true)
		robot.down()
	else
		robot.up()
		currentInvSlot = FindCable()
		robot.select(currentInvSlot)
		robot.place(sides.front)
		robot.down()
	end

	apiariesPlaced = apiariesPlaced + 1

	if(apiariesPlaced == 16) then
		print("16 apiaries placed, moving up")
		robot.up()
		robot.up()
		upper = true
	else if(apiariesPlaced >= 32) then
		print("Finished placing 32 apiaries")
		return
	end

	TurnLeft()
	if(apiariesPlaced < 16) then robot.move(sides.front)
	else if(apiariesPlaced > 16) then robot.move(sides.back)
	end
end
