-- 212x64/JF3R/SK.lua
-- Timestamp: 2019-09-22
-- Created by Jesper Frickmann

local sk = ... -- List of shared variables

local	function Draw()
	local blnkWt = 0
	local blnkFt = 0
	local txtFt = "Remain"
	
	local fmNbr, fmName = getFlightMode()
	InfoBar(" " .. fmName .. " ")	

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
	lcd.drawTimer(212, 16, sk.winTmr.value, DBLSIZE + RIGHT + blnkWt)

	lcd.drawText(110, 42, txtFt, MIDSIZE)
	lcd.drawTimer(212, 38, sk.fltTmr.value, DBLSIZE + RIGHT + blnkFt)

	if sk.state < sk.STATE_LANDINGPTS then
		lcd.drawText(95, 16, "--", DBLSIZE + RIGHT)
	elseif sk.state == sk.STATE_LANDINGPTS then
		lcd.drawNumber(95, 16, sk.landingPts, DBLSIZE + RIGHT + BLINK + INVERS)
	else
		lcd.drawNumber(95, 16, sk.landingPts, DBLSIZE + RIGHT)
	end

	if sk.state == sk.STATE_SAVE then
		lcd.drawText(4, LCD_H - 10, "EXIT", SMLSIZE + BLINK)
		lcd.drawText(LCD_W - 3, LCD_H - 10, "SAVE", SMLSIZE + BLINK + RIGHT)
	end
end  --  Draw()

return Draw