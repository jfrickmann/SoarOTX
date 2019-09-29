-- 128x64/JF3K/ALIGN.lua
-- Timestamp: 2019-09-29
-- Created by Jesper Frickmann

local ui = { } -- List of shared variables

function ui.Draw(i)
	soarUtil.InfoBar("Alignment")
	ui.DrawCurve(2, 8, 56, 56, ui.crvLft, ui.nPoints - i + 1)
	lcd.drawLine(64, 8, 64, LCD_H, SOLID, FORCE)
	ui.DrawCurve(70, 8, 56, 56, ui.crvRgt, i)
end -- Draw()

return ui