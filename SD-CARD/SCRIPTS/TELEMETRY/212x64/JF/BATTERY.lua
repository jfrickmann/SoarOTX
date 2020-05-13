-- 212x64/JF/BATTERY.lua
-- Timestamp: 2020-05-13
-- Created by Jesper Frickmann

local ui = ...

local	function Draw()
	soarUtil.InfoBar("Battery Warning")
	
	lcd.drawText(0, 12, "Battery level:")
	lcd.drawNumber(100, 12, 10 * soarUtil.bat + 0.5, RIGHT + PREC1)
	lcd.drawText(101, 12, "V")	

	lcd.drawText(0, 24, "Warning level:")
	lcd.drawNumber(100, 24, ui.bat10 + 0.5, RIGHT + PREC1 + INVERS + BLINK)
	lcd.drawText(101, 24, "V")	

	
end -- Draw()

return Draw