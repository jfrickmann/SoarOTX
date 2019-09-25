-- 212x64/JF3R/ADJMIX.lua
-- Timestamp: 2019-09-22
-- Created by Jesper Frickmann

local gv1 = ...

local function Draw()
	InfoBar(" Adjust mixes ")
	lcd.drawText(10, 14, "Elev trim = Elev-brake")
	lcd.drawLine(155, 10, 155, 61, SOLID, FORCE)
	lcd.drawText(160, 14, "BkE")
	lcd.drawNumber(202, 14, getValue(gv1), RIGHT)
end -- Draw()

return Draw