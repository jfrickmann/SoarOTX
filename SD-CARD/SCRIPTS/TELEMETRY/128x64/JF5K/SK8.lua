-- 128x64/JF3K/SK8.lua
-- Timestamp: 2020-05-13
-- Created by Jesper Frickmann

local ui = { } -- User interface variables

function ui.Draw()
	local att = {0, 0}
	att[ui.editing] = INVERS + BLINK
	
	soarUtil.InfoBar("Launch")
	
	lcd.drawText(1, 15, "Nominal height:")
	lcd.drawNumber(127, 15, ui.cutoff, RIGHT + att[1])
	
	lcd.drawText(1, 25, "Motor time:")
	lcd.drawText(127, 25, soarUtil.TmrStr(ui.time), RIGHT + att[2])
end -- Draw()
	
return ui