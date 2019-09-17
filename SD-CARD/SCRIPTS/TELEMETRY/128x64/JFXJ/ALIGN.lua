-- 128x64/JF/ALIGN.lua
-- Timestamp: 2019-09-16
-- Created by Jesper Frickmann

local ui = ... -- List of shared variables

local	function Draw()
	DrawMenu("Alignment")

	lcd.drawLine(64, 10, 64, 61, SOLID, FORCE)
	lcd.drawLine(2, 36, 126, 36, SOLID, FORCE)

	lcd.drawText(11, 12, "LA", SMLSIZE)
	ui.DrawCurve(11, 12, 48, 22, ui.crvLft[2], ui.nPoints - ui.lasti + 1)

	lcd.drawText(69, 12, "RA", SMLSIZE)
	ui.DrawCurve(69, 12, 48, 22, ui.crvRgt[2], ui.lasti)

	lcd.drawText(11, 38, "LF", SMLSIZE)
	ui.DrawCurve(11, 38, 48, 22, ui.crvLft[1], ui.nPoints - ui.lasti + 1)

	lcd.drawText(69, 38, "RF", SMLSIZE)
	ui.DrawCurve(69, 38, 48, 22, ui.crvRgt[1], ui.lasti)
end -- Draw()

return Draw