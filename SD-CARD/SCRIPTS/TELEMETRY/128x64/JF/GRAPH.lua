-- 128x64/JF/GRAPH.lua
-- Timestamp: 2019-10-12
-- Created by Jesper Frickmann
-- Telemetry script for plotting telemetry parameters recorded in the log file.

local gr = ... -- List of shared variables

-- First time, set some shared variables and hand over to read
if not gr.yValues then
	gr.left = 0
	gr.right = LCD_W - 10 -- Right side of the plot area
	return
end

local Plot = soarUtil.LoadWxH("PLOT.lua", gr) -- Screen size specific function

local function Draw(event)
	soarUtil.InfoBar(string.sub(gr.flightTable[gr.flightIndex][2], 1, 8) .. " " .. gr.logFileHeaders[gr.plotIndex])
	Plot()
	
	if gr.viewMode == 1 then -- Normal graph view
		if soarUtil.ShowHelp(10, event) then
			lcd.drawFilledRectangle(10, 8, 108, 48, SOLID)
			lcd.drawText(12, 10, "MENU - STATS", INVERS)
			lcd.drawText(12, 22, "ROT RGT - NEXT", INVERS)
			lcd.drawText(12, 34, "ROT LFT - PREV", INVERS)
			lcd.drawText(12, 46, "ENTER - VARIABLE", INVERS)
		end

		-- Change view mode
		if event == EVT_MENU_BREAK or event == EVT_SHIFT_BREAK then
			gr.left = 45
		end
	elseif gr.viewMode == 2 then -- View stats
		-- Print statistics
		lcd.drawText(0, 11, "Dur", SMLSIZE)
		lcd.drawTimer(gr.left + 3, 10, gr.tSpan, RIGHT)

		lcd.drawText(0, 21, "Min", SMLSIZE)
		lcd.drawNumber(gr.left, 20, 10 * gr.yMin2, PREC1 + RIGHT)

		lcd.drawText(0, 31, "Max", SMLSIZE)
		lcd.drawNumber(gr.left, 30, 10 * gr.yMax2, PREC1 + RIGHT)	

		if gr.launchAlt > 0 then
			lcd.drawText(0, 41, "Lnch", SMLSIZE)
			lcd.drawNumber(gr.left, 40, 10 * gr.launchAlt, PREC1 + RIGHT)
		end

		if soarUtil.ShowHelp(11, event) then
			lcd.drawFilledRectangle(10, 8, 108, 48, SOLID)
			lcd.drawText(12, 10, "MENU - MARKERS", INVERS)
			lcd.drawText(12, 22, "ROT RGT - NEXT", INVERS)
			lcd.drawText(12, 34, "ROT LFT - PREV", INVERS)
			lcd.drawText(12, 46, "ENTER - VARIABLE", INVERS)
		end
		
	elseif gr.viewMode == 3 then -- Select details and view slope
		local rate = (gr.yValues[gr.rgtMark] - gr.yValues[gr.lftMark]) / (gr.rgtTime - gr.lftTime)
		local att = 0

		if gr.selectedMark == 0 then att = INVERS end
		lcd.drawText(0, 11, "Lft", SMLSIZE + att)
		lcd.drawTimer(gr.left + 3, 10, gr.lftTime, RIGHT)
		lcd.drawNumber(gr.left, 20, 10 * gr.yValues[gr.lftMark], PREC1 + RIGHT)

		att = INVERS - att
		lcd.drawText(0, 31, "Rgt", SMLSIZE + att)
		lcd.drawTimer(gr.left + 3, 30, gr.rgtTime, RIGHT)
		lcd.drawNumber(gr.left, 40, 10 * gr.yValues[gr.rgtMark], PREC1 + RIGHT)
		
		lcd.drawText(0, 51, "Rate", SMLSIZE)
		lcd.drawNumber(gr.left, 50, 100 * rate, PREC2 + RIGHT)

		if soarUtil.ShowHelp(12, event) then
			lcd.drawFilledRectangle(10, 8, 108, 48, SOLID)
			lcd.drawText(12, 10, "MENU - FULL SIZE", INVERS)
			lcd.drawText(12, 22, "ROT RGT \126", INVERS)
			lcd.drawText(12, 34, "ROT LFT \127", INVERS)
			if gr.selectedMark == 0 then
				lcd.drawText(12, 46, "ENTER - MARKER", INVERS)
			else
				lcd.drawText(12, 46, "ENTER - ZOOM IN", INVERS)
			end
		end
		
		-- Back to full graph view
		if event == EVT_MENU_BREAK or event == EVT_SHIFT_BREAK then
			gr.left = 0
		end
	else -- Zoomed in
		-- Print statistics
		lcd.drawText(0, 11, "Dur", SMLSIZE)
		lcd.drawTimer(gr.left + 3, 10, gr.tSpan, RIGHT)

		lcd.drawText(0, 21, "Min", SMLSIZE)
		lcd.drawNumber(gr.left, 20, 10 * gr.yMin2, PREC1 + RIGHT)

		lcd.drawText(0, 31, "Max", SMLSIZE)
		lcd.drawNumber(gr.left, 30, 10 * gr.yMax2, PREC1 + RIGHT)		

		lcd.drawText(0, 41, "Rate", SMLSIZE)
		lcd.drawNumber(gr.left, 40, 100 * (gr.yMax2 - gr.yMin2) / gr.tSpan, PREC2 + RIGHT)

		if soarUtil.ShowHelp(13, event) then
			lcd.drawFilledRectangle(10, 25, 108, 14, SOLID)
			lcd.drawText(12, 27, "ENTER - ZOOM OUT", INVERS)
		end
	end
end  --  Draw()

return Draw