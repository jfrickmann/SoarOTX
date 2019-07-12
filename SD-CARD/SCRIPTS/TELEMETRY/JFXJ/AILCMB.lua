-- JF FXJ aileron and camber adjustment
-- Timestamp: 2019-07-07
-- Created by Jesper Frickmann

local gv1 = getFieldInfo("gvar1").id
local gv2 = getFieldInfo("gvar2").id
local gv5 = getFieldInfo("gvar5").id

local Draw -- Draw() function is defined for specific transmitter

-- Transmitter specific
if LCD_W == 128 then
	function Draw()
		DrawMenu("Aile & camber")

		lcd.drawText(5, 18, "Aileron trim =", SMLSIZE)
		lcd.drawText(5, 30, "Rudder trim =", SMLSIZE)
		lcd.drawText(5, 42, "Elevator trim =", SMLSIZE)

		lcd.drawLine(75, 10, 75, 61, SOLID, FORCE)
		
		lcd.drawText(85, 18, "Ail", SMLSIZE)
		lcd.drawText(85, 30, "AiF", SMLSIZE)
		lcd.drawText(85, 42, "CbA", SMLSIZE)

		lcd.drawNumber(123, 18, getValue(gv1), RIGHT + SMLSIZE)
		lcd.drawNumber(123, 30, getValue(gv2), RIGHT + SMLSIZE)
		lcd.drawNumber(123, 42, getValue(gv5), RIGHT + SMLSIZE)
	end -- Draw()
else
	function Draw()
		DrawMenu(" Aileron and camber ")
		
		lcd.drawText(10, 18, "Aileron trim = aileron", 0)
		lcd.drawText(10, 30, "Rudder trim = flaperon", 0)
		lcd.drawText(10, 42, "Elev. trim = aileron camber", 0)

		lcd.drawLine(155, 10, 155, 61, SOLID, FORCE)
		
		lcd.drawText(160, 18, "Ail")
		lcd.drawText(160, 30, "AiF")
		lcd.drawText(160, 42, "CbA")

		lcd.drawNumber(202, 18, getValue(gv1), RIGHT)
		lcd.drawNumber(202, 30, getValue(gv2), RIGHT)
		lcd.drawNumber(202, 42, getValue(gv5), RIGHT)
	end -- Draw()
end


local function run(event)
	-- Press EXIT to quit
	if event == EVT_EXIT_BREAK then
		return true
	end
	
	-- Enable adjustment function
	adj = 3
	
	Draw()
end -- run()

return{run = run}