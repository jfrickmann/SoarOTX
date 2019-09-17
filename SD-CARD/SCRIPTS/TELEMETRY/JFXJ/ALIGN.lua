-- JF FXJ Flaps and aileron Adjustment
-- Timestamp: 2019-09-16
-- Created by Jesper Frickmann
-- Script for adjusting the flaps and aileron output curves for the JF FXJ program.

local xValue = getFieldInfo("input8").id -- Step input before applying the output curves must be assigned to a channel

local gvIndex = {7, 8} -- Index of global variable used for communicating with the model program
local indexLft = {2, 0} -- Index of the left curve
local indexRgt = {3, 1} -- Index of the right curve
local avgs ={} -- Average values of left and right
local difs ={} -- Differences between left and right

local ui = {} -- List of  variables shared with loadable user interface
ui.nPoints = 5 -- Number of points on the curves
ui.lasti = 0 -- Index of point on the curves last time
ui.crvLft ={} -- Data structure defining the left flaperon curve
ui.crvRgt ={} -- Data structure defining the right flaperon curve

local Draw = LoadWxH("JFXJ/ALIGN.lua", ui) -- Screen size specific function

function ui.DrawCurve(x, y, w, h, crv, i)
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
	for j = 1, 2 do
		ui.crvRgt[j] = GetCurve2(indexRgt[j])
		ui.crvLft[j] = GetCurve2(indexLft[j])

		avgs[j] = {}
		difs[j] = {}

		for i = 1, ui.nPoints do
			-- Left curve is backwards; both by index and y-value
			avgs[j][i] = (ui.crvRgt[j]["y"][i] - ui.crvLft[j]["y"][ui.nPoints - i + 1]) / 2
			difs[j][i] = ui.crvRgt[j]["y"][i] + ui.crvLft[j]["y"][ui.nPoints - i + 1]
		end
	end
end -- init()

local function run(event)
	-- Press EXIT to quit
	if event == EVT_EXIT_BREAK then
		return true
	end
	
	local i = FindIndex() -- Index of curve point to change

	-- Enable adjustment function
	adj = 1

	-- If index changed, then set GV to current dif. value
	if i ~= ui.lasti then
		for j = 1, 2 do
			model.setGlobalVariable(gvIndex[j], 0, difs[j][i])
		end
		
		ui.lasti = i
	end
	
	for k = 1, 2 do
		difs[k][i] = model.getGlobalVariable(gvIndex[k], 0)
		
		-- Find min. and max. Y-values
		local minY = 1000
		local maxY = -1000
		
		for j = 1, ui.nPoints do
			local rt = avgs[k][j] + difs[k][j] / 2
			local lt = avgs[k][j] - difs[k][j] / 2
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
			ui.crvRgt[k]["y"][j] = a * (avgs[k][j] + difs[k][j] / 2) + b
			model.setCurve(indexRgt[k], ui.crvRgt[k])
			
			ui.crvLft[k]["y"][ui.nPoints - j + 1] = -(a * (avgs[k][j] - difs[k][j] / 2) + b)
			model.setCurve(indexLft[k], ui.crvLft[k])
		end
	end
	
	Draw()
end -- run()

return{init = init, run = run}