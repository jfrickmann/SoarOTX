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
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------
local widget = ... -- The widget table is passed as an argument to chunk()
local util = Utilities(widget.dir)
local gui = util.GUI()

util.flags = MIDSIZE
local LEFT = 10
local HEIGHT = 40
local LINE = 60
local BUTTON_W = 70

local border = false
local toggle = ""
local a, b, t, n


local function A()
  border = true
end

local function B()
  border = false
end

local function T(value)
  if value then
    toggle = "ON"
  else
    toggle = "OFF"
  end
end

local function drawFull()
  if border then
    for i = 0, 5 do
      lcd.drawRectangle(i, i, LCD_W - 2 * i, LCD_H - 2 * i, BATTERY_CHARGE_COLOR)
    end
  end

  lcd.drawText(LEFT + 2 * BUTTON_W, 12 + LINE, "Toggle = " .. toggle, bit32.bor(util.flags, DEFAULT_COLOR))
end

local function drawZone()
  lcd.drawRectangle(0, 0, widget.zone.w, widget.zone.h, BATTERY_CHARGE_COLOR)
  lcd.drawText(5, 5, "GUI test")
end

local function numberChange(d)
  n.value = n.value + d
end

do -- Initialization happens here
  local y = 10
  
  util.widgetRefresh = drawZone
  gui.fullScreenRefresh = drawFull
  
  a = gui.button(LEFT, y, BUTTON_W, HEIGHT, "A", A)
  b = gui.button(LEFT + 1.5 * BUTTON_W, y, BUTTON_W, HEIGHT, "B", B)
  y = y + LINE
  t = gui.toggleButton(LEFT, y, 1.5 * BUTTON_W, HEIGHT, "T", true, T)
  y = y + LINE
  n = gui.number(LEFT, y, 1.5 * BUTTON_W, HEIGHT, 0, numberChange, RIGHT)
  
  a.title = "ON"
  b.title = "OFF"
  t.title = "Toggle"
end

widget.update = function(options)
end

widget.background = function()
end

widget.refresh = function(event, touchState)
  gui.run(event, touchState)
end

return