-- 128x64/JF3K/ALIGN.lua
-- Timestamp: 2020-04-04
-- Created by Jesper Frickmann

local ui = ... -- List of shared variables
local crv = soarUtil.LoadWxH("CURVE.lua") -- Screen size specific function
crv.n = ui.n
crv.width = 56
crv.height = 56

function ui.Draw(rgtY, lftY, i)
	soarUtil.InfoBar("Alignment ")	

	crv.Draw(2, 8, lftY, ui.n + 1 - i)
	lcd.drawLine(64, 8, 64, LCD_H, SOLID, FORCE)
	crv.Draw(70, 8, rgtY, i)

	soarUtil.ShowHelp({enter = "RESET", exit = "EXIT" })
end -- Draw()

function ui.DrawReset(reset)
	soarUtil.InfoBar("Alignment ")
	
	if reset == 1 then
		lcd.drawText(4, 12, "Do you want to reset")
		lcd.drawText(4, 24, "the flaperon outputs?")
		lcd.drawText(4, 52, "EXIT = NO")
	else
		lcd.drawText(4, 12, "Outputs failed checks.")
		lcd.drawText(4, 24, "Do you want to reset?")
		lcd.drawText(4, 52, "EXIT = CANCEL")
	end
	
	lcd.drawText(4, 40, "ENTER = DO IT")
end -- DrawReset()