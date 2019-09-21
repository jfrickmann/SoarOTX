-- 212x64/JF3Rcf.lua
-- Timestamp: 2019-09-20
-- Created by Jesper Frickmann

local ui = ...

local function Draw()
	DrawMenu("JF F3R Configuration ")
	lcd.drawPixmap(156, 8, "/IMAGES/Lua-girl.bmp")
	
	for i = 1, #ui.texts do
		local inv
		if i == ui.selection then 
			inv = INVERS
		else
			inv = 0
		end
		
		lcd.drawText(0, 13 * i, ui.texts[i], inv)
	end
end -- Draw()

return Draw