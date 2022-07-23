local component = require("component")
local term = require("term")
local os = require("os")
local string = require("string")
local sides = require("sides")
local redstone = component.redstone
local neutron = component.gt_machine

local MeV = 215e6 -- Naq-Ad Solution => Adamantite, Naquadah Oxide, Naquadah-rich solution
--local MeV = 1075e6 -- Naquadah-rich solution => naquadria sulphate
--local MeV = 470e6 -- Concentrated enriched-naquadah sludge => enriched-naquadah sulphate, sodium sulfate, low quality naquadria

function asdf()
  while true do
    term.clear()
    term.setCursor(1,1)
    local info = neutron.getSensorInformation()
    info = string.gsub(info[4], "§d", "")
    info = string.gsub(info, "§r", "")
    info = string.gsub(info, "eV", "")
    info = string.gsub(info, ",", "")
    info = info:sub(33)
    info = tonumber(info)
    if(info < MeV) then
      print("Sending redstone")
      redstone.setOutput(sides.bottom, 15)
    else
      print("No redstone")
      redstone.setOutput(sides.bottom, 0)
    end
    print(info)
    os.sleep(1)
  end
end

function printAll(table)
  for k,v in pairs(table) do
    print(k.." - "..v)
  end
end

asdf()
