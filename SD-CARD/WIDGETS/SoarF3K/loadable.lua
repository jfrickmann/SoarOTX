---------------------------------------------------------------------------
-- SoarETX F3K score keeper widget, loadable part                        --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2021-09-24                                                   --
-- Version: 0.9                                                          --
--                                                                       --
-- Copyright (C) Jesper Frickmann                                        --
--                                                                       --
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               --
--                                                                       --
-- This program is free software; you can redistribute it and/or modify  --
-- it under the terms of the GNU General Public License version 2 as     --
-- published by the Free Software Foundation.                            --
--                                                                       --
-- This program is distributed in the hope that it will be useful        --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of        --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------

local zone, options = ...     -- zone and options were passed as arguments to chunk(...).
local widget = { }            -- The widget table will be returned to the main script.
local libGUI = loadGUI()      -- GUI library
libGUI.flags = MIDSIZE        -- Default drawing flags
local colors = libGUI.colors  -- Short cut

-- GUIs for the different screens and popups
local menuMain = libGUI.newGUI()
local menuF3K = libGUI.newGUI()
local menuPractice = libGUI.newGUI()
local menuScores = libGUI.newGUI()
local screenTask = libGUI.newGUI()
local promptSaveScores = libGUI.newGUI()

-- Screen drawing constants
local HEADER =   40
local LEFT =     25
local RGT =      LCD_W - 15
local TOP =      60
local LINE =     50
local LINE2 =    22 
local HEIGHT =   38
local HEIGHT2 =  18
local BUTTON_W = 90
local PROMPT_W = 260
local PROMPT_H = 170
local PROMPT_M = 30

local trimSources = {         -- Input sources for the trim buttons
  getFieldInfo("trim-ail").id,
  getFieldInfo("trim-rud").id,
  getFieldInfo("trim-ele").id,
  getFieldInfo("trim-thr").id
}
local rxBatSrc                -- Receiver battery source

-- Constants
local LS_ALT = getFieldInfo("ls1").id   -- Input ID for allowing altitude calls
local LS_ALT10 = getFieldInfo("ls6").id -- Input ID for altitude calls every 10 sec.
local FM_ADJUST = 1                     -- Adjustment flight mode
local FM_LAUNCH = 2                     -- Launch/motor flight mode
local GV_BAT = 6                        -- GV used for battery warning in FM_ADJUST
local ALT_UNIT = 9                      -- Altitude units (m)
local COLOR_NOTIFY_TEXT = lcd.RGB(255, 255, 127)
local COLOR_NOTIFY_BG =   lcd.RGB(0, 0, 128)

-- Program states
local STATE_IDLE = 1      -- Task window not running
local STATE_PAUSE = 2     -- Task window paused, not flying
local STATE_FINISHED = 3  -- Task has been finished
local STATE_WINDOW = 4    -- Task window started, not flying
local STATE_READY = 5     -- Flight timer will be started when launch switch is released
local STATE_FLYING = 6    -- Flight timer started but flight not yet committed
local STATE_COMMITTED = 7 -- Flight timer started, and flight committed
local STATE_FREEZE = 8    -- Still committed, but freeze  the flight timer
local state               -- Current program state

-- Common variables for score keeping
local scores = { }              -- List of saved scores
local taskWindow = 0            -- Task window duration (zero counts up)
local launches = -1             -- Number of launches allowed, -1 for unlimited
local taskScores = 0            -- Number of scores in task 
local finalScores = false       -- Task scores are final
local targetType = 0            -- 1. Huge ladder, 2. Poker, 3. "1234", 4. Big ladder, Else: constant time
local scoreType                 -- 1. Best, 2. Last, 3. Make time
local totalScore                -- Total score
local prevFM = getFlightMode()  -- Used for detecting when FM changes
local prevWt                    -- Previous value of the window timer
local prevFt                    -- Previous value of flight timer

-- Other common variables
local counts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45} -- Flight timer countdown
local countIndex            -- Index of timer count
local nextCall = 0          -- Call out altitude every 10 sec.
local winTimer = 0          -- Window timer
local flightTimer           -- Flight timer
local flightTime            -- Flight flown

-- Variables used for Poker task
local pokerCalled     -- Lock in time in Poker task
local lastInput = 0   -- For announcing changes in PokerCall
local lastChange = 0  -- Same
local tblStep = { {30, 5}, {60, 10}, {120, 15}, {210, 30}, {420, 60}, {taskWindow + 60} } -- Step sizes for input of call time

-- Set GV for controlling timers
local function SetGVTmr(tmr)
	model.setGlobalVariable(8, 0, tmr)
end

-- Handle transitions between program states
local function GotoState(newState)
  state = newState
 
  -- Stop blinking
    screenTask.timer0.blink = false

    if state < STATE_WINDOW or state == STATE_FREEZE then
		-- Stop both timers
		SetGVTmr(0)
    screenTask.labelTimer0.title = "Target:"
    screenTask.locked = false

  elseif state == STATE_WINDOW then
		-- Start task window timer, but not flight timer
		SetGVTmr(1)
    screenTask.labelTimer0.title = "Target:"
    screenTask.locked = true
	
  elseif state == STATE_FLYING then
		-- Start both timers
		SetGVTmr(2)
    screenTask.labelTimer0.title = "Flight:"
    screenTask.locked = true
    
    if model.getTimer(0).start > 0 then
      -- Report the target time
      playDuration(model.getTimer(0).start, 0)
    else
      -- ... or beep
      playTone(1760, 100, PLAY_NOW)
    end
  
  elseif state == STATE_COMMITTED then
    -- Call launch height
    if getValue(LS_ALT) > 0 then
      playNumber(getValue("Alt+"), ALT_UNIT)
    end
    
    if launches > 0 then 
      launches = launches - 1
    end
  
    lastChange = 0
 
 elseif state == STATE_FINISHED then
    playTone(880, 1000, 0)
  end
  
  -- Configure "button3"
  screenTask.button3.disabled = false
  if state <= STATE_PAUSE then
    screenTask.button3.title = "Start"    
  elseif state == STATE_WINDOW then
    screenTask.button3.title = "Pause"
  elseif state >= STATE_COMMITTED then
    screenTask.button3.title = "Zero"
  else
    screenTask.button3.disabled = true  
  end
  
  -- Configure info text label
	if state == STATE_PAUSE then
    screenTask.labelInfo.title = string.format("Total: %i sec.", totalScore)
	elseif state == STATE_FINISHED then
    screenTask.labelInfo.title = string.format("Done! %i sec.", totalScore)
	else
		if launches >= 0 then
			local s = ""
			if launches ~= 1 then s = "es" end
      screenTask.labelInfo.title = string.format("%i launch%s left", launches, s)
    else
      screenTask.labelInfo.title = ""
		end
	end
end -- GotoState()

-- Function for setting up a task
local function SetupTask(taskName, taskData)
  screenTask.title = taskName
  
  taskWindow = taskData[1]
  launches = taskData[2]
  taskScores = taskData[3]
  finalScores = taskData[4]
  targetType = taskData[5]
  scoreType = taskData[6]
  screenTask.buttonQR.value = taskData[7]  
  scores = { }
  totalScore = 0
  pokerCalled = false
  
  -- Setup scores
  for i = 1, 8 do
    if i > taskScores then
      screenTask.scoreLabels[i].hidden = true
      screenTask.scores[i].hidden = true
    else
      screenTask.scoreLabels[i].hidden = false
      screenTask.scores[i].hidden = false
    end
  end
  
  -- A few extra counts in 1234
  if targetType == 3 then
		counts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45, 65, 70, 75, 125, 130, 135, 185, 190, 195}
  else
    counts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45}
  end

  GotoState(STATE_IDLE)
end -- SetupTask(...)

-- Keep the best scores
local function RecordBest(scores, newScore)
  local n = #scores
  local i = 1
  local j = 0

  -- Find the position where the new score is going to be inserted
  if n == 0 then
    j = 1
  else
    -- Find the first position where existing score is smaller than the new score
    while i <= n and j == 0 do
      if newScore > scores[i] then j = i end
      i = i + 1
    end
    
    if j == 0 then j = i end -- New score is smallest; end of the list
  end

  -- If the list is not yet full; let it grow
  if n < taskScores then n = n + 1 end

  -- Insert the new score and move the following scores down the list
  for i = j, n do
    newScore, scores[i] = scores[i], newScore
  end
end  --  RecordBest (...)

-- Used for calculating the total score and sometimes target time
local function MaxScore(iFlight)
  if targetType == 1 then -- Huge ladder
    return 60 + 120 * iFlight
  elseif targetType == 2 then -- Poker
    return 9999
  elseif targetType == 3 then -- 1234
    return 300 - 60 * iFlight
  elseif targetType == 4 then -- Big ladder
    return 30 + 30 * iFlight
  else -- MaxScore = targetType
    return targetType
  end
end

-- Record scores
local function Score()
	if scoreType == 1 then -- Best scores
    RecordBest(scores, flightTime)

  elseif scoreType == 2 then -- Last scores
    local n = #scores
    if n >= taskScores then
      -- List is full; move other scores one up to make room for the latest at the end
      for j = 1, n - 1 do
        scores[j] = scores[j + 1]
      end
    else
      -- List can grow; add to the end of the list
      n = n + 1
    end
    scores[n] = flightTime

  else -- Must make time to get score
    local score = flightTime
    -- Did we make time?
    if flightTimer > 0 then
      return
    else
      -- In Poker, only score the call
      if pokerCalled then
        score = model.getTimer(0).start
        pokerCalled = false
      end
    end
    scores[#scores + 1] = score

	end

  totalScore = 0  
  for i = 1, #scores do
    totalScore = totalScore + math.min(MaxScore(i), scores[i])
  end
end -- Score()

-- Reset altimeter
local function ResetAlt()
  for i = 0, 31 do
    if model.getSensor(i).name == "Alt" then 
      model.resetSensor(i)
      break
    end
  end
end

-- Find the best target time, given what has already been scored, as well as the remaining time of the window.
-- Note: maxTarget ensures that recursive calls to this function only test shorter target times. That way, we start with
-- the longest flight and work down the list. And we do not waste time testing the same target times in different orders.
local function Best1234Target(timeLeft, scores, maxTarget)
  local bestTotal = 0
  local bestTarget = 0

  -- Max. minutes there is time left to fly
  local maxMinutes = math.min(maxTarget, 4, math.ceil(timeLeft / 60))

  -- Iterate from 1 to n minutes to find the best target time
  for i = 1, maxMinutes do
    local target
    local tl
    local tot
    local dummy

    -- Target in seconds
    target = 60 * i

    -- Copy scores to a new table
    local s = {}
    for j = 1, #scores do
      s[j] = scores[j]
    end

    -- Add new target time to s; only until the end of the window
    RecordBest(s, math.min(timeLeft, target))
    tl = timeLeft - target

    -- Add up total score, assuming that the new target time was made
    if tl <= 0 or i == 1 then
      -- No more flights are made; sum it all up
      tot = 0
      for j = 1, math.min(4, #s) do
        tot = tot + math.min(300 - 60 * j, s[j])
      end
    else
      -- More flights can be made; add more flights recursively
      -- Subtract one second from tl for turnaround time
      dummy, tot = Best1234Target(tl - 1, s, i - 1)
    end

    -- Do we have a new winner?
    if tot > bestTotal then
      bestTotal = tot
      bestTarget = target
    end
  end

  return bestTarget, bestTotal
end  --  Best1234Target(..)

-- Get called time from user in Poker
local function PokerCall()
  local dial
  
  -- Find dials for setting target time in Poker and height ceilings etc.
  for input = 0, 31 do
    local tbl = model.getInput(input, 0)
    
    if tbl and tbl.name == "Dial" then
      dial = tbl.source
    end
  end

  -- If input lines were not found, then default to S1 and S2
  if not dial then dial = getFieldInfo("s1").id end

  local input = getValue(dial)
  local i, x = math.modf(1 + (#tblStep - 1) * (math.min(1023, input) + 1024) / 2048)
  local t1 = tblStep[i][1]
  local t2 = tblStep[i + 1][1]
  local dt = tblStep[i][2]
  
  local result = t1 + dt * math.floor(x * (t2 - t1) /dt)
  
  if scoreType == 3 then
    result = math.min(winTimer - 1, result)
  end
  
  if math.abs(input - lastInput) >= 20 then
    lastInput = input
    lastChange = getTime()
  end
  
  if state == STATE_COMMITTED and lastChange > 0 and getTime() - lastChange > 100 then
    playTone(3000, 100, PLAY_NOW)
    playDuration(result)
    lastChange = 0
  end
  
  return result
end -- PokerCall()

local function TargetTime()
	if targetType == 2 then -- Poker
    if pokerCalled then
      return model.getTimer(0).start
    else
      return PokerCall()
    end
	elseif targetType == 3 then -- 1234
    return Best1234Target(winTimer, scores, 4)
	else -- All other tasks
    return MaxScore(#scores + 1)
	end
end -- TargetTime()
	
-- Initialize variables before flight
local function InitializeFlight()
	local targetTime = TargetTime()
	
	-- Get ready to count down
	countIndex = #counts
	while countIndex > 1 and counts[countIndex] >= targetTime do
		countIndex = countIndex - 1
	end

	-- Set flight timer
	model.setTimer(0, { start = targetTime, value = targetTime })
	flightTimer = targetTime
	prevFt = targetTime
end  --  InitializeFlight()

function widget.background()
	local flightMode = getFlightMode()
	local launchPulled = (flightMode == FM_LAUNCH and prevFM ~= flightMode)
	local launchReleased = (flightMode ~= prevFM and prevFM == FM_LAUNCH)
	prevFM = flightMode

  -- Reset altitude
	if launchPulled then
		ResetAlt()
	end
	
  -- Call altitude every 10 sec.
	if getValue(LS_ALT10) > 0 and getTime() > nextCall then
		playNumber(getValue("Alt"), ALT_UNIT)
		nextCall = getTime() + 1000
	end

	-- Write the current flight mode to a telemetry sensor.
	setTelemetryValue(0x5050, 0, 224, getFlightMode(), 0, 0, "FM")
	
	if state <= STATE_READY and state ~= STATE_FINISHED then
		InitializeFlight()
	end
	
	flightTimer = model.getTimer(0).value
	flightTime = math.abs(model.getTimer(0).start - flightTimer)
	winTimer = model.getTimer(1).value
	
	if state < STATE_WINDOW then
		if state == STATE_IDLE then
			-- Set window timer
			model.setTimer(1, { start = taskWindow, value = taskWindow })
			winTimer = taskWindow
			prevWt = taskWindow

			-- Automatically start window and flight if launch switch is released
			if launchPulled then
				GotoState(STATE_READY)
			end
		end

	else
		-- Did the window expire?
		if prevWt > 0 and winTimer <= 0 then
			playTone(880, 1000, 0)

			if state < STATE_FLYING then
				GotoState(STATE_FINISHED)
			elseif screenTask.buttonEoW.value then
				GotoState(STATE_FREEZE)
			end
		end

		if state == STATE_WINDOW then
			if launchPulled then
				GotoState(STATE_READY)
			elseif launchReleased then
				-- Play tone to warn that timer is NOT running
				playTone(1760, 200, 0, PLAY_NOW)
			end
			
		elseif state == STATE_READY then
			if launchReleased then
				GotoState(STATE_FLYING)
			end

		elseif state >= STATE_FLYING then
			-- Time counts
			if flightTimer <= counts[countIndex] and prevFt > counts[countIndex]  then
				if flightTimer > 15 then
					playDuration(flightTimer, 0)
				else
					playNumber(flightTimer, 0)
				end
				if countIndex > 1 then countIndex = countIndex - 1 end
			elseif flightTimer > 0 and math.ceil(flightTimer / 60) < math.ceil(prevFt / 60) then
				playDuration(flightTimer, 0)
			end
			
      -- Blink when flight ttimer is negative
      if flightTimer < 0 then
        screenTask.timer0.blink = true
      end
      
			if state == STATE_FLYING then
				-- Within 10 sec. "grace period", cancel the flight
				if launchPulled then
					GotoState(STATE_WINDOW)
				end

				-- After 10 seconds, commit flight
				if flightTime >= 10 then
					GotoState(STATE_COMMITTED)
				end
				
			elseif launchPulled then
				-- Report the time after flight is done
				if model.getTimer(0).start == 0 then
					playDuration(flightTime, 0)
				end

				Score()
				
				-- Change state
				if (finalScores and #scores == taskScores) or launches == 0 or (taskWindow > 0 and winTimer <= 0) then
					GotoState(STATE_FINISHED)
				elseif screenTask.buttonQR.value then
					GotoState(STATE_READY)
				else
					GotoState(STATE_WINDOW)
				end
			end
		end
		
		prevWt = winTimer
		prevFt = flightTimer
	end

  -- Update info for user dial targets
	if state == STATE_COMMITTED and targetType == 2 and (scoreType ~= 3 or taskScores - #scores > 1) then
    local call = PokerCall()
    local min = math.floor(call / 60)
    local sec = call - 60 * min
    screenTask.labelInfo.title = string.format("Next call: %02i:%02i", min, sec)
  end

  -- "Must make time" tasks
	if scoreType == 3 then
    if state == STATE_COMMITTED then
      pokerCalled = true
    elseif state < STATE_FLYING and state ~= STATE_FINISHED and winTimer < TargetTime() then
      GotoState(STATE_FINISHED)
    end
	end
end -- background()

function widget.update(opt)
  options = opt
end

-- Push new GUI as sub screen
local function PushGUI(gui)
  gui.parent = widget.gui
  widget.gui = gui
end

-- Are we allowed to pop screen?
local function CanPopGUI()
  return widget.gui.parent and not widget.gui.editing and not widget.gui.locked
end

-- Pop GUI to return to previous screen
local function PopGUI()
  if CanPopGUI() then
    widget.gui = widget.gui.parent
    return true
  end
end

-- Draw zone area when not in fullscreen mode
local function drawZone()
  lcd.drawFilledRectangle(0, 0, zone.w, zone.h, options.BgColor, options.BgOpacity)
  
  -- Draw timers
  local blink = 0
  local x = 5
  local tmr = model.getTimer(0).value
  if tmr < 0 then 
    blink = BLINK
  end

  lcd.drawText(x, 0, screenTask.labelTimer0.title, libGUI.colors.text)
  lcd.drawTimer(x, 18, tmr, libGUI.colors.text + DBLSIZE + blink)
  
  tmr = model.getTimer(1).value
  x = zone.w / 2 + 5

  lcd.drawText(x, 0, "Window:", libGUI.colors.text)
  lcd.drawTimer(x, 18, tmr, libGUI.colors.text + DBLSIZE + blink)
  
  -- Draw scores
  x = 5
  local y = 55
  local dy = (zone.h - y - select(2, lcd.sizeText("X", MIDSIZE))) / 3
  for i = 1, taskScores do
    lcd.drawText(x, y, string.format("%i.", i), libGUI.colors.text + MIDSIZE)
    if i > #scores then
      lcd.drawText(x + 20, y, " -  -  -", libGUI.colors.text + MIDSIZE)
    else
      lcd.drawTimer(x + 20, y, scores[i], libGUI.colors.text + MIDSIZE)
    end
    
    if i == 4 then
      x = zone.w / 2 + 5
      y = 55
    else
      y = y + dy
    end
  end
end -- drawZone()


-- Setup screen with title, trims, flight mode etc.
local function SetupScreen(gui, title)
  gui.widgetRefresh = drawZone
  gui.title = title
  
  function gui.fullScreenRefresh()
    local color
    local bat

    -- Bleed out background to make all of the screen readable
    lcd.drawFilledRectangle(0, HEADER, LCD_W, LCD_H - HEADER, options.BgColor, options.BgOpacity)

    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(10, 3, gui.title, bit32.bor(DBLSIZE, colors.focusText))

    -- Date
    local now = getDateTime()
    local str = string.format("%02i:%02i", now.hour, now.min)
    lcd.drawText(LCD_W - 90, 3, str, RIGHT + BOLD + colors.focusText)    

    -- Receiver battery
    if not rxBatSrc then rxBatSrc = getFieldInfo("Cels") end
		if not rxBatSrc then rxBatSrc = getFieldInfo("RxBt") end
		if not rxBatSrc then rxBatSrc = getFieldInfo("A1") end
		if not rxBatSrc then rxBatSrc = getFieldInfo("A2") end
		
    if rxBatSrc then
      bat = getValue(rxBatSrc.id)
      
      if type(bat) == "table" then
        for i = 2, #bat do
          bat[1] = math.min(bat[1], bat[i])
        end
        bat = bat[1]
      end
    end

    if bat then
      color = colors.focusText
    else
      color = COLOR_THEME_DISABLED
      bat = 0
    end
    
    str = string.format("%1.1fV", bat)
    lcd.drawText(LCD_W - 90, 21, str, RIGHT + BOLD + color)
    
    -- Draw trims
    -- Drawing parameters
    local p = {
    --{ x, y, h, w }
      { LCD_W - 191, LCD_H - 13, 177, 8 },
      { 14, LCD_H - 13, 177, 8 },
      { LCD_W - 13, 68, 8, 177 },
      { 6, 68, 8, 177 },
    }
    
    for i = 1, 4 do
      local q = p[i]
      local value = getValue(trimSources[i]) / 10.24
      local x, y
      if q[3] > q[4] then
        x = q[1] + q[3] * (value + 100) / 200
        y = q[2] + q[4] / 2
      else
        x = q[1] + q[3] / 2
        y = q[2] + q[4] * (100 - value) / 200
      end
      
      lcd.drawFilledRectangle(q[1], q[2], q[3], q[4], COLOR_THEME_SECONDARY1)
      lcd.drawFilledRectangle(x - 7, y - 7, 15, 15, COLOR_THEME_PRIMARY1)
      lcd.drawFilledRectangle(x - 8, y - 8, 15, 15, colors.buttonBackground)
      lcd.drawNumber(x, y, value, SMLSIZE + VCENTER + CENTER + colors.focusText)
    end
    
    -- Flight mode
    lcd.drawText(LCD_W / 2, LCD_H - 22, select(2, getFlightMode()), CENTER + COLOR_THEME_SECONDARY1)    
  end -- fullScreenRefresh()
  
  -- Return button
  gui.buttonRet = gui.button(LCD_W - 74, 6, 28, 28, "", PopGUI)

  -- Paint another face on it
  local drawRet = gui.buttonRet.draw
  function gui.buttonRet.draw(idx)
    local color
    drawRet(idx)

    if CanPopGUI() then
      color = colors.focusText
      gui.buttonRet.disabled = nil
    else
      color = COLOR_THEME_DISABLED
      gui.buttonRet.disabled = true
    end
    
    lcd.drawFilledRectangle(LCD_W - 74, 6, 28, 28, COLOR_THEME_SECONDARY1)
    lcd.drawRectangle(LCD_W - 74, 6, 28, 28, color)
    for i = -1, 1 do
      lcd.drawLine(LCD_W - 60 + i, 12, LCD_W - 60 + i, 30, SOLID, color)
    end
    for i = 0, 3 do
      lcd.drawLine(LCD_W - 60 , 10 + i, LCD_W - 50 - i, 20, SOLID, color)
      lcd.drawLine(LCD_W - 60 , 10 + i, LCD_W - 70 + i, 20, SOLID, color)
    end
  end

  -- Minimize button
  local buttonMin = gui.button(LCD_W - 34, 6, 28, 28, "", function() lcd.exitFullScreen() end)

  -- Paint another face on it
  local drawMin = buttonMin.draw
  function buttonMin.draw(idx)
    drawMin(idx)
    
    lcd.drawFilledRectangle(LCD_W - 34, 6, 28, 28, COLOR_THEME_SECONDARY1)
    lcd.drawRectangle(LCD_W - 34, 6, 28, 28, colors.focusText)
    for y = 19, 21 do
      lcd.drawLine(LCD_W - 30, y, LCD_W - 10, y, SOLID, colors.focusText)
    end
  end
  
  -- Short press EXIT to return to previous screen
  local function HandleEXIT(event, touchState)
    if PopGUI() then
      return false
    else
      return event
    end
  end
  gui.SetEventHandler(EVT_VIRTUAL_EXIT, HandleEXIT)
  
  return gui
end -- NewScreen

-- Setup main menu
do
  SetupScreen(menuMain, "SoarETX  F3K")

  local items = {
    "1. F3K tasks",
    "2. Practice tasks",
    "3. View saved scores"
  }
  
  local subMenus = {
    menuF3K,
    menuPractice,
    menuScores
  }
  
  -- Call back function running when a menu item was selected
  local function callBack(item, event, touchState)
    PushGUI(subMenus[item.idx])
  end

  menuMain.menu(LEFT, TOP, 5, items, callBack)
  widget.gui = menuMain
end


do -- Setup F3K tasks menu
  SetupScreen(menuF3K, "Select  F3K  Task")

	local tasks = {
		"A. Last flight",
		"B. Two last flights 3:00",
		"B. Two last flights 4:00",
		"C. All up last down",
		"D. Two flights only",
		"E. Poker 10 min.",
		"E. Poker 15 min.",
		"F. Three best out of six",
		"G. Five best flights",
		"H. 1-2-3-4 in any order",
		"I. Three best flights",
		"J. Three last flights",
		"K. Big Ladder",
		"L. One flight only",
		"M. Huge Ladder"
	}
  
  -- {win, launches, scores, final, tgtType, scoType, QR }
  local taskData = {
    { 420, -1, 1, false, 300, 2, false },   -- A. Last flight
    { 420, -1, 2, false, 180, 2, false },   -- B. Two last 3:00
    { 600, -1, 2, false, 240, 2, false },   -- B. Two last 4:00
    { 0, 8, 8, true, 180, 2, false },       -- C. AULD
    { 600, 2, 2, true, 300, 2, true },      -- D. Two flights only
    { 600, -1, 3, true, 2, 3, true },       -- E. Poker 10 min.
    { 900, -1, 3, true, 2, 3, true },       -- E. Poker 15 min.
    { 600, 6, 3, false, 180, 1, false },    -- F. 3 best of 6
    { 600, -1, 5, false, 120, 1, true },    -- G. 5 x 2:00
    { 600, -1, 4, false, 3, 1, true },      -- H. 1234
    { 600, -1, 3, false, 200, 1, true },    -- I. 3 Best
    { 600, -1, 3, false, 180, 2, false },   -- J. 3 last
    { 600, 5, 5, true, 4, 2, true },        -- K. Big ladder
    { 600, 1, 1, true, 599, 2, false },     -- L. One flight only
    { 900, 3, 3, true, 1, 2, true }         -- M. Huge Ladder
  }

  -- Call back function running when a menu item is selected
  local function callBack(item, event, touchState)
    SetupTask(tasks[item.idx], taskData[item.idx])
    PushGUI(screenTask)
  end

  menuF3K.menu(LEFT, TOP, 5, tasks, callBack)
end

do -- Setup practice tasks menu
  SetupScreen(menuPractice, "Select  Practice  Task")
  
	local tasks = {
		"Just Fly!",
		"Quick Relaunch!",
		"Deuces"
	}

  -- {win, launches, scores, final, tgtType, scoType, QR }
  local taskData = {
    { 0, -1, 8, false, 0, 2, false }, -- Just fly
    { 0, -1, 8, false, 2, 2, true },  -- QR
    { 600, 2, 2, true, 2, 2, false }  -- Deuces
  }
  
  -- Call back function running when a menu item is selected
  local function callBack(item)
    SetupTask(tasks[item.idx], taskData[item.idx])
    PushGUI(screenTask)
  end

  menuPractice.menu(LEFT, TOP, 5, tasks, callBack)
end


do -- Setup score keeper screen for F3K and Practice tasks
  SetupScreen(screenTask, "")
  
  -- Return button shows prompt to save scores instead of popping right away
  function screenTask.buttonRet.callBack()
    if state == STATE_IDLE then
      PopGUI()
    else
      screenTask.prompt = promptSaveScores
    end
  end
  
  -- Add score times
  local x = LEFT
  local y = TOP
  
  screenTask.scoreLabels = { }
  screenTask.scores = { }

  for i = 1, 8 do
    screenTask.scoreLabels[i] = screenTask.label(x, y, 20, HEIGHT, string.format("%i.", i))
    
    local s = screenTask.timer(x + 20, y, 60, HEIGHT)
    s.disabled = true
    s.value = "- - -"
    screenTask.scores[i] = s

    -- Modify timer's draw function to insert score value
    local draw = s.draw
    function s.draw(idx)
      if i > #scores then 
        screenTask.scores[i].value = " -   -   -"
      else
        screenTask.scores[i].value = scores[i]
      end
      
      draw(idx)
    end
    
    if i == 4 then
      y = TOP
      x = x + 85
    else
      y = y + LINE
    end
  end
  
  -- Add center buttons
  local x = (LCD_W - BUTTON_W) / 2
  local y = TOP
  screenTask.buttonQR = screenTask.toggleButton(x, y, BUTTON_W, HEIGHT, "QR", false, nil, DBLSIZE)
  y = y + LINE
  screenTask.buttonEoW = screenTask.toggleButton(x, y, BUTTON_W, HEIGHT, "EoW", true, nil, DBLSIZE)
  
  local function callBack(button)
    if state <= STATE_PAUSE then
      GotoState(STATE_WINDOW)
    
    elseif state == STATE_WINDOW then
      GotoState(STATE_PAUSE)
    
    elseif state >= STATE_COMMITTED then
      -- Record a zero score!
      flightTime = 0
      Score()
      
      -- Change state
      if winTimer <= 0 or (finalScores and #scores == taskScores) or launches == 0 then
        GotoState(STATE_FINISHED)
      else
        playTone(440, 333, PLAY_NOW)
        GotoState(STATE_WINDOW)
      end
    end
  end
  
  y = y + LINE
  screenTask.button3 = screenTask.button(x, y, BUTTON_W, HEIGHT, "Start", callBack, DBLSIZE)
  
  -- Info text label
  y = y + LINE
  screenTask.labelInfo = screenTask.label(RGT - 250, y, 250, HEIGHT, "", DBLSIZE + RIGHT)
  
  -- Add timers
  y = TOP
  screenTask.labelTimer0 = screenTask.label(RGT - 160, y, 50, HEIGHT2, "Target:", 0)
  y = y + LINE2
  screenTask.timer0 = screenTask.timer(RGT - 160, y, 160, HEIGHT, 0, nil, XXLSIZE + RIGHT)
  screenTask.timer0.disabled = true
  
  y = y + LINE
  screenTask.label(RGT - 160, y, 50, HEIGHT2, "Task:", 0)
  y = y + LINE2
  local tmr = screenTask.timer(RGT - 160, y, 160, HEIGHT, 1, nil, XXLSIZE + RIGHT)
  tmr.disabled = true
end

do -- Prompt asking to save scores and exit task window
  local x0 = (LCD_W - PROMPT_W) / 2
  local y0 = (LCD_H - PROMPT_H) / 2
  local LEFT = x0 + PROMPT_M
  local RGT = x0 + PROMPT_W - PROMPT_M
  local TOP = y0 + PROMPT_M
  local BOTTOM = y0 + PROMPT_H - PROMPT_M
  
  function promptSaveScores.fullScreenRefresh()
    lcd.drawFilledRectangle(x0, y0, PROMPT_W, PROMPT_H, COLOR_THEME_PRIMARY2, 2)
    lcd.drawRectangle(x0, y0, PROMPT_W, PROMPT_H, COLOR_THEME_PRIMARY1, 3)
  end

  promptSaveScores.label(x0, TOP, PROMPT_W, HEIGHT, "Save scores?", DBLSIZE + CENTER)

  local function callBack(button)
    if button == promptSaveScores.buttonYes then
      local logFile = io.open("/LOGS/JF F3K Scores.csv", "a")
      if logFile then
        io.write(logFile, string.format("%s,%s", model.getInfo().name, screenTask.title))

        local now = getDateTime()				
        io.write(logFile, string.format(",%04i-%02i-%02i", now.year, now.mon, now.day))
        io.write(logFile, string.format(",%02i:%02i", now.hour, now.min))				
        io.write(logFile, string.format(",s,%i", taskScores))
        io.write(logFile, string.format(",%i", totalScore))
        
        for i = 1, #scores do
          io.write(logFile, string.format(",%i", scores[i]))
        end
        
        io.write(logFile, "\n")
        io.close(logFile)
      end
    end
    
    SetupTask("Just Fly!", { 0, -1, 8, false, 0, 2, false })
    
    -- Dismiss prompt and return to menu
    screenTask.prompt = nil
    PopGUI()
  end -- callBack(...)

  promptSaveScores.buttonYes = promptSaveScores.button(LEFT, BOTTOM - HEIGHT, BUTTON_W, HEIGHT, "Yes", callBack, DBLSIZE)
  promptSaveScores.button(RGT - BUTTON_W, BOTTOM - HEIGHT, BUTTON_W, HEIGHT, "No", callBack, DBLSIZE)

end

do -- Setup score browser screen
  SetupScreen(menuScores, "TODO browse scores")
end

-- Initialize stuff
SetupTask("Just Fly!", { 0, -1, 8, false, 0, 2, false })
widget.update(options)

return widget