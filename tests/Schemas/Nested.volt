option serverOutput = "../Generated/Nested/Server.luau"
option clientOutput = "../Generated/Nested/Client.luau"
option typesOutput = "../Generated/Nested/Types.luau"
option runtime = "ReplicatedStorage.Packages.Volt"
option yield = promise
option promise = "ReplicatedStorage.Packages.Promise"
option scope = Oak

namespace Outer {
	namespace Inner {
		event announce {
			from: Server, type: Reliable, call: SingleAsync,
			data: u8,
		}
	}
}
