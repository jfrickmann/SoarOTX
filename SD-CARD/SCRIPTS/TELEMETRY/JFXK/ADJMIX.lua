-- JF FxK mix adjustment
-- Timestamp: 2021-01-02
-- Created by Jesper Frickmann

local cf = ...
local ui = soarUtil.LoadWxH("JFXK/ADJMIX.lua", ui) -- Screen size specific function

-- For updating aileron throws with negative differential
ui.gvAil = 0 -- Index of global variable used for aileron travel
ui.gvBrk = 1 -- Index of global variable used for air brake travel
ui.gvDif = 3 -- Index of global variable used for aileron differential

-- This is pretty messy, but getValue works better for getting values for the current flight mode,
-- whereas getGlobalVariable works better for flight mode 0 and for setting GVs from Lua 
ui.gv3 = getFieldInfo("gvar3").id
ui.gv4 = getFieldInfo("gvar4").id
ui.gv5 = getFieldInfo("gvar5").id
ui.gv6 = getFieldInfo("gvar6").id

local function run(event)
	-- Press EXIT to quit
	if event == EVT_VIRTUAL_EXIT then
		return true
	end
	
	-- Enable adjustment function
	cf.SetAdjust(3)
	
	-- Run user interface
	return ui.run(event)
end

return{run = run}