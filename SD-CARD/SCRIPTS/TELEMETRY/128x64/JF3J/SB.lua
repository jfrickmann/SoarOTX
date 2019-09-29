-- 128x64/JF3J/SB.lua
-- Timestamp: 2019-09-29
-- Created by Jesper Frickmann

local ui = { } -- List of shared variables

function ui.Draw()
	if #ui.lineData < 7 then
		return soarUtil.InfoBar("No scores recorded")
	end

	soarUtil.InfoBar(ui.lineData[2] .. " " .. ui.lineData[3])

	lcd.drawText(0, 20, "Landing")
	lcd.drawNumber(62, 16, ui.lineData[4], MIDSIZE + RIGHT)

	lcd.drawText(0, 42, "Start")
	lcd.drawNumber(62, 38, ui.lineData[5] * 10, PREC1 + MIDSIZE + RIGHT)

	lcd.drawText(66, 20, "Rem")
	lcd.drawTimer(128, 16, ui.lineData[7], MIDSIZE + RIGHT)

	lcd.drawText(66, 42, "Flt")
	lcd.drawTimer(128, 38, ui.lineData[8], MIDSIZE + RIGHT)

	-- Warn if the log file is growing too large
	if #ui.indices > 200 then
		lcd.drawText(5, 57, " Log getting too large ", BLINK + INVERS)
	end
end -- Draw()

return ui