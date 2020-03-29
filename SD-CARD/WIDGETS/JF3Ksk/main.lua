-- JF F3K Timing and score keeping, widget shell for Horus
-- Timestamp: 2019-12-30
-- Created by Jesper Frickmann

-- Path to the telemetry script
local file = "/SCRIPTS/TELEMETRY/JF3Ksk.lua"

local options = {
}

local run, background

local function create(zone, options)
	local chunk
	local tbl

	-- On Taranis, this loads from custom function, but apparently not on Horus...
	if not soarUtil then
		chunk = loadScript("/SCRIPTS/FUNCTIONS/JFutil.lua")
		chunk()
	end

	-- Now load the telemetry script running in this widget:
	chunk = loadScript(file)
	tbl = chunk()
	
	run = tbl.run
	background = tbl.background

	return { zone=zone, options=options}
end

local function update(widget, options)
	widget.options = options
end

local function refresh(widget, event)
	soarUtil.x = widget.zone.x
	soarUtil.y = widget.zone.y
	soarUtil.w = widget.zone.w
	soarUtil.h = widget.zone.h
	
	background()
	run(event)
soarUtil.drawNumber(0, 100, soarUtil.w)
soarUtil.drawNumber(0, 120, soarUtil.h)
end

return { name="SoarOTX F3K Score Keeper", options=options, create=create, update=update, background=background, refresh=refresh }
