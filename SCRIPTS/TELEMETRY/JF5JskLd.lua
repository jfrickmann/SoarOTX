-- JF F5J Timing and score keeping, loadable part
-- Timestamp: 2018-03-07
-- Created by Jesper Frickmann
-- Telemetry script for timing and keeping scores for F5J.

local armId = getFieldInfo("ls18").id -- Input ID for motor arming
local ft
local mt

local Draw -- Draw() function is defined for specific transmitter

-- Transmitter specific
if tx == TX_X9D then
	function Draw()
		local fmNbr, fmName = getFlightMode()
		DrawMenu(" " .. fmName .. " ")	

		lcd.drawText(58, 57, " JF F5J Score Keeper ", SMLSIZE)
		lcd.drawText(10, 20, "Landing", MIDSIZE)
		lcd.drawText(10, 42, "Start", MIDSIZE)
		lcd.drawText(110, 42, "Motor", MIDSIZE)
		lcd.drawTimer(162, 38, mt.value, DBLSIZE)

		if skLocals.state == skLocals.STATE_INITIAL then
			lcd.drawText(110, 20, "Target", MIDSIZE)
			lcd.drawTimer(162, 16, ft.value, DBLSIZE + BLINK + INVERS)
		elseif skLocals.state <= skLocals.STATE_GLIDE then
			lcd.drawText(110, 20, "Remain", MIDSIZE)
			lcd.drawTimer(162, 16, ft.value, DBLSIZE)
		else
			lcd.drawText(110, 20, "Flight", MIDSIZE)
			lcd.drawTimer(162, 16, ft.value, DBLSIZE)
		end

		if skLocals.state < skLocals.STATE_LANDINGPTS then
			lcd.drawText(88, 16, "--", DBLSIZE + RIGHT)
		elseif skLocals.state == skLocals.STATE_LANDINGPTS then
			lcd.drawNumber(88, 16, skLocals.landingPts, DBLSIZE + RIGHT + BLINK + INVERS)
		else
			lcd.drawNumber(88, 16, skLocals.landingPts, DBLSIZE + RIGHT)
		end

		if skLocals.state < skLocals.STATE_LANDINGPTS then
			lcd.drawText(88, 38, "---", DBLSIZE + RIGHT)
		elseif skLocals.state == skLocals.STATE_STARTHEIGHT then
			lcd.drawNumber(88, 38, skLocals.startHeight, DBLSIZE + RIGHT + BLINK + INVERS)
		else
			lcd.drawNumber(88, 38, skLocals.startHeight, DBLSIZE + RIGHT)
		end
		
		if getValue(armId) >0 then
			lcd.drawText(10, 16, "     MOTOR    ARMED     ", DBLSIZE + BLINK + INVERS)
		end
	end  --  Draw()
else -- QX7
	function Draw()
		local fmNbr, fmName = getFlightMode()
		DrawMenu(fmName)	

		lcd.drawText(47, 58, " JF F5J ", SMLSIZE)
		lcd.drawText(8, 20, "Landing", SMLSIZE)
		lcd.drawText(8, 42, "Start", SMLSIZE)
		lcd.drawText(68, 42, "Mot", SMLSIZE)
		lcd.drawTimer(90, 38, mt.value, MIDSIZE)

		if skLocals.state == skLocals.STATE_INITIAL then
			lcd.drawText(68, 20, "Tgt", SMLSIZE)
			lcd.drawTimer(90, 16, ft.value, MIDSIZE + BLINK + INVERS)
		elseif skLocals.state <= skLocals.STATE_GLIDE then
			lcd.drawText(68, 20, "Rem", SMLSIZE)
			lcd.drawTimer(90, 16, ft.value, MIDSIZE)
		else
			lcd.drawText(68, 20, "Flt", SMLSIZE)
			lcd.drawTimer(90, 16, ft.value, MIDSIZE)
		end

		if skLocals.state < skLocals.STATE_LANDINGPTS then
			lcd.drawText(58, 16, "--", MIDSIZE + RIGHT)
		elseif skLocals.state == skLocals.STATE_LANDINGPTS then
			lcd.drawNumber(58, 16, skLocals.landingPts, MIDSIZE + RIGHT + BLINK + INVERS)
		else
			lcd.drawNumber(58, 16, skLocals.landingPts, MIDSIZE + RIGHT)
		end

		if skLocals.state < skLocals.STATE_LANDINGPTS then
			lcd.drawText(58, 38, "---", MIDSIZE + RIGHT)
		elseif skLocals.state == skLocals.STATE_STARTHEIGHT then
			lcd.drawNumber(58, 38, skLocals.startHeight, MIDSIZE + RIGHT + BLINK + INVERS)
		else
			lcd.drawNumber(58, 38, skLocals.startHeight, MIDSIZE + RIGHT)
		end
		
		if getValue(armId) >0 then
			lcd.drawText(7, 16, "MOTOR ARMED", DBLSIZE + BLINK + INVERS)
		end
	end -- Draw()
end

local function run(event)
	ft = model.getTimer(0)
	mt = model.getTimer(1)
	
	if event == EVT_MENU_BREAK and skLocals.state > skLocals.STATE_LANDINGPTS and ft.value > 0 then
		-- Go back one step
		skLocals.state  = skLocals.state  - 1
	end
	
	if skLocals.state == skLocals.STATE_INITIAL then -- Set flight time before the flight
		local dt = 0
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT then
			dt = 60
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT then
			dt = -60
		end
		
		local tgt = ft.start + dt
		if tgt < 60 then
			tgt = 5940
		elseif tgt > 5940 then
			tgt = 60
		end
		model.setTimer(0, {start = tgt, value = tgt})
	elseif skLocals.state == skLocals.STATE_LANDINGPTS then -- Landed, input landing points 
		local dpts = 0
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT then
			dpts = 5
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT then
			dpts = -5
		end
		
		skLocals.landingPts = skLocals.landingPts + dpts
		if skLocals.landingPts < 0 then
			skLocals.landingPts = 50
		elseif skLocals.landingPts  > 50 then
			skLocals.landingPts = 0
		end
		
		if event == EVT_ENTER_BREAK then
			skLocals.state = skLocals.STATE_STARTHEIGHT
		end
	elseif skLocals.state == skLocals.STATE_STARTHEIGHT then -- Input start height
		local dm = 0
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT then
			dm = 1
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT then
			dm = -1
		end
		
		skLocals.startHeight = skLocals.startHeight + dm
		if skLocals.startHeight < 0 then
			skLocals.startHeight = 0
		elseif skLocals.startHeight  > 999 then
			skLocals.startHeight = 999
		end
		
		if event == EVT_ENTER_BREAK then
			skLocals.state = skLocals.STATE_SAVE
		end
	elseif skLocals.state == skLocals.STATE_SAVE then
		if event == EVT_ENTER_BREAK then -- Record scores if user pressed ENTER
			local logFile = io.open("/LOGS/JF F5J Scores.csv", "a")
			if logFile then
				local nameStr = model.getInfo().name

				local now = getDateTime()
				local dateStr = string.format("%04d-%02d-%02d", now.year, now.mon, now.day)
				local timeStr = string.format("%02d:%02d", now.hour, now.min)

				io.write(logFile, string.format("%s,%s,%s,", nameStr, dateStr, timeStr))
				io.write(logFile, string.format("%s,%s,", skLocals.landingPts, skLocals.startHeight))
				io.write(logFile, string.format("%s,%s\n", ft.start, ft.value))

				io.close(logFile)
			end
			
			skLocals.state = skLocals.STATE_INITIAL
		end

		if event == EVT_EXIT_BREAK then -- Do not record scores if user pressed EXIT
			skLocals.state = skLocals.STATE_INITIAL
		end
	end
	
	Draw()

	if skLocals.state == skLocals.STATE_SAVE then
		lcd.drawText(4, LCD_H - 10, "EXIT", SMLSIZE + BLINK)
		lcd.drawText(LCD_W - 3, LCD_H - 10, "SAVE", SMLSIZE + BLINK + RIGHT)
	end
end  --  run()

return {run = run}	