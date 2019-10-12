-- 212x64/JF/GRAPH.lua
-- Timestamp: 2019-10-11
-- Created by Jesper Frickmann
-- Telemetry script for plotting telemetry parameters recorded in the log file.

local gr = ... -- List of shared variables

-- First time, set some shared variables and hand over to read
if not gr.yValues then
	gr.left = 0
	gr.right = LCD_W - 15 -- Right side of the plot area
	return
end

local Plot = soarUtil.LoadWxH("PLOT.lua", gr) -- Screen size specific function

local function Draw(event)
	local width = gr.right - gr.left
	local tSpan = gr.tMax - gr.tMin
	
	soarUtil.InfoBar(" " .. string.sub(gr.flightTable[gr.flightIndex][2], 1, 8) .. "\t" .. gr.logFileHeaders[gr.plotIndex])

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
			gr.left = 45
		end
	elseif gr.viewMode == 2 then -- View stats
		-- Print statistics
		lcd.drawText(0, 11, "Dur", SMLSIZE)
		lcd.drawTimer(gr.left + 3, 10, tSpan, RIGHT)

		lcd.drawText(0, 21, "Min", SMLSIZE)
		lcd.drawNumber(gr.left, 20, 10 * gr.yMin2, PREC1 + RIGHT)

		lcd.drawText(0, 31, "Max", SMLSIZE)
		lcd.drawNumber(gr.left, 30, 10 * gr.yMax2, PREC1 + RIGHT)		

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

	elseif gr.viewMode == 3 then -- Select details and view slope
		local lftTime = gr.tMin + gr.lftMark * tSpan / width
		local rgtTime = gr.tMin + gr.rgtMark * tSpan / width
		local lftVal = gr.yValues[gr.lftMark]
		local rgtVal = gr.yValues[gr.rgtMark]
		local rate = (rgtVal - lftVal) / (rgtTime - lftTime)
		local att = 0

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

		-- Back to full graph view
		if event == EVT_MENU_BREAK or event == EVT_SHIFT_BREAK then
			gr.left = 0
		end
	else -- Zoomed in
		-- Print statistics
		lcd.drawText(0, 11, "Dur", SMLSIZE)
		lcd.drawTimer(gr.left + 3, 10, tSpan, RIGHT)

		lcd.drawText(0, 21, "Min", SMLSIZE)
		lcd.drawNumber(gr.left, 20, 10 * gr.yMin2, PREC1 + RIGHT)

		lcd.drawText(0, 31, "Max", SMLSIZE)
		lcd.drawNumber(gr.left, 30, 10 * gr.yMax2, PREC1 + RIGHT)		

		lcd.drawText(0, 41, "Rate", SMLSIZE)
		lcd.drawNumber(gr.left, 40, 100 * (gr.yMax2 - gr.yMin2) / tSpan, PREC2 + RIGHT)

		if soarUtil.ShowHelp(13, event) then
			lcd.drawText(LCD_W, 52, "ZOOM OUT", INVERS + RIGHT)
		end
	end
end  --  run()

return Draw