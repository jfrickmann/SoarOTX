-- JFXJ/BRKCRV.lua
-- Timestamp: 2020-04-18
-- Created by Jesper Frickmann

local cf = ...
local ui = {} -- Data shared with GUI
ui.n = 5 -- Number of points on the curves

local xInput = getFieldInfo("input8").id -- Step input before applying the output curves must be assigned to a channel
local lastpoint = 0 -- Index of point on the curves last time

local gvFlp = 1 -- Index of global variable set by throttle trim for common flap curve adjustment
local gvAil = 3 -- Index of global variable set by elevator trim for common aileron curve adjustment

local flpCrv -- Table with data for the flap curve
local ailCrv -- Table with data for the aileron curve

local flpCrvIndex = 4 -- Index of the  flap curve
local ailCrvIndex = 5 -- Index of the  aileron curve

soarUtil.LoadWxH("JFXJ/BRKCRV.lua", ui) -- Screen size specific function

-- Find index of the curve point that corresponds to the value of the step input
local function FindPoint()
	local x = getValue(xInput)
	return math.floor((ui.n - 1) / 2048 * (x + 1024) + 1.5) 
end -- FindPoint()

-- Work around the stupid fact that getCurve and setCurve tables are incompatible...
local function GetCurve(crvIndex)
	local newTbl = {}
	local oldTbl = model.getCurve(crvIndex)
	
	newTbl.y = {}
	for i = 1, ui.n do
		newTbl.y[i] = oldTbl.y[i - 1]
	end
	
	newTbl.smooth = 0
	newTbl.name = oldTbl.name
	
	return newTbl
end -- GetCurve()

local function init()
	flpCrv = GetCurve(flpCrvIndex)
	ailCrv = GetCurve(ailCrvIndex)
end -- init()

local function run(event)
	-- Press EXIT to quit
	if soarUtil.EvtExit(event) then
		return true
	end
	
	local point = FindPoint() -- Index of curve points to change

	-- Enable adjustment function
	cf.SetAdjust(2)

	-- If index changed, then set GV to current dif. value
	if point ~= lastpoint then
		model.setGlobalVariable(gvFlp, 1, flpCrv.y[point])
		model.setGlobalVariable(gvAil, 1, ailCrv.y[point])
		lastpoint = point
	end
	
	flpCrv.y[point] = model.getGlobalVariable(gvFlp, 1)
	model.setCurve(flpCrvIndex, flpCrv)

	ailCrv.y[point] = model.getGlobalVariable(gvAil, 1)
	model.setCurve(ailCrvIndex, ailCrv)

	ui.Draw(flpCrv.y, ailCrv.y, point)
	soarUtil.ShowHelp({msg1 = "Throttle - select point", msg2 = "TrmT, TrmE - adjust", exit = "DONE" })
end -- run()

return{init = init, run = run}