-- 128x64/JFxK/ALIGN.lua
-- Timestamp: 2020-04-14
-- Created by Jesper Frickmann

local ui = ... -- List of shared variables
local crv = soarUtil.LoadWxH("CURVE.lua") -- Screen size specific function
crv.n = ui.n
crv.width = 56
crv.height = 56

function ui.Draw(rgtY, lftY, i)
	soarUtil.InfoBar("Alignment")
	crv.Draw(2, 8, lftY, ui.n + 1 - i)
	lcd.drawLine(64, 8, 64, LCD_H, SOLID, FORCE)
	crv.Draw(70, 8, rgtY, i)

	soarUtil.ShowHelp({enter = "RESET", exit = "EXIT", msg1 = "Select pt. w. throttle.", msg2 = "TrmT and TrmA to adjust." })
end -- Draw()

function ui.DrawReset(reset)
	soarUtil.InfoBar("Alignment")
	
	if reset == 1 then
		lcd.drawText(0, 12, "Do you want to reset")
		lcd.drawText(0, 24, "the flaperon outputs?")
		lcd.drawText(0, 36, "ENTER = DO IT")
		lcd.drawText(0, 48, "EXIT = NO")
	else
		lcd.drawText(0, 10, "The flaperon outputs")
		lcd.drawText(0, 20, "did not pass all checks.")
		lcd.drawText(0, 30, "Do you want to reset?")
		lcd.drawText(0, 40, "ENTER = RESET")
		lcd.drawText(0, 50, "EXIT = NO")
	end
end -- DrawReset()