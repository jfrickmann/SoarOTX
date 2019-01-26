-- JF Log Data Graph, loadable part for interactive plot 
-- Timestamp: 2018-12-29
-- Created by Jesper Frickmann
-- Telemetry script for plotting telemetry parameters recorded in the log file.
-- The graph design was inspired by Nigel Sheffield's script

local function DrawGraph()
	local x0
	local mag
	local flags
	local precFac
	
	local yRange
	local yy1
	local yy2
	local xTick
	local yTick
	local m
	local b
	local b2

	-- Sometimes, a min. scale of zero looks better...
	if gr.yScaleMin < 0 then
		if -gr.yScaleMin < 0.08 * gr.yScaleMax then
			gr.yScaleMin = 0
		end
	else
		if gr.yScaleMin < 0.5 *  gr.yScaleMax then
			gr.yScaleMin = 0
		end
	end
	
	yRange = gr.yScaleMax - gr.yScaleMin

	if yRange <= 1E-8 then
		gr.yScaleMin = gr.yScaleMin - 0.04
		gr.yScaleMax = gr.yScaleMax + 0.04
		yRange = gr.yScaleMax - gr.yScaleMin
	end
	
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
	if gr.yScaleMin == 0 then
		m = (14 - LCD_H) / yRange
		b = LCD_H - 1 - m * gr.yScaleMin
	else
		m = (18 - LCD_H) / yRange
		b = LCD_H - 4 - m * gr.yScaleMin
	end

	b2 = math.max(8, math.min(LCD_H - 1, b))
	
	-- Draw horizontal grid lines
	for i = math.ceil(gr.yScaleMin / yTick) * yTick, math.floor(gr.yScaleMax / yTick) * yTick, yTick do
		yy1 = m * i + b
		if math.abs(i) > 1E-8 then
			lcd.drawLine(0, yy1, LCD_W, yy1, DOTTED, GRAY)
			lcd.drawNumber(LCD_W, yy1 - 3, math.floor(precFac * i + 0.5), SMLSIZE + RIGHT + flags)
		end
	end
	
	-- Find vertical grid line distance
	if gr.xScaleMax > 6000 then
		xTick = 600
	elseif gr.xScaleMax > 3000 then
		xTick = 300
	elseif gr.xScaleMax > 1200 then
		xTick = 120
	else
		xTick = 60
	end
	
	-- Draw vertical grid lines
	for i = xTick, math.floor(gr.xScaleMax / xTick) * xTick, xTick do
		xx1 = (LCD_W - 21) * i / gr.xScaleMax
		lcd.drawLine(xx1, LCD_H, xx1, 8, DOTTED, GRAY)
	end

	-- Plot the graph
	lcd.drawLine(0, m * gr.yValues[1] + b, 0, b2, SOLID, GRAY)
	for i = 1, #gr.yValues - 1 do
		x0 = gr.timeSerialStart + i * gr.xScaleMax / (LCD_W - 22)
		if x0 <= gr.timeSerialEnd then
			yy1 = m * gr.yValues[i] + b
			yy2 = m * gr.yValues[i + 1] + b
			
			lcd.drawLine(i, yy2, i, b2, SOLID, GRAY)
			lcd.drawLine(i - 1, yy1, i, yy2, SOLID, FORCE)
		end
	end

	-- Draw line through zero
	lcd.drawLine(0, b, LCD_W, b, SOLID, FORCE)
	if gr.yScaleMin < 0 then
		lcd.drawText(LCD_W, b - 3, " 0", SMLSIZE + RIGHT)
	end
end  --  DrawGraph()

local function run(event)
	local spacer = "\t"
	if tx ~= TX_X9D then spacer = " " end
	
	local title = " " .. string.sub(gr.flightTable[gr.flightIndex][2], 1, 8) .. spacer .. gr.logFileHeaders[gr.plotIndex]
	DrawMenu(title)

	-- Plus button was pressed; read next flight
	if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_RIGHT_BREAK then
		gr.flightIndex = gr.flightIndex + 1
		if gr.flightIndex > #gr.flightTable then
			gr.flightIndex = 1
		end
		gr.run = gr.read
	end

	-- Minus button was pressed; read previous flight
	if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_LEFT_BREAK then
		gr.flightIndex = gr.flightIndex - 1
		if gr.flightIndex < 1 then
			gr.flightIndex = #gr.flightTable
		end
		gr.run = gr.read
	end

	-- Enter button was pressed; change plot variable
	if event == EVT_ENTER_BREAK then
		gr.plotIndex = gr.plotIndex + 1
		if gr.plotIndex > gr.plotIndexLast then
			gr.plotIndex = 3
		end
		gr.run = gr.read
	end
	
	-- Menu button was  pressed; toggle viewStats
	if event == EVT_MENU_BREAK or event == EVT_SHIFT_BREAK then
		gr.viewStats = not gr.viewStats
	end
	
	if gr.viewStats then
		-- Print statistics
		lcd.drawText(10, 16, "Duration")
		lcd.drawTimer(88, 16, gr.xScaleMax, RIGHT)

		lcd.drawText(10, 26, "Minimum")
		lcd.drawNumber(85, 26, 100 * gr.yMin, PREC2 + RIGHT)

		lcd.drawText(10, 36, "Maximum")
		lcd.drawNumber(85, 36, 100 * gr.yMax, PREC2 + RIGHT)
		
		if gr.launchAlt > 0 then
			lcd.drawText(10, 46, "Launch")
			lcd.drawNumber(85, 46, 100 * gr.launchAlt, PREC2 + RIGHT)
		end
	else
		-- Draw graph
		return DrawGraph()
	end
end  --  run()

return { run = run }