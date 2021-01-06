-- JF F3RES mix adjustment
-- Timestamp: 2021-01-02
-- Created by Jesper Frickmann

local cf = ...
local gv1 = getFieldInfo("gvar1").id

local Draw = soarUtil.LoadWxH("JF3R/ADJMIX.lua", gv1) -- Screen size specific function

local function run(event)
	-- Press EXIT to quit
	if event == EVT_VIRTUAL_EXIT then
		return true
	end
	
	-- Enable adjustment function
	cf.SetAdjust(1)
	
	Draw()
end -- run()

return{run = run}