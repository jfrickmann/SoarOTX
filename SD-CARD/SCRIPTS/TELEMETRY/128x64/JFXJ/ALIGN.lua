-- 128x64/JF/ALIGN.lua
-- Timestamp: 2020-04-18
-- Created by Jesper Frickmann

local ui = ... -- List of shared variables
local crv = soarUtil.LoadWxH("CURVE.lua") -- Screen size specific function
crv.n = ui.n
crv.width = 61
crv.height = 26

function ui.Draw(rgtAilY, lftAilY, rgtFlpY, lftFlpY, i)
	soarUtil.InfoBar("Alignment")

	lcd.drawLine(64, 9, 64, LCD_H, SOLID, FORCE)
	lcd.drawLine(1, 36, LCD_W, 36, SOLID, FORCE)

	lcd.drawText(1, 9, "LA", SMLSIZE)
	crv.Draw(1, 9, lftAilY, ui.n + 1 - i)

	lcd.drawText(1, 37, "LF", SMLSIZE)
	crv.Draw(1, 37, lftFlpY, ui.n + 1 - i)

	lcd.drawText(65, 37, "RF", SMLSIZE)
	crv.Draw(65, 37, rgtFlpY, i)

	lcd.drawText(65, 9, "RA", SMLSIZE)
	crv.Draw(65, 9, rgtAilY, i)
end -- Draw()

return ui