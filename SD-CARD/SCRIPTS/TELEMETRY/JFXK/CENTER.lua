-- JF FxK air brake and aileron travel adjustment
-- Timestamp: 2020-04-13
-- Created by Jesper Frickmann

local gvAil = 0 -- Index of global variable used for aileron travel
local gvBrk = 1 -- Index of global variable used for air brake travel
local gvDif = 3 -- Index of global variable used for aileron differential
local cf = ...
local Draw = soarUtil.LoadWxH("JFXK/CENTER.lua") -- Screen size specific function

local function run(event)
	-- Press EXIT to quit
	if soarUtil.EvtExit(event) then
		return true
	end
	
	local brk = model.getGlobalVariable(gvBrk, 0)
	local dif = model.getGlobalVariable(gvDif, 0)
	
	-- Enable adjustment function
	cf.SetAdjust(2)
	
	-- Compensate for negative differential
	local difComp = 100.0 / math.max(50.0, math.min(100.0, 100.0 + dif))
	
	-- Calculate aileron travel from current air brak travel
	local ail = math.min(200, 2 * (100 - brk) * difComp)
	
	model.setGlobalVariable(gvAil, 0, ail)
	Draw(ail, brk)
end -- run()

return{run = run}