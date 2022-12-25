local component = require("component")
local io = require("io")
local sr = require("serialization")
local text = require("text")
local term = require("term")
local computer = require("computer")
local sides = require("sides")
--local redstone = component.redstone
local ae = component.me_interface
local gpu = component.gpu
local colors = require("colors")
local ev = require("event")
local redstone = component.redstone

os.execute("resolution 70 25")

----

local defaultColor = 0xFFFFFF
gpu.setForeground(defaultColor)

function printColor(color, wat)
	gpu.setForeground(color)
	print(wat)
	gpu.setForeground(defaultColor)
end
function clearTerminal()
	term.clear()
end
function formatInt(i)
	--if i < -10^18 or i > 10^18 then return "battery goes brr" end
	local neg = i<0
	i = math.floor(math.abs(i))
	return (neg and "-" or "") .. (tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", ""))
end
function unformatInt(i)
	local temp = string.gsub(i,"[^%d]","")
	return tonumber(temp)
end
function formatTime(t)
	if t > 3600 then return math.floor(t / 3600) .. "h" end
	if t > 60 then return math.floor(t / 60) .. "m" end
	return math.floor(t) .. "s"
end

-- general
local sleepTime = 0.5
local drawTime = 0.5
local craftTime = 1
local startTime = computer.uptime()

local function getVoltageOfTier(tier) return 32 * math.pow(4,tier - 1) end
local voltageNames = {"LV","MV","HV","EV","IV","LuV","ZPM","UV","UHV","UEV","UIV","UMV","UXV","MAX"}
local voltages = {}
for i=1, #voltageNames do
	voltages[voltageNames[i]] = getVoltageOfTier(i)
end

-- HARDCODED VALUES IN CASE OF GT_MACHINE MULTIBLOCK
local hardCodedVoltage = voltages.UHV
local hardCodedAmperage = 131072

package.loaded.electricity_display = nil
package.loaded.autocrafter = nil
local display = require("electricity_display")

local crafting_old = crafting
crafting = require("autocrafter") -- this needs to be global

crafting.Init(ae, computer, display, craftTime, crafting_old or {})
display.Init(crafting, ae, component, hardCodedVoltage, hardCodedAmperage)

crafting_old = nil
local pause = false

--[[
-- reload autocrafting when pressing "u"
if eventListener then
	ev.ignore( "key_down", eventListener )
end

-- this must be global
eventListener = function(name, keyboardAddress, char, code, playerName)
	if char == 117 then
		pause = true
		os.execute("wget -f http://81.233.65.53/opencomputers/gtnh/ac_data.lua")
		crafting.Init(ae, computer, display, craftTime, crafting)
		pause = false
	end
end
ev.listen("key_down", eventListener) -- listen for keypress
]]

--redstone.setBundledOutput(sides.left,colors.red,0) -- reset when starting
if #display.batteryBuffers < 2 then sleepTime = 0 end

local nextDraw = computer.uptime() + drawTime
local nextCraft = computer.uptime() + craftTime
local lastRedstoneInput = computer.uptime()
local playersOfflineTime = 600 -- 1800s = 30 minutes
local arePlayersOffline = false
while(true) do
	if pause then
		os.sleep(math.max(1,sleepTime))
	else
		local t = computer.uptime()
		local uptime = t - startTime

		if redstone.getInput(sides.left) > 0 then
			lastRedstoneInput = computer.uptime()
			arePlayersOffline = false
		else
			arePlayersOffline = lastRedstoneInput < computer.uptime() - playersOfflineTime
		end

		if sleepTime == 0 then
			display.CalcAverage(1/20, uptime)
		end

		if t > nextDraw then
			nextDraw = t + drawTime
			display.Draw(drawTime, uptime, t)
		end

		if t > nextCraft then
			nextCraft = t + craftTime
			crafting.Autocrafting(arePlayersOffline)
		end

		os.sleep(sleepTime)
	end
end
