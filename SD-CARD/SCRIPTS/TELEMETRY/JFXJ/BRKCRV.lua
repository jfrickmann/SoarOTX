-- JF FXJ flap curve adjustment
-- Timestamp: 2019-09-16
-- Created by Jesper Frickmann
-- Script for adjusting the flaps curves for the JF FXJ program.

local nPoints = 5 -- Number of points on the curves
local xValue = getFieldInfo("input8").id -- Step input before applying the output curves must be assigned to a channel
local gvIndex = {7, 8} -- Index of global variables used for communicating with the model program
local index = {4, 5} -- Indices of the curves

ui = {} -- List of  variables shared with loadable user interface
ui.crv ={} -- Data structures defining the curves
ui.lasti = 0 -- Index of point on the curves last time

local Draw = LoadWxH("JFXJ/BRKCRV.lua", ui) -- Screen size specific function

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
	
	newTbl["smooth"] = 0
	newTbl["name"] = oldTbl["name"]
	
	return newTbl
end -- GetCurve2()

local function init()
	for j = 1, 2 do
		ui.crv[j] = GetCurve2(index[j])
	end
end -- init()

local function run(event)
	-- Press EXIT to quit
	if event == EVT_EXIT_BREAK then
		return true
	end
	
	local i = FindIndex() -- Index of curve points to change

	-- Enable adjustment function
	adj = 2

	-- If index changed, then set GV to current dif. value
	if i ~= ui.lasti then
		for j = 1, 2 do
			model.setGlobalVariable(gvIndex[j], 0, ui.crv[j]["y"][i])
		end

		ui.lasti = i
	end
	
	for j = 1, 2 do
		local y = model.getGlobalVariable(gvIndex[j], 0)
		y = math.max(-100, y)
		y = math.min(100, y)
		
		ui.crv[j]["y"][i] = y
		model.setCurve(index[j], ui.crv[j])
	end

	Draw()
end -- run()

return{init = init, run = run}