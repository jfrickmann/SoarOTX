---------------------------------------------------------------------------
-- Shared Lua utilities library, and a widget showing how to use it.     --
-- NOTE: It is not necessary to load the widget to use the library;      --
-- as long as the files are present on the SD card it works.             --
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
local dir = "/WIDGETS/Utilities/"
local soarUtil

-- Return a library instance working in the client widget's directory
function Utilities(clientDir)
  -- Load the library on demand
  if not soarUtil then
  	local chunk = loadScript(dir .. "utilities.lua")
    soarUtil = chunk()
  end
  
  return soarUtil(clientDir)
end

-----------------------------------------------------------------------------
-- The following widget implementation demonstrates how to use the library --
-- and how to create a dynamically loadable widget to minimize the amount  --
-- memory consumed when the widget is not being used.                      --
-----------------------------------------------------------------------------

local options = { 
}

local function create(zone, options)
  local widget = {
    zone = zone, 
    options = options,
    dir = dir
  }
  
  -- Load the widget code. It will add functions to the widget table
  local chunk = loadScript(dir .. "loadable.lua")
  chunk(widget)

  return widget
end

local function update(widget, options)
  widget.update(options)
end

local function background(widget)
  widget.background()
end

local function refresh(widget, event, touchState)
  widget.refresh(event, touchState)
end

return {
  name = "Utilities",
  options = options,
  create = create,
  update = update,
  background = background,
  refresh = refresh
}