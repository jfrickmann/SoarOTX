---------------------------------------------------------------------------
-- SoarETX, loadable component                                           --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2021-12-20                                                   --
-- Version: 0.99                                                         --
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

local widget, soarGlobals =  ...
local libGUI =  loadGUI()
libGUI.flags =  MIDSIZE
local gui =     libGUI.newGUI()
local colors =  libGUI.colors
local title =   "Rx battery"
local lblCurrent, lblWarning

-- Screen drawing constants
local HEADER =  40
local MARGIN =  25
local TOP =     50
local LINE =    36
local HEIGHT =  28

-- Battery variables
local MEM_CRV = 31
local MEM_BAT =  0
local rxBatSrc
local rxBatNxtWarn = 0

local function getWarningLevel()
  return 0.1 * (soarGlobals.getParameter(soarGlobals.batteryParameter) + 100)
end

local function onSlide(slider)
  soarGlobals.setParameter(soarGlobals.batteryParameter, 10 * slider.value - 100)
end

function widget.background()
  local now = getTime()
  
  -- Receiver battery
  if not rxBatSrc then 
    rxBatSrc = getFieldInfo("Cels")
    if not rxBatSrc then rxBatSrc = getFieldInfo("RxBt") end
    if not rxBatSrc then rxBatSrc = getFieldInfo("A1") end
    if not rxBatSrc then rxBatSrc = getFieldInfo("A2") end
  end
  
  if rxBatSrc then
    soarGlobals.battery = getValue(rxBatSrc.id)
    
    if type(soarGlobals.battery) == "table" then
      for i = 2, #soarGlobals.battery do
        soarGlobals.battery[1] = math.min(soarGlobals.battery[1], soarGlobals.battery[i])
      end
      soarGlobals.battery = soarGlobals.battery[1]
    end
  end

  -- Warn about low receiver battery or Rx off
  if now > rxBatNxtWarn and soarGlobals.battery > 0 and soarGlobals.battery < getWarningLevel() then
    playHaptic(200, 0, 1)
    playFile("lowbat.wav")
    playNumber(10 * soarGlobals.battery + 0.5, 1, PREC1)
    rxBatNxtWarn = now + 2000
  end
end -- background()

function widget.refresh(event, touchState)
  widget.background()
  gui.run(event, touchState)
end -- refresh(...)

-------------------------------- Setup GUI --------------------------------

function libGUI.widgetRefresh()
  lcd.drawFilledRectangle(6, 4, widget.zone.w - 12, widget.zone.h - 8, colors.focus)
  lcd.drawRectangle(7, 5, widget.zone.w - 14, widget.zone.h - 10, colors.primary2, 1)
  lcd.drawText(widget.zone.w / 2, widget.zone.h / 2, title, CENTER + VCENTER + DBLSIZE + colors.primary2)
end

function gui.fullScreenRefresh()
  -- Top bar
  lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
  lcd.drawText(10, 2, title, bit32.bor(DBLSIZE, colors.primary2))

  -- Bleed out background to make all of the screen readable
  lcd.drawFilledRectangle(0, HEADER, LCD_W, LCD_H - HEADER, WHITE, 10)
  
  lblCurrent.title = string.format("%1.1f V", soarGlobals.battery)
  lblWarning.title = string.format("%1.1f V", getWarningLevel())
end

-- Minimize button
local buttonMin = gui.button(LCD_W - 34, 6, 28, 28, "", function() lcd.exitFullScreen() end)

-- Paint another face on it
local drawMin = buttonMin.draw
function buttonMin.draw(idx)
  drawMin(idx)
  
  lcd.drawFilledRectangle(LCD_W - 34, 6, 28, 28, COLOR_THEME_SECONDARY1)
  lcd.drawRectangle(LCD_W - 34, 6, 28, 28, colors.primary2)
  for y = 19, 21 do
    lcd.drawLine(LCD_W - 30, y, LCD_W - 10, y, SOLID, colors.primary2)
  end
end

do
  local x = MARGIN
  local y = TOP
  
  gui.label(x, y, 250, HEIGHT, "Current battery reading:")
  lblCurrent = gui.label(LCD_W - MARGIN, y, 0, HEIGHT, "", libGUI.flags + RIGHT)

  y = y + LINE
  gui.label(x, y, 250, HEIGHT, "Battery warning level:")
  lblWarning = gui.label(LCD_W - MARGIN, y, 0, HEIGHT, "", libGUI.flags + RIGHT)
  
  y = y + LINE + HEIGHT
  gui.horizontalSlider(x, y, LCD_W - 2 * MARGIN, getWarningLevel(), 0, 20, 0.1, onSlide)
end