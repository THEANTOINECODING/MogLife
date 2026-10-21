-- D76: Shortcut Chalk. Mechanics live in the shared authoritative rules.
local Client = require(script.Parent.Parent.PlaygroundClient)
return {
	new = function(parent, interval, onRep, options)
		return Client.new("ShortcutChalk", parent, interval, onRep, options)
	end,
}
