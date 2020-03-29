-- 128x64/JF/BRKCRV.lua
-- Timestamp: 2019-09-29
-- Created by Jesper Frickmann

local ui = { } -- List of shared variables

function ui.Draw()
	soarUtil.InfoBar("Airbrakes")
	lcd.drawText(12, 13, "Flap", SMLSIZE)
	ui.DrawCurve(11, 12, 48, 48, ui.crv[1], ui.lasti)
	lcd.drawLine(64, 10, 64, 61, SOLID, FORCE)
	lcd.drawText(70, 13, "Aile", SMLSIZE)
	ui.DrawCurve(69, 12, 48, 48, ui.crv[2], ui.lasti)
end -- Draw()

return ui