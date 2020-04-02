-- JF F3K Flaperon Adjustment
-- Timestamp: 2020-04-02
-- Created by Jesper Frickmann
-- Script for adjusting the flaperon output curves for the JF F3K program.

local N = 32 -- Highest output channel number
local ui = {} -- Data shared with GUI
ui.n = 5 -- Number of points on the curves

local n1 = ui.n + 1 -- n + 1
local midpt = n1 / 2 -- Mid point on curve
local reset = 0 -- Reset if > 0. 2 is non-increasing outputs; force reset or quit

local xInput = getFieldInfo("input7").id -- Step input before applying the output curves must be assigned to a channel
local gvAdjust = 7 -- Index of global variable set by throttle trim for common curve adjustment
local gvAlign = 8 -- Index of global variable set by aileron trim for left/right curve alignment

local rgtCrv -- Table with data for the right flaperon curve
local lftCrv -- Table with data for the left flaperon curve
local rgtCrvIndex = 1 -- Index of the right flaperon curve
local lftCrvIndex = 0 -- Index of the left flaperon curve

local rgtOut -- Table with data for the right flaperon output channel
local lftOut -- Table with data for the left flaperon output channel
local rgtOutIndex -- Index of the right output channel
local lftOutIndex -- Index of the left output channel

local rgtY = {} -- Output values after applying curve and center/endpoints for right channel
local lftY = {} -- Output values after applying curve and center/endpoints for left channel

local lastPoint = 0 -- Index of point on the curve last time
local lastAdjust -- Average y-value last time
local lastAlign -- Y-value difference last time

soarUtil.LoadWxH("JF3K/ALIGN.lua", ui) -- Screen size specific function

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
	for p = 1, ui.n do
		newTbl.y[p] = oldTbl.y[p - 1]
	end
	
	newTbl.smooth = 1
	newTbl.name = oldTbl.name
	
	return newTbl
end -- GetCurve()

-- Find the output where the specified curve index is being used
local function GetOutput(crvIndex)
	for i = 0, N - 1 do
		local out = model.getOutput(i)
		
		if out and out.curve == crvIndex then
			return i, out
		end
	end
end -- GetOutput()

-- Compute output after applying curve and center/endpoints
local function ComputeYs(crv, out, y)
	for p = 1, ui.n do
		if crv.y[p] < 0 then
			y[p] = out.offset + 0.01 * crv.y[p] * (out.offset - out.min)
		else
			y[p] = out.offset + 0.01 * crv.y[p] * (out.max - out.offset)
		end
	end
end -- ComputeYs()

-- Verify that both curves are monotonically increasing and within limits
local function ValidateYs()
	-- Check limits
	if rgtY[1] > 0 or rgtY[1] < -1500 or rgtY[ui.n] < 0 or rgtY[ui.n] > 1500 or 
	   lftY[1] > 0 or lftY[1] < -1500 or lftY[ui.n] < 0 or lftY[ui.n] > 1500 then
		return false
	end

	-- Check that ys are monotonically increasing
	for p = 2, ui.n do
		if rgtY[p] - rgtY[p - 1] < 10 or lftY[p] - lftY[p - 1] < 10 then
			return false
		end
	end
	
	return true
end -- ValidateYs()

-- Apply y-values to final outputs
local function ApplyYs(crv, crvIndex, out, outIndex, y)
	out.min = y[1]
	out.offset = y[midpt]
	out.max = y[ui.n]
	
	for p = 1, midpt do
		crv.y[p] = 100 * (y[p] - out.offset) / (out.offset - out.min)
	end
	
	for p = midpt + 1, ui.n do
		crv.y[p] = 100 * (y[p] - out.offset) / (out.max - out.offset)
	end
	
	model.setOutput(outIndex, out)
	model.setCurve(crvIndex, crv)
end -- ApplyYs()

-- Update GVs to reflect current point; applying limits may affect it so it has to reset
local function UpdateGVs(point)
		-- Left curve is backwards; both by index and y-value
		lastAdjust = math.floor(0.2 * (rgtY[point] - lftY[n1 - point]) + 0.5)
		lastAlign = math.floor(0.2 * (rgtY[point] + lftY[n1 - point]) + 0.5)
		
		model.setGlobalVariable(gvAdjust, 0, lastAdjust)
		model.setGlobalVariable(gvAlign, 0, lastAlign)
end -- UpdateGVs()

local function init()
	rgtCrv = GetCurve(rgtCrvIndex)
	rgtOutIndex, rgtOut = GetOutput(rgtCrvIndex)
	
	lftCrv = GetCurve(lftCrvIndex)
	lftOutIndex, lftOut = GetOutput(lftCrvIndex)
	
	ComputeYs(rgtCrv, rgtOut, rgtY)
	ComputeYs(lftCrv, lftOut, lftY)
	
	if not ValidateYs() then reset = 2 end
end -- init()

-- Reset outputs
local function Reset(crv, crvIndex, out, outIndex)
	for p = 1, ui.n do
		crv.y[p] = 200.0 / (ui.n - 1) * (p - midpt)
	end
	
	out.min = -1000
	out.offset = 0
	out.max = 1000
	
	model.setCurve(crvIndex, crv)
	model.setOutput(outIndex, out)
	
	init()
end -- Reset()

local function run(event)
	-- Enable adjustment function
	adj = 1

	-- Handle EXIT
	if soarUtil.EvtExit(event) then
		if reset == 1 then
			-- Do not reset curves
			reset = 0
		else
			-- Quit
			return true
		end
	end
	
	-- Handle ENTER
	if soarUtil.EvtEnter(event) then
		if reset == 0 then
			reset = 1
		else
			-- Reset outputs
			Reset(rgtCrv, rgtCrvIndex, rgtOut, rgtOutIndex) 
			Reset(lftCrv, lftCrvIndex, lftOut, lftOutIndex)
			reset = 0
		end
	end
	
	-- Waiting for input in reset mode
	if reset ~= 0 then 
		ui.DrawReset(reset)
		return
	end
	
	-- Index of selected curve point
	local point = FindPoint()

	-- If index changed, then set GV to current dif. value
	if point ~= lastPoint then
		lastPoint = point
		UpdateGVs(point)
	end
	
	-- If a GV changed, record changes to determine alignment and adjustment
	local dAdjust, dAlign

	dAdjust = 5 * (model.getGlobalVariable(gvAdjust, 0) - lastAdjust)
	dAlign = 2.5 * (model.getGlobalVariable(gvAlign, 0) - lastAlign)

	if dAdjust ~= 0 or dAlign ~= 0 then
		local fac
		
		-- Update the y-values using the "rubber band" algorithm
		for p = 1, ui.n do
			if p < point then
				fac = (p - 1) / (point - 1)
			elseif p > point then
				fac = (ui.n - p) / (ui.n - point)
			else
				fac = 1
			end
		
			rgtY[p] = rgtY[p] + fac * (dAlign + dAdjust)
			lftY[n1 - p] = lftY[n1 - p] + fac * (dAlign - dAdjust)
		end

		-- If a curve is no longer OK, then cancel the change
		if not ValidateYs() then
			ComputeYs(rgtCrv, rgtOut, rgtY)
			ComputeYs(lftCrv, lftOut, lftY)
		end
		
		UpdateGVs(point)

		-- Update curves and channel outputs
		ApplyYs(rgtCrv, rgtCrvIndex, rgtOut, rgtOutIndex, rgtY)
		ApplyYs(lftCrv, lftCrvIndex, lftOut, lftOutIndex, lftY)
	end
	
	ui.Draw(rgtY, lftY, point)
end -- run()

return{init = init, run = run}