---------------------------------------------------------------------------
-- The dynamically loadable part of the demonstration Lua widget.        --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2021-XX-XX                                                   --
-- Version: 0.9                                                          --
--                                                                       --
-- Copyright (C) EdgeTX                                                  --
--                                                                       --
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               --
--                                                                       --
-- This program is free software; you can redistribute it and/or modify  --
-- it under the terms of the GNU General Public License version 2 as     --
-- published by the Free Software Foundation.                            --
--                                                                       --
-- This program is distributed in the hope that it will be useful        --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of        --
-- MERCHANTABILITY or FITNESS FOR turnON PARTICULAR PURPOSE.  See the         --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------
local widget = ... -- The widget table is passed as an argument to chunk()
local libGUI = loadGUI()
local gui = libGUI.newGUI()
gui.flags = bit32.bor(MIDSIZE)

local LEFT = 10
local TOP = 10
local COL = 150
local ROW = 50
local WIDTH = 120
local HEIGHT = 40

local buttonON, buttonOFF, toggleButton, number, labelToggle, lableNumber, timer, labelTimer
local border = false
local TMR = 0

local function drawFull()
  if border then
    for i = 0, 5 do
      lcd.drawRectangle(i, i, LCD_W - 2 * i, LCD_H - 2 * i, BATTERY_CHARGE_COLOR)
    end
  end
end

local function drawZone()
  lcd.drawRectangle(0, 0, widget.zone.w, widget.zone.h, BATTERY_CHARGE_COLOR)
  lcd.drawText(5, 5, "Utilities")
end

local function turnON()
  border = true
end

local function turnOFF()
  border = false
end

local function doToggle(value)
  if value then
    labelToggle.title = "Toggle = ON"
  else
    labelToggle.title = "Toggle = OFF"
  end
end

local function numberChange(d)
  -- Scale down slide input
  if math.abs(d) > 1 then
    d = math.floor(0.1 * d + 0.5)
  end
  number.value = number.value + d
end

local function timerChange(event, touchState)
  local d = 0

  if not timer.value then  -- Initialize at first call
    timer.value = model.getTimer(TMR).value
  end
  if libGUI.match(event, EVT_VIRTUAL_ENTER, EVT_TOUCH_TAP) then
    local tmr = model.getTimer(TMR)
    tmr.value = timer.value
    model.setTimer(TMR, tmr)
  elseif event == EVT_VIRTUAL_EXIT then
    timer.value = nil
  elseif event == EVT_VIRTUAL_INC then
    d = 20
  elseif event == EVT_VIRTUAL_DEC then
    d = -20
  elseif event == EVT_TOUCH_SLIDE then
    d = -touchState.slideY
  end
  if d >= 20 then
    timer.value = 60 * math.ceil((timer.value + 1) / 60)
  elseif d <= -20 then
    timer.value = 60 * math.floor((timer.value - 1) / 60)
  end
end

do -- Initialization happens here
  gui.widgetRefresh = drawZone
  gui.fullScreenRefresh = drawFull
  
  local x = LEFT
  local y = TOP
  
  local function nextCol()
    x = x + COL
  end
  
  local function nextRow()
    x = LEFT
    y = y + ROW
  end
  buttonON = gui.button(x, y, WIDTH, HEIGHT, "ON", turnON)
  nextCol()
  buttonOFF = gui.button(x, y, WIDTH, HEIGHT, "OFF", turnOFF)
  nextRow()
  toggleButton = gui.toggleButton(x, y, WIDTH, HEIGHT, "Toggle", true, doToggle)
  nextCol()
  labelToggle = gui.label(x, y, WIDTH, HEIGHT, "")
  nextRow()
  labelNumber = gui.label(x, y, WIDTH, HEIGHT, "Number =")
  nextCol()
  number = gui.number(x, y, WIDTH, HEIGHT, 0, numberChange, bit32.bor(gui.flags, RIGHT))
  nextRow()
  labelTimer = gui.label(x, y, WIDTH, HEIGHT, "Timer =")
  nextCol()
  timer = gui.timer(x, y, WIDTH, HEIGHT, TMR, timerChange, bit32.bor(gui.flags, RIGHT))
end

widget.update = function(options)
end

widget.background = function()
end

widget.refresh = function(event, touchState)
  gui.run(event, touchState)
end

return