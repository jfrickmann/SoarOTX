-- 212x64/JFutil.lua
-- Timestamp: 2020-04-27
-- Created by Jesper Frickmann

-- Draw the basic menu with border and title
function soarUtil.InfoBar(title)
	local now = getDateTime()
	local infoStr = string.format("%1.2fV %02i:%02i", soarUtil.bat, now.hour, now.min)

	lcd.clear()
	lcd.drawText(LCD_W, 0, infoStr, RIGHT)
	lcd.drawScreenTitle(title, 0, 0)
end -- InfoBar()

-- Show help text
function soarUtil.ShowHelp(ht)
	if not soarUtil.showHelp then return end
	
	lcd.drawText(0, 4, "SHOW/HIDE HELP", INVERS)

	if ht.msg1 then
		lcd.drawFilledRectangle(8, 23, 160, 9, FORCE)
		lcd.drawText(8, 24, ht.msg1, INVERS)
	end
	
	if ht.msg2 then
		lcd.drawFilledRectangle(8, 31, 160, 9, FORCE)
		lcd.drawText(8, 32, ht.msg2, INVERS)
	end

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