-- The dev place's game: its options, then its two namespaces, each owned by
-- the service and the controller named after it, as GreeterService owns Greeter
option serverOutput = "../Network/Server.luau"
option clientOutput = "../Network/Client.luau"
option typesOutput = "../Network/Types.luau"
option runtime = "ReplicatedStorage.Packages.Volt"
option scope = Dev
option yield = promise
option promise = "ReplicatedStorage.Packages.Promise"

namespace Greeter {
	-- A client asks to be greeted, and GreeterService's Client handler answers
	function greet {
		data: (name: string(1..32)),
		return: (ok: boolean, reply: string(0..64)?),
	}

	-- A cheer, which the client sends more of in one frame than its Policy row lets through
	event cheer {
		from: Client, type: Reliable, call: SingleAsync,
		data: u8,
	}

	-- Tells every player who the server just greeted: a one-shot notification, so an event and never a Property
	event greeted {
		from: Server, type: Reliable, call: SingleAsync,
		data: (name: string(1..32), count: u32),
	}
}

namespace Score {
	-- Each player's points: an Oak.Property, its top value for everyone and an override per player
	event points {
		from: Server, type: Reliable, call: SingleAsync,
		data: u32,
	}

	-- The server asks a client whether it holds a number of points, and ScoreController answers
	function check {
		from: Server,
		data: u32,
		return: boolean,
	}
}
