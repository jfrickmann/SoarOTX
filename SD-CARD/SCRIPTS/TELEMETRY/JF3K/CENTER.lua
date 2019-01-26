-- JF F3K air brake and aileron travel adjustment
-- Timestamp: 2018-12-30
-- Created by Jesper Frickmann

local gvAil = 0 -- Index of global variable used for aileron travel
local gvBrk = 1 -- Index of global variable used for air brake travel
local gvDif = 3 -- Index of global variable used for aileron differential

local Draw -- Draw() function is defined for specific transmitter

-- Transmitter specific
if tx == TX_X9D then
	function Draw(ail, brk)
		DrawMenu(" Flaperon centering ")

		lcd.drawText(5, 12, "Use the throttle trim to ", 0)
		lcd.drawText(5, 24, "center the flaperons to", 0)
		lcd.drawText(5, 36, "their maximum reflex", 0)
		lcd.drawText(5, 48, "position (Speed mode).", 0)

		lcd.drawLine(155, 8, 155, LCD_H, SOLID, FORCE)		

		lcd.drawText(164, 12, "Ail")
		lcd.drawNumber(LCD_W, 12, ail, RIGHT)
		lcd.drawText(164, 24, "Brk")
		lcd.drawNumber(LCD_W, 24, brk, RIGHT)
	end -- Draw()
else
	function Draw(ail, brk)
		DrawMenu("Flaperons")

		lcd.drawText(2, 12, "Use throttle")
		lcd.drawText(2, 24, "trim to center")
		lcd.drawText(2, 36, "the flaperons")
		lcd.drawText(2, 48, "to Speed pos.")

		lcd.drawLine(82, 8, 82, LCD_H, SOLID, FORCE)		

		lcd.drawText(88, 12, "Ail")
		lcd.drawNumber(LCD_W, 12, ail, RIGHT)
		lcd.drawText(88, 24, "Brk")
		lcd.drawNumber(LCD_W, 24, brk, RIGHT)
	end -- Draw()
end

local function run(event)
	-- Press EXIT to quit
	if event == EVT_EXIT_BREAK then
		return true
	end
	
	local brk = model.getGlobalVariable(gvBrk, 0)
	local dif = model.getGlobalVariable(gvDif, 0)
	
	-- Enable adjustment function
	adj = 2
	
	-- Compensate for negative differential
	local difComp = 100.0 / math.max(50.0, math.min(100.0, 100.0 + dif))
	
	-- Calculate aileron travel from current air brak travel
	local ail = math.min(100, 2 * (100 - brk) * difComp)
	
	model.setGlobalVariable(gvAil, 0, ail)
	Draw(ail, brk)
end -- run()

return{run = run}