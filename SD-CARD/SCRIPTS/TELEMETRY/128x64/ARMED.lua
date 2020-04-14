-- 128x64/ARMED.lua
-- Timestamp: 2020-04-14
-- Created by Jesper Frickmann

local function FlashArmed()
	lcd.drawText(1, 28, "MOTOR  ARMED ", DBLSIZE + BLINK + INVERS)
end

return FlashArmed