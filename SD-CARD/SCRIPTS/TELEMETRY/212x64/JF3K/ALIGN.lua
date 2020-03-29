-- 212x64/JF3K/ALIGN.lua
-- Timestamp: 2019-09-29
-- Created by Jesper Frickmann

local ui = { } -- List of shared variables

function ui.Draw(i)
	soarUtil.InfoBar(" JF F3K Flaperon alignment ")
	lcd.drawText(2, 12, "Use the throttle")
	lcd.drawText(2, 25, "to move flaps.")
	lcd.drawText(2, 38, "Use the aileron")
	lcd.drawText(2, 51, "trim to align.")		

	lcd.drawLine(92, 8, 92, LCD_H, SOLID, FORCE)
	ui.DrawCurve(94, 8, 56, 56, ui.crvLft, ui.nPoints - i + 1)
	lcd.drawLine(152, 8, 152, LCD_H, SOLID, FORCE)
	ui.DrawCurve(154, 8, 56, 56, ui.crvRgt, i)
end -- Draw()

return ui