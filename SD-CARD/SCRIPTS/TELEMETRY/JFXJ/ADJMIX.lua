-- JF FXJ mix adjustment
-- Timestamp: 2021-01-02
-- Created by Jesper Frickmann

local cf = ...
local gv3 = getFieldInfo("gvar3").id -- Aileron -> Rudder
local gv4 = getFieldInfo("gvar4").id -- Differential
local gv6 = getFieldInfo("gvar5").id -- Brake -> Elevator
local gv7 = getFieldInfo("gvar6").id -- Snapflap

local Draw = soarUtil.LoadWxH("JFXJ/ADJMIX.lua", gv3, gv4, gv6, gv7) -- Screen size specific function

local function run(event)
	-- Press EXIT to quit
	if event == EVT_VIRTUAL_EXIT then
		return true
	end
	
	-- Enable adjustment function
	cf.SetAdjust(4)
	
	Draw()
end -- run()

return{run = run}