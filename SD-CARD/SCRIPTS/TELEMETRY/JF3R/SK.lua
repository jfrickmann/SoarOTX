-- JF F3RES Timing and score keeping, loadable part
-- Timestamp: 2019-07-07
-- Created by Jesper Frickmann
-- Telemetry script for timing and keeping scores for F3RES.

local sk = sk -- Local reference is faster than a global
local wt -- Window timer
local ft -- Flight timer
local Draw -- Draw() function is defined for specific transmitter

-- Transmitter specific
if LCD_W == 128 then
	function Draw()
		local blnkWt = 0
		local blnkFt = 0
		local txtFt = "Rem"
		
		local fmNbr, fmName = getFlightMode()
		DrawMenu(fmName)	

		if sk.state == sk.STATE_SETWINTMR then
			blnkWt = BLINK + INVERS
		elseif sk.state == sk.STATE_SETFLTTMR then
			blnkFt = BLINK + INVERS
		end
		
		if sk.state <= sk.STATE_SETFLTTMR then
			txtFt = "Tgt"
		elseif sk.state > sk.STATE_WINDOW then
			txtFt = "Flt"
		end
		
		lcd.drawText(0, 20, "Landing ")

		lcd.drawText(72, 20, "Win")
		lcd.drawTimer(128, 16, wt.value, MIDSIZE + RIGHT + blnkWt)

		lcd.drawText(72, 42, txtFt)
		lcd.drawTimer(128, 38, ft.value, MIDSIZE + RIGHT + blnkFt)

		if sk.state < sk.STATE_LANDINGPTS then
			lcd.drawText(60, 16, "--", MIDSIZE + RIGHT)
		elseif sk.state == sk.STATE_LANDINGPTS then
			lcd.drawNumber(60, 16, sk.landingPts, MIDSIZE + RIGHT + BLINK + INVERS)
		else
			lcd.drawNumber(60, 16, sk.landingPts, MIDSIZE + RIGHT)
		end
	end -- Draw()
else
	function Draw()
		local blnkWt = 0
		local blnkFt = 0
		local txtFt = "Remain"
		
		local fmNbr, fmName = getFlightMode()
		DrawMenu(" " .. fmName .. " ")	

		if sk.state == sk.STATE_SETWINTMR then
			blnkWt = BLINK + INVERS
		elseif sk.state == sk.STATE_SETFLTTMR then
			blnkFt = BLINK + INVERS
		end
		
		if sk.state <= sk.STATE_SETFLTTMR then
			txtFt = "Target"
		elseif sk.state > sk.STATE_WINDOW then
			txtFt = "Flight"
		end
		
		lcd.drawText(0, 20, "Landing", MIDSIZE)

		lcd.drawText(110, 20, "Window", MIDSIZE)
		lcd.drawTimer(212, 16, wt.value, DBLSIZE + RIGHT + blnkWt)

		lcd.drawText(110, 42, txtFt, MIDSIZE)
		lcd.drawTimer(212, 38, ft.value, DBLSIZE + RIGHT + blnkFt)

		if sk.state < sk.STATE_LANDINGPTS then
			lcd.drawText(95, 16, "--", DBLSIZE + RIGHT)
		elseif sk.state == sk.STATE_LANDINGPTS then
			lcd.drawNumber(95, 16, sk.landingPts, DBLSIZE + RIGHT + BLINK + INVERS)
		else
			lcd.drawNumber(95, 16, sk.landingPts, DBLSIZE + RIGHT)
		end
	end  --  Draw()
end

local function run(event)
	wt = model.getTimer(0)
	ft = model.getTimer(1)

	if sk.state == sk.STATE_SETWINTMR and event == EVT_ENTER_BREAK then
		sk.state = sk.STATE_SETFLTTMR
	end
	
	if (sk.state > sk.STATE_LANDINGPTS and wt.value > 0) or sk.state == sk.STATE_SETFLTTMR then
		if event == EVT_MENU_BREAK or event == EVT_UP_BREAK then
			-- Go back one step
			sk.state  = sk.state  - 1
		end
	end
	
	if sk.state <= sk.STATE_SETFLTTMR  then -- Set flight time before the flight
		local dt = 0
		local tgt
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT or event == EVT_RIGHT_BREAK then
			dt = 60
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT or event == EVT_LEFT_BREAK then
			dt = -60
		end
		
		if sk.state == sk.STATE_SETWINTMR then
			tgt = wt.start + dt
			if tgt < 60 then
				tgt = 5940
			elseif tgt > 5940 then
				tgt = 60
			end
			model.setTimer(0, {start = tgt, value = tgt})
		else
			tgt = ft.start + dt
			if tgt < 60 then
				tgt = 60
			elseif tgt > wt.start then
				tgt = wt.start
			end
			model.setTimer(1, {start = tgt, value = tgt})
		end
	elseif sk.state == sk.STATE_LANDINGPTS then -- Landed, input landing points 
		local dpts = 0
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT or event == EVT_RIGHT_BREAK then
			if sk.landingPts >= 90 then
				dpts = 1
			elseif sk.landingPts >= 30 then
				dpts = 5
			else
				dpts = 30
			end
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT or event == EVT_LEFT_BREAK then
			if sk.landingPts > 90 then
				dpts = -1
			elseif sk.landingPts > 30 then
				dpts = -5
			else
				dpts = -30
			end
		end
		
		sk.landingPts = sk.landingPts + dpts
		if sk.landingPts < 0 then
			sk.landingPts = 100
		elseif sk.landingPts  > 100 then
			sk.landingPts = 0
		end
		
		if event == EVT_ENTER_BREAK then
			sk.state = sk.STATE_SAVE
		end
	elseif sk.state == sk.STATE_SAVE then
		if event == EVT_ENTER_BREAK then -- Record scores if user pressed ENTER
			local logFile = io.open("/LOGS/JF F3RES Scores.csv", "a")
			if logFile then
				local nameStr = model.getInfo().name

				local now = getDateTime()
				local dateStr = string.format("%04d-%02d-%02d", now.year, now.mon, now.day)
				local timeStr = string.format("%02d:%02d", now.hour, now.min)

				io.write(logFile, string.format("%s,%s,%s,%s,", nameStr, dateStr, timeStr, sk.landingPts))
				io.write(logFile, string.format("%s,%s,%s,%s\n", wt.start, wt.value, ft.start, ft.value))

				io.close(logFile)
			end
			
			sk.state = sk.STATE_SETWINTMR
		end

		if event == EVT_EXIT_BREAK then -- Do not record scores if user pressed EXIT
			sk.state = sk.STATE_SETWINTMR
		end
	end
	
	Draw()

	if sk.state == sk.STATE_SAVE then
		lcd.drawText(4, LCD_H - 10, "EXIT", SMLSIZE + BLINK)
		lcd.drawText(LCD_W - 3, LCD_H - 10, "SAVE", SMLSIZE + BLINK + RIGHT)
	end
end  --  run()

return {run = run}	