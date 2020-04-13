-- 128x64/ARMED.lua
-- Timestamp: 2020-04-13
-- Created by Jesper Frickmann

local function FlashArmed()
	lcd.drawText(2, 28, "MOTOR  ARMED", DBLSIZE + BLINK + INVERS)
end

return FlashArmed