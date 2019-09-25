-- 212x64/JF3J/SK.lua
-- Timestamp: 2019-09-24
-- Created by Jesper Frickmann

local sk = ... -- List of shared variables
local ui = { } -- List of  variables shared with loadable user interface

function ui.Draw()
	local fmNbr, fmName = getFlightMode()
	InfoBar(" " .. fmName .. " ")	

	lcd.drawText(0, 20, "Landing", MIDSIZE)
	lcd.drawText(0, 42, "Start", MIDSIZE)

	if sk.state == sk.STATE_INITIAL then
		lcd.drawText(110, 20, "Target", MIDSIZE)
	elseif sk.state <= sk.STATE_WINDOW then
		lcd.drawText(110, 20, "Remain", MIDSIZE)
	else
		lcd.drawText(110, 20, "Window", MIDSIZE)
	end

	if sk.state == sk.STATE_INITIAL then
		lcd.drawTimer(212, 16, ui.winTmr.value, DBLSIZE + RIGHT + BLINK + INVERS)
	else
		lcd.drawTimer(212, 16, ui.winTmr.value, DBLSIZE + RIGHT)
	end

	lcd.drawText(110, 42, "Flight", MIDSIZE)

	if sk.state == sk.STATE_TIME then
		lcd.drawTimer(212, 38, ui.fltTmr.value, DBLSIZE + RIGHT + BLINK + INVERS)
	else
		lcd.drawTimer(212, 38, ui.fltTmr.value, DBLSIZE + RIGHT)
	end

	if sk.state < sk.STATE_LANDINGPTS then
		lcd.drawText(95, 16, "--", DBLSIZE + RIGHT)
	elseif sk.state == sk.STATE_LANDINGPTS then
		lcd.drawNumber(95, 16, sk.landingPts, DBLSIZE + RIGHT + BLINK + INVERS)
	else
		lcd.drawNumber(95, 16, sk.landingPts, DBLSIZE + RIGHT)
	end

	if sk.state < sk.STATE_LANDINGPTS then
		lcd.drawText(95, 38, "---", DBLSIZE + RIGHT)
	elseif sk.state == sk.STATE_STARTHEIGHT then
		lcd.drawNumber(95, 38, sk.startHeight * 10, PREC1 + DBLSIZE + RIGHT + BLINK + INVERS)
	else
		lcd.drawNumber(95, 38, sk.startHeight * 10, PREC1 + DBLSIZE + RIGHT)
	end

	if sk.state == sk.STATE_SAVE then
		lcd.drawText(4, LCD_H - 10, "EXIT", SMLSIZE + BLINK)
		lcd.drawText(LCD_W - 3, LCD_H - 10, "SAVE", SMLSIZE + BLINK + RIGHT)
	end
end  --  Draw()

return ui