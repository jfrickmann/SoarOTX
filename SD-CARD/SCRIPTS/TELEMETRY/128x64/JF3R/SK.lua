-- 128x64/JF3R/SK.lua
-- Timestamp: 2019-09-16
-- Created by Jesper Frickmann

local sk = ... -- List of shared variables

local	function Draw()
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
	lcd.drawTimer(128, 16, sk.winTmr.value, MIDSIZE + RIGHT + blnkWt)

	lcd.drawText(72, 42, txtFt)
	lcd.drawTimer(128, 38, sk.fltTmr.value, MIDSIZE + RIGHT + blnkFt)

	if sk.state < sk.STATE_LANDINGPTS then
		lcd.drawText(60, 16, "--", MIDSIZE + RIGHT)
	elseif sk.state == sk.STATE_LANDINGPTS then
		lcd.drawNumber(60, 16, sk.landingPts, MIDSIZE + RIGHT + BLINK + INVERS)
	else
		lcd.drawNumber(60, 16, sk.landingPts, MIDSIZE + RIGHT)
	end

	if sk.state == sk.STATE_SAVE then
		lcd.drawText(4, LCD_H - 10, "EXIT", SMLSIZE + BLINK)
		lcd.drawText(LCD_W - 3, LCD_H - 10, "SAVE", SMLSIZE + BLINK + RIGHT)
	end
end -- Draw()

return Draw