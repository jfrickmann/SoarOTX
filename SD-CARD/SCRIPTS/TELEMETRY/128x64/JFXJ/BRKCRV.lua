-- 128x64/JF/BRKCRV.lua
-- Timestamp: 2020-04-18
-- Created by Jesper Frickmann

local ui = ... -- List of shared variables
local crv = soarUtil.LoadWxH("CURVE.lua") -- Screen size specific function
crv.n = ui.n
crv.width = 60
crv.height = 56

function ui.Draw(yFlp, yAil, point)
	soarUtil.InfoBar("Airbrakes")
	lcd.drawText(1, 9, "Flap", SMLSIZE)
	crv.Draw(1, 8, yFlp, point, 10)
	lcd.drawLine(64, 8, 64, LCD_H, SOLID, FORCE)
	lcd.drawText(66, 9, "Aile", SMLSIZE)
	crv.Draw(66, 8, yAil, point, 10)
end -- Draw()

return ui