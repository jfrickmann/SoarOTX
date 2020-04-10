-- 212x64/JFXJ/AILCMB.lua
-- Timestamp: 2020-04-10
-- Created by Jesper Frickmann

local gv1, gv2, gv5 = ... -- List of shared variables

local	function Draw()
	soarUtil.InfoBar("Aileron and camber")
	
	lcd.drawText(10, 18, "Aileron trim = aileron", 0)
	lcd.drawText(10, 30, "Rudder trim = flaperon", 0)
	lcd.drawText(10, 42, "Elev. trim = aileron camber", 0)

	lcd.drawLine(155, 10, 155, 61, SOLID, FORCE)
	
	lcd.drawText(160, 18, "Ail")
	lcd.drawText(160, 30, "AiF")
	lcd.drawText(160, 42, "CbA")

	lcd.drawNumber(202, 18, getValue(gv1), RIGHT)
	lcd.drawNumber(202, 30, getValue(gv2), RIGHT)
	lcd.drawNumber(202, 42, getValue(gv5), RIGHT)
end -- Draw()

return Draw