-- JF F5J mix adjustment
-- Timestamp: 2018-03-31
-- Created by Jesper Frickmann

local gv3 = getFieldInfo("gvar3").id
local gv4 = getFieldInfo("gvar4").id
local gv6 = getFieldInfo("gvar6").id
local gv7 = getFieldInfo("gvar7").id

local Draw -- Draw() function is defined for specific transmitter

-- Transmitter specific
if tx == TX_X9D then
	function Draw()
		DrawMenu(" Adjust mixes ")
		
		lcd.drawText(10, 14, "Rudder trim = Aile-rudder")
		lcd.drawText(10, 26, "Aileron trim = Differential")
		lcd.drawText(10, 38, "Elevator trim = Brake-elev.")
		lcd.drawText(10, 50, "Throttle trim = Snap-flap")

		lcd.drawText(160, 14, "AiR")
		lcd.drawText(160, 26, "Dif")
		lcd.drawText(160, 38, "BkE")
		lcd.drawText(160, 50, "Snp")

		lcd.drawLine(155, 10, 155, 61, SOLID, FORCE)
		
		lcd.drawNumber(202, 14, getValue(gv3), RIGHT)
		lcd.drawNumber(202, 26, getValue(gv4), RIGHT)
		lcd.drawNumber(202, 38, getValue(gv6), RIGHT)
		lcd.drawNumber(202, 50, getValue(gv7), RIGHT)
	end -- Draw()
else
	function Draw()
		DrawMenu("Adjust mixes")

		lcd.drawText(5, 14, "Rudd. trim = Aile-rudd.", SMLSIZE)
		lcd.drawText(5, 26, "Aile. trim = Differential", SMLSIZE)
		lcd.drawText(5, 38, "Elev. trim = Brake-elev.", SMLSIZE)
		lcd.drawText(5, 50, "Throttle trim = Snap-flap", SMLSIZE)
	end -- Draw()
end

local function run(event)
	-- Press EXIT to quit
	if event == EVT_EXIT_BREAK then
		return true
	end
	
	-- Enable adjustment function
	adj = 4
	
	Draw()
end -- run()

return{run = run}