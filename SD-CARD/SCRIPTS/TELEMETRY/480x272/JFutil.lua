-- 480x272/JFutil.lua
-- Timestamp: 2020-01-04
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

-- Replace lcd functions with some that are a little less idiotic for widgets
function soarUtil.drawText(x, y, t, a)
	lcd.drawText(soarUtil.x + x, soarUtil.y + y, t, a)
end 

function soarUtil.drawNumber(x, y, z, a)
	lcd.drawNumber(soarUtil.x + x, soarUtil.y + y, z, a)
end 

function soarUtil.drawLine(x1, y1, x2, y2, pattern, flags)
	lcd.drawLine(soarUtil.x + x1, soarUtil.y + y1, soarUtil.x + x2, soarUtil.y + y2, pattern, flags)
end 

function soarUtil.drawFilledRectangle(x, y, w, h, flags)
	lcd.drawFilledRectangle(soarUtil.x + x, soarUtil.y + y, w, h, flags)
end 

-- Draw the basic menu with border and title
function soarUtil.InfoBar(title)
	local now = getDateTime()
	local infoStr = string.format("%1.2fV %02i:%02i", RBat(), now.hour, now.min)

	soarUtil.drawFilledRectangle(0, 0, soarUtil.w, 20, TITLE_BGCOLOR)
	soarUtil.drawLine(0, 20, soarUtil.w, 20, SOLID, 0)
	soarUtil.drawText(0, 0, title)
	soarUtil.drawText(soarUtil.w, 0, infoStr, RIGHT)
end -- InfoBar()

-- Show help text
function soarUtil.ShowHelp(ht)
end -- ShowHelp()