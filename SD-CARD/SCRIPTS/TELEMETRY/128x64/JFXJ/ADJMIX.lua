-- 128x64/JF/ADJMIX.lua
-- Timestamp: 2019-09-29
-- Created by Jesper Frickmann

local gv3, gv4, gv6, gv7 = ... -- List of shared variables

local	function Draw()
	soarUtil.InfoBar("Adjust mixes")

	lcd.drawText(5, 14, "Rudder trim =", SMLSIZE)
	lcd.drawText(5, 26, "Aileron trim =", SMLSIZE)
	lcd.drawText(5, 38, "Elevator trim =", SMLSIZE)
	lcd.drawText(5, 50, "Throttle trim =", SMLSIZE)

	lcd.drawLine(75, 10, 75, 61, SOLID, FORCE)
	
	lcd.drawText(85, 14, "AiR", SMLSIZE)
	lcd.drawText(85, 26, "Dif", SMLSIZE)
	lcd.drawText(85, 38, "BkE", SMLSIZE)
	lcd.drawText(85, 50, "Snp", SMLSIZE)

	lcd.drawNumber(123, 14, getValue(gv3), RIGHT + SMLSIZE)
	lcd.drawNumber(123, 26, getValue(gv4), RIGHT + SMLSIZE)
	lcd.drawNumber(123, 38, getValue(gv6), RIGHT + SMLSIZE)
	lcd.drawNumber(123, 50, getValue(gv7), RIGHT + SMLSIZE)
end -- Draw()

return Draw