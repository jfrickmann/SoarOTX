-- 128x64/JF3R/ADJMIX.lua
-- Timestamp: 2019-09-29
-- Created by Jesper Frickmann

local gv1 = ...

local function Draw()
	soarUtil.InfoBar("Adjust mixes")
	lcd.drawText(5, 14, "Elev trim =", SMLSIZE)
	lcd.drawLine(75, 10, 75, 61, SOLID, FORCE)
	lcd.drawText(85, 14, "BkE", SMLSIZE)
	lcd.drawNumber(123, 14, getValue(gv1), RIGHT + SMLSIZE)
end -- Draw()

return Draw