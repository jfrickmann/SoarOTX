-- JFXJ/ALIGN.lua
-- Timestamp: 2021-11-07
-- Created by Jesper Frickmann

local N = 32 -- Highest output channel number
local INP_STEP = getFieldInfo("input8").id -- Step input before applying the output curves must be assigned to a channel

local GV_FLP_ALIGN = 0 -- Index of global variable set by rudder trim for left/right flap curve alignment
local GV_FLP_ADJUST = 1 -- Index of global variable set by throttle trim for common flap curve adjustment
local GV_AIL_ALIGN = 2 -- Index of global variable set by aileron trim for left/right aileron curve alignment
local GV_AIL_ADJUST = 3 -- Index of global variable set by elevator trim for common aileron curve adjustment

local CRV_AIL_LFT = 0 -- Index of the left aileron curve
local CRV_AIL_RGT = 1 -- Index of the right aileron curve
local CRV_FLP_LFT = 2 -- Index of the left flap curve
local CRV_FLP_RGT = 3 -- Index of the right flap curve

local cf = ...
local ui = {} -- Data shared with GUI
ui.n = 5 -- Number of points on the curves

local n1 = ui.n + 1 -- n + 1
local midpt = n1 / 2 -- Mid point on curve
local reset = 0 -- Reset if > 0. 2 is non-increasing outputs; force reset or quit

local lftAilCrv -- Table with data for the left aileron curve
local rgtAilCrv -- Table with data for the right aileron curve
local lftFlpCrv -- Table with data for the left flap curve
local rgtFlpCrv -- Table with data for the right flap curve

local lftAilOut -- Table with data for the left aileron output channel
local rgtAilOut -- Table with data for the right aileron output channel
local lftFlpOut -- Table with data for the left flap output channel
local rgtFlpOut -- Table with data for the right flap output channel

local lftAilOutIndex -- Index of the left aileron output channel
local rgtAilOutIndex -- Index of the right aileron output channel
local lftFlpOutIndex -- Index of the left flap output channel
local rgtFlpOutIndex -- Index of the right flap output channel

local lftAilY = {} -- Output values after applying curve and center/endpoints for left aileron channel
local rgtAilY = {} -- Output values after applying curve and center/endpoints for right aileron channel
local lftFlpY = {} -- Output values after applying curve and center/endpoints for left flap channel
local rgtFlpY = {} -- Output values after applying curve and center/endpoints for right flap channel

local lastPoint = 0 -- Index of point on the curve last time
local lastAilAdjust -- Average aileron y-value last time
local lastAilAlign -- Aileron y-value difference last time
local lastFlpAdjust -- Average flap y-value last time
local lastFlpAlign -- Flap y-value difference last time

soarUtil.LoadWxH("JFXJ/ALIGN.lua", ui) -- Screen size specific function

-- Find index of the curve point that corresponds to the value of the step input
local function FindPoint()
	local x = getValue(INP_STEP)
	return math.floor((ui.n - 1) / 2048 * (x + 1024) + 1.5) 
end -- FindPoint()

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
	if rgtAilY[1] > 0 or rgtAilY[1] < -1500 or rgtAilY[ui.n] < 0 or rgtAilY[ui.n] > 1500 or 
	   lftAilY[1] > 0 or lftAilY[1] < -1500 or lftAilY[ui.n] < 0 or lftAilY[ui.n] > 1500 then
		return false
	end

	if rgtFlpY[1] > 0 or rgtFlpY[1] < -1500 or rgtFlpY[ui.n] < 0 or rgtFlpY[ui.n] > 1500 or 
	   lftFlpY[1] > 0 or lftFlpY[1] < -1500 or lftFlpY[ui.n] < 0 or lftFlpY[ui.n] > 1500 then
		return false
	end

	-- Check that ys are monotonically increasing
	for p = 2, ui.n do
		if rgtAilY[p] - rgtAilY[p - 1] < 10 or lftAilY[p] - lftAilY[p - 1] < 10 then
			return false
		end

		if rgtFlpY[p] - rgtFlpY[p - 1] < 10 or lftFlpY[p] - lftFlpY[p - 1] < 10 then
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
		lastAilAdjust = math.floor(0.033 * (rgtAilY[point] - lftAilY[n1 - point]) + 0.5)
		lastAilAlign = math.floor(0.066 * (rgtAilY[point] + lftAilY[n1 - point]) + 0.5)		
		lastFlpAdjust = math.floor(0.033 * (rgtFlpY[point] - lftFlpY[n1 - point]) + 0.5)
		lastFlpAlign = math.floor(0.066 * (rgtFlpY[point] + lftFlpY[n1 - point]) + 0.5)
		
		model.setGlobalVariable(GV_AIL_ADJUST, soarUtil.FM_ADJUST, lastAilAdjust)
		model.setGlobalVariable(GV_AIL_ALIGN, soarUtil.FM_ADJUST, lastAilAlign)
		model.setGlobalVariable(GV_FLP_ADJUST, soarUtil.FM_ADJUST, lastFlpAdjust)
		model.setGlobalVariable(GV_FLP_ALIGN, soarUtil.FM_ADJUST, lastFlpAlign)
end -- UpdateGVs()

local function init()
	lftAilCrv = model.getCurve(CRV_AIL_LFT)
	lftAilOutIndex, lftAilOut = GetOutput(CRV_AIL_LFT)
	ComputeYs(lftAilCrv, lftAilOut, lftAilY)

	rgtAilCrv = model.getCurve(CRV_AIL_RGT)
	rgtAilOutIndex, rgtAilOut = GetOutput(CRV_AIL_RGT)
	ComputeYs(rgtAilCrv, rgtAilOut, rgtAilY)

	lftFlpCrv = model.getCurve(CRV_FLP_LFT)
	lftFlpOutIndex, lftFlpOut = GetOutput(CRV_FLP_LFT)	
	ComputeYs(lftFlpCrv, lftFlpOut, lftFlpY)
	
	rgtFlpCrv = model.getCurve(CRV_FLP_RGT)
	rgtFlpOutIndex, rgtFlpOut = GetOutput(CRV_FLP_RGT)
	ComputeYs(rgtFlpCrv, rgtFlpOut, rgtFlpY)
	
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
	cf.SetAdjust(1)

	-- Handle EXIT
	if event == EVT_VIRTUAL_EXIT then
		if reset == 1 then
			-- Do not reset curves
			reset = 0
		else
			-- Quit
			return true
		end
	end
	
	-- Handle ENTER
	if event == EVT_VIRTUAL_ENTER then
		if reset == 0 then
			reset = 1
		else
			-- Reset outputs
			Reset(lftAilCrv, CRV_AIL_LFT, lftAilOut, lftAilOutIndex)
			Reset(rgtAilCrv, CRV_AIL_RGT, rgtAilOut, rgtAilOutIndex) 
			Reset(lftFlpCrv, CRV_FLP_LFT, lftFlpOut, lftFlpOutIndex)
			Reset(rgtFlpCrv, CRV_FLP_RGT, rgtFlpOut, rgtFlpOutIndex) 

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

	-- First ailerons
	dAdjust = 10 * (model.getGlobalVariable(GV_AIL_ADJUST, soarUtil.FM_ADJUST) - lastAilAdjust)
	dAlign = 5 * (model.getGlobalVariable(GV_AIL_ALIGN, soarUtil.FM_ADJUST) - lastAilAlign)

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
		
			rgtAilY[p] = rgtAilY[p] + fac * (dAlign + dAdjust)
			lftAilY[n1 - p] = lftAilY[n1 - p] + fac * (dAlign - dAdjust)
		end

		-- If a curve is no longer OK, then cancel the change
		if not ValidateYs() then
			ComputeYs(rgtAilCrv, rgtAilOut, rgtAilY)
			ComputeYs(lftAilCrv, lftAilOut, lftAilY)
		end
		
		UpdateGVs(point)

		-- Update curves and channel outputs
		ApplyYs(rgtAilCrv, CRV_AIL_RGT, rgtAilOut, rgtAilOutIndex, rgtAilY)
		ApplyYs(lftAilCrv, CRV_AIL_LFT, lftAilOut, lftAilOutIndex, lftAilY)
	end
	
	-- Then flaps
	dAdjust = 10 * (model.getGlobalVariable(GV_FLP_ADJUST, soarUtil.FM_ADJUST) - lastFlpAdjust)
	dAlign = 5 * (model.getGlobalVariable(GV_FLP_ALIGN, soarUtil.FM_ADJUST) - lastFlpAlign)

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
		
			rgtFlpY[p] = rgtFlpY[p] + fac * (dAlign + dAdjust)
			lftFlpY[n1 - p] = lftFlpY[n1 - p] + fac * (dAlign - dAdjust)
		end

		-- If a curve is no longer OK, then cancel the change
		if not ValidateYs() then
			ComputeYs(rgtFlpCrv, rgtFlpOut, rgtFlpY)
			ComputeYs(lftFlpCrv, lftFlpOut, lftFlpY)
		end
		
		UpdateGVs(point)

		-- Update curves and channel outputs
		ApplyYs(rgtFlpCrv, CRV_FLP_RGT, rgtFlpOut, rgtFlpOutIndex, rgtFlpY)
		ApplyYs(lftFlpCrv, CRV_FLP_LFT, lftFlpOut, lftFlpOutIndex, lftFlpY)
	end
	
	ui.Draw(rgtAilY, lftAilY, rgtFlpY, lftFlpY, point)
	soarUtil.ShowHelp({msg1 = "Throttle - select point", msg2 = "Trim - adjust/align", enter = "RESET", exit = "DONE" })
end -- run()

return{init = init, run = run}