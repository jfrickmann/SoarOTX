-- 212x64/JFutil.lua
-- Timestamp: 2019-10-21
-- Created by Jesper Frickmann

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
	lcd.drawText(LCD_W, 0, infoStr, RIGHT)
	lcd.drawScreenTitle(title, 0, 0)
end -- InfoBar()

-- Show help text
function soarUtil.ShowHelp(ht)
	if not soarUtil.showHelp then return end
	
	lcd.drawText(0, 4, "SHOW HELP", INVERS)

	if ht.enter then lcd.drawText(LCD_W, 52, ht.enter, INVERS + RIGHT) end
	if ht.exit then lcd.drawText(0, 52, ht.exit, INVERS) end
	if ht.up then lcd.drawText(LCD_W, 4, ht.up, INVERS + RIGHT) end
	if ht.down then lcd.drawText(LCD_W, 28, ht.down, INVERS + RIGHT) end

	if ht.ud then
		lcd.drawText(LCD_W, 4, " \192 ", INVERS + RIGHT)
		lcd.drawText(LCD_W, 28, " \193 ", INVERS + RIGHT)
	end

	if ht.lr then
		lcd.drawText(LCD_W, 4, " \126 ", INVERS + RIGHT)
		lcd.drawText(LCD_W, 28, " \127 ", INVERS + RIGHT)
	end
end -- ShowHelp()