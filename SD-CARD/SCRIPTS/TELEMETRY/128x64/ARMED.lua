-- 128x64/ARMED.lua
-- Timestamp: 2020-04-18
-- Created by Jesper Frickmann

local function FlashArmed()
	lcd.drawFilledRectangle(0, 20, 128, 32, FORCE)
	lcd.drawText(1, 28, "MOTOR  ARMED ", DBLSIZE + BLINK + INVERS)
end

return FlashArmed