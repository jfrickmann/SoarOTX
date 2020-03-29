-- 128x64/PLOT.lua
-- Timestamp: 2019-10-09
-- Created by Jesper Frickmann
-- Shared script for plotting data
-- Design inspired by Nigel Sheffield's script

local plot = ...
--	plot.tMin, plot.tMax
--	plot.yMin, plot.yMax
--	plot.left, plot.right
--	plot.yValues

local m, b, dx

local function X(t)
	return math.floor(plot.left + dx * t + 0.5)
end -- X()

local function Y(y)
	if not y then y = 0 end -- Handle Nil value
	return math.ceil(b + m * y - 0.5)
end -- Y()

function plot.DrawLine(t1, y1, t2, y2, ...)
	local dot, force = ...
	if not dot then dot = SOLID end
	if not force then force = FORCE end
	lcd.drawLine(X(t1), Y(y1), X(t2), Y(y2), dot, force)
end -- plot.drawLine()

local function Plot()
	local mag
	local flags
	local precFac
	local x1
	local y1
	local y2
	local tTick
	local yTick
	local tSpan = plot.tMax - plot.tMin
	local yRange = plot.yMax - plot.yMin

	dx = (plot.right - plot.left) / tSpan

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
	if plot.yMin == 0 then
		m = (14 - LCD_H) / yRange
		b = LCD_H - 1 - m * plot.yMin
	else
		m = (18 - LCD_H) / yRange
		b = LCD_H - 4 - m * plot.yMin
	end

	plot.b2 = math.max(8, math.min(LCD_H - 1, b))
	
	-- Draw horizontal grid lines
	for y = math.ceil(plot.yMin / yTick) * yTick, math.floor(plot.yMax / yTick) * yTick, yTick do
		y1 = Y(y)
		if math.abs(y) > 1E-8 then
			lcd.drawLine(plot.left, y1, plot.right, y1, DOTTED, FORCE)
			lcd.drawNumber(plot.right + 10, y1 - 3, math.floor(precFac * y + 0.5), SMLSIZE + RIGHT + flags)
		end
	end
	
	-- Find vertical grid line distance
	if tSpan > 6000 then
		tTick = 600
	elseif tSpan > 3000 then
		tTick = 300
	elseif tSpan > 1200 then
		tTick = 120
	else
		tTick = 60
	end
	
	for t = math.ceil(plot.tMin / tTick) * tTick, math.floor(plot.tMax / tTick) * tTick, tTick do
		x1 = X(t)
		lcd.drawLine(x1, LCD_H, x1, 8, DOTTED, FORCE)
	end

	-- Plot the graph
	y2 = Y(plot.yValues[0])
	for i = 1, math.min(plot.right - plot.left, #plot.yValues) do
		y1 = y2
		y2 = Y(plot.yValues[i])
		lcd.drawLine(plot.left + i - 1, y1, plot.left + i, y2, SOLID, FORCE)
	end

	-- Draw line through zero
	lcd.drawLine(plot.left, b, plot.right, b, SOLID, FORCE)
	if plot.yMin < 0 then
		lcd.drawText(plot.right + 10, b - 3, " 0", SMLSIZE + RIGHT)
	end
end  --  Plot()

return Plot