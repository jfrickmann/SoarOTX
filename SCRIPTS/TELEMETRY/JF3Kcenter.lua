-- JF F3K air brake and aileron travel adjustment
-- Timestamp: 2018-03-06
-- Created by Jesper Frickmann

local gvAil = 0 -- Index of global variable used for aileron travel
local gvBrk = 1 -- Index of global variable used for air brake travel
local gvDif = 3 -- Index of global variable used for aileron differential

local Draw -- Draw() function is defined for specific transmitter

-- Transmitter specific
if tx == TX_X9D then
	function Draw(ail, brk)
		DrawMenu(" Flaperon centering ")
		lcd.drawText(160, 18, "Ail")
		lcd.drawText(160, 30, "Brk")

		lcd.drawLine(155, 10, 155, 61, SOLID, FORCE)		
		lcd.drawNumber(202, 18, ail, RIGHT)
		lcd.drawNumber(202, 30, brk, RIGHT)

		lcd.drawText(10, 18, "Use the throttle", 0)
		lcd.drawText(10, 30, "trim to center the", 0)
		lcd.drawText(10, 42, "flaperons.", 0)
	end -- Draw()
else
	function Draw(ail, brk)
		DrawMenu("Flaperon centering")

		lcd.drawText(5, 18, "Use the throttle", SMLSIZE)
		lcd.drawText(5, 30, "trim to center the", SMLSIZE)
		lcd.drawText(5, 42, "flaperons.", SMLSIZE)
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