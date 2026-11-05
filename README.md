# Oak

Oak is Whiteoak Studios' service and controller framework for Roblox, the replacement for the archived Knit. A game writes its server code as services and its client code as controllers, plain tables made with `Oak.create`, and boots each realm with `Oak.start`. Every message between the realms goes through [Volt](https://github.com/Fadeluc-123/Volt), Whiteoak's buffer networking package, which owns everything on the wire: the schema, validation, rate limits and failure reports. Oak adds no networking of its own. It binds each service's handlers to the endpoints the game's Volt schema declares and refuses to boot when the two disagree, runs every `Init` and then every `Start`, routes each Volt failure to the table that owns the message or to a game-wide handler, and replicates state through `Oak.Property`. Knit typed every service `{ [any]: any }`, so nothing that touched one autocompleted. `Oak.create` returns the table it was given with its type unchanged, so every method, field and `Client` member stays typed in every file that reaches it, a peer reached by name included. Oak's types are written for luau-lsp's new type checker.

## Install

### `wally.toml`

```toml
[dependencies]
Oak = "fadeluc-123/oak@^1.0.0"
Promise = "evaera/promise@4.0.0"
Volt = "fadeluc-123/volt@0.1.0"
```

Oak depends on Promise and Volt itself, and a game lists both as well. Its generated network modules require `ReplicatedStorage.Packages.Volt` and, under `option yield = promise`, `ReplicatedStorage.Packages.Promise`, and Wally only puts a top-level dependency at those paths.

Keep the game's `Volt` on Oak's Volt line, `0.1.x` for Oak 1.0.0. `Oak.start` compares the Volt that compiled the game's network module with the Volt installed with Oak and refuses to boot, naming both versions, when their major.minor differ. Wally installs two Volt lines side by side without complaint, so that check is what catches a mismatch. The `volt` compiler comes from Volt's GitHub Releases through Rokit, on the same line: `rokit add fadeluc-123/volt`.

### The typed install

A Wally thunk in `Packages/` drops every `export type` of the package it points at, so after a plain `wally install`, `require(Packages.Oak)` is `any` and none of Oak's types reach the game. After every install, run these three in this order:

```sh
wally install
rojo sourcemap sourcemap.project.json --output sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages/
```

The project file is the game's sourcemap project, `sourcemap.project.json` in a Whiteoak game (`dev.project.json` in a package repo). `wally-package-types` 1.6.2 exits 1 on a second pass over links it has already typed, so it runs once after each fresh `wally install`. A Lune script in `.lune/` is a good home for the three.

### The new type checker

Oak is written for luau-lsp's new type checker, `LuauSolverV2`. luau-lsp's command line runs the old checker unless told otherwise, so every `luau-lsp analyze` passes `--flag:LuauSolverV2=true`:

```sh
luau-lsp analyze --platform=roblox --flag:LuauSolverV2=true --sourcemap=sourcemap.json --definitions=globalTypes.d.luau --ignore="Packages/**" src
```

`globalTypes.d.luau` is `scripts/globalTypes.d.luau` from luau-lsp's repository. The editor runs the same checker with these three lines in `.vscode/settings.json`, beside the `luau-lsp.sourcemap.rojoProjectFile` line that names the sourcemap project:

```json
{
	"luau-lsp.fflags.enableNewSolver": true,
	"luau-lsp.fflags.enableByDefault": true,
	"luau-lsp.fflags.sync": false
}
```

The first turns the new checker on, the second turns on every boolean Luau flag the way `luau-lsp analyze` does, and the third stops the extension copying Roblox's live Luau flags. Without the sourcemap line, luau-lsp builds no sourcemap, every instance-path require resolves to `any`, and Oak's typing is invisible.

### One `.luaurc` per mode

A peer's type is written through two aliases, so each mode folder (`src/game/`, `src/lobby/` and the rest) holds a `.luaurc` beside the root one that sets strict mode:

```json
{
	"aliases": {
		"Services": "./Server/Services",
		"Controllers": "./Client/Services"
	}
}
```

The aliases only shorten the path inside `typeof(require(...))`, which sits in a type position and never runs, and every require that runs keeps its instance path. A mode other than Game that names a peer it maps in from `src/game` also adds `@GameServices` and `@GameControllers`, pointing at `src/game`'s two folders, and types that peer through them, since an alias is read from the `.luaurc` nearest the file.

## A first look

One endpoint, the service that answers it, the controller that calls it, and the boot. The schema, `src/game/Schemas/Greeter.volt`:

```
namespace Greeter {
	function greet {
		return: string(0..64),
	}
}
```

`src/game/Server/Services/Features/GreeterService.luau`, below its header and requires:

```lua
local Service = Oak.create("GreeterService", {
	Client = {},

	Policy = {
		greet = { rate = { perSecond = GREET_RATE } },
	},

	_greeted = 0, -- Greetings answered on this server
})

function Service.greet(self: Self, player: Player): string
	self._greeted += 1
	return `Hello, {player.Name}! That's greeting {self._greeted} on this server`
end

function Service.Client:greet(player: Player): string
	return (Service :: Self):greet(player)
end

function Service:Start() end
function Service:Init() end

type Self = typeof(Service)

return Service
```

`src/game/Client/Services/Features/GreeterController.luau`, below its header and requires:

```lua
local Controller = Oak.create("GreeterController", {
	_greeting = nil :: string?, -- What the server greeted us with
})

function Controller:Init() end
function Controller.Start(self: Self)
	Network.Greeter.greet
		.invoke()
		:andThen(function (greeting: string)
			self._greeting = greeting
			print(greeting)
		end)
		:catch(warn)
end

type Self = typeof(Controller)

return Controller
```

Each realm's bootstrap requires its generated module, `Network.Server` here and `Network.Client` on the client, and after the component hoist shown under [Lifecycle and boot](#lifecycle-and-boot), starts its `Services` folder:

```lua
local Network = require(ReplicatedStorage.Shared.Network.Server) -- Volt-generated, this mode's module set

Oak.start(script.Services, Network)
```

`GreeterService` owns the `Greeter` namespace because its name is `Greeter` plus `Service`. The schema line, the `Client` handler and the `Policy` row must all exist: leave any one out and `Oak.start` refuses to boot, naming the endpoint.

## Using Oak

The snippets below are one small Game mode, laid out the way a Whiteoak game is. Like a Whiteoak game, it installs sleitnick's Observers (`sleitnick/observers`), which clears each player's records when they leave; Observers is the game's dependency, not Oak's.

```
src/game/
├── .luaurc                       -- @Services and @Controllers
├── Schemas/                      -- Game.volt (the options), Greeter.volt, Shop.volt, Inventory.volt
├── Server/
│   ├── init.server.luau
│   ├── Config/                   -- Greeter, Inventory, Moderation
│   └── Services/
│       ├── Features/             -- GreeterService, ShopService, InventoryService
│       └── Player/               -- ModerationService
├── Client/
│   ├── init.client.luau
│   ├── Components/Shop Counter.luau
│   └── Services/Features/        -- GreeterController, ShopController, InventoryController, NotificationController
└── Shared/
    ├── Config/Shop.luau
    ├── Config/Types/Shop.luau
    └── Network/                  -- Volt's output: Server.luau, Client.luau, Types.luau
```

`Shop.volt`, which every snippet below leans on:

```
namespace Shop {
	-- Each player's balance: state a late joiner must receive, so an Oak.Property
	event coins {
		from: Server, type: Reliable, call: SingleAsync,
		data: u32,
	}

	-- A one-shot notification, so a plain event and never a Property
	event purchased {
		from: Server, type: Reliable, call: ManyAsync,
		data: (itemId: string(1..32), remaining: u32),
	}

	-- ShopService's Policy row replaces this rate at bind, so it never applies
	function purchase {
		data: (itemId: string(1..32)),
		return: (ok: boolean, reason: string(0..128)?),
		rate: 4,
	}

	-- The server offers a player an item, and ShopController answers whether they can afford it
	function offer {
		from: Server,
		data: (itemId: string(1..32), price: u32),
		return: boolean,
	}
}
```

### Services and controllers

A service is a table made with `Oak.create`. `src/game/Server/Services/Features/ShopService.luau`:

```lua
--[[
    The shop: prices each item, takes coins for a purchase and hands the item
    to InventoryService, replicating each player's balance through a Property.
    Owns the Shop namespace, so every Shop endpoint and failure lands here
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Oak = require(Packages.Oak)
local Volt = require(Packages.Volt)

local Network = require(ReplicatedStorage.Shared.Network.Server)

local InventoryService: typeof(require("@Services/Features/InventoryService")) = Oak.getService("InventoryService")

local PRICES: { [string]: number } = require(ReplicatedStorage.Shared.Config.Shop).prices
local PURCHASE_BURST: number = require(ReplicatedStorage.Shared.Config.Shop).purchaseBurst
local PURCHASE_RATE: number = require(ReplicatedStorage.Shared.Config.Shop).purchaseRate
local STARTING_COINS: number = require(ReplicatedStorage.Shared.Config.Shop).startingCoins

type Bot = Volt.Bot

local Service = Oak.create("ShopService", {
	Client = {
		coins = Oak.Property(Network.Shop.coins, STARTING_COINS), -- Coin balance, per player
	},

	Policy = {
		purchase = { rate = { perSecond = PURCHASE_RATE, burst = PURCHASE_BURST } },
	},

	_prices = PRICES, -- What each item costs
	_sales = {} :: { [string]: number }, -- Units sold per item id on this server
})

--[[
    What an item costs, or nil for an item the shop doesn't sell
--]]

function Service.price(self: Self, itemId: string): number?
	return self._prices[itemId]
end

--[[
    Buys an item for a player: checks the price against their balance, puts
    the item in their inventory, then takes the coins. A refusal the player
    should read comes back as the reason
--]]

function Service.purchase(self: Self, player: Player, itemId: string): (boolean, string | nil)
	local price: number? = self:price(itemId)
	if not price then
		return false, `Unknown item: {itemId}`
	end

	local coins: number = self.Client.coins:GetFor(player)
	if coins < price then
		return false, `Not enough coins`
	end

	local inserted: boolean, reason: string? = InventoryService:insert(player, itemId)
	if not inserted then
		return false, reason
	end

	local remaining: number = coins - price
	self._sales[itemId] = (self._sales[itemId] or 0) + 1

	-- State through the Property, the notification through its own event
	self.Client.coins:SetFor(player, remaining)
	Network.Shop.purchased.fire(player, itemId, remaining)

	return true, nil
end

function Service.Client:purchase(player: Player, itemId: string): (boolean, string | nil)
	return (Service :: Self):purchase(player, itemId)
end

--[[
    Pays a player coins, for an item they sold back
--]]

function Service.pay(self: Self, player: Player, coins: number)
	self.Client.coins:SetFor(player, self.Client.coins:GetFor(player) + coins)
end

--[[
    Sends a player's balance again even though it hasn't changed, for a
    client that rebuilt its interface and lost what it had
--]]

function Service.resync(self: Self, player: Player)
	self.Client.coins:Refresh(player)
end

--[[
    Every Volt failure on a Shop message lands here instead of the game-wide
    handler, a purchase past the Policy row's rate among them
--]]

function Service.onFailure(player: Player | Bot, kind: string, detail: string)
	warn(`Shop {kind} failure from {player.Name}: {detail}`)
end

function Service:Start() end
function Service.Init(self: Self)
	self.Client.coins:SetTop(STARTING_COINS)
end

type Self = typeof(Service)

return Service
```

- `Oak.create(name, def)` takes the table's name first; the table itself has no `Name` field. The name is the registry name peers resolve by and loader errors and memory categories report, and by convention it matches the file name. The table's Volt namespace is that name less a trailing `Service` or `Controller`, so `ShopService` owns `namespace Shop`. `Oak.create(def)` with no name also works and takes the ModuleScript's name, with a warning at boot. Creating one table twice is an error.
- `create` returns the same table with its type unchanged, so methods, `Client` handlers, `onFailure`, `Init` and `Start` are added after the call, and any file that types this module autocompletes `:purchase`, `.Client.coins` and `._sales`.
- Oak reads five keys from the table: `Client`, `Policy`, `Init`, `Start` and `onFailure`. Every other key, such as `_sales`, is the service's own. A field whose first value is narrower than its type carries a cast in the literal, as `_sales` does.
- A method whose body uses `self` is defined with a dot and an annotated `self: Self`, called with a colon, and reaches the table through `self`, never through `Service`: the new checker checks neither the arguments nor the return of a call through the table's own local inside a function body. `type Self = typeof(Service)` is the last statement before the return: written directly after the create, it would leave the new checker unable to check calls through `self`.
- A `Client` handler is the one exception. The binder calls it with a colon, so its `self` is the `Client` table, and it sits directly under the method it wraps, names the player and forwards through the cast `(Service :: Self)`, which both checkers check fully.
- Both lifecycle methods are always written. An empty one keeps the colon on one line and goes first, directly above the one with a body, which takes the dot form. `GreeterService` above has both empty.
- Every service and controller file requires its realm's generated module as `Network` and calls handles through it, so each call is checked in the editor. A failure a service must report is a `(boolean, string | nil)` tuple, and every return path gives both values.

A controller is made the same way, with no `Client` and no `Policy`: the client's boot refuses a table with either. `src/game/Client/Services/Features/ShopController.luau`:

```lua
--[[
    The client half of the shop: the balance the server replicates, a toast
    for each purchase it confirms, buying through the Shop namespace and an
    answer to every item the server offers
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Oak = require(Packages.Oak)

local Network = require(ReplicatedStorage.Shared.Network.Client)

local NotificationController: typeof(require("@Controllers/Features/NotificationController")) =
	Oak.getController("NotificationController")

local Controller = Oak.create("ShopController", {
	coins = Oak.Property(Network.Shop.coins), -- This player's coin balance
})

--[[
    Whether the player can afford a price right now: false until the first
    balance has arrived, rather than waiting for it
--]]

function Controller.canAfford(self: Self, price: number): boolean
	local coins: number? = self.coins:Get()
	return coins ~= nil and coins >= price
end

--[[
    Asks the server to buy an item the player can afford, and toasts the
    reason for any refusal, whether the shop's or Volt's
--]]

function Controller.purchase(self: Self, itemId: string, price: number)
	if not self:canAfford(price) then
		return NotificationController:show(`Not enough coins for {itemId}`)
	end

	Network.Shop.purchase
		.invoke(itemId)
		:andThen(function (ok: boolean, reason: string?)
			if not ok then
				NotificationController:show(`Purchase refused: {reason}`)
			end
		end)
		:catch(function (reason: string)
			-- Volt's own refusals, such as rate limited or timeout
			NotificationController:show(`Purchase failed: {reason}`)
		end)
end

--[[
    Volt failures on a Shop message the server sent us. Only a bug can
    cause one, so it's logged
--]]

function Controller.onFailure(kind: string, detail: string)
	warn(`Shop {kind} failure: {detail}`)
end

function Controller:Start() end
function Controller.Init(self: Self)
	-- Both live for the whole client session, so neither keeps a disconnect
	Network.Shop.purchased.on(function (itemId: string, remaining: number)
		NotificationController:show(`Bought {itemId}, {remaining} coins left`)
	end)

	-- The client's boot checks this handler is connected once every Init has run
	Network.Shop.offer.on(function (_: string, price: number): boolean
		return self:canAfford(price)
	end)
end

type Self = typeof(Controller)

return Controller
```

The client reaches the server only through its `Network` module. There is no client `getService` and no auto-built proxy of a service. With `option yield = promise`, `invoke` returns a Promise that resolves with the handler's returns or rejects with Volt's reason. A file that makes a Promise of its own requires the package `: any`, `local Promise: any = require(Packages.Promise)`, because the new checker refuses every method call on a Promise whose require is bare. A function that returns one may annotate it `Oak.Promise<T...>`, which checks the first call on its chain.

### Peers

A service reaches another with `Oak.getService` and a controller another with `Oak.getController`, at module scope, first in the block after the `Network` require. The string carries no type, so the local is annotated with the peer's module type through the mode's aliases:

```lua
local InventoryService: typeof(require("@Services/Features/InventoryService")) = Oak.getService("InventoryService")
```

```lua
local NotificationController: typeof(require("@Controllers/Features/NotificationController")) =
	Oak.getController("NotificationController")
```

- The annotation goes on the local. A cast on the call, `Oak.getService("X") :: typeof(require(...))`, keeps no type in either checker, and an unannotated local is `any`. Both calls return `any`, which is what lets the annotation stand.
- Each call made before collect ends returns a lazy proxy that resolves to the named table on first use, so two modules can name each other with no require cycle. A call made after collect returns the table itself. Every name asked for is checked at the end of collect, and a name no collected table has fails the boot.
- The proxy forwards reads and writes to the real table, so `self._sales[itemId] = ...` in a method called through it lands on the service. Identity, iteration, `rawget` and `getmetatable` do not pass through, so a method never compares `self` with its own table, keys a table by `self`, iterates `self` or reads it raw.
- The `Init`s run one after another, so a peer whose answer depends on its own `Init` is called from `Start` or later.
- `getService` errors on the client and `getController` on the server.

#### A mutual pair

`ShopService` names `InventoryService`, and `InventoryService` names `ShopService` back. At runtime the proxies break the cycle, but the type checker still walks `typeof(require(...))`, and with it on both sides it reports a cyclic dependency and both types are lost. So one side types its peer through an interface declared in a module neither service requires. `src/game/Shared/Config/Types/Shop.luau`:

```lua
--[[
    The shop's shape for a peer that ShopService itself names, listing only
    the methods that peer calls; nothing checks it against ShopService
--]]

--!strict
export type ShopService = {
	price: (self: ShopService, itemId: string) -> number?,
	pay: (self: ShopService, player: Player, coins: number) -> (),
}

return {}
```

In the file that uses it, the interface's require sits directly above the peer line, named after its domain so it never clashes with a `Types` local of the file's own. A type annotation can only name a module required above it, and with the require below, the peer is untyped under both checkers with no error to say so. `src/game/Server/Services/Features/InventoryService.luau`:

```lua
--[[
    Every player's items: takes the item a player buys from the shop, and
    sells one back for the price ShopService lists for it
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Packages = ReplicatedStorage.Packages

local Oak = require(Packages.Oak)
local Observers = require(Packages.Observers)

local ShopTypes = require(ReplicatedStorage.Shared.Config.Types.Shop)
local ShopService: ShopTypes.ShopService = Oak.getService("ShopService") -- ShopService names us too, so this side types through the interface

local MAX_STACK: number = require(ServerScriptService.Server.Config.Inventory).maxStack
local SELL_RATE: number = require(ServerScriptService.Server.Config.Inventory).sellRate

local Service = Oak.create("InventoryService", {
	Client = {},

	Policy = {
		sell = { rate = { perSecond = SELL_RATE } },
	},

	_items = {} :: { [Player]: { [string]: number } }, -- How many of each item each player holds
})

--[[
    Gives a player one of an item, refused once they carry the most of it
    a player may
--]]

function Service.insert(self: Self, player: Player, itemId: string): (boolean, string | nil)
	local items: { [string]: number } = self._items[player] or {}
	local held: number = items[itemId] or 0
	if held >= MAX_STACK then
		return false, `You can't carry more {itemId}`
	end

	items[itemId] = held + 1
	self._items[player] = items

	return true, nil
end

--[[
    Sells one of an item back to the shop for the price it lists
--]]

function Service.sell(self: Self, player: Player, itemId: string): (boolean, string | nil)
	local items: { [string]: number } = self._items[player] or {}
	local held: number = items[itemId] or 0
	if held == 0 then
		return false, `You have no {itemId} to sell`
	end

	local price: number? = ShopService:price(itemId)
	if not price then
		return false, `The shop doesn't buy {itemId}`
	end

	items[itemId] = held - 1
	ShopService:pay(player, price)

	return true, nil
end

function Service.Client:sell(player: Player, itemId: string): (boolean, string | nil)
	return (Service :: Self):sell(player, itemId)
end

function Service:Start() end
function Service.Init(self: Self)
	-- Lives as long as the server
	Observers.observePlayer(function (player: Player)
		return function ()
			self._items[player] = nil
		end
	end)
end

type Self = typeof(Service)

return Service
```

Nothing checks the interface against `ShopService`'s real module, so a renamed method drifts silently until something calls it. Keep it to the methods the peer calls, and change it whenever one of them changes. A peer that doesn't name you back is typed the normal way.

### Lifecycle and boot

`Oak.start(rootOrList, Network)` boots a realm in this order:

1. The Volt line check: the boot fails, naming both versions, when the Volt that compiled `Network` and the Volt installed with Oak differ in major.minor.
2. Collect: `require` every ModuleScript under the root, deep (`Services/Features/` and `Services/Player/` alike), or every ModuleScript in a list, in its order. Each must return a table made by `Oak.create`. Two tables with one name, and on the client a table with `Client` or `Policy`, fail the boot, and collect ends by checking every peer name.
3. Bind: every binding check runs first, and only a clean one applies the `Policy` rates, takes the failure slot and connects the `Client` handlers. Nothing from the version check to here yields, so no inbound message is decoded before its rate and handler exist.
4. `Init`: each table's `Init`, in collect order, under `pcall`. Every failure is collected and reported with its table's name, then the boot fails: a half-initialized server is worse than a dead one.
5. On the client, the handler check: each server-to-client function in the client's `Network` with no handler connected fails the boot, naming the function and the controller that owns it. It runs after every `Init` and before any `Start`.
6. `Start`: each table's `Start` on a thread of its own, then `Oak.onStart()` resolves.

`Init` sets every `Client` Property's top value, registers per-player bindings and builds registries. It must not yield, since one yield stalls every table behind it, and nothing enforces that. It never binds an endpoint; Oak has already bound them. `Start` is for work that needs every other table's `Init` to have run.

A controller connects its server-to-client listeners in `Init`, and with them the handler of each server-to-client function, since the client's boot checks every such handler right after the `Init` pass. From `ShopController` above:

```lua
function Controller:Start() end
function Controller.Init(self: Self)
	-- Both live for the whole client session, so neither keeps a disconnect
	Network.Shop.purchased.on(function (itemId: string, remaining: number)
		NotificationController:show(`Bought {itemId}, {remaining} coins left`)
	end)

	-- The client's boot checks this handler is connected once every Init has run
	Network.Shop.offer.on(function (_: string, price: number): boolean
		return self:canAfford(price)
	end)
end
```

A listener, or a Property's `Observe`, connected in a controller's `Init` lives for the client session and keeps no disconnect. One connected for a character spawn, a screen, a component instance or a player goes into that owner's Trove, which calls the disconnect closure `on` and `Observe` return. Volt queues messages that arrive before a listener connects (64 per event by default, the oldest dropped), so a listener connected in `Init` loses nothing at join. A disconnected event queues again and replays at the next `on`, so an event to be ignored for a while is listened to for the session and checked inside the listener, rather than disconnected and connected per spawn.

Each realm's bootstrap sits at the realm root, hoists the realm's components onto the Component library, and starts its `Services` folder. `src/game/Server/init.server.luau`:

```lua
--[[
    Boots the Game server: hoists every component onto the Component library
    by its name, refusing one whose name the library already holds, then
    hands the Services tree and this mode's network module to Oak
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage.Packages

local Oak = require(packages.Oak)
local Component: any = require(packages.Component)

local Network = require(ReplicatedStorage.Shared.Network.Server) -- Volt-generated, this mode's module set

-- Git keeps no empty folder, so Components is absent until the first one
-- lands; the hoist is a no-op until then
local components: Instance? = script:FindFirstChild("Components")
local descendants: { Instance } = components and components:GetDescendants() or {}

for _, instance: Instance in descendants do
	if not instance:IsA("ModuleScript") then
		continue
	end

	assert(
		not Component[instance.Name],
		`Cannot create component {instance.Name} because Component library has member with the same name!`
	)
	Component[instance.Name] = require(instance) :: any -- This allows us to quickly access components directly from the Component library.
end

Oak.start(script.Services, Network)
```

`init.client.luau` is its twin and passes `require(ReplicatedStorage.Shared.Network.Client)`. Controllers bind no endpoints, but Oak checks the client's namespaces and handlers against that module and takes the client's failure slot through it. The bootstrap passes `--!strict` under both checkers: the loop's list is a typed local because the old checker refuses `components and components:GetDescendants() or {}` written straight into the `for`, and the hoist casts what `require(instance)` returns because no checker can follow a require of a loop variable. Component is required `: any`, since the loop assigns onto the table the package returns.

`Oak.start` also takes a list of ModuleScripts, collected in its order, for a place whose one tree serves several modes or a bootstrap that wants its set readable. The dev place's server uses it to start one service of two:

```lua
	Oak.start({ script.Services.Features.ScoreService }, Network)
```

A list holds every peer its tables name, or collect fails. A list naming one module twice, or holding something that isn't a ModuleScript, fails the boot. The `Network` passed with a list is compiled for exactly that list, since every namespace in it needs a started owner.

Code outside the loader, mainly Components, waits for the boot with `Oak.onStart()`, which is typed `Oak.Promise<()>` so both checkers check the first call on its chain. The Shop Counter component under [Properties](#properties-and-refresh) shows it.

### Binding

Each mode compiles its own `Schemas/` folder into one module set with one remote scope. The options sit in one file, `src/game/Schemas/Game.volt`:

```
-- The Game mode's options
option serverOutput = "../Shared/Network/Server.luau"
option clientOutput = "../Shared/Network/Client.luau"
option typesOutput = "../Shared/Network/Types.luau"
option runtime = "ReplicatedStorage.Packages.Volt"
option scope = Game
option yield = promise
option promise = "ReplicatedStorage.Packages.Promise"
```

`volt src/game/Schemas` compiles every `.volt` file in the folder as one schema. Output paths are relative to the file that sets them, the compiler doesn't create a missing output folder, and the three generated modules are committed and never edited by hand. `volt --check` compiles and writes nothing, and fails when what is on disk differs from what the schema compiles to.

Binding is exhaustive both ways, and it is checked in one place before anything is applied:

- Every endpoint's registry name is exactly `Namespace.message`, one namespace and then the message, so `Network.Shop.purchase` is `"Shop.purchase"`. Endpoints are camelCase to match the handler's name.
- Every namespace in the `Network` passed to `Oak.start` has exactly one started owner on each realm: a service on the server and a controller on the client. A namespace that holds only exported types has no endpoints and needs no owner.
- On the server, every inbound endpoint (a `from: Client` or `from: Both` event, a client-to-server function, a `Polling` event) has a `Client` handler, except a `Polling` event, which its service drains with `iter`. Every function in `Client` names an inbound declaration, and a Property beside them is left alone. Every inbound endpoint has a `Policy` row ([Rate limits](#rate-limits)).

A namespace whose client side has nothing to do still needs its controller, and the controller may hold nothing. `src/game/Client/Services/Features/InventoryController.luau`:

```lua
--[[
    The owner of the Inventory namespace on the client, which every namespace
    in the client's Network needs, though this one holds nothing yet
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Oak = require(Packages.Oak)

local Controller = Oak.create("InventoryController", {})

function Controller:Start() end
function Controller:Init() end

type Self = typeof(Controller)

return Controller
```

What the boot refuses. Each error names its table, endpoint, namespace, event or versions, and the binder reports every binding error it finds in one go, so one review round fixes them all:

| Mistake | Why it is refused |
|---|---|
| `Shop.volt` declares `function refund` and `ShopService.Client` has no `refund` | an inbound endpoint with no handler would answer `no handler` forever |
| `ShopService.Client:refnd` with no `refnd` in `Shop.volt` | a handler with no declaration is a typo or a forgotten schema line |
| `Party.volt` exists and no started service is named `PartyService` | every namespace in the `Network` belongs to a started service on the server |
| on the client, `Network` holds `Shop` and no started controller is named `ShopController` | the same rule on the client |
| `ShopService.Policy` has no `purchase` row | every inbound endpoint Oak binds, `Polling` events included, has a `Policy` row |
| `purchase = { rate = { burst = PURCHASE_BURST } }`, or a `perSecond` that isn't a number | every row holds a numeric `perSecond`, so nothing Oak binds is unlimited |
| `ShopService.Policy` has a `refund` row and `Shop.volt` declares no inbound `refund` | a `Policy` key names an inbound endpoint in the service's namespace |
| a schema declares `event heartbeat` at its top level | every registry name is exactly `Namespace.message` |
| an endpoint sits in a nested namespace, `Shop.Admin.refund` | the same rule |
| the server starts `ShopService` and a table created as `Oak.create("Shop", ...)` | two started tables whose names give one namespace; the error names both |
| a module calls `Oak.create("Service", ...)` | a name that gives an empty namespace |
| `Network` was compiled by Volt 0.2 and the Volt installed with Oak is 0.1 | a `Network` from another Volt line; the error names both versions |
| `Network` was compiled with `option casing = pascal` | Oak reads each handle's `on` and `fire` by their camel names |
| on the client, a server-to-client function has no handler once every `Init` has run | a forgotten client handler, named with the controller that owns it |
| `Oak.getService("InventoryServce")` | no collected table has that name |
| two modules both call `Oak.create("ShopService", ...)` | a name belongs to one table per realm |
| two services' `Client` tables both make `Oak.Property(Network.Shop.coins, ...)` | an event has one server Property; the second errors as it is made, naming the event |
| a module on the client creates a table with `Client` or `Policy` | a service was created on the client |
| a module under `Services/` returns a plain table | only a table made by `Oak.create` is a service or controller |
| `Oak.create` is called on a table it already created | one table is one service |
| two services' `Init`s throw | both are reported with their names, then the boot errors |

So exposing an endpoint takes a deliberate act in two files, a schema line and a handler with its `Policy` row, and forgetting any one of them fails the boot. Nothing in `Client` becomes a public remote by accident, and no endpoint is silently dead.

### The inbound pipeline

Every message a client sends passes the same fixed stages, with no configuration. The first three are Volt's and run before any game code:

1. Packet checks: the packet is within `maxPacket` (8,192 bytes), within the player's packet rate (`maxPacketsPerSecond`, 240), and comes after a completed schema-hash handshake.
2. Decode and validation: every length, range, enum tag, map key and instance class is checked as it is read. The declaration is the only payload schema, and read-side validation cannot be turned off.
3. Rate limit: a per-player, per-endpoint token bucket, with the rate from the endpoint's `Policy` row.
4. The handler: `Service.Client:purchase(player, itemId)`, whose returns become the reply. Volt runs a function's handler under `task.spawn` and `xpcall`.

Every Volt stage drops silently, so a probing client never learns which layer refused it: a function call refused at the rate stage is answered `rate limited`, and one dropped before it times out. A refusal the player should see (not enough coins, a full bag) is the handler's `(false, reason)`, and so is hostile or impossible input, since Volt has already dropped anything malformed. Every semantic check, such as distance, whether the character is alive, or line of sight, lives on the handler's path in the game's own class stack, on server-side state. Oak adds no stage: there is no middleware, guard list or hook between Volt's checks and the handler, so nothing rewrites arguments.

A handler's `player` may be a Tread test bot, which Volt sets up like a player. Oak's own types take `Player | Bot`, `Oak.Bot` being Volt's `{ Name: string }`, wherever a bot can arrive: a service's `onFailure`, the `Oak.onFailure` callback and every per-player Property method. A `Client` handler annotates `Player`, and a handler that may meet a bot checks `Network.isBot(player)` before calling `Kick` or anything else a bot lacks, as `ModerationService` does under [Failure routing](#failure-routing). A game's own per-player records key by `Player` and clear through `Observers.observePlayer`, which works off the `Players` service a bot never joins.

### Rate limits

Every inbound endpoint Oak binds, `Polling` events included, has a `Policy` row with a numeric `perSecond` and an optional `burst`. Oak hands each row to Volt's `Network.rate(name, perSecond, burst)` at bind, `burst` defaulting to `perSecond`, so the limit lives in the game's `Config/` and changes without a recompile. Because Oak always calls `Network.rate` for an endpoint it binds, the schema's own `rate`, the mode's default rates (120 a second per event, 60 per function) and a schema's `unlimited` never apply to it. `src/game/Shared/Config/Shop.luau`:

```lua
--[[
    Tuning for the shop: what each item costs, how many coins a new player
    starts with and how fast anyone may buy
--]]

--!strict
return {
	purchaseRate = 2, -- Purchases a second a player can keep up
	purchaseBurst = 4, -- Purchases a player can make back to back after a pause
	startingCoins = 250,

	prices = {
		medkit = 150,
		scope = 900,
	} :: { [string]: number },
}
```

and the row in `ShopService` that reads it:

```lua
	Policy = {
		purchase = { rate = { perSecond = PURCHASE_RATE, burst = PURCHASE_BURST } },
	},
```

`perSecond` is how fast a player's bucket refills and `burst` how many tokens it holds, so a player who has been idle can buy four things at once and then two a second. A call past the limit is dropped before the handler: the caller's Promise rejects with `rate limited`, which `ShopController.purchase` above turns into a toast, and the server reports a `rate` failure on the message, `Shop.purchase: over 2 a second`, to the owner's `onFailure`. Client-side cooldowns are decorative: a limit is on the server or it doesn't exist. A networked package that binds its own endpoints, as Tread and Decree do, applies the rates the game's configuration hands it and may declare `unlimited` on its own scope.

### Failure routing

Volt reports every dropped packet or message through one failure slot as `(player, kind, detail)`, and Oak takes the slot of the `Network` passed to `Oak.start` on both realms. Each failure goes to the first of these that applies:

1. A failure on one message (`decode`, `listener`, `handler`, `queue`, `resolve`, or `rate` on that message) goes to the `onFailure` of the table whose namespace owns the message, read from the registry name at the front of its detail (`Shop.purchase: over 2 a second`). A `resolve` failure, an `AwaitedInstance` that never arrived, comes on the client alone and goes to the controller that owns the event. A table that defines `onFailure` owns the behavior for its failures, and Oak applies no default to them.
2. A packet-level failure (`packet`, `handshake`, `rate` on the packet bucket, `outgoing`, `departed`, `budget`), or a message failure whose owner has no `onFailure`, goes to the callback given to `Oak.onFailure`, set once per realm. A later call replaces the earlier callback.
3. With neither set, Oak hands the failure to Volt's own default handler, which kicks on `handshake` with both schema hashes in the message, says nothing on `departed` or `budget`, and otherwise warns at most once per player, per kind, per minute, so an attack cannot flood the log. It never kicks a test bot; it warns instead.

`onFailure` is an index on the table, like `Client` and `Policy`, written with a dot. A service's takes the player first, as `ShopService` above does:

```lua
function Service.onFailure(player: Player | Bot, kind: string, detail: string)
	warn(`Shop {kind} failure from {player.Name}: {detail}`)
end
```

A controller's takes no player, since the client hears only from the server:

```lua
function Controller.onFailure(kind: string, detail: string)
	warn(`Shop {kind} failure: {detail}`)
end
```

The realm-wide callback usually belongs to one service, set from its `Init`. `src/game/Server/Services/Player/ModerationService.luau`:

```lua
--[[
    Moderation: owns the game-wide Volt failure handler, kicking a client
    whose handshake fails and flagging one whose failures pile up, then
    removing a player once their flags reach the limit
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Packages = ReplicatedStorage.Packages

local Oak = require(Packages.Oak)
local Observers = require(Packages.Observers)
local Volt = require(Packages.Volt)

local Network = require(ReplicatedStorage.Shared.Network.Server)

local FLAG_LIMIT: number = require(ServerScriptService.Server.Config.Moderation).flagLimit
local STRIKE_LIMIT: number = require(ServerScriptService.Server.Config.Moderation).strikeLimit

type Bot = Volt.Bot

local Service = Oak.create("ModerationService", {
	_flags = {} :: { [Player]: number }, -- Flags raised against each player
})

--[[
    Raises a flag against a player. Enough of them and they're removed
--]]

function Service.flag(self: Self, player: Player, reason: string)
	local flags: number = (self._flags[player] or 0) + 1
	self._flags[player] = flags

	warn(`Flagged {player.Name} ({flags}/{FLAG_LIMIT}): {reason}`)

	if flags >= FLAG_LIMIT then
		player:Kick(`Removed for suspicious traffic`)
	end
end

--[[
    Every Volt failure no service claimed: packet level ones such as a
    failed handshake, and message level ones in a namespace with no
    onFailure. It runs inline wherever Volt reports, so it never yields,
    and a test bot, which has no Kick, is only warned about
--]]

function Service._onFailure(self: Self, player: (Player | Bot)?, kind: string, detail: string)
	if not player then
		return warn(`Volt {kind} failure: {detail}`)
	end

	if Network.isBot(player) then
		return warn(`Volt {kind} failure from a bot: {detail}`)
	end

	if kind == "handshake" then
		(player :: Player):Kick(`Your game is out of date, please rejoin`)
		return
	end

	-- stats(player) is Volt's live table, so this is a lookup and not a copy
	local strikes: number = Network.stats(player).failures[kind] or 0
	if strikes >= STRIKE_LIMIT then
		self:flag(player :: Player, `{strikes} {kind} failures`)
	end
end

function Service:Start() end
function Service.Init(self: Self)
	Oak.onFailure(function (player: (Player | Bot)?, kind: string, detail: string)
		self:_onFailure(player, kind, detail)
	end)

	-- Lives as long as the server
	Observers.observePlayer(function (player: Player)
		return function ()
			self._flags[player] = nil
		end
	end)
end

type Self = typeof(Service)

return Service
```

The callback takes `(player, kind, detail)` on both realms, as Volt calls its own handler, so on the client its `player` is nil. Setting it replaces Volt's default entirely, the kick on a failed handshake included, which is why `_onFailure` kicks on `handshake` itself.

Every handler on this path runs inline wherever Volt reports the failure: on the receive loop, inside the game's own `fire`, `invoke` and flush calls, in the Heartbeat flush and on a function handler's thread. None of them may yield. Oak calls the game's handlers through `pcall`, so one that throws is warned about and the rest of the packet still arrives. An error in an async listener (every `SingleAsync` and `ManyAsync` one) shows in the output and never reaches a failure handler. An `outgoing` failure for a player also reaches every server Property, whichever handler then takes it ([Properties](#properties-and-refresh)). Oak only routes failures: strikes, flags and kicks are the game's, and `Network.stats(player)` gives the live counters to count them from.

### Properties and Refresh

A value is state when a client must be able to read it at any moment and a late joiner must receive it: a balance, an inventory snapshot, settings, registry data sent once. State goes in an `Oak.Property`. A delta or a one-shot notification (a purchase, an inventory patch, a hit, a sound) goes in a plain event fired with `fire`, `fireAll`, `fireList`, `fireExcept` or `fireSet`, never in a Property, since replaying the last delta to a joiner means nothing. A large replicated table takes both: a `snapshot` Property and a `patch` event sharing a `version` counter.

A Property sits over one Volt event, `from: Server`, `Reliable`, with one type as its `data` (a struct for a value of several parts), and never an `AwaitedInstance`. The server half lives in a service's `Client` table and is made with a default, `Oak.Property(Network.Shop.coins, STARTING_COINS)`, typed `Oak.Property<number>` from the handle. An event has one server Property: a second `Oak.Property` on the same event errors as it is made, naming the event, because two would both replay to every joiner and interleave on the client.

| Server method | What it does |
|---|---|
| `SetTop(value)` | sets the top value, which every player without an override sees |
| `Set(value)` | sets the top value and drops every override, so everyone sees it |
| `SetFor(player, value)` | overrides one player's value |
| `SetForList(players, value)` | overrides each listed player with one value |
| `ClearFor(player)` / `ClearForList(players)` | puts players back on the top value |
| `Refresh(player?)` | sends the value a player sees again even when unchanged; with no player, to everyone |
| `Get()` | the top value |
| `GetFor(player)` | the value that player sees now: their override, or the top value |

`SetTop` and `Set` differ only for players with an override: with a top value of 250 and Alice on her own 900, `SetTop(300)` moves everyone else to 300 and leaves Alice on 900, while `Set(300)` moves everyone to 300 and forgets her override.

- A setter never resends a value equal to the last one sent to that target: numbers, strings and booleans compare with `==`, buffers by their bytes, and tables field by field at every depth. The Property keeps its own deep copy of what it sent, so a table mutated in place and set again still goes out.
- A joining player, or test bot, gets their current value as soon as Volt announces the join, and so does everyone already set up when `Oak.start` binds. Volt holds each player's reliable messages, in order, until their handshake arrives, so a client that loads its `Network` late still gets the replay.
- When a player leaves, the Property drops their override, its copy of what it sent them and any resend waiting on their handshake. A Property knows a player from Volt's join announcement until their leave, so `SetFor`, `SetForList` and `Refresh(player)` naming a player outside that window, one who has left or one whose join Volt has not announced yet, do nothing. Roblox promises no order among an event's handlers, and in Studio a game's own `PlayerAdded` handler, or `observePlayer`'s, runs before Volt's, so a `SetFor` made there before the handler yields does nothing and the player sees the top value. Set a player's own value once something about them has loaded, as `ShopService` does when `DataService:onLoaded` answers. `ClearFor` is only for putting a player who is still here back on the top value.
- When Volt drops a message to a player as an `outgoing` failure, every server Property forgets what it last sent that player, so the next set for them goes out even when it equals that value. A drop before their handshake also makes every Property send them its current value once the handshake is accepted. A value dropped after the handshake that never changes again stays stale until the game calls `Refresh`.

`ShopService`'s `pay` and `resync` from above:

```lua
function Service.pay(self: Self, player: Player, coins: number)
	self.Client.coins:SetFor(player, self.Client.coins:GetFor(player) + coins)
end
```

```lua
function Service.resync(self: Self, player: Player)
	self.Client.coins:Refresh(player)
end
```

On the client, `Oak.Property(event)` takes no default and returns one shared object per event, typed `Oak.ClientProperty<T>`. The first call creates it and connects the event's one listener, which lives for the client session; every later call returns the same object and connects nothing, so a single-listener event is never refused a second listener. A controller field for it is optional: a controller, a React hook and a Component may each call `Oak.Property(Network.Shop.coins)` and get the object `ShopController.coins` holds. A React hook does that in its body and returns `Observe`'s disconnect from its effect, so the listener goes when the component unmounts.

| Client method | What it does |
|---|---|
| `Get()` | the last value the server sent, typed `T?`: nil until the first arrives, so narrow it before comparing |
| `Observe(callback)` | calls `callback` at once when a value has arrived, then with every new one, and returns its disconnect |
| `OnReady()` | a Promise that resolves with the first value |
| `IsReady()` | whether a value has arrived |

`OnReady`'s Promise has no timeout of its own, so a caller that must not wait forever chains `:timeout(seconds)` with a time from its `Config/`. A client Property is read-only: code that reads it never writes into it or into a table inside it.

A Component reaches a controller through `Oak.getController` like any peer, never by requiring its path, and waits for the boot before using it. `src/game/Client/Components/Shop Counter.luau`, a sleitnick Component:

```lua
--[[
    A shop counter in the world: shows the price of the item its Item
    attribute names on its billboard, and how far short the player's coins
    fall, kept current as the balance changes
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Oak = require(Packages.Oak)
local ComponentModule: any = require(Packages.Component)
local Trove = require(Packages.Trove)

local ShopController: typeof(require("@Controllers/Features/ShopController")) = Oak.getController("ShopController")

local PRICES: { [string]: number } = require(ReplicatedStorage.Shared.Config.Shop).prices

type Trove = typeof(Trove.new())

local Component = ComponentModule.new({
	Tag = "Shop Counter",
})

type Self = {
	Instance: Instance,
	_trove: Trove,
}

function Component.Construct(self: Self)
	self._trove = Trove.new()
end

function Component.Start(self: Self)
	local itemId = self.Instance:GetAttribute("Item") :: string
	local billboard = self.Instance:FindFirstChild("Billboard") :: BillboardGui?
	local label = billboard and billboard:FindFirstChild("Price") :: TextLabel?
	local price: number? = PRICES[itemId]
	if not label or not price then
		return warn(`Shop Counter {self.Instance:GetFullName()} has no Price label, or sells nothing the shop prices`)
	end

	-- Components live outside the loader, so wait for every Start to be spawned
	Oak.onStart()
		:andThen(function ()
			-- This listener belongs to this counter, so its Trove disconnects it in Stop
			self._trove:Add(ShopController.coins:Observe(function (balance: number)
				label.Text = balance >= price and `{price} coins` or `{price} coins, {price - balance} short`
			end))
		end)
		:catch(error)
end

function Component.Stop(self: Self)
	if self._trove then
		self._trove:Destroy()
	end
end

return Component
```

The package types nothing about the table it returns, so its require is aliased `ComponentModule`, takes `: any`, and `type Self` is written out directly under the `ComponentModule.new` call, listing `Instance`, every field and every method. Every method, the lifecycle hooks included, is a dot method taking `self: Self` and keeps sleitnick's names. All per-instance state goes on `self` in `Construct`, and whatever `Construct` opens, `Stop` closes. Instance handles are cast at the call with the local left bare: `:: BillboardGui?` after a `FindFirstChild`, so the counter checks for the label before it uses it.

## Try it yourself

This repository holds a small game in `dev/` that runs every part above in a real Studio session, the dev place `dev.project.json` builds:

```
dev/
├── .luaurc              -- @Services and @Controllers
├── Schemas/Dev.volt     -- the Greeter and Score namespaces
├── Schemas/Stale.volt   -- Dev.volt with greet's name allowed longer, so its hash differs
├── Network/             -- Volt's output for Dev.volt, and Network/Stale/ for Stale.volt
├── Server/              -- init.server.luau, Config/, Services/Features/GreeterService and ScoreService
└── Client/              -- init.client.luau, Config/, Services/Features/GreeterController and ScoreController
```

`dev.project.json` maps `dev/Network` to `ReplicatedStorage.Shared.Network`, `dev/Server` to `ServerScriptService.Server` and `dev/Client` to `StarterPlayerScripts.Client`, and puts Oak (`src/`), Promise and Volt side by side in `ReplicatedStorage.Packages`, the shape a game's install has. `GreeterService` answers a client's `greet`, awards points through its peer `ScoreService` and announces the greeting to everyone, and counts the cheers its `Policy` row lets through. `ScoreService` holds each player's points in a Property, sets a per-player override from a `Players.PlayerAdded` handler it connects in `Init`, and asks the client what it holds through a server-to-client function. On the client, `ScoreController` observes the points and answers that function, and `GreeterController`, which names `ScoreController` as a peer, greets once and sends five cheers in one frame. Every step prints a line naming what happened, which is what the Output shows.

1. Install the tools and packages, from the repository root:

   ```sh
   rokit install
   wally install
   rojo sourcemap dev.project.json --output sourcemap.json
   wally-package-types --sourcemap sourcemap.json Packages/
   lune run volt
   ```

   The first `rokit install` asks you to trust each tool; trust only the pins in `rokit.toml`. `lune run volt` copies Volt's runtime into `.volt/src` for the Lune suite, which `lune run tests` runs.

2. Open the dev place in Studio (place `72398334513601`), run `rojo serve dev.project.json`, which serves on port 34875, and click Connect in the Rojo plugin.

3. Press Play and read the Output. The server prints each service's `Init` line, then each `Start` line, then `Server: Oak.onStart resolved, every Start is spawned`, and the client does the same for its controllers, ending `Client: Oak.onStart resolved, every Start is spawned`. Then the rest of the game runs:

   | What it shows | Lines to look for |
   |---|---|
   | A Property round trip | the server's `ScoreService: SetFor(<you>, 50), and GetFor now reads <n>`, and the client's `ScoreController: points are now <n>` for each value that arrives: 10, the top value, then 50 if the override landed, then the greeting's award on top of it |
   | A server-to-client function | `ScoreService: <you>'s client holds <n> points: true` on the server |
   | A `Client` handler answering `invoke` | `GreeterController: greet answered true, "Hello, <you>! That's greeting 1 on this server", and we hold <n> points` on the client, after `ScoreService: awarded <you> 5 points, <n> in all` on the server |
   | The pipeline, and a failure routed to `onFailure` | two `GreeterService: cheer <k> from <you> got through` lines, then three `GreeterService.onFailure: rate failure from <you>: Greeter.cheer: over 1 a second`, because the cheer row lets 2 through at once and 1 a second after and the client sent 5 |

   The override set from `PlayerAdded` shows what happens to a value set before Volt announces the join. `SetFor` on a player Volt hasn't announced does nothing, and in Studio `ScoreService`'s handler runs before Volt's, so the `GetFor now reads` line shows 10 and the client's values go 10, then 15. Roblox promises no order among an event's handlers, so a 50 would mean the override landed after all.

4. Two toggles show the boot's refusals. Each is a boolean attribute on Workspace, set in Edit mode before Play: Rojo serves nothing into Workspace, so it leaves them alone. Set one in Workspace's Attributes in the Properties window, or from the command bar, and remove it after the run, since an attribute saved with the place stays on:

   ```lua
   workspace:SetAttribute("OakDevUnownedNamespace", true)
   ```

   | Attribute | What it does | What the Output shows |
   |---|---|---|
   | `OakDevUnownedNamespace` | the server bootstrap starts a list holding `ScoreService` alone, so the `Greeter` namespace has no started service | on the server, `Oak could not start:` followed by `the Network's namespace Greeter has no started service`, and no `Init` line; the client still boots, and its greeting fails with `no handler` |
   | `OakDevStaleClient` | the client bootstrap passes `Shared.Network.Stale.Client` to `Oak.start`, compiled from `Stale.volt` | the server refuses the stale handshake and Volt's default handler kicks the player with `Volt: schema mismatch (client 0xC255DBC8, server 0xC98873D4)`, the stale hash first. The client's own boot refuses too, naming `Greeter` and `Score` as namespaces with no started controller, because it collects none |

   The stale client collects no controller on purpose: a controller requires the real `Network.Client`, which would start a second Volt runtime on the same scope, whose correct handshake could reach the server first.

5. After changing a schema, compile it again with `volt dev/Schemas/Dev.volt` and `volt dev/Schemas/Stale.volt`, and commit the modules they write. CI runs `volt --check` on every file in `dev/Schemas/` and `tests/Schemas/`, which fails when a committed module differs from what its schema compiles to.

The Lune suite in `tests/` runs Oak's source over Volt's in-memory mock with no Studio at all: `lune run tests`.

## API

| Member | Realm | What it does |
|---|---|---|
| `Oak.create(name, def)` | both | makes `def` a service or controller named `name` and returns the same table, its type unchanged; creating one table twice errors |
| `Oak.create(def)` | both | the same, named after its ModuleScript, with a warning at boot |
| `Oak.getService(name)` | server | a peer service, typed by the annotation on its local: a proxy before collect ends, the table after; errors on the client |
| `Oak.getController(name)` | client | a peer controller, the same way; errors on the server |
| `Oak.start(rootOrList, Network)` | both | boots the realm over its generated module: the Volt line check, collect (a root deep, or a list in order), bind, every `Init`, the client's handler check, every `Start`; any problem stops the boot with an error naming it |
| `Oak.onStart()` | both | an `Oak.Promise<()>` that resolves once every `Start` has been spawned, at once if they have |
| `Oak.onFailure(callback)` | both | sets the realm's handler for every Volt failure no table's `onFailure` takes, called `(player, kind, detail)` with `player` nil on the client; a later call replaces it |
| `Oak.Property(event, default)` | server | the server half over a `from: Server` event, its top value starting at `default` |
| `Oak.Property(event)` | client | the event's one shared client object |

The package root exports these types, which a game writes through the typed thunk:

| Type | What it is |
|---|---|
| `Oak.Property<T>` | the server half, with `Set`, `SetTop`, `SetFor`, `SetForList`, `ClearFor`, `ClearForList`, `Refresh`, `Get` and `GetFor` |
| `Oak.ClientProperty<T>` | the client half, with `Get`, `Observe`, `OnReady` and `IsReady` |
| `Oak.Promise<T...>` | the Promise `onStart` returns, typing `andThen`, `catch`, `await` and `expect`; a chain is `any` after its first call |
| `Oak.Bot` | Volt's test bot, `{ Name: string }`, which every per-player parameter Oak takes accepts beside `Player` |

What Oak reads from a table made with `create`:

| Key | Who has it | What Oak does with it |
|---|---|---|
| `Client` | a service | each function is the handler of the inbound endpoint of its name; any other value, such as a Property, is left alone |
| `Policy` | a service | each row's `rate = { perSecond, burst? }` goes to `Network.rate` at bind |
| `Init` | both | run under `pcall` in collect order, after bind |
| `Start` | both | spawned on its own thread once every `Init` has run |
| `onFailure` | both | `function Service.onFailure(player, kind, detail)` or `function Controller.onFailure(kind, detail)`, handed every Volt failure on a message in the table's namespace |

## Security

Oak runs under zero client trust: every remote payload is hostile until the server has proven otherwise.

- Oak's source is public. A `shared` Wally package replicates its ModuleScripts, source included, to every client, so Oak holds no admin user ids, rate thresholds or anti-cheat tolerances. A tunable such as a `Policy` rate lives in the game's `Config/`, and Oak applies it at bind.
- The Volt schemas and generated modules live in the game, never in Oak, which ships only the plumbing; the game passes its generated `Network` to `Oak.start`. A mode's `Shared/Network/Server.luau` replicates to clients too. It holds serializers, message ids and the typed API and nothing secret, and a game that wants it off the client moves `serverOutput` under the mode's `Server/`.
- There is no service lookup on the client. A client-callable lookup that lists server services leaks what they are, so there is no client `getService` and no auto-built client proxy: `Oak.getService` resolves a peer by name on the server alone, and the client reaches the server only through the endpoints its `Network` declares.
- Trust is enforced at boot. Exposing an endpoint takes a schema declaration, a handler and a `Policy` row, and a missing one fails the boot, so nothing in `Client` silently becomes a public remote and nothing Oak binds is unlimited. Volt's stages drop silently and Oak adds none of its own, so a refusal the player must see is the handler's `(false, reason)`, and every semantic check is the handler's, on server-side state: the client sends opaque references, indices and quantities, and the server works out everything else.
- Networked packages stay apart. Tread and Decree each run their own Volt scope, bind their own endpoints and handle their own failures, so their namespaces are never in the game's `Network` and none of their failures reach Oak.
- Oak's per-player state clears when Volt's leave callback runs for that player or bot, and the failure warning's throttle is Volt's own.
- Oak uses no `_G`, so the ban stays true inside a game that exempts its Wally packages from it.
- Oak's only secret is the `WALLY_AUTH` secret its publish job reads, which lives in the GitHub repository's settings and never in the repository.

## The design

Oak's full design, with the reasons behind each part of this README and the rulings it rests on, is kept in the project's knowledge base, which sits beside this repository and is not part of it.
