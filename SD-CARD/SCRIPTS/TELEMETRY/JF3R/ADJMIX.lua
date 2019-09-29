-- JF F3RES mix adjustment
-- Timestamp: 2019-09-29
-- Created by Jesper Frickmann

local gv1 = getFieldInfo("gvar1").id

local Draw = soarUtil.LoadWxH("JF3R/ADJMIX.lua", gv1) -- Screen size specific function

local function run(event)
	-- Press EXIT to quit
	if event == EVT_EXIT_BREAK then
		return true
	end
	
	-- Enable adjustment function
	adj = 1
	
	Draw()
end -- run()

return{run = run}