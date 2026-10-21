-- D76: Crown Sneak. Mechanics live in the shared authoritative rules.
local Client = require(script.Parent.Parent.PlaygroundClient)
return {
	new = function(parent, interval, onRep, options)
		return Client.new("CrownSneak", parent, interval, onRep, options)
	end,
}
