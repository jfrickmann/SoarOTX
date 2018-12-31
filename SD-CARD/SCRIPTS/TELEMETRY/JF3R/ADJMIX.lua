-- JF F3RES mix adjustment
-- Timestamp: 2018-09-14
-- Created by Jesper Frickmann

local gv1 = getFieldInfo("gvar1").id

local Draw -- Draw() function is defined for specific transmitter

-- Transmitter specific
if tx == TX_X9D then
	function Draw()
		DrawMenu(" Adjust mixes ")
		
		lcd.drawText(10, 14, "Elev trim = Elev-brake")

		lcd.drawLine(155, 10, 155, 61, SOLID, FORCE)
		
		lcd.drawText(160, 14, "BkE")

		lcd.drawNumber(202, 14, getValue(gv1), RIGHT)
	end -- Draw()
else
	function Draw()
		DrawMenu("Adjust mixes")

		lcd.drawText(5, 14, "Elev trim =", SMLSIZE)

		lcd.drawLine(75, 10, 75, 61, SOLID, FORCE)
		
		lcd.drawText(85, 14, "BkE", SMLSIZE)

		lcd.drawNumber(123, 14, getValue(gv1), RIGHT + SMLSIZE)
	end -- Draw()
end

local function run(event)
	-- Press EXIT to quit
	if event == EVT_EXIT_BREAK then
		return true
	end
	
	-- Enable adjustment function
	adj = 1
	
	Draw()
end -- run()

return{run = run}