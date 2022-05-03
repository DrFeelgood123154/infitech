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
local hardCodedVoltage = 32768
local hardCodedAmperage = 64

package.loaded.electricity_display = nil
package.loaded.autocrafter = nil
local display = require("electricity_display")
local crafting = require("autocrafter")

crafting.Init(ae, computer, craftTime)
display.Init(crafting, ae, component, hardCodedVoltage, hardCodedAmperage)


--redstone.setBundledOutput(sides.left,colors.red,0) -- reset when starting
if #display.batteryBuffers < 2 then sleepTime = 0 end

local nextDraw = computer.uptime() + drawTime
local nextCraft = computer.uptime() + craftTime
while(true) do
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
