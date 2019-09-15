-- 128x64/JF3Kcf.lua
-- Timestamp: 2019-09-14
-- Created by Jesper Frickmann

local ui = ...

local function Draw()
	DrawMenu("Configuration")
	
	for i = 1, #ui.texts do
		local inv
		if i == ui.selection then 
			inv = INVERS
		else
			inv = 0
		end
		
		lcd.drawText(3, 13 * i, ui.texts[i], SMLSIZE + inv)
	end
end -- Draw()

return Draw