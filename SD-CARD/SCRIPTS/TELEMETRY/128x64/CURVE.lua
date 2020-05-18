-- 128x64/CURVE.lua
-- Timestamp: 2020-04-18
-- Created by Jesper Frickmann
-- Needs crv.width, crv.height and crv.n to be set

local crv = { } -- Shared data

crv.Draw = function(lft, top, y, i, scale)
	if not scale then scale = 1 end

	local x1, x2, y1, y2, y3
	
	if not (crv.width and crv.height and crv.n) then return end
	
	for j = 1, crv.n do
		local att
		
		-- Screen coordinates
		x2 = lft  + crv.width * (j - 1) / (crv.n - 1)
		y2 = top + crv.height * (0.5 - 0.00033 * scale * y[j])
		
		-- Mark point i
		if j == i then
			att = SMLSIZE + INVERS
			y3 = scale * y[j]
		else
			att = SMLSIZE
		end
		
		-- Draw marker
		lcd.drawText(x2, y2 - 2.5, "|", att)
		
		-- Draw line
		if j >= 2 then
			lcd.drawLine(x1, y1, x2, y2, SOLID, FORCE)
		end
		
		-- Save this point before going to the next one
		x1, y1 = x2, y2
	end
	
	-- Draw reference lines
	lcd.drawLine(lft, top + 0.5 * crv.height, lft + crv.width, top + 0.5 * crv.height, DOTTED, FORCE)
	lcd.drawLine(lft + 0.5 * crv.width, top, lft + 0.5 * crv.width, top + crv.height, DOTTED, FORCE)

	-- Draw the value being edited
	lcd.drawNumber(lft + crv.width, top + crv.height - 6, y3, PREC1 + RIGHT + SMLSIZE)
end -- DrawCurve()

return crv