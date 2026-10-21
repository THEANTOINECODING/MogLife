-- D76: Read & Rip. Mechanics live in the shared authoritative rules.
local Client = require(script.Parent.Parent.PlaygroundClient)
return {
	new = function(parent, interval, onRep, options)
		return Client.new("ReadRip", parent, interval, onRep, options)
	end,
}
