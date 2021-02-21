--[[
name = item name in game
label = item label in game
damage = item damage
keepStocked = keep this many in storage
threshold = start crafting if theres less than keepStocked-threshold in storage
redstoneFrequency = if crafting then emit redstone at this frequency (can be used for toggling spawners)
waitToCraft = wait this many seconds before starting to craft, if threshold is ok
balanceWith = item filters to balance with (name/label/damage)
balanceRatio = if balanceWith quantity is higher than this item*balanceRatio, craft this
balanceFixed = if balanceWith quantity is higher than balanceFixed, craft this

condition:
materials - divide toCraft by this
]]--
local autocraftData = {}
autocraftData["Tiny Titanium Dust"] = {
	name="gregtech:gt.metaitem.01",
	damage=28,
	keepStocked=100,
	threshold=0
}
autocraftData["Raw Rubber Dust"] = {
	name="gregtech:gt.metaitem.01",
	damage=2896,
	keepStocked=5000,
	threshold=1000
}
autocraftData["Powderbarrel"] = {
	label="gt.blockreinforced.5.name",
	keepStocked=1024,
	threshold=100
}
autocraftData["Duct tape"] = {
	label="gt.metaitem.01.32764.name",
	keepStocked=100,
	threshold=0
}
--cells
autocraftData["Oxygen Cell"] = {
	label="gt.metaitem.01.30013.name",
	keepStocked=5000,
	threshold=2500
}
autocraftData["Hydrogen Cell"] = {
	label="gt.metaitem.01.30001.name",
	keepStocked=5000,
	threshold=2500
}
autocraftData["Nitrogen Cell"] = {
	label="gt.metaitem.01.30012.name",
	keepStocked=5000,
	threshold=2500
}
autocraftData["Naphtha Cell"] = {
	label="gt.metaitem.01.30739.name",
	keepStocked=1000,
	threshold=500
}
autocraftData["Chlorine Cell"] = {
	label="gt.metaitem.01.30023.name",
	keepStocked=1000,
	threshold=500
}
autocraftData["Fluorine Cell"] = {
	label="gt.metaitem.01.30014.name",
	keepStocked=1000,
	threshold=500
}
autocraftData["Sulfuric Acid Cell"] = {
	label="gt.metaitem.01.30720.name",
	keepStocked=1000,
	threshold=500
}
autocraftData["Water Cell"] = {
	label="Water Cell",
	keepStocked=1000,
	threshold=500
}
--ebf
autocraftData["Chrome Ingot"] = {
	label="gt.metaitem.01.11030.name",
	keepStocked=100,
	threshold=50
}
autocraftData["Palladium Ingot"] = {
	label="gt.metaitem.01.11052.name",
	keepStocked=1000,
	threshold=800
}
autocraftData["Silicon Ingot"] = {
	label="gt.metaitem.01.11020.name",
	keepStocked=1000,
	threshold=800
}
autocraftData["Lutetium Ingot"] = {
	label="gt.metaitem.01.11078.name",
	keepStocked=100,
	threshold=0
}
autocraftData["Enriched Naquadah Ingot"] = {
	label="gt.metaitem.01.11326.name",
	keepStocked=1000,
	threshold=64
}
--other ingots
autocraftData["Magnesium Ingot"] = {
	label="gt.metaitem.01.11018.name",
	keepStocked=1000,
	threshold=800
}
autocraftData["Magnesium Dust"] = {
	label="gt.metaitem.01.2018.name",
	keepStocked=10000,
	threshold=1000
}
autocraftData["Tin Ingot"] = {
	label="gt.metaitem.01.11057.name",
	keepStocked=10000,
	threshold=1000
}

-- IC2
autocraftData["Empty Cell"] = {
	name="IC2:itemCellEmpty",
	keepStocked=1000,
	threshold=500
}
-- AE
autocraftData["Blank Pattern"] = {
	label="Blank Pattern",
	keepStocked=64,
	threshold=0
}
autocraftData["Quartz Fiber"] = {
	label="Quartz Fiber",
	keepStocked=64,
	threshold=0
}
autocraftData["ME Glass Cable - Fluix"] = {
	label="ME Glass Cable - Fluix",
	keepStocked=128,
	threshold=0
}
autocraftData["Charged Certus Quartz"] = {
	label="Charged Certus Quartz Crystal",
	keepStocked=1000,
	threshold=500
}
autocraftData["Pure Certus Quartz"] = {
	label="Pure Certus Quartz Crystal",
	keepStocked=1000,
	threshold=500
}
autocraftData["Pure Fluix Crystal"] = {
	label="Pure Fluix Crystal",
	keepStocked=1000,
	threshold=500
}

-- MC
autocraftData["Paper"] = {
	label="Paper",
	keepStocked=100,
	threshold=0
}
autocraftData["Stick"] = {
	label="Stick",
	keepStocked=1000,
	threshold=100
}
autocraftData["Planks"] = {
	name="ExtrabiomesXL:planks",
	damage=1,
	keepStocked=1000,
	threshold=100
}
autocraftData["Bone Meal"] = {
	label="Bone Meal",
	keepStocked=5000,
	threshold=4000
}
--[[ spawners
autocraftData["Leather"] = {
	label="Leather",
	keepStocked=5000,
	threshold=100,
	redstoneFrequency=4987
}
autocraftData["Raw Beef"] = {
	label="Raw Beef",
	keepStocked=5000,
	threshold=100,
	redstoneFrequency=4987
}
autocraftData["Ender Pearl"] = {
	label="Ender Pearl",
	keepStocked=2000,
	threshold=0,
	redstoneFrequency=4988
}
autocraftData["Feather"] = {
	label="Feather",
	keepStocked=200,
	threshold=0,
	redstoneFrequency=4985
}
autocraftData["Blaze Rod"] = {
	label="Blaze Rod",
	keepStocked=2000,
	threshold=0,
	redstoneFrequency=4986
}
autocraftData["Ink Sac"] = {
	label="Ink Sac",
	keepStocked=5000,
	threshold=2500,
	redstoneFrequency=4984
}
autocraftData["Bone"] = {
	label="Bone",
	keepStocked=5000,
	threshold=2500,
	redstoneFrequency=4999
}
--]]
--[[autocraftData["Gunpowder"] = {
	label="Gunpowder",
	keepStocked=50000,
	threshold=2500,
	redstoneFrequency=4999
}]]--
return autocraftData
