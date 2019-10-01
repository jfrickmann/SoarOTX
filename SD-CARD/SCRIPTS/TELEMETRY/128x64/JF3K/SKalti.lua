-- 128x64/JF3K/SKalti.lua
-- Timestamp: 2019-09-29
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts
local Plot = soarUtil.LoadWxH("PLOT.lua", sk.p) -- Screen size specific function
sk.p.heightInt = 7 -- Interval for recording heights
sk.p.left = 0
sk.p.right = sk.taskWindow / sk.p.heightInt + 1

-- Convert time to minutes and seconds
local function MinSec(t)
	local m = math.floor(t / 60)
	return m, t - 60 * m
end -- MinSec()

local function Draw()
	local att
	local xx1
	local xx2
	local yy1
	local yy2

	soarUtil.InfoBar(sk.taskName)
	
	-- Rescale if necessary
	sk.p.yMax = math.ceil(math.max(25, sk.p.maxHeight, sk.p.ceiling) / 25) * 25

	Plot()

	-- Draw lines to illustrate scores for recorded flights
	for i = 1, #sk.scores do
		xx1 = (sk.scores[i].start + 10) / sk.p.heightInt
		xx2 = (sk.scores[i].start + sk.scores[i].time) / sk.p.heightInt
		yy1 = sk.p.m * sk.scores[i].launch + sk.p.b

		if sk.task == sk.p.TASK_HEIGHT_GAIN or sk.task == sk.p.TASK_HEIGHT_POKER then
			-- Launch height
			lcd.drawLine(xx1, yy1, xx2, yy1, SOLID, FORCE)

			-- Max height
			xx1 = sk.scores[i].maxTime / sk.p.heightInt
			yy2 = sk.p.m * sk.scores[i].maxHeight + sk.p.b
			lcd.drawLine(xx1, yy1, xx1, yy2, SOLID, FORCE)			
		elseif sk.task == sk.p.TASK_THROW_LOW then
			-- Launch height
			yy2 = sk.p.m * 100 + sk.p.b
			lcd.drawLine(xx1, yy1, xx1, yy2, SOLID, FORCE)
			lcd.drawLine(xx1 - 2, yy1, xx1 + 2, yy1, SOLID, FORCE)
			lcd.drawLine(xx1 - 2, yy2, xx1 + 2, yy2, SOLID, FORCE)
		end
		
		-- Flight time
		if sk.task == sk.p.TASK_CEILING then
			xx1 = sk.scores[i].start / sk.p.heightInt
			yy2 = sk.p.m * sk.p.ceiling + sk.p.b
			lcd.drawLine(xx1, sk.p.b, xx1, yy2, SOLID, FORCE)
			lcd.drawLine(xx2, sk.p.b, xx2, yy2, SOLID, FORCE)
		end
	end

	-- Ceiling
	yy1 = sk.p.m * sk.p.ceiling + sk.p.b
	if sk.task == sk.p.TASK_CEILING then
		lcd.drawLine(sk.p.left, yy1, sk.p.right, yy1, SOLID, FORCE)
	end
		
	-- Draw lines to illustrate scores for current flight
	if sk.state >=sk.STATE_FLYING and sk.p.launchHeight > 0 then
		xx1 = sk.p.flightStart / sk.p.heightInt
		if model.getTimer(0).start == 0 then
			xx2 = sk.taskWindow / sk.p.heightInt
		else
			xx2 = (sk.p.flightStart + model.getTimer(0).start) / sk.p.heightInt
		end
		
		if sk.task == sk.p.TASK_CEILING then
			-- Flight time
			lcd.drawLine(xx1, sk.p.b, xx1, yy1, SOLID, FORCE)
			lcd.drawLine(xx2, sk.p.b, xx2, yy1, SOLID, FORCE)
		elseif sk.task == sk.p.TASK_HEIGHT_GAIN or sk.task == sk.p.TASK_HEIGHT_POKER then
			-- Ceiling
			lcd.drawLine(xx1, yy1, xx2, yy1, SOLID, FORCE)
			
			-- Launch height
			xx1 = (sk.p.flightStart + 10) / sk.p.heightInt
			yy1 = sk.p.m * sk.p.launchHeight + sk.p.b
			lcd.drawLine(xx1, yy1, xx2, yy1, SOLID, FORCE)
		else
			-- Launch height
			xx1 = (sk.p.flightStart + 10) / sk.p.heightInt
			yy1 = sk.p.m * sk.p.launchHeight + sk.p.b
			yy2 = sk.p.m * 100 + sk.p.b
			lcd.drawLine(xx1, yy1, xx1, yy2, SOLID, FORCE)
			lcd.drawLine(xx1 - 2, yy1, xx1 + 2, yy1, SOLID, FORCE)
			lcd.drawLine(xx1 - 2, yy2, xx1 + 2, yy2, SOLID, FORCE)
		end
	end

	-- In height poker, show call
	if sk.task == sk.p.TASK_HEIGHT_POKER and sk.state <= sk.STATE_WINDOW then
		local att = 0
		
		if sk.p.pokerCalled then att = att + BLINK + INVERS end
		lcd.drawText(2, 55, string.format("Call: %im", sk.p.targetGain), att)
	end

	-- Show ceiling
	if sk.task == sk.p.TASK_CEILING and sk.state == sk.STATE_IDLE then
		lcd.drawText(2, 55, string.format("Ceiling: %im", sk.p.ceiling))
	end

	-- Timers
	if sk.flightTimer < 0 then
		att = BLINK + INVERS
	else
		att = 0
	end
	
	lcd.drawTimer(LCD_W, 12, sk.flightTimer, MIDSIZE + RIGHT + att)

	if sk.state == sk.STATE_FINISHED then
		att = BLINK + INVERS
	else
		att = 0
	end
	
	lcd.drawTimer(LCD_W, 30, sk.winTimer,  MIDSIZE + RIGHT + att)

	-- QR and EoW
	if sk.eowTimerStop then
		lcd.drawText(LCD_W - 18, 48, "EoW", SMLSIZE + INVERS)
	end
	
	if sk.quickRelaunch then
		lcd.drawText(LCD_W - 33, 48, "QR", SMLSIZE + INVERS)
	end

	if sk.p.launchHeight > 0 then
		lcd.drawText(73, 58, string.format("Launch %i m", sk.p.launchHeight), SMLSIZE)
	end
	
	-- Scores
	for i = 1, sk.taskScores do
		local dy = 14
		
		if i > #sk.scores then
			lcd.drawText(73, dy * i, "- - -", SMLSIZE)
		elseif sk.p.unit == "s" then
			lcd.drawText(73, dy * i, string.format("%02i:%02i", MinSec(sk.scores[i].time)), SMLSIZE)
		else
			lcd.drawText(73, dy * i, string.format("%4i%s", sk.scores[i].gain, sk.p.unit), SMLSIZE)
		end
	end
end  --  Draw()

local function PromptScores()
	soarUtil.InfoBar(sk.taskName)
	lcd.drawText(8, 15, "Save scores?", MIDSIZE)
	lcd.drawText(8, 35, "ENTER = SAVE")
	lcd.drawText(8, 45, "EXIT = DON'T")
end -- PromptScores()

local function NotifyStopWindow()
	soarUtil.InfoBar(sk.taskName)
	lcd.drawText(8, 15, "Stop window", MIDSIZE)
	lcd.drawText(8, 30, "timer before", MIDSIZE)
	lcd.drawText(8, 45, "leaving task.", MIDSIZE)
end -- NotifyStopWindow()

local function NotifyStopFlight()
	soarUtil.InfoBar(sk.taskName)
	lcd.drawText(8, 15, "Stop the flight", MIDSIZE)
	lcd.drawText(8, 30, "timer before", MIDSIZE)
	lcd.drawText(8, 45, "pausing window.", MIDSIZE)
end -- NotifyStopFlight()

return Draw, PromptScores, NotifyStopWindow, NotifyStopFlight