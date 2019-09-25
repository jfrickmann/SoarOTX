-- 128x64/JF3K/SK9.lua
-- Timestamp: 2019-09-24
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts
local ui = { } -- User interface variables

function ui.Draw()
	local y = 8
	
	if not ui.planeName then
		return InfoBar("No scores recorded")
	end
	
	InfoBar(ui.taskName)
	
	for i = 1, ui.taskScores do
		if ui.scores[i] then
			if ui.unitStr == "s" then
				lcd.drawText(0, y, string.format("%i. %02i:%02i", i, ui.MinSec(ui.scores[i])))
			else
				lcd.drawText(0, y, string.format("%i. %4i%s", i, ui.scores[i], ui.unitStr))
			end
		else
			lcd.drawText(0, y, string.format("%i. - - -", i))
		end

		y = y + 8
	end	

	lcd.drawText(50, 10, ui.planeName, MIDSIZE)
	lcd.drawText(50, 28, string.format("%s %s", ui.dateStr, ui.timeStr))
	lcd.drawText(50, 42, string.format("Total %i %s", ui.totalScore, ui.unitStr))
	
	-- Warn if the log file is growing too large
	if #ui.indices > 200 then
		lcd.drawText(5, 57, " Log getting too large ", BLINK + INVERS)
	end

end -- Draw()
	
return ui