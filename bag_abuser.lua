local component = require("component")
local io = require("io")
local sr = require("serialization")
local text = require("text")
local term = require("term")
local sides = require("sides")
local event = require("event")
local shell = require("shell")
local robot = component.robot
local inv = component.inventory_controller

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
	if(slot ~= -1) then
		robot.select(slot)
		inv.equip(slot)
		return true
	end
	return false
end
function EquipLabel(what)
	local slot = FindItemByLabel(what)
	if(slot ~= -1) then
		robot.select(slot)
		inv.equip()
		return true
	end
	return false
end

function TurnRight()
	robot.turn(true)
end
function TurnLeft()
	robot.turn(false)
end

function MoveUp()
	robot.move(sides.up)
end
function MoveDown()
	robot.move(sides.down)
end

function Forward()
	robot.move(sides.front)
end

function DumpItems()
	for i = 1, robot.inventorySize() do
		robot.select(i)
		robot.drop(sides.front)
	end
end

-- pull items from chest
print("Getting items")
local chestSize = inv.getInventorySize(sides.front)

local normalOpened = 0
local uncommonOpened = 0
local rareOpened = 0
print("Starting")

local currentInvSlot;
while(true) do
	for i=1, chestSize do
		local wat = inv.getStackInSlot(sides.front, i)
		if(wat ~= nil) then
			wat = wat.label
			if(string.find(wat, "Treasure") ~= nil) then
				while(inv.suckFromSlot(sides.front, i)) do end
			end
		end
	end

	while(EquipLabel("Common Treasure")) do
		while(robot.use(sides.bottom)) do
			normalOpened = normalOpened + 1
		end
	end
	while(EquipLabel("Uncommon Treasure")) do
		while(robot.use(sides.bottom)) do
			uncommonOpened = uncommonOpened + 1
		end
	end
	while(EquipLabel("Rare Treasure")) do
		while(robot.use(sides.bottom)) do
			rareOpened = rareOpened + 1
		end
	end

	--dump trash
	TurnLeft()
	DumpItems()
	TurnRight()

	print("Treasures opened: ")
	print("Normal: "..normalOpened)
	print("Uncommon: "..uncommonOpened)
	print("Rare: "..rareOpened)
	print("Sleeping for 15 minutes")
	os.sleep(15*60)
end
