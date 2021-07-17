---------------------------------------------------------------------------
-- Lua widget to demonstrate handling of key and touch events in full    --
-- screen mode.                                                          --
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
local defaultOptions = {
}

-- String identifying events
local function evt2str(event)
  if event == EVT_VIRTUAL_PREV then return "EVT_VIRTUAL_PREV"
  elseif event == EVT_VIRTUAL_NEXT then return "EVT_VIRTUAL_NEXT"
  elseif event == EVT_VIRTUAL_DEC then return "EVT_VIRTUAL_DEC"
  elseif event == EVT_VIRTUAL_INC then return "EVT_VIRTUAL_INC"
  elseif event == EVT_VIRTUAL_PREV_PAGE then return "EVT_VIRTUAL_PREV_PAGE"
  elseif event == EVT_VIRTUAL_NEXT_PAGE then return "EVT_VIRTUAL_NEXT_PAGE"
  elseif event == EVT_VIRTUAL_MENU then return "EVT_VIRTUAL_MENU"
  elseif event == EVT_VIRTUAL_ENTER then return "EVT_VIRTUAL_ENTER"
  elseif event == EVT_VIRTUAL_MENU_LONG then return "EVT_VIRTUAL_MENU_LONG"
  elseif event == EVT_VIRTUAL_ENTER_LONG then return "EVT_VIRTUAL_ENTER_LONG"
  elseif event == EVT_VIRTUAL_EXIT then return "EVT_VIRTUAL_EXIT"
  elseif event == EVT_TOUCH_FIRST then return "EVT_TOUCH_FIRST"
  elseif event == EVT_TOUCH_BREAK then return "EVT_TOUCH_BREAK"
  elseif event == EVT_TOUCH_TAP then return "EVT_TOUCH_TAP" 
  elseif event == EVT_TOUCH_SLIDE then return "EVT_TOUCH_SLIDE"
  else 
    local txt = string.format("Event = %i", event)
    return txt
  end
end

-- Returns a function to animate tap events on the square
local function TapAnimation(widget)
  local delta = 20
  local maxS = 250
  local s = widget.s
  
  local function animate()
    s = s + delta
    lcd.drawRectangle(widget.x - 0.5 * s, widget.y - 0.5 * s, s, s)
    
    if s > maxS then
      widget.animate = nil
    end
  end
  
  return animate
end

-- Returns a function to animate swipe events shooting little bullets
local function SwipeAnimation(widget, deltaX, deltaY)
  local x = widget.x
  local y = widget.y
  
  local function animate()
    local x2 = x + deltaX
    local y2 = y + deltaY
    
    lcd.drawLine(x, y, x2, y2, SOLID, 0)
    x, y = x2, y2
    
    if x < 0 or x > LCD_W or y < 0 or y > LCD_H then
      widget.animate = nil
    end
  end
  
  return animate
end

local function create(zone, options)
  return {
    zone=zone, 
    options=options,
    event = 0,
    eventTime = 0,
    x = LCD_W / 2,
    y = LCD_H / 2,
    s = 30
  }
end

local function update(widget, options)
  widget.options = options
end

local function background(widget)
end

local function refresh(widget, event, touchState)
  local s = widget.s
  
  if event == nil then -- Widget mode; event == nil
    -- Draw a border using zone.w and zone.h
    for i = 0, 2 do
      lcd.drawRectangle(widget.zone.x + i, widget.zone.y + i, widget.zone.w - 2 * i, widget.zone.h - 2 * i)
    end
    
    lcd.drawText(10, 10, "Event Demo");
    widget.event = 0
    
  else -- Full screen mode. If no event happened then event == 0
    -- Draw a border using the full screen with LCD_W and LCD_H instead of zone.w and zone.h
    for i = 0, 2 do
      lcd.drawRectangle(i, i, LCD_W - 2 * i, LCD_H - 2 * i)
    end
    
    if event ~= 0 then -- We got a new event
      -- Save the event for subsequent cycles and mark the time
      widget.event = event
      widget.eventTime = getTime()
    
      if touchState then -- Only touch events come with a touchState; otherwise touchState == nil
        if event == EVT_TOUCH_FIRST then -- When the finger first hits the screen
          -- If the finger hit the square, then stick to it!
          widget.stick = (math.abs(touchState.x - widget.x) < 0.5 * s and math.abs(touchState.y - widget.y) < 0.5 * s)
          
        elseif event == EVT_TOUCH_BREAK then -- When the finger leaves the screen (and did not slide on it)
          if widget.stick then
            playTone(100, 200, 100, PLAY_NOW, 10)
          end
          
        elseif event == EVT_TOUCH_TAP then -- A short tap on the screen gives TAP instead of BREAK
          -- If the finger hit the square, then play the animation
          if widget.stick then
            playTone(200, 50, 100, PLAY_NOW)
            widget.animate = TapAnimation(widget)
          end
          
        elseif event == EVT_TOUCH_SLIDE then -- Sliding the finger gives a SLIDE instead of BREAK or TAP
          -- A fast vertical or horizontal slide gives a true swipe* value in touchState (only once per 500ms)
          if touchState.swipeRight then
            widget.animate = SwipeAnimation(widget, 20, 0)
            playTone(10000, 200, 100, PLAY_NOW, -60)
            
          elseif touchState.swipeLeft then
            widget.animate = SwipeAnimation(widget, -20, 0)
            playTone(10000, 200, 100, PLAY_NOW, -60)
            
          elseif touchState.swipeUp then
            widget.animate = SwipeAnimation(widget, 0, -20)
            playTone(10000, 200, 100, PLAY_NOW, -60)
            
          elseif touchState.swipeDown then
            widget.animate = SwipeAnimation(widget, 0, 20)
            playTone(10000, 200, 100, PLAY_NOW, -60)
            
          elseif widget.stick then
            -- If the finger hit the square, then move it around. (x, y) is the current position
            widget.x = touchState.x
            widget.y = touchState.y
            
            -- (slideX, slideY) gives the finger movement since the previous slide event - draw a little tail
            lcd.drawLine(widget.x - 3 * touchState.slideX, widget.y - 3 * touchState.slideY, widget.x, widget.y, SOLID, 0)
            
            -- (startX, startY) is the point where the first slide event started - draw a square outline
            lcd.drawRectangle(touchState.startX - 0.5 * s, touchState.startY - 0.5 * s, s, s)
            
          end
        end
      end      
    end
    
    -- Double the size of the square while the finger is on it
    if widget.event == EVT_TOUCH_FIRST and widget.stick then
      s = 2 * s
    end

    -- Draw the square
    lcd.drawFilledRectangle(widget.x - 0.5 * s, widget.y - 0.5 * s, s, s)
    
    -- Show the last event for 2 sec. in the upper left corner
    if getTime() - widget.eventTime < 200 then
      lcd.drawText(3, 3, evt2str(widget.event))
    end
    
    -- If we have an active animation, run it
    if widget.animate then 
      widget.animate()
    end
  end
end

return {
  name = "EventDemo", 
  options = defaultOptions, 
  create = create, 
  update = update, 
  refresh = refresh, 
  background = background
}