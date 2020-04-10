-- 212x64/JFxK/ADJMIX.lua
-- Timestamp: 2020-04-10
-- Created by Jesper Frickmann

local ui = { } -- List of shared variables

function ui.run(event)
	-- Draw instructions on the screen
	soarUtil.InfoBar("Adjust mixes")

	lcd.drawText(5, 12, "Rudder trim = Aile-rudder", 0)
	lcd.drawText(5, 24, "Aileron trim = Differential", 0)
	lcd.drawText(5, 36, "Elevator trim = Brake-elev.", 0)
	lcd.drawText(5, 48, "Throttle trim = Snap-flap", 0)
	
	lcd.drawLine(155, 8, 155, LCD_H, SOLID, FORCE)
	
	lcd.drawText(164, 12, "AiR")
	lcd.drawText(164, 24, "Dif")
	lcd.drawText(164, 36, "BkE")
	lcd.drawText(164, 48, "Snp")

	lcd.drawNumber(LCD_W, 12, getValue(ui.gv3), RIGHT)
	lcd.drawNumber(LCD_W, 24, getValue(ui.gv4), RIGHT)
	lcd.drawNumber(LCD_W, 36, getValue(ui.gv5), RIGHT)
	lcd.drawNumber(LCD_W, 48, getValue(ui.gv6), RIGHT)

	-- Update aileron throws as in CENTER.lua
	local brk = model.getGlobalVariable(ui.gvBrk, 0)
	local dif = model.getGlobalVariable(ui.gvDif, 0)
	local difComp = 100.0 / math.max(50.0, math.min(100.0, 100.0 + dif))
	local ail = math.min(200, 2 * (100 - brk) * difComp)	
	model.setGlobalVariable(ui.gvAil, 0, ail)
end -- run()

return ui