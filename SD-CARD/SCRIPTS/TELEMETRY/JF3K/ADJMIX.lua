-- JF F3K mix adjustment
-- Timestamp: 2019-07-05
-- Created by Jesper Frickmann

-- For updating aileron throws with negative differential
local gvAil = 0 -- Index of global variable used for aileron travel
local gvBrk = 1 -- Index of global variable used for air brake travel
local gvDif = 3 -- Index of global variable used for aileron differential

-- This is pretty messy, but getValue works better for getting values for the current flight mode,
-- whereas getGlobalVariable works better for flight mode 0 and for setting GVs from Lua 
local gv3 = getFieldInfo("gvar3").id
local gv4 = getFieldInfo("gvar4").id
local gv5 = getFieldInfo("gvar5").id
local gv6 = getFieldInfo("gvar6").id

local run -- run() function is defined for specific transmitter

-- Transmitter specific
if tx == TX_X9D then
	function run(event)
		-- Press EXIT to quit
		if event == EVT_EXIT_BREAK then
			return true
		end
		
		-- Enable adjustment function
		adj = 3
		
		-- Draw instructions on the screem
		DrawMenu(" Adjust mixes ")

		lcd.drawText(5, 12, "Rudder trim = Aile-rudder", 0)
		lcd.drawText(5, 24, "Aileron trim = Differential", 0)
		lcd.drawText(5, 36, "Elevator trim = Brake-elev.", 0)
		lcd.drawText(5, 48, "Throttle trim = Snap-flap", 0)
		
		lcd.drawLine(155, 8, 155, LCD_H, SOLID, FORCE)
		
		lcd.drawText(164, 12, "AiR")
		lcd.drawText(164, 24, "Dif")
		lcd.drawText(164, 36, "BkE")
		lcd.drawText(164, 48, "Snp")

		lcd.drawNumber(LCD_W, 12, getValue(gv3), RIGHT)
		lcd.drawNumber(LCD_W, 24, getValue(gv4), RIGHT)
		lcd.drawNumber(LCD_W, 36, getValue(gv5), RIGHT)
		lcd.drawNumber(LCD_W, 48, getValue(gv6), RIGHT)

		-- Update aileron throws as in CENTER.lua
		local brk = model.getGlobalVariable(gvBrk, 0)
		local dif = model.getGlobalVariable(gvDif, 0)
		local difComp = 100.0 / math.max(50.0, math.min(100.0, 100.0 + dif))
		local ail = math.min(200, 2 * (100 - brk) * difComp)	
		model.setGlobalVariable(gvAil, 0, ail)
	end -- run()
else
	function run(event)
		-- Press EXIT to quit
		if event == EVT_EXIT_BREAK then
			return true
		end
		
		-- Enable adjustment function
		adj = 3
		
		-- Draw instructions on the screem
		DrawMenu("Adjust mixes")

		lcd.drawText(2, 12, "Rudder trim =", SMLSIZE)
		lcd.drawText(2, 24, "Aileron trim =", SMLSIZE)
		lcd.drawText(2, 36, "Elevator trim =", SMLSIZE)
		lcd.drawText(2, 48, "Throttle trim =", SMLSIZE)

		lcd.drawLine(82, 8, 82, LCD_H, SOLID, FORCE)
		
		lcd.drawText(88, 12, "AiR", SMLSIZE)
		lcd.drawText(88, 24, "Dif", SMLSIZE)
		lcd.drawText(88, 36, "BkE", SMLSIZE)
		lcd.drawText(88, 48, "Snp", SMLSIZE)

		lcd.drawNumber(LCD_W, 12, getValue(gv3), RIGHT + SMLSIZE)
		lcd.drawNumber(LCD_W, 24, getValue(gv4), RIGHT + SMLSIZE)
		lcd.drawNumber(LCD_W, 36, getValue(gv5), RIGHT + SMLSIZE)
		lcd.drawNumber(LCD_W, 48, getValue(gv6), RIGHT + SMLSIZE)

		-- Update aileron throws as in CENTER.lua
		local brk = model.getGlobalVariable(gvBrk, 0)
		local dif = model.getGlobalVariable(gvDif, 0)
		local difComp = 100.0 / math.max(50.0, math.min(100.0, 100.0 + dif))
		local ail = math.min(200, 2 * (100 - brk) * difComp)	
		model.setGlobalVariable(gvAil, 0, ail)
	end -- run()
end

return{run = run}