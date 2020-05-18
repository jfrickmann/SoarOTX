-- 212x64/JFxK/CENTER.lua
-- Timestamp: 2020-04-18
-- Created by Jesper Frickmann

local function Draw(ail, brk)
	soarUtil.InfoBar("Center flaperons")

	lcd.drawText(5, 12, "Use the throttle trim to ", 0)
	lcd.drawText(5, 24, "center the flaperons to", 0)
	lcd.drawText(5, 36, "their maximum reflex", 0)
	lcd.drawText(5, 48, "position (Speed mode).", 0)

	lcd.drawLine(155, 8, 155, LCD_H, SOLID, FORCE)		

	lcd.drawText(164, 12, "Ail")
	lcd.drawNumber(LCD_W, 12, ail, RIGHT)
	lcd.drawText(164, 24, "Brk")
	lcd.drawNumber(LCD_W, 24, brk, RIGHT)
end -- Draw()

return Draw