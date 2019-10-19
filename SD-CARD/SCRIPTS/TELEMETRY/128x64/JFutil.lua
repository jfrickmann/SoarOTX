-- 128x64/JFutil.lua
-- Timestamp: 2019-10-17
-- Created by Jesper Frickmann

local helpKeys = { "rotary", "rotrgt", "rotlft", "enter", "exit" }
local helpLabels = { "ROTARY", "ROT \127", "ROT \126", "ENTER", "EXIT" }

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

-- Show help text
function soarUtil.ShowHelp(ht)
	if not soarUtil.showHelp then return end
	
	local y = 22
	
	lcd.drawFilledRectangle(0, 9, 128, 56, SOLID)
	lcd.drawText(0, 11, "MENU", INVERS)
	lcd.drawText(40, 11, "SHOW HELP", INVERS)
	
	for i = 1, #helpKeys do
		if ht[helpKeys[i]] then
			lcd.drawText(0, y, helpLabels[i], INVERS)
			lcd.drawText(40, y, ht[helpKeys[i]], INVERS)
			y = y + 11
		end
	end
end -- ShowHelp()