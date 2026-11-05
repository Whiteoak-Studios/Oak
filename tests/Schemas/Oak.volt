option serverOutput = "../Generated/Oak/Server.luau"
option clientOutput = "../Generated/Oak/Client.luau"
option typesOutput = "../Generated/Oak/Types.luau"
option runtime = "ReplicatedStorage.Packages.Volt"
option yield = promise
option promise = "ReplicatedStorage.Packages.Promise"
option scope = Oak

namespace Shop {
	struct Slot { item: string(1..32), quantity: u16 }
	struct Shelf { label: string(0..32), slots: { [u8]: Slot }(0..16) }

	function buy {
		rate: unlimited,
		data: u8,
		return: (ok: boolean, reason: string(0..64)?),
	}

	event report {
		from: Client, type: Reliable, call: SingleSync,
		data: string(0..64),
	}

	event chat {
		from: Both, type: Reliable, call: ManySync,
		data: string(0..64),
	}

	event browse {
		from: Client, type: Reliable, call: Polling,
		data: u8,
	}

	event coins {
		from: Server, type: Reliable, call: SingleAsync,
		data: u32,
	}

	event stock {
		from: Server, type: Reliable, call: SingleAsync,
		data: struct { version: u32, shelf: Shelf },
	}

	function confirm {
		from: Server,
		data: string(0..64),
		return: boolean,
	}
}

namespace Catalog {
	export struct Item { name: string(1..32), price: u32 }
}
