-- JF FxK air brake and aileron travel adjustment
-- Timestamp: 2021-01-02
-- Created by Jesper Frickmann

local GV_AIL = 0 -- Index of global variable used for aileron travel
local GV_BRK = 1 -- Index of global variable used for air brake travel
local GV_DIF = 3 -- Index of global variable used for aileron differential
local cf = ...
local Draw = soarUtil.LoadWxH("JFXK/CENTER.lua") -- Screen size specific function

local function run(event)
	-- Press EXIT to quit
	if event == EVT_VIRTUAL_EXIT then
		return true
	end
	
	local brk = model.getGlobalVariable(GV_BRK, 0)
	local dif = model.getGlobalVariable(GV_DIF, 0)
	
	-- Enable adjustment function
	cf.SetAdjust(2)
	
	-- Compensate for negative differential
	local difComp = 100.0 / math.max(50.0, math.min(100.0, 100.0 + dif))
	
	-- Calculate aileron travel from current air brak travel
	local ail = math.min(200, 2 * (100 - brk) * difComp)
	
	model.setGlobalVariable(GV_AIL, 0, ail)
	Draw(ail, brk)
end -- run()

return{run = run}