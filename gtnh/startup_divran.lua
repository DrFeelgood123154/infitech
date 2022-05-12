local url = "http://81.233.65.53/opencomputers/gtnh/"

local files = {
	"ac_data.lua",
	"autocrafter.lua",
	"electricity_display.lua",
	"main_pc.lua"
}
for k,v in pairs(files) do os.execute("wget -f " .. url .. v) end
os.execute(files[#files])