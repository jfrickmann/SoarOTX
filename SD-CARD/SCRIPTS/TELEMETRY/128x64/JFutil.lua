-- 128x64/JFutil.lua
-- Timestamp: 2020-03-30
-- Created by Jesper Frickmann

local helpKeys = { "enter", "up", "down", "ud", "lr", "exit" }
local helpLabels = { "ENTER", "ROT \192", "ROT \193", "ROT  \192\193", "ROT  \127\126", "EXIT" }

-- Input value for the receiver battery
local RBat
do
	local batField = getFieldInfo("RBat")
	if not batField then batField = getFieldInfo("RxBt") end
	if not batField then batField = getFieldInfo("A1") end
	
	if batField then
		RBat = function()
			return getValue(batField.id)
		end
	else
		RBat = function()
			return 0
		end
	end
end

-- Draw the basic menu with border and title
function soarUtil.InfoBar(title)
	local now = getDateTime()
	local infoStr = string.format("%1.2fV %02i:%02i", RBat(), now.hour, now.min)

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
	end
end

-- Show help text
function soarUtil.ShowHelp(ht)
	if not soarUtil.showHelp then return end
	
	local y = 22
	
	lcd.drawFilledRectangle(0, 9, 128, 56, SOLID)
	lcd.drawText(1, 11, menu, INVERS)
	lcd.drawText(45, 11, "SHOW/HIDE HELP", INVERS)
	
	for i = 1, #helpKeys do
		if ht[helpKeys[i]] then
			lcd.drawText(1, y, helpLabels[i], INVERS)
			lcd.drawText(45, y, ht[helpKeys[i]], INVERS)
			y = y + 11
		end
	end
end -- ShowHelp()