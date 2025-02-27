<div align="center">
    <img src="logo.png" width="600" />
</div>

#### _"Fast Entity Component Export System"_

A generalized replication system for [jecs](https://github.com/ukendio/jecs) that allows for easy and fast replication of components.

<br>

### Getting Started
Example in `examples/replication.luau` for how to use it. Here are some explanations and basic types:

```luau
feces.init :: (Jecs.World) -> ()
feces.replicated :: Jecs.Component<{Player} | Player?>
-- feces.replicated is readonly
```
`init()` should be obvious as to what it does, if the world is not set there will be warnings in the console.

`replicated` is the component used to mark entities that should be replicated by simply adding it to an entity, or replicate specific components by pairing it with the type of component.

If a list of players or a single player is provided, the component will only replicate to those players. This value is not meant to change at runtime and could cause issues if changed.

<br>

```luau
feces.getPackets :: () -> (() -> (number?, Packet?))
feces.getFullPacket :: () -> Packet
```

`getPackets()` returns an iterator to loop through all the packets at that frame

`getFullPacket()` returns all public entities and components at this frame (useful for giving new players a payload on join)

<br>

```luau
feces.applyPackets :: (EntityChanges) -> ()
feces.filterPackets :: (EntityChanges, ...: component<any>) -> ({ entity<any> }, { component<any> })
```

`applyPackets()` applies the packets to the world

`filterPackets()` filters the packets to only the components you want to replicate


<br>

### Installation
Either copy the code manually or use pesde:
```sh
pesde add neond00m/feces
```
