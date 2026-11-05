option serverOutput = "../Generated/TopLevel/Server.luau"
option clientOutput = "../Generated/TopLevel/Client.luau"
option typesOutput = "../Generated/TopLevel/Types.luau"
option runtime = "ReplicatedStorage.Packages.Volt"
option yield = promise
option promise = "ReplicatedStorage.Packages.Promise"
option scope = Oak

event announce {
	from: Server, type: Reliable, call: SingleAsync,
	data: u8,
}
