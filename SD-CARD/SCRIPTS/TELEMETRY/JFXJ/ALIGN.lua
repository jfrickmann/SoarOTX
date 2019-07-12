-- JF FXJ Flaps and aileron Adjustment
-- Timestamp: 2019-07-07
-- Created by Jesper Frickmann
-- Script for adjusting the flaps and aileron output curves for the JF FXJ program.

local nPoints = 5 -- Number of points on the curves
local xValue = getFieldInfo("input8").id -- Step input before applying the output curves must be assigned to a channel
local lasti -- Index of point on the curves last time

local gvIndex = {7, 8} -- Index of global variable used for communicating with the model program
local indexLft = {2, 0} -- Index of the left curve
local indexRgt = {3, 1} -- Index of the right curve
local crvLft ={} -- Data structure defining the left flaperon curve
local crvRgt ={} -- Data structure defining the right flaperon curve
local avgs ={} -- Average values of left and right
local difs ={} -- Differences between left and right

local Draw -- Draw() function is defined for specific transmitter

local function DrawCurve(x, y, w, h, crv, i)
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

-- Transmitter specific
if LCD_W == 128 then
	function Draw()
		DrawMenu("Alignment")

		lcd.drawLine(64, 10, 64, 61, SOLID, FORCE)
		lcd.drawLine(2, 36, 126, 36, SOLID, FORCE)

		lcd.drawText(11, 12, "LA", SMLSIZE)
		DrawCurve(11, 12, 48, 22, crvLft[2], nPoints - lasti + 1)

		lcd.drawText(69, 12, "RA", SMLSIZE)
		DrawCurve(69, 12, 48, 22, crvRgt[2], lasti)

		lcd.drawText(11, 38, "LF", SMLSIZE)
		DrawCurve(11, 38, 48, 22, crvLft[1], nPoints - lasti + 1)

		lcd.drawText(69, 38, "RF", SMLSIZE)
		DrawCurve(69, 38, 48, 22, crvRgt[1], lasti)
	end -- Draw()
else
	function Draw()
		DrawMenu(" Flaps/aileron alignment ")

		lcd.drawText(5, 13, "LA", SMLSIZE)
		DrawCurve(4, 12, 48, 36, crvLft[2], nPoints - lasti + 1)

		lcd.drawText(57, 13, "LF", SMLSIZE)
		DrawCurve(56, 12, 48, 36, crvLft[1], nPoints - lasti + 1)

		lcd.drawText(109, 13, "RF", SMLSIZE)
		DrawCurve(108, 12, 48, 36, crvRgt[1], lasti)		

		lcd.drawText(160, 13, "RA", SMLSIZE)
		DrawCurve(159, 12, 48, 36, crvRgt[2], lasti)

		lcd.drawText(8, 54, "Thr. to move. Rud. and aile. trims to align.", SMLSIZE)
	end -- Draw()
end

-- Find index of the curve point that corresponds to the value of the step input
local function FindIndex()
	local x = getValue(xValue)
	return math.floor((nPoints - 1) / 2048 * (x + 1024) + 1.5) 
end -- FindIndex()

-- Work around the stupid fact that getCurve and setCurve tables are incompatible...
local function GetCurve2(crvIndex)
	local newTbl = {}
	local oldTbl = model.getCurve(crvIndex)
	
	newTbl["y"] = {}
	for i = 1, nPoints do
		newTbl["y"][i] = oldTbl["y"][i - 1]
	end
	
	newTbl["smooth"] = 1
	newTbl["name"] = oldTbl["name"]
	
	return newTbl
end -- GetCurve2()

local function init()
	lasti = 0
	
	for j = 1, 2 do
		crvRgt[j] = GetCurve2(indexRgt[j])
		crvLft[j] = GetCurve2(indexLft[j])

		avgs[j] = {}
		difs[j] = {}

		for i = 1, nPoints do
			-- Left curve is backwards; both by index and y-value
			avgs[j][i] = (crvRgt[j]["y"][i] - crvLft[j]["y"][nPoints - i + 1]) / 2
			difs[j][i] = crvRgt[j]["y"][i] + crvLft[j]["y"][nPoints - i + 1]
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
	if i ~= lasti then
		for j = 1, 2 do
			model.setGlobalVariable(gvIndex[j], 0, difs[j][i])
		end
		
		lasti = i
	end
	
	for k = 1, 2 do
		difs[k][i] = model.getGlobalVariable(gvIndex[k], 0)
		
		-- Find min. and max. Y-values
		local minY = 1000
		local maxY = -1000
		
		for j = 1, nPoints do
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
		for j = 1, nPoints do
			crvRgt[k]["y"][j] = a * (avgs[k][j] + difs[k][j] / 2) + b
			model.setCurve(indexRgt[k], crvRgt[k])
			
			crvLft[k]["y"][nPoints - j + 1] = -(a * (avgs[k][j] - difs[k][j] / 2) + b)
			model.setCurve(indexLft[k], crvLft[k])
		end
	end
	
	Draw()
end -- run()

return{init = init, run = run}