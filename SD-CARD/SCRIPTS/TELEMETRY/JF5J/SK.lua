-- JF F5J Timing and score keeping, loadable part
-- Timestamp: 2019-01-05
-- Created by Jesper Frickmann
-- Telemetry script for timing and keeping scores for F5J.

local sk = sk -- Local reference is faster than a global
local armId = getFieldInfo("ls18").id -- Input ID for motor arming
local ft -- Flight timer
local mt -- Motor timer

local Draw -- Draw() function is defined for specific transmitter

-- Transmitter specific
if tx == TX_X9D then
	function Draw()
		local fmNbr, fmName = getFlightMode()
		DrawMenu(" " .. fmName .. " ")	

		lcd.drawText(0, 20, "Landing", MIDSIZE)
		lcd.drawText(0, 42, "Start", MIDSIZE)
		lcd.drawText(110, 42, "Motor", MIDSIZE)
		lcd.drawTimer(212, 38, mt.value, DBLSIZE + RIGHT)

		if sk.state == sk.STATE_INITIAL then
			lcd.drawText(110, 20, "Target", MIDSIZE)
			lcd.drawTimer(212, 16, ft.value, DBLSIZE + RIGHT + BLINK + INVERS)
		elseif sk.state <= sk.STATE_GLIDE then
			lcd.drawText(110, 20, "Remain", MIDSIZE)
			lcd.drawTimer(212, 16, ft.value, DBLSIZE + RIGHT)
		else
			lcd.drawText(110, 20, "Flight", MIDSIZE)
			lcd.drawTimer(212, 16, ft.value, DBLSIZE + RIGHT)
		end

		if sk.state < sk.STATE_LANDINGPTS then
			lcd.drawText(95, 16, "--", DBLSIZE + RIGHT)
		elseif sk.state == sk.STATE_LANDINGPTS then
			lcd.drawNumber(95, 16, sk.landingPts, DBLSIZE + RIGHT + BLINK + INVERS)
		else
			lcd.drawNumber(95, 16, sk.landingPts, DBLSIZE + RIGHT)
		end

		if sk.state < sk.STATE_LANDINGPTS then
			lcd.drawText(95, 38, "---", DBLSIZE + RIGHT)
		elseif sk.state == sk.STATE_STARTHEIGHT then
			lcd.drawNumber(95, 38, sk.startHeight * 10, PREC1 + DBLSIZE + RIGHT + BLINK + INVERS)
		else
			lcd.drawNumber(95, 38, sk.startHeight * 10, PREC1 + DBLSIZE + RIGHT)
		end
		
		if getValue(armId) >0 then
			lcd.clear()
			lcd.drawText(50, 16, "MOTOR  ARMED", DBLSIZE + BLINK + INVERS)
		end
	end  --  Draw()
else -- QX7 or X-lite
	function Draw()
		local fmNbr, fmName = getFlightMode()
		DrawMenu(fmName)	

		lcd.drawText(0, 20, "Landing")
		lcd.drawText(0, 42, "Start")
		lcd.drawText(72, 42, "Mot")
		lcd.drawTimer(128, 38, mt.value, MIDSIZE + RIGHT)

		if sk.state == sk.STATE_INITIAL then
			lcd.drawText(72, 20, "Tgt")
			lcd.drawTimer(128, 16, ft.value, MIDSIZE + RIGHT + BLINK + INVERS)
		elseif sk.state <= sk.STATE_GLIDE then
			lcd.drawText(72, 20, "Rem")
			lcd.drawTimer(128, 16, ft.value, MIDSIZE + RIGHT)
		else
			lcd.drawText(72, 20, "Flt")
			lcd.drawTimer(128, 16, ft.value, MIDSIZE + RIGHT)
		end

		if sk.state < sk.STATE_LANDINGPTS then
			lcd.drawText(60, 16, "--", MIDSIZE + RIGHT)
		elseif sk.state == sk.STATE_LANDINGPTS then
			lcd.drawNumber(60, 16, sk.landingPts, MIDSIZE + RIGHT + BLINK + INVERS)
		else
			lcd.drawNumber(60, 16, sk.landingPts, MIDSIZE + RIGHT)
		end

		if sk.state < sk.STATE_LANDINGPTS then
			lcd.drawText(60, 38, "---", MIDSIZE + RIGHT)
		elseif sk.state == sk.STATE_STARTHEIGHT then
			lcd.drawNumber(60, 38, sk.startHeight * 10, PREC1 + MIDSIZE + RIGHT + BLINK + INVERS)
		else
			lcd.drawNumber(60, 38, sk.startHeight * 10, PREC1 + MIDSIZE + RIGHT)
		end
		
		if getValue(armId) >0 then
			lcd.clear()
			lcd.drawText(2, 16, "MOTOR  ARMED", DBLSIZE + BLINK + INVERS)
		end
	end -- Draw()
end

local function run(event)
	ft = model.getTimer(0)
	mt = model.getTimer(1)
	
	if event == EVT_MENU_BREAK or event == EVT_UP_BREAK and sk.state > sk.STATE_LANDINGPTS and ft.value > 0 then
		-- Go back one step
		sk.state  = sk.state  - 1
	end
	
	if sk.state == sk.STATE_INITIAL then -- Set flight time before the flight
		local dt = 0
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT or event == EVT_RIGHT_BREAK then
			dt = 60
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT or event == EVT_LEFT_BREAK then
			dt = -60
		end
		
		local tgt = ft.start + dt
		if tgt < 60 then
			tgt = 5940
		elseif tgt > 5940 then
			tgt = 60
		end
		model.setTimer(0, {start = tgt, value = tgt})
	elseif sk.state == sk.STATE_LANDINGPTS then -- Landed, input landing points 
		local dpts = 0
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT or event == EVT_RIGHT_BREAK then
			dpts = 5
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT or event == EVT_LEFT_BREAK then
			dpts = -5
		end
		
		sk.landingPts = sk.landingPts + dpts
		if sk.landingPts < 0 then
			sk.landingPts = 50
		elseif sk.landingPts  > 50 then
			sk.landingPts = 0
		end
		
		if event == EVT_ENTER_BREAK then
			sk.state = sk.STATE_STARTHEIGHT
		end
	elseif sk.state == sk.STATE_STARTHEIGHT then -- Input start height
		local dm = 0
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_RIGHT_BREAK then
			dm = 0.1
		end
		
		if event == EVT_PLUS_REPT or event == EVT_RIGHT_REPT then
			dm = 1
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_LEFT_BREAK then
			dm = -0.1
		end
		
		if event == EVT_MINUS_REPT or event == EVT_LEFT_REPT then
			dm = -1
		end
		
		sk.startHeight = sk.startHeight + dm
		if sk.startHeight < 0 then
			sk.startHeight = 0
		elseif sk.startHeight  > 999 then
			sk.startHeight = 999
		end
		
		if event == EVT_ENTER_BREAK then
			sk.state = sk.STATE_SAVE
		end
	elseif sk.state == sk.STATE_SAVE then
		if event == EVT_ENTER_BREAK then -- Record scores if user pressed ENTER
			local logFile = io.open("/LOGS/JF F5J Scores.csv", "a")
			if logFile then
				local nameStr = model.getInfo().name

				local now = getDateTime()
				local dateStr = string.format("%04d-%02d-%02d", now.year, now.mon, now.day)
				local timeStr = string.format("%02d:%02d", now.hour, now.min)

				io.write(logFile, string.format("%s,%s,%s,", nameStr, dateStr, timeStr))
				io.write(logFile, string.format("%s,%4.1f,", sk.landingPts, sk.startHeight))
				io.write(logFile, string.format("%s,%s\n", ft.start, ft.value))

				io.close(logFile)
			end
			
			sk.state = sk.STATE_INITIAL
		end

		if event == EVT_EXIT_BREAK then -- Do not record scores if user pressed EXIT
			sk.state = sk.STATE_INITIAL
		end
	end
	
	Draw()

	if sk.state == sk.STATE_SAVE then
		lcd.drawText(4, LCD_H - 10, "EXIT", SMLSIZE + BLINK)
		lcd.drawText(LCD_W - 3, LCD_H - 10, "SAVE", SMLSIZE + BLINK + RIGHT)
	end
end  --  run()

return {run = run}	