-- 212x64/JF5J/SK.lua
-- Timestamp: 2020-04-10
-- Created by Jesper Frickmann

local sk = ... -- List of shared variables

local 	function Draw()
	local fmNbr, fmName = getFlightMode()
	soarUtil.InfoBar(fmName)	

	if getValue(sk.armId) >0 then
		lcd.drawText(50, 28, "MOTOR  ARMED", DBLSIZE + BLINK + INVERS)
		return
	end

	lcd.drawText(0, 20, "Landing", MIDSIZE)
	lcd.drawText(0, 42, "Start", MIDSIZE)
	lcd.drawText(110, 42, "Motor", MIDSIZE)
	lcd.drawTimer(212, 38, sk.motTmr.value, DBLSIZE + RIGHT)

	if sk.state == sk.STATE_INITIAL then
		lcd.drawText(110, 20, "Target", MIDSIZE)
	elseif sk.state <= sk.STATE_GLIDE then
		lcd.drawText(110, 20, "Remain", MIDSIZE)
	else
		lcd.drawText(110, 20, "Flight", MIDSIZE)
	end

	if sk.state == sk.STATE_INITIAL or sk.state == sk.STATE_TIME then
		lcd.drawTimer(212, 16, sk.fltTmr.value, DBLSIZE + RIGHT + BLINK + INVERS)
	else
		lcd.drawTimer(212, 16, sk.fltTmr.value, DBLSIZE + RIGHT)
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
		lcd.drawNumber(95, 38, sk.startHeight, DBLSIZE + RIGHT + BLINK + INVERS)
	else
		lcd.drawNumber(95, 38, sk.startHeight, DBLSIZE + RIGHT)
	end
	
	if sk.state == sk.STATE_SAVE then
		lcd.drawText(4, LCD_H - 10, "EXIT", SMLSIZE + BLINK)
		lcd.drawText(LCD_W - 3, LCD_H - 10, "SAVE", SMLSIZE + BLINK + RIGHT)
	end
end  --  Draw()

return Draw