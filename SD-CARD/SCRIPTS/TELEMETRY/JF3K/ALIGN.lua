-- JF F3K Flaperon Adjustment
-- Timestamp: 2019-10-18
-- Created by Jesper Frickmann
-- Script for adjusting the flaperon output curves for the JF F3K program.

local gvIndex = 8 -- Index of global variable used for communicating with the model program
local xValue = getFieldInfo("input7").id -- Step input before applying the output curves must be assigned to a channel
local indexRgt = 1 -- Index of the right flaperon curve
local indexLft = 0 -- Index of the left flaperon curve
local avgs -- Average values of left and right
local difs -- Differences between left and right
local lasti -- Index of point on the curve last time
local ui = soarUtil.LoadWxH("JF3K/ALIGN.lua") -- Screen size specific function

ui.nPoints = 5 -- Number of points on the curves

ui.DrawCurve = function(x, y, w, h, crv, i)
	local x1, x2, y1, y2, y3
	local n = #(crv.y)
	
	for j = 1, n do
		local att
		-- Screen coordinates
		x2 = x  + w * (j - 1) / (n - 1)
		y2 = y + h * (0.5 - 0.005 * crv.y[j])
		-- Mark point i
		if j == i then
			att = SMLSIZE + INVERS
			y3 = crv.y[j]
		else
			att = SMLSIZE
		end
		-- Draw marker
		lcd.drawText(x2, y2 - 2.5, "|", att)
		-- Draw line
		if j >= 2 then
			lcd.drawLine(x1, y1, x2, y2, SOLID, FORCE)
		end
		-- Save this point before going to the next one
		x1, y1 = x2, y2
	end
	
	-- Draw reference lines
	lcd.drawLine(x, y + 0.5 * h, x + w, y + 0.5 * h, DOTTED, FORCE)
	lcd.drawLine(x + 0.5 * w, y, x + 0.5 * w, y + h, DOTTED, FORCE)

	-- Draw the value being edited
	lcd.drawNumber(x + w, y + h - 6, y3, RIGHT + SMLSIZE)
end -- DrawCurve()

-- Find index of the curve point that corresponds to the value of the step input
local function FindIndex()
	local x = getValue(xValue)
	return math.floor((ui.nPoints - 1) / 2048 * (x + 1024) + 1.5) 
end -- FindIndex()

-- Work around the stupid fact that getCurve and setCurve tables are incompatible...
local function GetCurve2(crvIndex)
	local newTbl = {}
	local oldTbl = model.getCurve(crvIndex)
	
	newTbl["y"] = {}
	for i = 1, ui.nPoints do
		newTbl["y"][i] = oldTbl["y"][i - 1]
	end
	
	newTbl["smooth"] = 1
	newTbl["name"] = oldTbl["name"]
	
	return newTbl
end -- GetCurve2()

local function init()
	lasti = 0
	ui.crvRgt = GetCurve2(indexRgt)
	ui.crvLft = GetCurve2(indexLft)

	avgs = {}
	difs = {}

	for i = 1, ui.nPoints do
		-- Left curve is backwards; both by index and y-value
		avgs[i] = (ui.crvRgt["y"][i] - ui.crvLft["y"][ui.nPoints - i + 1]) / 2
		difs[i] = ui.crvRgt["y"][i] + ui.crvLft["y"][ui.nPoints - i + 1]
	end
end -- init()

local function run(event)
	-- Press EXIT to quit
	if soarUtil.EvtExit(event) then
		return true
	end
	
	local i = FindIndex() -- Index of curve point to change

	-- Enable adjustment function
	adj = 1

	-- If index changed, then set GV to current dif. value
	if i ~= lasti then
		model.setGlobalVariable(gvIndex, 0, difs[i])
		lasti = i
	end
	
	difs[i] = model.getGlobalVariable(gvIndex, 0)
	
	-- Find min. and max. Y-values
	local minY = 1000
	local maxY = -1000
	
	for j = 1, ui.nPoints do
		local rt = avgs[j] + difs[j] / 2
		local lt = avgs[j] - difs[j] / 2
		maxY = math.max(maxY, rt, lt)
		minY = math.min(minY, rt, lt)
	end

	-- Rescale curve to [-100, 100]
	local a = 1
	local b = 0
	if maxY > minY then
		a = 200 / (maxY - minY)
		b = 100 - a * maxY
	end
	
	-- Apply changes to the curves
	for j = 1, ui.nPoints do
		ui.crvRgt["y"][j] = a * (avgs[j] + difs[j] / 2) + b
		model.setCurve(indexRgt, ui.crvRgt)
		
		ui.crvLft["y"][ui.nPoints - j + 1] = -(a * (avgs[j] - difs[j] / 2) + b)
		model.setCurve(indexLft, ui.crvLft)
	end
	
	ui.Draw(i)
end -- run()

return{init = init, run = run}