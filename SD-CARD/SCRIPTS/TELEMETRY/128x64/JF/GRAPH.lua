-- 128x64/JF/GRAPH.lua
-- Timestamp: 2021-01-02
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
		-- Change view mode
		if event == EVT_VIRTUAL_EXIT then
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
	elseif gr.viewMode == 3 then -- Select details and view slope
		local rate = (gr.yValues[gr.rgtMark] - gr.yValues[gr.lftMark]) / (gr.rgtTime - gr.lftTime)
		local att

		if gr.selectedMark == 0 then
			att = INVERS
		else
			att = 0
		end

		lcd.drawText(0, 11, "Lft", SMLSIZE + att)
		lcd.drawTimer(gr.left + 3, 10, gr.lftTime, RIGHT)
		lcd.drawNumber(gr.left, 20, 10 * gr.yValues[gr.lftMark], PREC1 + RIGHT)

		att = INVERS - att
		lcd.drawText(0, 31, "Rgt", SMLSIZE + att)
		lcd.drawTimer(gr.left + 3, 30, gr.rgtTime, RIGHT)
		lcd.drawNumber(gr.left, 40, 10 * gr.yValues[gr.rgtMark], PREC1 + RIGHT)
		
		lcd.drawText(0, 51, "Rate", SMLSIZE)
		lcd.drawNumber(gr.left, 50, 100 * rate, PREC2 + RIGHT)

		-- Back to full graph view
		if event == EVT_VIRTUAL_EXIT then
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
	end
end  --  Draw()

return Draw