local robot = require("robot")
local sides = require("sides")

local actions = {}
local err = false
local ignoreSides = {}

local debugsides = {
	[sides.front] = "front",
	[sides.back] = "back",
	[sides.left] = "left",
	[sides.right] = "right",
	[sides.up] = "up",
	[sides.down] = "down",
}
local function debugIgnoreSides(t)
	local s = {}
	for k,v in pairs(t) do
		s[#s+1] = debugsides[k]
	end
	return table.concat(s,",")
end

local function dontIgnoreSide(side)
	return not ignoreSides[side]
end

local function checkAllSides()
	robot.select(1)

	if dontIgnoreSide(sides.front) and robot.compare(true) then
		return sides.front
	elseif dontIgnoreSide(sides.up) and robot.compareUp(true) then
		return sides.up
	elseif dontIgnoreSide(sides.down) and robot.compareDown(true) then
		return sides.down
	end

	if dontIgnoreSide(sides.left) then
		robot.turnLeft()
		if robot.compare(true) then
			robot.turnRight()
			return sides.left
		else
			robot.turnRight()
		end
	end

	if dontIgnoreSide(sides.right) then
		robot.turnRight()
		if robot.compare(true) then
			robot.turnLeft()
			return sides.right
		else
			robot.turnLeft()
		end
	end

	return false
end

local placeBlock
local function backTrack()
	if #actions == 0 then return false end
	local action = table.remove(actions,#actions)

	local dir = action.dir
	ignoreSides = action.ignoreSides or {}
	print("backtracking:",debugsides[dir],"ignoresides:",debugIgnoreSides(ignoreSides))

	local convert = {
		[sides.front] = function()
			robot.back()
			if not placeBlock() then
				err = "Unable to place block"
			end
		end,
		[sides.up] = function()
			robot.down()
			if not placeBlock(sides.up) then
				err = "Unable to place block"
			end
		end,
		[sides.down] = function()
			robot.up()
			if not placeBlock(sides.down) then
				err = "Unable to place block"
			end
		end,
		[sides.left] = function()
			robot.back()
			if not placeBlock() then
				err = "Unable to place block"
			end
			robot.turnRight()
		end,
		[sides.right] = function()
			robot.back()
			if not placeBlock() then
				err = "Unable to place block"
			end
			robot.turnLeft()
		end,
		[sides.back] = function()
			robot.forward()
			robot.turnAround()
			if not placeBlock() then
				err = "Unable to place block"
			end
			robot.turnAround()
		end
	}

	if convert[dir] then
		convert[dir]()
		return true
	end

	return false
end

local breakBlock
local function move(dir)
	print("moving:",debugsides[dir])
	local convert = {
		[sides.front] = function()
			if breakBlock() then
				robot.forward()
			else
				err = "Unable to break block"
			end
		end,
		[sides.up] = function()
			if breakBlock(sides.up) then
				robot.up()
			else
				err = "Unable to break block"
			end
		end,
		[sides.down] = function()
			if breakBlock(sides.down) then
				robot.down()
			else
				err = "Unable to break block"
			end
		end,
		[sides.left] = function()
			robot.turnLeft()
			if breakBlock() then
				robot.forward()
			else
				err = "Unable to break block"
			end
		end,
		[sides.right] = function()
			robot.turnRight()
			if breakBlock() then
				robot.forward()
			else
				err = "Unable to break block"
			end
		end,
		[sides.back] = function()
			if breakBlock() then
				robot.back()
			else
				err = "Unable to break block"
			end
		end
	}

	if convert[dir] then
		ignoreSides[dir] = true
		table.insert(actions,{
			dir = dir,
			ignoreSides = ignoreSides
		})
		ignoreSides = {}
		convert[dir]()
	end
end

function breakBlock(side)
	print("breaking block:",debugsides[side] or "front")
	local convert = {
		[sides.up] = robot.swingUp,
		[sides.down] = robot.swingDown
	}

	return (convert[side] or robot.swing)()
end

function placeBlock(side)
	print("placing block:",debugsides[side] or "front")
	robot.select(2)
	side = side or sides.front

	local convert = {
		[sides.up] = robot.placeUp,
		[sides.down] = robot.placeDown,
		[sides.front] = robot.place
	}
	local placeFunc = (convert[side] or robot.place)

	local num = robot.count()
	if num > 1 then
		return placeFunc()
	else
		for i=3,robot.inventorySize() do
			if robot.compareTo(i) then
				robot.select(i)
				return placeFunc()
			end
		end
	end

	return false
end

local ok, msg = pcall(function()
	while err == false do
		if robot.durability() == nil then err = "No tool equipped" break end

		local side = checkAllSides() -- check all sides for valid cable
		if not side then -- no cable was found
			if not backTrack() then -- unable to backtrack, actions table probably empty
				print("Done") -- call it
				break
			end
		else
			move(side) -- move toward side
		end
	end
end)

if not ok then print("ERROR2: " .. msg) end

if err then
	print("ERROR: " .. err)
end
