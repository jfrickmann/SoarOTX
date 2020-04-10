-- 212x64/JF3K/SK9.lua
-- Timestamp: 2020-04-10
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts
local ui = { } -- User interface variables

function ui.Draw()
	local x = 0
	local y = 9
	local split

	if not ui.planeName then
		return soarUtil.InfoBar("No scores recorded ")
	end
	
	soarUtil.InfoBar(ui.taskName)

	if ui.taskScores == 5 or taskScores == 6 then
		split = 4
	else
		split = 5
	end

	for i = 1, ui.taskScores do
		if i == split then
			x = 50
			y = 9
		end

		if ui.scores[i] then
			if ui.unitStr == "s" then
				lcd.drawText(x, y, string.format("%i. %s", i, soarUtil.TmrStr(ui.scores[i])), MIDSIZE)
			else
				lcd.drawText(x, y, string.format("%i. %4i%s", i, ui.scores[i], ui.unitStr), MIDSIZE)
			end
		else
			lcd.drawText(x, y, string.format("%i. - - -", i), MIDSIZE)
		end
		
		y = y + 14
	end

	lcd.drawText(105, 10, ui.planeName, DBLSIZE)
	lcd.drawText(105, 32, string.format("%s %s", ui.dateStr, ui.timeStr), MIDSIZE)
	lcd.drawText(105, 48, string.format("Total %i %s", ui.totalScore, ui.unitStr), MIDSIZE)

	-- Warn if the log file is growing too large
	if #ui.indices > 200 then
		lcd.drawText(40, 57, " Log is getting too large ", BLINK + INVERS)
	end
	
end -- Draw()
	
return ui