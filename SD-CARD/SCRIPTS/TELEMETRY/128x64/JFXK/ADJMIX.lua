-- 128x64/JFxK/ADJMIX.lua
-- Timestamp: 2020-04-09
-- Created by Jesper Frickmann

local ui = { } -- List of shared variables

function ui.run(event)
	-- Draw instructions on the screen
	soarUtil.InfoBar("Adjust mixes")

	lcd.drawText(2, 12, "Rudder trim =", SMLSIZE)
	lcd.drawText(2, 24, "Aileron trim =", SMLSIZE)
	lcd.drawText(2, 36, "Elevator trim =", SMLSIZE)
	lcd.drawText(2, 48, "Throttle trim =", SMLSIZE)

	lcd.drawLine(82, 8, 82, LCD_H, SOLID, FORCE)
	
	lcd.drawText(88, 12, "AiR", SMLSIZE)
	lcd.drawText(88, 24, "Dif", SMLSIZE)
	lcd.drawText(88, 36, "BkE", SMLSIZE)
	lcd.drawText(88, 48, "Snp", SMLSIZE)

	lcd.drawNumber(LCD_W, 12, getValue(ui.gv3), RIGHT + SMLSIZE)
	lcd.drawNumber(LCD_W, 24, getValue(ui.gv4), RIGHT + SMLSIZE)
	lcd.drawNumber(LCD_W, 36, getValue(ui.gv5), RIGHT + SMLSIZE)
	lcd.drawNumber(LCD_W, 48, getValue(ui.gv6), RIGHT + SMLSIZE)

	-- Update aileron throws as in CENTER.lua
	local brk = model.getGlobalVariable(ui.gvBrk, 0)
	local dif = model.getGlobalVariable(ui.gvDif, 0)
	local difComp = 100.0 / math.max(50.0, math.min(100.0, 100.0 + dif))
	local ail = math.min(200, 2 * (100 - brk) * difComp)	
	model.setGlobalVariable(ui.gvAil, 0, ail)
end -- run()

return ui