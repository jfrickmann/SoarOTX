-- JF Log Data Graph, loadable part for interactive plot 
-- Timestamp: 2019-07-09
-- Created by Jesper Frickmann
-- Telemetry script for plotting telemetry parameters recorded in the log file.
-- The graph design was inspired by Nigel Sheffield's script

local GREY
if LCD_W == 128 then
	GREY = 0
else
	GREY = GREY_DEFAULT
end

local function DrawGraph()
	local mag
	local flags
	local precFac
	
	local yRange
	local xx1
	local tMin
	local tMax
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
			lcd.drawLine(gr.x0, yy1, LCD_W, yy1, DOTTED, GREY)
			lcd.drawNumber(LCD_W, yy1 - 3, math.floor(precFac * i + 0.5), SMLSIZE + RIGHT + flags)
		end
	end
	
	-- Find vertical grid line distance
	if gr.tSpan > 6000 then
		xTick = 600
	elseif gr.tSpan > 3000 then
		xTick = 300
	elseif gr.tSpan > 1200 then
		xTick = 120
	else
		xTick = 60
	end
	
	-- Draw vertical grid lines
	if gr.tMin then
		tMin = gr.tMin
		tMax = gr.tMax
	else
		tMin = 0
		tMax = gr.tSpan
	end
	
	for i = 0, math.floor(tMax / xTick) * xTick, xTick do
		xx1 = math.floor((i - tMin) / gr.tSpan * gr.xWidth + 0.5)
		
		if xx1 >= 0 and xx1 <= gr.xWidth then
			xx1 = xx1 + gr.x0
			lcd.drawLine(xx1, LCD_H, xx1, 8, DOTTED, GREY)
		end
	end

	-- Plot the graph
	lcd.drawLine(gr.x0, m * gr.yValues[0] + b, gr.x0, b2, SOLID, GREY)
	for i = 1, gr.xWidth do
		yy1 = m * gr.yValues[i - 1] + b
		yy2 = m * gr.yValues[i] + b
		
		lcd.drawLine(gr.x0 + i, yy2, gr.x0 + i, b2, SOLID, GREY)
		lcd.drawLine(gr.x0 + i - 1, yy1, gr.x0 + i, yy2, SOLID, FORCE)
	end

	-- Draw line through zero
	lcd.drawLine(gr.x0, b, LCD_W, b, SOLID, FORCE)
	if gr.yScaleMin < 0 then
		lcd.drawText(LCD_W, b - 3, " 0", SMLSIZE + RIGHT)
	end
	
	-- Draw markers
	if gr.tMin then
		xx1 = gr.x0 + gr.lftMark
		lcd.drawLine(xx1, b2, xx1 , 8, SOLID, FORCE)
	
		xx1 = gr.x0 + gr.rgtMark
		lcd.drawLine(xx1, b2, xx1 , 8, SOLID, FORCE)
	end
end  --  DrawGraph()

local function run(event)
	local spacer = "\t"
	if LCD_W == 128 then spacer = " " end
	
	local title = " " .. string.sub(gr.flightTable[gr.flightIndex][2], 1, 8) .. spacer .. gr.logFileHeaders[gr.plotIndex]
	DrawMenu(title)
		
	if gr.viewMode == 1 then -- Normal graph view
		-- Change view mode
		if event == EVT_MENU_BREAK or event == EVT_SHIFT_BREAK then
			gr.viewMode = 2
			gr.x0 = 45
			gr.run = gr.read
		end
	elseif gr.viewMode == 2 then -- View stats
		-- Print statistics
		lcd.drawText(0, 11, "Dur", SMLSIZE)
		lcd.drawTimer(gr.x0 + 3, 10, gr.tSpan, RIGHT)

		lcd.drawText(0, 21, "Min", SMLSIZE)
		lcd.drawNumber(gr.x0, 20, 10 * gr.yMin, PREC1 + RIGHT)

		lcd.drawText(0, 31, "Max", SMLSIZE)
		lcd.drawNumber(gr.x0, 30, 10 * gr.yMax, PREC1 + RIGHT)		

		if gr.launchAlt > 0 then
			lcd.drawText(0, 41, "Lnch", SMLSIZE)
			lcd.drawNumber(gr.x0, 40, 10 * gr.launchAlt, PREC1 + RIGHT)
		end

		-- Change view mode
		if event == EVT_MENU_BREAK or event == EVT_SHIFT_BREAK then
			gr.viewMode = 3
			gr.tMin = 0
			gr.tMax = gr.tSpan
			gr.lftMark = math.floor(0.25 * gr.xWidth)
			gr.rgtMark = math.ceil(0.75 * gr.xWidth)
			gr.selectedMark = 0
		end
		
	else -- Select details and view slope
		local lftTime = gr.tMin + gr.lftMark * gr.tSpan / gr.xWidth
		local rgtTime = gr.tMin + gr.rgtMark * gr.tSpan / gr.xWidth
		local lftVal = gr.yValues[gr.lftMark]
		local rgtVal = gr.yValues[gr.rgtMark]
		local rate = (rgtVal - lftVal) / (rgtTime - lftTime)
		
		local att = 0
		local dx = 0

		if gr.selectedMark == 0 then att = INVERS end
		lcd.drawText(0, 11, "Lft", SMLSIZE + att)
		lcd.drawTimer(gr.x0 + 3, 10, lftTime, RIGHT)
		lcd.drawNumber(gr.x0, 20, 10 * lftVal, PREC1 + RIGHT)

		att = INVERS - att
		lcd.drawText(0, 31, "Rgt", SMLSIZE + att)
		lcd.drawTimer(gr.x0 + 3, 30, rgtTime, RIGHT)
		lcd.drawNumber(gr.x0, 40, 10 * rgtVal, PREC1 + RIGHT)
		
		lcd.drawText(0, 51, "Rate", SMLSIZE)
		lcd.drawNumber(gr.x0, 50, 100 * rate, PREC2 + RIGHT)

		-- Move markers
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT or event == EVT_RIGHT_BREAK then
			dx = 1
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT or event == EVT_LEFT_BREAK then
			dx = -1
		end
		
		if dx ~= 0 then
			if gr.selectedMark == 0 then
				gr.lftMark = math.min(gr.rgtMark - 1, math.max(0, gr.lftMark + dx))
			else
				gr.rgtMark = math.min(gr.xWidth, math.max(gr.lftMark + 1, gr.rgtMark + dx))
			end
		end

		-- Zoom in/out
		if event == EVT_EXIT_BREAK then
			if gr.tSpan < gr.tMax then
				gr.tMin = 0
				gr.tSpan = gr.tMax
				
				gr.lftMark = math.floor(lftTime / gr.tSpan * gr.xWidth + 0.5)
				gr.rgtMark = math.floor(rgtTime / gr.tSpan * gr.xWidth + 0.5)
				
				-- We cannot have left == right
				if gr.lftMark == gr.rgtMark then
					if gr.lftMark > 0 then
						gr.lftMark = gr.lftMark - 1
					else
						gr.rgtMark = gr.rgtMark + 1
					end
				end
			else
				gr.tMin = lftTime
				gr.tSpan = rgtTime - lftTime
				
				gr.lftMark = 0
				gr.rgtMark = gr.xWidth
			end
			
			gr.run = gr.read
		end
		
		-- Toggle selected marker
		if event == EVT_ENTER_BREAK then
			gr.selectedMark = 1 - gr.selectedMark
		end
		
		-- Change view mode
		if event == EVT_MENU_BREAK or event == EVT_SHIFT_BREAK then
			gr.viewMode = 1
			gr.x0 = 0
			gr.tMin = nil
			gr.run = gr.read
		end
	end
	
	DrawGraph()
		
	if gr.viewMode < 3 then
		-- Read next flight
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
	end
end  --  run()

return { run = run }