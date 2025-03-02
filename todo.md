### TODO:
- [ ] change output to provide the packets by component, allowing better replication through compiling libraries
    - [ ] reduce string key usage and opt for contiguous lists if possible?
- [ ] set up tests so that we can make sure the package works as expected
- [ ] rewrite targets based on [this discord message](https://discord.com/channels/385151591524597761/1248734074940559511/1341854413014175797)
- [x] remove packets with no changes? (may already be a feature, I don't remember)
- [ ] make it easier to exclude players from replication, maybe by making the value `(Player) -> boolean`
- [x] add example
- [x] add method to filter components that can be replicated to prevent mistakes?

### PLAN:
I think when the user wants to get all the packets but separate them by component, it would be nice to have it return data like this:
```luau
{
    [componentId] = {
        [Player] = {
            [entityId] = newValue (or the special nil/delete values)
        }
    }
}


getComponentChanges()
getDeletedEntities()
```
but then idk how to represent when entities are deleted. The other slight issue is that it doesn't represent public packets, so FireAllClients wouldn't work, but you can just add the component changes to all packets anyways.
