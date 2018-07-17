-- JF F3K mix adjustment
-- Timestamp: 2018-07-16
-- Created by Jesper Frickmann

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

		lcd.drawText(10, 14, "Rudder trim = Aile-rudder", 0)
		lcd.drawText(10, 26, "Aileron trim = Differential", 0)
		lcd.drawText(10, 38, "Elevator trim = Brake-elev.", 0)
		lcd.drawText(10, 50, "Throttle trim = Snap-flap", 0)
		
		lcd.drawLine(155, 10, 155, 61, SOLID, FORCE)
		
		lcd.drawText(160, 14, "AiR")
		lcd.drawText(160, 26, "Dif")
		lcd.drawText(160, 38, "BkE")
		lcd.drawText(160, 50, "Snp")

		lcd.drawNumber(202, 14, getValue(gv3), RIGHT)
		lcd.drawNumber(202, 26, getValue(gv4), RIGHT)
		lcd.drawNumber(202, 38, getValue(gv5), RIGHT)
		lcd.drawNumber(202, 50, getValue(gv6), RIGHT)
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

		lcd.drawText(5, 14, "Rudder trim =", SMLSIZE)
		lcd.drawText(5, 26, "Aileron trim =", SMLSIZE)
		lcd.drawText(5, 38, "Elevator trim =", SMLSIZE)
		lcd.drawText(5, 50, "Throttle trim =", SMLSIZE)

		lcd.drawLine(75, 10, 75, 61, SOLID, FORCE)
		
		lcd.drawText(85, 14, "AiR", SMLSIZE)
		lcd.drawText(85, 26, "Dif", SMLSIZE)
		lcd.drawText(85, 38, "BkE", SMLSIZE)
		lcd.drawText(85, 50, "Snp", SMLSIZE)

		lcd.drawNumber(123, 14, getValue(gv3), RIGHT + SMLSIZE)
		lcd.drawNumber(123, 26, getValue(gv4), RIGHT + SMLSIZE)
		lcd.drawNumber(123, 38, getValue(gv5), RIGHT + SMLSIZE)
		lcd.drawNumber(123, 50, getValue(gv6), RIGHT + SMLSIZE)
	end -- run()
end

return{run = run}