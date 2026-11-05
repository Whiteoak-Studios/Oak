option serverOutput = "../Generated/Orphan/Server.luau"
option clientOutput = "../Generated/Orphan/Client.luau"
option typesOutput = "../Generated/Orphan/Types.luau"
option runtime = "ReplicatedStorage.Packages.Volt"
option yield = promise
option promise = "ReplicatedStorage.Packages.Promise"
option scope = Oak

namespace Orphan {
	event announce {
		from: Server, type: Reliable, call: SingleAsync,
		data: u8,
	}
}
