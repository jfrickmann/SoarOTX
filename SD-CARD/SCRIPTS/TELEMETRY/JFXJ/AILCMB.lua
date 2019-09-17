-- JF FXJ aileron and camber adjustment
-- Timestamp: 2019-09-16
-- Created by Jesper Frickmann

local gv1 = getFieldInfo("gvar1").id
local gv2 = getFieldInfo("gvar2").id
local gv5 = getFieldInfo("gvar5").id

local Draw = LoadWxH("JFXJ/AILCMB.lua", gv1, gv2, gv5) -- Screen size specific function

local function run(event)
	-- Press EXIT to quit
	if event == EVT_EXIT_BREAK then
		return true
	end
	
	-- Enable adjustment function
	adj = 3
	
	Draw()
end -- run()

return{run = run}