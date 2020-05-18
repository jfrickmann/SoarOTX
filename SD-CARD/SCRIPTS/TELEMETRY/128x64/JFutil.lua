-- 128x64/JFutil.lua
-- Timestamp: 2020-04-27
-- Created by Jesper Frickmann

local helpKeys = { "enter", "up", "down", "ud", "lr", "exit" }
local helpLabels = { "ENTER", "ROT \192", "ROT \193", "ROT  \192\193", "ROT  \127\126", "EXIT" }

-- Draw the basic menu with border and title
function soarUtil.InfoBar(title)
	local now = getDateTime()
	local infoStr = string.format("%1.2fV %02i:%02i", soarUtil.bat, now.hour, now.min)

	lcd.clear()
	lcd.drawScreenTitle(title, 0, 0)
	lcd.drawText(LCD_W, 0, infoStr, RIGHT)
end -- InfoBar()

-- Xlite has no MENU button, so use SHIFT instead
local menu = "MENU"
do
	local ver, radio = getVersion()
	if string.find(radio, "xlite") then
		menu ="SHIFT"
	elseif string.find(radio, "t12") then
		menu ="\127 \126"
	end
end

-- Show help text
function soarUtil.ShowHelp(ht)
	if not soarUtil.showHelp then return end
	
	lcd.drawFilledRectangle(0, 9, 128, 56, SOLID)
	local y = 11
	
	if ht["msg1"] then
		lcd.drawText(1, y, ht["msg1"], INVERS)		
		y = y + 11
	end

	if ht["msg2"] then
		lcd.drawText(1, y, ht["msg2"], INVERS)		
		y = y + 11
	end

	lcd.drawText(1, y, menu, INVERS)
	lcd.drawText(45, y, "SHOW/HIDE HELP", INVERS)
	y = y + 11
	
	for i = 1, #helpKeys do
		if ht[helpKeys[i]] then
			lcd.drawText(1, y, helpLabels[i], INVERS)
			lcd.drawText(45, y, ht[helpKeys[i]], INVERS)
			y = y + 11
		end
	end

end -- ShowHelp()