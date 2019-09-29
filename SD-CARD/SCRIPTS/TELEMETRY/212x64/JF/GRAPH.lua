-- 212x64/JF/GRAPH.lua
-- Timestamp: 2019-09-29
-- Created by Jesper Frickmann
-- Telemetry script for plotting telemetry parameters recorded in the log file.

local gr = ... -- List of shared variables

-- First time, set some shared variables and hand over to read
if not gr.yValues then
	gr.left = 0
	gr.right = LCD_W - 15 -- Right side of the plot area
	gr.run = gr.read
	return true
end

local Plot = soarUtil.LoadWxH("PLOT.lua", gr) -- Screen size specific function

local function run(event)
	soarUtil.InfoBar(" " .. string.sub(gr.flightTable[gr.flightIndex][2], 1, 8) .. "\t" .. gr.logFileHeaders[gr.plotIndex])

	local width = gr.right - gr.left
	local tSpan = gr.tMax - gr.tMin
	local yMin = gr.yMin
	local yMax = gr.yMax
	
	-- Sometimes, a min. scale of zero looks better...
	if gr.yMin < 0 then
		if -gr.yMin < 0.08 * gr.yMax then
			gr.yMin = 0
		end
	else
		if gr.yMin < 0.5 *  gr.yMax then
			gr.yMin = 0
		end
	end
	
	-- Make sure that we have some range to work with...
	if gr.yMax - gr.yMin <= 1E-8 then
		gr.yMax = gr.yMax + 0.1
	end
	
	Plot()
	
	if gr.viewMode == 1 then -- Normal graph view
		if soarUtil.ShowHelp(10, event) then
			lcd.drawText(0, 4, "STATS", INVERS)
			lcd.drawText(LCD_W, 4, "NEXT", INVERS + RIGHT)
			lcd.drawText(LCD_W, 28, "PREV", INVERS + RIGHT)
			lcd.drawText(LCD_W, 52, "VARIABLE", INVERS + RIGHT)
		end

		-- Change view mode
		if event == EVT_MENU_BREAK or event == EVT_SHIFT_BREAK then
			gr.viewMode = 2
			gr.left = 45
			gr.run = gr.read
		end
	elseif gr.viewMode == 2 then -- View stats
		-- Print statistics
		lcd.drawText(0, 11, "Dur", SMLSIZE)
		lcd.drawTimer(gr.left + 3, 10, tSpan, RIGHT)

		lcd.drawText(0, 21, "Min", SMLSIZE)
		lcd.drawNumber(gr.left, 20, 10 * yMin, PREC1 + RIGHT)

		lcd.drawText(0, 31, "Max", SMLSIZE)
		lcd.drawNumber(gr.left, 30, 10 * yMax, PREC1 + RIGHT)		

		if gr.launchAlt > 0 then
			lcd.drawText(0, 41, "Lnch", SMLSIZE)
			lcd.drawNumber(gr.left, 40, 10 * gr.launchAlt, PREC1 + RIGHT)
		end

		if soarUtil.ShowHelp(11, event) then
			lcd.drawText(0, 4, "MARK", INVERS)
			lcd.drawText(LCD_W, 4, "NEXT", INVERS + RIGHT)
			lcd.drawText(LCD_W, 28, "PREV", INVERS + RIGHT)
			lcd.drawText(LCD_W, 52, "VARIABLE", INVERS + RIGHT)
		end

		-- Change view mode
		if event == EVT_MENU_BREAK or event == EVT_SHIFT_BREAK then
			gr.viewMode = 3
			gr.lftMark = math.floor(0.1 * width)
			gr.rgtMark = math.ceil(0.9 * width)
			gr.selectedMark = 0
		end

	elseif gr.viewMode == 3 then -- Select details and view slope
		local lftTime = gr.tMin + gr.lftMark * tSpan / width
		local rgtTime = gr.tMin + gr.rgtMark * tSpan / width
		local lftVal = gr.yValues[gr.lftMark]
		local rgtVal = gr.yValues[gr.rgtMark]
		local rate = (rgtVal - lftVal) / (rgtTime - lftTime)
		local att = 0

		-- Draw markers
		local xx1 = gr.left + gr.lftMark
		lcd.drawLine(xx1, gr.b2, xx1 , 8, SOLID, FORCE)
		xx1 = gr.left + gr.rgtMark
		lcd.drawLine(xx1, gr.b2, xx1 , 8, SOLID, FORCE)
	
		if gr.selectedMark == 0 then att = INVERS end
		lcd.drawText(0, 11, "Lft", SMLSIZE + att)
		lcd.drawTimer(gr.left + 3, 10, lftTime, RIGHT)
		lcd.drawNumber(gr.left, 20, 10 * lftVal, PREC1 + RIGHT)

		att = INVERS - att
		lcd.drawText(0, 31, "Rgt", SMLSIZE + att)
		lcd.drawTimer(gr.left + 3, 30, rgtTime, RIGHT)
		lcd.drawNumber(gr.left, 40, 10 * rgtVal, PREC1 + RIGHT)
		
		lcd.drawText(0, 51, "Rate", SMLSIZE)
		lcd.drawNumber(gr.left, 50, 100 * rate, PREC2 + RIGHT)

		if soarUtil.ShowHelp(12, event) then
			lcd.drawText(0, 4, "FULL SIZE", INVERS)
			lcd.drawText(LCD_W, 4, "\126", INVERS + RIGHT)
			lcd.drawText(LCD_W, 28, "\127", INVERS + RIGHT)
			if gr.selectedMark == 0 then
				lcd.drawText(LCD_W, 52, "MARKER", INVERS + RIGHT)
			else
				lcd.drawText(LCD_W, 52, "ZOOM IN", INVERS + RIGHT)
			end
		end
		
		-- Move markers
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT or event == EVT_RIGHT_BREAK then
			if gr.selectedMark == 0 then
				gr.lftMark = math.min(gr.rgtMark - 1, gr.lftMark + 1)
			else
				gr.rgtMark = math.min(width, math.max(gr.lftMark + 1, gr.rgtMark + 1))
			end
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT or event == EVT_LEFT_BREAK then
			if gr.selectedMark == 0 then
				gr.lftMark = math.max(0, gr.lftMark - 1)
			else
				gr.rgtMark = math.max(gr.lftMark + 1, gr.rgtMark - 1)
			end
		end
		
		-- Toggle selected marker or zoom in
		if event == EVT_ENTER_BREAK then
			if gr.selectedMark == 0 then
				gr.selectedMark = 1
			else
				gr.viewMode = 4
				gr.tMin = lftTime
				gr.tMax = rgtTime
				gr.selectedMark = 0
				gr.run = gr.read
			end
		end
		
		-- Back to full graph view
		if event == EVT_MENU_BREAK or event == EVT_SHIFT_BREAK then
			gr.viewMode = 1
			gr.left = 0
			gr.run = gr.read
		end
	else -- Zoomed in
		-- Print statistics
		lcd.drawText(0, 11, "Dur", SMLSIZE)
		lcd.drawTimer(gr.left + 3, 10, tSpan, RIGHT)

		lcd.drawText(0, 21, "Min", SMLSIZE)
		lcd.drawNumber(gr.left, 20, 10 * yMin, PREC1 + RIGHT)

		lcd.drawText(0, 31, "Max", SMLSIZE)
		lcd.drawNumber(gr.left, 30, 10 * yMax, PREC1 + RIGHT)		

		lcd.drawText(0, 41, "Rate", SMLSIZE)
		lcd.drawNumber(gr.left, 40, 100 * (yMax - yMin) / tSpan, PREC2 + RIGHT)

		if soarUtil.ShowHelp(13, event) then
			lcd.drawText(LCD_W, 52, "ZOOM OUT", INVERS + RIGHT)
		end

		if event == EVT_ENTER_BREAK then
			gr.viewMode = 3
			gr.run = gr.read
		end
	end
	
	if gr.viewMode < 3 then
		-- Read next flight
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_RIGHT_BREAK then
			gr.flightIndex = gr.flightIndex + 1
			if gr.flightIndex > #gr.flightTable then
				gr.flightIndex = 1
			end
			gr.run = gr.read
		end

		-- Minus button was pressed; read previous flight
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_LEFT_BREAK then
			gr.flightIndex = gr.flightIndex - 1
			if gr.flightIndex < 1 then
				gr.flightIndex = #gr.flightTable
			end
			gr.run = gr.read
		end

		-- Enter button was pressed; change plot variable
		if event == EVT_ENTER_BREAK then
			gr.plotIndex = gr.plotIndex + 1
			if gr.plotIndex > gr.plotIndexLast then
				gr.plotIndex = 3
			end
			gr.run = gr.read
		end
	end
end  --  run()

return { run = run }