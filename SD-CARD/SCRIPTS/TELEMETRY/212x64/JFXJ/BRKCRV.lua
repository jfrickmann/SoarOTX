-- 212x64/JFXJ/BRKCRV.lua
-- Timestamp: 2020-04-18
-- Created by Jesper Frickmann

local ui = ... -- List of shared variables
local crv = soarUtil.LoadWxH("CURVE.lua") -- Screen size specific function
crv.n = ui.n
crv.width = 56
crv.height = 56

function ui.Draw(yFlp, yAil, point)
	soarUtil.InfoBar("Airbrake curves")
	lcd.drawText(0, 14, "Use throttle to ")
	lcd.drawText(0, 26, "move airbrakes.")
	lcd.drawText(0, 38, "Thr. and elev.")
	lcd.drawText(0, 50, "trim to adjust.")

	lcd.drawLine(92, 10, 92, LCD_H, SOLID, FORCE)
	lcd.drawText(94, 9, "Flap", SMLSIZE)
	crv.Draw(94, 8, yFlp, point, 10)
	lcd.drawLine(152, 10, 152, LCD_H, SOLID, FORCE)
	lcd.drawText(154, 9, "Aile", SMLSIZE)
	crv.Draw(154, 8, yAil, point, 10)
end -- Draw()

return ui