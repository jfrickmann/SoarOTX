-- JF FXJ mix adjustment
-- Timestamp: 2019-09-29
-- Created by Jesper Frickmann

local gv3 = getFieldInfo("gvar3").id
local gv4 = getFieldInfo("gvar4").id
local gv6 = getFieldInfo("gvar6").id
local gv7 = getFieldInfo("gvar7").id

local Draw = soarUtil.LoadWxH("JFXJ/ADJMIX.lua", gv3, gv4, gv6, gv7) -- Screen size specific function

local function run(event)
	-- Press EXIT to quit
	if event == EVT_EXIT_BREAK then
		return true
	end
	
	-- Enable adjustment function
	adj = 4
	
	Draw()
end -- run()

return{run = run}