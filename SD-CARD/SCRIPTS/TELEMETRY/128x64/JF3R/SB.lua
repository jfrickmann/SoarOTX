-- 128x64/JF3R/SB.lua
-- Timestamp: 2020-04-30
-- Created by Jesper Frickmann

local ui = { } -- List of shared variables

function ui.Draw()
	if #ui.lineData < 7 then
		return soarUtil.InfoBar("No scores recorded")
	end

	soarUtil.InfoBar(ui.lineData[2] .. " " .. ui.lineData[3])

	lcd.drawText(0, 20, "Land")
	lcd.drawNumber(60, 16, ui.lineData[4], MIDSIZE + RIGHT)

	lcd.drawText(0, 42, "Win")
	lcd.drawTimer(60, 38, ui.lineData[6], MIDSIZE + RIGHT)

	lcd.drawText(72, 20, "Flt")
	lcd.drawTimer(128, 16, ui.lineData[9], MIDSIZE + RIGHT)

	lcd.drawText(72, 42, "Rem")
	lcd.drawTimer(128, 38, ui.lineData[7], MIDSIZE + RIGHT)

	-- Warn if the log file is growing too large
	if #ui.indices > 200 then
		lcd.drawText(12, 57, " Log getting too large ", SMLSIZE + BLINK + INVERS)
	end
end -- Draw()

return ui