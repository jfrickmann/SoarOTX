-- 212x64/JFxK/ALIGN.lua
-- Timestamp: 2020-04-18
-- Created by Jesper Frickmann

local ui = ... -- List of shared variables
local crv = soarUtil.LoadWxH("CURVE.lua") -- Screen size specific function
crv.n = ui.n
crv.width = 56
crv.height = 56

function ui.Draw(rgtY, lftY, i)
	soarUtil.InfoBar("Align flaperons")	

	lcd.drawText(0, 10, "Use the throttle")
	lcd.drawText(0, 20, "to select point.")
	lcd.drawText(0, 30, "Use aileron and")
	lcd.drawText(0, 40, "throttle trims")		
	lcd.drawText(0, 50, "to adjust.")		

	lcd.drawLine(92, 8, 92, LCD_H, SOLID, FORCE)
	crv.Draw(94, 8, lftY, ui.n + 1 - i)
	lcd.drawLine(152, 8, 152, LCD_H, SOLID, FORCE)
	crv.Draw(154, 8, rgtY, i)

	soarUtil.ShowHelp({enter = "RESET", exit = "EXIT" })
end -- Draw()

function ui.DrawReset(reset)
	soarUtil.InfoBar("JF F3K Flaperon alignment")
	
	if reset == 1 then
		lcd.drawText(25, 15, "Do you want to reset", MIDSIZE)
		lcd.drawText(25, 30, "the flaperon outputs?", MIDSIZE)
		lcd.drawText(4, LCD_H - 16, "NO", MIDSIZE + BLINK)
	else
		lcd.drawText(20, 10, "The flaperon outputs", MIDSIZE)
		lcd.drawText(20, 22, "did not pass all checks.", MIDSIZE)
		lcd.drawText(20, 34, "Do you want to reset?", MIDSIZE)
		lcd.drawText(4, LCD_H - 16, "EXIT", MIDSIZE + BLINK)
	end
	
	lcd.drawText(LCD_W - 3, LCD_H - 16, "DO IT", MIDSIZE + BLINK + RIGHT)
end -- DrawReset()