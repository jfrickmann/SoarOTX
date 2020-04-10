-- 212x64/JFXJ/BRKCRV.lua
-- Timestamp: 2020-04-10
-- Created by Jesper Frickmann

local ui = { } -- List of shared variables

function ui.Draw()
	soarUtil.InfoBar("Airbrake curves")
	lcd.drawText(10, 14, "Use throttle to ")
	lcd.drawText(10, 26, "move airbrakes.")
	lcd.drawText(10, 38, "Thr. and elev.")
	lcd.drawText(10, 50, "trim to adjust.")

	lcd.drawLine(103, 10, 103, 61, SOLID, FORCE)
	lcd.drawText(106, 13, "Flap", SMLSIZE)
	ui.DrawCurve(105, 12, 48, 48, ui.crv[1], ui.lasti)
	lcd.drawLine(155, 10, 155, 61, SOLID, FORCE)
	lcd.drawText(158, 13, "Aile", SMLSIZE)
	ui.DrawCurve(157, 12, 48, 48, ui.crv[2], ui.lasti)
end -- Draw()

return ui