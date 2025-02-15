### TODO:
- [ ] change output to provide the packets by component, allowing better replication through compiling libraries
    - [ ] reduce string key usage and opt for contiguous lists if possible?
- [ ] set up tests so that we can make sure the package works as expected
- [ ] remove packets with no changes? (may already be a feature, I don't remember)
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
```
but then idk how to represent when entities are deleted. The other slight issue is that it doesn't represent public packets, so FireAllClients wouldn't work, but you can just add the component changes to all packets anyways.
