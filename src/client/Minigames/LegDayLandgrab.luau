-- D76: Leg Day Landgrab. Mechanics live in the shared authoritative rules.
local Client = require(script.Parent.Parent.PlaygroundClient)
return {
	new = function(parent, interval, onRep, options)
		return Client.new("LegDayLandgrab", parent, interval, onRep, options)
	end,
}
