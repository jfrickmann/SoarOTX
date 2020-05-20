-- 128x64/JF3R/SK.lua
-- Timestamp: 2020-05-20
-- Created by Jesper Frickmann

local sk = ... -- List of shared variables

local function Draw()
	local fmNbr, fmName = getFlightMode()
	soarUtil.InfoBar(fmName)	

	local blnkWt = 0
	local blnkFt = 0

	if sk.state == sk.STATE_SETWINTMR then
		blnkWt = BLINK + INVERS
	elseif sk.state == sk.STATE_SETFLTTMR or sk.state == sk.STATE_TIME then
		blnkFt = BLINK + INVERS
	end
	
	local txtFt = "Rem"
	
	if sk.state <= sk.STATE_SETFLTTMR then
		txtFt = "Tgt"
	elseif sk.state > sk.STATE_WINDOW then
		txtFt = "Flt"
	end
	
	lcd.drawText(0, 20, "Land")

	lcd.drawText(72, 20, "Win")
	lcd.drawTimer(LCD_W, 16, sk.windowTimer.value, MIDSIZE + RIGHT + blnkWt)

	lcd.drawText(72, 42, txtFt)
	lcd.drawTimer(LCD_W, 38, sk.flightTimer.value, MIDSIZE + RIGHT + blnkFt)

	if sk.state < sk.STATE_LANDINGPTS then
		lcd.drawText(54, 16, "--", MIDSIZE + RIGHT)
	elseif sk.state == sk.STATE_LANDINGPTS then
		lcd.drawNumber(54, 16, sk.landingPts, MIDSIZE + RIGHT + BLINK + INVERS)
	else
		lcd.drawNumber(54, 16, sk.landingPts, MIDSIZE + RIGHT)
	end

	if sk.state == sk.STATE_SAVE then
		lcd.drawText(4, LCD_H - 10, "EXIT", SMLSIZE + BLINK)
		lcd.drawText(LCD_W - 3, LCD_H - 10, "SAVE", SMLSIZE + BLINK + RIGHT)
	end
end  --  Draw()

return Draw