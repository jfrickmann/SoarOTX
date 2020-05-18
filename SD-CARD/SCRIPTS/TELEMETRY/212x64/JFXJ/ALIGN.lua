-- 212x64/JFXJ/ALIGN.lua
-- Timestamp: 2020-04-17
-- Created by Jesper Frickmann

local ui = ... -- List of shared variables
local crv = soarUtil.LoadWxH("CURVE.lua") -- Screen size specific function
crv.n = ui.n
crv.width = 48
crv.height = 56

function ui.Draw(rgtAilY, lftAilY, rgtFlpY, lftFlpY, i)
	soarUtil.InfoBar("Flaps/aileron alignment")

	lcd.drawText(5, 13, "LA", SMLSIZE)
	crv.Draw(4, 8, lftAilY, ui.n + 1 - i)

	lcd.drawLine(54, 8, 54, LCD_H, SOLID, FORCE)

	lcd.drawText(57, 13, "LF", SMLSIZE)
	crv.Draw(56, 8, lftFlpY, ui.n + 1 - i)

	lcd.drawLine(106, 8, 106, LCD_H, SOLID, FORCE)

	lcd.drawText(109, 13, "RF", SMLSIZE)
	crv.Draw(108, 8, rgtFlpY, i)

	lcd.drawLine(157, 8, 157, LCD_H, SOLID, FORCE)

	lcd.drawText(160, 13, "RA", SMLSIZE)
	crv.Draw(159, 8, rgtAilY, i)
end -- Draw()

function ui.DrawReset(reset)
	soarUtil.InfoBar("Flaps/aileron alignment")
	
	if reset == 1 then
		lcd.drawText(25, 15, "Do you want to reset the", MIDSIZE)
		lcd.drawText(25, 30, "flap/aileron outputs?", MIDSIZE)
		lcd.drawText(4, LCD_H - 16, "NO", MIDSIZE + BLINK)
	else
		lcd.drawText(20, 10, "The flap/aileron outputs", MIDSIZE)
		lcd.drawText(20, 22, "did not pass all checks.", MIDSIZE)
		lcd.drawText(20, 34, "Do you want to reset?", MIDSIZE)
		lcd.drawText(4, LCD_H - 16, "EXIT", MIDSIZE + BLINK)
	end
	
	lcd.drawText(LCD_W - 3, LCD_H - 16, "DO IT", MIDSIZE + BLINK + RIGHT)
end -- DrawReset()

return ui