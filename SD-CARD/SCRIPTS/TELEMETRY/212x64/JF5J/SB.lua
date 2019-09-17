-- 212x64/JF5J/SB.lua
-- Timestamp: 2019-09-16
-- Created by Jesper Frickmann

local ui = ... -- List of shared variables

local	function Draw()
	lcd.drawText(0, 20, "Landing", MIDSIZE)
	lcd.drawNumber(95, 16, ui.lineData[4], DBLSIZE + RIGHT)

	lcd.drawText(0, 42, "Start", MIDSIZE)
	lcd.drawNumber(95, 38, ui.lineData[5] * 10, PREC1 + DBLSIZE + RIGHT)

	lcd.drawText(110, 20, "Target", MIDSIZE)
	lcd.drawTimer(212, 16, ui.lineData[6], DBLSIZE + RIGHT)

	lcd.drawText(110, 42, "Flight", MIDSIZE)
	lcd.drawTimer(212, 38, ui.lineData[7], DBLSIZE + RIGHT)

	-- Warn if the log file is growing too large
	if #ui.indices > 200 then
		lcd.drawText(40, 57, " Log getting too large ", BLINK + INVERS)
	end
end -- Draw()

return Draw