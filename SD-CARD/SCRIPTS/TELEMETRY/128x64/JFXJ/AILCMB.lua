-- 128x64/JF/AILCMB.lua
-- Timestamp: 2019-09-29
-- Created by Jesper Frickmann

local gv1, gv2, gv5 = ... -- List of shared variables

local	function Draw()
	soarUtil.InfoBar("Aile & camber")

	lcd.drawText(5, 18, "Aileron trim =", SMLSIZE)
	lcd.drawText(5, 30, "Rudder trim =", SMLSIZE)
	lcd.drawText(5, 42, "Elevator trim =", SMLSIZE)

	lcd.drawLine(75, 10, 75, 61, SOLID, FORCE)
	
	lcd.drawText(85, 18, "Ail", SMLSIZE)
	lcd.drawText(85, 30, "AiF", SMLSIZE)
	lcd.drawText(85, 42, "CbA", SMLSIZE)

	lcd.drawNumber(123, 18, getValue(gv1), RIGHT + SMLSIZE)
	lcd.drawNumber(123, 30, getValue(gv2), RIGHT + SMLSIZE)
	lcd.drawNumber(123, 42, getValue(gv5), RIGHT + SMLSIZE)
end -- Draw()

return Draw