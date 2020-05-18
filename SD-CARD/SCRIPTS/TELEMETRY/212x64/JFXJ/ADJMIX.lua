-- 212x64/JF/ADJMIX.lua
-- Timestamp: 2020-04-10
-- Created by Jesper Frickmann

local gv3, gv4, gv6, gv7 = ... -- List of shared variables

local	function Draw()
	soarUtil.InfoBar("Adjust mixes ")
	
	lcd.drawText(10, 14, "Rudder trim = Aile-rudder")
	lcd.drawText(10, 26, "Aileron trim = Differential")
	lcd.drawText(10, 38, "Elevator trim = Brake-elev.")
	lcd.drawText(10, 50, "Throttle trim = Snap-flap")

	lcd.drawLine(155, 10, 155, 61, SOLID, FORCE)
	
	lcd.drawText(160, 14, "AiR")
	lcd.drawText(160, 26, "Dif")
	lcd.drawText(160, 38, "BkE")
	lcd.drawText(160, 50, "Snp")

	lcd.drawNumber(202, 14, getValue(gv3), RIGHT)
	lcd.drawNumber(202, 26, getValue(gv4), RIGHT)
	lcd.drawNumber(202, 38, getValue(gv6), RIGHT)
	lcd.drawNumber(202, 50, getValue(gv7), RIGHT)
end -- Draw()

return Draw