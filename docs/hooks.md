---
sidebar_position: 4
---

# Hooks

Hooks allow you to add features tied to the replication process.

:::warning
With any of the hook methods:
Only one callback can be set at a time and calling again will overwrite the previous callback.

If you'd like a signal or some sort of scheduler please set that up on your own.
:::

## Hook Methods

#### [`added()`](/api/feces#added)

Hooks onto when a new **entity** is replicated to the world, not for new components.
The added callback is called *after* the first component value reveived is set to
a newly replicated entity. This is because there has to be at least one replicating
component under an entity for it to be added through feces.

#### [`changed()`](/api/feces#changed)

Hooks onto when a **component** value is changed in the world. Called *before* the component's new value is set in the world. This means that you can get whether the entity has the component or not, and the previous value of the component.

This also allows you to check for component deletions, values being set to `nil`, and compare previous and current values. The callback will pass in `nil` to `value` if the component was removed or the value was set to nil.

:::tip
To know for sure if a component was removed and not set to nil, you would need to use the
context of your own game since the hooks aren't given that information. 
(Maybe we'll add a removed() hook in the future)
:::

```lua
feces.changed(function(entity, component, value)
    local had = world:has(entity, component)
    if not had then
        print("component added", component)
        return
    end
    local previous = world:get(entity, component)
    if value == nil then
        print("component removed or set to nil", component)
        return
    end
    print("component changed", component, previous, "->", value)
end)
```

#### [`deleted()`](/api/feces#deleted)

Hooks onto when an **entity** is deleted in the world. This is called *before* the entity is deleted, allowing you to get the component values and cleanup, fairly straightforward.