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
	if i > 10^18 then return "battery goes brr" end
	local neg = i<0
	i = math.floor(math.abs(i))
	return (neg and "-" or "") .. (tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", ""))
end
function unformatInt(i)
	local temp = string.gsub(i,"[^%d]","")
	return tonumber(temp)
end

-- general
local sleepTime = 0.5
local drawTime = 0.5
local craftTime = 1
local startTime = computer.uptime()

-- HARDCODED VALUES IN CASE OF GT_MACHINE MULTIBLOCK
local hardCodedVoltage = 131072
local hardCodedAmperage = 64

package.loaded.electricity_display = nil
package.loaded.autocrafter = nil
local display = require("electricity_display")

local crafting_old = crafting
crafting = require("autocrafter") -- this needs to be global

crafting.Init(ae, computer, craftTime, crafting_old or {})
display.Init(crafting, ae, component, hardCodedVoltage, hardCodedAmperage)

crafting_old = nil

-- reload autocrafting when pressing "u"
if eventListener then
	ev.ignore( "key_down", eventListener )
end

local pause = false

-- this must be global
eventListener = function(name, keyboardAddress, char, code, playerName)
	if char == 117 then
		pause = true
		os.execute("wget -f http://81.233.65.53/opencomputers/gtnh/ac_data.lua")
		crafting.Init(ae, computer, craftTime, crafting)
		pause = false
	end
end
ev.listen("key_down", eventListener) -- listen for keypress

--redstone.setBundledOutput(sides.left,colors.red,0) -- reset when starting
if #display.batteryBuffers < 2 then sleepTime = 0 end

local nextDraw = computer.uptime() + drawTime
local nextCraft = computer.uptime() + craftTime
while(true) do
	if pause then
		os.sleep(math.max(1,sleepTime))
	else
		local t = computer.uptime()
		local uptime = t - startTime

		if sleepTime == 0 then
			display.CalcAverage(1/20, uptime)
		end

		if t > nextDraw then
			nextDraw = t + drawTime
			display.Draw(drawTime, uptime)
		end

		if t > nextCraft then
			nextCraft = t + craftTime
			crafting.Autocrafting()
		end

		os.sleep(sleepTime)
	end
end
