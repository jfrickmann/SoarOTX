-- 212x64/PLOT.lua
-- Timestamp: 2019-09-28
-- Created by Jesper Frickmann
-- Shared script for plotting data
-- Design inspired by Nigel Sheffield's script

local gr = ... 
--[[ List of shared variables --
	gr.tMin, gr.tMax
	gr.yMin, gr.yMax
	gr.left, gr.right
	gr.yValues
]]--

local function Plot()
	local mag
	local flags
	local precFac
	local xx1
	local yy1
	local yy2
	local xTick
	local yTick
	local tSpan = gr.tMax - gr.tMin
	local yRange = gr.yMax - gr.yMin
	local width = gr.right - gr.left

	-- Find horizontal tick line distance
	mag = math.floor(math.log(yRange, 10))
	if mag < -2 then mag = -2 end -- Don't go crazy with the scale

	if yRange / 10^mag > 6 then
		yTick = 2 * 10^mag
	elseif yRange / 10^mag > 3 then
		yTick = 1 * 10^mag
	elseif yRange / 10^mag > 2.4 then
		yTick = 0.5 * 10^mag
	elseif yRange / 10^mag > 1.2 then
		yTick = 0.4 * 10^mag
	else
		yTick = 0.2 * 10^mag
	end
	
	-- Flags for number precision
	if yTick < 0.1 then
		flags = PREC2
		precFac = 100
	elseif yTick < 1 then
		flags = PREC1
		precFac = 10
	else
		flags = 0
		precFac = 1
	end

	-- Find linear transformation from Y to screen pixel
	if gr.yMin == 0 then
		gr.m = (14 - LCD_H) / yRange
		gr.b = LCD_H - 1 - gr.m * gr.yMin
	else
		gr.m = (18 - LCD_H) / yRange
		gr.b = LCD_H - 4 - gr.m * gr.yMin
	end

	gr.b2 = math.max(8, math.min(LCD_H - 1, gr.b))
	
	-- Draw horizontal grid lines
	for i = math.ceil(gr.yMin / yTick) * yTick, math.floor(gr.yMax / yTick) * yTick, yTick do
		yy1 = gr.m * i + gr.b
		if math.abs(i) > 1E-8 then
			lcd.drawLine(gr.left, yy1, gr.right, yy1, DOTTED, GREY(6))
			lcd.drawNumber(gr.right + 15, yy1 - 3, math.floor(precFac * i + 0.5), SMLSIZE + RIGHT + flags)
		end
	end
	
	-- Find vertical grid line distance
	if tSpan > 6000 then
		xTick = 600
	elseif tSpan > 3000 then
		xTick = 300
	elseif tSpan > 1200 then
		xTick = 120
	else
		xTick = 60
	end
	
	for i = 0, math.floor(gr.tMax / xTick) * xTick, xTick do
		xx1 = math.floor((i - gr.tMin) / tSpan * width + 0.5)
		
		if xx1 >= 0 and xx1 <= width then
			xx1 = xx1 + gr.left
			lcd.drawLine(xx1, LCD_H, xx1, 8, DOTTED, GREY(6))
		end
	end

	-- Plot the graph
	lcd.drawLine(gr.left, gr.m * gr.yValues[0] + gr.b, gr.left, gr.b2, SOLID, GREY(12))
	for i = 1, width do
		yy1 = gr.m * gr.yValues[i - 1] + gr.b
		yy2 = gr.m * gr.yValues[i] + gr.b
		
		lcd.drawLine(gr.left + i, yy2, gr.left + i, gr.b2, SOLID, GREY(12))
		lcd.drawLine(gr.left + i - 1, yy1, gr.left + i, yy2, SOLID, FORCE)
	end

	-- Draw line through zero
	lcd.drawLine(gr.left, gr.b, gr.right, gr.b, SOLID, FORCE)
	if gr.yMin < 0 then
		lcd.drawText(gr.right + 15, gr.b - 3, " 0", SMLSIZE + RIGHT)
	end
end  --  Plot()

return Plot