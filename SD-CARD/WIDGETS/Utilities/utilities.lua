---------------------------------------------------------------------------
-- The dynamically loadable part of the shared Lua utilities library.    --
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
local widgetSizes = {
  {392, 170},
  {196, 170},
  {196, 85},
  {196, 42},
  {70, 39}
}

local function utilities(dir)
  local this = { }
  this.dir = dir
  this.flags = 0
  
--  The following variables can be set by the client.
--> widgetRefresh = function
--> flags = lcd flags; will be used as defaults for drawing text and numbers

  this.load4screen = function(file, ...)
    local filename = this.dir .. file .. "_" .. LCD_W .. "x" .. LCD_H .. ".lua"
    local chunk = loadScript(filename)
    return chunk(...)
  end -- load4screen(...)
  
  this.load4zone = function(file, zone, ...)
    local w, h = zone.w, zone.h
    
    for i, wh in ipairs(widgetSizes) do
      if wh[1] <= w and wh[2] <= h then
        local filename = this.dir .. file .. "_" .. wh[1] .. "x" .. wh[2] .. ".lua"
        local chunk = loadScript(filename)
        if chunk then
          return chunk(...)
        end
      end
    end
    
    print("----> load4zone could not find a script for: " .. this.dir .. file)
  end -- load4zone(...)

  -- Return true if the first arg matches any of the following args
  this.match = function(x, ...)
    for i, y in ipairs({...}) do
      if x == y then
        return true
      end
    end
    return false
  end
  
  local match = this.match -- Easier to use locally
  
  -- Create a new GUI object with interactive screen elements
  this.GUI = function()
    local this = { parent = this }
    local handlers = { }
    local elements = { }
    local focus = 0
    local edit = false

    -- Draw a rectangle with pattern
    local function drawRectangle(x, y, w, h, pat, flags)
      lcd.drawLine(x, y, x + w, y, pat, flags)
      lcd.drawLine(x + w, y, x + w, y + h, pat, flags)
      lcd.drawLine(x + w, y + h, x, y + h, pat, flags)
      lcd.drawLine(x, y + h, x, y, pat, flags)
    end
    
    -- Move focus to another element
    local function moveFocus(delta)
      repeat
        focus = focus + delta
        if focus > #elements then
          focus = 1
        elseif focus < 1 then
          focus = #elements
        end
      until not elements[focus].noFocus
    end -- moveFocus(...)
    
    -- Add an element and return it to the client
    local function addElement(element)
      local idx = #elements + 1
      elements[idx] = element
      return element
    end -- addElement(...)
    
    -- Set a handler for event (if no element is being edited)
    this.setHandler = function(event, f)
      table.insert(handlers, {event, f} )
    end -- setHandler
    
--  Public interface starts here. The following variables can be set by the client.
--> fullScreenRefresh = function
    
    -- Run an event cycle
    this.run = function(event, touchState)
      if not event then -- widget mode; event == nil
        if this.parent.widgetRefresh then
          this.parent.widgetRefresh()
        else
          lcd.drawText(1, 1, "No widget refresh")
          lcd.drawText(1, 25, "function was loaded.")
        end
      else -- full screen mode; event is a value
        if this.fullScreenRefresh then
          this.fullScreenRefresh(event, touchState)
        end
        for idx, element in ipairs(elements) do
          element.draw(idx)
        end
        if event == 0 then
          -- At the first cycle, find the first element that can take focus
          -- WARNING: if no element can take focus, then it loops infinitely!
          if focus == 0 then
            moveFocus(1)
          end
        else -- non-zero event; process it
          if edit then -- Send the event to the element being edited
            elements[focus].run(event, touchState)
          else
            -- Is the event being "handled"?
            for i, h in ipairs(handlers) do
              local evt, f = h[1], h[2]
              if event == evt then
                return f()
              end
            end
            -- Move focus or send event to the focused element
            if event == EVT_TOUCH_FIRST then
              for idx, element in ipairs(elements) do
                if element.covers(touchState.x, touchState.y) then
                  if not element.noFocus then
                    focus = idx
                  end
                  break
                end
              end
            elseif event == EVT_VIRTUAL_NEXT then
              moveFocus(1)
            elseif event == EVT_VIRTUAL_PREV then
              moveFocus(-1)
            else
              elements[focus].run(event, touchState)
            end
          end
        end
      end
    end -- run(...)

    -- Create a button to trigger a function
    this.button = function(x, y, w, h, title, callBack, flags)
      flags = bit32.bor(flags or 0, this.parent.flags)
      local this = { parent = this }
      this.title = title
      
      this.draw = function(idx)
        local flags = flags
        
        if focus == idx then
          flags = bit32.bor(flags, BOLD)
          drawRectangle(x - 1, y - 1, w + 2, h + 2, DOTTED, HIGHLIGHT_COLOR)
        end
        lcd.drawFilledRectangle(x, y, w, h, FOCUS_BGCOLOR)
        lcd.drawText(x + w / 2, y + 2, this.title, bit32.bor(CENTER, FOCUS_COLOR, flags))
      end
      
      this.run = function(event, touchState)
        if match(event, EVT_VIRTUAL_ENTER, EVT_TOUCH_TAP, EVT_TOUCH_BREAK) then
          callBack()
        end
      end
      
      this.covers = function(p, q)
        return (x <= p and p <= x + w and y <= q and q <= y + h)
      end
      
      return addElement(this)
    end -- button(...)
    
    -- Create a toggle button that turns on/off. callBack gets true/false
    this.toggleButton = function(x, y, w, h, title, value, callBack, flags)
      flags = bit32.bor(flags or 0, this.parent.flags)
      local this = { parent = this }
      this.title = title
      this.value = value
      
      this.draw = function(idx)
        local flags = flags
        local fg = FOCUS_COLOR
        local bg = FOCUS_BGCOLOR

        if this.value then
          fg = DEFAULT_COLOR
          bg = HIGHLIGHT_COLOR 
        end
        
        if focus == idx then
          drawRectangle(x - 1, y - 1, w + 2, h + 2, DOTTED, HIGHLIGHT_COLOR)
          flags = bit32.bor(flags, BOLD)
        end
        lcd.drawFilledRectangle(x, y, w, h, bg)
        lcd.drawText(x + w / 2, y + 2, this.title, bit32.bor(CENTER, fg, flags))
      end
      
      this.run = function(event, touchState)
        if match(event, EVT_VIRTUAL_ENTER, EVT_TOUCH_TAP, EVT_TOUCH_BREAK) then
          this.value = not this.value
          callBack(this.value)
        end
      end
      
      this.covers = function(p, q)
        return (x <= p and p <= x + w and y <= q and q <= y + h)
      end
      
      return addElement(this)
    end -- toggleButton(...)
    
    -- Create a number that can be edited
    this.number = function(x, y, w, h, value, callBack, flags)
      flags = bit32.bor(flags or 0, this.parent.flags)
      local this = { parent = this }
      this.value = value
      local xx
      
      if bit32.band(flags, RIGHT) ~= 0 then
        xx = x + w - 2
      elseif bit32.band(flags, CENTER) ~= 0 then
        xx = x + w / 2
      else
        xx = x + 2
      end
      
      this.draw = function(idx)
        local fg = DEFAULT_COLOR
        local flags = flags
        
        if focus == idx then
          drawRectangle(x - 1, y - 1, w + 2, h + 2, DOTTED, HIGHLIGHT_COLOR)
          flags = bit32.bor(flags, BOLD)
          if edit then
            fg = FOCUS_COLOR
            lcd.drawFilledRectangle(x, y, w, h, FOCUS_BGCOLOR)
          end
        end
        lcd.drawNumber(xx, y + 2, this.value, bit32.bor(fg, flags))
      end
      
      this.run = function(event, touchState)
        local d = 0
          
        if match(event, EVT_VIRTUAL_ENTER, EVT_TOUCH_BREAK, EVT_TOUCH_TAP) then
          edit = not edit
        elseif edit then
          if event == EVT_VIRTUAL_EXIT then
            edit = false
          elseif event == EVT_VIRTUAL_INC then
            d = 1
          elseif event == EVT_VIRTUAL_DEC then
            d = -1
          elseif event == EVT_TOUCH_SLIDE then
            d = -touchState.slideY
          end
        end
        callBack(d)
      end
      
      this.covers = function(p, q)
        return (x <= p and p <= x + w and y <= q and q <= y + h)
      end
       
      return addElement(this)
    end -- number(...)
    
    -- Create a menu of choices. callBack gets choice #
    local function menu(items, callBack, flags)
      flags = bit32.bor(flags or 0, this.parent.flags)
      local this = { parent = this }
      
      this.draw = function(idx)
        local flags = flags
        
        if focus == idx then
          flags = bit32.bor(flags, BOLD)
        else
        end
      end
      
      this.run = function(event, touchState)
      end
      
      this.covers = function(p, q)
        return (x <= p and p <= x + w and y <= q and q <= y + h)
      end
      
      return addElement( {draw = draw, run = run, covers = covers} )
    end -- menu(...)
    
    -- Create a display of current time on timer[tmr]
    local function timer(x, y, w, h, tmr, callBack, flags)
      flags = bit32.bor(flags or 0, this.parent.flags)
      local this = { parent = this }

      this.draw = function(idx)
        local flags = 0
        
        if focus == idx then
          flags = BOLD
        else
        end
      end
      
      this.run = function(event, touchState)
      end
      
      this.covers = function(p, q)
        return (x <= p and p <= x + w and y <= q and q <= y + h)
      end
      
      this.noFocus = true
      return addElement(this)
    end -- timer(...)
    
    return this
  end -- gui(...)
  
  return this
end

return utilities