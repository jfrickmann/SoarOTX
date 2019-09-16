-- 128x64/JFXJcf.lua
-- Timestamp: 2019-09-15
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
		
		lcd.drawText(0, 11 * i, ui.texts[i], SMLSIZE + inv)
	end
end -- Draw()

return Draw