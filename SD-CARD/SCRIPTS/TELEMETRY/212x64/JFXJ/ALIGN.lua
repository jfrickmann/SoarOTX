-- 212x64/JF/ALIGN.lua
-- Timestamp: 2019-09-16
-- Created by Jesper Frickmann

local ui = ... -- List of shared variables

local	function Draw()
	DrawMenu(" Flaps/aileron alignment ")

	lcd.drawText(5, 13, "LA", SMLSIZE)
	ui.DrawCurve(4, 12, 48, 36, ui.crvLft[2], ui.nPoints - ui.lasti + 1)

	lcd.drawText(57, 13, "LF", SMLSIZE)
	ui.DrawCurve(56, 12, 48, 36, ui.crvLft[1], ui.nPoints - ui.lasti + 1)

	lcd.drawText(109, 13, "RF", SMLSIZE)
	ui.DrawCurve(108, 12, 48, 36, ui.crvRgt[1], ui.lasti)		

	lcd.drawText(160, 13, "RA", SMLSIZE)
	ui.DrawCurve(159, 12, 48, 36, ui.crvRgt[2], ui.lasti)

	lcd.drawText(8, 54, "Thr. to move. Rud. and aile. trims to align.", SMLSIZE)
end -- Draw()

return Draw