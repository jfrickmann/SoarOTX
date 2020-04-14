-- 128x64/JF3K/SK9.lua
-- Timestamp: 2020-04-14
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts
local ui = { } -- User interface variables

function ui.Draw()
	local y = 9
	
	if not ui.planeName then
		return soarUtil.InfoBar("No scores recorded")
	end
	
	soarUtil.InfoBar(ui.taskName)

	for i = 1, ui.taskScores do
		if ui.scores[i] then
			lcd.drawText(1, y, string.format("%i.%s %i m.", i, soarUtil.TmrStr(ui.scores[i][1]), ui.scores[i][2]))
		else
			lcd.drawText(1, y, string.format("%i.- - -  - -", i))
		end
		
		y = y + 8
	end

	lcd.drawText(60, 10, ui.planeName)
	lcd.drawText(60, 21, ui.dateStr)
	lcd.drawText(60, 32, ui.timeStr)
	lcd.drawText(60, 43, string.format("Total %i s", ui.totalScore))
	lcd.drawText(60, 54, string.format("Nominal %i m", ui.nominal))

	-- Warn if the log file is growing too large
	if #ui.indices > 200 then
		lcd.drawText(40, 57, " Log is getting too large ", BLINK + INVERS)
	end
	
end -- Draw()
	
return ui