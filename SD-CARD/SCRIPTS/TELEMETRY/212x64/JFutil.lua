-- 212x64/JFutil.lua
-- Timestamp: 2019-09-29
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
