-- 128x64/JF3K/SK8.lua
-- Timestamp: 2020-04-14
-- Created by Jesper Frickmann

local ui = { } -- User interface variables

function ui.Draw()
	local att = {0, 0, 0}
	att[ui.editing] = INVERS + BLINK
	
	soarUtil.InfoBar("Launch")
	
	lcd.drawText(1, 15, "Nominal height:")
	lcd.drawNumber(127, 15, ui.cutoff + ui.zoom, RIGHT + att[1])
	
	lcd.drawText(1, 25, "Zoom:")
	lcd.drawNumber(127, 25, ui.zoom, RIGHT + att[2])
	
	lcd.drawText(1, 35, "Motor time:")
	lcd.drawText(127, 35, soarUtil.TmrStr(ui.time), RIGHT + att[3])
end -- Draw()
	
return ui