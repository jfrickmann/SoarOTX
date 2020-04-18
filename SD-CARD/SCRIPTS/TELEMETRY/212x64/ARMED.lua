-- 212x64/ARMED.lua
-- Timestamp: 2020-04-18
-- Created by Jesper Frickmann

local function FlashArmed()
	lcd.drawFilledRectangle(30, 20, 152, 32, FORCE)
	lcd.drawText(44, 28, "MOTOR  ARMED", DBLSIZE + BLINK + INVERS)
end

return FlashArmed