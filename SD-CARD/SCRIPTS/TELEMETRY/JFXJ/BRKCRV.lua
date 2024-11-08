-- JFXJ/BRKCRV.lua
-- Timestamp: 2024-11-07
-- Created by Jesper Frickmann

local GV_FLP = 1 -- Index of global variable set by throttle trim for common flap curve adjustment
local GV_AIL = 3 -- Index of global variable set by elevator trim for common aileron curve adjustment

local CRV_FLP = 4 -- Index of the  flap curve
local CRV_AIL = 5 -- Index of the  aileron curve

local INP_STEP = getFieldInfo("input8").id -- Step input before applying the output curves must be assigned to a channel

local cf = ...
local ui = {} -- Data shared with GUI
ui.n = 5 -- Number of points on the curves

local flpCrv -- Table with data for the flap curve
local ailCrv -- Table with data for the aileron curve
local lastpoint = 0 -- Index of point on the curves last time

soarUtil.LoadWxH("JFXJ/BRKCRV.lua", ui) -- Screen size specific function

-- Find index of the curve point that corresponds to the value of the step input
local function FindPoint()
	local x = getValue(INP_STEP)
	return math.floor((ui.n - 1) / 2048 * (x + 1024) + 1.5) 
end -- FindPoint()

local function init()
	flpCrv = model.getCurve(CRV_FLP)
	ailCrv = model.getCurve(CRV_AIL)
end -- init()

local function run(event)
	-- Press EXIT to quit
	if event == EVT_VIRTUAL_EXIT then
		return true
	end
	
	local point = FindPoint() -- Index of curve points to change

	-- Enable adjustment function
	cf.SetAdjust(2)

	-- If index changed, then set GV to current dif. value
	if point ~= lastpoint then
		model.setGlobalVariable(GV_FLP, 1, flpCrv.y[point])
		model.setGlobalVariable(GV_AIL, 1, ailCrv.y[point])
		lastpoint = point
	end
	
	flpCrv.y[point] = model.getGlobalVariable(GV_FLP, soarUtil.FM_ADJUST)
	model.setCurve(CRV_FLP, flpCrv)

	ailCrv.y[point] = model.getGlobalVariable(GV_AIL, soarUtil.FM_ADJUST)
	model.setCurve(CRV_AIL, ailCrv)

	ui.Draw(flpCrv.y, ailCrv.y, point)
	soarUtil.ShowHelp({msg1 = "Throttle - select point", msg2 = "TrmT, TrmE - adjust", exit = "DONE" })
end -- run()

return{init = init, run = run}