local sides = require("sides")
local component = require("component")

-- thorium:
--local reactorCode = "0D1C0D1C151C0D1C0D1C0D110D150D110D1C0D1C0D1C0D1C0D1C0D1C0D1C0D1C0D1C0D1C0D150D1515150D150D1C0D1C0D1C0D1C0D1C"

-- uranium
local reactorCode = "030C0D140D0D0C0D15150C0D0D0C0D0D030D150D030D0D030D0D0C0C0D0D0C0D0D0C0D150D030D0D030D0D030D150D0C150D0C150D0C"

local gridWidth = 9
local gridHeight = 6

local chestSide = sides.right
local reactorSide = sides.back

local transposer = component.transposer

local componentList = {
    "empty","fuelRodUranium","dualFuelRodUranium",
    "quadFuelRodUranium","fuelRodMox","dualFuelRodMox",
    "quadFuelRodMox","neutronReflector","thickNeutronReflector",
    "heatVent","advancedHeatVent","reactorHeatVent",
    "IC2:reactorVentSpread","IC2:reactorVentGold","coolantCell10k",
    "coolantCell30k","coolantCell60k","IC2:reactorHeatSwitch",
    "advancedHeatExchanger","coreHeatExchanger","IC2:reactorHeatSwitchSpread",
    "IC2:reactorPlating","heatCapacityReactorPlating","containmentReactorPlating",
    "rshCondensator","lzhCondensator","fuelRodThorium","dualFuelRodThorium",
    "quadFuelRodThorium","coolantCellHelium60k","coolantCellHelium180k",
    "coolantCellHelium360k","coolantCellNak60k","coolantCellNak180k",
    "coolantCellNak360k","iridiumNeutronReflector"
};

--[[
local componentList_36 = {
    "fuelRodUranium","dualFuelRodUranium","quadFuelRodUranium",
    nil, -- depleted isotope cell
    "neutronReflector","thickNeutronReflector","heatVent",
    "reactorHeatVent","IC2:reactorVentGold","advancedHeatVent",
    "componentHeatVent","rshCondensator","lzhCondensator",
    "IC2:reactorHeatSwitch","coreHeatExchanger","componentHeatExchanger",
    "advancedHeatExchanger","IC2:reactorPlating","heatCapacityReactorPlating",
    "containmentReactorPlating","coolantCell10k","coolantCell30k","coolantCell60k",
    nil,nil,nil,nil,nil,nil,nil,nil, -- heating cell
    "fuelRodThorium","dualFuelRodThorium","quadFuelRodThorium",
    nil,nil,nil, -- plutonium cells
    "iridiumNeutronReflector","coolantCellHelium60k","coolantCellHelium180k",
    "coolantCellHelium360k","coolantCellNak60k","coolantCellNak180k",
    "coolantCellNak360k"
}
]]

local function decode16(code)
    local reactor = {}
    local pos = 1
    for i=1,math.floor(#code/2) do
        local char = string.sub(code,pos,pos+1)
        reactor[i] = componentList[tonumber(char,16)+1]
        pos = pos + 2
    end
    return reactor
end

local function decode36(code)
    local reactor = {}

    -- this shit doesn't work

    --[[
    local function tobinary(n)
        local t = {}
        repeat
            local d = (n % 2)
            n = math.floor(n / 2)
            table.insert(t, 1, tostring(d))
        until n == 0
        return table.concat(t)
    end

    print(tonumber(code,36))

    local binary = {}
    for i=1,#code do binary[i] = tonumber(string.sub(code,i,i),36) end --string.sub(tobinary(tonumber(string.sub(code,i,i),36)),2,8) end
    binary = table.concat(binary)
    --binary = string.sub(binary,9)
    print(binary)

    local step = 7
    local pos = 8
    local i = 1
    while pos < #binary do
        local char = string.sub(binary,pos,pos+7)
        --print(char)
        local component = tonumber(char,2)

        if component <= 64 then
            if component then
                print("pos:",pos.."("..i..")","component:",component)
                reactor[i] = componentList_36[component+1]
            end

            i = i + 1
        end

        pos = pos + 8
    end
    ]]
    
    return reactor
end
local function decode(code)
    if #code > 100 then return decode16(code)
    else return decode36(code) end
end

local function scanInventory(side)
    local result = {}
    local size = transposer.getInventorySize(side)
    for i=1,size do
        local stack = transposer.getStackInSlot(side,i)
        if stack ~= nil then
            result[i] = stack
        end
    end
    return result
end

local function findComponent(inv_scan,id)
    --if string.sub(id, 1, 4) ~= "IC2:" then return end
    --print("Sucking: ", id)
    for i=1, #inv_scan do
        local stack = inv_scan[i]
        if stack ~= nil and stack.name == id and stack.size > 0 then
            --local success = inventory.suckFromSlot(chestSide, i, 1)
            --if not success then error("failed to suck component?") end
            stack.size = stack.size - 1
            return i
        end
    end
    return false   
end

local function getNeededComponents(components)
    local neededComponents = {}
    for row=1, gridHeight do
        for column=1, gridWidth do
            local id = components[(row-1)*gridWidth+column]
            --if string.sub(id, 1, 4) == "IC2:" then
                neededComponents[id] = neededComponents[id] or 0
                neededComponents[id] = neededComponents[id] + 1
            --end
        end
    end
    return neededComponents
end

local function processComponents(components)
    local inv = scanInventory(chestSide)
--    robot.select(1)
    for row=1, gridHeight do
        for column=1, gridWidth do
            local currentComponent = components[(row-1)*gridWidth+column]
            local componentSlot = findComponent(inv,currentComponent)
            if componentSlot ~= false then
              local inventorySlot = ((row-1)*gridWidth) + column
              io.write("dropping ", row, column, " name ", currentComponent, " into slot ", inventorySlot)
              local success, err = transposer.transferItem(chestSide, reactorSide, 1, componentSlot, inventorySlot)
              --success, err = inventory.dropIntoSlot(reactorSide, inventorySlot, 1 )
              if success then
                print("move successful")
              else
                print("move failed!")
                --error(err)
              end
            end
       end
    end
end

local components = decode16(reactorCode)
for k,v in pairs(getNeededComponents(components)) do print("#" .. v, k) end
print("Press to continue")
io.read()
processComponents(components)
