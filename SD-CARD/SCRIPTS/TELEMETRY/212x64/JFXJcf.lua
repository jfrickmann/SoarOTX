-- 212x64/JFXJcf.lua
-- Timestamp: 2019-09-15
-- Created by Jesper Frickmann

local ui = ...

local function Draw()
	DrawMenu(" JF FxJ Configuration ")
	lcd.drawPixmap(156, 8, "/IMAGES/Lua-girl.bmp")
	
	for i = 1, #ui.texts do
		local inv
		if i == ui.selection then 
			inv = INVERS
		else
			inv = 0
		end
		
		lcd.drawText(2, 11 * i, ui.texts[i], inv)
	end
end -- Draw()

return Draw