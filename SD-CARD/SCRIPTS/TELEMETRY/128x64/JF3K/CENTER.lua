-- 128x64/JF3K/CENTER.lua
-- Timestamp: 2019-09-22
-- Created by Jesper Frickmann

local function Draw(ail, brk)
	InfoBar("Flaperons")

	lcd.drawText(2, 12, "Use throttle")
	lcd.drawText(2, 24, "trim to center")
	lcd.drawText(2, 36, "the flaperons")
	lcd.drawText(2, 48, "to Speed pos.")

	lcd.drawLine(82, 8, 82, LCD_H, SOLID, FORCE)		

	lcd.drawText(88, 12, "Ail")
	lcd.drawNumber(LCD_W, 12, ail, RIGHT)
	lcd.drawText(88, 24, "Brk")
	lcd.drawNumber(LCD_W, 24, brk, RIGHT)
end -- Draw()

return Draw