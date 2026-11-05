# Changelog

Every notable change to Oak is recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

1.0.0 is Oak's first release, so its entry lists everything a game gets. The README explains each item under the same name.

## [1.0.0] - 2026-11-05

### Added

#### Services and controllers

- `Oak.create(name, def)`, which makes a service or controller of a table and returns that same table with its type unchanged, so every method, `Client` handler and field keeps its type and autocompletes wherever the module is required. The name is the table's registry name, and its Volt namespace is the name less a trailing `Service` or `Controller`.
- `Oak.create(def)` with no name, which takes the ModuleScript's name and warns at boot.
- `Oak.getService(name)` on the server and `Oak.getController(name)` on the client, which return a lazy proxy before boot and the table itself after it. Two tables may name each other, since neither requires the other. The local a peer goes in is typed through the `@Services` and `@Controllers` `.luaurc` aliases.

#### Boot

- `Oak.start(rootOrList, Network)`, which boots a realm over the `Network` module Volt generated for it: a root walked deep, or a list of ModuleScripts in its order.
- The Volt line check: a `Network` compiled by a Volt whose major.minor differs from the Volt installed with Oak fails the boot, naming both versions.
- Exhaustive binding, run before anything is applied, which fails the boot on a namespace with no started owner, an endpoint outside a namespace or in a nested one, two tables giving one namespace, a `Network` compiled in a casing other than camel, an inbound endpoint with no handler, a handler with no declaration, an inbound endpoint with no `Policy` row or one without a numeric `perSecond`, and a `Policy` key naming no inbound endpoint. Every problem a step finds is reported together.
- `Policy` rows, `{ rate = { perSecond, burst } }`, applied through `Network.rate` at bind, with `burst` defaulting to `perSecond`.
- Every `Init` run under `pcall`, every failure reported with its table's name, then every `Start` spawned. On the client, a server-to-client function with no handler once every `Init` has run fails the boot before any `Start`.
- `Oak.onStart()`, a Promise that resolves once every `Start` has been spawned, typed `Oak.Promise<()>`.

#### Failure routing

- Volt's one failure slot, taken at boot: a failure on a message goes to the owning table's `onFailure`, and a packet-level failure, or one whose owner defines no `onFailure`, goes to the game's `Oak.onFailure(callback)`. With neither set, Volt's own default handler takes it, kicking on a failed handshake.
- Every game handler on that path runs under `pcall`, so one that throws is warned and the rest of the packet still arrives.

#### `Oak.Property`

- `Oak.Property(event, default)` on the server: a value over one Volt event, with `Set`, `SetTop`, `SetFor`, `SetForList`, `ClearFor`, `ClearForList`, `Refresh`, `Get` and `GetFor`.
- No resend of a value equal to the last one sent to that player, compared field by field at every depth and by bytes for a buffer, against Oak's own copy of what it sent.
- The join replay: every joining player and Tread test bot gets their current value when Volt's joined callback runs, held by Volt until their handshake.
- A dropped message (an `outgoing` failure) makes every Property forget what it last sent that player, and a drop before their handshake resends every value once the handshake is accepted.
- A second server Property on one event errors when it is made, naming the event.
- `Oak.Property(event)` on the client: one shared object per event, with `Get`, `Observe`, `OnReady` and `IsReady`, so a controller, a React hook and a Component each read the same object.

#### Types

- The package root re-exports `Oak.Property<T>`, `Oak.ClientProperty<T>`, `Oak.Promise<T...>` and `Oak.Bot`, which a game reaches after the typed install in the README.
- Every public function carries a Moonwave doc comment.
