-- 128x64/JF5J/SK.lua
-- Timestamp: 2020-05-08
-- Created by Jesper Frickmann

local sk = ... -- List of shared variables

local 	function Draw()
	local fmNbr, fmName = getFlightMode()
	soarUtil.InfoBar(fmName)	

	lcd.drawText(0, 20, "Landing")
	lcd.drawText(0, 42, "Start")
	lcd.drawText(72, 42, "Mot")
	lcd.drawTimer(128, 38, sk.motorTimer.value, MIDSIZE + RIGHT)

	if sk.state == sk.STATE_INITIAL or sk.target > 0 then
		lcd.drawText(72, 20, "Tgt")
	elseif sk.state <= sk.STATE_GLIDE then
		lcd.drawText(72, 20, "Rem")
	else
		lcd.drawText(72, 20, "Flt")
	end

	if sk.target > 0 then
		lcd.drawTimer(128, 16, sk.target, MIDSIZE + RIGHT + BLINK + INVERS)
	elseif sk.state == sk.STATE_TIME then
		lcd.drawTimer(128, 16, sk.flightTimer.value, MIDSIZE + RIGHT + BLINK + INVERS)
	else
		lcd.drawTimer(128, 16, sk.flightTimer.value, MIDSIZE + RIGHT)
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
		lcd.drawNumber(60, 38, sk.startHeight, MIDSIZE + RIGHT + BLINK + INVERS)
	else
		lcd.drawNumber(60, 38, sk.startHeight, MIDSIZE + RIGHT)
	end
	
	if sk.state == sk.STATE_SAVE then
		lcd.drawText(4, LCD_H - 10, "EXIT", SMLSIZE + BLINK)
		lcd.drawText(LCD_W - 3, LCD_H - 10, "SAVE", SMLSIZE + BLINK + RIGHT)
	end
end -- Draw()

return Draw