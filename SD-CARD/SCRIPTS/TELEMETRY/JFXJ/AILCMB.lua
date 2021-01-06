-- JF FXJ aileron and camber adjustment
-- Timestamp: 2021-01-02
-- Created by Jesper Frickmann

local cf = ...
local gv1 = getFieldInfo("gvar1").id -- Aileron
local gv2 = getFieldInfo("gvar2").id -- Aileron -> Flap
local gv5 = getFieldInfo("gvar7").id -- Camber -> Aileron

local Draw = soarUtil.LoadWxH("JFXJ/AILCMB.lua", gv1, gv2, gv5) -- Screen size specific function

local function run(event)
	-- Press EXIT to quit
	if event == EVT_VIRTUAL_EXIT then
		return true
	end
	
	-- Enable adjustment function
	cf.SetAdjust(3)
	
	Draw()
end -- run()

return{run = run}