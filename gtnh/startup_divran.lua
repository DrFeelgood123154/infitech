local url = "http://81.233.65.53/opencomputers/gtnh/"
local f1 = "ac_data.lua"
local f2 = "main_pc.lua"
os.execute("resolution 70 25")
os.execute("wget -f " .. url .. f1)
os.execute("wget -f " .. url .. f2)
os.execute(f2)